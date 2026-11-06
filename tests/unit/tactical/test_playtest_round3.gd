extends TestCase
## Playtest round 3: stance labels, witnesses (NCPD neutral until a crime), the alarm countdown,
## magazines at gig start, Mortally Wounded crew acting, FLATLINED, no NPC Death Saves, autofire.


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func _enc(seed := 1, opts := {}) -> Encounter:
	var m := SceneGen.generate(11, "street_block", {"security": 2})
	var dice := Dice.new(seed)
	return Encounter.setup(m, dice, _crew(dice), "data", opts)


## An open 16x10 floor, the crew member at (2,5); `guards` alerted on OPFOR.
func _arena(guards: Array) -> Encounter:
	var m := TacMap.new(16, 10, 1)
	for y in 10:
		for x in 16:
			m.set_t(0, x, y, TacMap.T.FLOOR)
	m.entrances.append({"floor": 0, "pos": Vector2i(2, 5), "kind": "deploy", "main": false, "cells": [Vector2i(2, 5)]})
	var dice := Dice.new(3)
	var crew: Array[Combatant] = [Fixtures.shooter("A")]
	crew[0].weapons.append(Weapon.from_id("assault_rifle"))
	var e := Encounter.setup(m, dice, crew)
	e.units = e.units.filter(func(u): return u.team == 0)
	for cell in guards:
		e._add(Fixtures.unarmored("G%d" % e.units.size(), {"REF": 4}), cell, Encounter.OPFOR)
		e.units[-1].alerted = true
	e.units[0].pos = Vector3i(2, 5, 0)
	e.cur = e.units[0]
	e.turn = TurnState.begin(dice, e.cur.c)
	return e


# --- 1. One relation query for every stance label --------------------------------------------

func test_stance_labels_come_from_the_relation_query() -> void:
	var e := _enc()
	assert_eq(Hud.stance(e, Encounter.OPFOR), "HOSTILE")
	assert_eq(Hud.stance(e, e.CIV_TEAM), "NEUTRAL", "bystanders are neutral (the hover tip said HOSTILE)")
	assert_eq(Hud.stance(e, Encounter.TT_TEAM), "NEUTRAL")
	assert_eq(Hud.stance(e, Encounter.CREW), "ALLIED")
	assert_eq(Hud.stance_col("HOSTILE"), Hud.RED)
	assert_eq(Hud.stance_col("NEUTRAL"), Hud.NEUTRAL)
	assert_eq(Hud.stance_col("ALLIED"), Hud.CYAN)


# --- 2. Responders who aren't the site's own are witnesses ------------------------------------

func test_police_are_neutral_to_the_crew_by_kind() -> void:
	assert_eq(World.relation("crew", "ncpd"), "neutral", "HOUSE-RULE: cops aren't after the crew until they see a crime")


func test_ncpd_arrive_neutral_and_turn_on_an_attack_they_hear() -> void:
	var e := _enc(1, {"security_code": {"n": 11, "faction": "", "intensity": "medium", "hardened": false},
		"district_code": {"n": 11, "faction": "ncpd", "intensity": "medium", "hardened": false}})
	var before := e.units.size()
	e._arrive(e._plan_response(e.street_code))
	var cops := e.units.slice(before)
	assert_false(cops.is_empty(), "the NCPD arrive")
	var t := int(cops[0].team)
	assert_eq(e.relation(t, Encounter.CREW), "neutral", "no crime seen yet: not hostile (they engaged on sight)")
	assert_eq(Hud.stance(e, t), "NEUTRAL")
	assert_false(e.opfor().any(func(u): return u in cops), "not part of the opposition yet")
	var crew: Dictionary = e.units[0]
	assert_false(AI._enemies(e, cops[0]).has(crew), "the AI doesn't target the crew")
	assert_true(e.watching(cops[0]))
	# Gunfire from the crew within earshot is a crime they witness.
	var gun := crew.duplicate()
	gun.pos = cops[0].pos + Vector3i(3, 0, 0)
	e._witness_attack(crew, [gun.pos])
	assert_eq(e.relation(t, Encounter.CREW), "hostile", "they heard the crew open fire")
	assert_eq(Hud.stance_col(Hud.stance(e, t)), Hud.RED, "the stance turns red")
	assert_true(e.opfor().any(func(u): return u in cops), "now they count as opposition")


func test_witnesses_stay_neutral_far_from_a_fight_and_turn_on_a_raised_alarm() -> void:
	var e := _arena([Vector3i(14, 1, 0)])
	var t := e.witness_side("ncpd")
	e._add(Fixtures.unarmored("Cop"), Vector3i(15, 9, 0), t)
	var cop: Dictionary = e.units[-1]
	cop.alerted = true
	e._witness_attack(e.units[0], [Vector3i(2, 4, 0)])   # crew shooting 13+ squares from the cop
	assert_eq(e.relation(t, Encounter.CREW), "neutral", "out of earshot (GUNFIRE_RANGE)")
	var t2 := e.witness_side("6th_street")
	e._add(Fixtures.unarmored("Local"), Vector3i(12, 1, 0), t2)
	e.call_it_in(e.units[1])
	assert_eq(e.relation(t2, Encounter.CREW), "hostile", "a guard calling it in in front of them")


func test_witnesses_turn_on_crew_found_trespassing() -> void:
	var e := _enc()
	var t := e.witness_side("ncpd")
	var crew: Dictionary = e.units[0]
	var spot := Vector3i(-1, -1, -1)   # a restricted square next to the crew member's
	for f in e.m.floors:
		for y in e.m.h:
			for x in e.m.w:
				var v := Vector3i(x, y, f)
				if spot.x < 0 and f == e.m.street and e.m.walkable(f, Vector2i(x, y)) and not e.in_public(v) and not e.occupied().has(v):
					spot = v
	assert_true(spot.x >= 0, "the site has a restricted square")
	crew.pos = spot
	e._add(Fixtures.unarmored("Cop"), spot, t)   # standing on them: always in sight
	var cop: Dictionary = e.units[-1]
	cop.alerted = true
	e._spot_rolls[[cop.id, crew.id, e.init.round_num]] = true
	e.update_alerts()
	assert_eq(e.relation(t, Encounter.CREW), "hostile", "crew in a restricted area")


# --- 3. The alarm countdown ---------------------------------------------------------------

func test_alarm_countdown_counts_to_arriving_and_never_shows_a_negative() -> void:
	var e := _enc(1, {"security_code": {"n": 11, "faction": "", "intensity": "medium", "hardened": false}, "district_code": {}})
	e.call_it_in(e.units.filter(func(u): return u.team == Encounter.OPFOR)[0])
	var n := e.backup_in
	assert_true(n >= SecurityCode.ROUNDS_PER_MINUTE, "at least a minute away (2 rounds a minute, HOUSE-RULE)")
	assert_true(Hud.alarm_text(e).ends_with("IN %d ROUNDS" % n))
	var before := e.units.size()
	var seen: Array[String] = []
	for k in n + 2:
		e.init.round_num += 1
		e._tick_backup()
		seen.append(Hud.alarm_text(e))
	assert_true(seen.all(func(s): return not s.contains("-")), "no negative countdown: %s" % [seen])
	assert_eq(seen[n - 1], "ALARM · BACKUP ARRIVING", "0 shows ARRIVING, the round they land")
	assert_true(e.units.size() > before, "they landed")
	assert_eq(seen[n], "ALARM")
	assert_eq(Hud.countdown_text("BACKUP", -1), "ALARM · NOBODY ANSWERS", "the call's toast when no one answers")
	assert_eq(Hud.countdown_text("BACKUP", 1), "ALARM · BACKUP IN 1 ROUND")


# --- 4. Magazines at gig start ---------------------------------------------------------------

func test_weapons_start_every_gig_with_a_full_magazine() -> void:
	var dice := Dice.new(4)
	var crew := _crew(dice)
	var w := Weapon.from_id("heavy_pistol")
	crew[0].weapons = [w]
	w.ammo = 0
	w.jammed = true
	var saved := Combatant.from_dict(crew[0].to_dict())
	assert_eq(saved.weapons[0].ammo, 0, "a save carries the last gig's count")
	crew[0] = saved
	var e := Encounter.setup(SceneGen.generate(11, "street_block", {"security": 1}), dice, crew)
	assert_eq(e.units[0].c.weapons[0].ammo, w.mag(), "full at gig start")
	assert_false(e.units[0].c.weapons[0].jammed)


# --- 5. Mortally Wounded crew act ----------------------------------------------------------

func test_mortally_wounded_crew_take_their_turn_at_the_penalties() -> void:
	var t: TurnState = null
	var c: Combatant
	for s in range(1, 30):
		c = Fixtures.shooter("Dying")
		c.hp = 0
		t = TurnState.begin(Dice.new(s), c)
		if t.survived:
			break
	assert_true(t.survived and not c.dead)
	assert_true(t.action_available and t.move_actions == 1, "a successful Death Save: they act (p.222)")
	assert_eq(c.action_penalty(), 4, "-4 to all Actions (p.220)")
	assert_eq(c.stat("MOVE"), maxi(1, c.raw_stat("MOVE") - 6), "-6 MOVE, min 1 (p.220)")
	assert_true(Hud.conditions(c).any(func(s): return s.contains("-4 to all Actions")), "the HUD shows the penalty")


func test_a_mortally_wounded_crew_member_still_sees() -> void:
	var e := _enc()
	e.units[1].c.dead = true
	e.units[0].c.hp = 0
	e.refresh_vision()
	assert_true(e.vision.visible.has(e.units[0].pos), "the dying crew member's sight drives the fog (they aim and move)")


# --- 6. FLATLINED ---------------------------------------------------------------------

func test_death_reads_flatlined() -> void:
	var c := Fixtures.shooter("Gone")
	c.dead = true
	assert_eq(Campaign.WOUND_NAMES[c.wound_state()], "Flatlined")
	assert_true(Hud.stat_block(c, false).contains("Flatlined"))
	assert_false(Hud.stat_block(c, true).contains("Dead"))


# --- 7. No Death Saves for NPCs (HOUSE-RULE) -----------------------------------------------

func test_npcs_flatline_below_one_hp_and_crew_keep_death_saves() -> void:
	var e := _arena([Vector3i(8, 5, 0), Vector3i(9, 5, 0)])
	var g: Dictionary = e.units[1]
	var r := {"damage": 200, "location": "body"}
	Attack.apply_damage(e.dice, g.c, r, false, false, false)
	assert_true(g.c.dead, "a guard under 1 HP flatlines")
	var crew: Dictionary = e.units[0]
	Attack.apply_damage(e.dice, crew.c, {"damage": crew.c.hp + 30, "location": "body"}, false, false, false)
	assert_false(crew.c.dead, "the crew are Mortally Wounded and roll Death Saves")
	assert_eq(crew.c.wound_state(), Combatant.Wound.MORTAL)
	var g2: Dictionary = e.units[2]
	g2.c.hp = -2   # fire, strain or brain damage: the sweep catches it
	e._check_end()
	assert_true(g2.c.dead)


func test_captives_and_trauma_cardholders_keep_death_saves() -> void:
	var m := SceneGen.generate(5, "lone_building", {"security": 1})
	var d := Dice.new(9)
	var e := Encounter.setup(m, d, _crew(d), "rescue")
	var cap: Dictionary = e.units[int(e.objective.captive)]
	assert_true(cap.c.death_saves, "the rescue needs them alive: they can be stabilised")
	var g: Dictionary = e.units.filter(func(u): return u.team == Encounter.OPFOR)[0]
	assert_false(g.c.death_saves)
	g["trauma_card"] = true
	e._trauma_cards()
	assert_true(g.c.death_saves, "a cardholder lives until Trauma Team lands")


# --- 8. Autofire (p.173-174) ----------------------------------------------------------------

func test_autofire_dv_table() -> void:
	# [table, metres, DV] from the p.173 Autofire table; -1 is out of range.
	var rows := [["smg", 1, 20], ["smg", 6, 20], ["smg", 7, 17], ["smg", 12, 17], ["smg", 13, 20], ["smg", 25, 20],
		["smg", 26, 25], ["smg", 50, 25], ["smg", 51, 30], ["smg", 100, 30], ["smg", 101, -1],
		["assault_rifle", 6, 22], ["assault_rifle", 7, 20], ["assault_rifle", 13, 17], ["assault_rifle", 26, 20],
		["assault_rifle", 51, 25], ["assault_rifle", 101, -1]]
	for row in rows:
		assert_eq(RulesDB.range_dv(String(row[0]), float(row[1]), true), int(row[2]), "%s at %d m" % [row[0], row[1]])
	assert_eq(String(Weapon.from_id("heavy_smg").def.autofire_range), "smg", "the Heavy SMG uses the SMG column")


func test_autofire_damage_ammo_and_crits() -> void:
	# [weapon, multiplier cap] (p.94, p.173)
	for row in [["smg", 3], ["heavy_smg", 3], ["assault_rifle", 4]]:
		var w := Weapon.from_id(String(row[0]))
		assert_eq(w.autofire_mult(), int(row[1]))
		var hits := 0
		for s in range(1, 120):
			var a := Fixtures.shooter("A", {"REF": 8})
			a.skills["autofire"] = 8
			var t := Fixtures.unarmored("T", {"REF": 4, "BODY": 10})
			t.hp_max_override = 500
			t.hp = 500
			w.reload()
			var r := Attack.resolve(Dice.new(s), a, w, t, Attack.Mode.AUTOFIRE, 10.0)
			assert_eq(w.ammo, w.mag() - 10, "autofire spends 10 rounds (p.173)")
			if not r.hit:
				continue
			hits += 1
			var beat: int = r.check.total - r.check.dv
			assert_eq(r.damage, (r.faces[0] + r.faces[1]) * mini(beat, int(row[1])), "2d6 x the amount over the DV, capped (p.173)")
			assert_eq(r.faces.size(), 2)
			assert_eq(not r.crits.is_empty(), r.faces[0] == 6 and r.faces[1] == 6, "a crit on double 6s only")
		assert_true(hits > 20)
		w.ammo = 9
		assert_eq(Attack.preview(Fixtures.shooter(), w, Fixtures.unarmored(), Attack.Mode.AUTOFIRE, 10.0).reason, "need 10 rounds")


func test_suppressive_fire_skips_targets_in_cover() -> void:
	var e := _arena([Vector3i(8, 5, 0), Vector3i(8, 2, 0)])
	e.m.set_t(0, 7, 2, TacMap.T.WALL)   # cover beside the second guard, on the shooter's side
	e.los = Los.new(e.m)
	var got := e.suppress_targets(e.units[0])
	assert_true(got.has(e.units[1]), "in the open")
	assert_false(got.has(e.units[2]), "behind cover: out of reach of suppression (p.174)")
	var w: Weapon = e.cur.c.weapons[0]
	var r := e.suppress(w)
	assert_true(r.ok)
	assert_eq(w.ammo, w.mag() - 10, "10 rounds (p.174)")
