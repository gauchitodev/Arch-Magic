# 06-launcher — Pantalla de inicio

Por ahora, **[Kvaesitso](https://f-droid.org/packages/de.mm20.launcher2.release/)** (F-Droid): un launcher normal, con íconos y favoritos, que además se maneja con gestos y buscando por texto. El de RedMagic queda instalado de respaldo.

Usarlo unos días es la mejor forma de descubrir qué tiene que tener la "cabina" propia, si algún día la hacemos.

## Tema Arcano

[`arcano.kvtheme`](arcano.kvtheme): la paleta del proyecto (violeta oscuro, violeta y dorado) como tema de Kvaesitso. Es oscuro siempre, de día y de noche.

| Rol | Color |
|---|---|
| Fondo | `#13101A` |
| Acento | `#9B6BFF` |
| Detalles | `#E8C15A` |
| Texto | `#E4DFF0` |

Para cargarlo, desde Termux:

```bash
cd ~/Arch-Magic && git pull
cp 06-launcher/arcano.kvtheme /sdcard/Download/
```

Después, en Kvaesitso: **Ajustes → Apariencia → Importar tema** → `Download/arcano.kvtheme` → **Aplicar**.

Armado con el formato del código de Kvaesitso (v1.41, `ThemeBundle` versión 2). Todos los textos tienen contraste de 5:1 o más contra su fondo.
