#!/bin/sh
# USB Gadget Ethernet — START
# Creates RNDIS gadget and brings up usb0 at 192.168.10.20/24

set -e

echo "=== Loading modules ==="
modprobe libcomposite
modprobe usb_f_rndis

echo "=== Mounting configfs ==="
mount -t configfs none /sys/kernel/config 2>/dev/null || true

echo "=== Building gadget ==="
cd /sys/kernel/config/usb_gadget/
mkdir -p g1
cd g1

echo "0x1d6b" > idVendor
echo "0x0104" > idProduct
echo "0x0200" > bcdUSB
echo "0x0100" > bcdDevice

mkdir -p strings/0x409
echo "0123456789abcdef"     > strings/0x409/serialnumber
echo "Xilinx ZCU102"        > strings/0x409/manufacturer
echo "USB Ethernet Gadget"  > strings/0x409/product

mkdir -p configs/c.1
echo 250 > configs/c.1/MaxPower
mkdir -p configs/c.1/strings/0x409
echo "RNDIS Config" > configs/c.1/strings/0x409/configuration

mkdir -p functions/rndis.usb0
ln -sf functions/rndis.usb0 configs/c.1/

echo "=== Binding to UDC ==="
echo "fe200000.usb" > UDC

echo "=== Bringing up network ==="
sleep 1
ip addr flush dev usb0 2>/dev/null || true
ip addr add 192.168.10.20/24 dev usb0
ip link set usb0 up

echo ""
echo "=== Gadget is UP ==="
ip addr show usb0
echo ""
echo "Board IP  : 192.168.10.20"
echo "Set host  : 192.168.10.x (e.g. 192.168.10.1)"
echo "UDC state : $(cat /sys/class/udc/fe200000.usb/state)"
echo "Now plug USB cable into host PC"
