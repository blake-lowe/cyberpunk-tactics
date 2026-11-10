extends TestCase
## Floor-plan audit properties (owner playtest: one hard-to-find stair, corridors never wider than one
## square): stairs scale with the floor plate and stand apart, unplanned buildings get stair halls
## stacked storey over storey off a corridor near the door, big plates get two-square corridors that
## stack, and no storey is cut off or left with one-square slivers.

## [site, overrides]: lone buildings from a small walk-up to a big plate (shell = w - 3 by h - 3).
const CASES := [
	["gang_hideout", {"w": 14, "h": 14, "floors": 2}],
	["corp_office", {"w": 25, "h": 21, "floors": 3}],
	["clinic", {"w": 24, "h": 22, "floors": 2}],
	["corp_office", {"floors": 3}],
	["warehouse", {"floors": 2}],
	["apartments", {"floors": 3}],
	["club", {"w": 26, "h": 22, "floors": 2}],
	["data_center", {"floors": 2}],
]
static var _cache: Array[TacMap] = []


func _maps() -> Array[TacMap]:
	if _cache.is_empty():
		for i in CASES.size():
			var o: Dictionary = (CASES[i][1] as Dictionary).duplicate()
			o["site"] = CASES[i][0]
			o["basement_storeys"] = 0
			o["security"] = i % 4
			_cache.append(SceneGen.generate(7300 + i * 13, "lone_building", o))
	return _cache


func _tag(m: TacMap) -> String:
	return "%s seed %d" % [m.structures[0].site, m.seed_value]


func _stairs(m: TacMap) -> Array:
	return m.verticals.filter(func(v): return String(v.type) == "stairs" and int(v.get("structure", -1)) == 0 and int(v.to_floor) >= 1)


## The smallest storey's plate (a podium's tower decides), in squares.
func _area(m: TacMap) -> int:
	var r: Rect2i = m.structures[0].rect
	var least := 1 << 30
	for f in int(m.structures[0].floors):
		var n := 0
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				if m.t(f, x, y) in [TacMap.T.FLOOR, TacMap.T.WALL, TacMap.T.DOOR, TacMap.T.STAIRS, TacMap.T.ELEVATOR]:
					n += 1
		least = mini(least, n)
	return least


func test_stair_count_scales_with_the_floor_plate() -> void:
	var p := {"algorithm": "bsp"}
	var small := Footprint.make(Rect2i(0, 0, 11, 12))
	var mid := Footprint.make(Rect2i(0, 0, 22, 18))
	var big := Footprint.make(Rect2i(0, 0, 37, 29))
	assert_eq(BuildingGen.stair_count(p, small, 1), 0, "one storey: no stairs")
	assert_eq(BuildingGen.stair_count(p, small, 3), 1, "a small walk-up keeps one stair")
	assert_eq(BuildingGen.stair_count(p, mid, 2), 2, "a mid-size plate gets two")
	assert_eq(BuildingGen.stair_count(p, big, 3), 3, "a big plate gets three")
	assert_eq(BuildingGen.stair_count({"algorithm": "program"}, big, 3), 1, "a brief without `stairs` keeps one")
	assert_eq(BuildingGen.stair_count({"algorithm": "program", "stairs": 2}, big, 3), 2, "a brief names its own")
	for m in _maps():
		var got := _stairs(m).size()
		var area := _area(m)
		assert_true(got >= 1, "%s: a stair" % _tag(m))
		if area >= BuildingGen.TWO_STAIRS_AREA:
			assert_true(got >= 2, "%s: %d squares of plate, %d stairs" % [_tag(m), area, got])


## Bounding box of the top storey's plate (setbacks shrink it).
func _top_plate(m: TacMap) -> Rect2:
	var r: Rect2i = m.structures[0].rect
	var f := int(m.structures[0].floors) - 1
	var b := Rect2()
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if m.t(f, x, y) in [TacMap.T.FLOOR, TacMap.T.WALL, TacMap.T.DOOR, TacMap.T.STAIRS, TacMap.T.ELEVATOR]:
				b = Rect2(x, y, 1, 1) if b.size == Vector2.ZERO else b.expand(Vector2(x + 1, y + 1)).expand(Vector2(x, y))
	return b


func test_stairs_stand_apart() -> void:
	for m in _maps():
		var st := _stairs(m)
		var diag := _top_plate(m).size.length()   # the stairs run through every storey: the top one bounds them
		var far := 0.0
		for a in st:
			for b in st:
				if a != b:
					far = maxf(far, Vector2(a.pos - b.pos).length())
					assert_true(Vector2(a.pos - b.pos).length() >= 8.0, "%s: stairs %s and %s too close" % [_tag(m), a.pos, b.pos])
		if st.size() >= 2:
			assert_true(far >= diag / 3.0, "%s: the stairs %.1f apart at most, on a plate %.1f across" % [_tag(m), far, diag])


func test_stair_halls_stack_and_open_off_the_circulation() -> void:
	for m in _maps():
		var tag := _tag(m)
		var floors := int(m.structures[0].floors)
		for v in _stairs(m):
			for f in floors:
				var l := m.label(f, v.pos.x, v.pos.y)
				assert_true(l >= 0 and String(m.rooms[l].kind) == "stair_hall", "%s: stair %s on floor %d stands in a stair hall" % [tag, v.pos, f])
		# with corridors on the ground floor, the stair nearest the door opens onto one (or the lobby)
		var corr := m.rooms.any(func(r): return int(r.cells) > 0 and int(r.floor) == 0 and String(r.get("layout_kind", "")) == "corridor")
		if not corr:
			continue
		var halls_off := 0
		var halls := 0
		for r in m.rooms:
			if int(r.cells) == 0 or int(r.floor) != 0 or String(r.kind) != "stair_hall":
				continue
			halls += 1
			for d in m.doors:
				var other := int(d.b) if int(d.a) == int(r.id) else (int(d.a) if int(d.b) == int(r.id) else -2)
				if other >= 0 and String(m.rooms[other].get("layout_kind", "")) == "corridor" or other >= 0 and String(m.rooms[other].kind) in ["corridor", "lobby"]:
					halls_off += 1
					break
		assert_true(halls_off >= 1, "%s: a stair hall opens onto the corridor (%d of %d)" % [tag, halls_off, halls])


func test_stairs_are_near_the_door() -> void:
	for m in _maps():
		var e := m.main_entrance()
		var st := _stairs(m)
		if e.is_empty() or st.is_empty():
			continue
		# walk the street floor from the main door to the nearest stair
		var spos := {}
		for v in st:
			spos[v.pos] = true
		var dist := {e.pos: 0}
		var q: Array[Vector2i] = [e.pos]
		var r: Rect2i = m.structures[0].rect
		var found := -1
		while not q.is_empty():
			var c: Vector2i = q.pop_front()
			if spos.has(c):
				found = dist[c]
				break
			for d in MapGen.DIRS:
				var n: Vector2i = c + d
				if r.has_point(n) and not dist.has(n) and m.walkable_tile(m.t(0, n.x, n.y)) and m.t(0, n.x, n.y) != TacMap.T.OUTSIDE and not m.has_cover_at(0, n):
					dist[n] = dist[c] + 1
					q.append(n)
		assert_true(found >= 0, "%s: a stair reachable indoors from the main door" % _tag(m))
		assert_true(found <= roundi(r.size.x + r.size.y) * 0.75, "%s: the nearest stair is %d squares from the door" % [_tag(m), found])


func test_big_plates_get_two_square_corridors_that_stack() -> void:
	var wide := 0
	for m in _maps():
		var floors := int(m.structures[0].floors)
		var cells_by_floor := []
		for f in floors:
			cells_by_floor.append({})
		for r in m.rooms:
			if int(r.cells) == 0 or String(r.get("layout_kind", "")) != "corridor":
				continue
			for c in Furnish.room_cells(m, r):
				cells_by_floor[int(r.floor)][c] = true
			# minimum width across the corridor's run, sliced across its long axis
			var b: Rect2i = r.bounds
			var per := {}
			for c in Furnish.room_cells(m, r):
				var k: int = c.x if b.size.x >= b.size.y else c.y
				per[k] = int(per.get(k, 0)) + 1
			if per.values().min() >= 2:
				wide += 1
		# the ground floor's corridor squares are corridor on the storey above too (where it stands)
		if floors >= 2 and String(m.structures[0].algorithm) in ["bsp", "treemap"]:
			var same := 0
			for c in cells_by_floor[0]:
				if cells_by_floor[1].has(c):
					same += 1
			if cells_by_floor[0].size() > 0 and cells_by_floor[1].size() > 0:
				assert_true(same * 2 >= mini(cells_by_floor[0].size(), cells_by_floor[1].size()), "%s: corridors stack (%d shared)" % [_tag(m), same])
	assert_true(wide >= 3, "two-square corridors on the big plates (%d)" % wide)
	assert_eq(Layouts.corridor_width({}, Rect2i(0, 0, 30, 20)), 3, "a big plate's main corridor is two squares of floor")
	assert_eq(Layouts.corridor_width({}, Rect2i(0, 0, 14, 12)), 2, "a small one keeps one")
	assert_eq(Layouts.corridor_width({"corridor_w": 2}, Rect2i(0, 0, 30, 20)), 2, "a site can keep its halls narrow")


func test_every_storey_connected_and_no_slivers() -> void:
	for m in _maps():
		var tag := _tag(m)
		var e := m.main_entrance()
		assert_false(e.is_empty(), "%s: a main door" % tag)
		if e.is_empty():
			continue
		var reach := m.reachable(Vector3i(e.pos.x, e.pos.y, e.floor))
		for r in m.rooms:
			if int(r.cells) == 0 or r.get("outdoor", false):
				continue
			var cells := Furnish.room_cells(m, r)
			assert_true(cells.any(func(c): return reach.has(Vector3i(c.x, c.y, int(r.floor)))), "%s: room %d (%s, floor %d) reachable" % [tag, r.id, r.kind, r.floor])
			if String(r.kind) in ["corridor", "hallway"] or r.has("program_kind"):
				continue
			var set := {}
			for c in cells:
				set[c] = true
			var block := cells.any(func(c): return set.has(c + Vector2i.RIGHT) and set.has(c + Vector2i.DOWN) and set.has(c + Vector2i.ONE))
			assert_true(block, "%s: room %d (%s, floor %d, %d squares) is a one-square sliver" % [tag, r.id, r.kind, r.floor, r.cells])
		# no storey of the building has a wing walled off solid (3x3 of wall inside the plate)
		var sh: Rect2i = m.structures[0].rect
		for f in int(m.structures[0].floors):
			var solid := 0
			for y in range(sh.position.y + 1, sh.end.y - 1):
				for x in range(sh.position.x + 1, sh.end.x - 1):
					var all := true
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							if m.t(f, x + dx, y + dy) != TacMap.T.WALL:
								all = false
					if all:
						solid += 1
			assert_true(solid <= 6, "%s: floor %d has %d squares walled solid" % [tag, f, solid])
