extends TestCase
## Towers, stage 1a: the sky band (docs/plans/towers.md; TowerGen, TacMap storeys, World.tower,
## Campaign tower offers, CustomGig). A tower gig plays a band near the top of a tall building: the
## floors are named by their real storey, the crew deploys from the lift car in the band's lift
## lobby (and rides it down to get out), responders come up the lift or the fire stair, and tower
## gigs are offered only past the progression gate, and rarely.

static var _maps := {}


func _band(tower: String, seed_value: int, sec := 2) -> TacMap:
	var key := "%s/%d/%d" % [tower, seed_value, sec]
	if not _maps.has(key):
		_maps[key] = SceneGen.generate(seed_value, "tower_top", {"tower": tower, "security": sec})
	return _maps[key]


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch"),
		Recruit.generate(dice, "tech", "edgerunner", "Rook")]
	return crew


# --- Storey numbering ------------------------------------------------------------------------

func test_floors_are_named_by_their_real_storey() -> void:
	var m := _band("raven", 1)
	assert_true(m.is_tower(), "a tower band")
	assert_eq(m.storey_base, 47, "47 storeys under the band")
	assert_eq(m.floors, 4, "48, 49, 50 and the roof")
	assert_eq([m.floor_name(0), m.floor_name(1), m.floor_name(2), m.floor_name(3)], ["48", "49", "50", "R"])
	assert_eq([m.storey(0), m.storey(2), m.storey(3)], [48, 50, 51], "the roof is the storey above the top floor")
	assert_eq(m.bands.size(), 1, "stage 1a: one band")
	assert_eq(int(m.bands[0].roof_floor), 3)
	assert_eq(String(m.tower.id), "raven")
	assert_eq(int(m.tower.storeys), 50, "the book's 50 storeys (NC2045 p.124-125)")
	var plain := SceneGen.generate(3, "lone_building", {"site": "corp_office", "basement_storeys": 0})
	assert_false(plain.is_tower())
	assert_eq(plain.floor_name(0), "1", "an ordinary map keeps 1, 2, 3")
	assert_false(plain.to_dict().has("bands") or plain.to_dict().has("storey_base") or plain.to_dict().has("tower"), "and its save stays as it was")


func test_storeys_survive_a_save_and_reload() -> void:
	var m := _band("highcourt", 2)
	var d: Dictionary = JSON.parse_string(JSON.stringify(m.to_dict()))
	assert_eq(int(d.storey_base), 27)
	var back := TacMap.new(m.w, m.h, m.floors)
	TacMap.storeys_from_dict(back, d)
	for f in m.floors:
		assert_eq(back.floor_name(f), m.floor_name(f), "floor %d" % f)
	assert_eq(back.tower, m.tower)
	# A campaign saved with a tower offer on the board builds the same band from it when it loads.
	var camp := Campaign.new_game(5)
	var offer := camp.tower_gig(RulesDB.gen("gigs.json"), "the_glen_24", "data_theft")
	offer["id"] = "test-tower"
	camp.board.append(offer)
	var path := "user://test_towers_save.json"
	assert_true(camp.save(path))
	var loaded := Campaign.load_from(path)
	DirAccess.remove_absolute(path)
	assert_true(loaded != null, "the save loads")
	assert_eq(JSON.stringify(loaded.to_dict()), JSON.stringify(camp.to_dict()), "the round trip keeps the campaign")
	assert_eq(String(loaded.board[-1].get("tower", "")), "the_glen_24")
	camp.accept(camp.board.size() - 1)
	loaded.accept(loaded.board.size() - 1)
	var a := GigSetup.for_campaign(camp).map
	var b := GigSetup.for_campaign(loaded).map
	assert_eq(JSON.stringify(a.to_dict()), JSON.stringify(b.to_dict()), "the same band, storeys and all")
	assert_eq(b.floor_name(b.street), "48")


# --- Tower data ------------------------------------------------------------------------------

func test_tower_data_is_complete_and_cited() -> void:
	var sites := RulesDB.gen("sites.json")
	var kinds: Array = (RulesDB.gen("gigs.json").templates as Array).map(func(t): return String(t.kind))
	var ids := {}
	assert_true(World.towers().size() >= 6, "the plan's corporate towers and a hotel (%d)" % World.towers().size())
	for lid in World.towers():
		var t := World.tower(String(lid))
		var tag := String(lid)
		assert_false(ids.has(t.id), "%s: short id %s unique" % [tag, t.id])
		ids[t.id] = true
		assert_eq(World.tower(String(t.id)).location, lid, "%s: found by its short id" % tag)
		assert_true(String(t.get("cite", "")).begins_with("NC2045 p."), "%s: cited" % tag)
		assert_true(t.get("storeys_ours") is bool and t.get("ours") is Array, "%s: says which numbers are ours" % tag)
		assert_true(int(t.storeys) > 6, "%s: a tower, not an ordinary building (more than 6 storeys)" % tag)
		var rec: Dictionary = sites.get(String(t.recipe), {})
		assert_true(bool(rec.get("tower", false)), "%s: recipe %s is a tower site" % [tag, t.recipe])
		var b: Dictionary = t.bands.get("sky", {})
		assert_false(b.is_empty(), "%s: a sky band" % tag)
		var s: Array = b.storeys
		assert_true(int(s[0]) >= 2 and int(s[1]) <= int(t.storeys) and int(s[0]) <= int(s[1]), "%s: band %s inside the tower" % [tag, s])
		assert_eq(int(s[1]), int(t.storeys), "%s: the sky band is the top of the building" % tag)
		assert_true(bool(b.get("roof", false)), "%s: the roof is played" % tag)
		assert_eq((b.programme as Array).size(), int(s[1]) - int(s[0]) + 1, "%s: one programme per storey" % tag)
		for pn in b.programme:
			assert_true((rec.get("storeys", {}) as Dictionary).has(String(pn)), "%s: programme %s in %s" % [tag, pn, t.recipe])
		var at := World.location(String(lid))
		var offered := {}
		for k in at.get("gigs", []):
			offered[String(k)] = true
		for h in at.get("hooks", []):
			for k in h.get("gigs", []):
				offered[String(k)] = true
		assert_false((b.gigs as Array).is_empty(), "%s: the band hosts jobs" % tag)
		for k in b.gigs:
			assert_true(String(k) in kinds and offered.has(String(k)), "%s: band job %s is one the place offers" % [tag, k])
	for name in ["tower_corp", "tower_hotel"]:
		var rec2: Dictionary = sites[name]
		var depth := -1
		for pn in rec2.storeys:
			var rows: Array = rec2.storeys[pn]
			if depth < 0:
				depth = rows.size()
			assert_eq(rows.size(), depth, "%s/%s: every programme shares the band plan" % [name, pn])
			assert_true(JSON.stringify(rows).contains("\"lift_lobby\"") and JSON.stringify(rows).contains("\"stair_hall\""), "%s/%s: a lift lobby and a fire stair" % [name, pn])


# --- Band generation -------------------------------------------------------------------------

func test_band_generation_is_deterministic_per_seed() -> void:
	for tower in ["raven", "highcourt"]:
		var a := JSON.stringify(SceneGen.generate(17, "tower_top", {"tower": tower, "security": 2}).to_dict())
		var b := JSON.stringify(SceneGen.generate(17, "tower_top", {"tower": tower, "security": 2}).to_dict())
		var c := JSON.stringify(SceneGen.generate(18, "tower_top", {"tower": tower, "security": 2}).to_dict())
		assert_true(a == b, "%s: one seed, one band" % tower)
		assert_false(a == c, "%s: another seed, another band" % tower)


func test_bands_are_playable_floor_plates_in_the_sky() -> void:
	for tower in ["raven", "maf", "ziggurat", "continental", "highcourt", "segotari"]:
		for s in [3, 11]:
			var m := _band(tower, s)
			var tag := "%s seed %d" % [tower, s]
			var t := World.tower(tower)
			var b: Dictionary = t.bands.sky
			assert_eq(m.floors, (b.programme as Array).size() + 1, "%s: the band's storeys and the roof" % tag)
			assert_eq(m.structures.size(), 1, "%s: one building" % tag)
			assert_eq(String(m.structures[0].name), String(t.name), "%s: named for the strip" % tag)
			# no street: nothing outdoors at the band's level, sky beyond the plate
			for y in m.h:
				for x in m.w:
					assert_false(m.t(0, x, y) == TacMap.T.OUTSIDE, "%s: no open ground at %d,%d" % [tag, x, y])
			assert_eq(m.t(0, 0, 0), TacMap.T.VOID, "%s: sky in the corner" % tag)
			assert_true(m.entrances.all(func(e): return e.kind != "door"), "%s: no street doors" % tag)
			# every room reachable from the lift car, the roof by the fire stair
			var dep := SceneGen.deploy_cells(m)
			var reach := m.reachable(dep[0])
			for r in m.rooms:
				if int(r.cells) == 0:
					continue
				assert_true(Furnish.room_cells(m, r).any(func(c): return reach.has(Vector3i(c.x, c.y, r.floor))), "%s: %s on %s reachable" % [tag, r.kind, m.floor_name(r.floor)])
			assert_true(m.rooms.any(func(r): return r.kind == "roof" and int(r.cells) > 0 and int(r.floor) == m.floors - 1), "%s: the roof is a room" % tag)
			# each storey has its programme's rooms: the lift lobby, the fire stair hall and the corridors
			for f in m.floors - 1:
				var kinds := m.rooms.filter(func(r): return int(r.cells) > 0 and int(r.floor) == f).map(func(r): return String(r.kind))
				for k in ["lift_lobby", "stair_hall", "corridor"]:
					assert_true(k in kinds, "%s: %s on %s" % [tag, k, m.floor_name(f)])
			var top := m.rooms.filter(func(r): return int(r.cells) > 0 and int(r.floor) == m.floors - 2).map(func(r): return String(r.kind))
			assert_true(top.any(func(k): return k in ["exec_office", "ceo_suite", "suite", "pool_deck"]), "%s: the top storey is its programme's (%s)" % [tag, top])
			# the lift car: one square on every storey of the band, in the lift lobby, doors onto open floor
			var car := TowerGen.car(m)
			assert_false(car.is_empty(), "%s: a lift car" % tag)
			if car.is_empty():
				continue
			assert_eq([int(car.from_floor), int(car.to_floor)], [0, m.floors - 2], "%s: the car runs the band's storeys, not the roof" % tag)
			for f in m.floors - 1:
				assert_eq(m.t(f, car.pos.x, car.pos.y), TacMap.T.ELEVATOR, "%s: car shaft on %s" % [tag, m.floor_name(f)])
				assert_eq(String(m.rooms[m.label(f, car.pos.x, car.pos.y)].kind), "lift_lobby", "%s: car in the lobby on %s" % [tag, m.floor_name(f)])
				var front: Vector2i = car.pos + car.face
				assert_eq(m.t(f, front.x, front.y), TacMap.T.FLOOR, "%s: the doors open onto the lobby" % tag)
			assert_true(m.verticals.any(func(v): return v.type == "stairs" and int(v.to_floor) == m.floors - 1), "%s: the fire stair goes up to the roof" % tag)
			assert_true(m.architecture != null, "%s: the target's NET" % tag)


# --- Deploy and extraction -------------------------------------------------------------------

func test_the_crew_deploys_from_the_lift_car_in_the_lift_lobby() -> void:
	for tower in ["raven", "highcourt", "n54"]:
		for s in [2, 9]:
			var m := _band(tower, s)
			var tag := "%s seed %d" % [tower, s]
			var dep: Dictionary = m.entrances.filter(func(e): return e.kind == "deploy")[0]
			var car := TowerGen.car(m)
			assert_eq(dep.pos, car.pos, "%s: the zone starts at the car" % tag)
			var cells := SceneGen.deploy_cells(m)
			assert_eq(cells.size(), SceneGen.DEPLOY_SIZE, "%s: room for the crew" % tag)
			assert_true(cells.has(Vector3i(car.pos.x, car.pos.y, 0)), "%s: the car is a deploy square" % tag)
			for v in cells:
				assert_eq(v.z, 0, "%s: on the band's lowest storey" % tag)
				assert_eq(String(m.rooms[m.label(0, v.x, v.y)].kind), "lift_lobby", "%s: %s in the lift lobby" % [tag, v])
			assert_eq(SceneGen.deploy_ap_clashes(m), [], "%s: no access point in jack-in reach of the lift" % tag)
			var dice := Dice.new(s + 1)
			var e := Encounter.setup(m, dice, _crew(dice), "data")
			for u in e.alive(Encounter.CREW):
				assert_true(cells.has(u.pos), "%s: %s starts in the lobby by the car" % [tag, u.c.display_name])
				assert_true(e.extract_cells.has(u.pos), "%s: riding the car down is the way out" % tag)
				assert_true(e.passing_as_public(u), "%s: stepping out of the car, the crew passes as visitors (HOUSE-RULE)" % tag)
			assert_eq(e.extract_cells.size(), cells.size(), "%s: the extraction zone is the deploy zone" % tag)
			assert_true(e.can_withdraw() or e.cur.is_empty() or e.cur.team != Encounter.CREW, "%s: the crew can ride straight back down" % tag)


# --- Responders ------------------------------------------------------------------------------

func test_responders_come_up_the_lift_or_the_fire_stair() -> void:
	for tower in ["raven", "maf"]:
		var m := _band(tower, 4)
		var dice := Dice.new(5)
		var e := Encounter.setup(m, dice, _crew(dice), "data", {"complications": false, "utilities": false})
		var arrivals := m.entrances.filter(func(en): return en.has("arrival"))
		assert_true(arrivals.any(func(en): return en.arrival == "lift") and arrivals.any(func(en): return en.arrival == "stairs"), "%s: lift and stair arrivals" % tower)
		for f in m.floors - 1:
			assert_true(arrivals.any(func(en): return int(en.floor) == f and en.arrival == "lift"), "%s: the car stops on %s" % [tower, m.floor_name(f)])
		# the crew on the band's middle storey: responders step out on that storey
		var mid := 1
		var car := TowerGen.car(m)
		var stair: Dictionary = m.verticals.filter(func(v): return v.type == "stairs")[0]
		for u in e.alive(Encounter.CREW):
			u.pos = Vector3i(car.pos.x, car.pos.y, mid) + Vector3i(car.face.x, car.face.y, 0) * (1 + e.alive(Encounter.CREW).find(u))
		var at := e.arrival_cell()
		assert_eq(at.z, mid, "%s: on the crew's storey" % tower)
		assert_eq(Vector2i(at.x, at.y), stair.pos, "%s: the fire stair, the far one from a crew by the lift" % tower)
		for u in e.alive(Encounter.CREW):   # now the crew by the stair: out of the lift
			u.pos = Vector3i(stair.pos.x, stair.pos.y, mid) + Vector3i(0, 0, 0)
			break
		var by_stair := e.alive(Encounter.CREW)
		for i in by_stair.size():
			var c := Vector2i(stair.pos) + Vector2i(i - 1, 1) if i != 1 else Vector2i(stair.pos)
			by_stair[i].pos = Vector3i(c.x, c.y, mid)
		at = e.arrival_cell()
		assert_eq(Vector2i(at.x, at.y), car.pos, "%s: out of the lift car when the crew holds the stair" % tower)
		var before := e.units.size()
		e._spawn_wave(["mook", "mook", "mook"] as Array[String], "BACKUP", Encounter.OPFOR, e.opfor_faction)
		var came := e.units.slice(before)
		assert_eq(came.size(), 3, "%s: the wave arrives" % tower)
		for u in came:
			assert_eq(int(u.pos.z), mid, "%s: on the alarm storey" % tower)
			var l := m.label(u.pos.z, u.pos.x, u.pos.y)
			assert_true(l >= 0 and String(m.rooms[l].kind) in ["lift_lobby", "corridor", "stair_hall"], "%s: by the lift (%s)" % [tower, m.rooms[l].kind if l >= 0 else "none"])
			assert_true(Vector2(u.pos.x - car.pos.x, u.pos.y - car.pos.y).length() <= 6.5, "%s: steps off the car" % tower)
		assert_eq(Complication._far_entrance(e), e.arrival_cell(), "%s: a complication's arrivals use the same doors" % tower)


func test_the_mark_rides_down_in_the_car_unless_the_crew_holds_it() -> void:
	var m := _band("haakensen", 6, 3)
	var dice := Dice.new(7)
	var e := Encounter.setup(m, dice, _crew(dice), "assassinate", {"complications": false, "utilities": false})
	var car := TowerGen.car(m)
	assert_eq(e.objective.exits, [Vector3i(car.pos.x, car.pos.y, 0)], "the car on the band's lowest storey is the only way out")


# --- Campaign: gated and rare ---------------------------------------------------------------

func _boards(camp: Campaign, n: int) -> Array:
	var out := []
	for i in n:
		camp.refresh_board()
		out.append(camp.board.duplicate(true))
	return out


func test_tower_gigs_are_gated_and_rare() -> void:
	var g := RulesDB.gen("gigs.json")
	var gate := int(g.tower.rep)
	assert_true(gate >= 3, "past the early game (Reputation %d)" % gate)
	var camp := Campaign.new_game(11)
	for c in camp.crew:
		c.reputation = gate - 1
	assert_false(camp.tower_unlocked())
	var towers := 0
	for b in _boards(camp, 60):
		towers += (b as Array).filter(func(o): return o.has("tower")).size()
	assert_eq(towers, 0, "no tower offers before the gate")
	for c in camp.crew:
		c.reputation = gate
	assert_true(camp.tower_unlocked())
	var with := 0
	var offers := 0
	for b in _boards(camp, 200):
		var tw: Array = (b as Array).filter(func(o): return o.has("tower"))
		assert_true(tw.size() <= 1, "at most one tower offer on a board")
		var ordinary: Array = (b as Array).filter(func(o): return not o.get("unique", false))
		assert_eq(ordinary.size(), camp.board_size(), "a tower offer takes an ordinary one's place")
		with += int(not tw.is_empty())
		offers += ordinary.size()
		for o in tw:
			assert_eq(String(o.scene), "tower_top", "a tower offer plays the band")
			assert_true(World.towers().has(String(o.tower)), "at a tower")
			assert_true(String(o.kind) in (World.tower(String(o.tower)).bands.sky.gigs as Array), "a job the band hosts")
	assert_between(float(with) / 200.0, 0.12, 0.4, "rare: about one board in four (%d of 200)" % with)
	assert_true(float(with) / float(offers) < 0.12, "a good mix: most offers stay low-rise (%d of %d)" % [with, offers])


# --- The dev builder -------------------------------------------------------------------------

func test_the_custom_gig_builder_makes_a_tower_gig() -> void:
	var form := {"tower": "raven", "objective": "assassinate", "seed": 321}
	var gig := CustomGig.build(form)
	assert_eq(String(gig.scene), "tower_top")
	assert_eq(String(gig.tower), "the_glen_24")
	assert_eq(String(gig.band), "sky")
	assert_eq(String(gig.kind), "assassination", "the form's objective, which the band hosts")
	assert_true(bool(gig.dev))
	var flags := CustomGig.to_flags(form)
	assert_true("--tower=raven" in flags, "a dev flag of its own")
	assert_eq(CustomGig.build(CustomGig.from_flags(flags)), gig, "flags and form: the same gig")
	var m := SceneGen.generate(int(gig.seed), String(gig.scene), Campaign.scene_opts(gig))
	assert_true(m.is_tower() and m.floor_name(m.street) == "48", "the builder's gig builds Raven's band")
	var any := CustomGig.build({"tower": "any", "seed": 9})
	assert_true(World.towers().has(String(any.tower)), "any: a tower drawn")
	var by_scene := CustomGig.build({"scene": "tower_top", "seed": 9})
	assert_eq(String(by_scene.scene), "tower_top", "the scene picked directly is a tower gig too")
	assert_true(World.towers().has(String(by_scene.get("tower", ""))))
	var off := CustomGig.build({"location": "the_glen_24", "seed": 9})
	assert_false(off.has("tower"), "a tower's place without the tower field: its street-level building")
	var camp := Campaign.new_game(3)
	var started := camp.accept_custom({"tower": "highcourt", "seed": 44})
	assert_false(started.is_empty(), "it starts like a board gig")
	var gs := GigSetup.for_campaign(camp)
	assert_true(gs.map.is_tower() and gs.enc != null, "and plays as a tower band")
	assert_eq(gs.map.floor_name(0), "28")


func test_a_short_soak_of_tower_gigs() -> void:
	var d := SoakDriver.new()
	d.max_rounds = 6
	d.run_campaign(2, 2, ["tower:raven", "tower"])
	assert_eq(d.failures, [] as Array[String], "the gig loop holds in a tower")
	assert_eq(int(d.stats.offers.get("tower", 0)), 2)
