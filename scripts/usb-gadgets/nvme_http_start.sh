#!/bin/sh
# nvme_http_start.sh
# Share /dev/nvme0n1p2 contents as a read-only HTTP file browser
# over USB Ethernet. No extra packages needed — uses Python3 built-in.
#
# Usage: sudo ./nvme_http_start.sh
#
# Run AFTER ethernet_usb_start.sh and AFTER plugging USB cable.
#
# What this script does:
#   mount nvme0n1p2      <- mount NVMe with ntfs3 read-write
#   start python3 server <- serve /mnt/nvme over HTTP on port 8080
#
# After running:
#   Windows: open browser -> http://192.168.10.20:8080
#   You see a directory listing of all NVMe files
#   Click any file to download it
#
# Limitations:
#   Read-only from Windows side (browser download only)
#   Windows cannot write or delete files
#   For read-write access, use Samba instead
#
# Stop: press Ctrl+C to stop the server
# When done: run nvme_http_stop.sh

DEVICE="/dev/nvme0n1p2"
MOUNT_POINT="/mnt/nvme"
BIND_IP="192.168.10.20"
PORT="8080"

# ── mount nvme0n1p2 ── mount NVMe with ntfs3 read-write ──────────
# unmount first in case it is already mounted somewhere else
umount "$DEVICE"                          2>/dev/null
umount "/run/media/New Volume-nvme0n1p2"  2>/dev/null

# create mount point if it does not exist
mkdir -p "$MOUNT_POINT"

# mount with ntfs3 kernel driver, rw + force to bypass dirty flag
mount -t ntfs3 -o rw,force "$DEVICE" "$MOUNT_POINT"

# confirm mount succeeded (should print the mount entry)
grep nvme0n1p2 /proc/mounts

# show what is on the drive
echo ""
echo "NVMe contents:"
ls -lh "$MOUNT_POINT/"
echo ""

# ── start python3 server ── serve files over HTTP ────────────────
# python3 -m http.server: built-in module, no install needed
# --bind: listen only on USB Ethernet interface (192.168.10.20)
# port 8080: accessible as http://192.168.10.20:8080
# runs in foreground — press Ctrl+C to stop
echo "mount nvme0n1p2      [OK] mounted at $MOUNT_POINT"
echo "start python3 server [OK] starting on $BIND_IP:$PORT"
echo ""
echo "Open on Windows: http://$BIND_IP:$PORT"
echo "Press Ctrl+C to stop the server"
echo ""

cd "$MOUNT_POINT"
python3 -m http.server "$PORT" --bind "$BIND_IP"
