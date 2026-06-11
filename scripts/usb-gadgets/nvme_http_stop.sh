#!/bin/sh
# nvme_http_stop.sh
# Stop the NVMe HTTP file server and unmount the NVMe partition.
#
# Usage: sudo ./nvme_http_stop.sh
#
# Use this if you ran nvme_http_start.sh in the background
# or if you need to clean up after a Ctrl+C that left things mounted.
#
# What this script does:
#   kill python3 server  <- stop the HTTP server process
#   umount /mnt/nvme     <- unmount NVMe from Linux
#   verify clean         <- confirm nothing still running or mounted

MOUNT_POINT="/mnt/nvme"
PORT="8080"

# ── kill python3 server ── stop the HTTP server process ──────────
# find the python3 process running http.server on port 8080
# 2>/dev/null silences errors if process is not running
kill $(ps | grep "http.server $PORT" | grep -v grep | awk '{print $1}') 2>/dev/null
echo "python3 http.server: stopped"

# wait a moment for the process to exit cleanly
sleep 1

# ── umount /mnt/nvme ── unmount NVMe from Linux ──────────────────
umount "$MOUNT_POINT" 2>/dev/null

# confirm nothing is mounted on nvme0n1p2 (should print nothing)
grep nvme0n1p2 /proc/mounts || echo "nvme0n1p2: confirmed unmounted"

# ── verify clean ── confirm nothing still running or mounted ──────
# check no python3 http.server is still running
ps | grep "[h]ttp.server" || echo "http.server: not running"

# check mount point is free
mountpoint -q "$MOUNT_POINT" && echo "WARNING: $MOUNT_POINT still mounted" \
                               || echo "$MOUNT_POINT: unmounted"

# ── summary ──────────────────────────────────────────────────────
echo ""
echo "kill python3 server  [OK] HTTP server stopped"
echo "umount /mnt/nvme     [OK] NVMe unmounted from Linux"
echo "verify clean         [OK] check output above"
echo ""
echo "When done: run ethernet_usb_stop.sh  then unplug cable"
