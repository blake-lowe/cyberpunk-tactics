extends TestCase
## Set pieces (data/gen/setpieces.json): Fort Sumter, Ziggurat HQ, Main Port and Flotsam. Every
## seed must build the recipe: its key rooms, everything reachable from the crew's deploy zone,
## every objective placed where the recipe anchors it, and the recipe's posts and rules.

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
			return Vector3i(e.pos.x, e.pos.y, 0)
	return Vector3i(-1, -1, -1)


func test_every_set_piece_has_a_location_and_valid_data() -> void:
	var rooms_def := RulesDB.gen("rooms.json")
	var sites := RulesDB.gen("sites.json")
	for id in SetPieces.ids():
		var sp := SetPieces.get_def(id)
		assert_false(String(sp.get("cite", "")) == "", "%s: cited" % id)
		assert_false(String(sp.get("_why", "")) == "", "%s: _why" % id)
		assert_true(World.has_faction(String(sp.faction)), "%s: faction %s" % [id, sp.faction])
		for loc in sp.locations:
			assert_false(World.location(loc).is_empty(), "%s: location %s exists" % [id, loc])
			assert_eq(String(World.location(loc).get("setpiece", "")), id, "%s: World.location(%s) names it" % [id, loc])
			assert_eq(String(World.location(loc).get("owner", "")), String(sp.faction), "%s: the location's owner guards it" % id)
		for part in sp.sites:
			assert_true(sites.has(String(sp.sites[part].base)), "%s/%s: base site" % [id, part])
		for part in sp.key_rooms:
			for k in sp.key_rooms[part]:
				assert_true(rooms_def.has(k) or k in ["roof", "terrace"], "%s: key room %s has furniture data" % [id, k])
		for kind in sp.anchors:
			assert_true(Objective.kinds().has(kind), "%s: anchors for objective kind %s" % [id, kind])
	assert_eq(String(World.location("south_night_city_4").get("setpiece", "")), "fort_sumter", "Fort Sumter")
	assert_eq(String(World.location("upper_marina_40").get("setpiece", "")), "ziggurat_hq", "Ziggurat HQ")
	assert_eq(String(World.location("port_of_night_city_7").get("setpiece", "")), "main_port", "Main Port")
	assert_eq(String(World.location("port_of_night_city_5").get("setpiece", "")), "main_port", "Flotsam")
	assert_false(World.location("the_glen_1").has("setpiece"), "an ordinary bank has no set piece")


func test_set_pieces_build_their_key_rooms() -> void:
	for id in SetPieces.ids():
		var sp := SetPieces.get_def(id)
		for s in SEEDS:
			var m := _map(id, s)
			var tag := "%s seed %d" % [id, s]
			assert_eq(String(m.params.get("setpiece", "")), id, tag)
			for part in sp.key_rooms:
				var kinds := {}
				if part == "_scene":
					for r in m.rooms:
						if r.cells > 0 and r.get("outdoor", false):
							kinds[String(r.kind)] = true
				else:
					var st := _part(m, part)
					assert_false(st.is_empty(), "%s: builds %s" % [tag, part])
					if st.is_empty():
						continue
					for r in m.rooms:
						if r.cells > 0 and r.get("structure", -1) == st.id:
							kinds[String(r.kind)] = true
				for k in sp.key_rooms[part]:
					assert_true(kinds.has(k), "%s: %s has a %s (has %s)" % [tag, part, k, kinds.keys()])


func test_set_pieces_are_connected() -> void:
	for id in SetPieces.ids():
		for s in SEEDS:
			var m := _map(id, s)
			var tag := "%s seed %d" % [id, s]
			var d := _deploy(m)
			assert_true(d.x >= 0, "%s: a deploy zone" % tag)
			var reach := m.reachable(d)
			for r in m.rooms:
				if r.cells == 0 or r.get("structure", -1) < 0:
					continue
				var st: Dictionary = m.structures[r.structure]
				if String(st.get("part", "")) == "" and st.kind == "building":
					continue
				var any := false
				for c in Furnish.room_cells(m, r):
					if reach.has(Vector3i(c.x, c.y, r.floor)):
						any = true
						break
				assert_true(any, "%s: %s room %d (%s, floor %d) reachable from the deploy zone" % [tag, st.get("part", st.kind), r.id, r.kind, r.floor])
			for dv in m.devices:
				if m.structures[dv.structure].target:
					assert_true(reach.has(Vector3i(dv.pos.x, dv.pos.y, dv.floor)) or m.t(dv.floor, dv.pos.x, dv.pos.y) == TacMap.T.DOOR, "%s: %s reachable" % [tag, dv.type])


func test_every_objective_finds_its_place() -> void:
	for id in SetPieces.ids():
		var sp := SetPieces.get_def(id)
		for loc in sp.locations:   # each location may target another part (the port: freighter or Sakata Maru)
			for kind in Objective.kinds():
				var m := _map(id, SEEDS[1], {"location": loc})
				var dice := Dice.new(5)
				var e := Encounter.setup(m, dice, _crew(dice), String(kind), {"faction": String(sp.faction)})
				var tag := "%s@%s/%s" % [id, loc, kind]
				assert_eq(String(e.objective.kind), String(kind), tag)
				var role := String(SetPieces.ROLE_OF.get(kind, ""))
				var tst: Dictionary = m.structures.filter(func(st): return st.target)[0]
				var anchors: Dictionary = sp.sites[tst.part].get("anchors", sp.anchors)[kind] if role != "" else {}
				if role != "":
					var cell: Vector3i
					match role:
						"vip": cell = e.units[int(e.objective.target)].pos
						"captive": cell = e.units[int(e.objective.captive)].pos
						_: cell = e.objective.cell
					var l := m.label(cell.z, cell.x, cell.y)
					assert_true(l >= 0 and int(m.rooms[l].structure) == int(tst.id), "%s: inside the target building" % tag)
					if l >= 0:
						assert_true(String(m.rooms[l].kind) in anchors, "%s: %s in a %s, one of %s" % [tag, role, m.rooms[l].kind, anchors.keys()])
				if kind == "data":
					assert_true(int(e.objective.get("node", -1)) >= 0, "%s: a File worth stealing" % tag)
				e.next_turn()
				assert_eq(e.state, "playing", "%s: playable" % tag)


func test_fort_sumter_roof_snipers() -> void:
	for s in SEEDS:
		var m := _map("fort_sumter", s)
		var tag := "fort_sumter seed %d" % s
		var main := _part(m, "main")
		var nests := m.posts.filter(func(p): return p.kind == "sniper")
		assert_between(nests.size(), 2, 3, "%s: sniper nests" % tag)
		for p in nests:
			var l := m.label(p.floor, p.pos.x, p.pos.y)
			assert_true(l >= 0 and m.rooms[l].kind == "roof" and m.rooms[l].structure == main.id, "%s: the nest is on the school roof" % tag)
			assert_true(m.has_cover_at(p.floor, p.pos + Vector2i(p.facing)), "%s: sandbags in front of the nest" % tag)
		var dice := Dice.new(9)
		var e := Encounter.setup(m, dice, _crew(dice), "eliminate", {"faction": "deadwoods"})
		var snipers := 0
		for u in e.units:
			if u.team == Encounter.OPFOR and m.label(u.pos.z, u.pos.x, u.pos.y) >= 0 and m.rooms[m.label(u.pos.z, u.pos.x, u.pos.y)].kind == "roof":
				snipers += 1
				assert_eq(String(u.c.weapons[0].def.get("name", "")), "Sniper Rifle", "%s: a sniper rifle in the nest" % tag)
				assert_false(u.has("patrol"), "%s: snipers hold their nest" % tag)
		assert_true(snipers >= 2, "%s: the nests are manned first (%d)" % [tag, snipers])


func test_ziggurat_floors_follow_the_book() -> void:
	for s in SEEDS:
		var m := _map("ziggurat_hq", s)
		var tag := "ziggurat_hq seed %d" % s
		var main := _part(m, "main")
		assert_eq(int(main.floors), 6, "%s: six storeys" % tag)
		var by_floor := {}
		var vaults := []
		for r in m.rooms:
			if r.cells > 0 and r.get("structure", -1) == main.id:
				by_floor.get_or_add(int(r.floor), {})[String(r.kind)] = true
				if r.kind == "data_vault":
					vaults.append(r)
		for k in ["net_museum", "auditorium", "lobby", "vehicle_bay"]:
			assert_true(by_floor[0].has(k), "%s: %s on the public first floor" % [tag, k])
		assert_true(by_floor[5].has("ceo_suite"), "%s: UR's suite at the apex" % tag)
		assert_true(by_floor[4].has("exec_office"), "%s: executives on the upper floors" % tag)
		assert_true(by_floor[2].has("content_control") or by_floor[3].has("content_control"), "%s: content control in the middle" % tag)
		assert_eq(vaults.map(func(r): return r.floor).reduce(func(a, f): return a if f in a else a + [f], []).size(), 1, "%s: the CitiNet servers are on one floor" % tag)
		# The curve: each upper storey stands on less of the plot than the one below.
		var area := []
		for f in 6:
			var n := 0
			for y in m.h:
				for x in m.w:
					var l := m.label(f, x, y)
					if l >= 0 and m.rooms[l].structure == main.id and not m.rooms[l].get("outdoor", false):
						n += 1
			area.append(n)
		assert_true(area[5] < area[4] and area[4] < area[2], "%s: the tower steps back (%s)" % [tag, area])
	var floors := {}
	for s in range(20):
		for r in _map("ziggurat_hq", 500 + s).rooms:
			if r.kind == "data_vault" and r.cells > 0:
				floors[int(r.floor)] = true
	assert_true(floors.size() >= 3, "the secret server room moves between floors from seed to seed (%s)" % [floors.keys()])


func test_public_floor_lets_the_crew_in() -> void:
	var m := _map("ziggurat_hq", SEEDS[0])
	var dice := Dice.new(4)
	var e := Encounter.setup(m, dice, _crew(dice), "data", {"faction": "ziggurat"})
	var crew: Dictionary = e.alive(0)[0]
	var guard := {}
	for u in e.units:
		if e.is_guard(u) and u.pos.z == 0:
			guard = u
			break
	assert_false(guard.is_empty(), "a guard on the ground floor")
	var lobby := -1
	var post := -1
	for r in m.rooms:
		if r.cells > 0 and r.floor == 0 and r.get("structure", -1) == _part(m, "main").id:
			if r.kind == "net_museum":
				lobby = r.id
			if r.kind == "vehicle_bay":
				post = r.id
	var pub: Vector2i = Furnish.room_cells(m, m.rooms[lobby])[0]
	crew.pos = Vector3i(pub.x, pub.y, 0)
	assert_true(e.passing_as_public(crew), "a visitor in the Net museum")
	var priv: Vector2i = Furnish.room_cells(m, m.rooms[post])[0]
	crew.pos = Vector3i(priv.x, priv.y, 0)
	assert_false(e.passing_as_public(crew), "an intruder in the vehicle bays")
	crew.pos = Vector3i(pub.x, pub.y, 0)
	e.alarm = 1
	assert_false(e.passing_as_public(crew), "no visitors once the alarm is up")
	var plain := SceneGen.generate(3, "lone_building", {"site": "corp_hq"})
	var e2 := Encounter.setup(plain, dice, _crew(dice), "data")
	assert_false(e2.passing_as_public(e2.alive(0)[0]), "only set pieces with public_access")


func test_port_targets_by_location() -> void:
	var flotsam := _map("main_port", SEEDS[0], {"location": "port_of_night_city_5"})
	var quays := _map("main_port", SEEDS[0], {"location": "port_of_night_city_7"})
	for pair in [[flotsam, "sakata_maru"], [quays, "freighter"]]:
		var m: TacMap = pair[0]
		var t := m.structures.filter(func(st): return st.target)
		assert_eq(t.size(), 1, "one target")
		assert_eq(String(t[0].get("part", "")), pair[1], "the location's target is the %s" % pair[1])
	var guns := flotsam.cover.filter(func(c): return c.kind == "aa_gun")
	assert_between(guns.size(), 2, 3, "anti-aircraft guns on the Sakata Maru")
	var sak := _part(flotsam, "sakata_maru")
	for g in guns:
		var l := flotsam.label(g.floor, g.pos.x, g.pos.y)
		assert_true(l >= 0 and flotsam.rooms[l].structure == sak.id and flotsam.rooms[l].get("outdoor", false), "the guns are on the Sakata's open deck")
	assert_true(flotsam.posts.filter(func(p): return p.kind == "aa_gun").size() >= 2, "a gunner at each gun")


func test_set_pieces_deterministic() -> void:
	for id in SetPieces.ids():
		var a := JSON.stringify(SceneGen.generate(55, "lone_building", {"setpiece": id}).to_dict())
		var b := JSON.stringify(SceneGen.generate(55, "lone_building", {"setpiece": id}).to_dict())
		assert_true(a == b, id + " deterministic")
