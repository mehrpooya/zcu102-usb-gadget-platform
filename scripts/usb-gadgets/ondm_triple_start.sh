#!/bin/sh
# ondm_triple_start.sh
# One USB cable → host sees THREE devices simultaneously:
#   1. RNDIS Ethernet  → usb0 at 192.168.10.20/24  (road only, nothing running)
#   2. ONDM File Share → 1GB FAT32 image with ONDM2026.zip extracted (read-only)
#   3. CDC ACM Serial  → /dev/ttyGS0               (road only, no getty)
#
# Usage: sudo ./ondm_triple_start.sh
#
# What this script does:
#   create image         <- build 1GB FAT32 image with ONDM2026.zip contents (first run only)
#   load modules         <- libcomposite + rndis + mass_storage + acm
#   mount configfs       <- open the gadget control interface
#   mkdir g_ondm_triple  <- create ONE composite gadget
#   set VID/PID/strings  <- describe composite device to host
#   mkdir configs/c.1    <- create ONE USB configuration
#   FUNCTION 1: RNDIS    <- Ethernet function (road only)
#   FUNCTION 2: ONDM     <- File share from 1GB FAT32 image (read-only)
#   FUNCTION 3: ACM      <- Serial function (road only)
#   link all → config    <- RNDIS first (Windows needs it at interface 0)
#   echo fe200000.usb>UDC<- ACTIVATE: host now sees all three
#   ip addr usb0         <- bring up 192.168.10.20/24 (road only)
#
# Ethernet and Serial are roads — nothing runs over them here.
# Use other scripts over them after this script finishes.
#
# After running: plug USB cable → host sees NIC + drive + COM port
# When done:     run ondm_triple_stop.sh FIRST, then unplug cable

SOURCE_ZIP="/home/petalinux/ONDM2026.zip"
IMAGE_FILE="/home/petalinux/ondm_share.img"
MOUNT_POINT="/tmp/ondm_mnt"
IMAGE_SIZE_MB=1024
GADGET_NAME="g_ondm_triple"
UDC="fe200000.usb"
GADGET_DIR="/sys/kernel/config/usb_gadget/$GADGET_NAME"

echo "========================================"
echo " ONDM Triple USB Gadget — START"
echo " Ethernet + ONDM File Share + Serial"
echo "========================================"
echo ""

# ─────────────────────────────────────────────
# PREP: CREATE ONDM DISK IMAGE
# First run: creates 1GB FAT32 image and extracts ONDM2026.zip into it.
# Later runs: reuses existing image (fast, no rebuild).
# To refresh image: rm /home/petalinux/ondm_share.img then re-run.
# ─────────────────────────────────────────────

echo "--- Preparing ONDM disk image ---"

if [ ! -f "$IMAGE_FILE" ]; then

    echo "    Image not found — creating ${IMAGE_SIZE_MB}MB image..."

    # verify source zip exists before starting
    ls -lh "$SOURCE_ZIP" || { echo "ERROR: $SOURCE_ZIP not found"; exit 1; }

    # create 1GB empty file filled with zeros
    dd if=/dev/zero of="$IMAGE_FILE" bs=1M count=$IMAGE_SIZE_MB

    # format as FAT32 with volume label ONDM2026
    mkfs.vfat -F 32 -n "ONDM2026" "$IMAGE_FILE"

    # mount the image so we can copy files into it
    mkdir -p "$MOUNT_POINT"
    mount -o loop "$IMAGE_FILE" "$MOUNT_POINT"

    # extract ONDM2026.zip contents into the image
    # host sees extracted files directly — no unzipping needed on host side
    unzip "$SOURCE_ZIP" -d "$MOUNT_POINT/"

    # confirm what was extracted
    ls -lh "$MOUNT_POINT/"

    # unmount — image must NOT be loop-mounted when shared via USB
    umount "$MOUNT_POINT"

    echo "    Image created and zip extracted [OK]"
    echo "    File: $IMAGE_FILE"

else

    echo "    Image already exists — reusing [OK]"
    echo "    File: $IMAGE_FILE"
    echo "    (to refresh: rm $IMAGE_FILE and re-run)"

fi
echo ""

# ─────────────────────────────────────────────
# LOAD MODULES
# ─────────────────────────────────────────────

echo "--- Loading modules ---"

# composite gadget framework — required for all multi-function gadgets
modprobe libcomposite

# RNDIS Ethernet function driver
modprobe usb_f_rndis

# mass storage function driver
modprobe usb_f_mass_storage

# CDC ACM serial function driver + underlying serial layer
modprobe u_serial
modprobe usb_f_acm

echo "    libcomposite       [OK]"
echo "    usb_f_rndis        [OK]"
echo "    usb_f_mass_storage [OK]"
echo "    u_serial           [OK]"
echo "    usb_f_acm          [OK]"
echo ""

# ─────────────────────────────────────────────
# MOUNT CONFIGFS
# ─────────────────────────────────────────────

echo "--- Mounting configfs ---"

# configfs is the gadget control interface — gadget = directories and files
mount -t configfs none /sys/kernel/config 2>/dev/null

echo "    /sys/kernel/config ready [OK]"
echo ""

# ─────────────────────────────────────────────
# CREATE GADGET OBJECT
# ─────────────────────────────────────────────

echo "--- Creating gadget: $GADGET_NAME ---"

mkdir "$GADGET_DIR"

# bDeviceClass 0xEF + bDeviceSubClass 0x02 + bDeviceProtocol 0x01
# tells Windows this is a composite device using Interface Association Descriptors
# without these Windows cannot correctly split it into three separate devices
echo "0x1d6b"  > "$GADGET_DIR/idVendor"           # Linux Foundation
echo "0x0104"  > "$GADGET_DIR/idProduct"           # Multifunction Composite
echo "0x0200"  > "$GADGET_DIR/bcdUSB"              # USB 2.0
echo "0x0100"  > "$GADGET_DIR/bcdDevice"           # device version 1.0
echo "0xEF"    > "$GADGET_DIR/bDeviceClass"        # Miscellaneous Device
echo "0x02"    > "$GADGET_DIR/bDeviceSubClass"     # Common Class
echo "0x01"    > "$GADGET_DIR/bDeviceProtocol"     # Interface Association

# human-readable strings shown in Device Manager / dmesg
mkdir -p "$GADGET_DIR/strings/0x409"
echo "ONDMTRIPLE001"                 > "$GADGET_DIR/strings/0x409/serialnumber"
echo "Xilinx ZCU102"                 > "$GADGET_DIR/strings/0x409/manufacturer"
echo "ZCU102 Ethernet+ONDM+Serial"   > "$GADGET_DIR/strings/0x409/product"

echo "    VID=0x1d6b PID=0x0104 composite IAD [OK]"
echo ""

# ─────────────────────────────────────────────
# CREATE USB CONFIGURATION
# ─────────────────────────────────────────────

echo "--- Creating USB configuration c.1 ---"

mkdir -p "$GADGET_DIR/configs/c.1"
echo "500" > "$GADGET_DIR/configs/c.1/MaxPower"    # 500mA for three functions

mkdir -p "$GADGET_DIR/configs/c.1/strings/0x409"
echo "RNDIS+ONDM+ACM" > "$GADGET_DIR/configs/c.1/strings/0x409/configuration"

echo "    config c.1 MaxPower=500mA [OK]"
echo ""

# ─────────────────────────────────────────────
# FUNCTION 1: RNDIS ETHERNET  (road only)
# Creates the Ethernet function object.
# No server / no HTTP / no Samba is started here.
# Use this interface with other scripts after this one finishes.
# ─────────────────────────────────────────────

echo "--- Function 1: RNDIS Ethernet (road only) ---"

mkdir -p "$GADGET_DIR/functions/rndis.usb0"

echo "    rndis.usb0 created [OK]"
echo "    board MAC : $(cat $GADGET_DIR/functions/rndis.usb0/dev_addr 2>/dev/null)"
echo "    host MAC  : $(cat $GADGET_DIR/functions/rndis.usb0/host_addr 2>/dev/null)"
echo ""

# ─────────────────────────────────────────────
# FUNCTION 2: ONDM FILE SHARE (mass storage, read-only)
# Exposes the 1GB FAT32 image as a USB flash drive.
# Host sees the extracted ONDM2026.zip contents directly.
# ro=1 so host can read and copy files but cannot write or delete.
# ─────────────────────────────────────────────

echo "--- Function 2: ONDM File Share (mass storage, read-only) ---"

mkdir -p "$GADGET_DIR/functions/mass_storage.0"

# CRITICAL ORDER: set ro/cdrom/removable BEFORE writing file path
# once file is written the kernel locks the device and ro cannot be changed
echo "1" > "$GADGET_DIR/functions/mass_storage.0/lun.0/ro"         # read-only
echo "0" > "$GADGET_DIR/functions/mass_storage.0/lun.0/cdrom"      # hard disk
echo "1" > "$GADGET_DIR/functions/mass_storage.0/lun.0/removable"  # removable

# write the image file path — this activates the backing store
echo "$IMAGE_FILE" > "$GADGET_DIR/functions/mass_storage.0/lun.0/file"

echo "    mass_storage.0 created [OK]"
echo "    backing file : $IMAGE_FILE"
echo "    ro           : $(cat $GADGET_DIR/functions/mass_storage.0/lun.0/ro) (1=read-only)"
echo ""

# ─────────────────────────────────────────────
# FUNCTION 3: CDC ACM SERIAL  (road only)
# Creates the serial function and /dev/ttyGS0 on the board.
# No getty / no terminal is started here.
# Use /dev/ttyGS0 with your own scripts after this one finishes.
# ─────────────────────────────────────────────

echo "--- Function 3: CDC ACM Serial (road only) ---"

# creating this directory creates /dev/ttyGS0 on the board side
mkdir -p "$GADGET_DIR/functions/acm.GS0"

ls -la /dev/ttyGS0 2>/dev/null \
    && echo "    /dev/ttyGS0 created [OK]" \
    || echo "    WARNING: /dev/ttyGS0 not found yet (normal — appears after UDC bind)"
echo ""

# ─────────────────────────────────────────────
# LINK ALL FUNCTIONS → CONFIGURATION
# ORDER IS CRITICAL: RNDIS must be first
# Windows assigns interface numbers sequentially:
#   interface 0 → RNDIS (Windows expects this for driver matching)
#   interface 2 → mass storage
#   interface 4 → ACM serial
# ─────────────────────────────────────────────

echo "--- Linking functions into config (RNDIS must be first) ---"

ln -sf "$GADGET_DIR/functions/rndis.usb0"     "$GADGET_DIR/configs/c.1/"
ln -sf "$GADGET_DIR/functions/mass_storage.0" "$GADGET_DIR/configs/c.1/"
ln -sf "$GADGET_DIR/functions/acm.GS0"        "$GADGET_DIR/configs/c.1/"

echo "    rndis.usb0     → interface 0 (first) [OK]"
echo "    mass_storage.0 → interface 2         [OK]"
echo "    acm.GS0        → interface 4         [OK]"
echo ""

# ─────────────────────────────────────────────
# ACTIVATE: BIND TO UDC
# Writing the UDC name connects the gadget to the physical USB controller.
# Host will detect all three devices as soon as cable is plugged.
# ─────────────────────────────────────────────

echo "--- Activating: binding to UDC $UDC ---"

echo "$UDC" > "$GADGET_DIR/UDC"

sleep 1

echo "    UDC state: $(cat /sys/class/udc/$UDC/state)"
echo ""

# ─────────────────────────────────────────────
# ETHERNET: BRING UP usb0  (road only)
# Assigns IP and brings the interface UP.
# No HTTP / no Samba / no server started here.
# Run your own scripts over 192.168.10.20 after this finishes.
# ─────────────────────────────────────────────

echo "--- Bringing up Ethernet: usb0 at 192.168.10.20/24 (road only) ---"

ip addr flush dev usb0                 2>/dev/null
ip addr add 192.168.10.20/24 dev usb0
ip link set usb0 up

echo "    $(ip addr show usb0 | grep 'inet ')"
echo "    usb0 is UP — no server running"
echo ""

# ─────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────

echo "========================================"
echo " ONDM Triple Gadget is ACTIVE"
echo "========================================"
echo ""
echo " create image            [OK] $IMAGE_FILE"
echo " load modules            [OK] libcomposite+rndis+mass_storage+acm"
echo " mount configfs          [OK]"
echo " mkdir $GADGET_NAME [OK]"
echo " set VID/PID/strings     [OK] VID=0x1d6b PID=0x0104"
echo " mkdir configs/c.1       [OK] 500mA"
echo " Function 1 RNDIS        [OK] road ready → usb0 192.168.10.20"
echo " Function 2 ONDM Storage [OK] read-only → $IMAGE_FILE"
echo " Function 3 ACM Serial   [OK] road ready → /dev/ttyGS0"
echo " link all → config       [OK] RNDIS at interface 0"
echo " echo $UDC > UDC  [OK] ACTIVATED"
echo " ip usb0 up              [OK] 192.168.10.20/24"
echo ""
echo " Plug USB cable → host sees:"
echo "   [NIC]    Remote NDIS Compatible Device"
echo "            Windows: install RNDIS driver → set host IP 192.168.10.1/24"
echo "   [Drive]  ONDM2026 1GB read-only — extracted ONDM2026.zip contents"
echo "   [Serial] USB Serial Device (COMx)"
echo "            Windows: PuTTY → Serial → COMx → 115200 8N1"
echo ""
echo " Roads are up — run your other scripts over them:"
echo "   Ethernet : use 192.168.10.20 (e.g. SSH, HTTP, Samba, iperf3)"
echo "   Serial   : run  getty -L ttyGS0 115200 vt100  for login shell"
echo "              or   echo 'hello' > /dev/ttyGS0  to send data"
echo ""
echo " When done: sudo ./ondm_triple_stop.sh  then unplug cable"
echo "========================================"
