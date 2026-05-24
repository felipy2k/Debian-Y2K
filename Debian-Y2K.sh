#!/usr/bin/env bash

# =============================================================================
# Debian 13 (Trixie) — Custom Post-Install Setup
# Adapted from: felipy2k/Fedora-Y2K
# Tested against: Debian 13.x GNOME (amd64)
# =============================================================================

set -uo pipefail

# ── Logging — timestamped log in $HOME ──
LOG_FILE="$HOME/debian-y2k-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "\n${GREEN}▶ $*${NC}"; }
step()    { echo -e "  ${CYAN}→ $*${NC}"; }
warning() { echo -e "  ${YELLOW}⚠ $*${NC}"; ((WARN_COUNT++)) || true; }
fail()    { echo -e "${RED}✗ $*${NC}"; }
ok()      { echo -e "  ${GREEN}✓ $*${NC}"; }

WARN_COUNT=0

# ── try() — tolerância a falhas, nunca aborta o script ──
try() {
  set +e
  "$@"
  local rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    warning "Failed (exit $rc), continuing: $*"
  fi
  return 0
}

# ── Verificações iniciais ──
if [[ "$EUID" -eq 0 ]]; then
  fail "Não execute como root. Use um usuário regular com sudo."
  exit 1
fi

# ── Verifica acesso sudo ANTES de qualquer coisa ──
# No Debian, diferente do Ubuntu, o usuário NÃO é adicionado ao sudo
# automaticamente na instalação. Sem isso, todos os comandos vão falhar.
if ! sudo -n true 2>/dev/null; then
  if ! sudo true 2>/dev/null; then
    echo ""
    fail "Usuário \'$USER\' não tem acesso ao sudo."
    echo ""
    echo -e "${YELLOW}  No Debian, o sudo não é configurado automaticamente.${NC}"
    echo -e "${YELLOW}  Corrija isso ANTES de rodar o script:${NC}"
    echo ""
    echo -e "${CYAN}  1. Abra um novo terminal e entre como root:${NC}"
    echo -e "     ${BOLD}su -${NC}"
    echo ""
    echo -e "${CYAN}  2. Adicione seu usuário ao sudo e instale o curl:${NC}"
    echo -e "     ${BOLD}apt-get install -y sudo curl${NC}"
    echo -e "     ${BOLD}usermod -aG sudo ${USER}${NC}"
    echo -e "     ${BOLD}exit${NC}"
    echo ""
    echo -e "${CYAN}  3. Faça logout e login novamente, depois rode o script outra vez.${NC}"
    echo ""
    exit 1
  fi
fi

if ! grep -qi 'debian' /etc/os-release 2>/dev/null; then
  fail "Este script foi feito para Debian. Sistema detectado não é Debian."
  exit 1
fi

# Detecta versão e codename do Debian
# shellcheck source=/dev/null
. /etc/os-release
DEBIAN_CODENAME="${VERSION_CODENAME:-trixie}"
DEBIAN_VER="${VERSION_ID:-13}"
ARCH="$(dpkg --print-architecture)"

# ─────────────────────────────────────────────
# MENU
# ─────────────────────────────────────────────
show_menu() {
  clear
  echo -e "${BOLD}${BLUE}"
  echo "╔═══════════════════════════════════════════════════════════════╗"
  echo "║          Debian — Custom Post-Install Setup                   ║"
  echo "║          User: ${USER}                                        ║"
  echo "╠═══════════════════════════════════════════════════════════════╣"
  echo "║  [1] Run EVERYTHING (recommended)                            ║"
  echo "║  [2] Configure repos + update system only                    ║"
  echo "║  [3] Remove bloatware only                                   ║"
  echo "║  [4] Install APT packages only                               ║"
  echo "║  [5] Install Flatpaks only                                   ║"
  echo "║  [6] Install NVIDIA driver + CUDA only                       ║"
  echo "║  [7] Install GNOME extensions only                           ║"
  echo "║  [8] Apply visual settings only                              ║"
  echo "║  [9] Final verification                                      ║"
  echo "║  [0] Exit                                                    ║"
  echo "║  [r] Exit and reboot the system                              ║"
  echo "╚═══════════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  read -rp "  Choose an option: " CHOICE
}

# ─────────────────────────────────────────────
# REPOS — Debian 13 Trixie
# ─────────────────────────────────────────────
add_repos() {
  info "[REPOS] Configurando repositórios"

  # ── Habilita contrib, non-free e non-free-firmware ──
  # Debian 13 usa formato DEB822 em /etc/apt/sources.list.d/debian.sources
  # Fallback: formato one-line em /etc/apt/sources.list
  step "Habilitando contrib, non-free e non-free-firmware"

  SOURCES_DEB822="/etc/apt/sources.list.d/debian.sources"
  SOURCES_LIST="/etc/apt/sources.list"

  if [[ -f "$SOURCES_DEB822" ]]; then
    # Formato DEB822: linha "Components: main" → adiciona componentes ausentes
    for component in contrib non-free non-free-firmware; do
      if ! grep -q "$component" "$SOURCES_DEB822" 2>/dev/null; then
        try sudo sed -i \
          "s/^Components: \(.*\)/Components: \1 ${component}/" \
          "$SOURCES_DEB822"
        ok "Componente '$component' adicionado a $SOURCES_DEB822"
      else
        ok "'$component' já habilitado."
      fi
    done
  elif [[ -f "$SOURCES_LIST" ]]; then
    # Formato one-line: adiciona componentes nas linhas deb existentes
    for component in contrib non-free non-free-firmware; do
      if ! grep -q "$component" "$SOURCES_LIST" 2>/dev/null; then
        try sudo sed -i \
          "/^deb .*${DEBIAN_CODENAME}.* main/ s/$/ ${component}/" \
          "$SOURCES_LIST"
        ok "Componente '$component' adicionado a $SOURCES_LIST"
      else
        ok "'$component' já habilitado."
      fi
    done
  else
    warning "Arquivo de sources não encontrado. Criando /etc/apt/sources.list.d/debian-full.sources"
    sudo tee /etc/apt/sources.list.d/debian-full.sources > /dev/null <<EOF
Types: deb
URIs: http://deb.debian.org/debian
Suites: ${DEBIAN_CODENAME} ${DEBIAN_CODENAME}-updates
Components: main contrib non-free non-free-firmware

Types: deb
URIs: http://security.debian.org/debian-security
Suites: ${DEBIAN_CODENAME}-security
Components: main contrib non-free non-free-firmware
EOF
  fi

  # ── Google Chrome ──
  step "Google Chrome (repositório oficial)"
  if [[ ! -f /etc/apt/sources.list.d/google-chrome.list ]]; then
    if curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
        | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg 2>/dev/null; then
      echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] \
https://dl.google.com/linux/chrome/deb/ stable main" \
        | sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null
      ok "Repositório Chrome adicionado."
    else
      warning "Falha ao adicionar chave GPG do Chrome."
    fi
  else
    ok "Repositório Chrome já existe."
  fi

  # ── Multiarch i386 — obrigatório para Steam ──
  step "Habilitando multiarch i386 (obrigatório para Steam)"
  try sudo dpkg --add-architecture i386

  try sudo apt-get update -y
}

# ─────────────────────────────────────────────
# SYSTEM UPDATE
# ─────────────────────────────────────────────
update_system() {
  info "[SYSTEM] Atualizando o sistema"
  # full-upgrade resolve dependências de forma mais completa que upgrade
  try sudo apt-get full-upgrade -y
}

# ─────────────────────────────────────────────
# CODECS — Debian 13 Trixie
# Requer: non-free habilitado (MP3/GStreamer-ugly)
# ─────────────────────────────────────────────
install_codecs() {
  info "[CODECS] Instalando codecs multimídia"

  step "FFmpeg (completo com codecs proprietários)"
  try sudo apt-get install -y ffmpeg

  step "GStreamer stack completo"
  try sudo apt-get install -y \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    gstreamer1.0-vaapi \
    lame

  step "Aceleração de vídeo por hardware (VA-API / VDPAU)"
  # AMD: drivers Mesa já incluem VA-API no Debian (sem swap necessário)
  if lspci -d ::0300 -d ::0302 -d ::0380 2>/dev/null | grep -qi 'amd\|radeon\|ati'; then
    step "GPU AMD detectada — instalando mesa VA-API/VDPAU"
    try sudo apt-get install -y \
      mesa-va-drivers mesa-vdpau-drivers libva-drm2
  fi

  # Intel: driver VA-API (gen8+)
  if lspci -d ::0300 -d ::0302 -d ::0380 2>/dev/null | grep -qi 'intel'; then
    step "GPU Intel detectada — instalando intel-media-va-driver"
    try sudo apt-get install -y intel-media-va-driver libva-drm2
    # Gen 11+ (Ice Lake, Tiger Lake, etc.) pode precisar da versão non-free
    try sudo apt-get install -y intel-media-va-driver-non-free 2>/dev/null || true
  fi
}

# ─────────────────────────────────────────────
# APT PACKAGES
# Instala TUDO antes de remover qualquer coisa
# ─────────────────────────────────────────────
install_packages() {
  info "[APT] Instalando pacotes"

  install_codecs

  step "Base tools"
  try sudo apt-get install -y \
    git wget curl flatpak pipx fastfetch papirus-icon-theme \
    apt-transport-https ca-certificates gnupg

  step "Browsers"
  try sudo apt-get install -y \
    google-chrome-stable firefox torbrowser-launcher

  step "Aplicativos multimídia"
  try sudo apt-get install -y \
    vlc audacity darktable handbrake easyeffects obs-studio

  # obs-studio precisa de linux-headers para compilar v4l2loopback-dkms
  step "Dependências OBS Studio (headers do kernel)"
  try sudo apt-get install -y \
    "linux-headers-$(uname -r)" v4l2loopback-dkms

  step "Gráficos / 3D"
  try sudo apt-get install -y \
    gimp inkscape blender

  step "Gaming — Steam (requer multiarch i386)"
  # steam-installer: meta-package em 'contrib'
  # Nota: ao primeiro launch, Steam baixa o bootstrap automaticamente
  try sudo apt-get install -y steam-installer

  step "Apps GNOME"
  try sudo apt-get install -y \
    gnome-tweaks baobab nautilus deja-dup gnome-boxes gnome-calculator \
    gnome-calendar gnome-snapshot gnome-characters gnome-connections \
    gnome-contacts simple-scan gnome-disk-utility gnome-text-editor \
    gnome-font-viewer gnome-color-manager gnome-software gnome-clocks \
    gnome-logs evince loupe file-roller drawing

  step "Utilitários"
  try sudo apt-get install -y \
    timeshift solaar dreamchess lm-sensors deskflow

  # ── NordVPN — instalador oficial (detecta Debian automaticamente) ──
  step "NordVPN"
  if ! command -v nordvpn &>/dev/null; then
    if curl -sSf --max-time 10 -o /dev/null https://downloads.nordcdn.com/apps/linux/install.sh 2>/dev/null; then
      step "Executando instalador oficial NordVPN (CLI + GUI)"
      if sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh) -p nordvpn-gui; then
        ok "NordVPN instalado."
        try sudo systemctl enable --now nordvpnd
        try sudo usermod -aG nordvpn "$USER"
        ok "Faça login com: nordvpn login"
        warning "Associação ao grupo requer logout/reboot. Para uso imediato: newgrp nordvpn"
      else
        warning "Instalador NordVPN falhou. Tente manualmente após reboot:"
        echo "  sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)"
      fi
    else
      warning "Sem acesso a nordcdn.com — pulando NordVPN."
    fi
  else
    ok "NordVPN já instalado (pulando)."
  fi
}

# ─────────────────────────────────────────────
# FREEOFFICE — Substitui LibreOffice
# ─────────────────────────────────────────────
install_freeoffice() {
  info "[FREEOFFICE] Instalando FreeOffice 2024"

  if ! curl -fsSL --max-time 5 -o /dev/null \
      https://softmaker.net/down/install-softmaker-freeoffice-2024.sh 2>/dev/null; then
    warning "Sem acesso a softmaker.net — pulando FreeOffice."
    warning "Instale manualmente quando conectado:"
    echo "  curl -fsSL https://softmaker.net/down/install-softmaker-freeoffice-2024.sh | sudo bash"
    return
  fi

  step "Baixando e executando instalador oficial"
  if curl -fsSL https://softmaker.net/down/install-softmaker-freeoffice-2024.sh | sudo bash; then
    ok "FreeOffice instalado com sucesso."
  else
    warning "Falha ao instalar FreeOffice. Tente manualmente:"
    echo "  curl -fsSL https://softmaker.net/down/install-softmaker-freeoffice-2024.sh | sudo bash"
  fi
}

# ─────────────────────────────────────────────
# FLATPAKS
# ─────────────────────────────────────────────
install_flatpaks() {
  info "[FLATPAK] Instalando apps do Flathub"

  try flatpak remote-add --if-not-exists flathub \
    https://flathub.org/repo/flathub.flatpakrepo

  FLATPAK_IDS=(
    # Utilitários do sistema
    com.mattjakeman.ExtensionManager        # GNOME Extension Manager
    net.nokyan.Resources                    # Monitor de recursos
    com.github.tchx84.Flatseal              # Gerenciador de permissões Flatpak
    com.system76.Popsicle                   # Flash de imagens USB
    com.github.ADBeveridge.Raider           # Destruidor de arquivos
    org.localsend.localsend_app             # LocalSend (compartilhamento LAN)
    io.gitlab.adhami3310.Converter          # Switcheroo (conversor de imagens)
    io.podman_desktop.PodmanDesktop         # Podman Desktop (containers)

    # Multimídia
    org.shotcut.Shotcut                     # Editor de vídeo
    org.gnome.gitlab.YaLTeR.VideoTrimmer    # Cortador de vídeo
    hu.irl.cameractrls                      # Controles de câmera
    net.fasterland.converseen               # Conversor de imagens em lote

    # Produtividade / Criatividade
    org.freecad.FreeCAD                     # CAD 3D
    org.upscayl.Upscayl                     # Upscaler de imagens por IA
    io.github.nokse22.Exhibit               # Visualizador de modelos 3D
    com.github.phase1geo.Minder             # Mapa mental
    com.motrix.Motrix                       # Gerenciador de downloads

    # Entretenimento / Som / Outros
    com.discordapp.Discord                  # Discord
    com.rafaelmardojai.Blanket              # Sons ambiente
    de.haeckerfelix.Shortwave               # Rádio pela internet
    org.gnome.Podcasts                      # Podcasts
    nl.hjdskes.gcolor3                      # Seletor de cores
    com.vixalien.sticky                     # Notas adesivas
    com.jeffser.Alpaca                      # Alpaca (LLM local)
  )

  for app in "${FLATPAK_IDS[@]}"; do
    app="${app%%#*}"
    app="${app//[[:space:]]/}"
    [[ -z "$app" ]] && continue
    step "$app"
    try flatpak install -y flathub "$app"
  done
}

# ─────────────────────────────────────────────
# NVIDIA — lógica interna de instalação
# ─────────────────────────────────────────────
_nvidia_do_install() {

  # ── Secure Boot ──
  if command -v mokutil &>/dev/null && mokutil --sb-state 2>/dev/null | grep -qi enabled; then
    warning "Secure Boot está HABILITADO."
    warning "Após a instalação, talvez precise cadastrar a chave MOK do DKMS."
    warning "Veja: https://wiki.debian.org/SecureBoot"
    read -rp "  Continuar mesmo assim? [y/N]: " SB_CONFIRM
    [[ "${SB_CONFIRM,,}" != "y" ]] && { warning "Instalação NVIDIA cancelada."; return; }
  fi

  # ── CRÍTICO: kernel headers devem ser instalados ANTES do nvidia-driver ──
  # No Debian 13 + kernel 6.12, o DKMS falha sem os headers presentes.
  step "Instalando kernel headers (obrigatório para DKMS compilar o módulo)"
  KERNEL_VER="$(uname -r)"
  if sudo apt-get install -y "linux-headers-${KERNEL_VER}" 2>/dev/null; then
    ok "Headers instalados para kernel ${KERNEL_VER}"
  else
    # Fallback: meta-package que segue o kernel padrão do Debian
    warning "Headers específicos não encontrados. Tentando meta-package linux-headers-amd64"
    try sudo apt-get install -y linux-headers-amd64
  fi

  step "Instalando driver NVIDIA (Debian non-free: nvidia-driver + nvidia-kernel-dkms)"
  try sudo apt-get install -y \
    nvidia-driver \
    nvidia-kernel-dkms \
    nvidia-settings \
    firmware-misc-nonfree \
    libva-utils \
    vdpauinfo

  # nvidia-vaapi-driver: bridge VA-API→NVDEC (opcional, pode não existir em todas versões)
  step "Driver NVIDIA VA-API (opcional)"
  try sudo apt-get install -y nvidia-vaapi-driver 2>/dev/null || \
    warning "nvidia-vaapi-driver não disponível — pulando (não-crítico)."

  # ── Verifica resultado do DKMS ──
  step "Verificando status do DKMS"
  if command -v dkms &>/dev/null; then
    DKMS_STATUS="$(dkms status 2>/dev/null | grep -i nvidia || true)"
    if [[ -n "$DKMS_STATUS" ]]; then
      ok "DKMS NVIDIA: $DKMS_STATUS"
      if ! echo "$DKMS_STATUS" | grep -qi 'installed'; then
        warning "Módulo DKMS não está com status 'installed'. Forçando rebuild:"
        try sudo dkms autoinstall
      fi
    else
      warning "Módulo DKMS NVIDIA ainda não aparece. Pode precisar de reboot para finalizar."
    fi
  fi

  # ── Parâmetro obrigatório para suspend/hibernate funcionar ──
  step "Configurando NVreg_PreserveVideoMemoryAllocations (necessário para hibernate/suspend)"
  MODPROBE_CONF="/etc/modprobe.d/nvidia-power.conf"
  if [[ ! -f "$MODPROBE_CONF" ]]; then
    sudo tee "$MODPROBE_CONF" > /dev/null <<'EOF'
# Necessário para suspend/resume funcionar com NVIDIA no Debian
# Sem isso, a tela pode ficar preta ao retornar do suspend
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EOF
    ok "Parâmetro NVreg_PreserveVideoMemoryAllocations=1 configurado."
  else
    ok "Arquivo de configuração NVIDIA modprobe já existe."
  fi

  step "Regenerando initramfs"
  try sudo update-initramfs -u -k all

  # ── Serviços de power management ──
  # No Debian, estes serviços são DESABILITADOS por padrão — precisam ser ativados
  step "Habilitando serviços de gerenciamento de energia NVIDIA"
  try sudo systemctl enable nvidia-suspend.service
  try sudo systemctl enable nvidia-hibernate.service
  try sudo systemctl enable nvidia-resume.service
  ok "Serviços nvidia-suspend/hibernate/resume habilitados."

  # ── CUDA Toolkit (opcional) ──
  echo
  echo -e "${BOLD}── Full CUDA Toolkit? ──${NC}"
  echo "O driver já fornece suporte CUDA para apps (Blender, OBS, etc.)."
  echo "O CUDA Toolkit completo (nvcc, cuBLAS, headers) requer o repositório oficial NVIDIA."
  read -rp "  Adicionar o repositório NVIDIA CUDA para Debian ${DEBIAN_VER}? [y/N]: " CUDA_CONFIRM

  if [[ "${CUDA_CONFIRM,,}" == "y" ]]; then
    CUDA_KEYRING_URL="https://developer.download.nvidia.com/compute/cuda/repos/debian${DEBIAN_VER}/${ARCH}/cuda-keyring_1.1-1_all.deb"
    step "Baixando cuda-keyring de: $CUDA_KEYRING_URL"
    if curl -fsSL "$CUDA_KEYRING_URL" -o /tmp/cuda-keyring.deb 2>/dev/null; then
      try sudo dpkg -i /tmp/cuda-keyring.deb
      try sudo apt-get update -y
      step "Instalando cuda-toolkit (nvcc, libs, headers)"
      try sudo apt-get install -y cuda-toolkit
      ok "CUDA Toolkit instalado. Execute 'nvcc --version' após reboot."
    else
      warning "Não foi possível baixar o cuda-keyring."
      warning "Verifique a URL manualmente: https://developer.nvidia.com/cuda-downloads"
      warning "Selecione: Linux → x86_64 → Debian → ${DEBIAN_VER} → deb (network)"
    fi
  else
    ok "Suporte CUDA apenas pelo driver (sem nvcc). Suficiente para a maioria das aplicações."
  fi

  ok "Driver NVIDIA instalado. Reboot necessário para carregar o módulo do kernel."
}

# ─────────────────────────────────────────────
# NVIDIA + CUDA — detecção e confirmação
# ─────────────────────────────────────────────
install_nvidia() {
  info "[NVIDIA] Detectando GPU"

  if lspci -d ::0300 -d ::0302 -d ::0380 2>/dev/null | grep -qi nvidia; then
    GPU_INFO="$(lspci -d ::0300 -d ::0302 -d ::0380 2>/dev/null \
      | grep -i nvidia | head -1)"
    ok "GPU NVIDIA detectada: $GPU_INFO"
    _nvidia_do_install
    return
  fi

  # GPU não detectada — pode ser desktop com GPU integrada ativa
  warning "Nenhuma GPU NVIDIA detectada via lspci."
  echo -e "  ${CYAN}Isso pode acontecer quando:"
  echo -e "  • Inicializando com GPU integrada/onboard enquanto a NVIDIA está presente"
  echo -e "  • Instalando o driver antes de colocar a placa fisicamente${NC}"
  echo
  read -rp "  Instalar driver NVIDIA mesmo assim? [y/N]: " FORCE_CONFIRM
  if [[ "${FORCE_CONFIRM,,}" == "y" ]]; then
    _nvidia_do_install
  else
    ok "Instalação NVIDIA ignorada."
  fi
}

# ─────────────────────────────────────────────
# GNOME EXTENSIONS
# ─────────────────────────────────────────────
install_gnome_extensions() {
  info "[EXTENSIONS] Instalando extensões GNOME"

  export PATH="$HOME/.local/bin:$PATH"

  if ! command -v gext &>/dev/null; then
    step "Instalando gnome-extensions-cli via pipx"
    try pipx install gnome-extensions-cli
    export PATH="$HOME/.local/bin:$PATH"
  fi

  EXTENSIONS=(
    AlphabeticalAppGrid@stuarthayhurst
    appindicatorsupport@rgcjonas.gmail.com
    blur-my-shell@aunetx
    BringOutSubmenuOfPowerOffLogoutButton@pratap.fastmail.fm
    caffeine@patapon.info
    clipboard-indicator@tudmotu.com
    dash-to-dock@micxgx.gmail.com
    editdesktopfiles@dannflower
    gsconnect@andyholmes.github.io
    just-perfection-desktop@just-perfection
    tilingshell@ferrarodomenico.com
    Vitals@CoreCoding.com
  )

  if command -v gext &>/dev/null; then
    for ext in "${EXTENSIONS[@]}"; do
      ext="${ext%%#*}"
      ext="${ext//[[:space:]]/}"
      [[ -z "$ext" ]] && continue
      step "$ext"
      try gext install "$ext"
      try gext enable "$ext"
    done
    ok "Extensões instaladas. Algumas podem apresentar erro até a próxima atualização do GNOME Shell."
  else
    warning "gext não disponível. Instale manualmente via Extension Manager."
    printf '    - %s\n' "${EXTENSIONS[@]}"
  fi
}

# ─────────────────────────────────────────────
# REMOÇÃO DE BLOATWARE
# Executar APÓS instalar tudo para evitar
# quebra de dependências
# ─────────────────────────────────────────────
remove_bloat() {
  info "[CLEANUP] Removendo bloatware"
  warning "Execute este passo APÓS instalar tudo para evitar problemas de dependência."

  # Backup da lista de pacotes instalados (auxílio à recuperação)
  BACKUP_FILE="$HOME/debian-y2k-packages-before-cleanup-$(date +%Y%m%d-%H%M%S).txt"
  step "Salvando lista de pacotes em $BACKUP_FILE"
  if dpkg -l | grep '^ii' | awk '{print $2}' > "$BACKUP_FILE" 2>/dev/null; then
    ok "Backup salvo (restaurar com: xargs sudo apt-get install -y < $BACKUP_FILE)"
  else
    warning "Falha ao salvar backup."
  fi

  step "Removendo LibreOffice (substituído pelo FreeOffice)"
  try sudo apt-get remove -y --purge 'libreoffice*'

  step "Removendo players de mídia padrão do GNOME (substituídos pelo VLC)"
  # Debian 13 GNOME 48: gnome-music (substituiu Rhythmbox), totem
  for pkg in gnome-music rhythmbox totem totem-video-thumbnailer; do
    if dpkg -s "$pkg" &>/dev/null; then
      try sudo apt-get remove -y --purge "$pkg"
    fi
  done

  step "Removendo terminal duplicado (mantendo GNOME Console, padrão desde GNOME 46+)"
  # gnome-terminal pode não estar instalado no Debian 13 GNOME — try() garante continuidade
  try sudo apt-get remove -y --purge gnome-terminal 2>/dev/null || true

  step "Removendo gerenciador de extensões RPM (substituído pelo Extension Manager Flatpak)"
  # Em Debian o pacote pode ter nome diferente conforme a versão
  for pkg in gnome-shell-extension-prefs gnome-extensions-app; do
    dpkg -s "$pkg" &>/dev/null && \
      try sudo apt-get remove -y --purge "$pkg" || true
  done

  step "Removendo apps desnecessários"
  for pkg in \
    cheese gnome-tour gnome-weather gnome-maps yelp dconf-editor \
    htop piper qjackctl jackd2; do
    dpkg -s "$pkg" &>/dev/null && \
      try sudo apt-get remove -y --purge "$pkg" || true
  done

  step "Removendo Flatpaks desnecessários (se instalados)"
  for app in \
    org.gnome.Totem \
    org.gnome.Music \
    org.freedesktop.Piper \
    org.gnome.Help; do
    try flatpak uninstall -y "$app" 2>/dev/null || true
  done

  step "Limpando dependências órfãs"
  try sudo apt-get autoremove -y
  try sudo apt-get autoclean

  ok "Limpeza concluída."
}

# ─────────────────────────────────────────────
# VISUAL SETTINGS & DEFAULT APPS
# gsettings/xdg-mime são agnósticos de distro —
# este bloco funciona igual ao Fedora
# ─────────────────────────────────────────────
apply_settings() {
  info "[SETTINGS] Aplicando configurações GNOME e apps padrão"

  # ── Aparência ──
  try gsettings set org.gnome.desktop.interface icon-theme         'Papirus'
  try gsettings set org.gnome.desktop.interface color-scheme       'prefer-dark'
  try gsettings set org.gnome.desktop.interface clock-show-date    true
  try gsettings set org.gnome.desktop.interface clock-show-seconds true

  # ── Botões da barra de título: adiciona Minimizar e Maximizar ──
  try gsettings set org.gnome.desktop.wm.preferences button-layout \
    'appmenu:minimize,maximize,close'

  # ── Favoritos do Dock ──
  # Terminal padrão no Debian 13 GNOME 48: GNOME Console (org.gnome.Console.desktop)
  step "Definindo atalhos do dock"
  try gsettings set org.gnome.shell favorite-apps \
    "['google-chrome.desktop', 'org.gnome.Nautilus.desktop', \
'org.gnome.TextEditor.desktop', 'org.gnome.Console.desktop', \
'org.gnome.Calculator.desktop']"

  # ── Navegador padrão: Google Chrome ──
  step "Definindo Google Chrome como navegador padrão"
  try xdg-settings set default-web-browser google-chrome.desktop

  # ── Player padrão: VLC ──
  step "Definindo VLC como player padrão de áudio e vídeo"
  if [[ ! -f /usr/share/applications/vlc.desktop ]]; then
    warning "VLC não está instalado ainda — pulando configuração de player padrão."
    warning "Re-execute a opção [8] após instalar o VLC."
  else
    MEDIA_TYPES=(
      video/mp4 video/x-matroska video/webm video/avi video/quicktime
      video/x-msvideo video/mpeg video/x-flv video/3gpp video/ogg
      audio/mpeg audio/ogg audio/flac audio/x-wav audio/aac
      audio/mp4 audio/x-m4a audio/opus audio/webm
    )

    for mime in "${MEDIA_TYPES[@]}"; do
      try xdg-mime default vlc.desktop "$mime"
      gio mime "$mime" vlc.desktop 2>/dev/null || true
    done

    MIMEAPPS="$HOME/.config/mimeapps.list"
    mkdir -p "$HOME/.config"
    if ! grep -q '^\[Default Applications\]' "$MIMEAPPS" 2>/dev/null; then
      echo '[Default Applications]' >> "$MIMEAPPS"
    fi
    for mime in "${MEDIA_TYPES[@]}"; do
      sed -i "/^${mime//\//\\/}=/d" "$MIMEAPPS" 2>/dev/null || true
      sed -i "/^\[Default Applications\]/a ${mime}=vlc.desktop" "$MIMEAPPS"
    done
    ok "VLC definido como padrão (xdg-mime + gio mime + mimeapps.list)."
  fi

  # ── Chrome: Wayland + gestos de touchpad ──
  step "Configurando Chrome para Wayland e gestos de touchpad"
  FLAGS_FILE="$HOME/.config/chrome-flags.conf"
  mkdir -p "$HOME/.config"
  grep -qxF -- '--ozone-platform=wayland' "$FLAGS_FILE" 2>/dev/null \
    || echo '--ozone-platform=wayland' >> "$FLAGS_FILE"
  grep -qxF -- '--enable-features=TouchpadOverscrollHistoryNavigation' "$FLAGS_FILE" 2>/dev/null \
    || echo '--enable-features=TouchpadOverscrollHistoryNavigation' >> "$FLAGS_FILE"

  DESKTOP_SRC="/usr/share/applications/google-chrome.desktop"
  DESKTOP_DEST="$HOME/.local/share/applications/google-chrome.desktop"
  mkdir -p "$HOME/.local/share/applications"
  if [[ -f "$DESKTOP_SRC" ]]; then
    cp "$DESKTOP_SRC" "$DESKTOP_DEST"
    sed -i \
      '/^Exec=\/usr\/bin\/google-chrome-stable/ s|%U|--ozone-platform=wayland --enable-features=TouchpadOverscrollHistoryNavigation %U|g' \
      "$DESKTOP_DEST"
    ok "Chrome configurado para Wayland e gestos de touchpad."
  else
    warning "google-chrome.desktop não encontrado — Chrome pode não estar instalado. Re-execute [8] após instalar."
  fi

  # ── Wallpaper ──
  step "Baixando e aplicando wallpaper"
  WALLPAPER_URL="https://raw.githubusercontent.com/felipy2k/Fedora-Y2K/main/Y2K_Wallpaper.jpeg"
  WALLPAPER_PATH="$HOME/Pictures/Y2K_Wallpaper.jpeg"
  mkdir -p "$HOME/Pictures"
  if curl -fsSL "$WALLPAPER_URL" -o "$WALLPAPER_PATH"; then
    try gsettings set org.gnome.desktop.background picture-uri      "file://$WALLPAPER_PATH"
    try gsettings set org.gnome.desktop.background picture-uri-dark "file://$WALLPAPER_PATH"
    try gsettings set org.gnome.desktop.background picture-options  'zoom'
    ok "Wallpaper aplicado."
  else
    warning "Falha ao baixar wallpaper. Verifique sua conexão."
  fi

  ok "Configurações aplicadas."
}

# ─────────────────────────────────────────────
# VERIFICAÇÃO FINAL
# ─────────────────────────────────────────────
verify_final() {
  info "[VERIFICAÇÃO] Checando estado final do sistema"

  echo
  echo -e "${BOLD}── Pacotes que deveriam ter sido REMOVIDOS ──${NC}"
  REMOVED_CHECK=$(dpkg -l 2>/dev/null | grep '^ii' | awk '{print $2}' | grep -E \
    "libreoffice|gnome-music|rhythmbox|totem|cheese|gnome-weather|gnome-maps|yelp|dconf-editor|^htop$|^piper$|gnome-terminal" \
    || true)
  if [[ -z "$REMOVED_CHECK" ]]; then
    ok "Nenhum pacote indesejado encontrado."
  else
    warning "Ainda presentes:"
    echo "$REMOVED_CHECK"
  fi

  echo
  echo -e "${BOLD}── Pacotes APT que deveriam existir ──${NC}"
  dpkg -l 2>/dev/null | grep '^ii' | awk '{print $2}' | grep -E \
    "google-chrome-stable|firefox|^vlc$|audacity|darktable|handbrake|inkscape|easyeffects|^gimp$|^blender$|steam|dreamchess|nordvpn|deskflow|drawing|file-roller|obs-studio|gnome-software|papirus|softmaker|freeoffice|solaar|timeshift|deja-dup|^ffmpeg$|fastfetch" \
    2>/dev/null || warning "Alguns pacotes APT podem não estar instalados."

  echo
  echo -e "${BOLD}── Codecs ──${NC}"
  if dpkg -l ffmpeg 2>/dev/null | grep -q '^ii'; then
    ok "ffmpeg instalado."
  else
    warning "ffmpeg não encontrado."
  fi
  if dpkg -l gstreamer1.0-plugins-ugly 2>/dev/null | grep -q '^ii'; then
    ok "GStreamer plugins-ugly (MP3 etc.) instalados."
  else
    warning "gstreamer1.0-plugins-ugly ausente — verifique se non-free está habilitado."
  fi

  echo
  echo -e "${BOLD}── Aplicativos padrão ──${NC}"
  BROWSER=$(xdg-settings get default-web-browser 2>/dev/null || echo "não definido")
  VIDEO_DEFAULT=$(xdg-mime query default video/mp4 2>/dev/null || echo "não definido")
  AUDIO_DEFAULT=$(xdg-mime query default audio/mpeg 2>/dev/null || echo "não definido")
  BUTTONS=$(gsettings get org.gnome.desktop.wm.preferences button-layout 2>/dev/null || echo "não definido")
  echo "  Navegador padrão : $BROWSER"
  echo "  Player de vídeo  : $VIDEO_DEFAULT"
  echo "  Player de áudio  : $AUDIO_DEFAULT"
  echo "  Botões barra tít : $BUTTONS"

  [[ "$BROWSER" == *"google-chrome"* ]] && ok "Chrome é o navegador padrão." || warning "Chrome NÃO é o navegador padrão."
  [[ "$VIDEO_DEFAULT" == *"vlc"* ]]     && ok "VLC é o player de vídeo padrão." || warning "VLC NÃO é o player de vídeo padrão."
  [[ "$AUDIO_DEFAULT" == *"vlc"* ]]     && ok "VLC é o player de áudio padrão." || warning "VLC NÃO é o player de áudio padrão."
  [[ "$BUTTONS" == *"minimize,maximize"* ]] && ok "Botões Minimizar/Maximizar ativos." || warning "Botões Minimizar/Maximizar não configurados."

  echo
  echo -e "${BOLD}── Flatpaks instalados ──${NC}"
  flatpak list --app --columns=application 2>/dev/null | grep -E \
    "Alpaca|Resources|Flatseal|Blanket|Raider|FreeCAD|Upscayl|Shotcut|VideoTrimmer|cameractrls|converseen|nokye22.Exhibit|Minder|Motrix|localsend|Podcasts|Popsicle|Shortwave|sticky|Converter|ExtensionManager|PodmanDesktop|Discord" \
    || warning "Alguns Flatpaks esperados podem não estar instalados."

  echo
  echo -e "${BOLD}── GPU NVIDIA ──${NC}"
  if lspci -d ::0300 -d ::0302 -d ::0380 2>/dev/null | grep -qi nvidia; then
    if dpkg -l nvidia-driver 2>/dev/null | grep -q '^ii'; then
      ok "Driver NVIDIA instalado."
      # Verificar status DKMS
      DKMS_STATUS="$(dkms status 2>/dev/null | grep -i nvidia || true)"
      if echo "$DKMS_STATUS" | grep -qi 'installed'; then
        ok "Módulo DKMS NVIDIA compilado e instalado: $DKMS_STATUS"
      else
        warning "DKMS NVIDIA não aparece como 'installed'. Status: ${DKMS_STATUS:-vazio}. Pode precisar de reboot."
      fi
      # nvidia-smi só funciona após reboot com o módulo carregado
      nvidia-smi 2>/dev/null | head -4 || \
        warning "nvidia-smi não disponível (reboot necessário para carregar o módulo)."
      if command -v nvcc &>/dev/null; then
        ok "CUDA Toolkit presente: $(nvcc --version | grep release)"
      else
        echo "  ℹ CUDA Toolkit (nvcc) não instalado — suporte CUDA apenas pelo driver."
      fi
      # Verificar serviços de power management
      for svc in nvidia-suspend nvidia-hibernate nvidia-resume; do
        if systemctl is-enabled "${svc}.service" &>/dev/null; then
          ok "Serviço ${svc}.service habilitado."
        else
          warning "Serviço ${svc}.service NÃO está habilitado."
        fi
      done
    else
      warning "GPU NVIDIA detectada mas driver NÃO instalado."
    fi
  else
    ok "Sem GPU NVIDIA (driver desnecessário)."
  fi

  echo
  echo -e "${BOLD}── Extensões GNOME ──${NC}"
  if command -v gnome-extensions &>/dev/null; then
    gnome-extensions list --enabled 2>/dev/null || true
  else
    warning "gnome-extensions não disponível."
  fi

  echo
  echo -e "${BOLD}── Repositórios ──${NC}"
  if grep -r 'non-free' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null | grep -v '^#' | grep -q 'non-free'; then
    ok "Repositório non-free habilitado."
  else
    warning "Repositório non-free pode não estar habilitado — verifique os sources."
  fi
  if [[ -f /etc/apt/sources.list.d/google-chrome.list ]]; then
    ok "Repositório Google Chrome presente."
  else
    warning "Repositório Google Chrome não encontrado."
  fi
}

# ─────────────────────────────────────────────
# RUN EVERYTHING
# Ordem correta: instalar tudo → remover bloat
# ─────────────────────────────────────────────
run_all() {
  echo
  echo -e "${YELLOW}Isso executará todos os passos na ordem correta.${NC}"
  echo -e "${CYAN}Ordem: repos → update → APT packages → FreeOffice → Flatpaks → NVIDIA → Extensions → Remove bloat → Settings${NC}"
  echo

  # Verificação de espaço em disco — instalação completa precisa ~15+ GB
  AVAIL_GB=$(df -BG --output=avail / 2>/dev/null | tail -1 | tr -dc '0-9')
  if [[ -n "$AVAIL_GB" ]]; then
    echo -e "${BOLD}Espaço livre em /: ${AVAIL_GB} GB${NC}"
    if [[ "$AVAIL_GB" -lt 15 ]]; then
      warning "Menos de 15 GB livre — instalação completa pode falhar (Steam + Blender + CUDA são pesados)."
      read -rp "Continuar mesmo assim? [y/N]: " DISK_CONFIRM
      [[ "${DISK_CONFIRM,,}" != "y" ]] && { warning "Cancelado."; return; }
    fi
  fi

  read -rp "Confirmar? [y/N]: " CONFIRM
  [[ "${CONFIRM,,}" != "y" ]] && { warning "Cancelado."; return; }

  WARN_COUNT=0

  add_repos
  update_system
  install_packages        # Instala tudo (incluindo codecs)
  install_freeoffice      # FreeOffice antes de remover LibreOffice
  install_flatpaks
  install_nvidia
  install_gnome_extensions
  remove_bloat            # Remove LibreOffice e bloat APÓS instalar tudo
  apply_settings          # Configurações visuais + apps padrão
  verify_final

  echo
  echo -e "${BOLD}════════════════════════════════════════${NC}"
  echo -e "${BOLD}   RESUMO DA INSTALAÇÃO${NC}"
  echo -e "${BOLD}════════════════════════════════════════${NC}"
  if [[ "$WARN_COUNT" -eq 0 ]]; then
    ok "Setup concluído sem warnings!"
  else
    warning "Setup concluído com $WARN_COUNT warning(s) — revise o log acima."
  fi
  echo "  Log completo salvo em: $LOG_FILE"
  echo -e "${YELLOW}⚠ Reinicie o sistema para ativar todos os drivers e configurações.${NC}"
}

# ─────────────────────────────────────────────
# MAIN LOOP
# ─────────────────────────────────────────────
while true; do
  show_menu

  case "$CHOICE" in
    1) run_all ;;
    2) add_repos; update_system ;;
    3) remove_bloat ;;
    4) add_repos; install_packages ;;
    5) install_flatpaks ;;
    6) add_repos; install_nvidia ;;
    7) install_gnome_extensions ;;
    8) apply_settings ;;
    9) verify_final ;;
    0) echo "Saindo."; exit 0 ;;
    r|R) echo "Reiniciando..."; sudo reboot ;;
    *) warning "Opção inválida." ;;
  esac

  echo
  read -rp "Pressione ENTER para voltar ao menu..." _
done
