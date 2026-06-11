#!/bin/sh
# serial_usb_start.sh
# Create a USB CDC ACM serial gadget (virtual COM port).
# Host sees a USB serial port. Board side: /dev/ttyGS0
#
# Usage: sudo ./serial_usb_start.sh
#
# What this script does:
#   modprobe modules      <- load ACM serial gadget drivers
#   mount configfs        <- open the gadget control interface
#   mkdir g_serial        <- create gadget object
#   set VID/PID/strings   <- describe the device to the host
#   mkdir configs/c.1     <- create USB configuration
#   mkdir acm.GS0         <- create CDC ACM serial function -> /dev/ttyGS0
#   ln function -> config <- include function in configuration
#   echo fe200000.usb>UDC <- ACTIVATE: host now sees a COM port
#   getty on ttyGS0       <- start login shell on the serial port
#
# After running: plug USB cable
#   Windows: new COMx port in Device Manager, open with PuTTY 115200 8N1
#   Linux:   /dev/ttyACM0 appears, open with: screen /dev/ttyACM0 115200
#
# Baud rate note: USB serial does not use a real baud rate (data travels
#   at USB 2.0 speed). Set 115200 8N1 in your terminal — it is the
#   conventional setting and is accepted by all terminal programs.
#
# When done: run serial_usb_stop.sh FIRST, then unplug cable

# ── modprobe modules ── load ACM serial gadget drivers ───────────
modprobe libcomposite
modprobe u_serial
modprobe usb_f_acm

# ── mount configfs ── open the gadget control interface ──────────
mount -t configfs none /sys/kernel/config 2>/dev/null

# ── mkdir g_serial ── create the gadget object ───────────────────
mkdir /sys/kernel/config/usb_gadget/g_serial

# ── set VID/PID ── tell the host what kind of device this is ─────
echo "0x1d6b" > /sys/kernel/config/usb_gadget/g_serial/idVendor
echo "0x0109" > /sys/kernel/config/usb_gadget/g_serial/idProduct
echo "0x0200" > /sys/kernel/config/usb_gadget/g_serial/bcdUSB
echo "0x0100" > /sys/kernel/config/usb_gadget/g_serial/bcdDevice

# ── set strings ── human-readable names shown in Device Manager ──
mkdir /sys/kernel/config/usb_gadget/g_serial/strings/0x409
echo "SERIAL001ZCU102"   > /sys/kernel/config/usb_gadget/g_serial/strings/0x409/serialnumber
echo "Xilinx ZCU102"     > /sys/kernel/config/usb_gadget/g_serial/strings/0x409/manufacturer
echo "ZCU102 USB Serial" > /sys/kernel/config/usb_gadget/g_serial/strings/0x409/product

# ── mkdir configs/c.1 ── create USB configuration ────────────────
mkdir /sys/kernel/config/usb_gadget/g_serial/configs/c.1
echo "250" > /sys/kernel/config/usb_gadget/g_serial/configs/c.1/MaxPower

mkdir /sys/kernel/config/usb_gadget/g_serial/configs/c.1/strings/0x409
echo "CDC ACM Serial" > /sys/kernel/config/usb_gadget/g_serial/configs/c.1/strings/0x409/configuration

# ── mkdir acm.GS0 ── create CDC ACM serial function ──────────────
# this creates /dev/ttyGS0 on the board — the serial device
mkdir /sys/kernel/config/usb_gadget/g_serial/functions/acm.GS0

# confirm /dev/ttyGS0 was created
ls -la /dev/ttyGS0

# ── ln function -> config ── include function in configuration ────
ln -sf /sys/kernel/config/usb_gadget/g_serial/functions/acm.GS0 \
       /sys/kernel/config/usb_gadget/g_serial/configs/c.1/

# ── echo fe200000.usb -> UDC ── ACTIVATE: host now sees a COM port
echo "fe200000.usb" > /sys/kernel/config/usb_gadget/g_serial/UDC



getty -L ttyGS0 115200 vt100 &

# ── summary ──────────────────────────────────────────────────────
echo ""
echo "modprobe modules      [OK] libcomposite + u_serial + usb_f_acm"
echo "mount configfs        [OK] gadget control interface ready"
echo "mkdir g_serial        [OK] gadget object created"
echo "set VID/PID/strings   [OK] VID=0x1d6b PID=0x0109"
echo "mkdir configs/c.1     [OK] USB configuration created"
echo "mkdir acm.GS0         [OK] CDC ACM function -> /dev/ttyGS0"
echo "ln function -> config [OK] function included in config"
echo "echo fe200000.usb>UDC [OK] ACTIVATED"
echo "getty on ttyGS0       [OK] login shell started on serial port"
echo ""
echo "Board serial device : /dev/ttyGS0"
echo "UDC state          : $(cat /sys/class/udc/fe200000.usb/state)"
echo "When done: sudo ./serial_usb_stop.sh  then unplug cable"

# start getty on ttyGS0
# -L       = local mode (no modem control signals)
# 115200   = baud rate (cosmetic for USB, actual speed is USB 2.0)
# vt100    = terminal type
# runs in foreground so you can see it started
# press Ctrl+C here to kill getty (also closes the PuTTY session)
echo "Starting login terminal on /dev/ttyGS0 ..."
echo "Open PuTTY: Serial -> COMx -> 115200 -> Open"
echo "To stop the terminal please write exit into new opened COMx you already opened for Linux bash terminal"
echo ""