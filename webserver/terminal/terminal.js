/* ═══════════════════════════════════════════════════════════════
   terminal.js — Fancy live browser terminal for ZCU102
   Uses xterm.js + xterm-addon-fit over WebSocket PTY
   WebSocket server: ws://192.168.10.20:8765
   ═══════════════════════════════════════════════════════════════ */

'use strict';

/* ── Configuration ─────────────────────────────────────────────── */
const TERM_WS_URL = 'ws://192.168.10.20:8765';

/* ── State ──────────────────────────────────────────────────────── */
let term        = null;
let fitAddon    = null;
let socket      = null;
let isConnected = false;
let isMinimised = false;
let isMaximised = false;
let resizeObs   = null;
let tsbarTimer  = null;

/* ── DOM helpers ────────────────────────────────────────────────── */
const $ = id => document.getElementById(id);

function setWsStatus(state) {
  const badge = $('ws-status-badge');
  const dot   = $('tsbar-dot');
  const label = $('tsbar-state');
  const btn   = $('btn-connect');

  badge.className = 'term-ws-status ' + state;
  dot.className   = 'tsbar-dot ' + state;

  if (state === 'connected') {
    badge.textContent = '● CONNECTED';
    label.textContent = 'Connected';
    btn.textContent   = 'DISCONNECT';
    btn.className     = 'tchrome-btn tchrome-connect connected-state';
    document.querySelector('.term-outer').classList.add('connected');
    isConnected = true;
  } else if (state === 'connecting') {
    badge.textContent = '◌ CONNECTING…';
    label.textContent = 'Connecting';
    btn.textContent   = 'CANCEL';
    btn.className     = 'tchrome-btn tchrome-connect';
    isConnected = false;
  } else {
    badge.textContent = '● DISCONNECTED';
    label.textContent = 'Disconnected';
    btn.textContent   = 'CONNECT';
    btn.className     = 'tchrome-btn tchrome-connect';
    document.querySelector('.term-outer').classList.remove('connected');
    isConnected = false;
  }
}

/* ── Terminal init ──────────────────────────────────────────────── */
function initTerminal() {
  if (term) return; // already created

  /* xterm.js FitAddon — from CDN global */
  fitAddon = new FitAddon.FitAddon();

  /* Hot-pink terminal theme */
  term = new Terminal({
    cursorBlink:      true,
    cursorStyle:      'block',
    fontSize:         14,
    fontFamily:       "'Share Tech Mono', 'Fira Code', 'Courier New', monospace",
    letterSpacing:    0.5,
    lineHeight:       1.3,
    scrollback:       2000,
    allowTransparency: true,
    theme: {
      background:    '#12010a',
      foreground:    '#ffb8e0',
      cursor:        '#ff2d78',
      cursorAccent:  '#12010a',
      selectionBackground: 'rgba(255,45,120,0.35)',
      black:         '#1a0112',
      red:           '#ff4757',
      green:         '#00e5c8',
      yellow:        '#f5a623',
      blue:          '#8a7fff',
      magenta:       '#ff6ec7',
      cyan:          '#00e5c8',
      white:         '#ffb8e0',
      brightBlack:   '#5a1040',
      brightRed:     '#ff6b6b',
      brightGreen:   '#64ffda',
      brightYellow:  '#ffd07a',
      brightBlue:    '#b0a8ff',
      brightMagenta: '#ff9edb',
      brightCyan:    '#64ffda',
      brightWhite:   '#fff0f8',
    }
  });

  term.loadAddon(fitAddon);

  const viewport = $('terminal-viewport');
  term.open(viewport);
  fitAddon.fit();
  updateColsRows();

  /* Resize observer — refit when div changes size */
  resizeObs = new ResizeObserver(() => {
    if (fitAddon) {
      fitAddon.fit();
      updateColsRows();
      if (socket && socket.readyState === WebSocket.OPEN) {
        socket.send(JSON.stringify({
          type: 'resize',
          cols: Math.round(term.cols),
          rows: Math.round(term.rows)
        }));
      }
    }
  });
  resizeObs.observe(viewport);

  /* Welcome banner — shown before connecting */
  showBanner();

  /* Update status bar clock every second */
  tsbarTimer = setInterval(() => {
    const now = new Date();
    const p   = n => String(n).padStart(2, '0');
    const el  = $('tsbar-time');
    if (el) el.textContent = `${p(now.getHours())}:${p(now.getMinutes())}:${p(now.getSeconds())}`;
  }, 1000);

  /* Keystrokes / paste → WebSocket → PTY
   * Registered ONCE here in initTerminal — never in termConnect.
   * Registering inside termConnect stacks a new listener on every
   * reconnect, causing keystrokes to be sent N times (doubled chars). */
  term.onData(data => {
    if (socket && socket.readyState === WebSocket.OPEN) {
      socket.send(JSON.stringify({ type: 'input', data }));
    }
  });
}

function updateColsRows() {
  const el = $('term-cols-rows');
  if (el && term) el.textContent = `${term.cols}×${term.rows}`;
}

function showBanner() {
  const lines = [
    '\r\n',
    '\x1b[38;5;205m  ╔═══════════════════════════════════════════════════════╗\x1b[0m\r\n',
    '\x1b[38;5;205m  ║\x1b[0m  \x1b[1;38;5;219m ZCU102 LIVE TERMINAL\x1b[0m                               \x1b[38;5;205m║\x1b[0m\r\n',
    '\x1b[38;5;205m  ║\x1b[0m  \x1b[38;5;87m Zynq UltraScale+ MPSoC · Cortex-A53 × 4\x1b[0m            \x1b[38;5;205m║\x1b[0m\r\n',
    '\x1b[38;5;205m  ║\x1b[0m  \x1b[38;5;214m PetaLinux 2024.1 · Linux 6.6.10-xilinx\x1b[0m              \x1b[38;5;205m║\x1b[0m\r\n',
    '\x1b[38;5;205m  ╚═══════════════════════════════════════════════════════╝\x1b[0m\r\n',
    '\r\n',
    '\x1b[38;5;248m  WebSocket endpoint : \x1b[38;5;205mws://192.168.10.20:8765\x1b[0m\r\n',
    '\x1b[38;5;248m  Status             : \x1b[38;5;196mDisconnected — press CONNECT\x1b[0m\r\n',
    '\r\n',
  ];
  lines.forEach(l => term.write(l));
}

/* ── WebSocket connect / disconnect ─────────────────────────────── */
function termConnect() {
  if (isConnected) {
    termDisconnect();
    return;
  }

  if (!term) initTerminal();

  setWsStatus('connecting');
  term.write('\r\n\x1b[38;5;214m  Connecting to ws://192.168.10.20:8765 …\x1b[0m\r\n');

  try {
    socket = new WebSocket(TERM_WS_URL);
  } catch(e) {
    term.write(`\x1b[31m  Error: ${e.message}\x1b[0m\r\n`);
    setWsStatus('disconnected');
    return;
  }

  socket.onopen = () => {
    setWsStatus('connected');
    term.write('\x1b[38;5;87m  Connected!\x1b[0m\r\n\r\n');
    term.focus();

    /* Send initial terminal size */
    socket.send(JSON.stringify({
      type: 'resize',
      cols: Math.round(term.cols),
      rows: Math.round(term.rows)
    }));
  };

  /* Data from server PTY → xterm.js */
  socket.onmessage = event => {
    if (typeof event.data === 'string') {
      try {
        const msg = JSON.parse(event.data);
        if (msg.type === 'output') {
          term.write(msg.data);
        }
      } catch(_) {
        /* raw text fallback */
        term.write(event.data);
      }
    } else {
      /* binary: decode as UTF-8 and write */
      event.data.arrayBuffer().then(buf => {
        term.write(new Uint8Array(buf));
      });
    }
  };

  socket.onerror = () => {
    term.write('\r\n\x1b[31m  WebSocket error — is terminal_server_start.sh running?\x1b[0m\r\n');
    setWsStatus('disconnected');
  };

  socket.onclose = () => {
    term.write('\r\n\x1b[38;5;248m  Connection closed.\x1b[0m\r\n');
    setWsStatus('disconnected');
  };

  /* NOTE: term.onData is registered once in initTerminal() */
  /* Registering it here on every connect would stack listeners */
  /* and double/triple keystrokes on reconnect — bug fixed */
}

function termDisconnect() {
  if (socket) {
    socket.close();
    socket = null;
  }
  setWsStatus('disconnected');
}

/* ── Chrome controls ────────────────────────────────────────────── */
function termClose() {
  termDisconnect();
  const outer = document.querySelector('.term-outer');
  outer.style.opacity    = '0';
  outer.style.transform  = 'scale(0.98)';
  outer.style.transition = 'opacity 0.3s, transform 0.3s';
  setTimeout(() => {
    outer.style.opacity   = '1';
    outer.style.transform = '';
    setWsStatus('disconnected');
  }, 1000);
}

function termMinimise() {
  const outer = document.querySelector('.term-outer');
  isMinimised = !isMinimised;
  outer.classList.toggle('minimised', isMinimised);
}

function termMaximise() {
  const outer = document.querySelector('.term-outer');
  isMaximised = !isMaximised;
  outer.classList.toggle('maximised', isMaximised);
  /* refit after transition */
  setTimeout(() => {
    if (fitAddon) {
      fitAddon.fit();
      updateColsRows();
    }
  }, 50);
}

/* ── Scroll-triggered init ──────────────────────────────────────── */
document.addEventListener('DOMContentLoaded', () => {
  setWsStatus('disconnected');

  /* Initialise terminal when its section scrolls into view */
  const sectionObserver = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting && !term) {
        initTerminal();
        sectionObserver.disconnect();
      }
    });
  }, { threshold: 0.1 });

  const sect = document.getElementById('terminal');
  if (sect) sectionObserver.observe(sect);
});
