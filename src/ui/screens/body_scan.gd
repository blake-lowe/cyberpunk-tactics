class_name BodyScan
extends BodyArt
## The "scan" cyberware figure: a front-view medical scan plate (after Deus Ex: Human Revolution's
## augmentation screen and radiography). Soft tissue from BodyShape's distance field in a shader
## (body_scan.gdshader: an X-ray edge, density contours, scan slices); over it, drawn as vectors, the
## skeleton (skull, spine, ribs, pelvis, limb bones, hands and feet) and the organs as abstract
## shapes; round it the plate: a fine grid, a height scale, registration marks, a calibration strip
## and the R / L side markers (the patient's right on the viewer's left). Chrome replaces what it
## replaces: a cyberlimb's bones become struts and joints, a cybereye a lens, the Neural Link a
## trace down the spine; its tissue takes a violet armour lattice. The selected location is gold.

const SHADER := preload("res://src/ui/screens/body_scan.gdshader")
const BONE := Color(0.80, 0.96, 1.0)
const RG := ChromeBody.Reg
const MARGIN := 0.04   ## body units of halo round the frame

var _tissue: ColorRect
var _mat: ShaderMaterial
var _bones: Bones


func aspect() -> float:
	return BodyShape.ASPECT


func anchor_uv(loc: String) -> Vector2:
	var v: Vector2 = BodyShape.ANCHORS.get(loc, Vector2(0, 0.5))
	return Vector2(0.5 + v.x / BodyShape.ASPECT, v.y)


func _ready() -> void:
	_build()


func _build() -> void:
	if _tissue:
		return
	_tissue = ColorRect.new()
	_tissue.name = "Tissue"
	_tissue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	var pk := BodyShape.packed()
	_mat.set_shader_parameter("pa", pk[0])
	_mat.set_shader_parameter("pb", pk[1])
	_mat.set_shader_parameter("nparts", (pk[0] as PackedVector4Array).size())
	_mat.set_shader_parameter("tints", tint_array())
	_mat.set_shader_parameter("plated", plated_array())
	_mat.set_shader_parameter("meat", MEAT)
	_mat.set_shader_parameter("shell", shell)
	_mat.set_shader_parameter("motion", 1.0 if motion else 0.0)
	_mat.set_shader_parameter("band_y", -1.0)
	var sel := -1
	for r in tints.size():
		if region_selected(r):
			sel = r
			break
	_mat.set_shader_parameter("selected", sel)
	_tissue.material = _mat
	add_child(_tissue)
	_bones = Bones.new()
	_bones.art = self
	_bones.name = "Bones"
	_bones.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bones)


func _placed() -> void:
	_build()
	var h := fig.size.y
	var m := MARGIN * h
	var r := fig.grow(m)
	_tissue.position = r.position
	_tissue.size = r.size
	_mat.set_shader_parameter("map", Vector4(-BodyShape.ASPECT * 0.5 - MARGIN, -MARGIN, r.size.x / h, r.size.y / h))
	_mat.set_shader_parameter("px", 1.0 / maxf(h, 1.0))
	_bones.position = Vector2.ZERO
	_bones.size = size


## Body units → this control.
func P(v: Vector2) -> Vector2:
	return Vector2(fig.get_center().x, fig.position.y) + v * fig.size.y


# --- The plate --------------------------------------------------------------------------------

func _draw() -> void:
	if fig.size.y <= 0:
		return
	var h := fig.size.y
	var font := Hud.F_MONO if Hud.F_MONO else get_theme_default_font()
	var plate := Rect2(Vector2(stage.position.x + 4, fig.position.y - 2), Vector2(stage.size.x - 8, h + 4))
	# the fine grid (a fortieth of the height), heavier each head (an eighth)
	var step := h / 40.0
	var i := 0
	var y := fig.position.y
	while y <= fig.end.y + 0.5:
		var major := i % 5 == 0
		draw_line(Vector2(plate.position.x, y), Vector2(plate.end.x, y), Color(MEAT, 0.075 if major else 0.03), 1.0)
		y += step
		i += 1
	var cx := fig.get_center().x
	var k := 0
	while cx + k * step <= plate.end.x:
		for sx in ([1, -1] if k > 0 else [1]):
			var x: float = cx + sx * k * step
			if x >= plate.position.x:
				draw_line(Vector2(x, plate.position.y), Vector2(x, plate.end.y), Color(MEAT, 0.075 if k % 5 == 0 else 0.03), 1.0)
		k += 1
	# registration marks at the plate's corners
	for cn in [plate.position, Vector2(plate.end.x, plate.position.y), plate.end, Vector2(plate.position.x, plate.end.y)]:
		var o: Vector2 = cn
		draw_arc(o, 5.0, 0, TAU, 20, Color(MEAT, 0.5), 1.0, true)
		draw_line(o - Vector2(9, 0), o + Vector2(9, 0), Color(MEAT, 0.5), 1.0)
		draw_line(o - Vector2(0, 9), o + Vector2(0, 9), Color(MEAT, 0.5), 1.0)
	# the height scale up the left: 180 at the crown, ticks every 2, numbers every 20
	var sx0 := plate.position.x + 12.0
	draw_line(Vector2(sx0, fig.position.y), Vector2(sx0, fig.end.y), Color(MEAT, 0.4), 1.0)
	for cm in range(0, 181, 2):
		var ty := fig.end.y - cm / 180.0 * h
		var tl := 8.0 if cm % 20 == 0 else (5.0 if cm % 10 == 0 else 2.5)
		draw_line(Vector2(sx0, ty), Vector2(sx0 + tl, ty), Color(MEAT, 0.55 if cm % 10 == 0 else 0.3), 1.0)
		if cm % 20 == 0 and cm > 0:
			draw_string(font, Vector2(sx0 + 10, ty + 4), str(cm), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(MEAT, 0.5))
	# the side markers: the patient's right is on the viewer's left
	var mk := 16 if h > 480 else 13
	draw_string(Hud.F_BOLD if Hud.F_BOLD else font, Vector2(plate.position.x + 30, plate.position.y + 22), "R", HORIZONTAL_ALIGNMENT_LEFT, -1, mk, Color(MEAT, 0.7))
	draw_string(Hud.F_BOLD if Hud.F_BOLD else font, Vector2(plate.end.x - 30, plate.position.y + 22), "L", HORIZONTAL_ALIGNMENT_LEFT, -1, mk, Color(MEAT, 0.7))
	draw_string(font, Vector2(plate.position.x + 30, plate.position.y + 36), "A/P", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(MEAT, 0.4))
	# a calibration strip, bottom right: ten steps of density
	var cw := 7.0
	var cb := Vector2(plate.end.x - 14.0 - cw, plate.end.y - 14.0)
	for s in 10:
		var r := Rect2(cb - Vector2(0, (s + 1) * cw), Vector2(cw, cw - 1))
		draw_rect(r, Color(MEAT, 0.06 + s * 0.075))
	draw_rect(Rect2(cb - Vector2(1, 10 * cw + 1), Vector2(cw + 2, 10 * cw + 2)), Color(MEAT, 0.35), false, 1.0)
	# the axis
	var ax := fig.get_center().x
	var yy := fig.position.y - 6.0
	while yy < fig.end.y + 6.0:
		draw_line(Vector2(ax, yy), Vector2(ax, minf(yy + 3.0, fig.end.y + 6.0)), Color(MEAT, 0.14), 1.0)
		yy += 7.0


## The skeleton, organs and chrome, over the tissue.
class Bones extends Control:
	var art: BodyScan

	func _draw() -> void:
		if art == null or art.fig.size.y <= 0:
			return
		art._draw_inner(self)


# --- The skeleton and organs ------------------------------------------------------------------

var _cv: Control   ## the canvas being drawn on (Bones)


func _draw_inner(cv: Control) -> void:
	_cv = cv
	var h := fig.size.y
	var w := 1.0 if h < 520.0 else 1.25
	_organs(w)
	_skull(w)
	_spine(w)
	_ribs(w)
	_pelvis(w)
	for s in [-1.0, 1.0]:
		_arm(s, w)
		_leg(s, w)
	_chrome(w)
	_cv = null


## A region's bone colour: bone white over meat, else the region's tint.
func _bcol(r: int, a := 0.6) -> Color:
	var t: Color = tints[r][0] if r < tints.size() else Color(0, 0, 0, 0)
	return Color(BONE.lerp(Color(t, 1.0), t.a), a)


func _line(pts, col: Color, w := 1.0, closed := false) -> void:   # pts: Array or PackedVector2Array
	var pp := PackedVector2Array()
	for v: Vector2 in pts:
		pp.append(P(v))
	if closed and pp.size() > 2:
		pp.append(pp[0])
	if pp.size() >= 2:
		_cv.draw_polyline(pp, Color(col, col.a * 0.22), w * 3.2, true)
		_cv.draw_polyline(pp, col, w, true)


func _ell(c: Vector2, rx: float, ry: float, col: Color, w := 1.0, fill := 0.0, rot := 0.0, a0 := 0.0, a1 := TAU) -> void:
	var pts: Array = []
	var n := 28
	for i in n + 1:
		var t := lerpf(a0, a1, float(i) / n)
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry).rotated(rot))
	if fill > 0.0:
		var poly := PackedVector2Array()
		for v: Vector2 in pts:
			poly.append(P(v))
		_cv.draw_colored_polygon(poly, Color(col, fill))
	_line(pts, col, w)


func _shape(pts: Array, col: Color, w := 1.0, fill := 0.0) -> void:
	var sm := BodyArt._spline(PackedVector2Array(pts + [pts[0], pts[1]]))
	var poly := PackedVector2Array()
	for v in sm:
		poly.append(P(v))
	if fill > 0.0:
		_cv.draw_colored_polygon(poly, Color(col, fill))
	_cv.draw_polyline(poly, Color(col, col.a * 0.22), w * 3.2, true)
	_cv.draw_polyline(poly, col, w, true)


func _mx(pts: Array, s: float) -> Array:
	return pts.map(func(v: Vector2) -> Vector2: return Vector2(v.x * s, v.y))


## The organ colour follows Internal chrome (grafted in: violet; selected: gold).
func _organ_col() -> Color:
	if body and body.sel_loc == "internal":
		return Hud.GOLD
	if body and body.c and ChromeBody.chromed(body.c.implants, "internal"):
		return ChromeBody.CHROME
	return MEAT


func _organs(w: float) -> void:
	var oc := _organ_col()
	var a := 0.5
	# the brain: an outline and a few folds
	_ell(Vector2(0, 0.040), 0.031, 0.026, Color(_bcol(RG.HEAD, 0.35)), w * 0.8, 0.05)
	for g in [[Vector2(-0.018, 0.03), 0.010, 0.4, 2.6], [Vector2(0.016, 0.028), 0.011, 0.5, 2.8], [Vector2(0.0, 0.046), 0.012, 3.5, 5.9], [Vector2(-0.02, 0.05), 0.008, 3.9, 6.0], [Vector2(0.021, 0.05), 0.008, 3.4, 5.6]]:
		_ell(g[0], g[1], g[1] * 0.7, Color(_bcol(RG.HEAD, 0.25)), w * 0.7, 0.0, 0.0, g[2], g[3])
	# lungs
	for s in [-1.0, 1.0]:
		_shape(_mx([Vector2(0.022, 0.192), Vector2(0.040, 0.180), Vector2(0.066, 0.198), Vector2(0.080, 0.250), Vector2(0.078, 0.298),
			Vector2(0.050, 0.306), Vector2(0.024, 0.292), Vector2(0.018, 0.240)], s), Color(MEAT, 0.4), w * 0.9, 0.05)
	# heart, liver, stomach, kidneys, bladder
	_shape([Vector2(-0.010, 0.232), Vector2(0.018, 0.226), Vector2(0.040, 0.250), Vector2(0.026, 0.280), Vector2(0.004, 0.272), Vector2(-0.014, 0.252)], Color(oc, a + 0.1), w, 0.12)
	_shape([Vector2(-0.084, 0.300), Vector2(-0.030, 0.292), Vector2(0.022, 0.302), Vector2(0.004, 0.326), Vector2(-0.050, 0.344), Vector2(-0.082, 0.332)], Color(oc, a), w * 0.9, 0.07)
	_shape([Vector2(0.026, 0.312), Vector2(0.056, 0.304), Vector2(0.072, 0.326), Vector2(0.058, 0.356), Vector2(0.032, 0.352), Vector2(0.040, 0.332)], Color(oc, a), w * 0.9, 0.07)
	for s in [-1.0, 1.0]:
		_ell(Vector2(0.046 * s, 0.356), 0.011, 0.019, Color(oc, a), w * 0.9, 0.08, -0.25 * s)
	_ell(Vector2(0, 0.470), 0.018, 0.012, Color(oc, a * 0.8), w * 0.8, 0.06)
	# the gut: a coil in the belly
	var coil: Array = []
	for i in 9:
		var yy := 0.372 + i * 0.0085
		var xs := 0.05 - absf(i - 4) * 0.003
		coil.append(Vector2(-xs if i % 2 == 0 else xs, yy))
	_line(BodyArt._spline(PackedVector2Array(coil)), Color(oc, a * 0.6), w * 0.8)


func _skull(w: float) -> void:
	var c := _bcol(RG.HEAD)
	_ell(Vector2(0, 0.050), 0.037, 0.044, c, w, 0.0, 0.0, PI * 0.93, PI * 2.07)
	_line([Vector2(-0.035, 0.064), Vector2(-0.031, 0.083), Vector2(-0.027, 0.097), Vector2(-0.015, 0.110), Vector2(0, 0.114),
		Vector2(0.015, 0.110), Vector2(0.027, 0.097), Vector2(0.031, 0.083), Vector2(0.035, 0.064)], c, w)
	for s in [-1.0, 1.0]:
		var reg: int = RG.R_EYE if s < 0 else RG.L_EYE
		_ell(Vector2(0.016 * s, 0.057), 0.0115, 0.0095, _bcol(reg, 0.7), w)
		_line(_mx([Vector2(0.027, 0.066), Vector2(0.036, 0.068), Vector2(0.034, 0.078)], s), Color(c, 0.4), w * 0.8)   # cheekbone
	_line([Vector2(0, 0.064), Vector2(-0.006, 0.079), Vector2(0.006, 0.079), Vector2(0, 0.064)], Color(c, 0.5), w * 0.8)
	for i in 9:   # teeth
		var x := -0.016 + i * 0.004
		_line([Vector2(x, 0.088), Vector2(x, 0.097)], Color(c, 0.35), w * 0.7)
	_line([Vector2(-0.018, 0.0925), Vector2(0.018, 0.0925)], Color(c, 0.3), w * 0.7)


func _spine(w: float) -> void:
	var c := _bcol(RG.TORSO, 0.55)
	var y := 0.116
	var n := 0
	while y < 0.452:
		var cerv := y < 0.162
		var lum := y > 0.368
		var hgt := 0.0062 if cerv else (0.0155 if lum else 0.0162)
		var wd := 0.0072 if cerv else (0.0125 if lum else 0.0085 + (y - 0.162) * 0.012)
		var r := Rect2(P(Vector2(-wd, y)), Vector2(wd * 2, hgt - 0.002) * fig.size.y)
		_cv.draw_rect(r, Color(c, 0.08))
		_cv.draw_rect(r, c, false, w * 0.8)
		var tp := 0.011 if cerv else (0.020 if lum else 0.016)
		_line([Vector2(-wd - tp, y + hgt * 0.4), Vector2(-wd, y + hgt * 0.4)], Color(c, 0.45), w * 0.7)
		_line([Vector2(wd, y + hgt * 0.4), Vector2(wd + tp, y + hgt * 0.4)], Color(c, 0.45), w * 0.7)
		y += hgt
		n += 1
	_shape([Vector2(-0.024, 0.452), Vector2(0.024, 0.452), Vector2(0.010, 0.488), Vector2(0, 0.496), Vector2(-0.010, 0.488)], c, w * 0.9, 0.06)


func _ribs(w: float) -> void:
	var c := _bcol(RG.TORSO, 0.5)
	# the sternum and the collarbones
	_shape([Vector2(-0.009, 0.176), Vector2(0.009, 0.176), Vector2(0.007, 0.200), Vector2(0.008, 0.288), Vector2(0, 0.300), Vector2(-0.008, 0.288), Vector2(-0.007, 0.200)], c, w * 0.9, 0.08)
	for s in [-1.0, 1.0]:
		_line(BodyArt._spline(PackedVector2Array(_mx([Vector2(0.010, 0.172), Vector2(0.048, 0.176), Vector2(0.084, 0.167), Vector2(0.112, 0.177)], s))), Color(_bcol(RG.TORSO, 0.65)), w * 1.1)
		_line(_mx([Vector2(0.062, 0.182), Vector2(0.112, 0.188), Vector2(0.076, 0.268), Vector2(0.062, 0.182)], s), Color(c, 0.18), w * 0.8)   # shoulder blade, behind
		for i in 10:
			var y0 := 0.176 + i * 0.0165
			var lat := 0.058 + 0.026 * sin(PI * (i + 2.0) / 13.0)
			var pts: Array = [Vector2(0.010, y0), Vector2(lat * 0.55, y0 - 0.006), Vector2(lat, y0 + 0.012), Vector2(lat * 0.98, y0 + 0.032)]
			if i < 7:   # true ribs: the cartilage back up to the sternum (dimmer)
				pts.append(Vector2(lat * 0.7, y0 + 0.046))
			_line(BodyArt._spline(PackedVector2Array(_mx(pts, s))), Color(c, 0.5 - i * 0.015), w * 0.9)
			if i < 7:
				_line(BodyArt._spline(PackedVector2Array(_mx([Vector2(lat * 0.7, y0 + 0.046), Vector2(lat * 0.35, y0 + 0.04 - i * 0.002), Vector2(0.009, 0.205 + i * 0.012)], s))), Color(c, 0.22), w * 0.7)


func _pelvis(w: float) -> void:
	var c := _bcol(RG.TORSO, 0.55)
	for s in [-1.0, 1.0]:
		_shape(_mx([Vector2(0.024, 0.428), Vector2(0.058, 0.406), Vector2(0.088, 0.416), Vector2(0.092, 0.440), Vector2(0.076, 0.466),
			Vector2(0.066, 0.488), Vector2(0.044, 0.503), Vector2(0.010, 0.506), Vector2(0.016, 0.476), Vector2(0.026, 0.452)], s), c, w, 0.06)
		_ell(Vector2(0.034 * s, 0.489), 0.011, 0.008, Color(c, 0.4), w * 0.8)


func _arm(s: float, w: float) -> void:
	var reg: int = RG.L_ARM if s > 0 else RG.R_ARM
	var fore: int = RG.L_FORE if s > 0 else RG.R_ARM
	if region_plated(reg):
		_cyber_limb(s, [Vector2(0.128, 0.206), Vector2(0.164, 0.378), Vector2(0.192, 0.505)], reg, w)
		_cyber_hand(s, reg, w)
		return
	var c := _bcol(reg)
	var cf := _bcol(fore)
	_ell(Vector2(0.128 * s, 0.206), 0.014, 0.014, c, w, 0.06)
	_bone(Vector2(0.131 * s, 0.218), Vector2(0.161 * s, 0.366), 0.0052, 0.0075, c, w)
	_bone(Vector2(0.159 * s, 0.384), Vector2(0.186 * s, 0.497), 0.0032, 0.0042, cf, w)
	_bone(Vector2(0.170 * s, 0.382), Vector2(0.197 * s, 0.494), 0.0030, 0.0036, cf, w)
	_hand(s, cf, w)


func _hand(s: float, c: Color, w: float) -> void:
	for i in 3:
		_ell(Vector2((0.190 + i * 0.006) * s, 0.507 + (i % 2) * 0.004), 0.0035, 0.003, Color(c, 0.5), w * 0.7)
	for f in 4:
		var x0 := (0.188 + f * 0.0055) * s
		var y1 := 0.548 + (0.004 if f in [1, 2] else 0.0)
		_line([Vector2(x0, 0.516), Vector2(x0 + 0.0025 * s, y1)], Color(c, 0.55), w * 0.8)
		_line([Vector2(x0 + 0.003 * s, y1 + 0.002), Vector2(x0 + 0.005 * s, y1 + 0.03 - absf(f - 1.5) * 0.006)], Color(c, 0.45), w * 0.7)
	_line([Vector2(0.185 * s, 0.514), Vector2(0.181 * s, 0.536), Vector2(0.180 * s, 0.552)], Color(c, 0.5), w * 0.8)   # thumb


func _leg(s: float, w: float) -> void:
	var reg: int = RG.L_LEG if s > 0 else RG.R_LEG
	if region_plated(reg):
		_cyber_limb(s, [Vector2(0.072, 0.484), Vector2(0.059, 0.722), Vector2(0.067, 0.935)], reg, w)
		_line(_mx([Vector2(0.060, 0.94), Vector2(0.082, 0.988), Vector2(0.066, 0.99)], s), _bcol(reg, 0.8), w)
		return
	var c := _bcol(reg)
	_ell(Vector2(0.070 * s, 0.482), 0.012, 0.012, c, w, 0.06)
	_line(_mx([Vector2(0.074, 0.488), Vector2(0.090, 0.494), Vector2(0.084, 0.506)], s), Color(c, 0.6), w)
	_bone(Vector2(0.080 * s, 0.502), Vector2(0.059 * s, 0.690), 0.0075, 0.0085, c, w)
	_line(_mx([Vector2(0.044, 0.697), Vector2(0.050, 0.712), Vector2(0.070, 0.712), Vector2(0.075, 0.697)], s), Color(c, 0.55), w)
	_ell(Vector2(0.059 * s, 0.716), 0.010, 0.012, Color(c, 0.5), w * 0.9, 0.05)
	_bone(Vector2(0.056 * s, 0.738), Vector2(0.062 * s, 0.925), 0.0085, 0.0065, c, w)
	_line([Vector2(0.074 * s, 0.748), Vector2(0.075 * s, 0.926)], Color(c, 0.45), w * 0.8)   # fibula
	_ell(Vector2(0.066 * s, 0.942), 0.010, 0.007, Color(c, 0.5), w * 0.8)
	for f in 3:
		_line([Vector2((0.062 + f * 0.007) * s, 0.952), Vector2((0.068 + f * 0.009) * s, 0.988)], Color(c, 0.45), w * 0.7)


## A long bone: two walls with flared ends.
func _bone(a: Vector2, b: Vector2, ra: float, rb: float, c: Color, w: float) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	for sd in [-1.0, 1.0]:
		_line([a + n * ra * 1.7 * sd, a + d * 0.02 + n * ra * sd, b - d * 0.02 + n * rb * sd, b + n * rb * 1.6 * sd], c, w)
	_line([a + n * ra * 1.7, a - n * ra * 1.7], Color(c, 0.4), w * 0.8)
	_line([b + n * rb * 1.6, b - n * rb * 1.6], Color(c, 0.4), w * 0.8)


## A cyberlimb's frame: twin struts per segment, braces, a piston, ringed joints.
func _cyber_limb(s: float, joints: Array, reg: int, w: float) -> void:
	var c := _bcol(reg, 0.85)
	for i in joints.size() - 1:
		var a := Vector2(joints[i].x * s, joints[i].y)
		var b := Vector2(joints[i + 1].x * s, joints[i + 1].y)
		var d := (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		var g := 0.0068 - i * 0.0012
		var a2 := a + d * 0.012
		var b2 := b - d * 0.012
		_line([a2 + n * g, b2 + n * g], c, w)
		_line([a2 - n * g, b2 - n * g], c, w)
		var nb := 5
		for k in nb + 1:   # braces
			var t := float(k) / nb
			var p := a2.lerp(b2, t)
			var q := a2.lerp(b2, minf(1.0, t + 1.0 / nb))
			if k < nb:
				_line([p + n * g, q - n * g], Color(c, 0.4), w * 0.7)
		_line([a2.lerp(b2, 0.2), a2.lerp(b2, 0.75)], Color(c, 0.9), w * 1.6)   # the piston
	for j in joints.size():
		var p := Vector2(joints[j].x * s, joints[j].y)
		_ell(p, 0.0105, 0.0105, c, w, 0.12)
		_ell(p, 0.004, 0.004, Color(c, 0.9), w, 0.5)


func _cyber_hand(s: float, reg: int, w: float) -> void:
	var c := _bcol(reg, 0.8)
	for f in 4:
		var x0 := (0.188 + f * 0.0055) * s
		var pts: Array = [Vector2(x0, 0.514), Vector2(x0 + 0.002 * s, 0.548), Vector2(x0 + 0.004 * s, 0.572 - absf(f - 1.5) * 0.004)]
		_line(pts, c, w)
		for v: Vector2 in pts:
			_cv.draw_circle(P(v), 1.6, c)
	_line([Vector2(0.185 * s, 0.512), Vector2(0.180 * s, 0.536), Vector2(0.179 * s, 0.550)], c, w)


## Chrome that isn't a limb: lenses, the ear, the Neural Link's trace, the chip socket, a frame.
func _chrome(w: float) -> void:
	if body == null or body.c == null:
		return
	var imp := body.c.implants
	for s in [-1.0, 1.0]:
		var reg: int = RG.R_EYE if s < 0 else RG.L_EYE
		if region_amount(reg) > 0.0:
			var c := _bcol(reg, 0.95)
			var e := Vector2(0.016 * s, 0.057)
			_ell(e, 0.0075, 0.0075, c, w, 0.25)
			_ell(e, 0.0035, 0.0035, Color(c, 1.0), w, 0.7)
			_line([e + Vector2(-0.012, 0), e + Vector2(0.012, 0)], Color(c, 0.6), w * 0.7)
	if region_amount(RG.EAR) > 0.0:
		var c := _bcol(RG.EAR, 0.9)
		for r in [0.006, 0.010, 0.014]:
			_ell(Vector2(0.046, 0.066), r, r * 1.2, Color(c, 0.9 - r * 30.0), w, 0.0, 0.0, -PI * 0.45, PI * 0.45)
	if region_amount(RG.HEAD) > 0.0:   # the Neural Link: a processor at the skull's base, a trace down the spine
		var c := _bcol(RG.HEAD, 0.9)
		_cv.draw_rect(Rect2(P(Vector2(-0.008, 0.098)), Vector2(0.016, 0.010) * fig.size.y), Color(c, 0.3))
		_cv.draw_rect(Rect2(P(Vector2(-0.008, 0.098)), Vector2(0.016, 0.010) * fig.size.y), c, false, w)
		var y := 0.108
		_line([Vector2(-0.0025, y), Vector2(-0.0025, 0.45)], Color(c, 0.75), w)
		_line([Vector2(0.0025, y), Vector2(0.0025, 0.45)], Color(c, 0.45), w * 0.8)
		while y < 0.45:
			_cv.draw_circle(P(Vector2(-0.0025, y)), 1.7, c)
			y += 0.034
	if ChromeBody.chromed(imp, "chipware") or body.sel_loc == "chipware":
		var c := Color(_bcol(RG.NECK, 0.9))
		var r := Rect2(P(Vector2(-0.011, 0.130)), Vector2(0.022, 0.012) * fig.size.y)
		_cv.draw_rect(r, Color(c, 0.25))
		_cv.draw_rect(r, c, false, w)
		for i in 5:
			var x := -0.008 + i * 0.004
			_line([Vector2(x, 0.130), Vector2(x, 0.126)], c, w * 0.8)
	if region_plated(RG.TORSO):   # borgware: a linear frame over the shoulders and down the back
		var c := _bcol(RG.TORSO, 0.85)
		for s in [-1.0, 1.0]:
			_line(_mx([Vector2(0.118, 0.186), Vector2(0.060, 0.170), Vector2(0.036, 0.200), Vector2(0.034, 0.420), Vector2(0.074, 0.470)], s), c, w * 1.4)
			for y in [0.2, 0.26, 0.32, 0.38]:
				_ell(Vector2(0.035 * s, y), 0.005, 0.005, c, w, 0.4)
		_line([Vector2(-0.036, 0.26), Vector2(0.036, 0.26)], Color(c, 0.6), w)
		_line([Vector2(-0.035, 0.38), Vector2(0.035, 0.38)], Color(c, 0.6), w)
