extends TestCase
## Owner playtest v0.10.1: a data theft that ended when the guards broke (nobody had jacked in),
## extraction after every job, and the alarm saying why it went up.


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func _job(kind: String, site := "corp_office", sec := 2) -> Encounter:
	var m := SceneGen.generate(11, "lone_building", {"security": sec, "site": site})
	var dice := Dice.new(7)
	var e := Encounter.setup(m, dice, _crew(dice), kind)
	e.next_turn()
	return e


# --- The early end ------------------------------------------------------------------------------

## The bug (seeds 0, 1, 4 and more of an AI-vs-AI run of data gigs): one guard down, the leader
## among them, and Morale broke the rest (SPM p.20-21): some ran for the edge, some hid.
## Encounter.opfor() leaves those out, so data theft's "or eliminate all hostiles" read the site as
## cleared and won the gig, with the runners still on the map, their backup still coming and nobody
## jacked in.
func test_a_data_theft_does_not_end_when_the_guards_break() -> void:
	var e := _job("data")
	assert_true(e.obj.target_level() >= 0, "a NET target to steal from")
	var guards := e.units.filter(func(u): return int(u.team) == Encounter.OPFOR and not u.c.dead)
	assert_true(guards.size() >= 3, "a few guards")
	guards[0].c.dead = true   # one killed...
	for i in range(1, guards.size()):   # ...and the rest break (Morale.sweep's two outcomes)
		if i % 2 == 0:
			e.start_hiding(guards[i], "leader", 2, 4)
		else:
			e.start_flight(guards[i], "leader", 2, 4)
	e.backup_in = 4   # the alarm's up: "Gold Dragons in 4 rounds"
	assert_true(e.opfor().is_empty(), "nobody left counts as opposition: what the old fallback read as cleared")
	e._check_end()
	assert_eq(e.state, "playing", "the gig goes on: the data isn't theirs yet")
	assert_false(e.obj.extracting(), "and the job isn't done")
	assert_eq(e.obj.step(), "GET TO AN ACCESS POINT")
	assert_false(e.obj.hud_text().contains("ELIMINATE"), "no clear-the-site alternative while there's a File to pull")
	e.backup_in = -1
	e._check_end()
	assert_eq(e.state, "playing", "nor once the backup's in")


func test_clearing_a_site_waits_for_the_backup_that_is_coming() -> void:
	var e := _job("eliminate", "gang_hideout")
	for u in e.opfor():
		u.c.dead = true
	e.backup_in = 3
	e._check_end()
	assert_false(e.obj.extracting(), "backup on its way: not cleared")
	e.backup_in = -1
	e._check_end()
	assert_true(e.obj.extracting(), "all down, nobody coming: the job's done")


# --- Extraction after every job -----------------------------------------------------------------

## Finish `e`'s job by its own rules (what each module's check_end reads).
func _finish(e: Encounter) -> void:
	var o := e.objective
	match String(o.kind):
		"eliminate":
			for u in e.opfor():
				u.c.dead = true
			e.backup_in = -1
		"snatch":
			o.carrier = e.units[0].id
			e.units[0].pos = e.extract_cells.keys()[0]
		"rescue":
			var cap: Dictionary = e.units[int(o.captive)]
			o.freed = true
			cap.pos = e.extract_cells.keys()[1]
		"escort":
			var cu: Dictionary = e.units[int(o.client)]
			o.met = true
			cu.pos = (o.dest as Array)[0]
		"deliver":
			o.delivered = true
		"assassinate":
			e.units[int(o.target)].c.dead = true
		_:   # data, sabotage, plant, distraction, defend: done() is the job
			o.done = true


## A free square no way out reaches, for `u` to stand on.
func _away(e: Encounter, u: Dictionary) -> Vector3i:
	var out := {}
	for c in e.obj.exit_cells():
		out[c] = true
	var occ := e.occupied(u)
	var reach: Dictionary = e.nav.reachable(u.pos, 30, occ)
	var best: Vector3i = u.pos
	var bd := -1
	for v in reach:
		if not out.has(v) and not occ.has(v) and int(reach[v]) > bd and int(reach[v]) <= 20:
			bd = int(reach[v])
			best = v
	return best


func test_every_job_ends_with_the_way_out() -> void:
	for kind in Objective.kinds():
		var e := _job(String(kind))
		e.reinforcements = false
		var crew := e.units.filter(func(u): return int(u.team) == Encounter.CREW and not e.is_hostage(u))
		for u in crew:
			u.pos = _away(e, u)
		_finish(e)
		if String(kind) == "snatch":
			crew[1].pos = _away(e, crew[1])
		e._check_end()
		assert_eq(e.state, "playing", "%s: the job done doesn't end the gig on the spot" % kind)
		assert_true(e.obj.extracting(), "%s: the job's done, the way out is left" % kind)
		assert_eq(e.obj.step(), "REACH EXTRACTION", "%s: the round tab's step" % kind)
		var mk: Array = e.obj.shown_marks(true)
		assert_true(mk.size() == 1 and bool(mk[0].get("extract", false)), "%s: the marker points at extraction" % kind)
		assert_true(e.obj_actions().is_empty() or String(kind) in ["snatch"], "%s: nothing left to do but leave" % kind)
		var exits: Array = e.obj.exit_cells()
		var occ := {}
		for u in crew:   # everyone standing steps into the zone
			for c in exits:
				if not occ.has(c) and not e.occupied(u).has(c):
					u.pos = c
					occ[c] = true
					break
		e._check_end()
		assert_eq(e.state, "won", "%s: the crew is out: won" % kind)
		assert_true(e.log.any(func(l): return l.contains("The crew gets clear")), "%s: and the log says so" % kind)


func test_withdrawing_before_the_job_is_done_still_abandons_it() -> void:
	var e := _job("data")
	for u in e.units.filter(func(u): return int(u.team) == Encounter.CREW):
		assert_true(e.extract_cells.has(u.pos), "the crew starts in the zone")
	assert_true(e.withdraw(), "can pull out")
	assert_eq(e.state, "fled", "the job not done: abandoned")


# --- Why the alarm went up ----------------------------------------------------------------------

func test_a_guard_who_saw_the_crew_calls_the_alarm_in_with_the_reason() -> void:
	var e := _job("data", "corp_office", 3)
	e.reinforcements = true
	var vex: Dictionary = e.units[0]
	var cams := e.m.devices.filter(func(d): return String(d.type) == "camera")
	var g: Dictionary = {}
	for u in e.units.filter(func(u): return int(u.team) == Encounter.OPFOR and not u.alerted and not u.c.dead):
		for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
			var v: Vector3i = u.pos + d
			# beside a guard, out of every camera's view: the guard's eyes are the ones that catch Vex
			if e.m.walkable(v.z, Vector2i(v.x, v.y)) and not e.occupied().has(v) and e.los.trace(u.pos, v).clear \
					and not cams.any(func(c): return e.camera_sees(c, v)):
				vex.pos = v
				g = u
				break
		if not g.is_empty():
			break
	assert_false(g.is_empty(), "a guard with a square beside them no camera watches")
	e._spot_rolls[[g.id, vex.id, e.init.round_num]] = true   # the contest went the guard's way
	e.update_alerts()
	assert_true(g.alerted, "spotted")
	assert_eq(String(g.alert_why), "%s SAW VEX" % String(g.c.display_name).to_upper())
	e.call_it_in(g)   # on the guard's turn
	assert_eq(e.alarm_cause, "%s SAW VEX" % String(g.c.display_name).to_upper())
	assert_true(e.log.has("Alarm: %s saw Vex." % g.c.display_name), "the log says why: " + str(e.log.slice(-3)))
	var ev: Array = e.events.filter(func(x): return String(x.type) == "alarm")
	assert_eq(String(ev[-1].cause), e.alarm_cause, "the alarm event carries it for the callout")
	assert_eq(Hud.alarm_callout(e.alarm_cause), "%s SAW VEX: ALARM" % String(g.c.display_name).to_upper())


func test_a_camera_names_who_it_caught() -> void:
	var e := _job("data", "corp_office", 3)
	e.reinforcements = true
	var cams := e.m.devices.filter(func(d): return String(d.type) == "camera")
	assert_false(cams.is_empty(), "the office has cameras")
	var vex: Dictionary = e.units[0]
	var placed := false
	for d in cams:
		for v in e.camera_cells(d):
			if e.m.walkable(v.z, Vector2i(v.x, v.y)) and not e.occupied(vex).has(v) and e.camera_sees(d, v):
				vex.pos = v
				e._spot_rolls[["cam", d.id, vex.id, e.init.round_num]] = true
				e.cam_flagged[d.id] = {vex.id: true}   # caught once before: this sighting sends a guard (HOUSE-RULE)
				placed = true
				break
		if placed:
			break
	assert_true(placed, "somewhere a camera watches")
	for u in e.units:   # nobody sees Vex but the camera
		if int(u.team) == Encounter.OPFOR:
			u.erase("why_next")
			e._spot_rolls[[u.id, vex.id, e.init.round_num]] = false
	e.update_alerts()
	var cam_ev: Array = e.events.filter(func(x): return String(x.type) == "camera")
	assert_eq(cam_ev.size(), 1, "the camera caught Vex")
	var g: Dictionary = e.units[int(cam_ev[0].unit)]
	assert_eq(String(g.alert_why), "CAMERA SPOTTED VEX", "the guard it sent knows why")
	assert_true(e.alarm < 2, "not the alarm yet: the guard calls it in on their turn (time to react)")
	e.call_it_in(g)
	assert_eq(e.alarm_cause, "CAMERA SPOTTED VEX")
	assert_true(e.log.has("Alarm: Camera spotted Vex."), str(e.log.slice(-3)))
	assert_eq(Hud.alarm_callout(e.alarm_cause), "CAMERA SPOTTED VEX: ALARM")


func test_gunfire_and_the_clock_name_themselves() -> void:
	var e := _job("data", "corp_office", 3)
	e.reinforcements = true
	var g: Dictionary = e.units.filter(func(u): return int(u.team) == Encounter.OPFOR and not u.c.dead)[0]
	e._noise(g.pos)
	assert_eq(String(g.alert_why), "SHOTS HEARD")
	var f := _job("data", "corp_office", 3)
	f.reinforcements = true
	Clocks.raise_alarm(f)
	assert_eq(f.alarm_cause, Clocks.ALARM_WHY, "the detection clock ran out")
	assert_eq(Hud.alarm_callout(f.alarm_cause), "", "that one has its own DETECTED banner")


# --- A held camera still reports until it's looped ----------------------------------------------

## Owner: held the camera's Control Node, didn't Loop it, and got caught with nothing saying the
## camera was still live. Holding the node only feeds the runner; the Loop NET action blinds it.
func test_a_held_camera_still_reports_until_it_is_looped() -> void:
	var m := SceneGen.generate(11, "lone_building", {"site": "corp_office", "security": 2})
	var dice := Dice.new(3)
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	crew[1].role_rank = 6
	var e := Encounter.setup(m, dice, crew)
	e.reinforcements = true
	var runner: Dictionary = e.units[1]
	var a: NetArchitecture = m.architectures[m.architectures.keys()[0]]
	var ap: Dictionary = m.devices[a.access_points[0].device]
	runner.pos = Vector3i(ap.pos.x, ap.pos.y, ap.floor)
	e.cur = runner
	e.turn = TurnState.begin(dice, runner.c)
	assert_true(e.jack_in(e.jack_points(runner)[0]), "jacked in")
	var run: NetRun = e.runs[runner.id]
	for n in run.arch.nodes_of_type("firewall"):
		run.broken[n.id] = true
	for i in run.arch.ice:
		i["derezzed"] = true
	var node := {}
	for n in run.arch.nodes_of_type("control"):
		if (n.devices as Array).any(func(d): return String(m.devices[int(d)].type) == "camera") and String(n.group) != "master_cameras":
			node = n
			break
	assert_false(node.is_empty(), "a camera node")
	if node.is_empty():
		return
	run.held[int(node.id)] = true   # held: the runner has the feed
	var cid: int = (node.devices as Array).filter(func(d): return String(m.devices[int(d)].type) == "camera")[0]
	var cam: Dictionary = m.devices[cid]
	var vex: Dictionary = e.units[0]
	vex.pos = e.camera_cells(cam).keys()[0]
	vex.c.skills["stealth"] = 0
	e._spot_rolls[["cam", cid, vex.id, e.init.round_num]] = true
	e.cam_flagged[cid] = {vex.id: true}   # caught once before: this sighting sends a guard (HOUSE-RULE)
	assert_eq(Hud.loop_tag(_loop_row(e, int(runner.id), int(node.id))), " · STILL REPORTING", "the NET row says the camera is still live")
	var g := e._camera_spots()
	assert_false(g.is_empty(), "held but not looped: it still reports")
	if g.is_empty():
		return
	e._rouse([g])
	e.call_it_in(g)
	assert_eq(e.alarm_cause, "CAMERA SPOTTED VEX", "and the alarm says it was the camera")
	assert_eq(Hud.alarm_callout(e.alarm_cause), "CAMERA SPOTTED VEX: ALARM", "plain: no HELD/NOT LOOPED in it (owner)")
	e.alarm = 0   # back to quiet, to see the loop work
	assert_true(e.net_device(int(node.id), cid).ok, "looped")
	assert_eq(Hud.loop_tag(_loop_row(e, int(runner.id), int(node.id))), " · LOOPED")
	e.init.round_num += 1
	e._spot_rolls[["cam", cid, vex.id, e.init.round_num]] = true
	assert_true(e._camera_spots().is_empty(), "looped: it reports nobody")


func _loop_row(e: Encounter, uid: int, nid: int) -> Dictionary:
	for r in NetDevices.rows(e, uid):
		if int(r.node) == nid:
			for o in r.ops:
				if String(o.op) == "loop":
					return o
	return {}
