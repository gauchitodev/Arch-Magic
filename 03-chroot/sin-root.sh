#!/data/data/com.termux/files/usr/bin/bash
# ✦ Arch-Magic — Arch Linux sin root (proot)
#
# 🚧 Bosquejo: escrito antes de que llegue el teléfono, sin probar.
#
# Uso:  ./sin-root.sh instalar     instala Arch con proot-distro
#       ./sin-root.sh configurar   paquetes, idioma, zona horaria y tu usuario
#
# Después se entra con ./en-arch.sh, igual que con root.
#
# Es más lento que el chroot y no ve el hardware, pero anda desde el primer día
# y no toca nada de Android. Cuando haya root, arch.sh toma la posta.

set -euo pipefail

PROOT_DISTRO="${PROOT_DISTRO:-archlinux}"
ARCH_USUARIO="${ARCH_USUARIO:-gauchito}"
ARCH_IDIOMA="${ARCH_IDIOMA:-es_UY.UTF-8}"
ARCH_ZONA="${ARCH_ZONA:-America/Montevideo}"

violeta=$'\e[38;2;155;107;255m'
normal=$'\e[0m'
decir() { printf '%s✦%s %s\n' "$violeta" "$normal" "$*"; }

# Como root adentro de Arch (en proot, root es de mentira: no toca Android).
como_root() { proot-distro login "$PROOT_DISTRO" -- bash -c "$1"; }

instalar() {
  decir "Paquetes de Termux…"
  pkg update -y
  pkg install -y proot-distro x11-repo
  pkg install -y termux-x11-nightly pulseaudio

  decir "Instalando Arch (proot-distro ya deja pacman listo)…"
  proot-distro install "$PROOT_DISTRO"

  decir "Listo. Seguí con: ./sin-root.sh configurar"
}

configurar() {
  decir "Actualizando Arch…"
  como_root "pacman -Syu --noconfirm && pacman -S --noconfirm --needed sudo git curl base-devel"

  decir "Idioma y zona horaria…"
  como_root "
    sed -i 's/^#\\($ARCH_IDIOMA\\)/\\1/' /etc/locale.gen
    locale-gen
    echo LANG=$ARCH_IDIOMA > /etc/locale.conf
    ln -sf /usr/share/zoneinfo/$ARCH_ZONA /etc/localtime
  "

  decir "Usuario $ARCH_USUARIO…"
  # Sin contraseña para sudo: en proot root es de mentira y no puede tocar
  # Android, así que no hay nada que proteger. Con root real (arch.sh) sí pide.
  como_root "
    id $ARCH_USUARIO >/dev/null 2>&1 || useradd -m -G wheel -s /bin/bash $ARCH_USUARIO
    echo '%wheel ALL=(ALL:ALL) NOPASSWD: ALL' > /etc/sudoers.d/wheel
    chmod 440 /etc/sudoers.d/wheel
  "

  decir "Arch listo. Entrá con: ./en-arch.sh"
}

case "${1:-}" in
  instalar)   instalar ;;
  configurar) configurar ;;
  *)          sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
