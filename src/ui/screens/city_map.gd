class_name CityMap
extends Control
## The CITY tab's schematic of Night City (M9 P3), drawn from data/world/city.json `map`: our own
## stylised trace, not the book's map art. Dark land, near-black hatched water; each district a
## neon-edged polygon tinted by its Security Code (hot red = low, orange = middling, teal to blue =
## high, NC2045 p.7); NCART lines as thin side-by-side paths with station nodes; bridges as double
## strokes. Every district has a two-line label ("WATSON DEVELOPMENT" / "7 · NCPD"): under its
## anchor where there's room, else a callout in the gutter beside the city with a leader line.
## Job offers are gold diamonds at their district (numbered in the board's order); the crew's
## safehouse, when the campaign has one, a white house.
## Emits `hovered` when the thing under the mouse changes, `clicked` on a click.

signal hovered(kind: String, id: String)   ## kind: "district", "pin" (id = board index) or "" (nothing)
signal clicked(kind: String, id: String)

const PAD := 12.0            ## world units round the city in the fitted view
const GUTTER := 175.0        ## px kept free either side of the city for callout labels
const NAME_SIZE := 12
const CODE_SIZE := 11
const LABEL_H := 27.0
const PIN := 7.0             ## pin half-size, px
const LAND := Color("111820")
const WATER := Color("04070b")
const COAST := Color(0.02, 0.85, 0.91, 0.35)
const INK_DARK := Color("05080c")
## Security Code → tint: hot (low codes, danger) through orange to cool teal and blue (safe). The
## bands follow the city data's travel bands (low <= 3, mid 4-5, high >= 6; NC2045 p.18-20). No
## yellow or green in the ramp: gold is the job pins' (and selection's) colour, green is health.
const RAMP := ["ff1f55", "ff2a4c", "ff3b4f", "ff5a3c", "ff7f2a", "ff9a3c", "2fd3bf", "05d9e8", "17b5f2", "3d95ff", "5f7cff"]
const LINES := {"red": ["RED LINE", "ff5470"], "green": ["GREEN LINE", "39f0a0"], "blue": ["BLUE LINE", "3d7bff"],
	"orange": ["ORANGE LINE", "ff9a3c"], "exec_monorail": ["EXEC MONORAIL", "d8dee6"]}
const LINE_OFFSET := {"red": -1.5, "green": -0.5, "blue": 0.5, "orange": 1.5, "exec_monorail": 2.5}
## Faction names too long for a map label.
const SHORT := {"san_luis_obispo_county_sheriff": "SLO SHERIFF", "norcal_cog_military_police": "NORCAL MP",
	"ncu_campus_security": "NCU SECURITY"}

var camp: Campaign
var hover_kind := ""
var hover_id := ""
var locked := ""          ## a clicked district: gold edge, the panel stays on it
var scale_px := 1.0       ## px per world unit
var origin := Vector2.ZERO
var labels := {}          ## district id → {rect: Rect2 (name over code), anchor: Vector2 (px), align: -1/0/1, callout: bool}
var pins: Array[Dictionary] = []   ## {index, district, pos: Vector2 (local px)}
var homes: Array[Vector2] = []     ## the safehouse marker
var safehouse := ""       ## the crew's safehouse district, if the campaign has one
var _polys := {}          ## district id → PackedVector2Array (local px)
var _fills := {}          ## district id → Array[PackedVector2Array] (pieces the renderer can fill)
var _water: Array[PackedVector2Array] = []
var _hatch: Array[PackedVector2Array] = []
var _laid_for := Vector2.ZERO


func setup(p_camp: Campaign) -> CityMap:
	camp = p_camp
	var sh: Variant = camp.get("safehouse_district") if camp else null
	safehouse = String(sh) if sh is String and World.districts().has(String(sh)) else ""
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(func(): layout(); queue_redraw())
	return self


# --- Data -----------------------------------------------------------------------------------

static func city_map() -> Dictionary:
	return RulesDB.world("city.json").get("map", {})


static func outline(id: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in (city_map().districts.get(id, {}) as Dictionary).get("outline", []):
		out.append(Vector2(float(p[0]), float(p[1])))
	return out


static func anchor(id: String) -> Vector2:
	var m: Dictionary = city_map().districts.get(id, {})
	return Vector2(float(m.get("x", 0)), float(m.get("y", 0)))


static func code_of(id: String) -> int:
	return int((World.district(id).get("security_code", {}) as Dictionary).get("n", 5))


static func code_colour(n: int) -> Color:
	return Color(RAMP[clampi(n, 0, RAMP.size() - 1)])


## "NCPD", "WHITEWATER", "SLO SHERIFF": a faction short enough for a map label.
static func short_faction(id: String) -> String:
	if SHORT.has(id):
		return SHORT[id]
	var n := SecurityCode.faction_name(id).to_upper().trim_prefix("THE ")
	var paren := RegEx.create_from_string("\\(([A-Z0-9]+)\\)").search(n)
	if paren:
		return paren.get_string(1)
	if n.length() <= 12:
		return n
	var words := n.split(" ", false)
	return words[0] if words[0].length() >= 4 or words.size() < 2 else words[0] + " " + words[1]


## "7 · NCPD" (the district's Security Code and who holds it).
static func code_line(id: String) -> String:
	var c: Dictionary = World.district(id).get("security_code", {})
	return "%d · %s" % [int(c.get("n", 0)), short_faction(String(c.get("faction", "")))]


static func district_name(id: String) -> String:
	return String(World.district(id).get("name", id)).to_upper()


## The districts biggest first: the drawing order (small districts' edges on top) and the order
## labels claim room.
static func draw_order() -> Array[String]:
	var ids: Array[String] = []
	for id in city_map().districts:
		ids.append(String(id))
	ids.sort_custom(func(a, b): return float(city_map().districts[a].r) > float(city_map().districts[b].r))
	return ids


## The city's extent without the Outskirts (the fitted view), padded.
static func city_rect() -> Rect2:
	var r := Rect2()
	var first := true
	for id in city_map().districts:
		if id == "outskirts":
			continue
		for p in outline(String(id)):
			if first:
				r = Rect2(p, Vector2.ZERO)
				first = false
			r = r.expand(p)
	return r.grow(PAD)


# --- Layout ---------------------------------------------------------------------------------

func to_local_px(w: Vector2) -> Vector2:
	return origin + w * scale_px


func to_world(p: Vector2) -> Vector2:
	return (p - origin) / scale_px


## A point on the box edge runs on far past it, so water and the Outskirts fill the whole control.
static func _bleed(p: Vector2) -> Vector2:
	var b: Dictionary = city_map().get("bounds", {"w": 1000, "h": 1000})
	var q := p
	if p.x <= 0: q.x = -4000
	if p.y <= 0: q.y = -4000
	if p.x >= float(b.w): q.x = float(b.w) + 4000
	if p.y >= float(b.h): q.y = float(b.h) + 4000
	return q


func _local_poly(world: PackedVector2Array, bleed := false) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in world:
		out.append(to_local_px(_bleed(p) if bleed else p))
	return out


## Fit the city to the control (full height, gutters either side for callouts), then place pins
## and labels. Runs on resize; tests call it with a size set.
func layout() -> void:
	_laid_for = size
	if size.x < 10 or size.y < 10:
		return
	var cr := city_rect()
	scale_px = minf(maxf(0.2, size.x - 2 * GUTTER) / cr.size.x, (size.y - 8) / cr.size.y)
	origin = size / 2 - cr.get_center() * scale_px
	_polys.clear()
	_fills.clear()
	for id in city_map().districts:
		var poly := _local_poly(outline(String(id)), String(id) == "outskirts")
		_polys[id] = poly
		_fills[id] = fill_polys(poly)
	_water.clear()
	for w in city_map().get("water", []):
		var pts := PackedVector2Array()
		for p in w:
			pts.append(Vector2(float(p[0]), float(p[1])))
		_water.append(_local_poly(pts, true))
	_hatch.clear()
	var y := 3.0
	while y < size.y:
		var seg := PackedVector2Array([Vector2(-10, y), Vector2(size.x + 10, y)])
		for w in _water:
			for piece in Geometry2D.intersect_polyline_with_polygon(seg, w):
				_hatch.append(piece)
		y += 5.0
	_place_marks()
	_place_labels()


## A polygon as pieces the renderer can fill: itself, or (a coarse outline that folds over itself)
## the pieces Clipper untangles it into.
static func fill_polys(poly: PackedVector2Array) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	if not Geometry2D.triangulate_polygon(poly).is_empty():
		out.append(poly)
		return out
	for piece in Geometry2D.offset_polygon(poly, 0.5):
		if not Geometry2D.triangulate_polygon(piece).is_empty():
			out.append(piece)
	return out


## Job pins (and the safehouse) just above their district's anchor, side by side when several.
func _place_marks() -> void:
	pins.clear()
	homes.clear()
	var per: Dictionary = {}
	if camp:
		for i in camp.board.size():
			var d := String(camp.board[i].get("district", ""))
			if World.districts().has(d):
				if not per.has(d):
					per[d] = []
				(per[d] as Array).append(i)
	if safehouse != "":
		if not per.has(safehouse):
			per[safehouse] = []
		(per[safehouse] as Array).push_front(-1)
	for id in per:
		var marks: Array = per[id]
		var a := to_local_px(anchor(String(id)))
		var step := PIN * 2 + 3
		for k in marks.size():
			var at := a + Vector2((k - (marks.size() - 1) / 2.0) * step, -PIN - 5)
			if int(marks[k]) >= 0:
				pins.append({"index": int(marks[k]), "district": String(id), "pos": at})
			else:
				homes.append(at)


## Labels: a district's label goes just under its anchor (else just above) when it fits inside the
## city's span without covering another label, anchor or pin, biggest districts first; the rest
## become callouts in the gutters beside the city (west of the centre to the left), stacked in
## anchor order with a leader line back to the anchor, like a schematic's key.
func _place_labels() -> void:
	labels.clear()
	var nf := Hud.F_BOLD
	var cr := city_rect().grow(-PAD)
	var span := Rect2(to_local_px(cr.position), cr.size * scale_px)
	var obstacles: Array[Rect2] = []
	for id in city_map().districts:
		if id != "outskirts":
			obstacles.append(Rect2(to_local_px(anchor(String(id))) - Vector2(4, 4), Vector2(8, 8)))
	for pin in pins:
		obstacles.append(Rect2(pin.pos - Vector2(PIN, PIN), Vector2(PIN, PIN) * 2))
	for h in homes:
		obstacles.append(Rect2(h - Vector2(PIN, PIN), Vector2(PIN, PIN) * 2))
	var placed: Array[Rect2] = []
	var callouts := {-1: [], 1: []}
	var view := Rect2(Vector2(4, 30), size - Vector2(8, 30 + 8))
	for id in draw_order():
		var w := maxf(nf.get_string_size(district_name(id), HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x,
			nf.get_string_size(code_line(id), HORIZONTAL_ALIGNMENT_LEFT, -1, CODE_SIZE).x) + 8
		var sz := Vector2(w, LABEL_H)
		var a := to_local_px(anchor(id))
		if id == "outskirts":   # the land round the city: bottom right, clear of everything
			var r := Rect2(size - sz - Vector2(10, 10), sz)
			labels[id] = {"rect": r, "anchor": a, "align": 0, "callout": false}
			placed.append(r)
			continue
		var above := PIN * 2 + 14 if _has_marks(id) else 6.0
		var done := false
		for r in [Rect2(a + Vector2(-w / 2, 6), sz), Rect2(a + Vector2(-w / 2, -above - LABEL_H), sz)]:
			if _fits(r, span, view, placed, obstacles, a):
				labels[id] = {"rect": r, "anchor": a, "align": 0, "callout": false}
				placed.append(r)
				done = true
				break
		if not done:
			var side := -1 if a.x < span.get_center().x else 1
			(callouts[side] as Array).append([id, sz, a])
	for side in callouts:
		var items: Array = callouts[side]
		items.sort_custom(func(p, q): return (p[2] as Vector2).y < (q[2] as Vector2).y)
		var top := 34.0 if side < 0 else 44.0
		var bottom := size.y - (52.0 if side < 0 else LABEL_H + 22.0)
		var tops: Array[float] = []
		var prev := top - 3
		for it in items:   # down the column in anchor order, then pulled back up from the bottom
			var t := maxf((it[2] as Vector2).y - LABEL_H / 2, prev + 3)
			tops.append(t)
			prev = t + LABEL_H
		var nxt := bottom + 3
		for k in range(items.size() - 1, -1, -1):
			tops[k] = maxf(top, minf(tops[k], nxt - 3 - LABEL_H))
			nxt = tops[k]
		for k in items.size():
			var sz: Vector2 = items[k][1]
			var x := (span.position.x - 14 - sz.x) if side < 0 else (span.end.x + 14)
			x = clampf(x, 6, size.x - sz.x - 6)
			labels[items[k][0]] = {"rect": Rect2(Vector2(x, tops[k]), sz), "anchor": items[k][2], "align": side, "callout": true}


func _has_marks(id: String) -> bool:
	return id == safehouse or pins.any(func(p): return p.district == id)


func _fits(r: Rect2, span: Rect2, view: Rect2, placed: Array[Rect2], obstacles: Array[Rect2], own: Vector2) -> bool:
	if not view.encloses(r) or r.position.x < span.position.x - 6 or r.end.x > span.end.x + 6:
		return false
	for p in placed:
		if p.grow(2).intersects(r):
			return false
	for o in obstacles:
		if o.intersects(r) and not o.has_point(own):
			return false
	return true


# --- Hover and clicks -----------------------------------------------------------------------

## What's under a local point: ["pin", "<board index>"], ["district", id] or ["", ""] (water, void).
## A label counts as its district.
func pick(p: Vector2) -> Array:
	for pin in pins:
		if p.distance_to(pin.pos) <= PIN + 3:
			return ["pin", str(pin.index)]
	for id in labels:
		if (labels[id].rect as Rect2).has_point(p):
			return ["district", String(id)]
	for w in _water:
		if Geometry2D.is_point_in_polygon(p, w):
			return ["", ""]
	var best := ""
	var best_r := INF
	for id in _polys:
		if Geometry2D.is_point_in_polygon(p, _polys[id]):
			var r := float(city_map().districts[id].r)
			if r < best_r:
				best_r = r
				best = String(id)
	return ["district", best] if best != "" else ["", ""]


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		var h := pick((ev as InputEventMouseMotion).position)
		set_hover(h[0], h[1])
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h[0] != "" else Control.CURSOR_ARROW
	elif ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var h := pick((ev as InputEventMouseButton).position)
		if h[0] == "district":
			locked = "" if locked == h[1] else String(h[1])
		elif h[0] == "":
			locked = ""
		queue_redraw()
		clicked.emit(h[0], h[1])


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		set_hover("", "")


func set_hover(kind: String, id: String) -> void:
	if kind == hover_kind and id == hover_id:
		return
	hover_kind = kind
	hover_id = id
	queue_redraw()
	hovered.emit(kind, id)


## The district the view is about: the one under the mouse, else the locked one.
func focus() -> String:
	if hover_kind == "district":
		return hover_id
	if hover_kind == "pin" and camp and int(hover_id) < camp.board.size():
		return String(camp.board[int(hover_id)].get("district", ""))
	return locked


# --- Drawing --------------------------------------------------------------------------------

func _draw() -> void:
	if _laid_for != size:
		layout()
	if _polys.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), LAND)
	var f := focus()
	for id in draw_order():
		var on := id == f or id == locked
		var col := Color("17202a") if id == "outskirts" else Color(code_colour(code_of(id)), 0.30 if on else 0.13)
		if id == "outskirts" and not on:
			col = Color("0e141b")
		for piece in _fills[id]:
			draw_colored_polygon(piece, col)
	_draw_grid()
	for id in draw_order():
		var poly := _closed(_polys[id])
		if id == "outskirts":
			draw_polyline(poly, Color(Hud.DIM, 0.3), 1.0, true)
			continue
		var col := code_colour(code_of(id))
		draw_polyline(poly, Color(col, 0.12), 5.0, true)
		draw_polyline(poly, Color(col, 0.75), 1.2, true)
	for id in [f, locked]:
		if id != "" and _polys.has(id):
			var hi := Hud.GOLD if id == locked else code_colour(code_of(id)).lightened(0.4)
			if id == "outskirts" and id != locked:
				hi = Hud.TEXT
			draw_polyline(_closed(_polys[id]), Color(hi, 0.25), 6.0, true)
			draw_polyline(_closed(_polys[id]), hi, 2.0, true)
	for w in _water:
		draw_colored_polygon(w, WATER)
	for seg in _hatch:
		draw_polyline(seg, Color(Hud.CYAN, 0.06), 1.0)
	for w in _water:
		draw_polyline(_closed(w), COAST, 1.0, true)
	_draw_bridges()
	_draw_ncart()
	_draw_labels(f)
	_draw_pins()
	_draw_frame()


static func _closed(p: PackedVector2Array) -> PackedVector2Array:
	var c := p.duplicate()
	if c.size() > 0:
		c.append(c[0])
	return c


## A faint 50-unit survey grid (the terminal look).
func _draw_grid() -> void:
	var step := 50.0 * scale_px
	var col := Color(Hud.CYAN, 0.04)
	var x := fposmod(origin.x, step)
	while x < size.x:
		draw_line(Vector2(x, 0), Vector2(x, size.y), col, 1.0)
		x += step
	var y := fposmod(origin.y, step)
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), col, 1.0)
		y += step


## Bridges: a double stroke across the water between the two districts' nearest edge points.
func _draw_bridges() -> void:
	for b in city_map().get("bridges", []):
		var pa: PackedVector2Array = _polys.get(String(b[0]), PackedVector2Array())
		var pb: PackedVector2Array = _polys.get(String(b[1]), PackedVector2Array())
		if pa.is_empty() or pb.is_empty():
			continue
		var best := [pa[0], pb[0]]
		var bd := INF
		for p in pa:
			var q := _nearest_on(pb, p)
			if p.distance_to(q) < bd:
				bd = p.distance_to(q)
				best = [p, q]
		var a: Vector2 = best[0]
		var c: Vector2 = best[1]
		var dir := (c - a).normalized() if c != a else Vector2.RIGHT
		a -= dir * 4
		c += dir * 4
		var n := dir.orthogonal() * 2.0
		draw_line(a + n, c + n, Color(Hud.TEXT, 0.6), 1.0, true)
		draw_line(a - n, c - n, Color(Hud.TEXT, 0.6), 1.0, true)


static func _nearest_on(poly: PackedVector2Array, p: Vector2) -> Vector2:
	var best := poly[0]
	for i in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		if q.distance_to(p) < best.distance_to(p):
			best = q
	return best


## The NCART lines (p.28) through their districts' anchors in station order, side by side like a
## transit map, with a station node at each stop.
func _draw_ncart() -> void:
	var lines: Dictionary = city_map().get("ncart", {})
	for key in lines:
		var pts := PackedVector2Array()
		for d in lines[key]:
			pts.append(to_local_px(anchor(String(d))))
		pts = _offset(pts, float(LINE_OFFSET.get(key, 0.0)) * 3.0)
		var col := Color(String(LINES.get(key, ["", "c8d0d8"])[1]))
		if key == "exec_monorail":
			for i in pts.size() - 1:
				draw_dashed_line(pts[i], pts[i + 1], Color(col, 0.6), 1.2, 4.0, true, true)
		else:
			draw_polyline(pts, Color(col, 0.16), 4.0, true)
			draw_polyline(pts, Color(col, 0.85), 1.5, true)
		for p in pts:
			draw_circle(p, 2.4, INK_DARK)
			draw_circle(p, 2.4, col, false, 1.1, true)


## The polyline moved sideways by `o` px (a miter at each joint).
static func _offset(pts: PackedVector2Array, o: float) -> PackedVector2Array:
	if is_zero_approx(o) or pts.size() < 2:
		return pts
	var out := PackedVector2Array()
	for i in pts.size():
		var n := Vector2.ZERO
		if i > 0 and pts[i] != pts[i - 1]:
			n += (pts[i] - pts[i - 1]).normalized().orthogonal()
		if i < pts.size() - 1 and pts[i + 1] != pts[i]:
			n += (pts[i + 1] - pts[i]).normalized().orthogonal()
		n = n.normalized() if n.length() > 0.2 else n
		out.append(pts[i] + n * o)
	return out


func _draw_labels(f: String) -> void:
	var nf := Hud.F_BOLD
	for id in labels:   # leaders first, under every label
		var L: Dictionary = labels[id]
		if not L.callout:
			continue
		var r: Rect2 = L.rect
		var a: Vector2 = L.anchor
		var on: bool = id == f or id == locked
		var edge := Vector2(r.end.x + 2 if L.align < 0 else r.position.x - 2, r.get_center().y)
		var knee := edge + Vector2(-8 if L.align > 0 else 8, 0)
		var col := Color(Hud.GOLD, 0.9) if id == locked else (Color(Hud.TEXT, 0.85) if on else Color(Hud.DIM, 0.7))
		draw_polyline(PackedVector2Array([a, knee, edge]), col, 1.0, true)
		draw_circle(a, 2.2, col)
	for id in labels:
		var L: Dictionary = labels[id]
		var r: Rect2 = L.rect
		var on: bool = id == f or id == locked
		var col := code_colour(code_of(id)) if id != "outskirts" else Hud.DIM
		draw_rect(r, Color(0.012, 0.018, 0.026, 0.9 if on else 0.72))
		if on:
			draw_rect(r, Color(Hud.GOLD if id == locked else col, 0.85), false, 1.0)
		elif L.callout:   # a tick in the code colour on the leader's side
			draw_rect(Rect2(Vector2(r.end.x - 2 if L.align < 0 else r.position.x, r.position.y), Vector2(2, r.size.y)), col)
		var nm := district_name(id)
		var cl := code_line(id)
		var nw := nf.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
		var cw := nf.get_string_size(cl, HORIZONTAL_ALIGNMENT_LEFT, -1, CODE_SIZE).x
		var x_n := r.get_center().x - nw / 2
		var x_c := r.get_center().x - cw / 2
		if L.align < 0:
			x_n = r.end.x - 5 - nw
			x_c = r.end.x - 5 - cw
		elif L.align > 0:
			x_n = r.position.x + 5
			x_c = r.position.x + 5
		draw_string(nf, Vector2(x_n, r.position.y + 12), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE,
			Hud.TEXT if id != "outskirts" or on else Hud.DIM)
		draw_string(nf, Vector2(x_c, r.position.y + 24), cl, HORIZONTAL_ALIGNMENT_LEFT, -1, CODE_SIZE, col.lightened(0.15))


## Gold diamonds, numbered in the board's order; the safehouse a white house.
func _draw_pins() -> void:
	var nf := Hud.F_BOLD
	for h in homes:
		var s := PIN
		var house := PackedVector2Array([h + Vector2(0, -s), h + Vector2(s, -1), h + Vector2(s, s), h + Vector2(-s, s), h + Vector2(-s, -1)])
		draw_colored_polygon(house, Hud.TEXT)
		draw_polyline(_closed(house), INK_DARK, 1.0, true)
	for pin in pins:
		var p: Vector2 = pin.pos
		var on := hover_kind == "pin" and int(hover_id) == int(pin.index)
		var s := PIN + (2.0 if on else 0.0)
		var dia := PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)])
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s - 4), p + Vector2(s + 4, 0), p + Vector2(0, s + 4), p + Vector2(-s - 4, 0)]),
			Color(Hud.GOLD, 0.25 if on else 0.14))
		draw_colored_polygon(dia, Hud.GOLD.lightened(0.3) if on else Hud.GOLD)
		draw_polyline(_closed(dia), INK_DARK, 1.0, true)
		var t := str(int(pin.index) + 1)
		var tw := nf.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(nf, p + Vector2(-tw / 2, 4), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK_DARK)
		if on:
			draw_arc(p, s + 5, 0, TAU, 24, Hud.TEXT, 1.0, true)


## The terminal frame round the map: corner brackets, title, compass and the Security Code key.
func _draw_frame() -> void:
	var c := Color(Hud.CYAN, 0.6)
	var k := 14.0
	for corner in [[Vector2(1, 1), Vector2(1, 1)], [Vector2(size.x - 1, 1), Vector2(-1, 1)],
			[Vector2(1, size.y - 1), Vector2(1, -1)], [Vector2(size.x - 1, size.y - 1), Vector2(-1, -1)]]:
		var at: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		draw_line(at, at + Vector2(k * d.x, 0), c, 2.0)
		draw_line(at, at + Vector2(0, k * d.y), c, 2.0)
	var nf := Hud.F_BOLD
	draw_string(nf, Vector2(12, 22), "NIGHT CITY  ·  2045", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Hud.CYAN)
	var n := Vector2(size.x - 20, 16)   # compass
	draw_colored_polygon(PackedVector2Array([n + Vector2(0, -8), n + Vector2(5, 5), n + Vector2(0, 2), n + Vector2(-5, 5)]), Color(Hud.CYAN, 0.8))
	draw_string(nf, n + Vector2(-4, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Hud.CYAN)
	var sw := 14.0   # the key: eleven swatches, hot to safe
	var x0 := 12.0
	var y0 := size.y - 22.0
	draw_string(nf, Vector2(x0, y0 - 6), "SECURITY CODE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Hud.DIM)
	var hs := "HOT › SAFE"
	draw_string(nf, Vector2(x0 + RAMP.size() * (sw + 1) - nf.get_string_size(hs, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, y0 - 6), hs,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(Hud.DIM, 0.8))
	for i in RAMP.size():
		var r := Rect2(Vector2(x0 + i * (sw + 1), y0), Vector2(sw, 13))
		draw_rect(r, Color(code_colour(i), 0.3))
		draw_rect(Rect2(r.position + Vector2(0, 11), Vector2(sw, 2)), code_colour(i))
		var t := str(i)
		var tw := nf.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(nf, Vector2(r.get_center().x - tw / 2, y0 + 10), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Hud.TEXT)
