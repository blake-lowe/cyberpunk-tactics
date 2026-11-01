extends TestCase


func test_distribution_sums_to_one() -> void:
	var s := 0.0
	for v in Check.die_distribution().values():
		s += v
	assert_near(s, 1.0)


func test_chance_vs_dv_exact_values() -> void:
	# Need die > 5: faces 6-9 (0.4) + any natural 10 (0.1).
	assert_near(Check.chance_vs_dv(10, 15), 0.5)
	# Need die > 15: only 10 + (6..10) → 5%.
	assert_near(Check.chance_vs_dv(0, 15), 0.05)
	# Need die > 0: everything except a natural 1 (1 − k ≤ 0 always).
	assert_near(Check.chance_vs_dv(0, 0), 0.9)
	# Impossible and certain bounds.
	assert_near(Check.chance_vs_dv(0, 20), 0.0)
	assert_near(Check.chance_vs_dv(20, 9), 1.0)


func test_tie_fails() -> void:
	# Base 5 vs DV 10: die 5 ties (fails), so need 6+ → 0.5.
	assert_near(Check.chance_vs_dv(5, 10), 0.5)


func test_opposed_symmetric_bases_favor_defender() -> void:
	var p := Check.chance_opposed(10, 10)
	assert_true(p < 0.5, "defender wins ties, got %f" % p)
	# P(win) + P(lose) + P(tie) = 1 and win == lose by symmetry → p = (1 − tie) / 2.
	var tie := 0.0
	for v in Check.die_distribution():
		tie += Check.die_distribution()[v] ** 2
	assert_near(p, (1.0 - tie) / 2.0)


func test_simulation_matches_exact_chance() -> void:
	var dice := Dice.new(1234)
	var wins := 0
	var n := 20000
	for i in n:
		if Check.vs_dv(dice, 8, 15).success:
			wins += 1
	assert_near(float(wins) / n, Check.chance_vs_dv(8, 15), 0.015)


func test_crits_do_not_chain() -> void:
	var dice := Dice.new(99)
	for i in 5000:
		var r := Check.roll_die(dice)
		assert_between(r.die, -9, 20)
		if r.crit == Check.Crit.SUCCESS:
			assert_between(r.die, 11, 20)
		elif r.crit == Check.Crit.FAILURE:
			assert_between(r.die, -9, 0)
