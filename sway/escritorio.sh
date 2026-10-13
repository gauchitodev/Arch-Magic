#!/data/data/com.termux/files/usr/bin/bash
# ✦ Arch-Magic — abre el escritorio: Termux:X11 + Sway adentro de Arch
#
# 🚧 Bosquejo: escrito antes de que llegue el teléfono, sin probar.
#
# Uso (desde Termux):  ./escritorio.sh
#
# Anda con root (chroot) o sin root (proot): de eso se encarga en-arch.sh.

set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
EN_ARCH="$AQUI/../03-chroot/en-arch.sh"
# Este repo adentro de Arch: lo montan arch.sh y en-arch.sh.
REPO_EN_ARCH="/opt/arch-magic"

if ! pgrep -f termux-x11 >/dev/null; then
  termux-x11 :0 >/dev/null 2>&1 &
  sleep 2
fi
am start -n com.termux.x11/.MainActivity >/dev/null 2>&1

# Sonido: Arch le habla al PulseAudio de Termux por TCP.
pulseaudio --start --exit-idle-time=-1 \
  --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" 2>/dev/null || true

exec "$EN_ARCH" env PULSE_SERVER=tcp:127.0.0.1 "$REPO_EN_ARCH/sway/iniciar.sh"
