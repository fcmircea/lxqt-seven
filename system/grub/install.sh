#!/bin/bash
# Optional: install the Primitivistical GRUB theme and ask GRUB for the
# mode the theme is sized for.
#   sudo system/grub/install.sh [modes]     (default 1920x1080)
# GRUB uses the first mode the firmware offers; "auto" is appended as a last resort.
# Backs up /etc/default/grub and the installed theme first.
set -euo pipefail

[ "$EUID" -eq 0 ] || { echo "Run with sudo" >&2; exit 1; }
HERE="$(cd "$(dirname "$0")" && pwd)"
MODES="${1:-1920x1080}"
DEST=/boot/grub/themes/Primitivistical
STAMP="$(date +%Y%m%d-%H%M%S)"

if [ -d "$DEST" ]; then
    mv "$DEST" "$DEST.bak-$STAMP"
    echo "Old theme kept as $DEST.bak-$STAMP"
fi
cp -r "$HERE/Primitivistical" "$DEST"

cp -a /etc/default/grub "/etc/default/grub.bak-$STAMP"
set_key() {  # set_key <KEY> <value>
    if grep -q "^$1=" /etc/default/grub; then
        sed -i "s|^$1=.*|$1=\"$2\"|" /etc/default/grub
    else
        sed -i -e '$a\' /etc/default/grub
        echo "$1=\"$2\"" >> /etc/default/grub
    fi
}
set_key GRUB_THEME "$DEST/theme.txt"
set_key GRUB_GFXMODE "$MODES,auto"
echo "/etc/default/grub backed up to /etc/default/grub.bak-$STAMP"

update-grub
