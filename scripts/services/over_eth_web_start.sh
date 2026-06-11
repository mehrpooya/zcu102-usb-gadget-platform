#!/bin/sh
# over_eth_web_start.sh
# Start ZCU102 showcase web page + interactive terminal over USB Ethernet.
# Run AFTER ondm_triple_start.sh (USB Ethernet must be up first).
#
# Usage: sudo ./over_eth_web_start.sh
#
# What this script does:
#   check files          <- verify terminal/ folder exists
#   install websockets   <- install python websockets module if missing
#   start HTTP server    <- serve /home/petalinux/terminal/ on port 8081
#   start WS PTY server  <- WebSocket PTY bridge on port 8765
#
# Host access after running:
#   Windows browser: http://192.168.10.20:8081
#   Scroll to Terminal section → click CONNECT → pink shell
#
# Stop: sudo ./over_eth_web_stop.sh

TERM_ROOT="/home/petalinux/terminal"
BIND_IP="192.168.10.20"
WEB_PORT="8081"
TERM_PORT="8765"
WEB_LOG="/tmp/over_eth_web.log"
TERM_LOG="/tmp/over_eth_terminal.log"
WEB_PID="/tmp/over_eth_web.pid"
TERM_PID="/tmp/over_eth_terminal.pid"

echo "========================================"
echo " ZCU102 Web + Terminal — START"
echo " over USB Ethernet (${BIND_IP})"
echo " HTTP  : http://${BIND_IP}:${WEB_PORT}"
echo " WS PTY: ws://${BIND_IP}:${TERM_PORT}"
echo "========================================"
echo ""

# ─────────────────────────────────────────────
# CHECK FILES
# ─────────────────────────────────────────────
echo "--- Checking web files ---"
if [ ! -f "$TERM_ROOT/index.html" ]; then
    echo "ERROR: $TERM_ROOT/index.html not found"
    echo "Copy terminal project files to $TERM_ROOT first"
    exit 1
fi
if [ ! -f "$TERM_ROOT/terminal_server.py" ]; then
    echo "ERROR: $TERM_ROOT/terminal_server.py not found"
    exit 1
fi
echo "    index.html          [OK]"
echo "    terminal_server.py  [OK]"
echo ""

# ─────────────────────────────────────────────
# INSTALL WEBSOCKETS IF MISSING
# ─────────────────────────────────────────────
echo "--- Checking websockets module ---"
python3 -c "import websockets" 2>/dev/null || {
    echo "    Installing websockets..."
    python3 -m pip install websockets --break-system-packages 2>/dev/null
}
python3 -c "import websockets" && echo "    websockets [OK]" \
                                || { echo "ERROR: websockets not available"; exit 1; }
echo ""

# ─────────────────────────────────────────────
# KILL ANY EXISTING INSTANCES
# ─────────────────────────────────────────────
kill $(cat "$WEB_PID"  2>/dev/null) 2>/dev/null
kill $(cat "$TERM_PID" 2>/dev/null) 2>/dev/null
pkill -f "http.server $WEB_PORT"    2>/dev/null
pkill -f "terminal_server.py"       2>/dev/null
sleep 1

# ─────────────────────────────────────────────
# START HTTP WEB SERVER (background)
# ─────────────────────────────────────────────
echo "--- Starting HTTP web server ---"
python3 -m http.server "$WEB_PORT" \
    --bind "$BIND_IP" \
    --directory "$TERM_ROOT" \
    >> "$WEB_LOG" 2>&1 &
echo $! > "$WEB_PID"
echo "    HTTP server PID=$(cat $WEB_PID) → http://${BIND_IP}:${WEB_PORT} [OK]"
echo ""

# ─────────────────────────────────────────────
# START WEBSOCKET PTY SERVER (background)
# ─────────────────────────────────────────────
echo "--- Starting WebSocket PTY server ---"
python3 "$TERM_ROOT/terminal_server.py" \
    --host "$BIND_IP" \
    --port "$TERM_PORT" \
    >> "$TERM_LOG" 2>&1 &
echo $! > "$TERM_PID"
echo "    WS PTY server PID=$(cat $TERM_PID) → ws://${BIND_IP}:${TERM_PORT} [OK]"
echo ""

# ─────────────────────────────────────────────
# VERIFY BOTH RUNNING
# ─────────────────────────────────────────────
sleep 2
WEB_OK="NO"  ; TERM_OK="NO"
kill -0 $(cat "$WEB_PID"  2>/dev/null) 2>/dev/null && WEB_OK="OK"
kill -0 $(cat "$TERM_PID" 2>/dev/null) 2>/dev/null && TERM_OK="OK"

if [ "$TERM_OK" = "NO" ]; then
    echo "Terminal server log:"
    cat "$TERM_LOG"
fi

# ─────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────
echo "========================================"
echo " ZCU102 Web + Terminal is ACTIVE"
echo "========================================"
echo ""
echo " check files         [OK]"
echo " websockets module   [OK]"
echo " HTTP web server     [$WEB_OK] http://${BIND_IP}:${WEB_PORT}"
echo " WS PTY server       [$TERM_OK] ws://${BIND_IP}:${TERM_PORT}"
echo ""
echo " Windows browser: http://${BIND_IP}:${WEB_PORT}"
echo " Scroll to Terminal section → click CONNECT"
echo " Pink interactive shell in the browser"
echo ""
echo " Logs:"
echo "   tail -f $WEB_LOG"
echo "   tail -f $TERM_LOG"
echo ""
echo " Stop: sudo ./over_eth_web_stop.sh"
echo "========================================"
