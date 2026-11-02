extends TestCase


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func test_setup_places_crew_and_guards() -> void:
	var m := SceneGen.generate(11, "street_block", {"security": 2})
	var dice := Dice.new(1)
	var e := Encounter.setup(m, dice, _crew(dice))
	assert_eq(e.units.filter(func(u): return u.team == 0).size(), 2)
	assert_eq(e.units.filter(func(u): return u.team == 1).size(), 7, "3 + 2 per security level")
	for u in e.units:
		assert_true(m.walkable(u.pos.z, Vector2i(u.pos.x, u.pos.y)), "%s placed on open ground" % u.c.display_name)
	assert_true(e.objective.get("node", -1) >= 0, "the target NET has a File to steal")


func test_shooting_cover_destroys_it_and_opens_sight() -> void:
	var m := TacMap.new(8, 3, 1)
	for y in 3:
		for x in 8:
			m.set_t(0, x, y, TacMap.T.FLOOR)
	m.add_cover(Furnish.cover_entry("desk", 0, Vector2i(4, 1), -1))  # wood thin, 5 HP
	m.entrances.append({"floor": 0, "pos": Vector2i(1, 1), "kind": "deploy", "main": false, "cells": [Vector2i(1, 1)]})
	var dice := Dice.new(3)
	var crew: Array[Combatant] = [Fixtures.shooter("A")]
	crew[0].weapons.append(Weapon.from_id("heavy_pistol"))
	var e := Encounter.setup(m, dice, crew)
	e.cur = e.units[0]
	e.turn = TurnState.begin(dice, crew[0])
	var target := Vector3i(7, 1, 0)
	assert_false(e.los.sight(Vector3i(1, 1, 0), target).visible, "desk blocks the line")
	var r := e.shoot_cover(Vector3i(4, 1, 0), crew[0].weapons[0])
	assert_true(r.ok)
	assert_eq(r.left, 0, "3d6 always beats a 5 HP desk")
	assert_true(e.los.trace(Vector3i(1, 1, 0), target).clear, "sight opens")
	assert_true(m.walkable(0, Vector2i(4, 1)), "and so does the path")


func test_netrunner_unlocks_doors_and_steals_the_file() -> void:
	var m := SceneGen.generate(11, "lone_building", {"site": "corp_office", "security": 1})
	var dice := Dice.new(9)
	var e := Encounter.setup(m, dice, _crew(dice))
	var runner: Dictionary = e.units[1]
	var a: NetArchitecture = m.architecture
	# Put the runner beside the first access point and jack in.
	var ap_dev: Dictionary = m.devices[a.access_points[0].device]
	runner.pos = Vector3i(ap_dev.pos.x, ap_dev.pos.y, ap_dev.floor)
	e.cur = runner
	e.turn = TurnState.begin(dice, runner.c)
	assert_false(e.jack_points(runner).is_empty(), "access point in range")
	assert_true(e.jack_in(e.jack_points(runner)[0]))
	var run: NetRun = e.runs[runner.id]
	# Clear the way for the test: break every firewall and derez the ICE, then walk to the File.
	for n in a.nodes_of_type("firewall"):
		run.broken[n.id] = true
	for i in a.ice:
		i["derezzed"] = true
	assert_true(run.move_to(e.objective.node), "path to the target File")
	var tries := 0
	while not e.objective.done and tries < 40:
		e.net_left = 3
		e.net_action("eye_dee")
		tries += 1
	assert_true(e.objective.done, "Eye-Dee on the target File completes the objective")
	e._check_end()
	assert_eq(e.state, "won")


func test_auto_battle_runs_to_an_end() -> void:
	for seed in [5, 6]:
		var m := SceneGen.generate(seed, "lone_building", {"site": "warehouse", "security": 0})
		var dice := Dice.new(seed)
		var e := Encounter.setup(m, dice, _crew(dice))
		var guard := 0
		e.next_turn()
		while e.state == "playing" and guard < 400:
			AI.act(e, e.cur)
			e.end_turn()
			e.next_turn()
			guard += 1
		assert_true(e.log.size() > 0, "things happened")
		assert_true(e.state in ["won", "lost", "playing"])
