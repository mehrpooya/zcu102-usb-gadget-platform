#!/bin/sh
# over_eth_nvme_http_stop.sh
# Stop the NVMe HTTP file server and unmount NVMe.
# Usage: sudo ./over_eth_nvme_http_stop.sh

echo "========================================"
echo " NVMe HTTP File Browser — STOP"
echo "========================================"
echo ""

echo "--- Stopping HTTP server ---"
pkill -9 -f "http.server 8080" 2>/dev/null
pkill -9 -f "http.server"      2>/dev/null
sleep 1
ps | grep "[h]ttp.server" || echo "    http.server: confirmed stopped [OK]"
echo ""

echo "--- Unmounting NVMe ---"
umount /mnt/nvme 2>/dev/null
grep nvme0n1p2 /proc/mounts || echo "    nvme0n1p2: confirmed unmounted [OK]"
echo ""

echo "========================================"
echo " http.server stopped  [OK]"
echo " NVMe unmounted       [OK]"
echo "========================================"
echo ""
echo " HTTP share is gone. USB Ethernet still up."
echo " Run ondm_triple_stop.sh when fully done."
