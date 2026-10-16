#!/usr/bin/env bash
# ✦ Arch-Magic — el ventilador del RM10 Pro desde la consola
#
# Uso:  ./ventilador.sh estado        temperaturas, si está prendido y a cuántas RPM
#       ./ventilador.sh prender       modo normal (nivel 2, ~8.400 RPM)
#       ./ventilador.sh fuerte        modo fuerte (nivel 4, ~16.400 RPM)
#       ./ventilador.sh apagar
#       ./ventilador.sh auto [PRENDE] [APAGA]
#                                     lo prende solo si la piel pasa PRENDE °C
#                                     (40) y lo apaga al bajar de APAGA °C (37)
#       ./ventilador.sh arrancar      deja `auto` corriendo de fondo, si no lo está
#                                     (para el .bashrc de Termux)
#       ./ventilador.sh parar         frena el `auto` de fondo
#
# El botón de los ajustes rápidos no habla con el kernel: cambia ajustes de
# Android, y la app del ventilador (cn.nubia.fan) los pasa a /sys/kernel/fan.
# Probado en NX789J, RedMagicOS 10.0.9:
#   system fan_state_of_manual   2 prende · -2 apaga
#   system fan_state_of_mode     1 normal · 0 fuerte
# (global game_fan_off_on es solo un reflejo: cambiarlo no hace nada.)
#
# Escribir esos ajustes necesita ADB: ver adb-local.sh. Leer el estado no.

set -euo pipefail

ADB_DESTINO="${ADB_DESTINO:-127.0.0.1:5555}"
FAN=/sys/kernel/fan
# Dónde deja su número y su registro el `auto` de fondo.
CARPETA="${TMPDIR:-/tmp}/arch-magic"
PIDFILE="$CARPETA/ventilador.pid"
REGISTRO="$CARPETA/ventilador.log"

violeta=$'\e[38;2;155;107;255m'
dorado=$'\e[38;2;232;193;90m'
rojo=$'\e[31m'
normal=$'\e[0m'
decir() { printf '%s✦%s %s\n' "$violeta" "$normal" "$*"; }
avisar() { printf '%s!%s %s\n' "$dorado" "$normal" "$*"; }
morir() { printf '%s✗%s %s\n' "$rojo" "$normal" "$*" >&2; exit 1; }

adb_shell() { adb -s "$ADB_DESTINO" shell "$@" | tr -d '\r'; }

# Lee un archivo de /sys directo si se puede (Arch), y si no por ADB (Termux,
# donde SELinux no deja a las apps mirar /sys).
leer() {
  if [ -r "$1" ]; then cat "$1" 2>/dev/null || true
  else adb_shell cat "$1" 2>/dev/null || true
  fi
}

# Temperatura de una zona térmica por nombre, en grados enteros.
temp() {
  local z
  local z t
  for z in /sys/class/thermal/thermal_zone*; do
    if [ "$(leer "$z/type")" = "$1" ]; then
      t=$(leer "$z/temp")
      [[ "$t" =~ ^[0-9]+$ ]] && echo $(( t / 1000 )) || echo "?"
      return
    fi
  done
  echo "?"
}

# Conecta ADB si hace falta (después de cerrar Termux, la conexión se pierde).
hay_adb() {
  adb -s "$ADB_DESTINO" get-state >/dev/null 2>&1 && return
  adb connect "$ADB_DESTINO" >/dev/null 2>&1 || true
  adb -s "$ADB_DESTINO" get-state >/dev/null 2>&1
}

poner() {
  hay_adb || morir "Sin ADB en $ADB_DESTINO. Probá: $(dirname "$0")/adb-local.sh conectar"
  adb_shell settings put system "$1" "$2"
}

prendido() { [ "$(leer $FAN/fan_enable)" = 1 ]; }

estado() {
  local piel cpu bateria
  piel=$(temp skin-msm-therm); cpu=$(temp cpu-0-0-0); bateria=$(temp battery)
  printf '  piel %s°C · cpu %s°C · batería %s°C\n' "$piel" "$cpu" "$bateria"
  if prendido; then
    decir "Ventilador prendido: nivel $(leer $FAN/fan_speed_level), $(leer $FAN/fan_speed_count) RPM."
  else
    decir "Ventilador apagado."
  fi
}

prender() { poner fan_state_of_mode 1; poner fan_state_of_manual 2; decir "Prendido (normal)."; }
fuerte()  { poner fan_state_of_mode 0; poner fan_state_of_manual 2; decir "Prendido (fuerte)."; }
apagar()  { poner fan_state_of_manual -2; decir "Apagado."; }

auto() {
  local prende="${1:-40}" apaga="${2:-37}" piel lo_prendi=0
  [ "$apaga" -lt "$prende" ] || morir "APAGA tiene que ser menor que PRENDE."
  decir "Vigilando: prende a ${prende}°C, apaga a ${apaga}°C. Ctrl+C para salir."
  local sin_adb=0
  while true; do
    # Sin ADB no hay cómo prenderlo: esperar a que vuelva (después de reiniciar,
    # hasta que se haga adb-local.sh abrir) sin morirse.
    if ! hay_adb; then
      [ "$sin_adb" = 1 ] || avisar "$(date +%H:%M) sin ADB: espero a que vuelva."
      sin_adb=1; sleep 30; continue
    fi
    [ "$sin_adb" = 0 ] || decir "$(date +%H:%M) ADB de vuelta."
    sin_adb=0
    piel=$(temp skin-msm-therm)
    if [ "$piel" != "?" ]; then
      if [ "$piel" -ge "$prende" ] && ! prendido; then
        prender >/dev/null; lo_prendi=1
        decir "$(date +%H:%M) piel ${piel}°C: prendo."
      # Solo apaga si lo prendió él: si lo prendiste vos, es tuyo.
      elif [ "$piel" -le "$apaga" ] && [ "$lo_prendi" = 1 ] && prendido; then
        apagar >/dev/null; lo_prendi=0
        decir "$(date +%H:%M) piel ${piel}°C: apago."
      fi
    fi
    sleep 10
  done
}

corriendo() { [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

arrancar() {
  corriendo && return
  mkdir -p "$CARPETA"
  # Ruta completa y bash explícito: anda aunque lo hayan llamado como `bash ventilador.sh`.
  nohup bash "$(cd "$(dirname "$0")" && pwd)/$(basename "$0")" auto "$@" >>"$REGISTRO" 2>&1 &
  echo $! > "$PIDFILE"
}

parar() {
  corriendo || { avisar "No hay ningún auto corriendo."; return; }
  kill "$(cat "$PIDFILE")"; rm -f "$PIDFILE"
  decir "Auto frenado. Registro en $REGISTRO"
}

case "${1:-}" in
  estado|prender|fuerte|apagar|parar) "$1" ;;
  auto|arrancar) orden="$1"; shift; "$orden" "$@" ;;
  *) sed -n '4,14p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
