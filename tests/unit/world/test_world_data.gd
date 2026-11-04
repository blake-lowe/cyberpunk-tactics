extends TestCase
## Cross-references between the content files (data/gen, data/world): every id a file names
## exists where it should, and a sweep of encounters built from the data sets up and plays.
## (tools/test.sh separately checks data/world/ is in sync with docs/world/.)


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func _profiles() -> Array:
	return RulesDB.gen("districts.json").keys().filter(func(k): return k != "_doc")


func _sites() -> Array:
	return RulesDB.gen("sites.json").keys().filter(func(k): return k != "_doc")


func test_gig_places_exist() -> void:
	var g := RulesDB.gen("gigs.json")
	for sc in g.scene_tags:
		if String(sc).begins_with("neighborhood:"):
			assert_true(String(sc).get_slice(":", 1) in _profiles(), "scene tag %s: a district profile" % sc)
		else:
			assert_true(String(sc) in SceneGen.PLANNERS, "scene tag %s: a scene SceneGen builds" % sc)
	for kind in g.raid_sites:
		for site in g.raid_sites[kind]:
			assert_true(String(site) in _sites(), "raid site %s (%s) exists" % [site, kind])
	var tags := {}
	for sc in g.scene_tags:
		for t in g.scene_tags[sc]:
			tags[t] = true
	for kind in g.kind_tags:
		assert_true((g.kind_tags[kind] as Array).any(func(t): return tags.has(t)), "%s: some scene carries one of its tags" % kind)


func test_scene_themes_name_real_scenes_and_palettes() -> void:
	for sc in SceneTheme.themes():
		assert_true(String(sc) in SceneGen.PLANNERS, "theme %s: a scene" % sc)
		var pal := String(SceneTheme.themes()[sc].get("palette", ""))
		assert_true(pal == "" or SceneTheme.palettes().has(pal), "theme %s: palette %s exists" % [sc, pal])


func test_locations_resolve() -> void:
	var gig_kinds: Array = (RulesDB.gen("gigs.json")["templates"] as Array).map(func(t): return String(t.kind))
	for id in World.locations():
		var l := World.location(id)
		var owner := String(l.get("owner", ""))
		if owner != "" and not World.has_faction(owner):
			continue   # TODO(M9 P1 factions pass): every owner gets a faction; until then they can't host gigs
		assert_true(World.districts().has(String(l.get("district", ""))), "%s: district %s exists" % [id, l.get("district")])
		assert_true(l.has("profile") or l.has("site") or l.has("scene"), "%s: somewhere" % id)
		if l.has("profile"):
			assert_true(String(l.profile) in _profiles(), "%s: profile %s" % [id, l.profile])
		if l.has("site"):
			assert_true(String(l.site) in _sites(), "%s: site %s" % [id, l.site])
		if l.has("scene"):
			assert_true(String(l.scene) in SceneGen.PLANNERS, "%s: scene %s" % [id, l.scene])
		for k in l.get("gigs", []):
			assert_true(String(k) in gig_kinds, "%s: gig kind %s" % [id, k])
		assert_true(l.has("cite"), "%s: cited (or RULES-UNVERIFIED)" % id)


func test_the_board_sends_a_job_to_its_targets_own_place() -> void:
	# A location for the test, injected into the loaded data (the real registry starts empty).
	var data := RulesDB.world("locations.json")
	var saved: Dictionary = (data.get("locations", {}) as Dictionary).duplicate(true)
	data["locations"] = {"test_depot": {"name": "Test Depot", "owner": "militech", "site": "warehouse", "security": [3, 3],
		"gigs": ["sabotage", "corp_extraction", "data_theft"], "cite": "test"}}
	var camp := Campaign.new_game(5)
	var hits := 0
	for day in 12:
		camp.refresh_board()
		for g in camp.board:
			if String(g.get("location", "")) == "test_depot":
				hits += 1
				assert_eq(String(g.faction), "militech")
				assert_eq(String(g.site), "warehouse")
				assert_eq(int(g.security), 3, "kept to the place's security range")
				assert_eq(Campaign.place_name(g), "Test Depot")
	data["locations"] = saved
	assert_true(hits > 0, "Militech jobs sometimes happen at Militech's own depot")


## A sweep: every district profile with a rotating objective and target faction sets up, takes a
## turn, and the objective reports. Catches content that names something the code can't build.
func test_every_profile_objective_and_faction_family_sets_up() -> void:
	var kinds := Objective.kinds()
	var factions := ["security", "militech", "maelstrom", "valentinos", "biotechnica", "6th_street", "tyger_claws", "kang_tao", "bozos"]
	var i := 0
	for prof in _profiles():
		var kind := String(kinds[i % kinds.size()])
		var fid := String(factions[i % factions.size()])
		i += 1
		var m := SceneGen.generate(20 + i, "neighborhood", {"security": 1 + i % 3, "profile": prof})
		var dice := Dice.new(i)
		var e := Encounter.setup(m, dice, _crew(dice), kind, [], {"faction": fid})
		assert_eq(String(e.objective.kind), kind, "%s/%s/%s: objective" % [prof, kind, fid])
		assert_true(e.units.any(func(u): return u.team == Encounter.OPFOR), "%s/%s/%s: guards" % [prof, kind, fid])
		assert_false(e.obj.hud_text().is_empty())
		e.next_turn()
		assert_eq(e.state, "playing", "%s/%s/%s: playable" % [prof, kind, fid])
