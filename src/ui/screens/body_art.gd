class_name BodyArt
extends Control
## A 2D figure for the cyberware screens (ChromeBody's styles other than the hologram): it covers the
## whole ChromeBody, draws its figure in the frame ChromeBody gives it (place), and says where each
## location's leader line meets the body (anchor). ChromeBody hands it every region's tint (cyan
## meat, violet chrome, gold for the selected location: ChromeBody.region_tints) and the skin's
## (shell). A click on the figure picks the nearest location, as on the hologram. Motion (a scan
## sweep, a pulse on the selected place) stops under reduced motion.

const MEAT := Color("05d9e8")   ## Hud.CYAN

var body: ChromeBody
var motion := true
var tints: Array = []      ## per region (ChromeBody.Reg): [Color (a = how much), plated 0/1]
var shell := Color(0, 0, 0, 0)
var fig := Rect2()         ## the figure's frame
var stage := Rect2()       ## the open space between the card columns
var _press := Vector2(-1, -1)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = false


## The figure frame's width over its height.
func aspect() -> float:
	return 0.5


## Whether the drawing runs on under the card columns (they go to their narrowest, a little see-through).
func wide() -> bool:
	return false


## A location's anchor in the frame, as fractions of its width and height.
func anchor_uv(_loc: String) -> Vector2:
	return Vector2(0.5, 0.5)


func anchor(loc: String) -> Vector2:
	return fig.position + anchor_uv(loc) * fig.size


func place(p_fig: Rect2, p_stage: Rect2) -> void:
	fig = p_fig
	stage = p_stage
	_placed()
	queue_redraw()


## Override: lay out children in the new frame.
func _placed() -> void:
	pass


## A region's colour: meat cyan, or its tint over it.
func region_col(r: int, meat := MEAT) -> Color:
	if r < 0 or r >= tints.size():
		return meat
	var t: Color = tints[r][0]
	return meat.lerp(Color(t, 1.0), t.a)


func region_amount(r: int) -> float:
	return (tints[r][0] as Color).a if r >= 0 and r < tints.size() else 0.0


func region_plated(r: int) -> bool:
	return r >= 0 and r < tints.size() and float(tints[r][1]) > 0.0


## Whether a region is the selected location's (its tint is gold).
func region_selected(r: int) -> bool:
	if r < 0 or r >= tints.size():
		return false
	var t: Color = tints[r][0]
	return t.a > 0.0 and absf(t.r - Hud.GOLD.r) < 0.01 and absf(t.g - Hud.GOLD.g) < 0.01


## The tints as shader arrays: colours (a = amount) and plated flags.
func tint_array() -> PackedColorArray:
	var out := PackedColorArray()
	for t in tints:
		out.append(t[0])
	return out


func plated_array() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for t in tints:
		out.append(float(t[1]))
	return out


## A click on the figure picks the nearest location (within reach).
func _gui_input(ev: InputEvent) -> void:
	if body == null or not (ev is InputEventMouseButton) or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	if ev.pressed:
		_press = ev.position
		return
	if _press.x >= 0 and ev.position.distance_to(_press) < 4.0:
		var best := ""
		var bd := 48.0
		for loc: String in body.anchors:
			var d: float = ev.position.distance_to(body.anchors[loc])
			if d < bd:
				bd = d
				best = loc
		if best != "":
			body.loc_pressed.emit(best)
			accept_event()
	_press = Vector2(-1, -1)


# --- Shared drawing ---------------------------------------------------------------------------

## A polyline with a soft glow under it (a wide faint pass, then the line).
func glow_line(pts: PackedVector2Array, col: Color, w := 1.0, glow := 0.18) -> void:
	if pts.size() < 2:
		return
	if glow > 0.0:
		draw_polyline(pts, Color(col, col.a * glow), w * 4.0, true)
	draw_polyline(pts, col, w, true)


## Pseudo-handwriting (asemic: letter-like shapes, no real words): a line of joined cursive glyphs,
## seeded, from `o` along +x for `length` pixels with an x-height of `xh`, slanted; mirror-wise when
## `mirror` (Leonardo wrote right to left).
const GLYPHS := [
	[Vector2(0, 0.2), Vector2(0.55, 0.55), Vector2(0.5, 0.95), Vector2(0.15, 0.8), Vector2(0.2, 0.2), Vector2(0.6, 0.0), Vector2(1.0, 0.25)],
	[Vector2(0, 0.3), Vector2(0.3, 0.95), Vector2(0.75, 0.85), Vector2(0.7, 0.15), Vector2(0.3, 0.05), Vector2(0.25, 0.6), Vector2(0.7, 0.95), Vector2(1.0, 0.7)],
	[Vector2(0, 0.0), Vector2(0.05, 0.9), Vector2(0.25, 0.95), Vector2(0.45, 0.8), Vector2(0.5, 0.0), Vector2(0.55, 0.85), Vector2(0.8, 0.95), Vector2(0.95, 0.5), Vector2(1.0, 0.0)],
	[Vector2(0, 0.1), Vector2(0.4, 1.4), Vector2(0.55, 2.1), Vector2(0.35, 2.0), Vector2(0.3, 1.0), Vector2(0.5, 0.0), Vector2(1.0, 0.25)],
	[Vector2(0, 0.6), Vector2(0.4, 0.95), Vector2(0.6, 0.6), Vector2(0.3, 0.2), Vector2(0.6, 0.6), Vector2(0.6, -0.7), Vector2(0.3, -0.9), Vector2(0.2, -0.6), Vector2(0.8, -0.1), Vector2(1.0, 0.3)],
	[Vector2(0, 0.1), Vector2(0.3, 0.9), Vector2(0.4, 0.1), Vector2(1.0, 0.4)],
	[Vector2(0, 0.1), Vector2(0.35, 1.7), Vector2(0.45, 0.1), Vector2(1.0, 0.4)],
	[Vector2(0, 0.5), Vector2(0.5, 0.95), Vector2(0.2, 0.7), Vector2(0.15, 0.15), Vector2(0.5, 0.1), Vector2(0.6, 0.9), Vector2(0.65, 0.1), Vector2(1.0, 0.3)],
	[Vector2(0, 0.0), Vector2(0.1, 0.9), Vector2(0.4, 0.7), Vector2(0.7, 1.0), Vector2(1.0, 0.3)],
	[Vector2(0, 0.1), Vector2(0.45, 1.0), Vector2(0.6, 0.5), Vector2(0.3, 0.1), Vector2(1.0, 0.3)],
]
const GLYPH_W := [0.75, 0.85, 1.0, 0.6, 0.8, 0.4, 0.45, 0.85, 0.6, 0.6]


func script_line(o: Vector2, length: float, xh: float, col: Color, seed_i: int, w := 1.0, mirror := false) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var x := 0.0
	while x < length:
		var ctrl := PackedVector2Array()
		var marks: Array = []   # i dots, t bars
		for i in rng.randi_range(2, 6):
			var g := rng.randi() % GLYPHS.size()
			var gw: float = GLYPH_W[g] * xh * rng.randf_range(0.9, 1.15)
			if x + gw > length:
				break
			for q: Vector2 in GLYPHS[g]:
				ctrl.append(Vector2(x + q.x * gw, -q.y * xh))
			if g == 5:
				marks.append([Vector2(x + 0.35 * gw, -1.5 * xh), Vector2(x + 0.42 * gw, -1.55 * xh)])
			elif g == 6:
				marks.append([Vector2(x - 0.1 * gw, -1.05 * xh), Vector2(x + 0.8 * gw, -1.1 * xh)])
			x += gw
		if ctrl.size() >= 2:
			draw_polyline(_ink_pts(_spline(ctrl), o, length, xh, mirror), col, w, true)
			for m in marks:
				draw_polyline(_ink_pts(PackedVector2Array(m), o, length, xh, mirror), col, w, true)
		x += xh * rng.randf_range(0.9, 1.7)   # the gap between words


## Catmull-Rom through the control points.
static func _spline(c: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in c.size() - 1:
		var p0 := c[maxi(i - 1, 0)]
		var p1 := c[i]
		var p2 := c[i + 1]
		var p3 := c[mini(i + 2, c.size() - 1)]
		for k in 4:
			var t := k / 4.0
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(c[c.size() - 1])
	return out


## Slant (toward the writing's end) and place.
static func _ink_pts(pts: PackedVector2Array, o: Vector2, length: float, xh: float, mirror: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		var sx := p.x - p.y * 0.28
		out.append(o + Vector2(length - sx if mirror else sx, p.y))
	return out
