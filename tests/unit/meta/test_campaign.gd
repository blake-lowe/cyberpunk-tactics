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


func test_shop_stock_grows_with_reputation() -> void:
	var c := Campaign.new_game(3)
	var low := c.shop_stock().map(func(x): return x.id)
	assert_true("heavy_pistol" in low)
	assert_false("sniper_rifle" in low, "rep 0: no sniper rifles")
	c.rep = 5
	var high := c.shop_stock().map(func(x): return x.id)
	assert_true("sniper_rifle" in high and "metalgear" in high)


func test_buy_gun_becomes_primary_and_sells_extra() -> void:
	var c := Campaign.new_game(3)
	c.rep = 1
	var solo: Combatant = c.crew[0]   # assault rifle + heavy pistol
	var eb0 := c.eb
	assert_true(c.buy(solo, "shotgun"))
	assert_eq(solo.weapons[0].id(), "shotgun")
	assert_eq(solo.weapons.filter(func(w): return not w.is_melee()).size(), Campaign.MAX_GUNS)
	assert_eq(c.eb, eb0 - 600 + 50, "500eb list via a fixer (+20%), the heavy pistol sold back at half its 100eb")


func test_buy_armor_replaces_location_and_cant_overspend() -> void:
	var c := Campaign.new_game(3)
	var r: Combatant = c.crew[1]
	assert_true(c.buy(r, "light_armorjack", "head"))
	assert_eq((r.armor.head as ArmorPiece).id, "light_armorjack")
	c.eb = 10
	assert_false(c.buy(r, "kevlar", "body"))


func test_facilities_upgrade_and_apply() -> void:
	var c := Campaign.new_game(3)
	c.eb = 10000
	var n0 := c.board.size()
	assert_true(c.upgrade("intel"))
	assert_eq(c.board.size(), n0 + 1, "fixer network: one more gig")
	assert_true(c.upgrade("med_bay"))
	var solo: Combatant = c.crew[0]
	solo.hp = 1
	c.rest(1)
	assert_eq(solo.hp, mini(solo.max_hp(), 1 + solo.raw_stat("BODY") + 2), "med bay: +2 HP a day")
	assert_true(c.upgrade("med_bay"))
	assert_false(c.upgrade("med_bay"), "two levels max")
	assert_eq(c.treat_cost(), int(Campaign.ECON.treat_injury * 0.75))
	var d := Campaign.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(d.level("med_bay"), 2)
	assert_eq(d.level("intel"), 1)


func test_ripperdoc_foundations_humanity_and_therapy() -> void:
	var c := Campaign.new_game(5)
	c.eb = 10000
	var solo: Combatant = c.crew[0]
	solo.cyberware.clear()   # a clean slate (Role starting cyberware varies)
	solo.weapons = solo.weapons.filter(func(w): return not w.is_melee())
	assert_eq(c.install_block(solo, "kerenzikov"), "needs Neural Link", "speedware needs the foundation (p111)")
	var hum0 := solo.humanity
	assert_true(c.install(solo, "neural_link") > 0)
	assert_true(solo.humanity < hum0, "Humanity Loss rolled (p110)")
	assert_true(c.install(solo, "kerenzikov") > 0)
	assert_eq(c.install_block(solo, "kerenzikov"), "installed")
	c.install(solo, "cyberarm")
	c.install(solo, "wolvers")
	assert_eq(solo.weapons.filter(func(w): return w.is_melee()).map(func(w): return w.id()), ["heavy_melee"])
	var day0 := c.day
	var low := solo.humanity
	assert_true(c.therapy(solo))
	assert_true(solo.humanity > low and solo.humanity <= solo.max_humanity)
	assert_eq(c.day, day0 + 7, "therapy takes a week (p230)")


func test_cyber_claws_are_never_sold() -> void:
	var c := Campaign.new_game(5)
	c.eb = 10000
	var solo: Combatant = c.crew[0]
	solo.cyberware.clear()
	solo.weapons = solo.weapons.filter(func(w): return not w.is_melee())
	c.install(solo, "cyberarm")
	c.install(solo, "wolvers")
	assert_false(c.buy(solo, "light_melee"), "the claws fill the melee slot")
	c.install(solo, "big_knucks")
	var melee := solo.weapons.filter(func(w): return w.is_melee())
	assert_eq(melee.size(), 1)
	assert_eq(melee[0].id(), "heavy_melee", "keeps the harder-hitting Wolvers")
	var d := Combatant.from_dict(JSON.parse_string(JSON.stringify(solo.to_dict())))
	assert_true(d.weapons.any(func(w): return w.builtin))


func test_heat_rises_when_loud_and_cools_with_rest() -> void:
	var c := Campaign.new_game(6)
	var e := _finish(c, true)
	e.alarm = 2
	e.ncpd_in = -2
	var r := c.resolve(e)
	assert_eq(int(r.heat), Campaign.gig_heat(e))
	assert_true(c.heat >= 3, "alarm + NCPD")
	var h := c.heat
	c.rest(4)
	assert_eq(c.heat, h - 2, "lying low")
	var d := Campaign.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(d.heat, c.heat)


func test_downtime_episodes_for_low_humanity() -> void:
	var c := Campaign.new_game(6)
	var solo: Combatant = c.crew[0]
	solo.humanity = -1   # past the edge: an episode every time
	var other: Combatant = c.crew[1]
	var hp0 := other.hp
	var e := _finish(c, true)
	var r := c.resolve(e)
	assert_true(solo.display_name in r.episodes)
	assert_true(other.hp < hp0 or hp0 == 1, "a crewmate got hurt")
	assert_true(other.hp >= 1)
