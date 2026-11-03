#!/usr/bin/env python3
"""Build the small symbol fallback fonts the HUD uses (assets/fonts/UiSymbols-*.ttf).

The UI faces lack a few symbols (Chakra Petch: star, outline diamond, circles, warning, check;
Jersey10 also arrows, <= >= ~=, triangles, solid diamond). A full fallback font would bring its own
tall line metrics and push every label apart, so these are subsets with their vertical metrics
cut down below the UI faces' own (ascent 0.75 em, descent 0.2 em).
Needs fonttools (pip install fonttools). Run from the repo root. The Noto source (OFL, 1.2 MB) is
not kept in the repo; it is downloaded to /tmp when missing.
"""
import os
import urllib.request

from fontTools import subset
from fontTools.ttLib import TTFont

SETS = {
    "UiSymbols-Noto": ("/tmp/NotoSansSymbols2-Regular.ttf", "★☆◇◆○●⚠✓✗▲▼►◄■□"),
    "UiSymbols-Chakra": ("assets/fonts/ChakraPetch-SemiBold.ttf", "→←↑↓≈≤≥◆·×"),
}


NOTO_URL = "https://raw.githubusercontent.com/google/fonts/main/ofl/notosanssymbols2/NotoSansSymbols2-Regular.ttf"


def build(name: str, src: str, chars: str) -> None:
    if not os.path.exists(src) and "Noto" in src:
        urllib.request.urlretrieve(NOTO_URL, src)
    f = TTFont(src)
    cmap = f.getBestCmap()
    have = "".join(c for c in chars if ord(c) in cmap)
    opts = subset.Options()
    opts.layout_features = []
    opts.name_IDs = ["*"]
    opts.notdef_outline = False
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=[ord(c) for c in have])
    sub.subset(f)
    upm = f["head"].unitsPerEm
    asc, desc = round(upm * 0.75), round(upm * 0.2)
    f["hhea"].ascent, f["hhea"].descent, f["hhea"].lineGap = asc, -desc, 0
    os2 = f["OS/2"]
    os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = asc, -desc, 0
    os2.usWinAscent, os2.usWinDescent = asc, desc
    f.save("assets/fonts/%s.ttf" % name)
    print(name, "glyphs:", have)


for n, (src, chars) in SETS.items():
    build(n, src, chars)
