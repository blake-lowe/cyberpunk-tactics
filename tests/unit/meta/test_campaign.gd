extends TestCase
## M6: the gig loop's campaign state.


func _finish(c: Campaign, won: bool) -> Encounter:
	var gig: Dictionary = c.accept(0)
	var m := SceneGen.generate(int(gig.seed), String(gig.scene), {"security": int(gig.security)})
	var e := Encounter.setup(m, c.dice, c.alive_crew())
	e.state = "won" if won else "lost"
	return e


func test_new_game_has_a_crew_cash_and_a_board() -> void:
	var c := Campaign.new_game(5)
	assert_eq(c.crew.size(), 2)
	assert_eq(c.eb, 1000)
	assert_between(float(c.board.size()), 3.0, 4.0)
	for g in c.board:
		assert_true(SceneGen.scene_types().has(g.scene), "board scenes exist: %s" % g.scene)
		assert_true(int(g.pay) > 0 and String(g.title) != "" and not String(g.title).contains("{"))


func test_a_won_gig_pays_and_awards_ip() -> void:
	var c := Campaign.new_game(6)
	var pay: int = int(c.board[0].pay)
	var e := _finish(c, true)
	var r := c.resolve(e)
	assert_true(r.won)
	assert_eq(c.eb, 1000 + pay)
	assert_true(c.rep > 0)
	assert_true(c.crew[0].ip >= Campaign.IP_WIN)
	assert_eq(c.day, 2)
	assert_true(c.active_gig.is_empty())


func test_the_dead_stay_dead_and_the_dying_are_stabilized() -> void:
	var c := Campaign.new_game(7)
	var a: Combatant = c.crew[0]
	var b: Combatant = c.crew[1]
	var e := _finish(c, false)
	a.dead = true
	b.hp = -3   # Mortally Wounded at the end
	var r := c.resolve(e)
	assert_eq(c.crew.size(), 1, "permadeath")
	assert_eq(c.fallen.size(), 1)
	assert_true(r.dead.has(a.display_name))
	assert_eq(b.hp, 1, "carried out and stabilized")
	assert_false(b.unconscious)
	assert_eq(c.eb, 1000 - Campaign.ECON.rescue_fee, "a failed gig costs the rescue fee")


func test_rest_heals_body_per_day_and_patches_armor() -> void:
	var c := Campaign.new_game(8)
	var a: Combatant = c.crew[0]
	a.hp = 5
	a.armor.body.sp = 2
	c.rest(2)
	assert_eq(a.hp, mini(a.max_hp(), 5 + a.raw_stat("BODY") * 2), "BODY HP per day of rest (p223)")
	assert_eq(a.armor.body.sp, a.armor.body.max_sp)


func test_save_and_load_round_trip() -> void:
	var c := Campaign.new_game(9)
	c.crew[0].hp = 7
	c.crew[0].add_injury({"id": "broken_ribs", "name": "Broken Ribs", "fx": {"move_bleed": true}}, "body")
	c.crew[0].weapons[0].ammo = 3
	c.crew[0].ip = 55
	var path := "user://test_campaign.json"
	assert_true(c.save(path))
	var d := Campaign.load_from(path)
	assert_eq(d.eb, c.eb)
	assert_eq(d.crew[0].display_name, c.crew[0].display_name)
	assert_eq(d.crew[0].hp, c.crew[0].hp, "HP (after the injury's bonus damage)")
	assert_eq(d.crew[0].injuries.size(), 1)
	assert_eq(d.crew[0].weapons[0].ammo, 3)
	assert_eq(d.crew[0].ip, 55)
	assert_eq(d.crew[0].sp("body"), c.crew[0].sp("body"))
	assert_eq(d.board.size(), c.board.size())


func test_ip_raises_skills_at_book_cost() -> void:
	var a := Fixtures.shooter("A")
	a.ip = 200
	var lvl: int = int(a.skills.handgun)
	assert_eq(a.skill_raise_cost("handgun"), (lvl + 1) * 20, "20 x the new level (p411)")
	assert_true(a.raise_skill("handgun"))
	assert_eq(int(a.skills.handgun), lvl + 1)
	a.skills["autofire"] = 1
	assert_eq(a.skill_raise_cost("autofire"), 80, "(x2) skills cost 40 x the new level")
