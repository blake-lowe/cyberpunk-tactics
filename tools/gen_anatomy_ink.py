#!/usr/bin/env python3
"""Builds assets/third_party/anatomy/anatomy_ink.png: Thomas Milton's standing écorché, front view
(Rees's Cyclopaedia, "Anatomy, Myology", Plate VIII, 1804; Wellcome Collection, Public Domain Mark)
as an ink map for the cyberware screens' default body style, "anatomy" (ChromeBody, BodyAnatomy).
Plate X of the same series (1803: the same man a layer deeper, the skeleton showing) is warped onto
him limb by limb for the deep layer that shows through where chrome is (or the selected place).

Source (see assets/third_party/anatomy/README.md): the Wellcome Collection's IIIF image server,
full size (no rate limit):

    curl --http1.1 -o /some/dir/V0008060FA.jpg \
      https://iiif.wellcomecollection.org/image/V0008060FA/full/full/0/default.jpg
    curl --http1.1 -o /some/dir/V0008060EB.jpg \
      https://iiif.wellcomecollection.org/image/V0008060EB/full/full/0/default.jpg
    python3 tools/gen_anatomy_ink.py /some/dir/V0008060FA.jpg /some/dir/V0008060EB.jpg

Needs numpy, scipy, scikit-image and Pillow (not the game's dependencies: a one-off art step).

Channels of the output (an RGBA PNG, OUT_H tall; import it without the alpha-border fix: every
channel is data):
  R  the muscle plate as light: its ink found as darkness against a local paper estimate (the
     paper's grain, foxing and a later owner's blue pencil drop out), kept by hysteresis, and
     printed in reverse inside the figure: the paper glows, the engraver's lines stay dark, so his
     hatching models the form at any size (the mip chain averages it to tone);
  G  the figure's silhouette (soft-edged): the region and chrome masks in the shader;
  B  the deep plate as light, the same way (bones and the deep muscles), warped onto the muscle
     plate's pose by a piecewise affine map through hand-placed landmark pairs (LANDMARKS below),
     inside the figure;
  A  the figure's outline, a thin line.
The crop is the figure with a margin; BodyAnatomy's geometry constants (the bones, anchors and
levels) are in the output's pixels.
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from skimage.filters import apply_hysteresis_threshold
from skimage.morphology import remove_small_objects
from skimage.transform import PiecewiseAffineTransform, warp

OUT = "assets/third_party/anatomy/anatomy_ink.png"
SRC_SIZE = (2370, 3078)            # Plate VIII, full size (w, h)
DEEP_SIZE = (2320, 3129)           # Plate X
CROP = (500, 236, 1792, 2820)      # in Plate VIII: the figure and a margin (x0, y0, x1, y1)
OUT_H = 2048
LO, HI = 0.16, 0.36                # hysteresis: weak ink kept where it touches strong ink
C0, C1 = 0.12, 0.62                # ink density -> value (smoothstep)
PRINT_GAIN = 1.15                  # how dark the lines print in the light

# Landmarks: (Plate VIII x, y) <- (Plate X x, y), full-size pixels, picked by hand on the two
# plates (the same man, a year apart: the deep plate stands a little wider, arms further out).
LANDMARKS = [
    # head: crown, eyes, ear, chin; the neck's base
    ((1162, 265), (1103, 295)), ((1109, 421), (1053, 451)), ((1206, 421), (1147, 451)),
    ((1270, 450), (1200, 480)), ((1153, 583), (1097, 612)), ((1176, 745), (1082, 774)),
    # shoulders, armpits, navel, hips, crotch
    ((897, 760), (818, 774)), ((1471, 745), (1362, 759)), ((970, 965), (906, 980)),
    ((1412, 965), (1274, 995)), ((1162, 1200), (1082, 1230)), ((926, 1406), (906, 1406)),
    ((1397, 1406), (1332, 1465)), ((1153, 1598), (1097, 1568)),
    # the figure's right arm (the viewer's left): elbow, wrist, thumb, fingertips
    ((794, 1245), (671, 1245)), ((712, 1583), (568, 1568)), ((565, 1695), (509, 1700)),
    ((662, 1818), (553, 1833)),
    # the figure's left arm
    ((1529, 1245), (1479, 1245)), ((1603, 1583), (1612, 1568)), ((1729, 1736), (1788, 1686)),
    ((1632, 1818), (1641, 1818)),
    # legs: knee, ankle, toes
    ((1029, 2112), (876, 2156)), ((1353, 2112), (1215, 2142)), ((1015, 2627), (774, 2700)),
    ((1382, 2627), (1200, 2686)), ((897, 2715), (612, 2833)), ((1544, 2730), (1318, 2818)),
    # the frame's corners and edges (pinned: the warp covers the whole crop)
    ((500, 236), (420, 266)), ((1792, 236), (1712, 266)), ((500, 2820), (300, 2900)),
    ((1792, 2820), (1600, 2900)), ((500, 1500), (380, 1520)), ((1792, 1500), (1800, 1500)),
]


# Pairs of landmarks (by index) along a limb or across a gap: their midpoints are landmarks too, so
# no warp triangle spans an arm and the trunk.
MIDS = [(6, 14), (14, 15), (7, 18), (18, 19), (8, 14), (9, 18), (11, 22), (22, 24), (12, 23), (23, 25),
        (13, 22), (13, 23), (14, 11), (18, 12), (24, 25), (15, 11), (19, 12)]


def mid_points(lm):
    out = list(lm)
    for i, j in MIDS:
        (a, b), (c, d) = lm[i], lm[j]
        out.append((((a[0] + c[0]) / 2, (a[1] + c[1]) / 2), ((b[0] + d[0]) / 2, (b[1] + d[1]) / 2)))
    return out


def load(src: str, size: tuple) -> np.ndarray:
    a = np.asarray(Image.open(src).convert("RGB")).astype(np.float32) / 255.0
    if (a.shape[1], a.shape[0]) != size:
        sys.exit("%s: expected %s, got %s" % (src, size, (a.shape[1], a.shape[0])))
    return a


def ink_of(a: np.ndarray) -> np.ndarray:
    """Ink density off the paper: 0 paper, 1 solid ink. The blue pencil (a later hand) and the
    foxing (brown) are dropped: the engraving's ink is neutral."""
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    lum = 0.3 * r + 0.59 * g + 0.11 * b
    blue = np.clip(b - (r + g) / 2.0, 0, 1)
    warm = ndi.gaussian_filter(r - b, 3)
    brown = np.clip(warm - ndi.median_filter(warm[::8, ::8], 31).repeat(8, 0).repeat(8, 1)[:a.shape[0], :a.shape[1]], 0, 1)
    lum = lum + blue * 2.5 + brown * 3.0   # pencil and foxing read as paper
    lum = ndi.median_filter(lum, 3)
    paper = ndi.gaussian_filter(ndi.grey_closing(lum, size=(25, 25)), 25)
    ink = np.clip((paper - lum) / np.maximum(paper, 0.2), 0, 1)
    return ndi.gaussian_filter(ink, 0.6)


def silhouette(ink: np.ndarray) -> np.ndarray:
    """The figure: dense ink, closed, holes filled, its biggest piece."""
    m = ndi.gaussian_filter(ink, 6) > 0.16
    m = ndi.binary_closing(m, iterations=6)
    m = ndi.binary_fill_holes(m)
    m = ndi.binary_opening(m, iterations=5)   # the foxing stuck to the thigh goes
    lab, n = ndi.label(m)
    sizes = ndi.sum(m, lab, range(1, n + 1))
    return lab == (1 + int(np.argmax(sizes)))


def strokes(ink: np.ndarray, keep: np.ndarray) -> np.ndarray:
    mask = apply_hysteresis_threshold(ink, LO, HI) & keep
    mask = remove_small_objects(mask, max_size=12)
    soft = ndi.gaussian_filter(ndi.binary_dilation(mask, iterations=1).astype(np.float32), 0.7)
    x = np.clip((ink - C0) / (C1 - C0), 0, 1)
    return np.clip(x * x * (3 - 2 * x) * soft, 0, 1)


def print_light(strokes_: np.ndarray, sil: np.ndarray) -> np.ndarray:
    """The print as light: the paper inside the figure glows, the engraver's lines stay dark, so his
    hatching models the form (highlights on the tendons and bones, the grooves in shadow)."""
    soft = ndi.gaussian_filter(sil.astype(np.float32), 1.5)
    return soft * np.clip(1.0 - strokes_ * PRINT_GAIN, 0, 1)


def outline(sil: np.ndarray) -> np.ndarray:
    """The figure's edge: a thin line."""
    m = ndi.gaussian_gradient_magnitude(sil.astype(np.float32), 1.6)
    return np.clip(m / max(m.max(), 1e-6) * 1.8, 0, 1)


def main(src: str, deep: str, out: str = OUT) -> None:
    a = load(src, SRC_SIZE)
    ink = ink_of(a)
    sil = silhouette(ink)
    keep = ndi.binary_dilation(sil, iterations=4)
    muscle = print_light(strokes(ink, keep), sil)
    edge = outline(sil)
    # the deep plate, warped onto this one's pose (output coords <- deep coords)
    d = load(deep, DEEP_SIZE)
    dink = ink_of(d)
    dsil = silhouette(dink)
    dmus = print_light(strokes(dink, ndi.binary_dilation(dsil, iterations=4)), dsil)
    pts = mid_points(LANDMARKS)
    dst = np.array([p for p, _ in pts], dtype=np.float64)
    srcp = np.array([q for _, q in pts], dtype=np.float64)
    t = PiecewiseAffineTransform.from_estimate(dst, srcp)   # Plate VIII points -> Plate X: warp's inverse map
    x0, y0, x1, y1 = CROP
    sub = (slice(y0, y1), slice(x0, x1))

    def crop_map(coords):
        return t(coords + np.array([x0, y0]))

    deep_c = warp(dmus, crop_map, output_shape=(y1 - y0, x1 - x0), order=1, mode="constant", cval=0.0)
    sil_c = ndi.gaussian_filter(sil[sub].astype(np.float32), 2.0)
    deep_c *= np.clip(ndi.gaussian_filter(sil[sub].astype(np.float32), 3.0) * 1.5, 0, 1)
    rgba = np.stack([muscle[sub], sil_c, deep_c, edge[sub]], axis=-1)
    h = y1 - y0
    w = x1 - x0
    ow = round(w * OUT_H / h)
    # each channel scaled on its own (Pillow would premultiply an RGBA image by its alpha)
    chans = [Image.fromarray((np.clip(rgba[..., i], 0, 1) * 255).astype(np.uint8), "L").resize((ow, OUT_H), Image.LANCZOS) for i in range(4)]
    img = Image.merge("RGBA", chans)
    img.save(out, optimize=True)
    print("wrote", out, img.size)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    main(*sys.argv[1:4])
