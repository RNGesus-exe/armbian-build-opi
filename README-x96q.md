# Armbian for the X4MINI H618 TV box

Armbian (Debian 12 bookworm, kernel 6.6.44) for an Allwinner H618 Android TV box, built as `BOARD=x96q-v5-1`. All work is on the `opi` branch.

## Hardware

- Board: `X4MINI_H618_6521_4BIT_V1.0`
- SoC: Allwinner H618
- RAM: DDR3
- Storage: 16 GB eMMC and microSD
- Ethernet: 10/100 (internal PHY)
- Wi-Fi: SeekWave SWT6621S (SDIO)
- Serial: pads `R T G`, 115200 8N1 (`ttyS0`)

This is not an Orange Pi Zero 3. The Orange Pi Zero 3 image does not boot on this box: it sets up LPDDR4 memory, and this board has DDR3.

## Status

| Feature | State |
|---|---|
| Boot from microSD | works |
| Ethernet (100 Mbps) | works |
| Wi-Fi | works |
| SSH | works |
| Serial console | works |
| Bluetooth | not included, not needed |
| HDMI | not tested |
| Install to eMMC | not tested |

## Build

You need an Ubuntu 24.04 host with Docker, and your user must be in the `docker` group. Run the build from a normal terminal: VS Code's Flatpak terminal has no `sudo` or `docker`.

```bash
./compile.sh build BOARD=x96q-v5-1 BRANCH=current RELEASE=bookworm \
  BUILD_MINIMAL=no BUILD_DESKTOP=no KERNEL_CONFIGURE=no KERNEL_GIT=shallow \
  DOCKER_ARMBIAN_BASE_IMAGE=ubuntu:noble ENABLE_EXTENSIONS=x96q-seekwave-wifi
```

The image (about 2.5 GB) is written to `output/images/Armbian-unofficial_24.11.0-trunk_X96q-v5-1_bookworm_current_6.6.44.img`. A build that also compiles the kernel takes about 55 minutes.

What the less obvious options do:

- `DOCKER_ARMBIAN_BASE_IMAGE=ubuntu:noble`: the default jammy build container can't verify Debian's current signing keys. Without this option the build stops with `Release signed by unknown key`.
- `KERNEL_GIT=shallow`: skips an interactive question about downloading the kernel source.
- `ENABLE_EXTENSIONS=x96q-seekwave-wifi`: adds the Wi-Fi driver and firmware. Leave it out and the image has no Wi-Fi.

If Docker can't resolve hostnames (`Temporary failure resolving`), add `"dns": ["1.1.1.1", "8.8.8.8"]` to `/etc/docker/daemon.json` and restart Docker.

## Flash and first boot

Find the card's device name with `lsblk` first: `dd` overwrites whatever device it is given.

```bash
IMG=output/images/Armbian-unofficial_24.11.0-trunk_X96q-v5-1_bookworm_current_6.6.44.img
udisksctl unmount -b /dev/mmcblk0p1   # only if the card was mounted automatically
sudo dd if="$IMG" of=/dev/mmcblk0 bs=4M conv=fsync status=progress
sudo cmp -n "$(stat -c %s "$IMG")" "$IMG" /dev/mmcblk0   # no output means the write is good
```

Boot the box from the card. Log in as `root` with password `1234`, over serial or SSH. On first login you'll be asked to set a new password and create a user. Then connect to Wi-Fi:

```bash
nmcli device wifi connect "SSID" password "PASSWORD"
```

## Changes on top of Armbian

| Change | Files | Source |
|---|---|---|
| Board support: board config, device tree, U-Boot config for DDR3, Ethernet PHY setup in U-Boot, lower eMMC clock | `config/boards/x96q-v5-1.tvb`<br>`patch/kernel/archive/sunxi-6.{6,10}/patches.armbian/arm64-dts-sun50i-h313-x96q-v5.1.patch`<br>`patch/u-boot/u-boot-sunxi/board_x96q-v5-1/` | sicXnull, branch `X96Q-5.1-DDR3` (`333e462`) |
| `base-files` version lookup now reads Armbian's package index instead of scraping packages.debian.org and packages.ubuntu.com | `lib/functions/general/apt-utils.sh`<br>`lib/functions/artifacts/artifact-armbian-base-files.sh` | backported from [armbian/build](https://github.com/armbian/build) (`ca7b331`) |
| Wi-Fi: builds the SeekWave driver against the image's kernel, installs `skw_sdio_lite.ko`, `swt6621s_wifi.ko` and the firmware, and loads the driver at boot | `userpatches/extensions/x96q-seekwave-wifi.sh`<br>`userpatches/drivers/seekwave-swt6621s/`<br>`userpatches/firmware/seekwave-swt6621s/` | driver and firmware from [luisdosreis/linknlink-isg-box-se-armbian](https://github.com/luisdosreis/linknlink-isg-box-se-armbian) (`e89771b`); driver's kernel-version checks fixed so it builds on 6.6 |
| `DisableSerialConsole`: turns off the Linux serial console and the serial login prompt | `userpatches/customize-image.sh` | ours; it only runs for `BOARD=orangepizero3`, so this box still has its serial console |
| Track the `userpatches/` files above in git (Armbian ignores the whole folder by default) | `.gitignore` | ours |
