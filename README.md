# 🐧 Debian Y2K — Post-Install Setup Script

> An interactive post-installation script for **Debian 13 "Trixie"** with **GNOME 48**.  
> Automates everything from repositories and codecs to drivers, apps, extensions, and visual settings — through a clean modular menu.

---

## ⚠️ Before you start — Disable Secure Boot

**Secure Boot must be disabled in your BIOS/UEFI before running this script.**

The NVIDIA driver uses DKMS to build a kernel module at install time. With Secure Boot enabled, the unsigned module will be blocked from loading — the system may boot without GPU acceleration or fail entirely.

> 💡 **How to disable Secure Boot:**
> 1. Restart your computer and enter BIOS/UEFI (usually `F2`, `F10`, `F12` or `Del` during boot)
> 2. Navigate to the **Security** or **Boot** tab
> 3. Find **Secure Boot** and set it to **Disabled**
> 4. Save and exit (`F10`)
> 5. Boot into Debian and run the script

> 🔵 **Don't have an NVIDIA GPU?** You can skip this step — Secure Boot won't affect the rest of the installation.

---

## 💾 Disk Space Requirements

> Sizes measured via `apt-cache` (Debian 13 / Ubuntu 24.04 equivalent packages) + Flathub published sizes.  
> Values reflect **installed size on disk**, not download size.

| 🗂️ Component | 💽 Size | 📝 Notes |
|---|---|---|
| 🎬 Codecs (ffmpeg + GStreamer stack) | ~25 MB | |
| 🌐 Browsers (Chrome + Firefox) | ~320 MB | |
| 🎬 Multimedia apps (VLC, Audacity, Darktable, HandBrake, EasyEffects, OBS) | ~200 MB | |
| 🎨 Graphics / 3D (GIMP + Inkscape + Blender) | ~200 MB | |
| 🖥️ GNOME apps + Utilities | ~250 MB | |
| 🎨 Papirus icon theme | ~195 MB | Large — hundreds of icon variants |
| 📝 FreeOffice 2024 | ~700 MB | |
| 🎮 Steam (`steam-installer` APT package) | ~1 MB | Tiny APT package — bootstraps on first launch |
| 🎮 Steam runtime (downloaded on first launch) | ~1.5 GB | Downloaded by Steam itself, not by APT |
| 📱 Flatpaks (24 apps + GNOME/KDE runtimes) | ~3.2 GB | Largest single component of the install |
| 🟢 NVIDIA driver (`nvidia-driver` + DKMS) | ~250 MB | Only if NVIDIA GPU present |
| 🧪 CUDA Toolkit — `nvcc`, cuBLAS, headers | ~4.0 GB | **Optional** — prompted during install |

### Totals

| 📦 Scenario | 💽 Disk Used | 💡 Recommended Free Space |
|---|---|---|
| Base only (APT + FreeOffice + Flatpaks, no Steam runtime) | ~4.7 GB | **8 GB** |
| + Steam runtime (typical gaming setup) | ~6.2 GB | **10 GB** |
| + NVIDIA driver | ~6.5 GB | **10 GB** |
| + CUDA Toolkit | ~10.5 GB | **15 GB** |

> ⚠️ The script checks for **15 GB free** before running option `[1] Run EVERYTHING` — this safely covers the full scenario including CUDA. If you are skipping CUDA, 10 GB is sufficient.

---

## 🚀 Quick Start

### Step 0 — Configure `sudo` (fresh Debian install only)

> ⚠️ **This step is mandatory on a fresh Debian install.**  
> Unlike Ubuntu, Debian does **not** add your user to `sudo` automatically. Without this, every `sudo` command in the script will fail with `is not in the sudoers file`.

Open a terminal and run:

```bash
su -
```

Enter your **root password** (set during Debian installation), then run:

```bash
apt-get install -y sudo curl
usermod -aG sudo YOUR_USERNAME
exit
```

> 🔄 **Log out and log back in** for the group change to take effect before continuing.

---

### Step 1 — Download and run the script

```bash
curl -fsSL https://raw.githubusercontent.com/felipy2k/Debian-Y2K/main/Debian-Y2K.sh -o Debian-Y2K.sh
bash Debian-Y2K.sh
```

Or as a single one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/felipy2k/Debian-Y2K/main/Debian-Y2K.sh | bash
```

Prefer `git`? Install it first:

```bash
sudo apt-get install -y git
git clone https://github.com/felipy2k/Debian-Y2K.git
cd debian-Y2K
bash Debian-Y2K.sh
```

> ⚠️ **Do not run as root.** The script uses `sudo` internally where needed.

---

## 🗂️ Menu

```
╔═══════════════════════════════════════════════════════════════╗
║          Debian — Custom Post-Install Setup                   ║
╠═══════════════════════════════════════════════════════════════╣
║  [1] Run EVERYTHING (recommended)                            ║
║  [2] Configure repos + update system only                    ║
║  [3] Remove bloatware only                                   ║
║  [4] Install APT packages only                               ║
║  [5] Install Flatpaks only                                   ║
║  [6] Install NVIDIA driver + CUDA only                       ║
║  [7] Install GNOME extensions only                           ║
║  [8] Apply visual settings only                              ║
║  [9] Final verification                                      ║
║  [0] Exit                                                    ║
║  [r] Exit and reboot                                         ║
╚═══════════════════════════════════════════════════════════════╝
```

**Option [1] Run EVERYTHING** — correct execution order guaranteed:

```
repos → update → APT packages → FreeOffice → Flatpaks → NVIDIA → Extensions → Remove bloat → Settings
```

---

## ✨ What gets installed

### 📦 Repositories
| | |
|---|---|
| 🔓 | `contrib`, `non-free`, `non-free-firmware` components enabled (supports both DEB822 and one-line formats) |
| 🌐 | Google Chrome (official GPG keyring + APT source) |
| 🔢 | Multiarch `i386` enabled (required for Steam) |

---

### 🎬 Multimedia Codecs

- 📦 Full `ffmpeg` (H.264, H.265, AAC, MP3 and more) — installed directly from `non-free`
- 🎛️ Complete GStreamer stack — `base`, `good`, `bad`, `ugly`, `libav`, `vaapi`
- ⚡ Hardware acceleration auto-detected by GPU:
  - 🔴 **AMD** → `mesa-va-drivers` + `mesa-vdpau-drivers` (already freeworld in Debian, no swap needed)
  - 🔵 **Intel** → `intel-media-va-driver` + `intel-media-va-driver-non-free` (Gen 11+)
  - 🟢 **NVIDIA** → handled by the dedicated driver section

---

### 🖥️ NVIDIA Driver + CUDA

- 🔍 GPU detection via PCI class codes — no false positives
- 🔐 Secure Boot detection with confirmation prompt
- 🔑 **Kernel headers installed first** — mandatory on Debian 13 + kernel 6.12 (DKMS fails without them)
- 📦 Debian `non-free`: `nvidia-driver`, `nvidia-kernel-dkms`, `nvidia-settings`, `nvidia-vaapi-driver`, `firmware-misc-nonfree`
- 🔨 Verifies DKMS module status + forces rebuild if needed (`dkms autoinstall`)
- 🔄 Regenerates initramfs (`update-initramfs -u -k all`)
- 💤 Configures `NVreg_PreserveVideoMemoryAllocations=1` — **prevents black screen on resume from suspend/hibernate**
- ⚡ Enables power services: `nvidia-suspend`, `nvidia-hibernate`, `nvidia-resume` (disabled by default in Debian)
- 🧪 Optional: full CUDA Toolkit (`nvcc`, cuBLAS, headers) via official NVIDIA repo with `cuda-keyring`
- 🟢 **GPU detected** → installs automatically
- 🟡 **GPU not detected** → explains why and asks to confirm — install proceeds if confirmed

---

### 📥 APT Packages

| 🗂️ Category | 📦 Apps |
|---|---|
| 🌐 Browsers | Firefox, Google Chrome, Tor Browser |
| 🎬 Multimedia | VLC, Audacity, Darktable, HandBrake, EasyEffects, OBS Studio |
| 🎨 Graphics / 3D | GIMP, Inkscape, Blender |
| 🎮 Gaming | Steam (`steam-installer` from `contrib`, requires multiarch i386) |
| 🖥️ GNOME Apps | Tweaks, Baobab, Déjà Dup, Boxes, Calculator, Calendar, Snapshot, Characters, Connections, Contacts, Simple Scan, Disk Utility, Text Editor, Font Viewer, Color Manager, Software, Clocks, Logs, Evince, Loupe, File Roller, **Drawing** |
| 🔧 Utilities | Timeshift, Solaar, fastfetch, pipx, DreamChess, lm-sensors, Deskflow |
| 🛡️ VPN | **NordVPN** CLI + GUI (official installer, daemon enabled, user added to group) |
| 📝 Office | FreeOffice 2024 (official SoftMaker installer — auto-detects Debian) |

---

### 📱 Flatpaks (Flathub)

| 🗂️ Category | 📦 Apps |
|---|---|
| 🔧 System | Extension Manager, Resources, Flatseal, Popsicle, File Shredder (Raider), LocalSend, Switcheroo, Podman Desktop |
| 🎬 Multimedia | Shotcut, Video Trimmer, Camera Ctrls, Converseen |
| 🧠 Productivity | FreeCAD, Upscayl, Exhibit (3D Viewer), Minder, Motrix |
| 🎵 Entertainment | Blanket, Shortwave, Podcasts, Gcolor3, Sticky Notes, Alpaca, **Discord** |

---

### 🧩 GNOME Extensions

| 🔌 Extension | 📋 Purpose |
|---|---|
| AlphabeticalAppGrid | Sorts app grid alphabetically |
| AppIndicator Support | System tray icons |
| Blur my Shell | Blur effect on panel, dash and overview |
| Bring Out Submenu Of Power Off Button | Expands power menu options |
| Caffeine | Prevent sleep/suspend |
| Clipboard Indicator | Clipboard history manager |
| Dash to Dock | Persistent app dock |
| Edit Desktop Files | Edit `.desktop` files from the app grid |
| GSConnect | KDE Connect integration for GNOME |
| Just Perfection | Fine-tune GNOME Shell elements |
| Tiling Shell | Window tiling manager |
| Vitals | CPU, RAM, temp, fan, network in panel (uses `lm-sensors`) |

---

### 🎯 Default Apps & Settings

| ⚙️ Setting | 🎯 Value |
|---|---|
| 🌐 Web browser | Google Chrome |
| 🎬 Video player | VLC (via xdg-mime + gio mime + mimeapps.list) |
| 🎵 Audio player | VLC (same 3-method approach) |
| 🪟 Title bar | Minimize + Maximize + Close (right side) |
| 🚀 Dock | Chrome · Files · Text Editor · GNOME Console · Calculator · App Grid |
| 👆 Chrome touchpad | Two-finger swipe back/forward (Wayland flags) |

---

### 🧹 Bloatware Removed

| ❌ Type | 🗑️ What goes away |
|---|---|
| 📝 Office | LibreOffice → replaced by FreeOffice |
| 🎬 Video | Totem, totem-video-thumbnailer |
| 🎵 Audio | GNOME Music, Rhythmbox |
| 💻 Terminal | GNOME Terminal → keeps **GNOME Console** (default since GNOME 46+) |
| 🧩 Extensions | gnome-shell-extension-prefs → replaced by Extension Manager Flatpak |
| 🗑️ Other | Cheese, GNOME Tour, Weather, Maps, Yelp, dconf-editor, htop, Piper, qjackctl, jackd2 |

---

### 🎨 Visual Settings

| 🎨 | |
|---|---|
| 🖼️ | Icon theme: **Papirus** |
| 🌑 | Color scheme: **Dark mode** |
| 🕐 | Clock with date and seconds |
| 🪟 | Minimize + Maximize buttons on title bar |
| 🚀 | Dock shortcuts configured |
| 👆 | Chrome Wayland touchpad gestures |
| 🌌 | Wallpaper applied automatically |

![Wallpaper Preview](https://raw.githubusercontent.com/felipy2k/Fedora-Y2K/main/Y2K_Wallpaper.jpeg)

---

## ⚙️ Requirements

| | |
|---|---|
| 🐧 | **Debian 13 "Trixie"** — GNOME desktop (amd64) |
| 🌐 | Internet connection |
| 🔑 | User account with `sudo` access |
| 💾 | ~15 GB free disk space (Steam + Blender + CUDA) |

> ⚠️ **`sudo` not configured?** Unlike Ubuntu, Debian does not add the first user to `sudo` automatically during installation. If you get `felipe is not in the sudoers file`, fix it first:
>
> ```bash
> su -                                   # log in as root (password set during install)
> apt-get install -y sudo curl
> usermod -aG sudo YOUR_USERNAME
> exit                                   # back to your user
> ```
> Then **log out and log back in** for the group change to take effect. After that, `sudo` and `curl` will work normally.

---

## 📝 Important Notes

<details>
<summary>🟢 NVIDIA + Debian 13 — Kernel Headers Required</summary>

Unlike previous Debian versions, **Debian 13 with kernel 6.12 LTS requires kernel headers to be installed before the NVIDIA driver**. The script handles this automatically — it installs `linux-headers-$(uname -r)` first, with a fallback to the `linux-headers-amd64` meta-package if the specific version isn't found.

Without headers present, DKMS silently fails to compile the module and `nvidia-smi` never works even after reboot.
</details>

<details>
<summary>💤 NVIDIA Suspend / Hibernate</summary>

On Debian, the NVIDIA power management services (`nvidia-suspend`, `nvidia-hibernate`, `nvidia-resume`) are **disabled by default** and must be explicitly enabled. The script handles this.

Additionally, `NVreg_PreserveVideoMemoryAllocations=1` is written to `/etc/modprobe.d/nvidia-power.conf` — without this parameter, resuming from suspend typically results in a black screen.
</details>

<details>
<summary>🟢 NVIDIA GPU not detected?</summary>

This can happen when booting with the onboard/integrated GPU, or when pre-installing the driver before the card is physically inserted. The script detects this, explains it, and asks for confirmation — just say `y` and the driver installs normally. Typical workflow: install driver → reboot → switch to NVIDIA in BIOS.
</details>

<details>
<summary>🧪 CUDA Toolkit</summary>

The Debian `non-free` driver already includes CUDA runtime support for apps (Blender, OBS, etc.). The full Toolkit (`nvcc`, cuBLAS, headers) is optional — installed from the official NVIDIA repo via `cuda-keyring` upon confirmation.
</details>

<details>
<summary>🎮 Steam on Debian 13</summary>

Steam is installed as `steam-installer` from the `contrib` repository — not `non-free`. Multiarch i386 (`dpkg --add-architecture i386`) is enabled automatically in the repos step, before Steam is installed. On first launch, Steam downloads and installs its own bootstrap runtime.
</details>

<details>
<summary>🔓 Repositories — DEB822 vs one-line format</summary>

Debian 13 uses the new DEB822 format (`/etc/apt/sources.list.d/debian.sources`) by default. The script detects which format is present and adds `contrib`, `non-free`, and `non-free-firmware` components accordingly. If neither file is found, a new DEB822 file is created from scratch.
</details>

<details>
<summary>🛡️ NordVPN</summary>

Installed via the official NordVPN installer (`downloads.nordcdn.com`) — handles repo, GPG key, and packages in one step. Auto-detects Debian and installs the `.deb` package. Both **CLI and GUI** are installed (`-p nordvpn-gui`). The `nordvpnd` daemon is enabled and your user is added to the `nordvpn` group. After install: `nordvpn login`. For immediate use without logout: `newgrp nordvpn`.
</details>

<details>
<summary>🎬 VLC as default player</summary>

GNOME's system-level `gnome-mimeapps.list` can override user settings. The script uses **three methods simultaneously** — `xdg-mime`, `gio mime`, and direct `~/.config/mimeapps.list` writes — covering 19 MIME types.
</details>

<details>
<summary>👆 Chrome touchpad gestures</summary>

Writes `--ozone-platform=wayland` and `--enable-features=TouchpadOverscrollHistoryNavigation` to `~/.config/chrome-flags.conf` and a user-level `.desktop` copy. Idempotent — safe to re-run.
</details>

<details>
<summary>🛡️ Reliability & recovery</summary>

- 📋 **Logging** — timestamped log saved to `~/debian-y2k-YYYYMMDD-HHMMSS.log`
- 🔒 **Grouped installs** — independent APT groups; failures are isolated and visible
- 💾 **Package backup** — full `dpkg -l` list saved before bloat removal
- 💿 **Disk space check** — warns if less than 15 GB free
- 📊 **Final summary** — total warnings + log path
- 🔄 **Idempotent** — safe to re-run; already-applied changes are detected and skipped
- 🛡️ **Non-blocking** — `try()` wraps every command; failures log warnings and never abort
</details>

---

*Made with ❤️ for Debian users*
