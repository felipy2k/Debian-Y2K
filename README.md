# 🐧 Debian Y2K — Post-Install Setup Script

> An interactive post-installation script for **Debian 13 "Trixie"** with **GNOME 48**.  
> Automates repositories, codecs, drivers, apps, extensions and visual settings — through a clean modular menu.

---

## ⚠️ Before you start — Disable Secure Boot

**Secure Boot must be disabled in your BIOS/UEFI before running this script.**

The NVIDIA driver uses DKMS to build a kernel module at install time. With Secure Boot enabled, the unsigned module will be blocked from loading.

> 💡 **How to disable Secure Boot:**
> 1. Restart and enter BIOS/UEFI (`F2`, `F10`, `F12` or `Del`)
> 2. Navigate to **Security** or **Boot** tab
> 3. Set **Secure Boot** to **Disabled**
> 4. Save and exit (`F10`)

> 🔵 **No NVIDIA GPU?** You can skip this step entirely.

---

## 🚀 Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/felipy2k/Debian-Y2K/main/Debian-Y2K.sh -o Debian-Y2K.sh
bash Debian-Y2K.sh
```

> ⚠️ **Do not run as root.** The script uses `sudo` internally where needed.

---

## 📋 Menu

```
[1] Run EVERYTHING        — Full setup in the correct order
[2] Repos + Update        — Add repos and upgrade system
[3] Remove bloatware      — Remove unwanted apps
[4] Install APT packages  — Install .deb packages
[5] Install Flatpaks      — Install Flatpak apps
[6] Install NVIDIA driver — Detect GPU and install driver + CUDA
[7] Install GNOME extensions
[8] Apply visual settings — Theme, wallpaper, default apps
[9] Verify installation   — Check everything was applied
[f] Install FreeOffice    — Install FreeOffice 2024 (standalone)
[r] Restart
```

---

## 📦 What Gets Installed

### APT Packages (.deb)

| Category | Packages |
|---|---|
| **Browser** | Google Chrome |
| **Office** | FreeOffice 2024 (SoftMaker) |
| **Graphics** | Blender, Inkscape, Darktable, GIMP, ImageMagick, Drawing |
| **Video/Audio** | VLC, HandBrake, Audacity, OBS Studio, Shotcut, Shotwell |
| **System** | GNOME Boxes, Deja-dup, Easy Effects, Deskflow, Timeshift, Fastfetch |
| **Games** | Steam, DreamChess |
| **Security** | NordVPN, Tor Browser |
| **Codecs** | ffmpeg, libavcodec-extra, GStreamer plugins, libdvdread8t64 |
| **Hardware** | VA-API/VDPAU drivers, lm-sensors, v4l2loopback-dkms |
| **Misc** | Cheese, Converseen, papirus-icon-theme |

### Flatpak Apps

| App | Description |
|---|---|
| Discord | Chat and communities |
| Flatseal | Flatpak permissions manager |
| Extension Manager | GNOME extensions GUI |
| Resources | System monitor (CPU/RAM/GPU) |
| Popsicle (USB Flasher) | USB flash tool |
| Solaar | Logitech device manager |
| FreeCAD | 3D parametric CAD |
| Alpaca | Local LLM interface (Ollama) |
| Podman Desktop | Container management |
| Podcasts | GNOME podcast client |
| LocalSend | Local file transfer |
| Blanket | Ambient sounds |
| Sticky Notes | Desktop notes |
| Shortwave | Internet radio |
| Switcheroo | Image format converter |
| Exhibit | 3D model viewer |
| File Shredder | Secure file deletion |
| Upscayl | AI image upscaler |
| Cameractrls | Advanced webcam controls |
| Color Picker | Screen color picker |
| Tor Browser | Anonymous browser |

---

## 🧩 GNOME Extensions

| Extension | Description |
|---|---|
| Alphabetical App Grid | Sort app grid alphabetically |
| AppIndicator Support | System tray icons |
| Blur my Shell | Blur effect on overview and dash |
| Bring Out Submenu of Power Off | Better power menu |
| Caffeine | Prevent screen lock |
| Clipboard Indicator | Clipboard history |
| Dash to Dock | Persistent app dock |
| Edit Desktop Files | Edit `.desktop` files from the grid |
| GSConnect | KDE Connect integration |
| Just Perfection | Fine-tune GNOME Shell |
| Tiling Shell | Window tiling manager |
| Vitals | CPU, RAM, temp, network in panel |

---

## 🧹 Bloatware Removed

| Type | What goes away |
|---|---|
| **Office** | LibreOffice → replaced by FreeOffice |
| **Video** | Showtime (`gnome-showtime` APT + Flatpak), Totem |
| **Audio** | GNOME Music, Rhythmbox |
| **Mail** | Evolution, evolution-common, evolution-data-server |
| **Terminal** | GNOME Terminal → keeps **GNOME Console** (default since GNOME 46+) |
| **Other** | GNOME Tour, Weather, Maps, Yelp, dconf-editor, Piper, qjackctl |

---

## 🎨 Visual Settings

| Setting | Value |
|---|---|
| 🖼️ Icon theme | **Papirus-Dark** |
| 🌑 Color scheme | **Dark mode** |
| 🕐 Clock | Date + seconds visible |
| 🪟 Title bar | Minimize + Maximize + Close |
| 🌌 Wallpaper | Y2K wallpaper (applied automatically) |
| 🌐 Default browser | Google Chrome |
| 🎬 Default video player | **VLC** |
| 🎵 Default audio player | **VLC** |
| 👆 Chrome touchpad | Wayland + two-finger swipe gestures |

---

## 🎮 NVIDIA Driver

The script automatically detects your GPU and installs:

- `nvidia-driver` + `nvidia-kernel-dkms`
- Kernel headers (`linux-headers-$(uname -r)`) — required for DKMS
- `NVreg_PreserveVideoMemoryAllocations=1` — prevents black screen on suspend
- `nvidia-suspend`, `nvidia-hibernate`, `nvidia-resume` services enabled
- CUDA Toolkit (optional, prompted during install)

---

## ⚙️ Requirements

| | |
|---|---|
| 🐧 | **Debian 13 "Trixie"** — GNOME desktop (amd64) |
| 🌐 | Internet connection |
| 🔑 | User account with `sudo` access |
| 💾 | ~15 GB free disk space (Steam + Blender + FreeCAD are heavy) |

> **sudo not configured?** Debian doesn't set it up automatically.
> ```bash
> su -
> apt-get install -y sudo curl
> usermod -aG sudo YOUR_USERNAME
> exit
> # Log out and log back in, then run the script
> ```

---

## 📝 Notes

<details>
<summary>🟢 NVIDIA + Debian 13 — Kernel Headers Required</summary>

Debian 13 with kernel 6.12 LTS requires kernel headers to be installed **before** the NVIDIA driver. The script handles this automatically — it installs `linux-headers-$(uname -r)` first, with a fallback to `linux-headers-amd64`.

Without headers present, DKMS silently fails to compile the module and `nvidia-smi` never works even after reboot.
</details>

<details>
<summary>💤 NVIDIA Suspend / Hibernate</summary>

On Debian, the NVIDIA power management services are **disabled by default** and must be explicitly enabled. The script handles this.

`NVreg_PreserveVideoMemoryAllocations=1` is written to `/etc/modprobe.d/nvidia-power.conf` — without this parameter, resuming from suspend typically results in a black screen.
</details>

<details>
<summary>📦 FreeOffice Installation</summary>

FreeOffice is installed via the official SoftMaker installer (`softmaker.net`) which also configures the APT repository for automatic updates. Three fallback methods are attempted in order:

1. Official installer script (pipe to bash)
2. Direct `.deb` download (latest version detected automatically)
3. Manual APT repository setup

If all methods fail, the script prints the manual download URL.
</details>

<details>
<summary>🎬 VLC as Default Player</summary>

VLC is installed as a `.deb` package (APT) only — **not** as a Flatpak — to avoid duplicates in the app grid. Showtime (`gnome-showtime`) is removed via APT before VLC is set as default for all audio and video MIME types.
</details>

---

## 📜 License

MIT — feel free to fork and adapt.

---

*Adapted from [felipy2k/Fedora-Y2K](https://github.com/felipy2k/Fedora-Y2K) for Debian 13 Trixie.*
