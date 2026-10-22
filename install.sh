#!/bin/bash
# Install the "Seven" LXQt + labwc setup for the current user.
# Everything goes under $HOME; existing files are backed up first.
# System-level pieces (iGPU udev rule, /etc/environment) are NOT touched -
# see the README for those.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.local/state/lxqt-seven-backup-$(date +%Y%m%d-%H%M%S)"

backup() {  # backup <path>
    if [ -e "$1" ]; then
        mkdir -p "$BACKUP$(dirname "$1")"
        cp -a "$1" "$BACKUP$1"
    fi
}

put() {  # put <src> <dest>
    backup "$2"
    mkdir -p "$(dirname "$2")"
    cp -a "$1" "$2"
}

put_template() {  # put_template <src.in> <dest>  (replaces @HOME@)
    backup "$2"
    mkdir -p "$(dirname "$2")"
    sed "s|@HOME@|$HOME|g" "$1" > "$2"
}

echo "==> LXQt themes"
for t in seven dark-code; do
    backup "$HOME/.local/share/lxqt/themes/$t"
    rm -rf "$HOME/.local/share/lxqt/themes/$t"
    mkdir -p "$HOME/.local/share/lxqt/themes"
    cp -a "$REPO/lxqt/themes/$t" "$HOME/.local/share/lxqt/themes/$t"
done

echo "==> LXQt config (theme, palette, panel, session)"
put "$REPO/lxqt/lxqt.conf" "$HOME/.config/lxqt/lxqt.conf"
put_template "$REPO/lxqt/session.conf.in" "$HOME/.config/lxqt/session.conf"
put_template "$REPO/lxqt/panel.conf.in" "$HOME/.config/lxqt/panel.conf"
put_template "$REPO/pcmanfm-qt/settings.conf.in" "$HOME/.config/pcmanfm-qt/lxqt/settings.conf"

echo "==> labwc theme and config"
for f in "$REPO"/labwc/theme/Seven/labwc/*; do
    put "$f" "$HOME/.local/share/themes/Seven/labwc/$(basename "$f")"
done
for f in rc.xml autostart environment menu.xml themerc-override; do
    put "$REPO/labwc/$f" "$HOME/.config/labwc/$f"
done

echo "==> scripts (snip, claude-desktop wrapper, de-measure.sh)"
for f in "$REPO"/bin/*; do
    put "$f" "$HOME/.local/bin/$(basename "$f")"
    chmod +x "$HOME/.local/bin/$(basename "$f")"
done

echo "==> Network monitor plugin with link speed in its tooltip"
# Built from lxqt-panel 2.3.2 sources; a plugin from another release may not load.
if lxqt-panel --version 2>/dev/null | grep -q '^lxqt-panel 2\.3\.' && [ -e /usr/include/statgrab.h ] \
   && command -v cmake >/dev/null; then
    NETMON_BUILD="$(mktemp -d)"
    cmake -S "$REPO/plugins/networkmonitor" -B "$NETMON_BUILD" -DCMAKE_BUILD_TYPE=Release >/dev/null \
        && cmake --build "$NETMON_BUILD" -j >/dev/null \
        && cmake --install "$NETMON_BUILD" >/dev/null \
        && rm -rf "$NETMON_BUILD" \
        || echo "   (build failed: see cmake in $NETMON_BUILD)"
else
    echo "   (skipped: needs lxqt-panel 2.3, cmake, qt6-base-dev and libstatgrab-dev)"
fi

echo "==> 3840x2160 wallpaper"
python3 "$REPO/wallpaper/make-next-4k.py" || echo "   (skipped: needs python3-pil and KDE's Next wallpaper)"

echo "==> Breeze Dark for KDE apps running outside Plasma"
if command -v kwriteconfig6 >/dev/null; then
    backup "$HOME/.config/kdeglobals"
    kwriteconfig6 --file kdeglobals --group General --key ColorScheme BreezeDark
    for rc in katerc dolphinrc kwriterc okularrc gwenviewrc arkrc; do
        kwriteconfig6 --file "$rc" --group UiSettings --key ColorScheme BreezeDark
    done
else
    echo "   (skipped: kwriteconfig6 not found)"
fi

echo "==> Firefox (snap) taskbar icon"
if [ -e /snap/firefox/current/default256.png ]; then
    mkdir -p "$HOME/.local/share/icons/hicolor/256x256/apps"
    ln -sf /snap/firefox/current/default256.png "$HOME/.local/share/icons/hicolor/256x256/apps/firefox_firefox.png"
    [ -f "$HOME/.local/share/icons/hicolor/index.theme" ] || cp /usr/share/icons/hicolor/index.theme "$HOME/.local/share/icons/hicolor/"
else
    echo "   (skipped: snap Firefox not installed)"
fi

echo
echo "Done. Backups of replaced files: $BACKUP"
echo "Log out and pick 'LXQt (Wayland)' in SDDM. See README.md for the machine-specific bits"
echo "(monitor name/scale in labwc/autostart, keyboard layout, iGPU pinning)."
