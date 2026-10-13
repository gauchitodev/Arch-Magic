# 04-input — Entradas físicas

El slider y los gatillos de hombro, puestos a laburar. **Requiere root** (para leer los botones con `getevent`).

> 🚧 Bosquejo: escrito antes de que llegue el teléfono, sin probar. La lógica de los gatillos está probada con eventos falsos en una PC.

| Entrada | Acción |
|---|---|
| Slider afuera | Muestra el teclado en pantalla |
| Slider adentro | Lo esconde |
| Gatillo izquierdo | Pantalla de trabajo anterior |
| Gatillo derecho | Pantalla de trabajo siguiente |
| Los dos gatillos juntos | Asistente de voz (de nuevo para cortar) |

Los gatillos actúan **al soltarlos**: así, si apretás los dos juntos, la pantalla no se mueve antes de que arranque el asistente.

## Primer paso: averiguar los códigos

Con el teléfono en la mano, desde Termux:

```bash
su -c getevent -l
```

Mové el slider y apretá cada gatillo. Cada uno imprime una línea como:

```
/dev/input/event3: EV_KEY       KEY_F13              DOWN
```

El tercer campo (`KEY_F13`) es el código. Anotalos en el README cuando los tengamos.

## Uso

```bash
SLIDER=KEY_F13 GATILLO_IZQ=KEY_F14 GATILLO_DER=KEY_F15 ./entradas.sh
```

Si el teclado aparece al revés (al meter el slider en vez de sacarlo): `SLIDER_INVERTIDO=1`.

Para que arranque solo: un script en `~/.termux/boot/` con **Termux:Boot**.

## Cómo habla con Sway

El demonio corre en Termux, pero Sway vive adentro de Arch. Para hablarle, busca el socket de Sway en el `/tmp` del chroot (por eso [`sway/iniciar.sh`](../sway/iniciar.sh) pone `XDG_RUNTIME_DIR` en `/tmp`) y llama a `swaymsg` con `chroot`.

El teclado en pantalla ([wvkbd](https://github.com/jjsullivan5196/wvkbd)) se controla con señales: `SIGUSR2` lo muestra y `SIGUSR1` lo esconde.

## Modo escritorio con teclado Bluetooth

El script del README principal (Etapa 4) sigue en pie: detecta el teclado BT y levanta Termux:X11 con Sway.
