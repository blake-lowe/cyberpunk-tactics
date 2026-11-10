class_name NightMarket
extends RefCounted
## The book's Night Market generator (CPR core p.337-339; data/rules/night_market.json). Pure
## functions over a market dictionary, which Campaign keeps and saves:
##   {"opened": day, "closes": day, "categories": [category ids],
##    "listings": [{"category", "row" (index in its column), "name", "keys": [storage keys on sale]}]}
## Two different categories of goods (1d6 twice, a repeat rerolled); per category 1d10 types of
## items, each a d100 row of its column (a repeat rerolled); an item with Quality Ratings is there
## in all of them (p338). Rows the game has no item for are listed with no keys.


static func data() -> Dictionary:
	return RulesDB.load_json("night_market.json")


static func category(id: String) -> Dictionary:
	for c in data().categories:
		if String(c.id) == id:
			return c
	return {}


## Roll a new market that opens on `day`.
static func roll(dice: Dice, day: int) -> Dictionary:
	var d := data()
	var cats: Array = d.categories
	var picked: Array[String] = []
	while picked.size() < int(d.categories_roll.times):   # p338: 1d6 twice, reroll a repeat
		var r := dice.d(6)
		var cat: Dictionary = cats.filter(func(c): return int(c.roll) == r)[0]
		if not String(cat.id) in picked:
			picked.append(String(cat.id))
	var listings: Array = []
	for cid in picked:
		var rows: Array = category(cid).listings
		var n := mini(dice.d(10), rows.size())   # p338: 1d10 types of items
		var seen := {}
		while seen.size() < n:
			var r100 := dice.d(100)   # d100, a repeat rerolled
			var i := 0
			while r100 > int(rows[i].d100[1]):
				i += 1
			if seen.has(i):
				continue
			seen[i] = true
			listings.append({"category": cid, "row": i, "name": String(rows[i].name), "keys": resolve(dice, rows[i])})
	_add_foundations(listings)
	return {"opened": day, "closes": day + int(d.house_rules.open_days), "categories": picked, "listings": listings}


## Skill Chips one listing offers (resolve): the market's chips, each for one Skill, chosen at purchase.
const CHIP_STOCK := 3


## What a listing puts on sale: its keys or filter, only what the game plays, every Quality Rating
## of a weapon (p338), `choose` of them at random for a "GM's choice" row.
static func resolve(dice: Dice, listing: Dictionary) -> Array[String]:
	var cand: Array[String] = []
	if listing.has("keys"):
		for k in listing["keys"]:
			if on_sale(String(k)):
				cand.append(String(k))
	elif listing.has("filter"):
		cand = matching(listing.filter)
	var chips := cand.filter(func(k): return Cyber.def(Items.base_id(k)).get("fx", {}).has("skill_chip"))
	while chips.size() > CHIP_STOCK:   # HOUSE-RULE: a dealer stocks a few Skill Chips, not one for every Skill
		var drop: String = chips[dice.d(chips.size()) - 1]
		chips.erase(drop)
		cand.erase(drop)
	if listing.has("choose") and cand.size() > int(listing.choose):
		var pick: Array[String] = []
		while pick.size() < int(listing.choose):
			var k: String = cand[dice.d(cand.size()) - 1]
			if not k in pick:
				pick.append(k)
		cand = pick
	var out: Array[String] = []
	for k in cand:
		if Items.section(k) == "weapon":
			for q in ["poor", "standard", "excellent"]:
				if Weapon.can_have_quality(Items.base_id(k), q):
					out.append(Items.weapon_key(Items.base_id(k), q))
		else:
			out.append(k)
	return out


## Whether the game can sell this key: weapons, armour and kit marked "sold" (their rules are
## played), cyberware whose effect the game plays (Cyber.modelled).
static func on_sale(key: String) -> bool:
	match Items.section(key):
		"weapon":
			return Items.is_weapon(key) and RulesDB.weapon(Items.base_id(key)).has("sold")
		"armor":
			return Items.is_armor(key) and RulesDB.armor(Items.base_id(key)).has("sold")
		"cyberware":   # a piece made for one thing is sold made for it (Cyber.choices: "cyberware/skill_chip@handgun")
			return Items.is_cyberware(key) and Cyber.modelled(Items.base_id(key)) and Cyber.valid_spec(key.get_slice("/", 1))
	return key in Items.all()


## Every key on sale that fits a listing's filter (night_market.json _doc), in data order.
static func matching(f: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var keys: Array[String] = []
	var costs := {}
	var cats := {}
	match String(f.kind):
		"weapon":
			var db: Dictionary = RulesDB.load_json("weapons.json")["weapons"]
			for id in db:
				keys.append(Items.weapon_key(id))
				costs[keys[-1]] = int(db[id].get("cost", 0))
				cats[keys[-1]] = String(db[id].get("category", "standard"))
		"armor":
			var db: Dictionary = RulesDB.load_json("armor.json")["armor"]
			for id in db:
				keys.append("armor/" + id)
				costs[keys[-1]] = int(db[id].get("cost", 0))
		"cyberware":
			var db: Dictionary = RulesDB.load_json("cyberware.json")["cyberware"]
			for id in db:
				var k := "cyberware/" + String(id)
				if f.has("option") and bool(f.option) != Cyber.is_option(String(id)):
					continue
				var specs: Array[String] = [k]
				if not Cyber.choices(String(id)).is_empty():   # one key per choice: a Skill Chip per Skill, a popup per weapon
					specs.assign(Cyber.choices(String(id)).map(func(ch): return k + "@" + ch))
				for sk in specs:
					keys.append(sk)
					costs[sk] = Cyber.price(sk.get_slice("/", 1), false)   # the piece's own price (a chip's by its Skill, p.360)
					cats[sk] = String(db[id].get("category", ""))
		"kit":
			for k in Items.all():
				if Items.section(k) == String(f.get("section", Items.section(k))):
					keys.append(k)
					costs[k] = Items.price(k)
	for k in keys:
		var cost := int(costs[k])
		if not on_sale(k):
			continue
		if f.has("category") and String(cats.get(k, "")) != String(f.category):
			continue
		if (f.has("cost") and cost != int(f.cost)) or (f.has("cost_max") and cost > int(f.cost_max)) or (f.has("cost_min") and cost < int(f.cost_min)):
			continue
		out.append(k)
	return out


## p338: a Cyberware Option on sale brings the Foundational Cyberware it needs (the whole chain:
## Pain Editor → Chipware Socket → Neural Link).
static func _add_foundations(listings: Array) -> void:
	var have := {}
	for l in listings:
		for k in l["keys"]:
			have[k] = true
	var extra: Array[String] = []
	for l in listings:
		for k in l["keys"]:
			if Items.section(String(k)) != "cyberware":
				continue
			var need := Cyber.needs(Items.base_id(String(k)))
			while need != "":
				var nk := "cyberware/" + need
				if not have.has(nk):
					have[nk] = true
					extra.append(nk)
				need = Cyber.needs(need)
	if not extra.is_empty():
		listings.append({"category": "cyberware", "name": "Foundational Cyberware", "keys": extra})


## Always on sale, market or not: every item the game plays costing up to Premium (100eb), since
## that much can be bought without a Fixer or Night Market (CPR core p.385; owner's ruling).
## Weapons at Standard quality, armour, kit items; in data order.
static func staples() -> Array[String]:
	var cap := int(data().staples.get("max_cost", 100))
	var out: Array[String] = []
	var ws: Dictionary = RulesDB.load_json("weapons.json")["weapons"]
	for id in ws:
		var k := "weapon/%s" % id
		if on_sale(k) and Items.price(k) <= cap:
			out.append(k)
	var ar: Dictionary = RulesDB.load_json("armor.json")["armor"]
	for id in ar:
		var k := "armor/%s" % id
		if on_sale(k) and Items.price(k) <= cap:
			out.append(k)
	for k in Items.all():
		if on_sale(k) and Items.price(k) <= cap:
			out.append(k)
	return out


## Every distinct key the market has on sale, in listing order.
static func keys_of(market: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for l in market.get("listings", []):
		for k in l.get("keys", []):
			if not String(k) in out:
				out.append(String(k))
	return out


## The categories' names ("Weapons and Armor + Cyberware").
static func title(market: Dictionary) -> String:
	return " + ".join(Array(market.get("categories", [])).map(func(c): return String(category(String(c)).get("name", c))))
