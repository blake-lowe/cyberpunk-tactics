class_name NetGen
extends RefCounted
## Builds the NET Architecture from the physical map, so the digital layout mirrors the building.
## Rules-as-written core (p209-211): difficulty sets Password/File/Control DVs, the first two floors
## roll on the Lobby table, total size is 3d6 floors, branches on d10 ≥ 7, other floors roll the
## 3d6 Black ICE table. Enhancements (design spec: "enhanced but familiar"):
## - Control Nodes and Files come from real devices: one Control Node per device group
##   (e.g. "cameras on the staff floor"), one File per data terminal. Floors grow past 3d6 if the
##   building needs more.
## - Each security zone above public sits behind a Password "gate", in zone order, so deeper
##   physical security means deeper digital security.
## - HOUSE-RULE: an access point inside zone Z enters the architecture just past Z's gate —
##   getting in physically lets you skip digital layers.
##
## Styles: "stack" = one main branch in zone order, rules-as-written branches carry deep-zone
## content; "mirrored" = a shared lobby/public trunk, then one branch per building floor.


const FILES_PER_ZONE := 2


static func generate(m: TacMap, dice: Dice) -> NetArchitecture:
	var net := RulesDB.load_json("net.json")
	var a := NetArchitecture.new()
	a.difficulty = clampi(int(m.params.get("security", 1)), 0, 3)
	a.style = String(m.params.get("net_style", "stack"))
	var dv: int = net["difficulty"][a.difficulty]["dv"]

	# Content from the map, keyed by [building floor][zone].
	var content := {}
	var groups := {}
	for d in m.devices:
		if d.group != "":
			if not groups.has(d.group):
				groups[d.group] = {"type": "control", "dv": dv, "group": d.group, "devices": [], "zone": d.zone, "bfloor": d.floor}
			groups[d.group].devices.append(d.id)
			groups[d.group].zone = maxi(groups[d.group].zone, d.zone)
		if d.has("file_value"):
			_bucket(content, d.floor, d.zone).append({"type": "file", "dv": dv, "device": d.id, "value": d.file_value, "zone": d.zone})
	# Keep architectures quick to resolve: at most FILES_PER_ZONE Files per floor and zone, most
	# valuable first (the rest of the terminals are still access points).
	for f in content:
		for z in content[f]:
			var files: Array = content[f][z]
			files.sort_custom(func(x, y): return x.value > y.value)
			content[f][z] = files.slice(0, FILES_PER_ZONE)
	for g in groups.values():
		_bucket(content, g.bfloor, g.zone).append(g)

	var mz := MapGen.max_zone(a.difficulty)
	var required := 2  # lobby
	for f in content:
		for z in content[f]:
			required += content[f][z].size()
	required += mz - TacMap.Zone.PUBLIC  # gates (stack); mirrored adds per-floor gates below
	var extra_ice := maxi(0, dice.roll(3, 6) - required)

	var lobby := _lobby(dice, net)
	var entry := {}  # Vector2i(building floor, zone) → floor id
	if a.style == "mirrored":
		var trunk: Array = lobby
		for f in content:
			trunk += _shuffled(dice, content[f].get(TacMap.Zone.PUBLIC, []))
		var last := _chain(a, -1, 0, trunk)
		for f in m.floors:
			entry[Vector2i(f, TacMap.Zone.PUBLIC)] = 0
		var branch := 1
		for f in m.floors:
			var parent := last
			for z in range(TacMap.Zone.STAFF, mz + 1):
				var zitems := _shuffled(dice, content.get(f, {}).get(z, []))
				var nice := maxi(extra_ice / maxi(1, m.floors * (mz - 1)), min_ice(a.difficulty, z) if not zitems.is_empty() else 0)
				var seg := _segment(dice, net, a.difficulty, dv, z, zitems, nice)
				var first := a.floors.size()
				parent = _chain(a, parent, branch, seg)
				entry[Vector2i(f, z)] = mini(first + 1, a.floors.size() - 1)
			branch += 1
	else:
		var main: Array = lobby.duplicate()
		var gate_index := {}
		for z in range(TacMap.Zone.PUBLIC, mz + 1):
			var items := []
			for f in content:
				items += content[f].get(z, [])
			var ice_here := maxi(roundi(extra_ice * float(z) / (1 + 2 + 3 + 4)), min_ice(a.difficulty, z)) if z > TacMap.Zone.PUBLIC else 0
			gate_index[z] = main.size()
			main += _segment(dice, net, a.difficulty, dv, z, _shuffled(dice, items), ice_here)
		# Rules-as-written branching (p210): d10 ≥ 7 adds a branch, repeat. A branch takes the tail
		# of a deep zone's segment, hanging off that zone's gate.
		var branches := 0
		while dice.d(10) >= 7 and branches < 3:
			branches += 1
		var branch_specs := []
		for bi in branches:
			var z := mz - (bi % maxi(1, mz - TacMap.Zone.PUBLIC))
			var start: int = gate_index.get(z, 2) + 1
			var end_i: int = gate_index.get(z + 1, main.size())
			if end_i - start >= 3:
				var take := (end_i - start) / 2
				branch_specs.append({"zone": z, "floors": main.slice(end_i - take, end_i)})
				for k in take:
					main.remove_at(end_i - take)
				for zz in gate_index:
					if gate_index[zz] > gate_index[z]:
						gate_index[zz] -= take
		_chain(a, -1, 0, main)
		var bnum := 1
		for spec in branch_specs:
			_chain(a, int(gate_index[spec.zone]), bnum, spec.floors)
			bnum += 1
		for f in m.floors:
			for z in range(TacMap.Zone.PUBLIC, mz + 1):
				entry[Vector2i(f, z)] = 0 if z == TacMap.Zone.PUBLIC else mini(int(gate_index[z]) + 1, a.floors.size() - 1)

	for d in m.devices:
		if d.get("access_point", false):
			a.access_points.append({"device": d.id, "entry_floor": entry.get(Vector2i(d.floor, mini(d.zone, mz)), 0)})
	return a


## Minimum Black ICE per zone segment by difficulty. Map content usually exceeds the 3d6 floor
## budget, which would leave no room for ICE at all; every zone past public still gets defenders.
## Index: difficulty (0-3) → [staff, secure, vault].
const MIN_ICE := [[0, 1, 1], [1, 1, 1], [1, 1, 2], [1, 2, 2]]


static func min_ice(diff: int, z: int) -> int:
	if z <= TacMap.Zone.PUBLIC:
		return 0
	return MIN_ICE[diff][mini(z, TacMap.Zone.VAULT) - TacMap.Zone.STAFF]


static func _bucket(content: Dictionary, f: int, z: int) -> Array:
	return content.get_or_add(f, {}).get_or_add(z, [])


static func _shuffled(dice: Dice, arr: Array) -> Array:
	var out := arr.duplicate()
	Layouts._shuffle(dice, out)
	return out


## Zone segment: Password gate (above public), then the zone's content with ICE mixed in.
static func _segment(dice: Dice, net: Dictionary, diff: int, dv: int, z: int, items: Array, ice_count: int) -> Array:
	var forced := min_ice(diff, z)
	var seg := []
	if z > TacMap.Zone.PUBLIC:
		seg.append({"type": "password", "dv": dv, "zone": z, "gate": true})
	var body := items.duplicate()
	for i in ice_count:
		body.insert(dice.rng.randi_range(0, body.size()), _roll_floor(dice, net, diff, dv, z, i < forced))
	for b in body:
		b["zone"] = z
	return seg + body


## A non-content floor from the 3d6 table: ICE, or an extra Password on 9/12, or a decoy File on 10/11.
static func _roll_floor(dice: Dice, net: Dictionary, diff: int, dv: int, z: int, must_be_ice: bool = false) -> Dictionary:
	var r := dice.roll(3, 6)
	while must_be_ice and r >= 9 and r <= 12:
		r = dice.roll(3, 6)
	if r == 9 or r == 12:
		return {"type": "password", "dv": dv, "zone": z}
	if r == 10 or r == 11:
		return {"type": "file", "dv": dv, "value": 0, "device": -1, "zone": z}
	return {"type": "ice", "ice": net["floor_ice"][str(r)][diff], "zone": z}


static func _lobby(dice: Dice, net: Dictionary) -> Array:
	var out := []
	var last := ""
	for i in 2:
		var e: Dictionary
		while true:
			e = (net["lobby"][str(dice.d(6))] as Dictionary).duplicate(true)
			var key := String(e.type) + str(e.get("ice", ""))
			if key != last or e.type == "file":  # re-roll duplicate Passwords/Programs (p210)
				last = key
				break
		e["zone"] = TacMap.Zone.STREET
		e["lobby"] = true
		out.append(e)
	return out


## Append floors as a chain under `parent`. Returns the id of the last floor added.
static func _chain(a: NetArchitecture, parent: int, branch: int, seq: Array) -> int:
	var p := parent
	for f in seq:
		p = a.add_floor(p, branch, f)
	return p
