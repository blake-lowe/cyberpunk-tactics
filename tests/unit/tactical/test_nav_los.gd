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
