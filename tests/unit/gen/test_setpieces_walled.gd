extends TestCase
## Set pieces batch 3: the Combat Zone (Network 54's walled film set, NC2045 p.216) and the
## Estates (the Executive Zone's mansions, p.235). The generic checks (key rooms, reachability,
## objectives, determinism) are in test_setpieces.gd; these check what makes each one itself.

const SEEDS := [11, 2024, 77031]
static var _cache: Dictionary = {}


func _map(id: String, s: int, extra := {}) -> TacMap:
	var key := "%s/%d/%s" % [id, s, JSON.stringify(extra)]
	if not _cache.has(key):
		var o := {"setpiece": id}
		o.merge(extra, true)
		_cache[key] = SceneGen.generate(s, "lone_building", o)
	return _cache[key]


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func _part(m: TacMap, part: String) -> Dictionary:
	for st in m.structures:
		if String(st.get("part", "")) == part:
			return st
	return {}


func _deploy(m: TacMap) -> Vector3i:
	for e in m.entrances:
		if e.kind == "deploy":
			return Vector3i(e.pos.x, e.pos.y, int(e.floor))   # street level (m.street)
	return Vector3i(-1, -1, -1)


func test_locations_play_as_their_set_pieces() -> void:
	assert_eq(String(Campaign._place_at("new_westbrook_5").get("setpiece", "")), "combat_zone", "the Combat Zone")
	assert_eq(String(Campaign._place_at("executive_zone_1").get("setpiece", "")), "the_estates", "the Estates")
	assert_false(Campaign._place_at("executive_zone_2").has("setpiece"), "the country club stays procedural")


func test_combat_zone_is_a_walled_fake_city() -> void:
	for s in SEEDS:
		var m := _map("combat_zone", s)
		var tag := "combat_zone seed %d" % s
		var a: Array = m.params.get("hazard_area", [])
		assert_eq(a.size(), 4, "%s: the set's area is the hazard area" % tag)
		var city := Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))
		# the wall: concrete all round the set and the yard, but for its gates
		var wall := Rect2i(city.position.x - 1, 2, city.size.x + 2, city.end.y - 1)
		var holes := 0
		for x in range(wall.position.x, wall.end.x):
			for y in [wall.position.y, wall.end.y - 1]:
				if m.t(m.street, x, y) != TacMap.T.WALL:
					holes += 1
					assert_eq(m.t(m.street, x, y), TacMap.T.DOOR, "%s: (%d, %d) on the wall is a gate" % [tag, x, y])
				elif x > wall.position.x:
					assert_eq(int(m.wall_mat[m.street][y * m.w + x]), 1, "%s: a concrete wall" % tag)
		for y in range(wall.position.y, wall.end.y):
			for x in [wall.position.x, wall.end.x - 1]:
				if m.t(m.street, x, y) != TacMap.T.WALL:
					holes += 1
					assert_eq(m.t(m.street, x, y), TacMap.T.DOOR, "%s: (%d, %d) on the wall is a gate" % [tag, x, y])
		assert_between(holes, 3, 3, "%s: main gate, side door, yard gate" % tag)
		# the fake city: the district's buildings inside the set, none outside it
		var set_blds := m.structures.filter(func(st): return st.kind == "building" and String(st.get("part", "")) == "" and city.encloses(st.rect))
		assert_true(set_blds.size() >= 5, "%s: a fake city of ruins (%d buildings)" % [tag, set_blds.size()])
		assert_false(m.structures.any(func(st): return st.target and String(st.get("part", "")) != "main"), "%s: only the bunker is the target" % tag)
		var main := _part(m, "main")
		assert_true((main.rect as Rect2i).end.y < city.position.y, "%s: the production bunker behind the set, in the yard" % tag)
		# the crew comes in from the street outside the wall
		var d := _deploy(m)
		assert_true(d.y > wall.end.y, "%s: deploys on the street outside" % tag)
		# tunnels: hatches in the set's streets, a guard post at each
		var hatches := m.entrances.filter(func(e): return e.kind == "tunnel")
		assert_true(hatches.size() >= 3, "%s: tunnel hatches (%d)" % [tag, hatches.size()])
		for h in hatches:
			assert_true(city.has_point(h.pos) and m.walkable(m.street, h.pos), "%s: hatch %s open, in the set" % [tag, h.pos])
			assert_true(m.posts.any(func(p): return p.kind == "tunnel" and Vector2(p.pos).distance_to(Vector2(h.pos)) <= 1.0), "%s: a guard at hatch %s" % [tag, h.pos])
		# broadcast: camera masts in the set's streets, cameras and turrets on its NET, an uplink dish
		var masts := m.cover.filter(func(c): return c.kind == "camera_mast")
		assert_true(masts.size() >= 6, "%s: camera masts (%d)" % [tag, masts.size()])
		var sid := int(m.structures.filter(func(st): return st.kind == "arena")[0].id)
		var cams := m.devices.filter(func(dv): return dv.structure == sid and dv.type == "camera")
		assert_true(cams.size() >= 4, "%s: cameras on the set (%d)" % [tag, cams.size()])
		assert_true(m.devices.any(func(dv): return dv.structure == sid and dv.type == "turret"), "%s: turrets on the set" % tag)
		assert_true(m.cover.any(func(c): return c.kind == "dish"), "%s: the uplink dish" % tag)
		assert_true(m.cover.filter(func(c): return city.has_point(c.pos) and c.kind in ["rubble", "wreck", "barrier", "sandbags"]).size() >= 20, "%s: a battlefield to fight over" % tag)


func test_combat_zone_mist_on_the_set_only() -> void:
	var m := _map("combat_zone", SEEDS[0])
	var dice := Dice.new(9)
	var e := Encounter.setup(m, dice, _crew(dice), "rescue", {"faction": "network_54"})
	assert_true(e.hazard != null, "the MIST is the set piece's rule")
	assert_eq(e.hazard.name, "MIST", "named")
	assert_eq(e.post_faction, "network_54", "Net54 Security on the posts")
	var a: Array = m.params.hazard_area
	assert_eq(e.hazard.area, Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3])), "only over the set")
	e.hazard.force_stage(4)
	var cap: Dictionary = e.units[int(e.objective.captive)]
	assert_false(e.hazard.outside(cap.pos), "the bunker's prep cells are off the set: no MIST there")
	var d := _deploy(m)
	assert_false(e.hazard.outside(d), "nor on the street outside")
	var far := Vector3i(e.hazard.area.position.x + 1, e.hazard.area.end.y - 2, m.street)
	assert_true(e.hazard.outside(far), "a corner of the set is outside the final circle")
	assert_true(e.hazard.bites("captive", far), "the contestant's implant zaps them")


func test_estates_draw_a_named_owner() -> void:
	var names := {}
	for s in range(12):
		var m := _map("the_estates", 300 + s)
		var v := SetPieces.variant(m)
		assert_false(v.is_empty(), "seed %d: an owner" % (300 + s))
		names[String(v.name)] = true
		assert_true(SetPieces.place_name(m).begins_with("The Estates · "), "the HUD names the estate")
	assert_true(names.size() >= 5, "the owner varies per gig (%s)" % [names.keys()])
	var sp := SetPieces.get_def("the_estates")
	assert_eq((sp.variants as Array).size(), 12, "the twelve confirmed owners A-L")
	for v in sp.variants:
		assert_eq(int(v.security_code.n), 10, "%s: Security Code 10" % v.name)
		assert_true(World.has_faction(String(v.security_code.faction)), "%s: its guards" % v.name)


func test_sanderson_estate_is_danger_gal() -> void:
	var m := _map("the_estates", SEEDS[0], {"variant": "1i"})
	assert_eq(String(SetPieces.variant(m).name), "Michiko Sanderson's estate", "forced by id")
	var dice := Dice.new(4)
	var e := Encounter.setup(m, dice, _crew(dice), "assassinate", {"faction": "lazarus", "security_code": {"n": 10, "faction": "lazarus", "intensity": "heavy", "hardened": true}})
	assert_eq(e.post_faction, "danger_gal", "Danger Gal on the posts")
	assert_eq(String(e.code.faction), "danger_gal", "and answering the call")
	var m2 := _map("the_estates", SEEDS[0], {"variant": "1d"})
	var e2 := Encounter.setup(m2, dice, _crew(dice), "assassinate", {"faction": "lazarus"})
	assert_eq(e2.post_faction, "lazarus", "Lazarus everywhere else")
	var ur := _map("the_estates", SEEDS[0], {"variant": "1l"})
	assert_true(float(ur.structures.filter(func(st): return st.target)[0].params.get("net_threat", 1.0)) > 1.0, "UR's NET is tougher")


func test_estate_grounds() -> void:
	for s in SEEDS:
		var m := _map("the_estates", s)
		var tag := "the_estates seed %d" % s
		var main := _part(m, "main")
		assert_eq(String(main.site), "villa", "%s: the villa site" % tag)
		assert_false(_part(m, "garage").is_empty(), "%s: a garage" % tag)
		assert_true(m.structures.any(func(st): return st.site == "guard_booth"), "%s: a gatehouse" % tag)
		var deck: Array = m.rooms.filter(func(r): return r.cells > 0 and r.kind == "pool_deck")
		assert_eq(deck.size(), 1, "%s: a pool deck" % tag)
		var water := 0
		var b: Rect2i = deck[0].bounds
		for y in range(b.position.y - 1, b.end.y + 1):
			for x in range(b.position.x - 1, b.end.x + 1):
				if m.inb(x, y) and m.t(0, x, y) == TacMap.T.WATER:
					water += 1
		assert_true(water >= 30, "%s: the pool (%d squares)" % [tag, water])
		assert_true(b.end.y <= int((main.rect as Rect2i).position.y) + 1, "%s: the pool behind the house" % tag)
		assert_true(m.cover.any(func(c): return c.kind == "fountain"), "%s: a fountain on the lawn" % tag)
		assert_true(m.cover.filter(func(c): return c.kind == "tree").size() >= 6, "%s: trees round the grounds" % tag)
		var gate: Dictionary = m.entrances.filter(func(e): return e.kind == "gate")[0]
		var concrete := 0
		for x in m.w:
			var y: int = gate.pos.y
			if m.t(0, x, y) == TacMap.T.WALL and int(m.wall_mat[0][y * m.w + x]) == 1:
				concrete += 1
		assert_true(concrete >= m.w / 2, "%s: a concrete wall along the street" % tag)
		var gr: Array = m.rooms.filter(func(r): return r.cells > 0 and r.kind == "estate_grounds")
		assert_true(m.devices.any(func(dv): return dv.type == "turret" and dv.room == gr[0].id), "%s: automated turrets on the lawns" % tag)
