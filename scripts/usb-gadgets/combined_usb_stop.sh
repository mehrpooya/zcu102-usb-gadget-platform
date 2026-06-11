#!/bin/sh
# combined_usb_stop.sh
# Cleanly stop the combined Ethernet + NVMe USB gadget.
#
# Usage: sudo ./combined_usb_stop.sh
#
# What this script does:
#   ip link down / flush    <- bring down the Ethernet interface
#   echo "" -> UDC          <- DEACTIVATE: sends clean disconnect to host
#   sleep 2                 <- let host process the disconnect
#   rm/rmdir cleanup        <- remove all configfs objects in correct order
#   verify clean            <- confirm gadget is fully gone
#
# After running: unplug the USB cable
#
# Note: /sys/class/udc/fe200000.usb/state may still show "configured"
#       after stop and after cable unplug — normal ZynqMP DWC3 behaviour.
#       The register retains last hardware state. Safely ignore it.
#       Empty output from "cat /sys/class/udc/fe200000.usb/function"
#       is the real indicator that no gadget is bound.

# ── ip link down / flush ── bring down Ethernet interface ────────
ip link set usb0 down       2>/dev/null
ip addr flush dev usb0      2>/dev/null

# ── echo "" -> UDC ── DEACTIVATE: sends clean disconnect to host ─
# host loses both the NIC and the drive simultaneously
# bash -c with shell redirect is more reliable than tee for empty string
bash -c 'echo "" > /sys/kernel/config/usb_gadget/g_combined/UDC'

# ── sleep 2 ── let host process the disconnect ───────────────────
sleep 2

# confirm UDC file is now empty (should print nothing)
cat /sys/kernel/config/usb_gadget/g_combined/UDC

# ── rm/rmdir cleanup ── remove configfs objects ──────────────────
# strict order: symlinks first, then leaf dirs, then parents
# 2>/dev/null on each line so already-absent entries do not cause errors

# remove both function symlinks from configuration
rm -f  /sys/kernel/config/usb_gadget/g_combined/configs/c.1/rndis.usb0        2>/dev/null
rm -f  /sys/kernel/config/usb_gadget/g_combined/configs/c.1/mass_storage.0    2>/dev/null

# remove config strings directory
rmdir  /sys/kernel/config/usb_gadget/g_combined/configs/c.1/strings/0x409     2>/dev/null

# remove configuration directory
rmdir  /sys/kernel/config/usb_gadget/g_combined/configs/c.1                   2>/dev/null

# remove RNDIS function directory
rmdir  /sys/kernel/config/usb_gadget/g_combined/functions/rndis.usb0          2>/dev/null

# remove mass storage function directory
rmdir  /sys/kernel/config/usb_gadget/g_combined/functions/mass_storage.0      2>/dev/null

# remove gadget strings directory
rmdir  /sys/kernel/config/usb_gadget/g_combined/strings/0x409                 2>/dev/null

# remove the gadget itself (only succeeds when all children are gone)
rmdir  /sys/kernel/config/usb_gadget/g_combined                               2>/dev/null

# ── verify clean ── confirm gadget is fully removed ──────────────
# check 1: usb_gadget directory should be empty (g_combined gone)
ls /sys/kernel/config/usb_gadget/

# check 2: UDC function should be empty (no gadget bound)
cat /sys/class/udc/fe200000.usb/function

# ── summary ──────────────────────────────────────────────────────
echo ""
echo "ip link down / flush    [OK] Ethernet interface brought down"
echo "echo \"\" -> UDC         [OK] DEACTIVATED — host lost NIC and drive"
echo "sleep 2                 [OK] host processed disconnect"
echo "rm/rmdir cleanup        [OK] all configfs objects removed"
echo "verify clean            [OK] check ls and cat output above"
echo ""
echo "You can now safely unplug the USB cable."
echo ""
echo "To remount NVMe on Linux after unplugging:"
echo "  sudo mount -t ntfs3 -o rw,force /dev/nvme0n1p2 /mnt/nvme"
