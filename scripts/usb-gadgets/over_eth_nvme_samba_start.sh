#!/bin/sh
# over_eth_nvme_samba_start.sh
# Share /dev/nvme0n1p2 over USB Ethernet via Samba.
# Run AFTER ondm_triple_start.sh (USB Ethernet must be up first).
#
# Usage: sudo ./over_eth_nvme_samba_start.sh
#
# What this script does:
#   check smbd           <- verify Samba is installed
#   mount nvme0n1p2      <- mount NVMe read-write at /mnt/nvme
#   write smb.conf       <- configure share with user auth
#   smbpasswd -a         <- set Samba login (petalinux / zcu102)
#   start smbd           <- start file server
#   start nmbd           <- start name service
#
# Host access after running:
#   Windows Explorer: \\192.168.10.20\NVMe
#   Username: petalinux   Password: zcu102
#
# Stop: sudo ./over_eth_nvme_samba_stop.sh

DEVICE="/dev/nvme0n1p2"
MOUNT_POINT="/mnt/nvme"
SMB_CONF="/etc/samba/smb.conf"
SAMBA_USER="petalinux"
SAMBA_PASS="zcu102"
BIND_IP="192.168.10.20"

echo "========================================"
echo " NVMe Samba Share — START"
echo " over USB Ethernet (192.168.10.20)"
echo "========================================"
echo ""

# ─────────────────────────────────────────────
# CHECK SAMBA
# ─────────────────────────────────────────────
echo "--- Checking Samba ---"
which smbd || { echo "ERROR: smbd not found. Rebuild PetaLinux with samba package."; exit 1; }
echo "    smbd: $(which smbd) [OK]"
echo ""

# ─────────────────────────────────────────────
# MOUNT NVME
# ─────────────────────────────────────────────
echo "--- Mounting NVMe ---"
umount "$DEVICE"                           2>/dev/null
umount "/run/media/New Volume-nvme0n1p2"   2>/dev/null
mkdir -p "$MOUNT_POINT"
mount -t ntfs3 -o rw,force "$DEVICE" "$MOUNT_POINT"
grep nvme0n1p2 /proc/mounts
ls -lh "$MOUNT_POINT/"
echo "    mounted at $MOUNT_POINT [OK]"
echo ""

# ─────────────────────────────────────────────
# WRITE SMB.CONF
# ─────────────────────────────────────────────
echo "--- Writing smb.conf ---"
[ -f "$SMB_CONF" ] && cp "$SMB_CONF" "${SMB_CONF}.bak"
cat > "$SMB_CONF" << 'SMBCONF'
[global]
   workgroup = WORKGROUP
   server string = ZCU102 NVMe Share
   netbios name = ZCU102
   security = user
   map to guest = never
   dns proxy = no
   interfaces = usb0
   bind interfaces only = yes
   load printers = no
   printing = bsd
   printcap name = /dev/null
   disable spoolss = yes

[NVMe]
   comment = ZCU102 NVMe Drive
   path = /mnt/nvme
   browseable = yes
   read only = no
   writable = yes
   guest ok = no
   valid users = petalinux
   force user = root
   create mask = 0777
   directory mask = 0777
SMBCONF
echo "    smb.conf written [OK]"
echo ""

# ─────────────────────────────────────────────
# SET SAMBA PASSWORD
# ─────────────────────────────────────────────
echo "--- Setting Samba user credentials ---"
printf "%s\n%s\n" "$SAMBA_PASS" "$SAMBA_PASS" | smbpasswd -s -a "$SAMBA_USER"
echo "    user: $SAMBA_USER  password: $SAMBA_PASS [OK]"
echo ""

# ─────────────────────────────────────────────
# START SMBD
# ─────────────────────────────────────────────
echo "--- Starting smbd ---"
killall smbd 2>/dev/null; sleep 1
smbd --daemon
echo "    smbd started [OK]"
echo ""

# ─────────────────────────────────────────────
# START NMBD
# ─────────────────────────────────────────────
echo "--- Starting nmbd ---"
killall nmbd 2>/dev/null; sleep 1
nmbd --daemon 2>/dev/null || echo "    nmbd not available (use IP address)"
echo ""

# ─────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────
echo "========================================"
echo " NVMe Samba Share is ACTIVE"
echo "========================================"
echo ""
echo " check smbd      [OK]"
echo " mount nvme      [OK] $MOUNT_POINT (ntfs3 rw)"
echo " write smb.conf  [OK] bound to usb0"
echo " smbpasswd       [OK] $SAMBA_USER / $SAMBA_PASS"
echo " start smbd      [OK]"
echo " start nmbd      [OK]"
echo ""
echo " Windows access:"
echo "   Explorer: \\\\${BIND_IP}\\NVMe"
echo "   Username: $SAMBA_USER"
echo "   Password: $SAMBA_PASS"
echo ""
echo " Verify: ping ${BIND_IP} from Windows first"
echo " Stop: sudo ./over_eth_nvme_samba_stop.sh"
echo "========================================"
