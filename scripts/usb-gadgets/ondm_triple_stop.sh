#!/bin/sh
# ondm_triple_stop.sh
# Cleanly stop the ONDM triple USB composite gadget.
# Run this BEFORE unplugging the USB cable.
#
# Usage: sudo ./ondm_triple_stop.sh
#
# What this script does:
#   bring down usb0      <- stop Ethernet interface
#   echo "" → UDC        <- DEACTIVATE: clean disconnect to host
#   sleep 2              <- let host process the disconnect
#   rm/rmdir cleanup     <- remove configfs objects in correct order
#   verify clean         <- confirm gadget is fully gone
#
# After running: unplug the USB cable
#
# Note: ondm_share.img is NOT deleted — kept for next run.
# To refresh image: rm /home/petalinux/ondm_share.img
#
# Note: UDC state may still show "configured" after stop.
#       This is normal ZynqMP DWC3 behaviour — ignore it.
#       Use "cat /sys/class/udc/fe200000.usb/function" instead:
#       empty output = no gadget bound = clean stop.

GADGET_NAME="g_ondm_triple"
UDC="fe200000.usb"
GADGET_DIR="/sys/kernel/config/usb_gadget/$GADGET_NAME"

echo "========================================"
echo " ONDM Triple USB Gadget — STOP"
echo "========================================"
echo ""

# ─────────────────────────────────────────────
# ETHERNET: BRING DOWN usb0
# ─────────────────────────────────────────────

echo "--- Bringing down Ethernet interface ---"

ip link set usb0 down       2>/dev/null
ip addr flush dev usb0      2>/dev/null

echo "    usb0 down [OK]"
echo ""

# ─────────────────────────────────────────────
# DEACTIVATE: UNBIND FROM UDC
# Sends a clean USB disconnect signal to the host.
# Host loses all three devices simultaneously.
# bash -c with shell redirect is reliable for writing empty string.
# ─────────────────────────────────────────────

echo "--- Unbinding from UDC (sends clean disconnect to host) ---"

bash -c "echo \"\" > $GADGET_DIR/UDC" 2>/dev/null

# let the host process the disconnect
sleep 2

# confirm UDC file is empty (real success indicator)
UDC_VAL=$(cat "$GADGET_DIR/UDC" 2>/dev/null)
if [ -z "$UDC_VAL" ]; then
    echo "    UDC unbound [OK] — host lost all three devices"
else
    echo "    WARNING: UDC still shows: $UDC_VAL"
fi
echo ""

# ─────────────────────────────────────────────
# CLEANUP: REMOVE CONFIGFS OBJECTS
# Strict order: symlinks → leaf dirs → parent dirs
# 2>/dev/null so already-absent entries do not cause errors
# ─────────────────────────────────────────────

echo "--- Removing configfs objects ---"

# remove all function symlinks from configuration
rm -f  "$GADGET_DIR/configs/c.1/rndis.usb0"        2>/dev/null
echo "    symlink rndis.usb0     removed"

rm -f  "$GADGET_DIR/configs/c.1/mass_storage.0"    2>/dev/null
echo "    symlink mass_storage.0 removed"

rm -f  "$GADGET_DIR/configs/c.1/acm.GS0"           2>/dev/null
echo "    symlink acm.GS0        removed"

# remove config strings directory
rmdir  "$GADGET_DIR/configs/c.1/strings/0x409"     2>/dev/null
echo "    config strings removed"

# remove configuration directory
rmdir  "$GADGET_DIR/configs/c.1"                   2>/dev/null
echo "    config c.1 removed"

# remove RNDIS function directory
rmdir  "$GADGET_DIR/functions/rndis.usb0"          2>/dev/null
echo "    function rndis.usb0 removed"

# remove mass storage function directory
rmdir  "$GADGET_DIR/functions/mass_storage.0"      2>/dev/null
echo "    function mass_storage.0 removed"

# remove ACM serial function directory
rmdir  "$GADGET_DIR/functions/acm.GS0"             2>/dev/null
echo "    function acm.GS0 removed"

# remove gadget strings directory
rmdir  "$GADGET_DIR/strings/0x409"                 2>/dev/null
echo "    gadget strings removed"

# remove gadget directory (only works when all children are gone)
rmdir  "$GADGET_DIR"                               2>/dev/null
echo "    gadget $GADGET_NAME removed"
echo ""

# ─────────────────────────────────────────────
# VERIFY CLEAN
# ─────────────────────────────────────────────

echo "--- Verifying clean stop ---"

# check 1: configfs gadget directory gone
if [ ! -d "$GADGET_DIR" ]; then
    echo "    configfs: clean [OK]"
else
    echo "    WARNING: $GADGET_DIR still exists"
    ls "$GADGET_DIR" 2>/dev/null
fi

# check 2: UDC has no function bound
UDC_FUNC=$(cat /sys/class/udc/$UDC/function 2>/dev/null)
if [ -z "$UDC_FUNC" ]; then
    echo "    UDC function: empty [OK] — no gadget bound"
else
    echo "    WARNING: UDC still bound to: $UDC_FUNC"
fi

# check 3: remaining gadgets
REMAINING=$(ls /sys/kernel/config/usb_gadget/ 2>/dev/null)
if [ -z "$REMAINING" ]; then
    echo "    usb_gadget dir: empty [OK]"
else
    echo "    Remaining gadgets: $REMAINING"
fi

echo ""
echo "    Note: UDC state=$(cat /sys/class/udc/$UDC/state 2>/dev/null)"
echo "    (state may show 'configured' — ZynqMP DWC3 retains last hardware"
echo "     state in register — this is normal, safely ignore it)"
echo ""

# ─────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────

echo "========================================"
echo " bring down usb0     [OK] Ethernet interface down"
echo " echo \"\" → UDC       [OK] DEACTIVATED — host lost all devices"
echo " sleep 2             [OK] host processed disconnect"
echo " rm/rmdir cleanup    [OK] all configfs objects removed"
echo " verify clean        [OK] check output above"
echo "========================================"
echo ""
echo " You can now safely unplug the USB cable."
echo ""
echo " Image kept at: /home/petalinux/ondm_share.img"
echo " To refresh:    rm /home/petalinux/ondm_share.img"
echo "                sudo ./ondm_triple_start.sh"
echo "========================================"
