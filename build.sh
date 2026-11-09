#!/usr/bin/env bash
# Compila a ISO do Brisa OS (Debian 12 "bookworm", amd64, BIOS legado/MBR).
# Requer container/host Debian 12, root e internet.
# As listas de pacotes e o hook sao GERADOS aqui, para nao depender do upload da pasta config/.
set -euo pipefail
cd "$(dirname "$0")"
chmod +x auto/* scripts/*.sh scripts/*.py 2>/dev/null || true
[ "$(id -u)" -eq 0 ] || { echo "Execute como root."; exit 1; }

VERSION=0.1
ISO_NAME="brisa-os-${VERSION}-amd64.iso"
MAX=$((1200*1024*1024))
export DEBIAN_FRONTEND=noninteractive
MIRROR=http://deb.debian.org/debian
SECMIRROR=http://security.debian.org/debian-security

apt-get update
apt-get install -y --no-install-recommends live-build debootstrap debian-archive-keyring ca-certificates \
  xorriso squashfs-tools syslinux syslinux-common syslinux-utils isolinux mtools dosfstools xz-utils zstd file python3
echo "live-build instalado: $(dpkg-query -W -f='${Version}' live-build)"

lbcfg() {
  lb config noauto \
    --distribution bookworm \
    --architectures amd64 \
    --linux-flavours amd64 \
    --mirror-bootstrap "$MIRROR" \
    --mirror-chroot "$MIRROR" \
    --mirror-binary "$MIRROR" \
    --mirror-chroot-security "$SECMIRROR" \
    --mirror-binary-security "$SECMIRROR" \
    --binary-images iso-hybrid \
    --bootloaders syslinux \
    --debian-installer none \
    --archive-areas "main contrib non-free non-free-firmware" \
    --apt-indices false \
    --apt-recommends false \
    --memtest none \
    --security true \
    --chroot-squashfs-compression-type xz \
    --iso-application "Brisa OS" \
    --iso-publisher "Brisa OS Project" \
    --iso-volume "BRISA_OS" \
    --bootappend-live "boot=live components quiet locales=pt_BR.UTF-8 keyboard-layouts=br timezone=America/Sao_Paulo username=brisa hostname=brisa"
}

# Escreve listas de pacotes e hook dentro de config/ (criados pelo lb config).
escreve_config() {
  mkdir -p config/package-lists config/hooks/live

  cat > config/package-lists/brisa.list.chroot <<'BRISA_FIM'
xfce4-session xfwm4 xfdesktop4 xfce4-panel xfce4-settings xfce4-power-manager
xfce4-whiskermenu-plugin xfce4-pulseaudio-plugin xfce4-notifyd xfce4-terminal
xfce4-taskmanager xfce4-appfinder
thunar thunar-volman thunar-archive-plugin file-roller mousepad
lightdm lightdm-gtk-greeter dbus-x11 policykit-1 policykit-1-gnome sudo
xdg-utils xdg-user-dirs desktop-file-utils shared-mime-info
arc-theme papirus-icon-theme fonts-open-sans librsvg2-common adwaita-icon-theme
ntfs-3g exfatprogs exfat-fuse dosfstools e2fsprogs parted rsync gvfs gvfs-backends udisks2
network-manager network-manager-gnome wpasupplicant iw rfkill
pipewire pipewire-pulse wireplumber pavucontrol alsa-utils
xserver-xorg-core xserver-xorg-video-all xserver-xorg-input-libinput
libgl1-mesa-dri usbutils usb-modeswitch
firmware-linux-free firmware-misc-nonfree firmware-realtek firmware-atheros firmware-iwlwifi firmware-brcm80211 firmware-amd-graphics
firefox-esr firefox-esr-l10n-pt-br
curl ca-certificates nano
locales console-setup keyboard-configuration
live-boot live-config live-config-systemd
calamares calamares-settings-debian grub-pc os-prober
BRISA_FIM

  # Camadas opcionais: escritas so se nao existirem (nao reescreve quando removidas para caber em 1,2 GB)
  if [ ! -f config/package-lists/extras-1.list.chroot ] && [ ! -f config/dropped/extras-1.list.chroot ]; then
    echo "gparted mpv evince galculator ristretto xfce4-screenshooter" > config/package-lists/extras-1.list.chroot
  fi
  if [ ! -f config/package-lists/extras-2.list.chroot ] && [ ! -f config/dropped/extras-2.list.chroot ]; then
    echo "gnome-mines gnome-sudoku aisleriot quadrapassel five-or-more" > config/package-lists/extras-2.list.chroot
  fi

  cat > config/hooks/live/0100-brisa.hook.chroot <<'BRISA_FIM'
#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Locale / fuso
sed -i 's/^# *pt_BR.UTF-8/pt_BR.UTF-8/' /etc/locale.gen
locale-gen
update-locale LANG=pt_BR.UTF-8
echo "America/Sao_Paulo" > /etc/timezone

# Wine (precisa de multiarch i386). Steam NAO vai na ISO (muito grande): script de instalação sob demanda.
dpkg --add-architecture i386
apt-get update
apt-get install -y --no-install-recommends wine wine64 wine32:i386 libwine libwine:i386 fonts-wine \
  || echo "AVISO: Wine nao instalado (o build.sh vai acusar)"

cat > /usr/share/applications/wine-exe.desktop <<'EOT'
[Desktop Entry]
Type=Application
Name=Executar com Wine
Exec=wine start /unix %f
MimeType=application/x-ms-dos-executable;application/x-msdownload;application/vnd.microsoft.portable-executable;
NoDisplay=true
EOT
update-desktop-database || true

# Launchers do painel (o plugin lê a pasta launcher-N)
mk() { d=/etc/skel/.config/xfce4/panel/launcher-$1; mkdir -p "$d"; cp "/usr/share/applications/$2" "$d/" 2>/dev/null || echo "AVISO: $2 ausente"; }
mk 3 thunar.desktop
mk 4 firefox-esr.desktop
mk 5 xfce-settings-manager.desktop

# Atalho do instalador na área de trabalho
mkdir -p /etc/skel/Desktop
cp /usr/share/applications/brisa-instalar.desktop /etc/skel/Desktop/ 2>/dev/null || echo "AVISO: atalho do instalador ausente"
chmod +x /etc/skel/Desktop/brisa-instalar.desktop 2>/dev/null || true

# Identidade do sistema (sem quebrar ID_LIKE=debian)
sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="Brisa OS 0.1 (base Debian 12)"/; s/^NAME=.*/NAME="Brisa OS"/' /etc/os-release || true

# Marca no instalador (apenas textos)
for f in $(find /etc/calamares /usr/share/calamares -name branding.desc 2>/dev/null); do
  sed -i 's/Debian GNU\/Linux/Brisa OS/g; s/Debian/Brisa OS/g' "$f" || true
done

# Repositórios finais (para apt no sistema instalado/live)
cat > /etc/apt/sources.list <<'EOT'
deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
EOT

# Limpeza para reduzir a ISO
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/* /usr/share/doc/* /usr/share/man/* /usr/share/info/* /var/log/*.log
find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'pt*' ! -name 'en*' ! -name locale.alias -exec rm -rf {} +
BRISA_FIM
  chmod +x config/hooks/live/0100-brisa.hook.chroot
}

# Conferencia: as listas e o hook precisam estar presentes antes de compilar.
TIERS=(extras-2 extras-1)   # removidas nesta ordem se a ISO passar de 1,2 GB
DROPPED=()
while :; do
  echo "===== Compilacao (camadas removidas: ${DROPPED[*]:-nenhuma}) ====="
  rm -rf cache .build chroot binary ./*.iso
  lbcfg
  escreve_config
  echo "Config gerada: $(wc -l < config/package-lists/brisa.list.chroot) linhas em brisa.list.chroot; hook: $(wc -l < config/hooks/live/0100-brisa.hook.chroot) linhas."
  set +e; lb build 2>&1 | tee build.log; rc=${PIPESTATUS[0]}; set -e
  if [ "$rc" -ne 0 ]; then
    echo "ERRO: lb build falhou (codigo $rc). Ultimas linhas:"
    tail -n 60 build.log
    exit 3
  fi
  ISO=$(ls -1 ./*.iso | head -1)
  SIZE=$(stat -c%s "$ISO")
  echo "Tamanho: $((SIZE/1048576)) MiB (limite $((MAX/1048576)) MiB)"
  dpkg-query --admindir=chroot/var/lib/dpkg -Wf '${Installed-Size}\t${Package}\n' 2>/dev/null | sort -rn | head -30 > pacotes-maiores.txt || true
  [ "$SIZE" -le "$MAX" ] && break
  if [ ${#TIERS[@]} -eq 0 ]; then echo "ERRO: ISO acima de 1,2 GB mesmo sem extras."; exit 2; fi
  T=${TIERS[0]}; TIERS=("${TIERS[@]:1}"); DROPPED+=("$T")
  echo "ISO grande demais: removendo camada $T e recompilando"
  mkdir -p config/dropped && mv "config/package-lists/$T.list.chroot" config/dropped/
done

mv "$ISO" "$ISO_NAME"
sha256sum "$ISO_NAME" | tee "$ISO_NAME.sha256"

echo "===== Verificacoes ====="
FAIL=0

# 1) MBR/BIOS legado: assinatura 0x55AA e ao menos uma particao MBR
python3 - "$ISO_NAME" <<'PY' || FAIL=1
import sys
d = open(sys.argv[1], "rb").read(512)
ok_sig = d[510:512] == b"\x55\xaa"
parts = [d[446+16*i+4] for i in range(4) if d[446+16*i+4] != 0]
print(("OK  " if ok_sig else "FALTA ") + "assinatura MBR 0x55AA")
print(("OK  " if parts else "FALTA ") + f"particoes MBR: {len(parts)}")
sys.exit(0 if (ok_sig and parts) else 1)
PY

# 2) Pacotes instalados dentro do squashfs (le a base dpkg do sistema gerado)
SQ=$(find binary -name filesystem.squashfs 2>/dev/null | head -1 || true)
if [ -z "$SQ" ]; then
  echo "FALTA filesystem.squashfs. Conteudo de binary/:"; find binary -maxdepth 3 | head -30; FAIL=1
else
  echo "squashfs encontrado: $SQ ($(stat -c%s "$SQ") bytes)"
  rm -rf sqx && unsquashfs -no-progress -f -d sqx "$SQ" var/lib/dpkg/status > /dev/null 2> squashfs-erro.txt || true
  if [ ! -s sqx/var/lib/dpkg/status ]; then
    echo "ERRO: nao consegui ler var/lib/dpkg/status do squashfs"; head -5 squashfs-erro.txt; FAIL=1
  else
    echo "pacotes instalados no sistema: $(grep -c '^Status: install ok installed' sqx/var/lib/dpkg/status)"
    for pkg in wine firefox-esr calamares thunar xfce4-session xfce4-taskmanager xfce4-settings grub-pc ntfs-3g exfatprogs lightdm live-boot; do
      if awk -v p="$pkg" '/^Package: /{cur=$2} /^Status: install ok installed/{if(cur==p) f=1} END{exit !f}' sqx/var/lib/dpkg/status; then
        echo "OK  pacote $pkg"
      else
        echo "FALTA pacote $pkg"; FAIL=1
      fi
    done
  fi
fi

{
  echo "Brisa OS $VERSION"
  echo "Data: $(date -u +%F)"
  echo "Tamanho: $((SIZE/1048576)) MiB"
  echo "SHA-256: $(cut -d' ' -f1 "$ISO_NAME.sha256")"
  echo "Camadas removidas para caber em 1,2 GB: ${DROPPED[*]:-nenhuma}"
  echo "Verificacoes estaticas: $([ $FAIL -eq 0 ] && echo aprovadas || echo REPROVADAS)"
} | tee build-info.txt
[ "$FAIL" -eq 0 ] || { echo "ERRO: verificacoes reprovadas"; exit 4; }
echo "OK. Teste em VM (BIOS legado): bash scripts/boot-test.sh $ISO_NAME"
