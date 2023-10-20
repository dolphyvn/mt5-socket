from flask import Flask, request, jsonify
import socket

app = Flask(__name__)

# Configuration for the socket server
HOST = 'ea_IP'
PORT = 5000


def send_command_to_server(command):
    """Send a command to the socket server and return the response."""
    with socket.socket() as mySocket:
        mySocket.connect((HOST, PORT))
        mySocket.send(command.encode())
        data = mySocket.recv(1024).decode()
        return data


@app.route('/send_command', methods=['POST'])
def send_command():
    """Endpoint to send a command to the socket server."""
    data = request.json
    command = data.get('command', '')
    if not command:
        return jsonify({'error': 'Command not provided'}), 400

    response = send_command_to_server(command)
    return jsonify({'response': response})


if __name__ == '__main__':
    app.run(debug=True)
