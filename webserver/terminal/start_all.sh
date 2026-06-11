#!/bin/sh
# start_all.sh  — terminal project
# Starts HTTP server (port 8081) + WebSocket PTY server (port 8765)
# Both run in background so terminal stays free.
#
# Usage: sudo ./start_all.sh
# Run AFTER ethernet_usb_start.sh and AFTER plugging USB cable.

TERM_ROOT="/home/petalinux/terminal"
BIND_IP="192.168.10.20"
WEB_PORT="8081"
TERM_PORT="8765"
WEB_LOG="/tmp/terminal_web.log"
TERM_LOG="/tmp/terminal_server.log"
WEB_PID="/tmp/terminal_web.pid"
TERM_PID="/tmp/terminal_server.pid"

# ── install websockets if missing ────────────────────────────────
python3 -c "import websockets" 2>/dev/null || {
    echo "Installing websockets..."
    python3 -m pip install websockets --break-system-packages 2>/dev/null
}

# ── kill any existing instances ───────────────────────────────────
kill $(cat "$WEB_PID"  2>/dev/null) 2>/dev/null
kill $(cat "$TERM_PID" 2>/dev/null) 2>/dev/null
pkill -f "http.server $WEB_PORT"    2>/dev/null
pkill -f "terminal_server.py"       2>/dev/null
sleep 1

# ── start HTTP server ─────────────────────────────────────────────
python3 -m http.server "$WEB_PORT" \
    --bind "$BIND_IP" \
    --directory "$TERM_ROOT" \
    >> "$WEB_LOG" 2>&1 &
echo $! > "$WEB_PID"
echo "HTTP server started    : PID=$(cat $WEB_PID) → http://$BIND_IP:$WEB_PORT"

# ── start WebSocket PTY server ────────────────────────────────────
python3 "$TERM_ROOT/terminal_server.py" \
    --host "$BIND_IP" \
    --port "$TERM_PORT" \
    >> "$TERM_LOG" 2>&1 &
echo $! > "$TERM_PID"
echo "WebSocket PTY server   : PID=$(cat $TERM_PID) → ws://$BIND_IP:$TERM_PORT"

# ── verify ────────────────────────────────────────────────────────
sleep 2
WEB_OK="NO" ; TERM_OK="NO"
kill -0 $(cat "$WEB_PID"  2>/dev/null) 2>/dev/null && WEB_OK="OK"
kill -0 $(cat "$TERM_PID" 2>/dev/null) 2>/dev/null && TERM_OK="OK"

echo ""
echo "HTTP server    : [$WEB_OK]"
echo "Terminal server: [$TERM_OK]"

if [ "$TERM_OK" = "NO" ]; then
    echo "Terminal server log:"; cat "$TERM_LOG"
fi

echo ""
echo "Open browser: http://$BIND_IP:$WEB_PORT"
echo "Scroll to Terminal section → click CONNECT"
echo "Stop: sudo ./stop_all.sh"
