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


## Squares a ray from a to b passes through (supercover), excluding both ends. Where the ray runs
## exactly through a grid corner it takes only the two squares along it, not the two beside the
## corner: those are its pinches (Los.walk).
static func ray(a: Vector3i, b: Vector3i) -> Array[Vector3i]:
	return walk(a, b).cells


## The ray as {cells: ray(a, b), pinches: [[i, s1, s2], ...]}: every grid corner the ray runs
## exactly through, as the two squares beside it, `i` being how many of `cells` come before it.
## Two walls meeting there corner to corner pinch the ray shut (Los.pinched), just as Nav never
## steps diagonally between them (playtest v0.10.1: no seeing or shooting through a gap nobody can
## walk through). One wall corner alone doesn't stop a ray grazing past it.
static func walk(a: Vector3i, b: Vector3i) -> Dictionary:
	var out: Array[Vector3i] = []
	var pinches: Array = []
	var dx := b.x - a.x
	var dy := b.y - a.y
	var n := maxi(absi(dx), absi(dy)) * 2
	if n == 0:
		return {"cells": out, "pinches": pinches}
	var sx := 1 if dx > 0 else 0
	var sy := 1 if dy > 0 else 0
	var seen := {a: true, b: true}
	for i in range(1, n):
		# The sample point in 1/(2n) squares, exact: it is a grid corner when both are whole squares.
		var x2 := (2 * a.x + 1) * n + 2 * dx * i
		var y2 := (2 * a.y + 1) * n + 2 * dy * i
		if dx != 0 and dy != 0 and posmod(x2, 2 * n) == 0 and posmod(y2, 2 * n) == 0:
			var cx := x2 / (2 * n)
			var cy := y2 / (2 * n)
			var before := Vector3i(cx - sx, cy - sy, a.z)
			var after := Vector3i(cx - 1 + sx, cy - 1 + sy, a.z)
			if not seen.has(before):
				seen[before] = true
				out.append(before)
			pinches.append([out.size(), Vector3i(before.x, after.y, a.z), Vector3i(after.x, before.y, a.z)])
			if not seen.has(after):
				seen[after] = true
				out.append(after)
			continue
		var t := float(i) / n
		var px := a.x + 0.5 + dx * t
		var py := a.y + 0.5 + dy * t
		for off in [Vector2(0, 0), Vector2(0.001, 0.001), Vector2(-0.001, -0.001)]:
			var v := Vector3i(floori(px + off.x), floori(py + off.y), a.z)
			if not seen.has(v):
				seen[v] = true
				out.append(v)
	return {"cells": out, "pinches": pinches}


## Whether a corner pinch [i, s1, s2] (Los.walk) shuts out sight: walls or closed doors both sides.
func pinched(p: Array) -> bool:
	return blocker(p[1]) == "wall" and blocker(p[2]) == "wall"


## Whether walls or closed doors stand between a and b (cover, glass and furniture don't): a
## Netrunner's cable reach.
func wall_between(a: Vector3i, b: Vector3i) -> bool:
	var w := walk(a, b)
	for v in w.cells:
		if blocker(v) == "wall":
			return true
	for p in w.pinches:
		if pinched(p):
			return true
	return false


## Clear sight from a to b? Returns {clear, first_blocker, through_glass}. A corner pinched by two
## solid things (walls, closed doors, cover) blocks like a wall; first_blocker is then the side to
## shoot at (the cover piece if one is).
func trace(a: Vector3i, b: Vector3i) -> Dictionary:
	if a.z != b.z:
		return {"clear": false, "first_blocker": Vector3i(-1, -1, -1), "through_glass": false}
	var glass := false
	var w := walk(a, b)
	var cells: Array[Vector3i] = w.cells
	var pinches: Array = w.pinches
	var k := 0
	for i in cells.size() + 1:
		while k < pinches.size() and int(pinches[k][0]) == i:
			var p: Array = pinches[k]
			k += 1
			var b1 := blocker(p[1])
			var b2 := blocker(p[2])
			if b1 != "" and b2 != "":
				if b1 != "glass" and b2 != "glass":
					return {"clear": false, "first_blocker": p[2] if b2 == "cover" and b1 != "cover" else p[1], "through_glass": glass}
				glass = true
		if i == cells.size():
			break
		var v := cells[i]
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
