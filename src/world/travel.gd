class_name Travel
extends RefCounted
## Getting across Night City (NC2045 p.18-20): the time to cross a district depends on its
## Security Code, as the city map's travel band (city.json map.districts.<id>.band: high >= 6,
## mid 4-5, low <= 3). A drive from district A to district B crosses every district on the way,
## A and B included, so the time is the sum of their per-district times along the quickest chain
## of neighbours (map.districts.<id>.neighbours: a shared border or a bridge). Pure lookups.

## Average driving time per district, minutes, by band. NC2045 p.18: 15 (code 6+), 20 (4-5), 30 (3-).
const DRIVE_MINUTES := {"high": 15, "mid": 20, "low": 30}


static func _map_districts() -> Dictionary:
	return (RulesDB.world("city.json").get("map", {}) as Dictionary).get("districts", {})


## The district's travel band ("high", "mid", "low"; "" if it isn't on the map).
static func band(did: String) -> String:
	return String((_map_districts().get(did, {}) as Dictionary).get("band", ""))


## Minutes to drive across district `did` (-1 if it isn't on the map).
static func district_minutes(did: String) -> int:
	return int(DRIVE_MINUTES.get(band(did), -1))


## The quickest chain of districts from `from` to `to`, both included ([from] when they're the
## same; [] if either is off the map or there's no way through). Ties go to the data's order.
static func route(from: String, to: String) -> Array[String]:
	var out: Array[String] = []
	var ds := _map_districts()
	if not ds.has(from) or not ds.has(to):
		return out
	var best := {from: district_minutes(from)}
	var prev := {}
	var open: Array[String] = [from]
	var done := {}
	while not open.is_empty():
		var k := 0
		for i in open.size():
			if int(best[open[i]]) < int(best[open[k]]):
				k = i
		var cur: String = open[k]
		open.remove_at(k)
		if done.has(cur):
			continue
		done[cur] = true
		if cur == to:
			break
		for n in World.neighbours(cur):
			var nid := String(n)
			if not ds.has(nid) or done.has(nid):
				continue
			var t := int(best[cur]) + district_minutes(nid)
			if not best.has(nid) or t < int(best[nid]):
				best[nid] = t
				prev[nid] = cur
				open.append(nid)
	if not done.has(to):
		return out
	var at := to
	while at != from:
		out.push_front(at)
		at = String(prev[at])
	out.push_front(from)
	return out


## Minutes to drive from district `from` to district `to` (the sum along route; -1 if there's no
## route, e.g. a gig with no district).
static func drive_minutes(from: String, to: String) -> int:
	var r := route(from, to)
	if r.is_empty():
		return -1
	var t := 0
	for d in r:
		t += district_minutes(d)
	return t


## "~35 MIN DRIVE", "~1 HR 15 MIN DRIVE" ("" for no time).
static func label(minutes: int, what := "DRIVE") -> String:
	if minutes < 0:
		return ""
	var h := minutes / 60
	var m := minutes % 60
	var t := "%d MIN" % m if h == 0 else ("%d HR" % h if m == 0 else "%d HR %d MIN" % [h, m])
	return ("~%s %s" % [t, what]).strip_edges()
