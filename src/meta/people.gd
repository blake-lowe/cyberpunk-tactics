class_name People
extends RefCounted
## People of Night City (SPM p.50-51; data/gen/people.json): what kind of person a client, an
## assassination mark or a rescue captive is. A d10 picks the zone (Corporate 1-3, Moderate 4-6,
## Street 7-9, Outskirts 10), then the zone's die (1d10, or 2d10 on the Street) picks the type.
## Every roll draws from the passed Dice.
##
##   People.roll(dice)               -> {id, label, kind, zone, zone_name, cite}, zone rolled
##   People.roll(dice, "corporate")  -> a type from that zone (zones: People.zones())
##   People.roll_zone(dice)          -> a zone id


static func data() -> Dictionary:
	return RulesDB.gen("people.json")


## Zone ids in data order: corporate, moderate, street, outskirts.
static func zones() -> Array[String]:
	var out: Array[String] = []
	for z in data().zones:
		out.append(String(z))
	return out


## The types of person in `zone` (people.json zones.<zone>.types), [] for an unknown zone.
static func types(zone: String) -> Array:
	return (data().zones.get(zone, {}) as Dictionary).get("types", [])


## A zone by the book's d10 (SPM p.50).
static func roll_zone(dice: Dice) -> String:
	var r := dice.d(10)
	for z in data().zones:
		var span: Array = data().zones[z].zone_roll
		if r >= int(span[0]) and r <= int(span[1]):
			return String(z)
	return "street"


## A type of person from `zone` ("" or unknown: the zone is rolled first), as the type's entry
## plus `zone`, `zone_name` and `cite`.
static func roll(dice: Dice, zone := "") -> Dictionary:
	if not data().zones.has(zone):
		zone = roll_zone(dice)
	var z: Dictionary = data().zones[zone]
	var r := dice.roll(2, 10) if String(z.die) == "2d10" else dice.d(10)
	for t in z.types:
		if r >= int(t.roll[0]) and r <= int(t.roll[1]):
			var out: Dictionary = (t as Dictionary).duplicate()
			out.merge({"zone": zone, "zone_name": String(z.name), "cite": String(z.cite)})
			return out
	return {}
