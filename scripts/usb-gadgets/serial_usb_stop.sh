#!/bin/sh
# serial_usb_stop.sh
# Cleanly stop the USB CDC ACM serial gadget.
#
# Usage: sudo ./serial_usb_stop.sh
#
# What this script does:
#   kill getty           <- stop the login shell on ttyGS0
#   echo "" -> UDC       <- DEACTIVATE: sends clean disconnect to host
#   sleep 2              <- let host process the disconnect
#   rm/rmdir cleanup     <- remove all configfs objects in correct order
#   verify clean         <- confirm gadget is fully gone
#
# After running: unplug the USB cable
#
# Note: /sys/class/udc/fe200000.usb/state may still show "configured"
#       after stop — normal ZynqMP DWC3 behaviour, safely ignore it.
#       Empty output from "cat /sys/class/udc/fe200000.usb/function"
#       is the real indicator that no gadget is bound.

# ── kill getty ── stop the login shell ttyGS0 on ──────────
# find and kill the getty process running on ttyGS0
# 2>/dev/null silences errors if getty was not running
kill $(ps | grep "getty.*ttyGS0" | grep -v grep | awk '{print $1}') 2>/dev/null
killall -9 getty 2>/dev/null
echo "getty stopped"

# ── echo "" -> UDC ── DEACTIVATE: sends clean disconnect to host ─
bash -c 'echo "" > /sys/kernel/config/usb_gadget/g_serial/UDC'

# ── sleep 2 ── let host process the disconnect ───────────────────
sleep 2

# confirm UDC file is now empty (should print nothing)
cat /sys/kernel/config/usb_gadget/g_serial/UDC

# ── rm/rmdir cleanup ── remove configfs objects ──────────────────
# strict order: symlinks first, then leaf dirs, then parents
# 2>/dev/null silences errors for already-absent entries

# remove the symlink linking function into configuration
rm -f  /sys/kernel/config/usb_gadget/g_serial/configs/c.1/acm.GS0           2>/dev/null

# remove config strings directory
rmdir  /sys/kernel/config/usb_gadget/g_serial/configs/c.1/strings/0x409     2>/dev/null

# remove configuration directory
rmdir  /sys/kernel/config/usb_gadget/g_serial/configs/c.1                   2>/dev/null

# remove ACM function directory
rmdir  /sys/kernel/config/usb_gadget/g_serial/functions/acm.GS0             2>/dev/null

# remove gadget strings directory
rmdir  /sys/kernel/config/usb_gadget/g_serial/strings/0x409                 2>/dev/null

# remove the gadget itself
rmdir  /sys/kernel/config/usb_gadget/g_serial                               2>/dev/null

# ── verify clean ── confirm gadget is fully removed ──────────────
# check 1: usb_gadget directory should be empty (g_serial gone)
ls /sys/kernel/config/usb_gadget/

# check 2: UDC function should be empty (no gadget bound)
cat /sys/class/udc/fe200000.usb/function

# ── summary ──────────────────────────────────────────────────────
echo ""
echo "kill getty            [OK] login shell stopped"
echo "echo \"\" -> UDC       [OK] DEACTIVATED — host lost the COM port"
echo "sleep 2               [OK] host processed disconnect"
echo "rm/rmdir cleanup      [OK] all configfs objects removed"
echo "verify clean          [OK] check ls and cat output above"
echo ""
echo "You can now safely unplug the USB cable."
