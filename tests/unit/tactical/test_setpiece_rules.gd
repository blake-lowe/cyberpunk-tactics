extends TestCase
## Set piece rules the encounter honours (setpieces.json `rules`): Totentanz's neutral ground
## (NeutralGround, NC2045 p.94), the Combat Zone's contestants (FreeForAll, p.216) and automated
## turrets (Turret, CPR core p.214).

static var _cache: Dictionary = {}


func _map(id: String, s: int) -> TacMap:
	var key := "%s/%d" % [id, s]
	if not _cache.has(key):
		_cache[key] = SceneGen.generate(s, "lone_building", {"setpiece": id})
	return _cache[key]


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func _cells_of(m: TacMap, kind: String) -> Array:
	for r in m.rooms:
		if r.cells > 0 and r.kind == kind and int(r.floor) == m.street:
			return Furnish.room_cells(m, r).filter(func(c): return m.walkable(m.street, c) and not m.has_cover_at(m.street, c))
	return []


## Make `u` the unit whose turn it is (tests drive single actions).
func _turn_of(e: Encounter, u: Dictionary) -> void:
	e.cur = u
	e.turn = TurnState.begin(e.dice, u.c)


## A square next to `v` the unit can stand on, with a clear line to it.
func _beside(e: Encounter, v: Vector3i) -> Vector3i:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c := Vector3i(v.x + d.x, v.y + d.y, v.z)
		if e.m.walkable(c.z, Vector2i(c.x, c.y)) and not e.occupied().has(c) and e.adjacent(v, c):
			return c
	return Vector3i(-1, -1, -1)


# --- Totentanz: no fighting on the floor -------------------------------------------------

func _totentanz(s := 2024) -> Encounter:
	var dice := Dice.new(4)
	return Encounter.setup(_map("totentanz", s), dice, _crew(dice), "assassinate", {"faction": "maelstrom"})


func test_neutral_ground_holds_until_the_first_attack_inside() -> void:
	var e := _totentanz()
	assert_true(e.neutral != null, "Totentanz carries the rule")
	assert_true(e.neutral.holds, "the peace holds at the start")
	var bouncers := e.units.filter(func(u): return int(u.team) == e.neutral.side)
	assert_true(bouncers.size() >= 1, "the foyer's bouncer keeps the house")
	assert_eq(e.relation(e.neutral.side, Encounter.CREW), "neutral", "the house is neutral to the crew")
	assert_true(e.allied(e.neutral.side, Encounter.OPFOR), "and still Maelstrom")
	assert_true(e.log.any(func(l): return l.begins_with("TOTENTANZ: NO FIGHTING ON THE FLOOR")), "the briefing line")
	assert_eq(e.neutral.hud_text(), "TOTENTANZ · NO FIGHTING ON THE FLOOR", "the round tab line")
	var b: Dictionary = bouncers[0]
	var crew: Dictionary = e.alive(Encounter.CREW)[0]
	var floor_cells := _cells_of(e.m, "dance_floor")
	crew.pos = Vector3i(floor_cells[0].x, floor_cells[0].y, e.m.street)
	e.alarm = 2   # a fight somewhere else: the crew no longer passes as patrons
	e.update_alerts()
	e._noise(b.pos)
	assert_false(b.alerted, "bouncers don't join a fight they didn't see")
	var outside: Array = e.units.filter(func(u): return int(u.team) == Encounter.OPFOR and e.is_guard(u) and not u.get("vip", false))
	assert_false(outside.is_empty(), "Maelstrom outside the club")
	assert_false(AI._enemies(e, outside[0]).has(crew), "the rest of the house holds its fire at the crew on the floor")
	var lot := _cells_of(e.m, "rubble_field")
	crew.pos = Vector3i(lot[0].x, lot[0].y, e.m.street)
	assert_true(AI._enemies(e, outside[0]).has(crew), "out in the ruins the crew is fair game")
	# The crew starts it on the floor: the whole house turns.
	var at := _beside(e, b.pos)
	assert_true(at.x >= 0, "room beside the bouncer")
	crew.pos = at
	_turn_of(e, crew)
	var r := e.melee(b)
	assert_true(r.get("ok", false), "a punch at the bouncer")
	assert_false(e.neutral.holds, "the first attack inside breaks the peace")
	assert_eq(int(b.team), Encounter.OPFOR, "the bouncer is the opposition again")
	assert_true(b.alerted or b.c.dead or not b.c.can_act(), "and on the crew")
	assert_true(e.hostile(Encounter.CREW, int(b.team)), "hostile")
	assert_true(e.log.any(func(l): return l.contains("the peace is broken")), "the log says so")
	assert_true(e.events.any(func(ev): return ev.type == "peace_broken"), "an event for the view")
	assert_eq(e.neutral.hud_text(), "TOTENTANZ · THE HOUSE TURNS", "the round tab turns red")
	crew.pos = Vector3i(floor_cells[0].x, floor_cells[0].y, e.m.street)
	assert_true(AI._enemies(e, outside[0]).has(crew), "and the floor is no refuge any more")


func test_neutral_ground_outside_and_out_of_sight() -> void:
	var e := _totentanz()
	var b: Dictionary = e.units.filter(func(u): return int(u.team) == e.neutral.side)[0]
	var crew: Dictionary = e.alive(Encounter.CREW)[0]
	# Out in the ruins, out of every bouncer's sight: normal rules, the peace holds.
	var hidden := Vector3i(-1, -1, -1)
	for c in _cells_of(e.m, "rubble_field"):
		var v := Vector3i(c.x, c.y, e.m.street)
		if Vector2(v.x - b.pos.x, v.y - b.pos.y).length() > Encounter.SPOT_RANGE + 2:
			hidden = v
			break
	assert_true(hidden.x >= 0, "a corner of the ruins the bouncer can't see")
	crew.pos = hidden
	e._keep_peace(crew, [hidden + Vector3i(1, 0, 0)])
	assert_true(e.neutral.holds, "a fight out of the bouncers' sight leaves the house alone")
	# The bouncer steps out onto the plaza and watches a fight there: that breaks it too.
	var plaza := _cells_of(e.m, "plaza")
	var pair := []
	for a in plaza:
		for c in plaza:
			var va := Vector3i(a.x, a.y, e.m.street)
			var vc := Vector3i(c.x, c.y, e.m.street)
			if pair.is_empty() and Vector2(a - c).length() >= 2.0 and e.los.trace(va, vc).clear and not e.neutral.inside(va) and not e.neutral.inside(vc):
				pair = [va, vc]
	assert_eq(pair.size(), 2, "two plaza squares in sight of each other")
	b.pos = pair[0]
	crew.pos = pair[1]
	e._keep_peace(crew, [pair[1]])
	assert_false(e.neutral.holds, "an attack the bouncers can see turns the house")
	assert_true(b.alerted, "the bouncer is onto the crew")


func test_no_neutral_ground_elsewhere() -> void:
	var dice := Dice.new(5)
	var e := Encounter.setup(SceneGen.generate(7, "skirmish"), dice, _crew(dice), "eliminate")
	assert_true(e.neutral == null, "ordinary gigs have none")


# --- The Combat Zone's contestants ---------------------------------------------------------

func _combat_zone() -> Encounter:
	var dice := Dice.new(9)
	return Encounter.setup(_map("combat_zone", 11), dice, _crew(dice), "rescue", {"faction": "network_54"})


func test_contestants_roam_the_set_hostile_to_everyone() -> void:
	var e := _combat_zone()
	var m := e.m
	var cs := e.units.filter(func(u): return e.faction_of(u) == "contestants")
	assert_between(cs.size(), 3, 5, "a handful of contestants on the set")
	var a: Array = m.params.set_area
	var area := Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))
	var tsid := int(m.structures.filter(func(st): return st.target)[0].id)
	var t := int(cs[0].team)
	for u in cs:
		assert_eq(u.pos.z, m.street, "on the street floor")
		assert_true(area.has_point(Vector2i(u.pos.x, u.pos.y)), "on the set")
		var l := m.label(u.pos.z, u.pos.x, u.pos.y)
		assert_true(l < 0 or (int(m.rooms[l].structure) != tsid and m.rooms[l].kind != "production_lot"), "not in the bunker or the yard")
		assert_eq(String(u.c.block), "boosterganger", "a printed stat block")
		assert_false(u.alerted, "roaming, not yet onto anyone")
		assert_true(u.has("patrol"), "walking a beat")
	assert_true(e.hostile(t, Encounter.CREW), "hostile to the crew")
	assert_true(e.hostile(t, Encounter.OPFOR), "and to Net54's people")
	assert_false(e.hostile(t, Encounter.CIV_TEAM), "not to bystanders")
	assert_false(e.opfor().any(func(u): return int(u.team) == t), "not the gig's opposition")
	var ncpd := e.side_for("ncpd", "guard", true)
	assert_true(e.hostile(t, ncpd), "nor to whoever turns up later")
	assert_true(e.log.any(func(l): return l.begins_with("THE COMBAT ZONE")), "the briefing line")


func test_contestants_and_guards_fight_each_other() -> void:
	var e := _combat_zone()
	var m := e.m
	var c: Dictionary = e.units.filter(func(u): return e.faction_of(u) == "contestants")[0]
	var g: Dictionary = e.units.filter(func(u): return int(u.team) == Encounter.OPFOR and e.is_guard(u) and not u.get("vip", false) and not u.c.weapons.is_empty())[0]
	for u in e.alive(Encounter.CREW):
		u.c.dead = true   # off the board: the two sides only have each other
	var street := _cells_of(m, "arena_street")
	var pair := []
	for a in street:
		if not pair.is_empty():
			break
		for d in [Vector2i(4, 0), Vector2i(0, 4), Vector2i(3, 3)]:
			var va := Vector3i(a.x, a.y, m.street)
			var vb := Vector3i(a.x + d.x, a.y + d.y, m.street)
			if m.walkable(vb.z, Vector2i(vb.x, vb.y)) and not m.has_cover_at(vb.z, Vector2i(vb.x, vb.y)) and e.los.sight(va, vb).visible and not e.occupied().has(va) and not e.occupied().has(vb):
				pair = [va, vb]
				break
	assert_eq(pair.size(), 2, "two squares of street in sight of each other")
	c.pos = pair[0]
	g.pos = pair[1]
	c.alerted = true
	g.alerted = true
	_turn_of(e, c)
	var n0 := e.events.size()
	AI.act(e, c)
	var hits := e.events.slice(n0).filter(func(ev): return ev.type in ["attack", "shell", "blast"] and int(ev.unit) == int(c.id))
	assert_false(hits.is_empty(), "the contestant goes for someone")
	for ev in hits:
		if ev.has("target"):
			assert_true(e.hostile(int(c.team), int(e.units[int(ev.target)].team)), "a foe")
	if not g.c.can_act():
		return   # the contestant dropped them: nothing left to check
	_turn_of(e, g)
	n0 = e.events.size()
	AI.act(e, g)
	var back := e.events.slice(n0).filter(func(ev): return ev.type in ["attack", "shell", "blast", "move"] and int(ev.unit) == int(g.id))
	assert_false(back.is_empty(), "the guard engages the contestants")
	var shots := back.filter(func(ev): return ev.type == "attack")
	for ev in shots:
		assert_eq(e.faction_of(e.units[int(ev.target)]), "contestants", "at a contestant")


# --- Turrets ----------------------------------------------------------------------------------

## A skirmish map with a turret bolted on at an open square `d` squares from a crew member.
func _with_turret(seed_n := 7, weapon := "") -> Dictionary:
	var m := SceneGen.generate(seed_n, "skirmish")
	var dice := Dice.new(5)
	var deploy: Dictionary = m.entrances.filter(func(x): return x.kind == "deploy")[0]
	var d0: Vector2i = deploy.get("cells", [deploy.pos])[0]
	var spot := Vector3i(-1, -1, -1)
	var los := Los.new(m)
	for r in range(5, 9):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var v := Vector3i(d0.x + dx, d0.y + dy, m.street)
				if spot.x < 0 and m.inb(v.x, v.y) and m.walkable(v.z, Vector2i(v.x, v.y)) and not m.has_cover_at(v.z, Vector2i(v.x, v.y)) \
						and Vector2(dx, dy).length() >= 5 and los.sight(v, Vector3i(d0.x, d0.y, m.street)).visible:
					spot = v
	var dev := {"id": m.devices.size(), "type": "turret", "floor": spot.z, "pos": Vector2i(spot.x, spot.y), "room": m.label(spot.z, spot.x, spot.y),
		"zone": 0, "group": "turrets_test", "structure": -1}
	if weapon != "":
		dev["weapon"] = weapon
	m.devices.append(dev)
	var e := Encounter.setup(m, dice, _crew(dice), "eliminate")
	return {"e": e, "spot": spot, "deploy": Vector3i(d0.x, d0.y, m.street)}


func test_turret_stats_from_the_book() -> void:
	var c := Turret.make(1)
	assert_eq(c.skill_base("shoulder_arms"), 14, "Combat Number 14 (p.214)")
	assert_eq(c.skill_base("autofire"), 14, "for every mode")
	assert_eq(c.max_hp(), 25, "25 HP (p.214)")
	assert_eq(c.hp, 25, "fresh")
	assert_false(c.can_dodge_ranged(), "cannot dodge")
	assert_eq(c.weapons[0].id(), "assault_rifle", "an assault rifle by default")
	assert_eq(c.weapons[0].ammo, 25, "Assault Rifle (25)")


func test_turret_armaments_and_their_rounds() -> void:
	var rounds := {"assault_rifle": 25, "flamethrower": 4, "very_heavy_pistol": 8, "heavy_smg": 40}   # p.214
	for wid in rounds:
		assert_true(Turret.ARMAMENTS.has(wid), "%s is a turret gun" % wid)
		assert_false(RulesDB.weapon(wid).is_empty(), "%s exists in weapons.json" % wid)
		var w: Weapon = Turret.make(1, wid).weapons[0]
		assert_eq(w.id(), wid, "it mounts the gun asked for")
		assert_eq(w.ammo, int(rounds[wid]), "%s: %d rounds" % [wid, rounds[wid]])
	var vh: Weapon = Turret.make(1, "very_heavy_pistol").weapons[0]
	assert_eq(vh.special_left, 8, "VH Pistol (8 AP): every round armour-piercing")
	assert_eq(int(vh.special_fx.get("ablate_sp", 1)), 2, "AP ablates 2 (p.345)")
	assert_true(Turret.shells(Turret.make(1, "flamethrower").weapons[0]), "the flamethrower fires incendiary shells (p.348)")
	assert_eq(Turret.make(1, "dartgun").weapons[0].id(), "assault_rifle", "no dartgun until its darts are modelled")
	for site in RulesDB.gen("sites.json"):
		var gun := String(RulesDB.gen("sites.json")[site].get("turret_weapon", "")) if RulesDB.gen("sites.json")[site] is Dictionary else ""
		assert_true(gun == "" or Turret.ARMAMENTS.has(gun), "%s's turret_weapon is a turret gun" % site)


func test_a_sites_device_picks_the_gun() -> void:
	var s := _with_turret(7, "heavy_smg")
	var t: Dictionary = (s.e as Encounter).units.filter(func(u): return u.has("turret"))[0]
	assert_eq(t.c.weapons[0].id(), "heavy_smg", "the device's weapon")
	assert_eq(t.c.weapons[0].ammo, 40, "Heavy SMG (40)")


func test_turret_runs_dry_and_never_reloads() -> void:
	var s := _with_turret()
	var e: Encounter = s.e
	var t: Dictionary = e.units.filter(func(u): return u.has("turret"))[0]
	var crew: Dictionary = e.alive(Encounter.CREW)[0]
	crew.pos = s.deploy
	e.update_alerts()
	var w: Weapon = t.c.weapons[0]
	w.ammo = 1
	_turn_of(e, t)
	var n0 := e.events.size()
	AI.turret(e, t)
	assert_eq(e.events.slice(n0).filter(func(ev): return ev.type == "attack").size(), 1, "its last round")
	assert_eq(w.ammo, 0, "spent")
	for i in 3:
		_turn_of(e, t)
		var n1 := e.events.size()
		AI.turret(e, t)
		assert_true(e.events.slice(n1).filter(func(ev): return ev.type in ["attack", "shell", "reload"]).is_empty(), "empty: it stops firing")
	assert_eq(w.ammo, 0, "and nobody reloads it")


func test_flamethrower_turret_fires_its_shell_close_in() -> void:
	var s := _with_turret(7, "flamethrower")
	var e: Encounter = s.e
	var t: Dictionary = e.units.filter(func(u): return u.has("turret"))[0]
	var crew: Dictionary = e.alive(Encounter.CREW)[0]
	crew.pos = s.deploy
	e.update_alerts()
	_turn_of(e, t)
	var n0 := e.events.size()
	AI.turret(e, t)
	assert_true(e.events.slice(n0).filter(func(ev): return ev.type in ["attack", "shell"]).is_empty(), "out past 6 m: nothing")
	for u in e.alive(Encounter.CREW):
		u.pos = Vector3i(-50, -50, 0)
	crew.pos = _beside(e, t.pos)
	_turn_of(e, t)
	AI.turret(e, t)
	assert_eq(e.events.slice(n0).filter(func(ev): return ev.type == "shell" and int(ev.unit) == int(t.id)).size(), 1, "close in: a shell")
	assert_eq(t.c.weapons[0].ammo, 3, "one of its 4 shells")


func test_turret_fires_at_the_crew_on_the_sites_turn() -> void:
	var s := _with_turret()
	var e: Encounter = s.e
	var t: Dictionary = e.units.filter(func(u): return u.has("turret"))[0]
	assert_eq(t.pos, s.spot, "on its device")
	assert_true(e.hostile(int(t.team), Encounter.CREW), "the site's: hostile to the crew")
	assert_true(e.allied(int(t.team), Encounter.OPFOR), "and on the guards' side")
	assert_false(e.opfor().has(t), "not a guard to put down for the job")
	assert_false(e.is_guard(t), "no patrols, no spotting rolls")
	var crew: Dictionary = e.alive(Encounter.CREW)[0]
	crew.pos = s.deploy
	e.update_alerts()
	assert_true(t.alerted, "it has a target: it wakes")
	assert_true(e.init.order().has(t.c), "and joins the Initiative order")
	_turn_of(e, t)
	var n0 := e.events.size()
	var p0: Vector3i = t.pos
	AI.turret(e, t)
	var shots := e.events.slice(n0).filter(func(ev): return ev.type == "attack" and int(ev.unit) == int(t.id))
	assert_false(shots.is_empty(), "it fires")
	assert_true(e.allied(int(e.units[int(shots[0].target)].team), Encounter.CREW), "at the crew")
	assert_eq(t.pos, p0, "and never moves")
	t.c.hp = 0
	e._check_end()
	assert_true(t.c.dead, "at 0 HP it is wrecked")


func test_turret_dead_without_power() -> void:
	var s := _with_turret()
	var e: Encounter = s.e
	var t: Dictionary = e.units.filter(func(u): return u.has("turret"))[0]
	e.outages.append("power")
	assert_true(e.turret_off(t), "no power, no turret")
	_turn_of(e, t)
	var n0 := e.events.size()
	AI.turret(e, t)
	assert_true(e.events.slice(n0).is_empty(), "silent")


## The turret awake (the crew in its sights), hung on a control node of a NET on the map that the
## crew's Netrunner holds; a guard stands where the crew was, in the turret's sights. It is the
## runner's turn, jacked in. {} if the map has no control node.
func _held_turret() -> Dictionary:
	var s := _with_turret()
	var e: Encounter = s.e
	var t: Dictionary = e.units.filter(func(u): return u.has("turret"))[0]
	var crew: Dictionary = e.alive(Encounter.CREW)[0]
	crew.pos = s.deploy
	e.update_alerts()
	var arch: NetArchitecture = null
	var node := {}
	for sid in e.m.architectures:
		for n in (e.m.architectures[sid] as NetArchitecture).nodes:
			if node.is_empty() and String(n.type) == "control":
				arch = e.m.architectures[sid]
				node = n
	if node.is_empty():
		assert_true(false, "the map has a NET with a control node")
		return {}
	node.devices.append(int(t.turret))
	var runner: Dictionary = e.alive(Encounter.CREW)[1]
	var run := NetRun.new(arch, runner.c)
	run.held[node.id] = true
	e.runs[runner.id] = run
	e._retake_turrets()
	crew.pos = Vector3i(-50, -50, 0)   # out of the way
	var g: Dictionary = e.opfor()[0]
	g.pos = s.deploy
	_turn_of(e, runner)
	e.net_left = 3
	return {"e": e, "t": t, "runner": runner, "run": run, "node": int(node.id), "guard": g, "crew": crew, "deploy": s.deploy}


func test_netrunner_holds_a_turret_and_it_stops_acting_alone() -> void:
	var h := _held_turret()
	if h.is_empty():
		return
	var e: Encounter = h.e
	var t: Dictionary = h.t
	assert_true(t.alerted, "it had woken before the runner took it")
	assert_eq(int(t.held_by), int(h.runner.id), "the runner holds it")
	assert_true(e.allied(int(t.team), Encounter.CREW), "it stands with the crew now")
	assert_true(e.hostile(int(t.team), Encounter.OPFOR), "against the site's people")
	assert_false(e.init.order().has(t.c), "a held turret has no turn of its own")
	_turn_of(e, t)
	var n0 := e.events.size()
	AI.turret(e, t)
	assert_true(e.events.slice(n0).is_empty(), "and doesn't fire by itself, guard in sight or not")
	var ht: Array = e.held_turrets(int(h.runner.id))
	assert_eq(ht.size(), 1, "the NET panel lists it")
	assert_eq(String(ht[0].why), "", "ready to fire")
	assert_true((ht[0].targets as Array).any(func(x): return int(x.id) == int(h.guard.id)), "with the guard in its sights")
	assert_false((ht[0].targets as Array).any(func(x): return e.allied(int(e.units[int(x.id)].team), Encounter.CREW)), "never the crew")


func test_fire_turret_is_a_net_action_once_per_turn_per_node() -> void:
	var h := _held_turret()
	if h.is_empty():
		return
	var e: Encounter = h.e
	var t: Dictionary = h.t
	var runner: Dictionary = h.runner
	var g: Dictionary = h.guard
	e.morale = false   # the same guard is shot three times: hurt, he'd break (Morale) and stop being a target
	runner.c.skills["shoulder_arms"] = 40   # the runner's own Skill aims it (p.213-214): a sure hit
	var w: Weapon = t.c.weapons[0]
	assert_true(e.turret_chance(t, g, runner.c) > e.turret_chance(t, g, t.c), "their Skill, not the turret's Combat Number")
	var n0 := e.events.size()
	var r := e.fire_turret(int(t.id), int(g.id))
	assert_true(r.ok, "fired")
	assert_true(r.hit, "with the runner's Skill")
	assert_eq(e.net_left, 2, "one NET Action")
	assert_false(e.turn.action_available, "the turn goes to the NET (p197)")
	assert_eq(w.ammo, 24, "one of its own rounds")
	var shots := e.events.slice(n0).filter(func(ev): return ev.type == "attack")
	assert_eq(shots.size(), 1, "one shot")
	assert_eq(int(shots[0].unit), int(t.id), "from the turret")
	assert_eq(int(shots[0].target), int(g.id), "at the guard")
	assert_eq(e.cur, runner, "still the runner's turn")
	g.c.hp = g.c.max_hp()
	g.c.dead = false
	var again := e.fire_turret(int(t.id), int(g.id))
	assert_false(again.ok, "the node was used this turn (p199)")
	assert_eq(e.net_left, 2, "nothing spent")
	assert_true(String(e.held_turrets(int(runner.id))[0].why) != "", "the panel greys it out")
	e.init.round_num += 1   # the runner's next turn
	_turn_of(e, runner)
	e.net_left = 3
	assert_true(e.fire_turret(int(t.id), int(g.id)).ok, "next turn it fires again")
	assert_false(e.fire_turret(int(t.id), int(h.crew.id)).ok, "never at the crew")


func test_held_turret_out_of_rounds_cannot_be_fired() -> void:
	var h := _held_turret()
	if h.is_empty():
		return
	var e: Encounter = h.e
	h.t.c.weapons[0].ammo = 0
	var r := e.fire_turret(int(h.t.id), int(h.guard.id))
	assert_false(r.ok, "empty")
	assert_eq(String(r.reason), "out of ammunition", "and says so")
	assert_eq(e.net_left, 3, "no NET Action spent")


func test_jacking_out_hands_the_turret_back() -> void:
	var h := _held_turret()
	if h.is_empty():
		return
	var e: Encounter = h.e
	var t: Dictionary = h.t
	e._drop_run(int(h.runner.id), false)
	assert_false(t.has("held_by"), "released (p199)")
	assert_true(e.hostile(int(t.team), Encounter.CREW), "the site's again")
	assert_true(e.init.order().has(t.c), "back in the Initiative order on its own 1d10")
	h.crew.pos = h.deploy
	h.guard.pos = Vector3i(-50, -50, 0)
	_turn_of(e, t)
	var n0 := e.events.size()
	AI.turret(e, t)
	var shots := e.events.slice(n0).filter(func(ev): return ev.type == "attack" and int(ev.unit) == int(t.id))
	assert_false(shots.is_empty(), "it acts on its own again (CN + 1d10, p.213)")
	assert_true(e.allied(int(e.units[int(shots[0].target)].team), Encounter.CREW), "at the crew")
