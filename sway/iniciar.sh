#!/usr/bin/env bash
# ✦ Arch-Magic — arranca Sway adentro de Arch, dibujando en Termux:X11.
#
# 🚧 Bosquejo: escrito antes de que llegue el teléfono, sin probar.
#
# Antes: en Termux, `termux-x11 :0 &` y abrir la app Termux:X11.
# Después, adentro de Arch:  /opt/arch-magic/sway/iniciar.sh

# En /tmp para que el demonio de entradas (04-input) encuentre el socket de
# Sway desde afuera del chroot.
export XDG_RUNTIME_DIR="/tmp/runtime-$USER"
mkdir -p "$XDG_RUNTIME_DIR" && chmod 700 "$XDG_RUNTIME_DIR"

export DISPLAY=:0
export WLR_BACKENDS=x11
export WLR_RENDERER=pixman   # sin GPU: Termux:X11 no tiene aceleración

exec sway
