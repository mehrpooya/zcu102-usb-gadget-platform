#!/bin/sh
# USB Gadget Ethernet — STOP
# Tears down the gadget cleanly.
# IMPORTANT: Run this BEFORE unplugging the USB cable.

echo "=== Bringing down network interface ==="
ip link set usb0 down 2>/dev/null || true
ip addr flush dev usb0 2>/dev/null || true

echo "=== Unbinding from UDC ==="
echo "" > /sys/kernel/config/usb_gadget/g1/UDC 2>/dev/null || true
sleep 1

echo "=== Removing gadget configuration ==="
# Remove function symlink from config
rm -f /sys/kernel/config/usb_gadget/g1/configs/c.1/rndis.usb0

# Remove config strings
rmdir /sys/kernel/config/usb_gadget/g1/configs/c.1/strings/0x409 2>/dev/null || true

# Remove config
rmdir /sys/kernel/config/usb_gadget/g1/configs/c.1 2>/dev/null || true

# Remove function
rmdir /sys/kernel/config/usb_gadget/g1/functions/rndis.usb0 2>/dev/null || true

# Remove gadget strings
rmdir /sys/kernel/config/usb_gadget/g1/strings/0x409 2>/dev/null || true

# Remove gadget
rmdir /sys/kernel/config/usb_gadget/g1 2>/dev/null || true

echo ""
echo "=== Gadget removed ==="
echo "UDC state: $(cat /sys/class/udc/fe200000.usb/state 2>/dev/null || echo 'unbound')"
echo ""
echo "You can now safely unplug the USB cable."
