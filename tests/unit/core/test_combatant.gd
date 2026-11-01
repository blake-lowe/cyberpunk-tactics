extends TestCase


func test_derived_stats() -> void:
	var c := Fixtures.unarmored("A", {"BODY": 6, "WILL": 5})
	assert_eq(c.max_hp(), 40)  # 10 + 5 * ceil(5.5)
	assert_eq(c.hp, 40)
	assert_eq(c.seriously_wounded_threshold(), 20)
	assert_eq(c.death_save_target(), 6)
	assert_eq(c.skill_base("evasion"), 6 + 4)


func test_wound_states_and_penalties() -> void:
	var c := Fixtures.unarmored("A", {"BODY": 6, "WILL": 5, "MOVE": 6})
	assert_eq(c.wound_state(), Combatant.Wound.UNHURT)
	c.hp = 39
	assert_eq(c.wound_state(), Combatant.Wound.LIGHT)
	assert_eq(c.action_penalty(), 0)
	c.hp = 19
	assert_eq(c.wound_state(), Combatant.Wound.SERIOUS)
	assert_eq(c.action_penalty(), 2)
	c.hp = 0
	assert_eq(c.wound_state(), Combatant.Wound.MORTAL)
	assert_eq(c.action_penalty(), 4)
	assert_eq(c.stat("MOVE"), 1, "-6 MOVE, minimum 1")


func test_armor_penalty_worst_only() -> void:
	var c := Fixtures.unarmored("A", {"REF": 8, "DEX": 7, "MOVE": 5})
	c.armor["body"] = ArmorPiece.from_id("flak")              # -4
	c.armor["head"] = ArmorPiece.from_id("medium_armorjack")  # -2
	assert_eq(c.armor_penalty(), 4)
	assert_eq(c.stat("REF"), 4)
	assert_eq(c.stat("MOVE"), 1)
	assert_false(c.can_dodge_ranged(), "REF 4 after armor")


func test_crit_injury_effects_and_bonus_damage() -> void:
	var c := Fixtures.unarmored()
	var hp := c.hp
	c.add_injury(RulesDB.crit_table("head")["5"], "head")  # Concussion: -2 all
	assert_eq(c.hp, hp - 5)
	assert_eq(c.action_penalty(), 2)
	c.add_injury(RulesDB.crit_table("head")["2"], "head")  # Lost Eye: -4 ranged, DSP +1
	assert_eq(c.attack_penalty("ranged"), 6)
	assert_eq(c.attack_penalty("melee"), 2)
	assert_eq(c.base_dsp, 1)
	c.add_injury(RulesDB.crit_table("body")["12"], "body")  # Dismembered Leg: no dodge
	assert_false(c.can_dodge_ranged())


func test_suffer_crit_never_repeats() -> void:
	var c := Fixtures.unarmored("A", {"BODY": 10, "WILL": 10})
	c.hp = 1000
	var dice := Dice.new(5)
	var seen := {}
	for i in 11:
		var inj := c.suffer_crit(dice, "body")
		assert_false(seen.has(inj["id"]), "repeat " + inj["id"])
		seen[inj["id"]] = true
	assert_true(c.suffer_crit(dice, "body").is_empty(), "table exhausted")


func test_death_save() -> void:
	var c := Fixtures.unarmored("A", {"BODY": 6})
	assert_near(c.death_save_chance(), 0.5)  # rolls 1-5 are under 6
	c.dsp = 3
	assert_near(c.death_save_chance(), 0.2)  # 1-2
	var dice := Dice.new(11)
	var deaths := 0
	for i in 2000:
		var t := Fixtures.unarmored("T", {"BODY": 6})
		if not t.death_save(dice):
			deaths += 1
			assert_true(t.dead)
		assert_eq(t.dsp, 1, "penalty rises after every save")
	assert_near(deaths / 2000.0, 0.5, 0.04)


func test_stabilize_mortal() -> void:
	var c := Fixtures.unarmored()
	c.base_dsp = 1
	c.dsp = 4
	c.hp = -3
	assert_eq(c.stabilization_dv(), 15)
	c.stabilize()
	assert_eq(c.hp, 1)
	assert_true(c.unconscious)
	assert_eq(c.dsp, 1, "resets to base")
