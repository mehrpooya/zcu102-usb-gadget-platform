#!/bin/sh
# web_server_start.sh
# Serve the ZCU102 showcase webpage over USB Ethernet.
# Host opens: http://192.168.10.20:8080
#
# Usage: sudo ./web_server_start.sh
#
# Run AFTER ethernet_usb_start.sh and AFTER plugging USB cable.
#
# What this script does:
#   check files         <- verify index.html exists in web root
#   # kill any existing instance on port 8080
pkill -f "http.server 8080" 2>/dev/null
sleep 1

# check python3       <- verify python3 is available
#   start http.server   <- serve web root on 192.168.10.20:8080
#
# Files served:
#   index.html          <- main page
#   style.css           <- styling
#   app.js              <- JavaScript features
#   board.jpg           <- ZCU102 board photo
#   board-contents.jpg  <- kit contents photo
#
# After running:
#   Open browser on host: http://192.168.10.20:8080
#
# Stop: press Ctrl+C or run web_server_stop.sh

WEB_ROOT="/home/petalinux/www"
BIND_IP="192.168.10.20"
PORT="8080"

# ── check files ── verify web root and index.html exist ──────────
if [ ! -d "$WEB_ROOT" ]; then
    echo "ERROR: Web root not found: $WEB_ROOT"
    echo "Copy the web files first:"
    echo "  mkdir -p $WEB_ROOT"
    echo "  cp index.html style.css app.js board.jpg board-contents.jpg $WEB_ROOT/"
    exit 1
fi

if [ ! -f "$WEB_ROOT/index.html" ]; then
    echo "ERROR: index.html not found in $WEB_ROOT"
    echo "Copy the web files first"
    exit 1
fi

# ── # kill any existing instance on port 8080
pkill -f "http.server 8080" 2>/dev/null
sleep 1

# check python3 ── verify python3 is available ─────────────────
which python3 || { echo "ERROR: python3 not found"; exit 1; }
echo "python3 found: $(which python3)"

# ── show what will be served ──────────────────────────────────────
echo ""
echo "Files in web root ($WEB_ROOT):"
ls -lh "$WEB_ROOT/"
echo ""

# ── start http.server ── serve web root on BIND_IP:PORT ──────────
# --bind: listen only on USB Ethernet IP (192.168.10.20)
# --directory: serve files from WEB_ROOT
# runs in foreground — press Ctrl+C to stop
echo "check files         [OK] web files found"
echo "# kill any existing instance on port 8080
pkill -f "http.server 8080" 2>/dev/null
sleep 1

# check python3       [OK] python3 available"
echo "start http.server   [OK] starting..."
echo ""
echo "Open on Windows browser: http://$BIND_IP:$PORT"
echo "Press Ctrl+C to stop the server"
echo ""

python3 -m http.server "$PORT" --bind "$BIND_IP" --directory "$WEB_ROOT"
