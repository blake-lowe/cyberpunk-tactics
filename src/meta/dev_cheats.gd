class_name DevCheats
extends RefCounted
## DEV ONLY: the safehouse dev menu's cheats (DevMenu, developer mode: GameSettings.dev_mode). Every
## change goes through here so it is logged ("[DEV] ...") and counted on the campaign
## (Campaign.dev_cheats, saved; the save slot listing says "dev cheats"), like a custom gig is
## marked dev (Campaign.dev_gigs).
##
## The equipment catalogue is everything safehouse storage can hold (Items.is_stored), sold or not:
## weapons (at each quality they can have), armour, kit (ammo and grenades, drugs, gear), every
## piece of cyberware (unmodelled ones too, and each choice of a piece made for one thing: a Skill
## Chip's Skill, a popup's weapon), cyberdecks, Programs and deck Hardware. Keys are the ones the Night
## Market puts into storage (Items).

## Equipment filter tabs: [id, label]; an entry's `cat` is one of these ids (but "all").
const CATS := [["all", "All"], ["weapon", "Weapons"], ["armor", "Armor"], ["ammo", "Ammo & grenades"], ["drugs", "Drugs"],
	["gear", "Gear"], ["cyberware", "Cyberware"], ["deck", "Cyberdecks"], ["programs", "Programs"], ["hardware", "Hardware"]]
const QUALITIES := [["poor", "Poor"], ["standard", "Standard"], ["excellent", "Excellent"]]

static var _catalog: Array[Dictionary] = []


## Every item: {key (without a variant), name, cat, variants: [[suffix, label], ...] ([] for none),
## default (the suffix picked first), note ("" or "unmodelled" / "not sold")}. The storage key of a
## pick is key + suffix. Built once (the data doesn't change in a run).
static func catalog() -> Array[Dictionary]:
	if not _catalog.is_empty():
		return _catalog
	var out: Array[Dictionary] = []
	var ws: Dictionary = RulesDB.load_json("weapons.json")["weapons"]
	for id in ws:
		var wid := String(id)
		var vs: Array = []
		for q in QUALITIES:
			if q[0] == "standard" or Weapon.can_have_quality(wid, String(q[0])):
				vs.append(["" if q[0] == "standard" else "@" + String(q[0]), String(q[1])])
		out.append(_entry("weapon/" + wid, String((ws[id] as Dictionary).get("name", wid)), "weapon",
			vs if vs.size() > 1 else [], "", "" if (ws[id] as Dictionary).has("sold") else "not sold"))
	var ar: Dictionary = RulesDB.load_json("armor.json")["armor"]
	for id in ar:
		out.append(_entry("armor/" + String(id), String((ar[id] as Dictionary).get("name", id)), "armor"))
	var g: Dictionary = RulesDB.load_json("gear.json")
	for sec in Items.SECTIONS:
		for id in g.get(sec, {}):
			var k := "%s/%s" % [sec, id]
			if Items.is_item(k):
				out.append(_entry(k, Items.display_name(k), String(sec), [], "", "" if (g[sec][id] as Dictionary).has("sold") else "not sold"))
	for id in Cyber.db():
		var cid := String(id)
		var vs: Array = []
		for ch in Cyber.choices(cid):
			vs.append(["@" + ch, Cyber.choice_name(cid, ch)])
		out.append(_entry("cyberware/" + cid, String(Cyber.def(cid).get("name", cid)), "cyberware", vs,
			String(vs[0][0]) if not vs.is_empty() else "", "" if Cyber.modelled(cid) else "unmodelled"))
	for id in g.get("gear", {}):
		var k := "gear/" + String(id)
		if Deck.is_deck_key(k):
			out.append(_entry(k, String(Deck.entry(k).get("name", id)), "deck", [], "", "" if Deck.sold(k) else "not sold"))
	for sec in ["programs", "hardware"]:
		for id in g.get(sec, {}):
			var k := "%s/%s" % [sec, id]
			if Deck.is_netrun_key(k):
				out.append(_entry(k, String(Deck.entry(k).get("name", id)), sec, [], "", "" if Deck.sold(k) else "not sold"))
	_catalog = out.filter(func(e: Dictionary) -> bool: return Items.is_stored(key_for(e, String(e.default))))
	return _catalog


static func _entry(key: String, name: String, cat: String, variants: Array = [], default := "", note := "") -> Dictionary:
	return {"key": key, "name": name, "cat": cat, "variants": variants, "default": default, "note": note}


## The storage key of `e` made as `suffix` (one of its variants' suffixes, "" for none).
static func key_for(e: Dictionary, suffix: String) -> String:
	return String(e.key) + suffix


## The catalogue in tab `cat` ("all" for every tab) whose name or key holds `query` (any case).
static func filter(cat: String, query: String) -> Array[Dictionary]:
	var q := query.strip_edges().to_lower()
	var out: Array[Dictionary] = []
	for e in catalog():
		if cat != "all" and String(e.cat) != cat:
			continue
		if q != "" and not (String(e.name).to_lower().contains(q) or String(e.key).to_lower().contains(q)
				or (e.variants as Array).any(func(v): return String(v[1]).to_lower().contains(q))):
			continue
		out.append(e)
	return out


static func _mark(c: Campaign, line: String) -> void:
	c.dev_cheats += 1
	c.say("[DEV] " + line)


## Add `n` eb (negative takes some away; never below 0).
static func add_eb(c: Campaign, n: int) -> void:
	var before := c.eb
	c.eb = maxi(0, c.eb + n)
	_mark(c, "%s%s eb." % ["+" if c.eb >= before else "-", Campaign.eb_text(absi(c.eb - before))])


static func set_eb(c: Campaign, n: int) -> void:
	c.eb = maxi(0, n)
	_mark(c, "eb set to %s." % Campaign.eb_text(c.eb))


## Put `n` of `key` into safehouse storage. False (nothing changed) if storage can't hold it.
static func give(c: Campaign, key: String, n := 1) -> bool:
	if n <= 0 or not Items.is_stored(key):
		return false
	c._put(key, n)
	_mark(c, "Added %s%s to storage." % [Items.display_name(key), " ×%d" % n if n > 1 else ""])
	return true


## Everyone alive back to full HP, Critical Injuries gone.
static func heal_all(c: Campaign) -> void:
	for m in c.alive_crew():
		m.injuries.clear()
		m.hp = m.max_hp()
	_mark(c, "Crew healed.")


## Everyone's Humanity back to their maximum (chrome still lowers the maximum).
static func restore_humanity(c: Campaign) -> void:
	for m in c.alive_crew():
		if m.tracks_humanity:
			m.humanity = m.max_humanity
	_mark(c, "Humanity restored.")


## Jump to day `d` (never before day 1); a Night Market that has closed by then rolls anew.
static func set_day(c: Campaign, d: int) -> void:
	c.day = maxi(1, d)
	c.update_market()
	_mark(c, "Day set to %d." % c.day)


static func add_reputation(c: Campaign, n: int) -> void:
	for m in c.alive_crew():
		m.reputation = clampi(m.reputation + n, 0, 10)   # Reputation Levels 0-10, CPR core p.193 # RULES-UNVERIFIED (the top level)
	_mark(c, "Crew Reputation %+d." % n)


static func give_ip(c: Campaign, n: int) -> void:
	for m in c.alive_crew():
		m.ip = maxi(0, m.ip + n)
	_mark(c, "Crew +%d IP." % n)
