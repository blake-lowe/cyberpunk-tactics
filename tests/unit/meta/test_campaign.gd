extends TestCase
## M6: the gig loop's campaign state.


func _finish(c: Campaign, won: bool) -> Encounter:
	var gig: Dictionary = c.accept(0)
	var m := SceneGen.generate(int(gig.seed), String(gig.scene), Campaign.scene_opts(gig))
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
	assert_eq(c.crew[0].ip, int(Campaign.IP_GROUP.together), "everyone came back: the Group column's 30 (p410)")
	assert_true(c.crew.all(func(m): return m.reputation >= 1), "a won gig is a deed everyone there is known for (p193)")
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
	assert_eq(b.ip, int(Campaign.IP_GROUP.failed), "tried valiantly: 10 IP (p410)")
	assert_eq(b.reputation, 0, "no deed in a failure")


func test_rest_heals_body_per_day() -> void:
	var c := Campaign.new_game(8)
	var a: Combatant = c.crew[0]
	a.hp = 5
	c.rest(2)
	assert_eq(a.hp, mini(a.max_hp(), 5 + a.raw_stat("BODY") * 2), "BODY HP per day of rest (p223)")


func test_item_repair_dv_and_time_by_price_category() -> void:
	assert_eq(ArmorPiece.repair_hours(20), 1, "Everyday: 1 hour (p140)")
	assert_eq(ArmorPiece.repair_hours(50), 6, "Costly: 6 hours")
	assert_eq(ArmorPiece.repair_hours(100), 24, "Premium: 1 day")
	assert_eq(ArmorPiece.repair_hours(500), 24 * 7, "Expensive: 1 week")
	assert_eq(ArmorPiece.maker_dv(50), 13)


func test_a_skilled_hand_repairs_ablated_armor_in_downtime() -> void:
	var c := Campaign.new_game(8)
	var a: Combatant = c.crew[0]
	var t: Combatant = c.crew[1]
	t.stats["TECH"] = 8
	t.skills["basic_tech"] = 10   # 18 + 1d10 beats Kevlar's DV13 unless it fumbles
	assert_eq(c.best_repairer(), t)
	a.armor["body"] = ArmorPiece.from_id("kevlar")   # Costly: DV13, 6 hours (p140)
	a.armor.body.sp = 2
	var done := c.repair_armor_work(2)
	assert_true(done.is_empty() and a.armor.body.sp == 2, "not done after 2 of 6 hours")
	assert_eq(a.armor.body.repair_work, 2, "the work carries over")
	var d := Combatant.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	assert_eq(d.armor.body.repair_work, 2, "and survives a save")
	for k in 3:   # a day is four tries' worth; a fumble just starts it over
		if a.armor.body.sp == a.armor.body.max_sp:
			break
		c.rest(1)
	assert_eq(a.armor.body.sp, a.armor.body.max_sp, "repaired")
	assert_eq(a.armor.body.repair_work, 0)


func test_an_unskilled_crew_cant_fix_expensive_armor() -> void:
	var c := Campaign.new_game(8)
	for m in c.crew:
		m.stats["TECH"] = 2
		m.skills["basic_tech"] = 0
	var a: Combatant = c.crew[0]
	a.armor["body"] = ArmorPiece.from_id("metalgear")   # Luxury: DV29, a month; TECH 2 + 1d10 can't beat it
	a.armor.body.sp = 3
	assert_true(c.repair_armor_work(24 * 30).is_empty())
	assert_eq(a.armor.body.sp, 3, "both tries fail at the halfway mark")
	assert_eq(a.armor.body.repair_work, 0, "and each failure starts the repair from scratch (p140)")


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
	c.crew[1].reputation = 5   # the crew's best-known name opens the market
	var high := c.shop_stock().map(func(x): return x.id)
	assert_true("sniper_rifle" in high and "metalgear" in high)


func test_buy_gun_becomes_primary_and_sells_extra() -> void:
	var c := Campaign.new_game(3)
	c.crew[0].reputation = 1
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


func test_reputation_is_the_best_deed_of_those_who_were_there() -> void:
	var c := Campaign.new_game(6)
	var home: Combatant = c.crew[1]
	c.board[0]["security"] = 2
	var gig: Dictionary = c.accept(0)
	var m := SceneGen.generate(int(gig.seed), String(gig.scene), Campaign.scene_opts(gig))
	var went: Array[Combatant] = [c.crew[0]]
	var e := Encounter.setup(m, c.dice, went)
	e.state = "won"
	e.alarm = 2
	var r := c.resolve(e)
	assert_eq(c.crew[0].reputation, 4, "a loud security-2 job: stories all over the local area (p193)")
	assert_eq(home.reputation, 0, "only those who were there")
	assert_eq(r.reputation, {c.crew[0].display_name: 4})
	assert_eq(c.best_reputation(), 4)
	c.crew[0].reputation = 6
	c.board[0]["security"] = 1
	gig = c.accept(0)
	e = Encounter.setup(m, c.dice, went)
	e.state = "won"
	c.resolve(e)
	assert_eq(c.crew[0].reputation, 6, "a lesser deed doesn't replace a greater one")
	var d := Campaign.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(d.crew[0].reputation, 6, "saved per character")


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


func test_a_known_crew_gets_personal_jobs() -> void:
	var c := Campaign.new_game(8)
	c.crew[0].reputation = 5
	var seen := false
	for k in 12:
		c.refresh_board()
		if c.board.any(func(b): return b.get("unique", false)):
			seen = true
			var u: Dictionary = c.board.filter(func(b): return b.get("unique", false))[0]
			assert_eq(int(u.security), 3)
			break
	assert_true(seen, "a personal job shows up")


func test_setup_pays_nothing() -> void:
	var c := Campaign.new_game(6)
	c.board[0]["setup"] = true
	var e := _finish(c, true)
	var r := c.resolve(e)
	assert_eq(int(r.pay), 0)


func test_downtime_is_only_what_the_book_has() -> void:
	assert_eq(Campaign.DOWNTIME.keys(), ["recover"], "natural healing (p223); no Train/Hustle rule in the book")
	var c := Campaign.new_game(9)
	assert_true(c.crew.all(func(m): return m.reputation == 0), "most characters start at Reputation 0 (p193)")
	assert_false(c.to_dict().has("heat") or c.to_dict().has("rep"), "no campaign heat or crew-wide rep")
