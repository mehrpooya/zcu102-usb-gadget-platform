# ZCU102 USB Gadget Platform — Chat Migration Summary
# Paste this entire file into a new Claude conversation to continue with full context.

## Project Identity
- **User:** Ali Mehrpooya, Smart Internet Lab (HPN Group), University of Bristol
- **Board:** ZCU102 Rev 1.0 (XCZU9EG-2FFVB1156E)
- **Platform:** PetaLinux 2024.1, Linux 6.6.10-xilinx
- **Build machine project:** `~/BSPs/PYNQ_BSPs/ZCU102/XSATest/zcu102_pcieX1_rndis3`
- **Board login:** petalinux (SSH via eth0 at 192.168.137.68)
- **USB gadget IP:** 192.168.10.20/24 on usb0
- **UDC name:** fe200000.usb
- **NVMe:** MAXIO MAP1202, /dev/nvme0n1p2, 931.5GB NTFS, label "New Volume"

## Two Hardware Configurations Completed

### Config 1: PCIe x4 (USB2 gadget)
- All 4 GTR lanes → PCIe, NVMe at full x4 bandwidth
- USB 2.0 gadget only (480 Mbps, no GTR lane used)
- system-user.dtsi: deletes psgtr USB3/SATA/DP refs, sets dr_mode="peripheral", maximum-speed="high-speed"
- Disables SATA and DisplayPort

### Config 2: Normal lanes (USB3 gadget, current)
- Lane 0=PCIe x1, Lane 1=DP, Lane 2=USB3, Lane 3=SATA
- USB 3.0 SuperSpeed gadget (5 Gbps)
- system-user.dtsi: only `&dwc3_0 { dr_mode = "peripheral"; }`
- Kernel: CONFIG_USB_DWC3_DUAL_ROLE=y
- All interfaces working: PCIe+NVMe, DP (connected, Matchbox desktop running), SATA probed, USB3 SuperSpeed confirmed

## FSBL/GTR Mux Chain (Proven)
- FSBL reads SERDES_ICM_CFG0 (0xFD410010) and ICM_CFG1 (0xFD410014)
- Writes TCA6416 U97 I2C GPIO expander at addr 0x20 reg 0x02
- DATA_COMMON_CFG base = 0xE0, lane bits OR'd in
- Verified with FSBL debug patch printing actual U97 write value

## Completed USB Gadget Functions
All use configfs approach. Scripts at /home/petalinux/:

### Individual Gadgets
- **ethernet_usb_start/stop.sh** — RNDIS, usb0 at 192.168.10.20
- **nvme_usb_start/stop.sh** — NVMe /dev/nvme0n1p2 as USB drive (rw)
- **ondm_usb_start/stop.sh** — ONDM2026.zip in 1GB FAT32 image (ro)
- **serial_usb_start/stop.sh** — CDC ACM, /dev/ttyGS0
- **serial_terminal.sh** — getty on ttyGS0
- **serial_raw_send/receive.sh** — raw data pipe

### Composite Gadgets
- **combined_usb_start/stop.sh** — RNDIS + NVMe mass storage
- **triple_usb_start/stop.sh** — RNDIS + NVMe + ACM serial
- **ondm_triple_start/stop.sh** — RNDIS + ONDM image + ACM (roads only)

### Services Over USB Ethernet
- **nvme_samba_start/stop.sh** — Samba share (user auth: petalinux/zcu102)
- **nvme_http_start/stop.sh** — Python HTTP file browser :8080
- **over_eth_nvme_samba_start/stop.sh** — Samba after ondm_triple
- **over_eth_nvme_http_start/stop.sh** — HTTP after ondm_triple
- **over_eth_web_start/stop.sh** — Web+Terminal servers :8081 + ws:8765

## Web Server Projects
### www/ (port 8080) — showcase only, no terminal
- index.html, style.css, app.js, board images
- Dark amber/teal theme, 6 JS demo cards

### terminal/ (port 8081) — showcase + live browser terminal
- Same as www/ plus terminal.js, terminal_server.py, start_all.sh, stop_all.sh
- xterm.js 4.19.0 from jsDelivr (NOT cdnjs — addon-fit missing on cdnjs 5.3.0)
- Hot-pink terminal theme (#12010a bg, #ff2d78 cursor, CRT scanlines)
- Python asyncio WebSocket PTY server on port 8765
- FitAddon constructor: `new (window.FitAddon ? FitAddon.FitAddon : FitAddon)()`

## Critical Bugs Fixed
1. **Doubled chars on reconnect:** term.onData() was in termConnect() — moved to initTerminal() (single registration)
2. **Terminal infinite growth:** ResizeObserver on viewport creates feedback loop — use fixed height:440px + window resize listener
3. **Stop script hangs:** rmdir blocks when resources held — clear lun.0/file, fuser -k ttyGS0, killall smbd before rmdir
4. **UDC state "configured" after stop:** ZynqMP DWC3 hw register quirk — check `function` file instead
5. **lun.0/ro "Device busy":** Must set ro/cdrom/removable BEFORE writing file path
6. **Windows RNDIS driver:** Manual install needed (Microsoft → Remote NDIS Compatible Device)
7. **Windows guest SMB blocked:** Use smbpasswd user auth, map to guest=never

## Desktop Environment (Current)
- X11 + Matchbox Sato via xserver-nodm.service (graphical.target, auto-starts)
- Mali GPU via libmali-xlnx with X11 backend
- DP connected, DRM probed, /dev/dri/card0 present
- Screen blanking fix: DISPLAY=:0 xset s off -dpms s noblank
- Remote access: needs x11vnc (not yet installed) or use browser terminal

## PetaLinux Build Details
- bsp.cfg: NTFS3, EXFAT, NVME, USB_GADGET, DWC3, CONFIGFS, RNDIS, ACM, MASS_STORAGE, DRM_ZYNQMP_DPSUB
- Samba: added via meta-user/conf/user-rootfsconfig (NOT the auto-generated one)
- Custom recipes planned: zcu102-usb-gadgets.bb and zcu102-webserver.bb in meta-user/recipes-apps/

## Known Limitations
- ZynqMP DWC3 does NOT support runtime OTG/DRD role switching (AMD wiki confirmed)
- Cannot use mouse/keyboard while in gadget mode (same USB port)
- Samba requires PetaLinux rebuild (no dnf repos configured)
- xterm.js FitAddon unavailable on cdnjs for v5.x (use jsDelivr v4.19.0)

## Outstanding Work
- VNC server installation for remote desktop access
- PetaLinux rootfs recipe integration (recipes created but not yet built)
- Production system packaging
- USB3 throughput benchmarking (iperf3 over RNDIS at SuperSpeed)
