extends TestCase
## Floor navigation (playtest round 4: a tester never found the upper floor): stair links, GO UP /
## GO DOWN, the camera following a move to another floor, the objective's direction, the stairs
## that hint toward it, blueprint storeys.
## Hand-built 10 x 8, three floors, all floor: a stair shaft at (1, 1) through floors 0-2, a second
## at (8, 6) between floors 0 and 1 only, a ladder from (5, 7, 0) to (5, 7, 1).

var m: TacMap


func before_each() -> void:
	m = TacMap.new(10, 8, 3)
	for f in 3:
		for y in 8:
			for x in 10:
				m.set_t(f, x, y, TacMap.T.FLOOR)
	for f in 3:
		m.set_t(f, 1, 1, TacMap.T.STAIRS)
	m.verticals.append({"type": "stairs", "pos": Vector2i(1, 1), "from_floor": 0, "to_floor": 2})
	for f in 2:
		m.set_t(f, 8, 6, TacMap.T.STAIRS)
	m.verticals.append({"type": "stairs", "pos": Vector2i(8, 6), "from_floor": 0, "to_floor": 1})
	m.connectors.append({"type": "ladder", "a": Vector3i(5, 7, 0), "b": Vector3i(5, 7, 1)})


func test_stair_links_connect_the_next_storey_of_the_shaft() -> void:
	assert_eq(FloorNav.links(m, Vector3i(1, 1, 1)).size(), 2, "middle of the shaft: up and down")
	assert_eq(FloorNav.step(m, Vector3i(1, 1, 0), 1), Vector3i(1, 1, 1), "up one storey, same square")
	assert_eq(FloorNav.step(m, Vector3i(1, 1, 1), 1), Vector3i(1, 1, 2))
	assert_eq(FloorNav.step(m, Vector3i(1, 1, 1), -1), Vector3i(1, 1, 0))
	assert_eq(FloorNav.step(m, Vector3i(1, 1, 2), 1), FloorNav.NONE, "the top landing goes nowhere up")
	assert_eq(FloorNav.step(m, Vector3i(8, 6, 1), 1), FloorNav.NONE, "the short shaft ends at floor 1")
	assert_eq(FloorNav.step(m, Vector3i(5, 7, 0), 1), Vector3i(5, 7, 1), "a ladder end climbs to its other end")
	assert_eq(FloorNav.step(m, Vector3i(5, 7, 1), -1), Vector3i(5, 7, 0))
	assert_false(FloorNav.is_stair(m, Vector3i(4, 4, 0)), "plain floor")
	assert_true(FloorNav.is_stair(m, Vector3i(1, 1, 2)), "the landing on top is a stair square")


func test_go_up_needs_the_move_and_uses_the_path_cost() -> void:
	var nav := Nav.new(m)
	var start := Vector3i(1, 1, 0)
	var g := FloorNav.go(m, start, 1, nav.reachable(start, 6), {})
	assert_true(g.ok, "on the stairs with movement left: GO UP")
	assert_eq(g.dest, Vector3i(1, 1, 1))
	assert_false(g.run)
	assert_eq(nav.cost_of(start, nav.path(start, g.dest)), 1, "a flight costs 1 square like any step (Nav)")
	var none := FloorNav.go(m, start, 1, {}, {})
	assert_false(none.ok, "no movement left: offered, not lit")
	assert_eq(none.dest, Vector3i(1, 1, 1))
	var run := FloorNav.go(m, start, 1, {}, {Vector3i(1, 1, 1): 7})
	assert_true(run.ok and run.run, "only the Run reaches it: a Run")
	assert_false(FloorNav.go(m, start, -1, nav.reachable(start, 6), {}).ok, "no floor below the street here")
	var ladder := Vector3i(5, 7, 0)
	assert_false(FloorNav.go(m, ladder, 1, nav.reachable(ladder, 1), {}).ok, "a climb costs 2 (p169): 1 square is not enough")
	assert_true(FloorNav.go(m, ladder, 1, nav.reachable(ladder, 2), {}).ok)


func test_go_up_moves_the_unit_in_an_encounter() -> void:
	m.entrances.append({"floor": 0, "pos": Vector2i(2, 2), "kind": "deploy", "main": false, "cells": [Vector2i(2, 2)]})
	var dice := Dice.new(3)
	var crew: Array[Combatant] = [Fixtures.shooter("A")]
	var e := Encounter.setup(m, dice, crew)
	e.units = e.units.filter(func(u): return u.team == 0)
	e.cur = e.units[0]
	e.cur.pos = Vector3i(1, 1, 0)
	e.turn = TurnState.begin(dice, e.cur.c)
	var before := e.turn.squares_available()
	var g := FloorNav.go(m, e.cur.pos, 1, e.move_options(), e.run_options())
	assert_true(g.ok)
	assert_true(e.move_to(g.dest, g.run))
	assert_eq(e.cur.pos, Vector3i(1, 1, 1), "upstairs")
	assert_eq(e.turn.squares_available(), before - 1, "one square of movement")


func test_the_view_follows_moves_to_another_floor() -> void:
	assert_eq(FloorNav.follow_floor(0, 1, true, false), 1, "a crew move upstairs: the view goes along")
	assert_eq(FloorNav.follow_floor(1, 0, true, false), 0, "and down")
	assert_eq(FloorNav.follow_floor(0, 1, false, true), 1, "a foe the crew sees climbing")
	assert_eq(FloorNav.follow_floor(0, 1, false, false), 0, "an unseen foe never moves the view")
	assert_eq(FloorNav.follow_floor(2, 2, true, true), 2, "same floor: stays")


func test_floor_buttons_stop_at_the_top_and_bottom() -> void:
	assert_eq(FloorNav.next_floor(m, 0, 1), 1)
	assert_eq(FloorNav.next_floor(m, 0, -1), -1, "nothing below floor 0")
	assert_eq(FloorNav.next_floor(m, 2, 1), -1, "nothing above the top")
	assert_eq(FloorNav.next_floor(m, 2, -1), 1)


func test_objective_direction() -> void:
	assert_eq(FloorNav.objective_dir(0, 2), 1, "up")
	assert_eq(FloorNav.objective_dir(2, 0), -1, "down")
	assert_eq(FloorNav.objective_dir(1, 1), 0, "this floor")


func test_hint_lights_the_stairs_that_lead_toward_the_objective() -> void:
	var up2 := FloorNav.hint_stairs(m, 0, Vector3i(4, 4, 2))
	assert_true(up2.has(Vector3i(1, 1, 0)), "the shaft reaching floor 2")
	assert_true(up2.has(Vector3i(8, 6, 0)) and up2.has(Vector3i(5, 7, 0)), "the short flight and ladder lead up too")
	var from1 := FloorNav.hint_stairs(m, 1, Vector3i(4, 4, 2))
	assert_eq(from1, [Vector3i(1, 1, 1)] as Array[Vector3i], "from floor 1 only the shaft goes higher")
	var down := FloorNav.hint_stairs(m, 1, Vector3i(4, 4, 0))
	assert_true(down.has(Vector3i(1, 1, 1)) and down.has(Vector3i(8, 6, 1)) and down.has(Vector3i(5, 7, 1)), "every way down")
	assert_true(FloorNav.hint_stairs(m, 1, Vector3i(4, 4, 1)).is_empty(), "objective on this floor: no hint")


func test_hint_prefers_the_targets_own_building() -> void:
	m.rooms.append({"id": 0, "floor": 2, "zone": 0, "kind": "office", "cells": 1, "bounds": Rect2i(4, 4, 1, 1), "structure": 3})
	m.labels[2][4 * m.w + 4] = 0
	m.verticals[0]["structure"] = 3
	m.verticals[1]["structure"] = 4
	assert_eq(FloorNav.hint_stairs(m, 0, Vector3i(4, 4, 2)), [Vector3i(1, 1, 0)] as Array[Vector3i], "the target building's stairs")


func test_blueprint_floors_are_the_ones_the_crew_does_not_start_on() -> void:
	var bp := FloorNav.blueprint_floors(3, [Vector3i(2, 2, 0), Vector3i(3, 2, 0)])
	assert_false(bp.has(0), "the street the crew goes in on is scouted, not given")
	assert_true(bp.has(1) and bp.has(2), "the floors above are on the fixer's blueprints")
	assert_true(WorldBuilder.is_layout("wall_concrete") and WorldBuilder.is_layout("stairs") and WorldBuilder.is_layout("door"), "layout materials")
	assert_false(WorldBuilder.is_layout("wood") or WorldBuilder.is_layout("steel"), "furniture stays fogged")
