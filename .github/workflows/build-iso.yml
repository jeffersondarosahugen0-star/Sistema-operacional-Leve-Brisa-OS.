#!/usr/bin/env bash
# Compila a ISO do Brisa OS (Debian 12 "bookworm", amd64, BIOS legado/MBR).
# Requer container/host Debian 12, root e internet.
set -euo pipefail
cd "$(dirname "$0")"
chmod +x auto/* scripts/*.sh scripts/*.py config/hooks/live/* 2>/dev/null || true
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

# Configuracao explicita: nao depende de auto/config nem do padrao do lb (que causou Bullseye).
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

TIERS=(extras-2 extras-1)   # removidas nesta ordem se a ISO passar de 1,2 GB
DROPPED=()
while :; do
  echo "===== Compilacao (camadas removidas: ${DROPPED[*]:-nenhuma}) ====="
  lb clean --purge >/dev/null 2>&1 || true
  rm -rf cache .build chroot binary ./*.iso
  lbcfg
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
for f in usr/bin/wine usr/bin/firefox-esr usr/bin/calamares usr/bin/thunar usr/bin/xfce4-taskmanager usr/bin/xfce4-settings-manager usr/sbin/grub-install usr/sbin/mount.ntfs usr/sbin/mkfs.exfat; do
  if [ -e "chroot/$f" ] || [ -L "chroot/$f" ]; then echo "OK  $f"; else echo "FALTA $f"; FAIL=1; fi
done
python3 scripts/check_iso.py "$ISO_NAME" || FAIL=1

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
