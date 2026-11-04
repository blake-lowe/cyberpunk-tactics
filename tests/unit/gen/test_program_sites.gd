extends TestCase
## Programmed sites (Layouts.program): restaurant, hotel, bank and school, laid out room by room
## from the brief in data/gen/sites.json. Every seed must give a playable building: reachable rooms,
## the rooms the brief names opening onto each other, stairs in stair halls, every objective placed.

const SITES := ["restaurant", "hotel", "bank", "school"]
static var _cache: Array[TacMap] = []


func _maps() -> Array[TacMap]:
	if _cache.is_empty():
		for site in SITES:
			for s in 3:
				var o := {"site": site, "security": (s * 2 + SITES.find(site)) % 4, "basement_storeys": 0}   # above grade: basements are test_basements.gd's
				if s == 2:   # the tallest building of each (a hotel's suite floor, a bank's second storey)
					o["floors"] = int(RulesDB.gen("sites.json")[site].floors[1])
				_cache.append(SceneGen.generate(4100 + s * 31 + SITES.find(site), "lone_building", o))
	return _cache


func _site(m: TacMap) -> String:
	return String(m.structures[0].site)


func _tag(m: TacMap) -> String:
	return "%s seed %d" % [_site(m), m.seed_value]


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func test_programmed_sites_are_reachable_and_zoned() -> void:
	var rooms_def := RulesDB.gen("rooms.json")
	for m in _maps():
		var tag := _tag(m)
		assert_eq(String(m.structures[0].algorithm), "program", tag)
		var e := m.main_entrance()
		assert_false(e.is_empty(), "%s: a main entrance" % tag)
		if e.is_empty():
			continue
		var inside := m.label(0, e.pos.x, e.pos.y - 1)   # lone buildings face the street (south)
		var enter: Array = RulesDB.gen("sites.json")[_site(m)].layout.enter
		assert_true(inside >= 0 and String(m.rooms[inside].kind) in enter, "%s: the front door opens into %s" % [tag, enter])
		var reach := m.reachable(Vector3i(e.pos.x, e.pos.y, e.floor))
		for r in m.rooms:
			if r.cells == 0:
				continue
			assert_true(rooms_def.has(r.kind), "%s: room kind %s has furniture data" % [tag, r.kind])
			var any := false
			for c in Furnish.room_cells(m, r):
				if reach.has(Vector3i(c.x, c.y, r.floor)):
					any = true
					break
			assert_true(any, "%s: room %d (%s, floor %d) reachable" % [tag, r.id, r.kind, r.floor])
		for d in m.devices:
			assert_true(reach.has(Vector3i(d.pos.x, d.pos.y, d.floor)) or m.t(d.floor, d.pos.x, d.pos.y) == TacMap.T.DOOR, "%s: %s reachable" % [tag, d.type])
		for d in m.doors:
			if d.a >= 0:
				assert_true(absi(int(m.rooms[d.a].zone) - int(m.rooms[d.b].zone)) <= 1, "%s: doors step one security level at most" % tag)


func test_rooms_open_onto_what_the_brief_names() -> void:
	for m in _maps():
		var tag := _tag(m)
		var total := 0
		var off := 0
		for d in m.doors:
			if d.a < 0:
				continue
			total += 1
			var ka := String(m.rooms[d.a].kind)
			var kb := String(m.rooms[d.b].kind)
			if not BuildingGen._door_ok(m, d.a, d.b):
				off += 1
			for pair in [[ka, kb], [kb, ka]]:
				if pair[0] == "bank_vault":
					assert_eq(pair[1], "mantrap", "%s: the bank vault is entered only through the mantrap" % tag)
				if pair[0] == "vault" and _site(m) == "hotel":
					assert_eq(pair[1], "security_office", "%s: the hotel vault opens off the security office" % tag)
				if pair[0] in ["guest_room", "suite"]:
					assert_eq(pair[1], "corridor", "%s: guest rooms open onto the corridor" % tag)
				if pair[0] == "restroom":
					assert_false(pair[1] == "commercial_kitchen", "%s: no restroom opens into a kitchen" % tag)
				if pair[0] == "cold_store":
					assert_false(pair[1] in ["dining_room", "lobby"], "%s: the cold store is back of house" % tag)
		assert_true(off * 10 <= total, "%s: %d of %d doors stray from the brief" % [tag, off, total])


func test_stairs_and_lifts_stand_in_stair_halls() -> void:
	for m in _maps():
		var floors := int(m.structures[0].floors)
		if floors < 2:
			continue
		var tag := _tag(m)
		var lay: Dictionary = RulesDB.gen("sites.json")[_site(m)].layout
		var stairs := 0
		for v in m.verticals:
			var want: Array = lay.get("lift_in", lay.stair_in) if v.type == "elevator" else lay.stair_in
			stairs += 1 if v.type == "stairs" else 0
			for f in floors:
				var l := m.label(f, v.pos.x, v.pos.y)
				assert_true(l >= 0 and String(m.rooms[l].kind) in want, "%s: %s on floor %d stands in %s" % [tag, v.type, f, want])
		assert_eq(stairs, int(lay.get("stairs", 1)), "%s: stair shafts" % tag)


func test_bank_tellers_work_behind_glass() -> void:
	for m in _maps():
		if _site(m) != "bank":
			continue
		var glass := 0
		var counters := 0
		for r in m.rooms:
			if r.kind != "teller_line":
				continue
			for c in Furnish.room_cells(m, r):
				var w: Vector2i = c + Vector2i.DOWN
				if m.t(r.floor, w.x, w.y) == TacMap.T.WALL and int(m.wall_mat[r.floor][w.y * m.w + w.x]) == 6:
					glass += 1
			counters += m.cover.filter(func(cv): return cv.room == r.id and cv.kind == "teller_counter").size()
		assert_true(glass >= 4, "%s: bulletproof glass between the teller line and the hall (%d)" % [_tag(m), glass])
		assert_true(counters >= 2, "%s: teller counters (%d)" % [_tag(m), counters])


func test_every_objective_finds_its_place() -> void:
	for site in SITES:
		var anchors: Dictionary = RulesDB.gen("sites.json")[site].anchors
		for kind in Objective.kinds():
			var m := SceneGen.generate(77, "lone_building", {"site": site, "security": 2})
			var dice := Dice.new(3)
			var e := Encounter.setup(m, dice, _crew(dice), String(kind))
			var tag := "%s/%s" % [site, kind]
			assert_eq(String(e.objective.kind), String(kind), tag)
			var role := String({"assassinate": "vip", "rescue": "captive", "snatch": "package", "sabotage": "machine"}.get(kind, ""))
			if role != "":
				var cell: Vector3i
				match role:
					"vip": cell = e.units[int(e.objective.target)].pos
					"captive": cell = e.units[int(e.objective.captive)].pos
					_: cell = e.objective.cell
				var l := m.label(cell.z, cell.x, cell.y)
				assert_true(l >= 0 and int(m.rooms[l].structure) == 0, "%s: inside the target building" % tag)
				if l >= 0:
					assert_true(String(m.rooms[l].kind) in (anchors[role] as Dictionary), "%s: %s in a %s, one of %s" % [tag, role, m.rooms[l].kind, (anchors[role] as Dictionary).keys()])
			if kind == "data":
				assert_true(int(e.objective.get("node", -1)) >= 0, "%s: a File worth stealing" % tag)
			e.next_turn()
			assert_eq(e.state, "playing", "%s: playable" % tag)


func test_sites_size_their_lone_building() -> void:
	for site in SITES:
		var sdef: Dictionary = RulesDB.gen("sites.json")[site]
		for s in 3:
			var m := SceneGen.generate(900 + s, "lone_building", {"site": site})
			var shell: Rect2i = m.structures[0].rect
			assert_between(shell.size.x, sdef.footprint.w[0], sdef.footprint.w[1], "%s: frontage" % site)
			assert_between(shell.size.y, sdef.footprint.d[0], sdef.footprint.d[1], "%s: depth" % site)
			assert_between(int(m.structures[0].floors), sdef.floors[0], sdef.floors[1], "%s: storeys" % site)
	var m2 := SceneGen.generate(1, "lone_building", {"site": "hotel", "w": 44, "h": 30, "floors": 2})
	assert_eq(m2.w, 44, "the caller's size wins")
	assert_eq(int(m2.structures[0].floors), 2, "the caller's floors win")


## Planned from whichever side faces the street: the brief turns with the entrance.
func test_program_turns_to_face_the_street() -> void:
	for side in ["E", "N", ""]:
		var m := TacMap.new(40, 40, 3)
		for y in 40:
			for x in 40:
				m.set_t(0, x, y, TacMap.T.OUTSIDE)
		var shell := Rect2i(10, 3, 18, 22) if side != "E" else Rect2i(3, 10, 22, 18)
		if side == "":   # open ground only to the west: the building should face it
			for y in 40:
				for x in range(shell.end.x, 40):
					m.set_t(0, x, y, TacMap.T.VOID)
			for y in range(0, shell.position.y):
				for x in 40:
					m.set_t(0, x, y, TacMap.T.VOID)
			for y in range(shell.end.y, 40):
				for x in 40:
					m.set_t(0, x, y, TacMap.T.VOID)
		var st := BuildingGen.build(m, Dice.new(5), [], {"shell": shell, "site": "bank", "floors": 2, "security": 2, "target": true, "entry_side": side})
		var e := m.main_entrance()
		assert_false(e.is_empty(), "side %s: an entrance" % side)
		if e.is_empty():
			continue
		var want: String = side if side != "" else "W"
		var d: Vector2i = BuildingGen.SIDES[want]
		assert_eq(String(st.params.entry_side), want, "side %s: planned from %s" % [side, want])
		assert_false(shell.has_point(e.pos + d), "side %s: the door is on the %s facade" % [side, want])
		var l := m.label(0, e.pos.x - d.x, e.pos.y - d.y)
		assert_true(l >= 0 and m.rooms[l].kind == "banking_hall", "side %s: the door opens into the banking hall" % side)


func test_location_types_use_the_programmed_sites() -> void:
	for t in SITES:
		assert_eq(String(World.location_types()[t].get("site", "")), t, "%s places play as the %s site" % [t, t])
	assert_eq(String(World.location("the_glen_1").get("site", "")), "bank", "1st Night City Bank is a bank")


func test_programmed_sites_deterministic() -> void:
	for site in SITES:
		var a := JSON.stringify(SceneGen.generate(55, "lone_building", {"site": site, "security": 2}).to_dict())
		var b := JSON.stringify(SceneGen.generate(55, "lone_building", {"site": site, "security": 2}).to_dict())
		assert_true(a == b, site + " deterministic")
