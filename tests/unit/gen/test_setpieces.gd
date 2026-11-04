extends TestCase
## Set pieces (data/gen/setpieces.json): Fort Sumter, Ziggurat HQ, Main Port and Flotsam, the
## Potentilla, MAX-TAC HQ, Trauma Team Tower, Totentanz and Eurasiabank Plaza. Every
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
			# the location's owner guards it; an unowned ruin is held by whoever the recipe names
			var owner := String(World.location(loc).get("owner", ""))
			assert_true(owner == String(sp.faction) or owner == "", "%s: the location's owner (%s) guards it" % [id, owner])
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


func test_a_gig_at_a_famous_place_plays_as_its_set_piece() -> void:
	assert_eq(String(Campaign._place_at("south_night_city_4").get("setpiece", "")), "fort_sumter", "Fort Sumter")
	assert_eq(String(Campaign._place_at("upper_marina_40").get("setpiece", "")), "ziggurat_hq", "Ziggurat HQ")
	assert_false(Campaign._place_at("little_europe_1").has("setpiece"), "ordinary places stay procedural")


func test_campaign_scene_opts_build_the_set_piece() -> void:
	var gig := {"security": 2, "scene": "lone_building"}
	gig.merge(Campaign._place_at("south_night_city_4"))
	var o := Campaign.scene_opts(gig)
	assert_eq(String(o.get("setpiece", "")), "fort_sumter", "scene_opts carries the set piece")
	assert_eq(String(o.get("location", "")), "south_night_city_4", "and its location")
	var m := SceneGen.generate(9, String(gig.get("scene", "lone_building")), o)
	assert_eq(String(m.params.get("setpiece", "")), "fort_sumter", "the campaign map is the set piece")


# --- Visual identity: the shapes the looks hang on ------------------------------------------------

## A building's indoor squares on storey f, as their bounding box.
func _extent(m: TacMap, sid: int, f: int) -> Rect2i:
	var r := Rect2i()
	for y in m.h:
		for x in m.w:
			var l := m.label(f, x, y)
			if l >= 0 and int(m.rooms[l].structure) == sid and not m.rooms[l].get("outdoor", false):
				r = Rect2i(x, y, 1, 1) if not r.has_area() else r.expand(Vector2i(x, y)).expand(Vector2i(x + 1, y + 1))
	return r


func _props_of(m: TacMap, kind: String) -> Array:
	return m.cover.filter(func(c): return c.kind == kind)


func test_ziggurat_is_a_stepped_pyramid() -> void:
	for s in SEEDS:
		var m := _map("ziggurat_hq", s)
		var tag := "ziggurat_hq seed %d" % s
		var main := _part(m, "main")
		var ext := []
		for f in 6:
			ext.append(_extent(m, int(main.id), f))
		for f in range(2, 6):   # every storey from the third steps in at both ends
			assert_true(ext[f].position.x > ext[f - 1].position.x and ext[f].end.x < ext[f - 1].end.x, "%s: floor %d set back at both ends (%s in %s)" % [tag, f, ext[f], ext[f - 1]])
		assert_true(ext[3].end.y < ext[2].end.y and ext[5].end.y < ext[4].end.y, "%s: the street front steps back too" % tag)
		var terraces := {}
		for r in m.rooms:
			if r.cells > 0 and r.kind == "terrace" and r.structure == main.id:
				terraces[int(r.floor)] = true
		assert_true(terraces.size() >= 4, "%s: a terrace on every step (%s)" % [tag, terraces.keys()])
		var spire := _props_of(m, "spire")
		assert_eq(spire.size(), 9, "%s: a 3x3 spire crowns it" % tag)
		if not spire.is_empty():
			assert_eq(int(spire[0].floor), 6, "%s: on the top roof" % tag)


func test_fort_sumter_reads_as_a_school() -> void:
	for s in SEEDS:
		var m := _map("fort_sumter", s)
		var tag := "fort_sumter seed %d" % s
		var main := _part(m, "main")
		var cupola := _props_of(m, "cupola")
		assert_eq(cupola.size(), 9, "%s: a bell cupola" % tag)
		for c in cupola:
			var l := m.label(c.floor, c.pos.x, c.pos.y)
			assert_true(l >= 0 and m.rooms[l].kind == "roof" and m.rooms[l].structure == main.id, "%s: on the school roof" % tag)
		var pole := _props_of(m, "flagpole")
		assert_eq(pole.size(), 1, "%s: a flagpole" % tag)
		var rect: Rect2i = main.rect
		if not pole.is_empty():
			assert_true(pole[0].pos.y >= rect.end.y, "%s: the flagpole stands in front of the school" % tag)
		var lawn := 0
		for y in range(rect.end.y, m.h):
			for x in m.w:
				if m.t(0, x, y) == TacMap.T.OUTSIDE and m.ground[y * m.w + x] == TacMap.G.GRASS:
					lawn += 1
		assert_true(lawn >= 40, "%s: a front lawn (%d squares)" % [tag, lawn])
		assert_eq(_props_of(m, "bus").size(), 5, "%s: the old school bus across the lawn" % tag)


func test_sakata_maru_is_a_warship() -> void:
	for s in SEEDS:
		var m := _map("main_port", s, {"location": "port_of_night_city_5"})
		var tag := "sakata seed %d" % s
		var sak := _part(m, "sakata_maru")
		var hull: Rect2i = sak.rect
		var deck := -1
		for r in m.rooms:
			if r.cells > 0 and r.kind == "terrace" and r.structure == sak.id:
				deck = int(r.floor) if deck < 0 else mini(deck, int(r.floor))
		var turrets := _props_of(m, "turret")
		assert_eq(turrets.size(), 8, "%s: two gun turrets" % tag)
		for t in turrets:
			assert_eq(int(t.floor), deck, "%s: turrets on the main deck" % tag)
		assert_eq(_props_of(m, "mast").size(), 1, "%s: a mast" % tag)
		assert_eq(_props_of(m, "funnel").size(), 4, "%s: a funnel" % tag)
		var sup := _extent(m, int(sak.id), 1)
		assert_true(sup.position.x - hull.position.x >= 8 and hull.end.x - sup.end.x >= 12, "%s: the superstructure stands amidships (%s on %s)" % [tag, sup, hull])
		# the raked bow: the eastern end narrows to a point
		var bow_w := 0
		for y in range(hull.position.y, hull.end.y):
			if m.label(0, hull.end.x - 2, y) >= 0 and m.rooms[m.label(0, hull.end.x - 2, y)].structure == sak.id:
				bow_w += 1
		assert_true(bow_w <= 4, "%s: a pointed bow (%d wide)" % [tag, bow_w])


# --- Batch 2 ---------------------------------------------------------------------------------------

func test_potentilla_is_five_petals_round_the_memorial() -> void:
	for s in SEEDS:
		var m := _map("norcal_potentilla", s)
		var tag := "potentilla seed %d" % s
		var court := {}
		for r in m.rooms:
			if r.cells > 0 and r.kind == "courtyard":
				court = r
		assert_false(court.is_empty(), "%s: the courtyard" % tag)
		var cc := Vector2((court.bounds as Rect2i).get_center())
		var angles := []
		for part in ["main", "navy_hq", "air_hq", "armor_hq", "engineer_hq"]:
			var st := _part(m, part)
			assert_false(st.is_empty(), "%s: petal %s" % [tag, part])
			if st.is_empty():
				continue
			var v := Vector2((st.rect as Rect2i).get_center()) - cc
			angles.append(rad_to_deg(v.angle()))
		angles.sort()
		for i in angles.size():
			var gap: float = (angles[0] + 360.0 - angles[i]) if i == angles.size() - 1 else angles[i + 1] - angles[i]
			assert_true(gap >= 40.0, "%s: the petals ring the court (%s)" % [tag, angles])
		var col := _props_of(m, "columbarium")
		assert_eq(col.size(), 9, "%s: the memorial columbarium" % tag)
		for c in col:
			assert_eq(m.label(0, c.pos.x, c.pos.y), int(court.id), "%s: in the courtyard" % tag)
		var main := _part(m, "main")
		assert_true(Vector2((main.rect as Rect2i).get_center()).y < cc.y, "%s: the intelligence petal heads the flower" % tag)


func test_maxtac_castle_round_its_garden() -> void:
	for s in SEEDS:
		var m := _map("maxtac_hq", s)
		var tag := "maxtac seed %d" % s
		var court := {}
		for r in m.rooms:
			if r.cells > 0 and r.kind == "courtyard":
				court = r
		var cc := Vector2((court.bounds as Rect2i).get_center())
		assert_true(Vector2((_part(m, "west_tower").rect as Rect2i).get_center()).x < cc.x, "%s: the armory tower to the west" % tag)
		assert_true(Vector2((_part(m, "east_tower").rect as Rect2i).get_center()).x > cc.x, "%s: the vehicle tower to the east" % tag)
		assert_true(_props_of(m, "planter").filter(func(c): return m.label(0, c.pos.x, c.pos.y) == int(court.id)).size() >= 6, "%s: roses in the garden" % tag)
		assert_true(int(court.zone) >= TacMap.Zone.SECURE, "%s: the garden is the castle's secret heart" % tag)
		var av := _props_of(m, "av")
		assert_true(av.size() >= 9, "%s: an AV on the east tower's pad" % tag)
		for c in av:
			var l := m.label(c.floor, c.pos.x, c.pos.y)
			assert_true(l >= 0 and m.rooms[l].structure == _part(m, "east_tower").id, "%s: on the vehicle tower" % tag)
		# the curtain wall: solid concrete (not chain-link) all round the grounds
		var wall := 0
		for x in m.w:
			if m.t(0, x, 1) == TacMap.T.WALL and m.wall_mat[0][1 * m.w + x] == 1:
				wall += 1
		assert_true(wall >= m.w - 4, "%s: a concrete curtain wall" % tag)


func test_trauma_team_tower_launch_terraces() -> void:
	for s in SEEDS:
		var m := _map("trauma_team_tower", s)
		var tag := "tt tower seed %d" % s
		var main := _part(m, "main")
		var by_floor := {}
		for r in m.rooms:
			if r.cells > 0 and r.structure == main.id:
				by_floor.get_or_add(int(r.floor), {})[String(r.kind)] = true
		for k in ["lobby", "clinic_waiting", "dispatch_office", "exec_office", "security_post"]:
			assert_true(by_floor[0].has(k), "%s: %s on the ground floor" % [tag, k])
		assert_true(by_floor[3].has("vehicle_bay"), "%s: the squads' AV bays open on the launch terrace" % tag)
		assert_true(by_floor[5].has("control_room"), "%s: air control at the top" % tag)
		var av := _props_of(m, "av")
		assert_true(av.size() >= 18, "%s: AVs on the pads (%d squares)" % [tag, av.size()])
		for c in av:
			var l := m.label(c.floor, c.pos.x, c.pos.y)
			assert_true(l >= 0 and m.rooms[l].kind == "terrace", "%s: AVs stand on terraces" % tag)
		var e0 := _extent(m, int(main.id), 0)
		var e5 := _extent(m, int(main.id), 5)
		assert_true(e5.size.x < e0.size.x * 0.75 and e5.size.y < e0.size.y, "%s: the tower steps back to its air-control top" % tag)


func test_totentanz_safe_inside_dangerous_outside() -> void:
	var m := _map("totentanz", SEEDS[0])
	var dice := Dice.new(4)
	var e := Encounter.setup(m, dice, _crew(dice), "assassinate", {"faction": "maelstrom"})
	var crew: Dictionary = e.alive(0)[0]
	var main := _part(m, "main")
	var cell_of := func(kind: String, f: int) -> Vector2i:
		for r in m.rooms:
			if r.cells > 0 and r.kind == kind and int(r.floor) == f:
				return Furnish.room_cells(m, r)[0]
		return Vector2i(-1, -1)
	for k in ["dance_floor", "bar", "foyer", "plaza"]:
		var v: Vector2i = cell_of.call(k, 0)
		assert_true(v.x >= 0, "a %s" % k)
		crew.pos = Vector3i(v.x, v.y, 0)
		assert_true(e.passing_as_public(crew), "a patron on the %s" % k)
	var out: Vector2i = cell_of.call("rubble_field", 0)
	crew.pos = Vector3i(out.x, out.y, 0)
	assert_false(e.passing_as_public(crew), "off the path, in Maelstrom's ruins")
	var back: Vector2i = cell_of.call("backstage", 0)
	crew.pos = Vector3i(back.x, back.y, 0)
	assert_false(e.passing_as_public(crew), "backstage")
	var lookouts := m.posts.filter(func(p): return p.kind == "lookout" and m.label(0, p.pos.x, p.pos.y) >= 0 and m.rooms[m.label(0, p.pos.x, p.pos.y)].kind == "rubble_field")
	assert_true(lookouts.size() >= 2, "Maelstrom lookouts out in the ruins")
	var crowd := e.units.filter(func(u): return u.team == Encounter.CIV_TEAM)
	assert_true(crowd.size() >= 4, "a crowd on the club floor (%d)" % crowd.size())
	assert_true(_extent(m, int(main.id), 4).size.x < _extent(m, int(main.id), 2).size.x, "the broken top of Burleson Tower")


func test_eurasiabank_sunken_ruin() -> void:
	for s in SEEDS:
		var m := _map("eurasiabank_plaza", s)
		var tag := "eurasiabank seed %d" % s
		var main := _part(m, "main")
		var ground := {}
		for r in m.rooms:
			if r.cells > 0 and r.structure == main.id and r.floor == 0:
				ground[String(r.kind)] = true
		for k in ["banking_hall", "bank_vault", "archive", "server_room"]:
			assert_true(ground.has(k), "%s: the drowned %s at the bottom" % [tag, k])
		assert_true(SetPieceDressing.look(m, int(main.id)).get("flooded", []).has("bank_vault"), "%s: the vaults stand in water" % tag)
		var e0 := _extent(m, int(main.id), 0)
		var e2 := _extent(m, int(main.id), 2)
		assert_true(e2.size.x * e2.size.y < e0.size.x * e0.size.y * 0.7, "%s: the crumbled top storey" % tag)
		var terr := m.rooms.filter(func(r): return r.cells > 0 and r.kind == "terrace" and r.structure == main.id)
		assert_true(terr.size() >= 1, "%s: rubble terraces to climb" % tag)
		var breaches := 0
		var rect: Rect2i = main.rect
		for y in range(rect.position.y, rect.end.y):
			for x in [rect.position.x, rect.end.x - 1]:
				if m.t(0, x, y) == TacMap.T.OUTSIDE:
					breaches += 1
		for x in range(rect.position.x, rect.end.x):
			for y in [rect.position.y, rect.end.y - 1]:
				if m.t(0, x, y) == TacMap.T.OUTSIDE:
					breaches += 1
		assert_true(breaches >= 2, "%s: breached walls (%d)" % [tag, breaches])


func test_batch_two_locations_play_as_their_set_pieces() -> void:
	for pair in [["norcal_military_base_13", "norcal_potentilla"], ["south_night_city_9", "maxtac_hq"], ["watson_development_32", "trauma_team_tower"],
			["hot_zone_11", "totentanz"], ["hot_zone_6", "eurasiabank_plaza"]]:
		assert_eq(String(Campaign._place_at(pair[0]).get("setpiece", "")), pair[1], pair[0])
