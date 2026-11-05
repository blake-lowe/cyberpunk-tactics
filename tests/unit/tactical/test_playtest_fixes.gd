extends TestCase
## Owner playtest of the tactical map: the move path over the Run range and none once a move is
## spent, the NET panel's hover cards, the NET view only on the runner's own turn, the attack
## economy (two Brawling attacks are ROF 2, not a bug), and the end of a gig.

const GREYBOX := preload("res://src/tactical/greybox.gd")


## A 30x3 corridor: the shooter at (1,1), a guard posted far down at (28,1).
func _corridor() -> Encounter:
	var m := TacMap.new(30, 3, 1)
	for y in 3:
		for x in 30:
			m.set_t(0, x, y, TacMap.T.FLOOR)
	m.entrances.append({"floor": 0, "pos": Vector2i(1, 1), "kind": "deploy", "main": false, "cells": [Vector2i(1, 1)]})
	m.posts.append({"floor": 0, "pos": Vector2i(28, 1), "structure": -1, "zone": 1, "kind": "door"})
	var dice := Dice.new(4)
	var crew: Array[Combatant] = [Fixtures.shooter("A")]
	crew[0].weapons.append(Weapon.from_id("heavy_pistol"))
	var e := Encounter.setup(m, dice, crew)
	e.cur = e.units[0]
	e.cur.pos = Vector3i(1, 1, 0)
	e.turn = TurnState.begin(dice, crew[0])
	return e


func test_the_run_range_has_a_path_preview() -> void:
	var e := _corridor()
	var mv: int = e.cur.c.stat("MOVE")
	var walk := Vector3i(1 + mv, 1, 0)
	var run := Vector3i(1 + mv + 3, 1, 0)
	assert_true(e.move_options().has(walk) and not e.move_options().has(run), "the run square is past the normal move")
	assert_true(e.run_options().has(run), "but in the amber Run range")
	var p := e.move_preview(run)
	assert_false(p.is_empty(), "the Run range draws a path too")
	assert_eq(p[0], e.cur.pos, "from the unit")
	assert_eq(p[-1], run, "to the hovered square")
	assert_eq(e.move_preview(walk)[-1], walk, "the normal range still does")
	assert_true(e.move_preview(Vector3i(1 + 2 * mv + 2, 1, 0)).is_empty(), "nothing past the Run range")
	assert_true(e.move_preview(run, false).is_empty(), "nor into it when a Run isn't allowed")


func test_no_path_preview_once_the_move_is_spent() -> void:
	var e := _corridor()
	var mv: int = e.cur.c.stat("MOVE")
	assert_true(e.move_to(Vector3i(1 + 2 * mv, 1, 0), true), "a full Run")
	assert_true(not e.turn.can_move() and e.run_options().is_empty(), "no move left")
	assert_true(e.move_preview(Vector3i(2 * mv, 1, 0)).is_empty(), "so no path to wherever the cursor rests")
	var e2 := _corridor()
	e2.state = "won"
	assert_true(e2.move_preview(Vector3i(3, 1, 0)).is_empty(), "nor once the gig is over")


func test_net_panel_rows_have_cited_hover_cards() -> void:
	var ids: Array[String] = []
	ids.append_array(Encounter.NET_ACTIONS)
	ids.append_array(["jack_out_unsafe", "fire_turret", "net_actions"])
	ids.append_array(Recruit.generate(Dice.new(2), "netrunner", "edgerunner", "Patch").programs)
	for kind in RulesDB.load_json("black_ice.json")["ice"]:
		ids.append("ice:" + String(kind))
	for id in ids:
		var card := Hud.net_help(id)
		assert_true(card.begins_with("[b]"), "%s has a card" % id)
		assert_true(card.contains("CPR core p.") or card.contains("game rule"), "%s cites its page: %s" % [id, card])
	assert_true(Hud.net_help("backdoor").contains("1 NET Action"), "the cost")
	assert_true(Hud.net_help("zap").contains("1d6"), "the key numbers")
	assert_true(Hud.net_help("sword").contains("3d6") and Hud.net_help("sword").contains("ATK 1"), "a Program's stats")
	assert_true(Hud.net_help("ice:hellhound").contains("ATK 6"), "Black ICE stats")
	assert_true(Hud.net_help("zap", "64% now").contains("64% now"), "this moment's odds")
	assert_eq(Hud.net_help("no_such_thing"), "")


func _jacked() -> Array:
	var m := SceneGen.generate(11, "lone_building", {"site": "corp_office", "security": 1})
	var dice := Dice.new(9)
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	var e := Encounter.setup(m, dice, crew)
	var runner: Dictionary = e.units[1]
	var ap_dev: Dictionary = m.devices[m.architecture.access_points[0].device]
	runner.pos = Vector3i(ap_dev.pos.x, ap_dev.pos.y, ap_dev.floor)
	e.cur = runner
	e.turn = TurnState.begin(dice, runner.c)
	assert_true(e.jack_in(e.jack_points(runner)[0]))
	return [e, runner]


func test_the_net_view_is_the_jacked_in_runners_turn_only() -> void:
	var r := _jacked()
	var e: Encounter = r[0]
	assert_true(GREYBOX.net_view_run(e, true) == e.runs[r[1].id], "the runner's turn shows the NET")
	assert_true(GREYBOX.net_view_run(e, false) == null, "N shows the plain world")
	var t0 := e.turn
	e.cur = e.units.filter(func(u): return e.is_guard(u))[0]
	assert_true(GREYBOX.net_view_run(e, true) == null, "a guard's turn: the plain world, though the runner is still jacked in")
	e.cur = e.units[0]
	assert_true(GREYBOX.net_view_run(e, true) == null, "another crew member's turn too")
	e.cur = r[1]
	e.end_turn()
	e.next_turn()
	assert_true(e.turn != t0, "every turn is a new TurnState: the view's cue that the runner's turn ended")
	e.cur = r[1]
	e.state = "won"
	assert_true(GREYBOX.net_view_run(e, true) == null, "nor once the gig is over")


func test_two_brawling_attacks_are_rof_2_and_a_third_is_refused() -> void:
	var e := _corridor()
	var g: Dictionary = e.units.filter(func(u): return e.is_guard(u))[0]
	g.pos = Vector3i(2, 1, 0)
	var fists := Weapon.brawling(e.cur.c)
	assert_eq(Hud.attacks_per_action(fists, "brawl"), 2, "Brawling is ROF 2 (CPR core p.176): two attacks this turn")
	assert_eq(Hud.action_text(e.turn), "◆ ACTION")
	assert_true(e.melee(g, fists).ok, "first swing")
	assert_eq(Hud.action_text(e.turn), "◆ 1 MORE ATTACK (ROF 2)", "the card says a second is left")
	if not g.c.dead:
		assert_true(e.melee(g, fists).ok, "second swing, same Action (p169)")
	else:
		e.turn.attacks_left = 0
	assert_false(e.melee(g, fists).ok, "no third")
	assert_eq(Hud.action_text(e.turn), "◇ ACTION")


func test_a_2_rof_actions_second_check_must_be_a_single_2_rof_attack() -> void:
	var e := _corridor()
	var g: Dictionary = e.units.filter(func(u): return e.is_guard(u))[0]
	g.pos = Vector3i(6, 1, 0)
	g.c.hp = 999   # stays up for both checks
	var pistol: Weapon = e.cur.c.weapons[0]
	var rifle := Weapon.from_id("assault_rifle")
	e.cur.c.weapons.append(rifle)
	assert_true(e.attack(g, pistol, Attack.Mode.SINGLE).ok, "a heavy pistol shot (ROF 2)")
	assert_false(e.attack(g, rifle, Attack.Mode.SINGLE).ok, "not a ROF 1 rifle shot after it (p169)")
	assert_false(e.attack(g, rifle, Attack.Mode.AUTOFIRE).ok, "nor Autofire")
	assert_false(e.attack(g, pistol, Attack.Mode.AIMED_HEAD).ok, "nor an Aimed Shot, which takes the whole Action (p170)")
	assert_true(e.attack(g, pistol, Attack.Mode.SINGLE).ok, "the second pistol shot is fine")
	assert_eq(Hud.attacks_per_action(rifle, "auto"), 1)
	assert_eq(Hud.attacks_per_action(pistol, "single"), 2)


func test_a_finished_gig_always_offers_a_way_on() -> void:
	var camp: Array = GREYBOX.end_choices(true)
	assert_eq(String(camp[0][0]), "safehouse", "a board gig goes home to the debrief")
	assert_true(String(camp[0][1]).contains("SAFEHOUSE") and String(camp[0][1]).contains("ENTER"), "a button with its key")
	var dev: Array = GREYBOX.end_choices(false)
	assert_eq(dev.map(func(c): return String(c[0])), ["restart", "quit"], "a dev map without a campaign: restart or quit")
	# the data gig standalone (no campaign) ends on the File, the case that used to lock up
	var r := _jacked()
	var e: Encounter = r[0]
	e.objective.done = true
	e._check_end()
	assert_eq(e.state, "won")
