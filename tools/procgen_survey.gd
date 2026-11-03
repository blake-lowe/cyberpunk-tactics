extends SceneTree
## Procedural coverage survey: every scene x objective x security x seed through Encounter.setup,
## measuring whether the gig is actually playable. One line per run (TSV) + timings.
## Usage: godot --headless --path . -s tools/procgen_survey.gd -- [--scenes=a,b] [--seeds=4] > survey.tsv
## (docs/plans/missions-and-maps.md has the first results and what they mean.)

const OBJ := ["data", "eliminate", "snatch"]

func _initialize() -> void:
	var scenes := ["skirmish", "lone_building", "street_block", "megablock", "shipyard", "badlands", "rail_yard", "corp_campus",
		"neighborhood:corporate_center", "neighborhood:combat_zone", "neighborhood:pacifica", "neighborhood:industrial", "city_district"]
	var seeds := 4
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scenes="): scenes = Array(a.get_slice("=", 1).split(","))
		if a.begins_with("--seeds="): seeds = int(a.get_slice("=", 1))
	print("scene\tobj\tsec\tseed\tgen_ms\tw\th\tfl\ttarget\tguards\tbudget\tdeploy_to_target\tlocked_doors\taps\taps_reach\tfile\tfile_hops\tfile_fw\tfile_fwdv\tice\tpkg\tpkg_walk\tpkg_floor\tbackup_entr\tcams\tguards_locked\tnote")
	for sc in scenes:
		for sec in [1, 2, 3]:
			for sd in range(1, seeds + 1):
				var t0 := Time.get_ticks_msec()
				var name: String = sc
				var opts := {"security": sec}
				var gen_scene: String = sc
				if sc.begins_with("neighborhood:"):
					gen_scene = "neighborhood"
					opts["profile"] = sc.get_slice(":", 1)
				var m: TacMap = SceneGen.generate(sd * 13 + sec, gen_scene, opts)
				var gen_ms := Time.get_ticks_msec() - t0
				for obj in OBJ:
					_row(name, obj, sec, sd, gen_ms, m)
	quit()


func _row(name: String, obj: String, sec: int, sd: int, gen_ms: int, m0: TacMap) -> void:
	# fresh map per objective (setup mutates nothing structural, but keep runs independent)
	var m := m0
	var dice := Dice.new(sd * 7 + sec)
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner"), Recruit.generate(dice, "netrunner", "edgerunner")]
	var note := ""
	var e: Encounter = null
	e = Encounter.setup(m, dice, crew, obj)
	if e == null:
		print("%s\t%s\t%d\t%d\tSETUP_FAILED" % [name, obj, sec, sd])
		return
	var tsid := -1
	for st in m.structures:
		if st.target:
			tsid = st.id
	var guards := e.units.filter(func(u): return u.team == 1).size()
	var budget := Recruit.opposition(crew.size(), sec).size()
	var start: Vector3i = e.units[0].pos
	var field: Dictionary = e.nav.distance_field([start], {}, 2000)   # crew keys: locked doors block
	var tgt_d := -1
	for cell in field:
		var l := m.label(cell.z, cell.x, cell.y)
		if l >= 0 and m.rooms[l].structure == tsid:
			if tgt_d < 0 or int(field[cell]) < tgt_d:
				tgt_d = int(field[cell])
	var locked := e.nav.locked.size()
	# jack points the crew can actually stand at: walk-reachable cells within jack range, no wall
	var aps := 0
	var aps_reach := 0
	if m.architectures.has(tsid):
		var a: NetArchitecture = m.architectures[tsid]
		aps = a.access_points.size()
		for ap in a.access_points:
			var d: Dictionary = m.devices[ap.device]
			var dp := Vector3i(d.pos.x, d.pos.y, d.floor)
			var ok := false
			for cell in field:
				if cell.z == dp.z and Los.distance_m(cell, dp) <= Encounter.JACK_IN_RANGE_M and not e._wall_between(cell, dp):
					ok = true
					break
			if ok:
				aps_reach += 1
	# target file: hops / firewalls on the shortest NET route from any access point
	var file := int(e.objective.get("node", -1))
	var hops := -1
	var fw := -1
	var fwdv := 0
	var ice := 0
	if obj == "data" and file >= 0:
		var a2: NetArchitecture = m.architectures[tsid]
		ice = a2.ice.size()
		var best := [-1, -1, 0]
		for ap in a2.access_points:
			var r := _route(a2, int(ap.entry_node), file)
			if r[0] >= 0 and (best[0] < 0 or r[0] < best[0]):
				best = r
		hops = best[0]
		fw = best[1]
		fwdv = best[2]
	var pkg := "-"
	var pkg_walk := -1
	var pkg_floor := -1
	if obj == "snatch":
		var pc: Vector3i = e.objective.cell
		pkg = "%d,%d,%d" % [pc.x, pc.y, pc.z]
		pkg_walk = int(field.get(pc, -1))
		pkg_floor = pc.z
		var l2 := m.label(pc.z, pc.x, pc.y)
		if l2 < 0 or m.rooms[l2].structure != tsid:
			note += "pkg_outside_target;"
	var backup := m.entrances.filter(func(en): return en.kind != "deploy" and m.walkable(int(en.floor), en.pos)).size()
	var cams := m.devices.filter(func(d): return String(d.type) == "camera").size()
	var glocked := 0
	for g in e.units:
		if g.team == 1 and not field.has(g.pos):
			glocked += 1
	if tsid < 0:
		note += "no_target;"
	if guards < budget:
		note += "guards_short;"
	print("%s\t%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%d\t%d\t%d\t%d\t%d\t%s" % [name, obj, sec, sd, gen_ms,
		m.w, m.h, m.floors, tsid, guards, budget, tgt_d, locked, aps, aps_reach, file, hops, fw, fwdv, ice, pkg, pkg_walk, pkg_floor, backup, cams, glocked, note])


## Shortest route by hops (BFS) from `from` to `to`, counting firewalls passed and their max DV.
func _route(a: NetArchitecture, from: int, to: int) -> Array:
	var prev := {from: -1}
	var q := [from]
	while not q.is_empty():
		var n: int = q.pop_front()
		if n == to:
			break
		for nb in a.neighbors(n):
			if not prev.has(nb):
				prev[nb] = n
				q.append(nb)
	if not prev.has(to):
		return [-1, -1, 0]
	var hops := 0
	var fw := 0
	var dv := 0
	var s := to
	while s != from:
		hops += 1
		if a.nodes[s].type == "firewall":
			fw += 1
			dv = maxi(dv, int(a.nodes[s].dv))
		s = prev[s]
	return [hops, fw, dv]
