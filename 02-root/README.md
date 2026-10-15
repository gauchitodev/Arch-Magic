# 02-root — Bootloader y root

> 🚧 Basado en la [wiki de la comunidad del RM10 Pro](https://github.com/mkonic/redmagic-wiki) (que resume los hilos de XDA hasta agosto de 2026) y en el teléfono real: **NX789J, RedMagicOS 10.0.9 EEA, Android 15, parche de diciembre de 2024, kernel 6.6.30**. Los pasos exactos se completan con la experiencia.

## Paso 0 — Frenar las actualizaciones (hoy)

Las actualizaciones nuevas de ZTE **cierran las fallas que usa el unlock**: eso ya pasó en el RM11 y está confirmado. El riesgo de fondo es peor: que una actualización queme fusibles del chip y el teléfono no se pueda desbloquear nunca más (todavía no se vio, pero es lo que hizo Xiaomi).

Un firmware viejo es lo que querés: para el RM10, *"tiene que ser una versión vieja; no se desbloquea con cualquiera"*. La 10.0.9 es de las más viejas que existen. **No la toques.**

No hace falta entrar a la pantalla de actualizaciones (ni tocar la notificación de "actualización disponible"): se desactiva el actualizador directo por `adb`.

1. Opciones de desarrollador (7 toques en "Número de compilación") → **Depuración inalámbrica** → **Vincular con código**.
2. En Termux:

   ```bash
   pkg install android-tools
   adb pair localhost:PUERTO CÓDIGO      # los de la pantalla de vinculación
   adb connect localhost:OTRO_PUERTO     # el que muestra Depuración inalámbrica
   adb shell pm disable-user --user 0 com.zte.zdm
   ```

`com.zte.zdm` es el cliente de actualizaciones de ZTE (el que está detrás de Ajustes → Actualización del sistema). Desactivado no descarga ni instala nada, y la notificación desaparece. Se vuelve atrás con `adb shell pm enable com.zte.zdm`.

## Tres caminos

| | Sin root (proot) | GhostLock | Unlock |
|---|:---:|:---:|:---:|
| Toca particiones | No | No | Sí |
| Garantía y apps de banco | ✅ | ✅ | ❌ |
| Lector de huellas | ✅ | ✅ | ❌ (ver abajo) |
| Root | — | ✅ temporal | ✅ permanente |
| chroot, gatillos, slider | ❌ | ✅ | ✅ |
| Hay que repetirlo al reiniciar | — | Sí | No |
| Necesita Windows | No | No | Sí |
| Riesgo | Ninguno | Bajo (si no se escribe nada) | Brick, IMEI |

El orden recomendado: **sin root** desde el primer día → **GhostLock** para respaldar y probar el chroot → **unlock** solo si después hace falta.

## Camino 1 — GhostLock: root temporal sin desbloquear

[GhostLock](https://github.com/YuKongA/ghostlock-app) usa una falla del kernel (CVE-2026-43499) para dar root **sin flashear nada**: el bootloader sigue bloqueado y el arranque verificado sigue en verde. El root vive en memoria y se pierde al reiniciar.

### ¿Anda en este teléfono?

GhostLock no reconoce teléfonos sino **el kernel exacto**, letra por letra. Desde Termux, sin root:

```bash
uname -r
```

| Kernel | Dónde figura |
|---|---|
| `6.6.92-android15-8-g3637f4904cf5-ab13944661-4k` | Red Magic 10 Pro (firmware 11.x) |
| `6.6.30-android15-8-g54dcbfbef792-ab12368803-4k` | Red Magic Tablet 3 Pro |

**Este teléfono (10.0.9 EEA) da exactamente `6.6.30-android15-8-g54dcbfbef792-ab12368803-4k`**: la misma línea que la Tablet 3 Pro. Es el kernel genérico de Google, el mismo compilado, así que hay muy buena chance; falta confirmarlo en un RM10 Pro. Si no coincide, la app puede sacar los datos que le faltan de una imagen `boot.img` o de un OTA (ver la [página de GhostLock en la wiki](https://github.com/mkonic/redmagic-wiki/blob/main/docs/rm10pro/ghostlock-temp-root.md)).

### Uso

1. Instalar la app **GhostLock** y **KernelSU** (`me.weishu.kernelsu`), que es el que administra el root.
2. Abrir GhostLock → **Run**. Si el teléfono se reinicia, perdió la carrera: es normal, se prueba de nuevo.
3. En KernelSU, darle root a **Termux**.

### ⛔ Reglas para no brickear

Con el bootloader bloqueado, **cualquier partición modificada deja el teléfono sin arrancar**, y la única salida es EDL desde Windows con un respaldo que quizás no tenés.

- **Nunca tocar "Instalar" en KernelSU**: escribe `init_boot`.
- Nada de Magisk ni de herramientas que flasheen.
- Leer particiones **sí** es seguro: es lo que hace `respaldo-efs.sh`.
- Remontar `/data` (lo que hace `arch.sh` para el chroot) no escribe particiones: es seguro.

Si se corta la señal de datos después de GhostLock, correrlo de nuevo sin reiniciar lo suele arreglar.

## Respaldo (obligatorio antes de flashear)

`respaldo-efs.sh` solo **lee**, así que se puede correr con el root de GhostLock, sin desbloquear nada:

```bash
./respaldo-efs.sh             # respalda en /sdcard/Arch-Magic/respaldo-efs/<fecha>/
./respaldo-efs.sh verificar   # revisa con sha256 que el último respaldo esté sano
```

Qué guarda:

| Grupo | Particiones | Por qué |
|---|---|---|
| Módem | `modemst1`, `modemst2`, `fsg`, `fsc`, `persist` | IMEI, señal y calibración. Únicas de este teléfono: si se borran, no hay de dónde bajarlas |
| Arranque de fábrica | `abl`, `xbl_config`, `init_boot`, `vbmeta`, `ztecfg`, `uefi`, `devcfg`, `boot` | Las versiones de **antes de los parches** son las que permiten reabrir el unlock más adelante. `ztecfg` es el permiso de unlock y es distinto en cada teléfono |

Compara cada copia con el teléfono (una copia cortada parece un archivo normal), anota modelo, firmware y kernel en `info.txt`, y guarda un `SHA256SUMS`. **Después sacalo del teléfono**: a la PC y a un segundo lugar.

Nunca restaures el módem en otro teléfono: el IMEI es de este y ponerlo en otro es ilegal.

## Camino 2 — Unlock

### Lo que se pierde

- **El lector de huellas.** En todo el RM10, al desbloquear, Android empieza a decir *"Fingerprint hardware missing"*. El sensor está bien; es la ROM que lo bloquea a propósito. En el RM11 hay un arreglo (Opción 18 del toolbox), pero **en el RM10 no hay ninguno publicado**. Con unlock, el `sudo` con huella de [`03-chroot/`](../03-chroot/#huella-digital-para-sudo) cae siempre a la contraseña.
- **Apps de banco y Google Wallet**: revisan el estado del bootloader, no solo el root.
- **Volver a bloquear no deja todo como estaba**: Play Store puede quedar sin certificar igual.
- La garantía. Y ningún seguro cubre un brick por flasheo.

### Herramienta

**ZTE Family Toolbox v1.2.8-beta2**, solo Windows. Es gratis: si alguien te cobra, es una estafa.

- Usar **1.2.8-beta2** (la traducción al inglés de dev-reverse) o el original en chino. **Ninguna otra traducción**: varias hacen respaldos que dicen "éxito" pero quedan incompletos.
- La 1.2.8-beta4 es más nueva pero anda peor que la beta2.
- Versiones anteriores a la 1.2.3 no reconocen el RM10 Pro.

### Preparar Windows

Casi todos los "el toolbox no anda" son de la PC, no del teléfono:

1. Driver **Qualcomm USB 9008** y Visual C++ (x64 y ARM64).
2. Carpeta en la raíz de `C:` con nombre corto, sin espacios, tildes ni caracteres chinos (renombrar también los `.bat`).
3. La carpeta del respaldo, **adentro** de la del toolbox.
4. Antivirus apagado o con excepción (Defender borra el toolbox).
5. Si no reconoce el teléfono: desactivar la verificación de firma de drivers.
6. En el teléfono: **sacar la cuenta de Google y el PIN de bloqueo** antes de empezar.

En el Administrador de dispositivos, el teléfono en modo EDL tiene que aparecer como `Qualcomm HS-USB QDLoader 9008`.

### Pasos

1. **Opción 4 — Respaldo completo.** Tiene que pesar **unos 22 GB**. Revisá el tamaño y que estén los `.img` y `.xml`: hay gente que perdió el IMEI para siempre con un respaldo de 7 GB que "salió bien". Si no hay respaldo sano, **no se sigue**.
2. **Opción 0 — Unlock.** Borra todo el teléfono. El toolbox lo pasa a modo EDL solo.
3. En el "arreglo final" el teléfono está en fastboot y `adb reboot edl` no anda: apagarlo manteniendo encendido, y apenas se reinicia, apretar **Vol+ y Vol− juntos** para entrar a EDL.
4. Verificar: `fastboot getvar unlocked` → `yes`.
5. **Opción 4 de nuevo**: el respaldo de después del unlock es el que sirve para aplicar actualizaciones.

Si el unlock parece fallar y el toolbox "deshace" y brickea: restaurar el respaldo. Puede que el unlock ya esté aplicado igual.

### Root

Con el bootloader desbloqueado: `init_boot` de **la misma versión de firmware**, parcheado con KernelSU o Magisk, flasheado con la Opción 12 del toolbox (el fastboot de fábrica no escribe).

Pasos exactos: _a completar con la experiencia real_.

### Comparte lo que funcione

La queja más repetida en el hilo es que los dueños de RM10 no publican qué versión de firmware anduvo ni sus respaldos. Si el unlock sale en la 10.0.9 EEA, anotalo acá y en el hilo de XDA (sin el módem ni `ztecfg`, que son de este teléfono).
