#!/bin/sh
# serial_raw_receive.sh
# Receive raw characters sent from the host PuTTY window.
# Everything typed in PuTTY appears on the board terminal.
#
# Usage: sudo ./serial_raw_receive.sh
# Stop:  press Ctrl+C
#
# Run serial_usb_start.sh first, then plug cable, then run this.

# print everything the host sends to /dev/ttyGS0
# runs in foreground — press Ctrl+C to stop
echo "Press Ctrl+C here to stop the terminal"
echo ""
cat /dev/ttyGS0
