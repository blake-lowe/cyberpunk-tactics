class_name Los
extends RefCounted
## Line of sight and binary cover (p182: you're in cover only if fully behind something that could
## stop a bullet; if the enemy can see you, you're not in cover).
## - Rays run centre to centre on one floor (cross-floor sight comes with the 3D greybox).
## - Blocking: walls and closed doors (not windows, fences or bulletproof glass, which are
##   see-through), and cover pieces that still have HP.
## - A shooter standing next to cover may lean out: sight is checked from their own square and from
##   each open square beside it (XCOM-style step-out). Targets don't lean.

var m: TacMap
var cover_hp := {}      ## Vector3i → remaining HP of cover pieces (mutable copy of the map's)
var wall_hp := {}       ## Vector3i → remaining HP of damaged walls/doors/windows
var open_doors := {}    ## Vector3i door cells currently open (don't block sight)


func _init(p_map: TacMap) -> void:
	m = p_map
	for c in m.cover:
		cover_hp[Vector3i(c.pos.x, c.pos.y, c.floor)] = int(c.hp)


## What a square does to a ray: "" (nothing), "wall", "cover", "glass" (see-through cover).
func blocker(v: Vector3i) -> String:
	if cover_hp.get(v, 0) > 0:
		return "cover"
	var t := m.t(v.z, v.x, v.y)
	if t == TacMap.T.WALL:
		if wall_hp.get(v, 1) <= 0:
			return ""
		var wc := m.wall_cover(v.z, v.x, v.y)
		return "glass" if not wc.blocks_los and wc.cover else ("" if not wc.blocks_los else "wall")
	if t == TacMap.T.DOOR and not open_doors.has(v) and wall_hp.get(v, 1) > 0:
		return "wall"
	return ""


## Squares a ray from a to b passes through (supercover), excluding both ends.
static func ray(a: Vector3i, b: Vector3i) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var dx := b.x - a.x
	var dy := b.y - a.y
	var n := maxi(absi(dx), absi(dy)) * 2
	if n == 0:
		return out
	var seen := {a: true, b: true}
	for i in range(1, n):
		var t := float(i) / n
		var px := a.x + 0.5 + dx * t
		var py := a.y + 0.5 + dy * t
		for off in [Vector2(0, 0), Vector2(0.001, 0.001), Vector2(-0.001, -0.001)]:
			var v := Vector3i(floori(px + off.x), floori(py + off.y), a.z)
			if not seen.has(v):
				seen[v] = true
				out.append(v)
	return out


## Clear sight from a to b? Returns {clear, first_blocker, through_glass}.
func trace(a: Vector3i, b: Vector3i) -> Dictionary:
	if a.z != b.z:
		return {"clear": false, "first_blocker": Vector3i(-1, -1, -1), "through_glass": false}
	var glass := false
	for v in ray(a, b):
		var bl := blocker(v)
		if bl == "wall" or bl == "cover":
			return {"clear": false, "first_blocker": v, "through_glass": glass}
		if bl == "glass":
			glass = true
	return {"clear": true, "first_blocker": Vector3i(-1, -1, -1), "through_glass": glass}


## Squares the shooter can fire from: their own, plus open neighbours when they're next to cover.
func lean_points(a: Vector3i) -> Array[Vector3i]:
	var pts: Array[Vector3i] = [a]
	var near_cover := false
	for d in MapGen.DIRS:
		if blocker(Vector3i(a.x + d.x, a.y + d.y, a.z)) != "":
			near_cover = true
	if near_cover:
		for d in MapGen.DIRS:
			var n := Vector3i(a.x + d.x, a.y + d.y, a.z)
			if m.walkable(n.z, Vector2i(n.x, n.y)) and blocker(n) == "":
				pts.append(n)
	return pts


## Can a shooter at `a` see a target at `b`? Returns {visible, from, through_glass, blocker}.
## `blocker` is the first thing in the way from the shooter's own square (to shoot at it instead).
func sight(a: Vector3i, b: Vector3i) -> Dictionary:
	var direct := trace(a, b)
	if direct.clear:
		return {"visible": true, "from": a, "through_glass": direct.through_glass, "blocker": direct.first_blocker}
	for p in lean_points(a):
		if p == a:
			continue
		var t := trace(p, b)
		if t.clear:
			return {"visible": true, "from": p, "through_glass": t.through_glass, "blocker": direct.first_blocker}
	return {"visible": false, "from": a, "through_glass": false, "blocker": direct.first_blocker}


## Range in metres between squares (2 m per square), for the range DV tables.
static func distance_m(a: Vector3i, b: Vector3i) -> float:
	return Vector2(a.x - b.x, a.y - b.y).length() * 2.0 + absi(a.z - b.z) * 3.0
