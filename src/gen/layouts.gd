class_name Layouts
extends RefCounted
## Room-partition algorithms. Each fills `labels` (w-wide grid) inside `region` with room ids
## starting at 0 and returns per-room hints: [{zone_hint: int (-1 = derive from depth), kind: String}].
## Walls, doors, zoning and furnishing are shared (MapGen), so algorithms only decide room shapes.
##
##   bsp      — recursive binary space partition; the top splits become corridors.
##   treemap  — squarified treemap (Marson & Musse 2010, "Automatic Real-Time Generation of Floor
##              Plans Based on Squarified Treemaps"): zones sized by area, then rooms inside each zone.
##   corridor_units — apartment blocks: a 2-wide spine corridor along the long axis with units on
##              both sides, some units split into living room + bedroom.
##   train    — a long hull cut into cars across its length; some cars split into compartments.
##   growth   — constrained growth (Lopes et al. 2010, "A Constrained Growth Method for Procedural
##              Floor Plan Generation"): room seeds grow as rectangles, then L-shapes, then fill gaps.

const MIN_ROOM := 4
const MAX_ROOM := 10


static func run(algorithm: String, dice: Dice, w: int, region: Rect2i, labels: PackedInt32Array, p: Dictionary) -> Array:
	match algorithm:
		"bsp": return bsp(dice, w, region, labels, p)
		"treemap": return treemap(dice, w, region, labels, p)
		"growth": return growth(dice, w, region, labels, p)
		"corridor_units": return corridor_units(dice, w, region, labels, p)
		"train": return train(dice, w, region, labels, p)
	push_error("unknown layout " + algorithm)
	return []


static func _fill(w: int, labels: PackedInt32Array, r: Rect2i, id: int) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			labels[y * w + x] = id


# --- BSP --------------------------------------------------------------------

static func bsp(dice: Dice, w: int, region: Rect2i, labels: PackedInt32Array, p: Dictionary) -> Array:
	var mn := int(p.get("min_room", MIN_ROOM))
	var mx := int(p.get("max_room", MAX_ROOM))
	var hints := []
	var stack: Array = [[region, 0]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var r: Rect2i = item[0]
		var depth: int = item[1]
		var can_v := r.size.x >= mn * 2 + 1
		var can_h := r.size.y >= mn * 2 + 1
		var small := r.size.x <= mx and r.size.y <= mx
		if (not can_v and not can_h) or (small and dice.d(3) == 1):
			_fill(w, labels, r, hints.size())
			hints.append({"zone_hint": -1, "kind": ""})
			continue
		var vertical := can_v and (not can_h or r.size.x > r.size.y or (r.size.x == r.size.y and dice.d(2) == 1))
		var span := r.size.x if vertical else r.size.y
		var corridor := depth < int(p.get("corridor_depth", 2)) and span >= mn * 2 + 3
		var cw := 2 if corridor else 0
		var cut := dice.rng.randi_range(mn, span - mn - cw)
		var a: Rect2i
		var b: Rect2i
		var c: Rect2i
		if vertical:
			a = Rect2i(r.position, Vector2i(cut, r.size.y))
			c = Rect2i(r.position + Vector2i(cut, 0), Vector2i(cw, r.size.y))
			b = Rect2i(r.position + Vector2i(cut + cw, 0), Vector2i(r.size.x - cut - cw, r.size.y))
		else:
			a = Rect2i(r.position, Vector2i(r.size.x, cut))
			c = Rect2i(r.position + Vector2i(0, cut), Vector2i(r.size.x, cw))
			b = Rect2i(r.position + Vector2i(0, cut + cw), Vector2i(r.size.x, r.size.y - cut - cw))
		if corridor:
			_fill(w, labels, c, hints.size())
			hints.append({"zone_hint": -1, "kind": "corridor"})
		stack.append([a, depth + 1])
		stack.append([b, depth + 1])
	return hints


# --- Squarified treemap -----------------------------------------------------

## Zone area weights by security level (0-3). Index = Zone (PUBLIC, STAFF, SECURE, VAULT).
const ZONE_WEIGHTS := [
	[0.40, 0.60, 0.0, 0.0],
	[0.30, 0.50, 0.20, 0.0],
	[0.25, 0.40, 0.25, 0.10],
	[0.20, 0.35, 0.30, 0.15],
]


static func treemap(dice: Dice, w: int, region: Rect2i, labels: PackedInt32Array, p: Dictionary) -> Array:
	var sec := clampi(int(p.get("security", 1)), 0, 3)
	var zone_areas := []
	var zone_ids := []
	for z in 4:
		var wt: float = ZONE_WEIGHTS[sec][z]
		if wt > 0.0:
			zone_areas.append(wt * region.get_area())
			zone_ids.append(z + 1)
	# Zones are ordered strips from the south (entrance) edge inwards, so the gradient always runs
	# street → vault; rooms inside each zone use the squarified layout.
	var zone_rects := []
	var y_end := region.end.y
	for i in zone_areas.size():
		var thick: int = y_end - region.position.y if i == zone_areas.size() - 1 else maxi(MIN_ROOM + 1, roundi(zone_areas[i] / region.size.x))
		zone_rects.append(Rect2i(region.position.x, y_end - thick, region.size.x, thick))
		y_end -= thick
	var hints := []
	for i in zone_rects.size():
		var zr: Rect2i = zone_rects[i]
		var n := maxi(1, roundi(zr.get_area() / float(dice.rng.randi_range(45, 80))))
		var areas := []
		for k in n:
			areas.append(dice.rng.randf_range(0.6, 1.4))
		areas.sort()
		areas.reverse()
		var total := 0.0
		for a in areas:
			total += a
		for k in n:
			areas[k] = areas[k] / total * zr.get_area()
		for rr in squarify(areas, zr, false):
			_fill(w, labels, rr, hints.size())
			hints.append({"zone_hint": zone_ids[i], "kind": ""})
	# Corridor spine (Marson & Musse add corridors so every room reaches the public zone):
	# 2-wide north-south hall from the entrance side through the building.
	var cx := region.position.x + region.size.x / 2 - 1 + dice.rng.randi_range(-2, 2)
	var spine_len := roundi(region.size.y * (0.55 + 0.1 * sec))
	var spine := Rect2i(cx, region.end.y - spine_len, 2, spine_len)
	_fill(w, labels, spine, hints.size())
	hints.append({"zone_hint": 1, "kind": "corridor"})
	return hints


## Squarified treemap layout (Bruls, Huizing & van Wijk 2000) on an integer grid.
## Areas must sum to ~rect area. Rows are laid along the shorter side; when `from_south`, rows start
## at the bottom edge so the first items sit on the south side.
static func squarify(areas: Array, rect: Rect2i, from_south: bool) -> Array:
	var out := []
	var r := rect
	var i := 0
	while i < areas.size():
		if r.size.x <= 0 or r.size.y <= 0:
			break
		if i == areas.size() - 1:
			out.append(r)
			break
		var short := mini(r.size.x, r.size.y)
		var row := [areas[i]]
		var j := i + 1
		while j < areas.size() and _worst(row + [areas[j]], short) <= _worst(row, short):
			row.append(areas[j])
			j += 1
		var row_area := 0.0
		for a in row:
			row_area += a
		# Rows run along the shorter side (Bruls et al.): a tall rect gets a full-width row.
		var horizontal_row := r.size.x <= r.size.y
		var thick := clampi(roundi(row_area / (r.size.x if horizontal_row else r.size.y)), 1, r.size.y if horizontal_row else r.size.x)
		if j >= areas.size():
			thick = r.size.y if horizontal_row else r.size.x
		var row_rect: Rect2i
		if horizontal_row:
			var y0 := r.end.y - thick if from_south else r.position.y
			row_rect = Rect2i(r.position.x, y0, r.size.x, thick)
			r = Rect2i(r.position.x, r.position.y if from_south else r.position.y + thick, r.size.x, r.size.y - thick)
		else:
			row_rect = Rect2i(r.position.x, r.position.y, thick, r.size.y)
			r = Rect2i(r.position.x + thick, r.position.y, r.size.x - thick, r.size.y)
		# Split the row among its items.
		var span := row_rect.size.x if horizontal_row else row_rect.size.y
		var pos := 0
		for k in row.size():
			var seg := span - pos if k == row.size() - 1 else clampi(roundi(row[k] / row_area * span), 1, span - pos)
			if horizontal_row:
				out.append(Rect2i(row_rect.position.x + pos, row_rect.position.y, seg, row_rect.size.y))
			else:
				out.append(Rect2i(row_rect.position.x, row_rect.position.y + pos, row_rect.size.x, seg))
			pos += seg
		i = j
	return out


static func _worst(row: Array, side: int) -> float:
	var s := 0.0
	var mx := 0.0
	var mn := INF
	for a in row:
		s += a
		mx = maxf(mx, a)
		mn = minf(mn, a)
	var s2 := s * s
	var w2 := float(side * side)
	return maxf(w2 * mx / s2, s2 / (w2 * mn))


# --- Constrained growth -----------------------------------------------------

static func growth(dice: Dice, w: int, region: Rect2i, labels: PackedInt32Array, p: Dictionary) -> Array:
	var sec := clampi(int(p.get("security", 1)), 0, 3)
	var n := maxi(4, roundi(region.get_area() / 45.0))
	var hints := []
	var rects: Array[Rect2i] = []
	# Seeds: zone hint follows distance from the south (entrance) edge, so security deepens inwards.
	for i in n:
		var pos := Vector2i.ZERO
		for attempt in 30:
			pos = Vector2i(dice.rng.randi_range(region.position.x + 1, region.end.x - 2),
				dice.rng.randi_range(region.position.y + 1, region.end.y - 2))
			if labels[pos.y * w + pos.x] == -1 and rects.all(func(r): return r.grow(2).has_point(pos) == false):
				break
		if labels[pos.y * w + pos.x] != -1:
			continue
		var depth := 1.0 - float(pos.y - region.position.y) / region.size.y  # 0 at south edge
		var zone := TacMap.Zone.PUBLIC
		var cum := 0.0
		for zi in 4:
			cum += ZONE_WEIGHTS[sec][zi]
			if depth <= cum:
				zone = TacMap.Zone.PUBLIC + zi
				break
		labels[pos.y * w + pos.x] = hints.size()
		rects.append(Rect2i(pos, Vector2i.ONE))
		hints.append({"zone_hint": zone, "kind": "", "target": dice.rng.randi_range(25, 70)})

	# Phase 1: rectangular growth, one side at a time, until each room hits its target or is blocked.
	var dirs := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	var active := range(rects.size())
	while not active.is_empty():
		var still := []
		for id in active:
			var r: Rect2i = rects[id]
			if r.get_area() >= int(hints[id].target):
				continue
			var grew := false
			var order := dirs.duplicate()
			_shuffle(dice, order)
			for d in order:
				var strip := _strip(r, d)
				if _strip_free(w, region, labels, strip):
					_fill(w, labels, strip, id)
					rects[id] = r.merge(strip)
					grew = true
					break
			if grew:
				still.append(id)
		active = still

	# Phase 2: L-shaped growth — claim free cells along any side, then fill leftover gaps
	# with the most-adjacent room so the footprint is fully used.
	for pass_i in 3:
		for y in range(region.position.y, region.end.y):
			for x in range(region.position.x, region.end.x):
				if labels[y * w + x] != -1:
					continue
				var counts := {}
				for d in dirs:
					var nx: int = x + d.x
					var ny: int = y + d.y
					if region.has_point(Vector2i(nx, ny)):
						var l := labels[ny * w + nx]
						if l >= 0:
							counts[l] = counts.get(l, 0) + 1
				if not counts.is_empty():
					var best: int = counts.keys()[0]
					for k in counts:
						if counts[k] > counts[best]:
							best = k
					labels[y * w + x] = best
	for h in hints:
		h.erase("target")
	return hints


static func _shuffle(dice: Dice, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := dice.rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


static func _strip(r: Rect2i, d: Vector2i) -> Rect2i:
	match d:
		Vector2i.LEFT: return Rect2i(r.position.x - 1, r.position.y, 1, r.size.y)
		Vector2i.RIGHT: return Rect2i(r.end.x, r.position.y, 1, r.size.y)
		Vector2i.UP: return Rect2i(r.position.x, r.position.y - 1, r.size.x, 1)
	return Rect2i(r.position.x, r.end.y, r.size.x, 1)


static func _strip_free(w: int, region: Rect2i, labels: PackedInt32Array, s: Rect2i) -> bool:
	if not region.encloses(s):
		return false
	for y in range(s.position.y, s.end.y):
		for x in range(s.position.x, s.end.x):
			if labels[y * w + x] != -1:
				return false
	return true


# --- Apartment block: spine corridor + units ---------------------------------

static func corridor_units(dice: Dice, w: int, region: Rect2i, labels: PackedInt32Array, p: Dictionary) -> Array:
	var hints := []
	var horiz := region.size.x >= region.size.y
	var long := region.size.x if horiz else region.size.y
	var short := region.size.y if horiz else region.size.x
	var cw := 2
	var side := (short - cw) / 2
	var mk := func(a0: int, a1: int, b0: int, b1: int) -> Rect2i:
		# a = along the long axis, b = across it
		return Rect2i(region.position.x + a0, region.position.y + b0, a1 - a0, b1 - b0) if horiz \
			else Rect2i(region.position.x + b0, region.position.y + a0, b1 - b0, a1 - a0)
	_fill(w, labels, mk.call(0, long, side, side + cw), hints.size())
	hints.append({"zone_hint": TacMap.Zone.PUBLIC, "kind": "corridor"})
	for band in [[0, side], [side + cw, short]]:
		var a := 0
		while a < long:
			var unit_len: int = mini(dice.rng.randi_range(int(p.get("unit_min", 5)), int(p.get("unit_max", 8))), long - a)
			if long - a - unit_len < 4:
				unit_len = long - a
			var b0: int = band[0]
			var b1: int = band[1]
			if b1 - b0 >= 6 and dice.rng.randf() < 0.6:
				# living room on the corridor side, bedroom behind
				var mid := b0 + (b1 - b0) / 2
				var near_corr := b1 == side
				_fill(w, labels, mk.call(a, a + unit_len, b0, mid), hints.size())
				hints.append({"zone_hint": -1, "kind": "living" if near_corr else "bedroom"})
				_fill(w, labels, mk.call(a, a + unit_len, mid, b1), hints.size())
				hints.append({"zone_hint": -1, "kind": "bedroom" if near_corr else "living"})
			else:
				_fill(w, labels, mk.call(a, a + unit_len, b0, b1), hints.size())
				hints.append({"zone_hint": -1, "kind": "living"})
			a += unit_len
	return hints


# --- Train: cars along the long axis -----------------------------------------

static func train(dice: Dice, w: int, region: Rect2i, labels: PackedInt32Array, p: Dictionary) -> Array:
	var hints := []
	var horiz := region.size.x >= region.size.y
	var long := region.size.x if horiz else region.size.y
	var a := 0
	while a < long:
		var car: int = mini(int(p.get("car_length", 14)), long - a)
		if long - a - car < 6:
			car = long - a
		var parts := 2 if car >= 10 and dice.rng.randf() < 0.5 else 1
		var seg := car / parts
		for i in parts:
			var a0 := a + i * seg
			var a1 := a + car if i == parts - 1 else a0 + seg
			var r := Rect2i(region.position.x + a0, region.position.y, a1 - a0, region.size.y) if horiz \
				else Rect2i(region.position.x, region.position.y + a0, region.size.x, a1 - a0)
			_fill(w, labels, r, hints.size())
			hints.append({"zone_hint": -1, "kind": ""})
		a += car
	return hints
