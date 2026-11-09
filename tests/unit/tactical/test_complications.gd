extends TestCase
## The book's complication tables at gig start (Complication; data/rules/npcs.json complications,
## RTG Hardened Mooks/LTs/Mini Bosses), replacing our invented twists.


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


## An encounter with a complication forced ({tier?, roll}); security 1 fields Mooks only.
func _enc(force: Dictionary, security := 1, seed_value := 3) -> Encounter:
	var m := SceneGen.generate(11, "lone_building", {"security": security, "site": "corp_office"})
	var dice := Dice.new(seed_value)
	return Encounter.setup(m, dice, _crew(dice), "data", {"complication": force})


func _opfor(e: Encounter, tier := "") -> Array:
	return e.units.filter(func(u): return int(u.team) == Encounter.OPFOR and (tier == "" or String(u.c.role) == tier))


func test_the_oracle_decides_by_security_level() -> void:
	var want := {1: 0.10, 2: 0.35, 3: 0.60}   # HOUSE-RULE likelihoods: Impossible, Unlikely, 50/50 (SPM p.13)
	for lv in want:
		var hits := 0
		for s in 3000:
			hits += int(Complication.happens(Dice.new(s + 1), lv))
		assert_near(hits / 3000.0, float(want[lv]), 0.03, "security %d" % lv)


func test_none_unless_asked_and_never_on_the_board() -> void:
	var m := SceneGen.generate(11, "lone_building", {"security": 1, "site": "corp_office"})
	var dice := Dice.new(3)
	var e := Encounter.setup(m, dice, _crew(dice))
	assert_true(e.complication.is_empty(), "plain setups (tests, tools) roll nothing")
	var camp := Campaign.new_game(4)
	for g in camp.board:
		assert_false(g.has("complication") or String(g.blurb).to_lower().contains("complication"), "the board doesn't know")


func test_the_strongest_tier_present_rolls() -> void:
	var e := _enc({"roll": 8}, 1)
	assert_eq(String(e.complication.tier), "mook", "security 1 fields Mooks only")
	assert_eq(int(e.complication.roll), 8)
	assert_true(e.log.any(func(l): return String(l).begins_with("Complication: Two more hostiles, already hurt.")), "the log says so at the start, alert first")
	assert_eq(String(e.complication.hud), "Two more hostiles, already hurt", "the HUD gets the short alert, not the rules line")
	var e3 := _enc({"roll": 8}, 3)
	assert_eq(Complication.top_tier(e3), "mini_boss")
	assert_eq(String(e3.complication.tier), "mini_boss")


func test_two_more_mooks_join_on_round_2() -> void:
	var e := _enc({"tier": "mook", "roll": 2})
	var before := _opfor(e).size()
	assert_eq(e.complication_waves.size(), 1)
	e.next_turn()
	var guard := 0
	while e.init.round_num < 2 and guard < 200 and e.state == "playing":
		e.end_turn()
		e.next_turn()
		guard += 1
	assert_eq(_opfor(e).size(), before + 2, "two more Mooks at the start of Round 2")
	assert_true(e.complication_waves.is_empty())


func test_mook_wave_on_rounds_2_3_4() -> void:
	var e := _enc({"tier": "mook", "roll": 9})
	assert_eq(e.complication_waves.map(func(b): return int(b.round)), [2, 3, 4])


func test_two_extra_mooks_with_head_injuries_now() -> void:
	var plain := _enc({"tier": "mook", "roll": 8})   # roll 8: two extra Mooks, each with a head Critical Injury
	var hurt := _opfor(plain, "mook").filter(func(u): return u.c.injuries.any(func(i): return String(i.location) == "head"))
	assert_eq(hurt.size(), 2)
	for u in hurt:
		assert_eq(u.c.hp, u.c.max_hp(), "they start with the injury, not its Bonus Damage")


func test_incendiary_rounds_load_into_a_gun() -> void:
	var e := _enc({"tier": "mook", "roll": 1})
	var loaded := _opfor(e, "mook").filter(func(u): return u.c.weapons.any(func(w): return w.special_left == 10))
	if "kit" in e.complication.applied:
		assert_eq(loaded.size(), 1, "one Mook, 10 Incendiary rounds (CPR core p.346)")
		var w: Weapon = loaded[0].c.weapons.filter(func(x): return x.special_left == 10)[0]
		assert_false(w.fx().has("burning"), "nothing until fired")
		w.spend(1)
		assert_eq(int(w.fx().get("burning", 0)), 2, "a hit through armour sets them on fire")
	else:
		assert_true(e.complication.skipped.any(func(s): return String(s).begins_with("kit")), "no gun takes it: logged and skipped")


func test_special_rounds_run_out() -> void:
	var w := Weapon.from_id("smg")
	w.load_special(Items.fx("ammo/incendiary_ammo"), 10)
	for i in 10:
		w.spend(1)
		assert_eq(int(w.fx().get("burning", 0)), 2, "round %d is incendiary" % (i + 1))
	w.spend(1)
	assert_false(w.fx().has("burning"), "the eleventh is ordinary")
	assert_eq(w.ammo, 30 - 11)


func test_an_ap_grenade_and_athletics() -> void:
	var e := _enc({"tier": "mook", "roll": 4})
	var who := _opfor(e, "mook").filter(func(u): return "ammo/armor_piercing_ammo" in u.c.kit)
	assert_eq(who.size(), 1)
	assert_eq(who[0].c.skill_base("athletics"), 12)


func test_heavy_armorjack_and_faster() -> void:
	var e := _enc({"tier": "mook", "roll": 5})
	var who := _opfor(e, "mook").filter(func(u): return u.c.armor.body != null and u.c.armor.body.id == "heavy_armorjack")
	assert_eq(who.size(), 1)
	var c: Combatant = who[0].c
	var block: Dictionary = RulesDB.load_json("npcs.json").blocks[c.block]
	assert_eq(int(c.stats.REF), int(block.stats.REF) + 2, "+2 REF before the armour penalty")


func test_reckless_smg_mook() -> void:
	var e := _enc({"tier": "mook", "roll": 10})
	var who := _opfor(e, "mook").filter(func(u): return u.get("reckless", false))
	assert_eq(who.size(), 1)
	var c: Combatant = who[0].c
	assert_eq(c.weapons[0].id(), "smg")
	assert_eq(c.skill_base("autofire"), 16)
	assert_true(c.armor.head == null, "no head armour")


func test_black_lace_in_the_system() -> void:
	var e := _enc({"tier": "mook", "roll": 3})
	var high := _opfor(e, "mook").filter(func(u): return "black_lace" in u.c.drugs_taken)
	assert_eq(high.size(), mini(2, _opfor(e, "mook").size()))
	var c: Combatant = high[0].c
	c.hp = c.seriously_wounded_threshold() - 1
	assert_eq(c.action_penalty(), 0, "Black Lace: Seriously Wounded penalties ignored (CPR core p.358)")


func test_lieutenant_ambush_alerts_everyone() -> void:
	var e := _enc({"tier": "lieutenant", "roll": 1}, 2)
	assert_true(_opfor(e).all(func(u): return u.alerted), "they were waiting")
	assert_eq(e.alarm, 1)


func test_lieutenant_medic() -> void:
	var e := _enc({"tier": "lieutenant", "roll": 6}, 2)
	var lts := _opfor(e, "lieutenant")
	assert_true(not lts.is_empty())
	assert_eq(lts.filter(func(u): return u.c.skill_base("first_aid") == 14 and u.c.skill_base("paramedic") == 14).size(), 1)


func test_unsupported_fx_are_logged_and_skipped() -> void:
	var e := _enc({"tier": "lieutenant", "roll": 7}, 2)   # the grenade trap
	assert_true("trap" in e.complication.skipped)
	assert_true(e.log.any(func(l): return String(l).begins_with("Not modelled yet")))
	var e8 := _enc({"tier": "lieutenant", "roll": 8}, 2)   # studied the crew: {} in the data
	assert_true("the whole entry" in e8.complication.skipped)


func test_mini_boss_promotion() -> void:
	var e := _enc({"tier": "mini_boss", "roll": 2}, 3)
	var bosses := _opfor(e, "mini_boss")
	assert_true(not bosses.is_empty())
	var c: Combatant = bosses.filter(func(u): return u.c.hp_max_override > 0)[0].c
	assert_eq(c.hp, c.max_hp(), "+10 HP, at full")
	var e4 := _enc({"tier": "mini_boss", "roll": 4}, 3)
	var armoured := _opfor(e4, "mini_boss").filter(func(u): return u.c.armor.body != null and u.c.armor.body.id == "medium_armorjack" and u.c.armor_penalty() == 0)
	assert_eq(armoured.size(), 1, "tech-upgraded armorjack, no penalty")


func test_reckless_units_ignore_cover() -> void:
	# The AI's advance score drops the cover terms for a reckless unit: checked through the flag the
	# lieutenant's wild charge sets on the whole opposition.
	var e := _enc({"tier": "lieutenant", "roll": 4}, 2)
	assert_true(_opfor(e).all(func(u): return u.get("reckless", false)))
	assert_true("tactic charge" in e.complication.applied)
