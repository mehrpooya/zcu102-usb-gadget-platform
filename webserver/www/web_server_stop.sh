#!/bin/sh
# web_server_stop.sh - Stop the HTTP web server

# kill by process name pattern - catches all variants
pkill -9 -f "http.server" 2>/dev/null
pkill -9 -f "http.server 8080" 2>/dev/null

sleep 1

# verify
ps | grep "[h]ttp.server" || echo "http.server: confirmed stopped"
fuser 8080/tcp 2>/dev/null || echo "port 8080: free"

echo ""
echo "kill http.server    [OK] web server stopped"
echo "When done: run ethernet_usb_stop.sh  then unplug cable"
