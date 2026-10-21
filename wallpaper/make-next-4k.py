#!/usr/bin/env python3
"""Build a 3840x2160 copy of KDE's default "Next" wallpaper.

Plasma picks the 5120x2880 image on a 4K screen, which costs extra GPU memory
for no visible gain. This writes a wallpaper package with only 3840x2160
light/dark images, used by both Plasma and the LXQt desktop.

The source images come from the installed plasma-workspace-wallpapers /
breeze package (CC-BY-SA-4.0, Krystian Zajdel), so they are generated
locally rather than redistributed here.
"""
import os
import shutil
import sys

from PIL import Image

SRC = "/usr/share/wallpapers/Next/contents"
DEST = os.path.expanduser("~/.local/share/wallpapers/Next-4K")
SIZE = (3840, 2160)


def main():
    if not os.path.isdir(SRC):
        sys.exit(f"{SRC} not found - is the KDE 'Next' wallpaper installed?")
    for sub in ("images", "images_dark"):
        src = os.path.join(SRC, sub, "5120x2880.png")
        if not os.path.exists(src):
            print(f"skipping {sub}: {src} missing")
            continue
        out_dir = os.path.join(DEST, "contents", sub)
        os.makedirs(out_dir, exist_ok=True)
        out = os.path.join(out_dir, "3840x2160.png")
        Image.open(src).convert("RGB").resize(SIZE, Image.LANCZOS).save(out, optimize=True)
        print(f"wrote {out}")
    shutil.copy(os.path.join(os.path.dirname(os.path.abspath(__file__)), "metadata.json"),
                os.path.join(DEST, "metadata.json"))


if __name__ == "__main__":
    main()
