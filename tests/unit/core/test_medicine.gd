extends TestCase


func _enc_with_medtech() -> Encounter:
	var m := SceneGen.generate(11, "skirmish", {"security": 1})
	var d := Dice.new(3)
	var crew: Array[Combatant] = [Recruit.generate(d, "medtech", "edgerunner"), Recruit.generate(d, "solo", "edgerunner")]
	var e := Encounter.setup(m, d, crew)
	e.next_turn()
	while e.cur.c.role != "medtech":
		e.end_turn()
		e.next_turn()
	return e


func test_medtech_starts_with_doses_and_two_drugs() -> void:
	var e := _enc_with_medtech()
	var c: Combatant = e.cur.c
	assert_eq(c.doses, 2, "Medical Tech 2 = 2 doses (HOUSE-RULE: per gig)")
	assert_true(c.knows_drug("speedheal") and c.knows_drug("stim"))
	assert_false(c.knows_drug("antibiotic"))


func test_speedheal_heals_body_plus_will_once() -> void:
	var e := _enc_with_medtech()
	var ally: Dictionary = e.units.filter(func(u): return u.team == 0 and u != e.cur)[0]
	ally.pos = e.cur.pos + Vector3i(1, 0, 0)
	ally.c.hp = 5
	assert_eq(e.best_dose(ally), "speedheal")
	var r := e.dose(ally, "speedheal")
	assert_true(r.ok)
	assert_eq(ally.c.hp, mini(ally.c.max_hp(), 5 + ally.c.raw_stat("BODY") + ally.c.raw_stat("WILL")), "p150")
	e.turn.action_available = true
	assert_false(e.dose(ally, "speedheal").ok, "once per day")


func test_stim_ignores_serious_wound_penalty() -> void:
	var e := _enc_with_medtech()
	var me: Dictionary = e.cur
	me.c.hp = me.c.seriously_wounded_threshold() - 1
	var pen: int = me.c.action_penalty()
	assert_true(pen != 0)
	me.c.speedhealed = true
	assert_eq(e.best_dose(me), "stim")
	assert_true(e.dose(me, "stim").ok)
	assert_eq(me.c.action_penalty(), 0)


func test_drugs_without_a_combat_use_are_refused_not_turned_into_stim() -> void:
	var e := _enc_with_medtech()
	var me: Dictionary = e.cur
	me.c.medicine["pharma"] = 5   # knows all five (p149)
	assert_true(me.c.knows_drug("antibiotic"))
	var r := e.dose(me, "antibiotic")
	assert_false(r.ok, "refused: it works over days, not in a firefight")
	assert_false(me.c.stimmed, "and it never acts as Stim")
	assert_eq(me.c.doses, 2, "no dose spent")
