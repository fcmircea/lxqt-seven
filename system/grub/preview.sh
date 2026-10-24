#!/bin/bash
# Screenshot a GRUB theme as GRUB itself draws it, without rebooting:
# boots a throwaway UEFI GRUB image in QEMU/OVMF with sample menu entries.
#   preview.sh [theme_dir] [WIDTHxHEIGHT] [out.png]
# Needs grub-efi-amd64-bin, mtools, xorriso, qemu-system-x86, ovmf, python3-pil.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
THEME="$(readlink -f "${1:-$HERE/Primitivistical}")"
MODE="${2:-3840x2160}"
OUT="$(readlink -f "${3:-grub-preview-$MODE.png}")"
W=${MODE%x*}; H=${MODE#*x}

QPID=; WORK="$(mktemp -d)"
trap 'kill $QPID 2>/dev/null || true; rm -rf "$WORK"' EXIT
mkdir -p "$WORK/iso/boot/grub/themes" "$WORK/iso/boot/grub/fonts"
cp -r "$THEME" "$WORK/iso/boot/grub/themes/T"
cp /usr/share/grub/unicode.pf2 "$WORK/iso/boot/grub/fonts/"

# Same order as grub-mkconfig's 00_header: unicode first, then each theme .pf2.
cat > "$WORK/iso/boot/grub/grub.cfg" <<EOF
insmod all_video
insmod gfxterm
insmod png
set gfxmode=$MODE
loadfont \$prefix/fonts/unicode.pf2
terminal_output gfxterm
$(for f in "$THEME"/*.pf2; do echo "loadfont \$prefix/themes/T/$(basename "$f")"; done)
set theme=\$prefix/themes/T/theme.txt
set timeout_style=menu
set timeout=60
menuentry 'Kubuntu GNU/Linux' --class kubuntu --class gnu-linux --class gnu --class os { true; }
submenu 'Advanced options for Kubuntu GNU/Linux' { menuentry 'x' { true; } }
menuentry 'Memory test (mt86+x64)' --class memtest { true; }
menuentry 'Memory test (mt86+x64, serial console)' --class memtest { true; }
menuentry 'Windows Boot Manager (on /dev/nvme2n1p1)' --class windows --class os { true; }
menuentry 'UEFI Firmware Settings' { true; }
EOF
grub-mkrescue -o "$WORK/t.iso" "$WORK/iso" >/dev/null 2>&1

cp /usr/share/OVMF/OVMF_VARS_4M.fd "$WORK/vars.fd"
qemu-system-x86_64 -machine q35 -m 512 -display none \
    -drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
    -drive if=pflash,format=raw,file="$WORK/vars.fd" \
    -cdrom "$WORK/t.iso" -vga none -device VGA,xres="$W",yres="$H",vgamem_mb=64 \
    -qmp unix:"$WORK/qmp",server=on,wait=off >/dev/null 2>&1 &
QPID=$!
sleep "${WAIT:-12}"

python3 - "$WORK/qmp" "$WORK/s.ppm" <<'PY'
import socket, json, sys
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); f = s.makefile('rw')
f.readline()
for cmd in ({"execute": "qmp_capabilities"},
            {"execute": "screendump", "arguments": {"filename": sys.argv[2]}}):
    f.write(json.dumps(cmd) + "\n"); f.flush(); f.readline()
PY
python3 -c 'import sys; from PIL import Image; Image.open(sys.argv[1]).save(sys.argv[2])' "$WORK/s.ppm" "$OUT"
echo "$OUT"
