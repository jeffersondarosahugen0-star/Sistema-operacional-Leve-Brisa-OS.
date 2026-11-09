#!/bin/bash
# Brisa OS - Etapa 1: monta a ISO (BIOS/MBR, amd64) com live-build.
set -e
cd "$(dirname "$0")"

# o upload pelo site do GitHub perde a permissão de execução: restaurar
chmod +x config/hooks/live/*.chroot 2>/dev/null || true
chmod +x config/includes.chroot_after_packages/usr/local/bin/* 2>/dev/null || true

lb config \
  --distribution bookworm \
  --architectures amd64 \
  --linux-flavours amd64 \
  --archive-areas "main contrib non-free non-free-firmware" \
  --mirror-bootstrap http://deb.debian.org/debian/ \
  --mirror-chroot http://deb.debian.org/debian/ \
  --mirror-binary http://deb.debian.org/debian/ \
  --binary-images iso-hybrid \
  --bootloaders syslinux \
  --debian-installer none \
  --apt-recommends false \
  --memtest none \
  --chroot-squashfs-compression-type zstd \
  --iso-application "Brisa OS" \
  --iso-volume "BRISA_OS" \
  --bootappend-live "boot=live components quiet username=brisa hostname=brisa locales=pt_BR.UTF-8 keyboard-layouts=br timezone=America/Sao_Paulo"

lb build

ls -lh ./*.iso
mv ./live-image-amd64.hybrid.iso ./brisa-os-etapa1.iso
ls -lh ./brisa-os-etapa1.iso
