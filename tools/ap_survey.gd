extends SceneTree
## Access points (and the other objectives' targets) against the deploy zone and the crew's start
## squares, over every scene, lone-building site, district profile and set piece. One TSV row per
## access point (data) or target (snatch/sabotage/rescue/assassinate). flag: a = on a deploy/start
## square, b = jack-in from one (6 m, no wall; a target: beside it), c = in reach within one MOVE's
## walk, "-" = none; jack10 = J10 if a jack line from a deploy square is within 10 m (Long Leash).
## cause (flagged access points): where it came from, indoors/out, what the line passes through.
## Usage: timeout 3000 godot --headless --path . -s tools/ap_survey.gd -- [--seeds=8 | --seedlist=11,2]
##   [--sec=2] [--only=lone_building/] [--objs=data,snatch,sabotage,rescue,assassinate] > out.tsv
## (The suite's small pass is tests/unit/gen/test_deploy.gd; the soak checks it too.)

var seeds := 8
var seedlist: Array = []
var secfix := -1
var only := ""
var objs := ["data", "snatch", "sabotage", "rescue", "assassinate"]


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="): seeds = int(a.get_slice("=", 1))
		if a.begins_with("--seedlist="): seedlist = Array(a.get_slice("=", 1).split(",")).map(func(x): return int(x))
		if a.begins_with("--sec="): secfix = int(a.get_slice("=", 1))
		if a.begins_with("--only="): only = a.get_slice("=", 1)
		if a.begins_with("--objs="): objs = Array(a.get_slice("=", 1).split(","))
	var combos := []   # [label, scene, overrides]
	for sc in SceneGen.scene_types():
		if sc == "lone_building":
			for site in RulesDB.gen("sites.json").keys():
				if not String(site).begins_with("_"):
					combos.append(["lone_building/" + site, "lone_building", {"site": site}])
		elif sc == "neighborhood":
			for prof in RulesDB.gen("districts.json").keys():
				if not String(prof).begins_with("_"):
					combos.append(["neighborhood/" + prof, "neighborhood", {"profile": prof}])
		else:
			combos.append([sc, sc, {}])
	for sp in SetPieces.ids():
		if not String(sp).begins_with("_"):
			combos.append(["setpiece/" + sp, "lone_building", {"setpiece": sp}])
	print("combo\tseed\tsec\tobj\tdeploy\tkind\tdev\tdevtype\troom\tzone\ttarget\tfloor\td_deploy_m\td_start_m\tflag\twalk_sq\tmove\tcause\tjack10")
	for cb in combos:
		if only != "" and not String(cb[0]).begins_with(only):
			continue
		for sd in (seedlist if not seedlist.is_empty() else range(1, seeds + 1)):
			var sec: int = secfix if secfix >= 0 else 1 + sd % 3
			for obj in objs:
				if obj != "data" and not objs.has(obj):
					continue
				_run(cb, sd, sec, obj)
	quit()


func _run(cb: Array, sd: int, sec: int, obj: String) -> void:
	var o: Dictionary = (cb[2] as Dictionary).duplicate()
	o["security"] = sec
	var m: TacMap = SceneGen.generate(sd, String(cb[1]), o)
	var dice := Dice.new(sd)
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "A"), Recruit.generate(dice, "netrunner", "edgerunner", "B"),
		Recruit.generate(dice, "tech", "edgerunner", "C"), Recruit.generate(dice, "medtech", "edgerunner", "D")]
	var e := Encounter.setup(m, Dice.new(sd + 1), crew, obj)
	var deploy: Dictionary = m.entrances.filter(func(x): return x.kind == "deploy")[0]
	var dcells: Array = []
	for c in deploy.get("cells", [deploy.pos]):
		dcells.append(Vector3i(c.x, c.y, m.street))
	var starts: Array = e.units.filter(func(u): return u.team == Encounter.CREW).map(func(u): return u.pos)
	var mv := 0
	for c in crew:
		mv = maxi(mv, c.stat("MOVE"))
	var field: Dictionary = e.nav.distance_field(dcells, {}, 4000)
	var dkind := "near" if bool(deploy.get("near", false)) else "far"
	var label := String(cb[0])
	if obj == "data":
		for p in AccessPoints.all(e):
			var d: Dictionary = m.devices[int(p.device)]
			_report(e, m, label, sd, sec, obj, dkind, "ap", d, p.cell, dcells, starts, field, mv)
	else:
		var cell := Vector3i(-1, -1, -1)
		match obj:
			"snatch", "sabotage":
				cell = e.objective.get("cell", cell)
			"rescue":
				cell = e.units[int(e.objective.captive)].pos
			"assassinate":
				cell = e.units[int(e.objective.target)].pos
		if cell.x >= 0:
			_report(e, m, label, sd, sec, obj, dkind, obj, {"id": -1, "type": obj, "room": m.label(cell.z, cell.x, cell.y), "zone": -1, "structure": -1}, cell, dcells, starts, field, mv)


func _report(e: Encounter, m: TacMap, label: String, sd: int, sec: int, obj: String, dkind: String, kind: String, d: Dictionary, dp: Vector3i,
		dcells: Array, starts: Array, field: Dictionary, mv: int) -> void:
	var dd := INF
	var ds := INF
	var flag := "-"
	var jack_from_deploy := false
	var jack10 := false
	for v in dcells:
		dd = minf(dd, Los.distance_m(v, dp))
		if v == dp:
			flag = "a"
		if v.z == dp.z and Los.distance_m(v, dp) <= Encounter.JACK_IN_RANGE_M and not e._wall_between(v, dp):
			jack_from_deploy = true
		if v.z == dp.z and Los.distance_m(v, dp) <= 10.0 and not e._wall_between(v, dp):
			jack10 = true
	for v in starts:
		ds = minf(ds, Los.distance_m(v, dp))
		if v == dp:
			flag = "a"
	# reach: for an AP, any cell within jack range with no wall; for a target, adjacent (beside)
	var walk := -1
	for cell in field:
		if cell.z != dp.z:
			continue
		var ok := false
		if kind == "ap":
			ok = Los.distance_m(cell, dp) <= Encounter.JACK_IN_RANGE_M and not e._wall_between(cell, dp)
		else:
			ok = maxi(absi(cell.x - dp.x), absi(cell.y - dp.y)) <= 1
		if ok and (walk < 0 or int(field[cell]) < walk):
			walk = int(field[cell])
	if flag == "-":
		if kind == "ap" and jack_from_deploy:
			flag = "b"
		elif kind != "ap" and walk >= 0 and walk <= 1:
			flag = "b"
		elif walk >= 0 and walk <= mv:
			flag = "c"
	var cause := ""
	if (flag != "-" or jack10) and kind == "ap":
		cause = _cause(e, m, d, dp, dcells, dkind)
	var l := m.label(dp.z, dp.x, dp.y)
	var room := "street" if l < 0 else String(m.rooms[l].get("kind", "?"))
	var st := int(d.get("structure", -1))
	var tgt := st >= 0 and st < m.structures.size() and bool(m.structures[st].target)
	print("%s\t%d\t%d\t%s\t%s\t%s\t%d\t%s\t%s\t%d\t%s\t%d\t%.1f\t%.1f\t%s\t%d\t%d\t%s\t%s" % [label, sd, sec, obj, dkind, kind, int(d.id), String(d.type), room,
		int(d.get("zone", -1)), "T" if tgt else "o", dp.z, dd, ds, flag, walk, mv, cause, "J10" if jack10 and kind == "ap" else "-"])


func _cause(e: Encounter, m: TacMap, d: Dictionary, dp: Vector3i, dcells: Array, dkind: String) -> String:
	var parts := []
	# where it came from
	if String(d.type) == "junction" and String(d.get("group", "x")) == "":
		parts.append("src=ensure_public_access")
	else:
		var l := m.label(dp.z, dp.x, dp.y)
		var rk := "" if l < 0 else String(m.rooms[l].get("kind", ""))
		var spec_ap := false
		for s in RulesDB.gen("rooms.json").get(rk, {}).get("devices", []):
			if bool(s.get("ap", false)) and String(s.t) == String(d.type):
				spec_ap = true
		parts.append("src=room_spec" if spec_ap else "src=netgen_promoted")
	var l2 := m.label(dp.z, dp.x, dp.y)
	var outdoors := m.t(dp.z, dp.x, dp.y) == TacMap.T.OUTSIDE or l2 < 0 or bool(m.rooms[l2].get("outdoor", false))
	parts.append("loc=outdoors" if outdoors else "loc=indoors")
	# what the line from the nearest deploy cell passes through
	var best := Vector3i(-1, -1, -1)
	var bd := INF
	for v in dcells:
		if v.z == dp.z and Los.distance_m(v, dp) < bd and not e._wall_between(v, dp):
			bd = Los.distance_m(v, dp)
			best = v
	if best.x >= 0 and not outdoors:
		var via := "open"
		for r in Los.ray(best, dp):
			var b := e.los.blocker(r)
			if b == "glass":
				via = "window"
				break
			var t := m.t(r.z, r.x, r.y)
			if t == TacMap.T.DOOR:
				via = "open_door"
			elif t == TacMap.T.WALL:
				via = "low_wall"
		parts.append("via=" + via)
	var in_yard := dcells.any(func(v): return m.label(v.z, v.x, v.y) >= 0)
	parts.append("deploy=%s%s" % [dkind, "_yard" if in_yard else ""])
	if String(m.params.get("setpiece", "")) != "":
		parts.append("setpiece")
	return ",".join(parts)
