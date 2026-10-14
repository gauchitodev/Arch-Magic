# 02-root — Bootloader y root

> 🚧 Escrito antes de que llegue el teléfono. Los pasos exactos del unlock se completan con la experiencia real.

## ⚠️ Antes de empezar

- **Esto es sin red.** El unlock borra todo el teléfono y anula la garantía. Un seguro de equipos tampoco cubre un brick por flasheo: lo suelen excluir como daño por "configuración del sistema o programación".
- **No hay vuelta atrás fácil.** No vuelvas a bloquear el bootloader si el sistema no está exactamente de fábrica: puede dejar el teléfono brickeado para siempre.
- Confirmá en XDA que **tu versión de firmware** se puede desbloquear antes de tocar nada.

## Paso 0 — Respaldo del módem (obligatorio)

Hay unas pocas particiones que son **únicas de tu teléfono** y no se pueden bajar de ningún lado:

| Partición | Qué guarda |
|---|---|
| `modemst1`, `modemst2`, `fsg` | IMEI y configuración del módem |
| `fsc` | Checksum de las anteriores |
| `persist` | Calibración de sensores y del lector de huellas |

Un error común al flashear por EDL es pisarlas. El resultado: **sin IMEI y sin señal**, y sin forma de recuperarlo si no tenés respaldo.

### Antes del unlock: por EDL, solo lectura

Antes de escribir **cualquier cosa**, la primera sesión en EDL es solo para **leer**:

1. Anotá el IMEI (`*#06#`) y sacale foto a la etiqueta de la caja.
2. En modo EDL, leé las particiones de la tabla de arriba a archivos en la PC:
   - Con **ZTE Family Toolbox**, si tiene opción de leer o respaldar particiones.
   - O con [`edl`](https://github.com/bkerler/edl) y el loader de firehose del teléfono:
     ```bash
     for p in modemst1 modemst2 fsg fsc persist; do edl r $p $p.img; done
     sha256sum *.img > SHA256SUMS
     ```
3. Guardá la carpeta **en dos lugares** fuera del teléfono (la PC y un pendrive o la nube).

Recién con el respaldo guardado, seguí con el unlock.

### Después del root: desde el teléfono

Con root, repetí el respaldo desde Termux. Sirve para tener una segunda copia y para confirmar que la de EDL salió bien:

```bash
./respaldo-efs.sh             # respalda en /sdcard/Arch-Magic/respaldo-efs/<fecha>/
./respaldo-efs.sh verificar   # revisa con sha256 que el último respaldo esté sano
```

Copia cada partición, guarda modelo y firmware en `info.txt` y un `SHA256SUMS` para detectar si algún archivo se dañó. Después sacalo del teléfono.

### Restaurar (solo si se rompió)

Únicamente en **este mismo teléfono**: el IMEI es de este equipo y ponerlo en otro es ilegal.

```bash
# Por EDL:
edl w modemst1 modemst1.img   # y así con cada una

# Con root:
su -c "dd if=modemst1.img of=/dev/block/by-name/modemst1"
```

## Paso 1 — Unlock

- Herramienta: **ZTE Family Toolbox ≥ 1.2.3** (Windows).
- Conexión en **modo EDL (9008)**, no fastboot.
- Guía de referencia: hilo de AdaUnlocked en XDA.

Pasos exactos: _a completar con la experiencia real_.

## Paso 2 — Root

Extraer el `init_boot` de **la misma versión de firmware**, parchearlo con **KernelSU** o **Magisk**, flashearlo y verificar.

Pasos exactos: _a completar con la experiencia real_.

## Paso 3 — Respaldo de nuevo

Apenas tengas root: `./respaldo-efs.sh` y sacalo del teléfono.
