#!/bin/sh
# serial_raw_send.sh
# Send a message from the board to the host PuTTY window.
#
# Usage: sudo ./serial_raw_send.sh "your message here"
# Example: sudo ./serial_raw_send.sh "hello from ZCU102"
#
# Run serial_usb_start.sh first, then plug cable, then run this.
# The message appears in the PuTTY window on the host.

# check a message was provided
if [ -z "$1" ]; then
    echo "Usage: $0 \"your message here\""
    echo "Example: $0 \"hello from ZCU102\""
    exit 1
fi

# send the message to the host PuTTY window
# \n adds a newline so the message appears on its own line in PuTTY
printf "%s\n" "$1" > /dev/ttyGS0

echo "Sent to host: $1"
