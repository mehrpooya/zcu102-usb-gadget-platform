#!/bin/sh
# over_eth_web_stop.sh
# Stop the web server and WebSocket PTY server.
# Usage: sudo ./over_eth_web_stop.sh

WEB_PID="/tmp/over_eth_web.pid"
TERM_PID="/tmp/over_eth_terminal.pid"
WEB_PORT="8081"

echo "========================================"
echo " ZCU102 Web + Terminal — STOP"
echo "========================================"
echo ""

echo "--- Stopping HTTP web server ---"
kill $(cat "$WEB_PID" 2>/dev/null)  2>/dev/null
pkill -f "http.server $WEB_PORT"    2>/dev/null
rm -f "$WEB_PID"
sleep 1
ps | grep "[h]ttp.server $WEB_PORT" || echo "    http.server: confirmed stopped [OK]"
echo ""

echo "--- Stopping WebSocket PTY server ---"
kill $(cat "$TERM_PID" 2>/dev/null) 2>/dev/null
pkill -f "terminal_server.py"       2>/dev/null
rm -f "$TERM_PID"
sleep 1
ps | grep "[t]erminal_server"       || echo "    terminal_server: confirmed stopped [OK]"
echo ""

echo "========================================"
echo " HTTP web server stopped  [OK]"
echo " WS PTY server stopped    [OK]"
echo "========================================"
echo ""
echo " Web+Terminal gone. USB Ethernet still up."
echo " Run ondm_triple_stop.sh when fully done."
