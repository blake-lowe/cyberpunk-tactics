extends Objective
## Rescue: find the captive in the target building, cut them loose, and get them to the extraction
## zone alive. State: {captive, freed}.


## Held in the target building's most secure room, unarmed and hurt, on the neutral CAPTIVE side
## until freed (they neither see for the crew nor draw fire); freed, they join the crew's side and
## the initiative order and follow the crew on their own turns.
func setup(target_sid: int, origin: Vector2i, _sec: int) -> void:
	var cell := e.secure_cell(target_sid, origin, "captive")
	var roles: Array = cfg.roles
	var names: Array = cfg.names
	var c := Recruit.generate(e.dice, String(roles[e.dice.d(roles.size()) - 1]), "edgerunner", String(names[e.dice.d(names.size()) - 1]))
	c.weapons.clear()
	c.hp = maxi(1, c.max_hp() / 2)   # roughed up
	c.faction = "captive"
	e._add(c, cell, Encounter.CAPTIVE)
	var cu: Dictionary = e.units[-1]
	cu["captive"] = true
	cu.alerted = false
	o.merge({"captive": cu.id, "freed": false})


func check_end() -> String:
	var cap: Dictionary = e.units[int(o.captive)]
	if cap.c.dead:
		e.say("%s is dead. The job's over." % cap.c.display_name)
		return "lost"
	if o.freed and e.extract_cells.has(cap.pos) and cap.c.can_act():
		o.done = true
		e.say("%s is out." % cap.c.display_name)
		return "won"
	return ""


func actions() -> Array[String]:
	return ["free"] if not o.freed and _crew_beside(e.units[int(o.captive)].pos) else []


func act(action: String) -> Dictionary:
	if action != "free" or "free" not in actions():
		return {"ok": false, "reason": "get next to the captive"}
	var r := _use_action()
	if not r.ok:
		return r
	var cap: Dictionary = e.units[int(o.captive)]
	cap.team = Encounter.CREW
	cap.c.team = Encounter.CREW
	cap.alerted = true
	e.init.add(cap.c)
	o.freed = true
	e.events.append({"type": "free", "unit": e.cur.id, "target": cap.id})
	e.say("%s cuts %s loose. Get them to the extraction zone." % [e.cur.c.display_name, cap.c.display_name])
	e.refresh_vision()
	e._check_end()
	return {"ok": true}


func hud_text() -> String:
	var cap: Dictionary = e.units[int(o.captive)]
	if o.get("freed", false):
		return "OBJECTIVE · GET %s TO THE EXTRACTION ZONE" % cap.c.display_name.to_upper()
	return "OBJECTIVE · FIND AND FREE %s" % cap.c.display_name.to_upper()


func marks(_fog: bool) -> Array:
	if o.get("freed", false):
		return [_extract_mark()]
	return [{"cell": e.units[int(o.captive)].pos, "h": 1.4, "label": String(e.units[int(o.captive)].c.display_name).to_upper(), "tone": "gold"}]


func focus_unit() -> int:
	return int(o.captive)
