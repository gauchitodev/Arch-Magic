# 01-debloat — Sacar lo que sobra

Sacar las apps de RedMagic, ZTE y compañía que no se usan, **sin romper nada**: `pm uninstall --user 0` solo saca la app para tu usuario (no toca la partición del sistema) y se vuelve a poner cuando quieras.

Necesita root ([GhostLock](../02-root/#camino-1--ghostlock-root-temporal-sin-desbloquear) sirve) o `adb` desde una PC.

## Pasos

```bash
cd ~/Arch-Magic/01-debloat
./debloat.sh listar        # guarda las apps de fábrica en paquetes-<firmware>.txt
```

Con esa lista se arma `sacar.txt`: una app por línea, con un comentario de qué es. Después:

```bash
./debloat.sh sacar         # muestra la lista y pide confirmación
./debloat.sh restaurar     # vuelve a poner todo lo sacado
./debloat.sh restaurar com.ejemplo.app   # o una sola
```

Lo sacado queda anotado en `/sdcard/Arch-Magic/debloat-sacados.txt` (afuera del repo), así siempre se puede restaurar.

## Reglas

- **Nunca** se tocan, aunque estén en la lista: System UI, Ajustes, Teléfono, el instalador y los permisos, Termux y KernelSU.
- **No sacar** lo que maneja el **ventilador**, el **rendimiento**, los **gatillos** o el **slider** (Game Space y compañía): son la magia del proyecto. Ante la duda, se deja.
- **No sacar el launcher de RedMagic** hasta que el propio ([`06-launcher/`](../06-launcher/)) ande.
- De a pocas: sacar, reiniciar, usar el teléfono un día. Si algo falla, `restaurar`.
- El actualizador (`com.zte.zdm`) ya está desactivado aparte: ver [`02-root/`](../02-root/#paso-0--frenar-las-actualizaciones-hoy).

## Sin root

Desde una PC con `adb` (o desde Termux con Depuración inalámbrica), lo mismo a mano:

```bash
adb shell pm list packages -s                        # listar
adb shell pm uninstall --user 0 nombre.del.paquete   # sacar
adb shell cmd package install-existing nombre.del.paquete   # restaurar
```
