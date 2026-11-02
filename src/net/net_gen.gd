class_name NetGen
extends RefCounted
## Builds the site's NET graph from the physical map (M2 review decisions, docs/roadmap.md):
## - Complexity scales with security: low security = one subnet per zone in a simple chain;
##   high security = subnets per zone *and* building floor, loops inside subnets, lateral links
##   between floors and second firewall routes into deeper zones, plus patrolling ICE.
## - Control Nodes come from device groups, Files from data devices (max FILES_PER_SUBNET each).
## - Net-only content: master overrides and offsite data with no physical counterpart, and data
##   cores, which have no jack-in point. Only netrunning reaches them.
## - Each jack-in terminal is wired to its own fixed "port" node (review verdict: deterministic,
##   one access point → one node). Which subnet the port sits in is set at generation: its own
##   zone half the time, otherwise one zone shallower, never the vault — physical access helps
##   but doesn't map 1:1 onto the NET.
## - net_scale "intro": one small subnet, no firewalls, at most a token ICE, for tutorial gigs.
## - Black ICE comes from a points budget (security × gig threat), spent per zone, deeper zones
##   getting more; book stats and costs (data/rules/black_ice.json).

const FILES_PER_SUBNET := 1
const BRANCH_SIZE := 4                       # content nodes per subnet before it branches (readability)
const COMPLEXITY := [0.0, 0.12, 0.35, 0.6]   # by security level (M2c review: ~1.6x leaner)
const BUDGET := [3, 10, 24, 44]              # ICE points by security level
const OWN_ZONE_ENTRY := 0.5                  # chance a port is wired into its own zone
const INTRO_BUDGET := 1                      # intro gigs: at most one Wisp/Raven


## Build the NET for structure `sid` from its devices.
static func generate(m: TacMap, dice: Dice, sid: int) -> NetArchitecture:
	var a := NetArchitecture.new()
	var st: Dictionary = m.structures[sid]
	var sec := clampi(int(st.security), 0, 3)
	var intro: bool = st.params.get("net_scale", "") == "intro"
	a.structure = sid
	a.scale = "intro" if intro else "normal"
	a.difficulty = sec
	a.complexity = 0.0 if intro else COMPLEXITY[sec]
	var dv: int = RulesDB.load_json("net.json")["difficulty"][sec]["dv"]
	var per_floor := false  # M2d review: one subnet per security level; complexity lives in routes, not volume
	var mz: int = TacMap.Zone.PUBLIC if intro else int(st.get("max_zone", MapGen.max_zone(sec)))
	var devices := m.devices.filter(func(d): return d.get("structure", -1) == sid)

	# 1. Content buckets keyed by subnet: Vector2i(zone, building floor or 0).
	var buckets := {}
	var key_of := func(zone: int, bfloor: int) -> Vector2i:
		return Vector2i(zone, bfloor / 2 if per_floor and zone > TacMap.Zone.PUBLIC else 0)  # one subnet per two floors
	var groups := {}
	var files := {}
	for d in devices:
		var z := mini(maxi(int(d.zone), TacMap.Zone.PUBLIC), mz)
		if d.group != "":
			if not groups.has(d.group):
				groups[d.group] = {"type": "control", "dv": dv, "group": d.group, "devices": [], "zone": z, "bfloor": d.floor}
			groups[d.group].devices.append(d.id)
			groups[d.group].zone = maxi(groups[d.group].zone, z)
		if d.has("file_value"):
			files.get_or_add(key_of.call(z, d.floor), []).append({"type": "file", "dv": dv, "device": d.id,
				"value": d.file_value, "zone": z, "net_only": d.type == "data_core"})
	for k in files:
		var fl: Array = files[k]
		# Data cores always get a File; ordinary terminals are capped, most valuable first.
		var cores := fl.filter(func(f): return f.net_only)
		var rest := fl.filter(func(f): return not f.net_only)
		rest.sort_custom(func(x, y): return x.value > y.value)
		buckets.get_or_add(k, []).append_array(cores + rest.slice(0, FILES_PER_SUBNET))
	for g in groups.values():
		buckets.get_or_add(key_of.call(g.zone, g.bfloor), []).append(g)
	# Net-only content (no device): master camera override and offsite backups, in the deepest zone.
	var deepest := Vector2i(mz, 0)
	for k in buckets:
		if k.x == mz:
			deepest = k
			break
	if sec >= 1 and not intro:
		var cams := []   # (deep nodes are a notch harder, capped at the book's top DV of 12, p210)
		for d in devices:
			if d.type == "camera":
				cams.append(d.id)
		buckets.get_or_add(deepest, []).append({"type": "control", "dv": mini(dv + 2, 12), "group": "master_cameras", "devices": cams, "zone": mz, "net_only": true})
	if sec >= 2 and not intro:
		buckets.get_or_add(deepest, []).append({"type": "file", "dv": mini(dv + 2, 12), "device": -1, "value": 4, "zone": mz, "net_only": true, "label": "offsite backup"})
	# Every NET holds at least one File, so a data gig always has something to pull (playtest: a site
	# of only cameras and locks left the objective empty).
	if not buckets.values().any(func(b): return b.any(func(x): return x.type == "file")):
		buckets.get_or_add(deepest, []).append({"type": "file", "dv": dv, "device": -1, "value": 2, "zone": mz, "net_only": true, "label": "records"})
	for z in range(TacMap.Zone.PUBLIC, mz + 1):  # every zone gets a subnet, even if empty
		if not buckets.keys().any(func(k): return k.x == z):
			buckets[Vector2i(z, 0)] = []

	# 2. Subnets. M2f review: branch *down* a level (Y), never sideways within a level (T). A
	#    level with more than BRANCH_SIZE items splits into several small subnets ("branches"),
	#    each entered through its own firewall from a subnet one level up.
	var branches := {}
	for k in buckets:
		var items := _shuffled(dice, buckets[k])
		# The entry level (L1) is the single trunk; branching starts one level down.
		var n := 1 if k.x == TacMap.Zone.PUBLIC else maxi(1, ceili(items.size() / float(BRANCH_SIZE)))
		for b in n:
			var key := Vector2i(k.x, k.y * 10 + b)
			branches[key] = []
		for i in items.size():
			branches[Vector2i(k.x, k.y * 10 + i % n)].append(items[i])
	var keys := branches.keys()
	keys.sort_custom(func(x, y): return x.x < y.x or (x.x == y.x and x.y < y.y))
	var hub_of := {}
	for k in keys:
		var snid := a.subnets.size()
		var hub := a.add_node({"type": "hub", "zone": k.x, "subnet": snid, "net_only": k.x >= TacMap.Zone.VAULT})
		a.subnets.append({"id": snid, "zone": k.x, "bfloor": k.y, "hub": hub})
		hub_of[k] = hub
		for item in branches[k]:
			item.erase("bfloor")
			item["subnet"] = snid
			a.link(hub, a.add_node(item))

	# 3. Firewalls into each deeper subnet; second routes and lateral links at high complexity.
	for k in keys:
		if k.x == TacMap.Zone.PUBLIC:
			continue
		var outer := _outer_subnets(keys, k)
		_firewall(a, hub_of[outer[0]], hub_of[k], k.x, dv)
		if outer.size() > 1 and dice.rng.randf() < 0.6 * a.complexity:
			_firewall(a, hub_of[outer[1]], hub_of[k], k.x, dv)
		elif dice.rng.randf() < 0.35 * a.complexity:
			_firewall(a, hub_of[outer[0]], hub_of[k], k.x, mini(dv + 2, 12))  # back door with a harder lock

	# 4. Jack-in points: at most one per subnet (M2c review: keep NETs lean); the other terminals
	#    stay on the map as plain terminals. Each kept one gets its own fixed port node.
	var ap_taken := {}
	for d in devices:
		if not d.get("access_point", false):
			continue
		var dk: Vector2i = key_of.call(mini(maxi(int(d.zone), TacMap.Zone.PUBLIC), mz), d.floor)
		if ap_taken.has(dk):
			d["access_point"] = false
			continue
		ap_taken[dk] = true
		var z := mini(maxi(int(d.zone), TacMap.Zone.PUBLIC), mini(mz, TacMap.Zone.SECURE))
		if z > TacMap.Zone.PUBLIC and dice.rng.randf() >= OWN_ZONE_ENTRY:
			z -= 1
		var level_keys := keys.filter(func(kk): return kk.x == z)
		var hub: int = hub_of[level_keys[dice.rng.randi_range(0, level_keys.size() - 1)]] if not level_keys.is_empty() else hub_of[keys[0]]
		var port := a.add_node({"type": "port", "zone": a.nodes[hub].zone, "subnet": a.nodes[hub].subnet, "device": d.id})
		a.link(hub, port)
		a.access_points.append({"device": d.id, "entry_node": port})

	# 4b. Every NET needs a way in: if no terminal qualified (small sites like the skirmish bar),
	#     the most public device doubles as a jack-in point on an L1 hub.
	if a.access_points.is_empty() and not devices.is_empty():
		var pick: Dictionary = devices[0]
		for d in devices:
			if int(d.zone) < int(pick.zone) or (int(d.zone) == int(pick.zone) and String(d.type) == "terminal"):
				pick = d
		pick["access_point"] = true
		var l1 := keys.filter(func(kk): return kk.x == keys[0].x)
		var hub2: int = hub_of[l1[0]] if not l1.is_empty() else hub_of[keys[0]]
		var port2 := a.add_node({"type": "port", "zone": a.nodes[hub2].zone, "subnet": a.nodes[hub2].subnet, "device": pick.id})
		a.link(hub2, port2)
		a.access_points.append({"device": pick.id, "entry_node": port2})

	# 5. Black ICE from the budget.
	_spend_ice(a, dice, keys, hub_of, float(st.params.get("net_threat", 1.0)), intro)
	return a


## Subnets one zone shallower, same building floor first.
static func _outer_subnets(keys: Array, k: Vector2i) -> Array:
	var out := keys.filter(func(o): return o.x == k.x - 1)
	out.sort_custom(func(x, y): return absi(x.y - k.y) < absi(y.y - k.y))
	return out


static func _firewall(a: NetArchitecture, outer_hub: int, inner_hub: int, zone: int, dv: int) -> void:
	var fw := a.add_node({"type": "firewall", "zone": zone, "subnet": a.nodes[inner_hub].subnet, "dv": dv})
	a.link(outer_hub, fw)
	a.link(fw, inner_hub)


## Spend the whole-site budget: each pick prefers the strongest affordable ICE, then lands in a
## subnet chosen with weight = zone depth (deeper zones get more), guarding a node or patrolling.
static func _spend_ice(a: NetArchitecture, dice: Dice, keys: Array, hub_of: Dictionary, threat: float, intro: bool) -> void:
	var table: Dictionary = RulesDB.load_json("black_ice.json")["ice"]
	a.budget = INTRO_BUDGET if intro else roundi(BUDGET[a.difficulty] * threat)
	var zone_w := PackedFloat32Array()
	for k in keys:
		zone_w.append(float(k.x) * float(k.x))  # public 1, staff 4, secure 9, vault 16
	while a.spent < a.budget:
		var left := a.budget - a.spent
		var options := []
		var wts := PackedFloat32Array()
		for kind in table:
			var e: Dictionary = table[kind]
			if int(e.tier) <= a.difficulty and int(e.points) <= left:
				options.append(kind)
				wts.append(pow(float(e.points), 1.5))
		if options.is_empty():
			break
		var kind: String = options[dice.rng.rand_weighted(wts)]
		var k: Vector2i = keys[dice.rng.rand_weighted(zone_w)]
		var sid: int = a.nodes[hub_of[k]].subnet
		var guardable := a.nodes.filter(func(n): return n.subnet == sid and n.type in ["file", "control", "firewall"])
		var patrol := dice.rng.randf() < 0.5 * a.complexity
		var node: int = hub_of[k] if patrol or guardable.is_empty() else guardable[dice.rng.randi_range(0, guardable.size() - 1)].id
		a.ice.append({"id": a.ice.size(), "kind": kind, "node": node, "patrol": patrol})
		a.spent += int(table[kind].points)


static func _shuffled(dice: Dice, arr: Array) -> Array:
	var out := arr.duplicate()
	Layouts._shuffle(dice, out)
	return out
