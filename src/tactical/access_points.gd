class_name AccessPoints
extends RefCounted
## Where the crew can jack in (CPR core p.198: within 6 m of an access point, no wall between), for
## the view's way-finding: Alt's port icons over every access point the crew has seen, and the data
## lines a Netrunner's idle turn draws to each one they could reach and jack in at this turn. Pure
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


## Seen access points the active unit `u` (a Netrunner, Encounter.cur) could jack in at this turn:
## one with a square in jack range (no wall between, p198) that `u` stands on or can still reach
## by moving or running this turn. Each entry adds `from`: the nearest such square.
static func in_reach(e: Encounter, u: Dictionary, fog_on := true) -> Array:
	var out := []
	if NetRun.interface_rank(u.c) <= 0 or e.runs.has(u.id):
		return out
	var opts := {u.pos: 0}
	if e.cur == u and e.turn != null:
		opts.merge(e.move_options())
		opts.merge(e.run_options())
	var rng := Encounter.jack_range(u.c)
	var sq := int(ceil(rng / 2.0))
	for p in seen(e, fog_on):
		var c: Vector3i = p.cell
		var best := Vector3i(-1, -1, -1)
		var bd := INF
		for dy in range(-sq, sq + 1):
			for dx in range(-sq, sq + 1):
				var v := Vector3i(c.x + dx, c.y + dy, c.z)
				if not opts.has(v) or Los.distance_m(v, c) > rng or e._wall_between(v, c):
					continue
				var dist := Vector3(v - u.pos).length()
				if dist < bd:
					bd = dist
					best = v
		if best.x >= 0:
			var q: Dictionary = p.duplicate()
			q["from"] = best
			out.append(q)
	return out
