class_name AccessPoints
extends RefCounted
## Where the crew can jack in (CPR core p.198: within 6 m of an access point, no wall between), for
## the view's way-finding: port icons over every access point the crew knows of (seen, or found by
## a Netrunner's Scan: Encounter.scan_access_points, CPR core p.199), and the data lines a
## Netrunner's idle turn draws to each one their Scans found. Pure lookups on the Encounter, so they
## are testable headless. (The old passive "sense by Interface" range is gone: the book makes
## finding access points the Scanner ability, a Meat Action.)


## Every NET access point on the map: [{device, cell: Vector3i, structure, index}].
static func all(e: Encounter) -> Array:
	var out := []
	for sid in e.m.architectures:
		var a: NetArchitecture = e.m.architectures[sid]
		for i in a.access_points.size():
			var d: Dictionary = e.m.devices[int(a.access_points[i].device)]
			out.append({"device": int(d.id), "cell": Vector3i(d.pos.x, d.pos.y, d.floor), "structure": int(sid), "index": i})
	return out


## Access points the crew knows of: seen, or found by a Scan (all of them with the fog off).
static func seen(e: Encounter, fog_on := true) -> Array:
	return all(e).filter(func(p): return not fog_on or e.vision.explored.has(p.cell) or e.scanned.has(p.cell))


## Access points a Scan found, for a Netrunner's data lines: the ones within jack-in reach of a walk
## from here matter most, so nearest first, each with `dist_m` (as the crow flies). Nothing for a
## non-Netrunner or a runner already jacked in.
static func scanned_for(e: Encounter, u: Dictionary) -> Array:
	var out := []
	if NetRun.interface_rank(u.c) <= 0 or e.runs.has(u.id):
		return out
	for p in all(e):
		if e.scanned.has(p.cell):
			var q: Dictionary = p.duplicate()
			q["dist_m"] = Los.distance_m(u.pos, p.cell)
			out.append(q)
	out.sort_custom(func(a, b): return a.dist_m < b.dist_m)
	return out


## Device id → true for every access point (the view gives them their own look).
static func device_ids(m: TacMap) -> Dictionary:
	var out := {}
	for sid in m.architectures:
		for ap in (m.architectures[sid] as NetArchitecture).access_points:
			out[int(ap.device)] = true
	return out
