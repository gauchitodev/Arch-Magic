#!/data/data/com.termux/files/usr/bin/bash
# ✦ Arch-Magic — correr algo en Arch, con root o sin root
#
# Uso:  ./en-arch.sh                 abre una consola en Arch
#       ./en-arch.sh comando ...     corre el comando en Arch (stdin pasa derecho)
#
# Elige solo cómo entrar:
#   chroot  si hay root y Arch está instalado con arch.sh (rápido, hardware real)
#   proot   si no (anda desde el primer día, ver sin-root.sh)
# Para forzar uno: ARCH_MODO=chroot o ARCH_MODO=proot.
#
# Lo usan el asistente de voz y sway/escritorio.sh, así ellos no tienen que saber
# si el teléfono tiene root o no.

set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
ARCH_MODO="${ARCH_MODO:-auto}"
ARCH_RAIZ="${ARCH_RAIZ:-/data/local/arch}"
ARCH_USUARIO="${ARCH_USUARIO:-gauchito}"
PROOT_DISTRO="${PROOT_DISTRO:-archlinux}"
COMPARTIDA_ANDROID="${COMPARTIDA_ANDROID:-/sdcard/Arch-Magic}"
# El su de verdad. KernelSU (y GhostLock) atrapan esta ruta aunque el archivo no
# exista, y Magisk también la usa; el `su` de Termux no la encuentra.
SU="${SU:-/system/bin/su}"

modo() {
  if [ "$ARCH_MODO" != auto ]; then
    echo "$ARCH_MODO"
  elif "$SU" -c "test -x $ARCH_RAIZ/usr/bin/pacman" 2>/dev/null; then
    echo chroot
  else
    echo proot
  fi
}

# Comillas simples a prueba de todo, para pasar el comando por el sh de Android.
comillas() { printf "'%s'" "${1//\'/\'\\\'\'}"; }

en_chroot() {
  "$AQUI/arch.sh" montar >/dev/null
  if [ $# -eq 0 ]; then
    exec "$AQUI/arch.sh" entrar "$ARCH_USUARIO"
  fi
  local orden
  orden=$(printf '%q ' "$@")
  exec "$SU" -c "chroot $ARCH_RAIZ /usr/bin/su - $ARCH_USUARIO -c $(comillas "$orden")"
}

en_proot() {
  # --shared-tmp: el /tmp de Arch es el de Termux, así se ve el socket de
  # Termux:X11. Igual que en el chroot, de /sdcard solo se comparte una carpeta.
  mkdir -p "$COMPARTIDA_ANDROID" 2>/dev/null || true
  # El repo se ve en /opt/arch-magic, igual que en el chroot.
  local opciones=(--user "$ARCH_USUARIO" --shared-tmp --bind "$(dirname "$AQUI"):/opt/arch-magic")
  [ -d "$COMPARTIDA_ANDROID" ] && opciones+=(--bind "$COMPARTIDA_ANDROID:/mnt/android")

  if [ $# -eq 0 ]; then
    exec proot-distro login "$PROOT_DISTRO" "${opciones[@]}"
  fi
  local orden
  orden=$(printf '%q ' "$@")
  exec proot-distro login "$PROOT_DISTRO" "${opciones[@]}" -- bash -lc "$orden"
}

case "$(modo)" in
  chroot) en_chroot "$@" ;;
  proot)  en_proot "$@" ;;
  *)      echo "✗ ARCH_MODO tiene que ser auto, chroot o proot." >&2; exit 1 ;;
esac
