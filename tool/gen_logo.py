#!/usr/bin/env python3
"""Generates a white school-building logo (PNG) for the native Android
splash screen into every mipmap density folder.

Drawn geometrically (flag + building + roof + door + windows) so it does
not depend on any icon font. Supersampled 8x then LANCZOS-downscaled for
smooth edges.
"""
from PIL import Image, ImageDraw
import os

WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)

BASE = 24.0  # design grid units
SS = 8       # supersample factor for the 192px master

MASTER = 192
SIZES = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
OUT = "android/app/src/main/res"


def rounded_rect(d, box, radius):
    x0, y0, x1, y1 = box
    d.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=WHITE)


def draw_logo(size):
    """Draw the logo at `size` px directly (already scaled coordinates)."""
    s = size / BASE
    img = Image.new("RGBA", (size, size), CLEAR)
    d = ImageDraw.Draw(img)

    # ── Flag ──
    # pole
    d.rounded_rectangle(
        [5.4 * s, 0.6 * s, 6.6 * s, 5.6 * s], radius=0.4 * s, fill=WHITE
    )
    # pennant (triangle flag pointing right)
    d.polygon(
        [(6.6 * s, 1.0 * s), (12.4 * s, 2.6 * s), (6.6 * s, 4.2 * s)], fill=WHITE
    )

    # ── Roof (pediment) ──
    d.polygon(
        [(4.0 * s, 10.0 * s), (12.0 * s, 4.0 * s), (20.0 * s, 10.0 * s)], fill=WHITE
    )

    # ── Building body ──
    rounded_rect(d, [4.0 * s, 10.0 * s, 20.0 * s, 22.0 * s], 1.4 * s)

    # ── Cutouts (transparent holes) ──
    # door
    d.rounded_rectangle(
        [10.3 * s, 16.0 * s, 13.7 * s, 22.0 * s], radius=1.2 * s, fill=CLEAR
    )
    # windows
    d.rounded_rectangle(
        [6.2 * s, 12.5 * s, 9.2 * s, 15.0 * s], radius=0.6 * s, fill=CLEAR
    )
    d.rounded_rectangle(
        [14.8 * s, 12.5 * s, 17.8 * s, 15.0 * s], radius=0.6 * s, fill=CLEAR
    )
    return img


def main():
    # Master at 8x for smooth downscaling
    master = draw_logo(MASTER * SS)

    for density, px in SIZES.items():
        if px == MASTER:
            img = master.resize((MASTER, MASTER), Image.LANCZOS)
        else:
            img = master.resize((px, px), Image.LANCZOS)
        path = os.path.join(OUT, f"mipmap-{density}", "splash_logo.png")
        img.save(path)
        print(f"wrote {path} ({px}x{px})")


if __name__ == "__main__":
    main()
