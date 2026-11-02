extends TestCase


func _enc_with_tech() -> Encounter:
	var m := SceneGen.generate(11, "skirmish", {"security": 1})
	var d := Dice.new(3)
	var crew: Array[Combatant] = [Recruit.generate(d, "tech", "edgerunner"), Recruit.generate(d, "solo", "edgerunner")]
	var e := Encounter.setup(m, d, crew)
	e.next_turn()
	while e.cur.c.role != "tech":
		e.end_turn()
		e.next_turn()
	return e


func test_tech_starts_with_eight_maker_ranks() -> void:
	var t := Recruit.generate(Dice.new(1), "tech", "edgerunner")
	var total := 0
	for k in t.maker:
		total += int(t.maker[k])
	assert_eq(total, 8, "Rank 4 = 8 Specialty ranks (p147)")


func test_jury_rig_restores_worn_armour_once() -> void:
	var e := _enc_with_tech()
	var ally: Dictionary = e.units.filter(func(u): return u.team == 0 and u != e.cur)[0]
	ally.pos = e.cur.pos + Vector3i(1, 0, 0)
	var a: ArmorPiece = ally.c.armor.body
	a.sp = 3
	assert_eq(e.rig_target_loc(ally), "body")
	var r := e.jury_rig(ally)
	assert_true(r.ok)
	assert_true(a.rigged)
	if r.success:
		assert_eq(a.sp, a.max_sp)
	e.turn.action_available = true
	assert_eq(e.rig_target_loc(ally), "head" if (ally.c.armor.head as ArmorPiece).sp < (ally.c.armor.head as ArmorPiece).max_sp else "", "body already rigged")


func test_workshop_upgrade_adds_one_sp_and_saves() -> void:
	var c := Campaign.new_game(4)
	c.eb = 5000
	var t := Recruit.generate(c.dice, "tech", "edgerunner")
	c.crew.append(t)
	var solo: Combatant = c.crew[0]
	var base: int = (solo.armor.body as ArmorPiece).max_sp
	var success := false
	for k in 10:   # until a success (DV17 vs roughly 9-10 + d10)
		var r := c.upgrade_armor(solo, "body")
		if r.is_empty():
			break
		if r.success:
			success = true
			break
	assert_true(success, "a Tech gets there eventually")
	assert_eq((solo.armor.body as ArmorPiece).max_sp, base + 1)
	assert_true(c.upgrade_armor(solo, "body").is_empty(), "one upgrade per item")
	var d := Combatant.from_dict(JSON.parse_string(JSON.stringify(solo.to_dict())))
	assert_eq((d.armor.body as ArmorPiece).max_sp, base + 1)
