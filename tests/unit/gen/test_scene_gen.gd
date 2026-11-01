extends TestCase

static var _cache: Array[TacMap] = []


func _scenes() -> Array[TacMap]:
	if _cache.is_empty():
		for scene in SceneGen.scene_types():
			if scene == "lone_building":
				continue
			for s in 2:
				_cache.append(SceneGen.generate(300 + s * 41, scene, {"security": 1 + s * 2}))
	return _cache


func _spawn0(m: TacMap) -> Vector3i:
	for e in m.entrances:
		if e.kind == "spawn":
			return Vector3i(e.pos.x, e.pos.y, e.floor)
	return Vector3i(-1, -1, -1)


func test_every_scene_type_generates() -> void:
	var seen := {}
	for m in _scenes():
		seen[m.params.scene] = true
		assert_true(m.structures.size() >= 2, "%s has several structures (%d)" % [m.params.scene, m.structures.size()])
		assert_true(m.structures.any(func(s): return s.target), "%s has a target" % m.params.scene)
		assert_true(m.architecture != null, "%s target has a NET" % m.params.scene)
	assert_eq(seen.size(), SceneGen.scene_types().size() - 1)


func test_everything_reachable_from_the_street() -> void:
	for m in _scenes():
		var s0 := _spawn0(m)
		assert_true(s0.x >= 0, "%s has spawns" % m.params.scene)
		if s0.x < 0:
			continue
		assert_true(m.walkable(s0.z, Vector2i(s0.x, s0.y)), "%s spawn is open ground" % m.params.scene)
		var reach := m.reachable(s0)
		for e in m.entrances:
			if e.kind == "spawn":
				assert_true(reach.has(Vector3i(e.pos.x, e.pos.y, e.floor)), "%s: spawn %s connected" % [m.params.scene, e.pos])
		for r in m.rooms:
			if r.cells == 0:
				continue
			var any := false
			for c in Furnish.room_cells(m, r):
				if reach.has(Vector3i(c.x, c.y, r.floor)):
					any = true
					break
			assert_true(any, "%s seed %d: %s (structure %d, floor %d) unreachable" % [m.params.scene, m.seed_value, r.kind, r.structure, r.floor])


func test_cover_only_on_open_ground() -> void:
	for m in _scenes():
		for c in m.cover:
			assert_true(Furnish.open_tile(m.t(c.floor, c.pos.x, c.pos.y)), "%s: %s on a non-open tile" % [m.params.scene, c.kind])


func test_nets_belong_to_their_structure() -> void:
	for m in _scenes():
		for sid in m.architectures:
			var a: NetArchitecture = m.architectures[sid]
			for ap in a.access_points:
				assert_eq(int(m.devices[ap.device].structure), int(sid), "%s: AP device belongs to structure" % m.params.scene)
				assert_eq(a.nodes[ap.entry_node].type, "port", "each jack-in point has its own port node")


func test_scenes_deterministic() -> void:
	for scene in ["street_block", "badlands"]:
		var a := JSON.stringify(SceneGen.generate(9, scene).to_dict())
		var b := JSON.stringify(SceneGen.generate(9, scene).to_dict())
		assert_true(a == b, scene + " deterministic")


func test_intro_net_is_tiny() -> void:
	var m := MapGen.generate(4, "corp_office", {"security": 2, "net_scale": "intro"})
	var a := m.architecture
	assert_eq(a.scale, "intro")
	assert_eq(a.subnets.size(), 1)
	assert_eq(a.nodes_of_type("firewall").size(), 0)
	assert_true(a.spent <= NetGen.INTRO_BUDGET)


func test_walls_doors_and_fences_as_cover() -> void:
	var found := {}
	for m in _scenes():
		for f in m.floors:
			for y in m.h:
				for x in m.w:
					if m.t(f, x, y) != TacMap.T.WALL:
						continue
					var wc := m.wall_cover(f, x, y)
					found[wc.material] = wc
		for d in m.doors:
			var dc := m.wall_cover(d.floor, d.pos.x, d.pos.y)
			if d.get("gate", false):
				assert_false(dc.cover, "fence gates are no cover")
			else:
				assert_eq(dc.hp, TacMap.SECURITY_DOOR_HP if d.security else TacMap.DOOR_HP)
	assert_eq(found["plaster"].hp, 15, "office wall: thick plaster (p183)")
	assert_eq(found["concrete"].hp, 25)
	assert_eq(found["stone"].hp, 40, "rock outcrop ≈ boulder")
	assert_false(found["fence"].cover, "fences stop movement, not bullets")
	assert_false(found["fence"].blocks_los)
	assert_true(found["fence"].blocks_move)


func test_roofs_have_access_and_connectors_land_on_walkable_ground() -> void:
	for m in _scenes():
		for r in m.rooms:
			if r.cells > 0 and r.kind == "roof":
				var sid: int = r.structure
				var hatch := m.verticals.any(func(v): return v.get("structure", -1) == sid and v.to_floor == r.floor)
				var ladder := m.connectors.any(func(c): return c.get("structure", -1) == sid)
				assert_true(hatch or ladder, "%s: roof of structure %d has a way up" % [m.params.scene, sid])
		for c in m.connectors:
			assert_true(m.walkable_tile(m.t(c.a.z, c.a.x, c.a.y)) and m.walkable_tile(m.t(c.b.z, c.b.x, c.b.y)), "connector ends walkable")


func test_city_district_has_bridges() -> void:
	var m: TacMap = _scenes().filter(func(x): return x.params.scene == "city_district")[0]
	assert_true(m.doors.any(func(d): return d.get("skybridge", false)), "skybridges")
	assert_true(m.verticals.any(func(v): return v.get("structure", 0) == -1), "footbridges")
	assert_true(m.structures.size() > 20, "dozens of structures")


func test_net_links_join_existing_nets() -> void:
	for m in _scenes():
		for l in m.net_links:
			assert_true(m.architectures.has(l.a) and m.architectures.has(l.b), "link ends have NETs")
			assert_eq(m.architectures[l.a].nodes[l.a_node].type, "hub")
