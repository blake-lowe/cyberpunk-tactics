extends TestCase


# --- TurnState ------------------------------------------------------------

func test_move_split_around_attack_and_run() -> void:
	var c := Fixtures.shooter("A", {"MOVE": 6})
	var t := TurnState.begin(Dice.new(1), c)
	assert_true(t.move(2))
	assert_true(t.start_attack(Weapon.from_id("heavy_pistol")))
	assert_eq(t.attacks_left, 2, "ROF 2")
	assert_true(t.use_attack())
	assert_true(t.move(3))  # split: move, shoot, move, shoot (p169)
	assert_true(t.use_attack())
	assert_false(t.use_attack())
	assert_true(t.move(1))
	assert_false(t.move(1), "MOVE 6 squares spent")
	assert_false(t.run(), "Action already used")


func test_run_needs_prior_move() -> void:
	var c := Fixtures.shooter("A", {"MOVE": 5})
	var t := TurnState.begin(Dice.new(1), c)
	assert_false(t.run())
	t.move(5)
	assert_true(t.run())
	assert_true(t.move(5))
	assert_false(t.start_attack(Weapon.from_id("smg")))


func test_aimed_or_autofire_is_single_check() -> void:
	var t := TurnState.begin(Dice.new(1), Fixtures.shooter())
	t.start_attack(Weapon.from_id("heavy_pistol"), true)
	assert_eq(t.attacks_left, 1)


func test_mortal_death_save_at_turn_start() -> void:
	var dice := Dice.new(2)
	var deaths := 0
	for i in 500:
		var c := Fixtures.unarmored("A", {"BODY": 6})
		c.hp = 0
		var t := TurnState.begin(dice, c)
		if not t.survived:
			deaths += 1
			assert_false(t.action_available)
	assert_near(deaths / 500.0, 0.5, 0.07)


func test_spinal_injury_skips_next_action() -> void:
	var c := Fixtures.unarmored()
	c.add_injury(RulesDB.crit_table("body")["10"], "body")
	var t := TurnState.begin(Dice.new(1), c)
	assert_false(t.action_available)
	assert_true(t.can_move())
	assert_true(TurnState.begin(Dice.new(1), c).action_available, "only the next turn")


func test_broken_ribs_hurt_after_moving_over_4m() -> void:
	var c := Fixtures.unarmored("A", {"MOVE": 6})
	c.add_injury(RulesDB.crit_table("body")["5"], "body")
	var hp := c.hp
	var t := TurnState.begin(Dice.new(1), c)
	t.move(2)  # exactly 4 m: fine
	assert_eq(t.end(), 0)
	t = TurnState.begin(Dice.new(1), c)
	t.move(3)
	assert_eq(t.end(), 5)
	assert_eq(c.hp, hp - 5)


# --- Humanity & cyberware -------------------------------------------------

func test_cyberware_humanity_and_cap() -> void:
	var c := Fixtures.unarmored("A", {"EMP": 6})
	c.init_humanity()
	assert_eq(c.humanity, 60)
	assert_eq(c.install_cyberware("neural_link", null, true), 7)
	assert_eq(c.humanity, 53)
	assert_eq(c.max_humanity, 58)
	assert_eq(c.raw_stat("EMP"), 5)
	c.install_cyberware("biomonitor", null, true)  # 0 HL: no cap change
	assert_eq(c.max_humanity, 58)
	c.regain_humanity(50)
	assert_eq(c.humanity, 58, "capped by installed cyberware")


func test_psychosis_tiers() -> void:
	var c := Fixtures.unarmored()
	assert_eq(c.psychosis_tier(), 0, "untracked")
	c.init_humanity()
	c.humanity = 25
	assert_eq(c.psychosis_tier(), 1)
	c.humanity = 5
	assert_eq(c.psychosis_tier(), 3)
	c.humanity = -1
	assert_eq(c.psychosis_tier(), 4)


func test_subdermal_armor_does_not_stack_and_ablates() -> void:
	var c := Fixtures.unarmored()
	c.armor["body"] = ArmorPiece.from_id("kevlar")  # SP7
	c.install_cyberware("subdermal_armor")
	assert_eq(c.sp("body"), 11)
	assert_eq(c.sp("head"), 11)
	c.ablate("body")
	assert_eq(c.sp("body"), 10)
	assert_eq(c.armor["body"].sp, 6, "worn armor ablates too")


func test_grafted_muscle_capped_at_10() -> void:
	var c := Fixtures.unarmored("A", {"BODY": 9})
	c.install_cyberware("grafted_muscle_and_bone_lace")
	assert_eq(c.stat("BODY"), 10)


func test_kerenzikov_initiative() -> void:
	var c := Fixtures.unarmored()
	c.install_cyberware("kerenzikov")
	assert_eq(c.initiative_bonus(), 2)


# --- Solo Combat Awareness ------------------------------------------------

func test_awareness_allocation_limits() -> void:
	var c := Fixtures.shooter()
	assert_false(c.set_awareness({"precision_attack": 3}), "not a Solo")
	c.role = "solo"
	c.role_rank = 4
	assert_false(c.set_awareness({"precision_attack": 3, "spot_weakness": 2}), "over rank")
	assert_true(c.set_awareness({"precision_attack": 3, "spot_weakness": 1}))
	assert_eq(c.awareness_level("precision_attack"), 1)
	assert_eq(Attack.attack_base(c, Weapon.from_id("heavy_pistol"), Attack.Mode.SINGLE), 13)


func test_fumble_recovery_raises_hit_chance() -> void:
	# Base 10 vs DV 10: normal needs die > 0 (90%); with Fumble Recovery a 1 counts as 1 → 100%.
	assert_near(Check.chance_vs_dv(10, 10), 0.9)
	assert_near(Check.chance_vs_dv(10, 10, true), 1.0)


func test_damage_deflection_once_per_round() -> void:
	var d := Fixtures.unarmored()
	d.role = "solo"
	d.role_rank = 4
	d.set_awareness({"damage_deflection": 4})  # level 2
	var r := {"damage": 10, "location": "body", "through": 0, "crits": []}
	Attack.apply_damage(Dice.new(1), d, r, false, false, false)
	assert_eq(r.through, 8)
	r = {"damage": 10, "location": "body", "through": 0, "crits": []}
	Attack.apply_damage(Dice.new(1), d, r, false, false, false)
	assert_eq(r.through, 10)
	d.new_round()
	r = {"damage": 10, "location": "body", "through": 0, "crits": []}
	Attack.apply_damage(Dice.new(1), d, r, false, false, false)
	assert_eq(r.through, 8)


# --- Unarmed & area -------------------------------------------------------

func test_unarmed_dice() -> void:
	assert_eq(Weapon.unarmed_dice(Fixtures.unarmored("A", {"BODY": 4})), 1)
	assert_eq(Weapon.unarmed_dice(Fixtures.unarmored("A", {"BODY": 8})), 3)
	var weak := Fixtures.unarmored("A", {"BODY": 3})
	weak.install_cyberware("cyberarm")
	assert_eq(Weapon.unarmed_dice(weak), 2)
	assert_false(Weapon.brawling(weak).halves_sp())
	assert_true(Weapon.martial_arts(weak).halves_sp())


func test_explosion_hits_all_with_same_damage() -> void:
	var dice := Dice.new(6)
	var targets := [Fixtures.unarmored("A"), Fixtures.unarmored("B"), Fixtures.unarmored("C")]
	var out := Attack.explosion(dice, 99, 6, targets)  # attack total 99: nobody can dodge it
	var dmg := 0
	for f in out.faces:
		dmg += f
	for res in out.results:
		assert_false(res.dodged)
		assert_eq(res.through, dmg)


func test_suppressive_fire_uses_ammo() -> void:
	var a := Fixtures.shooter()
	var w := Weapon.from_id("smg")
	var out := Attack.suppressive_fire(Dice.new(3), a, w, [Fixtures.unarmored()])
	assert_true(out.ok)
	assert_eq(w.ammo, 20)
	assert_false(Attack.suppressive_fire(Dice.new(3), a, Weapon.from_id("heavy_pistol"), []).ok)


# --- Recruits ---------------------------------------------------------------

func test_recruits_are_valid() -> void:
	var dice := Dice.new(2024)
	for role in ["solo", "netrunner", "medtech", "tech"]:
		for method in ["streetrat", "edgerunner"]:
			var c := Recruit.generate(dice, role, method)
			assert_eq(c.role_rank, 4)
			assert_eq(c.hp, c.max_hp())
			assert_eq(c.skills.size(), 20, "%s %s skills" % [role, method])
			for s in c.skills:
				assert_between(c.skills[s], 2, 6, s)
			assert_true(c.humanity < c.raw_stat("EMP") * 10 + 10)
			assert_false(c.weapons.is_empty())
			if method == "edgerunner":
				var spent := 0
				for s in c.skills:
					spent += c.skills[s] * (2 if RulesDB.skill(s)["x2"] else 1)
				assert_between(spent, 85, 86, "%s skill points" % role)


func test_recruit_starting_humanity_loss() -> void:
	var c := Recruit.generate(Dice.new(5), "netrunner", "streetrat")
	assert_eq(c.humanity, int(c.stats["EMP"]) * 10 - 14)  # p117: Netrunner HL 14
	assert_true(c.has_cyberware("interface_plugs"))
