class_name Items
extends RefCounted
## Safehouse storage keys and carried gear. Pure lookups and rules; Campaign keeps the storage
## (Campaign.stash: key → how many), Encounter uses the kit items.
##
## Kit items (data/rules/gear.json entries with a "kit" kind) go into a gig in a crew member's two
## kit slots: "<section>/<id>", e.g. "ammo/flashbang_ammo", "drugs/synthcoke", "gear/medscanner".
## Weapons: "weapon/<id>" (Standard Quality) or "weapon/<id>@poor" / "@excellent" (p.342).
## Armour: "armor/<id>", plus "@upgraded" for a piece a Tech has upgraded (+1 SP, p148) and
## "@sp<N>" for a piece put away ablated to N SP (it stays that way until worn and repaired).
## Cyberware: "cyberware/<id>", bought like any other gear and kept in storage until the Med Bay's
## ripperdoc installs it (then it's part of that crew member: removable, never moved to anyone else).

const SECTIONS := ["ammo", "drugs", "gear"]


static func def(key: String) -> Dictionary:
	if not key.contains("/") or section(key) in ["weapon", "armor", "cyberware"]:
		return {}
	return RulesDB.gear(key.get_slice("/", 0), key.get_slice("/", 1))


static func is_item(key: String) -> bool:
	return not String(def(key).get("kit", "")).is_empty()


## "consumable" or "utility".
static func kind(key: String) -> String:
	return String(def(key).get("kit", ""))


## How it's used in a gig: "grenade" (thrown like a frag), "dose" (an Action, on yourself),
## "carried" (works while it's on you).
static func use(key: String) -> String:
	return String(def(key).get("kit_use", "carried"))


static func display_name(key: String) -> String:
	match section(key):
		"weapon":
			return make_weapon(key).display_name() if is_stored(key) else key
		"armor":
			if not is_stored(key):
				return key
			var a := make_armor(key)
			return a.name + (" +1" if a.upgraded else "") + (" (SP %d/%d)" % [a.sp, a.max_sp] if a.sp < a.max_sp else "")
		"cyberware":
			return String(RulesDB.cyberware(base_id(key)).get("name", key)) if is_cyberware(key) else key
	var d := def(key)
	return String(d.get("kit_name", d.get("name", key)))


## The few letters that fit an action-bar button ("FLASH", "COKE").
static func short_name(key: String) -> String:
	return String(def(key).get("kit_short", display_name(key))).to_upper()


## List price of one (grenades are sold singly, p.344; a weapon at its quality, p.342; cyberware
## includes the installation, p110).
static func price(key: String) -> int:
	match section(key):
		"weapon":
			return make_weapon(key).cost() if is_stored(key) else 0
		"armor":
			return int(RulesDB.armor(base_id(key)).get("cost", 0)) if is_stored(key) else 0
		"cyberware":
			return int(RulesDB.cyberware(base_id(key)).get("cost", 0)) if is_cyberware(key) else 0
	return int(def(key).get("cost", 0))


static func fx(key: String) -> Dictionary:
	return def(key).get("fx", {})


## Every kit item a market may sell: storage keys marked "sold" (the game plays them), in data order.
static func all() -> Array[String]:
	var out: Array[String] = []
	var g: Dictionary = RulesDB.load_json("gear.json")
	for sec in SECTIONS:
		for id in g.get(sec, {}):
			if g[sec][id].has("kit") and g[sec][id].has("sold"):
				out.append("%s/%s" % [sec, id])
	return out


## The kinds each kit slot accepts (gear.json kit_rules: slot 1 consumable, slot 2 either).
static func slot_kinds() -> Array:
	return RulesDB.load_json("gear.json")["kit_rules"]["slots"]


static func fits(slot: int, key: String) -> bool:
	return key == "" or (slot >= 0 and slot < slot_kinds().size() and kind(key) in (slot_kinds()[slot] as Array))


# --- Storage keys beyond kit -------------------------------------------------------------

## "weapon", "armor", "cyberware" or a gear.json section.
static func section(key: String) -> String:
	return key.get_slice("/", 0) if key.contains("/") else ""


## The data id under a key: "weapon/heavy_pistol@poor" → "heavy_pistol".
static func base_id(key: String) -> String:
	return key.get_slice("/", 1).get_slice("@", 0)


## The "@" tags after the id: "armor/kevlar@upgraded@sp4" → ["upgraded", "sp4"].
static func tags(key: String) -> PackedStringArray:
	var parts := key.get_slice("/", 1).split("@")
	parts.remove_at(0)
	return parts


static func is_weapon(key: String) -> bool:
	return section(key) == "weapon" and (RulesDB.load_json("weapons.json")["weapons"] as Dictionary).has(base_id(key))


static func is_armor(key: String) -> bool:
	return section(key) == "armor" and (RulesDB.load_json("armor.json")["armor"] as Dictionary).has(base_id(key))


static func is_cyberware(key: String) -> bool:
	return section(key) == "cyberware" and (RulesDB.load_json("cyberware.json")["cyberware"] as Dictionary).has(base_id(key))


## Anything safehouse storage can hold: a kit item, a weapon, an armour piece or a piece of
## cyberware waiting to be installed.
static func is_stored(key: String) -> bool:
	return is_item(key) or is_weapon(key) or is_armor(key) or (is_cyberware(key) and tags(key).is_empty())


## The book's Price Categories (CPR core p.385), cheapest first: [name, eb]. Super Luxury is
## 10,000eb and up.
const PRICE_TIERS := [["Cheap", 10], ["Everyday", 20], ["Costly", 50], ["Premium", 100], ["Expensive", 500],
	["Very Expensive", 1000], ["Luxury", 5000], ["Super Luxury", 10000]]


## The Price Category a price falls in (p.385): the dearest category it reaches.
static func price_tier(eb: int) -> String:
	var out := String(PRICE_TIERS[0][0])
	for t in PRICE_TIERS:
		if eb >= int(t[1]):
			out = String(t[0])
	return out


## What a kit slot is called (gear.json kit_rules: slot 1 "Consumable", slot 2 "Utility").
static func slot_name(slot: int) -> String:
	var kinds := slot_kinds()
	return String((kinds[slot] as Array)[0]).capitalize() if slot >= 0 and slot < kinds.size() else ""


static func weapon_key(weapon_id: String, quality := "standard") -> String:
	return "weapon/" + weapon_id + ("" if quality == "standard" else "@" + quality)


## The storage key of a carried weapon (its quality kept; ammo and jams don't keep in storage).
static func key_of_weapon(w: Weapon) -> String:
	return weapon_key(w.id(), w.quality)


## The storage key of a worn armour piece: an upgrade and any ablation go with it.
static func key_of_armor(a: ArmorPiece) -> String:
	return "armor/" + a.id + ("@upgraded" if a.upgraded else "") + ("@sp%d" % a.sp if a.sp < a.max_sp else "")


static func make_weapon(key: String) -> Weapon:
	var t := tags(key)
	return Weapon.from_id(base_id(key), t[0] if not t.is_empty() else "standard")


static func make_armor(key: String) -> ArmorPiece:
	var a := ArmorPiece.from_id(base_id(key))
	for t in tags(key):
		if t == "upgraded":
			a.upgraded = true
			a.max_sp += 1   # p148: one +1 SP upgrade per item
			a.sp = a.max_sp
	for t in tags(key):
		if t.begins_with("sp"):
			a.sp = clampi(int(t.substr(2)), 0, a.max_sp)
	return a
