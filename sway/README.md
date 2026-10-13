# sway — Modo móvil y escritorio

Sway corriendo adentro de Arch y dibujando en Termux:X11.

> 🚧 Sin probar en el teléfono. En una PC (13/10), con Sway sin GPU (pixman) a 1080×2400 y un dedo virtual: la línea se dibuja y reserva su lugar, los cuatro gestos hacen lo que dicen, y `default_orientation auto` apila en vertical en el teléfono y pone lado a lado en un monitor de 2560×1440.

| Archivo | Qué es |
|---|---|
| [`escritorio.sh`](escritorio.sh) | Desde Termux: abre Termux:X11, el sonido y Sway adentro de Arch (con o sin root) |
| [`iniciar.sh`](iniciar.sh) | Adentro de Arch: arranca Sway con lo que necesita Termux:X11 (sin GPU, socket en `/tmp`) |
| [`arch-magic.conf`](arch-magic.conf) | Piezas del config: la línea, el teclado y los colores Arcano |
| [`linea.py`](linea.py) | La línea de abajo, estilo Motorola |

## La línea de abajo

Una rayita violeta pegada al borde inferior, como la barra de gestos de Motorola, pero para moverse entre pantallas de trabajo:

| Gesto | Acción |
|---|---|
| Deslizar a la izquierda | Pantalla de trabajo siguiente |
| Deslizar a la derecha | Pantalla de trabajo anterior |
| Deslizar para arriba | Menú de apps (`wofi`) |
| Tocar | Muestra o esconde el teclado en pantalla |

Mientras arrastrás, la rayita sigue al dedo. Hace lo mismo que los gatillos, pero con el dedo.

## Teclado en pantalla

[wvkbd](https://github.com/jjsullivan5196/wvkbd) arranca escondido. Sin root, aparece y desaparece tocando la línea de abajo. Con root, también con el slider (ver [`04-input/`](../04-input/)). Está en AUR como `wvkbd`.

> A verificar en el teléfono: que wvkbd alterne con `SIGRTMIN` (el toque de la línea) y que se muestre y esconda con `SIGUSR2` y `SIGUSR1` (el slider).

## Instalación (adentro de Arch)

```bash
sudo pacman -S sway wofi foot python-gobject gtk3 gtk-layer-shell
# wvkbd desde AUR
mkdir -p ~/.config/sway
cp /etc/sway/config ~/.config/sway/config
echo 'include /opt/arch-magic/sway/arch-magic.conf' >> ~/.config/sway/config
```

El repo no hace falta clonarlo adentro de Arch: `arch.sh` y `en-arch.sh` lo muestran en `/opt/arch-magic`. Un `git pull` en Termux y Sway ya usa lo nuevo.

Para arrancar, desde Termux: `~/Arch-Magic/sway/escritorio.sh`.

En Termux:X11, poné el toque en modo **pantalla táctil directa**: en modo touchpad la línea no recibe los deslizamientos.
