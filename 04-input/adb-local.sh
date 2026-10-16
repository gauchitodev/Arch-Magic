#!/usr/bin/env bash
# ✦ Arch-Magic — ADB contra el propio teléfono, sin cable y sin root
#
# Uso:  ./adb-local.sh emparejar PUERTO CODIGO   una sola vez (necesita Wi-Fi)
#       ./adb-local.sh abrir PUERTO              deja ADB en el 5555 (necesita Wi-Fi)
#       ./adb-local.sh conectar                  se conecta al 5555 (sin Wi-Fi)
#       ./adb-local.sh estado                    qué está conectado
#       ./adb-local.sh cerrar                    apaga el 5555 hasta que se vuelva a abrir
#
# La depuración inalámbrica solo se activa con Wi-Fi. Pero una vez adentro,
# `adb tcpip 5555` deja a ADB escuchando en todas las interfaces, localhost
# incluido, hasta reiniciar: de ahí en más anda sin red.
#
# El usuario `shell` de ADB puede sacar capturas, tocar la pantalla y manejar
# apps, pero no tocar particiones ni datos de otras apps: menos que root.
#
# Anda en Termux (pkg install android-tools) y en Arch (pacman -S android-tools).
# Cada lado tiene su propia llave: la primera vez, Android pregunta si la acepta.

set -euo pipefail

# El servidor de ADB escucha en un socket de archivo dentro de ~/.android (700),
# no en el puerto 5037: ese puerto no pide llave, y cualquier app del teléfono
# que se conectara ahí manejaría el teléfono entero. Así lo usa solo su dueño.
mkdir -p "$HOME/.android" && chmod 700 "$HOME/.android"
export ADB_SERVER_SOCKET="${ADB_SERVER_SOCKET:-localfilesystem:$HOME/.android/adb-server.sock}"

PUERTO_FIJO="${PUERTO_FIJO:-5555}"
LOCAL="127.0.0.1"

violeta=$'\e[38;2;155;107;255m'
dorado=$'\e[38;2;232;193;90m'
rojo=$'\e[31m'
normal=$'\e[0m'
decir() { printf '%s✦%s %s\n' "$violeta" "$normal" "$*"; }
avisar() { printf '%s!%s %s\n' "$dorado" "$normal" "$*"; }
morir() { printf '%s✗%s %s\n' "$rojo" "$normal" "$*" >&2; exit 1; }

command -v adb >/dev/null ||
  morir "Falta adb. Termux: pkg install android-tools · Arch: sudo pacman -S android-tools"

conectado() { adb devices | grep -q "^$LOCAL:$1[[:space:]]*device$"; }

emparejar() {
  [ $# -eq 2 ] || morir "Uso: $0 emparejar PUERTO CODIGO"
  # El cartel con el código se cierra si salís de Ajustes: por eso pantalla dividida.
  adb pair "$LOCAL:$1" "$2"
  decir "Emparejado. Ahora: $0 abrir PUERTO (el de la pantalla principal, no el del código)."
}

abrir() {
  [ $# -eq 1 ] || morir "Uso: $0 abrir PUERTO   (el de Ajustes → Depuración inalámbrica)"
  adb connect "$LOCAL:$1" >/dev/null
  conectado "$1" || morir "No pude conectar a $LOCAL:$1. ¿Emparejaste y el puerto es el de ahora?"
  decir "Pasando ADB al puerto $PUERTO_FIJO…"
  adb -s "$LOCAL:$1" tcpip "$PUERTO_FIJO" >/dev/null
  adb disconnect "$LOCAL:$1" >/dev/null 2>&1 || true
  # adbd se reinicia al cambiar de modo: darle un momento.
  local i
  for i in 1 2 3 4 5; do
    sleep 1
    adb connect "$LOCAL:$PUERTO_FIJO" >/dev/null 2>&1 || true
    if conectado "$PUERTO_FIJO"; then
      decir "Listo: ADB en $LOCAL:$PUERTO_FIJO. Ya podés apagar el Wi-Fi (vale hasta reiniciar)."
      return
    fi
  done
  morir "adbd no volvió en el $PUERTO_FIJO. Mirá: $0 estado"
}

conectar() {
  adb connect "$LOCAL:$PUERTO_FIJO" >/dev/null 2>&1 || true
  if conectado "$PUERTO_FIJO"; then
    decir "Conectado a $LOCAL:$PUERTO_FIJO."
  elif adb devices | grep -q "^$LOCAL:$PUERTO_FIJO[[:space:]]*unauthorized"; then
    avisar "Android pregunta si acepta esta llave: mirá la pantalla y tocá Permitir."
  else
    morir "Nada en el $PUERTO_FIJO. ¿Reiniciaste? Con Wi-Fi: $0 abrir PUERTO"
  fi
}

estado() {
  adb devices -l | sed '1d;/^$/d' | sed 's/^/  /'
  if conectado "$PUERTO_FIJO"; then
    decir "ADB en $PUERTO_FIJO: andando."
  else
    avisar "ADB en $PUERTO_FIJO: no conectado. Probá $0 conectar"
  fi
}

cerrar() {
  conectado "$PUERTO_FIJO" || morir "No hay nada abierto en el $PUERTO_FIJO."
  # Vuelve a modo USB: el 5555 deja de escuchar.
  adb -s "$LOCAL:$PUERTO_FIJO" usb >/dev/null
  adb disconnect "$LOCAL:$PUERTO_FIJO" >/dev/null 2>&1 || true
  decir "Cerrado. ADB ya no escucha en el $PUERTO_FIJO."
}

case "${1:-}" in
  emparejar|abrir|conectar|estado|cerrar) orden="$1"; shift; "$orden" "$@" ;;
  *) sed -n '4,8p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
