# sway — Modo móvil y escritorio

Sway corriendo adentro de Arch y dibujando en Termux:X11.

> 🚧 Bosquejo: escrito antes de que llegue el teléfono, sin probar.

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
sudo pacman -S sway wofi python-gobject gtk3 gtk-layer-shell
# wvkbd desde AUR
mkdir -p ~/.config/sway
cp ~/Arch-Magic/sway/{linea.py,arch-magic.conf} ~/.config/sway/
echo 'include ~/.config/sway/arch-magic.conf' >> ~/.config/sway/config
```

Para arrancar, desde Termux: `~/Arch-Magic/sway/escritorio.sh`. Necesita el repo clonado también adentro de Arch, en `~/Arch-Magic` (o decile dónde con `REPO_EN_ARCH`).
