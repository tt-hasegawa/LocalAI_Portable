/**
 * LocalAI Portable - Built-in HTTPS Reverse Proxy with WebSocket Support
 * Powered by bundled node.exe (Zero external dependencies)
 */

const https = require('https');
const http = require('http');
const fs = require('fs');
const net = require('net');
const path = require('path');

const ROOT_DIR = path.resolve(__dirname, '..');
const CERT_DIR = path.join(ROOT_DIR, 'cert');

const HTTPS_PORT = parseInt(process.env.HTTPS_PORT || '8443', 10);
const TARGET_HOST = process.env.VSCODE_LOCAL_HOST || '127.0.0.1';
const TARGET_PORT = parseInt(process.env.VSCODE_PORT || '8000', 10);
const PASSPHRASE = process.env.SSL_PASSPHRASE || 'localai';

// Load certificate: checks server.pfx or server.crt/server.key
let tlsOptions = {};
const pfxPath = path.join(CERT_DIR, 'server.pfx');
const crtPath = path.join(CERT_DIR, 'server.crt');
const keyPath = path.join(CERT_DIR, 'server.key');

if (fs.existsSync(pfxPath)) {
    tlsOptions = {
        pfx: fs.readFileSync(pfxPath),
        passphrase: PASSPHRASE
    };
} else if (fs.existsSync(crtPath) && fs.existsSync(keyPath)) {
    tlsOptions = {
        cert: fs.readFileSync(crtPath),
        key: fs.readFileSync(keyPath)
    };
} else {
    console.error('[HTTPS Proxy] Error: No SSL certificate found in ' + CERT_DIR);
    console.error('Expected either server.pfx or (server.crt + server.key).');
    process.exit(1);
}

// HTTP request proxy
const server = https.createServer(tlsOptions, (clientReq, clientRes) => {
    const options = {
        hostname: TARGET_HOST,
        port: TARGET_PORT,
        path: clientReq.url,
        method: clientReq.method,
        headers: {
            ...clientReq.headers,
            'x-forwarded-proto': 'https',
            'x-forwarded-host': clientReq.headers.host || ''
        }
    };

    const proxyReq = http.request(options, (proxyRes) => {
        clientRes.writeHead(proxyRes.statusCode, proxyRes.headers);
        proxyRes.pipe(clientRes);
    });

    proxyReq.on('error', (err) => {
        clientRes.writeHead(502, { 'Content-Type': 'text/plain; charset=utf-8' });
        clientRes.end('[LocalAI HTTPS Proxy] Bad Gateway: Cannot connect to VS Code Web on port ' + TARGET_PORT + ' (' + err.message + ')');
    });

    clientReq.pipe(proxyReq);
});

// WebSocket bidirectional proxy
server.on('upgrade', (req, clientSocket, head) => {
    const serverSocket = net.connect(TARGET_PORT, TARGET_HOST, () => {
        let raw = `${req.method} ${req.url} HTTP/${req.httpVersion}\r\n`;
        for (let i = 0; i < req.rawHeaders.length; i += 2) {
            raw += `${req.rawHeaders[i]}: ${req.rawHeaders[i + 1]}\r\n`;
        }
        raw += '\r\n';
        serverSocket.write(raw);
        if (head && head.length > 0) {
            serverSocket.write(head);
        }
        serverSocket.pipe(clientSocket);
        clientSocket.pipe(serverSocket);
    });

    serverSocket.on('error', () => clientSocket.destroy());
    clientSocket.on('error', () => serverSocket.destroy());
});

server.listen(HTTPS_PORT, '0.0.0.0', () => {
    console.log(`[HTTPS Proxy] Listening on https://0.0.0.0:${HTTPS_PORT} -> http://${TARGET_HOST}:${TARGET_PORT}`);
});
