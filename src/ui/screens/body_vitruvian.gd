class_name BodyVitruvian
extends BodyArt
## The "vitruvian" cyberware figure: Leonardo's Vitruvian Man (c. 1490, public domain; the ink lifted
## off a photograph of the sheet: assets/third_party/vitruvian/README.md) as a ripperdoc's schematic.
## His own line work, muscle hatching and wash, glowing on the dark page (body_vitruvian.gdshader);
## round it, redrawn crisp: the circle with a degree ring, the square ticked in palms and cubits, his
## proportion levels, an arm-span dimension and notes in a mirror-written asemic hand (no words).
## Each body region (bones laid over the drawing, both poses) takes its tint: chromed limbs plated
## and circuit-traced in violet, the selected location gold, external chrome a dermal mesh. The
## sheet is square: it runs on under the card columns, which go see-through to show it.

const INK := preload("res://assets/third_party/vitruvian/vitruvian_ink.png")
const SHADER := preload("res://src/ui/screens/body_vitruvian.gdshader")
## The drawing's geometry, in the ink texture's pixels (tools/gen_vitruvian_ink.py).
const SIDE := 1640.0
const CENTRE := Vector2(820, 820)      ## the circle's centre (the navel)
const RADIUS := 806.0
const SQUARE := Rect2(160, 294, 1356, 1330)
## Bones over the drawing, both poses: [from, to, reach (px), region]. The figure faces us: his
## right is on the viewer's left.
const BONES := [
	[Vector2(815, 330), Vector2(815, 445), 78.0, ChromeBody.Reg.HEAD],
	[Vector2(788, 377), Vector2(792, 377), 17.0, ChromeBody.Reg.R_EYE],
	[Vector2(842, 377), Vector2(846, 377), 17.0, ChromeBody.Reg.L_EYE],
	[Vector2(884, 405), Vector2(886, 425), 22.0, ChromeBody.Reg.EAR],
	[Vector2(815, 470), Vector2(815, 512), 42.0, ChromeBody.Reg.NECK],
	[Vector2(815, 560), Vector2(815, 760), 128.0, ChromeBody.Reg.TORSO],
	[Vector2(815, 760), Vector2(815, 950), 102.0, ChromeBody.Reg.TORSO],
	# his right arm: level, then raised
	[Vector2(700, 535), Vector2(470, 536), 40.0, ChromeBody.Reg.R_ARM],
	[Vector2(470, 536), Vector2(262, 533), 33.0, ChromeBody.Reg.R_ARM],
	[Vector2(262, 533), Vector2(165, 528), 30.0, ChromeBody.Reg.R_ARM],
	[Vector2(700, 505), Vector2(470, 425), 38.0, ChromeBody.Reg.R_ARM],
	[Vector2(470, 425), Vector2(290, 360), 31.0, ChromeBody.Reg.R_ARM],
	[Vector2(290, 360), Vector2(182, 310), 30.0, ChromeBody.Reg.R_ARM],
	# his left arm (the forearm and hand: fashionware's)
	[Vector2(930, 535), Vector2(1160, 536), 40.0, ChromeBody.Reg.L_ARM],
	[Vector2(1160, 536), Vector2(1398, 533), 33.0, ChromeBody.Reg.L_FORE],
	[Vector2(1398, 533), Vector2(1508, 528), 30.0, ChromeBody.Reg.L_FORE],
	[Vector2(930, 505), Vector2(1160, 425), 38.0, ChromeBody.Reg.L_ARM],
	[Vector2(1160, 425), Vector2(1340, 362), 31.0, ChromeBody.Reg.L_FORE],
	[Vector2(1340, 362), Vector2(1448, 296), 30.0, ChromeBody.Reg.L_FORE],
	# legs: standing, then spread
	[Vector2(765, 990), Vector2(775, 1280), 56.0, ChromeBody.Reg.R_LEG],
	[Vector2(775, 1280), Vector2(792, 1595), 42.0, ChromeBody.Reg.R_LEG],
	[Vector2(740, 1000), Vector2(600, 1250), 56.0, ChromeBody.Reg.R_LEG],
	[Vector2(600, 1250), Vector2(440, 1488), 42.0, ChromeBody.Reg.R_LEG],
	[Vector2(872, 990), Vector2(882, 1280), 56.0, ChromeBody.Reg.L_LEG],
	[Vector2(882, 1280), Vector2(866, 1595), 42.0, ChromeBody.Reg.L_LEG],
	[Vector2(892, 1000), Vector2(1032, 1250), 56.0, ChromeBody.Reg.L_LEG],
	[Vector2(1032, 1250), Vector2(1205, 1478), 42.0, ChromeBody.Reg.L_LEG],
]
## Where each location's leader line meets the drawing (texture pixels).
const ANCHORS := {"neural_link": Vector2(815, 312), "right_eye": Vector2(790, 377), "left_eye": Vector2(844, 377),
	"cyberaudio": Vector2(886, 415), "chipware": Vector2(815, 492), "internal": Vector2(815, 650),
	"borgware": Vector2(930, 568), "right_arm": Vector2(575, 535), "left_arm": Vector2(1060, 535),
	"fashion": Vector2(1195, 535), "external": Vector2(712, 1080), "right_leg": Vector2(640, 1190),
	"left_leg": Vector2(995, 1190)}
## His proportions (Vitruvius, as Leonardo ruled them): levels as fractions of the height.
const LEVELS := [[0.0, "0"], [0.125, "1/8"], [0.25, "1/4"], [0.5, "1/2"], [0.75, "3/4"], [1.0, "1"]]

const LINE := Color(0.02, 0.85, 0.91, 0.5)

var _ink: TextureRect
var _mat: ShaderMaterial


func aspect() -> float:
	return 1.0


func wide() -> bool:
	return true


func anchor_uv(loc: String) -> Vector2:
	return (ANCHORS.get(loc, CENTRE) as Vector2) / SIDE


func _ready() -> void:
	_build()


func _build() -> void:
	if _ink:
		return
	_ink = TextureRect.new()
	_ink.name = "Ink"
	_ink.texture = INK
	_ink.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ink.stretch_mode = TextureRect.STRETCH_SCALE
	_ink.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	var segs := PackedVector4Array()
	var segp := PackedVector4Array()
	for b in BONES:
		var a: Vector2 = b[0] / SIDE
		var e: Vector2 = b[1] / SIDE
		segs.append(Vector4(a.x, a.y, e.x, e.y))
		segp.append(Vector4(float(b[2]) / SIDE, float(b[3]), 0, 0))
	_mat.set_shader_parameter("segs", segs)
	_mat.set_shader_parameter("segp", segp)
	_mat.set_shader_parameter("nseg", BONES.size())
	_mat.set_shader_parameter("tints", tint_array())
	_mat.set_shader_parameter("plated", plated_array())
	_mat.set_shader_parameter("meat", MEAT)
	_mat.set_shader_parameter("shell", shell)
	_mat.set_shader_parameter("motion", 1.0 if motion else 0.0)
	var sel := -1
	for r in tints.size():
		if region_selected(r):
			sel = r
			break
	_mat.set_shader_parameter("selected", sel)
	_ink.material = _mat
	add_child(_ink)


func _placed() -> void:
	_build()
	_ink.position = fig.position
	_ink.size = fig.size
	_mat.set_shader_parameter("px", 1.0 / maxf(fig.size.x, 1.0))


## Texture pixels → this control.
func _p(v: Vector2) -> Vector2:
	return fig.position + v / SIDE * fig.size


func _k() -> float:
	return fig.size.x / SIDE


func _draw() -> void:
	if fig.size.x <= 0:
		return
	var k := _k()
	var c := _p(CENTRE)
	var r := RADIUS * k
	var sq := Rect2(_p(SQUARE.position), SQUARE.size * k)
	var font := Hud.F_MONO if Hud.F_MONO else get_theme_default_font()
	# a faint halo behind him, and the page's grid (a palm square) inside the circle
	draw_circle(c, r, Color(MEAT, 0.025))
	var palm := sq.size.x / 24.0
	var i := -14
	while i <= 14:
		var off := i * palm
		var half := sqrt(maxf(0.0, r * r - off * off))
		var a := 0.07 if i % 6 == 0 else 0.035
		draw_line(Vector2(c.x + off, c.y - half), Vector2(c.x + off, c.y + half), Color(MEAT, a), 1.0)
		var oy := sq.get_center().y - c.y + off
		var hy := sqrt(maxf(0.0, r * r - oy * oy))
		draw_line(Vector2(c.x - hy, c.y + oy), Vector2(c.x + hy, c.y + oy), Color(MEAT, a), 1.0)
		i += 1
	# the circle: a double ring, ticked every 5 degrees, numbered every 30
	draw_arc(c, r, 0, TAU, 160, LINE, 1.3, true)
	draw_arc(c, r + 7.0, 0, TAU, 160, Color(MEAT, 0.16), 1.0, true)
	for d in 72:
		var ang := deg_to_rad(d * 5.0 - 90.0)
		var u := Vector2.from_angle(ang)
		var long := d % 6 == 0
		draw_line(c + u * r, c + u * (r + (12.0 if long else 7.0)), Color(MEAT, 0.5 if long else 0.28), 1.0, true)
		if long:
			var t := "%03d" % (d * 5)
			var tp := c + u * (r + 22.0) - Vector2(9, -4)
			draw_string(font, tp, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(MEAT, 0.45))
	# the square, ticked in palms (24 to his height) and cubits (6 palms)
	draw_rect(sq, LINE, false, 1.3)
	for j in 25:
		var long := j % 6 == 0
		var tl := 9.0 if long else 4.5
		var col := Color(MEAT, 0.55 if long else 0.32)
		var x := sq.position.x + j * palm
		var y := sq.position.y + j * palm * sq.size.y / sq.size.x
		draw_line(Vector2(x, sq.end.y), Vector2(x, sq.end.y - tl), col, 1.0)
		draw_line(Vector2(x, sq.position.y), Vector2(x, sq.position.y + tl), col, 1.0)
		draw_line(Vector2(sq.position.x, y), Vector2(sq.position.x + tl, y), col, 1.0)
		draw_line(Vector2(sq.end.x, y), Vector2(sq.end.x - tl, y), col, 1.0)
		if long and j > 0 and j < 24:
			draw_string(font, Vector2(x - 3, sq.end.y + 13), str(j / 6), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(MEAT, 0.42))
	# his proportion levels: dashed across the middle, numbered at the stage's edges
	var lx0 := maxf(stage.position.x + 6.0, sq.position.x)
	var lx1 := minf(stage.end.x - 6.0, sq.end.x)
	for lv in LEVELS:
		var y := sq.position.y + float(lv[0]) * sq.size.y
		_dashed(Vector2(lx0, y), Vector2(lx1, y), Color(MEAT, 0.16), 6.0, 5.0)
		draw_line(Vector2(lx0, y), Vector2(lx0 + 8, y), Color(MEAT, 0.5), 1.0)
		draw_line(Vector2(lx1 - 8, y), Vector2(lx1, y), Color(MEAT, 0.5), 1.0)
		draw_string(font, Vector2(lx1 - 30, y - 3), String(lv[1]), HORIZONTAL_ALIGNMENT_RIGHT, 22, 11, Color(MEAT, 0.5))
	# the axis, the circle's centre (navel) and the square's (the groin)
	_dashed(Vector2(c.x, sq.position.y - 26.0 * k * 3), Vector2(c.x, sq.end.y + 6), Color(MEAT, 0.14), 3.0, 4.0)
	draw_arc(c, 7.0, 0, TAU, 24, Color(Hud.GOLD, 0.6), 1.0, true)
	draw_line(c - Vector2(12, 0), c + Vector2(12, 0), Color(Hud.GOLD, 0.6), 1.0)
	draw_line(c - Vector2(0, 12), c + Vector2(0, 12), Color(Hud.GOLD, 0.6), 1.0)
	var g := sq.get_center()
	draw_polyline(PackedVector2Array([g + Vector2(0, -6), g + Vector2(6, 0), g + Vector2(0, 6), g + Vector2(-6, 0), g + Vector2(0, -6)]), Color(Hud.GOLD, 0.5), 1.0, true)
	# the span: arm to arm equals his height
	var sy := sq.position.y - 16.0
	_dim(Vector2(sq.position.x, sy), Vector2(sq.end.x, sy), Color(MEAT, 0.42))
	draw_string(font, Vector2(c.x + 8, sy - 5), "1.000", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(MEAT, 0.6))
	var hx := sq.end.x + 16.0
	_dim(Vector2(hx, sq.position.y), Vector2(hx, sq.end.y), Color(MEAT, 0.42))
	# notes in a mirror-written hand: over his head, and under each level arm
	var nc := Color(MEAT, 0.32)
	var xh := maxf(2.2, 9.0 * k)
	var top := c + Vector2(-150, -330) * k
	for ln in 3:
		script_line(top + Vector2(0, ln * xh * 3.4), 300.0 * k - ln * 40.0 * k, xh, nc, 11 + ln, 1.0, true)
	for side in [-1.0, 1.0]:
		var o := c + Vector2(side * 380.0 - 120.0, -90.0) * k
		for ln in 2:
			script_line(o + Vector2(0, ln * xh * 3.4), 240.0 * k, xh, Color(MEAT, 0.24), 31 + ln + int(side), 1.0, true)


func _dashed(a: Vector2, b: Vector2, col: Color, dash: float, gap: float) -> void:
	var l := a.distance_to(b)
	if l <= 0.0:
		return
	var d := (b - a) / l
	var t := 0.0
	while t < l:
		draw_line(a + d * t, a + d * minf(t + dash, l), col, 1.0)
		t += dash + gap


## A dimension line with arrowheads and end stops.
func _dim(a: Vector2, b: Vector2, col: Color) -> void:
	draw_line(a, b, col, 1.0, true)
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	for e in [[a, d], [b, -d]]:
		var p: Vector2 = e[0]
		var dd: Vector2 = e[1]
		draw_colored_polygon(PackedVector2Array([p, p + dd * 7 + n * 2.5, p + dd * 7 - n * 2.5]), col)
		draw_line(p + n * 5, p - n * 5, col, 1.0)
