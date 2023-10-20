
# Socket Server Command Interface

This README provides an overview of the command syntax for the socket server, as well as instructions on how to use the Flask API to send commands to the server via webhooks.

## Command Syntax

Commands sent to the socket server should be comma-separated strings. The general format is:

phpCopy code

`<action>,<symbol>,<size>[,<stop_loss>,<take_profit>]` 

-   `<action>`: The trading action. Valid values are `buy`, `sell`, or `close`.
-   `<symbol>`: The trading symbol (e.g., `GBPUSD`).
-   `<size>`: The trade size (e.g., `0.1`).
-   `<stop_loss>` (optional): The stop loss value.
-   `<take_profit>` (optional): The take profit value.

Examples:

-   To buy: `buy,GBPUSD,0.1`
-   To sell with stop loss and take profit: `sell,GBPUSD,0.1,1.3000,1.3100`
-   To close 50% all position: `close,0.5`
-   To close 100% all position: `close,1`

## Using the Flask API

The Flask API provides an endpoint to send commands to the socket server. The endpoint is:

bashCopy code

`POST /send_command` 

### Sample Webhook to Send Commands

To send a command to the socket server via the Flask API, you can use a tool like `curl` or any HTTP client:

bashCopy code

`curl -X POST http://localhost:5000/send_command \
     -H "Content-Type: application/json" \
     -d '{"command": "buy,GBPUSD,0.1"}'` 

Replace `"buy,GBPUSD,0.1"` with your desired command.

### Response

The Flask API will return a JSON response with the server's reply:

jsonCopy code

`{
    "response": "Server's response here"
}`
