#!/bin/sh
# ondm_usb_start.sh
# Share the extracted contents of /home/petalinux/ONDM2026.zip
# as a USB drive to the host PC.
# Host sees a 1GB USB flash drive containing all extracted files.
#
# Usage: sudo ./ondm_usb_start.sh
#
# What this script does:
#   check source file     <- verify ONDM2026.zip exists
#   create image          <- make a 1GB FAT32 disk image if not yet made
#   extract zip into image<- unzip ONDM2026.zip contents into the image
#   modprobe modules      <- load usb gadget drivers
#   mount configfs        <- open the gadget control interface
#   mkdir g_ondm          <- create gadget object
#   set VID/PID/strings   <- describe the device to the host
#   mkdir configs/c.1     <- create USB configuration
#   mkdir mass_storage.0  <- create the disk function
#   set ro=1 first        <- read-only: host can read but not modify
#   point lun at image    <- lun.0/file = ondm_share.img (the FAT32 image)
#   ln function -> config <- include function in configuration
#   echo fe200000.usb>UDC <- ACTIVATE: host now sees the drive
#
# Why not point directly at the .zip file?
#   USB mass storage requires a disk IMAGE with a real FAT32 filesystem.
#   A .zip file has no filesystem — host would say "disk needs formatting".
#   We create a 1GB FAT32 image, extract the zip INTO it, then share the
#   image as the USB drive. Host sees all files directly, no extraction needed.
#
# Image is kept after stop for reuse. To refresh with new zip contents:
#   rm /home/petalinux/ondm_share.img  then re-run this script.
#
# After running: plug USB cable -> host sees a 1GB USB drive with files
# When done:     run ondm_usb_stop.sh FIRST, then unplug cable

SOURCE_FILE="/home/petalinux/ONDM2026.zip"
IMAGE_FILE="/home/petalinux/ondm_share.img"
MOUNT_POINT="/tmp/ondm_mnt"

# ── check source file ── verify ONDM2026.zip exists ─────────────
ls -lh "$SOURCE_FILE"

# ── create image ── make 1GB FAT32 disk image if not yet made ────
# if image already exists it is reused without recreation
# to force recreation: rm /home/petalinux/ondm_share.img

if [ ! -f "$IMAGE_FILE" ]; then

    echo "Image not found — creating 1GB image at $IMAGE_FILE ..."

    # create a 1GB empty file filled with zeros
    # bs=1M count=1024 = 1024 x 1MB = 1GB
    dd if=/dev/zero of="$IMAGE_FILE" bs=1M count=1024

    # format the image as FAT32 with volume label ONDM2026
    # mkfs.vfat works directly on image files, no loop device needed
    mkfs.vfat -F 32 -n "ONDM2026" "$IMAGE_FILE"

    # mount the image to a temporary directory so we can write files into it
    mkdir -p "$MOUNT_POINT"
    mount -o loop "$IMAGE_FILE" "$MOUNT_POINT"

    # extract all contents of ONDM2026.zip directly into the image filesystem
    # host will see the extracted files, no zip extraction needed on host side
    unzip "$SOURCE_FILE" -d "$MOUNT_POINT/"

    # show what was extracted so we can verify
    ls -lh "$MOUNT_POINT/"

    # unmount the image before sharing via USB
    # image must NOT be mounted on Linux while shared via USB mass storage
    umount "$MOUNT_POINT"

    echo "Image created and contents extracted: $IMAGE_FILE"

else

    # image already exists from a previous run — reuse it as-is
    echo "Image already exists: $IMAGE_FILE"
    echo "Reusing existing image (delete it to refresh with new zip contents)"

fi

# ── modprobe modules ── load usb gadget drivers ──────────────────
modprobe libcomposite
modprobe usb_f_mass_storage

# ── mount configfs ── open the gadget control interface ──────────
mount -t configfs none /sys/kernel/config 2>/dev/null

# ── mkdir g_ondm ── create the gadget object ─────────────────────
mkdir /sys/kernel/config/usb_gadget/g_ondm

# ── set VID/PID ── tell the host what kind of device this is ─────
echo "0x1d6b" > /sys/kernel/config/usb_gadget/g_ondm/idVendor
echo "0x0108" > /sys/kernel/config/usb_gadget/g_ondm/idProduct
echo "0x0200" > /sys/kernel/config/usb_gadget/g_ondm/bcdUSB
echo "0x0100" > /sys/kernel/config/usb_gadget/g_ondm/bcdDevice

# ── set strings ── human-readable names shown in Device Manager ──
mkdir /sys/kernel/config/usb_gadget/g_ondm/strings/0x409
echo "ONDM2026ZCU102"      > /sys/kernel/config/usb_gadget/g_ondm/strings/0x409/serialnumber
echo "Xilinx ZCU102"       > /sys/kernel/config/usb_gadget/g_ondm/strings/0x409/manufacturer
echo "ONDM2026 File Share" > /sys/kernel/config/usb_gadget/g_ondm/strings/0x409/product

# ── mkdir configs/c.1 ── create USB configuration ────────────────
mkdir /sys/kernel/config/usb_gadget/g_ondm/configs/c.1
echo "250" > /sys/kernel/config/usb_gadget/g_ondm/configs/c.1/MaxPower

mkdir /sys/kernel/config/usb_gadget/g_ondm/configs/c.1/strings/0x409
echo "Mass Storage" > /sys/kernel/config/usb_gadget/g_ondm/configs/c.1/strings/0x409/configuration

# ── mkdir mass_storage.0 ── create the disk function object ──────
mkdir /sys/kernel/config/usb_gadget/g_ondm/functions/mass_storage.0

# ── set ro=1 BEFORE file ── read-only: host cannot modify image ──
# ro=1 means host can read and copy files but cannot write or delete
# this protects the image from accidental changes by the host
# ro/cdrom/removable MUST be set BEFORE writing lun.0/file
# once file is written the kernel locks the device and ro becomes read-only
echo "1" > /sys/kernel/config/usb_gadget/g_ondm/functions/mass_storage.0/lun.0/ro
echo "0" > /sys/kernel/config/usb_gadget/g_ondm/functions/mass_storage.0/lun.0/cdrom
echo "1" > /sys/kernel/config/usb_gadget/g_ondm/functions/mass_storage.0/lun.0/removable

# ── point lun at image ── lun.0/file = the 1GB FAT32 image ───────
# the image contains all extracted files from ONDM2026.zip
echo "$IMAGE_FILE" > /sys/kernel/config/usb_gadget/g_ondm/functions/mass_storage.0/lun.0/file

# ── ln function -> config ── include function in configuration ────
ln -sf /sys/kernel/config/usb_gadget/g_ondm/functions/mass_storage.0 \
       /sys/kernel/config/usb_gadget/g_ondm/configs/c.1/

# ── echo fe200000.usb -> UDC ── ACTIVATE: host now sees the drive ─
echo "fe200000.usb" > /sys/kernel/config/usb_gadget/g_ondm/UDC

# ── summary ──────────────────────────────────────────────────────
echo ""
echo "check source file     [OK] $SOURCE_FILE exists"
echo "create image          [OK] $IMAGE_FILE (1GB FAT32)"
echo "extract zip into image[OK] contents of ONDM2026.zip extracted"
echo "modprobe modules      [OK] libcomposite + usb_f_mass_storage"
echo "mount configfs        [OK] gadget control interface ready"
echo "mkdir g_ondm          [OK] gadget object created"
echo "set VID/PID/strings   [OK] VID=0x1d6b PID=0x0108"
echo "mkdir configs/c.1     [OK] USB configuration created"
echo "mkdir mass_storage.0  [OK] disk function created"
echo "set ro=1 first        [OK] read-only — host cannot modify"
echo "point lun at image    [OK] lun.0/file = $IMAGE_FILE"
echo "ln function -> config [OK] function included in config"
echo "echo fe200000.usb>UDC [OK] ACTIVATED"
echo ""
echo "Now plug USB cable -> host sees a 1GB USB drive labelled ONDM2026"
echo "Drive contains the extracted files from ONDM2026.zip"
echo "Host can read and copy files — cannot write (read-only)"
echo ""
echo "When done: sudo ./ondm_usb_stop.sh  then unplug cable"
