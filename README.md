# lxqt-seven

A Windows 7-flavoured dark setup for **LXQt 2.3 on Wayland (labwc)**, running
alongside KDE Plasma 6 on Ubuntu 26.04. It came out of comparing how much GPU
memory each desktop uses on a hybrid AMD iGPU + NVIDIA machine.

![panel](screenshots/panel.png)

![start menu](screenshots/start-menu.png)

![title bar](screenshots/titlebar.png)

## What's in it

| Path | What it is |
|---|---|
| `lxqt/themes/seven/` | Panel theme: glass-style blue-grey gradient bar, blue start orb, glassy icon-only task buttons, two-line clock, start menu styled like the context menu |
| `lxqt/themes/dark-code/` | Plainer dark panel theme with a blue accent (the stock "dark" theme with its red accent swapped out) |
| `lxqt/lxqt.conf` | Breeze Dark palette (`#202326` window, `#2a7db3` selection), Breeze widget style, breeze-dark icons |
| `lxqt/panel.conf.in` | Panel layout: start menu, Quick Launch (Claude, QTerminal, file manager), grouped icon-only taskbar, tray, clock, show-desktop. No desktop switcher |
| `lxqt/session.conf` | Uses labwc as the compositor and skips LXQt's first-run compositor picker |
| `labwc/theme/Seven/` | labwc title bars to match: gradient active title, flat grey inactive, dark menus and Alt+Tab |
| `labwc/rc.xml` | LXQt's default labwc config, set to the Seven theme with breeze-dark icons, plus screenshot shortcuts |
| `labwc/autostart`, `labwc/environment` | Monitor mode and scale, keyboard layout, iGPU pinning (machine-specific, see below) |
| `pcmanfm-qt/settings.conf.in` | Desktop wallpaper setting |
| `wallpaper/make-next-4k.py` | Generates a 3840x2160 copy of KDE's "Next" wallpaper (Plasma otherwise loads the 5120x2880 one on 4K) |
| `bin/snip` | Snipping-tool style screenshots with `grim` + `slurp`, saved to `~/Pictures/Screenshots` and copied to the clipboard |
| `bin/claude-desktop` | Wrapper that gives the Claude desktop app KWallet access outside Plasma (Electron otherwise disables encrypted storage) |
| `bin/de-measure.sh` | Logs iGPU/NVIDIA memory, iGPU load and desktop RAM per session, for comparing desktops |
| `system/61-amd-igpu.rules` | udev rule creating a stable `/dev/dri/amd-igpu` symlink (optional, needs root) |

## Install

Requires LXQt's minimal pieces:

```bash
sudo apt install --no-install-recommends lxqt-core lxqt-wayland-session labwc wlr-randr qtxdg-tools screengrab grim slurp wl-clipboard python3-pil
```

Then, as your user:

```bash
./install.sh
```

It backs up anything it replaces to `~/.local/state/lxqt-seven-backup-<date>/`.
Log out and choose **LXQt (Wayland)** in SDDM.

### Machine-specific bits to adjust

- `labwc/autostart`: `wlr-randr --output HDMI-A-1 --mode 3840x2160@120 --scale 1.5`. Change it to your output name, mode and scale (`wlr-randr` lists outputs).
- `labwc/environment`: `XKB_DEFAULT_LAYOUT=ro` and `WLR_DRM_DEVICES=/dev/dri/amd-igpu`.
- iGPU pinning (optional, hybrid GPU machines): install the udev rule and point both compositors at the iGPU:

  ```bash
  sudo cp system/61-amd-igpu.rules /etc/udev/rules.d/
  echo 'KWIN_DRM_DEVICES=/dev/dri/amd-igpu' | sudo tee -a /etc/environment
  echo 'WLR_DRM_DEVICES=/dev/dri/amd-igpu' | sudo tee -a /etc/environment
  ```

  Remove the `WLR_DRM_DEVICES` line from `labwc/environment` if you don't use this.

## Keyboard shortcuts (labwc)

| Keys | Action |
|---|---|
| Super+Shift+S | Region screenshot (drag), saved and copied |
| Super+Shift+F | Full-screen screenshot, saved and copied |
| Super+Shift+G | ScreenGrab app |
| Print / Shift+Print / Ctrl+Print | Same three, for keyboards with a Print key |
| Super+U / I / J / K | Snap window to top-left / top-right / bottom-left / bottom-right quarter (press again to restore) |
| Super+C | Centre the window at 80% size |
| Super+Arrows | Snap to left / right / top / bottom half |
| Super+A | Toggle maximise |

Dragging also snaps, FancyZones-style: drop a window on a screen edge for a half,
in a corner for a quarter, at the top to maximise. Hold Ctrl, Alt, Shift or Super
while dragging to see and pick the predefined zones (`<regions>` in `labwc/rc.xml`).

## Firefox

Firefox draws its own title bar by default. To get the Seven title bar, right-click
the tab bar → **Customize Toolbar…** → tick **Title Bar**. The installer also links
the snap Firefox icon so it shows on the LXQt taskbar.

## Measured (one 4K monitor at 120 Hz and 150%, same apps open)

| | Plasma 6.6 | LXQt 2.3 + labwc |
|---|---|---|
| iGPU VRAM + GTT | 699 MiB | 267 MiB |
| Desktop session RAM | 593 MiB | 423 MiB |
| NVIDIA VRAM (compositor on iGPU) | 1 MiB | 1 MiB |

## License

LGPL-2.1-or-later. The LXQt panel themes are derived from
[lxqt-themes](https://github.com/lxqt/lxqt-themes) (LGPL-2.1+). The wallpaper
is not included; `make-next-4k.py` builds it from your installed copy of KDE's
"Next" wallpaper (CC-BY-SA-4.0, Krystian Zajdel).
