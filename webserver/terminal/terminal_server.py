#!/usr/bin/env python3
"""
terminal_server.py
WebSocket PTY bridge for the ZCU102 browser terminal.
Spawns a real PTY shell and forwards I/O to/from the browser over WebSocket.

Architecture:
  Browser (xterm.js) <─── WebSocket ───> terminal_server.py <─── PTY ───> /bin/sh

Protocol (JSON over WebSocket):
  Browser → Server:  {"type": "input",  "data": "<keystrokes>"}
  Browser → Server:  {"type": "resize", "cols": N, "rows": M}
  Server  → Browser: {"type": "output", "data": "<terminal output>"}

Usage:
  python3 terminal_server.py
  python3 terminal_server.py --host 192.168.10.20 --port 8765 --shell /bin/sh
"""

import asyncio
import json
import os
import pty
import select
import signal
import struct
import fcntl
import termios
import argparse
import logging
import sys
import threading

# Try to import websockets — graceful error if missing
try:
    import websockets
    import websockets.server
except ImportError:
    print("ERROR: 'websockets' module not found.")
    print("Install with:  python3 -m pip install websockets")
    print("Or on PetaLinux: pip3 install websockets --break-system-packages")
    sys.exit(1)

# ── Logging ────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    datefmt='%H:%M:%S'
)
log = logging.getLogger('terminal_server')

# ── PTY helper ────────────────────────────────────────────────────

def set_pty_size(fd, cols, rows):
    """Set PTY window size so the shell knows its dimensions."""
    winsize = struct.pack('HHHH', rows, cols, 0, 0)
    try:
        fcntl.ioctl(fd, termios.TIOCSWINSZ, winsize)
    except Exception:
        pass  # not fatal

# ── WebSocket handler ─────────────────────────────────────────────

async def handle_terminal(websocket):
    """Handle one browser WebSocket connection → one PTY session."""
    client = websocket.remote_address
    log.info(f"Connection from {client}")

    # Spawn a PTY and start /bin/sh inside it
    shell = os.environ.get('SHELL', '/bin/sh')
    pid, master_fd = pty.fork()

    if pid == 0:
        # ── child process: becomes the shell ──
        os.environ.setdefault('TERM', 'xterm-color')
        os.environ.setdefault('PS1', r'\[\033[38;5;205m\]root@zcu102pcie\[\033[0m\]:\[\033[38;5;87m\]\w\[\033[0m\]\$ ')
        os.execvp(shell, [shell])
        # execvp never returns on success

    # ── parent process: bridge PTY ↔ WebSocket ──

    log.info(f"  Spawned shell PID={pid} on master_fd={master_fd}")
    # Send newline after short delay to trigger prompt

    loop = asyncio.get_event_loop()

    async def pty_to_ws():
        """Read PTY output and send to browser."""
        while True:
            try:
                # Run blocking read in thread pool to keep asyncio happy
                data = await loop.run_in_executor(
                    None,
                    lambda: _read_pty(master_fd)
                )
                if data is None:
                    break
                msg = json.dumps({'type': 'output', 'data': data.decode('utf-8', errors='replace')})
                await websocket.send(msg)
            except websockets.exceptions.ConnectionClosed:
                break
            except Exception as e:
                log.debug(f"pty_to_ws error: {e}")
                break

    def _read_pty(fd):
        """Blocking PTY read with select timeout."""
        try:
            r, _, _ = select.select([fd], [], [], 0.1)
            if r:
                return os.read(fd, 4096)
            return b''
        except (OSError, IOError):
            return None

    async def ws_to_pty():
        """Receive browser input and write to PTY."""
        async for message in websocket:
            try:
                msg = json.loads(message)
                if msg.get('type') == 'input':
                    data = msg['data'].encode('utf-8')
                    os.write(master_fd, data)
                elif msg.get('type') == 'resize':
                    cols = int(msg.get('cols', 80))
                    rows = int(msg.get('rows', 24))
                    set_pty_size(master_fd, cols, rows)
                    log.debug(f"Resize: {cols}×{rows}")
            except json.JSONDecodeError:
                # raw input fallback
                os.write(master_fd, message.encode('utf-8'))
            except (OSError, IOError):
                break
            except websockets.exceptions.ConnectionClosed:
                break

    # Run both directions concurrently
    try:
        await asyncio.gather(pty_to_ws(), ws_to_pty())
    except Exception as e:
        log.debug(f"Session ended: {e}")
    finally:
        log.info(f"Closing session for {client}")
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            os.close(master_fd)
        except OSError:
            pass
        try:
            os.waitpid(pid, os.WNOHANG)
        except ChildProcessError:
            pass

# ── Main ──────────────────────────────────────────────────────────

async def main(host, port):
    log.info(f"ZCU102 Terminal Server starting on ws://{host}:{port}")
    log.info(f"Shell: {os.environ.get('SHELL', '/bin/sh')}")
    log.info("Browser: open http://192.168.10.20:8080 → Terminal section → CONNECT")

    async with websockets.serve(
        handle_terminal,
        host,
        port,
        ping_interval=20,
        ping_timeout=30,
    ):
        log.info(f"Listening on ws://{host}:{port}")
        await asyncio.Future()  # run forever

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='ZCU102 WebSocket PTY terminal server')
    parser.add_argument('--host',  default='192.168.10.20', help='Bind address')
    parser.add_argument('--port',  default=8765, type=int,   help='WebSocket port')
    args = parser.parse_args()

    try:
        asyncio.run(main(args.host, args.port))
    except KeyboardInterrupt:
        log.info("Stopped.")
