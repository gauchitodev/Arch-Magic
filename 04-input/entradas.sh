#!/data/data/com.termux/files/usr/bin/bash
# ✦ Arch-Magic — demonio de entradas físicas
#
# 🚧 Bosquejo: escrito antes de que llegue el teléfono, sin probar. Los códigos
# de las teclas son de mentira hasta que corramos `su -c getevent -l`.
#
#   slider afuera           → muestra el teclado en pantalla
#   slider adentro          → lo esconde
#   gatillo izquierdo       → pantalla de trabajo anterior
#   gatillo derecho         → pantalla de trabajo siguiente
#   los dos gatillos juntos → asistente de voz (de nuevo para cortar)
#
# Corre en Termux como usuario normal: solo getevent y Sway van con su.

set -euo pipefail

# --- Configuración -----------------------------------------------------------

AQUI="$(cd "$(dirname "$0")" && pwd)"
ASISTENTE="${ASISTENTE:-$AQUI/../05-voice/asistente.sh}"
ARCH_RAIZ="${ARCH_RAIZ:-/data/local/arch}"
# El su de verdad. KernelSU (y GhostLock) atrapan esta ruta aunque el archivo no
# exista, y Magisk también la usa; el `su` de Termux no la encuentra.
SU="${SU:-/system/bin/su}"

# Completar con lo que diga `su -c getevent -l` al tocar cada cosa.
SLIDER="${SLIDER:-CODIGO_SLIDER}"
GATILLO_IZQ="${GATILLO_IZQ:-CODIGO_GATILLO_IZQ}"
GATILLO_DER="${GATILLO_DER:-CODIGO_GATILLO_DER}"
# Si el teclado aparece al revés (al meter el slider), poner 1.
SLIDER_INVERTIDO="${SLIDER_INVERTIDO:-0}"

TECLADO="wvkbd-mobintl"

# --- Acciones ----------------------------------------------------------------

# swaymsg desde afuera de Arch: se busca el socket de Sway en el /tmp del chroot.
sway() {
  "$SU" -c "
    sock=\$(ls $ARCH_RAIZ/tmp/runtime-*/sway-ipc.*.sock 2>/dev/null | head -n1)
    [ -n \"\$sock\" ] && chroot $ARCH_RAIZ /usr/bin/swaymsg -s \"\${sock#$ARCH_RAIZ}\" $*
  " >/dev/null || true
}

# wvkbd: SIGUSR1 lo esconde, SIGUSR2 lo muestra.
teclado() {
  local senal=USR1
  [ "$1" = mostrar ] && senal=USR2
  "$SU" -c "pkill -$senal -x $TECLADO" 2>/dev/null || true
}

voz() { "$ASISTENTE" >/dev/null 2>&1 & }

# --- Bucle -------------------------------------------------------------------

# Los gatillos actúan al soltarlos: así, si apretaste los dos juntos, no se
# mueve la pantalla antes de que arranque el asistente.
izq=0 der=0 combo=0

apretar() {
  case "$1" in
    izq) izq=1 ;;
    der) der=1 ;;
  esac
  if [ "$izq" = 1 ] && [ "$der" = 1 ]; then combo=1; fi
}

soltar() {
  case "$1" in
    izq) izq=0 ;;
    der) der=0 ;;
  esac
  if [ "$combo" = 1 ]; then
    # Se dispara una sola vez, cuando se suelta el último de los dos.
    if [ "$izq" = 0 ] && [ "$der" = 0 ]; then combo=0; voz; fi
    return
  fi
  case "$1" in
    izq) sway workspace prev_on_output ;;
    der) sway workspace next_on_output ;;
  esac
}

slider() {
  local afuera="$1"
  [ "$SLIDER_INVERTIDO" = 1 ] && afuera=$((1 - afuera))
  if [ "$afuera" = 1 ]; then teclado mostrar; else teclado esconder; fi
}

# Líneas de getevent -lq:  /dev/input/event3: EV_KEY  KEY_F13  DOWN
"$SU" -c "getevent -lq" | while read -r _ _ codigo valor; do
  case "$valor" in
    DOWN|00000001) estado=1 ;;
    UP|00000000)   estado=0 ;;
    *) continue ;;   # REPEAT y otros
  esac
  case "$codigo" in
    "$SLIDER")      slider "$estado" ;;
    "$GATILLO_IZQ") if [ "$estado" = 1 ]; then apretar izq; else soltar izq; fi ;;
    "$GATILLO_DER") if [ "$estado" = 1 ]; then apretar der; else soltar der; fi ;;
  esac
done
