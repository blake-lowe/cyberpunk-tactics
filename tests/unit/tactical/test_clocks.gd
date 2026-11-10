extends TestCase
## Solo Play Clocks in the encounter (Clocks; SPM p.25-26): the detection clock on a stealth gig,
## its triggers, emptying into the alarm (the NC2045 response timer after the call), Degrees of
## Consequence and winning dice back.

static var _maps := {}


func _map(site := "corp_office", sec := 1) -> TacMap:
	var key := "%s/%d" % [site, sec]
	if not _maps.has(key):
		_maps[key] = SceneGen.generate(11, "lone_building", {"site": site, "security": sec})
	return _maps[key]


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


## A gig with the clock as a campaign gig gets it ("auto"), on a code that always answers.
func _enc(kind := "data", sec := 1, opts: Dictionary = {}) -> Encounter:
	var dice := Dice.new(3)
	var o := {"clocks": "auto", "security_code": {"n": 11, "faction": "", "intensity": "medium", "hardened": false}}
	o.merge(opts, true)
	var e := Encounter.setup(_map("corp_office", sec), dice, _crew(dice), kind, o)
	e.next_turn()
	return e


func _det(e: Encounter) -> Clock:
	return Clocks.get_clock(e, "detection")


func test_a_stealth_gig_runs_a_detection_clock_sized_by_security() -> void:
	var want := {1: [6, [1]], 2: [5, [1]], 3: [5, [1, 6]]}   # HOUSE-RULE pools (clocks.json); 2 is the book's Corporate Heist 5d6
	for sec in want:
		var e := _enc("data", sec)
		var c := _det(e)
		assert_true(c != null, "security %d: a clock" % sec)
		assert_eq(c.size, int(want[sec][0]), "security %d pool" % sec)
		assert_eq(c.drop_on, want[sec][1], "security %d drops on" % sec)
		assert_true(c.running() and c.pool == c.size)
	assert_true(_det(_enc("eliminate")) == null, "a straight gang hit isn't a stealth gig")
	var dice := Dice.new(3)
	var plain := Encounter.setup(_map(), dice, _crew(dice))
	assert_true(plain.clocks.is_empty(), "tests and tools run none unless asked")
	assert_true(Campaign.encounter_opts({"faction": "arasaka"}).get("clocks") == "auto", "campaign gigs ask for it")


func test_a_failed_bypass_and_crew_noise_roll_it() -> void:
	var e := _enc()
	var c := _det(e)
	var before := c.rolls
	Clocks.trigger(e, "failed_tech", int(e.cur.id), "test")
	assert_eq(c.rolls, before + 1, "every failed Electronics/Security Tech check rolls")
	Clocks.trigger(e, "noise", int(e.cur.id), "test")
	Clocks.trigger(e, "noise", int(e.cur.id), "test")
	assert_eq(c.rolls, before + 2, "noise: once a turn")
	e._noise(e.cur.pos)
	assert_eq(c.rolls, before + 2, "the crew's gunfire this turn already rolled")
	assert_true(e.events.any(func(ev): return String(ev.type) == "clock" and String(ev.clock) == "detection"), "the view gets a clock event")


func test_a_minute_in_a_secured_room_rolls_it() -> void:
	var e := _enc()
	var c := _det(e)
	var secure := Vector3i(-1, -1, -1)
	for f in e.m.floors:
		for y in e.m.h:
			for x in e.m.w:
				var l := e.m.label(f, x, y)
				if secure.x < 0 and l >= 0 and int(e.m.rooms[l].zone) >= TacMap.Zone.SECURE and e.m.walkable(f, Vector2i(x, y)):
					secure = Vector3i(x, y, f)
	assert_true(secure.x >= 0, "the office has a secured room")
	e.units[0].pos = secure
	var r0 := c.rolls
	Clocks.round_start(e)
	assert_eq(c.rolls, r0, "the first round there: nothing yet")
	e.init.round_num += 1
	Clocks.round_start(e)
	assert_eq(c.rolls, r0 + 1, "a minute (two rounds, the HOUSE-RULE pace) in one secured room")
	Clocks.round_start(e)
	assert_eq(c.rolls, r0 + 1, "once a round")


func test_it_empties_into_the_alarm_and_the_response_timer() -> void:
	var e := _enc()
	var c := _det(e)
	assert_eq(e.alarm, 0)
	c.pool = 1
	var r := Clocks.trigger(e, "failed_tech", int(e.cur.id), "test", [1])
	assert_true(bool(r[0].emptied))
	assert_true(c.is_empty())
	assert_eq(e.alarm, 2, "the alarm is up, nobody having seen the crew")
	assert_true(e.backup_in > 0, "the site's code answered: the NC2045 response time counts down (%d)" % e.backup_in)
	assert_true(e.log.any(func(l): return String(l).contains("detection clock runs out")))
	assert_true(e.log.any(func(l): return String(l).contains("calls it in")), "a guard calls it in")
	assert_false(c.escalated, "one die: the plain outcome")
	Clocks.trigger(e, "failed_tech", int(e.cur.id), "test")
	assert_eq(c.rolls, 1, "an empty clock rolls no more")


func test_degrees_of_consequence_send_a_heavier_response() -> void:
	var e := _enc()
	var c := _det(e)
	c.pool = 2
	Clocks.trigger(e, "failed_tech", int(e.cur.id), "test", [1, 1])
	assert_true(c.escalated)
	assert_eq(e.alarm, 2)
	assert_eq(String(e._response.code.intensity), "heavy", "Medium one step up (NC2045 p.7)")
	assert_true(e.events.any(func(ev): return String(ev.type) == "clock_escalate"))


func test_being_seen_still_raises_the_alarm_and_stops_the_clock() -> void:
	var e := _enc()
	var g: Dictionary = e.units.filter(func(u): return int(u.team) == Encounter.OPFOR and not u.c.dead)[0]
	g.alerted = true
	e.call_it_in(g)
	assert_eq(e.alarm, 2, "sight-based detection works as before")
	assert_eq(_det(e).state, "stopped", "the clock is moot")
	assert_true(e.events.any(func(ev): return String(ev.type) == "clock_stop"))


func test_spoof_wins_a_die_back_or_rolls_the_clock() -> void:
	var won := 0
	var lost := 0
	for s in 40:
		var dice := Dice.new(s + 1)
		var e := Encounter.setup(_map(), dice, _crew(dice), "data", {"clocks": true})
		e.next_turn()
		var cam := {}
		for d in e.m.devices:
			if String(d.type) == "camera" and not e.disabled_devices.has(d.id):
				cam = d
				break
		if cam.is_empty():
			continue
		var c := _det(e)
		c.pool = c.size - 1
		e.cur.pos = Vector3i(cam.pos.x, cam.pos.y, cam.floor)
		e.turn = TurnState.begin(dice, e.cur.c)
		assert_true(Clocks.can_spoof(e), "a camera in reach, a die to win")
		assert_eq(Hud.interact_here(e)[0], "spoof", "the bar offers SPOOF")
		var rolls := c.rolls
		var r := Clocks.spoof(e)
		assert_true(r.ok)
		assert_false(e.turn.action_available, "an Action")
		if r.success:
			won += 1
			assert_eq(c.pool, c.size, "a die back")
			assert_true(e.looped.has(int(cam.id)), "the feed looped by hand")
			assert_true(Clocks.reclaimable(e) == null, "once per clock a turn")
		else:
			lost += 1
			assert_eq(c.rolls, rolls + 1, "a failed check rolls the clock (the risk)")
	assert_true(won > 0 and lost > 0, "both outcomes come up (%d won, %d lost)" % [won, lost])


func test_looping_cameras_from_the_net_wins_a_die_back_once_per_device() -> void:
	var e := _enc()
	var c := _det(e)
	c.pool = c.size - 2
	var cam := -1
	for d in e.m.devices:
		if String(d.type) == "camera":
			cam = int(d.id)
	Clocks.on_net_device(e, cam, "loop", true)
	assert_eq(c.pool, c.size - 1, "a die back")
	assert_true(e.events.any(func(ev): return String(ev.type) == "clock_add"))
	Clocks.on_net_device(e, cam, "loop", true)
	assert_eq(c.pool, c.size - 1, "not twice in a turn, nor twice for one device")
	e.init.round_num += 1
	Clocks.on_net_device(e, cam, "loop", true)
	assert_eq(c.pool, c.size - 1, "that device has fooled them once already")
	Clocks.on_net_device(e, cam, "loop", false)
	assert_eq(c.pool, c.size - 1, "restoring a feed wins nothing")
