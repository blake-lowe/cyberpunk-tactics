class_name AccessPoints
extends RefCounted
## Where the crew can jack in (CPR core p.198: within 6 m of an access point, no wall between), for
## the view's way-finding: Alt's port icons over every access point the crew has seen, and the data
## lines a Netrunner's idle turn draws to each one they sense (Interface range, a straight line). Pure
## lookups on the Encounter, so they are testable headless.


## Every NET access point on the map: [{device, cell: Vector3i, structure, index}].
static func all(e: Encounter) -> Array:
	var out := []
	for sid in e.m.architectures:
		var a: NetArchitecture = e.m.architectures[sid]
		for i in a.access_points.size():
			var d: Dictionary = e.m.devices[int(a.access_points[i].device)]
			out.append({"device": int(d.id), "cell": Vector3i(d.pos.x, d.pos.y, d.floor), "structure": int(sid), "index": i})
	return out


## Access points the crew has seen (all of them with the fog off).
static func seen(e: Encounter, fog_on := true) -> Array:
	return all(e).filter(func(p): return not fog_on or e.vision.explored.has(p.cell))


## Device id → true for every access point (the view gives them their own look).
static func device_ids(m: TacMap) -> Dictionary:
	var out := {}
	for sid in m.architectures:
		for ap in (m.architectures[sid] as NetArchitecture).access_points:
			out[int(ap.device)] = true
	return out


## HOUSE-RULE: a Netrunner senses access points by Interface rather than by where MOVE could take
## them this turn (owner: a role-ability stat and a straight line read better than a move+run
## reach): every access point within Interface x SENSE_M_PER_RANK metres as the crow flies
## (Los.distance_m: through walls, 3 m a storey), seen or not. Nothing for a non-Netrunner or a
## runner already jacked in. Entries add `dist_m`, nearest first.
const SENSE_M_PER_RANK := 4.0


static func sense_range_m(c: Combatant) -> float:
	return NetRun.interface_rank(c) * SENSE_M_PER_RANK


static func sensed(e: Encounter, u: Dictionary) -> Array:
	var out := []
	if NetRun.interface_rank(u.c) <= 0 or e.runs.has(u.id):
		return out
	var rng := sense_range_m(u.c)
	for p in all(e):
		var d := Los.distance_m(u.pos, p.cell)
		if d <= rng:
			var q: Dictionary = p.duplicate()
			q["dist_m"] = d
			out.append(q)
	out.sort_custom(func(a, b): return a.dist_m < b.dist_m)
	return out
