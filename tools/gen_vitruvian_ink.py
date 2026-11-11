#!/usr/bin/env python3
"""Builds assets/third_party/vitruvian/vitruvian_ink.png: Leonardo da Vinci's Vitruvian Man (c. 1490,
public domain) as an ink-only alpha map for the cyberware screens' "vitruvian" body style (ChromeBody).

Source: Wikimedia Commons, "Da Vinci Vitruve Luc Viatour.jpg" (Public domain: PD-Art / PD-old; see
assets/third_party/vitruvian/README.md). Fetch the 1920 px rendition (the original is rate-limited):

    curl -o /some/dir/vitruve_1920.jpg \
      https://upload.wikimedia.org/wikipedia/commons/thumb/2/22/Da_Vinci_Vitruve_Luc_Viatour.jpg/1920px-Da_Vinci_Vitruve_Luc_Viatour.jpg
    python3 tools/gen_vitruvian_ink.py /some/dir/vitruve_1920.jpg

Needs numpy, scipy, scikit-image and Pillow (not the game's dependencies: a one-off art step).

What it does: lifts the ink off the paper (darkness against a local paper estimate, so stains and
the paper's tone drop out), keeps strokes by hysteresis (strong ink and what it connects to; lone
paper specks go), maps the ink's density to alpha with a soft curve (so Leonardo's hatching and
wash keep their tone), erases the drawn circle and square (the game redraws them crisp) and
everything outside the circle (the mirror-writing), and crops to the circle. The output is
1640 px square; in it the circle is centred at (820, 820), radius 806, and the square spans
(160, 294)-(1516, 1624): VitruvianArt's geometry constants.
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage.filters import apply_hysteresis_threshold
from skimage.morphology import remove_small_objects

OUT = "assets/third_party/vitruvian/vitruvian_ink.png"
# In the 1920 x 2610 source: the circle and the square, and the crop round the circle.
CX, CY, R = 940.0, 1086.0, 806.0
SQ = (280.0, 560.0, 1636.0, 1890.0)
CROP = (120, 266, 1760, 1906)
LO, HI = 0.14, 0.34       # hysteresis: weak ink kept where it touches strong ink
C0, C1 = 0.10, 0.55       # ink density → alpha (smoothstep)


def main(src: str, out: str = OUT) -> None:
    a = np.asarray(Image.open(src).convert("RGB")).astype(np.float32) / 255.0
    if a.shape[:2] != (2610, 1920):
        sys.exit("expected the 1920 x 2610 rendition, got %s" % (a.shape[:2],))
    lum = 0.3 * a[..., 0] + 0.59 * a[..., 1] + 0.11 * a[..., 2]
    lum = ndi.median_filter(lum, 3)
    paper = ndi.gaussian_filter(ndi.grey_closing(lum, size=(17, 17)), 20)
    ink = np.clip((paper - lum) / np.maximum(paper, 0.2), 0, 1)
    ink = ndi.gaussian_filter(ink, 0.6)
    mask = apply_hysteresis_threshold(ink, LO, HI)
    mask = remove_small_objects(mask, max_size=90)
    soft = ndi.gaussian_filter(ndi.binary_dilation(mask, iterations=1).astype(np.float32), 0.8)
    x = np.clip((ink - C0) / (C1 - C0), 0, 1)
    alpha = np.clip(x * x * (3 - 2 * x) * soft, 0, 1)
    h, w = alpha.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    keep = np.hypot(xx - CX, yy - CY) < R - 9
    band = 7
    for v in (SQ[0], SQ[2]):
        keep &= ~((np.abs(xx - v) < band) & (yy > SQ[1] - band) & (yy < SQ[3] + band))
    for v in (SQ[1], SQ[3]):
        keep &= ~((np.abs(yy - v) < band) & (xx > SQ[0] - band) & (xx < SQ[2] + band))
    keep &= yy < SQ[3] - 3
    alpha *= ndi.gaussian_filter(keep.astype(np.float32), 1.0)
    crop = alpha[CROP[1]:CROP[3], CROP[0]:CROP[2]]
    Image.fromarray((crop * 255).astype(np.uint8), "L").save(out, optimize=True)
    print("wrote", out, crop.shape)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(*sys.argv[1:3])
