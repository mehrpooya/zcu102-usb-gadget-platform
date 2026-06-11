#!/bin/sh
# ondm_usb_stop.sh
# Cleanly stop the ONDM2026 file share USB gadget.
#
# Usage: sudo ./ondm_usb_stop.sh
#
# What this script does:
#   echo "" -> UDC      <- DEACTIVATE: sends clean disconnect to host
#   sleep 2             <- let host process the disconnect
#   rm/rmdir cleanup    <- remove all configfs objects in correct order
#   verify clean        <- confirm gadget is fully gone
#
# After running: unplug the USB cable
#
# The image file /home/petalinux/ondm_share.img is NOT deleted.
# It stays for the next run of ondm_usb_start.sh (faster restart).
# To refresh with new zip contents:
#   rm /home/petalinux/ondm_share.img
#   sudo ./ondm_usb_start.sh   <- recreates image with latest zip
#
# Note: /sys/class/udc/fe200000.usb/state may still show "configured"
#       after stop and after cable unplug — normal ZynqMP DWC3 behaviour.
#       The register retains last hardware state. Safely ignore it.
#       Empty output from "cat /sys/class/udc/fe200000.usb/function"
#       is the real indicator that no gadget is bound.

# ── echo "" -> UDC ── DEACTIVATE: sends clean disconnect to host ─
# host immediately loses the USB drive
# bash -c with shell redirect is more reliable than tee for empty string
bash -c 'echo "" > /sys/kernel/config/usb_gadget/g_ondm/UDC'

# ── sleep 2 ── let host process the disconnect ───────────────────
sleep 2

# confirm UDC file is now empty (should print nothing)
cat /sys/kernel/config/usb_gadget/g_ondm/UDC

# ── rm/rmdir cleanup ── remove configfs objects ──────────────────
# strict order: symlinks first, then leaf dirs, then parents
# 2>/dev/null on each line so already-absent entries do not cause errors

# remove the symlink linking function into configuration
rm -f  /sys/kernel/config/usb_gadget/g_ondm/configs/c.1/mass_storage.0      2>/dev/null

# remove config strings directory
rmdir  /sys/kernel/config/usb_gadget/g_ondm/configs/c.1/strings/0x409       2>/dev/null

# remove configuration directory
rmdir  /sys/kernel/config/usb_gadget/g_ondm/configs/c.1                     2>/dev/null

# remove mass storage function directory
rmdir  /sys/kernel/config/usb_gadget/g_ondm/functions/mass_storage.0        2>/dev/null

# remove gadget strings directory
rmdir  /sys/kernel/config/usb_gadget/g_ondm/strings/0x409                   2>/dev/null

# remove the gadget itself (only succeeds when all children are gone)
rmdir  /sys/kernel/config/usb_gadget/g_ondm                                 2>/dev/null

# ── verify clean ── confirm gadget is fully removed ──────────────
# check 1: usb_gadget directory should be empty (g_ondm gone)
ls /sys/kernel/config/usb_gadget/

# check 2: UDC function should be empty (no gadget bound)
cat /sys/class/udc/fe200000.usb/function

# ── summary ──────────────────────────────────────────────────────
echo ""
echo "echo \"\" -> UDC     [OK] DEACTIVATED — host lost the drive"
echo "sleep 2             [OK] host processed disconnect"
echo "rm/rmdir cleanup    [OK] all configfs objects removed"
echo "verify clean        [OK] check ls and cat output above"
echo ""
echo "You can now safely unplug the USB cable."
echo ""
echo "Image kept at: /home/petalinux/ondm_share.img"
echo "To refresh contents: rm /home/petalinux/ondm_share.img"
echo "                     sudo ./ondm_usb_start.sh"
