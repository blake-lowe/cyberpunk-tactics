extends Objective
## Distraction: draw the site's response here and keep it busy. Raise the alarm (a guard calling it
## in, or the crew tripping the alarm panel inside the target building's door: an Action beside it),
## then hold out hold_rounds rounds, and until the response the call brought is here (if one is
## coming: Encounter.backup_in); then get out through the deploy zone (or clear the site). The owner's pick of the two plays the brief offered (the other: start a
## fight between two other sides) for being the simpler one to read and to play.
## State: {panel, alarm_round, need}.
##
## HOUSE-RULE: hold_rounds by security level (data/gen/objectives.json distraction).


## The alarm panel: the target building's square nearest the deploy zone by walking (its front
## door, the lobby), so the loud way in is always on offer.
func setup(target_sid: int, origin: Vector2i, sec: int) -> void:
	var field: Dictionary = e.nav.distance_field([Vector3i(origin.x, origin.y, e.m.street)], {}, 4000)
	var best := Vector3i(-1, -1, -1)
	var bd := 1 << 30
	for v in field:
		var l := e.m.label(v.z, v.x, v.y)
		if l < 0 or e.m.rooms[l].structure != target_sid or e.m.rooms[l].get("outdoor", false) or e.m.t(v.z, v.x, v.y) == TacMap.T.DOOR \
				or e.m.has_cover_at(v.z, Vector2i(v.x, v.y)):
			continue
		if int(field[v]) < bd or (int(field[v]) == bd and v < best):
			bd = int(field[v])
			best = v
	if best.x < 0:
		best = Vector3i(origin.x, origin.y, e.m.street)
	o.merge({"panel": best, "alarm_round": -1, "need": int((cfg.hold_rounds as Dictionary).get(str(clampi(sec, 1, 3)), 4))})


func alarm_up() -> bool:
	return int(o.get("alarm_round", -1)) >= 0


## Rounds still to hold out once the alarm is up (0 once done), or -1 before it.
func rounds_left() -> int:
	if not alarm_up():
		return -1
	return maxi(0, int(o.alarm_round) + int(o.need) - e.init.round_num)


## The alarm counts the moment it's raised (Encounter.alarm 2: someone called it in); the hold
## runs from that round.
func before_check() -> void:
	if not alarm_up() and e.alarm >= 2:
		o.alarm_round = e.init.round_num
		e.say("The alarm's up. Keep them busy for %d rounds." % int(o.need))


## The site's response still on its way (Encounter.backup_in counting down): the distraction is
## for them, so the crew holds until they're here.
func response_pending() -> bool:
	return e.backup_in > 0


func tick() -> void:
	before_check()
	if alarm_up() and not done() and rounds_left() <= 0 and not response_pending():
		o.done = true
		e.say("Every eye on the site is on the crew. Get out.")
		e._check_end()


func check_end() -> String:
	if done() and (e.opfor().is_empty() or e._crew_out()):
		e.say("The crew gets clear. The job's done.")
		return "won"
	return ""


func withdraw_wins() -> bool:
	return done()


func actions() -> Array[String]:
	var out: Array[String] = []   # typed: a bare [] from a ternary comes back untyped
	if not alarm_up() and e.alarm < 2 and _crew_beside(o.panel):
		out.append("alarm")
	return out


## Trip the alarm panel (an Action beside it): the site's alarm goes out as if a guard had called
## it in (Encounter.call_it_in: the radio rouses the guards nearby, the site's code and the
## street's are rolled for a response).
func act(action: String) -> Dictionary:
	if action != "alarm" or "alarm" not in actions():
		return {"ok": false, "reason": "get next to the alarm panel"}
	var r := _use_action()
	if not r.ok:
		return r
	e.say("%s trips the alarm." % e.cur.c.display_name)
	e.events.append({"type": "alarm_panel", "unit": e.cur.id, "cell": o.panel})
	e.call_it_in(e.cur)
	var called := "%s calls it in." % e.cur.c.display_name   # the panel calls it in, not the crew member
	if not e.log.is_empty() and e.log[-1].begins_with(called):
		e.log[-1] = "The alarm goes out." + e.log[-1].substr(called.length())
	e.alarm = 2   # with responses switched off (balance tests) nobody comes, but the alarm's still up
	var radio := float(e.doctrine.get("alarm", {}).get("radio_range", 20.0))   # the bell rouses the guards in radio range of it
	var p: Vector3i = o.panel
	e._rouse(e.units.filter(func(g): return e.is_guard(g) and e.hostile(int(g.team), Encounter.CREW) and not g.alerted and not g.c.dead \
		and Vector2(g.pos.x - p.x, g.pos.y - p.y).length() <= radio))
	before_check()
	e._check_end()
	return {"ok": true}


func action_title(action: String) -> String:
	return "TRIP ALARM" if action == "alarm" else super(action)


func action_glyph(action: String) -> String:
	return "tamper" if action == "alarm" else super(action)


func hud_text() -> String:
	if done():
		return "REACH EXTRACTION\nTHE DISTRACTION WORKED"
	if alarm_up():
		var left := rounds_left()
		var lines: Array[String] = ["KEEP THEM BUSY"]
		if left > 0:
			lines.append("%d MORE ROUND%s" % [left, "" if left == 1 else "S"])
		if response_pending():
			lines.append(("UNTIL %s ARRIVES · %d" if left <= 0 else "%s IN %d") % [e.backup_label, e.backup_in])
		return "\n".join(lines)
	return "RAISE THE ALARM\nTHEN HOLD OUT %d ROUNDS" % int(o.need)


func marks(_fog: bool) -> Array:
	if done():
		return [_extract_mark()]
	if alarm_up():
		return []
	return [{"cell": o.panel, "h": 1.2, "label": "★ ALARM PANEL", "tone": "red"}]


## Auto-play: to the panel until the alarm is up, then fight where they stand, then out.
func crew_goal(_u: Dictionary) -> Variant:
	if done():
		return e.extract_cells.keys()
	if alarm_up():
		return []
	return [o.panel]


func focus_cell() -> Vector3i:
	return o.panel
