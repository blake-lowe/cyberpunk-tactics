extends TestCase
## Inventory: gear bought into safehouse storage, two kit slots per crew member (slot 1 a
## consumable, slot 2 a utility), used in gigs, settled afterwards.

const FLASH := "ammo/flashbang_ammo"
const AP := "ammo/armor_piercing_ammo"
const FIRE := "ammo/incendiary_ammo"
const COKE := "drugs/synthcoke"
const LACE := "drugs/black_lace"
const MEDSCAN := "gear/medscanner"


func _camp() -> Campaign:
	var c := Campaign.new_game(4)
	c.crew[0].reputation = 5
	c.eb = 20000
	return c


func _enc_with(kit: Array, overrides := {}) -> Encounter:
	var m := SceneGen.generate(11, "skirmish", {"security": 1})
	var dice := Dice.new(3)
	var c := Recruit.generate(dice, "solo", "edgerunner")
	for k in overrides:
		c.stats[k] = overrides[k]
	c.kit[0] = kit[0]
	c.kit[1] = kit[1]
	var crew: Array[Combatant] = [c]
	var e := Encounter.setup(m, dice, crew)
	e.next_turn()
	return e


func test_slot_rules_follow_the_data() -> void:
	assert_true(Items.fits(0, FLASH) and Items.fits(0, COKE), "slot 1 takes consumables")
	assert_false(Items.fits(0, MEDSCAN), "but not utilities")
	assert_true(Items.fits(1, MEDSCAN), "slot 2 takes utilities")
	assert_false(Items.fits(1, FLASH), "but not a second consumable")
	assert_eq(Items.kind(MEDSCAN), "utility")


func test_a_new_crew_starts_with_empty_storage() -> void:
	var camp := Campaign.new_game(4)
	assert_true(camp.stash.is_empty(), "the book has no basic grenade to hand out (p94, p344)")
	assert_true(camp.crew.all(func(m): return m.kit == ["", ""]))
	assert_false(Items.is_item("ammo/frag_grenade"))


func test_market_prices_are_list_prices() -> void:
	var camp := _camp()
	assert_eq(camp.item_price(FLASH), Items.price(FLASH))
	assert_false(Campaign.FACILITIES.has("armory"), "the Armory is a room, not an upgrade")


func test_buying_fills_storage_and_packing_needs_stock() -> void:
	var camp := _camp()
	var a: Combatant = camp.crew[0]
	var b: Combatant = camp.crew[1]
	assert_false(camp.set_kit(a, 0, FLASH), "nothing in storage yet")
	assert_true(camp.buy_item(FLASH))
	assert_eq(int(camp.stash[FLASH]), 1)
	assert_true(camp.set_kit(a, 0, FLASH))
	assert_false(camp.set_kit(b, 0, FLASH), "one flashbang can't go with two people")
	assert_false(camp.set_kit(a, 0, MEDSCAN), "a utility can't take the consumable slot")
	camp.buy_item(MEDSCAN)
	assert_true(camp.set_kit(a, 1, MEDSCAN))
	camp.crew[0].reputation = 0
	assert_false(camp.buy_item(LACE), "Black Lace needs a name on the street")


func test_after_a_gig_spent_consumables_go_and_the_rest_comes_back() -> void:
	var camp := _camp()
	var a: Combatant = camp.crew[0]
	camp.buy_item(FLASH)
	camp.buy_item(AP)
	camp.buy_item(MEDSCAN)
	camp.set_kit(a, 0, FLASH)
	camp.set_kit(a, 1, MEDSCAN)
	a.kit_spent = [true, false]
	var gone := camp._settle_kits()
	assert_false(camp.stash.has(FLASH), "the thrown flashbang is gone")
	assert_eq(int(camp.stash[MEDSCAN]), 1, "the medscanner comes home")
	assert_eq(a.kit[0], "", "and the empty slot is cleared")
	assert_eq(gone.size(), 1)
	var b: Combatant = camp.crew[1]
	camp.set_kit(b, 0, AP)
	b.dead = true
	camp._settle_kits()
	assert_false(camp.stash.has(AP), "whoever doesn't come back loses what they carried")


func test_doses_boost_stats_for_the_gig_and_spend_the_slot() -> void:
	var e := _enc_with([COKE, ""])
	var c: Combatant = e.cur.c
	var ref := c.stat("REF")
	var r := e.take_dose(0)
	assert_true(r.ok)
	assert_eq(c.stat("REF"), ref + 1, "Synthcoke +1 REF (p.358)")
	assert_false(e.turn.action_available, "an Action")
	e.turn.action_available = true
	assert_false(e.take_dose(0).ok, "used up")
	assert_eq(e.kit_action(0), "")


func test_black_lace_costs_humanity_and_shrugs_off_serious_wounds() -> void:
	var e := _enc_with([LACE, ""])
	var c: Combatant = e.cur.c
	var hum := c.humanity
	c.hp = c.seriously_wounded_threshold() - 1
	var pen := c.action_penalty()
	assert_true(pen > 0)
	var r := e.take_dose(0)
	assert_true(r.ok)
	assert_true(c.humanity < hum, "2d6 Humanity (p.358)")
	assert_eq(c.action_penalty(), 0, "serious wounds ignored")


func test_a_flashbang_blinds_and_deafens_for_a_minute() -> void:
	var hit := false
	for s in 40:
		var e := _enc_with([FLASH, ""])
		var g: Dictionary = e.units.filter(func(u): return u.team == Encounter.OPFOR)[0]
		g.pos = e.cur.pos + Vector3i(3, 0, 0)
		if not e.m.walkable(g.pos.z, Vector2i(g.pos.x, g.pos.y)) or not e.los.trace(e.cur.pos, g.pos).clear:
			continue
		g.c.stats["WILL"] = 1
		e.dice = Dice.new(s)
		var r := e.throw_grenade(g.pos, 0)
		assert_true(r.ok)
		assert_true(e.cur.c.kit_spent[0])
		var mine: Array = r.hits.filter(func(h): return h.id == g.id)
		if not mine.is_empty() and not mine[0].dodged and not mine[0].status.get("resisted", true):
			assert_true(g.c.has_injury("damaged_eye") and g.c.has_injury("damaged_ear"), "Damaged Eye and Ear (p.346)")
			assert_eq(r.damage, 0, "no damage")
			for inj in g.c.injuries:
				if inj.has("expires_in"):
					inj.expires_in = 1
			e.cur = g
			e.turn = TurnState.begin(e.dice, g.c)
			e.end_turn()
			assert_false(g.c.has_injury("damaged_eye"), "gone after the minute")
			hit = true
			break
	assert_true(hit, "a flashbang that landed and wasn't resisted")


func test_damage_grenades_carry_their_ammo_rules() -> void:
	var c := Fixtures.unarmored()
	c.armor["body"] = ArmorPiece.from_id("light_armorjack")
	c.hp = 300
	var faces := PackedInt32Array([6, 6, 6, 1, 1, 1])
	Attack.explosion_rolled(Dice.new(1), 30, faces, [c], Items.fx(AP))
	assert_eq(c.sp("body"), 9, "Armor-Piercing ablates 2 (p.345)")
	var d := Fixtures.unarmored()
	d.hp = 300
	Attack.explosion_rolled(Dice.new(1), 30, faces, [d], Items.fx(FIRE))
	assert_eq(d.burning, 2, "Incendiary sets them alight (p.346)")


func test_carried_utilities_add_their_skill_bonus_once() -> void:
	var c := Recruit.generate(Dice.new(2), "medtech", "edgerunner")
	var fa := c.skill_base("first_aid")
	c.kit[1] = MEDSCAN
	assert_eq(c.skill_base("first_aid"), fa + 2, "Medscanner +2 First Aid (p.353)")
	c.kit[0] = MEDSCAN
	assert_eq(c.skill_base("first_aid"), fa + 2, "two scanners don't stack")


func test_drugs_can_hook_you_and_therapy_cures_it() -> void:
	var camp := _camp()
	var a: Combatant = camp.crew[0]
	a.stats["WILL"] = 1
	var hooked := false
	for i in 30:
		a.addictions.clear()
		a.drugs_taken = ["synthcoke"]
		camp._addiction_checks()
		if "synthcoke" in a.addictions:
			hooked = true
			break
	assert_true(hooked, "WILL 1 vs DV15: hooked sooner or later (p.229)")
	a.drugs_taken.clear()
	var ref := a.stat("REF")
	a.addictions.erase("synthcoke")
	assert_eq(a.stat("REF"), ref + 2, "an addict runs 2 REF short without it")
	a.addictions.append("synthcoke")
	assert_true(camp.treat_addiction(a, "synthcoke").is_empty(), "therapy needs a Medtech, not the patient (p229)")
	var doc := Recruit.generate(camp.dice, "medtech", "edgerunner")
	camp.crew.append(doc)
	assert_eq(camp.therapist_for(a), doc)
	assert_eq(camp.therapist_for(doc), null, "Medtechs can't do Therapy on themselves")
	doc.stats["TECH"] = 8
	doc.medicine["pharma"] = 5
	doc.medicine["cryo"] = 5   # 18 + 1d10 beats DV15 unless it fumbles
	var eb0 := camp.eb
	var day0 := camp.day
	var tries := 0
	while "synthcoke" in a.addictions and tries < 5:
		camp.treat_addiction(a, "synthcoke")
		tries += 1
	assert_false("synthcoke" in a.addictions, "clean")
	assert_eq(camp.eb, eb0 - 500 * tries, "the Medtech buys the 500eb materials each week (p230)")
	assert_eq(camp.day, day0 + 7 * tries, "a week each")
	a.drugs_taken = ["synthcoke"]
	a.stats["WILL"] = 10
	camp._addiction_checks()
	assert_true("synthcoke" in a.addictions, "for a year after, that drug's roll fails automatically (p230)")
	var back := Combatant.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	assert_eq(back.clean_since, a.clean_since)


func test_a_failed_therapy_wastes_the_week_and_materials() -> void:
	var camp := _camp()
	var a: Combatant = camp.crew[0]
	a.addictions.append("synthcoke")
	var doc := Recruit.generate(camp.dice, "medtech", "edgerunner")
	camp.crew.append(doc)
	doc.stats["TECH"] = 0
	doc.medicine.clear()   # 0 + 1d10 vs DV15: only a critical 10 can beat it
	var eb0 := camp.eb
	var failed := false
	for k in 10:
		var r := camp.treat_addiction(a, "synthcoke")
		if not r.success:
			failed = true
			break
		a.addictions.append("synthcoke")
	assert_true(failed, "TECH 0 + 1d10 vs DV15 mostly fails")
	assert_true("synthcoke" in a.addictions, "still hooked")
	assert_true(camp.eb < eb0, "the materials are gone")


func test_storage_kits_and_addictions_survive_a_save() -> void:
	var camp := _camp()
	camp.buy_item(FLASH)
	camp.set_kit(camp.crew[0], 0, FLASH)
	camp.crew[0].addictions.append("boost")
	var back := Campaign.from_dict(JSON.parse_string(JSON.stringify(camp.to_dict())))
	assert_eq(int(back.stash[FLASH]), 1)
	assert_eq(back.crew[0].kit[0], FLASH)
	assert_true("boost" in back.crew[0].addictions)
