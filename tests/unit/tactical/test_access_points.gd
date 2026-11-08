extends TestCase
## Access-point way-finding (AccessPoints): which access points get Alt's port icons (every one the
## crew has seen) and which get an idle Netrunner's data lines (sensed: within Interface x 4 m in a
## straight line, HOUSE-RULE), and the access point models.

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


func test_a_netrunner_senses_access_points_in_interface_range_through_walls() -> void:
	var r := _enc()
	var e: Encounter = r[0]
	var runner: Dictionary = r[1]
	var ap: Dictionary = AccessPoints.all(e)[0]
	var c: Vector3i = ap.cell
	var rng := AccessPoints.sense_range_m(runner.c)
	assert_eq(rng, NetRun.interface_rank(runner.c) * AccessPoints.SENSE_M_PER_RANK, "Interface x 4 m (HOUSE-RULE)")
	e.vision.explored.erase(c)
	runner.pos = c
	assert_true(AccessPoints.sensed(e, runner).any(func(p): return p.cell == c), "sensed even unseen")
	# just inside and just outside the range, in a straight line along the row (walls don't matter)
	var sq := int(floor(rng / 2.0))
	runner.pos = Vector3i(c.x + sq, c.y, c.z)
	assert_true(AccessPoints.sensed(e, runner).any(func(p): return p.cell == c), "at the edge of range")
	runner.pos = Vector3i(c.x + sq + 1, c.y, c.z)
	assert_false(AccessPoints.sensed(e, runner).any(func(p): return p.cell == c), "a square past it")
	# no MOVE in it: a runner who has spent their move senses the same
	runner.pos = c
	e.turn.move_left = 0
	e.turn.action_available = false
	assert_true(AccessPoints.sensed(e, runner).any(func(p): return p.cell == c))
	var hits := AccessPoints.sensed(e, runner)
	for k in range(1, hits.size()):
		assert_true(float(hits[k - 1].dist_m) <= float(hits[k].dist_m), "nearest first")


func test_no_lines_for_a_non_netrunner_or_once_jacked_in() -> void:
	var r := _enc()
	var e: Encounter = r[0]
	var runner: Dictionary = r[1]
	var solo: Dictionary = e.units[0]
	var ap: Dictionary = AccessPoints.all(e)[0]
	e.vision.explored[ap.cell] = true
	solo.pos = ap.cell
	e.cur = solo
	e.turn = TurnState.begin(e.dice, solo.c)
	assert_true(AccessPoints.sensed(e, solo).is_empty(), "no Interface: no lines")
	runner.pos = ap.cell
	e.cur = runner
	e.turn = TurnState.begin(e.dice, runner.c)
	assert_false(AccessPoints.sensed(e, runner).is_empty())
	assert_true(e.jack_in(e.jack_points(runner)[0]))
	assert_true(AccessPoints.sensed(e, runner).is_empty(), "jacked in: the lines go")


func test_access_points_come_in_every_model() -> void:
	var seen := {}
	for id in 16:
		var k := DeviceView.access_point_model(id)
		assert_true(k >= 0 and k < DeviceView.AP_MODELS)
		seen[k] = true
	assert_eq(seen.size(), DeviceView.AP_MODELS, "consecutive ids cycle through every model")
