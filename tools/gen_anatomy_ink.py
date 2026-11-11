#!/usr/bin/env python3
"""Builds the cyberware screens' figure plates (ChromeBody, BodyAnatomy), one per body:

male: assets/third_party/anatomy/anatomy_ink.png: Thomas Milton's standing écorché, front view
(Rees's Cyclopaedia, "Anatomy, Myology", Plate VIII, 1804; Wellcome Collection, Public Domain Mark).
Plate X of the same series (1803: the same man a layer deeper, the skeleton showing) is warped onto
him limb by limb for the deep layer. The screens always show the two as a hybrid (owner: "baseline
both the male and female skeleton engraving hybrid images"): the deep plate's bones everywhere, the
surface plate a faint body over them (body_anatomy.gdshader, `skin`).

Source (see assets/third_party/anatomy/README.md): the Wellcome Collection's IIIF image server,
full size (no rate limit):

    curl --http1.1 -o /some/dir/V0008060FA.jpg \
      https://iiif.wellcomecollection.org/image/V0008060FA/full/full/0/default.jpg
    curl --http1.1 -o /some/dir/V0008060EB.jpg \
      https://iiif.wellcomecollection.org/image/V0008060EB/full/full/0/default.jpg
    python3 tools/gen_anatomy_ink.py /some/dir/V0008060FA.jpg /some/dir/V0008060EB.jpg

female: assets/third_party/anatomy_female/anatomy_female_ink.png: Andrew Bell's superficial anatomy
of the woman, front view, her raised left arm lowered (bent at the elbow and wrist: pose_arm), with his
skeleton of a woman (mirrored) laid onto her (Encyclopaedia Britannica 3rd ed., 1797-98; Wellcome,
Public Domain Mark; assets/third_party/anatomy_female/README.md; main_female below):

    curl --http1.1 -o /some/dir/V0008101ER.jpg \
      https://iiif.wellcomecollection.org/image/V0008101ER/full/full/0/default.jpg
    curl --http1.1 -o /some/dir/V0008127.jpg \
      https://iiif.wellcomecollection.org/image/V0008127/full/full/0/default.jpg
    python3 tools/gen_anatomy_ink.py female /some/dir/V0008101ER.jpg /some/dir/V0008127.jpg

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




# --- The female plates (Andrew Bell, Encyclopaedia Britannica 3rd ed., 1797-98) -----------------
# Bell's *Superficial anatomy of the woman: anterior view* (after Bidloo; Wellcome V0008101ER) is the
# figure; his *Skeleton of a woman: anterior view* (after Sue and Thiroux d'Arconville; Wellcome
# V0008127), mirrored left to right so its raised arm is her raised arm, is warped onto her for the
# deep layer (the trunk, head and legs through landmarks, the arms bone by bone). Both are engraved by
# the same hand for the same edition: they print as a set. Her left arm, held out with the drape in the
# plate, is then lowered on every layer at once (pose_arm: bent at the elbow and the wrist, a little
# at the shoulder), so she stands with her arms at her sides as Milton's man does.

F_OUT = "assets/third_party/anatomy_female/anatomy_female_ink.png"
F_SIZE = (1181, 1618)
F_DEEP_SIZE = (2050, 3407)
F_CROP = (196, 52, 854, 1580)       # in her plate: the figure and a margin, centred on her (x0, y0, x1, y1)
F_LO, F_HI = 0.08, 0.20             # her plate is stippled and lighter than Milton's: more of it kept
F_C0, F_C1 = 0.04, 0.32
F_GAIN = 1.5                        # how dark her lines print in the light
F_TONE, F_TONE_REF = 0.6, 0.3       # her stipple's local density darkens the light (her shading), so she
                                    # prints as much light as Milton's man (a mean of ~0.33 inside)

# Her body (hand-traced, her plate's pixels): she holds a drape that falls behind her from both hands
# and lies on the ground past her feet. Where she meets paper the trace runs wide and the ink finds her
# edge; where she meets the drape it follows her contour.
F_KEEP = [
    (470, 68), (545, 66), (582, 88), (600, 112), (622, 160), (620, 215), (598, 252),
    (640, 280), (700, 330), (770, 400), (850, 450), (930, 470), (985, 505), (1022, 545),
    (1010, 600), (990, 605), (965, 598), (945, 592), (925, 610), (905, 595), (895, 555),
    (860, 548), (790, 540), (720, 540), (690, 580), (690, 640),
    (697, 700), (700, 730), (700, 780), (694, 840), (684, 900), (670, 960), (652, 1020), (636, 1080),
    (627, 1130), (620, 1200), (617, 1260), (615, 1320), (612, 1380), (610, 1410),
    (622, 1440), (650, 1465), (672, 1490), (676, 1515), (660, 1533), (620, 1533), (590, 1522), (572, 1500),
    (564, 1470), (566, 1430), (568, 1380), (565, 1300), (560, 1220), (553, 1175),
    (547, 1250), (552, 1330), (556, 1400), (557, 1440), (556, 1470), (548, 1500), (540, 1535), (520, 1550),
    (480, 1552), (458, 1540), (452, 1510), (462, 1485), (485, 1460), (497, 1435), (500, 1400),
    (486, 1335), (470, 1250), (460, 1170), (448, 1083), (428, 1020), (412, 960), (403, 900), (398, 860), (395, 840),
    (360, 862), (340, 885), (300, 885), (278, 860), (275, 820), (290, 800),
    (305, 780), (322, 740), (338, 700), (352, 660), (360, 620), (358, 560), (358, 480), (360, 400), (368, 340),
    (395, 300), (420, 265), (415, 200), (405, 150), (420, 110), (440, 95),
]
# From here down (her shins and feet) the trace is her edge on every side: it is the silhouette.
F_TRACED_BELOW = 1060
# The plate's reference letters on her (x0, y0, x1, y1): painted out with the paper round them.
F_LETTERS = [(452, 414, 472, 436), (570, 398, 590, 421)]

# Landmarks: (her plate x, y) <- (the skeleton plate, mirrored, x, y); full-size pixels, by hand.
F_LANDMARKS = [
    # head: crown (under the hair), eyes, chin; the neck's base
    ((505, 95), (995, 165)), ((517, 172), (945, 265)), ((565, 185), (1045, 265)), ((530, 250), (995, 455)),
    ((515, 300), (964, 623)),
    # shoulders, the ribs' lower edge, navel, iliac crests, hip joints, pubis
    ((410, 350), (736, 659)), ((635, 335), (1209, 650)), ((405, 560), (773, 1077)), ((650, 560), (1164, 1077)),
    ((528, 630), (964, 1230)), ((400, 680), (709, 1314)), ((655, 680), (1236, 1290)),
    ((440, 790), (755, 1623)), ((620, 790), (1218, 1623)), ((527, 800), (973, 1641)),
    # her right arm (the viewer's left: the hand at her hip): elbow, wrist, fingers
    ((400, 610), (589, 1178)), ((335, 795), (433, 1611)), ((290, 860), (460, 1933)),
    # her left arm, held out: elbow, wrist, fingers
    ((745, 470), (1467, 1111)), ((912, 500), (1744, 1444)), ((980, 560), (1811, 1733)),
    # legs: knee, ankle, toes
    ((493, 1100), (782, 2278)), ((572, 1112), (1156, 2267)), ((527, 1421), (811, 2933)),
    ((602, 1429), (1133, 2944)), ((493, 1542), (711, 3189)), ((635, 1521), (1233, 3200)),
    # the crop's corners and edges (pinned, at the figures' scale)
    ((226, 52), (396, 75)), ((1048, 52), (1977, 75)), ((226, 1580), (396, 3259)), ((1048, 1580), (1977, 3259)),
    ((226, 800), (396, 1634)), ((1048, 800), (1977, 1634)),
]
# Pairs (by index) whose midpoints pin a limb's line or the gap beside it.
F_MIDS = [(5, 15), (15, 16), (16, 17), (6, 18), (18, 19), (19, 20), (12, 21), (21, 23), (13, 22), (22, 24),
          (14, 21), (14, 22), (21, 22), (23, 24), (7, 15), (10, 16), (8, 18)]


def mid_points_of(lm, mids):
    out = list(lm)
    for i, j in mids:
        (a, b), (c, d) = lm[i], lm[j]
        out.append((((a[0] + c[0]) / 2, (a[1] + c[1]) / 2), ((b[0] + d[0]) / 2, (b[1] + d[1]) / 2)))
    return out


def polygon_mask(pts, shape) -> np.ndarray:
    from PIL import ImageDraw
    im = Image.new("L", (shape[1], shape[0]), 0)
    ImageDraw.Draw(im).polygon([tuple(p) for p in pts], fill=255)
    return np.asarray(im) > 0


def paint_out(a: np.ndarray, boxes) -> np.ndarray:
    """Letters gone: each box takes the paper's colour round it (a ring's median)."""
    a = a.copy()
    for x0, y0, x1, y1 in boxes:
        ring = np.concatenate([a[y0 - 4:y0, x0:x1].reshape(-1, 3), a[y1:y1 + 4, x0:x1].reshape(-1, 3),
                               a[y0:y1, x0 - 4:x0].reshape(-1, 3), a[y0:y1, x1:x1 + 4].reshape(-1, 3)])
        a[y0:y1, x0:x1] = np.median(ring, axis=0)
    return a


def strokes_with(ink, keep, lo, hi, c0, c1) -> np.ndarray:
    mask = apply_hysteresis_threshold(ink, lo, hi) & keep
    mask = remove_small_objects(mask, max_size=6)
    soft = ndi.gaussian_filter(ndi.binary_dilation(mask, iterations=1).astype(np.float32), 0.7)
    x = np.clip((ink - c0) / (c1 - c0), 0, 1)
    return np.clip(x * x * (3 - 2 * x) * soft, 0, 1)


BARE_HOLE = 0.035                   # a hole in the bones' mask this lightly inked is paper (left dark)


def bones_of(ink: np.ndarray) -> np.ndarray:
    """A bare skeleton's bones: dense ink closed and filled, every large piece (the hands' small bones
    too); the plate's letters, standing alone on the paper, are too small to stay. A hole is filled
    only where it is engraved (a bone's modelled face, the shadow behind the ribs): a bare one is
    paper showing between bones (the pelvis's foramina, between the forearm's two bones), which would
    print as a blank patch of light now that the skeleton shows everywhere."""
    m = ndi.gaussian_filter(ink, 4.0) > 0.2   # (the paper's grain stays under it)
    m = ndi.binary_closing(m, iterations=3)
    holes = ndi.binary_fill_holes(m) & ~m   # only the small ones (not the space between the legs)
    lab, n = ndi.label(holes)
    sizes = ndi.sum(holes, lab, range(1, n + 1))
    inked = ndi.mean(ink, lab, range(1, n + 1))
    m |= np.isin(lab, 1 + np.nonzero((sizes < 6000) & (inked > BARE_HOLE))[0])
    m = ndi.binary_opening(m, iterations=2)
    return remove_small_objects(m, max_size=4000)


# The arms, joint by joint: shoulder, elbow, wrist, the hand's end (full-size pixels). Her right arm
# hangs at her side, the hand at her hip in the drape; her left is held out, the hand holding the drape
# up. The skeleton's (mirrored) are both nearly straight, the hands open.
F_ARMS = {
    "right": [(392, 360), (382, 597), (336, 798), (288, 866)],
    "left": [(636, 334), (755, 468), (905, 494), (985, 566)],
}
F_DEEP_ARMS = {
    "right": [(736, 659), (589, 1178), (433, 1611), (460, 1933)],
    "left": [(1209, 650), (1467, 1111), (1744, 1444), (1811, 1733)],
}
F_DEEP_SCALE = 0.478                # the skeleton plate's pixels to hers (crown to pubis)
F_DEEP_ARM_R = 70.0                 # an arm's reach round its bones, the skeleton plate's pixels
F_DEEP_TRUNK = [((995, 165), (973, 1641), 250.0), ((709, 1314), (1236, 1290), 120.0),
                ((755, 1623), (811, 2933), 90.0), ((1218, 1623), (1133, 2944), 90.0)]
# The owner (on the first cut): "change the lifted hand and arm pose to be lower (bend at wrist and
# elbow joint)". Her left forearm turns down about the elbow and the hand about the wrist, the upper
# arm a little in toward her about the shoulder (degrees, y down: positive turns an arm pointing to the
# viewer's right downward), so the arm hangs by her side, the elbow a touch bent, the hand down.
F_ARM_TURNS = (10.0, 51.0, -14.0)  # shoulder, elbow, wrist
F_ARM_R = 34.0                      # her arm's reach round its bones (her plate's pixels)
F_TRUNK = [((505, 95), (527, 800), 150.0), ((440, 790), (527, 1421), 95.0), ((620, 790), (602, 1429), 95.0),
           ((410, 350), (636, 334), 40.0)]   # (the head and trunk, the legs, the shoulders' line)


def seg_dist(px: np.ndarray, py: np.ndarray, a, b) -> np.ndarray:
    """Distance from each point to the segment a-b."""
    ax, ay = a
    dx, dy = b[0] - ax, b[1] - ay
    t = np.clip(((px - ax) * dx + (py - ay) * dy) / max(dx * dx + dy * dy, 1e-9), 0.0, 1.0)
    return np.hypot(px - ax - t * dx, py - ay - t * dy)


def limb_owners(shape, chain, trunk, reach, tau=0.12):
    """Soft ownership of every pixel of a plate: [the rest of the body, upper arm, forearm, hand], each a
    softmin over distances to the bones as a fraction of their reach (a wide trunk, a thin limb), so a
    limb's pixels are cut out cleanly with a soft seam at each joint."""
    yy, xx = np.mgrid[0:shape[0], 0:shape[1]].astype(np.float32)
    rest = np.full(shape, np.inf, np.float32)
    for a, b, r in trunk:
        rest = np.minimum(rest, seg_dist(xx, yy, a, b) / r)
    ds = [rest] + [seg_dist(xx, yy, chain[k], chain[k + 1]) / reach for k in range(3)]
    m = np.minimum.reduce(ds)
    ws = [np.exp(-(d - m) / tau) for d in ds]
    s = sum(ws)
    return [w / s for w in ws]


def bone_frame(a, b, p_x, p_y, along: float, across: float, a2, b2):
    """Points in the frame of the segment a2-b2 mapped into the segment a-b's: along the bone scaled by
    `along`, across it by `across` (the output's inverse map for one limb segment)."""
    e2 = np.array(b2, float) - a2
    e2 /= np.hypot(*e2)
    n2 = np.array([-e2[1], e2[0]])
    e = np.array(b, float) - a
    e /= np.hypot(*e)
    n = np.array([-e[1], e[0]])
    u = (p_x - a2[0]) * e2[0] + (p_y - a2[1]) * e2[1]
    v = (p_x - a2[0]) * n2[0] + (p_y - a2[1]) * n2[1]
    return a[0] + u * along * e[0] + v * across * n[0], a[1] + u * along * e[1] + v * across * n[1]


def sample(img: np.ndarray, sx: np.ndarray, sy: np.ndarray) -> np.ndarray:
    return ndi.map_coordinates(img, [sy, sx], order=1, mode="constant", cval=0.0)


def smooth01(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3 - 2 * x)


def bend_map(px: np.ndarray, py: np.ndarray, chain, turns):
    """The inverse map of an arm posed anew (the posed image's points -> the plate's): the upper arm
    turned about the shoulder, the forearm about the elbow, the hand about the wrist (`turns`, degrees,
    y down). Each turn is a rotation about its joint by an angle that depends on the direction (and,
    at the shoulder, the distance) from the joint: the whole turn over the limb beyond the joint, none
    over the limb before it, eased round both sides between. A rotation about a point keeps every
    point's distance to it, and the angle eases slower than the direction changes, so the map is one
    to one: the engraving is turned, never stretched along the limb, and each joint bends smoothly with
    no seam. (The body round the arm is kept apart by its ownership mask: pose_arm.)"""
    sh, el, wr, tip = [np.array(p, float) for p in chain]
    t_sh, t_el, t_wr = [np.radians(t) for t in turns]

    def turn(x, y, c, ang):
        ca, sa = np.cos(ang), np.sin(ang)
        dx, dy = x - c[0], y - c[1]
        return c[0] + dx * ca - dy * sa, c[1] + dx * sa + dy * ca

    def wrap(d):
        return (d + 180.0) % 360.0 - 180.0

    def angle(v):
        return float(np.degrees(np.arctan2(v[1], v[0])))

    def eased(d, lo, hi, back):
        """1 over [lo, hi] (degrees from the posed limb), 0 within 30 degrees of the limb before the
        joint (at `back`), eased round both sides."""
        far = back - 360.0 if back > 0 else back
        near = back + 360.0 if back < 0 else back
        return np.where(d < lo, smooth01((d - (far + 30.0)) / (lo - far - 30.0)),
                        np.where(d > hi, smooth01(((near - 30.0) - d) / (near - 30.0 - hi)), 1.0))

    # the posed joints
    el1 = np.array(turn(el[0], el[1], sh, t_sh))
    wr1 = np.array(turn(wr[0], wr[1], sh, t_sh))
    tip1 = np.array(turn(tip[0], tip[1], sh, t_sh))
    wr2 = np.array(turn(wr1[0], wr1[1], el1, t_el))
    tip2 = np.array(turn(tip1[0], tip1[1], el1, t_el))
    upper = angle(el1 - sh)
    fore = angle(wr2 - el1)
    hand = angle(tip2 - wr2) + turns[2]
    # 1: undo the hand's turn about the posed wrist
    d = wrap(np.degrees(np.arctan2(py - wr2[1], px - wr2[0])) - hand)
    k = eased(d, -40.0, 40.0, wrap(fore + 180.0 - hand))
    qx, qy = turn(px, py, wr2, -t_wr * k)
    # 2: undo the forearm's turn about the posed elbow
    d = wrap(np.degrees(np.arctan2(qy - el1[1], qx - el1[0])) - fore)
    k = eased(d, -25.0, 22.0, wrap(upper + 180.0 - fore))
    qx, qy = turn(qx, qy, el1, -t_el * k)
    # 3: undo the upper arm's turn about the shoulder, fading in from the joint (the shoulder's cap
    # barely moves, so the arm meets the trunk where it did)
    r = np.hypot(qx - sh[0], qy - sh[1])
    k = smooth01(r / 90.0)
    return turn(qx, qy, sh, -t_sh * k)


def pose_arm(layers, x0: int, y0: int, chain, turns, trunk, reach):
    """Layers (crops of a plate at x0, y0) with an arm posed anew: the arm (by soft ownership:
    limb_owners) lifted off the body, turned (bend_map) and laid back over the body without it. The arm
    is clear of the body beyond the shoulder, so nothing of the body moves."""
    h, w = layers[0].shape
    own = limb_owners((h, w), [(x - x0, y - y0) for x, y in chain], [((a[0] - x0, a[1] - y0), (b[0] - x0, b[1] - y0), r) for a, b, r in trunk], reach)
    arm = own[1] + own[2] + own[3]
    yy, xx = np.mgrid[y0:y0 + h, x0:x0 + w].astype(np.float64)
    bx, by = bend_map(xx, yy, chain, turns)
    bx -= x0
    by -= y0
    return [lay * (1.0 - arm) + sample(lay * arm, bx, by) for lay in layers]


def main_female(src: str, deep: str, out: str = F_OUT, pose: bool = True) -> None:
    a = paint_out(load(src, F_SIZE), F_LETTERS)
    ink = ink_of(a)
    keep_poly = polygon_mask(F_KEEP, ink.shape)
    m = ndi.gaussian_filter(ink, 4) > 0.12
    m = ndi.binary_closing(m, iterations=4) & keep_poly
    m[F_TRACED_BELOW:] |= keep_poly[F_TRACED_BELOW:]   # below her knees the trace is her edge all round
    m = ndi.binary_fill_holes(m)
    m = ndi.binary_opening(m, iterations=3)
    lab, n = ndi.label(m)
    sizes = ndi.sum(m, lab, range(1, n + 1))
    sil = lab == (1 + int(np.argmax(sizes)))
    keep = ndi.binary_dilation(sil, iterations=3) & keep_poly
    st = strokes_with(ink, keep, F_LO, F_HI, F_C0, F_C1)
    tone = np.clip(ndi.gaussian_filter(ink, 2.5) / F_TONE_REF, 0, 1)
    body = ndi.gaussian_filter(sil.astype(np.float32), 1.5) * np.clip(1.0 - st * F_GAIN, 0, 1) * (1.0 - F_TONE * tone)
    # the skeleton, mirrored, its bones printed as light
    d = load(deep, F_DEEP_SIZE)[:, ::-1]
    dink = ink_of(d)
    bones = bones_of(dink)
    dprint = print_light(strokes_with(dink, ndi.binary_dilation(bones, iterations=2), LO, HI, C0, C1), bones).astype(np.float32)
    x0, y0, x1, y1 = F_CROP
    wx1 = max(x1, F_SIZE[0])   # worked on to the plate's right edge (her left hand, held out), cropped last
    yy, xx = np.mgrid[y0:y1, x0:wx1].astype(np.float64)   # her plate's pixels over the work
    # its trunk, head and legs warped onto her through the landmarks (the arms cut out of it)...
    pts = mid_points_of(F_LANDMARKS, F_MIDS)
    t = PiecewiseAffineTransform.from_estimate(np.array([p for p, _ in pts], float), np.array([q for _, q in pts], float))
    sxy = t(np.stack([xx.ravel(), yy.ravel()], axis=1))
    sx, sy = sxy[:, 0].reshape(xx.shape), sxy[:, 1].reshape(xx.shape)
    rest = np.ones_like(dprint)
    arms = []
    for side in ("right", "left"):
        own = limb_owners(dprint.shape, F_DEEP_ARMS[side], F_DEEP_TRUNK, F_DEEP_ARM_R)
        rest *= own[0]
        arms.append(own[1:])
    deep_c = sample(dprint * rest, sx, sy)
    # ...and its arms laid along hers bone by bone (each bone's length to hers, its width to scale: a
    # piecewise-affine warp through a few landmarks folded them where her arms bend more than its)
    for side, own in zip(("right", "left"), arms):
        src_c, dst_c = F_DEEP_ARMS[side], F_ARMS[side]
        for k in range(3):
            ls = np.hypot(src_c[k + 1][0] - src_c[k][0], src_c[k + 1][1] - src_c[k][1])
            ld = np.hypot(dst_c[k + 1][0] - dst_c[k][0], dst_c[k + 1][1] - dst_c[k][1])
            along = ls / ld if k < 2 else 1.5 / F_DEEP_SCALE   # a hand shortened by half again (hers close round the drape)
            bx, by = bone_frame(src_c[k], src_c[k + 1], xx, yy, along, 1.0 / F_DEEP_SCALE, dst_c[k], dst_c[k + 1])
            deep_c += sample(dprint * own[k], bx, by)
    body_c = body[y0:y1, x0:wx1]
    silf = sil[y0:y1, x0:wx1].astype(np.float32)
    if pose:   # her left arm lowered: every layer turned the same way
        body_c, silf, deep_c = pose_arm([body_c, silf, deep_c], x0, y0, F_ARMS["left"], F_ARM_TURNS, F_TRUNK, F_ARM_R)
    body_c, silf, deep_c = [lay[:, :x1 - x0] for lay in (body_c, silf, deep_c)]
    silb = silf > 0.5
    edge = outline(silb)
    sil_c = ndi.gaussian_filter(silb.astype(np.float32), 1.5)
    deep_c *= np.clip(ndi.gaussian_filter(silb.astype(np.float32), 2.0) * 1.5, 0, 1)
    rgba = np.stack([body_c, sil_c, deep_c, edge], axis=-1)
    h = y1 - y0
    w = x1 - x0
    ow = round(w * OUT_H / h)
    chans = [Image.fromarray((np.clip(rgba[..., i], 0, 1) * 255).astype(np.uint8), "L").resize((ow, OUT_H), Image.LANCZOS) for i in range(4)]
    img = Image.merge("RGBA", chans)
    img.save(out, optimize=True)
    print("wrote", out, img.size)


if __name__ == "__main__":
    if len(sys.argv) >= 4 and sys.argv[1] == "female":
        main_female(*sys.argv[2:5])
    elif len(sys.argv) >= 3:
        main(*sys.argv[1:4])
    else:
        sys.exit(__doc__)
