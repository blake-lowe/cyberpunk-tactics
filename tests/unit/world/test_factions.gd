extends TestCase
## Factions as data (data/world/factions.json): integrity, relations, and encounters built from
## them (who the guards are, who fights whom when third parties turn up).


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func _enc(faction: String, kind := "eliminate", scene := "street_block") -> Encounter:
	var m := SceneGen.generate(7, scene, {"security": 2})
	var dice := Dice.new(5)
	return Encounter.setup(m, dice, _crew(dice), kind, [], {"faction": faction})


# --- data integrity --------------------------------------------------------------------

func test_every_faction_resolves_against_the_rules_data() -> void:
	var tiers: Dictionary = RulesDB.load_json("npcs.json")["tiers"]
	var weapons: Dictionary = RulesDB.load_json("weapons.json")["weapons"]
	var armor: Dictionary = RulesDB.load_json("armor.json")["armor"]
	var kinds: Dictionary = RulesDB.world("factions.json")["kind_relations"]
	var gig_kinds: Array = (RulesDB.gen("gigs.json")["templates"] as Array).map(func(t): return String(t.kind))
	for id in World.factions():
		var f := World.faction(id)
		assert_true(kinds.has(String(f.kind)), "%s: known kind %s" % [id, f.kind])
		var roster: Dictionary = f.get("roster", {})
		for tier in roster.get("ranks", {}):
			assert_true(tiers.has(tier), "%s: rank for a real tier (%s)" % [id, tier])
		for tier in roster.get("kits", {}):
			for kit in roster.kits[tier]:
				for w in kit:
					assert_true(weapons.has(w), "%s: kit weapon %s exists" % [id, w])
		for tier in roster.get("armor", {}):
			assert_true(armor.has(roster.armor[tier]), "%s: armour %s exists" % [id, roster.armor[tier]])
		var quals: Dictionary = RulesDB.load_json("weapons.json")["quality"]
		for tier in roster.get("quality", {}):
			var q: Variant = roster.quality[tier]
			for name in ([q] if q is String else (q as Dictionary).keys()):
				assert_true(quals.has(String(name)), "%s: quality %s for %s exists" % [id, name, tier])
		var r: Dictionary = roster.get("responder", {})
		if r.has("armor"):
			assert_true(armor.has(r.armor), "%s: responder armour exists" % id)
		for g in f.get("gigs", []):
			assert_true(g in gig_kinds, "%s: targetable by a real gig kind (%s)" % [id, g])
		for k in f.get("look", {}):
			if k in ["jacket", "accent", "pants"]:
				assert_true(Color.html_is_valid(String(f.look[k])), "%s: look.%s is a colour" % [id, k])


func test_every_gig_kind_has_a_target_faction() -> void:
	for t in RulesDB.gen("gigs.json")["templates"]:
		assert_false(World.targets_for(String(t.kind)).is_empty(), "someone to aim a %s at" % t.kind)


# --- relations --------------------------------------------------------------------------

func test_relations_are_symmetric_and_follow_kinds_and_overrides() -> void:
	var ids: Array = World.factions().keys()
	for a in ids:
		for b in ids:
			assert_eq(World.relation(a, b), World.relation(b, a), "%s/%s symmetric" % [a, b])
	assert_eq(World.relation("militech", "maelstrom"), "hostile", "corps and gangs")
	assert_eq(World.relation("militech", "biotechnica"), "neutral", "corps keep to themselves")
	assert_eq(World.relation("valentinos", "tyger_claws"), "neutral", "gangs by default")
	assert_eq(World.relation("maelstrom", "tyger_claws"), "hostile", "Maelstrom hates every other gang")
	assert_eq(World.relation("ncpd", "valentinos"), "hostile", "police and gangs")
	assert_eq(World.relation("ncpd", "6th_street"), "neutral", "6th Street and the NCPD get along")
	assert_eq(World.relation("crew", "bystanders"), "neutral")
	assert_eq(World.relation("crew", "trauma_team"), "neutral", "Trauma Team minds its own business")
	assert_eq(World.relation("ncpd", "maxtac"), "ally")


# --- encounters ----------------------------------------------------------------------

func test_the_guards_come_from_the_target_faction() -> void:
	var e := _enc("maelstrom")
	var guards := e.units.filter(func(u): return u.team == Encounter.OPFOR)
	assert_true(guards.size() >= 3)
	assert_true(guards.all(func(u): return u.c.faction == "maelstrom"), "Maelstrom, all of them")
	assert_true(guards.any(func(u): return u.c.display_name.begins_with("Maelstrom")), "named by their rank")
	assert_true(e.hostile(Encounter.OPFOR, Encounter.CREW))
	assert_false(e.hostile(Encounter.CIV_TEAM, Encounter.CREW), "bystanders aren't")
	assert_false(e.hostile(Encounter.OPFOR, Encounter.CIV_TEAM), "and nobody shoots them on purpose")


func test_an_unknown_faction_falls_back_to_private_security() -> void:
	var e := _enc("no_such_faction")
	assert_eq(e.opfor_faction, World.DEFAULT_OPFOR)


func test_police_answering_a_gang_job_fight_the_gang_too() -> void:
	var e := _enc("valentinos")
	e._ncpd_wave()
	var cops := e.units.filter(func(u): return e.faction_of(u) == "ncpd")
	assert_false(cops.is_empty(), "the NCPD turns up")
	var t: int = cops[0].team
	assert_true(t != Encounter.OPFOR, "on their own side")
	assert_true(e.hostile(t, Encounter.CREW), "after the crew")
	assert_true(e.hostile(t, Encounter.OPFOR), "and the Valentinos: a three-way fight")
	var g: Dictionary = e.units.filter(func(u): return u.team == Encounter.OPFOR)[0]
	assert_true(AI._enemies(e, g).has(cops[0]), "the gang shoots back at them")


func test_police_answering_a_corp_job_leave_the_guards_alone() -> void:
	var e := _enc("militech")
	e._ncpd_wave()
	var cops := e.units.filter(func(u): return e.faction_of(u) == "ncpd")
	assert_false(cops.is_empty())
	assert_false(e.hostile(cops[0].team, Encounter.OPFOR), "corp security and the NCPD don't trade shots")
	assert_true(e.opfor().has(cops[0]), "but they count against the crew")


func test_gunfire_never_puts_bystanders_in_the_initiative() -> void:
	var m := SceneGen.generate(7, "neighborhood", {"security": 1, "profile": "market_streets"})
	var dice := Dice.new(4)
	var e := Encounter.setup(m, dice, _crew(dice), "eliminate")
	for u in e.units:
		if u.get("civ", false):
			e._noise(u.pos)
	assert_false(e.units.any(func(u): return u.get("civ", false) and e.init.entries.any(func(x): return x.c == u.c)), "they panic and run; they never take a turn")


func test_shooting_trauma_team_makes_them_hostile() -> void:
	var e := _enc("militech")
	assert_false(e.hostile(Encounter.TT_TEAM, Encounter.CREW))
	e.set_relation(Encounter.TT_TEAM, Encounter.CREW, "hostile")
	assert_true(e.hostile(Encounter.CREW, Encounter.TT_TEAM))


# --- the fixer board ------------------------------------------------------------------

func test_board_gigs_name_a_target_that_fits_the_job() -> void:
	var camp := Campaign.new_game(3)
	for day in 6:
		camp.refresh_board()
		for g in camp.board:
			var fid := String(g.get("faction", ""))
			assert_true(World.has_faction(fid), "gig has a target faction (%s)" % fid)
			assert_true(String(g.kind) in World.targets_for_any(fid), "%s can be the target of %s" % [fid, g.kind])
			var name := World.display_name(fid)
			if World.kind(fid) == "gang":
				assert_false(String(g.title).contains("{"), "title filled")
			assert_true(String(g.title).contains(name) or String(g.blurb).contains(name) or not (String(g.title) + String(g.blurb)).contains("{"), "%s named in '%s'" % [name, g.title])
