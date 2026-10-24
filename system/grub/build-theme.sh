#!/bin/bash
# Rebuild system/grub/Primitivistical from the upstream theme
# (https://github.com/fffred/primitivistical-grub, v0.2).
#   build-theme.sh <upstream>/Primitivistical [font_px icon_px item_px]
# Defaults suit GRUB at 1920x1080 on a 4K panel (the monitor doubles it);
# use 40 64 80 for GRUB at native 3840x2160.
# GRUB draws fonts as 1-bit bitmaps and shrinks icons crudely, so both are
# made at the exact pixel size they are shown at.
set -euo pipefail

SRC="$1"; FPX="${2:-20}"; IPX="${3:-32}"; IH="${4:-40}"
OUT="$(cd "$(dirname "$0")" && pwd)/Primitivistical"
TTF=/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf

rm -rf "$OUT"; mkdir -p "$OUT/icons"
# Only the selection box: upstream's item_*.png are fully transparent but still
# get alpha-blended across every row on each redraw.
cp "$SRC"/selected_*.png "$OUT/"
cp "$SRC/../LICENSE" "$OUT/COPYING"

python3 - "$SRC/icons" "$OUT/icons" "$IPX" <<'PY'
import sys, pathlib
from PIL import Image
src, dst, px = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), int(sys.argv[3])
for p in sorted(src.glob('*.png')):
    im = Image.open(p).convert('RGBA')
    im = im.crop(im.getbbox())                       # trim padding so logos fill the box
    side = max(im.size)
    sq = Image.new('RGBA', (side, side))
    sq.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    sq.resize((px, px), Image.LANCZOS).save(dst / p.name, optimize=True)
PY

grub-mkfont -s "$FPX" -o "$OUT/DejaVuSans$FPX.pf2" "$TTF"
NAME="DejaVu Sans Regular $FPX"

# Upstream ships placeholders (ICON_WIDTH, ...) that its installer fills in.
# Each move redraws the whole boot_menu box and copies its rows to the screen,
# so the box is sized to 8 rows instead of 70% of the screen.
sed -e "/^    item_pixmap_style/d; s/height = 70%/height = $((8 * (IH + IH / 6)))/" \
    -e "s/ICON_WIDTH/$IPX/; s/ICON_HEIGHT/$IPX/; s/ITEM_ICON_SPACE/$((IPX / 3))/" \
    -e "s/ITEM_HEIGHT/$IH/; s/ITEM_SPACING/$((IH / 6))/" \
    -e "s/^    item_color = /    item_font = \"$NAME\"\n    selected_item_font = \"$NAME\"\n    item_color = /" \
    -e "s/^    color = \"#ddd\"/    font = \"$NAME\"\n    color = \"#ddd\"/" \
    "$SRC/theme.txt" > "$OUT/theme.txt"
echo "Built $OUT ($NAME, ${IPX}px icons, ${IH}px rows)"
