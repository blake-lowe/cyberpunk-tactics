extends TestCase
## External playtest round 4: the freed hostage is the player's to move (and the follower AI's
## corner bug), the camera after a death and at the start, and Put Out Fire (CPR core p.180).
## The deploy distance has its own file (tests/unit/gen/test_deploy.gd).


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func _rescue(seed_value := 11) -> Encounter:
	var m := SceneGen.generate(seed_value, "lone_building", {"security": 1, "site": "gang_hideout"})
	var dice := Dice.new(7)
	return Encounter.setup(m, dice, _crew(dice), "rescue")


## Stand crew member 0 beside the captive and cut them loose.
func _free(e: Encounter) -> Dictionary:
	var cap: Dictionary = e.units[int(e.objective.captive)]
	var solo: Dictionary = e.units[0]
	e.cur = solo
	e.turn = TurnState.begin(e.dice, solo.c)
	for d in MapGen.DIRS:
		var v: Vector3i = cap.pos + Vector3i(d.x, d.y, 0)
		if e.m.walkable(v.z, Vector2i(v.x, v.y)) and not e.occupied(solo).has(v):
			solo.pos = v
			break
	assert_true(e.free_captive().ok, "freed")
	return cap


# --- The hostage ------------------------------------------------------------------------------

func test_the_freed_hostage_takes_their_own_turns_under_the_player() -> void:
	var e := _rescue()
	var cap := _free(e)
	assert_true(e.is_hostage(cap), "a hostage")
	assert_eq(int(cap.team), Encounter.CREW, "on the crew's side")
	var start: Vector3i = cap.pos
	var reached := false
	for i in 30:
		e.end_turn()
		if e.state != "playing":
			break
		e.next_turn()
		if e.cur == cap:
			reached = true
			break
	assert_true(reached, "next_turn hands the hostage's turn to the player")
	if reached:
		assert_eq(cap.pos, start, "nobody moved them for the player")
		assert_true(e.turn.can_move() and cap.c.weapons.is_empty(), "their own Move, and still unarmed")


func test_the_hostage_reaching_extraction_wins_and_a_dead_one_loses() -> void:
	var e := _rescue()
	var cap := _free(e)
	cap.pos = e.extract_cells.keys()[0]
	e._check_end()
	walk_out(e)
	assert_eq(e.state, "won", "out = done")
	var e2 := _rescue()
	var cap2 := _free(e2)
	cap2.c.dead = true
	e2._check_end()
	assert_eq(e2.state, "lost", "the hostage flatlined")


func test_a_hostage_alone_is_not_a_crew() -> void:
	var e := _rescue()
	_free(e)
	for u in e.units:
		if u.team == Encounter.CREW and not e.is_hostage(u):
			u.c.dead = true
	e._check_end()
	assert_eq(e.state, "lost", "the crew is gone: the hostage alone doesn't keep the gig going")


func test_the_crew_can_withdraw_without_the_hostage() -> void:
	var e := _rescue()
	var cap := _free(e)
	var cells: Array = e.extract_cells.keys()
	var i := 0
	for u in e.units:
		if u.team == Encounter.CREW and not e.is_hostage(u):
			u.pos = cells[i]
			i += 1
	e.cur = e.units[0]
	assert_false(e.extract_cells.has(cap.pos))
	assert_true(e.can_withdraw(), "abandoning the hostage is the crew's call")
	assert_true(e.withdraw())
	assert_eq(e.state, "fled", "the rescue failed")
	assert_false(cap.c.dead, "nobody shoots the hostage for leaving them")


func test_the_hud_tags_the_hostage() -> void:
	var e := _rescue()
	var cap := _free(e)
	assert_eq(Hud.crew_tag(cap), "HOSTAGE")
	assert_eq(Hud.crew_tag(e.units[0]), String(e.units[0].c.role).to_upper(), "crew show their role")


func test_the_hostage_is_not_paid_counted_or_recruited() -> void:
	var c := Campaign.new_game(31)
	var gig: Dictionary = c.accept(0)
	var m := SceneGen.generate(int(gig.seed), String(gig.scene), Campaign.scene_opts(gig))
	var e := Encounter.setup(m, c.dice, c.alive_crew(), "rescue")
	var names := c.crew.map(func(x): return x.display_name)
	var cap := _free(e)
	cap.c.dead = true   # flatlined on the way out
	e._check_end()
	var r := c.resolve(e)
	assert_eq(c.crew.map(func(x): return x.display_name), names, "the roster is the crew who went")
	assert_true(r.dead.is_empty() and c.fallen.is_empty(), "the hostage isn't one of the crew's dead")
	assert_eq(c.crew[0].ip, int(Campaign.IP_GROUP.failed), "a failed job, not a crew death")
	var c2 := Campaign.new_game(32)
	var g2: Dictionary = c2.accept(0)
	var m2 := SceneGen.generate(int(g2.seed), String(g2.scene), Campaign.scene_opts(g2))
	var e2 := Encounter.setup(m2, c2.dice, c2.alive_crew(), "rescue")
	var n2 := c2.crew.size()
	var cap2 := _free(e2)
	cap2.pos = e2.extract_cells.keys()[0]
	e2._check_end()
	walk_out(e2)
	assert_eq(e2.state, "won")
	var r2 := c2.resolve(e2)
	assert_eq(c2.crew.size(), n2, "a rescued hostage goes home, not onto the roster")
	assert_eq(int(r2.pay), int(g2.pay), "the gig's pay, nothing per head")


## The follower used a straight line to the lead: with a wall between them it walked into the
## corner nearest the lead and stayed there. Walking distance takes it round by the gap.
func test_the_follower_walks_round_a_wall_not_into_the_corner() -> void:
	var m := TacMap.new(14, 8, 1)
	for y in 8:
		for x in 14:
			m.set_t(0, x, y, TacMap.T.FLOOR)
	for y in 7:   # a wall down x = 6, open at the bottom row
		m.set_t(0, 6, y, TacMap.T.WALL)
	m.entrances.append({"floor": 0, "pos": Vector2i(12, 1), "kind": "deploy", "main": false, "cells": [Vector2i(12, 1)]})
	var dice := Dice.new(5)
	var crew: Array[Combatant] = [Fixtures.shooter("Lead")]
	var e := Encounter.setup(m, dice, crew, "data")
	var lead: Dictionary = e.units[0]
	lead.pos = Vector3i(8, 1, 0)
	var h := Recruit.civilian(dice, Recruit.civilian_blocks()[0], "Hostage")
	h.weapons.clear()
	e._add(h, Vector3i(4, 1, 0), Encounter.CREW)
	var hu: Dictionary = e.units[-1]
	hu["captive"] = true
	e.cur = hu
	e.turn = TurnState.begin(dice, h)
	var field: Dictionary = e.nav.distance_field([lead.pos], {}, 4000)
	var before := int(field[hu.pos])
	AI.follow(e, hu)
	var after := int(field.get(hu.pos, 999))
	assert_true(after <= before - 2, "closer on foot (%d -> %d squares)" % [before, after])
	assert_true(hu.pos != Vector3i(5, 1, 0), "not the corner by the wall")


# --- Camera -----------------------------------------------------------------------------------

func test_a_new_turn_of_the_last_unit_standing_recentres() -> void:
	var t1 := TurnState.new()
	var t2 := TurnState.new()
	assert_true(CamFrame.new_crew_turn(3, true, 3, t2, t1), "the same unit's next turn (the other one died)")
	assert_true(CamFrame.new_crew_turn(4, true, 3, t1, t1), "another unit")
	assert_false(CamFrame.new_crew_turn(3, true, 3, t1, t1), "the same turn, after an action")
	assert_false(CamFrame.new_crew_turn(3, false, 3, t2, t1), "not the crew's turn")
	var goal := CamFrame.unit_focus(Vector2(10, 10), 0.0, 20.0)
	assert_false(CamFrame.needs_recentre(goal, goal + Vector2(0.1, 0.0)), "already centred: no jump")
	assert_true(CamFrame.needs_recentre(goal + Vector2(1.5, 0.5), goal), "off centre: pan")


func test_the_opening_shot_shows_the_door() -> void:
	for yaw in [0.0, 45.0, 200.0]:
		for door in [Vector2(18, 10), Vector2(40, 60), Vector2(100, 4)]:
			var unit := Vector2(10, 10)
			var op := CamFrame.opening(unit, door, yaw, 20.0, 16.0 / 9.0)
			var focus: Vector2 = op.focus
			var d := float(op.dist)
			assert_true(d >= 20.0, "never zooms in")
			if d < CamFrame.MAX_DIST:
				assert_true(CamFrame.fits(unit + Vector2(0.5, 0.5), focus, float(op.yaw), d, 16.0 / 9.0), "the crew in frame (yaw %d, door %s)" % [yaw, door])
				assert_true(CamFrame.fits(door + Vector2(0.5, 0.5), focus, float(op.yaw), d, 16.0 / 9.0), "the door in frame (yaw %d, door %s)" % [yaw, door])
	var near := CamFrame.opening(Vector2(10, 10), Vector2(14, 10), 0.0, 20.0, 16.0 / 9.0)
	assert_eq(float(near.dist), 20.0, "a door across the street needs no zoom")
	assert_eq(float(near.yaw), 0.0, "nor a turn")


func test_every_scene_opening_fits_the_door() -> void:
	for scene in ["lone_building", "street_block", "badlands", "warzone", "corp_campus", "shipyard"]:
		var m := SceneGen.generate(4, scene, {"security": 1})
		var dep: Dictionary = m.entrances.filter(func(x): return x.kind == "deploy")[0]
		var door := m.main_entrance()
		var op := CamFrame.opening(Vector2(dep.pos), Vector2(door.pos), 0.0, 20.0, 16.0 / 9.0)
		assert_true(CamFrame.fits(Vector2(door.pos) + Vector2(0.5, 0.5), op.focus, float(op.yaw), op.dist, 16.0 / 9.0), "%s: the door is on screen" % scene)


# --- Put Out Fire (CPR core p.180) ------------------------------------------------------------

func _burning_arena(guard_at := Vector3i(28, 1, 0)) -> Encounter:
	var m := TacMap.new(30, 3, 1)
	for y in 3:
		for x in 30:
			m.set_t(0, x, y, TacMap.T.FLOOR)
	m.entrances.append({"floor": 0, "pos": Vector2i(1, 1), "kind": "deploy", "main": false, "cells": [Vector2i(1, 1)]})
	m.posts.append({"floor": 0, "pos": Vector2i(guard_at.x, guard_at.y), "structure": -1, "zone": 1, "kind": "door"})
	var dice := Dice.new(4)
	var crew: Array[Combatant] = [Fixtures.shooter("A")]
	crew[0].weapons.append(Weapon.from_id("heavy_pistol"))
	var e := Encounter.setup(m, dice, crew)
	e.cur = e.units[0]
	e.cur.pos = Vector3i(1, 1, 0)
	e.turn = TurnState.begin(dice, crew[0])
	return e


func test_put_out_fire_is_offered_only_while_burning_and_costs_the_action() -> void:
	var e := _burning_arena()
	var c: Combatant = e.cur.c
	assert_false("put_out" in e.grapple_options(), "not on fire: no entry")
	c.burning = 4
	assert_true("put_out" in e.grapple_options(), "on fire: the bar offers it")
	assert_eq(Hud.action_help("put_out"), "", "no hover card (owner verdict 2026-11-10: self-explanatory)")
	assert_eq(String(RulesDB.load_json("action_help.json").actions.put_out.page), "p.180", "its cite lives in the data's page field")
	assert_false(TextCites.has_cite(Hud.action_help("put_out")), "never on the card")
	var row: Array = Hud.GRAPPLE_ACTIONS.filter(func(r): return r[0] == "put_out")[0]
	assert_eq(String(row[2]), "C", "a key of its own (C, freed when the cutaway modes retired)")
	for r in Hud.MAIN_ACTIONS:
		assert_true(String(r[2]) != "C", "no clash with the main bar")
	var hp := c.hp
	assert_true(e.grapple_act("put_out").ok)
	assert_eq(c.burning, 0, "out")
	assert_false(e.turn.action_available, "it took the Action")
	assert_false(e.put_out_fire().ok, "once is enough")
	e.end_turn()
	assert_eq(c.hp, hp, "no burn at the end of the turn")


func test_spending_the_action_elsewhere_leaves_you_burning() -> void:
	var e := _burning_arena()
	var c: Combatant = e.cur.c
	c.burning = 2
	var hp := c.hp
	assert_true(e.turn.use_action(), "spent on something else")
	e.end_turn()
	assert_eq(c.burning, 2, "still on fire")
	assert_eq(c.hp, hp - 2, "and it burns (p.180)")


func test_the_ai_puts_itself_out_when_it_has_nothing_better() -> void:
	var e := _burning_arena()
	var g: Dictionary = e.units.filter(func(u): return e.is_guard(u))[0]
	g.alerted = true
	e.cur = g
	e.turn = TurnState.begin(e.dice, g.c)
	g.c.burning = 4
	AI.act(e, g)
	assert_eq(g.c.burning, 0, "a long shot across the hall: beat the flames out first")
	# point blank, healthy: shoot instead
	var e2 := _burning_arena(Vector3i(3, 1, 0))
	var g2: Dictionary = e2.units.filter(func(u): return e2.is_guard(u))[0]
	g2.alerted = true
	e2.cur = g2
	e2.turn = TurnState.begin(e2.dice, g2.c)
	g2.c.burning = 2
	g2.c.hp = g2.c.max_hp()
	var shot := false
	for t in e2.units:
		if e2.hostile(int(g2.team), int(t.team)):
			var p := e2.preview(t, g2.c.weapons[0], Attack.Mode.SINGLE)
			shot = shot or (p.ok and float(p.chance) >= AI.PUT_OUT_SHOT)
	if shot:
		assert_false(AI.put_out(e2, g2), "a good shot beats a little fire")
		assert_eq(g2.c.burning, 2)
	# nearly down: put it out whatever
	g2.c.hp = 5
	assert_true(AI.put_out(e2, g2), "burning would take them down")
