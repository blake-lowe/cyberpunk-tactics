extends Objective
## Escort: walk the client, a weak friendly civilian, from the crew's side across the site to the
## rendezvous at its far edge (their ride waits there), past people who would rather they didn't
## make it. Lost if the client flatlines. A map with no other way off it has the client wait at a
## pickup point in the target building instead (meet them, an Action beside them), and the crew
## walks them back to the extraction zone.
## State: {client, name, mode: "through" | "pickup", met, dest: [squares], at: the rendezvous}.
##
## The client is a ward, as a rescue's freed captive is (Encounter.is_hostage): on the crew's side
## and in the Initiative order, the player's to move (AI.follow stands in for the player in
## auto-play, toward ward_goal), but never one of the crew (no pay, no permadeath, not on the
## roster; the HUD tags them CLIENT). HOUSE-RULE (owner verdict: the VIP is controllable like the
## freed hostage): the rescue already plays that way, so the client does too.


## The client: one of the district's civilians (any NC2045 civilian block: Recruit.civilian_blocks)
## under one of cfg names, unarmed (they hired the crew to do the shooting), at full health.
func setup(target_sid: int, origin: Vector2i, _sec: int) -> void:
	var names: Array = cfg.names
	var name: String = names[e.dice.d(names.size()) - 1]
	var blocks := Recruit.civilian_blocks(e.district)
	var c := Recruit.civilian(e.dice, blocks[e.dice.d(blocks.size()) - 1], name)
	c.weapons.clear()
	c.faction = "captive"   # a civilian's look, nobody's side but the crew's
	var dest := _rendezvous(origin)
	var mode := "through" if not dest.is_empty() else "pickup"
	if mode == "through":
		e._add(c, _beside_crew(origin), Encounter.CREW)
	else:
		e._add(c, e.secure_cell(target_sid, origin, "captive"), Encounter.CAPTIVE)
		dest = e.extract_cells.keys()
	var cu: Dictionary = e.units[-1]
	cu["captive"] = true   # a ward: Encounter.is_hostage
	cu["ward"] = "CLIENT"
	cu.alerted = mode == "through"
	o.merge({"client": cu.id, "name": name, "mode": mode, "met": mode == "through", "dest": dest,
		"at": dest[0] if not dest.is_empty() else Vector3i(origin.x, origin.y, e.m.street)})


## The rendezvous: the way off the map (a street edge or a gate, else any other exit) the crew
## would walk farthest to reach from the deploy zone, and the open squares around it. [] if
## there is none to reach.
func _rendezvous(origin: Vector2i) -> Array:
	var from := Vector3i(origin.x, origin.y, e.m.street)
	var field: Dictionary = e.nav.distance_field([from], {}, 4000)
	var best := Vector3i(-1, -1, -1)
	var bd := -1
	for pass_n in 2:   # map edges and gates first; buildings' doors only if there's nothing else
		for en in e.m.entrances:
			if en.kind == "deploy" or not bool(en.get("exit", true)) or (pass_n == 0 and en.kind == "door"):
				continue
			var v := Vector3i(en.pos.x, en.pos.y, int(en.get("floor", 0)))
			if field.has(v) and int(field[v]) > bd and int(field[v]) >= int(cfg.get("min_walk", 12)):
				bd = int(field[v])
				best = v
		if best.x >= 0:
			break
	if best.x < 0:
		return []
	var out: Array = [best]
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		var v := best + Vector3i(d.x, d.y, 0)
		if e.m.inb(v.x, v.y) and e.m.walkable(v.z, Vector2i(v.x, v.y)) and not e.m.has_cover_at(v.z, Vector2i(v.x, v.y)) and field.has(v):
			out.append(v)
	return out


## A free deploy square for the client, else the nearest free square to the deploy zone.
func _beside_crew(origin: Vector2i) -> Vector3i:
	var occ := e.occupied()
	var deploy: Array = e.extract_cells.keys()
	deploy.sort()
	for v in deploy:
		if not occ.has(v):
			return v
	var reach: Dictionary = e.nav.reachable(Vector3i(origin.x, origin.y, e.m.street), 6, occ)
	var best := Vector3i(origin.x, origin.y, e.m.street)
	var bd := 999
	for v in reach:
		if not occ.has(v) and int(reach[v]) < bd:
			bd = int(reach[v])
			best = v
	return best


func client() -> Dictionary:
	return e.units[int(o.client)]


func check_end() -> String:
	var cu := client()
	if cu.c.dead:
		e.say("%s flatlined. The job's over." % cu.c.display_name)
		return "lost"
	if o.met and (o.dest as Array).has(cu.pos) and cu.c.can_act():
		o.done = true
		e.say("%s %s." % [cu.c.display_name, "makes the rendezvous" if o.mode == "through" else "is out"])
		return "won"
	return ""


func actions() -> Array[String]:
	var out: Array[String] = []   # typed: a bare [] from a ternary comes back untyped
	if not o.met and _crew_beside(client().pos):
		out.append("meet")
	return out


## Pickup: meet the client where they wait (an Action beside them): they join the crew's side and
## the Initiative order, the player's to move from their next turn.
func act(action: String) -> Dictionary:
	if action != "meet" or "meet" not in actions():
		return {"ok": false, "reason": "get next to the client"}
	var r := _use_action()
	if not r.ok:
		return r
	var cu := client()
	cu.team = Encounter.CREW
	cu.c.team = Encounter.CREW
	cu.alerted = true
	e.init.add(cu.c)
	o.met = true
	e.events.append({"type": "free", "unit": e.cur.id, "target": cu.id})
	e.say("%s finds %s. Get them to the extraction zone." % [e.cur.c.display_name, cu.c.display_name])
	e.refresh_vision()
	e._check_end()
	return {"ok": true}


func action_title(action: String) -> String:
	return "MEET CLIENT" if action == "meet" else super(action)


func action_glyph(action: String) -> String:
	return "free" if action == "meet" else super(action)


func hud_text() -> String:
	var cu := client()
	var nm := String(cu.c.display_name).to_upper()
	var who := item_marker("")   # the focus: who they are (a key exec)
	var lines: Array[String] = []
	if not o.get("met", true):
		lines.append("MEET %s" % nm)
		lines.append("THEY'RE WAITING INSIDE")
	elif o.mode == "through":
		lines.append("GET %s TO THE RENDEZVOUS" % nm)
		lines.append("KEEP THEM ALIVE")
	else:
		lines.append("GET %s TO EXTRACTION" % nm)
	if who != "":
		lines.insert(1, who)
	if not cu.c.dead and cu.c.wound_state() == Combatant.Wound.MORTAL:
		lines.append("%s IS BLEEDING OUT" % nm)
	return "\n".join(lines)


func order() -> String:
	return "ESCORT %s" % String(client().c.display_name).to_upper()


func current_step() -> String:
	var cu := client()
	if not cu.c.dead and cu.c.wound_state() == Combatant.Wound.MORTAL:
		return "THEY'RE BLEEDING OUT"
	if not o.get("met", true):
		return "MEET THEM INSIDE"
	return "GET THEM TO THE RENDEZVOUS" if o.mode == "through" else "GET THEM TO EXTRACTION"


## The client (a ward on the crew's side, so always in sight) and, once met, where they're going.
func marks(_fog: bool) -> Array:
	var cu := client()
	var out: Array = []
	if o.get("met", true):
		out.append({"cell": o.at, "h": 0.6, "label": "★ RENDEZVOUS", "tone": "gold"} if o.mode == "through" else _extract_mark())
	if not cu.c.dead:
		out.append({"cell": cu.pos, "h": 1.4, "label": "★ CLIENT · %s" % String(cu.c.display_name).to_upper(), "tone": "gold", "unit": cu.id})
	return out


func zones() -> Array:
	return [{"cells": o.dest, "tone": "gold"}] if o.get("mode", "") == "through" else []


## Through to a rendezvous at the map's edge: the crew can leave by it with the client, or go back
## the way it came.
func exit_cells() -> Array:
	return (o.dest as Array) + e.extract_cells.keys() if o.get("mode", "") == "through" else e.extract_cells.keys()


func ward_goal() -> Array:
	return o.dest if o.get("mode", "") == "through" else []


## A guard whose id falls on cfg hunt_every goes for the client (the target's people want them
## dead: owner, "hostiles target the VIP sometimes"); the rest weigh them a little over the crew.
## HOUSE-RULE weights. The shooter is the unit whose turn it is (AI._shoot runs on it).
func _hunter(u: Dictionary) -> bool:
	return not u.is_empty() and e.is_guard(u) and e.hostile(int(u.team), Encounter.CREW) and int(u.id) % int(cfg.get("hunt_every", 3)) == 0


func ai_target_mult(t: Dictionary) -> float:
	if int(t.id) != int(o.client):
		return 1.0
	return float(cfg.get("hunt_mult", 2.5)) if _hunter(e.cur) else float(cfg.get("client_mult", 1.3))


## Hunters close on the client.
func ai_pull(u: Dictionary, cell: Vector3i) -> float:
	if not _hunter(u) or not o.get("met", true):
		return 0.0
	var cp: Vector3i = client().pos
	return -0.5 * Vector2(cp.x - cell.x, cp.y - cell.y).length() if cp.z == cell.z else 0.0


## Auto-play: fetch the client (pickup), keep within 3 squares of them, and walk them to the goal.
func crew_goal(u: Dictionary) -> Variant:
	var cu := client()
	if cu.c.dead:
		return []
	if not o.met:
		return [cu.pos]
	if Vector2(cu.pos.x - u.pos.x, cu.pos.y - u.pos.y).length() + absi(cu.pos.z - u.pos.z) * 4 > 3.0:
		return [cu.pos]
	return o.dest


func focus_unit() -> int:
	return int(o.client)
