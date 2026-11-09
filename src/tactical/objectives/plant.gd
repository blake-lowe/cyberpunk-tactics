extends "res://src/tactical/objectives/data_theft.gd"
## Plant: the reverse of a data theft. Get a bug or false data into the target's system, either in
## the NET (a Netrunner reaches the target File's level and Eye-Dees it: the data goes in instead of
## out, NetRun as in a data theft) or by hand at the device in the target building's most secure
## room: plant_actions Actions beside it, over as many turns as it takes (HOUSE-RULE: a short job
## for anyone, no roll). Unlike a data theft, putting every guard down doesn't do it. Done is won,
## as a data theft's download is (no extraction phase after the objective).
## State: {structure, node (the NET target, -1 with no NET), cell (the device), device, name, progress}.


func setup(target_sid: int, origin: Vector2i, sec: int) -> void:
	super(target_sid, origin, sec)   # the NET's most valuable File, when the building has a NET
	var cell := e.secure_cell(target_sid, origin, "machine")
	var devices: Dictionary = cfg.devices
	var keys := devices.keys()
	var kind: String = keys[e.dice.d(keys.size()) - 1]
	var entry := Furnish.cover_entry("machine", cell.z, Vector2i(cell.x, cell.y), e.m.label(cell.z, cell.x, cell.y))
	entry.kind = kind
	e.m.add_cover(entry)
	e.los.cover_hp[cell] = int(entry.hp)
	o.merge({"cell": cell, "device": kind, "name": devices[kind], "progress": 0})


func plant_actions() -> int:
	return int(cfg.get("plant_actions", 2))


func check_end() -> String:
	if done():
		e.say("The plant is in. The job's done.")
		return "won"
	if e.los.cover_hp.get(o.cell, 1) <= 0 and int(o.get("node", -1)) < 0:
		e.say("%s is wrecked and there's no NET to go in by. The job's over." % String(o.name).capitalize())
		return "lost"
	return ""


func net_line() -> String:
	return ": the false data, planted"


func actions() -> Array[String]:
	var out: Array[String] = []   # typed: a bare [] from a ternary comes back untyped
	if not done() and e.los.cover_hp.get(o.cell, 0) > 0 and _crew_beside(o.cell):
		out.append("plant")
	return out


## One Action of the plant beside the device; the last one finishes it.
func act(action: String) -> Dictionary:
	if action != "plant" or "plant" not in actions():
		return {"ok": false, "reason": "get next to the device"}
	var r := _use_action()
	if not r.ok:
		return r
	o.progress = int(o.progress) + 1
	e.events.append({"type": "plant", "unit": e.cur.id, "cell": o.cell, "progress": int(o.progress)})
	var left := plant_actions() - int(o.progress)
	if left > 0:
		e.say("%s gets to work on %s: %d more Action%s." % [e.cur.c.display_name, o.name, left, "" if left == 1 else "s"])
	else:
		o.done = true
		e.say("%s finishes the plant on %s." % [e.cur.c.display_name, o.name])
		e._check_end()
	return {"ok": true}


func action_title(action: String) -> String:
	return String(_words()[1]) if action == "plant" else super(action)


func action_glyph(action: String) -> String:
	return "bypass" if action == "plant" else super(action)


## The order and the interact slot's title, by the gig's Mission Types row (GigSetup.name_focus
## sets o.mission): a bug, false data, a device to field-test (cfg orders), else a bug.
func _words() -> Array:
	return (cfg.get("orders", {}) as Dictionary).get(String(o.get("mission", "")), ["PLANT THE BUG", "PLANT BUG"])


func order() -> String:
	return String(_words()[0])


func hud_text() -> String:
	var what := String(o.name).trim_prefix("the ").to_upper()
	var lines: Array[String] = [order()]
	var it := item_marker("")
	if it != "":
		lines.append("IN THE %s" % it)
	if int(o.get("progress", 0)) > 0:
		lines.append("%d MORE ACTION%s AT THE %s" % [plant_actions() - int(o.progress), "" if plant_actions() - int(o.progress) == 1 else "S", what])
	else:
		lines.append("BY HAND AT THE %s" % what)
	if int(o.get("node", -1)) >= 0 and e.m.architectures.has(int(o.structure)):
		var fn: Dictionary = (e.m.architectures[int(o.structure)] as NetArchitecture).nodes[int(o.node)]
		lines.append("OR JACK IN: NET LEVEL %d" % int(fn.zone))
	return "\n".join(lines)


## The device; and while nobody on the crew is jacked in, the nearest Access Point into the NET.
func marks(fog: bool) -> Array:
	var out: Array = [{"cell": o.cell, "h": 1.6, "label": "★ PLANT · %s" % String(o.name).trim_prefix("the ").to_upper(), "tone": "cyan"}]
	out.append_array(super(fog))
	return out


## Auto-play: a Netrunner goes in by the NET (the soak's own data-theft play); everyone else heads
## for the device.
func crew_goal(u: Dictionary) -> Variant:
	if int(o.get("node", -1)) >= 0 and NetRun.interface_rank(u.c) > 0:
		return null
	return [o.cell]


func focus_cell() -> Vector3i:
	return o.cell
