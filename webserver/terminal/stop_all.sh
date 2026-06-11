#!/bin/sh
# stop_all.sh  — terminal project
# Stops HTTP server + WebSocket PTY server.
# Run BEFORE ethernet_usb_stop.sh

WEB_PID="/tmp/terminal_web.pid"
TERM_PID="/tmp/terminal_server.pid"
WEB_PORT="8081"

kill $(cat "$WEB_PID"  2>/dev/null) 2>/dev/null
pkill -f "http.server $WEB_PORT"    2>/dev/null
rm -f "$WEB_PID"
echo "HTTP server stopped"

kill $(cat "$TERM_PID" 2>/dev/null) 2>/dev/null
pkill -f "terminal_server.py"       2>/dev/null
rm -f "$TERM_PID"
echo "WebSocket PTY server stopped"

sleep 1
ps | grep "[h]ttp.server $WEB_PORT" || echo "HTTP server: confirmed stopped"
ps | grep "[t]erminal_server"       || echo "Terminal server: confirmed stopped"

echo ""
echo "Both stopped. Next: sudo ./ethernet_usb_stop.sh  then unplug cable"
