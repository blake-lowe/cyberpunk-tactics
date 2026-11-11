extends TestCase
## Access-point way-finding (AccessPoints): which access points get the port icons (every one the
## crew has seen or Scanned) and which get an idle Netrunner's data lines (the ones a Scan found:
## Scanner, CPR core p.199), and the access point models.

static var _m: TacMap


func _enc() -> Array:
	if _m == null:
		_m = SceneGen.generate(11, "lone_building", {"site": "corp_office", "security": 2})
	var dice := Dice.new(4)
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	var e := Encounter.setup(_m, dice, crew)
	var runner: Dictionary = e.units[1]
	e.cur = runner
	e.turn = TurnState.begin(dice, runner.c)
	return [e, runner]


func test_every_access_point_is_listed_once() -> void:
	var r := _enc()
	var e: Encounter = r[0]
	var n := 0
	for sid in e.m.architectures:
		n += (e.m.architectures[sid] as NetArchitecture).access_points.size()
	assert_true(n > 0, "the site has a way in")
	assert_eq(AccessPoints.all(e).size(), n)
	assert_eq(AccessPoints.device_ids(e.m).size(), n, "the device look keys on them")


func test_icons_only_for_access_points_the_crew_has_seen() -> void:
	var r := _enc()
	var e: Encounter = r[0]
	var ap: Dictionary = AccessPoints.all(e)[0]
	e.vision.explored.erase(ap.cell)
	assert_false(AccessPoints.seen(e).any(func(p): return p.cell == ap.cell), "unseen: no icon")
	assert_true(AccessPoints.seen(e, false).any(func(p): return p.cell == ap.cell), "the fog off: every one")
	e.vision.explored[ap.cell] = true
	assert_true(AccessPoints.seen(e).any(func(p): return p.cell == ap.cell), "seen: its icon")


func test_scan_finds_access_points_by_the_roll_through_walls() -> void:
	var r := _enc()
	var e: Encounter = r[0]
	var runner: Dictionary = r[1]
	var ap: Dictionary = AccessPoints.all(e)[0]
	var c: Vector3i = ap.cell
	e.vision.explored.erase(c)
	assert_true(AccessPoints.scanned_for(e, runner).is_empty(), "nothing found before a Scan: no lines")
	assert_false(AccessPoints.seen(e).any(func(p): return p.cell == c), "nor an icon")
	runner.pos = c
	var res := e.scan_access_points()
	assert_true(res.ok)
	assert_false(e.turn.action_available, "a Meat Action (p.199)")
	assert_eq(float(res.range_m), maxf(0.0, int(res.check) * Encounter.SCAN_M_PER_POINT), "the roll x 2 m (HOUSE-RULE)")
	if float(res.range_m) >= 0.0:
		assert_true(e.scanned.has(c), "standing on it: found")
	assert_true(AccessPoints.seen(e).any(func(p): return p.cell == c), "found: its icon, seen or not")
	assert_true(AccessPoints.scanned_for(e, runner).any(func(p): return p.cell == c), "and its data line")
	assert_true(e.events.any(func(ev): return String(ev.type) == "scan"), "the view plays it")
	assert_false(e.scan_access_points().ok, "no Action left: no second Scan")
	var hits := AccessPoints.scanned_for(e, runner)
	for k in range(1, hits.size()):
		assert_true(float(hits[k - 1].dist_m) <= float(hits[k].dist_m), "nearest first")


func test_a_better_scan_reaches_further() -> void:
	var r := _enc()
	var e: Encounter = r[0]
	var runner: Dictionary = r[1]
	var near := 0
	var far := 0
	var aps := AccessPoints.all(e)
	for s in 30:   # every reach the dice give finds exactly the access points inside it
		e.scanned.clear()
		e.dice = Dice.new(s + 1)
		e.turn = TurnState.begin(e.dice, runner.c)
		var res := e.scan_access_points()
		for p in aps:
			var inside := Los.distance_m(runner.pos, p.cell) <= float(res.range_m)
			assert_eq(e.scanned.has(p.cell), inside, "found exactly within reach")
		if int(res.check) >= 14:
			far += 1
		elif int(res.check) <= 8:
			near += 1
	assert_true(far > 0 and near > 0, "the dice range")


func test_only_a_netrunner_scans_and_jacked_in_lines_go() -> void:
	var r := _enc()
	var e: Encounter = r[0]
	var runner: Dictionary = r[1]
	var solo: Dictionary = e.units[0]
	var ap: Dictionary = AccessPoints.all(e)[0]
	e.cur = solo
	e.turn = TurnState.begin(e.dice, solo.c)
	assert_false(e.scan_access_points().ok, "no Interface, no Scanner")
	assert_true(e.turn.action_available, "nothing spent")
	assert_true(Hud.role_action(solo.c).is_empty() or String(Hud.role_action(solo.c)[0]) != "scan")
	assert_eq(String(Hud.role_action(runner.c)[0]), "scan", "the Netrunner's role button is SCAN")
	e.scanned[ap.cell] = true
	assert_true(AccessPoints.scanned_for(e, solo).is_empty(), "no lines for a non-Netrunner")
	runner.pos = ap.cell
	e.cur = runner
	e.turn = TurnState.begin(e.dice, runner.c)
	assert_false(AccessPoints.scanned_for(e, runner).is_empty())
	assert_true(e.jack_in(e.jack_points(runner)[0]))
	assert_true(AccessPoints.scanned_for(e, runner).is_empty(), "jacked in: the lines go")


func test_access_points_come_in_every_model() -> void:
	var seen := {}
	for id in 16:
		var k := DeviceView.access_point_model(id)
		assert_true(k >= 0 and k < DeviceView.AP_MODELS)
		seen[k] = true
	assert_eq(seen.size(), DeviceView.AP_MODELS, "consecutive ids cycle through every model")
