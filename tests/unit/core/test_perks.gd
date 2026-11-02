extends TestCase


func _solo() -> Combatant:
	var c := Recruit.generate(Dice.new(4), "solo", "edgerunner")
	c.ip = 1000
	return c


func test_skill_perk_adds_to_skill_base() -> void:
	var c := _solo()
	var before := c.skill_base("handgun")
	assert_true(c.take_perk("gunslinger"))
	assert_eq(c.skill_base("handgun"), before + 2)
	assert_eq(c.ip, 900, "tier 1 costs 100 IP")


func test_one_perk_per_tier_and_tier2_gated() -> void:
	var c := _solo()
	assert_eq(c.perk_block("hard_target"), "needs tier 1")
	assert_true(c.take_perk("rifleman"))
	assert_eq(c.perk_block("gunslinger"), "tier taken")
	assert_eq(c.perk_block("hard_target"), "needs Rank 5", "starting Rank 4 (p142)")
	assert_true(c.raise_rank())
	assert_eq(c.role_rank, 5)
	assert_eq(c.ip, 900 - 300, "Rank 5 costs 60 x 5 (p411)")
	assert_true(c.take_perk("hard_target"))
	assert_eq(c.perk_block("netrunner_overclock"), "not this Role")


func test_perks_survive_save() -> void:
	var c := _solo()
	c.take_perk("gunslinger")
	var d := Combatant.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(d.perks, ["gunslinger"] as Array[String])
	assert_eq(d.skill_base("handgun"), c.skill_base("handgun"))


func test_netrunner_perks_hook_the_encounter() -> void:
	var r := Recruit.generate(Dice.new(4), "netrunner", "edgerunner")
	assert_eq(Encounter.jack_range(r), 6.0)
	r.perks.append("long_leash")
	assert_eq(Encounter.jack_range(r), 10.0)
	r.perks.append("overclock")
	assert_eq(int(r.perk_fx("net_actions")), 1)


func test_trauma_surgeon_halves_clinic() -> void:
	var camp := Campaign.new_game(2)
	var full := camp.treat_cost()
	var m := Recruit.generate(camp.dice, "medtech", "edgerunner")
	m.perks.append("trauma_surgeon")
	camp.crew.append(m)
	assert_eq(camp.treat_cost(), full / 2)


func test_triage_reach() -> void:
	var e := Encounter.new()
	var m := Recruit.generate(Dice.new(4), "medtech", "edgerunner")
	var u := {"c": m, "pos": Vector3i(5, 5, 0)}
	var t := {"c": _solo(), "pos": Vector3i(7, 5, 0)}
	assert_false(e.can_reach_to_stabilize(u, t))
	m.perks.append("long_reach")
	assert_true(e.can_reach_to_stabilize(u, t))
	t.pos = Vector3i(7, 5, 1)
	assert_false(e.can_reach_to_stabilize(u, t), "same floor only")
