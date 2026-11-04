class_name Items
extends RefCounted
## Carried gear (data/rules/gear.json entries with a "kit" kind): what can sit in safehouse storage
## and go into a gig in a crew member's two kit slots. Keys are "<section>/<id>", e.g.
## "ammo/flashbang_ammo", "drugs/synthcoke", "gear/medscanner". Pure lookups and rules; Campaign
## keeps the storage, Encounter uses the items.

const SECTIONS := ["ammo", "drugs", "gear"]


static func def(key: String) -> Dictionary:
	if not key.contains("/"):
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
	var d := def(key)
	return String(d.get("kit_name", d.get("name", key)))


## The few letters that fit an action-bar button ("FLASH", "COKE").
static func short_name(key: String) -> String:
	return String(def(key).get("kit_short", display_name(key))).to_upper()


## List price of one (grenades are sold singly, p.344).
static func price(key: String) -> int:
	return int(def(key).get("cost", 0))


static func fx(key: String) -> Dictionary:
	return def(key).get("fx", {})


## Every item the market can stock: storage keys with a shop_rep, in data order.
static func all() -> Array[String]:
	var out: Array[String] = []
	var g: Dictionary = RulesDB.load_json("gear.json")
	for sec in SECTIONS:
		for id in g.get(sec, {}):
			if g[sec][id].has("kit") and g[sec][id].has("shop_rep"):
				out.append("%s/%s" % [sec, id])
	return out


## The kinds each kit slot accepts (gear.json kit_rules: slot 1 consumable, slot 2 either).
static func slot_kinds() -> Array:
	return RulesDB.load_json("gear.json")["kit_rules"]["slots"]


static func fits(slot: int, key: String) -> bool:
	return key == "" or (slot >= 0 and slot < slot_kinds().size() and kind(key) in (slot_kinds()[slot] as Array))
