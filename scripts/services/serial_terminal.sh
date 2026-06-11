#!/bin/sh
# serial_terminal.sh
# Start a full login terminal on the USB serial port.
# Host PuTTY gets a ZCU102 login prompt — type commands like SSH.
#
# Usage: sudo ./serial_terminal.sh
#
# Run serial_usb_start.sh first, then plug cable, then run this.
#
# On PuTTY (Windows):
#   Connection type: Serial
#   Serial line:     COMx  (check Device Manager for the port number)
#   Speed:           115200
#   Click Open -> you see: zcu102pcie login:
#
# To stop the terminal session:
#   Type "exit" in PuTTY to end the shell session
#   OR run: kill $(ps | grep "getty.*ttyGS0" | grep -v grep | awk '{print $1}')

# start getty on ttyGS0
# -L       = local mode (no modem control signals)
# 115200   = baud rate (cosmetic for USB, actual speed is USB 2.0)
# vt100    = terminal type
# runs in foreground so you can see it started
# press Ctrl+C here to kill getty (also closes the PuTTY session)
echo "Starting login terminal on /dev/ttyGS0 ..."
echo "Open PuTTY: Serial -> COMx -> 115200 -> Open"
echo "Press Ctrl+C here to stop the terminal if it doesn't work please write exit into new opened COMx you already opened for Linux bash terminal"
echo ""

getty -L ttyGS0 115200 vt100
