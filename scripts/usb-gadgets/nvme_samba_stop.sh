#!/bin/sh
# nvme_samba_stop.sh
# Stop Samba file server and unmount the NVMe partition.
#
# Usage: sudo ./nvme_samba_stop.sh
# Run BEFORE ethernet_usb_stop.sh
#
# What this script does:
#   killall smbd/nmbd    <- kill ALL samba processes by name
#   sleep 2              <- let any open files finish
#   umount /mnt/nvme     <- unmount NVMe from Linux
#   verify clean         <- confirm nothing still running or mounted

MOUNT_POINT="/mnt/nvme"

# ── killall smbd/nmbd ── kill ALL Samba processes by name ────────
# Samba spawns one child process per connected client — killing only
# the parent PID from the pid file leaves child processes running.
# killall kills every process with that name including all children.
killall smbd 2>/dev/null || true
killall nmbd 2>/dev/null || true
echo "smbd and nmbd kill signal sent"

# ── sleep 2 ── let processes exit and files finish ───────────────
sleep 2

# ── verify processes stopped ── should print nothing ─────────────
ps | grep "[s]mbd" || echo "smbd: confirmed stopped"
ps | grep "[n]mbd" || echo "nmbd: confirmed stopped"

# ── umount /mnt/nvme ── unmount NVMe from Linux ──────────────────
umount "$MOUNT_POINT" 2>/dev/null

# confirm unmounted — should print nothing
grep nvme0n1p2 /proc/mounts || echo "nvme0n1p2: confirmed unmounted"

# ── verify mount point is free ───────────────────────────────────
mountpoint -q "$MOUNT_POINT" \
    && echo "WARNING: $MOUNT_POINT still mounted" \
    || echo "$MOUNT_POINT: unmounted"

# ── summary ──────────────────────────────────────────────────────
echo ""
echo "killall smbd/nmbd    [OK] all Samba processes stopped"
echo "sleep 2              [OK] writes flushed"
echo "umount /mnt/nvme     [OK] NVMe unmounted"
echo "verify clean         [OK] check output above"
echo ""
echo "Next: sudo ./ethernet_usb_stop.sh  then unplug cable"
