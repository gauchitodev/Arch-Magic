# 05-voice — Asistente de voz

Apretás los dos gatillos, hablás, los volvés a apretar y Claude te contesta en voz alta.

> 🚧 Bosquejo: escrito antes de que llegue el teléfono, sin probar en Android. La parte de Claude está probada con una API falsa en una PC.

```
gatillos → termux-microphone-record → ffmpeg → whisper.cpp → Claude → termux-tts-speak
```

Todo corre en Termux, sin root (salvo el modo `code`, que entra al chroot).

## Instalación

1. App **Termux:API** desde F-Droid (la misma fuente que Termux).
2. Paquetes:

   ```bash
   pkg install termux-api ffmpeg jq curl git clang cmake
   ```

3. whisper.cpp, compilado en el teléfono:

   ```bash
   git clone https://github.com/ggml-org/whisper.cpp ~/whisper.cpp
   cd ~/whisper.cpp
   cmake -B build && cmake --build build -j --config Release
   ./models/download-ggml-model.sh base
   ```

   `base` es rápido y entiende bien el español. Si se equivoca mucho, probá `small`.

## Uso

```bash
./asistente.sh                  # empieza a escuchar
./asistente.sh                  # corta, transcribe y responde
./asistente.sh "¿qué hora es en Tokio?"   # sin micrófono, para probar
```

Normalmente no se llama a mano: lo dispara el demonio de [`04-input/`](../04-input/) con los dos gatillos.

## Con qué Claude habla

| Modo | Qué usa | Qué necesita |
|---|---|---|
| `api` | La API de Anthropic con `curl` | Una clave de Console (se paga aparte del plan) |
| `code` | `claude -p` adentro del chroot | Tu plan Pro/Max, root y Arch montado |

Sin configurar nada, usa `api` si encuentra una clave y `code` si no. La clave va en `ANTHROPIC_API_KEY` o en `~/.config/arch-magic/anthropic-key`.

El modo `api` usa `claude-opus-5-5` con esfuerzo bajo, para que conteste rápido. Si Claude rechaza una pregunta, la API la reintenta sola con otro modelo (`fallbacks`), y si igual no puede, el asistente lo dice en voz alta en vez de quedarse callado.

## Configuración

| Variable | Por defecto |
|---|---|
| `CLAUDE_MODO` | automático (`api` o `code`) |
| `CLAUDE_MODELO` | `claude-opus-5-5` |
| `WHISPER_BIN` | `~/whisper.cpp/build/bin/whisper-cli` |
| `WHISPER_MODELO` | `~/whisper.cpp/models/ggml-base.bin` |
| `VOZ_IDIOMA` / `VOZ_REGION` | `es` / `UY` |

## Pendiente

- Que se acuerde de la charla anterior (hoy cada pregunta arranca de cero).
- Que corte solo cuando dejás de hablar, sin tener que apretar de nuevo.
- Probar cuánto tarda whisper en el Snapdragon 8 Elite.
