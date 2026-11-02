extends TestCase


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func test_setup_places_crew_and_guards() -> void:
	var m := SceneGen.generate(11, "street_block", {"security": 2})
	var dice := Dice.new(1)
	var e := Encounter.setup(m, dice, _crew(dice))
	assert_eq(e.units.filter(func(u): return u.team == 0).size(), 2)
	assert_eq(e.units.filter(func(u): return u.team == 1).size(), Recruit.opposition(2, 2).size(), "the p399 budget for 2 crew at security 2")
	assert_true(e.units.any(func(u): return u.team == 1 and u.c.role == "lieutenant"), "security 2 brings a Lieutenant")
	for u in e.units:
		assert_true(m.walkable(u.pos.z, Vector2i(u.pos.x, u.pos.y)), "%s placed on open ground" % u.c.display_name)
	assert_true(e.objective.get("node", -1) >= 0, "the target NET has a File to steal")


func test_shooting_cover_destroys_it_and_opens_sight() -> void:
	var m := TacMap.new(8, 3, 1)
	for y in 3:
		for x in 8:
			m.set_t(0, x, y, TacMap.T.FLOOR)
	m.add_cover(Furnish.cover_entry("desk", 0, Vector2i(4, 1), -1))  # wood thin, 5 HP
	m.entrances.append({"floor": 0, "pos": Vector2i(1, 1), "kind": "deploy", "main": false, "cells": [Vector2i(1, 1)]})
	var dice := Dice.new(3)
	var crew: Array[Combatant] = [Fixtures.shooter("A")]
	crew[0].weapons.append(Weapon.from_id("heavy_pistol"))
	var e := Encounter.setup(m, dice, crew)
	e.cur = e.units[0]
	e.turn = TurnState.begin(dice, crew[0])
	var target := Vector3i(7, 1, 0)
	assert_false(e.los.sight(Vector3i(1, 1, 0), target).visible, "desk blocks the line")
	var r := e.shoot_cover(Vector3i(4, 1, 0), crew[0].weapons[0])
	assert_true(r.ok)
	assert_eq(r.left, 0, "3d6 always beats a 5 HP desk")
	assert_true(e.los.trace(Vector3i(1, 1, 0), target).clear, "sight opens")
	assert_true(m.walkable(0, Vector2i(4, 1)), "and so does the path")
	var ev: Dictionary = e.events.filter(func(x): return x.type == "cover")[-1]
	assert_eq(int(ev.left), 0, "the event carries the HP left, so playback shows the break on the right shot")
	assert_true(ev.get("is_cover", false))


func test_netrunner_unlocks_doors_and_steals_the_file() -> void:
	var m := SceneGen.generate(11, "lone_building", {"site": "corp_office", "security": 1})
	var dice := Dice.new(9)
	var e := Encounter.setup(m, dice, _crew(dice))
	var runner: Dictionary = e.units[1]
	var a: NetArchitecture = m.architecture
	# Put the runner beside the first access point and jack in.
	var ap_dev: Dictionary = m.devices[a.access_points[0].device]
	runner.pos = Vector3i(ap_dev.pos.x, ap_dev.pos.y, ap_dev.floor)
	e.cur = runner
	e.turn = TurnState.begin(dice, runner.c)
	assert_false(e.jack_points(runner).is_empty(), "access point in range")
	assert_true(e.jack_in(e.jack_points(runner)[0]))
	var run: NetRun = e.runs[runner.id]
	# Clear the way for the test: break every firewall and derez the ICE, then walk to the File.
	for n in a.nodes_of_type("firewall"):
		run.broken[n.id] = true
	for i in a.ice:
		i["derezzed"] = true
	assert_true(run.move_to(e.objective.node), "path to the target File")
	var tries := 0
	while not e.objective.done and tries < 40:
		e.net_left = 3
		e.net_action("eye_dee")
		tries += 1
	assert_true(e.objective.done, "Eye-Dee on the target File completes the objective")
	e._check_end()
	assert_eq(e.state, "won")


func test_auto_battle_runs_to_an_end() -> void:
	for seed in [5, 6]:
		var m := SceneGen.generate(seed, "lone_building", {"site": "warehouse", "security": 0})
		var dice := Dice.new(seed)
		var e := Encounter.setup(m, dice, _crew(dice))
		var guard := 0
		e.next_turn()
		while e.state == "playing" and guard < 400:
			AI.act(e, e.cur)
			e.end_turn()
			e.next_turn()
			guard += 1
		assert_true(e.log.size() > 0, "things happened")
		assert_true(e.state in ["won", "lost", "playing"])


func _corridor_encounter(guard_at: Vector2i, wall_x := -1) -> Encounter:
	var m := TacMap.new(30, 3, 1)
	for y in 3:
		for x in 30:
			m.set_t(0, x, y, TacMap.T.WALL if x == wall_x else TacMap.T.FLOOR)
	m.entrances.append({"floor": 0, "pos": Vector2i(1, 1), "kind": "deploy", "main": false, "cells": [Vector2i(1, 1)]})
	m.posts.append({"floor": 0, "pos": guard_at, "structure": -1, "zone": 1, "kind": "door"})
	var dice := Dice.new(4)
	var crew: Array[Combatant] = [Fixtures.shooter("A")]
	crew[0].weapons.append(Weapon.from_id("heavy_pistol"))
	return Encounter.setup(m, dice, crew)


func _in_init(e: Encounter, u: Dictionary) -> bool:
	return e.init.entries.any(func(x): return x.c == u.c)


func test_unalerted_guards_stay_out_of_initiative() -> void:
	var e := _corridor_encounter(Vector2i(25, 1), 10)  # a wall between crew and guard
	var g: Dictionary = e.units[1]
	assert_false(g.alerted)
	assert_false(_in_init(e, g), "guard who hasn't seen anyone isn't in the rotation")
	e.next_turn()
	assert_eq(e.cur.team, 0, "only the crew takes turns")


func test_guard_in_sight_joins_initiative() -> void:
	var e := _corridor_encounter(Vector2i(12, 1))
	var g: Dictionary = e.units[1]
	for v in e.m.w:   # light the corridor
		e.lit[Vector3i(v, 1, 0)] = true
	g.facing = Vector2(-1, 0)   # looking down the corridor at the crew
	g.alerted = false
	var spotted := false
	for k in 30:   # Perception vs Stealth: a contest, not a certainty
		if not e.update_alerts().is_empty():
			spotted = true
			break
	assert_true(spotted, "facing the crew in a lit corridor: spotted within a few looks")
	assert_true(_in_init(e, g))
	assert_eq(e.alarm, 1)


func test_guard_facing_away_or_in_the_dark_is_slower() -> void:
	var e := _corridor_encounter(Vector2i(12, 1))
	var g: Dictionary = e.units[1]
	g.facing = Vector2(1, 0)   # back turned
	g.alerted = false
	for k in 30:
		e.update_alerts()
	assert_false(g.alerted, "11 squares behind the guard's back: never seen")
	g.facing = Vector2(-1, 0)
	e.lit.clear()
	var hits := 0
	for k in 200:
		e._spot_rolls.clear()
		if e._spots(g, e.units[0]):
			hits += 1
	for v in e.m.w:
		e.lit[Vector3i(v, 1, 0)] = true
	var lit_hits := 0
	for k in 200:
		e._spot_rolls.clear()
		if e._spots(g, e.units[0]):
			lit_hits += 1
	assert_true(lit_hits > hits, "darkness makes the crew harder to spot (-4)")


func test_gunfire_alerts_guards_behind_walls() -> void:
	var e := _corridor_encounter(Vector2i(12, 1), 6)
	var g: Dictionary = e.units[1]
	assert_false(g.alerted)
	e.next_turn()
	e.los.cover_hp[Vector3i(3, 1, 0)] = 10  # something to shoot at
	e.shoot_cover(Vector3i(3, 1, 0), e.cur.c.weapons[0])
	assert_true(g.alerted, "a shot 11 squares away is heard")
	assert_true(_in_init(e, g))


func test_run_spends_the_action_for_a_second_move() -> void:
	var e := _corridor_encounter(Vector2i(28, 0), 26)  # guard walled off at the far end
	e.next_turn()
	var mv: int = e.cur.c.stat("MOVE")
	var far := Vector3i(1 + mv + 2, 1, 0)
	assert_false(e.move_to(far), "beyond one Move Action without running")
	assert_true(e.move_to(far, true), "Run covers the rest (p127: an additional Move Action)")
	assert_false(e.turn.action_available, "running used the Action")
	assert_eq(e.events.filter(func(x): return x.type == "move").back().run, true)


func test_skirmish_always_has_guards() -> void:
	for seed in [11, 12, 13]:
		var m := SceneGen.generate(seed, "skirmish", {"security": 1})
		var dice := Dice.new(seed)
		var e := Encounter.setup(m, dice, _crew(dice))
		assert_eq(e.units.filter(func(u): return u.team == 1).size(), Recruit.opposition(2, 1).size(), "the full budget is placed even without posts")


func test_failed_death_save_emits_a_death_event() -> void:
	var m := SceneGen.generate(11, "street_block", {"security": 1})
	var dice := Dice.new(4)
	var crew := _crew(dice)
	var e := Encounter.setup(m, dice, crew)
	crew[1].hp = 0          # Mortally Wounded (p221)
	crew[1].dsp = 50        # and certain to fail the save
	var died := false
	for k in 6:
		e.end_turn()
		e.next_turn()
		if e.events.any(func(x): return x.type == "death" and e.units[x.unit].c == crew[1]):
			died = true
			break
	assert_true(died, "the view gets a death event to animate")
	assert_true(crew[1].dead)


func test_alerted_guard_calls_in_backup_which_arrives_rounds_later() -> void:
	var m := SceneGen.generate(11, "street_block", {"security": 1})
	var dice := Dice.new(1)
	var e := Encounter.setup(m, dice, _crew(dice))
	var before := e.units.size()
	var g: Dictionary = e.units.filter(func(u): return u.team == 1)[0]
	e._rouse([g])
	assert_eq(e.alarm, 1)
	var arrived := false
	for k in 60:
		e.end_turn()
		e.next_turn()
		if e.state != "playing":
			break
		if e.units.size() > before:
			arrived = true
			break
	assert_true(e.alarm == 2, "the guard called it in")
	assert_true(arrived, "backup turned up")
	assert_true(e.units.filter(func(u): return u.c.display_name.begins_with("Backup")).all(func(u): return u.alerted), "backup arrives alerted")


func test_patrols_walk_their_route() -> void:
	var m := SceneGen.generate(11, "street_block", {"security": 2})
	var dice := Dice.new(4)
	var e := Encounter.setup(m, dice, _crew(dice))
	var walkers: Array = e.units.filter(func(u): return u.team == 1 and u.has("patrol") and not u.alerted)
	assert_false(walkers.is_empty(), "some guards patrol")
	var w: Dictionary = walkers[0]
	var start: Vector3i = w.pos
	e.patrol_step()
	assert_true(w.alerted or w.pos != start, "a patrol step moves the guard (unless it just spotted someone)")
	assert_true(e.events.any(func(x): return x.type == "move" and x.get("patrol", false)))


func _snatch() -> Encounter:
	var m := SceneGen.generate(5, "lone_building", {"security": 1})
	var d := Dice.new(9)
	var crew: Array[Combatant] = [Recruit.generate(d, "solo", "edgerunner")]
	return Encounter.setup(m, d, crew, "snatch")


func test_snatch_package_sits_in_the_target_building_reachable() -> void:
	var e := _snatch()
	var cell: Vector3i = e.objective.cell
	var l := e.m.label(cell.z, cell.x, cell.y)
	assert_true(l >= 0, "package indoors")
	var sid := -1
	for st in e.m.structures:
		if st.target:
			sid = st.id
	assert_eq(e.m.rooms[l].structure, sid)
	assert_true(e.nav.distance_field([e.units[0].pos], {}).has(cell), "crew can walk to it")


func test_snatch_grab_then_extract_wins() -> void:
	var e := _snatch()
	e.next_turn()
	while e.cur.team != 0:
		e.end_turn()
		e.next_turn()
	var u := e.cur
	var start: Vector3i = u.pos
	assert_false(e.grab().ok, "too far to grab")
	u.pos = e.objective.cell
	e.turn.action_available = true
	assert_true(e.grab().ok)
	assert_eq(int(e.objective.carrier), u.id)
	assert_eq(e.state, "playing", "holding it isn't enough")
	u.pos = start + Vector3i(0, 0, 0)
	e._check_end()
	assert_eq(e.state, "won", "carried out through the deploy zone")


func test_snatch_carrier_down_drops_package() -> void:
	var e := _snatch()
	e.next_turn()
	while e.cur.team != 0:
		e.end_turn()
		e.next_turn()
	var u := e.cur
	u.pos = e.objective.cell + Vector3i(1, 0, 0) if e.m.walkable(e.objective.cell.z, Vector2i(e.objective.cell.x + 1, e.objective.cell.y)) else e.objective.cell
	assert_true(e.grab().ok)
	u.c.hp = 0
	u.c.dead = true
	e._check_end()
	assert_eq(int(e.objective.carrier), -1)
	assert_eq(e.objective.cell, u.pos)


func test_eliminate_ignores_the_file_and_waits_for_backup() -> void:
	var m := SceneGen.generate(5, "lone_building", {"security": 1})
	var d := Dice.new(9)
	var crew: Array[Combatant] = [Recruit.generate(d, "solo", "edgerunner")]
	var e := Encounter.setup(m, d, crew, "eliminate")
	assert_false(e.objective.has("node"))
	for g in e.units:
		if g.team == 1:
			g.c.dead = true
	e.backup_in = 2
	e._check_end()
	assert_eq(e.state, "playing", "backup still coming")
	e.backup_in = -1
	e._check_end()
	assert_eq(e.state, "won")


func test_twists_heavy_blackout_shift_change() -> void:
	var m := SceneGen.generate(5, "lone_building", {"security": 1})
	var crew: Array[Combatant] = [Recruit.generate(Dice.new(9), "solo", "edgerunner")]
	var plain := Encounter.setup(m, Dice.new(9), crew)
	var crew2: Array[Combatant] = [Recruit.generate(Dice.new(9), "solo", "edgerunner")]
	var e := Encounter.setup(SceneGen.generate(5, "lone_building", {"security": 1}), Dice.new(9), crew2, "data", ["heavy", "blackout", "shift_change"])
	assert_true(e.units.any(func(u): return u.team == 1 and u.c.role == "lieutenant"), "heavy: security 2 opposition brings a Lieutenant")
	assert_false(plain.units.any(func(u): return u.team == 1 and u.c.role == "lieutenant"))
	assert_true(plain.lit.size() > 0 and e.lit.is_empty(), "blackout: no lights")
	e.next_turn()
	var guard := 0
	while e.init.round_num < Encounter.SHIFT_CHANGE_ROUND and guard < 200:
		e.end_turn()
		e.next_turn()
		guard += 1
	assert_eq(e.alarm, 2, "shift change calls it in")


func test_watched_cells_follow_the_cone() -> void:
	var m := SceneGen.generate(5, "lone_building", {"security": 1})
	var crew: Array[Combatant] = [Recruit.generate(Dice.new(9), "solo", "edgerunner")]
	var e := Encounter.setup(m, Dice.new(9), crew)
	var g: Dictionary = e.units.filter(func(u): return u.team == 1)[0]
	g.facing = Vector2(1, 0)
	var w := e.watched_cells(g)
	assert_true(w.size() > 0)
	for v in w:
		var d := Vector2(v.x - g.pos.x, v.y - g.pos.y)
		assert_true(d.length() <= Encounter.AWARE_RANGE or rad_to_deg(absf(Vector2(1, 0).angle_to(d))) <= Encounter.VIEW_HALF_ANGLE, "inside the cone")


func test_spot_roll_is_once_per_round() -> void:
	var e := _corridor_encounter(Vector2i(6, 1))
	var g: Dictionary = e.units[1]
	g.facing = Vector2(-1, 0)
	var first := e._spots(g, e.units[0])
	for k in 20:
		assert_eq(e._spots(g, e.units[0]), first, "no rerolling the same contest within a round")


func test_ncpd_follows_backup_if_the_fight_goes_on() -> void:
	var m := SceneGen.generate(11, "street_block", {"security": 1})
	var dice := Dice.new(1)
	var e := Encounter.setup(m, dice, _crew(dice))
	e.alarm = 2
	e.backup_in = 1
	e._backup_round = -5
	e.next_turn()
	assert_eq(e.ncpd_in, Encounter.NCPD_ROUNDS, "backup arrived and the clock started")
	var cops := false
	for k in 200:
		for u in e.units:
			if u.team == 0:
				u.c.hp = u.c.max_hp()   # keep the crew alive for the test
		e.end_turn()
		e.next_turn()
		if e.units.any(func(u): return u.c.display_name.begins_with("NCPD")):
			cops = true
			break
	assert_true(cops, "NCPD responds")
	assert_eq(e.ncpd_in, -2, "only once")


func test_withdraw_needs_everyone_up_in_the_zone_and_leaves_the_rest() -> void:
	var m := SceneGen.generate(11, "street_block", {"security": 1})
	var dice := Dice.new(1)
	var e := Encounter.setup(m, dice, _crew(dice))
	e.next_turn()
	while e.cur.team != 0:
		e.end_turn()
		e.next_turn()
	var crew := e.units.filter(func(u): return u.team == 0)
	assert_true(e.can_withdraw(), "everyone starts in the deploy zone")
	crew[1].pos = crew[1].pos + Vector3i(0, 0, 0)
	crew[1].c.unconscious = true   # out cold: can't walk out
	assert_true(e.can_withdraw())
	assert_eq(e.left_behind().size(), 1)
	assert_true(e.withdraw())
	assert_eq(e.state, "fled")
	assert_true(crew[1].c.dead, "left behind")
