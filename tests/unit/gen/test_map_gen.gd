extends TestCase

const SITES := ["corp_office", "warehouse", "gang_hideout"]
static var _cache: Array[TacMap] = []


func _maps() -> Array[TacMap]:
	if _cache.is_empty():
		for site in SITES:
			for sec in 4:
				for s in 2:
					_cache.append(MapGen.generate(1000 + s * 17 + sec, site, {"security": sec, "floors": 1 + (s + sec) % 2 + 1,
						"verticality": 1 + s % 2}))
	return _cache


func test_everything_reachable_from_main_entrance() -> void:
	for m in _maps():
		var e := m.main_entrance()
		assert_false(e.is_empty(), "%s has a main entrance" % m.params.site)
		if e.is_empty():
			continue
		var reach := m.reachable(Vector3i(e.pos.x, e.pos.y, e.floor))
		var tag := "%s seed %d" % [m.params.site, m.seed_value]
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
			assert_true(absi(za - zb) <= 1, "%s: door jumps zones %d→%d" % [m.params.site, za, zb])
		for r in m.rooms:
			if r.cells > 0:
				assert_between(r.zone, TacMap.Zone.PUBLIC, mz)


func test_room_kinds_have_data() -> void:
	var rooms_def := RulesDB.gen("rooms.json")
	for m in _maps():
		for r in m.rooms:
			if r.cells > 0:
				assert_true(rooms_def.has(r.kind), "%s: room kind '%s' missing from rooms.json" % [m.params.site, r.kind])
		for c in m.cover:
			assert_true(c.hp > 0)


func test_site_uses_its_layout() -> void:
	assert_eq(MapGen.generate(1, "corp_office").algorithm, "treemap")
	assert_eq(MapGen.generate(1, "warehouse").algorithm, "bsp")
	assert_eq(MapGen.generate(1, "gang_hideout").algorithm, "growth")
	assert_eq(MapGen.generate(1, "warehouse", {"algorithm": "growth"}).algorithm, "growth", "override for comparisons")


func test_control_nodes_mirror_device_groups() -> void:
	for m in _maps():
		var a := m.architecture
		var groups := {}
		for d in m.devices:
			if d.group != "":
				groups[d.group] = true
		for g in groups:
			assert_eq(a.nodes.filter(func(n): return n.type == "control" and n.group == g).size(), 1, "%s: group %s" % [m.params.site, g])
		for d in m.devices:
			if d.type == "data_core":
				var f := a.nodes.filter(func(n): return n.type == "file" and n.get("device", -1) == d.id)
				assert_eq(f.size(), 1, "data core has a File")
				if f.size() == 1:
					assert_true(f[0].net_only, "data core is net-only")


func test_firewalls_gate_deeper_zones() -> void:
	for m in _maps():
		var a := m.architecture
		var fw := {}
		for n in a.nodes_of_type("firewall"):
			fw[n.id] = true
		var public_hub: int = a.subnets.filter(func(s): return s.zone == TacMap.Zone.PUBLIC)[0].hub
		for id in a.reach(public_hub, fw):
			var n: Dictionary = a.nodes[id]
			if n.type != "firewall":
				assert_eq(int(n.zone), TacMap.Zone.PUBLIC, "%s: node %d (%s) reachable without a firewall" % [m.params.site, id, n.type])


func test_jack_in_points_partial_and_never_vault() -> void:
	var own := 0
	var shallower := 0
	for m in _maps():
		var a := m.architecture
		for ap in a.access_points:
			var dev: Dictionary = m.devices[ap.device]
			var entry_zone := int(a.nodes[ap.entry_node].zone)
			assert_true(entry_zone < TacMap.Zone.VAULT, "no physical shortcut into the vault")
			assert_true(entry_zone <= maxi(int(dev.zone), TacMap.Zone.PUBLIC), "never deeper than the device")
			if dev.zone > TacMap.Zone.PUBLIC and dev.zone < TacMap.Zone.VAULT:
				if entry_zone == int(dev.zone):
					own += 1
				else:
					shallower += 1
	assert_true(own > 0 and shallower > 0, "entries vary: own %d, shallower %d" % [own, shallower])


func test_ice_budget_spent_within_tier() -> void:
	var table: Dictionary = RulesDB.load_json("black_ice.json")["ice"]
	for m in _maps():
		var a := m.architecture
		assert_eq(a.spent, a.budget, "%s sec %d budget fully spent" % [m.params.site, a.difficulty])
		var total := 0
		for i in a.ice:
			assert_true(int(table[i.kind].tier) <= a.difficulty, "%s allowed at difficulty %d" % [i.kind, a.difficulty])
			total += int(table[i.kind].points)
		assert_eq(total, a.spent)


func test_complexity_scales_with_security() -> void:
	var loops := {0: 0, 3: 0}
	for m in _maps():
		var a := m.architecture
		var extra := a.edges.size() - (a.nodes.size() - 1)
		if a.difficulty == 0:
			assert_eq(extra, 0, "security 0 is a simple tree")
		if a.difficulty in loops:
			loops[a.difficulty] += extra
	assert_true(loops[3] > 0, "high security has loops/extra routes")


func test_same_seed_same_map() -> void:
	for site in SITES:
		var a := JSON.stringify(MapGen.generate(77, site, {"security": 2}).to_dict())
		var b := JSON.stringify(MapGen.generate(77, site, {"security": 2}).to_dict())
		assert_true(a == b, site + " deterministic")


func test_netrun_firewall_and_ice() -> void:
	var m := MapGen.generate(5, "corp_office", {"security": 2})
	var a := m.architecture
	for i in a.ice:
		i["derezzed"] = true  # isolate the firewall rule first
	var runner := Fixtures.unarmored("Net")
	runner.role = "netrunner"
	runner.role_rank = 6
	var run := NetRun.new(a, runner)
	var fw: Dictionary = a.nodes_of_type("firewall")[0]
	var outer: int = a.neighbors(fw.id).filter(func(n): return int(a.nodes[n].zone) < int(fw.zone))[0]
	var inner: int = a.neighbors(fw.id).filter(func(n): return int(a.nodes[n].zone) >= int(fw.zone))[0]
	run.current = outer
	assert_true(run.can_move_to(fw.id), "can reach the firewall")
	assert_false(run.can_move_to(inner), "blocked inward")
	run.current = inner
	assert_true(run.can_move_to(outer), "can leave outward without breaking it")
	run.current = outer
	run.broken[fw.id] = true
	assert_true(run.can_move_to(inner))
	a.ice[0]["derezzed"] = false
	run.current = a.ice[0].node
	assert_eq(run.movable().size(), 1, "active Black ICE pins the runner")
	assert_eq(NetRun.net_actions(6), 3)
