class_name Security
extends RefCounted
## Security doctrines (data/world/security.json): how a faction guards its own site.
## Pure lookups; Encounter reads a doctrine at setup and the numbers drive guards, patrols, radio
## and shouting range, Trauma Team cards and keycards. Who answers a call comes from the gig's
## Security Codes (SecurityCode, NC2045 p.7), not from the doctrine.

const CORP_SITES := ["corp_office", "corp_hq", "data_center", "clinic", "bank", "hotel"]
const CORP_SCENES := ["arcology", "corp_campus"]


## A doctrine with the defaults filled in, one level deep: a doctrine's block (budget, alarm,
## outer_patrols, ...) replaces only the keys it names.
static func doctrine(id: String) -> Dictionary:
	var all: Dictionary = RulesDB.world("security.json")["doctrines"]
	var out: Dictionary = (all["default"] as Dictionary).duplicate(true)
	var d: Dictionary = all.get(id, {})
	for k in d:
		if out.get(k) is Dictionary and d[k] is Dictionary:
			(out[k] as Dictionary).merge(d[k], true)
		else:
			out[k] = d[k]
	out["id"] = id if all.has(id) else "default"
	return out


static func ids() -> Array:
	return (RulesDB.world("security.json")["doctrines"] as Dictionary).keys()


## The doctrine a faction runs at a site: its own, except that faction-less private security
## guards corporate sites the corporate way.
static func for_site(faction: String, site: String, scene: String) -> Dictionary:
	var id := String(World.faction(faction).get("doctrine", "default"))
	if faction == World.DEFAULT_OPFOR and (site in CORP_SITES or scene in CORP_SCENES):
		id = "corp_standard"
	return doctrine(id)


## The guard roster (NPC tiers, strongest first) for a crew of `crew_size` at `security`:
## crew_size x (base + per_level x security) edgerunners' worth on CPR p399 costs (Mook 1,
## Lieutenant 2, Mini Boss 3), officers by level, the rest Mooks (at least min_mooks).
static func roster(d: Dictionary, crew_size: int, security: int) -> Array[String]:
	const COST := {"mook": 1, "lieutenant": 2, "mini_boss": 3}
	var b: Dictionary = d.budget
	var budget := int(round(crew_size * (float(b.base) + float(b.per_level) * security)))
	var out: Array[String] = []
	var lv := mini(security, 3)
	for k in range(lv, 0, -1):   # the highest level's officer list that applies
		if (d.officers as Dictionary).has(str(k)):
			for t in d.officers[str(k)]:
				out.append(String(t))
				budget -= int(COST.get(String(t), 1))
			break
	for i in maxi(int(b.get("min_mooks", 2)), budget):
		out.append("mook")
	return out


## How many outer patrol pairs a map of `area` squares gets.
static func patrol_pairs(d: Dictionary, area: int) -> int:
	var p: Dictionary = d.outer_patrols
	return clampi(int((area - int(p.area_start)) / int(p.area_per_pair)), 0, int(p.max_pairs))
