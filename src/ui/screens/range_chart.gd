class_name RangeChart
extends Control
## The Armory's overlaid effective-range plot: hit chance against distance for the stored weapon
## (THIS, gold: the selected item) and the one in the slot (NOW, cyan), for the selected crew
## member. Curves come from RangeCurve (monotone fit through the book's range-table steps; the
## exact steps are drawn faintly behind). Autofire, where the weapon has it, is a dashed line in
## the same colour. A curve ends where the weapon runs out of range, with a drop line and a cap.
##
## X axis in band space (RangeCurve.band_u): every range band gets the same width, labelled at the
## book's band edges in metres. It reads like a log axis (the bands double) but starts at 0 m, so a
## pistol's close bands aren't crushed the way a linear 0-800 m axis would crush them.

const PAD_L := 30.0
const PAD_R := 8.0
const PAD_T := 24.0
const PAD_B := 16.0
const FONT_SIZE := 12

## [{tag ("THIS"/"NOW"), colour, width (px, default 2), data (RangeCurve.for_weapon)}]
var series: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(150, 96)


func set_series(s: Array) -> void:
	series = s
	queue_redraw()


## The furthest band-space x any curve reaches (at least the first two bands).
func x_max() -> float:
	var u := 2.0
	for s in series:
		for mode in ["single", "autofire"]:
			if (s.data as Dictionary).has(mode):
				u = maxf(u, float(s.data[mode].end_u))
	return ceilf(u)


func _plot() -> Rect2:
	return Rect2(PAD_L, PAD_T, maxf(10.0, size.x - PAD_L - PAD_R), maxf(10.0, size.y - PAD_T - PAD_B))


func _to_px(r: Rect2, u: float, p: float, umax: float) -> Vector2:
	return Vector2(r.position.x + r.size.x * u / umax, r.position.y + r.size.y * (1.0 - p))


func _draw() -> void:
	var font: Font = Hud.F_BOLD if Hud.F_BOLD else get_theme_default_font()
	var r := _plot()
	var umax := x_max()
	var grid := Color(Hud.DIM, 0.16)
	var axis := Color(Hud.DIM, 0.55)
	draw_rect(r, Color(0.0, 0.0, 0.0, 0.25))
	# y gridlines every 25 %, labelled at 0, 50 and 100
	for i in 5:
		var p := i * 0.25
		var y := _to_px(r, 0, p, umax).y
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), axis if i == 0 else grid, 1.0)
		if i % 2 == 0:
			_text(font, "%d%%" % int(p * 100), Vector2(r.position.x - 4, y), Hud.DIM, HORIZONTAL_ALIGNMENT_RIGHT)
	# x gridlines at the band edges, labelled in metres
	# (the last label carries the unit and is right-aligned; a label that would touch the one
	# before it is skipped, the gridline stays)
	var edges := RangeCurve.edges()
	var ty := r.end.y + 2 + FONT_SIZE * 0.5
	var right := r.position.x + _text(font, "0", Vector2(r.position.x, ty), Hud.DIM, HORIZONTAL_ALIGNMENT_CENTER) / 2
	var last_l := r.end.x - font.get_string_size("%d m" % int(edges[int(umax) - 1]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	for i in int(umax):
		var x := _to_px(r, i + 1, 0, umax).x
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), grid, 1.0)
		var last := i + 1 == int(umax)
		var lbl := str(int(edges[i])) + (" m" if last else "")
		var w := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
		var lo := x - w if last else x - w / 2
		if last or (lo > right + 4 and lo + w < last_l - 4):
			_text(font, lbl, Vector2(x, ty), Hud.DIM, HORIZONTAL_ALIGNMENT_RIGHT if last else HORIZONTAL_ALIGNMENT_CENTER)
			right = lo + w
	# curves: faint table steps, then the fitted curve, then the out-of-range mark
	for s in series:
		var col: Color = s.colour
		for mode in ["single", "autofire"]:
			if not (s.data as Dictionary).has(mode):
				continue
			var d: Dictionary = s.data[mode]
			var steps: PackedFloat32Array = d.steps
			var end_u := float(d.end_u)
			for i in steps.size():
				var a := float(i)
				var b := minf(float(i + 1), end_u)
				if a >= end_u:
					break
				draw_line(_to_px(r, a, steps[i], umax), _to_px(r, b, steps[i], umax), Color(col, 0.22), 1.0)
			var pts := PackedVector2Array()
			for q in (d.points as PackedVector2Array):
				pts.append(_to_px(r, q.x, q.y, umax))
			if pts.size() < 2:
				continue
			# THIS is drawn first and wider, so where the two weapons match its gold edges NOW's cyan
			var w := float(s.get("width", 2.0))
			if mode == "autofire":
				_dashed(pts, col, w)
			else:
				draw_polyline(pts, col, w, true)
			var end := pts[pts.size() - 1]
			draw_dashed_line(end, Vector2(end.x, r.end.y), Color(col, 0.6), 1.0, 3.0)
			draw_rect(Rect2(end - Vector2(3, 3), Vector2(6, 6)), col)
	# legend along the top: THIS / NOW (a melee weapon gets its reach instead of a curve)
	var x := r.position.x
	var ly := 7.0
	var any_auto := false
	for s in series:
		var col: Color = s.colour
		var melee := bool(s.data.get("melee", false))
		any_auto = any_auto or (s.data as Dictionary).has("autofire")
		if not melee:
			draw_line(Vector2(x, ly), Vector2(x + 12, ly), col, 2.0)
			x += 16
		var t := "%s%s" % [s.tag, ": MELEE 2 M" if melee else ""]
		x += _text(font, t, Vector2(x, ly), col, HORIZONTAL_ALIGNMENT_LEFT) + 12
	if any_auto:
		_dashed(PackedVector2Array([Vector2(x, ly), Vector2(x + 14, ly)]), Hud.DIM, 2.0)
		_text(font, "AUTOFIRE", Vector2(x + 18, ly), Hud.DIM, HORIZONTAL_ALIGNMENT_LEFT)
	if series.all(func(s): return bool(s.data.get("melee", false))):
		_text(font, "MELEE: 2 M", r.get_center(), Hud.DIM, HORIZONTAL_ALIGNMENT_CENTER)


## Text centred vertically on `at.y`; returns its width.
func _text(font: Font, s: String, at: Vector2, col: Color, align: HorizontalAlignment) -> float:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var x := at.x
	if align == HORIZONTAL_ALIGNMENT_RIGHT:
		x -= w
	elif align == HORIZONTAL_ALIGNMENT_CENTER:
		x -= w / 2
	var y := at.y + (font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) / 2
	draw_string(font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, col)
	return w


## A dashed polyline (dashes measured along the curve).
func _dashed(pts: PackedVector2Array, col: Color, width: float, dash := 6.0, gap := 4.0) -> void:
	var on := true
	var left := dash
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var t := 0.0
		while t < seg:
			var step := minf(left, seg - t)
			var p0 := a.lerp(b, t / seg)
			var p1 := a.lerp(b, (t + step) / seg)
			if on:
				draw_line(p0, p1, col, width, true)
			t += step
			left -= step
			if left <= 0.0:
				on = not on
				left = dash if on else gap
