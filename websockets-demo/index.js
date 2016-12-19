const WebSocketServer = require('ws').Server;
const wss = new WebSocketServer({port: process.env.PORT | 3000});

console.log('server is listening');

wss.on('connection', (ws) => {
    ws.on('message', (message) => {
        console.log('received: %s', message);
		ws.send(message);
    });
});
