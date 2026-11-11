class_name Shop
extends RefCounted
## The Fixer Network's NIGHT MARKET tab as a shop (MarketTab draws it): one list of everything for
## sale now (Campaign.market_stock: the Night Market's listings and the fixer's staples, CPR core
## p.337-339 and p.385), one entry per item and Quality Rating, with the shop's categories, search,
## sorts and the market's stock in plain words. Pure functions over plain dictionaries so they
## test headless; the cart is a Dictionary (storage key → how many) and Campaign.buy_cart buys it.

## The shop's categories, in TYPE sort order. The first six are always listed (owner's verdict);
## Gear (scanners and other carried utilities) and Netrunning (decks, Programs, deck Hardware) only
## when something is on sale in it.
const CATEGORIES := ["Firearms", "Melee", "Armor", "Cyberware", "Grenades", "Drugs", "Gear", "Netrunning"]
const ALWAYS_LISTED := 6
const ALL := "All"
## Sorts: by type (category, then price), price ascending, price descending.
const SORTS := ["type", "low", "high"]
const QUALITY_ORDER := {"poor": 0, "standard": 1, "excellent": 2}


## The shop category of a storage key: weapons split into Firearms and Melee (weapons.json
## "melee"), armour, cyberware, drugs, thrown kit (gear.json kit_use "grenade"), anything else Gear.
static func category_of(key: String) -> String:
	if Deck.is_netrun_key(key):
		return "Netrunning"
	match Items.section(key):
		"weapon":
			return "Melee" if bool(RulesDB.weapon(Items.base_id(key)).get("melee", false)) else "Firearms"
		"armor":
			return "Armor"
		"cyberware":
			return "Cyberware"
		"drugs":
			return "Drugs"
	return "Grenades" if Items.use(key) == "grenade" else "Gear"


## Everything for sale now, one entry per key: Campaign.market_stock's fields plus cat (category_of),
## tier (Price Category, p.385), quality, market (only the Night Market sells it: gone when its
## stock runs out) and desc (the full description: what it does; cyberware's Humanity Loss, what it needs
## and where it's installed).
static func entries(camp: Campaign) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for it in camp.market_stock():
		var e: Dictionary = it.duplicate()
		var key := String(e.key)
		e.cat = category_of(key)
		e.tier = Items.price_tier(int(e.cost))
		var tags := Items.tags(key)
		e.quality = tags[0] if Items.section(key) == "weapon" and not tags.is_empty() else "standard"   # p.342
		e.market = not NightMarket.is_staple(key)
		e.desc = describe(e)
		out.append(e)
	return out


## The full description of a stock entry: its info line, and for cyberware its Humanity Loss, the
## foundation it needs and that the Med Bay installs it (p.338: free when bought at a Night Market).
static func describe(it: Dictionary) -> String:
	var desc := String(it.get("info", ""))
	if String(it.get("kind", "")) == "cyberware":
		var id := Items.base_id(String(it.key))
		var need := Cyber.needs(id)
		desc += (" " if desc != "" else "") + "Humanity Loss %s." % String(Cyber.def(id).get("hl_dice", ""))
		if Cyber.def(id).get("paired", false):
			desc += " Paired: one in each %s, both bought." % ("leg" if String(Cyber.def(id).host) == "leg" else "eye")
		if need != "":
			desc += " Needs %s." % Cyber.display(need)
		desc += " Installed at the Med Bay."
	elif Deck.is_loadable(String(it.get("key", ""))):   # a Program or Hardware takes deck slots (p.196, p.204, p.208)
		var n := Deck.slots_of(String(it.key))
		desc += " Takes %d deck slot%s; loaded at the Armory." % [n, "" if n == 1 else "s"]
	elif Deck.is_deck_key(String(it.get("key", ""))):
		desc += " For Netrunners: carry it and load Programs at the Armory."
	return desc


## What the shop shows: {cat: "All" or a category, query} (owner: no filters, the market just
## has a reasonable number of items).
static func matches(e: Dictionary, f: Dictionary, ignore_cat := false) -> bool:
	var cat := String(f.get("cat", ALL))
	if not ignore_cat and cat != ALL and String(e.cat) != cat:
		return false
	var q := String(f.get("query", "")).strip_edges().to_lower()
	if q != "":
		var hay := " ".join([String(e.name), String(e.desc), String(e.cat), String(e.tier)]).to_lower()
		for word in q.split(" ", false):
			if not hay.contains(word):
				return false
	return true


static func filtered(list: Array[Dictionary], f: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in list:
		if matches(e, f):
			out.append(e)
	return out


## Category → how many entries the search shows in it (whatever category is picked), plus "All".
static func counts(list: Array[Dictionary], f: Dictionary) -> Dictionary:
	var out := {ALL: 0}
	for c in CATEGORIES:
		out[c] = 0
	for e in list:
		if matches(e, f, true):
			out[String(e.cat)] = int(out.get(String(e.cat), 0)) + 1
			out[ALL] = int(out[ALL]) + 1
	return out


## The categories the rail lists: the six always, Gear when anything is on sale in it.
static func listed_categories(list: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for i in CATEGORIES.size():
		var c: String = CATEGORIES[i]
		if i < ALWAYS_LISTED or list.any(func(e): return String(e.cat) == c):
			out.append(c)
	return out


## Sorted copy: "type" (category, then price, name, quality), "low" / "high" (price, then type).
static func sorted(list: Array[Dictionary], mode: String) -> Array[Dictionary]:
	var out := list.duplicate()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var pa := int(a.cost)
		var pb := int(b.cost)
		if mode != "type" and pa != pb:
			return pa < pb if mode == "low" else pa > pb
		var ca := CATEGORIES.find(String(a.cat))
		var cb := CATEGORIES.find(String(b.cat))
		if ca != cb:
			return ca < cb
		if pa != pb:
			return pa < pb
		if String(a.name) != String(b.name):
			return String(a.name) < String(b.name)
		return int(QUALITY_ORDER.get(String(a.quality), 1)) < int(QUALITY_ORDER.get(String(b.quality), 1)))
	return out


# --- The cart (storage key → how many) ---------------------------------------------------

static func cart_add(cart: Dictionary, key: String, n := 1) -> void:
	cart_set(cart, key, int(cart.get(key, 0)) + n)


## Set a line's quantity; 0 or fewer removes it.
static func cart_set(cart: Dictionary, key: String, n: int) -> void:
	if n <= 0:
		cart.erase(key)
	else:
		cart[key] = n


# --- The market's stock, in plain words (owner: stock instead of days left) ----------------

## Whether a Night Market is up.
static func market_up(camp: Campaign) -> bool:
	return not (camp.market.get("categories", []) as Array).is_empty()


## "Night Market here · 23 pieces in stock" (or "· sold out"); "No Night Market is up".
static func market_note(camp: Campaign) -> String:
	if not market_up(camp):
		return "No Night Market is up"
	var n := NightMarket.stock_left(camp.market)
	return "Night Market here · %s" % ("sold out" if n == 0 else "%d piece%s in stock" % [n, "" if n == 1 else "s"])


## A market item's badge: "3 IN STOCK".
static func badge(stock: int) -> String:
	return "%d IN STOCK" % stock
