extends TestCase
## HOUSE-RULE: turrets by site and security level (sites.json `turrets`, Furnish.has_turrets), not
## in every vault and secure room: likely at banks, data centres and corp and police sites, never at
## bars, flats or restaurants; a scene may raise the odds (the corporate campus, where military
## locations play); set pieces keep the turrets their recipes place.


func _turrets(m: TacMap) -> Array:
	return m.devices.filter(func(d): return String(d.type) == "turret")


func test_every_site_has_turret_odds_by_level() -> void:
	var sites := RulesDB.gen("sites.json")
	for k in sites:
		if String(k).begins_with("_"):
			continue
		var t: Dictionary = sites[k].get("turrets", {})
		for lv in ["1", "2", "3"]:
			assert_true(t.has(lv), "%s: a chance at security %s" % [k, lv])
			assert_between(float(t.get(lv, -1)), 0.0, 1.0, "%s level %s" % [k, lv])
		assert_true(float(t.get("2", 0)) <= float(t.get("3", 0)), "%s: more likely the better guarded" % k)
	for k in ["bar", "restaurant", "apartments", "capsule_hotel", "school", "squat"]:
		assert_eq(float(sites[k].turrets["3"]), 0.0, "%s: never" % k)
	assert_true(float(sites.bank.turrets["3"]) >= 0.9 and float(sites.data_center.turrets["3"]) >= 0.8, "vaults and server halls: likely")


func test_banks_are_mostly_armed_and_bars_never() -> void:
	var banks := 0
	var bars := 0
	for s in 16:
		if not _turrets(SceneGen.generate(300 + s, "lone_building", {"site": "bank", "security": 3})).is_empty():
			banks += 1
		bars += _turrets(SceneGen.generate(300 + s, "lone_building", {"site": "bar", "security": 3})).size()
	assert_true(banks >= 11, "a security 3 bank's vaults have turrets on most maps (%d of 16)" % banks)
	assert_eq(bars, 0, "a bar never")
	var offices := 0
	for s in 16:
		if not _turrets(SceneGen.generate(300 + s, "lone_building", {"site": "corp_office", "security": 2})).is_empty():
			offices += 1
	assert_true(offices < 16, "a security 2 office only sometimes (%d of 16)" % offices)


func test_the_roll_is_seeded_per_building_and_the_campus_raises_it() -> void:
	var m := SceneGen.generate(7, "lone_building", {"site": "corp_office", "security": 2})
	var sid := int(m.structures.filter(func(st): return st.target)[0].id)
	assert_eq(Furnish.has_turrets(m, sid), Furnish.has_turrets(m, sid), "the same map, the same answer")
	var hits := 0
	for s in 40:
		var mm := SceneGen.generate(s, "lone_building", {"site": "corp_office", "security": 2})
		hits += int(Furnish.has_turrets(mm, int(mm.structures.filter(func(st): return st.target)[0].id)))
	assert_between(float(hits), 3.0, 20.0, "about the data's 25%% (%d of 40)" % hits)
	m.params["turrets"] = {"2": 1.0}
	assert_true(Furnish.has_turrets(m, sid), "a scene's own odds win when higher (military campus)")
	assert_true(float(RulesDB.gen("scenes.json").corp_campus.turrets["3"]) >= 0.9)


func test_set_pieces_keep_their_turrets() -> void:
	var cz := SceneGen.generate(11, "lone_building", {"setpiece": "combat_zone"})
	assert_false(_turrets(cz).is_empty(), "the Combat Zone's street turrets (rooms.json arena_street)")
	for st in cz.structures:
		assert_true(Furnish.has_turrets(cz, int(st.id)), "a set piece's buildings keep the old rule")
