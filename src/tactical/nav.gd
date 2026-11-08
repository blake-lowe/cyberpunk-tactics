class_name Nav
extends RefCounted
## Grid movement on a TacMap. Squares are 2 m; a Move Action covers MOVE squares (p168-169),
## diagonals allowed and costing 1 like orthogonal steps, but never cutting a wall corner.
## Stairs and elevators cost 1 per floor; ladders and fire escapes count as climbing, 2 per floor
## (p169: climbing costs 2 m/yds per m/yd). Locked security doors block until unlocked.

const DIRS8: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

var m: TacMap
var locked := {}          ## Vector3i door cells that are locked (security doors until hacked)
var _links := {}          ## Vector3i → [[Vector3i, cost]] for shafts and connectors
var halted := {}          ## Vector2i shaft squares whose elevator car is stopped (held from the NET): nobody rides it


func _init(p_map: TacMap) -> void:
	m = p_map
	for v in m.verticals:
		for f in range(v.from_floor, v.to_floor + 1):
			for g in range(v.from_floor, v.to_floor + 1):
				if f != g and absi(f - g) == 1:
					_links.get_or_add(Vector3i(v.pos.x, v.pos.y, f), []).append([Vector3i(v.pos.x, v.pos.y, g), 1])
	for c in m.connectors:
		var cost := 2 * absi(c.a.z - c.b.z)
		_links.get_or_add(c.a, []).append([c.b, cost])
		_links.get_or_add(c.b, []).append([c.a, cost])
	for d in m.doors:
		if d.security:
			locked[Vector3i(d.pos.x, d.pos.y, d.floor)] = true


func open(v: Vector3i) -> bool:
	return m.walkable(v.z, Vector2i(v.x, v.y)) and not locked.has(v)


## Neighbours with step costs. `occupied` cells (other units) can't be entered.
func neighbours(v: Vector3i, occupied: Dictionary) -> Array:
	var out := []
	for d in DIRS8:
		var n := Vector3i(v.x + d.x, v.y + d.y, v.z)
		if not open(n) or occupied.has(n):
			continue
		if d.x != 0 and d.y != 0:
			# No corner cutting: both orthogonal cells must be open.
			if not open(Vector3i(v.x + d.x, v.y, v.z)) or not open(Vector3i(v.x, v.y + d.y, v.z)):
				continue
		out.append([n, 1])
	for l in _links.get(v, []):
		if open(l[0]) and not occupied.has(l[0]) and not (halted.has(Vector2i(v.x, v.y)) and l[0].x == v.x and l[0].y == v.y):
			out.append(l)
	return out


## Every cell reachable within `budget` squares: {cell: cost}.
func reachable(start: Vector3i, budget: int, occupied: Dictionary = {}) -> Dictionary:
	return _dial([start], occupied, budget)


## Walking distance from the nearest of `sources` to every reachable cell, up to `limit`.
func distance_field(sources: Array, occupied: Dictionary = {}, limit := 400) -> Dictionary:
	return _dial(sources, occupied, limit)


## Dijkstra with a bucket queue (step costs are small integers), so no sorting is needed.
func _dial(sources: Array, occupied: Dictionary, limit: int) -> Dictionary:
	var dist := {}
	var buckets: Array = [[]]
	for v in sources:
		dist[v] = 0
		buckets[0].append(v)
	var d := 0
	while d < buckets.size():
		var bucket: Array = buckets[d]
		var i := 0
		while i < bucket.size():
			var v: Vector3i = bucket[i]
			i += 1
			if dist[v] != d:
				continue
			for nb in neighbours(v, occupied):
				var nd: int = d + nb[1]
				if nd <= limit and nd < dist.get(nb[0], 1 << 30):
					dist[nb[0]] = nd
					while buckets.size() <= nd:
						buckets.append([])
					buckets[nd].append(nb[0])
		d += 1
	return dist


## Shortest path (A*), start excluded, goal included. Empty if unreachable.
func path(start: Vector3i, goal: Vector3i, occupied: Dictionary = {}) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	if start == goal or not open(goal):
		return out
	var came := {}
	var g := {start: 0}
	var heap: Array = [[_h(start, goal), start]]
	while not heap.is_empty():
		heap.sort_custom(func(a, b): return a[0] < b[0])
		var v: Vector3i = heap.pop_front()[1]
		if v == goal:
			var cur := goal
			while cur != start:
				out.push_front(cur)
				cur = came[cur]
			return out
		for nb in neighbours(v, occupied):
			var ng: int = g[v] + nb[1]
			if ng < g.get(nb[0], 1 << 30):
				g[nb[0]] = ng
				came[nb[0]] = v
				heap.append([ng + _h(nb[0], goal), nb[0]])
	return out


## Movement cost of a path from `start` (the sum of each step's cost).
func cost_of(start: Vector3i, p: Array[Vector3i]) -> int:
	var total := 0
	var prev := start
	for v in p:
		var step := 1
		for l in _links.get(prev, []):
			if l[0] == v:
				step = l[1]
		total += step
		prev = v
	return total


static func _h(a: Vector3i, b: Vector3i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y)) + absi(a.z - b.z)
