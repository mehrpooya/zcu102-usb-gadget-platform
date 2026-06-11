#!/bin/sh
# triple_usb_stop.sh
# Cleanly stop the triple USB composite gadget.
# Run BEFORE unplugging the USB cable.
# Usage: sudo ./triple_usb_stop.sh

GADGET_NAME="g_triple"
UDC="fe200000.usb"
GADGET_DIR="/sys/kernel/config/usb_gadget/$GADGET_NAME"

echo "========================================"
echo " Triple USB Gadget — STOP"
echo "========================================"
echo ""

# ─────────────────────────────────────────────
# SERIAL: RELEASE ttyGS0 BEFORE ACM RMDIR
# Kill all processes holding ttyGS0 open.
# Without this, rmdir acm.GS0 blocks forever.
# ─────────────────────────────────────────────
echo "--- Releasing serial port ---"
# kill any ping/process running inside the serial session
fuser -k /dev/ttyGS0                                         2>/dev/null
# kill getty on ttyGS0
kill $(ps | grep "getty.*ttyGS0" | grep -v grep | awk '{print $1}') 2>/dev/null
killall -9 getty                                             2>/dev/null
sleep 1
echo "    ttyGS0 released [OK]"
echo ""

# ─────────────────────────────────────────────
# ETHERNET: BRING DOWN usb0 BEFORE RNDIS RMDIR
# ─────────────────────────────────────────────
echo "--- Bringing down Ethernet interface ---"
ip link set usb0 down       2>/dev/null
ip addr flush dev usb0      2>/dev/null
echo "    usb0 down [OK]"
echo ""

# ─────────────────────────────────────────────
# MASS STORAGE: CLEAR LUN FILE BEFORE RMDIR
# Releasing the backing device prevents rmdir from blocking.
# ─────────────────────────────────────────────
echo "--- Releasing NVMe from mass storage ---"
echo "" > "$GADGET_DIR/functions/mass_storage.0/lun.0/file" 2>/dev/null
echo "    lun.0/file cleared [OK]"
echo ""

# ─────────────────────────────────────────────
# DEACTIVATE: UNBIND FROM UDC
# ─────────────────────────────────────────────
echo "--- Unbinding from UDC ---"
bash -c "echo \"\" > $GADGET_DIR/UDC"                       2>/dev/null
sleep 2
UDC_VAL=$(cat "$GADGET_DIR/UDC" 2>/dev/null)
[ -z "$UDC_VAL" ] && echo "    UDC unbound [OK]" \
                  || echo "    WARNING: UDC still shows $UDC_VAL"
echo ""

# ─────────────────────────────────────────────
# CLEANUP: REMOVE CONFIGFS OBJECTS
# 2>/dev/null so absent entries do not cause errors
# ─────────────────────────────────────────────
echo "--- Removing configfs objects ---"

rm -f  "$GADGET_DIR/configs/c.1/rndis.usb0"        2>/dev/null
rm -f  "$GADGET_DIR/configs/c.1/mass_storage.0"    2>/dev/null
rm -f  "$GADGET_DIR/configs/c.1/acm.GS0"           2>/dev/null
echo "    symlinks removed"

rmdir  "$GADGET_DIR/configs/c.1/strings/0x409"     2>/dev/null
echo "    config strings removed"

rmdir  "$GADGET_DIR/configs/c.1"                   2>/dev/null
echo "    config c.1 removed"

rmdir  "$GADGET_DIR/functions/rndis.usb0"          2>/dev/null
echo "    rndis.usb0 removed"

rmdir  "$GADGET_DIR/functions/mass_storage.0"      2>/dev/null
echo "    mass_storage.0 removed"

rmdir  "$GADGET_DIR/functions/acm.GS0"             2>/dev/null
echo "    acm.GS0 removed"

rmdir  "$GADGET_DIR/strings/0x409"                 2>/dev/null
echo "    gadget strings removed"

rmdir  "$GADGET_DIR"                               2>/dev/null
echo "    gadget $GADGET_NAME removed"
echo ""

# ─────────────────────────────────────────────
# VERIFY
# ─────────────────────────────────────────────
echo "--- Verifying ---"
[ ! -d "$GADGET_DIR" ]       && echo "    configfs : clean [OK]"     || echo "    WARNING: $GADGET_DIR still exists"
UDC_FUNC=$(cat /sys/class/udc/$UDC/function 2>/dev/null)
[ -z "$UDC_FUNC" ]           && echo "    UDC func : empty [OK]"     || echo "    WARNING: still bound to $UDC_FUNC"
REMAINING=$(ls /sys/kernel/config/usb_gadget/ 2>/dev/null)
[ -z "$REMAINING" ]          && echo "    gadgets  : none [OK]"      || echo "    Remaining: $REMAINING"
echo ""

echo "========================================"
echo " All resources released and cleaned."
echo " UDC state: $(cat /sys/class/udc/$UDC/state 2>/dev/null)"
echo " (state may show 'configured' — normal on ZynqMP)"
echo "========================================"
echo ""
echo " You can now safely unplug the USB cable."
