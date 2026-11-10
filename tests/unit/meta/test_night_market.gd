extends TestCase
## The book's Night Market (CPR core p.337-339, data/rules/night_market.json) and safehouse storage
## for everything: buying into storage, equipping weapons and armour from it.


func _market_with(c: Campaign, keys: Array) -> void:
	c.market = {"opened": c.day, "closes": c.day + 999, "categories": [], "listings": [{"category": "test", "name": "Test", "keys": keys}]}


func test_every_category_has_twenty_d100_rows_covering_1_to_100() -> void:
	var cats: Array = NightMarket.data().categories
	assert_eq(cats.size(), 6, "six kinds of goods on a d6 (p338)")
	for c in cats:
		var rows: Array = c.listings
		assert_eq(rows.size(), 20, "%s: twenty rows" % c.id)
		var nxt := 1
		for r in rows:
			assert_eq(int(r.d100[0]), nxt, "%s: no gaps" % c.id)
			nxt = int(r.d100[1]) + 1
		assert_eq(nxt, 101)
		for r in rows:
			for k in r.get("keys", []):
				var known: bool = Items.is_stored(String(k)) or Items.is_cyberware(String(k)) or not Items.def(String(k)).is_empty() \
					or (Items.section(String(k)) == "weapon" and RulesDB.load_json("weapons.json").weapons.has(Items.base_id(String(k))))
				assert_true(known, "%s: %s is an item in our data" % [r.name, k])


func test_a_roll_is_two_different_categories_with_one_to_ten_listings_each() -> void:
	for s in 30:
		var m := NightMarket.roll(Dice.new(s), 5)
		var cats: Array = m.categories
		assert_eq(cats.size(), 2)
		assert_true(cats[0] != cats[1], "a repeat is rerolled (p338)")
		for cid in cats:
			var rows: Array = m.listings.filter(func(l): return l.category == cid and l.has("row"))
			assert_between(float(rows.size()), 1.0, 10.0, "1d10 types of items")
			var seen := {}
			for l in rows:
				seen[int(l.row)] = true
			assert_eq(seen.size(), rows.size(), "no row twice")
		for k in NightMarket.keys_of(m):
			assert_true(NightMarket.on_sale(k), "%s: only what the game plays is on sale" % k)
		assert_eq(int(m.opened), 5)
		assert_eq(int(m.closes), 5 + int(NightMarket.data().house_rules.open_days))


func test_the_same_seed_rolls_the_same_market() -> void:
	assert_eq(JSON.stringify(NightMarket.roll(Dice.new(77), 1)), JSON.stringify(NightMarket.roll(Dice.new(77), 1)))


func test_price_filters_follow_the_book_rows() -> void:
	assert_eq(NightMarket.matching({"kind": "armor", "cost_max": 100}), ["armor/leathers", "armor/kevlar", "armor/light_armorjack", "armor/medium_armorjack"])
	assert_eq(NightMarket.matching({"kind": "armor", "cost": 500}), ["armor/heavy_armorjack", "armor/flak"])
	assert_eq(NightMarket.matching({"kind": "armor", "cost": 1000}), ["armor/bodyweight_suit"])
	assert_eq(NightMarket.matching({"kind": "kit", "section": "drugs", "cost_max": 20}), ["drugs/synthcoke"], "Street Drugs of 20eb or less")
	assert_eq(NightMarket.matching({"kind": "kit", "section": "drugs", "cost": 50}), ["drugs/black_lace", "drugs/boost"])
	assert_eq(NightMarket.matching({"kind": "cyberware", "category": "cyberoptics", "option": true, "cost_max": 500}),
		["cyberware/dartgun", "cyberware/targeting_scope", "cyberware/teleoptics"])
	var thousand := NightMarket.matching({"kind": "cyberware", "category": "neuralware", "option": true, "cost": 1000})
	assert_eq(thousand[0], "cyberware/pain_editor")
	assert_true("cyberware/skill_chip@autofire" in thousand, "a chip for an (x2) Skill is 1,000eb (p.360)")
	assert_false("cyberware/skill_chip@handgun" in thousand, "a chip for any other Skill is 500eb")
	assert_true("cyberware/skill_chip@handgun" in NightMarket.matching({"kind": "cyberware", "category": "neuralware", "cost_max": 500}))


func test_a_dealer_stocks_a_few_skill_chips_each_for_one_skill() -> void:
	var l := {"name": "Neuralware Option of 500eb or less", "filter": {"kind": "cyberware", "category": "neuralware", "option": true, "cost_max": 500}}
	var keys := NightMarket.resolve(Dice.new(5), l)
	var chips := keys.filter(func(k): return Items.base_id(k) == "skill_chip")
	assert_eq(chips.size(), NightMarket.CHIP_STOCK, "a few chips, chosen at purchase")
	assert_eq(keys, NightMarket.resolve(Dice.new(5), l), "seeded")
	for k in chips:
		assert_true(Items.is_stored(k) and NightMarket.on_sale(k), k)
		assert_true(Items.display_name(k).begins_with("Skill Chip: "), Items.display_name(k))
	assert_eq(Items.price("cyberware/skill_chip@autofire"), 1000)
	assert_eq(Items.price("cyberware/popup_ranged_weapon@heavy_pistol"), 600, "the gun is the buyer's (p.365): 500 + 100")
	assert_false(Items.is_stored("cyberware/skill_chip"), "a chip is made for a Skill")
	assert_false(Items.is_stored("cyberware/skill_chip@not_a_skill"))
	assert_true(NightMarket.matching({"kind": "kit", "section": "attachments", "cost_max": 100}).is_empty(), "attachments aren't stocked yet")


func test_gms_choice_picks_one_and_weapons_come_in_every_quality() -> void:
	var ex := NightMarket.resolve(Dice.new(3), {"name": "Exotic", "filter": {"kind": "weapon", "category": "exotic"}, "choose": 1})
	assert_eq(ex.size(), 1, "a single exotic (exotics have no Quality Ratings, p342)")
	var melee := NightMarket.resolve(Dice.new(3), {"name": "Light Melee", "keys": ["weapon/light_melee"]})
	assert_eq(melee.size(), 3)
	assert_true(NightMarket.resolve(Dice.new(3), {"name": "Canned Goods"}).is_empty(), "food isn't in the game")
	assert_true(NightMarket.resolve(Dice.new(3), {"name": "Bow", "keys": ["weapon/bow"]}).is_empty(), "bows wait for arrows")


func test_a_cyberware_option_brings_its_foundations() -> void:
	var ls: Array = [{"category": "cyberware", "name": "Neuralware Option of exactly 1,000eb", "keys": ["cyberware/pain_editor"]}]
	NightMarket._add_foundations(ls)
	assert_eq(ls.size(), 2)
	assert_eq(ls[1]["keys"], ["cyberware/chipware_socket", "cyberware/neural_link"], "the whole chain (p338)")


func test_markets_come_and_go() -> void:
	var c := Campaign.new_game(4)
	assert_eq((c.market.categories as Array).size(), 2, "a market is up from day 1")
	var closes := int(c.market.closes)
	var first := JSON.stringify(c.market)
	c.rest(closes - c.day - 1)
	assert_eq(JSON.stringify(c.market), first, "still the same market")
	c.rest(1)
	assert_eq(int(c.market.opened), closes, "a new one sets up when it closes")


func test_buying_goes_into_storage_and_never_blocks_another() -> void:
	var c := Campaign.new_game(4)
	c.eb = 5000
	_market_with(c, ["weapon/assault_rifle", "armor/kevlar", "cyberware/neural_link"])
	var weapons0 := c.crew[0].weapons.size()
	assert_true(c.buy("weapon/assault_rifle"))
	assert_true(c.buy("weapon/assault_rifle"), "owning one doesn't stop a second")
	assert_eq(c.stored("weapon/assault_rifle"), 2)
	assert_eq(c.crew[0].weapons.size(), weapons0, "bought for nobody")
	assert_eq(c.eb, 4000, "list price")
	assert_false(c.buy("weapon/sniper_rifle"), "not on sale (over 100eb, not listed)")
	assert_true(c.buy("cyberware/neural_link"), "chrome is bought into storage like the rest")
	assert_eq(c.stored("cyberware/neural_link"), 1)
	c.eb += 500
	assert_true(c.buy("ammo/flashbang_ammo"), "a staple")
	c.eb = 10
	assert_false(c.buy("armor/kevlar"), "can't overspend")
	assert_true(c.market_stock().any(func(x): return x.key == "ammo/teargas_ammo" and x.staple))
	assert_true(c.market_stock().any(func(x): return x.key == "weapon/assault_rifle" and int(x.owned) == 2 and x.kind == "weapon"))


func test_equip_and_unequip_weapons_from_storage() -> void:
	var c := Campaign.new_game(4)
	var solo: Combatant = c.crew[0]
	var before: Array = solo.weapons.map(func(w): return w.id())
	assert_false(c.equip_weapon(solo, "weapon/shotgun"), "nothing in storage")
	c.stash["weapon/shotgun@poor"] = 1
	assert_eq(c.weapon_options(), ["weapon/shotgun@poor"])
	assert_true(c.equip_weapon(solo, "weapon/shotgun@poor"))
	assert_eq(solo.weapons[-1].id(), "shotgun", "carried after what they had: order is as equipped")
	assert_eq(solo.weapons[-1].quality, "poor")
	assert_false(c.stash.has("weapon/shotgun@poor"))
	assert_true(c.unequip_weapon(solo, 0))
	assert_eq(c.stored(Items.weapon_key(String(before[0]))), 1, "back to storage with its quality")
	assert_true(c.equip_weapon(solo, Items.weapon_key(String(before[0])), 0), "and back as the primary")
	assert_eq(solo.weapons[0].id(), before[0])
	assert_false(c.unequip_weapon(solo, 99))


func test_armor_swaps_keep_upgrades_and_ablation() -> void:
	var c := Campaign.new_game(4)
	var r: Combatant = c.crew[1]
	var old: ArmorPiece = r.armor.body
	old.upgraded = true
	old.max_sp += 1
	old.sp = 5
	c.stash["armor/kevlar"] = 1
	assert_eq(c.armor_options(), ["armor/kevlar"])
	assert_eq(c.equip_block(r, "armor/kevlar", "legs"), "no such location")
	assert_true(c.equip_armor(r, "body", "armor/kevlar"))
	assert_eq((r.armor.body as ArmorPiece).id, "kevlar")
	var key := "armor/%s@upgraded@sp5" % old.id
	assert_eq(c.stored(key), 1, "the old piece goes to storage, upgrade and damage noted")
	var back := Items.make_armor(key)
	assert_eq(back.max_sp, old.max_sp)
	assert_eq(back.sp, 5)
	assert_true(back.upgraded)
	assert_true(c.unequip_armor(r, "head"))
	assert_eq(r.armor.head, null)
	assert_true(c.equip_armor(r, "head", key), "any piece goes on the head or the body")
	assert_eq(r.sp("head"), 5)


func test_recruits_arrive_equipped_and_storage_starts_empty() -> void:
	var c := Campaign.new_game(4)
	assert_true(c.stash.is_empty())
	assert_true(c.crew.all(func(m): return not m.weapons.is_empty() and m.armor.body != null))
	assert_true(c.recruits.all(func(m): return not m.weapons.is_empty()))


func test_check_stash_drops_what_storage_cant_hold() -> void:
	var c := Campaign.new_game(4)
	c.stash = {"weapon/nope": 1, "armor/kevlar": 0, "drugs/synthcoke": 1, "cyberware/neural_link": 1}
	c.crew[0].kit[0] = "drugs/synthcoke"
	c.crew[1].kit[0] = "drugs/synthcoke"
	c.check_stash()
	assert_eq(c.stash, {"drugs/synthcoke": 1, "cyberware/neural_link": 1}, "a stored piece of chrome is kept")
	assert_eq(c.crew.filter(func(m): return m.kit[0] == "drugs/synthcoke").size(), 1, "one dose can't go with two people")


func test_humanity_therapy_follows_the_book() -> void:
	var c := Campaign.new_game(4)
	c.eb = 5000
	var a: Combatant = c.crew[0]
	a.humanity = a.max_humanity - 20
	assert_true(c.humanity_therapy(a).is_empty(), "a Medtech performs therapy (p229)")
	var doc := Recruit.generate(c.dice, "medtech", "edgerunner")
	c.crew.append(doc)
	doc.stats["TECH"] = 8
	doc.medicine["pharma"] = 5
	doc.medicine["cryo"] = 5   # 18 + 1d10 beats DV15 unless it fumbles
	var eb0 := c.eb
	var day0 := c.day
	var low := a.humanity
	var r := c.humanity_therapy(a, "standard")
	assert_eq(c.eb, eb0 - 100, "Standard: 100eb of materials (p230)")
	assert_eq(c.day, day0 + 7, "a week")
	if r.success:
		assert_between(float(a.humanity - low), 2.0, 12.0, "2d6 Humanity back")
	assert_true(a.humanity <= a.max_humanity)
	assert_eq(Campaign.humanity_therapy_cost("extreme"), 500, "Extreme: 500eb of materials")
	a.humanity = a.max_humanity
	assert_true(c.humanity_therapy(a).is_empty(), "nothing to regain")


func test_a_failed_humanity_therapy_wastes_the_week_and_materials() -> void:
	var c := Campaign.new_game(4)
	c.eb = 5000
	var a: Combatant = c.crew[0]
	var doc := Recruit.generate(c.dice, "medtech", "edgerunner")
	c.crew.append(doc)
	doc.stats["TECH"] = 0
	doc.medicine.clear()   # 0 + 1d10 vs DV17: only an exploding 10 makes it
	var failed := false
	for k in 10:
		a.humanity = a.max_humanity - 20
		var eb0 := c.eb
		var r := c.humanity_therapy(a, "extreme")
		assert_eq(c.eb, eb0 - 500, "the materials are spent either way (p229)")
		if not r.success:
			assert_eq(a.humanity, a.max_humanity - 20, "nothing regained")
			failed = true
			break
	assert_true(failed)


func test_everything_up_to_premium_is_always_on_sale() -> void:
	var st := NightMarket.staples()
	assert_true("weapon/heavy_pistol" in st, "a 50eb Heavy Pistol needs no fixer (p.385)")
	assert_true("armor/kevlar" in st)
	for k in st:
		assert_true(Items.price(k) <= 100, "%s is Premium or less" % k)
	assert_false("weapon/assault_rifle" in st, "500eb waits for a Night Market")


func test_price_tiers_are_the_books() -> void:
	assert_eq(Items.price_tier(10), "Cheap", "p.385")
	assert_eq(Items.price_tier(50), "Costly")
	assert_eq(Items.price_tier(100), "Premium")
	assert_eq(Items.price_tier(1000), "Very Expensive")
	assert_eq(Items.price_tier(25000), "Super Luxury", "10,000eb and up")
	assert_eq(Items.slot_name(0), "Consumable")
	assert_eq(Items.slot_name(1), "Utility")
