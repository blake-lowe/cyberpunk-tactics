extends TestCase


func test_range_dv_lookup() -> void:
	assert_eq(RulesDB.range_dv("pistol", 5), 13)
	assert_eq(RulesDB.range_dv("pistol", 6), 13)
	assert_eq(RulesDB.range_dv("pistol", 6.5), 15)
	assert_eq(RulesDB.range_dv("assault_rifle", 24), 15)  # p170 example
	assert_eq(RulesDB.range_dv("assault_rifle", 14, true), 17)  # p173 autofire example
	assert_eq(RulesDB.range_dv("pistol", 300), -1)
	assert_eq(RulesDB.range_dv("smg", 120, true), -1)


func test_preview_uses_range_dv_without_dodge() -> void:
	var a := Fixtures.shooter()
	var d := Fixtures.unarmored("D", {"REF": 6})
	var w := Weapon.from_id("heavy_pistol")
	var p := Attack.preview(a, w, d, Attack.Mode.SINGLE, 10)
	assert_true(p.ok)
	assert_eq(p.base, 12)
	assert_eq(p.dv, 15)
	assert_eq(p.defense_base, -1)
	assert_near(p.chance, Check.chance_vs_dv(12, 15))


func test_preview_ref8_defender_dodges_when_better() -> void:
	var a := Fixtures.shooter()
	var w := Weapon.from_id("heavy_pistol")
	# Close range DV13 vs a strong dodger: dodging is better for them.
	var dodger := Fixtures.unarmored("D", {"REF": 8, "DEX": 9})
	dodger.skills["evasion"] = 7
	var p := Attack.preview(a, w, dodger, Attack.Mode.SINGLE, 4)
	assert_eq(p.defense_base, 16)
	assert_near(p.chance, Check.chance_opposed(12, 16))
	# Long range DV25: the range DV is harder than their dodge, so they don't dodge.
	p = Attack.preview(a, w, dodger, Attack.Mode.SINGLE, 40)
	assert_eq(p.defense_base, -1)
	assert_eq(p.dv, 25)


func test_aimed_shot_penalty_and_legality() -> void:
	var a := Fixtures.shooter()
	var d := Fixtures.unarmored()
	var w := Weapon.from_id("assault_rifle")
	assert_eq(Attack.preview(a, w, d, Attack.Mode.AIMED_HEAD, 20).base, 12 - 8)
	assert_eq(Attack.preview(a, Weapon.from_id("heavy_pistol"), d, Attack.Mode.AUTOFIRE, 5).reason, "no autofire")
	w.ammo = 9
	assert_eq(Attack.preview(a, w, d, Attack.Mode.AUTOFIRE, 5).reason, "need 10 rounds")
	assert_eq(Attack.preview(a, Weapon.from_id("light_melee"), d, Attack.Mode.SINGLE, 3).reason, "out of reach")


func test_melee_halves_sp_and_ablates() -> void:
	var d := Fixtures.shooter("D")  # SP11 body
	var r := {"damage": 7, "location": "body", "through": 0, "crits": []}
	Attack.apply_damage(Dice.new(1), d, r, true, false, false)
	assert_eq(r.through, 1)  # SP11 halved → 6
	assert_eq(d.sp("body"), 10)
	assert_eq(d.hp, d.max_hp() - 1)


func test_no_ablation_when_nothing_gets_through() -> void:
	var d := Fixtures.shooter("D")
	var r := {"damage": 11, "location": "body", "through": 0, "crits": []}
	Attack.apply_damage(Dice.new(1), d, r, false, false, false)
	assert_eq(r.through, 0)
	assert_eq(d.sp("body"), 11)


func test_head_shot_doubles_through_damage() -> void:
	var d := Fixtures.shooter("D")
	var r := {"damage": 15, "location": "head", "through": 0, "crits": []}
	Attack.apply_damage(Dice.new(1), d, r, false, true, false)
	assert_eq(r.through, 8)  # (15 - 11) * 2
	assert_eq(d.sp("head"), 10)


func test_crit_trigger_applies_even_if_sp_stops_damage() -> void:
	var d := Fixtures.shooter("D")
	var r := {"damage": 6, "location": "body", "through": 0, "crits": []}
	Attack.apply_damage(Dice.new(3), d, r, false, false, true)
	assert_eq(r.through, 0)
	assert_eq(r.crits.size(), 1)
	assert_eq(d.hp, d.max_hp() - 5)


func test_mortally_wounded_hit_causes_crit_and_dsp() -> void:
	var d := Fixtures.unarmored("D")
	d.hp = 0
	var r := {"damage": 3, "location": "body", "through": 0, "crits": []}
	Attack.apply_damage(Dice.new(4), d, r, false, false, false)
	assert_eq(r.crits.size(), 1)
	assert_true(d.dsp >= 1)


func test_resolve_consumes_ammo() -> void:
	var dice := Dice.new(8)
	var a := Fixtures.shooter()
	var d := Fixtures.unarmored()
	var w := Weapon.from_id("assault_rifle")
	Attack.resolve(dice, a, w, d, Attack.Mode.SINGLE, 20)
	assert_eq(w.ammo, 24)
	Attack.resolve(dice, a, w, d, Attack.Mode.AUTOFIRE, 20)
	assert_eq(w.ammo, 14)


func test_autofire_damage_capped_by_multiplier() -> void:
	var dice := Dice.new(21)
	var a := Fixtures.shooter("A", {"REF": 10})
	a.skills["autofire"] = 10
	for i in 300:
		var d := Fixtures.unarmored("D", {"BODY": 10, "WILL": 10})
		d.hp = 1000
		var w := Weapon.from_id("smg")
		var r := Attack.resolve(dice, a, w, d, Attack.Mode.AUTOFIRE, 3)
		if r.hit:
			var mult := mini(r.check.total - r.check.dv, 3)
			assert_eq(r.damage, (r.faces[0] + r.faces[1]) * mult)
			assert_true(r.damage <= 36)


func test_resolve_hit_rate_matches_preview() -> void:
	# Guards against preview and resolve drifting apart (the UI promises this number).
	var dice := Dice.new(77)
	var a := Fixtures.shooter()
	var w := Weapon.from_id("heavy_pistol")
	for setup in [[6, 10.0], [9, 4.0]]:  # [defender REF, distance]: plain DV, then dodging
		var d := Fixtures.unarmored("D", {"REF": setup[0], "DEX": 8})
		var expected: float = Attack.preview(a, w, d, Attack.Mode.SINGLE, setup[1]).chance
		var hits := 0
		var n := 6000
		for i in n:
			w.reload()
			var t := Fixtures.unarmored("D", {"REF": setup[0], "DEX": 8})
			if Attack.resolve(dice, a, w, t, Attack.Mode.SINGLE, setup[1]).hit:
				hits += 1
		assert_near(float(hits) / n, expected, 0.02, "setup %s" % [setup])
