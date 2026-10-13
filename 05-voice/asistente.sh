#!/data/data/com.termux/files/usr/bin/bash
# ✦ Arch-Magic — asistente de voz
#
# 🚧 Bosquejo: escrito antes de que llegue el teléfono, sin probar.
#
# Uso:  ./asistente.sh             la primera vez empieza a escuchar,
#                                  la segunda corta, transcribe y responde
#       ./asistente.sh "pregunta"  salta el micrófono (para probar)
#       ./asistente.sh boton       deja un botón fijo en las notificaciones
#       ./asistente.sh sin-boton   lo saca
#
# Flujo: micrófono → whisper.cpp → Claude → voz de Android
# Corre en Termux como usuario normal (Termux:API no anda como root).

set -euo pipefail

# --- Configuración -----------------------------------------------------------

AQUI="$(cd "$(dirname "$0")" && pwd)"
ESTADO="${ESTADO:-$HOME/.cache/arch-magic/voz}"

WHISPER_BIN="${WHISPER_BIN:-$HOME/whisper.cpp/build/bin/whisper-cli}"
WHISPER_MODELO="${WHISPER_MODELO:-$HOME/whisper.cpp/models/ggml-base.bin}"

# api    → API de Anthropic con curl (necesita ANTHROPIC_API_KEY, cuenta de Console)
# code   → Claude Code adentro de Arch (usa tu plan Pro/Max; con o sin root)
# Sin decir nada: api si hay clave, code si no.
CLAUDE_MODO="${CLAUDE_MODO:-}"
CLAUDE_MODELO="${CLAUDE_MODELO:-claude-opus-5-5}"
CLAVE_ARCHIVO="${CLAVE_ARCHIVO:-$HOME/.config/arch-magic/anthropic-key}"
EN_ARCH="${EN_ARCH:-$AQUI/../03-chroot/en-arch.sh}"

VOZ_IDIOMA="${VOZ_IDIOMA:-es}"
VOZ_REGION="${VOZ_REGION:-UY}"

SISTEMA="Sos el asistente de voz de un teléfono con Arch Linux. Tu respuesta \
se va a leer en voz alta: contestá corto (dos o tres oraciones), en español \
rioplatense, sin markdown, sin listas, sin emojis y sin bloques de código."

# --- Utilidades --------------------------------------------------------------

AUDIO="$ESTADO/pregunta.m4a"
WAV="$ESTADO/pregunta.wav"
GRABANDO="$ESTADO/grabando"
NOTI="arch-magic-voz"

mkdir -p "$ESTADO"

avisar() {
  termux-notification --id "$NOTI" --title "✦ Arch-Magic" --content "$1" \
    --priority low --ongoing >/dev/null 2>&1 || true
}
terminar() { termux-notification-remove "$NOTI" >/dev/null 2>&1 || true; }
fallar() { terminar; termux-toast "✦ $1" 2>/dev/null || true; echo "✗ $1" >&2; exit 1; }

# --- Pasos -------------------------------------------------------------------

empezar_a_escuchar() {
  rm -f "$AUDIO" "$WAV"
  termux-microphone-record -f "$AUDIO" -l 0 >/dev/null
  touch "$GRABANDO"
  termux-vibrate -d 40
  avisar "Escuchando… (gatillos de nuevo para cortar)"
}

dejar_de_escuchar() {
  termux-microphone-record -q >/dev/null
  rm -f "$GRABANDO"
  termux-vibrate -d 40
  sleep 0.5   # que Termux:API termine de cerrar el archivo
  [ -s "$AUDIO" ] || fallar "No se grabó nada."
}

transcribir() {
  avisar "Pensando…"
  # whisper.cpp solo come WAV mono a 16 kHz.
  ffmpeg -loglevel error -y -i "$AUDIO" -ar 16000 -ac 1 "$WAV"
  "$WHISPER_BIN" -m "$WHISPER_MODELO" -l "$VOZ_IDIOMA" -nt -np -f "$WAV" \
    | tr '\n' ' ' | sed 's/^ *//; s/ *$//'
}

clave() {
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo "$ANTHROPIC_API_KEY"
  elif [ -f "$CLAVE_ARCHIVO" ]; then
    cat "$CLAVE_ARCHIVO"
  fi
}

preguntar_por_api() {
  local cuerpo respuesta
  cuerpo=$(jq -n --arg modelo "$CLAUDE_MODELO" --arg sistema "$SISTEMA" --arg pregunta "$1" '{
    model: $modelo,
    max_tokens: 4000,
    output_config: {effort: "low"},
    fallbacks: "default",
    system: $sistema,
    messages: [{role: "user", content: $pregunta}]
  }')
  respuesta=$(curl -sS https://api.anthropic.com/v1/messages \
    -H "content-type: application/json" \
    -H "x-api-key: $(clave)" \
    -H "anthropic-version: 2023-06-01" \
    -H "anthropic-beta: server-side-fallback-2026-07-01" \
    -d "$cuerpo") || fallar "Sin conexión con Claude."

  if [ "$(jq -r '.type' <<<"$respuesta")" = error ]; then
    fallar "Claude: $(jq -r '.error.message' <<<"$respuesta")"
  fi
  if [ "$(jq -r '.stop_reason' <<<"$respuesta")" = refusal ]; then
    echo "Eso no te lo puedo contestar."
    return
  fi
  jq -r '[.content[] | select(.type == "text") | .text] | join(" ")' <<<"$respuesta"
}

# Claude Code adentro de Arch (chroot o proot, lo decide en-arch.sh). La
# pregunta va por stdin, así no hay que pelear con comillas.
preguntar_por_code() {
  printf '%s\n\nPregunta: %s\n' "$SISTEMA" "$1" | "$EN_ARCH" claude -p
}

preguntar() {
  local modo="$CLAUDE_MODO"
  if [ -z "$modo" ]; then
    if [ -n "$(clave)" ]; then modo=api; else modo=code; fi
  fi
  case "$modo" in
    api)  preguntar_por_api "$1" ;;
    code) preguntar_por_code "$1" ;;
    *)    fallar "CLAUDE_MODO tiene que ser api o code." ;;
  esac
}

hablar() {
  # Por si Claude igual se manda un asterisco o un numeral.
  local limpio="${1//[*_#\`>]/}"
  terminar
  termux-tts-speak -l "$VOZ_IDIOMA" -n "$VOZ_REGION" "$limpio"
}

responder() {
  local pregunta="$1" respuesta
  [ -n "$pregunta" ] || fallar "No te entendí."
  echo "▸ $pregunta"
  respuesta=$(preguntar "$pregunta")
  echo "✦ $respuesta"
  hablar "$respuesta"
}

# Botón fijo en la barra de notificaciones: sirve desde cualquier app, incluso
# adentro de Termux:X11, y no necesita root (los gatillos sí).
BOTON="arch-magic-boton"

poner_boton() {
  termux-notification --id "$BOTON" --title "✦ Arch-Magic" \
    --content "Tocá Hablar, hablá y tocá de nuevo para cortar" \
    --ongoing --priority low \
    --button1 "Hablar" --button1-action "$AQUI/asistente.sh"
}

# --- Principal ---------------------------------------------------------------

case "${1:-}" in
  boton)     poner_boton; exit ;;
  sin-boton) termux-notification-remove "$BOTON"; exit ;;
esac

if [ $# -gt 0 ]; then
  responder "$*"
elif [ -f "$GRABANDO" ]; then
  dejar_de_escuchar
  responder "$(transcribir)"
else
  empezar_a_escuchar
fi
