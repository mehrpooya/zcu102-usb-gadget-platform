#!/bin/sh
# USB Gadget Ethernet — CHANGE IP
# Usage: ./usb_change_ip.sh <new_ip> <prefix_length>
# Example: ./usb_change_ip.sh 10.10.70.1 24

NEW_IP=$1
PREFIX=$2

if [ -z "$NEW_IP" ] || [ -z "$PREFIX" ]; then
    echo "Usage: $0 <ip_address> <prefix_length>"
    echo "Example: $0 10.10.70.1 24"
    exit 1
fi

echo "=== Changing usb0 IP address ==="
echo "Old configuration:"
ip addr show usb0

ip addr flush dev usb0
ip addr add "${NEW_IP}/${PREFIX}" dev usb0
ip link set usb0 up

echo ""
echo "New configuration:"
ip addr show usb0
echo ""
echo "New IP: ${NEW_IP}/${PREFIX}"
