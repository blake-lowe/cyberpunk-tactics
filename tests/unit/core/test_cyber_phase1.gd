extends TestCase
## Cyberware phase 1, combat chrome (CPR core p.359-367): the Sandevistan and the Initiative re-sort,
## popup weapons and the Popup Shield, the Skill Chip, the scanners, TeleOptics, the Linear Frames,
## Hardened Shielding; the chrome menu's options; guards using their chrome.


## An open 30x10 floor, the crew member at (2,5), alerted guards at `guard_cells`.
func _arena(guard_cells: Array, seed := 3) -> Encounter:
	var m := TacMap.new(30, 10, 1)
	for y in 10:
		for x in 30:
			m.set_t(0, x, y, TacMap.T.FLOOR)
	m.entrances.append({"floor": 0, "pos": Vector2i(2, 5), "kind": "deploy", "main": false, "cells": [Vector2i(2, 5)]})
	var dice := Dice.new(seed)
	var crew: Array[Combatant] = [Fixtures.shooter("A")]
	crew[0].weapons.append(Weapon.from_id("heavy_pistol"))
	var e := Encounter.setup(m, dice, crew)
	e.units = e.units.filter(func(u): return u.team == 0)
	for cell in guard_cells:
		var g := Fixtures.shooter("G%d" % e.units.size(), {"REF": 4})
		g.weapons.append(Weapon.from_id("heavy_pistol"))
		e._add(g, cell, 1)
		e.units[-1].alerted = true
	e.units[0].pos = Vector3i(2, 5, 0)
	e.cur = e.units[0]
	e.turn = TurnState.begin(dice, e.cur.c)
	return e


func _chromed(specs: Array, c: Combatant = null) -> Combatant:
	if c == null:
		c = Fixtures.shooter("C")
	for s in specs:
		c.install_cyberware(String(s))
	return c


# --- Sandevistan (p.359) ---------------------------------------------------------------------------

func test_the_sandevistan_is_an_action_for_plus_three_initiative_once_a_gig() -> void:
	var e := _arena([Vector3i(20, 5, 0)])
	var c: Combatant = e.cur.c
	_chromed(["neural_link", "sandevistan"], c)
	var before := c.initiative_bonus()
	var opt: Dictionary = e.chrome_options()[0]
	assert_eq(String(opt.id), "sandevistan")
	assert_eq(String(opt.cost), "ACTION")
	assert_true(opt.ok)
	assert_true(e.use_chrome("sandevistan").ok)
	assert_false(e.turn.action_available, "activating it is an Action (p.359)")
	assert_eq(c.initiative_bonus(), before + 3, "+3 to Initiative")
	assert_eq(int(c.chrome_on.sandevistan), Encounter.SANDEVISTAN_ROUNDS, "a minute: 20 rounds")
	assert_eq(e.events[-1].type, "chrome")
	e.turn = TurnState.begin(e.dice, c)
	assert_false(e.use_chrome("sandevistan").ok, "running: can't again")
	for i in Encounter.SANDEVISTAN_ROUNDS:
		e.end_turn()
	assert_false(c.chrome_on.has("sandevistan"), "the minute is up")
	assert_eq(c.initiative_bonus(), before)
	e.turn = TurnState.begin(e.dice, c)
	var again: Dictionary = e.chrome_options()[0]
	assert_false(again.ok, "the hour's cooldown outlasts the gig")
	assert_eq(String(again.why), "Used this gig")
	c.gig_reset()
	assert_true(e.chrome_options()[0].ok, "ready for the next gig")


func test_a_knocked_out_sandevistan_wont_start() -> void:
	var e := _arena([])
	var c: Combatant = e.cur.c
	_chromed(["neural_link", "sandevistan"], c)
	c.cyber_off[Cyber.key(c.implant("sandevistan"))] = 5
	assert_false(e.use_chrome("sandevistan").ok)
	assert_eq(String(e.chrome_options()[0].why), "Chrome offline")


func test_the_initiative_re_sort_waits_for_the_next_round() -> void:
	var init := Initiative.new(Dice.new(1))
	var a := Fixtures.shooter("A", {"REF": 2})
	var b := Fixtures.shooter("B", {"REF": 8})
	var c := Fixtures.shooter("C", {"REF": 5})
	for x in [a, b, c]:
		init.add(x)
	for ent in init.entries:   # fixed rolls: B 20, C 15, A 13
		ent.roll = {a: 13, b: 20, c: 15}[ent.c]
	init.entries.sort_custom(Initiative._before)
	assert_eq(init.next_turn(), b)
	assert_eq(init.next_turn(), c)
	assert_eq(init.next_turn(), a)
	init.adjust(a, 3)   # A kicks in a Sandevistan on their turn: 16
	assert_eq(init.order(), [b, c, a] as Array[Combatant], "this Round keeps its order: nobody acts twice or loses a turn")
	assert_eq(init.next_turn(), b, "the next Round starts in the new order")
	assert_eq(init.order(), [b, a, c] as Array[Combatant], "A (16) now goes before C (15)")
	assert_eq(init.next_turn(), a)
	assert_eq(init.next_turn(), c)
	init.adjust(a, -3)   # the minute is up
	init.next_turn()
	assert_eq(init.order(), [b, c, a] as Array[Combatant], "back where it was")


func test_a_sandevistan_ties_keep_their_tiebreak() -> void:
	var init := Initiative.new(Dice.new(2))
	var a := Fixtures.shooter("A")
	var b := Fixtures.shooter("B")
	init.add(a)
	init.add(b)
	for ent in init.entries:
		ent.roll = 10
		ent.tb = 1 if ent.c == a else 2
	init.entries.sort_custom(Initiative._before)
	init.next_turn()
	init.next_turn()
	init.adjust(a, 3)
	init.adjust(a, -3)
	init.next_turn()
	assert_eq(init.order(), [b, a] as Array[Combatant], "the same tie-break key: deterministic")


# --- Popup weapons (p.360, p.365) ------------------------------------------------------------------

func test_popup_weapons_are_one_handed_concealed_and_free_to_draw() -> void:
	var c := Fixtures.shooter("C")
	c.weapons.append(Weapon.from_id("heavy_pistol"))
	_chromed(["cyberarm", "popup_ranged_weapon@heavy_smg"], c)
	var w: Weapon = c.weapons.filter(func(x): return x.popup != "")[0]
	assert_eq(w.id(), "heavy_smg", "the gun the buyer provided (p.365)")
	assert_eq(int(w.def.hands), 1)
	assert_true(w.builtin, "part of the arm: never sold or swapped")
	assert_false(w.revealed, "concealed without a Check")
	assert_eq(w.display_name(), "Popup Heavy SMG")
	assert_eq(c.weapons[0].id(), "heavy_pistol", "the primary stays in hand")
	assert_false(c.concealed(c.implant("cyberarm")))
	assert_true(c.concealed(c.implant("popup_ranged_weapon")), "nobody knows it's there")
	var m := _chromed(["cyberarm", "popup_melee_weapon@heavy_melee"], Fixtures.unarmored("M"))
	var mw: Weapon = m.weapons.filter(func(x): return x.popup != "")[0]
	assert_true(mw.is_melee() and mw.dice() == 3 and int(mw.def.hands) == 1, "a one-handed heavy melee weapon")
	assert_eq(Cyber.choices("popup_melee_weapon"), ["light_melee", "medium_melee", "heavy_melee"] as Array[String], "light, medium or heavy (p.365)")
	assert_false("assault_rifle" in Cyber.choices("popup_ranged_weapon"), "one-handed only")
	assert_true("heavy_pistol" in Cyber.choices("popup_ranged_weapon"))
	assert_true(c.remove_cyberware("popup_ranged_weapon"))
	assert_false(c.weapons.any(func(x): return x.popup != ""), "the gun goes with the piece")


func test_single_shot_popups_reload_as_their_weapons_do() -> void:
	var c := _chromed(["cyberarm", "popup_grenade_launcher", "cybereye", "dartgun"])
	var gl: Weapon = c.weapons.filter(func(x): return x.id() == "grenade_launcher")[0]
	assert_eq(gl.mag(), 1, "a single grenade in its magazine (p.365)")
	assert_eq(int(gl.def.hands), 1, "one-handed")
	var dg: Weapon = c.weapons.filter(func(x): return x.id() == "dartgun")[0]
	assert_eq(dg.mag(), 1, "a single shot in the clip (p.360)")
	assert_eq(int(dg.fx().get("ablate_sp", 1)), 2, "a Non-Basic dart: the Armor-Piercing one the game plays (p.345, p.348)")
	var e := _arena([Vector3i(8, 5, 0)])
	e.cur.c.weapons.append(gl)
	gl.ammo = 0
	assert_true(e.reload(gl), "reloaded with an Action, like any launcher")
	assert_eq(gl.ammo, 1)


func test_a_popup_is_revealed_by_its_first_attack() -> void:
	var e := _arena([Vector3i(6, 5, 0)])
	var c: Combatant = e.cur.c
	_chromed(["cyberarm", "popup_ranged_weapon@heavy_pistol"], c)
	var w: Weapon = c.weapons.filter(func(x): return x.popup != "")[0]
	assert_true(e.draw(w), "drawn without an Action")
	assert_true(e.turn.action_available)
	var r := e.attack(e.units[1], w, Attack.Mode.SINGLE)
	assert_true(r.get("ok", false))
	assert_true(w.revealed, "seen once used")
	assert_false(c.concealed(c.implant("popup_ranged_weapon")))
	c.gig_reset()
	assert_false(w.revealed, "hidden again next gig")


func test_a_foes_unrevealed_popup_stays_off_the_inspector() -> void:
	var g := _chromed(["cyberarm", "popup_ranged_weapon@heavy_smg"], Fixtures.shooter("G"))
	g.team = 1
	var card := Hud.stat_block(g, true)
	assert_false(card.contains("Popup Heavy SMG"), "not until it's used")
	assert_false(card.contains("Popup Ranged"), "nor the piece")
	g.weapons.filter(func(x): return x.popup != "")[0].revealed = true
	assert_true(Hud.stat_block(g, true).contains("Popup Heavy SMG"))
	g.team = 0
	g.weapons.filter(func(x): return x.popup != "")[0].revealed = false
	assert_true(Hud.stat_block(g, true).contains("Popup Heavy SMG"), "the crew knows its own")


func test_popups_survive_a_save() -> void:
	var c := _chromed(["cyberarm", "popup_ranged_weapon@smg", "popup_shield"], Recruit.generate(Dice.new(4), "solo", "edgerunner", "S"))
	c.shield_piece().hp = 4
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var back := Combatant.from_dict(d)
	var w: Array = back.weapons.filter(func(x): return x.popup != "")
	assert_eq(w.size(), 1)
	assert_eq(w[0].display_name(), "Popup SMG")
	assert_eq(String(back.implant("popup_ranged_weapon").choice), "smg")
	assert_eq(back.shield_hp(), 4, "a shield's HP is kept")


func test_npc_blocks_carry_their_popups_as_printed() -> void:
	var blocks: Dictionary = RulesDB.load_json("npcs.json")["blocks"]
	for id in blocks:
		var srcs: Dictionary = blocks[id].get("weapon_sources", {})
		if not srcs.values().has("popup_ranged_weapon"):
			continue
		var c := Recruit.from_block(Dice.new(1), String(id))
		var pw: Array = c.weapons.filter(func(x): return x.popup.begins_with("popup_ranged_weapon"))
		assert_eq(pw.size(), 1, "%s: the printed popup gun is in the arm" % id)
		assert_false(pw[0].revealed)
		return
	assert_true(false, "a block with a popup gun")


# --- Popup Shield (p.183, p.365) -------------------------------------------------------------------

func test_the_popup_shield_comes_out_free_and_takes_the_attack() -> void:
	var e := _arena([Vector3i(8, 5, 0)])
	var g: Dictionary = e.units[1]
	_chromed(["cyberarm", "popup_shield"], e.cur.c)
	var c: Combatant = e.cur.c
	assert_eq(c.shield_hp(), 10, "a Bulletproof Shield: 10 HP")
	var opt: Dictionary = e.chrome_options().filter(func(o): return o.id == "popup_shield")[0]
	assert_eq(String(opt.cost), "FREE")
	assert_true(e.use_chrome("popup_shield").ok)
	assert_true(c.shield_out and e.turn.action_available, "drawn without an Action (p.365)")
	assert_false("shield" in e.grapple_options(), "one shield at a time")
	assert_eq(Attack.preview(c, Weapon.from_id("assault_rifle"), g.c, Attack.Mode.SINGLE, 10.0).reason, "two-handed: shield out")
	# the guard shoots: the shield takes the whole attack, no dodge (p.183)
	e.cur = g
	e.turn = TurnState.begin(e.dice, g.c)
	var w: Weapon = g.c.weapons[0]
	var p := e.preview(e.units[0], w, Attack.Mode.SINGLE)
	assert_true(p.has("popup_shield"))
	assert_eq(int(p.defense_base), -1, "no dodge")
	var hp := c.hp
	var hits := 0
	for i in 12:
		e.turn = TurnState.begin(e.dice, g.c)
		w.ammo = w.mag()
		var r := e.attack(e.units[0], w, Attack.Mode.SINGLE)
		if r.hit:
			hits += 1
		if c.shield_hp() <= 0:
			break
	assert_true(hits > 0)
	assert_eq(c.hp, hp, "nothing gets through to them")
	assert_eq(c.shield_hp(), 0, "until it's destroyed")
	assert_true(e.log.any(func(l): return l.contains("popup shield breaks")))
	assert_false(e.preview(e.units[0], w, Attack.Mode.SINGLE).has("popup_shield"), "destroyed: no cover")
	e.cur = e.units[0]
	e.turn = TurnState.begin(e.dice, c)
	assert_false(e.use_chrome("popup_shield").ok, "only a shield with HP folds away (p.365)")
	assert_true(c.shield_out, "stuck out")


func test_a_shield_holder_counts_as_in_cover_for_suppression() -> void:
	var e := _arena([Vector3i(8, 5, 0)])
	var g: Dictionary = e.units[1]
	assert_true(e.suppress_targets(e.units[0]).has(g))
	_chromed(["cyberarm", "popup_shield"], g.c)
	g.c.shield_out = true
	assert_false(e.suppress_targets(e.units[0]).has(g), "while you wield a shield you are in cover (p.183)")


func test_a_damaged_popup_shield_is_replaced_after_the_gig() -> void:
	var camp := Campaign.new_game(7)
	var c: Combatant = camp.crew[0]
	_chromed(["cyberarm", "popup_shield"], c)
	c.shield_piece().hp = 0
	camp.eb = 150
	var who := camp._replace_popup_shields()
	assert_eq(who, [c.display_name])
	assert_eq(c.shield_hp(), 10)
	assert_eq(camp.eb, 50, "a Bulletproof Shield: 100eb")


# --- Skill Chip (p.359-360) -------------------------------------------------------------------------

func test_a_skill_chip_trains_its_skill_at_three_unless_higher() -> void:
	var c := Fixtures.unarmored("C")
	_chromed(["neural_link", "chipware_socket", "skill_chip@handgun", "chipware_socket", "skill_chip@stealth"], c)
	assert_eq(c.skill_level("handgun"), 3, "trained at +3")
	assert_eq(c.skill_level("stealth"), 3)
	c.skills["handgun"] = 5
	assert_eq(c.skill_level("handgun"), 5, "already higher: it does nothing")
	c.cyber_off[Cyber.key(c.implant("skill_chip@stealth"))] = 3
	assert_eq(c.skill_level("stealth"), 0, "knocked out: nothing")
	assert_eq(Cyber.display("skill_chip@stealth"), "Skill Chip: Stealth")
	assert_eq(Cyber.price("skill_chip@autofire"), 1000, "(x2) Skills cost more (p.360)")
	assert_eq(Cyber.price("skill_chip@stealth"), 500)


func test_chips_swap_at_the_safehouse_and_a_reused_chip_costs_no_humanity() -> void:
	var camp := Campaign.new_game(3)
	var c: Combatant = camp.crew[0]
	for k in ["cyberware/neural_link", "cyberware/chipware_socket", "cyberware/skill_chip@handgun"]:
		camp._put(k)
	if not c.has_cyberware("neural_link"):
		assert_true(camp.install(c, "neural_link") >= 0)
	assert_true(camp.install(c, "chipware_socket") >= 0)
	var hum := c.humanity
	var lost := camp.install(c, "skill_chip@handgun")
	assert_true(lost > 0, "the first time costs Humanity (p.359)")
	assert_eq(String(c.implant("skill_chip").choice), "handgun")
	assert_true(camp.remove(c, "skill_chip@handgun", "chipware"))
	assert_eq(camp.stored("cyberware/skill_chip@handgun"), 1, "out whole, back to storage")
	var h2 := c.humanity
	assert_eq(camp.install(c, "skill_chip@handgun"), 0, "re-installing a chip you've used costs nothing (p.359)")
	assert_eq(c.humanity, mini(h2, c.max_humanity))
	assert_true(hum > c.humanity)


# --- Scanners, TeleOptics (p.361, p.365-366) ----------------------------------------------------------

func test_arm_scanners_add_two_and_dont_stack_with_the_carried_ones() -> void:
	var c := _chromed(["cyberarm", "medscanner"])
	var fa := c.skill_base("first_aid")
	var bare := Fixtures.shooter("B")
	assert_eq(fa, bare.skill_base("first_aid") + 2, "+2 First Aid (p.365)")
	assert_eq(c.skill_base("paramedic"), bare.skill_base("paramedic") + 2)
	c.kit[1] = "gear/medscanner"
	assert_eq(c.skill_base("first_aid"), fa, "the carried one doesn't stack")
	var t := _chromed(["cyberarm", "techscanner"])
	assert_eq(t.skill_base("weaponstech"), Fixtures.shooter("X").skill_base("weaponstech") + 2)


func test_teleoptics_add_one_to_single_and_aimed_shots_at_51_m() -> void:
	var a := _chromed(["cybereye", "teleoptics"])
	var bare := Fixtures.shooter("B")
	var w := Weapon.from_id("assault_rifle")
	var t := Fixtures.unarmored()
	var b0 := int(Attack.preview(bare, w, t, Attack.Mode.SINGLE, 60.0).base)
	assert_eq(int(Attack.preview(a, w, t, Attack.Mode.SINGLE, 60.0).base), b0 + 1, "single shot at 60 m")
	assert_eq(int(Attack.preview(a, w, t, Attack.Mode.AIMED_HEAD, 60.0).base), int(Attack.preview(bare, w, t, Attack.Mode.AIMED_HEAD, 60.0).base) + 1, "aimed")
	assert_eq(int(Attack.preview(a, w, t, Attack.Mode.SINGLE, 50.0).base), int(Attack.preview(bare, w, t, Attack.Mode.SINGLE, 50.0).base), "under 51 m: nothing")
	assert_eq(int(Attack.preview(a, w, t, Attack.Mode.AUTOFIRE, 60.0).base), int(Attack.preview(bare, w, t, Attack.Mode.AUTOFIRE, 60.0).base), "not autofire")


# --- Linear Frames, Hardened Shielding (p.367) --------------------------------------------------------

func test_linear_frames_set_body_and_need_grafted_muscle_and_body() -> void:
	var camp := Campaign.new_game(5)
	var c: Combatant = camp.crew[0]
	c.stats["BODY"] = 5
	for k in ["grafted_muscle_and_bone_lace", "grafted_muscle_and_bone_lace", "implanted_linear_frame_sigma", "implanted_linear_frame_beta"]:
		camp._put("cyberware/" + k)
	for p in c.implants.filter(func(x): return String(x.id) == "grafted_muscle_and_bone_lace"):
		c.implants.erase(p)
	assert_eq(camp.install_block(c, "implanted_linear_frame_sigma"), "Needs Grafted Muscle and Bone Lace")
	assert_true(camp.install(c, "grafted_muscle_and_bone_lace") >= 0)
	assert_eq(c.raw_stat("BODY"), 7)
	assert_eq(camp.install_block(c, "implanted_linear_frame_beta"), "Needs two Grafted Muscle and Bone Lace")
	assert_eq(camp.install_block(c, "implanted_linear_frame_sigma"), "", "BODY 7 with the lace: over 6")
	var hp_before := c.max_hp()
	assert_true(camp.install(c, "implanted_linear_frame_sigma") >= 0)
	assert_eq(c.raw_stat("BODY"), 12, "BODY becomes 12")
	assert_eq(c.death_save_target(), 12, "the Death Save follows")
	assert_true(c.max_hp() > hp_before, "and HP")
	assert_eq(c.seriously_wounded_threshold(), ceili(c.max_hp() / 2.0))
	assert_eq(camp.install_block(c, "implanted_linear_frame_beta"), "Only one linear frame")
	assert_eq(camp.remove_block(c, "grafted_muscle_and_bone_lace"), "Implanted Linear Frame Sigma needs it")
	var b := Fixtures.unarmored("B", {"BODY": 6})
	b.install_cyberware("grafted_muscle_and_bone_lace")
	b.install_cyberware("grafted_muscle_and_bone_lace")
	assert_eq(b.raw_stat("BODY"), 8, "two laces don't stack (p.111)")
	assert_eq(Cyber.stat_block(b, "implanted_linear_frame_beta"), "", "BODY 8")
	b.install_cyberware("implanted_linear_frame_beta")
	assert_eq(b.raw_stat("BODY"), 14)
	assert_eq(Attack.handling_reason(Weapon.from_id("rhinemetall_emg86"), b), "", "BODY 11+ weapons in hand")
	var hb := c.max_humanity
	c.remove_cyberware("implanted_linear_frame_sigma")
	assert_eq(c.max_humanity, hb + 4, "borgware: 4 of the cap (p.230)")


func test_hardened_shielding_is_sold_and_shown() -> void:
	assert_true(Cyber.modelled("hardened_shielding"))
	var c := _chromed(["cyberarm", "hardened_shielding"])
	assert_true("Hardened Shielding" in Cyber.names(c.implants))


# --- The chrome menu and the AI ------------------------------------------------------------------------

func test_the_chrome_menu_lists_only_activated_chrome() -> void:
	var e := _arena([])
	assert_true(e.chrome_options().is_empty(), "no chrome: no menu")
	_chromed(["neural_link", "kerenzikov", "cyberarm", "popup_ranged_weapon@heavy_pistol"], e.cur.c)
	assert_true(e.chrome_options().is_empty(), "always-on chrome and popup guns aren't in it (the gun is in the attack menu)")
	assert_true(Hud.weapon_tabs(e.cur.c).any(func(w): return w != null and w.popup != ""), "the popup is a weapon tab")
	_chromed(["popup_shield"], e.cur.c)
	assert_eq(e.chrome_options().map(func(o): return o.id), ["popup_shield"])
	for o in e.chrome_options():
		assert_true(String(o.line).split(" ").size() <= 10, "one short line: " + String(o.line))
		assert_false(TextCites.has_cite(String(o.line)), "no cites in player text")
	assert_true(Hud.help_text().contains("C  Chrome menu"), "listed in the controls panel")
	assert_eq(Hud.CHROME_KEY, "C", "C for chrome (owner, 2026-11-11)")
	assert_false(Hud.MAIN_ACTIONS.any(func(r): return r[2] == Hud.CHROME_KEY and r[0] != "chrome"), "a key of its own")


func test_a_guard_kicks_in_the_sandevistan_on_first_contact() -> void:
	var e := _arena([Vector3i(27, 5, 0)])
	var g: Dictionary = e.units[1]
	_chromed(["neural_link", "sandevistan"], g.c)
	g.c.skills["handgun"] = 0   # no shot worth taking at this range
	e.cur = g
	e.turn = TurnState.begin(e.dice, g.c)
	AI.act(e, g)
	assert_true(g.c.chrome_on.has("sandevistan"), "first contact, no good shot: speedware")
	assert_true(e.events.any(func(x): return x.type == "chrome"))


func test_a_guard_with_a_good_shot_shoots_first() -> void:
	var e := _arena([Vector3i(5, 5, 0)])
	var g: Dictionary = e.units[1]
	_chromed(["neural_link", "sandevistan"], g.c)
	g.c.skills["handgun"] = 10
	e.cur = g
	e.turn = TurnState.begin(e.dice, g.c)
	AI.act(e, g)
	assert_false(g.c.chrome_on.has("sandevistan"))
	assert_true(e.events.any(func(x): return x.type == "attack"))


func test_a_guard_pops_a_better_gun_and_its_shield() -> void:
	var e := _arena([Vector3i(12, 5, 0)])
	var g: Dictionary = e.units[1]
	g.c.weapons.clear()
	g.c.weapons.append(Weapon.from_id("medium_pistol"))
	_chromed(["cyberarm", "popup_grenade_launcher", "cyberarm", "popup_shield"], g.c)
	g.c.skills["heavy_weapons"] = 8
	e.cur = g
	e.turn = TurnState.begin(e.dice, g.c)
	AI.act(e, g)
	var gl: Weapon = g.c.weapons.filter(func(x): return x.id() == "grenade_launcher")[0]
	assert_true(gl.revealed, "the launcher hits harder: popped and fired")
	assert_eq(gl.ammo, 0)
	assert_true(g.c.shield_out, "a one-hander: the other arm holds the shield")
	e.turn = TurnState.begin(e.dice, g.c)
	e.events.clear()
	AI.act(e, g)
	assert_eq(g.c.weapons[0].id(), "medium_pistol", "a spent single shot: back to the pistol, not a reload")
