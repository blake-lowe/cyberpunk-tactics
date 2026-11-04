extends TestCase
## Security doctrines (data/world/security.json): integrity, and encounters that follow them.


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func _enc(faction: String, site := "corp_office", kind := "data") -> Encounter:
	var m := SceneGen.generate(11, "lone_building", {"security": 2, "site": site})
	var dice := Dice.new(7)
	return Encounter.setup(m, dice, _crew(dice), kind, {"faction": faction})


func test_doctrines_resolve() -> void:
	var tiers: Dictionary = RulesDB.load_json("npcs.json")["tiers"]
	for id in Security.ids():
		var d := Security.doctrine(id)
		for k in ["budget", "officers", "outer_patrols", "alarm", "trauma_cards"]:
			assert_true(d.has(k), "%s: %s (from default if not its own)" % [id, k])
		for k in ["backup", "escalation"]:
			assert_false(d.has(k), "%s: %s is the Security Codes' job now (NC2045 p.7)" % [id, k])
		for lv in d.officers:
			for t in d.officers[lv]:
				assert_true(tiers.has(t), "%s: officer tier %s" % [id, t])
	for f in World.factions():
		var did := String(World.faction(f).get("doctrine", "default"))
		assert_true(did in Security.ids(), "%s: doctrine %s exists" % [f, did])


func test_the_default_doctrine_keeps_the_p399_budget() -> void:
	var d := Security.doctrine("default")
	assert_eq(Security.roster(d, 2, 1), ["mook", "mook", "mook"] as Array[String], "security 1: 3 edgerunners' worth of Mooks")
	assert_eq(Security.roster(d, 2, 2), ["lieutenant", "mook", "mook", "mook"] as Array[String])
	assert_eq(Security.roster(d, 2, 3)[0], "mini_boss", "a Mini Boss leads at security 3")


func test_gangs_field_more_bodies_and_carry_no_keycards() -> void:
	var corp := _enc("security", "gang_hideout")
	var gang := _enc("maelstrom", "gang_hideout")
	assert_eq(String(gang.doctrine.id), "gang_den")
	var n := func(e: Encounter): return e.units.filter(func(u): return u.team == Encounter.OPFOR and not u.get("outer", false)).size()
	assert_true(n.call(gang) >= n.call(corp), "a gang den is crowded (%d vs %d)" % [n.call(gang), n.call(corp)])
	assert_false(gang.units.any(func(u): return u.has("keycard")), "nobody hands out keycards in a gang den")


func test_corporate_sites_carry_trauma_cards_by_doctrine() -> void:
	var e := _enc("security", "corp_office", "assassinate")
	assert_eq(String(e.doctrine.id), "corp_standard", "private security guards a corp office the corporate way")
	assert_true(e.units[int(e.objective.target)].get("trauma_card", false), "the mark is a subscriber")
	var mil := _enc("militech", "corp_office", "assassinate")
	var officers := mil.units.filter(func(u): return u.team == Encounter.OPFOR and String(u.c.role) in ["lieutenant", "mini_boss"] and not u.get("vip", false))
	assert_false(officers.is_empty())
	assert_true(officers.all(func(u): return u.get("trauma_card", false)), "Militech officers all carry cards (by tier, not by name)")
	var gang := _enc("voodoo_boys", "gang_hideout", "assassinate")
	assert_false(gang.units.any(func(u): return u.get("trauma_card", false)), "gangers don't")


func test_the_radio_range_still_comes_from_the_doctrine() -> void:
	var e := _enc("militech")
	assert_eq(float(e.doctrine.alarm.radio_range), 30.0, "Militech's wider radio net")
	var g: Dictionary = e.units.filter(func(u): return u.team == Encounter.OPFOR)[0]
	e.call_it_in(g)
	assert_eq(e.alarm, 2)
	var near := e.units.filter(func(u): return u.team == Encounter.OPFOR and Vector2(u.pos.x - g.pos.x, u.pos.y - g.pos.y).length() <= 30.0)
	assert_true(near.all(func(u): return u.alerted), "the call rouses the guards within the radio range")
