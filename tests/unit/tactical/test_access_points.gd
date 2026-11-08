extends TestCase
## Access-point way-finding (AccessPoints): which access points get Alt's port icons (every one the
## crew has seen) and which get an idle Netrunner's data lines (seen, and reachable to jack in at
## this turn: within 6 m with no wall between, p198, from a square they stand on or can still reach).

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


func test_lines_go_to_seen_access_points_in_reach_this_turn() -> void:
	var r := _enc()
	var e: Encounter = r[0]
	var runner: Dictionary = r[1]
	var ap: Dictionary = AccessPoints.all(e)[0]
	var c: Vector3i = ap.cell
	e.vision.explored[c] = true
	# standing right by it: in reach from where they stand
	var near := Vector3i(-1, -1, -1)
	for v in e.nav.reachable(c, 2, e.occupied()):
		if v != c and not e._wall_between(v, c) and not e.occupied().has(v):
			near = v
			break
	assert_true(near.x >= 0, "a square beside the access point")
	runner.pos = near
	e.turn = TurnState.begin(e.dice, runner.c)
	var hits := AccessPoints.in_reach(e, runner)
	assert_true(hits.any(func(p): return p.cell == c), "beside it: a line")
	var hit: Dictionary = hits.filter(func(p): return p.cell == c)[0]
	assert_true(Los.distance_m(hit.from, c) <= Encounter.jack_range(runner.c), "from a square in jack range (p198)")
	# unseen: no line, even in reach
	e.vision.explored.erase(c)
	assert_false(AccessPoints.in_reach(e, runner).any(func(p): return p.cell == c), "unseen: no line")
	e.vision.explored[c] = true
	# out of this turn's reach: no line
	runner.pos = Vector3i(0, 0, 0)
	var far := Vector3i(-1, -1, -1)
	for v in e.nav.reachable(c, 200, {}):
		if Vector2(v.x - c.x, v.y - c.y).length() > 40 and v.z == c.z:
			far = v
			break
	if far.x >= 0:
		runner.pos = far
		e.turn = TurnState.begin(e.dice, runner.c)
		assert_false(AccessPoints.in_reach(e, runner).any(func(p): return p.cell == c), "too far to get there this turn")
	# a turn's moving spent: only where they stand counts
	runner.pos = near
	e.turn = TurnState.begin(e.dice, runner.c)
	e.turn.move_left = 0
	e.turn.action_available = false
	assert_true(AccessPoints.in_reach(e, runner).any(func(p): return p.cell == c), "already in range")


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
	assert_true(AccessPoints.in_reach(e, solo).is_empty(), "no Interface: no lines")
	runner.pos = ap.cell
	e.cur = runner
	e.turn = TurnState.begin(e.dice, runner.c)
	assert_false(AccessPoints.in_reach(e, runner).is_empty())
	assert_true(e.jack_in(e.jack_points(runner)[0]))
	assert_true(AccessPoints.in_reach(e, runner).is_empty(), "jacked in: the lines go")
