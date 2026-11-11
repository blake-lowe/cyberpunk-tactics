class_name BodyFacet
extends BodyArt
## The "facet" cyberware figure: a low-poly mannequin, cut from BodyShape's body into flat facets
## (points inside and along the edge, Delaunay-triangulated, each facet lit by the slope of a dome
## raised over the body). Meat is matte gunmetal with a cyan rim; chrome is polished: violet facets
## reflecting a studio's light (a bright sky, a dark horizon, a strip light), gold for the selected
## location. External chrome edges the whole figure. With motion on, the strip light drifts slowly
## across the facets.

const RG := ChromeBody.Reg
const SPACING := 0.022       ## between the facets' points (body units)
const DOME := 0.055          ## how high the body's dome rises (sets the facets' slopes)
const GUNMETAL := Color(0.19, 0.25, 0.31)
const BODY_H := 0.92         ## the body's share of the frame's height (the floor's reflection below)

static var _mesh: Array = []   ## (mesh())

var _t := 0.0
var _drawn_t := -1.0


func aspect() -> float:
	return BodyShape.ASPECT * BODY_H


func anchor_uv(loc: String) -> Vector2:
	var v: Vector2 = BodyShape.ANCHORS.get(loc, Vector2(0, 0.5))
	return Vector2(0.5 + v.x * BODY_H / aspect(), v.y * BODY_H)


func _process(delta: float) -> void:
	if motion and is_visible_in_tree():
		_t += delta
		if _t - _drawn_t > 0.05:   # the light drifts slowly: twenty redraws a second is plenty
			_drawn_t = _t
			queue_redraw()


func P(v: Vector2) -> Vector2:
	return Vector2(fig.get_center().x, fig.position.y) + v * fig.size.y * BODY_H


# --- The mesh ---------------------------------------------------------------------------------

## The body's distance on a grid (sampled once; read back bilinearly), and the nearest part's region.
const G := 0.008
const GX0 := -0.264
const GY0 := -0.016
static var _gd := PackedFloat32Array()
static var _gr := PackedByteArray()
static var _gw := 0
static var _gh := 0


static func _grid() -> void:
	if not _gd.is_empty():
		return
	_gw = int(ceil(0.528 / G)) + 1
	_gh = int(ceil(1.032 / G)) + 1
	_gd.resize(_gw * _gh)
	_gr.resize(_gw * _gh)
	for j in _gh:
		for i in _gw:
			var sm := BodyShape.sample(Vector2(GX0 + i * G, GY0 + j * G))
			_gd[j * _gw + i] = sm[0]
			_gr[j * _gw + i] = int(sm[1])


static func gdist(p: Vector2) -> float:
	var fx := clampf((p.x - GX0) / G, 0.0, _gw - 1.001)
	var fy := clampf((p.y - GY0) / G, 0.0, _gh - 1.001)
	var i := int(fx)
	var j := int(fy)
	var tx := fx - i
	var ty := fy - j
	var a := lerpf(_gd[j * _gw + i], _gd[j * _gw + i + 1], tx)
	var b := lerpf(_gd[(j + 1) * _gw + i], _gd[(j + 1) * _gw + i + 1], tx)
	return lerpf(a, b, ty)


static func gregion(p: Vector2) -> int:
	var i := clampi(int(round((p.x - GX0) / G)), 0, _gw - 1)
	var j := clampi(int(round((p.y - GY0) / G)), 0, _gh - 1)
	return _gr[j * _gw + i]


## [points, triangles [a, b, c, region, normal], outline edges [a, b]], built once per run.
static func mesh() -> Array:
	if not _mesh.is_empty():
		return _mesh
	_grid()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2077
	var pts := PackedVector2Array()
	# along the edge: where the distance changes sign along the grid's rows and columns
	var edge := PackedVector2Array()
	for j in _gh:
		for i in _gw - 1:
			var d0 := _gd[j * _gw + i]
			var d1 := _gd[j * _gw + i + 1]
			if (d0 < 0.0) != (d1 < 0.0):
				edge.append(Vector2(GX0 + (i + d0 / (d0 - d1)) * G, GY0 + j * G))
	for i in _gw:
		for j in _gh - 1:
			var d0 := _gd[j * _gw + i]
			var d1 := _gd[(j + 1) * _gw + i]
			if (d0 < 0.0) != (d1 < 0.0):
				edge.append(Vector2(GX0 + i * G, GY0 + (j + d0 / (d0 - d1)) * G))
	var espace := SPACING * 0.62
	var cells := {}
	for p in edge:
		_add(pts, cells, p, espace)
	var n_edge := pts.size()
	# inside: a jittered grid, kept off the edge
	var gy := 0.0
	var row := 0
	while gy < 1.0:
		var gx := -0.25 + (SPACING * 0.5 if row % 2 == 1 else 0.0)
		while gx < 0.25:
			var p := Vector2(gx + rng.randf_range(-0.3, 0.3) * SPACING, gy + rng.randf_range(-0.3, 0.3) * SPACING)
			if gdist(p) < -SPACING * 0.45:
				_add(pts, cells, p, SPACING * 0.7)
			gx += SPACING
		gy += SPACING * 0.866
		row += 1
	var tris: Array = []
	var outline: Array = []
	var idx := Geometry2D.triangulate_delaunay(pts)
	for t in range(0, idx.size(), 3):
		var a := pts[idx[t]]
		var b := pts[idx[t + 1]]
		var c := pts[idx[t + 2]]
		if maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a))) > SPACING * 2.6:
			continue
		var ok := true
		for m in [(a + b + c) / 3.0, (a + b) * 0.5, (b + c) * 0.5, (c + a) * 0.5]:
			if gdist(m) > 0.0015:
				ok = false
				break
		if not ok:
			continue
		# the facet's normal: the dome's slope at its centre (so neighbours shade alike and the form
		# reads), nudged a little per facet (so the facets show)
		var ctr := (a + b + c) / 3.0
		var ge := G * 0.5
		var grad := Vector2(gdist(ctr + Vector2(ge, 0)) - gdist(ctr - Vector2(ge, 0)), gdist(ctr + Vector2(0, ge)) - gdist(ctr - Vector2(0, ge))) / (2.0 * ge)
		var hc := sqrt(maxf(0.0, -gdist(ctr)) * DOME)
		var slope := DOME / (2.0 * maxf(hc, 0.012))
		var n := Vector3(grad.x * slope + rng.randf_range(-0.1, 0.1), grad.y * slope + rng.randf_range(-0.1, 0.1), 1.0).normalized()
		tris.append([idx[t], idx[t + 1], idx[t + 2], gregion((a + b + c) / 3.0), n])
		for e in [[idx[t], idx[t + 1]], [idx[t + 1], idx[t + 2]], [idx[t + 2], idx[t]]]:
			if e[0] < n_edge and e[1] < n_edge and gdist((pts[e[0]] + pts[e[1]]) * 0.5) > -0.004:
				outline.append(e)
	_mesh = [pts, tris, outline]
	return _mesh


## Whether `p` is at least `r` from every point so far (a spatial hash of SPACING cells), and if so
## add it.
static func _add(pts: PackedVector2Array, cells: Dictionary, p: Vector2, r: float) -> bool:
	var k := Vector2i(floori(p.x / SPACING), floori(p.y / SPACING))
	var r2 := r * r
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for i: int in cells.get(k + Vector2i(dx, dy), []):
				if pts[i].distance_squared_to(p) < r2:
					return false
	if not cells.has(k):
		cells[k] = []
	cells[k].append(pts.size())
	pts.append(p)
	return true


# --- Drawing ----------------------------------------------------------------------------------

func _draw() -> void:
	if fig.size.y <= 0:
		return
	var m := mesh()
	var pts: PackedVector2Array = m[0]
	var tris: Array = m[1]
	var h := fig.size.y
	# the stage: a light from above, a floor with the figure's shadow
	var foot := P(Vector2(0, 1.0))
	var beam := PackedVector2Array([P(Vector2(-0.16, -0.04)), P(Vector2(0.16, -0.04)), P(Vector2(0.3, 1.0)), P(Vector2(-0.3, 1.0))])
	draw_polygon(beam, PackedColorArray([Color(MEAT, 0.05), Color(MEAT, 0.05), Color(MEAT, 0.0), Color(MEAT, 0.0)]))
	var fl := PackedVector2Array()
	for i in 40:
		var a := TAU * i / 40.0
		fl.append(foot + Vector2(cos(a) * h * 0.2, sin(a) * h * 0.025))
	draw_colored_polygon(fl, Color(0, 0, 0, 0.45))
	fl.append(fl[0])
	draw_polyline(fl, Color(MEAT, 0.25), 1.0, true)
	draw_line(Vector2(stage.position.x + 10, foot.y), Vector2(stage.end.x - 10, foot.y), Color(MEAT, 0.12), 1.0)
	var sweep := sin(_t * 0.35) * 0.35 if motion else 0.0
	# the floor's reflection of the legs, fading down
	for t in tris:
		var a: Vector2 = pts[t[0]]
		var b: Vector2 = pts[t[1]]
		var c: Vector2 = pts[t[2]]
		var top := minf(a.y, minf(b.y, c.y))
		if top < 0.915:
			continue
		var fade := clampf((top - 0.915) / 0.085, 0.0, 1.0) * 0.2
		var col := _shade(t[4], t[3], sweep)
		col.a = fade
		draw_colored_polygon(PackedVector2Array([P(Vector2(a.x, 2.0 - a.y)), P(Vector2(b.x, 2.0 - b.y)), P(Vector2(c.x, 2.0 - c.y))]), col)
	# the facets
	for t in tris:
		var poly := PackedVector2Array([P(pts[t[0]]), P(pts[t[1]]), P(pts[t[2]])])
		var reg: int = t[3]
		draw_colored_polygon(poly, _shade(t[4], reg, sweep))
		poly.append(poly[0])
		draw_polyline(poly, Color(1, 1, 1, 0.04) if region_amount(reg) > 0.0 else Color(MEAT, 0.06), 1.0, true)
	# the outline: a cyan rim, or the skin's chrome
	var shell_on := shell.a > 0.0
	var rim := Color(shell, 1.0) if shell_on else MEAT
	var ra := 0.85 if shell_on else 0.45
	for e in m[2]:
		var p0 := P(pts[e[0]])
		var p1 := P(pts[e[1]])
		draw_line(p0, p1, Color(rim, ra * 0.3), 4.0 if shell_on else 3.0, true)
		draw_line(p0, p1, Color(rim, ra), 1.2, true)
	_eyes()


## A facet's colour: matte gunmetal with a cyan rim (meat), or polished chrome (violet, or gold for
## the selected location) reflecting a studio: bright overhead, a dark horizon, a strip light.
func _shade(n: Vector3, reg: int, sweep: float) -> Color:
	var amt := region_amount(reg)
	var light := Vector3(-0.45, -0.6, 0.66).normalized()
	var dif := clampf(n.dot(light), 0.0, 1.0)
	var rimv := clampf((n.x - 0.35) * 1.6, 0.0, 1.0)   # light from the viewer's right
	var meat := GUNMETAL * (0.3 + 1.05 * dif) + Color(MEAT, 1.0) * rimv * 0.4
	meat.a = 1.0
	if amt <= 0.0:
		return meat
	# chrome: a reflection of the studio by the facet's tilt: the backdrop face on, a bright sky
	# above, a dark band just under the horizon, a strip light to the left (it drifts with motion)
	var env := 0.55
	env += smoothstep(-0.12, -0.6, n.y) * 0.6
	env -= exp(-pow((n.y - 0.16) / 0.09, 2.0)) * 0.32
	env += exp(-pow((n.x + 0.5 + sweep) / 0.1, 2.0)) * 0.85
	env += clampf(n.dot(Vector3(0.3, -0.3, 0.9).normalized()), 0.0, 1.0) * 0.12
	var tint: Color = Color(tints[reg][0], 1.0)
	var lo := Color(tint.r * 0.12, tint.g * 0.06, tint.b * 0.16)
	var v := pow(clampf(env, 0.0, 1.0), 1.25)
	var chrome := lo.lerp(tint, v)
	if env > 0.85:   # the highlight burns toward white
		chrome = chrome.lerp(Color(1, 1, 1), clampf((env - 0.85) * 1.6, 0.0, 0.8))
	chrome.a = 1.0
	return meat.lerp(chrome, clampf(amt * 1.15, 0.0, 1.0))


## The faceless head's eyes: a slit of light, bright where a cybereye is.
func _eyes() -> void:
	for s in [-1.0, 1.0]:
		var reg: int = RG.R_EYE if s < 0 else RG.L_EYE
		var on := region_amount(reg) > 0.0
		var c := region_col(reg) if on else Color(MEAT, 0.45)
		var e := P(Vector2(0.016 * s, 0.058))
		var w := fig.size.y * 0.009
		if on:
			draw_line(e - Vector2(w * 1.5, 0), e + Vector2(w * 1.5, 0), Color(c, 0.3), 4.0, true)
		draw_line(e - Vector2(w, 0), e + Vector2(w, 0), c, 1.6, true)
