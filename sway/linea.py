#!/usr/bin/env python3
"""✦ Arch-Magic — la línea de abajo, como la de Motorola.

🚧 Sin probar en el teléfono. Probado en una PC con Sway sin GPU y un dedo
virtual: se dibuja, reserva su lugar y los cuatro gestos andan.

Una rayita violeta pegada al borde de abajo de la pantalla:

    deslizar a la izquierda → pantalla de trabajo siguiente
    deslizar a la derecha   → pantalla de trabajo anterior
    deslizar para arriba    → menú de apps
    tocar                   → muestra o esconde el teclado en pantalla

El toque es para cuando no hay root: con root, el slider hace lo mismo.

Mientras arrastrás, la rayita sigue al dedo.

Necesita (en Arch): python-gobject gtk3 gtk-layer-shell
"""

import os
import subprocess

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, Gtk, GtkLayerShell  # noqa: E402

ALTO = 28            # zona táctil, en píxeles
GROSOR = 5           # grosor de la rayita
ANCHO = 0.3          # ancho de la rayita, como fracción de la pantalla
UMBRAL = 60          # cuánto hay que arrastrar para que cuente
TOQUE = 12           # menos que esto es un toque, no un arrastre
ACENTO = (0x9B / 255, 0x6B / 255, 0xFF / 255)  # violeta Arcano
MENU = os.environ.get("ARCH_MAGIC_MENU", "wofi --show drun")


def sway(*orden):
    subprocess.Popen(["swaymsg", *orden], stdout=subprocess.DEVNULL)


def alternar_teclado():
    # wvkbd: SIGRTMIN lo muestra si está escondido y lo esconde si se ve.
    subprocess.Popen(["pkill", "-RTMIN", "-x", "wvkbd-mobintl"])


class Linea(Gtk.Window):
    def __init__(self):
        super().__init__()

        GtkLayerShell.init_for_window(self)
        GtkLayerShell.set_namespace(self, "arch-magic-linea")
        GtkLayerShell.set_layer(self, GtkLayerShell.Layer.TOP)
        for borde in (GtkLayerShell.Edge.BOTTOM, GtkLayerShell.Edge.LEFT, GtkLayerShell.Edge.RIGHT):
            GtkLayerShell.set_anchor(self, borde, True)
        # Reserva su lugar: las ventanas no se meten abajo de la línea.
        GtkLayerShell.auto_exclusive_zone_enable(self)
        self.set_size_request(-1, ALTO)

        # Fondo transparente: solo se ve la rayita.
        visual = self.get_screen().get_rgba_visual()
        if visual:
            self.set_visual(visual)
        self.set_app_paintable(True)

        self.add_events(
            Gdk.EventMask.BUTTON_PRESS_MASK
            | Gdk.EventMask.BUTTON_RELEASE_MASK
            | Gdk.EventMask.BUTTON_MOTION_MASK
        )
        self.connect("draw", self.dibujar)
        self.connect("button-press-event", self.apretar)
        self.connect("motion-notify-event", self.arrastrar)
        self.connect("button-release-event", self.soltar)

        self.inicio = None   # dónde apoyaste el dedo
        self.dx = 0          # cuánto lo corriste, para que la rayita lo siga

    def dibujar(self, _widget, cr):
        ancho = self.get_allocated_width()
        largo = ancho * ANCHO
        x = (ancho - largo) / 2 + self.dx
        y = (ALTO - GROSOR) / 2
        radio = GROSOR / 2

        cr.set_source_rgba(0, 0, 0, 0)
        cr.set_operator(1)  # CAIRO_OPERATOR_SOURCE: borra el fondo
        cr.paint()
        cr.set_operator(2)  # CAIRO_OPERATOR_OVER

        cr.set_source_rgb(*ACENTO)
        cr.new_sub_path()
        cr.arc(x + radio, y + radio, radio, 1.5708, 4.7124)
        cr.arc(x + largo - radio, y + radio, radio, 4.7124, 1.5708)
        cr.close_path()
        cr.fill()

    def apretar(self, _widget, evento):
        self.inicio = (evento.x_root, evento.y_root)

    def arrastrar(self, _widget, evento):
        if self.inicio is None:
            return
        self.dx = evento.x_root - self.inicio[0]
        self.queue_draw()

    def soltar(self, _widget, evento):
        if self.inicio is None:
            return
        dx = evento.x_root - self.inicio[0]
        dy = evento.y_root - self.inicio[1]
        self.inicio = None
        self.dx = 0
        self.queue_draw()

        if abs(dx) < TOQUE and abs(dy) < TOQUE:
            alternar_teclado()
        elif -dy > UMBRAL and -dy > abs(dx):
            subprocess.Popen(MENU, shell=True)
        elif dx < -UMBRAL:
            sway("workspace", "next_on_output")
        elif dx > UMBRAL:
            sway("workspace", "prev_on_output")


if __name__ == "__main__":
    ventana = Linea()
    ventana.connect("destroy", Gtk.main_quit)
    ventana.show_all()
    Gtk.main()
