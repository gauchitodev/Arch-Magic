# 04-input — Entradas físicas

El slider, los gatillos de hombro y el ventilador, puestos a laburar.

## Lo que ya anda (sin root, por ADB)

| Script | Qué hace |
|---|---|
| [`adb-local.sh`](adb-local.sh) | ADB contra el propio teléfono en `127.0.0.1:5555`. Se empareja una vez con Wi-Fi y después anda sin red hasta reiniciar. El usuario `shell` puede sacar capturas, tocar la pantalla y leer botones (`getevent`), pero no tocar particiones ni datos de otras apps |
| [`ventilador.sh`](ventilador.sh) | `estado`, `prender`, `fuerte`, `apagar`, y `auto` (prende a 40 °C de piel, apaga a 37 °C; si lo prendiste vos, no lo toca). `arrancar` lo deja de fondo, para el `.bashrc` de Termux |

Termux y Arch comparten la red: el mismo `adb-local.sh conectar` anda de los dos lados (cada uno con su llave; la primera vez Android pregunta).

## Lo que encontramos en el NX789J

| Entrada | Dispositivo | Evento | Estado |
|---|---|---|---|
| Slider | `gpio-keys_nubia` | `EV_SW SW_PEN_INSERTED` (1 afuera, 0 adentro) | ⏸️ RedMagic lo usa para el Game Space |
| Gatillos | `nubia_tgk_aw_sar0_ch0` / `sar1` | Nada fuera del modo juego | ⏸️ Hay que ver cómo activarlos |

**El slider y el Game Space.** Al sacarlo, el sistema pone `default_home=cn.nubia.gamelauncher`, te manda al inicio, silencia las notificaciones y sube a 90 Hz; al meterlo, lo deshace. No hay opción para apagarlo en Ajustes ni en el Game Space Center. Termux deja alternar su teclado con **Ctrl+Alt+K** (mandado por ADB con `input keycombination`; `dumpsys input_method | grep mInputShown` dice si está visible), así que la parte del teclado está resuelta: falta que el Game Space no se meta. Queda para cuando haya root.

**El ventilador.** El botón de los ajustes rápidos no habla con el kernel: cambia ajustes de Android, y la app `cn.nubia.fan` los pasa a `/sys/kernel/fan` (que se puede leer sin root: `fan_enable`, `fan_speed_level`, `fan_speed_count` = RPM).

| Ajuste (`settings put system …`) | Valor | Efecto |
|---|---|---|
| `fan_state_of_manual` | `2` / `-2` | Prende / apaga |
| `fan_state_of_mode` | `1` / `0` | Normal (nivel 2, ~8.400 RPM) / fuerte (nivel 4, ~16.400 RPM) |

`global game_fan_off_on` es solo un reflejo del estado: cambiarlo no hace nada.

## Con root: `entradas.sh`

> 🚧 Bosquejo: escrito antes de que llegue el teléfono. La lógica de los gatillos está probada con eventos falsos en una PC; el código del slider ya se conoce (`SLIDER=SW_PEN_INSERTED`), los de los gatillos todavía no.

| Entrada | Acción |
|---|---|
| Slider afuera | Muestra el teclado en pantalla |
| Slider adentro | Lo esconde |
| Gatillo izquierdo | Pantalla de trabajo anterior |
| Gatillo derecho | Pantalla de trabajo siguiente |
| Los dos gatillos juntos | Asistente de voz (de nuevo para cortar) |

Los gatillos actúan **al soltarlos**: así, si apretás los dos juntos, la pantalla no se mueve antes de que arranque el asistente.

### Averiguar los códigos

Con root, `su -c getevent -l`; sin root, `adb shell getevent -lt` (ver arriba). Mové el slider y apretá cada gatillo. Cada uno imprime una línea como:

```
/dev/input/event4: EV_SW        SW_PEN_INSERTED      00000001
```

El tercer campo es el código.

### Uso

```bash
SLIDER=SW_PEN_INSERTED GATILLO_IZQ=CODIGO GATILLO_DER=CODIGO ./entradas.sh
```

Si el teclado aparece al revés (al meter el slider en vez de sacarlo): `SLIDER_INVERTIDO=1`.

Para que arranque solo: un script en `~/.termux/boot/` con **Termux:Boot**.

### Cómo habla con Sway

El demonio corre en Termux, pero Sway vive adentro de Arch. Para hablarle, busca el socket de Sway en el `/tmp` del chroot (por eso [`sway/iniciar.sh`](../sway/iniciar.sh) pone `XDG_RUNTIME_DIR` en `/tmp`) y llama a `swaymsg` con `chroot`.

El teclado en pantalla ([wvkbd](https://github.com/jjsullivan5196/wvkbd)) se controla con señales: `SIGUSR2` lo muestra y `SIGUSR1` lo esconde.

### Modo escritorio con teclado Bluetooth

El script del README principal (Etapa 4) sigue en pie: detecta el teclado BT y levanta Termux:X11 con Sway.
