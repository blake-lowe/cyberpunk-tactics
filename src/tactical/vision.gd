class_name Vision
extends RefCounted
## What the crew can see (M3 playtest verdict: building interiors show only once the squad can see
## them). Cells are `visible` (in sight right now) or `explored` (seen before, drawn dimmed).
## Outdoor ground, roofs and the outer shell of buildings start explored; interiors start unknown.
## Sight is blocked by walls and closed doors (Los.blocker "wall"); low cover and glass don't hide
## the room behind them. One floor at a time (cross-floor sight comes later).

const RADIUS := 18     # squares (36 m): roughly what a tactical camera frames

var m: TacMap
var los: Los
var visible := {}      ## Vector3i → true
var explored := {}     ## Vector3i → true


func _init(p_map: TacMap, p_los: Los) -> void:
	m = p_map
	los = p_los
	for f in m.floors:
		for y in m.h:
			for x in m.w:
				if _outdoor(f, x, y):
					explored[Vector3i(x, y, f)] = true
	# The outer shell: walls, doors and windows touching outdoor cells.
	for f in m.floors:
		for y in m.h:
			for x in m.w:
				var t := m.t(f, x, y)
				if (t == TacMap.T.WALL or t == TacMap.T.DOOR) and _touches_outdoor(f, x, y):
					explored[Vector3i(x, y, f)] = true


func _outdoor(f: int, x: int, y: int) -> bool:
	var t := m.t(f, x, y)
	if t in [TacMap.T.OUTSIDE, TacMap.T.ROOF, TacMap.T.WATER, TacMap.T.BRIDGE]:
		return true
	var l := m.label(f, x, y)
	return l >= 0 and m.rooms[l].get("outdoor", false)


func _touches_outdoor(f: int, x: int, y: int) -> bool:
	for d in Nav.DIRS8:
		var n: Vector2i = Vector2i(x, y) + d
		if not m.inb(n.x, n.y) or m.t(f, n.x, n.y) == TacMap.T.VOID or _outdoor(f, n.x, n.y):
			return true
	return false


## Recompute sight from the given eye positions. Returns true if anything new was explored.
func update(eyes: Array) -> bool:
	visible = {}
	for e in eyes:
		_cast(e)
	var before := explored.size()
	explored.merge(visible)
	return explored.size() != before


func _cast(a: Vector3i) -> void:
	visible[a] = true
	var r := RADIUS
	var r2 := r * r
	for i in range(-r, r + 1):
		for b in [Vector3i(a.x + i, a.y - r, a.z), Vector3i(a.x + i, a.y + r, a.z), Vector3i(a.x - r, a.y + i, a.z), Vector3i(a.x + r, a.y + i, a.z)]:
			var cells := Los.ray(a, b)
			cells.append(b)
			for v in cells:
				if not m.inb(v.x, v.y) or (v.x - a.x) * (v.x - a.x) + (v.y - a.y) * (v.y - a.y) > r2:
					break
				visible[v] = true
				if los.blocker(v) == "wall":
					break


## 0 unknown, 1 explored (dim), 2 visible.
func state(v: Vector3i) -> int:
	return 2 if visible.has(v) else (1 if explored.has(v) else 0)
