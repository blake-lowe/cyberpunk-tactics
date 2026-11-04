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
	var a: Array = m.params.hazard_area
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
	# The MIST spares Net54 and zaps the contestants' implants.
	e.hazard.force_stage(4)
	var far := Vector3i(e.hazard.area.position.x + 1, e.hazard.area.end.y - 2, m.street)
	assert_true(e.hazard.outside(far), "a corner outside the final circle")
	var c: Dictionary = cs[0]
	c.pos = far
	var hp: int = c.c.hp
	e._hazard_harm(c)
	assert_true(c.c.hp < hp, "the MIST hits a contestant")
	var g: Dictionary = e.opfor()[0]
	var gpos: Vector3i = g.pos
	g.pos = far
	hp = g.c.hp
	e._hazard_harm(g)
	assert_eq(g.c.hp, hp, "Net54's people carry transponders")
	g.pos = gpos


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
func _with_turret(seed_n := 7) -> Dictionary:
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
	m.devices.append({"id": m.devices.size(), "type": "turret", "floor": spot.z, "pos": Vector2i(spot.x, spot.y), "room": m.label(spot.z, spot.x, spot.y),
		"zone": 0, "group": "turrets_test", "structure": -1})
	var e := Encounter.setup(m, dice, _crew(dice), "eliminate")
	return {"e": e, "spot": spot, "deploy": Vector3i(d0.x, d0.y, m.street)}


func test_turret_stats_from_the_book() -> void:
	var c := Turret.make(1)
	assert_eq(c.skill_base("shoulder_arms"), 14, "Combat Number 14 (p.214)")
	assert_eq(c.skill_base("autofire"), 14, "for every mode")
	assert_eq(c.max_hp(), 25, "25 HP (p.214)")
	assert_eq(c.hp, 25, "fresh")
	assert_false(c.can_dodge_ranged(), "cannot dodge")
	assert_eq(c.weapons[0].id(), "assault_rifle", "an assault rifle")


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


func test_netrunner_turns_a_turret() -> void:
	var s := _with_turret()
	var e: Encounter = s.e
	var t: Dictionary = e.units.filter(func(u): return u.has("turret"))[0]
	# Hang the turret on a control node of any NET on the map and let the runner hold it.
	var arch: NetArchitecture = null
	var node := {}
	for sid in e.m.architectures:
		for n in (e.m.architectures[sid] as NetArchitecture).nodes:
			if node.is_empty() and String(n.type) == "control":
				arch = e.m.architectures[sid]
				node = n
	if node.is_empty():
		assert_true(false, "the map has a NET with a control node")
		return
	node.devices.append(int(t.turret))
	var runner: Dictionary = e.alive(Encounter.CREW)[1]
	var run := NetRun.new(arch, runner.c)
	run.held[node.id] = true
	e.runs[runner.id] = run
	e._retake_turrets()
	assert_true(e.allied(int(t.team), Encounter.CREW), "it fires for the crew now")
	assert_true(e.hostile(int(t.team), Encounter.OPFOR), "at the site's people")
	assert_true(t.alerted and e.init.order().has(t.c), "on its own turn")
	for u in e.alive(Encounter.CREW):
		u.c.dead = true   # off the board: the guard is all it can see
	var g: Dictionary = e.opfor()[0]
	g.pos = s.deploy
	_turn_of(e, t)
	var n0 := e.events.size()
	AI.turret(e, t)
	var shots := e.events.slice(n0).filter(func(ev): return ev.type == "attack")
	assert_false(shots.is_empty(), "it shoots the guard")
	for u in e.units:
		if u.team == Encounter.CREW:
			u.c.dead = false
	e._drop_run(runner.id, false)
	assert_true(e.hostile(int(t.team), Encounter.CREW), "jacking out hands it back to the site (p199)")
