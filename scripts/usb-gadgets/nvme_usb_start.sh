#!/bin/sh
# nvme_usb_start.sh
# Expose /dev/nvme0n1p2 to the host PC as a USB mass storage device.
#
# Usage: sudo ./nvme_usb_start.sh
#
# What this script does:
#   modprobe check          <- verify required modules are available
#   unmount nvme0n1p2       <- free the partition from Linux
#   modprobe modules        <- load usb gadget drivers
#   mount configfs          <- open the gadget control interface
#   mkdir g_nvme            <- create gadget object
#   set VID/PID/strings     <- describe the device to the host
#   mkdir configs/c.1       <- create USB configuration
#   mkdir mass_storage.0    <- create the disk function
#   set ro/removable first  <- must be before writing file path
#   echo /dev/nvme0n1p2     <- point it at the real NVMe partition
#   ln -sf function->config <- include function in configuration
#   echo fe200000.usb > UDC <- ACTIVATE: host now sees the drive
#
# After running: plug USB cable -> host sees a 931.5GB drive
# When done:     run nvme_usb_stop.sh FIRST, then unplug cable

# ── modprobe check ── verify required modules are available ─────
modprobe libcomposite
modprobe usb_f_mass_storage

# ── unmount nvme0n1p2 ── free the partition from Linux ──────────
# both known mount points, 2>/dev/null silences "not mounted" errors
umount /mnt/nvme                          2>/dev/null
umount "/run/media/New Volume-nvme0n1p2"  2>/dev/null

# confirm nothing is mounted (should print nothing)
grep nvme0n1p2 /proc/mounts

# ── mount configfs ── open the gadget control interface ─────────
mount -t configfs none /sys/kernel/config 2>/dev/null

# ── mkdir g_nvme ── create the gadget object ────────────────────
mkdir /sys/kernel/config/usb_gadget/g_nvme

# ── set VID/PID ── tell the host what kind of device this is ────
echo "0x1d6b" > /sys/kernel/config/usb_gadget/g_nvme/idVendor
echo "0x0107" > /sys/kernel/config/usb_gadget/g_nvme/idProduct
echo "0x0200" > /sys/kernel/config/usb_gadget/g_nvme/bcdUSB
echo "0x0100" > /sys/kernel/config/usb_gadget/g_nvme/bcdDevice

# ── set strings ── human-readable names shown in Device Manager ─
mkdir /sys/kernel/config/usb_gadget/g_nvme/strings/0x409
echo "NVME001ZCU102"       > /sys/kernel/config/usb_gadget/g_nvme/strings/0x409/serialnumber
echo "Xilinx ZCU102"       > /sys/kernel/config/usb_gadget/g_nvme/strings/0x409/manufacturer
echo "ZCU102 NVMe Storage" > /sys/kernel/config/usb_gadget/g_nvme/strings/0x409/product

# ── mkdir configs/c.1 ── create USB configuration ───────────────
mkdir /sys/kernel/config/usb_gadget/g_nvme/configs/c.1
echo "500" > /sys/kernel/config/usb_gadget/g_nvme/configs/c.1/MaxPower

mkdir /sys/kernel/config/usb_gadget/g_nvme/configs/c.1/strings/0x409
echo "Mass Storage" > /sys/kernel/config/usb_gadget/g_nvme/configs/c.1/strings/0x409/configuration

# ── mkdir mass_storage.0 ── create the disk function object ─────
mkdir /sys/kernel/config/usb_gadget/g_nvme/functions/mass_storage.0

# ── set ro/removable BEFORE file ── flags must come first ───────
# once file is written the kernel locks the device and ro becomes read-only
echo "0" > /sys/kernel/config/usb_gadget/g_nvme/functions/mass_storage.0/lun.0/ro
echo "0" > /sys/kernel/config/usb_gadget/g_nvme/functions/mass_storage.0/lun.0/cdrom
echo "1" > /sys/kernel/config/usb_gadget/g_nvme/functions/mass_storage.0/lun.0/removable

# ── echo /dev/nvme0n1p2 -> file ── point it at the real NVMe ────
echo "/dev/nvme0n1p2" > /sys/kernel/config/usb_gadget/g_nvme/functions/mass_storage.0/lun.0/file

# ── ln function -> config ── include function in configuration ───
ln -sf /sys/kernel/config/usb_gadget/g_nvme/functions/mass_storage.0 \
       /sys/kernel/config/usb_gadget/g_nvme/configs/c.1/

# ── echo fe200000.usb -> UDC ── ACTIVATE: host now sees the drive
echo "fe200000.usb" > /sys/kernel/config/usb_gadget/g_nvme/UDC

# ── summary ─────────────────────────────────────────────────────
echo ""
echo "modprobe check          [OK] modules loaded"
echo "unmount nvme0n1p2       [OK] partition freed from Linux"
echo "modprobe modules        [OK] libcomposite + usb_f_mass_storage"
echo "mount configfs          [OK] gadget control interface ready"
echo "mkdir g_nvme            [OK] gadget object created"
echo "set VID/PID/strings     [OK] VID=0x1d6b PID=0x0107"
echo "mkdir configs/c.1       [OK] USB configuration created"
echo "mkdir mass_storage.0    [OK] disk function created"
echo "set ro/removable first  [OK] flags set before file path"
echo "echo /dev/nvme0n1p2     [OK] NVMe partition assigned"
echo "ln function -> config   [OK] function included in config"
echo "echo fe200000.usb > UDC [OK] ACTIVATED"
echo ""
echo "Now plug USB cable -> host sees a 931.5GB drive"
echo "When done: sudo ./nvme_usb_stop.sh  then unplug cable"