extends TestCase
## The model glue behind the between-gigs screens: merged log lines, Recover's day count, weapon
## order in a loadout, and the per-member debrief (what each crew member's gig changed) that the
## debrief screen and the crew cards' marks read.


func _gig(c: Campaign, won := true) -> Encounter:
	var gig: Dictionary = c.accept(0)
	var m := SceneGen.generate(int(gig.seed), String(gig.scene), Campaign.scene_opts(gig))
	var e := Encounter.setup(m, c.dice, c.alive_crew())
	e.state = "won" if won else "lost"
	return e


func test_repeated_log_lines_merge_with_a_count() -> void:
	var c := Campaign.new_game(3)
	c.say("Bought Flashbang")
	c.say("Bought Flashbang")
	c.say("Bought Flashbang")
	assert_eq(c.log[-1], "Bought Flashbang ×3")
	c.say("Bought Smoke Grenade")
	assert_eq(c.log[-1], "Bought Smoke Grenade", "a different line starts a new entry")
	assert_eq(c.log[-2], "Bought Flashbang ×3")


func test_buying_twice_merges_in_the_log() -> void:
	var c := Campaign.new_game(4)
	c.eb = 10000
	var key: String = NightMarket.staples()[0]
	assert_true(c.buy(key) and c.buy(key))
	assert_eq(c.log[-1], "Bought %s ×2" % Items.display_name(key))
	assert_eq(c.stored(key), 2, "owning one never blocks buying another")


func test_days_to_recover_counts_body_hp_a_day() -> void:
	var c := Campaign.new_game(5)
	assert_eq(c.days_to_recover(), 0, "everyone at full HP")
	var a: Combatant = c.crew[0]
	var body := a.raw_stat("BODY")
	a.hp = a.max_hp() - body * 2 - 1   # two days and a bit: three days (p223)
	assert_eq(c.days_to_recover(), 3)
	var day := c.day
	assert_eq(c.recover_until_healed(), 3)
	assert_eq(a.hp, a.max_hp())
	assert_eq(c.day, day + 3)
	assert_eq(c.recover_until_healed(), 0, "nothing to heal: no days pass")
	assert_eq(c.day, day + 3)


func test_reorder_weapon_moves_one_within_the_loadout() -> void:
	var c := Campaign.new_game(6)
	var a: Combatant = c.crew[0]
	while a.weapons.size() < 2:
		a.weapons.append(Items.make_weapon(NightMarket.staples()[0]))
	var first := a.weapons[0]
	var second := a.weapons[1]
	assert_true(c.reorder_weapon(a, 1, 0))
	assert_eq(a.weapons[0], second, "moved up to be drawn first")
	assert_eq(a.weapons[1], first)
	assert_false(c.reorder_weapon(a, 0, 0), "no move")
	assert_false(c.reorder_weapon(a, 5, 0), "out of range")


func test_debrief_lists_each_member_and_what_changed() -> void:
	var c := Campaign.new_game(7)
	var a: Combatant = c.crew[0]
	var b: Combatant = c.crew[1]
	var crits: Dictionary = RulesDB.load_json("critical_injuries.json")
	a.add_injury(crits.body["5"], "body", false)   # already hurt before the gig: not news
	var e := _gig(c, true)
	a.add_injury(crits.body["6"], "body", false)   # Broken Arm on the gig
	b.dead = true
	var r := c.resolve(e)
	assert_eq(r.members.size(), 2, "the fallen are in the debrief too")
	var ma: Dictionary = c.debrief_for(a)
	assert_eq(ma.injuries, ["Broken Arm"], "only injuries from this gig")
	assert_eq(int(ma.ip), int(Campaign.IP_GROUP.barely), "won with a death: 20 IP (p410)")
	assert_true(int(ma.reputation) >= 1, "the deed's Level (p193)")
	assert_false(ma.dead)
	var mb: Dictionary = r.members.filter(func(m): return m.name == b.display_name)[0]
	assert_true(mb.dead)
	assert_eq(int(mb.ip), 0)
	for w in b.weapons:
		assert_true(w.display_name() in mb.lost or w.builtin, "lost gear lists each weapon they carried: %s" % [mb.lost])
	if b.armor.body:
		assert_true((b.armor.body as ArmorPiece).name in mb.lost, "and the armour they wore")
	for cw in b.cyberware:
		assert_true(String(RulesDB.cyberware(cw).name) in mb.lost, "and their chrome")
	assert_eq(ma.lost, [], "the living lost nothing")
	var marks := c.marks_for(a)
	assert_true("+%d IP" % int(Campaign.IP_GROUP.barely) in marks, "crew card mark: %s" % [marks])
	assert_true("Broken Arm" in marks)


func test_debrief_survives_a_save_and_clears_at_the_next_gig() -> void:
	var c := Campaign.new_game(8)
	c.resolve(_gig(c, true))
	assert_false(c.marks_for(c.crew[0]).is_empty())
	var back := Campaign.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.marks_for(back.crew[0]), c.marks_for(c.crew[0]), "marks stay until the next gig, across a save")
	back.accept(0)
	assert_true(back.marks_for(back.crew[0]).is_empty(), "taking the next gig clears them")


func test_debrief_records_kit_used_and_a_new_addiction() -> void:
	var c := Campaign.new_game(9)
	c.eb = 10000
	var a: Combatant = c.crew[0]
	var cons: Array = NightMarket.staples().filter(func(k): return Items.fits(0, k))
	var key: String = cons[0]
	assert_true(c.buy(key))
	assert_true(c.set_kit(a, 0, key))
	var e := _gig(c, true)
	a.kit_spent[0] = true
	a.clean_since["black_lace"] = c.day   # within a year of therapy the roll fails (p230): hooked
	a.drugs_taken.append("black_lace")
	c.resolve(e)
	var m := c.debrief_for(a)
	assert_eq(m.kit, [Items.display_name(key)])
	assert_eq(m.addicted, [String(RulesDB.gear("drugs", "black_lace").name)])
	assert_true(c.marks_for(a).any(func(x): return x.begins_with("ADDICTED")))
