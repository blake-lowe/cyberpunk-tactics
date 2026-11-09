class_name CorpseLoot
extends RefCounted
## Searching bodies (Cyberpunk RED: Single Player Mode, Corpse Loot, SPM p.65-70): the book's three
## d100 tables of what's in someone's pockets beyond their stat block (Streetrat, Edgerunner,
## Corporate; data/rules/corpse_loot.json). Rules only: Encounter.search_body spends the Action and
## applies what plays at once (a keycard opens doors, a NET login code waits for the Netrunner);
## Campaign.resolve takes the rest home (items to storage, eb to the wallet, leads to the lead list)
## when whoever found it got out.
##
## HOUSE-RULE (owner: "not every enemy should drop loot, so probably lower rates than the book
## suggests"): the book gives every body a row. Here a body has anything worth taking only on
## 1d6 at or under HAS_LOOT for its tier (a Mook 1 in 3, a Lieutenant 1 in 2, a Mini Boss, a Boss
## or an assassination's mark 2 in 3); only then is the table rolled. A row the game can't play
## yet (`unmodelled`: junk, flavour, gear we don't model) is re-rolled, so a find is always
## something. The stat block's own gear stays on the body (the owner removed salvage).

const DATA := "corpse_loot.json"
## 1d6 at or under this: the body has something (HOUSE-RULE, see above).
const HAS_LOOT := {"mook": 2, "lieutenant": 3, "mini_boss": 4, "boss": 4}
const DIE := 6
## HOUSE-RULE: a valuable (a row with `fence`: gems, wine, programs, a painting) goes to a fence
## for this share of what the book says it's worth; cash and chips count in full.
const FENCE := 0.5
const TABLES := ["streetrat", "edgerunner", "corporate"]


static func tables() -> Dictionary:
	return RulesDB.load_json(DATA)["tables"]


## The rows of `table` the game plays (no `unmodelled`).
static func modelled(table: String) -> Array:
	return (tables()[table].rows as Array).filter(func(r): return not (r as Dictionary).has("unmodelled"))


## Which table a body rolls on (HOUSE-RULE, our mapping): by the faction it stood with (World.kind).
##   corp and service (corp security, contractors, Trauma Team): Corporate;
##   police (NCPD, MaxTac): Edgerunner;
##   gangs and criminal outfits: Streetrat for Mooks, Edgerunner for Lieutenants and up;
##   anyone else (armed locals, generic security): the same split by tier.
## An assassination's mark rolls Corporate if their people are a corp, else Edgerunner.
static func table_for(e: Encounter, u: Dictionary) -> String:
	var kind := World.kind(e.faction_of(u))
	if u.get("vip", false):
		return "corporate" if kind == "corp" else "edgerunner"
	match kind:
		"corp", "service":
			return "corporate"
		"police":
			return "edgerunner"
	return "streetrat" if String(u.c.role) in ["", "mook"] else "edgerunner"


## The 1d6 a body needs to have anything (HAS_LOOT by tier; a mark counts as a Mini Boss).
static func has_loot_target(u: Dictionary) -> int:
	if u.get("vip", false):
		return int(HAS_LOOT.mini_boss)
	return int(HAS_LOOT.get(String(u.c.role), HAS_LOOT.mook))


## Search `body` for `by` (both units). Returns the find: {body, by, by_name, from, table, roll,
## label, kind, ...}: kind "nothing" (empty pockets), "eb" {eb}, "item" {items: {key: n}}, "lead"
## {hook}, "keycard" {zone}, "net_code". Rolls the dice; marks the body searched.
static func search(e: Encounter, by: Dictionary, body: Dictionary) -> Dictionary:
	body["searched"] = true
	var find := {"body": int(body.id), "by": int(by.id), "by_name": by.c.display_name, "from": body.c.display_name,
		"kind": "nothing", "label": "nothing worth taking", "table": table_for(e, body), "roll": 0}
	if e.dice.d(DIE) > has_loot_target(body):
		return find
	var rows: Array = tables()[find.table].rows
	var row: Dictionary = {}
	for i in 1000:   # re-roll the unmodelled rows (every table has modelled ones; the cap is a guard)
		var r := e.dice.d(100)
		row = rows[r - 1]
		if not row.has("unmodelled"):
			break
	if row.has("unmodelled"):
		return find
	find.roll = int(row.roll)
	find.label = String(row.label)
	find.kind = String(row.kind)
	match find.kind:
		"eb":
			var v := amount(e.dice, row.eb)
			find["eb"] = int(floor(v * FENCE)) if bool(row.get("fence", false)) else v
			find["fence"] = bool(row.get("fence", false))
		"item":
			var items := {}
			for k in row.items:
				items[String(k)] = maxi(1, amount(e.dice, row.items[k]))
			find["items"] = items
		"lead":
			find["hook"] = String(row.hook)
		"keycard":
			find["zone"] = String(row.zone)
	return find


## A count or eb value from the data: a number, "NdS" or "NdSxM" (rolled).
static func amount(dice: Dice, v: Variant) -> int:
	if v is float or v is int:
		return int(v)
	var s := String(v)
	var mult := 1
	if s.contains("x"):
		mult = int(s.get_slice("x", 1))
		s = s.get_slice("x", 0)
	if s.contains("d"):
		return dice.roll(int(s.get_slice("d", 0)), int(s.get_slice("d", 1))) * mult
	return int(s) * mult


## A find in a few words for the log and the debrief: "credstick · 100eb", "gemstone pouch · 250eb
## fenced", "bottle of Synthcoke: Synthcoke x3", "heist plans chip (a lead)". `lead_tag`: false
## where a LEAD chip already says so (the debrief).
static func describe(f: Dictionary, lead_tag := true) -> String:
	match String(f.get("kind", "")):
		"eb":
			return "%s · %deb%s" % [String(f.label), int(f.eb), " fenced" if bool(f.get("fence", false)) else ""]
		"item":
			var parts: Array[String] = []
			for k in f.get("items", {}):
				var n := int(f.items[k])
				parts.append(Items.display_name(String(k)) + (" x%d" % n if n > 1 else ""))
			return "%s: %s" % [String(f.label), ", ".join(parts)]
		"lead":
			return "%s (a lead)" % String(f.label) if lead_tag else String(f.label)
		"keycard":
			return "%s (opens %s)" % [String(f.label), "every lock here" if String(f.get("zone", "")) == "high" else "the outer doors"]
		"net_code":
			return "%s (opens one Password on this NET)" % String(f.label)
	return String(f.get("label", ""))


## The finds that go home (Campaign.resolve): those whose finder came back. A gig that ends with
## the whole crew down ("lost") keeps nothing; a withdrawal keeps what those who got out carry
## (Encounter.withdraw leaves the rest dead). Keycards and login codes were used up on site.
static func kept(e: Encounter) -> Array:
	if e.state == "lost":
		return []
	return e.loot.filter(func(f): return String(f.kind) in ["eb", "item", "lead"] and not e.units[int(f.by)].c.dead)
