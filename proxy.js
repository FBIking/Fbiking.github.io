const http = require('http');
const net = require('net');
const url = require('url'); // Node.js built-in module for URL parsing

const PROXY_PORT = 8080; // Listen on a non-privileged port (> 1024)

// --- Handle standard HTTP requests ---
const server = http.createServer((req, res) => {
    console.log(`[${new Date().toLocaleTimeString()}] HTTP Request: ${req.method} ${req.url}`);

    // Parse the URL from the client's request
    const reqUrl = url.parse(req.url);

    // Prepare options for the request to the actual destination server
    const options = {
        hostname: reqUrl.hostname,
        port: reqUrl.port || 80, // Default to port 80 for HTTP
        path: reqUrl.path,
        method: req.method,
        headers: req.headers // Forward client headers
    };

    // Make the request to the actual destination server
    const proxyReq = http.request(options, (proxyRes) => {
        // Send the destination server's response headers back to the client
        res.writeHead(proxyRes.statusCode, proxyRes.headers);
        // Pipe the destination server's response body back to the client
        proxyRes.pipe(res);
    });

    // Pipe the client's request body to the destination server
    req.pipe(proxyReq);

    // Handle errors during the proxy request
    proxyReq.on('error', (err) => {
        console.error(`[${new Date().toLocaleTimeString()}] Proxy request error to ${options.hostname}:${options.port}: ${err.message}`);
        if (!res.headersSent) { // Only send error if headers haven't been sent yet
            res.writeHead(500, { 'Content-Type': 'text/plain' });
            res.end('Proxy Error: ' + err.message);
        }
    });

    // Handle client request errors
    req.on('error', (err) => {
        console.error(`[${new Date().toLocaleTimeString()}] Client request error: ${err.message}`);
        proxyReq.destroy(); // Close the connection to the target
    });
});

// --- Handle HTTPS CONNECT requests ---
// When a browser wants to make an HTTPS connection through a proxy,
// it sends a CONNECT request to the proxy. The proxy then establishes
// a raw TCP tunnel to the destination.
server.on('connect', (req, clientSocket, head) => {
    console.log(`[${new Date().toLocaleTimeString()}] HTTPS CONNECT: ${req.url}`);

    // req.url for CONNECT is typically "hostname:port" (e.g., "www.google.com:443")
    const [hostname, port] = req.url.split(':');
    const targetPort = parseInt(port, 10) || 443; // Default to 443 for HTTPS

    // Establish a direct TCP connection to the HTTPS destination
    const serverSocket = net.connect(targetPort, hostname, () => {
        // Inform the client that the tunnel is established
        clientSocket.write('HTTP/1.1 200 Connection Established\r\nProxy-agent: Node.js-Proxy\r\n\r\n');
        // Send any buffered data (head) from the client to the target
        serverSocket.write(head);
        // Pipe data in both directions to create the tunnel
        serverSocket.pipe(clientSocket);
        clientSocket.pipe(serverSocket);
    });

    // Handle errors on the target side of the tunnel
    serverSocket.on('error', (err) => {
        console.error(`[${new Date().toLocaleTimeString()}] HTTPS Target socket error to ${hostname}:${targetPort}: ${err.message}`);
        if (!clientSocket.writableEnded) {
            clientSocket.write('HTTP/1.1 500 Connection Error\r\n\r\n');
            clientSocket.end();
        }
    });

    // Handle errors on the client side of the tunnel
    clientSocket.on('error', (err) => {
        console.error(`[${new Date().toLocaleTimeString()}] HTTPS Client socket error: ${err.message}`);
        serverSocket.destroy(); // Close the connection to the target
    });

    // Handle client socket close
    clientSocket.on('end', () => {
        serverSocket.end();
    });
});

// Start the proxy server
server.listen(PROXY_PORT, () => {
    console.log(`[${new Date().toLocaleTimeString()}] HTTP/HTTPS Proxy listening on port ${PROXY_PORT}`);
    console.log(`Configure your browser/system to use this proxy at localhost:${PROXY_PORT}`);
});

server.on('error', (err) => {
    console.error(`[${new Date().toLocaleTimeString()}] Proxy server error: ${err.message}`);
});
