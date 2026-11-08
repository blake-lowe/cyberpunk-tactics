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
		if e.kind in ["spawn", "deploy"]:
			return Vector3i(e.pos.x, e.pos.y, e.floor)
	return Vector3i(-1, -1, -1)


func test_every_scene_type_generates() -> void:
	var seen := {}
	for m in _scenes():
		seen[m.params.scene] = true
		assert_true(m.structures.size() >= (1 if m.params.scene in ["skirmish", "tower_top"] else 2), "%s has several structures (%d)" % [m.params.scene, m.structures.size()])
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
			if e.kind in ["spawn", "deploy"]:
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
			var sock: Dictionary = m.architectures[l.a].nodes[l.a_node]
			assert_eq(sock.type, "socket")
			assert_eq(int(sock.target_structure), int(l.b))
			var back: Dictionary = m.architectures[l.b].nodes[l.b_node]
			assert_eq(back.type, "socket", "bidirectional: a socket on the far side too")
			assert_eq(int(back.target_node), int(l.a_node))


func test_socket_crossing() -> void:
	var crossed := false
	for m in _scenes():
		if m.net_links.is_empty():
			continue
		var l: Dictionary = m.net_links[0]
		var runner := Fixtures.unarmored("Net")
		runner.role = "netrunner"
		runner.role_rank = 4
		var run := NetRun.new(m.architectures[l.a], runner)
		run.nets = m.architectures
		run.current = l.a_node
		assert_true(run.cross(), "stepping onto a socket crosses")
		assert_eq(run.arch.structure, int(l.b))
		assert_eq(run.current, int(l.b_node))
		crossed = true
		break
	assert_true(crossed, "at least one scene has a linked NET")


func test_deploy_zone_and_posts() -> void:
	for m in _scenes():
		var deploys := m.entrances.filter(func(e): return e.kind == "deploy")
		assert_eq(deploys.size(), 1, "%s has one deploy zone" % m.params.scene)
		if deploys.is_empty():
			continue
		var reach := m.reachable(_spawn0(m) if _spawn0(m).x >= 0 else Vector3i(deploys[0].pos.x, deploys[0].pos.y, 0))
		for c in deploys[0].cells:
			assert_true(m.walkable(m.street, c), "deploy cell open")
		for p in m.posts:
			assert_true(m.walkable(p.floor, p.pos), "%s: post on open ground" % m.params.scene)


func test_window_glass_rules() -> void:
	var seen := {}
	for m in _scenes():
		for f in m.floors:
			for i in m.wall_mat[f].size():
				if m.tiles[f][i] == TacMap.T.WALL and m.wall_mat[f][i] in [5, 6]:
					seen[m.wall_mat[f][i]] = m.wall_cover(f, i % m.w, i / m.w)
	assert_true(seen.has(5) and seen.has(6), "both window kinds appear")
	assert_false(seen[5].cover, "ordinary glass is no cover")
	assert_false(seen[5].blocks_los)
	assert_true(seen[6].cover and seen[6].hp == 15, "bulletproof glass: thin, 15 (p182)")
	assert_false(seen[6].blocks_los, "and see-through")


func test_diagonal_avenue_keeps_everything_reachable() -> void:
	var m := SceneGen.generate(5, "street_block", {"diagonal_chance": 1.0})
	var spawn := Vector3i(-1, -1, 0)
	for e in m.entrances:
		if e.kind in ["spawn", "deploy"]:
			spawn = Vector3i(e.pos.x, e.pos.y, 0)
			break
	var reach := m.reachable(spawn)
	for r in m.rooms:
		if r.cells == 0:
			continue
		assert_true(Furnish.room_cells(m, r).any(func(c): return reach.has(Vector3i(c.x, c.y, r.floor))), "%s reachable" % r.kind)


func test_every_neighbourhood_profile() -> void:
	var profiles := RulesDB.gen("districts.json").keys().filter(func(k): return not k.begins_with("_"))
	var sites := {}
	for prof in profiles:
		var m := SceneGen.generate(77, "neighborhood", {"profile": prof, "w": 100, "h": 76, "security": 2})
		var s0 := _spawn0(m)
		assert_true(s0.x >= 0, prof + " has an entry")
		assert_true(m.architecture != null, prof + " target has a NET")
		var reach := m.reachable(s0)
		var lost := 0
		for r in m.rooms:
			if r.cells > 0 and not Furnish.room_cells(m, r).any(func(c): return reach.has(Vector3i(c.x, c.y, r.floor))):
				lost += 1
		assert_eq(lost, 0, "%s: %d rooms unreachable" % [prof, lost])
		for st in m.structures:
			sites[st.site] = true
		if prof in ["combat_zone", "hot_zone"]:
			var breaches := 0
			for st in m.structures:
				if st.kind == "building":
					var r: Rect2i = st.rect
					for y in range(r.position.y, r.end.y):
						for x in range(r.position.x, r.end.x):
							if (x == r.position.x or x == r.end.x - 1) and m.t(0, x, y) == TacMap.T.OUTSIDE:
								breaches += 1
			assert_true(breaches > 0, prof + " is visibly ruined")
	assert_true(sites.size() >= 15, "many establishment types appear (%d)" % sites.size())



func test_sockets_same_level_and_branches_go_down() -> void:
	for m in _scenes():
		for l in m.net_links:
			var sa: Dictionary = m.architectures[l.a].nodes[l.a_node]
			var sb: Dictionary = m.architectures[l.b].nodes[l.b_node]
			assert_eq(int(sa.zone), int(sb.zone), "%s: socket joins the same level" % m.params.scene)
		for sid in m.architectures:
			var a: NetArchitecture = m.architectures[sid]
			for e in a.edges:
				var na: Dictionary = a.nodes[e.x]
				var nb: Dictionary = a.nodes[e.y]
				if na.type == "hub" and nb.type == "hub":
					assert_true(na.zone != nb.zone, "no sideways hub-to-hub links within a level")
			for n in a.nodes_of_type("firewall"):
				var zs := a.neighbors(n.id).map(func(x): return int(a.nodes[x].zone))
				zs.sort()
				assert_eq(zs[1] - zs[0], 1, "firewalls lead exactly one level down")
			# Every subnet connects back to the entry level.
			var root: int = a.subnets.filter(func(s): return s.zone == TacMap.Zone.PUBLIC)[0].hub
			var all := a.reach(root, {})
			for s in a.subnets:
				assert_true(all.has(s.hub), "subnet %d connected" % s.id)


func test_every_net_has_a_way_in() -> void:
	for scene in ["skirmish", "lone_building", "street_block"]:
		for seed in [11, 12]:
			var m := SceneGen.generate(seed, scene, {"security": 1})
			for sid in m.architectures:
				assert_false(m.architectures[sid].access_points.is_empty(), "%s seed %d structure %d has a jack-in point" % [scene, seed, sid])
