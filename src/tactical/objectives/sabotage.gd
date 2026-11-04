extends Objective
## Sabotage: plant a timed charge on a machine in the target building, get clear, and let it blow;
## then leave (or clear the site). State: {cell, target_kind, name, planted, boom_round, planter}.


## The machine: a big piece of hardware (cover) in the target building's most secure room.
func setup(target_sid: int, origin: Vector2i, _sec: int) -> void:
	var cell := e.secure_cell(target_sid, origin, "machine")
	var targets: Dictionary = cfg.targets
	var kinds := targets.keys()
	var kind: String = kinds[e.dice.d(kinds.size()) - 1]
	var entry := Furnish.cover_entry("machine", cell.z, Vector2i(cell.x, cell.y), e.m.label(cell.z, cell.x, cell.y))
	entry.kind = kind
	e.m.add_cover(entry)
	e.los.cover_hp[cell] = int(entry.hp)
	o.merge({"cell": cell, "target_kind": kind, "name": targets[kind], "planted": false, "boom_round": -1})


func check_end() -> String:
	if done() and (e.opfor().is_empty() or e._crew_out()):
		e.say("The crew gets clear. The job's done.")
		return "won"
	return ""


func actions() -> Array[String]:
	return ["plant"] if not o.planted and not done() and _crew_beside(o.cell) else []


## Set the charge (an Action, next to the machine): it goes off fuse_rounds rounds later.
func act(action: String) -> Dictionary:
	if action != "plant" or "plant" not in actions():
		return {"ok": false, "reason": "get next to the target"}
	var r := _use_action()
	if not r.ok:
		return r
	o.planted = true
	o.boom_round = e.init.round_num + fuse_rounds()
	o["planter"] = e.cur.id
	e.events.append({"type": "plant", "unit": e.cur.id, "cell": o.cell})
	e.say("%s sets the charge on %s. %d rounds. Move." % [e.cur.c.display_name, o.name, fuse_rounds()])
	return {"ok": true}


func fuse_rounds() -> int:
	return int(cfg.get("fuse_rounds", 3))


## Rounds until the charge goes off, or -1 if none is ticking.
func fuse_left() -> int:
	return int(o.boom_round) - e.init.round_num if o.get("planted", false) and not done() else -1


func tick() -> void:
	if not o.planted or done() or e.init.round_num < int(o.boom_round):
		return
	e._detonate(o.cell, int(cfg.get("charge_half", 3)), int(cfg.get("charge_dice", 8)), int(o.get("planter", 0)), int(cfg.get("charge_total", 17)))
	o.done = true
	e.say("%s goes up." % String(o.name).capitalize())
	e.alarm = maxi(e.alarm, 1)
	e._check_end()


func withdraw_wins() -> bool:
	return done()


func hud_text() -> String:
	if done():
		return "OBJECTIVE · %s IS WRECKED\nGET TO THE EXTRACTION ZONE" % String(o.name).to_upper()
	if o.get("planted", false):
		return "CHARGE SET · %d ROUND%s · GET CLEAR" % [fuse_left(), "" if fuse_left() == 1 else "S"]
	return "OBJECTIVE · PLANT A CHARGE ON %s" % String(o.name).to_upper()


func marks(_fog: bool) -> Array:
	if done():
		return [_extract_mark()]
	var label := "CHARGE · %d" % fuse_left() if o.get("planted", false) else "TARGET"
	return [{"cell": o.cell, "h": 1.8, "label": label, "tone": "red"}]


func focus_cell() -> Vector3i:
	return o.cell
