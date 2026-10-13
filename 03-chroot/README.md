# 03-chroot — Arch Linux en chroot

Arch Linux ARM corriendo sobre el kernel de Android, casi nativo y con acceso real al hardware. **Requiere root** (Etapa 2).

> 🚧 Escrito antes de que llegue el teléfono. La lógica de montaje está probada en una PC, pero en el RedMagic todavía no. Cuando lo esté, este aviso desaparece.

## Uso

Desde Termux, como usuario normal (el script pide root solo):

```bash
pkg install curl tar
cd ~/Arch-Magic/03-chroot

./arch.sh instalar      # descarga Arch Linux ARM (~600 MB) y lo descomprime
./arch.sh configurar    # DNS, pacman, idioma, zona horaria y tu usuario
./arch.sh entrar gauchito
```

| Comando | Qué hace |
|---|---|
| `instalar` | Descarga `ArchLinuxARM-aarch64-latest.tar.gz` y lo descomprime en `/data/local/arch` |
| `configurar` | Primer arranque: DNS, grupos de red, llaves de pacman, `pacman -Syu`, `sudo`, idioma, zona horaria y usuario. Borra el usuario `alarm` que trae la imagen |
| `entrar [usuario]` | Monta todo y abre una consola. Sin usuario, entra como root |
| `montar` | Monta todo sin abrir consola. Lo usan el asistente de voz y el demonio de entradas |
| `desmontar` | Desmonta todo, de adentro hacia afuera |
| `estado` | Muestra qué está montado |
| `huella` | Usa la huella digital para `sudo`. `huella quitar` vuelve a solo contraseña |

`entrar` se puede llamar las veces que quieras: lo que ya está montado no se vuelve a montar.

## Huella digital para sudo

Linux no puede leer el sensor de huellas: lo maneja Android. Así que se hace un puente:

```
sudo (Arch) → huella-pam → socket → huella.sh (Termux) → cartel de huella de Android
```

```bash
pkg install termux-api socat jq   # y la app Termux:API de F-Droid
./arch.sh huella                  # instala el lado de Arch (una sola vez)
./huella.sh                       # dejarlo corriendo (o con Termux:Boot)
```

Cuando hagas `sudo` en Arch, aparece el cartel de Android con quién lo pide. Ponés el dedo y listo.

**La contraseña nunca deja de andar.** Si la huella falla, si tocás "Usar contraseña", si pasan 30 segundos o si `huella.sh` no está corriendo, sudo te pide la contraseña como siempre. Para volver a solo contraseña: `./arch.sh huella quitar`.

Por qué no se puede trampear desde Arch: el socket vive en una carpeta que es del usuario de Termux con permisos `700`. Los usuarios de Arch no pueden ni mirarla, así que no pueden poner un socket falso que conteste "OK". Solo root (o sea, sudo) llega.

Probado en una PC con `sudo` y PAM de verdad y un sensor de mentira: huella buena entra sin contraseña, huella mala cae a la contraseña, y sin demonio también. En esa prueba apareció que `pam_exec` corre el programa como el usuario y no como root, por eso la regla lleva `seteuid`.

## Configuración

Por variables de entorno, sin tocar el script:

| Variable | Por defecto |
|---|---|
| `ARCH_RAIZ` | `/data/local/arch` |
| `ARCH_USUARIO` | `gauchito` |
| `ARCH_IDIOMA` | `es_UY.UTF-8` |
| `ARCH_ZONA` | `America/Montevideo` |
| `COMPARTIDA_ANDROID` | `/sdcard/Arch-Magic` |

```bash
ARCH_USUARIO=franco ./arch.sh configurar
```

## Qué se monta

| Adentro de Arch | Viene de | Para qué |
|---|---|---|
| `/proc`, `/sys` | kernel | Lo básico de cualquier Linux |
| `/dev`, `/dev/pts` | Android | Dispositivos y terminales (las mismas que Termux) |
| `/dev/shm`, `/tmp` | RAM | Temporales; se borran al desmontar |
| `/tmp/.X11-unix` | Termux:X11 | Que Sway pueda dibujar en `DISPLAY=:0` |
| `/mnt/android` | `/sdcard/Arch-Magic` | **La única** carpeta compartida con Android |
| `/run/arch-magic` | Termux | El socket de la huella para `sudo` (solo lo ve root) |

El resto de `/sdcard` y las particiones de Android **no se ven** desde Arch. Es a propósito: Claude Code trabaja ahí adentro y no tiene por qué tocar tus fotos.

## Detalles de Android que el script resuelve

- **`/data` viene con `nosuid`**: sin remontarlo, `sudo` no funciona. El script lo remonta con `dev,suid`.
- **No hay `/etc/resolv.conf`**: Android resuelve DNS por otro lado. Se escribe uno con 1.1.1.1 y 8.8.8.8.
- **Red restringida por grupo**: el kernel de Android solo deja usar internet a los grupos `aid_inet` (3003) y `aid_net_raw` (3004). Se crean en Arch y se agregan root, tu usuario y `alpm`, que es con el que pacman descarga.
- **Los montajes se pierden entre sesiones de su**: el script usa `su --mount-master` (Magisk y KernelSU) para que queden en el espacio de nombres global.

## Si algo falla

- **pacman no descarga nada** (`failed retrieving file`): revisá que `alpm` esté en `aid_inet` con `id alpm`. Si sigue fallando, en `/etc/pacman.conf` comentá `DownloadUser = alpm`.
- **pacman se queja del sandbox** (Landlock): agregá `DisableSandbox` en la sección `[options]` de `/etc/pacman.conf`.
- **`sudo: effective uid is not 0`**: `/data` quedó con `nosuid`. Salí y volvé a entrar con `./arch.sh entrar`.
- **`desmontar` dice que algo está ocupado**: hay un proceso de Arch todavía corriendo. Lo desmonta en diferido igual, pero conviene cerrar todo antes.

## Sin root

Mientras tanto, o si no querés rootear: `proot-distro`, como figura en el README principal. Es más lento y no ve el hardware, pero anda desde el primer día.
