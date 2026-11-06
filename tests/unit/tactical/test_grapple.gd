extends TestCase
## Grappling (CPR core p.168-169, p.177, p.184): Grab, Choke, Throw, Human Shield, Escape,
## Release, Get Up; the grapple's penalties; every way it ends; the AI; nothing outlasts the gig.

const SURE := 40   ## a Brawling level no roll can beat (min total 6 + 40 - 9 > any 1d10 total under 30)


## An open 16x10 floor: the crew member A at (2,5), guards at `guard_cells` (alerted).
func _arena(guard_cells: Array, seed := 5) -> Encounter:
	var m := TacMap.new(16, 10, 1)
	for y in 10:
		for x in 16:
			m.set_t(0, x, y, TacMap.T.FLOOR)
	m.entrances.append({"floor": 0, "pos": Vector2i(2, 5), "kind": "deploy", "main": false, "cells": [Vector2i(2, 5)]})
	var dice := Dice.new(seed)
	var crew: Array[Combatant] = [Fixtures.shooter("A")]
	crew[0].weapons.append(Weapon.from_id("heavy_pistol"))
	var e := Encounter.setup(m, dice, crew)
	e.units = e.units.filter(func(u): return u.team == 0)
	for cell in guard_cells:
		var g := Fixtures.unarmored("G%d" % e.units.size(), {"REF": 4})
		g.skills["brawling"] = 4
		g.weapons.append(Weapon.from_id("heavy_pistol"))
		e._add(g, cell, 1)
		e.units[-1].alerted = true
	e.units[0].pos = Vector3i(2, 5, 0)
	_turn(e, e.units[0])
	return e


func _turn(e: Encounter, u: Dictionary) -> void:
	e.cur = u
	e.turn = TurnState.begin(e.dice, u.c)


## A sure grab by the active unit on `t`.
func _hold(e: Encounter, t: Dictionary) -> void:
	e.cur.c.skills["brawling"] = SURE
	var r := e.grapple(t)
	assert_true(r.get("ok", false) and r.get("success", false), "a sure grab lands: %s" % r.get("reason", ""))
	e.cur.c.skills["brawling"] = 4
	_turn(e, e.cur)


# --- Grab -----------------------------------------------------------------------------------

func test_grab_is_dex_plus_brawling_on_both_sides() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var g: Dictionary = e.units[1]
	var p := e.grab_preview(g)
	assert_true(p.ok, p.get("reason", ""))
	assert_eq(int(p.base), 6 + 4, "DEX 6 + Brawling 4 (p.177)")
	assert_eq(int(p.defense_base), 6 + 4, "the defender rolls DEX + Brawling too, not Evasion")
	assert_near(p.chance, Check.chance_opposed(10, 10), 1e-9, "ties to the defender")
	assert_true(p.chance < 0.5, "even odds favour the defender (ties)")


func test_grab_needs_reach_an_action_a_free_person() -> void:
	var e := _arena([Vector3i(3, 5, 0), Vector3i(6, 5, 0), Vector3i(1, 5, 0)])
	assert_eq(e.grab_why_not(e.units[2]), "out of reach", "two squares off")
	e.units[3].c.unconscious = true
	assert_eq(e.grab_why_not(e.units[3]), "they're down")
	e.turn.action_available = false
	assert_eq(e.grab_why_not(e.units[1]), "no action left", "Grab is an Action (p.168)")
	_turn(e, e.cur)
	_hold(e, e.units[1])
	e.units[3].c.unconscious = false
	assert_eq(e.grab_why_not(e.units[3]), "already holding or held", "one grapple at a time")
	assert_false(e.grapple(e.units[1]).get("ok", false), "no second grab on the one already held")


func test_a_failed_grab_spends_the_action_and_holds_nothing() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var g: Dictionary = e.units[1]
	e.cur.c.skills["brawling"] = 0
	g.c.skills["brawling"] = SURE
	var r := e.grapple(g)
	assert_true(r.ok)
	assert_false(r.success)
	assert_true(e.cur.c.grapple == null and g.c.grapple == null)
	assert_false(e.turn.action_available, "the Grab took the Action")


func test_grappled_both_take_minus_two_and_the_defender_cannot_move() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var a: Dictionary = e.units[0]
	var g: Dictionary = e.units[1]
	var pen_a: int = a.c.action_penalty()
	var pen_g: int = g.c.action_penalty()
	var pistol: Weapon = a.c.weapons[0]
	var base_before := Attack.attack_base(a.c, pistol, Attack.Mode.SINGLE)
	_hold(e, g)
	assert_true(a.c.is_grappling() and g.c.is_grappled() and a.c.grapple == g.c.grapple)
	assert_eq(a.c.action_penalty(), pen_a + 2, "-2 to all Actions, Attacker (p.177)")
	assert_eq(g.c.action_penalty(), pen_g + 2, "-2 to all Actions, Defender (p.177)")
	assert_eq(Attack.attack_base(a.c, pistol, Attack.Mode.SINGLE), base_before - 2, "attacks at -2")
	var mp := Attack.preview(Fixtures.shooter("X"), Weapon.from_id("light_melee"), g.c, Attack.Mode.SINGLE, 2.0)
	assert_eq(int(mp.defense_base), g.c.skill_base("evasion") - pen_g - 2, "and their Evasion at -2")
	_turn(e, g)
	assert_eq(e.turn.move_actions, 0, "the Defender can't use a Move Action (p.177)")
	assert_false(e.move_to(Vector3i(4, 5, 0)), "and can't walk away")
	assert_false(e.move_to(Vector3i(4, 5, 0), true), "or run")
	assert_true(e.turn.action_available, "they still have their Action")


func test_no_two_handed_weapons_for_either_party() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var a: Dictionary = e.units[0]
	var g: Dictionary = e.units[1]
	a.c.weapons.insert(0, Weapon.from_id("assault_rifle"))
	g.c.weapons.insert(0, Weapon.from_id("shotgun"))
	_hold(e, g)
	assert_eq(a.c.weapons[0].id(), "heavy_pistol", "the Grab slung the rifle and drew the pistol (free hand)")
	var rifle: Weapon = a.c.weapons.filter(func(w): return w.id() == "assault_rifle")[0]
	var p := e.preview(g, rifle, Attack.Mode.SINGLE)
	assert_false(p.ok)
	assert_eq(String(p.reason), "two-handed: in a grapple", "p.177")
	assert_true(e.preview(g, a.c.weapons[0], Attack.Mode.SINGLE).ok, "a one-handed pistol still works")
	_turn(e, g)
	assert_false(e.preview(a, g.c.weapons[0], Attack.Mode.SINGLE).ok, "the Defender can't use their shotgun either")
	assert_false(e.shotgun_shell(a, g.c.weapons[0]).get("ok", false), "not even a shell")
	assert_true(e.preview(a, Weapon.brawling(g.c), Attack.Mode.SINGLE).ok, "fists are fine")


func test_the_attackers_move_drags_the_defender() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var a: Dictionary = e.units[0]
	var g: Dictionary = e.units[1]
	_hold(e, g)
	assert_true(e.move_to(Vector3i(2, 1, 0)), "the Attacker moves")
	assert_eq(a.pos, Vector3i(2, 1, 0))
	assert_true(e.adjacent(a.pos, g.pos), "the Defender is dragged along beside them")
	assert_true(g.c.is_grappled(), "still held")
	var dragged := e.events.filter(func(ev): return ev.type == "move" and ev.get("dragged", false))
	assert_eq(dragged.size(), 1, "the view gets the drag")
	assert_eq(int(dragged[0].unit), int(g.id))


# --- Ending a grapple -----------------------------------------------------------------------

func test_release_is_free() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	_hold(e, e.units[1])
	var r := e.release()
	assert_true(r.ok)
	assert_true(e.turn.action_available, "letting go is free (p.177)")
	assert_true(e.cur.c.grapple == null and e.units[1].c.grapple == null)
	assert_eq(e.cur.c.action_penalty(), 0, "the -2 is gone")


func test_escape_takes_an_action_and_a_won_grab_roll() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var a: Dictionary = e.units[0]
	var g: Dictionary = e.units[1]
	_hold(e, g)
	_turn(e, g)
	var p := e.escape_preview()
	assert_true(p.ok)
	assert_near(p.chance, Check.chance_opposed(Grapple.base(g.c), Grapple.base(a.c)), 1e-9, "their Grab roll vs the Attacker's, ties to the Attacker")
	g.c.skills["brawling"] = 0
	a.c.skills["brawling"] = SURE
	var r := e.escape_grapple()
	assert_true(r.ok and not r.success, "a lost roll keeps them held")
	assert_false(e.turn.action_available, "the Action is spent either way")
	assert_true(g.c.is_grappled())
	_turn(e, g)
	g.c.skills["brawling"] = SURE
	a.c.skills["brawling"] = 0
	r = e.escape_grapple()
	assert_true(r.success)
	assert_true(g.c.grapple == null and a.c.grapple == null, "free")
	assert_true(e.turn.can_move(), "free mid-turn: the Move Action is theirs again")
	assert_true(e.move_to(Vector3i(5, 5, 0)), "and they walk off")


func test_anyone_else_can_break_the_hold() -> void:
	var e := _arena([Vector3i(3, 5, 0), Vector3i(3, 4, 0)])
	var a: Dictionary = e.units[0]
	var g: Dictionary = e.units[1]
	var g2: Dictionary = e.units[2]
	_hold(e, g)
	_turn(e, g2)
	assert_true(e.break_targets(g2).has(g), "a friend beside the holder can try")
	assert_true("break" in e.grapple_options())
	g2.c.skills["brawling"] = SURE
	var r := e.escape_grapple(g)
	assert_true(r.ok and r.success)
	assert_true(g.c.grapple == null and a.c.grapple == null)


func test_the_holder_going_down_ends_it() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var a: Dictionary = e.units[0]
	var g: Dictionary = e.units[1]
	_hold(e, g)
	a.c.unconscious = true
	e._check_end()
	assert_true(g.c.grapple == null, "an unconscious holder holds nothing")
	assert_true(e.events.any(func(ev): return ev.type == "grapple" and ev.kind == "broken"))


func test_the_held_one_dying_ends_it_unless_a_shield() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var g: Dictionary = e.units[1]
	_hold(e, g)
	g.c.hp = 0   # an NPC below 1 HP flatlines (NPC_FLATLINE)
	e._check_end()
	assert_true(g.c.dead)
	assert_true(e.cur.c.grapple == null, "let go of the body")


func test_damage_alone_doesnt_break_it() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var g: Dictionary = e.units[1]
	_hold(e, g)
	g.c.hp -= 5
	e.cur.c.hp -= 5
	e._check_end()
	assert_true(g.c.is_grappled(), "RULES-UNVERIFIED: only going down ends it")


# --- Choke ----------------------------------------------------------------------------------

func test_choke_deals_body_ignoring_armour_without_ablation() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var g: Dictionary = e.units[1]
	g.c.armor["body"] = ArmorPiece.from_id("light_armorjack")
	_hold(e, g)
	var hp0: int = g.c.hp
	var r := e.choke()
	assert_true(r.ok)
	assert_eq(r.damage, 6, "the Attacker's BODY (p.177)")
	assert_eq(g.c.hp, hp0 - 6, "straight to HP")
	assert_eq(g.c.sp("body"), 11, "armour neither stops it nor ablates")
	assert_false(e.turn.action_available, "an Action")
	assert_false(e.choke().get("ok", true), "one Choke per Action")


func test_choke_leaves_them_at_one_hp_unconscious_instead_of_below_zero() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var g: Dictionary = e.units[1]
	_hold(e, g)
	g.c.hp = 4   # 4 - 6 = -2
	var r := e.choke()
	assert_true(r.knocked_out)
	assert_eq(g.c.hp, 1)
	assert_true(g.c.unconscious and not g.c.dead)
	assert_true(e.events[-1].ko)


func test_choke_on_someone_at_one_hp_hurts_normally() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var g: Dictionary = e.units[1]
	_hold(e, g)
	g.c.hp = 1   # not "above 1 HP": the protection doesn't apply
	e.choke()
	assert_true(g.c.dead, "an NPC choked below 1 HP flatlines (NPC_FLATLINE)")


func test_three_successive_rounds_of_choking_knock_them_out() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var g: Dictionary = e.units[1]
	g.c.stats["BODY"] = 12
	g.c.hp = 200   # far too many HP to choke out
	_hold(e, g)
	for r in 3:
		e.init.round_num = 4 + r
		_turn(e, e.units[0])
		var res := e.choke()
		assert_eq(res.knocked_out, r == 2, "round %d" % r)
	assert_true(g.c.unconscious, "3 successive Rounds: Unconscious whatever the HP (p.177)")


func test_a_skipped_round_restarts_the_choke_count() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var g: Dictionary = e.units[1]
	g.c.hp = 200
	_hold(e, g)
	for rn in [1, 2, 4]:
		e.init.round_num = rn
		_turn(e, e.units[0])
		e.choke()
	assert_false(g.c.unconscious, "not successive")
	assert_eq(g.c.grapple.chokes, 1)


# --- Throw, Prone, Get Up -------------------------------------------------------------------

func test_throw_deals_body_ends_the_grapple_and_leaves_them_prone() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var a: Dictionary = e.units[0]
	var g: Dictionary = e.units[1]
	g.c.armor["body"] = ArmorPiece.from_id("light_armorjack")
	_hold(e, g)
	var hp0: int = g.c.hp
	var r := e.throw_foe()
	assert_true(r.ok)
	assert_eq(g.c.hp, hp0 - 6, "BODY to HP, armour ignored (p.177)")
	assert_eq(g.c.sp("body"), 11, "no ablation")
	assert_true(g.c.prone, "Prone")
	assert_true(a.c.grapple == null and g.c.grapple == null, "the grapple ends")
	assert_eq(a.c.action_penalty(), 0, "and its -2")
	assert_true(e.adjacent(a.pos, g.pos), "lands beside the thrower")
	assert_ne_pos(g.pos, Vector3i(3, 5, 0), "in another square (over the shoulder)")
	assert_true(not e.occupied(g).has(g.pos), "a free one")
	assert_false(e.turn.action_available)


func assert_ne_pos(a: Vector3i, b: Vector3i, msg: String) -> void:
	assert_true(a != b, msg)


func test_prone_means_no_move_until_get_up_which_costs_the_action() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var g: Dictionary = e.units[1]
	_hold(e, g)
	e.throw_foe()
	_turn(e, g)
	assert_eq(e.turn.move_actions, 0, "Prone: no Move Action (p.168-169)")
	assert_false(e.move_to(Vector3i(8, 5, 0)))
	assert_true("get_up" in e.grapple_options(), "the bar offers Get Up")
	var r := e.get_up()
	assert_true(r.ok)
	assert_false(g.c.prone)
	assert_false(e.turn.action_available, "Get Up is the Action (p.168)")
	assert_true(e.turn.can_move(), "and gives the Move Action back")
	assert_true(e.move_to(Vector3i(5, 4, 0)))
	assert_false(e.get_up().get("ok", true), "not prone any more")


# --- Human Shield ---------------------------------------------------------------------------

## The crew member holds G1 as a shield; G2 shoots from (8,5).
func _shield_setup() -> Encounter:
	var e := _arena([Vector3i(3, 5, 0), Vector3i(8, 5, 0)])
	_hold(e, e.units[1])
	var r := e.human_shield()
	assert_true(r.ok, r.get("reason", ""))
	assert_false(e.turn.action_available, "an Action to equip (p.169)")
	return e


func test_human_shield_takes_ranged_shots_and_cannot_dodge() -> void:
	var e := _shield_setup()
	var a: Dictionary = e.units[0]
	var g: Dictionary = e.units[1]
	g.c.stats["REF"] = 10   # would dodge bullets
	assert_true(g.c.is_human_shield())
	assert_false(g.c.can_dodge_ranged(), "a Human Shield can't dodge (p.184)")
	_turn(e, e.units[2])
	var w: Weapon = e.cur.c.weapons[0]
	var p := e.preview(a, w, Attack.Mode.SINGLE)
	assert_true(p.ok)
	assert_eq(int(p.shield), int(g.id), "the shield is in the way: counts as cover (p.184)")
	assert_eq(int(p.defense_base), -1, "a DV shot: no dodge")
	e.cur.c.skills["handgun"] = SURE
	var ahp: int = a.c.hp
	var ghp: int = g.c.hp
	e.attack(a, w, Attack.Mode.SINGLE)
	assert_eq(a.c.hp, ahp, "the holder is untouched")
	assert_true(g.c.hp < ghp or g.c.dead, "the shield takes it (damaged normally, p.184)")


func test_human_shield_doesnt_stop_melee_or_aimed_head_shots() -> void:
	var e := _shield_setup()
	var a: Dictionary = e.units[0]
	_turn(e, e.units[2])
	var w: Weapon = e.cur.c.weapons[0]
	assert_false(e.preview(a, w, Attack.Mode.AIMED_HEAD).has("shield"), "Aimed Shot at the head (p.184)")
	e.units[2].pos = Vector3i(1, 5, 0)
	assert_false(e.preview(a, Weapon.brawling(e.cur.c), Attack.Mode.SINGLE).has("shield"), "melee (p.184)")


func test_the_holder_can_attack_their_own_shield() -> void:
	var e := _shield_setup()
	_turn(e, e.units[0])
	var p := e.preview(e.units[1], e.units[0].c.weapons[0], Attack.Mode.SINGLE)
	assert_true(p.ok and not p.has("shield"), "p.184")


func test_a_dead_shield_is_a_corpse_shield_with_body_hp_and_dropping_it_takes_an_action() -> void:
	var e := _shield_setup()
	var a: Dictionary = e.units[0]
	var g: Dictionary = e.units[1]
	g.c.hp = 0
	e._check_end()
	assert_true(g.c.dead)
	assert_true(a.c.is_grappling(), "still held")
	assert_eq(a.c.grapple.corpse_hp, 6, "HP = their BODY in life (p.184)")
	assert_eq(a.c.action_penalty(), 0, "nobody to struggle with: no -2")
	_turn(e, e.units[2])
	var w: Weapon = e.cur.c.weapons[0]
	var p := e.preview(a, w, Attack.Mode.SINGLE)
	assert_eq(int(p.shield), int(g.id), "the corpse still covers")
	e.cur.c.skills["handgun"] = SURE
	var ahp: int = a.c.hp
	var r := e.attack(a, w, Attack.Mode.SINGLE)
	assert_true(r.hit)
	assert_eq(a.c.hp, ahp, "the corpse soaks it")
	assert_eq(a.c.grapple.corpse_hp, maxi(0, 6 - int(r.damage)))
	_turn(e, a)
	assert_eq(e.grapple_options(), ["release"] as Array[String], "only dropping it")
	e.turn.action_available = false
	assert_false(e.release().get("ok", true), "dropping a corpse shield costs an Action (p.184)")
	_turn(e, a)
	assert_true(e.release().ok)
	assert_true(a.c.grapple == null)


func test_a_spent_corpse_shield_no_longer_covers() -> void:
	var e := _shield_setup()
	var a: Dictionary = e.units[0]
	e.units[1].c.hp = 0
	e._check_end()
	a.c.grapple.hit_corpse(99)
	_turn(e, e.units[2])
	assert_false(e.preview(a, e.cur.c.weapons[0], Attack.Mode.SINGLE).has("shield"), "0 HP: not cover (p.183)")
	assert_true(a.c.is_grappling(), "but still in hand until dropped")


func test_releasing_a_live_shield_is_free() -> void:
	var e := _shield_setup()
	_turn(e, e.units[0])
	assert_true(e.release().ok)
	assert_true(e.turn.action_available, "ending the grapple is free (p.184)")


# --- Options for the bar --------------------------------------------------------------------

func test_grapple_options_follow_the_state() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	assert_eq(e.grapple_options(), ["grab"] as Array[String])
	_hold(e, e.units[1])
	assert_eq(e.grapple_options(), ["choke", "throw", "shield", "release"] as Array[String])
	_turn(e, e.units[1])
	assert_eq(e.grapple_options(), ["escape"] as Array[String])
	for id in ["grab", "choke", "throw", "shield", "release", "escape", "break", "get_up"]:
		assert_true(Hud.action_help(id) != "", "a hover card for %s" % id)


# --- AI -------------------------------------------------------------------------------------

func test_a_brawler_grabs_an_isolated_runner_then_chokes() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var a: Dictionary = e.units[0]
	var g: Dictionary = e.units[1]
	g.c.skills["brawling"] = SURE
	_turn(e, g)
	AI.act(e, g)
	assert_true(g.c.is_grappling() and a.c.is_grappled(), "grabbed the lone crew member")
	var hp0: int = a.c.hp
	_turn(e, g)
	AI.act(e, g)
	assert_true(a.c.hp < hp0, "then chokes them")


func test_the_ai_wont_grab_someone_with_friends_beside_them() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var b := Fixtures.shooter("B")
	e._add(b, Vector3i(2, 6, 0), 0)
	var g: Dictionary = e.units[1]
	g.c.skills["brawling"] = SURE
	_turn(e, g)
	AI.act(e, g)
	assert_true(g.c.grapple == null, "not isolated")


func test_a_held_guard_tries_to_escape() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var g: Dictionary = e.units[1]
	_hold(e, g)
	g.c.skills["brawling"] = SURE
	_turn(e, g)
	AI.act(e, g)
	assert_true(g.c.grapple == null, "broke free")


func test_a_prone_guard_gets_up() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var g: Dictionary = e.units[1]
	_hold(e, g)
	e.throw_foe()
	_turn(e, g)
	AI.act(e, g)
	assert_false(g.c.prone, "Get Up")
	assert_false(e.turn.action_available)


# --- Nothing outlasts the gig ---------------------------------------------------------------

func test_grapple_and_prone_never_persist() -> void:
	var e := _arena([Vector3i(3, 5, 0)])
	var a: Dictionary = e.units[0]
	var g: Dictionary = e.units[1]
	_hold(e, g)
	a.c.prone = true
	var d: Dictionary = a.c.to_dict()
	assert_false(d.has("grapple") or d.has("prone"), "not saved")
	var back := Combatant.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_true(back.grapple == null and not back.prone)
	a.c.gig_reset()   # the next gig
	assert_true(a.c.grapple == null and not a.c.prone)
	assert_true(g.c.grapple == null, "the other end is let go too")


func test_left_click_grabs_with_the_tool_armed_right_click_still_moves() -> void:
	var L := MOUSE_BUTTON_LEFT
	var R := MOUSE_BUTTON_RIGHT
	assert_eq(ClickIntent.of(L, false, false, "grab", false, true), ClickIntent.TOOL, "left on a foe with GRAB armed grabs")
	assert_eq(ClickIntent.of(L, false, false, "break", false, false), ClickIntent.TOOL, "left on a held friend breaks the hold")
	assert_eq(ClickIntent.of(R, false, false, "grab", false, true), ClickIntent.MOVE, "right still moves")
