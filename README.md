# Grok Bot for Linux (unofficial)

> **Unofficial. Not an xAI or Cursor product.**
> Linux is unsupported by them. This repo is only for people on Linux
> who already have a Grok Bot plan and want the desktop app natively —
> no Wine.

Grateful fork of
**[jakob-bu/grok-bot-linux-unofficial](https://github.com/jakob-bu/grok-bot-linux-unofficial)**.
We use Jakob’s port; it works really well. Please see [THANKS.md](THANKS.md).

Cursor ships Grok Bot for macOS and Windows only. This does the same
thing the [Codex Mac-to-Linux port](https://github.com/ilysenko/codex-desktop-linux)
did: take the official Electron app, put it on a Linux Electron runtime,
and replace the Windows-only native addons.

Current target: **Grok Bot 0.29.0** on **Electron 42.1.0** (x86_64).

This repository **never** commits the official installer, `app.asar`,
or built binaries. You build those on your machine. GitHub Releases
here will not ship Grok Bot itself.

## Launch it like any other app (no sudo)

```bash
sudo apt install p7zip-full curl unzip build-essential python3 \
  libfuse2 fakeroot rsync
# Node.js 20+ (Ubuntu 24.04 distro nodejs is often too old;
# use https://github.com/nvm-sh/nvm or NodeSource)

git clone https://github.com/lyffseba/grok-bot-linux-unofficial.git grok-bot-linux
cd grok-bot-linux
make build
make install-user
```

Then open **Grok Bot (Unofficial)** from the app menu, or run:

```bash
grok-bot
```

Sign in with the same Cursor / SuperGrok account you use on Mac or
Windows. Bots live on the cloud computer; this build is the remote
control.

Remove it:

```bash
make uninstall-user
```

## Ubuntu / Debian (.deb, needs sudo)

```bash
make build
sudo dpkg -i dist/grok-bot_*_amd64.deb
sudo apt-get install -f -y   # if dpkg reports missing GTK/NSS libs
grok-bot
```

Or skip packaging and run the tree:

```bash
make build
./dist/Grok_Bot_0.29.0_linux_x64/grok-bot --no-sandbox --ozone-platform-hint=auto
```

AppImage (needs FUSE 2):

```bash
chmod +x dist/Grok_Bot_*_x86_64.AppImage
./dist/Grok_Bot_*_x86_64.AppImage
```

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
| `make install-user` | Copy into `~/.local` and add an app-menu shortcut |
| `make uninstall-user` | Remove the `~/.local` install |
| `./scripts/build.sh 0.29.0` | Pin a specific upstream version |
| `./scripts/build.sh --exe ~/Downloads/Grok_Bot_0.29.0_Setup.exe` | Use an installer you already downloaded |
| `make install-deb` | Build if needed and `dpkg -i` |

If Chromium's sandbox cannot take setuid (containers, some Ubuntu
defaults), the launcher adds `--no-sandbox`. Extra Electron flags go
in `~/.config/grok-bot/electron-flags.conf`, one per line.

NVIDIA + black window: add `--ozone-platform=x11` to that file.

## Updates

The in-app updater talks to Windows/macOS feeds and will not install a
Linux build. When Cursor ships a new version:

```bash
make detect
make build
make install-user
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
- Build machine: `p7zip-full`, `curl`, `unzip`, `g++`, `python3`, Node 20+, `rsync`

## License

Scripts and Linux-native sources in this repo: [MIT](LICENSE).

Upstream port: [jakob-bu/grok-bot-linux-unofficial](https://github.com/jakob-bu/grok-bot-linux-unofficial) (MIT).

Grok Bot belongs to xAI / Cursor. Electron belongs to the Electron
project. See [NOTICE.md](NOTICE.md) and [THANKS.md](THANKS.md).
