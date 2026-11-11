extends TestCase
## Cyberware phases 3 and 4 (CPR core p.359-366, p.169): movement (Grip Foot on ladders, Skate Foot on
## a Run, the Grapple Hand's line to a ledge), the NET and downtime (Interface Plugs gate jacking in,
## the save migration, Enhanced Antibodies), the heavily chromed Mini Boss, guards using all of it,
## and what's now on sale.


## A 30x10 street (floor 0) under a two-storey block whose roof (floors 1 and 2) covers x >= 14:
## open air over the street to its west. A ladder runs from (4,2,0) to (4,2,1) on a ledge at x 3-5,
## y 1-3 of floor 1. The crew member at (2,5,0); alerted guards at `guard_cells`.
func _arena(guard_cells: Array, seed := 3) -> Encounter:
	var m := TacMap.new(30, 10, 3)
	for y in 10:
		for x in 30:
			m.set_t(0, x, y, TacMap.T.FLOOR)
			if x >= 14:
				m.set_t(1, x, y, TacMap.T.FLOOR)
				m.set_t(2, x, y, TacMap.T.ROOF)
	for y in range(1, 4):
		for x in range(3, 6):
			m.set_t(1, x, y, TacMap.T.ROOF)
	m.connectors.append({"type": "ladder", "a": Vector3i(4, 2, 0), "b": Vector3i(4, 2, 1)})
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


const LEGS := ["cyberleg", "cyberleg"]


# --- Grip Foot (p.366; climbing p.169) ----------------------------------------------------------

func test_a_ladder_costs_two_a_floor_and_one_with_grip_feet() -> void:
	var e := _arena([])
	e.cur.pos = Vector3i(4, 2, 0)
	e.turn = TurnState.begin(e.dice, e.cur.c)
	assert_eq(int(e.move_options().get(Vector3i(4, 2, 1), -1)), 2, "climbing: 2 squares for every 1 (p.169)")
	_chromed(LEGS + ["grip_foot"], e.cur.c)
	assert_eq(int(e.move_options().get(Vector3i(4, 2, 1), -1)), 2, "one grip foot does nothing: they come paired (p.366)")
	_chromed(["grip_foot"], e.cur.c)
	assert_true(e.cur.c.climbs_free())
	assert_eq(int(e.move_options().get(Vector3i(4, 2, 1), -1)), 1, "no climbing penalty: a floor costs what the stairs do")
	assert_true(e.move_to(Vector3i(4, 2, 1)))
	assert_eq(e.turn.squares_moved, 1, "and the move is priced the same")
	assert_false(e.nav.climb_free, "the discount is theirs alone: Nav goes back to the book's price")


func test_a_knocked_out_grip_foot_climbs_like_meat() -> void:
	var e := _arena([])
	e.cur.pos = Vector3i(4, 2, 0)
	_chromed(LEGS + ["grip_foot", "grip_foot"], e.cur.c)
	e.cur.c.cyber_off[Cyber.key(e.cur.c.implant("grip_foot", "left_leg"))] = 3
	e.turn = TurnState.begin(e.dice, e.cur.c)
	assert_eq(int(e.move_options().get(Vector3i(4, 2, 1), -1)), 2)


# --- Jumping and the Jump Booster (p.169, p.366) -------------------------------------------------

## Two roofs on floor 1 split by a gap of `gap` squares of open air: x 0..9 and x 10+gap..29, y 0..9.
## The crew member at (9,5,1), on the west roof's edge.
func _roofs(gap: int) -> Encounter:
	var m := TacMap.new(30, 10, 2)
	for y in 10:
		for x in 30:
			m.set_t(0, x, y, TacMap.T.FLOOR)
			if x < 10 or x >= 10 + gap:
				m.set_t(1, x, y, TacMap.T.ROOF)
	m.entrances.append({"floor": 0, "pos": Vector2i(2, 5), "kind": "deploy", "main": false, "cells": [Vector2i(2, 5)]})
	var dice := Dice.new(3)
	var crew: Array[Combatant] = [Fixtures.shooter("A")]
	var e := Encounter.setup(m, dice, crew)
	e.units = e.units.filter(func(u): return u.team == 0)
	e.units[0].pos = Vector3i(9, 5, 1)
	e.cur = e.units[0]
	e.turn = TurnState.begin(dice, e.cur.c)
	return e


## The jump links out of square `v`: {landing: cost}.
func _jumps(n: Nav, v: Vector3i) -> Dictionary:
	var out := {}
	for l in n._links.get(v, []):
		if String(l[2]) == "jump":
			out[l[0]] = int(l[1])
	return out


func test_a_running_jump_costs_two_squares_a_square() -> void:
	var e := _roofs(2)
	var far := Vector3i(12, 5, 1)   # 3 squares on: 2 of air and the landing
	assert_eq(int(e.move_options().get(far, -1)), 6, "jumping with a running start: 2 for every 1 (p.169)")
	assert_true(e.move_to(far))
	assert_eq(e.turn.squares_moved, 6)


func test_jump_boosters_jump_at_walking_cost() -> void:
	var e := _roofs(2)
	_chromed(LEGS + ["jump_booster"], e.cur.c)
	assert_eq(int(e.move_options().get(Vector3i(12, 5, 1), -1)), 6, "one booster: they come paired")
	_chromed(["jump_booster"], e.cur.c)
	assert_true(e.cur.c.jumps_free())
	assert_eq(int(e.move_options().get(Vector3i(12, 5, 1), -1)), 3, "no jumping penalty (p.366)")
	assert_false(e.nav.jump_free, "theirs alone")


func test_the_longest_jump_and_a_standing_one() -> void:
	assert_true(_jumps(_roofs(4).nav, Vector3i(9, 5, 1)).is_empty(), "8 m of air: too far")
	var e := _roofs(3)
	assert_eq(_jumps(e.nav, Vector3i(9, 5, 1)), {Vector3i(13, 5, 1): 8}, "6 m with a run-up: 4 squares at 2 each")
	e.m.set_t(1, 8, 5, TacMap.T.VOID)   # nothing behind the take-off: a standing jump, half the distance
	assert_false(_jumps(Nav.new(e.m), Vector3i(9, 5, 1)).has(Vector3i(13, 5, 1)), "standing: not 6 m")
	var e1 := _roofs(1)
	e1.m.set_t(1, 8, 5, TacMap.T.VOID)
	assert_eq(int(_jumps(Nav.new(e1.m), Vector3i(9, 5, 1)).get(Vector3i(11, 5, 1), -1)), 4, "but 2 m")


func test_no_jumps_at_street_level() -> void:
	var e := _roofs(2)
	for v in e.nav._links:
		for l in e.nav._links[v]:
			assert_true(String(l[2]) != "jump" or (v as Vector3i).z == 1)


# --- Skate Foot (p.366) ---------------------------------------------------------------------------

func test_skate_feet_add_six_metres_to_a_run() -> void:
	var e := _arena([])
	var c: Combatant = e.cur.c
	var far := Vector3i(2 + 6 + 6 + 3, 5, 0)   # MOVE 6 twice, plus 3 squares
	assert_false(e.run_options().has(far), "nothing to run with yet: no Move Action taken")
	assert_false(e.move_to(far, true), "15 squares: beyond a meat Run")
	_chromed(LEGS + ["skate_foot", "skate_foot"], c)
	assert_eq(c.run_bonus_squares(), 3, "+6 m/yds = 3 squares (p.126)")
	assert_eq(e.turn.run_squares(), 9)
	assert_true(e.move_to(far, true), "Move, then Run: 6 + 6 + 3")
	assert_false(e.turn.action_available, "the Run took the Action")
	var e2 := _arena([])
	_chromed(LEGS + ["skate_foot", "skate_foot"], e2.cur.c)
	assert_true(e2.move_to(Vector3i(4, 5, 0)))
	assert_true(e2.run_options().has(far), "run options reach the extra squares")
	assert_false(e2.run_options().has(far + Vector3i(1, 0, 0)))
	assert_eq(int(e2.cur.c.stat("MOVE")), 6, "walking is unchanged: only the Run")


func test_a_guard_on_skates_runs_further_to_the_crew() -> void:
	var e := _arena([Vector3i(29, 9, 0)])
	var g: Dictionary = e.units[1]
	_chromed(LEGS + ["skate_foot", "skate_foot"], g.c)
	e.cur = g
	e.turn = TurnState.begin(e.dice, g.c)
	AI._go_toward(e, g, Vector3i(2, 5, 0))
	assert_eq(e.turn.squares_moved, 15, "MOVE 6, a Run of 6 and the skates' 3")


# --- Grapple Hand (p.365) -------------------------------------------------------------------------

func test_the_grapple_hand_reaches_a_ledge_in_sight_within_30_m() -> void:
	var e := _arena([])
	e.cur.pos = Vector3i(10, 5, 0)
	assert_true(e.grapple_targets(e.cur).is_empty(), "no hand, no line")
	_chromed(["cyberarm", "grapple_hand"], e.cur.c)
	var t := e.grapple_targets(e.cur)
	assert_true(t.has(Vector3i(14, 5, 1)), "the first storey's edge")
	assert_true(t.has(Vector3i(14, 5, 2)), "the roof's edge")
	assert_eq(int(t[Vector3i(14, 5, 2)]), 4 + 2, "4 squares across, a storey a square up: no climbing penalty")
	assert_false(t.has(Vector3i(15, 5, 2)), "only an edge holds the hook: not the middle of the roof")
	assert_true(t.has(Vector3i(5, 2, 1)), "the ladder's ledge too")
	assert_false(t.has(Vector3i(4, 2, 1)), "its middle isn't an edge")
	assert_false(t.has(Vector3i(27, 5, 2)), "beyond 30 m")
	e.cur.pos = Vector3i(20, 5, 0)   # indoors, under the block: no open air to fire through
	assert_false(e.grapple_targets(e.cur).keys().any(func(v): return v.x >= 14), "a ceiling overhead")


func test_firing_the_line_is_an_action_and_the_climb_is_movement() -> void:
	var e := _arena([])
	e.cur.pos = Vector3i(10, 5, 0)
	_chromed(["cyberarm", "grapple_hand"], e.cur.c)
	var opt: Array = e.chrome_options().filter(func(o): return String(o.id) == "grapple_hand")
	assert_eq(opt.size(), 1, "in the chrome menu")
	assert_true(opt[0].ok, String(opt[0].why))
	assert_false(e.grapple_line(Vector3i(16, 5, 2)).ok, "not an edge")
	var r := e.grapple_line(Vector3i(14, 5, 2))
	assert_true(r.ok, String(r.get("reason", "")))
	assert_eq(e.cur.pos, Vector3i(14, 5, 2))
	assert_false(e.turn.action_available, "firing it is the Action")
	assert_eq(e.turn.squares_moved, 6)
	assert_true(e.events.any(func(x): return x.type == "move" and x.get("grapple", false)))
	assert_false(e.grapple_line(Vector3i(14, 6, 2)).ok, "once a turn: the Action's gone")
	assert_eq(String(e.chrome_options().filter(func(o): return String(o.id) == "grapple_hand")[0].why), "No Action left")


func test_the_line_must_fit_the_movement_left() -> void:
	var e := _arena([])
	e.cur.pos = Vector3i(10, 5, 0)
	_chromed(["cyberarm", "grapple_hand"], e.cur.c)
	assert_true(e.move_to(Vector3i(13, 5, 0)))   # 3 of 6 squares gone
	assert_false(e.grapple_line(Vector3i(14, 1, 2)).ok, "4 across and 2 up is 6: only 3 left")
	assert_true(e.grapple_line(Vector3i(14, 5, 2)).ok, "1 across and 2 up fits")


func test_a_guard_grapples_up_to_a_crew_member_on_the_roof() -> void:
	var e := _arena([Vector3i(10, 5, 0)])
	var g: Dictionary = e.units[1]
	_chromed(["cyberarm", "grapple_hand"], g.c)
	e.units[0].pos = Vector3i(22, 5, 2)   # on the roof: no shot from the street
	e.cur = g
	e.turn = TurnState.begin(e.dice, g.c)
	AI.act(e, g)
	assert_eq(g.pos.z, 2, "up the line to the roof")
	assert_true(e.events.any(func(x): return x.type == "move" and x.get("grapple", false)))


# --- Tactile Boost on guard (p.359) --------------------------------------------------------------

func test_a_posted_guard_keeps_a_hand_on_the_wall_and_turns_to_movement() -> void:
	var e := _arena([Vector3i(20, 5, 0)])
	var g: Dictionary = e.units[1]
	g.alerted = false
	_chromed(["neural_link", "chipware_socket", "tactile_boost"], g.c)
	g.erase("patrol")
	e._post_guards()
	if g.has("patrol"):   # a walking guard keeps their hands to themselves
		assert_false(g.c.touching)
		g.erase("patrol")
		g.c.touching = true
	assert_true(g.c.touching, "standing post: hand down")
	g.facing = Vector2(1, 0)   # looking away from the crew, who are behind them
	e._mark_positions()
	e.units[0].pos = Vector3i(8, 5, 0)   # 12 squares behind: 24 m, too far
	e._feel_motion()
	assert_eq(g.facing, Vector2(1, 0), "beyond 20 m")
	e.units[0].pos = Vector3i(12, 5, 0)   # 16 m, moving
	e._feel_motion()
	assert_eq(g.facing, Vector2(-1, 0), "felt it: turned to look")


func test_a_guard_lifts_the_hand_when_the_fight_starts() -> void:
	var e := _arena([Vector3i(12, 5, 0)])
	var g: Dictionary = e.units[1]
	_chromed(["neural_link", "chipware_socket", "tactile_boost"], g.c)
	g.c.touching = true
	e.cur = g
	e.turn = TurnState.begin(e.dice, g.c)
	AI.act(e, g)
	assert_false(g.c.touching, "the hand comes off the wall to fight")


# --- Interface Plugs gate jacking in (p.196, p.359) -----------------------------------------------

func test_a_netrunner_needs_interface_plugs_to_jack_in() -> void:
	var c := Fixtures.shooter("N")
	assert_eq(NetRun.jack_block(c), "Not a Netrunner")
	_chromed(["neural_link", "interface_plugs"], c)
	assert_eq(NetRun.jack_block(c), "Not a Netrunner", "plugs don't make a Netrunner")
	var n := Fixtures.shooter("R")
	n.role = "netrunner"
	n.role_rank = 4
	assert_eq(NetRun.jack_block(n), "Needs Interface Plugs")
	_chromed(["neural_link", "interface_plugs"], n)
	assert_eq(NetRun.jack_block(n), "Needs a cyberdeck", "plugs plug into a deck (p.196)")
	n.deck = Deck.STARTING_DECK
	assert_eq(NetRun.jack_block(n), "")
	n.cyber_off[Cyber.key(n.implant("interface_plugs"))] = 2
	assert_eq(NetRun.jack_block(n), "Interface Plugs offline", "knocked out by a Microwaver")
	for p in NetRun.jack_block(Fixtures.shooter()).split(" "):
		assert_false(p.contains("p."), "no cites in player text")


func test_the_encounter_wont_jack_in_without_plugs() -> void:
	var m := SceneGen.generate(11, "lone_building", {"site": "corp_office", "security": 1})
	var dice := Dice.new(9)
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	var e := Encounter.setup(m, dice, crew)
	var runner: Dictionary = e.units[1]
	var ap_dev: Dictionary = m.devices[m.architecture.access_points[0].device]
	runner.pos = Vector3i(ap_dev.pos.x, ap_dev.pos.y, ap_dev.floor)
	e.cur = runner
	e.turn = TurnState.begin(dice, runner.c)
	var plugs: Dictionary = runner.c.implant("interface_plugs")
	assert_false(plugs.is_empty(), "a Netrunner recruit comes with them")
	runner.c.implants.erase(plugs)
	assert_false(e.jack_in(e.jack_points(runner)[0]), "no plugs: no NET")
	assert_true(e.turn.action_available, "and nothing spent")
	runner.c.implants.append(plugs)
	assert_true(e.jack_in(e.jack_points(runner)[0]))


func test_every_netrunner_recruit_has_plugs() -> void:
	for s in 40:
		var r := Recruit.generate(Dice.new(s + 1), "netrunner")
		assert_eq(NetRun.jack_block(r), "", "recruit %d" % s)


func test_v19_netrunners_without_plugs_get_them_free() -> void:
	var d := Campaign.new_game(4).to_dict()
	d["version"] = 19
	var runner := -1
	for i in (d.crew as Array).size():
		if String(d.crew[i].role) == "netrunner":
			runner = i
	assert_true(runner >= 0, "the starting crew has a Netrunner")
	d.crew[runner]["cyberware"] = [{"id": "shift_tacts", "loc": "fashion"}]
	var other := 0 if runner != 0 else 1
	d.crew[other]["cyberware"] = []
	var hum := int(d.crew[runner].humanity)
	var mig := SaveMigrations.migrate(JSON.parse_string(JSON.stringify(d)))
	var ids: Array = (mig.crew[runner].cyberware as Array).map(func(p): return String(p.id))
	assert_true("interface_plugs" in ids and "neural_link" in ids, "plugs, and the Neural Link they need: %s" % [ids])
	assert_eq((mig.crew[other].cyberware as Array).size(), 0, "nobody else gets any")
	var c := Campaign.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_eq(NetRun.jack_block(c.crew[runner]), "", "and can jack in")
	assert_eq(c.crew[runner].humanity, hum, "free: no Humanity lost")
	assert_eq(int(c.to_dict().version), SaveMigrations.CURRENT)
	var again := SaveMigrations.migrate(JSON.parse_string(JSON.stringify(mig)))
	assert_eq((again.crew[runner].cyberware as Array).size(), ids.size(), "a current save is left alone")


# --- Enhanced Antibodies (p.362) ------------------------------------------------------------------

func test_enhanced_antibodies_double_healing_at_rest() -> void:
	var camp := Campaign.new_game(4)
	var a: Combatant = camp.crew[0]
	var b: Combatant = camp.crew[1]
	a.hp = 1
	b.hp = 1
	_chromed(["enhanced_antibodies"], b)
	assert_eq(b.rest_heal(1), b.raw_stat("BODY") * 2, "BODY x 2 a day")
	assert_eq(a.rest_heal(3), a.raw_stat("BODY") * 3)
	camp.rest(1)
	assert_eq(a.hp, mini(a.max_hp(), 1 + a.raw_stat("BODY")))
	assert_eq(b.hp, mini(b.max_hp(), 1 + 2 * b.raw_stat("BODY")))
	b.hp = 1
	a.hp = a.max_hp()
	assert_eq(camp.days_to_recover(), ceili(float(b.max_hp() - 1) / (2.0 * b.raw_stat("BODY"))), "they're up twice as soon")


# --- The heavily chromed Mini Boss (RTG Hardened Mini Bosses p.2: 600eb more cyberware) -----------

func _boss_enc(seed_value := 3) -> Encounter:
	var m := SceneGen.generate(11, "lone_building", {"security": 3, "site": "corp_office"})
	var dice := Dice.new(seed_value)
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return Encounter.setup(m, dice, crew, "data", {"complication": {"tier": "mini_boss", "roll": 5}})


func test_the_heavily_chromed_boss_gets_600eb_of_combat_chrome() -> void:
	var e := _boss_enc()
	assert_true("cyberware_eb" in e.complication.applied, "applied, not skipped: %s" % [e.complication])
	assert_false("cyberware_eb" in e.complication.skipped)
	assert_true(e.log.any(func(l): return String(l).contains("chromed up")), "the log says what it got")


func test_chrome_up_is_deterministic_affordable_and_played() -> void:
	var a := Fixtures.shooter("B")
	var got := Complication.chrome_up(a, 600)
	var b := Fixtures.shooter("B")
	assert_eq(Complication.chrome_up(b, 600), got, "the same boss, the same chrome")
	var spent := 0
	for p in a.implants:
		spent += int(Cyber.def(String(p.id)).cost)
		assert_true(Cyber.modelled(String(p.id)), "%s plays" % p.id)
	assert_true(spent <= 600 and spent >= 500, "600eb's worth: %d" % spent)
	assert_true("Anti-Dazzle" in got and a.cyber_working("anti_dazzle"), "meat eyes: two Cybereyes with Anti-Dazzle: %s" % [got])
	var k := _chromed(["neural_link"], Fixtures.shooter("K"))
	var kgot := Complication.chrome_up(k, 600)
	assert_eq(kgot[0], "Kerenzikov", "a Neural Link takes speedware first: %s" % [kgot])
	assert_eq(k.initiative_bonus(), 2)
	var s := _chromed(["neural_link", "sandevistan"], Fixtures.shooter("S"))
	assert_false("Kerenzikov" in Complication.chrome_up(s, 600), "only one speedware")
	var cheap := Complication.chrome_up(Fixtures.shooter("P"), 100)
	assert_eq(cheap, ["Nasal Filters"] as Array[String], "100eb buys what 100eb buys")


# --- On sale ----------------------------------------------------------------------------------------

func test_movement_and_net_chrome_is_on_sale_and_swimming_isnt() -> void:
	for id in ["grip_foot", "jump_booster", "skate_foot", "grapple_hand", "cyberleg", "interface_plugs", "enhanced_antibodies"]:
		assert_true(Cyber.modelled(id), id)
		assert_true(NightMarket.on_sale("cyberware/" + id), "%s on sale" % id)
		assert_false(Cyber.summary(id).contains("p."), "%s: no cites" % id)
	for id in ["web_foot"]:
		assert_false(NightMarket.on_sale("cyberware/" + id), "%s: nothing to play it on yet" % id)
	assert_true(NightMarket.on_sale("cyberware/cyberdeck"), "the arm's Cyberdeck plays now: +1 deck slot (Deck)")
