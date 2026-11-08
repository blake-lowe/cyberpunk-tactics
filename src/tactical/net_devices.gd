class_name NetDevices
extends RefCounted
## Working the devices on a held Control Node (CPR core p.199): each thing on the Node is operated
## with its own NET Action, from anywhere in the Architecture while the Node is held, and each Node
## can be activated once per Turn. What each device type does is data (data/rules/net_devices.json);
## the state lives on the Encounter (looped, sealed, dev_state, dark_rooms, nav.halted) so the rules
## stay in one place and the view only reads it. Jacking out loses every Node (p199): release()
## hands everything back to the site.
##
## HOUSE-RULE (bank): one activation works every device of one type on the Node (all its cameras,
## all its lights). The book prices each device at a NET Action, but with one activation per Node a
## Turn a bank of six cameras would take six Turns; a camera bank is one Observation Camera system
## (p.215), so it is worked as one.
## HOUSE-RULE (feed): a held camera feeds the crew what it sees at no cost; watching is not
## operating it. Looping it (the NET Action) is what stops it reporting to the site.
## HOUSE-RULE (seal): a door locked from the NET is locked to everyone; the guards' keycards don't
## open a lock the runner holds (the book leaves it to the GM; otherwise locking would do nothing).
## HOUSE-RULE (distract): starting a machine or paging over the PA turns unalerted guards within
## distract_range on its floor to look at it (no book rule for it; Control Nodes may be
## non-combat, p.210-211). Lights killed give the book's darkness penalty to spot (-4).
## RULES-UNVERIFIED: the alarm line cut doubling the response time (Encounter.call_it_in).

static func db() -> Dictionary:
	return RulesDB.load_json("net_devices.json")


## The device type's entry ({name, op, bank, doors}), {} when the type does nothing remotely.
static func spec(kind: String) -> Dictionary:
	return (db().devices as Dictionary).get(kind, {})


## Who holds device `did` through the NET: the runner's unit id, or -1.
static func holder(e: Encounter, did: int) -> int:
	for uid in e.runs:
		var run: NetRun = e.runs[uid]
		for nid in run.held:
			if (run.arch.nodes[nid].get("devices", []) as Array).has(did):
				return int(uid)
	return -1


## Every device some runner holds: device id → runner unit id.
static func held_map(e: Encounter) -> Dictionary:
	var out := {}
	for uid in e.runs:
		var run: NetRun = e.runs[uid]
		for nid in run.held:
			for did in run.arch.nodes[nid].get("devices", []):
				out[int(did)] = int(uid)
	return out


static func _cell(d: Dictionary) -> Vector3i:
	return Vector3i(d.pos.x, d.pos.y, d.floor)


## The doors a seal works: the device's own room's, or the site's gates.
static func door_cells(e: Encounter, d: Dictionary) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	var how := String(spec(String(d.type)).get("doors", "room"))
	for dr in e.m.doors:
		var c := Vector3i(dr.pos.x, dr.pos.y, dr.floor)
		if e.m.t(c.z, c.x, c.y) != TacMap.T.DOOR:
			continue   # shot away
		if how == "gates":
			if dr.get("gate", false) and (int(dr.get("structure", -1)) == int(d.get("structure", -1)) or int(d.get("structure", -1)) < 0):
				out.append(c)
		elif int(dr.get("a", -1)) == int(d.get("room", -2)) or int(dr.get("b", -1)) == int(d.get("room", -2)):
			out.append(c)
	if how == "gates" and out.is_empty():   # a booth with no gate of its own building: every gate on the map
		for dr in e.m.doors:
			if dr.get("gate", false) and e.m.t(int(dr.floor), dr.pos.x, dr.pos.y) == TacMap.T.DOOR:
				out.append(Vector3i(dr.pos.x, dr.pos.y, dr.floor))
	return out


## Is a device's op switched on (looped, locked, sealed, halted, dark, cut)?
static func is_on(e: Encounter, d: Dictionary) -> bool:
	match String(spec(String(d.type)).get("op", "")):
		"loop": return e.looped.has(int(d.id))
		"lock": return e.nav.locked.has(_cell(d))
		"halt": return e.nav.halted.has(Vector2i(d.pos.x, d.pos.y))
		"lights": return e.dark_rooms.has(int(d.get("room", -1)))
		"seal", "cut_alarm": return e.dev_state.has(int(d.id))
	return false


static func _occupied_any(e: Encounter, cells: Array) -> bool:
	for u in e.units:
		if not u.c.dead and not u.get("fled", false) and cells.has(u.pos):
			return true
	return false


## Why device `d` can't be worked now ("" = it can). `on` its current state.
static func why_not(e: Encounter, d: Dictionary, on: bool) -> String:
	if e._unpowered(d) or ("power" in e.outages and String(spec(String(d.type)).get("op", "")) == "lights"):
		return "no power"
	match String(spec(String(d.type)).get("op", "")):
		"lock":
			var c := _cell(d)
			if e.m.t(c.z, c.x, c.y) != TacMap.T.DOOR:
				return "the door is wrecked"
			if not on and _occupied_any(e, [c]):
				return "someone is in the doorway"
		"seal":
			var cells := door_cells(e, d)
			if cells.is_empty():
				return "no doors to work"
			if not on and _occupied_any(e, cells):
				return "someone is in a doorway"
		"loop":
			if e.disabled_devices.has(int(d.id)) and not e.looped.has(int(d.id)):
				return "dead"   # killed by hand: nothing left to loop
	return ""


## The held Control Nodes of runner `uid` and what can be done with each, for the NET panel and
## the AI: [{node, group, used (activated this Turn), ops: [{node, device, devices, kind, op, name,
## label, on, why}]}]. Turrets are listed by Encounter.held_turrets (their FIRE rows).
static func rows(e: Encounter, uid: int) -> Array:
	var run: NetRun = e.runs.get(uid)
	var out := []
	if run == null:
		return out
	var ids := run.held.keys()
	ids.sort()
	for nid in ids:
		var n: Dictionary = run.arch.nodes[nid]
		var used := int(run.activated.get(nid, -1)) == e.init.round_num
		var ops := []
		var banked := {}
		for did in n.get("devices", []):
			var d: Dictionary = e.m.devices[did]
			var kind := String(d.type)
			var sp := spec(kind)
			var op := String(sp.get("op", ""))
			if op == "" or op == "fire":
				continue
			if bool(sp.get("bank", false)):
				if banked.has(kind):
					(ops[int(banked[kind])].devices as Array).append(int(did))
					continue
				banked[kind] = ops.size()
			var on := is_on(e, d)
			var labels: Dictionary = db().ops[op]
			var why := "node already used this turn" if used else why_not(e, d, on)
			var nm := String(sp.name)
			if not bool(sp.get("bank", false)):   # one of several alike: say which (the room it serves, the floor)
				nm = where(e, d)
			ops.append({"node": int(nid), "device": int(did), "devices": [int(did)], "kind": kind, "op": op, "name": nm,
				"label": String(labels.on if on else labels.off), "on": on, "why": why, "dist": _crew_dist(e, d)})
		for o in ops:   # a bank's label counts its devices
			if (o.devices as Array).size() > 1:
				o.name = "%d %s" % [(o.devices as Array).size(), String(o.name)]
		ops.sort_custom(func(a, b): return float(a.dist) < float(b.dist))   # nearest the crew first
		out.append({"node": int(nid), "group": String(n.group), "used": used, "ops": ops})
	return out


## A device in words for its row: "server room door, F2", "elevator, F1".
static func where(e: Encounter, d: Dictionary) -> String:
	var what := String(spec(String(d.type)).get("name", String(d.type).replace("_", " ")))
	if String(d.type) == "door_lock":
		what = "door"
	var r := int(d.get("room", -1))
	var room := String(e.m.rooms[r].kind).replace("_", " ") + " " if r >= 0 and r < e.m.rooms.size() and String(d.type) in ["door_lock", "vault_lock", "cell_locks", "shutter_control"] else ""
	return "%s%s, F%d" % [room, what, int(d.floor) + 1]


## How far the device is from the nearest crew member on its floor (squares; far floors count more).
static func _crew_dist(e: Encounter, d: Dictionary) -> float:
	var best := INF
	for u in e.units:
		if int(u.team) == Encounter.CREW and not u.c.dead:
			best = minf(best, Vector2(u.pos.x - d.pos.x, u.pos.y - d.pos.y).length() + 30.0 * absi(int(u.pos.z) - int(d.floor)))
	return best


## Work device `did` on held node `nid` (Encounter.net_device spends the NET Action first).
## Returns {ok, op, on (the new state), text (the log line)}.
static func operate(e: Encounter, uid: int, nid: int, did: int) -> Dictionary:
	var run: NetRun = e.runs[uid]
	var n: Dictionary = run.arch.nodes[nid]
	var d: Dictionary = e.m.devices[did]
	var sp := spec(String(d.type))
	var op := String(sp.op)
	var devs: Array = [did]
	if bool(sp.get("bank", false)):
		devs = (n.devices as Array).filter(func(x): return String(e.m.devices[x].type) == String(d.type))
	var on := is_on(e, d)
	var who: String = e.units[uid].c.display_name
	var text := ""
	var cells: Array[Vector3i] = []
	match op:
		"loop":   # the site's feed shows a recording; the runner still watches the real one
			for x in devs:
				if on:
					e.looped.erase(int(x))
					if not e._unpowered(e.m.devices[x]):
						e.disabled_devices.erase(int(x))
				elif not e.disabled_devices.has(int(x)):
					e.looped[int(x)] = uid
					e.disabled_devices[int(x)] = true
			text = "%s %s %d camera feed%s." % [who, "restores" if on else "loops", devs.size(), "" if devs.size() == 1 else "s"]
		"lock":
			var c := _cell(d)
			_door(e, uid, c, not on)
			cells.append(c)
			text = "%s %s the %s from the NET." % [who, "unlocks" if on else "locks", where(e, d)]
		"seal":
			cells = door_cells(e, d)
			for c in cells:
				_door(e, uid, c, not on)
			if on:
				e.dev_state.erase(did)
			else:
				e.dev_state[did] = uid
			text = "%s %s the %s (%d door%s)." % [who, "opens" if on else "seals", String(sp.name), cells.size(), "" if cells.size() == 1 else "s"]
		"halt":
			var p := Vector2i(d.pos.x, d.pos.y)
			if on:
				e.nav.halted.erase(p)
			else:
				e.nav.halted[p] = true
			text = "%s %s the elevator." % [who, "starts" if on else "halts"]
		"lights":
			for x in devs:
				var r := int(e.m.devices[x].get("room", -1))
				if on:
					e.dark_rooms.erase(r)
				elif r >= 0:
					e.dark_rooms[r] = uid
			e._compute_light()
			text = "%s %s the %s." % [who, "brings up" if on else "kills", String(sp.name)]
		"cut_alarm":
			for x in devs:
				if on:
					e.dev_state.erase(int(x))
				else:
					e.dev_state[int(x)] = uid
			text = "%s %s the alarm line%s." % [who, "restores" if on else "cuts", "" if on else ": a call for help goes out slow"]
		"sprinklers":
			var doused := []
			var sid := int(d.get("structure", -1))
			for u in e.units:
				var l := e.m.label(u.pos.z, u.pos.x, u.pos.y)
				if u.c.burning > 0 and l >= 0 and int(e.m.rooms[l].get("structure", -2)) == sid and not e.m.rooms[l].get("outdoor", false):
					u.c.burning = 0
					doused.append(u.c.display_name)
			on = false
			text = "%s sets off the sprinklers%s." % [who, (": " + ", ".join(doused) + " put out") if not doused.is_empty() else ""]
		"distract":
			var c := _cell(d)
			var turned := 0
			var rng := int(db().get("distract_range", 10))
			for g in e.units:
				if e.is_guard(g) and e.hostile(int(g.team), Encounter.CREW) and not g.alerted and not g.c.dead and g.pos.z == c.z \
						and Vector2(c.x - g.pos.x, c.y - g.pos.y).length() <= rng and g.pos != c:
					g["facing"] = Vector2(c.x - g.pos.x, c.y - g.pos.y).normalized()
					turned += 1
			on = false
			text = "%s starts up the %s: %d guard%s look round." % [who, String(sp.name), turned, "" if turned == 1 else "s"]
	var now := not on if op not in ["sprinklers", "distract"] else true
	return {"ok": true, "op": op, "on": now, "text": text, "devices": devs, "cells": cells}


## A door locked (sealed against everyone, keycards included) or unlocked from the NET. The first
## touch remembers how the site had it, for release().
static func _door(e: Encounter, uid: int, c: Vector3i, lock: bool) -> void:
	if not e._net_doors.has(c):
		e._net_doors[c] = [uid, e.nav.locked.has(c)]
	if lock:
		e.nav.locked[c] = true
		e.sealed[c] = true
		e.los.open_doors.erase(c)   # it swings shut
	else:
		e.nav.locked.erase(c)
		e.sealed.erase(c)
	for dv in e.m.devices:   # the lock lamp follows the door
		if String(dv.type) == "door_lock" and _cell(dv) == c:
			if lock:
				e.disabled_devices.erase(int(dv.id))
			else:
				e.disabled_devices[int(dv.id)] = true


## Runner `uid` let go (Jack Out, p199): the site has its devices back as it left them. Looped
## feeds go live, doors the NET locked or opened go back to the site's locks (a door left standing
## open stays open), halted elevators run, dark rooms light up, the alarm line is restored.
static func release(e: Encounter, uid: int) -> void:
	for did in e.looped.keys():
		if int(e.looped[did]) == uid:
			e.looped.erase(did)
			if not e._unpowered(e.m.devices[did]):
				e.disabled_devices.erase(did)
	for c in e._net_doors.keys():
		var rec: Array = e._net_doors[c]
		if int(rec[0]) != uid:
			continue
		e._net_doors.erase(c)
		e.sealed.erase(c)
		if bool(rec[1]) and not e.los.open_doors.has(c) and e.m.t(c.z, c.x, c.y) == TacMap.T.DOOR:
			e.nav.locked[c] = true
			for dv in e.m.devices:
				if String(dv.type) == "door_lock" and _cell(dv) == c:
					e.disabled_devices.erase(int(dv.id))
		elif not bool(rec[1]):
			e.nav.locked.erase(c)
	for did in e.dev_state.keys():
		if int(e.dev_state[did]) == uid:
			e.dev_state.erase(did)
	var held := held_map(e)
	for p in e.nav.halted.keys():   # an elevator nobody else holds runs again
		var still := false
		for did in held:
			var d: Dictionary = e.m.devices[did]
			if int(held[did]) != uid and String(d.type) == "elevator" and Vector2i(d.pos.x, d.pos.y) == p:
				still = true
		if not still:
			e.nav.halted.erase(p)
	var relit := false
	for r in e.dark_rooms.keys():
		if int(e.dark_rooms[r]) == uid:
			e.dark_rooms.erase(r)
			relit = true
	if relit:
		e._compute_light()


## Is the site's alarm line cut (a held alarm panel worked from the NET)?
static func alarm_cut(e: Encounter) -> bool:
	for did in e.dev_state:
		if String(e.m.devices[did].type) == "alarm_panel":
			return true
	return false


## What the crew sees through held cameras (HOUSE-RULE feed): every square a held, powered camera
## watches, looped or not (a loop fools the site, not the runner).
static func feed_cells(e: Encounter) -> Dictionary:
	var out := {}
	if e.runs.is_empty():
		return out
	for did in held_map(e):
		var d: Dictionary = e.m.devices[did]
		if String(d.type) != "camera" or e._unpowered(d) or (e.disabled_devices.has(did) and not e.looped.has(did)):
			continue
		out.merge(e.camera_cells(d))
		out[_cell(d)] = true
	return out


## Cameras feeding the crew right now (device ids), for the view's lamps.
static func feeding(e: Encounter) -> Dictionary:
	var out := {}
	for did in held_map(e):
		var d: Dictionary = e.m.devices[did]
		if String(d.type) == "camera" and not e._unpowered(d) and (not e.disabled_devices.has(did) or e.looped.has(did)):
			out[did] = true
	return out


## Eye-Dee's answer for File node `n` (p.199: what the data is and its value): {what, value,
## tier}. What it is comes from the room its terminal stands in (data/rules/net_devices.json files).
static func file_info(e: Encounter, n: Dictionary) -> Dictionary:
	var f: Dictionary = db().files
	var what := String(n.get("label", ""))
	var did := int(n.get("device", -1))
	if what == "" and did >= 0 and did < e.m.devices.size():
		var r := int(e.m.devices[did].get("room", -1))
		if r >= 0 and r < e.m.rooms.size():
			what = String((f.rooms as Dictionary).get(String(e.m.rooms[r].kind), String(e.m.rooms[r].kind).replace("_", " ") + " files"))
	if what == "":
		what = "data"
	var v := clampi(int(n.get("value", 1)), 1, (f.tiers as Array).size() - 1)
	return {"what": what, "value": v, "tier": String(f.tiers[v])}
