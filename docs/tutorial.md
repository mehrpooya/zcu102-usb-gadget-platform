# ZCU102 USB Gadget, PCIe NVMe & Web Server — Engineering Tutorial

**Author:** Ali Mehrpooya, Smart Internet Lab (HPN Group), University of Bristol  
**Board:** Xilinx ZCU102 (XCZU9EG-2FFVB1156E)  
**Platform:** PetaLinux 2024.1, Linux 6.6.10-xilinx  
**Date:** June 2026  

---

## 1. Project Overview

This project transforms the Xilinx ZCU102 evaluation board into a multi-function USB device. When connected to a host PC via a single USB cable, the board can simultaneously present itself as a network adapter, a storage drive, and a serial console. The system also hosts a web server and a live browser-based terminal, all running on PetaLinux 2024.1.

### Key Achievements

- USB Gadget Ethernet (RNDIS): Board appears as a NIC to the host — SSH, ping, file sharing all work over USB
- USB Mass Storage: Board exposes NVMe SSD (931.5 GB) or file images as USB flash drives
- USB Serial (CDC ACM): Virtual COM port for terminal access
- Composite Gadgets: All three functions simultaneously over one USB cable
- NVMe over PCIe x4: 931.5 GB NTFS storage via MAXIO MAP1202 SSD
- Web Server: Dark-themed showcase page served from the board
- Browser Terminal: Full PTY shell in the browser via xterm.js + WebSocket
- Samba File Server: Simultaneous NVMe access from board and Windows host
- USB3 SuperSpeed: 5 Gbps gadget mode with normal GTR lane allocation

---

## 2. Hardware & Software Environment

### Hardware

| Component | Details |
|-----------|---------|
| Board | ZCU102 Rev 1.0 (EK-U1-ZCU102-G) |
| SoC | XCZU9EG-2FFVB1156E (Zynq UltraScale+ MPSoC) |
| CPU | Quad-core ARM Cortex-A53 @ 1.2 GHz |
| Real-time CPU | Dual Cortex-R5F @ 500 MHz |
| GPU | Mali-400MP2 |
| DDR4 | 4 GB 64-bit |
| NVMe SSD | MAXIO MAP1202, 931.5 GB, via PCIe |
| USB PHY | SMSC USB3320 (ULPI, MIO52-63) |
| GTR Lanes | 4 × PS-GTR SerDes |
| SD Card | 29.9 GB (OS boot) |

### Software

| Component | Version |
|-----------|---------|
| PetaLinux | 2024.1 |
| Linux Kernel | 6.6.10-xilinx |
| Vivado | 2024.1 |
| USB Controller | DWC3 at fe200000 |
| UDC Name | fe200000.usb |

### Network Configuration

| Interface | IP Address | Purpose |
|-----------|-----------|---------|
| eth0 | 192.168.137.68 (DHCP) | SSH from Windows host |
| usb0 | 192.168.10.20/24 | USB Gadget Ethernet |
| Host USB side | 192.168.10.1 or 192.168.10.10 | Windows RNDIS adapter |

---

## 3. FSBL & GTR Mux Proof Chain

### The Problem

The ZCU102 has 4 PS-GTR SerDes lanes that can be assigned to PCIe, USB3, SATA, or DisplayPort. The lane-to-connector routing is controlled by a TCA6416 I2C GPIO expander (U97) which sets Pericom mux select pins. Understanding who programs these muxes was critical for debugging PCIe x4 configurations.

### The Proof Chain

The FSBL (First Stage Boot Loader) alone programs the muxes, not U-Boot, not Linux:

1. **Vivado PS-GTR configuration** → exported to XSA
2. **XSA generates `psu_init.c`** → contains `Xil_Out32(0xFD410010, ...)` to write the SERDES ICM registers
3. **FSBL calls `psu_init()`** first thing at boot → programs GTR lanes
4. **FSBL calls `XFsbl_BoardConfig()`** → reads ICM registers, computes mux values, writes to U97 via I2C

### Key Register Addresses

| Register | Address | Meaning |
|----------|---------|---------|
| SERDES_ICM_CFG0 | 0xFD410010 | Lanes 0-1 protocol (bits[2:0]=lane0, bits[6:4]=lane1) |
| SERDES_ICM_CFG1 | 0xFD410014 | Lanes 2-3 protocol |
| U97 Register 0x02 | I2C 0x20 | Mux select + DATA_COMMON_CFG |

### Protocol Values

0=PowerDown, 1=PCIe, 2=SATA, 3=USB3, 4=DisplayPort, 5=SGMII

### Verification Command

```bash
# In U-Boot shell:
i2c dev 0    # select I2C bus 0
i2c md 0x20 0x02 1    # read U97 register 2
# PCIe x4: 0xE0    Mixed (PCIe+DP+USB+SATA): 0xEE
```

---

## 4. Device Tree Architecture

### DT Include Chain

```
system-top.dts
  ├── zynqmp.dtsi          (base SoC: all peripherals, status="disabled")
  ├── zynqmp-clk-ccf.dtsi  (clock framework)
  ├── pl.dtsi              (PL peripherals from Vivado)
  └── pcw.dtsi             (auto-generated from XSA: status="okay" for enabled peripherals)

system-user.dtsi
  ├── system-conf.dtsi     (aliases, chosen node)
  └── zcu102-rev1.0.dtsi   (board-specific: psgtr clocks, phy assignments, pinctrl)
      └── zcu102-reva.dtsi (actual board config)
          └── zcu102-revb.dtsi (minor rev B differences)
```

### Key Lesson: Override Layering

`system-user.dtsi` is applied LAST and overrides everything. This is where custom modifications go. The files in `project-spec/meta-user/recipes-bsp/device-tree/files/` are the persistent, user-owned files. The `pcw.dtsi` is auto-generated from the XSA and should never be manually edited.

### PCIe x4 system-user.dtsi (Previous Configuration)

When all 4 GTR lanes were assigned to PCIe, extensive overrides were needed:

```dts
/* Override psgtr: only PCIe ref clock */
&psgtr { clocks = <&si5341 0 5>; clock-names = "ref0"; };
/* Delete USB3 phy to prevent psgtr reconfiguring lane 2 */
&usb0 { /delete-property/ phys; /delete-property/ phy-names; };
/* Gadget mode on USB 2.0 only */
&dwc3_0 { dr_mode = "peripheral"; maximum-speed = "high-speed"; ... };
/* Disable SATA and DP (their lanes are PCIe now) */
&sata { status = "disabled"; ... };
&zynqmp_dpsub { status = "disabled"; ... };
```

### Normal Lane Allocation system-user.dtsi (Current Configuration)

With normal lane allocation (PCIe×1 + DP + SATA + USB3), minimal overrides needed:

```dts
/include/ "system-conf.dtsi"
#include "zcu102-rev1.0.dtsi"
/ { chosen { myname = "Ali Mehrpooya"; }; };
&gem3 { local-mac-address = [02 00 00 00 00 01]; };
&dwc3_0 { dr_mode = "peripheral"; };
```

---

## 5. PCIe x4 Configuration & NVMe Integration

### The Problem

Adding an NVMe SSD via PCIe x4 caused kernel panics (`nwl-pcie Slave error`) because the inherited `zcu102-reva.dtsi` device tree assigned GTR lane 2 to USB3 and lane 3 to SATA. When Linux probed the psgtr driver, it reconfigured these lanes away from PCIe, destroying the PCIe link and causing DMA errors.

### The Solution

Override `system-user.dtsi` to delete all non-PCIe psgtr references and disable SATA/DP/USB3. Keep USB0 enabled in USB 2.0 mode (MIO52-63, no GTR lane) for gadget functionality.

### NVMe Details

| Property | Value |
|----------|-------|
| Controller | MAXIO MAP1202 |
| Capacity | 931.5 GB |
| Filesystem | NTFS (label: "New Volume") |
| Device | /dev/nvme0n1p2 |
| Mount | `mount -t ntfs3 -o rw,force /dev/nvme0n1p2 /mnt/nvme` |

### The NTFS Dirty Flag Issue

Windows Fast Startup leaves NTFS in a dirty state. Linux ntfs3 refuses to mount read-write. Fix: `mount -t ntfs3 -o rw,force`. To prevent: always "Eject" the drive in Windows before disconnecting.

---

## 6. USB Gadget Mode — Concepts

### Host vs Device

Every USB connection has a host (master) and a device/gadget (slave). USB Gadget mode makes the ZCU102 the device — when plugged into a PC, the PC sees it as a peripheral.

### The Three-Layer Model

```
Layer 3: Network interface (usb0)      ← Linux sees like eth0
Layer 2: USB function (RNDIS/ACM/MSC)  ← what host PC sees
Layer 1: UDC hardware (fe200000.usb)   ← physical controller
```

### configfs — The Gadget Control Interface

Modern Linux builds USB gadgets through configfs: a virtual filesystem where creating directories and writing files defines the USB device descriptors.

```
/sys/kernel/config/usb_gadget/
  └── g1/                          ← gadget object
      ├── idVendor, idProduct      ← USB identifiers
      ├── strings/0x409/           ← human-readable names
      ├── configs/c.1/             ← USB configuration
      │   └── rndis.usb0 → ...    ← symlink to function
      ├── functions/rndis.usb0/    ← RNDIS function
      └── UDC                      ← write "fe200000.usb" to activate
```

### Critical Rules

1. **One UDC, one gadget**: Only one gadget can bind to `fe200000.usb` at a time
2. **Mass storage flag order**: Set `ro`, `cdrom`, `removable` BEFORE writing `lun.0/file`
3. **RNDIS first in composite**: Windows expects RNDIS at interface 0
4. **UDC state register**: Shows "configured" even after stop on ZynqMP — this is a hardware register quirk, ignore it. Use `cat /sys/class/udc/fe200000.usb/function` (empty = no gadget bound)
5. **Stop before unplug**: Always run the stop script before unplugging USB cable

### Kernel Config Requirements (bsp.cfg)

```
CONFIG_USB_GADGET=y
CONFIG_USB_DWC3=y
CONFIG_USB_DWC3_GADGET=y          (or CONFIG_USB_DWC3_DUAL_ROLE=y)
CONFIG_CONFIGFS_FS=y
CONFIG_USB_LIBCOMPOSITE=m
CONFIG_USB_CONFIGFS=m
CONFIG_USB_CONFIGFS_RNDIS=y
CONFIG_USB_CONFIGFS_ECM=y
CONFIG_USB_CONFIGFS_ACM=y
CONFIG_USB_CONFIGFS_MASS_STORAGE=y
CONFIG_USB_F_RNDIS=m
CONFIG_USB_F_ECM=m
CONFIG_USB_F_ACM=m
CONFIG_USB_F_MASS_STORAGE=m
CONFIG_USB_U_SERIAL=m
```

### First Check After Boot

```bash
ls /sys/class/udc/
# Must show: fe200000.usb
# If empty: dr_mode is wrong in device tree — must fix and reboot
```

---

## 7. USB Gadget — Ethernet (RNDIS)

**Scripts:** `ethernet_usb_start.sh`, `ethernet_usb_stop.sh`, `ethernet_usb_change_ip.sh`

The RNDIS gadget makes the board appear as a USB network adapter on the host. Both sides get an IP address and can exchange TCP/IP traffic over the USB cable.

### Architecture

```
ZCU102 (gadget)  ====USB cable====  Host PC
  usb0: 192.168.10.20               RNDIS adapter: 192.168.10.1
```

### Windows RNDIS Driver

Windows 10/11 does not auto-install the RNDIS driver for VID 0x1d6b. Manual install: Device Manager → right-click RNDIS → Update driver → Browse → Let me pick → Network adapters → Microsoft → Remote NDIS Compatible Device.

### IP Change

```bash
./ethernet_usb_change_ip.sh 10.10.70.1 24
```

---

## 8. USB Gadget — Mass Storage (NVMe)

**Scripts:** `nvme_usb_start.sh`, `nvme_usb_stop.sh`

Exposes `/dev/nvme0n1p2` (931.5 GB NTFS) to the host as a USB flash drive. The NVMe partition must be unmounted from Linux before sharing — simultaneous access causes filesystem corruption.

### Critical: Exclusive Access

USB Mass Storage operates at the raw block level. The host and Linux cannot both have the filesystem mounted. The start script unmounts all Linux mount points before activating.

### Stop Script Gotcha

The stop script must: (1) clear `lun.0/file` before rmdir, (2) use `killall` not PID files for Samba, (3) use `bash -c 'echo "" > UDC'` for reliable unbind.

---

## 9. USB Gadget — Mass Storage (ONDM ZIP)

**Scripts:** `ondm_usb_start.sh`, `ondm_usb_stop.sh`

Cannot point `lun.0/file` directly at a `.zip` file — USB mass storage requires a filesystem. Solution: create a 1 GB FAT32 disk image, extract the ZIP contents into it, then share the image. Host sees a USB drive with the extracted files.

### Image Creation (first run only)

```bash
dd if=/dev/zero of=/home/petalinux/ondm_share.img bs=1M count=1024
mkfs.vfat -F 32 -n "ONDM2026" /home/petalinux/ondm_share.img
mount -o loop ondm_share.img /tmp/ondm_mnt
unzip ONDM2026.zip -d /tmp/ondm_mnt/
umount /tmp/ondm_mnt
```

Image is reused on subsequent runs. Delete to rebuild with new ZIP contents.

---

## 10. USB Gadget — Serial (CDC ACM)

**Scripts:** `serial_usb_start.sh`, `serial_usb_stop.sh`, `serial_terminal.sh`, `serial_raw_send.sh`, `serial_raw_receive.sh`

Creates a virtual COM port. Board side: `/dev/ttyGS0`. Host side: `COMx` (Windows) or `/dev/ttyACM0` (Linux).

### Baud Rate

USB serial does not use a real baud rate — data travels at USB speed. The 115200 setting is conventional and accepted by all terminal programs.

### Raw Mode vs Terminal Mode

```bash
# Raw: just send/receive bytes
cat /dev/ttyGS0 &              # receive from host
echo "hello" > /dev/ttyGS0     # send to host

# Terminal: full login shell
getty -L ttyGS0 115200 vt100 &  # host gets login prompt
```

### "No job control" Warning

This is normal for USB serial TTY — not a full PTY. Ctrl+C does not work inside serial sessions. Kill processes from the main SSH terminal instead.

---

## 11. Combined USB Gadgets

**Scripts:** `combined_usb_start.sh`, `combined_usb_stop.sh`

Combines RNDIS Ethernet + NVMe Mass Storage in one composite gadget. One USB cable, host sees both a NIC and a 931.5 GB drive.

Key: `bDeviceClass=0xEF, bDeviceSubClass=0x02, bDeviceProtocol=0x01` (IAD composite). RNDIS must be linked first for Windows driver matching.

---

## 12. Triple USB Gadget

**Scripts:** `triple_usb_start.sh`, `triple_usb_stop.sh`

Adds CDC ACM Serial to the combined gadget. One USB cable → NIC + Drive + COM port.

### Stop Script Fix

The stop script must release resources before rmdir to prevent hanging: clear `lun.0/file`, kill all processes on `ttyGS0` with `fuser -k`, bring down `usb0`, then unbind UDC and clean configfs.

---

## 13. ONDM Triple USB Gadget

**Scripts:** `ondm_triple_start.sh`, `ondm_triple_stop.sh`

Same as triple but mass storage shares the ONDM 1 GB image (read-only) instead of NVMe. Ethernet and Serial are "roads only" — no servers started. Run other scripts over these roads afterwards.

### Running Services Over the Roads

```bash
sudo ./ondm_triple_start.sh         # bring up all three roads

# Then pick what to run:
sudo ./over_eth_nvme_samba_start.sh  # Samba over ethernet
sudo ./over_eth_nvme_http_start.sh   # HTTP browser over ethernet
sudo ./over_eth_web_start.sh         # Web+Terminal over ethernet
getty -L ttyGS0 115200 vt100 &       # Login shell over serial
```

---

## 14. NVMe Sharing — Samba over USB Ethernet

**Scripts:** `nvme_samba_start.sh`, `nvme_samba_stop.sh`, `over_eth_nvme_samba_start.sh`, `over_eth_nvme_samba_stop.sh`

Unlike USB mass storage, Samba allows simultaneous access from board and Windows. NVMe stays mounted on Linux; Windows connects as a network drive.

### Authentication

University/corporate Windows blocks guest SMB access. Solution: user authentication with `smbpasswd -a petalinux` (password: `zcu102`). `smb.conf` uses `map to guest = never` and `valid users = petalinux`.

### Stop Script Fix

Use `killall smbd` not PID files — Samba spawns child processes per connection.

---

## 15. NVMe Sharing — HTTP File Browser

**Scripts:** `nvme_http_start.sh`, `nvme_http_stop.sh`, `over_eth_nvme_http_start.sh`, `over_eth_nvme_http_stop.sh`

Zero-dependency read-only file browser using Python3 built-in `http.server`. Browse NVMe contents at `http://192.168.10.20:8080`.

---

## 16. ZCU102 Showcase Web Server

**Folder:** `/home/petalinux/www/`  
**Files:** `index.html`, `style.css`, `app.js`, `board.jpg`, `board-contents.jpg`, `web_server_start.sh`, `web_server_stop.sh`

Dark circuit-board aesthetic with amber/teal accents. Sections: hero (live uptime), specs (6 cards), gallery (2 photos), JavaScript demos (clock, fetch, canvas particles, localStorage, DOM animation, Web Audio), static terminal, footer.

---

## 17. Live Browser Terminal

**Folder:** `/home/petalinux/terminal/`  
**Files:** `index.html`, `style.css`, `app.js`, `terminal.js`, `terminal_server.py`, `start_all.sh`, `stop_all.sh`

### Architecture

```
Browser (xterm.js)  ←WebSocket→  terminal_server.py  ←PTY→  /bin/sh
     port 8081          port 8765         (asyncio)       (real shell)
```

### Hot-Pink Terminal Theme

Deep magenta background (#12010a), pink text (#ffb8e0), CRT scanlines, glowing border, chrome bar with connect/disconnect/minimise/maximise.

### Key Bug Fix: Doubled Characters

`term.onData()` must be registered ONCE in `initTerminal()`, never inside `termConnect()`. Each `onData` registration stacks a new listener — after N reconnects, keystrokes are sent N times (pwd → ppwwdd → pppwwwddd). Fix: single listener that checks the current `socket` variable.

### CDN Version

xterm.js 5.3.0 does not have `addon-fit` on cdnjs. Use jsDelivr with xterm 4.19.0:

```
cdn.jsdelivr.net/npm/xterm@4.19.0/css/xterm.css
cdn.jsdelivr.net/npm/xterm@4.19.0/lib/xterm.js
cdn.jsdelivr.net/npm/xterm-addon-fit@0.5.0/lib/xterm-addon-fit.js
```

### Terminal Viewport Fix

Use `height: 440px; overflow: hidden;` not `min-height: 400px` on `.term-viewport`. The ResizeObserver + FitAddon creates an infinite grow loop with min-height.

---

## 18. USB3 SuperSpeed Gadget (New XSA)

With normal GTR lane allocation (PCIe×1 + DP + SATA + USB3), the USB gadget operates at SuperSpeed (5 Gbps) — 10× faster than the previous USB2 High Speed (480 Mbps).

### Minimal system-user.dtsi

```dts
/include/ "system-conf.dtsi"
#include "zcu102-rev1.0.dtsi"
/ { chosen { myname = "Ali Mehrpooya"; }; };
&gem3 { local-mac-address = [02 00 00 00 00 01]; };
&dwc3_0 { dr_mode = "peripheral"; };
```

Everything else (psgtr clocks, USB3 phy, SATA phy, DP phy, PCIe) comes automatically from `zcu102-reva.dtsi` and `pcw.dtsi`.

### Verification

```bash
cat /sys/class/udc/fe200000.usb/maximum_speed   # super-speed
lspci                                             # NVMe visible
dmesg | grep -i sata                             # SATA probed
cat /sys/class/drm/card0-DP-1/status             # connected/disconnected
```

---

## 19. DisplayPort & Desktop Environment

### Device Tree

The `pcw.dtsi` auto-configures DP with 1 lane via psgtr lane 1. The dmesg shows `ZynqMP DisplayPort Subsystem driver probed` and `/dev/dri/card0` exists.

### Desktop Packages (petalinux-config -c rootfs)

For a minimal desktop environment, enable: `weston`, `weston-init` (Wayland), or `matchbox-desktop`, `matchbox-session-sato`, `xserver-xorg`, `packagegroup-core-x11` (X11).

### Starting the Desktop

```bash
weston --tty=1 &              # Wayland
# or
startx &                       # X11
# then
DISPLAY=:0 xrandr              # verify resolution
```

### Host + Gadget (Mouse/Keyboard Problem)

USB0 is in `dr_mode = "peripheral"` — cannot plug in mouse/keyboard. Solutions: (1) use `dr_mode = "otg"` for software-switchable mode, (2) use SSH/web terminal for input, (3) connect mouse/keyboard when temporarily in host mode.

---

## 20. PetaLinux RootFS Integration

### Recommended Method: Custom Recipe

Create a Yocto recipe in `meta-user` that installs all scripts and web files into the rootfs during build.

### Directory Structure

```
project-spec/meta-user/
  recipes-apps/
    zcu102-usb-gadgets/
      zcu102-usb-gadgets.bb
      files/
        ethernet_usb_start.sh
        ethernet_usb_stop.sh
        ethernet_usb_change_ip.sh
        nvme_usb_start.sh
        nvme_usb_stop.sh
        nvme_samba_start.sh
        nvme_samba_stop.sh
        nvme_http_start.sh
        nvme_http_stop.sh
        combined_usb_start.sh
        combined_usb_stop.sh
        serial_usb_start.sh
        serial_usb_stop.sh
        serial_terminal.sh
        serial_raw_send.sh
        serial_raw_receive.sh
        triple_usb_start.sh
        triple_usb_stop.sh
        ondm_usb_start.sh
        ondm_usb_stop.sh
        ondm_triple_start.sh
        ondm_triple_stop.sh
        over_eth_nvme_samba_start.sh
        over_eth_nvme_samba_stop.sh
        over_eth_nvme_http_start.sh
        over_eth_nvme_http_stop.sh
        over_eth_web_start.sh
        over_eth_web_stop.sh
    zcu102-webserver/
      zcu102-webserver.bb
      files/
        www/
          index.html
          style.css
          app.js
        terminal/
          index.html
          style.css
          app.js
          terminal.js
          terminal_server.py
          start_all.sh
          stop_all.sh
```

### Recipe: zcu102-usb-gadgets.bb

```text
SUMMARY = "ZCU102 USB Gadget Scripts"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://ethernet_usb_start.sh \
    file://ethernet_usb_stop.sh \
    file://ethernet_usb_change_ip.sh \
    file://nvme_usb_start.sh \
    file://nvme_usb_stop.sh \
    file://nvme_samba_start.sh \
    file://nvme_samba_stop.sh \
    file://nvme_http_start.sh \
    file://nvme_http_stop.sh \
    file://combined_usb_start.sh \
    file://combined_usb_stop.sh \
    file://serial_usb_start.sh \
    file://serial_usb_stop.sh \
    file://serial_terminal.sh \
    file://serial_raw_send.sh \
    file://serial_raw_receive.sh \
    file://triple_usb_start.sh \
    file://triple_usb_stop.sh \
    file://ondm_usb_start.sh \
    file://ondm_usb_stop.sh \
    file://ondm_triple_start.sh \
    file://ondm_triple_stop.sh \
    file://over_eth_nvme_samba_start.sh \
    file://over_eth_nvme_samba_stop.sh \
    file://over_eth_nvme_http_start.sh \
    file://over_eth_nvme_http_stop.sh \
    file://over_eth_web_start.sh \
    file://over_eth_web_stop.sh \
"

do_install() {
    install -d ${D}/home/petalinux
    for f in ${WORKDIR}/*.sh; do
        install -m 0755 ${f} ${D}/home/petalinux/
    done
}

FILES:${PN} = "/home/petalinux/*.sh"
```

### Enable in rootfs

Add to `project-spec/meta-user/conf/user-rootfsconfig`:

```
CONFIG_zcu102-usb-gadgets
CONFIG_zcu102-webserver
```

Then: `petalinux-config -c rootfs` → enable both → build.

---

## 21. Troubleshooting & Lessons Learned

### "Device or resource busy" on lun.0/ro

Set `ro`, `cdrom`, `removable` BEFORE writing `file`. Once `file` is written, the kernel locks the device.

### "Address already in use" on HTTP server

Kill existing instance: `pkill -9 -f "http.server"`. Add `pkill` to start scripts before launching.

### Stop script hangs on rmdir

Resources are still held. Fix: (1) `fuser -k /dev/ttyGS0` for serial, (2) clear `lun.0/file` for mass storage, (3) `killall smbd` for Samba.

### UDC state shows "configured" after stop

ZynqMP DWC3 hardware register retains last state. Ignore it. Check `cat /sys/class/udc/fe200000.usb/function` instead — empty means clean.

### xterm.js doubled characters

`term.onData()` registered in `termConnect()` stacks listeners. Register ONCE in `initTerminal()`.

### xterm.js FitAddon not defined

xterm 5.3.0 moved addons to separate packages. Use xterm 4.19.0 from jsDelivr or use unpkg for the addon.

### Terminal viewport grows infinitely

ResizeObserver on the same element FitAddon modifies creates a feedback loop. Use fixed `height: 440px; overflow: hidden;` and `window.addEventListener('resize')` instead.

### NTFS dirty flag

`mount -t ntfs3 -o rw,force`. On Windows, always "Eject" before disconnecting.

### Windows RNDIS "security policies block guest access"

Use Samba user auth: `smbpasswd -a petalinux`, `map to guest = never`, `valid users = petalinux`.

### Samba not found in petalinux-config -c rootfs

Add `CONFIG_samba` to `project-spec/meta-user/conf/user-rootfsconfig` (persistent file, not the auto-generated one at `project-spec/configs/rootfsconfigs/user-rootfsconfig`).

---

## 22. Script Reference

### Port Map

| Script | Port | Protocol | What host sees |
|--------|------|----------|----------------|
| ethernet_usb_start | - | USB RNDIS | NIC adapter |
| nvme_usb_start | - | USB Mass Storage | 931.5 GB drive |
| ondm_usb_start | - | USB Mass Storage | 1 GB read-only drive |
| serial_usb_start | - | USB CDC ACM | COMx serial port |
| combined_usb_start | - | USB Composite | NIC + drive |
| triple_usb_start | - | USB Composite | NIC + drive + COM |
| ondm_triple_start | - | USB Composite | NIC + 1GB drive + COM |
| over_eth_nvme_samba | 445 | SMB/CIFS | Network drive |
| over_eth_nvme_http | 8080 | HTTP | File browser |
| over_eth_web | 8081+8765 | HTTP+WebSocket | Web page + terminal |

### Script Pairing

Every start script has a matching stop. Always run them as pairs. Never mix pairs (e.g., do not use `ethernet_usb_stop.sh` to stop `triple_usb_start.sh`).
