#!/bin/sh
# over_eth_nvme_http_start.sh
# Share /dev/nvme0n1p2 over USB Ethernet as a read-only HTTP file browser.
# Run AFTER ondm_triple_start.sh (USB Ethernet must be up first).
#
# Usage: sudo ./over_eth_nvme_http_start.sh
#
# What this script does:
#   mount nvme0n1p2      <- mount NVMe at /mnt/nvme
#   start python3 server <- serve /mnt/nvme on 192.168.10.20:8080
#
# Host access after running:
#   Windows browser: http://192.168.10.20:8080
#   Click any file to download it (read-only)
#
# Stop: sudo ./over_eth_nvme_http_stop.sh

DEVICE="/dev/nvme0n1p2"
MOUNT_POINT="/mnt/nvme"
BIND_IP="192.168.10.20"
PORT="8080"

echo "========================================"
echo " NVMe HTTP File Browser — START"
echo " over USB Ethernet (${BIND_IP}:${PORT})"
echo "========================================"
echo ""

# ─────────────────────────────────────────────
# MOUNT NVME
# ─────────────────────────────────────────────
echo "--- Mounting NVMe ---"
umount "$DEVICE"                           2>/dev/null
umount "/run/media/New Volume-nvme0n1p2"   2>/dev/null
mkdir -p "$MOUNT_POINT"
mount -t ntfs3 -o rw,force "$DEVICE" "$MOUNT_POINT"
grep nvme0n1p2 /proc/mounts
echo ""
echo "--- NVMe contents ---"
ls -lh "$MOUNT_POINT/"
echo "    mounted at $MOUNT_POINT [OK]"
echo ""

# ─────────────────────────────────────────────
# START HTTP SERVER
# ─────────────────────────────────────────────
echo "--- Starting HTTP file server ---"
echo "    bound to: $BIND_IP:$PORT"
echo "    serving : $MOUNT_POINT"
echo "    runs in foreground — Ctrl+C to stop"
echo "    OR use: sudo ./over_eth_nvme_http_stop.sh"
echo ""
echo "========================================"
echo " NVMe HTTP Browser is ACTIVE"
echo "========================================"
echo ""
echo " mount nvme         [OK] $MOUNT_POINT"
echo " start http.server  [OK] $BIND_IP:$PORT"
echo ""
echo " Windows browser: http://${BIND_IP}:${PORT}"
echo " Click any file to download"
echo ""

cd "$MOUNT_POINT"
python3 -m http.server "$PORT" --bind "$BIND_IP"
