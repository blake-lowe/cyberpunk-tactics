class_name BodyAnatomy
extends Control
## The cyberware figure (ChromeBody's): a real anatomical plate as light on the dark page (owner, on an
## early prototype: "This diagram feel looks good... I very much like the horizontal glitch
## fuzziness. Maybe a free online skeletal muscle diagram"; then, on this one: "Let's take that going
## forward"). Two plates, chosen by the crew member's body (ChromeBody.plate_of):
## - male: Thomas Milton's standing écorché, front view (Rees's Cyclopaedia, Anatomy Plate VIII, 1804),
##   with Plate X (the same man a layer deeper, to the bones) warped onto him
##   (assets/third_party/anatomy/README.md);
## - female: Andrew Bell's superficial anatomy of the woman, front view (Encyclopaedia Britannica, 3rd
##   ed., after Bidloo, 1798), her raised left arm lowered (bent at the elbow and wrist), with Bell's
##   skeleton of a woman from the same edition warped onto her (assets/third_party/anatomy_female/README.md).
## Either is always shown as the hybrid (owner: "aesthetically I prefer the look of the skeletal hybrid
## images... drop the skin on versions and baseline both"): the skeleton everywhere with the body a faint
## engraving over it (SKIN). The engraving's lines glow cyan, its hatching a faint tone, under a
## horizontal glitch fuzz (body_anatomy.gdshader). Round the figure, redrawn crisp: a height scale in
## heads, the proportion levels, a centre line and registration marks (owner, playtest: the asemic
## notes and the navel's crosshair are gone). Each body region (bones laid over the plate) takes its
## tint (ChromeBody.region_tints): chrome violet, its bones barer and brighter, with a circuit spine on
## a limb; the selected location gold; external chrome (shell) a dermal mesh. The glitch grows as
## Humanity falls (`psycho`, ChromeBody.glitch_of: owner, playtest: "crazy cyberpsycho effects" at low
## Humanity, a little fuzz at full). A click on the figure picks the nearest location. Motion (the
## glitch, a scan line, a pulse on the selected place) stops under reduced motion; the glitch's
## strength then shows as a still distortion.

const MEAT := Color("05d9e8")   ## Hud.CYAN
const SHADER := preload("res://src/ui/screens/body_anatomy.gdshader")
const LINE := Color(0.02, 0.85, 0.91, 0.5)
## The surface plate's share of the print over the skeleton (the shader's `skin`): a faint body.
const SKIN := 0.22

## Each plate's geometry, in its ink texture's pixels (tools/gen_anatomy_ink.py): the crown (the top
## of the head), the soles (the heels' line), the chin, the centre line's x, the navel; the bones laid
## over it by hand, [from, to, reach (px), region] (the figure faces us: their right is on the
## viewer's left; the eyes and the ear come first: inside their reach they win over the head, as in
## region_at and the shader); where each location's leader line meets the body (placed so the cards'
## pair rows, ChromeBody.ROWS, run top to bottom on both sides with no leader lines crossing: the
## Chipware Socket at the neck beside the Fashionware's light tattoo at the collarbone, the External
## Cyberware on the flank's skin beside the Internal Cyberware's core in the chest); and the
## proportion levels (crown, chin, nipples, navel, crotch, knees, soles).
const PLATES := {
	"male": {
		"ink": preload("res://assets/third_party/anatomy/anatomy_ink.png"),
		"size": Vector2(1024, 2048), "crown": 9.0, "sole": 1990.0, "chin": 262.0, "axis": 524.0, "navel": Vector2(529, 786),
		"bones": [
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
			# his left arm (the forearm and hand: L_FORE, tinted as the arm)
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
		],
		"anchors": {"neural_link": Vector2(522, 40), "right_eye": Vector2(448, 150), "left_eye": Vector2(534, 147),
			"cyberaudio": Vector2(610, 128), "chipware": Vector2(531, 312), "internal": Vector2(540, 560),
			"right_arm": Vector2(262, 700), "left_arm": Vector2(800, 680),
			"fashion": Vector2(620, 350), "external": Vector2(420, 600), "right_leg": Vector2(421, 1660),
			"left_leg": Vector2(672, 1660)},
		"levels": [9.0, 262.0, 515.0, 786.0, 1060.0, 1488.0, 1990.0],
	},
	"female": {
		"ink": preload("res://assets/third_party/anatomy_female/anatomy_female_ink.png"),
		"size": Vector2(882, 2048), "crown": 25.5, "sole": 2001.0, "chin": 258.7, "axis": 441.0, "navel": Vector2(445, 775),
		"bones": [
			[Vector2(429, 159), Vector2(434, 159), 13.4, ChromeBody.Reg.R_EYE],
			[Vector2(492, 177), Vector2(497, 177), 13.4, ChromeBody.Reg.L_EYE],
			[Vector2(534, 178), Vector2(535, 196), 16.1, ChromeBody.Reg.EAR],   # her left ear, under the hair
			[Vector2(417, 51), Vector2(447, 236), 99.2, ChromeBody.Reg.HEAD],
			[Vector2(437, 272), Vector2(433, 339), 53.6, ChromeBody.Reg.NECK],
			[Vector2(434, 373), Vector2(443, 734), 201.0, ChromeBody.Reg.TORSO],
			[Vector2(443, 734), Vector2(443, 989), 167.5, ChromeBody.Reg.TORSO],
			# her right arm (the viewer's left, down by her side, the hand at her hip holding the drape)
			[Vector2(276, 420), Vector2(268, 741), 34.8, ChromeBody.Reg.R_ARM],
			[Vector2(268, 741), Vector2(186, 996), 32.2, ChromeBody.Reg.R_ARM],
			[Vector2(186, 996), Vector2(132, 1080), 50.9, ChromeBody.Reg.R_ARM],
			# her left arm, lowered (tools/gen_anatomy_ink.py, F_ARM_TURNS: the forearm and hand hang by
			# her side; L_FORE, tinted as the arm)
			[Vector2(595, 393), Vector2(716, 583), 40.2, ChromeBody.Reg.L_ARM],
			[Vector2(716, 583), Vector2(783, 775), 34.8, ChromeBody.Reg.L_FORE],
			[Vector2(783, 775), Vector2(785, 915), 53.6, ChromeBody.Reg.L_FORE],
			# legs: thigh, shin, foot
			[Vector2(356, 1029), Vector2(398, 1405), 93.8, ChromeBody.Reg.R_LEG],
			[Vector2(398, 1405), Vector2(443, 1827), 53.6, ChromeBody.Reg.R_LEG],
			[Vector2(443, 1840), Vector2(397, 1994), 53.6, ChromeBody.Reg.R_LEG],
			[Vector2(552, 1029), Vector2(504, 1421), 93.8, ChromeBody.Reg.L_LEG],
			[Vector2(504, 1421), Vector2(544, 1834), 53.6, ChromeBody.Reg.L_LEG],
			[Vector2(544, 1847), Vector2(595, 1961), 53.6, ChromeBody.Reg.L_LEG],
		],
		"anchors": {"neural_link": Vector2(414, 46), "right_eye": Vector2(431, 159), "left_eye": Vector2(494, 177),
			"cyberaudio": Vector2(535, 166), "chipware": Vector2(434, 308), "internal": Vector2(440, 500),
			"right_arm": Vector2(271, 600), "left_arm": Vector2(695, 550),
			"fashion": Vector2(510, 350), "external": Vector2(350, 560), "right_leg": Vector2(415, 1606),
			"left_leg": Vector2(525, 1622)},
		"levels": [25.5, 258.7, 513.3, 774.7, 1022.7, 1404.6, 2001.0],
	},
}

var body: ChromeBody
var plate := "male"        ## a PLATES key
var motion := true
var psycho := 0.0          ## the glitch's strength, 0 (full Humanity: a little fuzz) to 1 (ChromeBody.glitch_of)
var tints: Array = []      ## per region (ChromeBody.Reg): [Color (a = how much), plated 0/1]
var shell := Color(0, 0, 0, 0)
var fig := Rect2()         ## the figure's frame
var stage := Rect2()       ## the open space between the card columns
var _press := Vector2(-1, -1)
var _ink: TextureRect
var _mat: ShaderMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = false


func geo() -> Dictionary:
	return PLATES[plate]


## The body region at a point of a plate (texture pixels), as the shader finds it: an eye or the ear
## inside its reach, else the bone nearest as a fraction of its reach.
static func region_at(p: Vector2, pl := "male") -> int:
	var best := INF
	var reg := ChromeBody.Reg.TORSO
	for b in PLATES[pl].bones:
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


## The figure frame's width over its height.
func aspect() -> float:
	var s: Vector2 = geo().size
	return s.x / s.y


## A location's anchor in the frame, as fractions of its width and height.
func anchor_uv(loc: String) -> Vector2:
	return (geo().anchors.get(loc, geo().navel) as Vector2) / (geo().size as Vector2)


func anchor(loc: String) -> Vector2:
	return fig.position + anchor_uv(loc) * fig.size


func place(p_fig: Rect2, p_stage: Rect2) -> void:
	fig = p_fig
	stage = p_stage
	_build()
	_ink.position = fig.position
	_ink.size = fig.size
	_mat.set_shader_parameter("px", Vector2(1.0 / maxf(fig.size.x, 1.0), 1.0 / maxf(fig.size.y, 1.0)))
	queue_redraw()


## Whether a region is the selected location's (its tint is gold).
func region_selected(r: int) -> bool:
	if r < 0 or r >= tints.size():
		return false
	var t: Color = tints[r][0]
	return t.a > 0.0 and absf(t.r - Hud.GOLD.r) < 0.01 and absf(t.g - Hud.GOLD.g) < 0.01


func _ready() -> void:
	_build()


func _build() -> void:
	if _ink:
		return
	var g := geo()
	var sz: Vector2 = g.size
	_ink = TextureRect.new()
	_ink.name = "Ink"
	_ink.texture = g.ink
	_ink.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ink.stretch_mode = TextureRect.STRETCH_SCALE
	_ink.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_ink.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	var segs := PackedVector4Array()
	var segp := PackedVector4Array()
	for b in g.bones:
		var a: Vector2 = b[0] / sz
		var e: Vector2 = b[1] / sz
		segs.append(Vector4(a.x, a.y, e.x, e.y))
		var small := int(b[3]) in [ChromeBody.Reg.R_EYE, ChromeBody.Reg.L_EYE, ChromeBody.Reg.EAR]
		segp.append(Vector4(float(b[2]) / sz.x, float(b[3]), 1.0 if small else 0.0, 0))
	var cols := PackedColorArray()
	var plated := PackedFloat32Array()
	var sel := -1
	for r in tints.size():
		cols.append(tints[r][0])
		plated.append(float(tints[r][1]))
		if sel < 0 and region_selected(r):
			sel = r
	_mat.set_shader_parameter("segs", segs)
	_mat.set_shader_parameter("segp", segp)
	_mat.set_shader_parameter("nseg", (g.bones as Array).size())
	_mat.set_shader_parameter("aspect", aspect())
	_mat.set_shader_parameter("tints", cols)
	_mat.set_shader_parameter("plated", plated)
	_mat.set_shader_parameter("meat", MEAT)
	_mat.set_shader_parameter("skin", SKIN)
	_mat.set_shader_parameter("shell", shell)
	_mat.set_shader_parameter("motion", 1.0 if motion else 0.0)
	_mat.set_shader_parameter("psycho", clampf(psycho, 0.0, 1.0))
	_mat.set_shader_parameter("selected", sel)
	_ink.material = _mat
	add_child(_ink)


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


# --- The page round the figure ----------------------------------------------------------------

## Texture pixels → this control.
func _p(v: Vector2) -> Vector2:
	return fig.position + v / (geo().size as Vector2) * fig.size


func _y(ty: float) -> float:
	return fig.position.y + ty / float(geo().size.y) * fig.size.y


func _draw() -> void:
	if fig.size.x <= 0:
		return
	var g := geo()
	var font := Hud.F_MONO if Hud.F_MONO else get_theme_default_font()
	var top := _y(g.crown)
	var sole := _y(g.sole)
	var tall := sole - top
	var head := _y(g.chin) - top
	var x0 := maxf(stage.position.x + 6.0, fig.position.x - 46.0)   # the scale's rail
	var x1 := minf(stage.end.x - 6.0, fig.end.x + 46.0)             # the levels' far end
	var ax := _p(Vector2(g.axis, 0)).x
	# the page's grid behind the figure: faint, a head square
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
	# the height scale: a rail at their right, ticked in eighths of a head, numbered in heads
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
	# the proportion levels: dashed across, the fraction of the height at the far end
	for lv: float in g.levels:
		var ly := _y(lv)
		_dashed(Vector2(x0 + 12, ly), Vector2(x1, ly), Color(MEAT, 0.19), 5.0, 5.0)
		draw_line(Vector2(x1 - 8, ly), Vector2(x1, ly), Color(MEAT, 0.5), 1.0)
		var frac := (sole - ly) / tall
		draw_string(font, Vector2(x1 - 30, ly - 3), "%.3f" % frac if frac < 0.999 else "1.000", HORIZONTAL_ALIGNMENT_RIGHT, 30, 9, Color(MEAT, 0.45))
	# the centre line
	_dashed(Vector2(ax, top - 16), Vector2(ax, sole + 10), Color(MEAT, 0.12), 3.0, 4.0)
	# the height, crown to sole, beside the levels' numbers
	var hx := x1 + 2.0
	if hx < stage.end.x - 2.0:
		_dim(Vector2(hx, top), Vector2(hx, sole), Color(MEAT, 0.32))
	# registration marks at the plate's corners, a little off
	var fr := Rect2(Vector2(x0 - 2, top - 10), Vector2(x1 - x0 + 4, tall + 20))
	for p in [fr.position, Vector2(fr.end.x, fr.position.y), fr.end, Vector2(fr.position.x, fr.end.y)]:
		_reg_mark(p, 5.0)


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

