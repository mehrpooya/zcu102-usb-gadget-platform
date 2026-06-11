#!/bin/sh
# over_eth_nvme_samba_stop.sh
# Stop Samba and unmount NVMe.
# Usage: sudo ./over_eth_nvme_samba_stop.sh

echo "========================================"
echo " NVMe Samba Share — STOP"
echo "========================================"
echo ""

echo "--- Stopping Samba ---"
killall smbd 2>/dev/null; echo "    smbd stopped"
killall nmbd 2>/dev/null; echo "    nmbd stopped"
sleep 2
ps | grep "[s]mbd" || echo "    smbd: confirmed stopped [OK]"
echo ""

echo "--- Unmounting NVMe ---"
umount /mnt/nvme 2>/dev/null
grep nvme0n1p2 /proc/mounts || echo "    nvme0n1p2: confirmed unmounted [OK]"
echo ""

echo "========================================"
echo " smbd/nmbd stopped  [OK]"
echo " NVMe unmounted     [OK]"
echo "========================================"
echo ""
echo " Samba share is gone. USB Ethernet still up."
echo " Run ondm_triple_stop.sh when fully done."
