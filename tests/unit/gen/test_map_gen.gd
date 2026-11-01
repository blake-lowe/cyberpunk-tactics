extends TestCase

const ALGOS := ["bsp", "treemap", "growth"]


func _maps() -> Array[TacMap]:
	var out: Array[TacMap] = []
	for algo in ALGOS:
		for sec in 4:
			for s in 3:
				out.append(MapGen.generate(1000 + s * 17 + sec, algo, {"security": sec, "floors": 1 + s % 3,
					"verticality": 1 + s % 2, "net_style": "stack" if s % 2 == 0 else "mirrored"}))
	return out


func test_everything_reachable_from_main_entrance() -> void:
	for m in _maps():
		var e := m.main_entrance()
		assert_false(e.is_empty(), "%s has a main entrance" % m.algorithm)
		if e.is_empty():
			continue
		var reach := m.reachable(Vector3i(e.pos.x, e.pos.y, e.floor))
		var tag := "%s seed %d" % [m.algorithm, m.seed_value]
		for r in m.rooms:
			if r.cells == 0:
				continue
			var any := false
			for c in Furnish.room_cells(m, r):
				if reach.has(Vector3i(c.x, c.y, r.floor)):
					any = true
					break
			assert_true(any, "%s: room %d (%s, floor %d) unreachable" % [tag, r.id, r.kind, r.floor])
		for d in m.devices:
			assert_true(reach.has(Vector3i(d.pos.x, d.pos.y, d.floor)) or m.t(d.floor, d.pos.x, d.pos.y) == TacMap.T.DOOR,
				"%s: device %s unreachable" % [tag, d.type])


func test_security_gradient() -> void:
	for m in _maps():
		var mz := MapGen.max_zone(int(m.params.security))
		for d in m.doors:
			if d.a < 0:
				continue
			var za: int = m.rooms[d.a].zone
			var zb: int = m.rooms[d.b].zone
			assert_true(absi(za - zb) <= 1, "%s: door jumps zones %d→%d" % [m.algorithm, za, zb])
		for r in m.rooms:
			if r.cells > 0:
				assert_between(r.zone, TacMap.Zone.PUBLIC, mz)


func test_rooms_have_kinds_and_cover_has_hp() -> void:
	for m in _maps():
		for r in m.rooms:
			if r.cells > 0:
				assert_true(r.kind != "", "room %d has a kind" % r.id)
		assert_true(m.cover.size() > 0, "%s has cover" % m.algorithm)
		for c in m.cover:
			assert_true(c.hp > 0)


func test_architecture_mirrors_devices() -> void:
	for m in _maps():
		var a := m.architecture
		var groups := {}
		for d in m.devices:
			if d.group != "":
				groups[d.group] = true
		for g in groups:
			var n := a.floors.filter(func(f): return f.type == "control" and f.group == g).size()
			assert_eq(n, 1, "%s: group %s has one Control Node" % [m.algorithm, g])
		# Files: at most FILES_PER_ZONE per (floor, zone), and the most valuable device always has one.
		var buckets := {}
		for d in m.devices:
			if d.has("file_value"):
				buckets.get_or_add(Vector2i(d.floor, d.zone), []).append(d)
		for k in buckets:
			var devs: Array = buckets[k]
			devs.sort_custom(func(x, y): return x.file_value > y.file_value)
			var with_file := devs.filter(func(d): return a.floors.any(func(f): return f.type == "file" and f.get("device", -1) == d.id))
			assert_eq(with_file.size(), mini(devs.size(), NetGen.FILES_PER_ZONE), "files in bucket %s" % k)
			assert_true(with_file.has(devs[0]), "most valuable file kept")
		for ap in a.access_points:
			assert_between(ap.entry_floor, 0, a.floors.size() - 1)
		assert_true(a.floors[0].get("lobby", false) and a.floors[1].get("lobby", false), "two lobby floors")


func test_deep_content_sits_behind_gates() -> void:
	for m in _maps():
		var a := m.architecture
		for f in a.floors:
			if f.type == "ice" or f.get("lobby", false) or f.get("gate", false):
				continue
			var gates := {}
			for id in a.path_to(f.id):
				if a.floors[id].get("gate", false):
					gates[a.floors[id].zone] = true
			for z in range(TacMap.Zone.STAFF, int(f.zone) + 1):
				assert_true(gates.has(z), "%s/%s: floor %d (zone %d) missing gate %d" % [m.algorithm, a.style, f.id, f.zone, z])


func test_same_seed_same_map() -> void:
	for algo in ALGOS:
		var a := JSON.stringify(MapGen.generate(77, algo, {"security": 2}).to_dict())
		var b := JSON.stringify(MapGen.generate(77, algo, {"security": 2}).to_dict())
		assert_true(a == b, algo + " deterministic")


func test_netrun_passwords_block_descent() -> void:
	var m := MapGen.generate(5, "treemap", {"security": 2})
	var a := m.architecture
	var runner := Fixtures.unarmored("Net")
	runner.role = "netrunner"
	runner.role_rank = 6
	var run := NetRun.new(a, runner)
	assert_eq(NetRun.net_actions(6), 3)
	run.current = 0
	var gate := a.floors.filter(func(f): return f.get("gate", false))[0] as Dictionary
	var below := a.children(gate.id)
	assert_true(run.move_to(gate.id), "can reach the gate floor itself")
	if not below.is_empty():
		assert_false(run.can_move_to(below[0]), "locked below the password")
		run.broken[gate.id] = true
		assert_true(run.move_to(below[0]))
	assert_true(run.move_to(0), "moving up is free")
	assert_near(run.chance(8), Check.chance_vs_dv(6, 8))
