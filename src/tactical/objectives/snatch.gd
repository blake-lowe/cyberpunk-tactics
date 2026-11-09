extends Objective
## Snatch and extract: grab the package in the target building and carry it back to the deploy
## zone. A carrier who goes down drops it where they fall. State: {cell, carrier}.


func setup(target_sid: int, origin: Vector2i, _sec: int) -> void:
	o.merge({"cell": e.secure_cell(target_sid, origin, "package"), "carrier": -1})


func before_check() -> void:   # a carrier who can't act drops the package on their square
	var carrier: int = o.get("carrier", -1)
	if carrier < 0 or e.units[carrier].c.can_act():
		return
	o.cell = e.units[carrier].pos
	o.carrier = -1
	e.events.append({"type": "drop", "unit": carrier, "cell": o.cell})
	e.say("%s drops the %s." % [e.units[carrier].c.display_name, item_short("package")])


func check_end() -> String:
	var carrier: int = o.carrier
	if carrier >= 0 and e.extract_cells.has(e.units[carrier].pos):
		o.done = true
		e.say("%s gets the %s out." % [e.units[carrier].c.display_name, item_short("package")])
		return "won"
	return ""


func actions() -> Array[String]:
	var out: Array[String] = []   # typed: a bare [] from a ternary comes back untyped
	if int(o.carrier) < 0 and _crew_beside(o.cell):
		out.append("grab")
	return out


func act(action: String) -> Dictionary:
	if action != "grab" or int(o.carrier) >= 0:
		return {"ok": false, "reason": "nothing to grab"}
	if not _crew_beside(o.cell):
		return {"ok": false, "reason": "get next to the package"}
	var r := _use_action()
	if not r.ok:
		return r
	o.carrier = e.cur.id
	e.events.append({"type": "grab", "unit": e.cur.id, "cell": o.cell})
	e.say("%s has the %s. Carry it to the extraction zone." % [e.cur.c.display_name, item_short("package")])
	e._check_end()
	return {"ok": true}


func hud_text() -> String:
	return "GET THE %s TO EXTRACTION" % item_marker("PACKAGE") if int(o.get("carrier", -1)) >= 0 else "RECOVER THE %s" % item_marker("PACKAGE")


func marks(_fog: bool) -> Array:
	if int(o.get("carrier", -1)) < 0:
		return [{"cell": o.cell, "h": 0.4, "label": "★ " + item_marker("PACKAGE"), "tone": "gold"}]
	return [_extract_mark()]


## Guards close on whoever carries the package; while it's on the floor, one in `keepers` stays
## within 3 squares of it.
func ai_pull(u: Dictionary, cell: Vector3i) -> float:
	if int(u.team) != Encounter.OPFOR:
		return 0.0
	var carrier: int = o.get("carrier", -1)
	if carrier >= 0:
		var cp: Vector3i = e.units[carrier].pos
		return -0.6 * Vector2(cp.x - cell.x, cp.y - cell.y).length() if cp.z == cell.z else 0.0
	var pk: Vector3i = o.cell
	if u.id % int(cfg.get("keepers", 3)) == 0 and pk.z == cell.z and Vector2(pk.x - cell.x, pk.y - cell.y).length() <= 3.0:
		return 10.0
	return 0.0


func ai_target_mult(t: Dictionary) -> float:
	return 1.6 if int(o.get("carrier", -1)) == t.id else 1.0   # stop the package leaving


func focus_cell() -> Vector3i:
	return o.cell
