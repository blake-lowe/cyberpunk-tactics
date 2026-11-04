class_name RulesDB
extends RefCounted
## Loads and caches rules content from res://data/rules/*.json.

const DIR := "res://data/rules/"

static var _cache: Dictionary = {}


static func load_json(file: String) -> Dictionary:
	if not _cache.has(file):
		var text := FileAccess.get_file_as_string(DIR + file)
		var parsed: Variant = JSON.parse_string(text)
		assert(parsed is Dictionary, "Failed to parse " + file)
		_cache[file] = parsed
	return _cache[file]


## Generation content (not rules) lives in res://data/gen/.
static func gen(file: String) -> Dictionary:
	var key := "gen/" + file
	if not _cache.has(key):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/gen/" + file))
		assert(parsed is Dictionary, "Failed to parse " + file)
		_cache[key] = parsed
	return _cache[key]


## World content (Night City: factions, later locations and security doctrines) lives in
## res://data/world/.
static func world(file: String) -> Dictionary:
	var key := "world/" + file
	if not _cache.has(key):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/" + file))
		assert(parsed is Dictionary, "Failed to parse " + file)
		_cache[key] = parsed
	return _cache[key]


static func weapon(id: String) -> Dictionary:
	var w: Dictionary = load_json("weapons.json")["weapons"][id].duplicate()
	w["id"] = id
	return w


static func armor(id: String) -> Dictionary:
	var a: Dictionary = load_json("armor.json")["armor"][id].duplicate()
	a["id"] = id
	return a


static func cyberware(id: String) -> Dictionary:
	return load_json("cyberware.json")["cyberware"][id]


static func skill(id: String) -> Dictionary:
	return load_json("skills.json")["skills"][id]


static func skill_stat(id: String) -> String:
	return skill(id)["stat"]


static func crit_table(location: String) -> Dictionary:
	return load_json("critical_injuries.json")[location]


## DV for a single shot at `distance_m`, or -1 if out of range. Uses the autofire table if `autofire`.
static func range_dv(table_key: String, distance_m: float, autofire: bool = false) -> int:
	var db := load_json("weapons.json")
	var bands: Array = db["range_bands_m"]
	var row: Array = db["autofire_dv" if autofire else "range_dv"][table_key]
	var d := ceili(distance_m)
	for i in row.size():
		if d <= int(bands[i]):
			return -1 if row[i] == null else int(row[i])
	return -1
