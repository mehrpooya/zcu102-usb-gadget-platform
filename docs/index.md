# ZCU102 USB Gadget Platform

**PetaLinux reference design for the AMD Zynq™ UltraScale+™ MPSoC ZCU102 Evaluation Board**

| | |
|---|---|
| **Author** | Ali Mehrpooya — Smart Internet Lab (HPN Group), University of Bristol |
| **Board** | ZCU102 Rev 1.0 (XCZU9EG-2FFVB1156E) |
| **Platform** | PetaLinux 2024.1 · Linux 6.6.10-xilinx · Vivado 2024.1 |
| **Status** | Validated on hardware |

---

This project turns the AMD ZCU102 evaluation board into a **multi-function USB peripheral**.
Over a single USB cable, the board simultaneously presents itself to a host PC as a network
adapter, a mass-storage drive, and a serial console — while also serving a live web dashboard
and an interactive browser-based terminal from the board itself.

```{toctree}
:maxdepth: 2
:caption: Documentation

tutorial
```

```{toctree}
:maxdepth: 1
:caption: Project

GitHub Repository <https://github.com/mehrpooya/zcu102-usb-gadget-platform>
```

## Quick navigation

Use the sidebar to browse all 22 sections of the tutorial, or jump directly to:

- **[Full tutorial](tutorial.md)** — start here
- **Sections:** Project Overview · Hardware · FSBL/GTR · Device Tree · PCIe/NVMe ·
  USB Gadget (Ethernet, Storage, Serial, Composite) · Samba · HTTP · Web Server ·
  Browser Terminal · USB3 SuperSpeed · DisplayPort · PetaLinux · Troubleshooting · Scripts
