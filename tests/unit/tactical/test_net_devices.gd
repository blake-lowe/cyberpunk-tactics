extends TestCase
## Working held Control Nodes (CPR core p.199; NetDevices, Encounter.net_device): Control takes the
## node and changes nothing by itself; each device is then a NET Action, from anywhere in the NET,
## each node once per Turn (turrets' FIRE included); Jack Out hands it all back. Eye-Dee tells what
## a File is and its value.

static var _maps := {}


func _map(site: String, sec: int) -> TacMap:
	var key := "%s/%d" % [site, sec]
	if not _maps.has(key):
		_maps[key] = SceneGen.generate(11, "lone_building", {"site": site, "security": sec})
	return _maps[key]


## A fresh encounter on a cached map with the Netrunner jacked in at the first access point, every
## firewall open and the ICE derezzed: [e, runner, run].
func _jacked(site := "corp_office", sec := 2) -> Array:
	var m := _map(site, sec)
	var dice := Dice.new(3)
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	crew[1].role_rank = 6
	var e := Encounter.setup(m, dice, crew)
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
	return [e, runner, run]


## The control node with the most devices of `kind` (not the master override), or {}.
func _node_with(run: NetRun, e: Encounter, kind: String) -> Dictionary:
	var best := {}
	var bn := 0
	for n in run.arch.nodes_of_type("control"):
		var k := (n.devices as Array).filter(func(d): return String(e.m.devices[int(d)].type) == kind).size()
		if k > bn and String(n.group) != "master_cameras":
			best = n
			bn = k
	return best


func _devs(e: Encounter, n: Dictionary, kind: String) -> Array:
	return (n.devices as Array).filter(func(d): return String(e.m.devices[int(d)].type) == kind)


## The next turn of the runner (a fresh round, NET Actions back).
func _next_turn(e: Encounter, runner: Dictionary) -> void:
	e.init.round_num += 1
	e.cur = runner
	e.turn = TurnState.begin(e.dice, runner.c)
	e._netting = true
	e.net_left = 3


func _op(e: Encounter, uid: int, nid: int, op: String) -> Dictionary:
	for row in e.device_ops(uid):
		if int(row.node) == nid:
			for o in row.ops:
				if String(o.op) == op:
					return o
	return {}


func test_control_takes_the_node_and_changes_nothing_until_worked() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var run: NetRun = r[2]
	var n := _node_with(run, e, "camera")
	assert_false(n.is_empty(), "a cameras node")
	run.current = int(n.id)
	var res := {}
	for k in 30:
		e.net_left = 3
		res = e.net_action("control")
		if res.get("success", false):
			break
	assert_true(run.held.has(int(n.id)), "p199: the node is held")
	assert_true(e.log.any(func(l): return String(l).contains("takes the") and String(l).contains("camera")), "the log names what hangs off it")
	assert_true(e.events.any(func(ev): return String(ev.type) == "net_control" and ev.ok), "the view gets an event for the FX")
	for did in _devs(e, n, "camera"):
		assert_false(e.disabled_devices.has(int(did)), "taking the node doesn't switch anything off (p199: working it does)")
		assert_eq(e.device_holder(int(did)), int(r[1].id), "the runner holds it")
	var ops := e.device_ops(int(r[1].id))
	assert_eq(ops.size(), 1, "the NET panel lists the held node")
	assert_eq(String(ops[0].ops[0].op), "loop", "with its camera row")
	assert_eq(String(ops[0].ops[0].label), "LOOP FEED")


func test_held_camera_feeds_the_crew_what_it_sees() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var run: NetRun = r[2]
	var n := _node_with(run, e, "camera")
	var cam: Dictionary = e.m.devices[int(_devs(e, n, "camera")[0])]
	var watched := e.camera_cells(cam)
	assert_false(watched.is_empty())
	var far := watched.keys().filter(func(v): return not e.vision.visible.has(v))
	run.held[int(n.id)] = true
	e.refresh_vision()
	for v in watched:
		assert_true(e.vision.visible.has(v), "a held camera is a vision source (%s)" % v)
	if not far.is_empty():
		assert_true(e.vision.explored.has(far[0]), "what it shows stays explored")
	e.net_action("jack_out")
	e.refresh_vision()
	assert_true(far.is_empty() or not e.vision.visible.has(far[0]), "jacked out: the feed is gone")


func test_loop_is_a_net_action_once_per_node_per_turn() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var runner: Dictionary = r[1]
	var run: NetRun = r[2]
	var n := _node_with(run, e, "camera")
	var nid := int(n.id)
	run.held[nid] = true
	var cams := _devs(e, n, "camera")
	var left := e.net_left
	var res := e.net_device(nid, int(cams[0]))
	assert_true(res.ok, "looped")
	assert_eq(e.net_left, left - 1, "one NET Action")
	for did in cams:
		assert_true(e.disabled_devices.has(int(did)) and e.looped.has(int(did)), "every camera on the node (house rule: one camera system)")
	assert_true(e.log[-1].contains("loops"), "logged: %s" % e.log[-1])
	assert_true(e.events.any(func(ev): return String(ev.type) == "net_device" and String(ev.op) == "loop"))
	e.refresh_vision()
	var cam: Dictionary = e.m.devices[int(cams[0])]
	for v in e.camera_cells(cam):
		assert_true(e.vision.visible.has(v), "a loop fools the site, not the runner")
		break
	# a crew member in full view of a looped camera is never reported
	var crew: Dictionary = r[1]
	var spot: Vector3i = e.camera_cells(cam).keys()[0]
	var solo: Dictionary = e.units[0]
	solo.pos = spot
	solo.c.skills["stealth"] = 0
	assert_true(e._camera_spots().is_empty(), "looped: it reports nobody")
	# again this turn: refused, nothing spent
	var again := e.net_device(nid, int(cams[0]))
	assert_false(again.ok, "p199: each node once per turn")
	assert_eq(String(again.reason), "node already used this turn")
	assert_eq(e.net_left, left - 1, "nothing spent")
	assert_true(String(_op(e, int(crew.id), nid, "loop").why) != "", "the panel greys it out")
	_next_turn(e, runner)
	var back := e.net_device(nid, int(cams[0]))
	assert_true(back.ok and not back.on, "next turn: restored")
	assert_false(e.disabled_devices.has(int(cams[0])), "reporting again")


func test_door_lock_unlocks_and_locks_against_guards_too() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var runner: Dictionary = r[1]
	var run: NetRun = r[2]
	var n := _node_with(run, e, "door_lock")
	assert_false(n.is_empty(), "a locks node")
	var nid := int(n.id)
	run.held[nid] = true
	var lock: Dictionary = e.m.devices[int(_devs(e, n, "door_lock")[0])]
	var cell := Vector3i(lock.pos.x, lock.pos.y, lock.floor)
	assert_true(e.nav.locked.has(cell), "a security door starts locked")
	assert_eq(String(_op(e, int(runner.id), nid, "lock").label), "UNLOCK")
	var res := e.net_device(nid, int(lock.id))
	assert_true(res.ok and not res.on, "unlocked from the NET")
	assert_false(e.nav.locked.has(cell), "the crew can walk through")
	assert_true(e.disabled_devices.has(int(lock.id)), "the keypad lamp goes green")
	assert_true(e.log[-1].contains("unlocks"), e.log[-1])
	_next_turn(e, runner)
	e.los.open_doors[cell] = true   # someone opened it meanwhile
	var shut := e.net_device(nid, int(lock.id))
	assert_true(shut.ok and shut.on, "locked again")
	assert_true(e.nav.locked.has(cell) and e.sealed.has(cell), "sealed")
	assert_false(e.los.open_doors.has(cell), "it swings shut")
	assert_false(e.disabled_devices.has(int(lock.id)), "the lamp goes red")
	# a guard's keys don't open a lock the runner holds
	var g: Dictionary = e.opfor()[0]
	var keep: Dictionary = e.cur
	e.cur = g
	var guard_blocked: Dictionary = e._with_locks(func(): return {"open": e.nav.open(cell)})
	e.cur = keep
	assert_false(guard_blocked.open, "locked doors block enemy movement")
	# jack out: the site has its lock back, keys work again
	e.net_action("jack_out")
	assert_false(e.sealed.has(cell), "the seal goes with the node")
	assert_true(e.nav.locked.has(cell), "still a locked security door for the crew")
	e.cur = g
	var guard_open: Dictionary = e._with_locks(func(): return {"open": e.nav.open(cell)})
	e.cur = keep
	assert_true(guard_open.open, "guards carry the keys again")


func test_lock_refused_with_someone_in_the_doorway() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var runner: Dictionary = r[1]
	var run: NetRun = r[2]
	var n := _node_with(run, e, "door_lock")
	var nid := int(n.id)
	run.held[nid] = true
	var lock: Dictionary = e.m.devices[int(_devs(e, n, "door_lock")[0])]
	var cell := Vector3i(lock.pos.x, lock.pos.y, lock.floor)
	e.net_device(nid, int(lock.id))   # unlocked
	_next_turn(e, runner)
	e.units[0].pos = cell
	var left := e.net_left
	var res := e.net_device(nid, int(lock.id))
	assert_false(res.ok, "not on someone")
	assert_eq(String(res.reason), "someone is in the doorway")
	assert_eq(e.net_left, left, "nothing spent")


func test_refusals_cost_nothing() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var run: NetRun = r[2]
	var n := _node_with(run, e, "camera")
	var cam := int(_devs(e, n, "camera")[0])
	var left := e.net_left
	assert_false(e.net_device(int(n.id), cam).ok, "not held")
	run.held[int(n.id)] = true
	assert_false(e.net_device(int(n.id), 0 if cam != 0 else 1).ok or (n.devices as Array).has(0 if cam != 0 else 1), "a device not on that node")
	assert_eq(e.net_left, left)
	e.net_left = 0
	assert_false(e.net_device(int(n.id), cam).ok, "no NET Actions left")


func test_eye_dee_tells_what_the_file_is_and_its_value() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var run: NetRun = r[2]
	var target := int(e.objective.node)
	var other := -1
	for f in run.arch.nodes_of_type("file"):
		if int(f.id) != target:
			other = int(f.id)
	assert_true(other >= 0, "a File besides the target")
	run.current = other
	var res := {}
	for k in 30:
		e.net_left = 3
		res = e.net_action("eye_dee")
		if res.get("success", false):
			break
	assert_true(res.success, "identified")
	assert_true(String(res.what) != "" and int(res.value) >= 1 and int(res.value) <= 5, "what it is and its value (p199): %s" % res)
	assert_true(String(res.tier) in ["scrap", "routine", "useful", "valuable", "paydata"])
	assert_false(res.target, "not the job's File")
	assert_false(e.objective.done)
	assert_true(e.log.any(func(l): return String(l).begins_with("Eye-Dee: ") and String(l).contains("value %d/5" % int(res.value))), "logged")
	var ev: Array = e.events.filter(func(x): return String(x.type) == "eye_dee" and x.ok)
	assert_eq(ev.size(), 1, "an event for the reveal FX")
	assert_eq(String(ev[0].what), String(res.what))
	assert_true(run.action_block("eye_dee") != "", "once identified, done")
	# the target File: Eye-Dee confirms it and the job is done
	run.current = target
	for k in 30:
		e.net_left = 3
		res = e.net_action("eye_dee")
		if res.get("success", false):
			break
	assert_true(res.target, "the target File says so")
	assert_true(e.objective.done, "and is downloaded")
	assert_true(e.log.any(func(l): return String(l).contains("the target data")))


func test_eye_dee_names_a_file_by_its_room() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var run: NetRun = r[2]
	for f in run.arch.nodes_of_type("file"):
		var info := NetDevices.file_info(e, f)
		if f.has("label"):
			assert_eq(String(info.what), String(f.label), "net-only Files keep their label")
		elif int(f.get("device", -1)) >= 0:
			var room: Dictionary = e.m.rooms[int(e.m.devices[int(f.device)].room)]
			var want := String((NetDevices.db().files.rooms as Dictionary).get(String(room.kind), ""))
			if want != "":
				assert_eq(String(info.what), want, "what the %s holds" % room.kind)


func test_turret_fire_and_a_device_share_the_nodes_turn() -> void:
	var r := _jacked("bank", 3)
	var e: Encounter = r[0]
	var runner: Dictionary = r[1]
	var run: NetRun = r[2]
	var n := _node_with(run, e, "turret")
	if n.is_empty():
		assert_true(false, "the bank has a turret node")
		return
	# a camera on the turret's node too (synthetic), so one node has a device row and a FIRE row
	var t: Dictionary = e.m.devices[int(_devs(e, n, "turret")[0])]
	e.m.devices.append({"id": e.m.devices.size(), "type": "camera", "floor": t.floor, "pos": Vector2i(t.pos.x, t.pos.y), "room": t.room, "zone": t.zone, "group": n.group, "structure": t.structure})
	var cam := int(e.m.devices[-1].id)
	(n.devices as Array).append(cam)
	run.held[int(n.id)] = true
	e._retake_turrets()
	var ht := e.held_turrets(int(runner.id))
	assert_eq(ht.size(), 1, "the held turret is listed (its FIRE rows)")
	assert_true(e.net_device(int(n.id), cam).ok, "the camera worked")
	var tu: Dictionary = e.units[int(ht[0].id)]
	var g: Dictionary = e.opfor()[0]
	var fire := e.fire_turret(int(tu.id), int(g.id))
	assert_false(fire.ok, "p199: the node has acted this turn")
	assert_eq(String(fire.reason), "node already used this turn")
	assert_eq(String(e.held_turrets(int(runner.id))[0].why), "node already used this turn", "the FIRE row says why")
	e.net_action("jack_out")
	assert_false(tu.has("held_by"), "jack out: the turret goes back to the site")


func test_vault_seal_halt_lights_alarm_sprinklers_distract() -> void:
	var r := _jacked("bank", 3)
	var e: Encounter = r[0]
	var runner: Dictionary = r[1]
	var run: NetRun = r[2]
	var n := _node_with(run, e, "vault_lock")
	assert_false(n.is_empty(), "the bank's vault lock node")
	var nid := int(n.id)
	run.held[nid] = true
	var vl: Dictionary = e.m.devices[int(_devs(e, n, "vault_lock")[0])]
	var doors := NetDevices.door_cells(e, vl)
	assert_false(doors.is_empty(), "the vault room's doors")
	for c in doors:   # nobody in the way
		for u in e.units:
			if u.pos == c:
				u.pos = Vector3i(-50, -50, 0)
	assert_true(e.net_device(nid, int(vl.id)).ok, "sealed")
	for c in doors:
		assert_true(e.nav.locked.has(c) and e.sealed.has(c), "every door of the vault")
	# synthetic devices on the same held node: an elevator, a light rig, an alarm panel, sprinklers, a PA
	var room_id := int(vl.room)
	var add := func(kind: String, pos: Vector2i, fl: int, room: int) -> int:
		e.m.devices.append({"id": e.m.devices.size(), "type": kind, "floor": fl, "pos": pos, "room": room, "zone": 0, "group": n.group, "structure": vl.structure})
		(n.devices as Array).append(int(e.m.devices[-1].id))
		return int(e.m.devices[-1].id)
	var shaft := Vector2i(2, 2)
	for v in e.m.verticals:
		if String(v.type) == "elevator":
			shaft = v.pos
	var ev: int = add.call("elevator", shaft, 0, -1)
	_next_turn(e, runner)
	assert_true(e.net_device(nid, ev).ok, "halted")
	assert_true(e.nav.halted.has(shaft))
	var up := Vector3i(shaft.x, shaft.y, 0)
	assert_false(e.nav.neighbours(up, {}).any(func(l): return (l[0] as Vector3i).z != 0 and (l[0] as Vector3i).x == shaft.x and (l[0] as Vector3i).y == shaft.y), "nobody rides a halted car")
	var lit_room := -1
	for v in e.lit:
		var l := e.m.label(v.z, v.x, v.y)
		if l >= 0:
			lit_room = l
			break
	if lit_room >= 0:
		var lr: Dictionary = e.m.rooms[lit_room]
		var lights: int = add.call("light_rig", Vector2i(0, 0), int(lr.floor), lit_room)
		_next_turn(e, runner)
		assert_true(e.net_device(nid, lights).ok, "lights out")
		assert_false(e.lit.keys().any(func(v): return e.m.label(v.z, v.x, v.y) == lit_room), "the room is dark: -4 to spot anyone in it")
	var alarm: int = add.call("alarm_panel", Vector2i(0, 0), 0, room_id)
	_next_turn(e, runner)
	assert_true(e.net_device(nid, alarm).ok, "the alarm line cut")
	assert_true(NetDevices.alarm_cut(e))
	var spr: int = add.call("sprinkler_valve", Vector2i(0, 0), 0, room_id)
	var solo: Dictionary = e.units[0]
	var indoor := Vector3i(-1, -1, -1)
	for rm in e.m.rooms:
		if rm.cells > 0 and int(rm.get("structure", -1)) == int(vl.structure) and not rm.get("outdoor", false):
			var cs := Furnish.room_cells(e.m, rm)
			if not cs.is_empty():
				indoor = Vector3i(cs[0].x, cs[0].y, rm.floor)
				break
	solo.pos = indoor
	solo.c.burning = 2
	_next_turn(e, runner)
	assert_true(e.net_device(nid, spr).ok, "sprinklers")
	assert_eq(solo.c.burning, 0, "put out indoors")
	var g: Dictionary = {}
	for u in e.opfor():
		if not u.alerted and not u.c.dead and not u.has("turret"):
			g = u
			break
	if not g.is_empty():
		var pa: int = add.call("pa_system", Vector2i(g.pos.x + 3, g.pos.y), g.pos.z, -1)
		g["facing"] = Vector2(-1, 0)
		_next_turn(e, runner)
		assert_true(e.net_device(nid, pa).ok, "the PA pages someone")
		assert_true((g.facing as Vector2).dot(Vector2(1, 0)) > 0.9, "the guard looks round towards it")
	# jack out: everything back as the site had it
	e.net_action("jack_out")
	for c in doors:
		assert_false(e.sealed.has(c), "the vault seal goes")
	assert_false(e.nav.halted.has(shaft), "the elevator runs")
	assert_true(e.dark_rooms.is_empty(), "the lights come back")
	assert_false(NetDevices.alarm_cut(e), "the alarm line is restored")


func test_every_device_op_has_a_cited_card() -> void:
	var db := NetDevices.db()
	for kind in db.devices:
		var op := String(db.devices[kind].op)
		var id := "fire_turret" if op == "fire" else "dev_" + op
		var card := Hud.net_help(id)
		assert_true(card.begins_with("[b]"), "%s (%s) has a card" % [id, kind])
		assert_true(card.contains("CPR core p."), "%s cites its page" % id)
		assert_true(card.contains("NET Action"), "%s says what it costs" % id)
		assert_true(db.ops.has(op) or op == "fire", "%s has its row labels" % op)
	assert_true(Hud.net_help("held").contains("p.199"))
	assert_true(Hud.net_help("backdoor").contains("Password") and Hud.net_help("backdoor").contains("Virus"), "Backdoor: breaks a Password; lasting access is a Virus")
	assert_true(Hud.net_help("eye_dee").contains("worth"), "Eye-Dee: what it is worth")
