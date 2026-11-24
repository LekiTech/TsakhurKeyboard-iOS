#!/usr/bin/env python3
"""Install the app icon from the approved artwork.

Reads the artwork as delivered, kept unmodified in docs/branding/:

    TsakhurKeyboard_AppIcon_1024.png    if present (the original file), otherwise
    TsakhurKeyboard_AppIcon_1024.webp   the copy the artwork arrived as

and writes into Assets.xcassets:

    AppIcon.appiconset/AppIcon-1024.png   the same pixels: 1024 × 1024, opaque RGB, square
    AppLogo.imageset/AppLogo.png          512 × 512, the logo on the app's screen

Needs Pillow:

    python3 scripts/make_icon.py

The artwork is not changed: no pixel is repainted, cropped or scaled for the
icon (a WebP source is only re-encoded as PNG, which is lossless). The
script checks what iOS requires of an app icon and stops if a check fails:
exactly 1024 × 1024, no transparency, and a full-bleed square. Full bleed
here means that each corner carries the colour of the field 24 px inside it
(no pre-rounded corners) and that the outer 8 px hold no near-black pixel
and no near-white one, except where the white field of the flag runs across
the whole icon and so reaches its left and right edges (no margin, outline
or shadow). The white field is the one run of rows that are white for
24 px at both ends, with 4 px above and below for its uneven edge.
"""
import os
import sys

from PIL import Image

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRANDING = os.path.join(REPO, "docs", "branding")
SOURCES = ["TsakhurKeyboard_AppIcon_1024.png", "TsakhurKeyboard_AppIcon_1024.webp"]
ASSETS = os.path.join(REPO, "TsakhurKeyboard", "TsakhurKeyboard", "Assets.xcassets")
SIZE = 1024
BORDER = 8        # px from each edge that are checked
REFERENCE = 24    # px inward from a corner where the field colour is sampled
TOLERANCE = 30    # summed RGB difference that counts as another colour
BAND_END = 24     # px at both ends of a row that must be white for it to be a row of the white field
BAND_MIN = 100    # rows the white field must have
EDGE = 4          # px above and below the field that count as its edge

def distance(a, b):
    return sum(abs(x - y) for x, y in zip(a, b))


def near_white(c):
    return min(c) > 200


def main():
    path = next((p for p in (os.path.join(BRANDING, n) for n in SOURCES) if os.path.exists(p)), None)
    if path is None:
        sys.exit("error: no artwork in docs/branding/ (expected " + " or ".join(SOURCES) + ")")
    source = Image.open(path)
    if source.size != (SIZE, SIZE):
        sys.exit(f"error: the source is {source.size}, expected {SIZE} × {SIZE}")
    if "A" in source.getbands() and source.getchannel("A").getextrema()[0] < 255:
        sys.exit("error: the source has transparent pixels; an app icon must be opaque")
    img = source.convert("RGB")
    px = img.load()

    last = SIZE - 1
    for (x, y), (ix, iy) in {(0, 0): (REFERENCE, REFERENCE), (last, 0): (last - REFERENCE, REFERENCE),
                             (0, last): (REFERENCE, last - REFERENCE),
                             (last, last): (last - REFERENCE, last - REFERENCE)}.items():
        if distance(px[x, y], px[ix, iy]) > TOLERANCE:
            sys.exit(f"error: the corner at ({x}, {y}) is not the colour of its field "
                     "(pre-rounded corners?); the artwork must be a full-bleed square")
    white_rows = sorted(y for y in range(SIZE)
                        if all(near_white(px[x, y]) and near_white(px[last - x, y]) for x in range(BAND_END)))
    if len(white_rows) < BAND_MIN or white_rows[-1] - white_rows[0] + 1 != len(white_rows):
        sys.exit("error: the white field of the flag is not one band across the icon")
    # The edge of the field is not perfectly level in the artwork: the rows
    # within EDGE px of it belong to it.
    band_rows = set(range(white_rows[0] - EDGE, white_rows[-1] + EDGE + 1))
    margin = 0
    for y in range(SIZE):
        for x in range(SIZE):
            if min(x, y, last - x, last - y) < BORDER:
                c = px[x, y]
                if max(c) < 60:
                    margin += 1
                elif near_white(c):
                    margin += not (min(x, last - x) < BORDER and y in band_rows and BORDER <= y <= last - BORDER)
    if margin:
        sys.exit(f"error: {margin} near-white or near-black pixels in the outer {BORDER} px that are not part of "
                 "the white field (a margin, an outline or a shadow?); the artwork must be full bleed")

    img.save(os.path.join(ASSETS, "AppIcon.appiconset", "AppIcon-1024.png"), "PNG", optimize=True)
    img.resize((512, 512), Image.LANCZOS).save(os.path.join(ASSETS, "AppLogo.imageset", "AppLogo.png"),
                                               "PNG", optimize=True)
    corners = " ".join("#%02X%02X%02X" % px[x, y] for x, y in ((0, 0), (last, 0), (0, last), (last, last)))
    print(f"icon installed from {os.path.basename(path)}: {SIZE} × {SIZE} RGB PNG, no alpha, full bleed, "
          f"corner colours {corners}, white field in rows {white_rows[0]}–{white_rows[-1]}")


if __name__ == "__main__":
    main()
