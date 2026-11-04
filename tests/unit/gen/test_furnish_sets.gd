extends TestCase
## Room sets (rooms.json `_sets`, Furnish._pattern): the programmed sites are furnished the way
## real rooms are planned (a teller line, a kitchen line, rows of desks facing a board, guest
## rooms with a bed and a desk), every new piece is cover with book HP or decor that never
## blocks, and no furniture ever closes the way through a room.

const SITES := ["restaurant", "hotel", "bank", "school"]
static var _cache: Array[TacMap] = []


func _maps() -> Array[TacMap]:
	if _cache.is_empty():
		for site in SITES:
			for s in 2:
				var floors: Array = RulesDB.gen("sites.json")[site].floors
				_cache.append(SceneGen.generate(7300 + s * 17 + SITES.find(site), "lone_building", {"site": site, "security": 2, "floors": int(floors[s])}))
	return _cache


func _tag(m: TacMap) -> String:
	return "%s seed %d" % [m.structures[0].site, m.seed_value]


func _in(m: TacMap, kind: String, room_kind: String) -> Array:
	return m.cover.filter(func(c): return c.kind == kind and c.room >= 0 and m.rooms[c.room].kind == room_kind)


func _decor_in(m: TacMap, kind: String, room_kind: String) -> Array:
	return m.decor.filter(func(d): return d.kind == kind and m.rooms[d.room].kind == room_kind)


func test_set_pieces_are_cover_or_decor() -> void:
	var rooms_def := RulesDB.gen("rooms.json")
	var hp: Dictionary = RulesDB.load_json("armor.json")["cover_hp"]
	for piece in Furnish.PIECES:
		var mat: Array = Furnish.PIECES[piece]
		assert_true(hp.has(mat[0]), "%s: a material on the cover table" % piece)
		assert_true(int(hp[mat[0]][0 if mat[1] else 1]) > 0, "%s: cover with HP (else it belongs in DECOR)" % piece)
	for d in Furnish.DECOR:
		assert_false(Furnish.PIECES.has(d), "%s is decor, not cover" % d)
	var sets: Dictionary = rooms_def["_sets"]
	for name in sets:
		if name.begins_with("_"):
			continue
		for e in sets[name]:
			var k := String(e[2])
			if k.begins_with("~"):
				assert_true(k.substr(1) in Furnish.DECOR, "set %s: decor %s known" % [name, k])
			else:
				assert_true(Furnish.PIECES.has(k), "set %s: %s has cover data" % [name, k])
	for kind in rooms_def:
		if kind.begins_with("_"):
			continue
		for spec in rooms_def[kind].get("furniture", []):
			if spec is Array:
				assert_true(Furnish.PIECES.has(spec[0]), "%s: %s has cover data" % [kind, spec[0]])
				continue
			if spec.has("set"):
				assert_true(sets.has(spec.set), "%s: set %s exists" % [kind, spec.set])
			for k in spec.get("cycle", []) + ([spec.piece] if spec.has("piece") else []):
				assert_true(Furnish.PIECES.has(k), "%s: %s has cover data" % [kind, k])


func test_furniture_never_blocks_a_room() -> void:
	for m in _maps():
		var tag := _tag(m)
		for c in m.cover:
			assert_false(m.has_decor_at(c.floor, c.pos), "%s: decor under the %s at %s" % [tag, c.kind, c.pos])
		for d in m.decor:
			assert_true(m.walkable(d.floor, d.pos), "%s: %s at %s stands on open floor" % [tag, d.kind, d.pos])
		for r in m.rooms:
			if r.cells == 0 or int(r.get("structure", -1)) != 0:
				continue
			var open := {}
			for c in Furnish.room_cells(m, r):
				if m.walkable(r.floor, c):
					open[c] = true
			assert_false(open.is_empty(), "%s: room %d (%s) has floor left" % [tag, r.id, r.kind])
			if open.is_empty():
				continue
			var start: Vector2i = open.keys()[0]
			var seen := {start: true}
			var q: Array[Vector2i] = [start]
			while not q.is_empty():
				var c: Vector2i = q.pop_back()
				for dd in MapGen.DIRS:
					if open.has(c + dd) and not seen.has(c + dd):
						seen[c + dd] = true
						q.append(c + dd)
			assert_eq(seen.size(), open.size(), "%s: room %d (%s, floor %d) is one open area" % [tag, r.id, r.kind, r.floor])
			# every doorway into the room lands on open floor
			for d in m.doors:
				if int(d.floor) != int(r.floor) or not (int(d.a) == int(r.id) or int(d.b) == int(r.id)):
					continue
				var lands := false
				for dd in MapGen.DIRS:
					if open.has(d.pos + dd):
						lands = true
				assert_true(lands, "%s: the door at %s opens onto open floor in the %s" % [tag, d.pos, r.kind])


func test_bank_has_a_teller_line_a_queue_and_a_vault_door() -> void:
	for m in _maps():
		if m.structures[0].site != "bank":
			continue
		var tag := _tag(m)
		var tellers := _in(m, "teller_counter", "teller_line")
		assert_true(tellers.size() >= 4, "%s: a teller counter line (%d)" % [tag, tellers.size()])
		var line := {}
		for t in tellers:
			line[t.pos.y] = line.get(t.pos.y, 0) + 1
			var glass := m.t(t.floor, t.pos.x + t.face.x, t.pos.y + t.face.y) == TacMap.T.WALL and int(m.wall_mat[t.floor][(t.pos.y + t.face.y) * m.w + t.pos.x + t.face.x]) == 6
			assert_true(glass, "%s: the teller at %s faces the hall through bulletproof glass" % [tag, t.pos])
		assert_eq(line.size(), 1, "%s: one straight counter" % tag)
		assert_true(_decor_in(m, "stanchion", "banking_hall").size() >= 6, "%s: queue posts in the hall" % tag)
		assert_true(_in(m, "desk", "banking_hall").size() >= 1, "%s: customer desks in the hall" % tag)
		assert_eq(_in(m, "vault_door", "bank_vault").size(), 1, "%s: the vault door" % tag)
		for r in m.rooms:
			if r.kind == "loan_office" and r.cells > 0:
				assert_true(_in(m, "desk", "loan_office").size() >= 1, "%s: a desk in the loan office" % tag)


func test_restaurant_has_a_host_stand_booths_tables_and_a_kitchen_line() -> void:
	for m in _maps():
		if m.structures[0].site != "restaurant":
			continue
		var tag := _tag(m)
		assert_eq(_in(m, "host_stand", "dining_room").size(), 1, "%s: a host stand by the door" % tag)
		assert_true(_in(m, "booth", "dining_room").size() >= 4, "%s: booths along a wall" % tag)
		var tables := _in(m, "table", "dining_room")
		assert_true(tables.size() >= 4, "%s: tables (%d)" % [tag, tables.size()])
		assert_true(_decor_in(m, "side_chair", "dining_room").size() >= tables.size(), "%s: chairs at the tables" % tag)
		assert_true(_in(m, "stove", "commercial_kitchen").size() >= 2, "%s: a range" % tag)
		assert_true(_in(m, "pass", "commercial_kitchen").size() >= 1, "%s: a pass to the dining room" % tag)
		assert_true(_in(m, "shelf", "cold_store").size() >= 1, "%s: cold-store shelving" % tag)


func test_hotel_has_a_front_desk_and_furnished_guest_rooms() -> void:
	for m in _maps():
		if m.structures[0].site != "hotel":
			continue
		var tag := _tag(m)
		assert_eq(_in(m, "reception", "lobby").size(), 3, "%s: a front desk" % tag)
		assert_true(_in(m, "armchair", "lobby").size() >= 2, "%s: a seating group" % tag)
		for r in m.rooms:
			if r.kind != "guest_room" or r.cells == 0:
				continue
			var mine := m.cover.filter(func(c): return c.room == r.id)
			assert_eq(mine.filter(func(c): return c.kind == "bed").size(), 1, "%s: a bed in guest room %d" % [tag, r.id])
			assert_eq(mine.filter(func(c): return c.kind == "desk").size(), 1, "%s: a desk in guest room %d" % [tag, r.id])
			assert_true(m.decor.any(func(d): return d.room == r.id and d.kind == "nightstand"), "%s: a nightstand in guest room %d" % [tag, r.id])
			# one window per outside wall (two on a long one), not a random scatter
			var windows := 0
			var b: Rect2i = r.bounds
			for y in range(b.position.y - 1, b.end.y + 1):
				for x in range(b.position.x - 1, b.end.x + 1):
					if int(m.wall_mat[r.floor][y * m.w + x]) == 5 and m.t(r.floor, x, y) == TacMap.T.WALL:
						windows += 1
			assert_between(windows, 1, 2, "%s: guest room %d's window" % [tag, r.id])


func test_school_has_classroom_rows_lockers_and_bleachers() -> void:
	for m in _maps():
		if m.structures[0].site != "school":
			continue
		var tag := _tag(m)
		for r in m.rooms:
			if r.kind != "classroom" or r.cells < 20:
				continue
			var desks: Array = m.cover.filter(func(c): return c.room == r.id and c.kind == "school_desk")
			assert_true(desks.size() >= 3, "%s: rows of desks in classroom %d" % [tag, r.id])
			var faces := {}
			for d in desks:
				faces[d.face] = true
			assert_eq(faces.size(), 1, "%s: classroom %d's desks all face the board" % [tag, r.id])
			var board: Array = m.decor.filter(func(d): return d.room == r.id and d.kind == "board")
			assert_eq(board.size(), 1, "%s: a board in classroom %d" % [tag, r.id])
			if not board.is_empty() and not desks.is_empty():
				assert_eq(board[0].face, -(desks[0].face as Vector2i), "%s: the board faces the class" % tag)
		assert_true(_in(m, "locker", "hallway").size() >= 6, "%s: lockers along the corridor" % tag)
		assert_true(_in(m, "bleachers", "gym").size() >= 4, "%s: bleachers in the gym" % tag)
		assert_eq(_in(m, "crate", "gym").size(), 0, "%s: an open gym floor" % tag)
		assert_true(_in(m, "table", "cafeteria").size() >= 3, "%s: cafeteria tables" % tag)
