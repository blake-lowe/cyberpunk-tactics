extends TestCase
## The Closed Question Oracle (Oracle; SPM p.12-13): five likelihoods, five answers on a d100,
## exact odds, seeded rolls; and the complication chance that now goes through it (Complication).


func test_the_odds_table_is_the_books() -> void:
	# SPM p.13: the top roll of No / No with Complication / Complicated / Yes with Complication.
	assert_eq(Oracle.BANDS.certain, [5, 10, 15, 40])
	assert_eq(Oracle.BANDS.likely, [15, 25, 35, 55])
	assert_eq(Oracle.BANDS.even, [20, 30, 40, 60])
	assert_eq(Oracle.BANDS.unlikely, [40, 55, 65, 75])
	assert_eq(Oracle.BANDS.impossible, [75, 85, 90, 95])
	var yes := {"certain": 0.85, "likely": 0.65, "even": 0.60, "unlikely": 0.35, "impossible": 0.10}
	for lk in Oracle.LIKELIHOODS:
		var total := 0.0
		for o in Oracle.OUTCOMES:
			total += Oracle.chance(lk, o)
		assert_near(total, 1.0, 0.0001, "%s: the five answers cover the d100" % lk)
		assert_near(Oracle.chance_yes(lk), float(yes[lk]), 0.0001, "%s: chance of a yes" % lk)
	assert_near(Oracle.chance("even", "complicated"), 0.10, 0.0001)
	assert_near(Oracle.chance("impossible", "yes"), 0.05, 0.0001)


func test_band_edges() -> void:
	assert_eq(Oracle.outcome_for(1, "certain"), "no")
	assert_eq(Oracle.outcome_for(5, "certain"), "no")
	assert_eq(Oracle.outcome_for(6, "certain"), "no_complication")
	assert_eq(Oracle.outcome_for(15, "certain"), "complicated")
	assert_eq(Oracle.outcome_for(40, "certain"), "yes_complication")
	assert_eq(Oracle.outcome_for(41, "certain"), "yes")
	assert_eq(Oracle.outcome_for(95, "impossible"), "yes_complication")
	assert_eq(Oracle.outcome_for(96, "impossible"), "yes")
	assert_eq(Oracle.outcome_for(100, "impossible"), "yes")
	assert_eq(Oracle.outcome_for(60, "even"), "yes_complication")
	assert_eq(Oracle.outcome_for(61, "even"), "yes")


func test_asking_is_seeded_and_matches_the_odds() -> void:
	var a := Dice.new(42)
	var b := Dice.new(42)
	for i in 50:
		assert_eq(Oracle.ask(a, "likely"), Oracle.ask(b, "likely"), "the same seed, the same answers")
	var d := Dice.new(7)
	var n := 4000
	var hits := {}
	for i in n:
		var r := Oracle.ask(d, "unlikely")
		assert_eq(String(r.outcome), Oracle.outcome_for(int(r.roll), "unlikely"))
		assert_eq(bool(r.yes), Oracle.is_yes(String(r.outcome)))
		hits[r.outcome] = int(hits.get(r.outcome, 0)) + 1
	for o in Oracle.OUTCOMES:
		assert_near(float(hits.get(o, 0)) / n, Oracle.chance("unlikely", o), 0.03, "unlikely: %s" % o)
	assert_eq(String(Oracle.ask(Dice.new(1), "nonsense").likelihood), "even", "an unknown likelihood asks 50/50")


## HOUSE-RULE mapping (Complication.LIKELIHOOD): the complication question's likelihood by the
## gig's security level, through the Oracle, replacing the old flat one in three.
func test_complication_chance_goes_through_the_oracle() -> void:
	assert_eq(Complication.likelihood(1), "impossible")
	assert_eq(Complication.likelihood(2), "unlikely")
	assert_eq(Complication.likelihood(3), "even")
	assert_eq(Complication.likelihood(9), "even", "clamped to 1-3")
	assert_false(load("res://src/tactical/complication.gd").get_script_constant_map().has("CHANCE_IN"), "no flat chance any more")
	for lv in [1, 2, 3]:
		var hits := 0
		for s in 2000:
			var d := Dice.new(s + 1)
			var want := Oracle.ask(Dice.new(s + 1), Complication.likelihood(lv))
			var got := Complication.happens(d, lv)
			assert_eq(got, bool(want.yes), "the same roll the Oracle makes")
			hits += int(got)
		assert_near(hits / 2000.0, Oracle.chance_yes(Complication.likelihood(lv)), 0.035, "level %d" % lv)


## In a gig: the encounter asks at its map's security level and keeps the answer on the complication.
func test_an_encounter_asks_the_oracle_at_its_security_level() -> void:
	var crew_dice := Dice.new(3)
	var rates := {}
	for sec in [1, 3]:
		var hits := 0
		var tries := 40
		for s in tries:
			var m := SceneGen.generate(11, "lone_building", {"security": sec, "site": "corp_office"})
			var dice := Dice.new(100 + s)
			var crew: Array[Combatant] = [Recruit.generate(crew_dice, "solo", "edgerunner", "Vex")]
			var e := Encounter.setup(m, dice, crew, "data", {"complications": true})
			if not e.complication.is_empty():
				hits += 1
				assert_true(String(e.complication.get("oracle", "")) in ["yes", "yes_complication"], "the Oracle's yes is kept on it")
		rates[sec] = float(hits) / tries
	assert_true(float(rates[1]) < float(rates[3]), "a Light place springs fewer than a Heavy one (%s)" % str(rates))
	assert_between(float(rates[1]), 0.0, 0.3, "Impossible: about 1 in 10")
	assert_between(float(rates[3]), 0.35, 0.85, "50/50: about 6 in 10")
