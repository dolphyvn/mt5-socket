// ###################################################################
// Based on the awesome example from: https://www.mql5.com/en/blogs/post/706665
// ###################################################################

#property strict
input int   InpStopLossPoints    =  200;  // Stop loss in pips
input int   TakeProfitPoints     = 400; // Take profit in pips
input float   vol    =  5;  // Lot size
#include <socket-library-mt4-mt5.mqh>
#include <Trade/Trade.mqh>
CTrade trade;
CPositionInfo  m_position;
// Server socket
ServerSocket * glbServerSocket;

// Array of current clients
ClientSocket * glbClients[];

// Watch for need to create timer;
bool glbCreatedTimer = false;

// --------------------------------------------------------------------
// Initialisation - set up server socket
// --------------------------------------------------------------------

void OnInit()
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
   // Create the server socket
   glbServerSocket = new ServerSocket(5000, false);
   if (glbServerSocket.Created()) {
      Print("Server socket created");

      // Note: this can fail if MT4/5 starts up
      // with the EA already attached to a chart. Therefore,
      // we repeat in OnTick()
      glbCreatedTimer = EventSetMillisecondTimer(100);
   } else {
      Print("Server socket FAILED - is the port already in use?");
   }
}


// --------------------------------------------------------------------
// Termination - free server socket and any clients
// --------------------------------------------------------------------

void OnDeinit(const int reason)
{
   glbCreatedTimer = false;

   // Delete all clients currently connected
   for (int i = 0; i < ArraySize(glbClients); i++) {
      delete glbClients[i];
   }

   // Free the server socket
   delete glbServerSocket;
   Print("Server socket terminated");
}

// --------------------------------------------------------------------
// Timer - accept new connections, and handle incoming data from clients
// --------------------------------------------------------------------

void OnTimer()
{
   AcceptPendingConnections();
   ProcessClientCommands();
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
         pNewClient.Send("Connected to the MT5 Server!\r\n");
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
            HandleClientCommand(strCommand);
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
void HandleClientCommand(string strCommand)
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
      ExecuteBuyCommand(count, size, symbol, arr);
   } else if (action == "sell") {
      ExecuteSellCommand(count, size, symbol, arr);
   } else if (action == "close") {
      ClosePositions(arr);
   } else if (strCommand == "q") {
      delete glbServerSocket;
      Print("Server socket terminated");
   }
}

void ExecuteBuyCommand(int count, double size, string symbol, string &arr[])
{
   if (count == 3) {
      trade.Buy(size);
   } else if (count >= 4) {
      int sl = StringToInteger(arr[3]);
      int tp = StringToInteger(arr[4]);
      trade.Buy(size, symbol, "", sl, tp);
   }
}

void ExecuteSellCommand(int count, double size, string symbol, string &arr[])
{
   if (count == 3) {
      trade.Sell(size);
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


void OnTimer__()
{
   string recvMsg = "No data recived";
   // Keep accepting any pending connections until Accept() returns NULL
   ClientSocket * pNewClient = NULL;

   do {
      pNewClient = glbServerSocket.Accept();
      if (pNewClient != NULL) {
         int sz = ArraySize(glbClients);
         ArrayResize(glbClients, sz + 1);
         glbClients[sz] = pNewClient;

         Print("Connection recived!");
         pNewClient.Send("Connected to the MT5 Server!\r\n");
      }

   } while (pNewClient != NULL);

   // Read incoming data from all current clients, watching for
   // any which now appear to be dead
   int ctClients = ArraySize(glbClients);
   for (int i = ctClients - 1; i >= 0; i--) {
      ClientSocket * pClient = glbClients[i];
      //pNewClient.Send("Hellowwwwww\r\n");


      // Keep reading CRLF-terminated lines of input from the client
      // until we run out of data
      string strCommand;
      do {
         strCommand = pClient.Receive();

         if (strCommand != "") Print(strCommand);
         string arr[]; // Declare a string array to store the split values
         int count = StringSplit(strCommand, ',', arr); // Split the string by comma
         if (count < 3) Print("Synax error");
         if (count > 2) {
            string action = arr[0];   // "buy"
            string symbol = arr[1];   // "GBPUSD"
            double size = StringToDouble(arr[2]); // 0.1
            Print(action, " ", symbol, " ", size);

            if (action == "buy") {
               if (count <= 3) {
                  trade.Buy(size);
               }
               
               if (count >= 4) {
                  int sl = StringToInteger(arr[3]); // 0.1
                  int tp = StringToInteger(arr[4]); // 0.1
                  trade.Buy(size,symbol,"",sl,tp);
               } 
            }
            if (action == "sell") {
               if (count <= 3) {
                  trade.Buy(size);
               }
               
               if (count >= 4) {
                  int sl = StringToInteger(arr[3]); // 0.1
                  int tp = StringToInteger(arr[4]); // 0.1
                  trade.Sell(size,symbol,"",sl,tp);
               } 
            }
            
            if (action == "close") {
               double p = StringToDouble(arr[1]); // 0.1

               Print("Close all possitions");
               int      cnt         =  PositionsTotal();
               
               for (int i=cnt-1; i>=0; i--) {
                  ulong ticket   =  PositionGetTicket(i);
                  if (ticket>0) {
                    trade.PositionClosePartial(ticket,m_position.Volume()*(p),200); 
                  }
               }                              
            }


         }         
       
         // Free the server socket
         if (strCommand == "q"){
            delete glbServerSocket;
            Print("Server socket terminated");
          }

      } while (strCommand != "");

      if (!pClient.IsSocketConnected()) {
         // Client is dead. Remove from array
         delete pClient;
         for (int j = i + 1; j < ctClients; j++) {
            glbClients[j - 1] = glbClients[j];
         }
         ctClients--;
         ArrayResize(glbClients, ctClients);
      }
   }
}

// Use OnTick() to watch for failure to create the timer in OnInit()
void OnTick()
{
   if (!glbCreatedTimer) glbCreatedTimer = EventSetMillisecondTimer(100);
}
