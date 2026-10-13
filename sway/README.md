# sway — Modo móvil y escritorio

Sway corriendo adentro de Arch y dibujando en Termux:X11.

> 🚧 Bosquejo: escrito antes de que llegue el teléfono, sin probar.

| Archivo | Qué es |
|---|---|
| [`iniciar.sh`](iniciar.sh) | Arranca Sway con lo que necesita Termux:X11 (sin GPU, socket en `/tmp`) |
| [`arch-magic.conf`](arch-magic.conf) | Piezas del config: la línea, el teclado y los colores Arcano |
| [`linea.py`](linea.py) | La línea de abajo, estilo Motorola |

## La línea de abajo

Una rayita violeta pegada al borde inferior, como la barra de gestos de Motorola, pero para moverse entre pantallas de trabajo:

| Gesto | Acción |
|---|---|
| Deslizar a la izquierda | Pantalla de trabajo siguiente |
| Deslizar a la derecha | Pantalla de trabajo anterior |
| Deslizar para arriba | Menú de apps (`wofi`) |

Mientras arrastrás, la rayita sigue al dedo. Hace lo mismo que los gatillos, pero con el dedo.

## Teclado en pantalla

[wvkbd](https://github.com/jjsullivan5196/wvkbd) arranca escondido y aparece cuando sacás el slider (ver [`04-input/`](../04-input/)). Está en AUR como `wvkbd`.

## Instalación (adentro de Arch)

```bash
sudo pacman -S sway wofi python-gobject gtk3 gtk-layer-shell
# wvkbd desde AUR
mkdir -p ~/.config/sway
cp ~/Arch-Magic/sway/{linea.py,arch-magic.conf} ~/.config/sway/
echo 'include ~/.config/sway/arch-magic.conf' >> ~/.config/sway/config
```

Para arrancar: en Termux, `termux-x11 :0 &` y abrir la app Termux:X11. Después, en Arch: `~/Arch-Magic/sway/iniciar.sh`.
