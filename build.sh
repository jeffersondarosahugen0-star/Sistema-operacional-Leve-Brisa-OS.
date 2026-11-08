#!/usr/bin/env bash
# Compila a ISO do Brisa OS. Requer Debian 12 (ou container debian:bookworm), root e internet.
set -euo pipefail
cd "$(dirname "$0")"
chmod +x auto/* scripts/*.sh scripts/*.py config/hooks/live/* 2>/dev/null || true
[ "$(id -u)" -eq 0 ] || { echo "Execute como root."; exit 1; }
VERSION=0.1
ISO_NAME="brisa-os-${VERSION}-amd64.iso"
MAX=$((1200*1024*1024))
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends live-build debootstrap debian-archive-keyring ca-certificates \
  xorriso squashfs-tools syslinux syslinux-common syslinux-utils isolinux mtools dosfstools xz-utils zstd file python3

TIERS=(extras-2 extras-1)     # removidas nesta ordem se a ISO passar de 1,2 GB
DROPPED=()
attempt=0
while :; do
  attempt=$((attempt+1))
  echo "===== Tentativa $attempt ====="
  lb clean --purge >/dev/null 2>&1 || true
  rm -f ./*.iso
  if ! BRISA_LB_EXTRA="--chroot-squashfs-compression-type xz" lb config; then
    echo "AVISO: opcoes de compressao rejeitadas; configurando sem elas"
    lb config
  fi
  set +e; lb build 2>&1 | tee build.log; rc=${PIPESTATUS[0]}; set -e
  [ "$rc" -eq 0 ] || { echo "ERRO: lb build falhou (codigo $rc). Veja build.log"; exit 3; }
  ISO=$(ls -1 ./*.iso | head -1)
  SIZE=$(stat -c%s "$ISO")
  echo "Tamanho: $((SIZE/1024/1024)) MiB (limite $((MAX/1024/1024)) MiB)"
  echo "--- 30 maiores pacotes instalados (KiB) ---"
  dpkg-query --admindir=chroot/var/lib/dpkg -Wf '${Installed-Size}\t${Package}\n' 2>/dev/null | sort -rn | head -30 | tee pacotes-maiores.txt || true
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
  echo "Tamanho: $((SIZE/1024/1024)) MiB"
  echo "SHA-256: $(cut -d' ' -f1 "$ISO_NAME.sha256")"
  echo "Camadas removidas para caber em 1,2 GB: ${DROPPED[*]:-nenhuma}"
  echo "Verificacoes estaticas: $([ $FAIL -eq 0 ] && echo aprovadas || echo REPROVADAS)"
} | tee build-info.txt
[ "$FAIL" -eq 0 ] || { echo "ERRO: verificacoes reprovadas"; exit 4; }
echo "Teste em VM (BIOS legado): scripts/boot-test.sh $ISO_NAME"
