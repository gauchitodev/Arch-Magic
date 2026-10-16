#!/data/data/com.termux/files/usr/bin/bash
# ✦ Arch-Magic — sacar lo que sobra de RedMagic OS, sin romper nada
#
# Uso:  ./debloat.sh listar               guarda qué apps trae de fábrica
#       ./debloat.sh sacar [lista]        saca las de la lista (por defecto sacar.txt)
#       ./debloat.sh restaurar [paquete]  vuelve a poner todo lo sacado, o uno
#
# Necesita root (GhostLock sirve). No borra nada del sistema: "pm uninstall
# --user 0" solo la saca para tu usuario, y restaurar la vuelve a poner tal cual.

set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
# El su de verdad. KernelSU (y GhostLock) atrapan esta ruta aunque el archivo no
# exista, y Magisk también la usa; el `su` de Termux no la encuentra.
SU="${SU:-/system/bin/su}"
# Lo sacado se anota acá, afuera del repo, para poder restaurarlo siempre.
REGISTRO="${REGISTRO:-/sdcard/Arch-Magic/debloat-sacados.txt}"

# Nunca, aunque estén en la lista: sin estas el teléfono no arranca, no llama o
# perdés el root y Termux.
PROTEGIDOS=(
  android com.android.systemui com.android.settings com.android.phone
  com.android.shell com.android.providers.settings com.android.providers.telephony
  com.android.packageinstaller com.google.android.packageinstaller
  com.android.permissioncontroller com.google.android.permissioncontroller
  com.termux com.termux.api com.termux.x11 com.termux.widget com.termux.boot
  me.weishu.kernelsu
)

decir() { printf '\e[38;2;155;107;255m✦\e[0m %s\n' "$*"; }
avisar() { printf '\e[38;2;232;193;90m!\e[0m %s\n' "$*"; }
morir() { printf '\e[31m✗\e[0m %s\n' "$*" >&2; exit 1; }

pm_root() { "$SU" -c "pm $*"; }

protegido() {
  local p
  for p in "${PROTEGIDOS[@]}"; do [ "$1" = "$p" ] && return 0; done
  return 1
}

listar() {
  local firmware salida
  firmware=$(getprop ro.build.display.id 2>/dev/null || echo desconocido)
  salida="$AQUI/paquetes-$firmware.txt"

  # package:/ruta/base.apk=nombre  →  nombre  ruta
  {
    # Solo las de fábrica (-s): las que instalaste vos no van al repo.
    echo "# Apps de fábrica de $firmware ($(date +%Y-%m-%d)) y dónde viven."
    pm_root "list packages -f -s" | sed 's/^package://' \
      | awk '{ i = index($0, ".apk="); printf "%-55s %s\n", substr($0, i + 5), substr($0, 1, i + 3) }' \
      | sort
  } > "$salida"

  decir "$(grep -vc '^#' "$salida") apps de fábrica guardadas en $salida"
}

sacar() {
  local lista="${1:-$AQUI/sacar.txt}" paquete paquetes=() p
  [ -f "$lista" ] || morir "No encuentro $lista."

  # Una app por línea; lo que va después de # es comentario.
  while read -r paquete _; do
    paquete="${paquete%%#*}"
    [ -n "$paquete" ] || continue
    if protegido "$paquete"; then
      avisar "$paquete está protegida: no se toca."
      continue
    fi
    paquetes+=("$paquete")
  done < "$lista"
  [ "${#paquetes[@]}" -gt 0 ] || morir "La lista está vacía."

  # Antes de preguntar: si no se puede anotar lo sacado, no se saca nada.
  { mkdir -p "$(dirname "$REGISTRO")" && touch "$REGISTRO"; } 2>/dev/null \
    || morir "No puedo escribir en $REGISTRO. Corré termux-setup-storage, aceptá el permiso y probá de nuevo."

  decir "Se van a sacar ${#paquetes[@]} apps:"
  printf '    %s\n' "${paquetes[@]}"
  read -r -p "¿Seguir? [s/N] " respuesta
  [ "$respuesta" = s ] || [ "$respuesta" = S ] || morir "No se sacó nada."

  for p in "${paquetes[@]}"; do
    if pm_root "uninstall --user 0 $p" 2>&1 | grep -q Success; then
      echo "$p" >> "$REGISTRO"
      decir "Afuera: $p"
    else
      avisar "No se pudo (o no estaba): $p"
    fi
  done
  decir "Listo. Si algo falla: ./debloat.sh restaurar"
}

restaurar() {
  local p resto
  [ -s "$REGISTRO" ] || morir "No hay nada sacado en $REGISTRO."
  if [ -n "${1:-}" ]; then
    grep -qx "$1" "$REGISTRO" || morir "$1 no figura entre las sacadas."
    set -- "$1"
  else
    mapfile -t resto < "$REGISTRO"
    set -- "${resto[@]}"
  fi

  for p in "$@"; do
    if "$SU" -c "cmd package install-existing $p" 2>&1 | grep -qi installed; then
      grep -vx "$p" "$REGISTRO" > "$REGISTRO.tmp" || true
      mv "$REGISTRO.tmp" "$REGISTRO"
      decir "De vuelta: $p"
    else
      avisar "No se pudo restaurar: $p"
    fi
  done
}

case "${1:-}" in
  listar)    listar ;;
  sacar)     shift; sacar "$@" ;;
  restaurar) shift; restaurar "$@" ;;
  *)         sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
