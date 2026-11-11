extends TestCase
## Cyberware phase 2, senses and hazards (CPR core p.359-363): smoke grenades' clouds (p.347), Low
## Light/Infrared/UV against darkness, smoke and the weather, Image Enhance and Amplified Hearing,
## Anti-Dazzle, Level Damper, Nasal Filters and the Independent Air Supply against flashbangs, the
## Shrieker and gas grenades, the Radar/Sonar Implant and the Tactile Boost revealing units, guards
## using their chrome, the AI's smoke, and what's now on sale.


## An open 30x10 floor (no lights: dark everywhere), the crew member at (2,5), guards at `guard_cells`.
func _arena(guard_cells: Array, tile := TacMap.T.FLOOR, seed := 3) -> Encounter:
	var m := TacMap.new(30, 10, 1)
	for y in 10:
		for x in 30:
			m.set_t(0, x, y, tile)
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


func _chromed(specs: Array, c: Combatant) -> Combatant:
	for s in specs:
		c.install_cyberware(String(s))
	return c


const LLIR := ["cybereye", "cybereye", "low_light_infrared_uv", "low_light_infrared_uv"]


## Someone sure to fail any Resist Torture/Drugs Check (WILL far below any roll).
func _weak(name := "W") -> Combatant:
	return Fixtures.unarmored(name, {"WILL": -40})


# --- Smoke (p.347) ---------------------------------------------------------------------------------

func test_a_smoke_cloud_is_ten_metres_square_and_walls_stop_it() -> void:
	var e := _arena([])
	var c := e.smoke.add(e.m, e.los, Vector3i(10, 5, 0), 0)
	assert_eq((c.cells as Dictionary).size(), 25, "10 x 10 m: 5x5 squares of 2 m")
	assert_true(e.smoke.covers(Vector3i(8, 3, 0)) and e.smoke.covers(Vector3i(12, 7, 0)), "corner to corner")
	assert_false(e.smoke.covers(Vector3i(13, 5, 0)), "no further")
	for y in 10:   # a wall down x = 11: the smoke doesn't pass it
		e.m.set_t(0, 11, y, TacMap.T.WALL)
	var c2 := e.smoke.add(e.m, e.los, Vector3i(20, 5, 0), 0)
	assert_eq((c2.cells as Dictionary).size(), 25)
	var w := e.smoke.add(e.m, e.los, Vector3i(10, 5, 0), 0)
	assert_eq((w.cells as Dictionary).size(), 15, "three columns this side of the wall (x 8-10)")
	assert_false((w.cells as Dictionary).has(Vector3i(12, 5, 0)), "nothing beyond the wall")


func test_smoke_lasts_a_minute() -> void:
	var e := _arena([])
	e.init.round_num = 3
	e.smoke.add(e.m, e.los, Vector3i(10, 5, 0), 3)
	for r in range(4, 23):
		e.init.round_num = r
		e._round_senses()
		assert_true(e.smoke.covers(Vector3i(10, 5, 0)), "still there in Round %d" % r)
	e.init.round_num = 23
	e._round_senses()
	assert_false(e.smoke.covers(Vector3i(10, 5, 0)), "20 Rounds of 3 s: gone at the start of Round 23")
	assert_true(e.events.any(func(ev): return String(ev.type) == "smoke_clear"), "the view hears it clear")


func test_smoke_obscures_but_doesnt_block_sight() -> void:
	var e := _arena([Vector3i(20, 5, 0)])
	var g: Dictionary = e.units[1]
	assert_eq(e.obscured_mod(e.cur.c, e.cur.pos, g.pos), 0, "clear air")
	e.smoke.add(e.m, e.los, Vector3i(10, 5, 0), 0)
	assert_true(e.los.trace(e.cur.pos, g.pos).clear, "smoke isn't cover: the line is still there")
	assert_true(e.smoke.on_line(e.cur.pos, g.pos), "it's on the line")
	assert_false(e.smoke.on_line(Vector3i(2, 0, 0), Vector3i(20, 0, 0)), "a line round it isn't")
	assert_eq(e.obscured_mod(e.cur.c, e.cur.pos, g.pos), -4, "-4 to attack through it (p.347)")
	var w: Weapon = e.cur.c.weapons[0]
	var p := e.preview(g, w, Attack.Mode.SINGLE)
	assert_true(p.ok)
	assert_eq(int(p.obscured), -4)
	var clear := e.preview(g, w, Attack.Mode.SINGLE)
	e.smoke = Smoke.new()
	clear = e.preview(g, w, Attack.Mode.SINGLE)
	assert_eq(int(p.base), int(clear.base) - 4, "the -4 is in the attack's base")
	assert_true(float(p.chance) < float(clear.chance))


func test_smoke_and_darkness_are_one_minus_four() -> void:
	var e := _arena([Vector3i(8, 5, 0)])
	var g: Dictionary = e.units[1]
	var a: Dictionary = e.cur
	assert_false(e.lit.has(a.pos), "the arena has no lights")
	var dark := e.spot_base(g, a)
	e.lit[a.pos] = true
	var lit := e.spot_base(g, a)
	assert_eq(lit - dark, 4, "darkness: -4 (p.130-131)")
	e.smoke.add(e.m, e.los, Vector3i(5, 5, 0), 0)
	assert_eq(e.spot_base(g, a), dark, "lit but in smoke: the same -4")
	e.lit.erase(a.pos)
	assert_eq(e.spot_base(g, a), dark, "dark and smoke: still -4, one modifier (obscured)")


func test_a_smoke_grenade_leaves_a_cloud_and_hurts_nobody() -> void:
	var e := _arena([Vector3i(8, 5, 0), Vector3i(9, 6, 0)])
	e.cur.c.kit[0] = "ammo/smoke_ammo"
	var hp: int = e.units[1].c.hp
	var r := e.throw_grenade(Vector3i(8, 5, 0))
	assert_true(r.ok)
	assert_eq((r.hits as Array).size(), 0, "nobody caught: no check, no damage")
	assert_eq(int(e.units[1].c.hp), hp)
	assert_eq(e.smoke.clouds.size(), 1)
	assert_true(e.smoke.covers(r.center), "where it landed")
	var ev: Dictionary = e.events.filter(func(x): return String(x.type) == "blast")[0]
	assert_eq(int(ev.smoke), int(e.smoke.clouds[0].id), "the view knows which cloud")
	assert_true(e.log[-1].contains("smoke"), e.log[-1])


# --- Low Light / Infrared / UV (p.360) --------------------------------------------------------------

func test_low_light_ignores_darkness_smoke_and_weather() -> void:
	var e := _arena([Vector3i(14, 5, 0)], TacMap.T.OUTSIDE)
	var g: Dictionary = e.units[1]
	var a: Dictionary = e.cur
	e.weather = "smog"
	assert_true(Weather.sight("smog") > 0, "smog takes sight off (NCW p.5)")
	e.smoke.add(e.m, e.los, Vector3i(8, 5, 0), 0)
	assert_eq(e.sight_penalty(g.c, g.pos, a.pos, true), 4 + Weather.sight("smog"), "dark or smoke -4, and the smog")
	_chromed(["cybereye", "cybereye", "low_light_infrared_uv"], g.c)
	assert_false(g.c.sees_through_obscurement(), "one eye only: a paired option needs both")
	_chromed(["low_light_infrared_uv"], g.c)
	assert_true(g.c.sees_through_obscurement())
	assert_eq(e.sight_penalty(g.c, g.pos, a.pos, true), 0, "darkness, smoke and fog: 0")
	var before := e.spot_base(g, a)
	g.c.cyber_off[Cyber.key(g.c.implant("low_light_infrared_uv", "left_eye"))] = 3
	assert_eq(e.spot_base(g, a), before - 4 - Weather.sight("smog"), "knocked out: back to the penalties")


func test_low_light_shoots_through_smoke_and_weather() -> void:
	var e := _arena([Vector3i(14, 5, 0)], TacMap.T.OUTSIDE)
	var g: Dictionary = e.units[1]
	var w: Weapon = e.cur.c.weapons[0]
	e.weather = "heavy_rain"
	e.smoke.add(e.m, e.los, Vector3i(8, 5, 0), 0)
	var p := e.preview(g, w, Attack.Mode.SINGLE)
	assert_eq(int(p.obscured), -4)
	assert_eq(int(p.weather), -Weather.sight("heavy_rain"), "a shot past 6 m in heavy rain")
	_chromed(LLIR, e.cur.c)
	var q := e.preview(g, w, Attack.Mode.SINGLE)
	assert_eq(int(q.obscured), 0)
	assert_eq(int(q.weather), 0)
	assert_true(q.sees_through, "the card says why")
	assert_eq(int(q.base), int(p.base) + 4 + Weather.sight("heavy_rain"))


# --- Image Enhance (p.360) and Amplified Hearing (p.361) ------------------------------------------

func test_image_enhance_and_amplified_hearing_add_two_each() -> void:
	var c := Fixtures.shooter("C")
	assert_eq(c.perception_bonus(true, true), 0)
	_chromed(["cybereye", "cybereye", "image_enhance"], c)
	assert_eq(c.perception_bonus(true, false), 0, "paired: one eye does nothing")
	_chromed(["image_enhance"], c)
	assert_eq(c.perception_bonus(true, false), 2, "+2 when the Check includes sight")
	assert_eq(c.perception_bonus(false, true), 0, "not for hearing alone")
	_chromed(["cyberaudio_suite", "amplified_hearing"], c)
	assert_eq(c.perception_bonus(false, true), 2, "+2 when it includes hearing")
	assert_eq(c.perception_bonus(true, true), 4, "two pieces, both senses: both")


func test_a_guard_spotting_takes_the_perception_chrome() -> void:
	var e := _arena([Vector3i(8, 5, 0)])
	var g: Dictionary = e.units[1]
	var base := e.spot_base(g, e.cur)
	_chromed(["cybereye", "cybereye", "image_enhance", "image_enhance", "cyberaudio_suite", "amplified_hearing"], g.c)
	assert_eq(e.spot_base(g, e.cur), base + 4, "spotting a sneaker is sight and hearing")


# --- Hazard immunities ---------------------------------------------------------------------------

func _flash(c: Combatant, seed := 1) -> Dictionary:
	var fx := Items.fx("ammo/flashbang_ammo")
	var r := {}
	Attack.apply_status(Dice.new(seed), c, fx.status, fx, r)
	return r


func test_a_flashbang_blinds_and_deafens() -> void:
	var c := _weak()
	var r := _flash(c)
	assert_false(r.status.resisted)
	assert_true(c.has_injury("damaged_eye") and c.has_injury("damaged_ear"), "Damaged Eye and Damaged Ear (p.346)")


func test_anti_dazzle_stops_the_flash_and_a_level_damper_the_bang() -> void:
	var a := _chromed(["cybereye", "cybereye", "anti_dazzle", "anti_dazzle"], _weak("A"))
	_flash(a)
	assert_false(a.has_injury("damaged_eye"), "immune to dangerous flashes (p.360)")
	assert_true(a.has_injury("damaged_ear"), "the bang still deafens")
	var d := _chromed(["cyberaudio_suite", "level_damper"], _weak("D"))
	_flash(d)
	assert_true(d.has_injury("damaged_eye"))
	assert_false(d.has_injury("damaged_ear"), "immune to dangerously loud noises (p.361)")
	var both := _chromed(["cybereye", "cybereye", "anti_dazzle", "anti_dazzle", "cyberaudio_suite", "level_damper"], _weak("B"))
	var r := _flash(both)
	assert_true(r.status.get("immune", false), "both: no check at all")
	assert_true(both.injuries.is_empty())
	var ear := _weak("E")
	ear.kit[1] = "gear/ear_protectors"
	_flash(ear)
	assert_false(ear.has_injury("damaged_ear"), "carried ear protectors do the same (p.352)")


func test_a_level_damper_shrugs_off_the_shrieker_both_ends() -> void:
	var w := Weapon.from_id("shrieker")
	var t := _chromed(["cyberaudio_suite", "level_damper"], _weak("T"))
	var r := {}
	Attack.apply_status(Dice.new(2), t, w.fx().status, w.fx(), r)
	assert_true(r.status.get("immune", false), "a Shrieker hit is a loud noise")
	assert_false(t.has_injury("damaged_ear"))
	var plain := _weak("P")
	Attack.apply_status(Dice.new(2), plain, w.fx().status, w.fx(), {})
	assert_true(plain.has_injury("damaged_ear"))
	var shooter := Fixtures.shooter("S")
	shooter.kit[1] = "gear/ear_protectors"
	var sr := {}
	Attack._self_effects(shooter, w, sr)
	assert_false(sr.has("self_hurt"), "firing it with ear protection is safe (p.349)")
	var bare := Fixtures.shooter("B")
	var br := {}
	Attack._self_effects(bare, w, br)
	assert_eq(String(br.get("self_hurt", "")), "damaged_ear")


func test_gas_grenades_poison_unless_the_air_is_filtered() -> void:
	for key in ["ammo/poison_ammo", "ammo/biotoxin_ammo"]:
		var e := _arena([Vector3i(8, 5, 0), Vector3i(9, 5, 0), Vector3i(8, 6, 0), Vector3i(9, 6, 0)])
		var plain: Combatant = e.units[1].c
		var nasal: Combatant = _chromed(["nasal_filters"], e.units[2].c)
		var tank: Combatant = _chromed(["independent_air_supply"], e.units[3].c)
		var mask: Combatant = e.units[4].c
		mask.kit[1] = "gear/anti_smog_mask"
		for c: Combatant in [plain, nasal, tank, mask]:
			c.stats["WILL"] = -40
			c.stats["REF"] = 4   # nobody dives clear
		var hp := {}
		for u in e.units:
			hp[u.id] = u.c.hp
		e.cur.c.kit[0] = key
		e.cur.c.skills["athletics"] = 20   # on target
		var r := e.throw_grenade(Vector3i(8, 5, 0))
		assert_true(r.ok and r.hit, key)
		assert_true(plain.hp < int(hp[1]), "%s: breathed in, straight to HP (p.345-346)" % key)
		for i in [2, 3, 4]:
			assert_eq(e.units[i].c.hp, int(hp[i]), "%s: %s filters it out" % [key, e.units[i].c.display_name])
		var h2: Dictionary = (r.hits as Array).filter(func(h): return int(h.id) == 2)[0]
		assert_true(h2.status.get("immune", false), "Nasal Filters: immune (p.363)")
		assert_eq(int(plain.sp("body")), plain.armor["body"].sp if plain.armor["body"] else 0, "armor untouched")


func test_teargas_needs_meat_eyes_not_lungs() -> void:
	var fx := Items.fx("ammo/teargas_ammo")
	var nasal := _chromed(["nasal_filters"], _weak("N"))
	Attack.apply_status(Dice.new(4), nasal, fx.status, fx, {})
	assert_true(nasal.has_injury("damaged_eye"), "teargas works on meat eyes (p.347): Nasal Filters don't help")
	var eyes := _chromed(["cybereye", "cybereye"], _weak("E"))
	var r := {}
	Attack.apply_status(Dice.new(4), eyes, fx.status, fx, r)
	assert_true(r.status.get("immune", false), "two Cybereyes do")


func test_a_turret_cant_be_poisoned() -> void:
	var fx := Items.fx("ammo/poison_ammo")
	var t := Turret.make(1)
	var r := {}
	Attack.apply_status(Dice.new(5), t, fx.status, fx, r)
	assert_true(r.status.get("immune", false), "meat only (p.346)")


# --- Radar / Sonar (p.363) and Tactile Boost (p.359) -----------------------------------------------

func test_radar_reveals_anyone_within_fifty_metres_not_behind_cover() -> void:
	var e := _arena([Vector3i(25, 5, 0), Vector3i(27, 2, 0), Vector3i(25, 8, 0)])
	e.units = e.units.filter(func(u): return u.id <= 2)   # keep one beyond 50 m out: (27,2) is 25.2 squares
	e.refresh_vision()
	assert_false(e.vision.visible.has(Vector3i(25, 5, 0)), "23 squares (46 m): past the crew's sight")
	assert_true(e.reveals.is_empty(), "no chrome, no blips")
	_chromed(["radar_sonar_implant"], e.cur.c)
	e.refresh_vision()
	assert_eq(String(e.reveals.get(1, "")), "radar", "46 m, nothing between")
	assert_false(e.reveals.has(2), "beyond 50 m")
	e.los.cover_hp[Vector3i(20, 5, 0)] = 20
	e.refresh_vision()
	assert_false(e.reveals.has(1), "behind cover the scan doesn't reach")
	e.los.cover_hp.erase(Vector3i(20, 5, 0))
	e.smoke.add(e.m, e.los, Vector3i(22, 5, 0), 0)
	e.refresh_vision()
	assert_true(e.reveals.has(1), "smoke and darkness don't stop radar")
	assert_true(e.log.any(func(l): return l.contains("radar beeps")), "a new mover beeps with a direction")


func test_tactile_boost_feels_movement_through_walls_with_a_hand_down() -> void:
	var e := _arena([Vector3i(10, 5, 0)])
	for y in 10:
		e.m.set_t(0, 6, y, TacMap.T.WALL)   # a wall between: out of sight
	var c: Combatant = _chromed(["neural_link", "chipware_socket", "tactile_boost"], e.cur.c)
	var g: Dictionary = e.units[1]
	e.init.round_num = 1
	e._round_senses()
	e.init.round_num = 2
	e._round_senses()   # nobody moved during Round 1
	e.refresh_vision()
	assert_false(e.vision.visible.has(g.pos))
	assert_true(e.reveals.is_empty(), "the hand isn't down")
	var opt: Array = e.chrome_options().filter(func(o): return String(o.id) == "tactile_boost")
	assert_eq(String(opt[0].cost), "FREE")
	assert_true(e.use_chrome("tactile_boost").ok)
	assert_true(c.touching)
	assert_true(e.reveals.is_empty(), "standing still: nothing to feel")
	g.pos = Vector3i(11, 5, 0)   # the guard walks
	e.refresh_vision()
	assert_eq(String(e.reveals.get(1, "")), "motion", "16-18 m, through the wall")
	g.pos = Vector3i(20, 5, 0)
	e.refresh_vision()
	assert_false(e.reveals.has(1), "36 m: beyond 20 m")


func test_the_tactile_hand_is_busy_and_walking_lifts_it() -> void:
	var e := _arena([Vector3i(10, 5, 0)])
	var c: Combatant = _chromed(["neural_link", "chipware_socket", "tactile_boost"], e.cur.c)
	c.weapons.insert(0, Weapon.from_id("assault_rifle"))
	e.use_chrome("tactile_boost")
	var p := e.preview(e.units[1], c.weapons[0], Attack.Mode.SINGLE)
	assert_false(p.ok, "a two-handed gun needs the hand (p.359)")
	var q := e.preview(e.units[1], c.weapons[1], Attack.Mode.SINGLE)
	assert_true(q.ok, "a pistol in the other hand is fine")
	assert_true(e.move_to(Vector3i(3, 5, 0)))
	assert_false(c.touching, "walking lifts the hand")


# --- Guards with chrome (NPC blocks) ----------------------------------------------------------------

func test_a_low_light_guard_sees_the_crew_in_dark_and_smoke() -> void:
	var e := _arena([Vector3i(8, 5, 0), Vector3i(8, 6, 0)])
	var plain: Dictionary = e.units[1]
	var owl: Dictionary = e.units[2]
	_chromed(LLIR, owl.c)
	e.smoke.add(e.m, e.los, Vector3i(5, 5, 0), 0)
	assert_eq(e.spot_base(owl, e.cur) - e.spot_base(plain, e.cur), 4, "no penalty for the guard with night eyes")
	e.cur = owl
	var p := e.preview(e.units[0], owl.c.weapons[0], Attack.Mode.SINGLE)
	assert_eq(int(p.obscured), 0, "and it shoots through the smoke unhindered")


func test_npc_blocks_with_anti_dazzle_shrug_off_flashbangs() -> void:
	var pyro: Dictionary = RulesDB.load_json("npcs.json")["blocks"]["pyro"]
	var c := Fixtures.unarmored("Pyro", {"WILL": -40})
	for id in Cyber.foundations_first(pyro.cyberware):   # the Pyro's printed chrome
		c.install_cyberware(id, null, true)
	var r := _flash(c)
	assert_true(r.status.get("immune", false), "flash and bang both stopped")
	assert_true(c.immune_to("inhaled"), "and Nasal Filters")


# --- The AI and smoke -------------------------------------------------------------------------------

func test_a_pinned_guard_throws_smoke_and_the_ai_respects_it() -> void:
	var e := _arena([Vector3i(12, 5, 0)])
	var g: Dictionary = e.units[1]
	for i in 2:   # a second and third crew member: three guns on the guard, all in the open
		var x := Fixtures.shooter("X%d" % i)
		x.weapons.append(Weapon.from_id("heavy_pistol"))
		e._add(x, Vector3i(2, 3 + i * 4, 0), 0)
	g.c.kit[0] = "ammo/smoke_ammo"
	g.c.weapons[0] = Weapon.from_id("medium_pistol")
	g.c.skills["handgun"] = 0   # a hopeless shot at this range
	e.cur = g
	e.turn = TurnState.begin(e.dice, g.c)
	AI.act(e, g)
	assert_eq(e.smoke.clouds.size(), 1, "pinned with no good shot: smoke")
	assert_true(g.c.kit_spent[0])
	assert_true(e.smoke.covers(g.pos) or e.smoke.on_line(e.units[0].pos, g.pos), "between them and the guns")


func _flash_ai(immune: bool) -> Dictionary:
	var e := _arena([Vector3i(9, 5, 0)])
	var g: Dictionary = e.units[1]
	var chrome := ["cybereye", "cybereye", "anti_dazzle", "anti_dazzle", "cyberaudio_suite", "level_damper"] if immune else []
	for i in 2:
		var x := _chromed(chrome, Fixtures.shooter("X%d" % i))
		e._add(x, Vector3i(2, 4 + i * 2, 0), 0)
	_chromed(chrome, e.units[0].c)
	g.c.kit[0] = "ammo/flashbang_ammo"
	g.c.skills["handgun"] = 0
	e.cur = g
	e.turn = TurnState.begin(e.dice, g.c)
	AI.act(e, g)
	return g


func test_the_ai_doesnt_waste_a_flashbang_on_the_immune() -> void:
	assert_true(_flash_ai(false).c.kit_spent[0], "three in the blast, no good shot: the flashbang goes")
	assert_false(_flash_ai(true).c.kit_spent[0], "everyone it would hit is immune: keep it")


# --- On sale -----------------------------------------------------------------------------------------

func test_the_new_gear_is_on_sale() -> void:
	for key in ["ammo/smoke_ammo", "ammo/poison_ammo", "ammo/biotoxin_ammo", "gear/anti_smog_mask", "gear/ear_protectors"]:
		assert_true(key in Items.all(), "%s is kit" % key)
		assert_true(NightMarket.on_sale(key), "%s on sale" % key)
		if Items.use(key) == "grenade":
			assert_true(Items.short_name(key).length() <= 8, key)
	assert_eq(Items.use("ammo/smoke_ammo"), "grenade")
	assert_eq(Items.use("gear/anti_smog_mask"), "carried")
	assert_true(Items.fits(1, "gear/ear_protectors"), "a utility")
	for id in ["low_light_infrared_uv", "image_enhance", "amplified_hearing", "anti_dazzle", "level_damper", "nasal_filters",
			"independent_air_supply", "radar_sonar_implant", "tactile_boost", "cyberaudio_suite"]:
		assert_true(NightMarket.on_sale("cyberware/" + id), "%s on sale" % id)


func test_the_inspector_says_what_the_senses_do() -> void:
	var c := Fixtures.shooter("C")
	assert_eq(Hud.senses_text(c), "")
	_chromed(LLIR + ["image_enhance", "image_enhance", "nasal_filters", "radar_sonar_implant"], c)
	var s := Hud.senses_text(c)
	for w in ["sees through dark and smoke", "+2 Perception", "gas-proof", "radar 50 m"]:
		assert_true(s.contains(w), "%s in %s" % [w, s])
