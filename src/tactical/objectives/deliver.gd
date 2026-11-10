extends "res://src/tactical/objectives/snatch.gd"
## Deliver: the reverse of a snatch. The crew walks in carrying the package, leaves it at the drop
## point inside the target building (an Action beside it), then gets out through the deploy zone
## (or clears the site). A carrier who goes down drops it where they fall (snatch's before_check),
## and anyone can pick it up again (grab). State: {cell, carrier, drop, delivered}.


## The drop point: the target building's most secure square (where a snatch's package would be
## kept). The first of the crew carries the package in.
func setup(target_sid: int, origin: Vector2i, _sec: int) -> void:
	var carrier := -1
	for u in e.units:
		if int(u.team) == Encounter.CREW and not e.is_hostage(u):
			carrier = int(u.id)
			break
	var cell: Vector3i = e.units[carrier].pos if carrier >= 0 else Vector3i(origin.x, origin.y, e.m.street)
	o.merge({"cell": cell, "carrier": carrier, "drop": e.secure_cell(target_sid, origin, "package"), "delivered": false})


func check_end() -> String:
	return "won" if o.delivered else ""   # then the way out (Objective.extracting)


func actions() -> Array[String]:
	var out: Array[String] = []   # typed: a bare [] from a ternary comes back untyped
	if o.delivered or e.cur.is_empty():
		return out
	if int(o.carrier) < 0 and _crew_beside(o.cell):
		out.append("grab")
	elif int(o.carrier) == int(e.cur.id) and _crew_beside(o.drop):
		out.append("drop")
	return out


## Leave the package at the drop point (an Action, beside it or on it); grab picks it up off the
## floor again (snatch's act).
func act(action: String) -> Dictionary:
	if action == "grab":
		return super(action) if not o.delivered else {"ok": false, "reason": "it's delivered"}
	if action != "drop" or "drop" not in actions():
		return {"ok": false, "reason": "carry it to the drop point"}
	var r := _use_action()
	if not r.ok:
		return r
	o.delivered = true
	o.carrier = -1
	o.cell = o.drop
	o.done = true
	e.events.append({"type": "deliver", "unit": e.cur.id, "cell": o.drop})
	e.say("%s leaves the %s at the drop point. Get out." % [e.cur.c.display_name, item_short("package")])
	e._check_end()
	return {"ok": true}


func action_title(action: String) -> String:
	return "LEAVE PACKAGE" if action == "drop" else super(action)


func action_glyph(action: String) -> String:
	return "grab" if action == "drop" else super(action)


func hud_text() -> String:
	var what := item_marker("PACKAGE")
	if o.get("delivered", false):
		return "REACH EXTRACTION\n%s DELIVERED" % what
	if int(o.get("carrier", -1)) >= 0:
		return "DELIVER THE %s\nLEAVE IT AT THE DROP POINT" % what
	return "RECOVER THE %s\nTHEN GET IT TO THE DROP POINT" % what


func order() -> String:
	return "DELIVER THE %s" % item_marker("PACKAGE")


func current_step() -> String:
	if o.get("delivered", false):
		return "REACH EXTRACTION"
	return "LEAVE IT AT THE DROP POINT" if int(o.get("carrier", -1)) >= 0 else "PICK IT UP"


func marks(_fog: bool) -> Array:
	if o.get("delivered", false):
		return [_extract_mark()]
	if int(o.get("carrier", -1)) < 0:
		return [{"cell": o.cell, "h": 0.4, "label": "★ " + item_marker("PACKAGE"), "tone": "gold"}]
	return [{"cell": o.drop, "h": 0.6, "label": "★ DROP POINT", "tone": "gold"}]


## Guards close on the carrier and mind a package on the floor (snatch); once it's delivered they
## don't know it's there.
func ai_pull(u: Dictionary, cell: Vector3i) -> float:
	return 0.0 if o.get("delivered", false) else super(u, cell)


func ai_target_mult(t: Dictionary) -> float:
	return 1.0 if o.get("delivered", false) else super(t)


## Auto-play: the carrier to the drop point, the rest with them; a package on the floor first; out
## once it's delivered.
func crew_goal(u: Dictionary) -> Variant:
	if o.delivered:
		return e.extract_cells.keys()
	var carrier := int(o.carrier)
	if carrier < 0:
		return [o.cell]
	if carrier != int(u.id):
		var cp: Vector3i = e.units[carrier].pos
		if Vector2(cp.x - u.pos.x, cp.y - u.pos.y).length() + absi(cp.z - u.pos.z) * 4 > 4.0:
			return [cp]
	return [o.drop]


func focus_cell() -> Vector3i:
	return o.drop if not o.get("delivered", false) else o.cell
