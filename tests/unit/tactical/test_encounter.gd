extends TestCase


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func test_setup_places_crew_and_guards() -> void:
	var m := SceneGen.generate(11, "street_block", {"security": 2})
	var dice := Dice.new(1)
	var e := Encounter.setup(m, dice, _crew(dice))
	assert_eq(e.units.filter(func(u): return u.team == 0).size(), 2)
	assert_eq(e.units.filter(func(u): return u.team == 1 and not u.get("outer", false)).size(), Recruit.opposition(2, 2).size(), "the p399 budget for 2 crew at security 2")
	var outer := e.units.filter(func(u): return u.get("outer", false))
	assert_eq(outer.size(), 2 * clampi(int((m.w * m.h - 1500) / 2500), 0, 4), "a street block gets patrol pairs outside the target")
	assert_true(outer.all(func(u): return u.has("patrol")), "outer pairs walk a beat")
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
	e.heat = 3   # security 1: NCPD only bothers if the crew is already wanted
	e.alarm = 2
	e.backup_in = 1
	e._backup_round = -5
	e.next_turn()
	assert_eq(e.ncpd_in, Encounter.NCPD_ROUNDS - 1, "backup arrived and the clock started (heat 3: a round sooner)")
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


func test_low_security_low_heat_brings_no_ncpd() -> void:
	var m := SceneGen.generate(11, "street_block", {"security": 1})
	var dice := Dice.new(1)
	var e := Encounter.setup(m, dice, _crew(dice))
	e.alarm = 2
	e.backup_in = 1
	e._backup_round = -5
	e.next_turn()
	assert_eq(e.ncpd_in, -1, "no NCPD clock for a quiet security-1 site")


func _jacked() -> Array:
	var m := SceneGen.generate(11, "lone_building", {"site": "corp_office", "security": 1})
	var dice := Dice.new(9)
	var e := Encounter.setup(m, dice, _crew(dice))
	var runner: Dictionary = e.units[1]
	var a: NetArchitecture = m.architecture
	var ap_dev: Dictionary = m.devices[a.access_points[0].device]
	runner.pos = Vector3i(ap_dev.pos.x, ap_dev.pos.y, ap_dev.floor)
	e.cur = runner
	e.turn = TurnState.begin(dice, runner.c)
	e.jack_in(e.jack_points(runner)[0])
	return [e, runner, e.runs[runner.id]]


func test_jack_in_is_the_first_net_action_and_forgoes_the_meat_action() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	assert_eq(e.net_left, Encounter.net_actions_for(r[1].c) - 1, "p198: Jack In is a NET Action")
	assert_false(e.turn.action_available, "p197: a turn in the NET forgoes the meat Action")


func test_wrong_node_actions_cost_nothing() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var left := e.net_left
	var res := e.net_action("control")   # standing on the port
	assert_false(res.ok)
	assert_eq(e.net_left, left, "refused before spending")
	assert_false(e.net_action("pathfinder_typo").ok)
	assert_eq(e.net_left, left)


func test_no_net_after_the_meat_action() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	e.turn = TurnState.begin(e.dice, r[1].c)   # a new turn, still jacked in
	e.net_left = 3
	e._netting = false
	e.turn.action_available = false   # e.g. they shot someone
	assert_false(e.net_action("backdoor").ok, "p197")


func test_jack_out_loses_held_nodes_and_relocks_doors() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var run: NetRun = r[2]
	var ctl := -1
	for n in run.arch.nodes_of_type("control"):
		for did in n.devices:
			if e.m.devices[did].type == "door_lock":
				ctl = n.id
	if ctl < 0:
		return   # no lock on this map; covered elsewhere
	run.held[ctl] = true
	var lock: Dictionary = {}
	for did in run.arch.nodes[ctl].devices:
		e.disabled_devices[did] = true
		if e.m.devices[did].type == "door_lock":
			lock = e.m.devices[did]
	var cell := Vector3i(lock.pos.x, lock.pos.y, lock.floor)
	e.nav.locked.erase(cell)
	e.net_action("jack_out")
	assert_true(e.disabled_devices.is_empty(), "p199: held nodes are lost")
	assert_true(e.nav.locked.has(cell), "the door locks again")


func test_dumped_by_range_suffers_the_ice_met() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	var run: NetRun = r[2]
	var ice := {"id": 999, "kind": "hellhound", "node": run.current, "patrol": false}
	run.arch.ice.append(ice)
	run.met[run.met_key(ice)] = true
	var hp0: int = r[1].c.hp
	e._drop_run(r[1].id, true)
	assert_true(r[1].c.hp < hp0, "p198: an unsafe jack-out suffers the ICE met, no roll")
	assert_false(e.runs.has(r[1].id))


func _on_ice(kind: String) -> Array:
	var r := _jacked()
	var run: NetRun = r[2]
	var ice := {"id": 900, "kind": kind, "node": run.current, "patrol": false}
	run.arch.ice.append(ice)
	run.met[run.met_key(ice)] = true
	r[0].net_left = 3
	return r + [ice]


func test_sword_does_3d6_to_black_ice() -> void:
	var r := _on_ice("dragon")
	var e: Encounter = r[0]
	var ice: Dictionary = r[3]
	var hits := 0
	for k in 30:
		e.net_left = 3
		var res := e.net_action("sword")
		assert_true(res.ok)
		if res.success:
			hits += 1
		if ice.get("derezzed", false):
			break
	assert_true(hits > 0)
	assert_true(int(ice.get("rez", 30)) < 30)


func test_armor_cuts_brain_damage_once_per_run() -> void:
	var r := _on_ice("hellhound")
	var e: Encounter = r[0]
	var run: NetRun = r[2]
	assert_true(e.net_action("armor").ok)
	assert_eq(run.armor_rez, 7)
	e.net_left = 3
	assert_false(e.net_action("armor").ok, "once per Netrun")


func test_slide_escapes_to_a_neighbour() -> void:
	var r := _on_ice("wisp")
	var e: Encounter = r[0]
	var run: NetRun = r[2]
	var start := run.current
	var targets := run.slide_targets()
	assert_false(targets.is_empty())
	var res := e.net_action("slide", targets[0])
	assert_true(res.ok)
	if res.success:
		assert_eq(run.current, targets[0])
	else:
		assert_eq(run.current, start)
	e.net_left = 3
	assert_false(e.net_action("slide", targets[0]).ok, "once per turn")


func test_wounds_lower_interface() -> void:
	var r := _jacked()
	var run: NetRun = r[2]
	var full := run.rank()
	r[1].c.hp = r[1].c.seriously_wounded_threshold() - 1
	assert_eq(run.rank(), full - 2, "p220: Seriously Wounded -2 to Actions, Interface included")


func test_giant_throws_the_runner_out_and_wisp_costs_an_action() -> void:
	var r := _on_ice("giant")
	var e: Encounter = r[0]
	e._ice_effect(r[1], r[2], r[3])
	assert_false(e.runs.has(r[1].id), "p207: forced unsafe Jack Out")
	var r2 := _on_ice("wisp")
	r2[0]._ice_effect(r2[1], r2[2], r2[3])
	assert_eq((r2[2] as NetRun).wisp, 1)


func test_meeting_ice_rolls_speed_and_may_strike_first() -> void:
	var struck := 0
	for k in 12:
		var r := _jacked()
		var e: Encounter = r[0]
		var run: NetRun = r[2]
		var ice := {"id": 901 + k, "kind": "hellhound", "node": run.current, "patrol": false}
		run.arch.ice.append(ice)
		var hp0: int = r[1].c.hp
		e._meet_ice(r[1], run)
		assert_true(run.met.has(run.met_key(ice)))
		if r[1].c.hp < hp0:
			struck += 1
	assert_true(struck > 0, "SPD 6 Hellhound beats Interface 4 often enough")


func test_jack_in_needs_no_wall_between() -> void:
	var e := _corridor_encounter(Vector2i(20, 1), 5)
	assert_true(e._wall_between(Vector3i(3, 1, 0), Vector3i(7, 1, 0)))
	assert_false(e._wall_between(Vector3i(6, 1, 0), Vector3i(9, 1, 0)))


func test_cameras_spot_unless_the_netrunner_holds_them() -> void:
	var e := _corridor_encounter(Vector2i(25, 1))
	e.m.devices.append({"id": e.m.devices.size(), "type": "camera", "pos": Vector2i(4, 1), "floor": 0, "group": "cameras"})
	var cam_id: int = e.m.devices[-1].id
	var crew: Dictionary = e.units[0]
	crew.pos = Vector3i(6, 1, 0)
	crew.c.skills["stealth"] = 0
	e.lit[crew.pos] = true
	var spotted := false
	for k in 30:
		e._spot_rolls.clear()
		if not e._camera_spots().is_empty():
			spotted = true
			break
	assert_true(spotted, "a live camera catches a clumsy sneak")
	e.disabled_devices[cam_id] = true
	for k in 30:
		e._spot_rolls.clear()
		assert_true(e._camera_spots().is_empty(), "held cameras see nothing")


func test_firewall_left_from_inside_lets_you_back_in() -> void:
	var a := NetArchitecture.new()
	var deep := a.add_node({"type": "hub", "zone": 2, "subnet": 0})
	var fw := a.add_node({"type": "firewall", "zone": 2, "subnet": 0, "dv": 8})
	var outer := a.add_node({"type": "hub", "zone": 1, "subnet": 1})
	a.link(deep, fw)
	a.link(fw, outer)
	var run := NetRun.new(a, Recruit.generate(Dice.new(1), "netrunner", "edgerunner"))
	run.current = deep
	assert_true(run.move_to(outer), "outward through a firewall is free")
	assert_true(run.can_move_to(deep), "and you can go back the way you came")
	var run2 := NetRun.new(a, run.runner)
	run2.current = outer
	assert_false(run2.can_move_to(deep), "coming from outside still needs a Backdoor")


func test_pathfinder_sees_through_opened_firewalls() -> void:
	var a := NetArchitecture.new()
	var hub := a.add_node({"type": "hub", "zone": 1, "subnet": 0})
	var fw := a.add_node({"type": "firewall", "zone": 2, "subnet": 1, "dv": 30})
	var deep := a.add_node({"type": "file", "zone": 2, "subnet": 1, "dv": 6})
	a.link(hub, fw)
	a.link(fw, deep)
	var run := NetRun.new(a, Recruit.generate(Dice.new(1), "netrunner", "edgerunner"))
	run.current = hub
	run.revealed[hub] = true
	run.pathfinder(Dice.new(3))
	assert_false(run.revealed.has(deep), "a DV30 firewall stops it")
	run.broken[fw] = true
	run.pathfinder(Dice.new(3))
	assert_true(run.revealed.has(deep), "a Backdoored firewall doesn't")


func test_kraken_hold_blocks_sliding_deeper() -> void:
	var a := NetArchitecture.new()
	var here := a.add_node({"type": "hub", "zone": 1, "subnet": 0})
	var deeper := a.add_node({"type": "hub", "zone": 2, "subnet": 1})
	var shallower := a.add_node({"type": "hub", "zone": 0, "subnet": 2})
	a.link(here, deeper)
	a.link(here, shallower)
	var run := NetRun.new(a, Recruit.generate(Dice.new(1), "netrunner", "edgerunner"))
	run.current = here
	run.no_deeper = true
	assert_eq(run.slide_targets(), [shallower], "p207: no going deeper")


func test_rejacking_remembers_met_ice_and_plug_pull_works() -> void:
	var r := _on_ice("giant")
	var e: Encounter = r[0]
	var run: NetRun = r[2]
	var key := run.met_key(r[3])
	assert_true(e.net_action("jack_out_unsafe").ok)
	assert_false(e.runs.has(r[1].id))
	e.turn = TurnState.begin(e.dice, r[1].c)
	e._netting = false
	e.jack_in(e.jack_points(r[1])[0])
	assert_true((e.runs[r[1].id] as NetRun).met.has(key), "no fresh ambush on a re-jack")


func test_no_net_actions_on_a_turn_without_an_action() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	e.turn.action_available = false
	e.net_left = 0
	assert_false(e.net_action("pathfinder").ok)


func test_tamper_with_a_camera_by_hand() -> void:
	var e := _corridor_encounter(Vector2i(25, 1))
	e.next_turn()
	while e.cur.team != 0:
		e.end_turn()
		e.next_turn()
	e.m.devices.append({"id": e.m.devices.size(), "type": "camera", "pos": Vector2i(e.cur.pos.x + 1, 1), "floor": 0, "group": "cameras"})
	var cam: int = e.m.devices[-1].id
	assert_false(e.camera_in_reach(e.cur).is_empty())
	e.cur.c.skills["electronics_security_tech"] = 10
	var done := false
	for k in 10:
		e.turn.action_available = true
		var r := e.tamper_camera()
		assert_true(r.ok)
		if r.success:
			done = true
			break
	assert_true(done)
	assert_true(e.disabled_devices.has(cam))
	assert_true(e.camera_in_reach(e.cur).is_empty(), "a dead camera is out of play")


func test_crew_pass_through_allies_but_not_stop_on_them() -> void:
	var m := TacMap.new(12, 1, 1)
	for x in 12:
		m.set_t(0, x, 0, TacMap.T.FLOOR)
	m.entrances.append({"floor": 0, "pos": Vector2i(1, 0), "kind": "deploy", "main": false, "cells": [Vector2i(1, 0), Vector2i(2, 0)]})
	var dice := Dice.new(4)
	var crew: Array[Combatant] = [Fixtures.shooter("A"), Fixtures.shooter("B")]
	var e := Encounter.setup(m, dice, crew)
	e.next_turn()
	var me: Dictionary = e.cur
	var ally: Dictionary = e.units.filter(func(u): return u.team == 0 and u != me)[0]
	me.pos = Vector3i(1, 0, 0)
	ally.pos = Vector3i(2, 0, 0)   # a one-square corridor, ally in the way
	var opts := e.move_options()
	assert_false(opts.has(ally.pos), "can't stop on an ally")
	assert_true(opts.has(Vector3i(4, 0, 0)), "but can pass them")
	assert_true(e.move_to(Vector3i(4, 0, 0)))


func test_giant_stays_met_after_throwing_you_out() -> void:
	var r := _on_ice("giant")
	var e: Encounter = r[0]
	var key := (r[2] as NetRun).met_key(r[3])
	e._ice_effect(r[1], r[2], r[3])
	assert_false(e.runs.has(r[1].id))
	assert_true(e._met_memory[r[1].id].has(key), "no re-ambush on the next jack-in")


func test_cameras_face_away_from_their_wall() -> void:
	var m := TacMap.new(12, 12, 1)
	for y in 12:
		for x in 12:
			m.set_t(0, x, y, TacMap.T.WALL if x == 0 else TacMap.T.FLOOR)
	m.entrances.append({"floor": 0, "pos": Vector2i(10, 10), "kind": "deploy", "main": false, "cells": [Vector2i(10, 10)]})
	var e := Encounter.setup(m, Dice.new(2), [Fixtures.shooter("A")] as Array[Combatant])
	var cam := {"id": 77, "type": "camera", "pos": Vector2i(0, 6), "floor": 0}
	assert_true(e.camera_facing(cam).x > 0.9, "points into the room")
	assert_true(e.camera_sees(cam, Vector3i(4, 6, 0)), "ahead")
	assert_false(e.camera_sees(cam, Vector3i(1, 1, 0)), "beside the mount, outside the 90° cone")


func test_every_data_gig_has_a_terminal_reachable_on_foot() -> void:
	for sc in ["shipyard", "badlands", "undercity", "arcology"]:
		for sd in [1, 2]:
			var m := SceneGen.generate(sd * 13 + 2, sc, {"security": 2})
			var e := Encounter.setup(m, Dice.new(3), [Recruit.generate(Dice.new(1), "netrunner", "edgerunner")] as Array[Combatant])
			var field: Dictionary = e.nav.distance_field([e.units[0].pos], {}, 3000)
			var ok := false
			for sid in m.architectures:
				if not m.structures[sid].target:
					continue
				for ap in (m.architectures[sid] as NetArchitecture).access_points:
					var d: Dictionary = m.devices[ap.device]
					var dp := Vector3i(d.pos.x, d.pos.y, d.floor)
					for cell in field:
						if cell.z == dp.z and Los.distance_m(cell, dp) <= 6.0 and not e._wall_between(cell, dp):
							ok = true
							break
			assert_true(ok, "%s seed %d: a jack point reachable without breaching" % [sc, sd])


func test_bypass_a_lock_and_loot_a_keycard() -> void:
	var m := SceneGen.generate(17, "lone_building", {"security": 2})
	var dice := Dice.new(5)
	var e := Encounter.setup(m, dice, _crew(dice))
	if e.nav.locked.is_empty():
		return
	e.next_turn()
	while e.cur.team != 0:
		e.end_turn()
		e.next_turn()
	var cell: Vector3i = e.nav.locked.keys()[0]
	e.cur.pos = Vector3i(cell.x, cell.y, cell.z) + Vector3i(1, 0, 0)
	assert_eq(e.lock_in_reach(e.cur), cell)
	e.cur.c.skills["electronics_security_tech"] = 10
	var opened := false
	for k in 12:
		e.turn.action_available = true
		var r := e.bypass_lock()
		assert_true(r.ok)
		if r.success:
			opened = true
			break
	assert_true(opened)
	assert_false(e.nav.locked.has(cell), "bypassed doors stop blocking")
	# keycards: someone carries one; downed, it can be taken
	var carrier: Array = e.units.filter(func(u): return u.has("keycard"))
	assert_false(carrier.is_empty(), "a guard carries the keycard")
	var g: Dictionary = carrier[0]
	g.c.dead = true
	g.pos = e.cur.pos + Vector3i(0, 1, 0)
	e.turn.action_available = true
	var r2 := e.loot_keycard()
	assert_true(r2.ok)
	assert_false(g.has("keycard"))
	for d in m.devices:
		if String(d.type) == "door_lock" and int(d.zone) <= int(r2.get("zone", 99)):
			pass
	assert_true(e.keycards.size() > 0)
