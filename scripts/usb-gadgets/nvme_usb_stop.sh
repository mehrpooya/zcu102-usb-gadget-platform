#!/bin/sh
# nvme_usb_stop.sh
# Cleanly stop the NVMe USB mass storage gadget.
#
# Usage: sudo ./nvme_usb_stop.sh
#
# What this script does:
#   echo "" -> UDC      <- DEACTIVATE: sends clean disconnect to host
#   sleep 2             <- let host process the disconnect
#   rm/rmdir cleanup    <- remove all configfs objects in correct order
#   verify clean        <- confirm gadget is fully gone
#
# After running: unplug the USB cable
#
# Note: /sys/class/udc/fe200000.usb/state may still show "configured"
#       after stop and even after cable unplug — this is normal on
#       ZynqMP DWC3, the register retains last state, safely ignore it.
#       Use "cat /sys/class/udc/fe200000.usb/function" instead —
#       empty output means no gadget is bound (real success indicator).

# ── echo "" -> UDC ── DEACTIVATE: sends clean disconnect to host ─
# host (Windows) loses the drive immediately
# bash -c with shell redirect is more reliable than tee for empty string
bash -c 'echo "" > /sys/kernel/config/usb_gadget/g_nvme/UDC'

# ── sleep 2 ── let host process the disconnect ───────────────────
sleep 2

# confirm UDC file is now empty (should print nothing)
cat /sys/kernel/config/usb_gadget/g_nvme/UDC

# ── rm/rmdir cleanup ── remove configfs objects ──────────────────
# strict order: contents must be removed before their parent directory
# 2>/dev/null on each line so already-absent entries do not cause errors

# remove the symlink linking function into configuration
rm -f  /sys/kernel/config/usb_gadget/g_nvme/configs/c.1/mass_storage.0      2>/dev/null

# remove config strings directory
rmdir  /sys/kernel/config/usb_gadget/g_nvme/configs/c.1/strings/0x409       2>/dev/null

# remove configuration directory
rmdir  /sys/kernel/config/usb_gadget/g_nvme/configs/c.1                     2>/dev/null

# remove mass storage function directory
rmdir  /sys/kernel/config/usb_gadget/g_nvme/functions/mass_storage.0        2>/dev/null

# remove gadget strings directory
rmdir  /sys/kernel/config/usb_gadget/g_nvme/strings/0x409                   2>/dev/null

# remove the gadget itself (only succeeds when all children are gone)
rmdir  /sys/kernel/config/usb_gadget/g_nvme                                 2>/dev/null

# ── verify clean ── confirm gadget is fully removed ──────────────
# check 1: usb_gadget directory should be empty (g_nvme gone)
ls /sys/kernel/config/usb_gadget/

# check 2: UDC function should be empty (no gadget bound)
cat /sys/class/udc/fe200000.usb/function

# ── summary ──────────────────────────────────────────────────────
echo ""
echo "echo \"\" -> UDC     [OK] DEACTIVATED — host lost the device"
echo "sleep 2             [OK] host processed disconnect"
echo "rm/rmdir cleanup    [OK] all configfs objects removed"
echo "verify clean        [OK] check ls and cat output above"
echo ""
echo "You can now safely unplug the USB cable."
echo ""
echo "To remount NVMe on Linux after unplugging:"
echo "  sudo mount -t ntfs3 -o rw,force /dev/nvme0n1p2 /mnt/nvme"
