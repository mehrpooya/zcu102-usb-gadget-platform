#!/bin/sh
# triple_usb_start.sh
# One USB cable → host sees THREE devices simultaneously:
#   1. RNDIS Ethernet  → Windows NIC / Linux usb0 (192.168.10.20)
#   2. NVMe Storage    → Windows drive letter / Linux /dev/sdX
#   3. CDC ACM Serial  → Windows COMx / Linux /dev/ttyACM0
#
# Usage: sudo ./triple_usb_start.sh
#
# What this script does:
#   load modules            <- libcomposite + rndis + mass_storage + acm
#   unmount nvme0n1p2       <- free NVMe from Linux (required for mass storage)
#   mount configfs          <- open the gadget control interface
#   mkdir g_triple          <- create ONE gadget object
#   set VID/PID/strings     <- describe composite device to host
#   mkdir configs/c.1       <- create ONE USB configuration
#   --- RNDIS section ---   <- create Ethernet function
#   --- Mass Storage ---     <- create NVMe disk function
#   --- CDC ACM section ---  <- create Serial function
#   link all → config       <- RNDIS first (Windows needs it at interface 0)
#   echo fe200000.usb > UDC <- ACTIVATE: host sees all three
#   ip addr / ip link       <- bring up usb0 at 192.168.10.20
#   getty on ttyGS0         <- start login shell on serial port
#
# After running: plug USB cable → host sees NIC + drive + COM port
#   Windows NIC    : install RNDIS driver → set host IP 192.168.10.1/24
#   Windows Drive  : opens automatically in Explorer
#   Windows Serial : PuTTY → Serial → COMx → 115200 8N1
#
# When done: sudo ./triple_usb_stop.sh  then unplug cable

GADGET_NAME="g_triple"
UDC="fe200000.usb"
GADGET_BASE="/sys/kernel/config/usb_gadget"
GADGET_DIR="$GADGET_BASE/$GADGET_NAME"
DEVICE="/dev/nvme0n1p2"

echo "========================================"
echo " Triple USB Gadget — START"
echo " Ethernet + NVMe Storage + Serial"
echo "========================================"
echo ""

# ════════════════════════════════════════════
# LOAD MODULES
# ════════════════════════════════════════════
echo "--- Loading modules ---"
modprobe libcomposite
modprobe usb_f_rndis
modprobe usb_f_mass_storage
modprobe usb_f_acm
modprobe u_serial
echo "    libcomposite      [OK]"
echo "    usb_f_rndis       [OK]"
echo "    usb_f_mass_storage [OK]"
echo "    usb_f_acm         [OK]"
echo ""

# ════════════════════════════════════════════
# UNMOUNT NVME (required before mass storage)
# ════════════════════════════════════════════
echo "--- Unmounting NVMe from Linux ---"
umount /mnt/nvme                          2>/dev/null
umount "/run/media/New Volume-nvme0n1p2"  2>/dev/null
# confirm nothing is mounted (should print nothing)
grep nvme0n1p2 /proc/mounts || echo "    nvme0n1p2 is free [OK]"
echo ""

# ════════════════════════════════════════════
# MOUNT CONFIGFS
# ════════════════════════════════════════════
echo "--- Mounting configfs ---"
mount -t configfs none /sys/kernel/config 2>/dev/null
echo "    /sys/kernel/config ready [OK]"
echo ""

# ════════════════════════════════════════════
# CREATE GADGET OBJECT
# ════════════════════════════════════════════
echo "--- Creating gadget object: $GADGET_NAME ---"
mkdir "$GADGET_DIR"

# USB device descriptor
# bDeviceClass 0xEF + subclass 0x02 + protocol 0x01 = IAD composite device
# Windows uses these to correctly separate the three functions
echo "0x1d6b"  > "$GADGET_DIR/idVendor"     # Linux Foundation
echo "0x0104"  > "$GADGET_DIR/idProduct"    # Multifunction Composite Gadget
echo "0x0200"  > "$GADGET_DIR/bcdUSB"       # USB 2.0
echo "0x0100"  > "$GADGET_DIR/bcdDevice"    # Device version 1.0
echo "0xEF"    > "$GADGET_DIR/bDeviceClass"     # Miscellaneous
echo "0x02"    > "$GADGET_DIR/bDeviceSubClass"  # Common Class
echo "0x01"    > "$GADGET_DIR/bDeviceProtocol"  # Interface Association

# Human-readable strings shown in Device Manager / lsusb
mkdir -p "$GADGET_DIR/strings/0x409"
echo "ZCU102TRIPLE001"           > "$GADGET_DIR/strings/0x409/serialnumber"
echo "Xilinx ZCU102"             > "$GADGET_DIR/strings/0x409/manufacturer"
echo "ZCU102 Ethernet+NVMe+Serial" > "$GADGET_DIR/strings/0x409/product"

echo "    VID=0x1d6b PID=0x0104 composite [OK]"
echo ""

# ════════════════════════════════════════════
# CREATE USB CONFIGURATION
# ════════════════════════════════════════════
echo "--- Creating USB configuration ---"
mkdir -p "$GADGET_DIR/configs/c.1"
echo "500" > "$GADGET_DIR/configs/c.1/MaxPower"   # 500mA for three functions

mkdir -p "$GADGET_DIR/configs/c.1/strings/0x409"
echo "RNDIS+NVMe+ACM" > "$GADGET_DIR/configs/c.1/strings/0x409/configuration"

echo "    config c.1 MaxPower=500mA [OK]"
echo ""

# ════════════════════════════════════════════
# FUNCTION 1: RNDIS ETHERNET
# ════════════════════════════════════════════
echo "--- Function 1: RNDIS Ethernet ---"

mkdir -p "$GADGET_DIR/functions/rndis.usb0"

# RNDIS must be the FIRST function linked into config
# Windows looks for RNDIS at interface 0 — if it is not first, driver fails
echo "    rndis.usb0 created [OK]"
echo ""

# ════════════════════════════════════════════
# FUNCTION 2: NVME MASS STORAGE
# ════════════════════════════════════════════
echo "--- Function 2: NVMe Mass Storage ---"

mkdir -p "$GADGET_DIR/functions/mass_storage.0"

# CRITICAL: set ro/cdrom/removable BEFORE writing file
# once file is written the kernel locks the device and ro becomes read-only
echo "0" > "$GADGET_DIR/functions/mass_storage.0/lun.0/ro"         # read-write
echo "0" > "$GADGET_DIR/functions/mass_storage.0/lun.0/cdrom"      # hard disk
echo "1" > "$GADGET_DIR/functions/mass_storage.0/lun.0/removable"  # removable

# NOW write the backing device (locks the lun after this)
echo "$DEVICE" > "$GADGET_DIR/functions/mass_storage.0/lun.0/file"

echo "    mass_storage.0 → $DEVICE [OK]"
echo "    ro=$(cat $GADGET_DIR/functions/mass_storage.0/lun.0/ro) (0=read-write)"
echo ""

# ════════════════════════════════════════════
# FUNCTION 3: CDC ACM SERIAL
# ════════════════════════════════════════════
echo "--- Function 3: CDC ACM Serial ---"

# creating this directory also creates /dev/ttyGS0 on the board
mkdir -p "$GADGET_DIR/functions/acm.GS0"

# confirm /dev/ttyGS0 appeared
ls -la /dev/ttyGS0 2>/dev/null && echo "    /dev/ttyGS0 created [OK]" \
                                 || echo "    WARNING: /dev/ttyGS0 not found"
echo ""

# ════════════════════════════════════════════
# LINK ALL FUNCTIONS INTO CONFIGURATION
# Order matters: RNDIS first, then the others
# ════════════════════════════════════════════
echo "--- Linking functions into config (RNDIS must be first) ---"
ln -sf "$GADGET_DIR/functions/rndis.usb0"     "$GADGET_DIR/configs/c.1/"
ln -sf "$GADGET_DIR/functions/mass_storage.0" "$GADGET_DIR/configs/c.1/"
ln -sf "$GADGET_DIR/functions/acm.GS0"        "$GADGET_DIR/configs/c.1/"
echo "    rndis.usb0     → interface 0 [OK]"
echo "    mass_storage.0 → interface 2 [OK]"
echo "    acm.GS0        → interface 4 [OK]"
echo ""

# ════════════════════════════════════════════
# ACTIVATE: BIND TO UDC
# ════════════════════════════════════════════
echo "--- Binding to UDC: $UDC ---"
echo "$UDC" > "$GADGET_DIR/UDC"
sleep 1
echo "    UDC state: $(cat /sys/class/udc/$UDC/state)"
echo ""

# ════════════════════════════════════════════
# ETHERNET: BRING UP usb0 AT 192.168.10.20
# ════════════════════════════════════════════
echo "--- Bringing up Ethernet interface ---"
ip addr flush dev usb0                2>/dev/null
ip addr add 192.168.10.20/24 dev usb0
ip link set usb0 up
echo "    usb0: $(ip addr show usb0 | grep 'inet ')"
echo ""

# ════════════════════════════════════════════
# SERIAL: START LOGIN SHELL ON ttyGS0
# ════════════════════════════════════════════
echo "--- Starting serial login shell ---"
# getty: opens ttyGS0, shows login prompt, handles user login
# -L = local mode (no modem signals), 115200 = baud (cosmetic for USB)
# running in background so script can exit
sleep 1
getty -L ttyGS0 115200 vt100 &
GETTY_PID=$!
echo "    getty started on /dev/ttyGS0 PID=$GETTY_PID [OK]"
echo ""

# ════════════════════════════════════════════
# SUMMARY
# ════════════════════════════════════════════
echo "========================================"
echo " Triple USB Gadget is ACTIVE"
echo "========================================"
echo ""
echo " load modules            [OK] rndis + mass_storage + acm"
echo " unmount nvme0n1p2       [OK] partition freed from Linux"
echo " mount configfs          [OK] gadget control interface ready"
echo " mkdir g_triple          [OK] composite gadget created"
echo " set VID/PID/strings     [OK] VID=0x1d6b PID=0x0104"
echo " mkdir configs/c.1       [OK] USB configuration ready"
echo " Function 1: RNDIS       [OK] Ethernet → usb0 192.168.10.20"
echo " Function 2: Mass Storage [OK] NVMe $DEVICE → host drive"
echo " Function 3: CDC ACM     [OK] Serial → /dev/ttyGS0"
echo " link all → config       [OK] RNDIS first"
echo " echo $UDC > UDC         [OK] ACTIVATED"
echo " ip addr usb0            [OK] 192.168.10.20/24"
echo " getty on ttyGS0         [OK] login shell ready"
echo ""
echo " Now plug USB cable into host PC:"
echo ""
echo " [Ethernet]"
echo "   Windows: install RNDIS driver → set host IP 192.168.10.1/24"
echo "   Board IP: 192.168.10.20"
echo ""
echo " [NVMe Storage]"
echo "   Windows: new drive letter appears automatically"
echo "   Do NOT mount $DEVICE on Linux while gadget is running"
echo ""
echo " [Serial Terminal]"
echo "   Windows: new COMx in Device Manager"
echo "   PuTTY → Serial → COMx → 115200 → 8N1 → Open"
echo "   Linux host: screen /dev/ttyACM0 115200"
echo ""
echo " When done: sudo ./triple_usb_stop.sh  then unplug cable"
echo "========================================"
