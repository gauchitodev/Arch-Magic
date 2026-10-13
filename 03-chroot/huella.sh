#!/data/data/com.termux/files/usr/bin/bash
# ✦ Arch-Magic — huella digital para sudo (lado Termux)
#
# 🚧 Bosquejo: escrito antes de que llegue el teléfono. Probado en una PC con
# un sensor de mentira.
#
# Linux no puede leer el sensor de huellas: lo maneja Android. Este demonio
# hace de puente: cuando sudo pide permiso adentro de Arch, muestra el cartel
# de huella de Android (termux-fingerprint) y le contesta OK o NO.
#
# Uso:  ./huella.sh      (dejarlo corriendo; con Termux:Boot arranca solo)
#
# Corre en Termux como usuario normal. Necesita Termux:API, socat y jq.

set -euo pipefail

# Esta carpeta se ve adentro de Arch como /run/arch-magic (la monta arch.sh).
# Es 700 y del usuario de Termux: los usuarios de Arch no pueden entrar ni
# poner un socket falso; solo root (o sea, sudo) llega al socket.
DIR="${HUELLA_DIR:-/data/data/com.termux/files/usr/tmp/arch-magic}"
SOCKET="$DIR/huella.sock"

# Atiende un pedido. socat conecta la entrada y la salida al socket.
responder() {
  local usuario servicio resultado
  read -r -t 5 usuario servicio || { echo NO; return; }
  # Solo letras simples: esto se muestra en pantalla.
  usuario="${usuario//[^a-zA-Z0-9_-]/}"
  servicio="${servicio//[^a-zA-Z0-9_-]/}"

  resultado=$(termux-fingerprint \
    -t "✦ Arch-Magic" \
    -d "$usuario quiere usar $servicio" \
    -c "Usar contraseña" 2>/dev/null) || { echo NO; return; }

  if [ "$(jq -r '.auth_result' <<<"$resultado" 2>/dev/null)" = AUTH_RESULT_SUCCESS ]; then
    echo OK
  else
    echo NO
  fi
}

if [ "${1:-}" = --responder ]; then
  responder
  exit
fi

mkdir -p "$DIR"
chmod 700 "$DIR"
rm -f "$SOCKET"
echo "✦ Esperando pedidos de sudo en $SOCKET"
exec socat UNIX-LISTEN:"$SOCKET",fork,mode=600 EXEC:"$0 --responder"
