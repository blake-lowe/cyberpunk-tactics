class_name BodyAnatomy
extends BodyArt
## The "anatomy" cyberware figure, the default (owner, on the Vitruvian prototype: "This diagram feel
## looks good. Maybe we should use something similar but not exactly the vitruvian man image. I very
## much like the horizontal glitch fuzziness. Maybe a free online skeletal muscle diagram"; the scan
## and faceted figures were cut as cartoonish): a real anatomical plate given the Vitruvian's
## treatment. Thomas Milton's standing écorché, front view (Rees's Cyclopaedia, Anatomy Plate VIII,
## 1804, public domain: assets/third_party/anatomy/README.md), with Plate X (the same man a layer
## deeper, to the bones) warped onto him: the engraving's contours glowing cyan on the dark page,
## its hatching a faint tone, a horizontal glitch fuzz (body_anatomy.gdshader). Round him, redrawn
## crisp: a height scale in heads, his proportion levels, a centre line, registration marks and
## notes in an asemic hand (no words). Each body region (bones laid over the plate) takes its tint:
## chrome violet with the bones showing through and a circuit spine, the selected location gold,
## external chrome a dermal mesh. He stands tall and narrow, between the card columns.

const INK := preload("res://assets/third_party/anatomy/anatomy_ink.png")
const SHADER := preload("res://src/ui/screens/body_anatomy.gdshader")
## The plate's geometry, in the ink texture's pixels (tools/gen_anatomy_ink.py).
const SIZE := Vector2(1024, 2048)
const CROWN := 9.0           ## the top of his head
const SOLE := 1990.0         ## his soles (the heels' line)
const CHIN := 262.0
const AXIS := 524.0          ## his centre line (the crown, the navel, the crotch)
const NAVEL := Vector2(529, 786)
## Bones over the plate: [from, to, reach (px), region], placed by hand on it. He faces us, his head
## a little turned to his right: his right is on the viewer's left. The eyes and the ear come first:
## inside their reach they win over the head (region_at; the shader works the same way).
const BONES := [
	[Vector2(447, 149), Vector2(450, 150), 15.0, ChromeBody.Reg.R_EYE],
	[Vector2(533, 147), Vector2(536, 147), 15.0, ChromeBody.Reg.L_EYE],
	[Vector2(610, 132), Vector2(612, 164), 19.0, ChromeBody.Reg.EAR],
	[Vector2(518, 45), Vector2(512, 215), 98.0, ChromeBody.Reg.HEAD],
	[Vector2(527, 270), Vector2(535, 350), 56.0, ChromeBody.Reg.NECK],
	[Vector2(545, 415), Vector2(535, 700), 205.0, ChromeBody.Reg.TORSO],
	[Vector2(535, 700), Vector2(524, 905), 168.0, ChromeBody.Reg.TORSO],
	# his right arm (the viewer's left): upper arm, forearm, hand
	[Vector2(352, 440), Vector2(238, 786), 60.0, ChromeBody.Reg.R_ARM],
	[Vector2(238, 786), Vector2(179, 1048), 50.0, ChromeBody.Reg.R_ARM],
	[Vector2(179, 1048), Vector2(140, 1250), 72.0, ChromeBody.Reg.R_ARM],
	# his left arm (the forearm and hand: fashionware's)
	[Vector2(760, 440), Vector2(821, 786), 60.0, ChromeBody.Reg.L_ARM],
	[Vector2(821, 786), Vector2(881, 1060), 50.0, ChromeBody.Reg.L_FORE],
	[Vector2(881, 1060), Vector2(905, 1250), 72.0, ChromeBody.Reg.L_FORE],
	# legs: thigh, shin, foot
	[Vector2(422, 905), Vector2(429, 1488), 95.0, ChromeBody.Reg.R_LEG],
	[Vector2(429, 1488), Vector2(428, 1905), 64.0, ChromeBody.Reg.R_LEG],
	[Vector2(428, 1915), Vector2(305, 1968), 50.0, ChromeBody.Reg.R_LEG],
	[Vector2(628, 905), Vector2(655, 1488), 95.0, ChromeBody.Reg.L_LEG],
	[Vector2(655, 1488), Vector2(702, 1905), 64.0, ChromeBody.Reg.L_LEG],
	[Vector2(702, 1915), Vector2(790, 1965), 50.0, ChromeBody.Reg.L_LEG],
]
## Where each location's leader line meets the plate (texture pixels).
const ANCHORS := {"neural_link": Vector2(522, 40), "right_eye": Vector2(448, 150), "left_eye": Vector2(534, 147),
	"cyberaudio": Vector2(611, 148), "chipware": Vector2(531, 312), "internal": Vector2(540, 560),
	"borgware": Vector2(757, 445), "right_arm": Vector2(262, 700), "left_arm": Vector2(800, 680),
	"fashion": Vector2(872, 1020), "external": Vector2(372, 1200), "right_leg": Vector2(421, 1660),
	"left_leg": Vector2(672, 1660)}
## His proportion levels, ruled across the figure (texture y: crown, chin, nipples, navel, crotch,
## knees, soles), each labelled with its height above the soles as a fraction of his (the diagram's
## own numbers: no words).
const LEVELS := [CROWN, CHIN, 515.0, NAVEL.y, 1060.0, 1488.0, SOLE]

const LINE := Color(0.02, 0.85, 0.91, 0.5)

var _ink: TextureRect
var _mat: ShaderMaterial


## The body region at a point of the plate (texture pixels), as the shader finds it: an eye or the
## ear inside its reach, else the bone nearest as a fraction of its reach.
static func region_at(p: Vector2) -> int:
	var best := INF
	var reg := ChromeBody.Reg.TORSO
	for b in BONES:
		var a: Vector2 = b[0]
		var e: Vector2 = b[1]
		var ab := e - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var d := p.distance_to(a + ab * t) / float(b[2])
		var small := int(b[3]) in [ChromeBody.Reg.R_EYE, ChromeBody.Reg.L_EYE, ChromeBody.Reg.EAR]
		if small and d < 1.0:
			return int(b[3])
		if d < best:
			best = d
			reg = int(b[3])
	return reg


func aspect() -> float:
	return SIZE.x / SIZE.y


func anchor_uv(loc: String) -> Vector2:
	return (ANCHORS.get(loc, NAVEL) as Vector2) / SIZE


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
		var a: Vector2 = b[0] / SIZE
		var e: Vector2 = b[1] / SIZE
		segs.append(Vector4(a.x, a.y, e.x, e.y))
		var small := int(b[3]) in [ChromeBody.Reg.R_EYE, ChromeBody.Reg.L_EYE, ChromeBody.Reg.EAR]
		segp.append(Vector4(float(b[2]) / SIZE.x, float(b[3]), 1.0 if small else 0.0, 0))
	_mat.set_shader_parameter("segs", segs)
	_mat.set_shader_parameter("segp", segp)
	_mat.set_shader_parameter("nseg", BONES.size())
	_mat.set_shader_parameter("aspect", aspect())
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
	_mat.set_shader_parameter("px", Vector2(1.0 / maxf(fig.size.x, 1.0), 1.0 / maxf(fig.size.y, 1.0)))


## Texture pixels → this control.
func _p(v: Vector2) -> Vector2:
	return fig.position + v / SIZE * fig.size


func _y(ty: float) -> float:
	return fig.position.y + ty / SIZE.y * fig.size.y


func _draw() -> void:
	if fig.size.x <= 0:
		return
	var font := Hud.F_MONO if Hud.F_MONO else get_theme_default_font()
	var top := _y(CROWN)
	var sole := _y(SOLE)
	var tall := sole - top
	var head := _y(CHIN) - top
	var x0 := maxf(stage.position.x + 6.0, fig.position.x - 46.0)   # the scale's rail
	var x1 := minf(stage.end.x - 6.0, fig.end.x + 46.0)             # the levels' far end
	var ax := _p(Vector2(AXIS, 0)).x
	# the page's grid behind him: faint, a head square
	var gx := ax
	while gx > x0:
		gx -= head * 0.5
	gx += head * 0.5
	while gx < x1:
		draw_line(Vector2(gx, top - 4), Vector2(gx, sole + 4), Color(MEAT, 0.045), 1.0)
		gx += head * 0.5
	var gy := top
	while gy <= sole + 1:
		draw_line(Vector2(x0, gy), Vector2(x1, gy), Color(MEAT, 0.045), 1.0)
		gy += head * 0.5
	# the height scale: a rail at his right, ticked in eighths of a head, numbered in heads
	draw_line(Vector2(x0, top), Vector2(x0, sole), LINE, 1.0)
	var n := 0
	var y := sole
	while y >= top - 0.5:
		var big := n % 8 == 0
		var mid := n % 4 == 0
		var tl := 9.0 if big else (5.5 if mid else 3.0)
		draw_line(Vector2(x0, y), Vector2(x0 + tl, y), Color(MEAT, 0.55 if big else 0.3), 1.0)
		if big and n > 0:
			draw_string(font, Vector2(x0 - 13, y + 4), str(n / 8), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(MEAT, 0.5))
		y -= head / 8.0
		n += 1
	for e in [top, sole]:
		draw_line(Vector2(x0 - 7, e), Vector2(x0 + 4, e), Color(MEAT, 0.6), 1.0)
	# his proportion levels: dashed across, the fraction of his height at the far end
	for lv: float in LEVELS:
		var ly := _y(lv)
		_dashed(Vector2(x0 + 12, ly), Vector2(x1, ly), Color(MEAT, 0.19), 5.0, 5.0)
		draw_line(Vector2(x1 - 8, ly), Vector2(x1, ly), Color(MEAT, 0.5), 1.0)
		var frac := (sole - ly) / tall
		draw_string(font, Vector2(x1 - 30, ly - 3), "%.3f" % frac if frac < 0.999 else "1.000", HORIZONTAL_ALIGNMENT_RIGHT, 30, 9, Color(MEAT, 0.45))
	# the centre line, the navel (gold, as the Vitruvian's circle's centre) and the crotch
	_dashed(Vector2(ax, top - 16), Vector2(ax, sole + 10), Color(MEAT, 0.12), 3.0, 4.0)
	var c := _p(NAVEL)
	draw_arc(c, 6.0, 0, TAU, 24, Color(Hud.GOLD, 0.55), 1.0, true)
	draw_line(c - Vector2(10, 0), c + Vector2(10, 0), Color(Hud.GOLD, 0.55), 1.0)
	draw_line(c - Vector2(0, 10), c + Vector2(0, 10), Color(Hud.GOLD, 0.55), 1.0)
	# his height, crown to sole, beside the levels' numbers
	var hx := x1 + 2.0
	if hx < stage.end.x - 2.0:
		_dim(Vector2(hx, top), Vector2(hx, sole), Color(MEAT, 0.32))
	# registration marks at the plate's corners, a little off
	var fr := Rect2(Vector2(x0 - 2, top - 10), Vector2(x1 - x0 + 4, tall + 20))
	for p in [fr.position, Vector2(fr.end.x, fr.position.y), fr.end, Vector2(fr.position.x, fr.end.y)]:
		_reg_mark(p, 5.0)
	# notes in an asemic hand: beside his head and beside his shins, with a tick to the body
	var xh := maxf(2.2, fig.size.y * 0.0045)
	var nc := Color(MEAT, 0.3)
	var notes := [
		[Vector2(640, 40), 1, 3, 11, Vector2(600, 90)],      # over his left shoulder: three lines
		[Vector2(70, 270), -1, 2, 21, Vector2(440, 250)],    # by his right cheek
		[Vector2(80, 1560), -1, 3, 31, Vector2(380, 1600)],  # by his right shin
		[Vector2(760, 1660), 1, 2, 41, Vector2(700, 1700)],  # by his left shin
	]
	for nt in notes:
		var o := _p(nt[0])
		var w := 0.26 * fig.size.x
		if int(nt[1]) < 0:
			o.x = maxf(o.x, x0 + 14.0)
		else:
			o.x = minf(o.x, x1 - w - 4.0)
		for ln in int(nt[2]):
			script_line(o + Vector2(0, ln * xh * 3.3), w - ln * w * 0.18, xh, nc, int(nt[3]) + ln, 1.0, false)
		var tick := _p(nt[4])
		var from := o + Vector2(w if int(nt[1]) < 0 else -4.0, -xh * 0.5)
		draw_line(from, tick, Color(MEAT, 0.16), 1.0, true)
		draw_circle(tick, 1.4, Color(MEAT, 0.4))


## A printer's registration mark: a circle and its cross.
func _reg_mark(p: Vector2, r: float) -> void:
	draw_arc(p, r, 0, TAU, 20, Color(MEAT, 0.4), 1.0, true)
	draw_line(p - Vector2(r * 1.8, 0), p + Vector2(r * 1.8, 0), Color(MEAT, 0.4), 1.0)
	draw_line(p - Vector2(0, r * 1.8), p + Vector2(0, r * 1.8), Color(MEAT, 0.4), 1.0)


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
		draw_colored_polygon(PackedVector2Array([p, p + dd * 6 + n * 2.2, p + dd * 6 - n * 2.2]), col)
		draw_line(p + n * 4, p - n * 4, col, 1.0)
