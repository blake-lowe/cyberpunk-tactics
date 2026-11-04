extends Objective
## Assassination: put the mark down before they reach an exit, then get out (or clear the site).
## Trauma Team flying the mark out blows the job. State: {target, name, exits, escaped}.


## The mark: a Night City civilian who fits the target (vip_block: an executive for a corp, a fixer
## for a gang), else one of the target faction's own Lieutenants (a Mini Boss at security 2+), in
## the target building's most secure room, with bodyguards beside them. Exits: the map's entrances
## other than the deploy zone, where the mark runs once the alarm goes up.
func setup(target_sid: int, origin: Vector2i, sec: int) -> void:
	var cell := e.secure_cell(target_sid, origin, "vip")
	var names: Array = cfg.names
	var name: String = names[e.dice.d(names.size()) - 1]
	var block := vip_block(e.opfor_faction, cfg, e.dice)
	var vip: Combatant
	if block != "":
		vip = Recruit.civilian(e.dice, block, name)
	else:
		var tier := "mini_boss" if sec >= 2 else "lieutenant"
		vip = Recruit.npc(e.dice, tier, name, SecurityCode.tier_pool(e.opfor_faction, tier, false))
	vip.faction = e.opfor_faction
	e._add(vip, cell, Encounter.OPFOR)
	var vu: Dictionary = e.units[-1]
	vu["vip"] = true
	var guards := 0
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
		if guards >= int(cfg.get("bodyguards", 2)):
			break
		var v := cell + Vector3i(d.x, d.y, 0)
		if e.m.walkable(v.z, Vector2i(v.x, v.y)) and not e.occupied().has(v) and e.m.label(v.z, v.x, v.y) >= 0:
			var g := World.npc(e.dice, e.opfor_faction, "lieutenant" if sec >= 3 else "mook", guards + 1, "Bodyguard")
			e._add(g, v, Encounter.OPFOR)
			e.units[-1]["bodyguard"] = true
			guards += 1
	var exits: Array = []
	for en in e.m.entrances:
		if en.kind != "deploy" and e.m.walkable(int(en.get("floor", 0)), en.pos):
			exits.append(Vector3i(en.pos.x, en.pos.y, int(en.get("floor", 0))))
	o.merge({"target": vu.id, "name": name, "exits": exits, "escaped": false})


## The civilian block the mark is for target faction `fid` (cfg vip_blocks, by the faction's kind:
## NC2045's Junior Executive or Rupture Fighter for a corp, the Minimallism Fixer for a gang), or ""
## when the kind has none (the police: the mark is one of their own officers).
static func vip_block(fid: String, p_cfg: Dictionary, dice: Dice) -> String:
	var known := RulesDB.load_json("npcs.json")["blocks"] as Dictionary
	var fits: Array = ((p_cfg.get("vip_blocks", {}) as Dictionary).get(World.kind(fid), []) as Array).filter(
		func(id): return known.has(String(id)) and bool(known[String(id)].get("civilian", false)))
	return String(fits[dice.d(fits.size()) - 1]) if not fits.is_empty() else ""


func check_end() -> String:
	var vip: Dictionary = e.units[int(o.target)]
	if not done() and not vip.c.can_act() and not o.get("escaped", false):
		o.done = true
		e.events.append({"type": "target_down", "unit": vip.id})
		e.say("%s is down. Get out." % o.name)
	if done() and (e.opfor().is_empty() or e._crew_out()):
		e.say("The crew gets clear. The job's done.")
		return "won"
	return ""


func withdraw_wins() -> bool:
	return done()


## The mark reached an exit: gone, and the job with them.
func escape(u: Dictionary) -> void:
	o.escaped = true
	e.events.append({"type": "escape", "unit": u.id})
	u.c.dead = true   # off the map (not killed: the log says so)
	u["escaped"] = true
	e.say("%s gets away." % o.name)
	e.state = "lost"


func on_evacuated(patient: int) -> void:
	if int(o.target) != patient:
		return
	o.done = false
	o.escaped = true
	e.state = "lost"
	e.say("Trauma Team saved %s. The job's blown." % o.name)


func hud_text() -> String:
	var tt_inbound: bool = not e.tt.is_empty() and String(e.tt.state) in ["called", "landed"]
	if done():
		if tt_inbound:
			return "OBJECTIVE · %s IS DOWN, NOT DEAD\nTRAUMA TEAM INBOUND: FINISH IT" % String(o.name).to_upper()
		return "OBJECTIVE · %s IS DOWN\nGET TO THE EXTRACTION ZONE" % String(o.name).to_upper()
	var vip: Dictionary = e.units[int(o.target)]
	var run := " · RUNNING FOR AN EXIT" if (vip.alerted or e.alarm >= 1) else ""
	if tt_inbound and int(e.tt.patient) == vip.id:
		run = " · TRAUMA TEAM INBOUND: FINISH IT"
	return "OBJECTIVE · TAKE DOWN %s%s" % [String(o.name).to_upper(), run]


func marks(fog: bool) -> Array:
	var vip: Dictionary = e.units[int(o.target)]
	if done():
		return [_extract_mark()]
	if not vip.c.dead and (not fog or e.vision.visible.has(vip.pos) or e.vision.explored.has(vip.pos)):
		return [{"cell": vip.pos, "h": 1.6, "label": "TARGET", "tone": "red"}]
	return []


func focus_unit() -> int:
	return int(o.target)
