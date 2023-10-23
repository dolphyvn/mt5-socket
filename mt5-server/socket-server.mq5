// ###################################################################
// Based on the awesome example from: https://www.mql5.com/en/blogs/post/706665
// ###################################################################
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.14"
#property description "b,n,m: market buy, s,d,f: market sell (if RR is 1:2 and first buy is 1 lot then n will be 2 and m will 4)"
#property description "o: limit buy, i: limit sell"
#property description "c: close all possitions"
#property description "q: close 25%, w: close 50%, e: close 75% ( only possition profit > 0)"
#property description "h: when you want to trade two way at the same time. "
#property description "1,2,3,4,5,6: to change to timeframe M1,M5,M15,M30,H1,H4 "
//#property description "q, w, e"

#property strict
input int   ServerPort     = 5000; // Server listen port
input int   InpStopLossPoints    =  200;  // Stop loss in pips
input int   TakeProfitPoints     = 400; // Take profit in pips
input float   vol    =  0.1;  // Lot size
input int    MaxTradesPerSymbol = 2; // Max trades per symbol
input string LicenseId = "License ID";   // Telegram chat ID
input bool EaClient = true; // Set EA to run or client. Default is client set to true 
input string targetCopyServerInfo = "192.168.68.201:7000"; // IP Address and port, comma for multiple 
    

#define KEY_1 49
#define KEY_2 50
#define KEY_3 51
#define KEY_4 52
#define KEY_5 53
#define KEY_6 54
#define KEY_H 72 // buy and sell at the same time
#define KEY_O 79 // O
#define KEY_I 73 // i
#define KEY_B 66 // b
#define KEY_N 78 // n
#define KEY_M 77 // m
#define KEY_S 83 // s
#define KEY_D 68 // d
#define KEY_C 67
#define KEY_F 70 // f. 
#define KEY_Q 81 // close 25%
#define KEY_W 87 // close 50%
#define KEY_E 69 // close 75%
#define KEY_P 80 // show profit or debug info
//
input int   InpStopLossPointsProfile1    =  50;  // Stop loss in pips profile 1
input int   TakeProfitPointsProfile1     = 200; // Take profit in pips profile 1
input float   volProfile1    =  5;  // Lot size profile 1
//

input double riskPercentage = 10; // Risk ratio in Percentage
input float   limit_spread = 0.001; // pips add or subtract on a pending order.
input double pipValueForOneLot = 10; //Assume pip value for a standard lot (1.0 lot) for major pairs like EURUSD is roughly $10 per pip
//input int   percentClose = 10; // Percentage to close a position
//input int   profitLevel = 50; // Min profit to close in percent
input string settings = "b,m,n=buy,s,d,f=sell,c=close,q=close 25%,w=close 50%,e=close 75%"; 
input string hedgekey = "h to buy and sell at the same time xD"; 



#include <socket-library-mt4-mt5.mqh>
#include <Trade/Trade.mqh>
CTrade trade;
CPositionInfo  m_position;
// Server socket
ServerSocket * glbServerSocket;

// Array of current clients
ClientSocket * glbClients[];
// define for client socket
//ClientSocket *targetCopyClient = NULL;
ClientSocket *socketClient = NULL;
// Watch for need to create timer;
bool glbCreatedTimer = false;

// --------------------------------------------------------------------
// Initialisation - set up server socket
// --------------------------------------------------------------------

int OnInit()
{

     
      datetime checkTime   =  TimeCurrent()-30;  // Only looking at trades in last 30 seconds
      int      cnt         =  PositionsTotal();                   // This won't see limit and stop orders
      for (int i=cnt-1; i>=0; i--) {
         ulong ticket   =  PositionGetTicket(i);
         if (ticket>0) {
            if (PositionGetInteger(POSITION_MAGIC)==0 && PositionGetDouble(POSITION_SL)==0) {
                           // magic 0 = manual entry, sl 0 means not set
               if (PositionGetInteger(POSITION_TIME)>checkTime) {             // lets you override after 30 seconds
                  string   symbol         =  PositionGetString(POSITION_SYMBOL);
                  double   stopLoss       =  InpStopLossPoints*SymbolInfoDouble(symbol, SYMBOL_POINT);
                  double   takeProfit     =  TakeProfitPoints*SymbolInfoDouble(symbol, SYMBOL_POINT);
                  double   takeProfitPrice = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) ?
                                             PositionGetDouble(POSITION_PRICE_OPEN)+takeProfit :
                                             PositionGetDouble(POSITION_PRICE_OPEN)-takeProfit;
                  double   stopLossPrice  =  (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) ?
                                             PositionGetDouble(POSITION_PRICE_OPEN)-stopLoss :
                                             PositionGetDouble(POSITION_PRICE_OPEN)+stopLoss;
                  stopLossPrice           =  NormalizeDouble(stopLossPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                  trade.PositionModify(ticket, stopLossPrice, takeProfitPrice);
                  
                
               }
            }
         }
      }   
      
      if (!EaClient) {
      
         // Create the server socket
         // Attempt to create the server socket
         glbServerSocket = new ServerSocket(ServerPort, false);
         
         // Check if the socket was created successfully
         if (glbServerSocket.Created()) 
         {
            Print("Server socket created on port: ", ServerPort);
            glbCreatedTimer = EventSetMillisecondTimer(100);
         } 
         else 
         {
            // If the socket creation failed, attempt to close it and retry
            if(glbServerSocket != NULL)
            {
               delete glbServerSocket;
               glbServerSocket = NULL;
            }
            
            // Wait for a moment
            Sleep(1000); // Wait for 1 second
            
            // Retry creating the socket
            glbServerSocket = new ServerSocket(ServerPort, false);
            if(glbServerSocket.Created())
            {
               Print("Server socket created on port: ", ServerPort, " after retrying.");
               glbCreatedTimer = EventSetMillisecondTimer(100);
            }
            else
            {
               Print("Server socket FAILED - is the port already in use?");
               return(INIT_FAILED);
            }
         }
         // Connect to main server
         string serverIP = "gpt.aliases.me"; // IP Address of the server
         ushort serverPyPort = 7300;      // Port number of the server 
         socketClient = new ClientSocket(serverIP, serverPyPort);
        
         if(socketClient.IsSocketConnected())
         {
            Print("Health check successfully!");
         }
         else
         {
            Print("Failed to Health check. Error: ", socketClient.GetLastSocketError());
         }
      
         return(INIT_SUCCEEDED);      
        
      }
      return(INIT_SUCCEEDED); 
}


// --------------------------------------------------------------------
// Termination - free server socket and any clients
// --------------------------------------------------------------------



// --------------------------------------------------------------------
// Timer - accept new connections, and handle incoming data from clients
// --------------------------------------------------------------------




void OnTimer()
{

   if (!EaClient) {
      AcceptPendingConnections();
      ProcessClientCommands();
   }



}

// Accept any pending connections
void AcceptPendingConnections()
{
   ClientSocket * pNewClient = NULL;
   do {
      pNewClient = glbServerSocket.Accept();
      if (pNewClient != NULL) {
         int sz = ArraySize(glbClients);
         ArrayResize(glbClients, sz + 1);
         glbClients[sz] = pNewClient;

         Print("Connection received!");
         pNewClient.Send("Connected to the meta master!\r\n");
      }
   } while (pNewClient != NULL);
}

// Process commands from all connected clients
void ProcessClientCommands()
{
   int ctClients = ArraySize(glbClients);
   for (int i = ctClients - 1; i >= 0; i--) {
      ClientSocket * pClient = glbClients[i];
      string strCommand;
      do {
         strCommand = pClient.Receive();
         if (strCommand != "") {
            Print("Receiving data from clients");
            HandleClientCommand(strCommand);
            SendDataToServer(strCommand);            
         }
      } while (strCommand != "");

      if (!pClient.IsSocketConnected()) {
         // Client is disconnected. Remove from array
         delete pClient;
         for (int j = i + 1; j < ctClients; j++) {
            glbClients[j - 1] = glbClients[j];
         }
         ctClients--;
         ArrayResize(glbClients, ctClients);
      }
   }
}


// Handle individual client commands
void HandleServerCommand(string strCommand)
{
   Print(strCommand);
   string arr[];
   int count = StringSplit(strCommand, ',', arr);
   if (count < 3) {
      Print("Syntax error");
      return;
   }

   string action = arr[0];
   string symbol = arr[1];
   double size = StringToDouble(arr[2]);

   if (action == "buy") {
      if (!MaxTrades(symbol)) {
         ExecuteBuyCommand(count, size, symbol, arr);
      }
      
   } else if (action == "sell") {
      if (!MaxTrades(symbol)) {
         ExecuteSellCommand(count, size, symbol, arr);
      }
      
   } else if (action == "close") {
      ClosePositions(arr);
   }
}
// Handle individual client commands
void HandleClientCommand(string strCommand)
{
   Print("Commands from client:");
   Print(strCommand);
   string arr[];
   int count = StringSplit(strCommand, ',', arr);
   if (count < 3) {
      Print("Syntax error");
      return;
   }

   string action = arr[0];
   string symbol = arr[1];
   double size = StringToDouble(arr[2]);
   Print("Request Symbol:", symbol);
   if (action == "buy") {
      Print("Buy request from client:");
      ExecuteBuyCommand(count, size, symbol, arr);
   } else if (action == "sell") {
      Print("Sell request from client:");
      ExecuteSellCommand(count, size, symbol, arr);
   } else if (action == "close") {
      Print("Close request from client:");
      ClosePositions(arr);
   } else if (strCommand == "q") {
      delete glbServerSocket;
      Print("Server socket terminated");
   }
}

void ExecuteBuyCommand(int count, double size, string symbol, string &arr[])
{
   if (count == 3) {
      trade.Buy(size,symbol);
   } else if (count >= 4) {
      int sl = StringToInteger(arr[3]);
      int tp = StringToInteger(arr[4]);
      trade.Buy(size, symbol, "", sl, tp);
   }
}

void ExecuteSellCommand(int count, double size, string symbol, string &arr[])
{
   if (count == 3) {
      trade.Sell(size,symbol);
   } else if (count >= 4) {
      int sl = StringToInteger(arr[3]);
      int tp = StringToInteger(arr[4]);
      trade.Sell(size, symbol, "", sl, tp);
   }
}

void ClosePositions(string &arr[])
{
   double p = StringToDouble(arr[1]);
   Print("Close all positions");
   int cnt = PositionsTotal();
   for (int i = cnt - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0) {
         trade.PositionClosePartial(ticket, m_position.Volume() * (p), 200);
      }
   }
}




// Use OnTick() to watch for failure to create the timer in OnInit()
void OnTick()
{
   if(EaClient) 
   {
   
      if (!glbCreatedTimer) glbCreatedTimer = EventSetMillisecondTimer(100);
      if(socketClient != NULL)
      {
         if(socketClient.IsSocketConnected())
         {
            Print("Socket is connected.");
         // Receive data from the server
            string receivedData = socketClient.Receive("\r\n"); // Assuming messages are separated by "\r\n"
            if(StringLen(receivedData) > 0)
            {
               Print("Received from server: ", receivedData);
               HandleServerCommand(receivedData);
            }
            else
            {
               Print("No data received from server.");
            }
         }
         else
         {
            Print("Socket is not connected. Error: ", socketClient.GetLastSocketError());
         }
      }
      else
      {
         Print("Socket client is NULL.");
      }      
   
   }
      datetime checkTime   =  TimeCurrent()-30;  // Only looking at trades in last 30 seconds
      int      cnt         =  PositionsTotal();                   // This won't see limit and stop orders
      for (int i=cnt-1; i>=0; i--) {
         ulong ticket   =  PositionGetTicket(i);
         if (ticket>0) {
            if (PositionGetInteger(POSITION_MAGIC)==0 && PositionGetDouble(POSITION_SL)==0) {
                           // magic 0 = manual entry, sl 0 means not set
               if (PositionGetInteger(POSITION_TIME)>checkTime) {             // lets you override after 30 seconds
                  string   symbol         =  PositionGetString(POSITION_SYMBOL);
                  double   stopLoss       =  InpStopLossPoints*SymbolInfoDouble(symbol, SYMBOL_POINT);
                  double   takeProfit     =  TakeProfitPoints*SymbolInfoDouble(symbol, SYMBOL_POINT);
                  double   takeProfitPrice = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) ?
                                             PositionGetDouble(POSITION_PRICE_OPEN)+takeProfit :
                                             PositionGetDouble(POSITION_PRICE_OPEN)-takeProfit;
                  double   stopLossPrice  =  (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) ?
                                             PositionGetDouble(POSITION_PRICE_OPEN)-stopLoss :
                                             PositionGetDouble(POSITION_PRICE_OPEN)+stopLoss;
                  stopLossPrice           =  NormalizeDouble(stopLossPrice, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                  trade.PositionModify(ticket, stopLossPrice, takeProfitPrice);
                  
                
               }
            }
         }
      } 
   
   
}


//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---

   // To be used for getting recent/latest price quotes
   MqlTick Latest_Price; // Structure to get the latest prices      
   SymbolInfoTick(Symbol() ,Latest_Price); // Assign current prices to structure 

// The BID price.
   static double dBid_Price; 

// The ASK price.
   static double dAsk_Price; 

   dBid_Price = Latest_Price.bid;  // Current Bid price.
   dAsk_Price = Latest_Price.ask;  // Current Ask price.
   
   if(riskPercentage != 0) {
   
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      // Calculate dollar amount at risk
      double dollarRisk = accountBalance * riskPercentage / 100.0;
      
      // Assume pip value for a standard lot (1.0 lot) for major pairs like EURUSD is roughly $10 per pip
      // For other pairs or account currencies, you need to adjust this value
      double pipValueForOneLot = 10.0;
       
      // Calculate lot size
      double vol = dollarRisk / (InpStopLossPoints * pipValueForOneLot);
      
      Print("Calculated lot size: ", vol);
   
   }

   int rr = TakeProfitPoints/InpStopLossPoints;
   
   if(id == CHARTEVENT_KEYDOWN){
   
      if(lparam == KEY_P){

         double pft=0;
         for(int i=PositionsTotal()-1;i>=0;i--)
           {
            ulong ticket=PositionGetTicket(i);
            if(ticket>0)
              {
               if(PositionGetInteger(POSITION_MAGIC)==0 && PositionGetString(POSITION_SYMBOL)==Symbol())
                 {
                  pft+=PositionGetDouble(POSITION_PROFIT);
                 }
              }
           }
         SendDataToServer("Testing");
      }   
      
      if(lparam == KEY_1){
         Print("1 pressed");
         ChartSetSymbolPeriod(0, NULL, PERIOD_M1);
         
      }
      if(lparam == KEY_2){
         Print("2 pressed");
         ChartSetSymbolPeriod(0, NULL, PERIOD_M5);
         
      }      
      if(lparam == KEY_3){
         Print("3 pressed");
         ChartSetSymbolPeriod(0, NULL, PERIOD_M15);
         
      } 
      if(lparam == KEY_4){
         Print("4 pressed");
         ChartSetSymbolPeriod(0, NULL, PERIOD_M30);
         
      }
 
      if(lparam == KEY_5){
         Print("5 pressed");
         ChartSetSymbolPeriod(0, NULL, PERIOD_H1);
         
      }  
      if(lparam == KEY_6){
         Print("6 pressed");
         ChartSetSymbolPeriod(0, NULL, PERIOD_H4);
         
      } 
      //double sum_profit = 0;
      double sum_profit = m_position.Commission()+m_position.Swap()+m_position.Profit(); 
      Print("Curent profit :",sum_profit);
        
      if(lparam == KEY_O){
         Print("o pressed");
         trade.SellLimit(vol,dAsk_Price+dAsk_Price*limit_spread);
         
      }
      if(lparam == KEY_I){
         Print("i pressed");
         trade.BuyLimit(vol,dAsk_Price-dAsk_Price*limit_spread);
         //trade.
         //trade.Buy(vol);
      }            
      if(lparam == KEY_B){
         Print("b pressed");
         //trade.BuyLimit(vol,dAsk_Price-dAsk_Price*0.05);
         //trade.
         trade.Buy(vol);
         if (EaClient) 
         {
            //Print("Curent profit :",Symbol());
           SendDataToServer("buy" + Symbol());
         }         
      }
      
      if(lparam == KEY_N){
         Print("n pressed");
         //trade.BuyLimit(vol,dAsk_Price-dAsk_Price*0.05);
         //trade.
         trade.Buy(vol*rr);
      }
      if(lparam == KEY_M){
         Print("m pressed");
         //trade.BuyLimit(vol,dAsk_Price-dAsk_Price*0.05);
         //trade.
         trade.Buy(vol*rr*2);
      }      
      if(lparam == KEY_S){
         Print("s pressed");
         
         trade.Sell(vol);
      }
      if(lparam == KEY_D){
         Print("d pressed");
         
         trade.Sell(vol*rr);
      }
      if(lparam == KEY_F){
         Print("f pressed");
         
         trade.Sell(vol*rr*2);
      }            
      if(lparam == KEY_H){
         Print("h pressed");
         trade.Buy(vol);
         trade.Sell(vol);
      } 
 
      if(lparam == KEY_C){
         Print("c pressed.Close all possitions");
         int      cnt         =  PositionsTotal();
         
         for (int i=cnt-1; i>=0; i--) {
            ulong ticket   =  PositionGetTicket(i);
            if (ticket>0) {

               
               trade.PositionClose(ticket);
               
            }
         }
       }    

      if(lparam == KEY_Q){
         Print("q pressed.Close 25% all possitions");
         int      cnt         =  PositionsTotal();
         
         for (int i=cnt-1; i>=0; i--) {
            ulong ticket   =  PositionGetTicket(i);
            if (ticket>0) {
               
               if (sum_profit > 0 ) {
                  trade.PositionClosePartial(ticket,m_position.Volume()*(0.25),200);
               }
            }
         }
       }



      if(lparam == KEY_W){
         Print("w pressed.Close 50% all possitions");
         int      cnt         =  PositionsTotal();
         
         for (int i=cnt-1; i>=0; i--) {
            ulong ticket   =  PositionGetTicket(i);
            if (ticket>0) {

               if (sum_profit > 0 ) {
                  trade.PositionClosePartial(ticket,m_position.Volume()*(0.5),200);
               }
            }
         }
       }

      if(lparam == KEY_E){
         Print("e pressed.Close 75% all possitions");
         int      cnt         =  PositionsTotal();
         
         for (int i=cnt-1; i>=0; i--) {
            ulong ticket   =  PositionGetTicket(i);
            if (ticket>0) {
              
               if (sum_profit > 0 ) {
                  trade.PositionClosePartial(ticket,m_position.Volume()*(0.75),200);
               }
            }
         }
       }      
       
   }
  }
  
void SendDataToServer(string data)
{
//  if (!EaClient) 
//  { 
  
     if(socketClient != NULL && socketClient.IsSocketConnected())
     {
       bool sent = socketClient.Send(data + "\r\n"); // Adding "\r\n" as a message separator
       if(sent)
       {
         Print("Health Check Look Good!");
       }
       else
       {
           Print("Health Check Error!");
         //Print("Failed to send data to server. Error: ", socketClient.GetLastSocketError());
       }
     }  
//  }

}

void OnDeinit(const int reason)
{
   if (!EaClient) {
      if(glbServerSocket != NULL)
      {
         delete glbServerSocket;
         glbServerSocket = NULL;
      }
      
      if(glbCreatedTimer != 0)
      {
         EventKillTimer();
         glbCreatedTimer = 0;
      }
   }

}

bool MaxTrades(string _symbol)
{
   int      trades = 0;
   int      cnt         =  PositionsTotal();                   // This won't see limit and stop orders
   for (int i=cnt-1; i>=0; i--) {
      ulong ticket   =  PositionGetTicket(i);
      if (ticket>0) {
         string symbol = PositionGetString(POSITION_SYMBOL);
         if (symbol == _symbol) {
            trades++;
         }
         
      }
   }   
   if (trades > MaxTradesPerSymbol) {
      return true;
   }
   return false;

}
