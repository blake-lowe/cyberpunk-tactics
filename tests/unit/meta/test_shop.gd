extends TestCase
## The Night Market shop (Shop, Campaign.buy_cart): the cart is bought all or nothing into
## storage; categories, search, sorts and the market's stock in plain words.


func _camp(keys: Array, eb := 5000, qty := 99) -> Campaign:
	var c := Campaign.new_game(4)
	c.eb = eb
	c.market = NightMarket.stocked(keys, c.day, qty, 3)
	c.market.categories = ["test"]
	return c


func test_buy_cart_buys_every_line_into_storage() -> void:
	var c := _camp(["weapon/assault_rifle", "cyberware/neural_link"])
	var cart := {"weapon/assault_rifle": 2, "ammo/flashbang_ammo": 3, "cyberware/neural_link": 1}
	var expect := 2 * Items.price("weapon/assault_rifle") + 3 * Items.price("ammo/flashbang_ammo") + Items.price("cyberware/neural_link")
	assert_eq(Campaign.cart_total(cart), expect)
	assert_eq(Campaign.cart_count(cart), 6)
	var flash0 := c.stored("ammo/flashbang_ammo")
	var r := c.buy_cart(cart)
	assert_true(r.ok)
	assert_eq(int(r.count), 6)
	assert_eq(int(r.total), expect)
	assert_eq(c.eb, 5000 - expect, "eb deducted once for the lot")
	assert_eq(c.stored("weapon/assault_rifle"), 2)
	assert_eq(c.stored("ammo/flashbang_ammo"), flash0 + 3)
	assert_eq(c.stored("cyberware/neural_link"), 1, "chrome waits in storage for the Med Bay")
	assert_eq((r.bought as Dictionary).size(), 3)
	assert_eq(c.log[-1], "Bought 6 items for %s eb" % Campaign.eb_text(expect))


func test_buy_cart_is_all_or_nothing() -> void:
	var c := _camp(["weapon/assault_rifle"], 600)
	var before := JSON.stringify(c.stash)
	var r := c.buy_cart({"weapon/assault_rifle": 1, "ammo/flashbang_ammo": 2})   # 500 + 200 > 600
	assert_false(r.ok)
	assert_eq(String(r.reason), "short")
	assert_eq(c.eb, 600, "nothing paid when short")
	assert_eq(JSON.stringify(c.stash), before, "nothing bought when short")
	r = c.buy_cart({"ammo/flashbang_ammo": 1, "weapon/sniper_rifle": 1})   # not listed, over the staples' cap
	assert_false(r.ok)
	assert_eq(String(r.reason), "off_sale")
	assert_eq(String(r.key), "weapon/sniper_rifle")
	assert_eq(c.eb, 600, "an item off sale stops the whole cart")
	assert_eq(JSON.stringify(c.stash), before)
	r = c.buy_cart({"weapon/nope": 1})
	assert_eq(String(r.reason), "off_sale", "not a storage key")
	assert_eq(String(c.buy_cart({}).reason), "empty")
	assert_eq(String(c.buy_cart({"ammo/flashbang_ammo": 0}).reason), "empty", "zero lines are skipped")
	assert_true(c.buy_cart({"weapon/assault_rifle": 1}).ok, "exactly affordable")
	assert_eq(c.eb, 100)
	assert_eq(c.log[-1], "Bought %s for 500 eb" % Items.display_name("weapon/assault_rifle"), "one item is named")
	assert_true(c.buy("ammo/teargas_ammo"), "buy() still buys one")


func test_categories() -> void:
	assert_eq(Shop.category_of("weapon/heavy_pistol@poor"), "Firearms")
	assert_eq(Shop.category_of("weapon/light_melee"), "Melee")
	assert_eq(Shop.category_of("armor/kevlar"), "Armor")
	assert_eq(Shop.category_of("cyberware/cybereye"), "Cyberware")
	assert_eq(Shop.category_of("ammo/flashbang_ammo"), "Grenades")
	assert_eq(Shop.category_of("drugs/synthcoke"), "Drugs")
	assert_eq(Shop.category_of("gear/medscanner"), "Gear")
	assert_eq(Shop.category_of("gear/cyberdeck_standard"), "Netrunning")
	assert_eq(Shop.category_of("programs/sword"), "Netrunning")
	assert_eq(Shop.category_of("hardware/range_upgrade"), "Netrunning")
	var c := _camp(["weapon/assault_rifle"])
	var all := Shop.entries(c).filter(func(e): return not String(e.cat) in ["Gear", "Netrunning"])   # the Anti-Smog Mask (20eb) and cheap Programs are staples now
	assert_eq(Shop.listed_categories(all), ["Firearms", "Melee", "Armor", "Cyberware", "Grenades", "Drugs"], "the six always; Gear only when on sale")
	assert_true("Netrunning" in Shop.listed_categories(Shop.entries(c)), "the fixer always has Programs of 100eb or less (under the staples' cap)")
	assert_true("Gear" in Shop.listed_categories(Shop.entries(c)), "the fixer always has an Anti-Smog Mask (Everyday, under the staples' cap)")
	assert_true("Gear" in Shop.listed_categories(Shop.entries(_camp(["gear/medscanner"]))))


func test_one_entry_per_quality_and_market_badge() -> void:
	var c := _camp(["weapon/shotgun@poor", "weapon/shotgun", "weapon/shotgun@excellent", "weapon/heavy_pistol"])
	var all := Shop.entries(c)
	var sg := all.filter(func(e): return Items.base_id(String(e.key)) == "shotgun")
	assert_eq(sg.size(), 3, "Poor, Standard and Excellent stay separate entries")
	assert_eq(sg.map(func(e): return String(e.quality)), ["poor", "standard", "excellent"])
	assert_true(sg.all(func(e): return bool(e.market)), "only the market sells shotguns")
	var hp: Array = all.filter(func(e): return String(e.key) == "weapon/heavy_pistol")
	assert_eq(hp.size(), 1, "listed once though the fixer stocks it too")
	assert_false(bool(hp[0].market), "the fixer keeps selling it: no market badge")
	var chrome := Shop.entries(_camp(["cyberware/kerenzikov"])).filter(func(e): return String(e.kind) == "cyberware")
	assert_true(String(chrome[0].desc).contains("Installed at the Med Bay"))
	assert_true(String(chrome[0].desc).contains("Needs Neural Link"))


func test_search_counts_and_sorts_with_no_filters() -> void:
	var c := _camp(["weapon/shotgun@poor", "weapon/shotgun", "weapon/shotgun@excellent", "armor/flak"], 600)
	c.stash = {"weapon/heavy_pistol": 1}
	var all := Shop.entries(c)
	var f := MarketTab.new_state()
	for gone in ["market_only", "afford", "hide_owned"]:
		assert_false(f.has(gone), "no %s filter (owner)" % gone)
	assert_eq(Shop.filtered(all, f).size(), all.size(), "everything on sale is listed")
	assert_eq(all.filter(func(e): return bool(e.market)).size(), 4, "the four listings")
	assert_true(all.any(func(e): return String(e.key) == "weapon/heavy_pistol"), "what the crew owns stays listed")
	assert_true(all.any(func(e): return String(e.key) == "armor/flak"), "and what they can't afford")
	f.query = "shotgun"
	assert_eq(Shop.filtered(all, f).size(), 3)
	f.query = ""
	f.cat = "Armor"
	assert_true(Shop.filtered(all, f).all(func(e): return String(e.cat) == "Armor"))
	var n := Shop.counts(all, f)
	assert_eq(int(n.All), all.size(), "counts ignore the category picked")
	assert_eq(int(n.Firearms), all.filter(func(e): return String(e.cat) == "Firearms").size())
	var low := Shop.sorted(all, "low")
	for i in range(1, low.size()):
		assert_true(int(low[i - 1].cost) <= int(low[i].cost), "price ascending")
	var high := Shop.sorted(all, "high")
	for i in range(1, high.size()):
		assert_true(int(high[i - 1].cost) >= int(high[i].cost), "price descending")
	var typ := Shop.sorted(all, "type")
	for i in range(1, typ.size()):
		var a := Shop.CATEGORIES.find(String(typ[i - 1].cat))
		var b := Shop.CATEGORIES.find(String(typ[i].cat))
		assert_true(a < b or (a == b and int(typ[i - 1].cost) <= int(typ[i].cost)), "by category, then price")


func test_cart_helpers_and_market_stock_in_plain_words() -> void:
	var cart := {}
	Shop.cart_add(cart, "ammo/flashbang_ammo")
	Shop.cart_add(cart, "ammo/flashbang_ammo", 2)
	assert_eq(int(cart["ammo/flashbang_ammo"]), 3)
	Shop.cart_set(cart, "ammo/flashbang_ammo", 0)
	assert_true(cart.is_empty(), "0 removes the line")
	var c := _camp(["armor/flak", "weapon/assault_rifle"], 5000, 3)
	assert_eq(Shop.market_note(c), "Night Market here · 6 pieces in stock")
	assert_eq(Shop.badge(3), "3 IN STOCK")
	var flak: Dictionary = Shop.entries(c).filter(func(e): return String(e.key) == "armor/flak")[0]
	assert_eq(int(flak.stock), 3)
	assert_true(MarketTab.tooltip(flak).contains("3 in stock"))
	var fixer: Dictionary = Shop.entries(c).filter(func(e): return String(e.key) == "armor/kevlar")[0]
	assert_eq(int(fixer.stock), -1, "the fixer's staples never run out")
	c.market.stock = {"armor/flak": 0, "weapon/assault_rifle": 0}
	assert_eq(Shop.market_note(c), "Night Market here · sold out")
	assert_false(Shop.entries(c).any(func(e): return String(e.key) == "armor/flak"), "at 0 the item is gone")
	for e in Shop.entries(c):
		assert_false(String(MarketTab.tooltip(e)).to_lower().contains("days left"), "no days left anywhere")
	c.market = {}
	assert_false(Shop.market_up(c))
	assert_eq(Shop.market_note(c), "No Night Market is up")


func test_buying_takes_from_the_stock_and_never_more_than_it_has() -> void:
	var c := _camp(["weapon/assault_rifle", "armor/flak"], 10000, 2)
	var r := c.buy_cart({"weapon/assault_rifle": 3})
	assert_false(r.ok)
	assert_eq(String(r.reason), "stock", "only 2 in stock")
	assert_eq(int(r.stock), 2)
	assert_eq(c.eb, 10000, "nothing paid")
	assert_true(c.buy_cart({"weapon/assault_rifle": 1, "armor/kevlar": 5}).ok, "a staple has no stock limit")
	assert_eq(NightMarket.stock_of(c.market, "weapon/assault_rifle"), 1, "one bought, one left")
	assert_true(c.buy("weapon/assault_rifle"), "buy() takes the last")
	assert_eq(NightMarket.stock_of(c.market, "weapon/assault_rifle"), 0)
	assert_false(c.on_sale("weapon/assault_rifle"), "sold out: gone")
	assert_false(c.buy("weapon/assault_rifle"))
	assert_eq(String(c.buy_cart({"weapon/assault_rifle": 1}).reason), "off_sale")
	assert_eq(c.stored("weapon/assault_rifle"), 2)
