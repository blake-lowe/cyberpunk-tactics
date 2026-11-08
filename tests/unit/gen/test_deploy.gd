extends TestCase
## Where the crew starts (SceneGen._deploy_zone, params.deploy in data/gen/scenes.json): "near" a
## short walk from the target's street door, or "far" at the spawn farthest from it (playtest
## round 4: a tester spent two minutes finding the door).


func _deploy(m: TacMap) -> Dictionary:
	for e in m.entrances:
		if e.kind == "deploy":
			return e
	return {}


## Walking squares from the deploy zone's first square to the step outside the main door (-1: none).
func _walk_to_door(m: TacMap) -> int:
	var d := _deploy(m)
	var door := m.main_entrance()
	if d.is_empty() or door.is_empty():
		return -1
	var nav := Nav.new(m)
	var field: Dictionary = nav.distance_field([Vector3i(door.pos.x, door.pos.y, m.street)], {}, 4000)
	return int(field.get(Vector3i(d.pos.x, d.pos.y, m.street), -1))


func _valid(m: TacMap, label: String) -> void:
	var d := _deploy(m)
	assert_false(d.is_empty(), "%s: a deploy zone" % label)
	if d.is_empty():
		return
	var cells: Array = d.cells
	assert_eq(cells.size(), SceneGen.DEPLOY_SIZE, "%s: room for the crew" % label)
	var reach := m.reachable(Vector3i(d.pos.x, d.pos.y, m.street))
	var door := m.main_entrance()
	for v in cells:
		assert_true(m.walkable(m.street, v), "%s: %s walkable" % [label, v])
		assert_eq(m.t(m.street, v.x, v.y), TacMap.T.OUTSIDE, "%s: %s outdoors, not in a building" % [label, v])
	if not door.is_empty():
		assert_true(reach.has(Vector3i(door.pos.x, door.pos.y, m.street)), "%s: the door is reachable from the zone" % label)


func test_every_scene_says_near_or_far() -> void:
	for id in SceneGen.scene_types():
		var p: Dictionary = RulesDB.gen("scenes.json")[id].get("params", {})
		assert_true(String(p.get("deploy", "")) in ["near", "far"], "%s has a deploy setting" % id)


func test_near_scenes_start_across_the_street_from_the_door() -> void:
	for scene in ["lone_building", "skirmish", "street_block", "megablock", "arcology"]:
		for s in [3, 8, 21]:
			var m := SceneGen.generate(s, scene, {"security": 2})
			var label := "%s seed %d" % [scene, s]
			_valid(m, label)
			assert_true(bool(_deploy(m).get("near", false)), "%s: deployed near" % label)
			var w := _walk_to_door(m)
			assert_true(w >= 0 and w <= SceneGen.DEPLOY_NEAR[2] + 2, "%s: %d squares' walk to the door" % [label, w])


func test_near_neighbourhood_and_set_piece() -> void:
	var m := SceneGen.generate(5, "neighborhood", {"security": 2, "profile": "mixed_residential"})
	_valid(m, "neighbourhood")
	assert_true(bool(_deploy(m).get("near", false)), "a city neighbourhood starts near")
	var sp := SceneGen.generate(4, "lone_building", {"setpiece": "totentanz"})
	_valid(sp, "totentanz")
	assert_true(bool(_deploy(sp).get("near", false)), "a plot set piece starts near")


func test_far_scenes_keep_the_long_approach() -> void:
	for scene in ["badlands", "warzone", "corp_campus"]:
		var m := SceneGen.generate(6, scene, {"security": 2})
		_valid(m, scene)
		assert_false(bool(_deploy(m).get("near", false)), "%s deploys far" % scene)
	var mx := SceneGen.generate(6, "lone_building", {"setpiece": "maxtac_hq"})
	assert_false(bool(_deploy(mx).get("near", false)), "a large compound set piece deploys far")


func test_the_caller_can_override_the_scene() -> void:
	var near := SceneGen.generate(9, "lone_building", {"security": 1})
	var far := SceneGen.generate(9, "lone_building", {"security": 1, "deploy": "far"})
	assert_true(bool(_deploy(near).get("near", false)))
	assert_false(bool(_deploy(far).get("near", false)))
	assert_true(_walk_to_door(near) < _walk_to_door(far), "near is nearer (%d vs %d)" % [_walk_to_door(near), _walk_to_door(far)])


func test_a_near_start_is_not_already_spotted() -> void:
	var dice := Dice.new(3)
	var spotted := 0
	var n := 0
	for scene in ["lone_building", "street_block", "megablock"]:
		for s in [2, 7, 13, 31]:
			var m := SceneGen.generate(s, scene, {"security": 2})
			var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
			var e := Encounter.setup(m, Dice.new(s), crew, "data")
			n += 1
			if e.alarm > 0 or e.units.any(func(u): return e.is_guard(u) and u.alerted):
				spotted += 1
	assert_true(spotted * 4 <= n, "at most a quarter of near starts begin with the guards alerted (%d of %d)" % [spotted, n])


## No NET access point within jack-in reach (SceneGen.AP_CLEAR_M, no wall between) of a deploy
## square or a crew start square (owner: a corp office crew deployed on a junction box and jacked
## in on turn 1). [scene, overrides, seed, security]: maps the generator survey caught (a junction
## box on the deploy zone; Totentanz's plaza camera beside it), and two that were always clear.
const AP_CASES := [["lone_building", {"site": "corp_office"}, 11, 2], ["lone_building", {"site": "gang_hideout"}, 1, 2],
	["lone_building", {"site": "ship"}, 1, 2], ["neighborhood", {"profile": "market_streets"}, 1, 2],
	["neighborhood", {"profile": "pacifica"}, 2, 3], ["lone_building", {"setpiece": "totentanz"}, 2, 3],
	["lone_building", {"setpiece": "totentanz"}, 1, 2], ["skirmish", {}, 3, 2], ["street_block", {}, 3, 2]]


func test_no_access_point_in_reach_of_the_start() -> void:
	var dice := Dice.new(4)
	var n := 0
	for cs in AP_CASES:
		var o: Dictionary = (cs[1] as Dictionary).duplicate()
		o["security"] = int(cs[3])
		var m := SceneGen.generate(int(cs[2]), String(cs[0]), o)
		var label := "%s %s seed %d" % [cs[0], cs[1], cs[2]]
		assert_eq(SceneGen.deploy_ap_clashes(m), [], "%s: deploy squares in jack-in reach of an access point" % label)
		var crew: Array[Combatant] = [Recruit.generate(dice, "netrunner", "edgerunner", "Patch"), Recruit.generate(dice, "solo", "edgerunner", "Vex")]
		var e := Encounter.setup(m, Dice.new(int(cs[2])), crew, "data")
		var los := Los.new(m)
		var aps := SceneGen.access_point_cells(m)
		n += aps.size()
		for u in e.units.filter(func(x): return x.team == Encounter.CREW):
			assert_eq(e.jack_points(u), [], "%s: %s can jack in from the start" % [label, u.c.display_name])
			assert_false(SceneGen.any_jack_reach(los, [u.pos], aps), "%s: %s starts within %d m of an access point" % [label, u.c.display_name, SceneGen.AP_CLEAR_M])
	assert_true(n > 0, "the sweep met some access points")
