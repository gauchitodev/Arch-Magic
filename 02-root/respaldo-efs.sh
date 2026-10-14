#!/data/data/com.termux/files/usr/bin/bash
# ✦ Arch-Magic — respaldo de las particiones del módem (IMEI, señal, calibración)
#
# 🚧 Bosquejo: escrito antes de que llegue el teléfono. Probado en una PC con
# particiones de mentira.
#
# Uso:  ./respaldo-efs.sh              respalda (necesita root)
#       ./respaldo-efs.sh verificar    revisa que el último respaldo esté sano
#
# Estas particiones son únicas de TU teléfono: si se borran, perdés el IMEI y la
# señal, y no hay de dónde bajarlas. Respaldá antes de cualquier flasheo y
# sacá la copia del teléfono (a la PC y a otro lado más).

set -euo pipefail

TERMUX_BIN="/data/data/com.termux/files/usr/bin"
DESTINO_BASE="${DESTINO_BASE:-/sdcard/Arch-Magic/respaldo-efs}"

# modemst1/2 y fsg: IMEI y configuración del módem. fsc: su checksum.
# persist: calibración de sensores y del lector de huellas.
PARTICIONES=(modemst1 modemst2 fsg fsc persist)
# Dónde busca las particiones, en orden. Se puede cambiar para probar.
CARPETAS="${CARPETAS:-/dev/block/by-name /dev/block/bootdevice/by-name}"

decir() { printf '\e[38;2;155;107;255m✦\e[0m %s\n' "$*"; }
avisar() { printf '\e[38;2;232;193;90m!\e[0m %s\n' "$*"; }
morir() { printf '\e[31m✗\e[0m %s\n' "$*" >&2; exit 1; }

como_root() {
  [ "$(id -u)" = 0 ] && return
  command -v su >/dev/null || morir "Hace falta root. Antes del root, el respaldo se hace por EDL (ver README)."
  exec su -c "$(printf '%q ' env "DESTINO_BASE=$DESTINO_BASE" "CARPETAS=$CARPETAS" \
    "$TERMUX_BIN/bash" "$(cd "$(dirname "$0")" && pwd)/$(basename "$0")" "$@")"
}

buscar() {
  local carpeta
  for carpeta in $CARPETAS; do
    if [ -e "$carpeta/$1" ]; then echo "$carpeta/$1"; return; fi
  done
}

respaldar() {
  local destino faltan=0 p dispositivo
  destino="$DESTINO_BASE/$(date +%Y-%m-%d-%H%M%S)"
  mkdir -p "$destino"

  for p in "${PARTICIONES[@]}"; do
    dispositivo=$(buscar "$p")
    if [ -z "$dispositivo" ]; then
      avisar "No encuentro $p (puede que este modelo no la tenga)."
      faltan=$((faltan + 1))
      continue
    fi
    decir "Copiando $p…"
    dd if="$dispositivo" of="$destino/$p.img" bs=4M 2>/dev/null
  done

  if [ "$faltan" -ge "${#PARTICIONES[@]}" ]; then
    rmdir "$destino"
    morir "No encontré ninguna partición. ¿Es el teléfono correcto?"
  fi

  # Para saber de dónde salió este respaldo.
  {
    echo "Fecha: $(date)"
    echo "Modelo: $(getprop ro.product.model 2>/dev/null || echo '?')"
    echo "Firmware: $(getprop ro.build.display.id 2>/dev/null || echo '?')"
  } > "$destino/info.txt"

  (cd "$destino" && sha256sum ./*.img > SHA256SUMS)

  decir "Respaldo en $destino"
  avisar "Ahora sacalo del teléfono: copialo a la PC y a un segundo lugar."
  avisar "Nunca lo restaures en otro teléfono: el IMEI es de este."
}

verificar() {
  local ultimo
  ultimo=$(find "$DESTINO_BASE" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -n1)
  [ -n "$ultimo" ] || morir "No hay respaldos en $DESTINO_BASE."
  decir "Verificando $ultimo"
  (cd "$ultimo" && sha256sum -c SHA256SUMS) || morir "¡El respaldo está dañado! Hacé uno nuevo."
  decir "Respaldo sano."
}

case "${1:-}" in
  "")        como_root "$@"; respaldar ;;
  verificar) como_root "$@"; verificar ;;
  *)         sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
