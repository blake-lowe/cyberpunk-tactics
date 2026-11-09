extends Objective
## Rescue: find the captive in the target building, cut them loose, and get them to the extraction
## zone alive. State: {captive, freed}.


## Held in the target building's most secure room, unarmed and hurt, on the neutral CAPTIVE side
## until freed (they neither see for the crew nor draw fire); freed, they join the crew's side and
## the initiative order as a HOSTAGE the player moves on their own turns (playtest round 4: left to
## the AI they got stuck), but never one of the crew: no pay, no permadeath, not on the roster
## (Encounter.is_hostage). The job is won when they reach the extraction zone, lost if they
## flatline. They're one of Night City's civilians (any NC2045 civilian block:
## Recruit.civilian_blocks), stripped of their weapons.
func setup(target_sid: int, origin: Vector2i, _sec: int) -> void:
	var cell := e.secure_cell(target_sid, origin, "captive")
	var blocks := Recruit.civilian_blocks()
	var block: String = blocks[e.dice.d(blocks.size()) - 1]
	var name := Names.full_name(Names.sub_dice(e.dice))   # a Night City person: one draw, as the old fixed list took one die
	var c := Recruit.civilian(e.dice, block, name)
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
		e.say("%s flatlined. The job's over." % cap.c.display_name)
		return "lost"
	if o.freed and e.extract_cells.has(cap.pos) and cap.c.can_act():
		o.done = true
		e.say("%s is out." % cap.c.display_name)
		return "won"
	return ""


func near_done() -> bool:
	return done() or bool(o.get("freed", false))


func actions() -> Array[String]:
	var out: Array[String] = []   # typed: a bare [] from a ternary comes back untyped
	if not o.freed and _crew_beside(e.units[int(o.captive)].pos):
		out.append("free")
	return out


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
		return "GET %s TO EXTRACTION" % cap.c.display_name.to_upper()
	var who := item_marker("")   # the focus: who they are (a kidnapped student)
	return "FIND AND FREE %s" % cap.c.display_name.to_upper() + ("\n" + who if who != "" else "")


func order() -> String:
	return "RESCUE %s" % String(e.units[int(o.captive)].c.display_name).to_upper()


func current_step() -> String:
	return "GET THEM TO EXTRACTION" if o.get("freed", false) else "FIND AND FREE THEM"


func marks(_fog: bool) -> Array:
	if o.get("freed", false):
		return [_extract_mark()]
	var cap: Dictionary = e.units[int(o.captive)]   # held where the fixer said: they don't move until freed
	return [{"cell": cap.pos, "h": 1.4, "label": "★ CAPTIVE · %s" % String(cap.c.display_name).to_upper(), "tone": "gold", "unit": cap.id}]


func focus_unit() -> int:
	return int(o.captive)
