extends TestCase
## Hand-built 12 x 7, two floors:
##   x=6 is a wall column with a door at y=3 and a window at y=5.
##   A crate (cover) at (3, 1). Stairs at (1, 5) linking floors 0 and 1.

var m: TacMap


func before_each() -> void:
	m = TacMap.new(12, 7, 2)
	for y in 7:
		for x in 12:
			m.set_t(0, x, y, TacMap.T.FLOOR)
			m.set_t(1, x, y, TacMap.T.FLOOR)
	for y in 7:
		m.set_t(0, 6, y, TacMap.T.WALL)
		m.wall_mat[0][y * 12 + 6] = 0  # plaster
	m.set_t(0, 6, 3, TacMap.T.DOOR)
	m.doors.append({"floor": 0, "pos": Vector2i(6, 3), "a": -1, "b": -1, "security": false})
	m.wall_mat[0][5 * 12 + 6] = 5  # window
	m.add_cover(Furnish.cover_entry("crate", 0, Vector2i(3, 1), -1))
	m.set_t(0, 1, 5, TacMap.T.STAIRS)
	m.set_t(1, 1, 5, TacMap.T.STAIRS)
	m.verticals.append({"type": "stairs", "pos": Vector2i(1, 5), "from_floor": 0, "to_floor": 1})


func test_walls_block_windows_dont() -> void:
	var los := Los.new(m)
	assert_false(los.trace(Vector3i(4, 2, 0), Vector3i(8, 2, 0)).clear, "plaster wall blocks")
	assert_true(los.trace(Vector3i(4, 5, 0), Vector3i(8, 5, 0)).clear, "window is see-through")
	assert_false(los.trace(Vector3i(4, 3, 0), Vector3i(8, 3, 0)).clear, "closed door blocks")
	los.open_doors[Vector3i(6, 3, 0)] = true
	assert_true(los.trace(Vector3i(4, 3, 0), Vector3i(8, 3, 0)).clear, "open door doesn't")


func test_cover_blocks_until_destroyed() -> void:
	var los := Los.new(m)
	var t := los.trace(Vector3i(3, 0, 0), Vector3i(3, 4, 0))
	assert_false(t.clear, "crate between them")
	assert_eq(t.first_blocker, Vector3i(3, 1, 0))
	los.cover_hp[Vector3i(3, 1, 0)] = 0
	assert_true(los.trace(Vector3i(3, 0, 0), Vector3i(3, 4, 0)).clear, "destroyed cover stops blocking")


func test_lean_out_from_cover() -> void:
	var los := Los.new(m)
	# Shooter tucked behind the crate at (3,0) can lean to (2,0)/(4,0) and see (3,4)... from (2,0) the
	# ray to (3,4) clears the crate.
	var s := los.sight(Vector3i(3, 0, 0), Vector3i(3, 4, 0))
	assert_true(s.visible, "leans out")
	assert_true(s.from != Vector3i(3, 0, 0))
	# Target hiding behind the crate from a shooter in the open is in cover (no lean for targets).
	assert_false(los.sight(Vector3i(3, 4, 0), Vector3i(3, 0, 0)).visible, "target behind crate is in cover")


func test_nav_moves_doors_and_stairs() -> void:
	var nav := Nav.new(m)
	var r := nav.reachable(Vector3i(5, 3, 0), 2)
	assert_true(r.has(Vector3i(7, 3, 0)), "through the open door in 2")
	assert_false(r.has(Vector3i(7, 2, 0)), "no squeezing diagonally past the door frame")
	assert_false(r.has(Vector3i(3, 1, 0)), "cover blocks movement")
	var p := nav.path(Vector3i(2, 5, 0), Vector3i(2, 5, 1))
	assert_eq(p.size(), 3, "step to the stairs, up, step off")
	assert_eq(p[1], Vector3i(1, 5, 1))
	assert_eq(nav.cost_of(Vector3i(2, 5, 0), p), 3)
	nav.locked[Vector3i(6, 3, 0)] = true
	assert_true(nav.path(Vector3i(5, 3, 0), Vector3i(7, 3, 0)).is_empty(), "locked door blocks")


func test_ladder_costs_double() -> void:
	m.connectors.append({"type": "ladder", "a": Vector3i(10, 1, 0), "b": Vector3i(10, 1, 1)})
	var nav := Nav.new(m)
	var p := nav.path(Vector3i(10, 1, 0), Vector3i(10, 1, 1))
	assert_eq(nav.cost_of(Vector3i(10, 1, 0), p), 2, "climbing costs 2 per floor (p169)")


func test_real_scene_paths_from_deploy_to_target() -> void:
	var sm := SceneGen.generate(11, "street_block", {"security": 2})
	var nav := Nav.new(sm)
	nav.locked = {}
	var deploy: Dictionary = sm.entrances.filter(func(e): return e.kind == "deploy")[0]
	var door: Dictionary = sm.main_entrance()
	var p := nav.path(Vector3i(deploy.pos.x, deploy.pos.y, 0), Vector3i(door.pos.x, door.pos.y, 0))
	assert_false(p.is_empty(), "crew can walk to the target's door")


func test_vision_reveals_rooms_only_when_seen() -> void:
	# Outdoors (y 0) and a building (y 2-6) with an interior wall at x 6 splitting two rooms.
	var m := TacMap.new(12, 8, 1)
	for y in 8:
		for x in 12:
			var inside := y >= 2 and y <= 6 and x <= 11
			var wall := inside and (y == 2 or y == 6 or x == 0 or x == 11 or x == 6)
			m.set_t(0, x, y, TacMap.T.OUTSIDE if not inside else (TacMap.T.WALL if wall else TacMap.T.FLOOR))
	m.set_t(0, 3, 2, TacMap.T.DOOR)
	var los := Los.new(m)
	var v := Vision.new(m, los)
	assert_eq(v.state(Vector3i(3, 0, 0)), 1, "outdoors starts explored")
	assert_eq(v.state(Vector3i(0, 4, 0)), 1, "outer wall starts explored")
	assert_eq(v.state(Vector3i(3, 4, 0)), 0, "interior starts unknown")
	v.update([Vector3i(3, 0, 0)])
	assert_eq(v.state(Vector3i(3, 4, 0)), 0, "closed door hides the room")
	los.open_doors[Vector3i(3, 2, 0)] = true
	v.update([Vector3i(3, 0, 0)])
	assert_eq(v.state(Vector3i(3, 4, 0)), 2, "open door: the room is in sight")
	assert_eq(v.state(Vector3i(8, 4, 0)), 0, "the room behind the inner wall stays unknown")
	v.update([Vector3i(3, 0, 0) + Vector3i(-3, 0, 0)])
	assert_eq(v.state(Vector3i(3, 4, 0)) >= 1, true, "explored rooms are remembered")


func test_paths_never_enter_walls_or_cut_corners() -> void:
	var sm := SceneGen.generate(5, "skirmish", {})
	var nav := Nav.new(sm)
	nav.locked = {}
	var open := []
	for y in sm.h:
		for x in sm.w:
			if sm.walkable(0, Vector2i(x, y)):
				open.append(Vector3i(x, y, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in 40:
		var a: Vector3i = open[rng.randi() % open.size()]
		var b: Vector3i = open[rng.randi() % open.size()]
		var p := nav.path(a, b)
		var prev := a
		for c in p:
			if c.z == prev.z:
				assert_true(sm.walkable(c.z, Vector2i(c.x, c.y)), "step %s is walkable" % c)
				if c.x != prev.x and c.y != prev.y:
					assert_true(sm.walkable(c.z, Vector2i(c.x, prev.y)) and sm.walkable(c.z, Vector2i(prev.x, c.y)), "diagonal %s→%s doesn't cut a corner" % [prev, c])
			prev = c


# --- Playtest v0.10.1: diagonal wall gaps and seeing in through an open door -------------------

## An open 9 x 9 floor with walls at `walls`.
func _open_map(walls: Array) -> TacMap:
	var mm := TacMap.new(9, 9, 1)
	for y in 9:
		for x in 9:
			mm.set_t(0, x, y, TacMap.T.FLOOR)
	for w: Vector2i in walls:
		mm.set_t(0, w.x, w.y, TacMap.T.WALL)
	return mm


func _check_pinch(a: Vector3i, b: Vector3i, walls: Array, label: String) -> void:
	var mm := _open_map(walls)
	var los := Los.new(mm)
	var v := Vision.new(mm, los)
	v.update([a])
	assert_false(Nav.new(mm).reachable(a, 1).has(b), "%s: no diagonal step through the gap" % label)
	assert_false(los.trace(a, b).clear, "%s: no line of fire through the gap" % label)
	assert_false(los.sight(a, b).visible, "%s: no sight through the gap, leaning or not" % label)
	assert_false(los.sight(b, a).visible, "%s: nor back the other way" % label)
	assert_false(v.visible.has(b), "%s: vision stops at the gap" % label)
	assert_true(los.wall_between(a, b), "%s: a cable doesn't pass either" % label)
	# The same squares with no walls: all three pass.
	var om := _open_map([])
	var olos := Los.new(om)
	var ov := Vision.new(om, olos)
	ov.update([a])
	assert_true(Nav.new(om).reachable(a, 1).has(b), "%s open: the diagonal step" % label)
	assert_true(olos.trace(a, b).clear and olos.sight(a, b).visible, "%s open: line of fire and sight" % label)
	assert_true(ov.visible.has(b), "%s open: vision" % label)


func test_diagonal_pinch_blocks_sight_fire_and_movement_alike() -> void:
	# Every diagonal: the old ray let one pair through and blocked the other on a single wall.
	_check_pinch(Vector3i(4, 4, 0), Vector3i(5, 5, 0), [Vector2i(5, 4), Vector2i(4, 5)], "down-right")
	_check_pinch(Vector3i(4, 4, 0), Vector3i(5, 3, 0), [Vector2i(5, 4), Vector2i(4, 3)], "up-right")
	_check_pinch(Vector3i(4, 4, 0), Vector3i(3, 3, 0), [Vector2i(3, 4), Vector2i(4, 3)], "up-left")
	_check_pinch(Vector3i(4, 4, 0), Vector3i(3, 5, 0), [Vector2i(3, 4), Vector2i(4, 5)], "down-left")


func test_diagonal_pinch_blocks_longer_rays_through_the_corner() -> void:
	var mm := _open_map([Vector2i(5, 4), Vector2i(4, 5)])   # pinch at the corner (5, 5)
	var los := Los.new(mm)
	assert_false(los.trace(Vector3i(2, 2, 0), Vector3i(7, 7, 0)).clear, "a long diagonal through the pinch")
	assert_false(los.trace(Vector3i(3, 4, 0), Vector3i(6, 5, 0)).clear, "a 3:1 ray through the pinch corner")
	var v := Vision.new(mm, los)
	v.update([Vector3i(2, 2, 0)])
	assert_false(v.visible.has(Vector3i(7, 7, 0)), "vision doesn't leak through the pinch")


func test_one_wall_corner_doesnt_stop_a_grazing_ray() -> void:
	# Only one side of the corner is wall: no pinch, the ray grazes past (no step there, though).
	var los := Los.new(_open_map([Vector2i(5, 4)]))
	assert_true(los.trace(Vector3i(4, 4, 0), Vector3i(5, 5, 0)).clear, "down-right grazes past")
	assert_true(los.trace(Vector3i(4, 4, 0), Vector3i(5, 3, 0)).clear, "up-right grazes past")


func test_crates_corner_to_corner_pinch_fire_and_the_crate_is_the_blocker() -> void:
	var mm := _open_map([])
	mm.add_cover(Furnish.cover_entry("crate", 0, Vector2i(5, 4), -1))
	mm.add_cover(Furnish.cover_entry("crate", 0, Vector2i(4, 5), -1))
	var t := Los.new(mm).trace(Vector3i(4, 4, 0), Vector3i(5, 5, 0))
	assert_false(t.clear, "two crates corner to corner")
	assert_true(t.first_blocker in [Vector3i(5, 4, 0), Vector3i(4, 5, 0)], "a crate is what's in the way")


## Outdoors (y 0-1), a building (structure 2, y 2-7) with its door at (4, 2).
func _door_building() -> TacMap:
	var mm := TacMap.new(9, 9, 1)
	mm.rooms.append({"id": 0, "floor": 0, "zone": 0, "kind": "office", "cells": 28, "bounds": Rect2i(1, 3, 7, 4), "structure": 2})
	for y in 9:
		for x in 9:
			var inside := y >= 2 and y <= 7
			var wall := inside and (y == 2 or y == 7 or x == 0 or x == 8)
			mm.set_t(0, x, y, TacMap.T.OUTSIDE if not inside else (TacMap.T.WALL if wall else TacMap.T.FLOOR))
			if inside and not wall:
				mm.labels[0][y * 9 + x] = 0
	mm.set_t(0, 4, 2, TacMap.T.DOOR)
	mm.doors.append({"floor": 0, "pos": Vector2i(4, 2), "a": -1, "b": 0, "security": false, "structure": 2})
	return mm


func test_just_outside_an_open_door_sees_the_room_in_its_sight_line() -> void:
	var mm := _door_building()
	var los := Los.new(mm)
	los.open_doors[Vector3i(4, 2, 0)] = true
	var v := Vision.new(mm, los)
	var eye := Vector3i(4, 1, 0)
	v.update([eye])
	for c in [Vector3i(4, 3, 0), Vector3i(4, 6, 0), Vector3i(3, 6, 0), Vector3i(5, 6, 0), Vector3i(3, 5, 0), Vector3i(5, 5, 0)]:
		assert_eq(v.state(c), 2, "%s is in the sight line through the door" % c)
		assert_true(los.sight(eye, c).visible, "%s can be shot at through the door" % c)
	assert_eq(v.state(Vector3i(1, 3, 0)), 0, "the corner beside the door frame stays fogged")
	# The view (FloorNav.peeks): the building is seen into, so it is cut at that floor though no
	# crew member is inside; with the door shut it keeps its roof.
	var peeks := FloorNav.peeks(mm, v.visible)
	assert_eq(peeks, {2: 0}, "seen into through the door")
	assert_eq(FloorNav.slices([[-1, 0]], 0, -1, 0, peeks), {2: 0}, "its roof lifts for the crew outside")
	los.open_doors.erase(Vector3i(4, 2, 0))
	v.update([eye])
	assert_eq(FloorNav.peeks(mm, v.visible), {}, "door shut: nothing inside in sight, the roof stays on")
	assert_eq(FloorNav.slices([[2, 1]], 0, -1, 0, {2: 0}), {2: 1}, "crew inside keep their own cut")
