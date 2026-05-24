#!/usr/bin/env bash

# =============================================================================
# Debian 13 (Trixie) — Custom Post-Install Setup
# Adapted from: felipy2k/Fedora-Y2K
# Tested against: Debian 13.x GNOME (amd64)
# =============================================================================

set -uo pipefail

LOG_FILE="$HOME/debian-y2k-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "\n${GREEN}▶ $*${NC}"; }
step()    { echo -e "  ${CYAN}→ $*${NC}"; }
warning() { echo -e "  ${YELLOW}⚠ $*${NC}"; ((WARN_COUNT++)) || true; }
fail()    { echo -e "${RED}✗ $*${NC}"; }
ok()      { echo -e "  ${GREEN}✓ $*${NC}"; }

WARN_COUNT=0

try() {
  set +e
  "$@"
  local rc=$?
  set -e
  [[ $rc -ne 0 ]] && warning "Failed (exit $rc), continuing: $*"
  return 0
}

# ── Verificações iniciais ──
if [[ "$EUID" -eq 0 ]]; then
  fail "Não execute como root. Use um usuário regular com sudo."
  exit 1
fi

if ! grep -qi 'debian' /etc/os-release 2>/dev/null; then
  fail "Este script foi feito para Debian. Sistema detectado não é Debian."
  exit 1
fi

if ! sudo -v 2>/dev/null; then
  fail "Usuário '$(whoami)' não tem acesso ao sudo."
  echo "  No Debian, o sudo não é configurado automaticamente."
  echo "  Corrija isso ANTES de rodar o script:"
  echo "  1. Abra um novo terminal e entre como root:"
  echo "     su -"
  echo "  2. Adicione seu usuário ao sudo e instale o curl:"
  echo "     apt-get install -y sudo curl"
  echo "     usermod -aG sudo $(whoami)"
  echo "     exit"
  echo "  3. Faça logout e login novamente, depois rode o script outra vez."
  exit 1
fi

# shellcheck source=/dev/null
. /etc/os-release
DEBIAN_CODENAME="${VERSION_CODENAME:-trixie}"

# ─────────────────────────────────────────────
# MENU
# ─────────────────────────────────────────────
show_menu() {
  echo
  echo -e "${BOLD}════════════════════════════════════════${NC}"
  echo -e "${BOLD}   Debian Y2K — Post-Install Setup${NC}"
  echo -e "${BOLD}════════════════════════════════════════${NC}"
  echo -e "  ${CYAN}Sistema: Debian ${VERSION_ID:-13} (${DEBIAN_CODENAME})${NC}"
  echo
  echo "  [1] Executar TUDO (recomendado para instalação limpa)"
  echo "  [2] Repositórios + Atualizar sistema"
  echo "  [3] Remover bloatware"
  echo "  [4] Instalar pacotes APT"
  echo "  [5] Instalar Flatpaks"
  echo "  [6] Instalar driver NVIDIA"
  echo "  [7] Instalar extensões GNOME"
  echo "  [8] Aplicar configurações visuais"
  echo "  [9] Verificar instalação"
  echo "  [f] Instalar FreeOffice"
  echo "  [0] Sair"
  echo "  [r] Reiniciar"
  echo
  read -rp "Escolha: " CHOICE
}

# ─────────────────────────────────────────────
# REPOSITÓRIOS
# ─────────────────────────────────────────────
add_repos() {
  info "[REPOS] Configurando repositórios"

  # ── Habilita non-free, non-free-firmware e contrib ──
  step "Verificando e habilitando repositórios non-free"
  if [[ -f /etc/apt/sources.list.d/debian.sources ]]; then
    # DEB822 format (Debian 13 padrão)
    if ! grep -q 'non-free' /etc/apt/sources.list.d/debian.sources; then
      sudo sed -i 's/^Components: main$/Components: main contrib non-free non-free-firmware/' \
        /etc/apt/sources.list.d/debian.sources
      ok "Componentes non-free habilitados (DEB822)."
    else
      ok "Componentes non-free já habilitados."
    fi
  elif [[ -f /etc/apt/sources.list ]]; then
    if ! grep -v '^#' /etc/apt/sources.list | grep -q 'non-free'; then
      sudo sed -i 's/ main$/ main contrib non-free non-free-firmware/' /etc/apt/sources.list
      ok "Componentes non-free habilitados (one-line)."
    else
      ok "Componentes non-free já habilitados."
    fi
  else
    warning "Arquivo sources.list não encontrado. Verifique a configuração do APT."
  fi

  # ── Flathub ──
  step "Configurando Flathub"
  if ! flatpak remote-list 2>/dev/null | grep -q 'flathub'; then
    sudo apt-get install -y flatpak gnome-software-plugin-flatpak 2>/dev/null || \
      sudo apt-get install -y flatpak 2>/dev/null || true
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    ok "Flathub adicionado."
  else
    ok "Flathub já configurado."
  fi

  # ── Google Chrome ──
  # BUG FIX: método correto para Debian 13 — chave em /usr/share/keyrings/ com signed-by
  step "Adicionando repositório Google Chrome"
  CHROME_KEYRING="/usr/share/keyrings/google-chrome.gpg"
  CHROME_LIST="/etc/apt/sources.list.d/google-chrome.list"

  if [[ ! -f "$CHROME_KEYRING" ]]; then
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
      | gpg --dearmor \
      | sudo tee "$CHROME_KEYRING" > /dev/null
    ok "Chave GPG do Chrome adicionada."
  else
    ok "Chave GPG do Chrome já existe."
  fi

  if [[ ! -f "$CHROME_LIST" ]]; then
    echo "deb [arch=amd64 signed-by=${CHROME_KEYRING}] https://dl.google.com/linux/chrome/deb/ stable main" \
      | sudo tee "$CHROME_LIST" > /dev/null
    ok "Repositório Chrome adicionado."
  else
    ok "Repositório Chrome já existe."
  fi

  sudo apt-get update -qq
  ok "Repositórios configurados."
}

# ─────────────────────────────────────────────
# UPDATE
# ─────────────────────────────────────────────
update_system() {
  info "[UPDATE] Atualizando sistema"
  try sudo apt-get upgrade -y
  try sudo apt-get dist-upgrade -y
  ok "Sistema atualizado."
}

# ─────────────────────────────────────────────
# PACOTES APT
# ─────────────────────────────────────────────
install_packages() {
  info "[PACKAGES] Instalando pacotes APT"

  PACKAGES=(
    # Utilitários do sistema
    curl wget git
    fastfetch
    lm-sensors hddtemp smartmontools
    pipx python3-pip python3-requests
    gir1.2-soup-3.0
    flatpak

    # Aparência
    papirus-icon-theme

    # Navegador
    google-chrome-stable

    # Multimídia
    audacity
    handbrake
    obs-studio
    v4l2loopback-dkms
    shotwell
    shotcut              # Editor de vídeo (preferência .deb sobre Flatpak)
    cheese               # Webcam (usuário optou por manter)

    # Gráficos / Design
    blender
    inkscape
    darktable
    gimp
    imagemagick
    converseen           # Conversor de imagens em lote

    # Apps GNOME / Sistema
    gnome-boxes
    deja-dup
    easyeffects
    dreamchess
    deskflow
    drawing
    timeshift

    # Comunicação
    torbrowser-launcher  # Tor Browser

    # Player de mídia (APT .deb — não instalar Flatpak para evitar duplicata)
    vlc

    # Codecs e drivers de mídia
    ffmpeg
    libavcodec-extra
    gstreamer1.0-plugins-bad
    gstreamer1.0-plugins-ugly
    gstreamer1.0-plugins-good
    gstreamer1.0-libav
    libdvdread8
    libdvd-pkg

    # VA-API / VDPAU
    mesa-va-drivers
    mesa-vdpau-drivers
    libva-drm2
    libva-utils
    vdpauinfo

    # Fontes
    fonts-noto
    fonts-noto-color-emoji

    # Rede
    network-manager-openvpn-gnome
  )

  # OBS Studio exige kernel headers para DKMS
  KERNEL_PKG="linux-headers-$(uname -r)"
  PACKAGES+=("$KERNEL_PKG")

  step "Instalando ${#PACKAGES[@]} pacotes"
  if ! sudo apt-get install -y "${PACKAGES[@]}"; then
    warning "Instalação em lote falhou — tentando pacote por pacote"
    for pkg in "${PACKAGES[@]}"; do
      [[ -z "$pkg" ]] && continue
      dpkg -s "$pkg" &>/dev/null 2>&1 || try sudo apt-get install -y "$pkg"
    done
  fi

  # libdvd-pkg requer dpkg-reconfigure após instalação
  if dpkg -s libdvd-pkg &>/dev/null 2>&1; then
    step "Configurando libdvd-pkg"
    try sudo dpkg-reconfigure -f noninteractive libdvd-pkg
  fi

  ok "Pacotes APT instalados."

  install_nordvpn
  install_steam
}

install_nordvpn() {
  info "[NORDVPN] Instalando NordVPN"
  if command -v nordvpn &>/dev/null; then
    ok "NordVPN já está instalado."
    return
  fi
  step "Baixando instalador oficial"
  if curl -fsSL https://downloads.nordcdn.com/apps/linux/install.sh -o /tmp/nordvpn-install.sh; then
    bash /tmp/nordvpn-install.sh --no-prompt || \
      warning "Instalação NordVPN falhou — instale manualmente em https://nordvpn.com/download/"
    rm -f /tmp/nordvpn-install.sh
  else
    warning "Download do instalador NordVPN falhou."
  fi
}

install_steam() {
  info "[STEAM] Instalando Steam"
  if command -v steam &>/dev/null || flatpak info com.valvesoftware.Steam &>/dev/null 2>&1; then
    ok "Steam já está instalado."
    return
  fi
  step "Habilitando arquitetura i386 (necessário para Steam)"
  try sudo dpkg --add-architecture i386
  try sudo apt-get update -qq
  # Steam no Debian 13 usa steam-installer do repositório contrib
  if sudo apt-get install -y steam-installer 2>/dev/null; then
    ok "Steam instalado via steam-installer (contrib)."
  else
    warning "steam-installer não disponível. Instalando Steam via Flatpak..."
    try flatpak install -y flathub com.valvesoftware.Steam
  fi
}

# ─────────────────────────────────────────────
# FREEOFFICE
# ─────────────────────────────────────────────
install_freeoffice() {
  info "[FREEOFFICE] Instalando FreeOffice (SoftMaker)"

  if dpkg -l 'softmaker-freeoffice*' 2>/dev/null | grep -q '^ii'; then
    ok "FreeOffice já está instalado."
    return
  fi

  # ── Método 1: installer oficial (recomendado pelo SoftMaker) ──
  # Nota: deve rodar como root completo via "sudo bash -c '...'" para
  # que o curl interno do installer também rode como root.
  # DEBIAN_FRONTEND evita travamento em prompts interativos.
  step "Método 1: installer oficial SoftMaker"
  if sudo bash -c 'DEBIAN_FRONTEND=noninteractive curl -fsSL --connect-timeout 20 https://softmaker.net/down/install-softmaker-freeoffice-2024.sh | bash'; then
    ok "FreeOffice 2024 instalado via installer oficial."
    return
  fi
  warning "Installer oficial falhou — tentando download direto do .deb."

  # ── Método 2: download direto do .deb ──
  # O SoftMaker publica .deb com padrão: softmaker-freeoffice-2024_YYMM-01_amd64.deb
  # Tenta os últimos 6 meses em ordem decrescente.
  step "Método 2: download direto do .deb"
  DEB_BASE="https://www.softmaker.net/down"
  DEB_FILE=""
  # Gera lista de versões: YYMM do mês atual para 6 meses atrás
  VERSIONS=()
  for i in 0 1 2 3 4 5; do
    VERSIONS+=("$(date -d "$i months ago" +%y%m 2>/dev/null || true)")
  done

  for ver in "${VERSIONS[@]}"; do
    [[ -z "$ver" ]] && continue
    url="${DEB_BASE}/softmaker-freeoffice-2024_${ver}-01_amd64.deb"
    code=$(curl -fsSL --connect-timeout 10 -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "0")
    if [[ "$code" == "200" ]]; then
      DEB_FILE="/tmp/softmaker-freeoffice-2024_${ver}.deb"
      step "Baixando: $url"
      curl -fsSL --connect-timeout 20 "$url" -o "$DEB_FILE" && break
      DEB_FILE=""
    fi
  done

  if [[ -n "$DEB_FILE" && -f "$DEB_FILE" ]]; then
    step "Instalando .deb"
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$DEB_FILE"; then
      rm -f "$DEB_FILE"
      ok "FreeOffice instalado via .deb direto."
      return
    fi
    # apt-get com path de .deb pode falhar em versões antigas — tenta dpkg + fix
    if sudo dpkg -i "$DEB_FILE" 2>/dev/null; then
      sudo DEBIAN_FRONTEND=noninteractive apt-get install -f -y 2>/dev/null || true
      rm -f "$DEB_FILE"
      ok "FreeOffice instalado via dpkg."
      return
    fi
    rm -f "$DEB_FILE"
  fi
  warning "Download direto do .deb falhou."

  # ── Método 3: repositório APT manual ──
  step "Método 3: repositório APT manual"
  SOFTMAKER_KEYRING="/etc/apt/keyrings/softmaker.gpg"
  sudo mkdir -p /etc/apt/keyrings

  if [[ ! -f "$SOFTMAKER_KEYRING" ]]; then
    curl -fsSL --connect-timeout 15 https://shop.softmaker.com/repo/linux-repo-public.key \
      | gpg --dearmor \
      | sudo tee "$SOFTMAKER_KEYRING" > /dev/null 2>&1 || true
  fi

  if [[ -f "$SOFTMAKER_KEYRING" ]]; then
    echo "deb [arch=amd64 signed-by=${SOFTMAKER_KEYRING}] https://shop.softmaker.com/repo/apt stable non-free" \
      | sudo tee /etc/apt/sources.list.d/softmaker.list > /dev/null
    try sudo apt-get update -qq
    if sudo DEBIAN_FRONTEND=noninteractive apt-get install -y softmaker-freeoffice-2024 2>/dev/null; then
      ok "FreeOffice instalado via repositório APT."
      return
    fi
  fi

  fail "Todos os métodos falharam."
  echo "  Instale manualmente:"
  echo "  1. Acesse https://www.freeoffice.com/en/download"
  echo "  2. Baixe o pacote .deb para Linux amd64"
  echo "  3. sudo apt install ./softmaker-freeoffice-*.deb"
  ((WARN_COUNT++)) || true
}

# ─────────────────────────────────────────────
# FLATPAKS
# ─────────────────────────────────────────────
install_flatpaks() {
  info "[FLATPAKS] Instalando aplicativos Flatpak"

  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

  FLATPAKS=(
    # ── GNOME / Sistema ──
    com.mattjakeman.ExtensionManager  # Gerenciador de extensões GNOME
    com.github.tchx84.Flatseal        # Gerenciador de permissões Flatpak
    net.nokyan.Resources              # Monitor de recursos (CPU/RAM/GPU)
    com.system76.Popsicle             # Gravador de USB

    # ── Periféricos ──
    io.github.solaar_mouse.solaar     # Periféricos Logitech

    # ── Comunicação ──
    com.discordapp.Discord            # Discord (apenas Flatpak oficial)

    # ── Multimídia / Vídeo ──
    de.haeckerfelix.Shortwave         # Rádio pela internet

    # ── Gráficos / Design / 3D ──
    org.freecad.FreeCAD            # CAD 3D (Flatpak = versão atual)
    io.github.nokse22.exhibit         # Visualizador de modelos 3D
    io.gitlab.adhami3310.Switcheroo   # Conversor de imagens (formato)

    # ── Produtividade / Utilitários ──
    org.gnome.Podcasts                # Podcasts
    org.localsend.localsend_app       # Transferência local de arquivos
    com.rafaelmardojai.Blanket        # Sons ambiente
    com.vixalien.sticky               # Sticky Notes
    io.github.ADBeveridge.Raider      # File Shredder seguro
    org.gnome.VideoTrimmer            # Aparador de vídeo simples

    # ── IA / Dev ──
    com.jeffser.Alpaca                # Interface Ollama (LLM local)
    io.podman_desktop.PodmanDesktop   # Podman Desktop (containers)

    # ── Fotos / Imagem ──
    io.github.thewh1teagle.upscayl    # Upscaler de imagem com IA
    hu.irl.cameractrls                # Controles avançados de webcam

    # ── Ferramentas de cor ──
    nl.hjdskes.gcolor3                # Color Picker
  )

  for app in "${FLATPAKS[@]}"; do
    # Ignora comentários inline
    app="${app%%#*}"
    app="${app//[[:space:]]/}"
    [[ -z "$app" ]] && continue

    step "Instalando: $app"
    if flatpak info "$app" &>/dev/null 2>&1; then
      ok "$app já instalado."
    else
      try flatpak install -y flathub "$app"
    fi
  done

  ok "Flatpaks instalados."
}

# ─────────────────────────────────────────────
# NVIDIA + CUDA
# ─────────────────────────────────────────────
_nvidia_do_install() {
  if command -v mokutil &>/dev/null && mokutil --sb-state 2>/dev/null | grep -qi 'enabled'; then
    warning "Secure Boot está ATIVADO."
    warning "Após a instalação, talvez precise cadastrar a chave MOK do DKMS."
    warning "Veja: https://wiki.debian.org/SecureBoot"
    read -rp "  Continuar mesmo assim? [y/N]: " SB_CONFIRM
    [[ "${SB_CONFIRM,,}" != "y" ]] && { warning "Instalação NVIDIA cancelada."; return; }
  fi

  # CRÍTICO: no Debian 13 + kernel 6.12, o DKMS falha sem os headers presentes
  step "Instalando kernel headers (obrigatório para DKMS)"
  KERNEL_VER="$(uname -r)"
  if sudo apt-get install -y "linux-headers-${KERNEL_VER}" 2>/dev/null; then
    ok "Headers instalados para kernel ${KERNEL_VER}"
  else
    warning "Headers específicos não encontrados. Tentando meta-package linux-headers-amd64"
    try sudo apt-get install -y linux-headers-amd64
  fi

  step "Instalando driver NVIDIA (Debian non-free)"
  try sudo apt-get install -y \
    nvidia-driver \
    nvidia-kernel-dkms \
    nvidia-settings \
    firmware-misc-nonfree \
    libva-utils \
    vdpauinfo

  step "Driver NVIDIA VA-API (opcional)"
  sudo apt-get install -y nvidia-vaapi-driver 2>/dev/null || \
    warning "nvidia-vaapi-driver não disponível — pulando (não-crítico)."

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
      warning "Módulo DKMS NVIDIA ainda não aparece. Pode precisar de reboot."
    fi
  fi

  # Necessário para suspend/hibernate não dar tela preta com NVIDIA
  step "Configurando NVreg_PreserveVideoMemoryAllocations"
  MODPROBE_CONF="/etc/modprobe.d/nvidia-power.conf"
  if [[ ! -f "$MODPROBE_CONF" ]]; then
    sudo tee "$MODPROBE_CONF" > /dev/null <<'EOF'
# Necessário para suspend/resume funcionar com NVIDIA no Debian
# Sem isso, a tela pode ficar preta ao retornar do suspend
options nvidia NVreg_PreserveVideoMemoryAllocations=1
EOF
    ok "NVreg_PreserveVideoMemoryAllocations=1 configurado."
  else
    ok "Arquivo de configuração NVIDIA modprobe já existe."
  fi

  step "Atualizando initramfs"
  try sudo update-initramfs -u -k all

  # No Debian, serviços NVIDIA de suspend/hibernate ficam desabilitados por padrão
  step "Habilitando serviços NVIDIA de suspend/hibernate"
  for svc in nvidia-suspend nvidia-hibernate nvidia-resume; do
    if systemctl list-unit-files "${svc}.service" 2>/dev/null | grep -q "${svc}"; then
      try sudo systemctl enable "${svc}.service"
      ok "${svc} habilitado."
    fi
  done

  step "CUDA (opcional)"
  if apt-cache search 'cuda-toolkit' 2>/dev/null | grep -q 'cuda-toolkit'; then
    read -rp "  Instalar CUDA Toolkit? (requer ~5GB) [y/N]: " CUDA_CONFIRM
    if [[ "${CUDA_CONFIRM,,}" == "y" ]]; then
      try sudo apt-get install -y cuda-toolkit
    fi
  else
    warning "CUDA Toolkit não disponível nos repositórios atuais."
    echo "  Veja: https://developer.nvidia.com/cuda-downloads"
  fi

  ok "Driver NVIDIA instalado. Reinicie para ativar."
}

install_nvidia() {
  info "[NVIDIA] Detectando GPU"

  if lspci -d ::0300 -d ::0302 -d ::0380 2>/dev/null | grep -qi nvidia; then
    GPU_INFO="$(lspci -d ::0300 -d ::0302 -d ::0380 2>/dev/null | grep -i nvidia | head -1)"
    ok "GPU NVIDIA detectada: $GPU_INFO"
    _nvidia_do_install
    return
  fi

  warning "Nenhuma GPU NVIDIA detectada via lspci."
  echo -e "  ${CYAN}Isso pode acontecer quando:"
  echo -e "  • Inicializando com GPU integrada/onboard enquanto a NVIDIA está presente"
  echo -e "  • Instalando o driver antes de colocar a placa fisicamente${NC}"
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

  # Garante pipx
  if ! command -v pipx &>/dev/null; then
    step "Instalando pipx"
    try sudo apt-get install -y pipx
    try pipx ensurepath
    export PATH="$HOME/.local/bin:$PATH"
  else
    ok "pipx disponível."
  fi

  # Garante gext (gnome-extensions-cli)
  if ! command -v gext &>/dev/null; then
    step "Instalando gnome-extensions-cli via pipx"
    try pipx install gnome-extensions-cli
    export PATH="$HOME/.local/bin:$PATH"
    hash -r 2>/dev/null || true
  else
    ok "gext disponível."
  fi

  if ! command -v gext &>/dev/null; then
    warning "gext não disponível após instalação."
    warning "Instale as extensões manualmente via Extension Manager (Flatpak)."
    return
  fi

  GNOME_VER=$(gnome-shell --version 2>/dev/null | grep -oP '\d+' | head -1 || echo "48")
  step "GNOME Shell versão detectada: $GNOME_VER"

  EXTENSIONS=(
    "AlphabeticalAppGrid@stuarthayhurst"
    "appindicatorsupport@rgcjonas.gmail.com"
    "blur-my-shell@aunetx"
    "BringOutSubmenuOfPowerOffLogoutButton@pratap.fastmail.fm"
    "caffeine@patapon.info"
    "clipboard-indicator@tudmotu.com"
    "dash-to-dock@micxgx.gmail.com"
    "editdesktopfiles@dannflower"
    "gsconnect@andyholmes.github.io"
    "just-perfection-desktop@just-perfection"
    "tilingshell@ferrarodomenico.com"
    "Vitals@CoreCoding.com"
  )

  FAILED_EXTS=()
  for ext in "${EXTENSIONS[@]}"; do
    step "Instalando: $ext"
    if gext install "$ext" 2>/dev/null; then
      if gext enable "$ext" 2>/dev/null; then
        ok "$ext"
      else
        warning "$ext instalado mas não habilitado (possível incompatibilidade com GNOME $GNOME_VER)"
        FAILED_EXTS+=("$ext")
      fi
    else
      warning "$ext — falha na instalação"
      FAILED_EXTS+=("$ext")
    fi
  done

  if [[ ${#FAILED_EXTS[@]} -gt 0 ]]; then
    warning "${#FAILED_EXTS[@]} extensão(ões) com problema — verifique no Extension Manager:"
    printf '    • %s\n' "${FAILED_EXTS[@]}"
  else
    ok "Todas as extensões instaladas e habilitadas."
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

  # Backup da lista de pacotes instalados
  BACKUP_FILE="$HOME/debian-y2k-packages-before-cleanup-$(date +%Y%m%d-%H%M%S).txt"
  step "Salvando lista de pacotes em $BACKUP_FILE"
  dpkg -l | grep '^ii' | awk '{print $2}' > "$BACKUP_FILE" 2>/dev/null && \
    ok "Backup salvo (restaurar com: xargs sudo apt-get install -y < $BACKUP_FILE)" || \
    warning "Falha ao salvar backup."

  step "Removendo LibreOffice (substituído pelo FreeOffice)"
  try sudo apt-get remove -y --purge 'libreoffice*'

  # Remove Showtime (player padrão GNOME 48) e qualquer instância VLC Flatpak duplicada
  # VLC fica apenas como .deb para evitar duplicata no app grid
  step "Removendo players GNOME padrão e VLC Flatpak duplicado"
  for app in org.gnome.Showtime org.gnome.Totem org.gnome.Music org.videolan.VLC; do
    if flatpak info "$app" &>/dev/null 2>&1; then
      step "Removendo Flatpak: $app"
      try flatpak uninstall -y "$app"
    fi
  done
  for pkg in gnome-music rhythmbox totem totem-video-thumbnailer; do
    dpkg -s "$pkg" &>/dev/null 2>&1 && try sudo apt-get remove -y --purge "$pkg" || true
  done

  step "Removendo Evolution (cliente de e-mail padrão GNOME — não utilizado)"
  for pkg in evolution evolution-common evolution-data-server; do
    dpkg -s "$pkg" &>/dev/null 2>&1 && try sudo apt-get remove -y --purge "$pkg" || true
  done

  step "Removendo terminal duplicado (mantendo GNOME Console, padrão desde GNOME 46+)"
  dpkg -s gnome-terminal &>/dev/null 2>&1 && \
    try sudo apt-get remove -y --purge gnome-terminal || true

  step "Removendo gerenciador de extensões APT (substituído pelo Extension Manager Flatpak)"
  for pkg in gnome-shell-extension-prefs gnome-extensions-app; do
    dpkg -s "$pkg" &>/dev/null 2>&1 && try sudo apt-get remove -y --purge "$pkg" || true
  done

  step "Removendo apps desnecessários"
  for pkg in gnome-tour gnome-weather gnome-maps yelp dconf-editor piper qjackctl jackd2; do
    dpkg -s "$pkg" &>/dev/null 2>&1 && try sudo apt-get remove -y --purge "$pkg" || true
  done

  step "Removendo Flatpaks desnecessários"
  for app in org.freedesktop.Piper org.gnome.Help org.gnome.Weather org.gnome.Maps; do
    flatpak info "$app" &>/dev/null 2>&1 && try flatpak uninstall -y "$app" || true
  done

  step "Limpando dependências órfãs"
  try sudo apt-get autoremove -y
  try sudo apt-get autoclean

  ok "Limpeza concluída."
}

# ─────────────────────────────────────────────
# CONFIGURAÇÕES VISUAIS E APPS PADRÃO
# gsettings/xdg-mime são agnósticos de distro
# ─────────────────────────────────────────────
apply_settings() {
  info "[SETTINGS] Aplicando configurações GNOME e apps padrão"

  # ── Aparência ──
  # BUG FIX: tenta Papirus-Dark primeiro, com fallback para Papirus
  # (antes aplicava 'Papirus' diretamente sem verificar variantes disponíveis)
  step "Aplicando tema de ícones Papirus"
  if gsettings set org.gnome.desktop.interface icon-theme 'Papirus-Dark' 2>/dev/null; then
    ok "Icon theme: Papirus-Dark"
  elif gsettings set org.gnome.desktop.interface icon-theme 'Papirus' 2>/dev/null; then
    ok "Icon theme: Papirus (Papirus-Dark não disponível)"
  else
    warning "Não foi possível aplicar tema Papirus."
    warning "Verifique se papirus-icon-theme está instalado: dpkg -s papirus-icon-theme"
  fi

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
  if [[ -f /usr/share/applications/google-chrome.desktop ]]; then
    try xdg-settings set default-web-browser google-chrome.desktop
    ok "Chrome definido como navegador padrão."
  else
    warning "google-chrome.desktop não encontrado — re-execute [8] após instalar o Chrome."
  fi

  # ── Player padrão: VLC ──
  # BUG FIX: o script anterior só verificava /usr/share/applications/vlc.desktop (instalação APT)
  # mas VLC é instalado como Flatpak (org.videolan.VLC.desktop) — verificação errada causava skip
  step "Definindo VLC como player padrão de áudio e vídeo"
  VLC_DESKTOP=""
  if [[ -f /usr/share/applications/vlc.desktop ]]; then
    VLC_DESKTOP="vlc.desktop"
  elif flatpak info org.videolan.VLC &>/dev/null 2>&1; then
    VLC_DESKTOP="org.videolan.VLC.desktop"
  fi

  if [[ -z "$VLC_DESKTOP" ]]; then
    warning "VLC não encontrado (APT nem Flatpak) — pulando configuração de player."
    warning "Re-execute [8] após instalar o VLC."
  else
    MEDIA_TYPES=(
      video/mp4 video/x-matroska video/webm video/avi video/quicktime
      video/x-msvideo video/mpeg video/x-flv video/3gpp video/ogg
      audio/mpeg audio/ogg audio/flac audio/x-wav audio/aac
      audio/mp4 audio/x-m4a audio/opus audio/webm
    )

    for mime in "${MEDIA_TYPES[@]}"; do
      try xdg-mime default "$VLC_DESKTOP" "$mime" 2>/dev/null
      gio mime "$mime" "$VLC_DESKTOP" 2>/dev/null || true
    done

    MIMEAPPS="$HOME/.config/mimeapps.list"
    mkdir -p "$HOME/.config"
    if ! grep -q '^\[Default Applications\]' "$MIMEAPPS" 2>/dev/null; then
      echo '[Default Applications]' >> "$MIMEAPPS"
    fi
    for mime in "${MEDIA_TYPES[@]}"; do
      sed -i "/^${mime//\//\\/}=/d" "$MIMEAPPS" 2>/dev/null || true
      sed -i "/^\[Default Applications\]/a ${mime}=${VLC_DESKTOP}" "$MIMEAPPS"
    done
    ok "VLC ($VLC_DESKTOP) definido como padrão (xdg-mime + gio mime + mimeapps.list)."
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
    warning "google-chrome.desktop não encontrado — re-execute [8] após instalar o Chrome."
  fi

  # ── Wallpaper ──
  # BUG FIX: adicionado --connect-timeout e verificação se arquivo já existe
  step "Baixando e aplicando wallpaper"
  WALLPAPER_URL="https://raw.githubusercontent.com/felipy2k/Fedora-Y2K/main/Y2K_Wallpaper.jpeg"
  WALLPAPER_DIR="$HOME/Pictures"
  WALLPAPER_PATH="$WALLPAPER_DIR/Y2K_Wallpaper.jpeg"
  mkdir -p "$WALLPAPER_DIR"

  if [[ -f "$WALLPAPER_PATH" ]]; then
    ok "Wallpaper já existe — reaplicando."
  elif curl -fsSL --connect-timeout 15 "$WALLPAPER_URL" -o "$WALLPAPER_PATH"; then
    ok "Wallpaper baixado."
  else
    warning "Falha ao baixar wallpaper. Baixe manualmente:"
    warning "  URL: $WALLPAPER_URL"
    warning "  Destino: $WALLPAPER_PATH"
  fi

  if [[ -f "$WALLPAPER_PATH" ]]; then
    WALLPAPER_URI="file://$WALLPAPER_PATH"
    try gsettings set org.gnome.desktop.background picture-uri      "$WALLPAPER_URI"
    try gsettings set org.gnome.desktop.background picture-uri-dark "$WALLPAPER_URI"
    try gsettings set org.gnome.desktop.background picture-options  'zoom'
    try gsettings set org.gnome.screensaver       picture-uri       "$WALLPAPER_URI"
    ok "Wallpaper aplicado."
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
    "libreoffice|gnome-music|rhythmbox|totem|gnome-weather|gnome-maps|yelp|dconf-editor|^piper$|gnome-terminal" \
    || true)
  if [[ -z "$REMOVED_CHECK" ]]; then
    ok "Nenhum pacote indesejado encontrado."
  else
    warning "Pacotes ainda instalados (execute opção [3]):"
    echo "$REMOVED_CHECK" | sed 's/^/    /'
  fi

  # BUG FIX: verifica Showtime (GNOME 48) além de Totem
  echo
  echo -e "${BOLD}── Flatpaks que deveriam ter sido REMOVIDOS ──${NC}"
  for app in org.gnome.Showtime org.gnome.Totem org.gnome.Music; do
    if flatpak info "$app" &>/dev/null 2>&1; then
      warning "$app ainda instalado — execute opção [3]."
    else
      ok "$app removido."
    fi
  done

  echo
  echo -e "${BOLD}── Apps instalados ──${NC}"
  declare -A APT_CHECKS=(
    ["google-chrome-stable"]="Google Chrome"
    ["papirus-icon-theme"]="Papirus Icon Theme"
    ["audacity"]="Audacity"
    ["blender"]="Blender"
    ["inkscape"]="Inkscape"
    ["darktable"]="Darktable"
    ["handbrake"]="HandBrake"
    ["obs-studio"]="OBS Studio"
    ["easyeffects"]="Easy Effects"
    ["deskflow"]="Deskflow"
    ["timeshift"]="Timeshift"
    ["fastfetch"]="Fastfetch"
    ["lm-sensors"]="LM Sensors"
    ["pipx"]="pipx"
    ["python3-requests"]="python3-requests (GSConnect)"
    ["vlc"]="VLC media player (APT)"
    ["torbrowser-launcher"]="Tor Browser"
    ["converseen"]="Converseen"
    ["shotcut"]="Shotcut"
    ["cheese"]="Cheese"
  )
  for pkg in "${!APT_CHECKS[@]}"; do
    if dpkg -s "$pkg" &>/dev/null 2>&1; then
      ok "${APT_CHECKS[$pkg]}"
    else
      warning "${APT_CHECKS[$pkg]} ($pkg) NÃO instalado"
    fi
  done

  echo
  echo -e "${BOLD}── Flatpaks instalados ──${NC}"
  for app in \
    com.mattjakeman.ExtensionManager \
    io.github.solaar_mouse.solaar \
    com.discordapp.Discord \
    com.github.tchx84.Flatseal \
    net.nokyan.Resources \
    org.freecad.FreeCAD \
    com.jeffser.Alpaca; do
    if flatpak info "$app" &>/dev/null 2>&1; then
      ok "$app"
    else
      warning "$app NÃO instalado"
    fi
  done

  echo
  echo -e "${BOLD}── Configurações GNOME ──${NC}"
  ICON_THEME=$(gsettings get org.gnome.desktop.interface icon-theme 2>/dev/null || echo "não definido")
  COLOR_SCHEME=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo "não definido")
  WALLPAPER=$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null || echo "não definido")
  ok "Icon theme:    $ICON_THEME"
  ok "Color scheme:  $COLOR_SCHEME"
  ok "Wallpaper:     $WALLPAPER"

  echo
  echo -e "${BOLD}── Repositórios ──${NC}"
  if grep -r 'non-free' /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null \
      | grep -v '^#' | grep -q 'non-free'; then
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
  install_packages        # Instala tudo (incluindo Chrome e codecs)
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
    f|F) install_freeoffice ;;
    r|R) echo "Reiniciando..."; sudo reboot ;;
    *) warning "Opção inválida." ;;
  esac
done
