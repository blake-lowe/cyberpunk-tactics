class_name PathTrace
extends RefCounted
## The move preview's trace (greybox._draw_path) as a polyline that rides just above the squares the
## walker crosses. It was a Catmull-Rom spline through the square centres, which overshot and cut
## straight through steps, floors and walls wherever the path changed storey (owner playtest).
## Here every flat stretch is draped over the walked surface (a kerb or a step is a short vertical
## jog on the lower side of its face), a flight of stairs is climbed along its treads, a ladder goes
## straight up in front of its rungs, a jump arcs over its gap, and the corners are rounded a
## little. Pure maths: the greybox hands in the surface and the stair flights, so it tests headless.

const LIFT := 0.1      ## height of the trace over the surface (and its offset from a riser's face)
const ROUND := 0.09    ## corner rounding radius
const EPS := 0.002
const PARAPET := 0.3   ## a roof edge's parapet (WorldBuilder._roof_clutter: 0.28) a ladder's trace clears


## The trace through `path` (squares, Vector3i x, y, storey).
## `surf.call(x: float, z: float, f: int) -> float`: the height of what you stand on at world (x, z)
## on storey f (a flight of steps rises across its square).
## `flight.call(c: Vector3i) -> Vector2`: the direction a flight of stairs on square c rises in
## (world x, z; it climbs from storey c.z to c.z + 1 across the square), ZERO where there is none.
static func points(path: Array, surf: Callable, flight: Callable, fh: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	if path.size() < 2:
		return out
	var c0: Vector3i = path[0]
	var p := Vector2(c0.x + 0.5, c0.y + 0.5)
	out.append(Vector3(p.x, float(surf.call(p.x, p.y, c0.z)) + LIFT, p.y))
	for i in range(1, path.size()):
		var a: Vector3i = path[i - 1]
		var b: Vector3i = path[i]
		var bc := Vector2(b.x + 0.5, b.y + 0.5)
		var flat := Vector2(b.x - a.x, b.y - a.y).length()
		if flat < 0.5 and a.z != b.z:   # a shaft: stairs (climbed along the flight), a lift or a hatch
			var ctr := Vector2(a.x + 0.5, a.y + 0.5)
			var up: Vector2 = flight.call(Vector3i(a.x, a.y, mini(a.z, b.z)))
			if up == Vector2.ZERO:   # a lift or a hatch: straight up the middle
				_drape(out, p, ctr, a.z, surf)
				_rise(out, ctr, float(surf.call(ctr.x, ctr.y, b.z)) + LIFT)
				p = ctr
			elif b.z > a.z:   # up the flight's treads, then just past its high end (up the back of a flight stacked on it)
				var edge := ctr + up * 0.49
				var top := ctr + up * (0.5 + LIFT)
				_drape(out, p, edge, a.z, surf)
				_line(out, Vector3(top.x, out[-1].y, top.y))
				_rise(out, top, float(surf.call(top.x, top.y, b.z)) + LIFT)
				p = top
			else:   # down: from just past the flight's high end onto its top tread, then down the treads
				var edge := ctr + up * 0.49
				var top := ctr + up * (0.5 + LIFT)
				_drape(out, p, top, a.z, surf)
				_rise(out, top, float(surf.call(edge.x, edge.y, b.z)) + LIFT)
				_line(out, Vector3(edge.x, out[-1].y, edge.y))
				p = edge
		elif a.z != b.z:   # a ladder (a fire escape): straight up its foot's square, in front of the rungs, then over the edge
			var foot: Vector3i = a if a.z < b.z else b
			var head: Vector3i = b if a.z < b.z else a
			var away := Vector2(foot.x - head.x, foot.y - head.y).normalized()
			var rung := Vector2(foot.x + 0.5, foot.y + 0.5) + away * 0.15
			var hc := Vector2(head.x + 0.5, head.y + 0.5)
			var over := float(head.z) * fh + PARAPET + LIFT   # clear of the roof edge's parapet
			if a == foot:
				_drape(out, p, rung, a.z, surf)
				_rise(out, rung, over)
				_line(out, Vector3(hc.x, over, hc.y))
				_rise(out, hc, float(surf.call(hc.x, hc.y, b.z)) + LIFT)
			else:
				_drape(out, p, hc, a.z, surf)
				_rise(out, hc, over)
				_line(out, Vector3(rung.x, over, rung.y))
				_rise(out, rung, float(surf.call(rung.x, rung.y, b.z)) + LIFT)
				_drape(out, rung, bc, b.z, surf)
			p = bc
		elif flat > 1.5:   # a jump across a gap: an arc, as the walker leaps (greybox._anim_move)
			var y0 := out[-1].y
			var y1 := float(surf.call(bc.x, bc.y, b.z)) + LIFT
			var hop := 0.3 * flat
			var n := maxi(6, int(flat * 4.0))
			for k in range(1, n + 1):
				var t := float(k) / n
				var q := p.lerp(bc, t)
				out.append(Vector3(q.x, lerpf(y0, y1, t) + sin(t * PI) * hop, q.y))
			p = bc
		else:
			var to := bc
			if i + 1 < path.size():   # the next move goes down a flight from b: head for the flight's high end, not b's middle
				var c: Vector3i = path[i + 1]
				if c.x == b.x and c.y == b.y and c.z < b.z:
					var up: Vector2 = flight.call(c)
					if up != Vector2.ZERO:
						to = bc + up * (0.5 + LIFT)
			_drape(out, p, to, b.z, surf)
			p = to
	return _round(out)


## Walk on storey f from `from` to `to` over the surface: points along each square crossed (closer
## over a sloping flight), and a vertical jog wherever the height changes at a square's edge, on
## the lower side of the face (up: before it; down: after it), so the trace never cuts a riser.
static func _drape(out: PackedVector3Array, from: Vector2, to: Vector2, f: int, surf: Callable) -> void:
	var d := to - from
	var ln := d.length()
	if ln < EPS:
		return
	var dn := d / ln
	var ts: Array[float] = [0.0, 1.0]   # where the segment crosses a square's edge
	for ax in 2:
		var a0 := from[ax]
		var a1 := to[ax]
		if absf(a1 - a0) < EPS:
			continue
		for k in range(int(floor(minf(a0, a1))) + 1, int(ceil(maxf(a0, a1)))):
			var t := (float(k) - a0) / (a1 - a0)
			if t > EPS and t < 1.0 - EPS:
				ts.append(t)
	ts.sort()
	var cuts: Array[float] = []
	for t in ts:   # a diagonal through a corner crosses both edges at once
		if cuts.is_empty() or t - cuts[-1] > EPS:
			cuts.append(t)
	var gap := LIFT * 1.3 / ln   # room left for a jog, in t
	var skip_to := 0.0
	for j in range(cuts.size() - 1):
		var t0 := cuts[j]
		var t1 := cuts[j + 1]
		var mid := from + d * (t0 + t1) * 0.5
		var q1 := from + d * t1
		var y_here := _surf_in(surf, q1, mid, f) + LIFT
		var y_next := y_here
		if j + 2 < cuts.size():
			y_next = _surf_in(surf, q1, from + d * (t1 + cuts[j + 2]) * 0.5, f) + LIFT
		var steps := maxi(1, int(ceil((t1 - t0) * ln * 8.0)))   # fine enough for a flight's slope
		for k in range(1, steps):
			var t := lerpf(t0, t1, float(k) / steps)
			if t < skip_to or (y_next > y_here + 0.02 and t > t1 - gap):
				continue
			var q := from + d * t
			_line(out, Vector3(q.x, _surf_in(surf, q, mid, f) + LIFT, q.y))
		if absf(y_next - y_here) <= 0.02:
			_line(out, Vector3(q1.x, y_here, q1.y))
		elif y_next > y_here:   # step up: rise before the face
			var jog := q1 - dn * LIFT
			_line(out, Vector3(jog.x, _surf_in(surf, jog, mid, f) + LIFT, jog.y))
			_line(out, Vector3(jog.x, y_next, jog.y))
			_line(out, Vector3(q1.x, y_next, q1.y))
		else:   # step down: over the edge, then drop past the face
			var jog := q1 + dn * LIFT
			_line(out, Vector3(q1.x, y_here, q1.y))
			_line(out, Vector3(jog.x, y_here, jog.y))
			_line(out, Vector3(jog.x, y_next, jog.y))
			skip_to = t1 + gap


## The surface at q, sampled inside the square `inside` lies in (q itself may sit on its edge).
static func _surf_in(surf: Callable, q: Vector2, inside: Vector2, f: int) -> float:
	var cell := Vector2(floor(inside.x), floor(inside.y))
	var qq := q.clamp(cell + Vector2(EPS, EPS), cell + Vector2(1.0 - EPS, 1.0 - EPS))
	return float(surf.call(qq.x, qq.y, f))


static func _rise(out: PackedVector3Array, at: Vector2, y: float) -> void:
	_line(out, Vector3(at.x, out[-1].y, at.y))
	_line(out, Vector3(at.x, y, at.y))


static func _line(out: PackedVector3Array, v: Vector3) -> void:
	if out.is_empty() or out[-1].distance_to(v) > EPS:
		out.append(v)


## Drop the points a straight run passes through, then round each remaining corner with a short
## quadratic curve (radius ROUND, at most half of either leg) so the trace reads as one stroke.
static func _round(pts: PackedVector3Array) -> PackedVector3Array:
	var lean := PackedVector3Array()
	for i in pts.size():
		if i > 0 and i < pts.size() - 1:
			var u := (pts[i] - pts[i - 1]).normalized()
			var w := (pts[i + 1] - pts[i]).normalized()
			if u.dot(w) > 0.9995:
				continue
		lean.append(pts[i])
	if lean.size() < 3:
		return lean
	var out := PackedVector3Array([lean[0]])
	for i in range(1, lean.size() - 1):
		var a := lean[i - 1]
		var v := lean[i]
		var b := lean[i + 1]
		var u := (v - a).normalized()
		var w := (b - v).normalized()
		if u.dot(w) > 0.97:   # nearly straight (a gentle bend in a slope or an arc): keep the point
			out.append(v)
			continue
		var r := minf(ROUND, minf(a.distance_to(v), v.distance_to(b)) * 0.5)
		var p0 := v - u * r
		var p2 := v + w * r
		for k in 5:
			var t := k / 4.0
			out.append(p0 * (1.0 - t) * (1.0 - t) + v * 2.0 * (1.0 - t) * t + p2 * t * t)
	out.append(lean[-1])
	return out


## A thin square tube along the trace (unlit, so it reads as an even line from any camera angle,
## the vertical parts too: a flat ribbon goes edge-on up a ladder), with a flat diamond at the end.
static func tube(pts: PackedVector3Array, half: float, diamond: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var side_prev := Vector3.RIGHT
	var rings: Array = []
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var s := t.cross(Vector3.UP)
		s = s.normalized() if s.length() > 0.2 else side_prev   # straight up or down: keep the last heading's side
		side_prev = s
		var n := s.cross(t).normalized()
		rings.append([pts[i] + (s + n) * half, pts[i] + (s - n) * half, pts[i] + (-s - n) * half, pts[i] + (-s + n) * half])
	for i in pts.size() - 1:
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		for k in 4:
			var k2 := (k + 1) % 4
			for v in [r0[k], r0[k2], r1[k2], r0[k], r1[k2], r1[k]]:
				st.add_vertex(v)
	var e := pts[-1] + Vector3(0, 0.01, 0)
	for v in [e + Vector3(-diamond, 0, 0), e + Vector3(0, 0, -diamond), e + Vector3(diamond, 0, 0), e + Vector3(-diamond, 0, 0), e + Vector3(diamond, 0, 0), e + Vector3(0, 0, diamond)]:
		st.add_vertex(v)
	return st.commit()
