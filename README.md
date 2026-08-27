# Grok Bot for Linux

Unofficial Ubuntu/Linux build of the **Grok Bot** desktop app.

Cursor ships Grok Bot for macOS and Windows only. This repo does the same
thing the [Codex Mac-to-Linux port](https://github.com/ilysenko/codex-desktop-linux)
did: take the official Electron app, put it on a Linux Electron runtime,
and replace the Windows-only native addons.

It is **not** an xAI or Cursor product. Linux is unsupported by them.

## What you get

The official Grok Bot UI — bots, the shared computer, sign-in with your
Cursor account — running as a native Linux app. No Wine.

Current target: **Grok Bot 0.29.0** on **Electron 42.1.0** (x86_64).

## Ubuntu / Debian

```bash
sudo apt install p7zip-full curl unzip build-essential python3 \
  libfuse2 fakeroot
# Node.js 20+ (Ubuntu 24.04: sudo apt install nodejs npm  is too old;
# use https://github.com/nvm-sh/nvm or NodeSource)

git clone <this-repo> grok-bot-linux
cd grok-bot-linux
make build
sudo dpkg -i dist/grok-bot_*_amd64.deb
sudo apt-get install -f -y   # if dpkg reports missing GTK/NSS libs

grok-bot
```

Or skip the package and run the tree directly:

```bash
make build
./dist/Grok_Bot_0.29.0_linux_x64/grok-bot --no-sandbox --ozone-platform-hint=auto
```

AppImage (needs FUSE 2):

```bash
chmod +x dist/Grok_Bot_*_x86_64.AppImage
./dist/Grok_Bot_*_x86_64.AppImage
```

Sign in with the same Cursor / SuperGrok account you use on the Mac app.
Bots live on the cloud computer; this build is the remote control.

## Other distros

The tarball in `dist/` is a self-contained Electron tree. On Fedora /
Arch, install GTK3, NSS, ALSA, and Mesa, then:

```bash
tar -xzf dist/Grok_Bot_*_linux_x64.tar.gz
./Grok_Bot_*_linux_x64/grok-bot --no-sandbox --ozone-platform-hint=auto
```

## Build options

| Command | Result |
|---|---|
| `make detect` | Newest official Windows version on Cursor's CDN |
| `make build` | Tarball + `.deb` + AppImage in `dist/` |
| `./scripts/build.sh 0.29.0` | Pin a specific upstream version |
| `./scripts/build.sh --exe ~/Downloads/Grok_Bot_0.29.0_Setup.exe` | Use an installer you already downloaded |
| `make install-deb` | Build if needed and `dpkg -i` |

If Chromium's sandbox cannot take setuid (containers, some Ubuntu
defaults), the `/usr/bin/grok-bot` wrapper adds `--no-sandbox`. Extra
Electron flags go in `~/.config/grok-bot/electron-flags.conf`, one per
line.

NVIDIA + black window: add `--ozone-platform=x11` to that file.

## Updates

The in-app updater talks to Windows/macOS feeds and will not install a
Linux build. When Cursor ships a new version:

```bash
make detect
make build
sudo dpkg -i dist/grok-bot_*_amd64.deb
```

## How this compares to the Mac app

| | Official Mac app | This Linux build |
|---|---|---|
| UI / bots / cloud computer | yes | same `app.asar` |
| Sign-in | Cursor account | same |
| Native addons | Mach-O | rebuilt or replaced for Linux |
| Auto-update | official | rebuild from the new Windows installer |
| Support | Cursor | none (community) |

The Mac `.dmg` is not used here. Extracting it on Linux is awkward, and
its native modules are still the wrong ABI. The Windows NSIS installer
unpacks with `7z` and is the source every working community port uses.
Details: [docs/how-it-works.md](docs/how-it-works.md).

## Requirements

- x86_64 Linux, glibc 2.34+ (Ubuntu 22.04 or newer)
- Eligible Grok Bot plan (same as the official apps)
- Build machine: `p7zip-full`, `curl`, `unzip`, `g++`, `python3`, Node 20+

This repository never commits the official installer, `app.asar`, or
built binaries. Those are produced on your machine.

## License

Scripts and Linux-native sources in this repo: [MIT](LICENSE).

Grok Bot belongs to xAI / Cursor. Electron belongs to the Electron
project. See [NOTICE.md](NOTICE.md).
