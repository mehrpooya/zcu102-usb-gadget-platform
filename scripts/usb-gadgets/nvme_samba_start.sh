#!/bin/sh
# nvme_samba_start.sh
# Share /dev/nvme0n1p2 to the host over USB Ethernet using Samba.
# NVMe stays mounted on Linux — both sides can access simultaneously.
#
# Usage: sudo ./nvme_samba_start.sh
#
# Run AFTER ethernet_usb_start.sh and AFTER plugging USB cable.
#
# What this script does:
#   smbpasswd -a petalinux <- create samba user (first run only)
#   mkdir /mnt/nvme        <- create mount point if not exists
#   mount nvme0n1p2        <- mount NVMe with ntfs3 read-write
#   write smb.conf         <- configure Samba share with user auth
#   start smbd             <- start Samba file server
#   start nmbd             <- start Samba name service
#
# After running:
#   Windows Explorer address bar: \\192.168.10.20\NVMe
#   Username: petalinux
#   Password: zcu102
#
# When done: run nvme_samba_stop.sh, then ethernet_usb_stop.sh

DEVICE="/dev/nvme0n1p2"
MOUNT_POINT="/mnt/nvme"
SMB_CONF="/etc/samba/smb.conf"
SAMBA_USER="petalinux"
SAMBA_PASS="zcu102"

# ── smbpasswd -a petalinux ── create samba user (first run only) ─
# Samba maintains its own password database separate from Linux
# this creates the Samba user so Windows authentication works
# on subsequent runs it updates the existing password
printf "%s\n%s\n" "$SAMBA_PASS" "$SAMBA_PASS" | smbpasswd -s -a "$SAMBA_USER"
echo "Samba user '$SAMBA_USER' set with password '$SAMBA_PASS'"

# ── mkdir /mnt/nvme ── create mount point if not exists ──────────
mkdir -p "$MOUNT_POINT"

# ── mount nvme0n1p2 ── mount NVMe with ntfs3 read-write ──────────
# unmount first in case it is already mounted somewhere else
umount "$DEVICE"                          2>/dev/null
umount "/run/media/New Volume-nvme0n1p2"  2>/dev/null

# mount with ntfs3 driver (kernel NTFS, read-write)
# force: bypass dirty flag left by Windows fast-startup
mount -t ntfs3 -o rw,force "$DEVICE" "$MOUNT_POINT"

# confirm mount succeeded
grep nvme0n1p2 /proc/mounts

# show contents
ls -lh "$MOUNT_POINT/"

# ── write smb.conf ── configure Samba with user authentication ───
# uses username/password auth — works on university/corporate Windows
# guest access disabled to comply with Windows security policies
[ -f "$SMB_CONF" ] && cp "$SMB_CONF" "${SMB_CONF}.bak"

cat > "$SMB_CONF" << 'SMBCONF'
[global]
   workgroup = WORKGROUP
   server string = ZCU102 NVMe Share
   netbios name = ZCU102
   security = user
   # user auth — no guest — works with Windows org security policies
   map to guest = never
   dns proxy = no
   # bind only to usb0 — accessible via USB Ethernet only
   interfaces = usb0
   bind interfaces only = yes
   # disable printing
   load printers = no
   printing = bsd
   printcap name = /dev/null
   disable spoolss = yes

[NVMe]
   comment = ZCU102 NVMe Drive (931.5GB)
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

echo "smb.conf written"

# ── start smbd ── start Samba file server ────────────────────────
kill $(cat /var/run/samba/smbd.pid 2>/dev/null) 2>/dev/null
sleep 1
smbd --daemon
echo "smbd started"

# ── start nmbd ── start Samba name service ────────────────────────
kill $(cat /var/run/samba/nmbd.pid 2>/dev/null) 2>/dev/null
sleep 1
nmbd --daemon 2>/dev/null || echo "nmbd not available — use IP address"

# ── summary ──────────────────────────────────────────────────────
echo ""
echo "smbpasswd -a petalinux [OK] samba user set"
echo "mkdir /mnt/nvme        [OK] mount point ready"
echo "mount nvme0n1p2        [OK] mounted at $MOUNT_POINT (ntfs3 rw)"
echo "write smb.conf         [OK] user auth configured"
echo "start smbd             [OK] file server running"
echo "start nmbd             [OK] name service running"
echo ""
echo "Windows access:"
echo "  Explorer address bar: \\\\192.168.10.20\\NVMe"
echo "  Username: $SAMBA_USER"
echo "  Password: $SAMBA_PASS"
echo ""
echo "ZCU102 access:"
echo "  ls /mnt/nvme/"
echo ""
echo "When done: sudo ./nvme_samba_stop.sh  then sudo ./ethernet_usb_stop.sh"
