class_name CityMap
extends Control
## The CITY tab's schematic of Night City (M9 P3), drawn from data/world/city.json `map`: our own
## stylised trace, not the book's map art. Dark land, near-black hatched water; each district a
## neutral, cyan-edged polygon named by its label (under its anchor where there's room, else a
## callout in the gutter beside the city with a leader line); bridges as double strokes. No
## security or faction information (owner playtest: a clean map with names).
## The crew's safehouse is a white house. With a gig selected (`select_gig`) the map plots the drive
## from the safehouse district to the gig's district (Travel.route: the quickest chain of
## neighbouring districts), pins the gig as a gold diamond and animates the route: a line that
## draws itself through the districts crossed with a marker running along it, over ROUTE_TIME s
## (a Tween on `route_t`), then the drive time (Travel.label) beside the pin.
## Hover only highlights (a redraw; nothing resizes). Emits `clicked` on a click.

signal clicked(kind: String, id: String)   ## kind: "district", "pin" (id = board index) or "" (nothing)

const PAD := 12.0            ## world units round the city in the fitted view
const GUTTER := 175.0        ## px kept free either side of the city for callout labels
const NAME_SIZE := 12
const LABEL_H := 17.0
const PIN := 7.0             ## pin half-size, px
const ROUTE_TIME := 1.0      ## s for the route to draw itself
const LAND := Color("111820")
const WATER := Color("04070b")
const COAST := Color(0.02, 0.85, 0.91, 0.35)
const INK_DARK := Color("05080c")
const FILL := Color("18222d")
const EDGE := Color(0.02, 0.85, 0.91, 0.55)

var camp: Campaign
var hover_kind := ""
var hover_id := ""
var gig := -1             ## the selected board index (-1: none, the map shows only the safehouse)
var route: Array[String] = []        ## the districts the drive crosses, safehouse first
var route_t := 1.0:       ## how much of the route is drawn (0..1); the Tween runs it
	set(v):
		route_t = v
		queue_redraw()
var scale_px := 1.0       ## px per world unit
var origin := Vector2.ZERO
var labels := {}          ## district id → {rect: Rect2, anchor: Vector2 (px), align: -1/0/1, callout: bool}
var pins: Array[Dictionary] = []   ## the selected gig's pin: {index, district, pos: Vector2 (local px)}
var homes: Array[Vector2] = []     ## the safehouse marker
var safehouse := ""       ## the crew's safehouse district, if the campaign has one
var _polys := {}          ## district id → PackedVector2Array (local px)
var _fills := {}          ## district id → Array[PackedVector2Array] (pieces the renderer can fill)
var _water: Array[PackedVector2Array] = []
var _hatch: Array[PackedVector2Array] = []
var _route_px := PackedVector2Array()   ## the route in local px: house, the districts' anchors, pin
var _tw: Tween
var _laid_for := Vector2.ZERO


func setup(p_camp: Campaign) -> CityMap:
	camp = p_camp
	var sh: Variant = camp.get("safehouse_district") if camp else null
	safehouse = String(sh) if sh is String and World.districts().has(String(sh)) else ""
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(func(): layout(); queue_redraw())
	return self


## Plot board offer `i` (-1 clears it): its route from the safehouse, its pin, and the animation
## from the start (a new pick restarts it).
func select_gig(i: int) -> void:
	gig = i if camp and i >= 0 and i < camp.board.size() else -1
	route.clear()
	if gig >= 0 and safehouse != "":
		route = Travel.route(safehouse, String(camp.board[gig].get("district", "")))
	_place_marks()
	if _tw:
		_tw.kill()
		_tw = null
	if gig >= 0 and is_inside_tree():
		route_t = 0.0
		_tw = create_tween()
		_tw.tween_property(self, "route_t", 1.0, ROUTE_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		route_t = 1.0
	queue_redraw()


## The drive's polyline in map (world) units: the anchor of each district Travel.route crosses,
## from `from` to `to` ([] when there's no route; one point when they're the same district).
static func route_points(from: String, to: String) -> PackedVector2Array:
	var out := PackedVector2Array()
	for d in Travel.route(from, to):
		out.append(anchor(d))
	return out


## The first `t` (0..1) of a polyline by length: the part drawn so far, its last point the marker.
static func trace(pts: PackedVector2Array, t: float) -> PackedVector2Array:
	if pts.size() < 2 or t >= 1.0:
		return pts
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var left := maxf(0.0, t) * total
	var out := PackedVector2Array([pts[0]])
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if left <= seg:
			if left > 0.0:
				out.append(pts[i].lerp(pts[i + 1], left / seg))
			return out
		left -= seg
		out.append(pts[i + 1])
	return out




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


## The safehouse and the selected gig's pin just above their district's anchor (side by side when
## they share one), and the route between them in local px. Labels don't depend on these: every
## anchor keeps room for its marks (`_mark_zone`), so a new pick never moves a label.
func _place_marks() -> void:
	pins.clear()
	homes.clear()
	_route_px = PackedVector2Array()
	if _polys.is_empty():
		return
	var per: Dictionary = {}
	if safehouse != "":
		per[safehouse] = [-1]
	if gig >= 0:
		var d := String(camp.board[gig].get("district", ""))
		if World.districts().has(d):
			if not per.has(d):
				per[d] = []
			(per[d] as Array).append(gig)
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
	if route.is_empty() or homes.is_empty() or pins.is_empty():
		return
	_route_px.append(homes[0])
	for k in range(1, route.size() - 1):
		_route_px.append(to_local_px(anchor(route[k])))
	_route_px.append(pins[0].pos)


## The room a district's anchor keeps for the safehouse and a gig pin above it.
static func _mark_zone(a: Vector2) -> Rect2:
	return Rect2(a + Vector2(-PIN * 2 - 3, -PIN * 2 - 6), Vector2(PIN * 4 + 6, PIN * 2 + 10))


## Labels: a district's label goes just under its anchor (else just above) when it fits inside the
## city's span without covering another label, anchor or pin, biggest districts first; the rest
## become callouts in the gutters beside the city (west of the centre to the left), like a
## schematic's key: each leader ends inside its own district (its centre, else the nearest point
## whose line clears the labels in the city), the column is stacked in that order, and two labels
## whose leaders cross swap places.
func _place_labels() -> void:
	labels.clear()
	var nf := Hud.F_BOLD
	var cr := city_rect().grow(-PAD)
	var span := Rect2(to_local_px(cr.position), cr.size * scale_px)
	var obstacles: Array[Rect2] = []
	for id in city_map().districts:
		if id != "outskirts":
			obstacles.append(_mark_zone(to_local_px(anchor(String(id)))))
	var placed: Array[Rect2] = []
	var callouts := {-1: [], 1: []}
	var view := Rect2(Vector2(4, 30), size - Vector2(8, 30 + 8))
	for id in draw_order():
		var w := nf.get_string_size(district_name(id), HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x + 10
		var sz := Vector2(w, LABEL_H)
		var a := to_local_px(anchor(id))
		if id == "outskirts":   # the land round the city: bottom right, clear of everything
			var r := Rect2(size - sz - Vector2(10, 10), sz)
			labels[id] = {"rect": r, "anchor": a, "align": 0, "callout": false}
			placed.append(r)
			continue
		var above := PIN * 2 + 10
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
		var col_x := (span.position.x - 20) if side < 0 else (span.end.x + 20)   # knees clear of in-city labels (up to 6 px past the span)
		for it in items:   # each leader ends inside its own district, clear of the labels in the city
			var aim := _leader_target(String(it[0]), Vector2(col_x, (it[2] as Vector2).y), placed)
			it[2] = aim[0]
			it.append(aim[1])
		items.sort_custom(func(p, q): return (p[2] as Vector2).y < (q[2] as Vector2).y)
		var top := 34.0 if side < 0 else 44.0
		var bottom := size.y - (12.0 if side < 0 else LABEL_H + 22.0)   # clear of the Outskirts (right)
		var tops: Array[float] = []
		var prev := top - 3
		for it in items:   # down the column in target order, then pulled back up from the bottom
			var t := maxf((it[2] as Vector2).y - LABEL_H / 2, prev + 3)
			tops.append(t)
			prev = t + LABEL_H
		var nxt := bottom + 3
		for k in range(items.size() - 1, -1, -1):
			tops[k] = maxf(top, minf(tops[k], nxt - 3 - LABEL_H))
			nxt = tops[k]
		var rects: Array[Rect2] = []
		for k in items.size():
			var sz: Vector2 = items[k][1]
			var x := (col_x - sz.x) if side < 0 else col_x
			x = clampf(x, 6, size.x - sz.x - 6)
			rects.append(Rect2(Vector2(x, tops[k]), sz))
		_untangle(items, rects, side, placed)
		for pass_i in 4:   # the labels settled where they could: re-aim any leader that runs through a label or crosses another
			var moved := false
			for k in items.size():
				var l := leader(rects[k], side, items[k][2], items[k][3])
				var others: Array[PackedVector2Array] = []
				for j in items.size():
					if j != k:
						others.append(leader(rects[j], side, items[j][2], items[j][3]))
				if _path_hits(l.slice(1), placed) or others.any(func(o): return _leaders_cross(l, o)):
					var aim := _leader_target(String(items[k][0]), l[1], placed, others)
					items[k][2] = aim[0]
					items[k][3] = aim[1]
					moved = true
			if not moved:
				break
			_untangle(items, rects, side, placed)
		for k in items.size():
			labels[items[k][0]] = {"rect": rects[k], "anchor": items[k][2], "via": items[k][3], "align": side, "callout": true}


## Does a polyline run through any of `rects` (grown 2 px)?
static func _path_hits(path: PackedVector2Array, rects: Array[Rect2]) -> bool:
	for i in path.size() - 1:
		if rects.any(func(r): return _seg_hits_rect(path[i], path[i + 1], r.grow(2))):
			return true
	return false


## Where a callout's leader ends, as [target, via]: a point inside the district (sampled on a grid,
## at least 4 px in from its outline) whose line from the gutter (`from`) crosses no label already in
## the city and none of the `avoid` leaders, scored by length plus 1.5x its distance from the
## district's centre. When every straight line is blocked, the path bends round the labels in the
## way (the shortest route through their corners: a visibility graph, Dijkstra from `from`) and
## `via` holds the corners. Else the centre (else the anchor, if the outline is too thin to sample).
func _leader_target(id: String, from: Vector2, placed: Array[Rect2], avoid: Array[PackedVector2Array] = []) -> Array:
	var poly: PackedVector2Array = _polys.get(id, PackedVector2Array())
	if poly.size() < 3:
		return [to_local_px(anchor(id)), []]
	var c := _centroid(poly)
	var cand: Array[Vector2] = []
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	var step := maxf(4.0, minf(box.size.x, box.size.y) / 10.0)
	var y := box.position.y + step / 2
	while y < box.end.y:
		var x := box.position.x + step / 2
		while x < box.end.x:
			var q := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(q, poly) and _inset(q, poly) >= 4.0:
				cand.append(q)
			x += step
		y += step
	if Geometry2D.is_point_in_polygon(c, poly):
		cand.push_front(c)
	if cand.is_empty():
		return [to_local_px(anchor(id)), []]
	cand.sort_custom(func(p, q): return p.distance_to(c) < q.distance_to(c))
	cand = cand.slice(0, 48)
	var blocked := func(a: Vector2, b: Vector2) -> bool:
		if _path_hits(PackedVector2Array([a, b]), placed):
			return true
		var seg := PackedVector2Array([a, b])
		return avoid.any(func(o): return _leaders_cross(seg, o))
	var best_q := Vector2.INF
	var best_s := INF
	for q in cand:
		var s := from.distance_to(q) + 1.5 * q.distance_to(c)
		if s < best_s and not blocked.call(from, q):
			best_s = s
			best_q = q
	if best_q != Vector2.INF:
		return [best_q, []]
	var near := Rect2(from, Vector2.ZERO).expand(c).merge(box).grow(40)
	var nodes: Array[Vector2] = [from]
	for r in placed:
		if r.intersects(near):
			var g := r.grow(5)
			for corner: Vector2 in [g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]:
				if not placed.any(func(o): return o.grow(2).has_point(corner)):
					nodes.append(corner)
	var dist: Array[float] = []
	var prev: Array[int] = []
	var done: Array[bool] = []
	for i in nodes.size():
		dist.append(INF if i > 0 else 0.0)
		prev.append(-1)
		done.append(false)
	for _k in nodes.size():
		var u := -1
		for i in nodes.size():
			if not done[i] and dist[i] < INF and (u < 0 or dist[i] < dist[u]):
				u = i
		if u < 0:
			break
		done[u] = true
		for v in nodes.size():
			if not done[v] and dist[u] + nodes[u].distance_to(nodes[v]) < dist[v] and not blocked.call(nodes[u], nodes[v]):
				dist[v] = dist[u] + nodes[u].distance_to(nodes[v])
				prev[v] = u
	var best := -1
	for q in cand:
		for i in range(1, nodes.size()):
			if dist[i] == INF:
				continue
			var s := dist[i] + nodes[i].distance_to(q) + 1.5 * q.distance_to(c)
			if s < best_s and not blocked.call(nodes[i], q):
				best_s = s
				best = i
				best_q = q
	if best < 0:
		return [cand[0], []]
	var via: Array = []
	var k := best
	while k > 0:
		via.push_front(nodes[k])
		k = prev[k]
	return [best_q, via]


## The area centroid of a polygon (its vertex mean if it has no area).
static func _centroid(poly: PackedVector2Array) -> Vector2:
	var a := 0.0
	var c := Vector2.ZERO
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		var cr := p.cross(q)
		a += cr
		c += (p + q) * cr
	if absf(a) < 1e-3:
		c = Vector2.ZERO
		for p in poly:
			c += p
		return c / poly.size()
	return c / (3.0 * a)


## How far a point inside a polygon is from its outline.
static func _inset(p: Vector2, poly: PackedVector2Array) -> float:
	var d := INF
	for i in poly.size():
		d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])))
	return d


static func _seg_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[i], c[(i + 1) % 4]) != null:
			return true
	return false


## A callout's leader: from the label's inner edge, a short level run to the knee, then straight to
## its target, round a label's corner on the way if `via` holds one. [edge, knee, (via,) target].
static func leader(r: Rect2, align: int, target: Vector2, via: Array = []) -> PackedVector2Array:
	var edge := Vector2(r.end.x + 2 if align < 0 else r.position.x - 2, r.get_center().y)
	var knee := edge + Vector2(-8 if align > 0 else 8, 0)
	var out := PackedVector2Array([edge, knee])
	for p in via:
		out.append(p)
	out.append(target)
	return out


static func _leaders_cross(p: PackedVector2Array, q: PackedVector2Array) -> bool:
	for i in p.size() - 1:
		for j in q.size() - 1:
			if Geometry2D.segment_intersects_segment(p[i], p[i + 1], q[j], q[j + 1]) != null:
				return true
	return false


## Swap the column slots of two callouts whose leaders cross until none do (or it stops helping):
## the labels are all one height, so a swap keeps the column tidy.
func _untangle(items: Array, rects: Array[Rect2], side: int, placed: Array[Rect2]) -> void:
	for pass_i in 12:
		var swapped := false
		for i in items.size():
			for j in range(i + 1, items.size()):
				var li := leader(rects[i], side, items[i][2], items[i][3])
				var lj := leader(rects[j], side, items[j][2], items[j][3])
				if not _leaders_cross(li, lj):
					continue
				var ri := Rect2(Vector2(rects[i].position.x, rects[j].position.y), rects[i].size)
				var rj := Rect2(Vector2(rects[j].position.x, rects[i].position.y), rects[j].size)
				var ni := leader(ri, side, items[i][2], items[i][3])
				var nj := leader(rj, side, items[j][2], items[j][3])
				if _leaders_cross(ni, nj) or _path_hits(ni.slice(1), placed) or _path_hits(nj.slice(1), placed):
					continue
				rects[i] = ri
				rects[j] = rj
				swapped = true
		if not swapped:
			return


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
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h[0] == "pin" else Control.CURSOR_ARROW
	elif ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var h := pick((ev as InputEventMouseButton).position)
		clicked.emit(h[0], h[1])


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		set_hover("", "")


## Hover is a highlight only: a redraw, never a relayout (owner playtest: the old hover rebuilt the
## side panel, whose width changed the map's, which moved the labels under the mouse, and so on).
func set_hover(kind: String, id: String) -> void:
	if kind == hover_kind and id == hover_id:
		return
	hover_kind = kind
	hover_id = id
	queue_redraw()


# --- Drawing --------------------------------------------------------------------------------

func _draw() -> void:
	if _laid_for != size:
		layout()
	if _polys.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), LAND)
	var hov := hover_id if hover_kind == "district" and hover_id != "outskirts" else ""   # the land round the city stays dark
	var dest := String(camp.board[gig].get("district", "")) if gig >= 0 else ""
	for id in draw_order():
		var col := Color("0e141b") if id == "outskirts" else FILL
		if id == hov:
			col = col.lightened(0.08)
		if id in route:
			col = col.lerp(Hud.GOLD, 0.07)
		for piece in _fills[id]:
			draw_colored_polygon(piece, col)
	_draw_grid()
	for id in draw_order():
		var poly := _closed(_polys[id])
		if id == "outskirts":
			draw_polyline(poly, Color(Hud.DIM, 0.3), 1.0, true)
			continue
		draw_polyline(poly, Color(EDGE, 0.15), 5.0, true)
		draw_polyline(poly, EDGE, 1.2, true)
	for id in [hov, dest]:
		if id != "" and _polys.has(id):
			var hi := Hud.GOLD if id == dest else Hud.TEXT
			draw_polyline(_closed(_polys[id]), Color(hi, 0.25), 6.0, true)
			draw_polyline(_closed(_polys[id]), Color(hi, 0.9), 1.6, true)
	for w in _water:
		draw_colored_polygon(w, WATER)
	for seg in _hatch:
		draw_polyline(seg, Color(Hud.CYAN, 0.06), 1.0)
	for w in _water:
		draw_polyline(_closed(w), COAST, 1.0, true)
	_draw_bridges()
	_draw_labels(hov, dest)
	_draw_route()
	_draw_pins()
	_draw_frame()


func _draw_labels(hov: String, dest: String) -> void:
	var nf := Hud.F_BOLD
	for id in labels:   # leaders first, under every label
		var L: Dictionary = labels[id]
		if not L.callout:
			continue
		var on: bool = id == hov or id == dest
		var col := Color(Hud.GOLD, 0.9) if id == dest else (Color(Hud.TEXT, 0.85) if on else Color(Hud.DIM, 0.6))
		draw_polyline(leader(L.rect, int(L.align), L.anchor, L.get("via", [])), col, 1.0, true)
		draw_circle(L.anchor, 2.0, col)
	for id in labels:
		var L: Dictionary = labels[id]
		var r: Rect2 = L.rect
		var on: bool = id == hov or id == dest
		draw_rect(r, Color(0.012, 0.018, 0.026, 0.9 if on else 0.7))
		if on:
			draw_rect(r, Color(Hud.GOLD if id == dest else Hud.TEXT, 0.85), false, 1.0)
		var nm := district_name(id)
		var nw := nf.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE).x
		var x := r.get_center().x - nw / 2
		if L.align < 0:
			x = r.end.x - 5 - nw
		elif L.align > 0:
			x = r.position.x + 5
		var col := Hud.GOLD if id == dest else (Hud.TEXT if id != "outskirts" or on else Hud.DIM)
		draw_string(nf, Vector2(x, r.position.y + 13), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, NAME_SIZE, col)


## The drive so far: a glow and a gold line from the house along the districts' anchors, a marker
## at its head; once it's whole, the drive time beside the pin.
func _draw_route() -> void:
	if _route_px.size() < 2:
		return
	var drawn := trace(_route_px, route_t)
	for p in _route_px:   # the stops to come, faint
		draw_circle(p, 2.0, Color(Hud.GOLD, 0.35))
	if drawn.size() >= 2:
		draw_polyline(drawn, Color(Hud.GOLD, 0.22), 7.0, true)
		draw_polyline(drawn, Hud.GOLD, 2.2, true)
	var head := drawn[drawn.size() - 1]
	if route_t < 1.0:
		draw_circle(head, 7.0, Color(Hud.GOLD, 0.3))
		draw_circle(head, 4.0, Hud.TEXT)
		draw_circle(head, 4.0, INK_DARK, false, 1.0, true)


## The safehouse a white house; the selected gig a gold diamond, its drive time beside it once the
## route has drawn.
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
			Color(Hud.GOLD, 0.3))
		draw_colored_polygon(dia, Hud.GOLD.lightened(0.3) if on else Hud.GOLD)
		draw_polyline(_closed(dia), INK_DARK, 1.0, true)
		if on:
			draw_arc(p, s + 5, 0, TAU, 24, Hud.TEXT, 1.0, true)
		var drive := drive_text()
		if drive != "" and route_t >= 1.0:   # NC2045 p.18: the drive from the safehouse district
			var r := drive_tag_rect(p, nf.get_string_size(drive, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 8)
			draw_rect(r, Color(INK_DARK, 0.92))
			draw_rect(r, Color(Hud.GOLD, 0.7), false, 1.0)
			draw_string(nf, r.position + Vector2(4, 13), drive, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Hud.GOLD)


## Where the drive time goes beside the pin at `p`: right, left, above or below it, the first
## that's inside the view and clear of the labels and the route (else the one covering least).
func drive_tag_rect(p: Vector2, w: float) -> Rect2:
	var h := 18.0
	var g := PIN + 7
	var best := Rect2()
	var best_cost := INF
	for r: Rect2 in [Rect2(p + Vector2(g, -h / 2), Vector2(w, h)), Rect2(p + Vector2(-g - w, -h / 2), Vector2(w, h)),
			Rect2(p + Vector2(-w / 2, -g - h), Vector2(w, h)), Rect2(p + Vector2(-w / 2, g), Vector2(w, h))]:
		var cost := 0.0 if Rect2(Vector2.ZERO, size).encloses(r) else 1e6
		for id in labels:
			cost += (labels[id].rect as Rect2).intersection(r).get_area()
		var rs: Array[Rect2] = [r]
		if _path_hits(_route_px, rs):
			cost += 50.0
		if cost < best_cost:
			best_cost = cost
			best = r
	return best


## The selected gig's drive from the safehouse, "~45 MIN DRIVE" ("" for none).
func drive_text() -> String:
	if gig < 0 or camp == null:
		return ""
	return Travel.label(camp.travel_minutes(camp.board[gig]))


## The terminal frame round the map: corner brackets, title and compass.
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
