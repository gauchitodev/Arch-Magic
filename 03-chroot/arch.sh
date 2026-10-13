#!/data/data/com.termux/files/usr/bin/bash
# ✦ Arch-Magic — Arch Linux ARM en chroot sobre Android (requiere root)
#
# Uso:  ./arch.sh <comando> [usuario]
#
#   instalar     descarga Arch Linux ARM y lo descomprime en $ARCH_RAIZ
#   configurar   primer arranque: DNS, llaves de pacman, idioma y tu usuario
#   entrar       monta todo y abre una consola en Arch (como root o [usuario])
#   montar       monta todo sin abrir consola (lo usan los otros scripts)
#   desmontar    desmonta todo en orden inverso
#   estado       muestra qué está montado
#
# Se corre desde Termux como usuario normal: el script se vuelve a llamar con su.

set -euo pipefail

# --- Configuración -----------------------------------------------------------

ARCH_RAIZ="${ARCH_RAIZ:-/data/local/arch}"
ARCH_URL="${ARCH_URL:-http://os.archlinuxarm.org/os/ArchLinuxARM-aarch64-latest.tar.gz}"
ARCH_USUARIO="${ARCH_USUARIO:-gauchito}"
ARCH_IDIOMA="${ARCH_IDIOMA:-es_UY.UTF-8}"
ARCH_ZONA="${ARCH_ZONA:-America/Montevideo}"

# Carpeta que se comparte con Android. Solo esta: el resto de /sdcard no se ve
# desde Arch, así Claude Code no tiene cómo tocar las fotos ni los datos.
COMPARTIDA_ANDROID="${COMPARTIDA_ANDROID:-/sdcard/Arch-Magic}"
COMPARTIDA_ARCH="/mnt/android"

TERMUX="/data/data/com.termux/files"
TERMUX_BIN="$TERMUX/usr/bin"

# --- Utilidades --------------------------------------------------------------

violeta=$'\e[38;2;155;107;255m'
dorado=$'\e[38;2;232;193;90m'
rojo=$'\e[31m'
normal=$'\e[0m'

decir() { printf '%s✦%s %s\n' "$violeta" "$normal" "$*"; }
avisar() { printf '%s!%s %s\n' "$dorado" "$normal" "$*"; }
morir() { printf '%s✗%s %s\n' "$rojo" "$normal" "$*" >&2; exit 1; }

# Si no somos root, volver a llamarnos con su. --mount-master hace que los
# montajes queden en el espacio de nombres global y no se pierdan al salir.
como_root() {
  [ "$(id -u)" = 0 ] && return
  command -v su >/dev/null || morir "No hay su. ¿El teléfono tiene root?"
  local linea
  linea=$(printf '%q ' env \
    "ARCH_RAIZ=$ARCH_RAIZ" "ARCH_URL=$ARCH_URL" "ARCH_USUARIO=$ARCH_USUARIO" \
    "ARCH_IDIOMA=$ARCH_IDIOMA" "ARCH_ZONA=$ARCH_ZONA" \
    "COMPARTIDA_ANDROID=$COMPARTIDA_ANDROID" "TERM=${TERM:-xterm-256color}" \
    "$TERMUX_BIN/bash" "$0" "$@")
  # Magisk y KernelSU entienden --mount-master; si este su no, va sin él.
  if su --mount-master -c true >/dev/null 2>&1; then
    exec su --mount-master -c "$linea"
  fi
  avisar "Este su no acepta --mount-master: los montajes pueden no verse desde otras apps."
  exec su -c "$linea"
}

montado() { grep -q " $1 " /proc/mounts; }

montar() {
  local destino="$1"; shift
  montado "$destino" && return
  mkdir -p "$destino"
  mount "$@" "$destino"
}

# --- Comandos ----------------------------------------------------------------

instalar() {
  [ -x "$ARCH_RAIZ/usr/bin/pacman" ] && morir "Ya hay un Arch en $ARCH_RAIZ."

  local paquete="$TERMUX/home/ArchLinuxARM-aarch64-latest.tar.gz"
  if [ ! -f "$paquete" ]; then
    decir "Descargando Arch Linux ARM…"
    "$TERMUX_BIN/curl" -fL --progress-bar -o "$paquete.parcial" "$ARCH_URL"
    mv "$paquete.parcial" "$paquete"
  fi

  decir "Descomprimiendo en $ARCH_RAIZ (tarda un rato)…"
  mkdir -p "$ARCH_RAIZ"
  # -p conserva permisos y dueños: sin eso sudo y compañía no andan.
  "$TERMUX_BIN/tar" -xzpf "$paquete" -C "$ARCH_RAIZ" \
    || morir "Falló la descompresión. Probá borrar $paquete y descargar de nuevo."

  decir "Listo. Seguí con: ./arch.sh configurar"
}

montar_todo() {
  [ -x "$ARCH_RAIZ/usr/bin/pacman" ] || morir "No hay Arch en $ARCH_RAIZ. Corré ./arch.sh instalar"

  # Android monta /data con nosuid y nodev: sin esto sudo no funciona.
  mount -o remount,dev,suid /data

  montar "$ARCH_RAIZ/proc"     -t proc proc
  montar "$ARCH_RAIZ/sys"      -t sysfs sysfs
  montar "$ARCH_RAIZ/dev"      --bind /dev
  # Las mismas terminales que Termux: si no, la consola en la que entraste no
  # existiría adentro de Arch.
  montar "$ARCH_RAIZ/dev/pts"  --bind /dev/pts
  # Android no tiene /dev/shm. Se crea en el /dev de Android (que vive en RAM y
  # se borra al reiniciar), así que no deja rastros.
  montar "$ARCH_RAIZ/dev/shm"  -t tmpfs tmpfs -o mode=1777
  montar "$ARCH_RAIZ/tmp"      -t tmpfs tmpfs -o mode=1777

  # Socket de Termux:X11, para que Sway pueda dibujar en :0.
  local x11="$TERMUX/usr/tmp/.X11-unix"
  if [ -d "$x11" ]; then
    montar "$ARCH_RAIZ/tmp/.X11-unix" --bind "$x11"
  fi

  mkdir -p "$COMPARTIDA_ANDROID"
  montar "$ARCH_RAIZ$COMPARTIDA_ARCH" --bind "$COMPARTIDA_ANDROID"
}

# Corre un comando dentro de Arch con un entorno limpio.
en_arch() {
  chroot "$ARCH_RAIZ" /usr/bin/env -i \
    HOME=/root TERM="${TERM:-xterm-256color}" LANG="$ARCH_IDIOMA" \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/bin \
    DISPLAY=:0 \
    "$@"
}

configurar() {
  montar_todo

  decir "DNS y nombre del equipo…"
  # Android no usa /etc/resolv.conf, así que Arch no sabría a quién preguntar.
  rm -f "$ARCH_RAIZ/etc/resolv.conf"
  printf 'nameserver 1.1.1.1\nnameserver 8.8.8.8\n' > "$ARCH_RAIZ/etc/resolv.conf"
  echo arch-magic > "$ARCH_RAIZ/etc/hostname"
  printf '127.0.0.1 localhost\n::1 localhost\n127.0.1.1 arch-magic\n' > "$ARCH_RAIZ/etc/hosts"

  decir "Grupos de red de Android…"
  # El kernel de Android solo deja usar la red a los grupos aid_inet y
  # aid_net_raw. alpm es el usuario con el que pacman descarga paquetes.
  en_arch bash -c '
    getent group aid_inet    >/dev/null || groupadd -g 3003 aid_inet
    getent group aid_net_raw >/dev/null || groupadd -g 3004 aid_net_raw
    getent passwd alpm >/dev/null && usermod -aG aid_inet,aid_net_raw alpm
    usermod -aG aid_inet,aid_net_raw root
  '

  decir "Llaves de pacman y actualización…"
  en_arch pacman-key --init
  en_arch pacman-key --populate archlinuxarm
  en_arch pacman -Syu --noconfirm
  en_arch pacman -S --noconfirm --needed sudo git curl base-devel

  decir "Idioma y zona horaria…"
  sed -i "s/^#\\($ARCH_IDIOMA\\)/\\1/" "$ARCH_RAIZ/etc/locale.gen"
  en_arch locale-gen
  echo "LANG=$ARCH_IDIOMA" > "$ARCH_RAIZ/etc/locale.conf"
  ln -sf "/usr/share/zoneinfo/$ARCH_ZONA" "$ARCH_RAIZ/etc/localtime"

  decir "Usuario $ARCH_USUARIO…"
  # La imagen trae un usuario alarm con contraseña alarm: afuera.
  en_arch bash -c 'id alarm >/dev/null 2>&1 && userdel -r alarm || true'
  if ! en_arch id "$ARCH_USUARIO" >/dev/null 2>&1; then
    en_arch useradd -m -G wheel,aid_inet,aid_net_raw -s /bin/bash "$ARCH_USUARIO"
    avisar "Elegí una contraseña para $ARCH_USUARIO:"
    en_arch passwd "$ARCH_USUARIO"
  fi
  echo '%wheel ALL=(ALL:ALL) ALL' > "$ARCH_RAIZ/etc/sudoers.d/wheel"
  chmod 440 "$ARCH_RAIZ/etc/sudoers.d/wheel"

  decir "Arch configurado. Entrá con: ./arch.sh entrar $ARCH_USUARIO"
}

entrar() {
  montar_todo
  if [ -n "${1:-}" ]; then
    en_arch su - "$1"
  else
    en_arch bash --login
  fi
}

desmontar() {
  # Orden inverso: primero lo más adentro.
  local destinos=(
    "$ARCH_RAIZ$COMPARTIDA_ARCH"
    "$ARCH_RAIZ/tmp/.X11-unix"
    "$ARCH_RAIZ/tmp"
    "$ARCH_RAIZ/dev/shm"
    "$ARCH_RAIZ/dev/pts"
    "$ARCH_RAIZ/dev"
    "$ARCH_RAIZ/sys"
    "$ARCH_RAIZ/proc"
  )
  local d
  for d in "${destinos[@]}"; do
    montado "$d" || continue
    umount "$d" 2>/dev/null || {
      avisar "$d está ocupado, lo desmonto en diferido."
      umount -l "$d"
    }
  done
  decir "Desmontado."
}

estado() {
  local lineas
  lineas=$(grep " $ARCH_RAIZ" /proc/mounts | awk '{print "  " $2 "  (" $3 ")"}' || true)
  if [ -n "$lineas" ]; then
    decir "Montado en $ARCH_RAIZ:"
    echo "$lineas"
  else
    decir "No hay nada montado."
  fi
}

# --- Principal ---------------------------------------------------------------

comando="${1:-}"
case "$comando" in
  instalar|configurar|entrar|desmontar|estado)
    como_root "$@"
    shift
    "$comando" "$@"
    ;;
  montar)
    como_root "$@"
    montar_todo
    ;;
  *)
    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
