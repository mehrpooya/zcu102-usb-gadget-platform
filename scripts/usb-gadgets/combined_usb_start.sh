#!/bin/sh
# combined_usb_start.sh
# Start BOTH Ethernet (RNDIS) AND NVMe mass storage over one USB cable.
# One gadget, one UDC bind, two functions in one configuration.
#
# Usage: sudo ./combined_usb_start.sh
#
# What this script does:
#   modprobe modules        <- load rndis + mass_storage drivers
#   unmount nvme0n1p2       <- free NVMe partition from Linux
#   mount configfs          <- open the gadget control interface
#   mkdir g_combined        <- create ONE gadget object
#   set VID/PID/strings     <- describe the composite device to host
#   mkdir configs/c.1       <- create ONE USB configuration
#   mkdir rndis.usb0        <- create Ethernet function
#   mkdir mass_storage.0    <- create NVMe disk function
#   set ro/removable first  <- must be before writing file path
#   echo /dev/nvme0n1p2     <- point mass storage at the real NVMe
#   ln rndis -> config      <- include Ethernet in config (FIRST)
#   ln mass_storage->config <- include NVMe in config (SECOND)
#   echo fe200000.usb > UDC <- ACTIVATE ONCE: host sees both
#   ip addr add / ip up     <- bring up the Ethernet interface
#
# After running: plug USB cable -> host sees NIC + 931.5GB drive
# When done:     run combined_usb_stop.sh FIRST, then unplug cable
#
# Note: RNDIS must be linked into config BEFORE mass_storage.
#       Windows looks for RNDIS at interface 0 — order matters.

# ── modprobe modules ── load rndis + mass_storage drivers ────────
modprobe libcomposite
modprobe usb_f_rndis
modprobe usb_f_mass_storage

# ── unmount nvme0n1p2 ── free NVMe partition from Linux ──────────
# mass storage requires exclusive block device access
# 2>/dev/null silences "not mounted" errors if already unmounted
umount /mnt/nvme                          2>/dev/null
umount "/run/media/New Volume-nvme0n1p2"  2>/dev/null

# confirm nothing is mounted on nvme0n1p2 (should print nothing)
grep nvme0n1p2 /proc/mounts

# ── mount configfs ── open the gadget control interface ──────────
mount -t configfs none /sys/kernel/config 2>/dev/null

# ── mkdir g_combined ── create ONE gadget object ─────────────────
mkdir /sys/kernel/config/usb_gadget/g_combined

# ── set VID/PID ── composite device descriptor ───────────────────
# bDeviceClass 0xEF + subclass 0x02 + protocol 0x01 tells the host
# this is a composite device using Interface Association Descriptors
# so it correctly separates the NIC and disk functions
echo "0x1d6b"  > /sys/kernel/config/usb_gadget/g_combined/idVendor
echo "0x0104"  > /sys/kernel/config/usb_gadget/g_combined/idProduct
echo "0x0200"  > /sys/kernel/config/usb_gadget/g_combined/bcdUSB
echo "0x0100"  > /sys/kernel/config/usb_gadget/g_combined/bcdDevice
echo "0xEF"    > /sys/kernel/config/usb_gadget/g_combined/bDeviceClass
echo "0x02"    > /sys/kernel/config/usb_gadget/g_combined/bDeviceSubClass
echo "0x01"    > /sys/kernel/config/usb_gadget/g_combined/bDeviceProtocol

# ── set strings ── names shown in Device Manager ─────────────────
mkdir /sys/kernel/config/usb_gadget/g_combined/strings/0x409
echo "ZCU102COMBO01"          > /sys/kernel/config/usb_gadget/g_combined/strings/0x409/serialnumber
echo "Xilinx ZCU102"          > /sys/kernel/config/usb_gadget/g_combined/strings/0x409/manufacturer
echo "ZCU102 Ethernet+NVMe"   > /sys/kernel/config/usb_gadget/g_combined/strings/0x409/product

# ── mkdir configs/c.1 ── create ONE USB configuration ────────────
mkdir /sys/kernel/config/usb_gadget/g_combined/configs/c.1
echo "500" > /sys/kernel/config/usb_gadget/g_combined/configs/c.1/MaxPower

mkdir /sys/kernel/config/usb_gadget/g_combined/configs/c.1/strings/0x409
echo "RNDIS+NVMe" > /sys/kernel/config/usb_gadget/g_combined/configs/c.1/strings/0x409/configuration

# ── mkdir rndis.usb0 ── create Ethernet function ─────────────────
mkdir /sys/kernel/config/usb_gadget/g_combined/functions/rndis.usb0

# ── mkdir mass_storage.0 ── create NVMe disk function ────────────
mkdir /sys/kernel/config/usb_gadget/g_combined/functions/mass_storage.0

# ── set ro/removable BEFORE file ── flags must come first ────────
# once file is written the kernel locks the device and ro becomes read-only
echo "0" > /sys/kernel/config/usb_gadget/g_combined/functions/mass_storage.0/lun.0/ro
echo "0" > /sys/kernel/config/usb_gadget/g_combined/functions/mass_storage.0/lun.0/cdrom
echo "1" > /sys/kernel/config/usb_gadget/g_combined/functions/mass_storage.0/lun.0/removable

# ── echo /dev/nvme0n1p2 -> file ── point NVMe function at device ─
echo "/dev/nvme0n1p2" > /sys/kernel/config/usb_gadget/g_combined/functions/mass_storage.0/lun.0/file

# ── ln rndis -> config ── RNDIS MUST be linked FIRST ─────────────
# Windows assigns drivers by interface number: RNDIS must be at 0
ln -sf /sys/kernel/config/usb_gadget/g_combined/functions/rndis.usb0 \
       /sys/kernel/config/usb_gadget/g_combined/configs/c.1/

# ── ln mass_storage -> config ── NVMe linked SECOND ──────────────
ln -sf /sys/kernel/config/usb_gadget/g_combined/functions/mass_storage.0 \
       /sys/kernel/config/usb_gadget/g_combined/configs/c.1/

# ── echo fe200000.usb -> UDC ── ACTIVATE ONCE ────────────────────
# one bind activates both functions simultaneously
echo "fe200000.usb" > /sys/kernel/config/usb_gadget/g_combined/UDC

# ── ip addr / ip link ── bring up the Ethernet interface ─────────
sleep 1
ip addr flush dev usb0                2>/dev/null
ip addr add 192.168.10.20/24 dev usb0
ip link set usb0 up

# ── summary ──────────────────────────────────────────────────────
echo ""
echo "modprobe modules        [OK] libcomposite + usb_f_rndis + usb_f_mass_storage"
echo "unmount nvme0n1p2       [OK] partition freed from Linux"
echo "mount configfs          [OK] gadget control interface ready"
echo "mkdir g_combined        [OK] one gadget object created"
echo "set VID/PID/strings     [OK] VID=0x1d6b PID=0x0104 composite"
echo "mkdir configs/c.1       [OK] one USB configuration"
echo "mkdir rndis.usb0        [OK] Ethernet function created"
echo "mkdir mass_storage.0    [OK] NVMe disk function created"
echo "set ro/removable first  [OK] flags set before file path"
echo "echo /dev/nvme0n1p2     [OK] NVMe partition assigned"
echo "ln rndis -> config      [OK] Ethernet linked first (interface 0)"
echo "ln mass_storage->config [OK] NVMe linked second (interface 2)"
echo "echo fe200000.usb > UDC [OK] ACTIVATED — both functions live"
echo "ip addr / ip link       [OK] usb0 up at 192.168.10.20/24"
echo ""
echo "Now plug USB cable -> host sees:"
echo "  Windows: NIC (install RNDIS driver) + 931.5GB drive"
echo "  Linux:   usb0/enx.. network + /dev/sdX block device"
echo ""
echo "Set host IP to 192.168.10.1/24"
echo "When done: sudo ./combined_usb_stop.sh  then unplug cable"
