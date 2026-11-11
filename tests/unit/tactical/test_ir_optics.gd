extends TestCase
## Thermal sight (owner rulings 2026-11-11): Low Light/Infrared/UV (CPR core p.360) beats darkness
## and smoke and sees through the fine-particulate weather (smog, ash, dust) but not heavy
## precipitation (Weather.optics_sight, per mood in data/gen/atmospheres.json); infrared cameras
## (Security.ir_camera, by the doctrine's `ir_cameras` and the building's security level) ignore
## darkness and smoke; the attack card and the device hover card say so.

const LLIR := ["cybereye", "cybereye", "low_light_infrared_uv", "low_light_infrared_uv"]
const CLEARS := ["smog", "ash", "dust"]                 ## fine particulates: thermal sees through
const BLURS := ["heavy_rain", "storm", "blood_rain"]    ## precipitation: the full penalty stays


## An open 30x10 street (no lights: dark everywhere), the crew member at (2,5), a guard at (14,5).
func _street(tile := TacMap.T.OUTSIDE) -> Encounter:
	var m := TacMap.new(30, 10, 1)
	for y in 10:
		for x in 30:
			m.set_t(0, x, y, tile)
	m.entrances.append({"floor": 0, "pos": Vector2i(2, 5), "kind": "deploy", "main": false, "cells": [Vector2i(2, 5)]})
	var dice := Dice.new(3)
	var crew: Array[Combatant] = [Fixtures.shooter("A")]
	crew[0].weapons.append(Weapon.from_id("heavy_pistol"))
	var e := Encounter.setup(m, dice, crew)
	e.units = e.units.filter(func(u): return u.team == 0)
	var g := Fixtures.shooter("G", {"REF": 4})
	g.weapons.append(Weapon.from_id("heavy_pistol"))
	e._add(g, Vector3i(14, 5, 0), 1)
	e.units[-1].alerted = true
	e.units[0].pos = Vector3i(2, 5, 0)
	e.cur = e.units[0]
	e.turn = TurnState.begin(dice, e.cur.c)
	return e


func _chrome(c: Combatant) -> void:
	for s in LLIR:
		c.install_cyberware(String(s))


func _camera(e: Encounter, at: Vector2i, ir: bool) -> Dictionary:
	e.m.devices.append({"id": e.m.devices.size(), "type": "camera", "pos": at, "floor": 0, "group": "cameras", "ir": ir})
	return e.m.devices[-1]


# --- Per-mood optics ------------------------------------------------------------------------------

func test_every_sighted_mood_says_what_thermal_optics_see_through() -> void:
	var moods: Dictionary = Atmosphere.data().moods
	for id in moods:
		var md: Dictionary = moods[id]
		if int(md.get("sight", 0)) > 0:
			assert_true(md.has("optics_sight"), "%s: declares optics_sight" % id)
	for id in CLEARS:
		assert_true(Weather.sight(id) > 0, id)
		assert_eq(Weather.optics_sight(id), 0, "%s: fine particulates, thermal sees through" % id)
		assert_true(Weather.optics_clear(id))
	for id in BLURS:
		assert_true(Weather.sight(id) > 0, id)
		assert_eq(Weather.optics_sight(id), Weather.sight(id), "%s: water scatters and absorbs IR: the full penalty" % id)
		assert_false(Weather.optics_clear(id))
	assert_eq(Weather.optics_sight("clear"), 0)
	assert_false(Weather.optics_clear("clear"), "nothing to see through")


func test_optics_spot_through_dark_smoke_and_dust_but_not_rain() -> void:
	var e := _street()
	var g: Dictionary = e.units[1]
	var a: Dictionary = e.cur
	e.smoke.add(e.m, e.los, Vector3i(8, 5, 0), 0)
	_chrome(g.c)
	for id in CLEARS:
		e.weather = id
		assert_eq(e.sight_penalty(g.c, g.pos, a.pos, true), 0, "%s, darkness and smoke: nothing" % id)
	for id in BLURS:
		e.weather = id
		assert_eq(e.sight_penalty(g.c, g.pos, a.pos, true), Weather.sight(id), "%s: only the rain's penalty, not the dark or the smoke" % id)
		var plain := Fixtures.shooter("P")
		assert_eq(e.sight_penalty(plain, g.pos, a.pos, true), 4 + Weather.sight(id), "%s: bare eyes take both" % id)


func test_the_attack_card_says_what_the_optics_ignore() -> void:
	var e := _street()
	var g: Dictionary = e.units[1]
	var w: Weapon = e.cur.c.weapons[0]
	_chrome(e.cur.c)
	e.weather = "heavy_rain"
	var dry := e.preview(g, w, Attack.Mode.SINGLE)
	assert_eq(int(dry.weather), -Weather.sight("heavy_rain"), "heavy rain still costs the shot")
	assert_false(dry.sees_through, "no smoke, and the rain isn't seen through: no optics line")
	e.smoke.add(e.m, e.los, Vector3i(8, 5, 0), 0)
	var p := e.preview(g, w, Attack.Mode.SINGLE)
	assert_eq(int(p.obscured), 0)
	assert_eq(int(p.weather), -Weather.sight("heavy_rain"))
	assert_true(p.sees_smoke and not p.sees_weather)
	assert_eq(Hud.optics_line(p, e.weather), "Thermal optics: ignore smoke")
	e.weather = "dust"
	var q := e.preview(g, w, Attack.Mode.SINGLE)
	assert_eq(int(q.weather), 0, "dust is nothing to thermal")
	assert_true(q.sees_smoke and q.sees_weather)
	assert_eq(Hud.optics_line(q, e.weather), "Thermal optics: ignore smoke and the dust storm")
	assert_false(Hud.optics_line(q, e.weather).contains("p."), "no page cites in player text")


# --- Infrared cameras -----------------------------------------------------------------------------

func test_an_ir_camera_ignores_darkness_and_smoke() -> void:
	var e := _street(TacMap.T.FLOOR)
	var plain := _camera(e, Vector2i(4, 5), false)
	var ir := _camera(e, Vector2i(4, 6), true)
	var v := Vector3i(7, 5, 0)
	assert_false(e.lit.has(v), "the arena has no lights")
	assert_eq(e.camera_penalty(plain, v), Encounter.DARK_PENALTY, "a plain camera in the dark: -4")
	assert_eq(e.camera_penalty(ir, v), 0, "infrared: sees the heat")
	e.lit[v] = true
	assert_eq(e.camera_penalty(plain, v), 0, "lit: fine")
	e.smoke.add(e.m, e.los, Vector3i(6, 5, 0), 0)
	assert_eq(e.camera_penalty(plain, v), Encounter.DARK_PENALTY, "smoke on the line: -4")
	assert_eq(e.camera_penalty(ir, v), 0, "infrared sees through smoke")


func test_an_ir_camera_catches_a_sneak_in_the_dark_more_often() -> void:
	var caught := {false: 0, true: 0}
	for ir in [false, true]:
		var e := _street(TacMap.T.FLOOR)
		e.units = e.units.filter(func(u): return u.team == 0)
		var g := Fixtures.shooter("G")
		e._add(g, Vector3i(25, 2, 0), 1)   # someone to send
		var d := _camera(e, Vector2i(4, 5), ir)
		var crew: Dictionary = e.units[0]
		crew.pos = Vector3i(7, 5, 0)
		crew.c.skills["stealth"] = 4
		for k in 200:
			e._spot_rolls.clear()
			e.units[1].alerted = false
			if not e._camera_spots().is_empty():
				caught[ir] += 1
		assert_true(e.camera_sees(d, crew.pos), "in view")
	assert_true(int(caught[true]) > int(caught[false]) + 30, "IR in the dark: %d vs %d" % [caught[true], caught[false]])


func test_ir_cameras_by_security_level_are_deterministic() -> void:
	var d := Security.doctrine("default")
	var count := func(doc: Dictionary, sec: int) -> int:
		var n := 0
		for i in 400:
			if Security.ir_camera(doc, 11, i, sec):
				n += 1
		return n
	assert_eq(count.call(d, 1), 0, "security 1: none")
	var two: int = count.call(d, 2)
	assert_true(two > 140 and two < 260, "security 2: about half (%d / 400)" % two)
	var three: int = count.call(d, 3)
	assert_true(three > 300 and three > two, "security 3: most (%d / 400)" % three)
	assert_eq(count.call(Security.doctrine("corp_military"), 3), 400, "Militech: every one")
	assert_true(count.call(Security.doctrine("gang_den"), 3) < three, "a gang: fewer")
	for i in 50:
		assert_eq(Security.ir_camera(d, 11, i, 2), Security.ir_camera(d, 11, i, 2), "same seed, same camera")
	var differs := false
	for i in 50:
		differs = differs or Security.ir_camera(d, 11, i, 2) != Security.ir_camera(d, 12, i, 2)
	assert_true(differs, "another map, another mix")


func test_a_generated_gig_marks_its_ir_cameras_the_same_every_time() -> void:
	var marks := func(sec: int) -> Array:
		var m := SceneGen.generate(11, "lone_building", {"security": sec, "site": "corp_office"})
		var dice := Dice.new(7)
		var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex")]
		var e := Encounter.setup(m, dice, crew)
		return e.m.devices.filter(func(x): return String(x.type) == "camera").map(func(x): return [int(x.id), bool(x.ir)])
	var a: Array = marks.call(3)
	assert_false(a.is_empty(), "the office has cameras")
	assert_eq(marks.call(3), a, "seeded: a reload agrees")
	assert_true(a.any(func(x): return x[1]), "security 3: some are infrared")
	var low: Array = marks.call(1)
	assert_true(low.all(func(x): return not x[1]), "security 1: none")


func test_the_hover_card_says_infrared() -> void:
	assert_eq(Hud.device_note({"type": "camera", "ir": true}), "Infrared: sees in the dark and through smoke")
	assert_eq(Hud.device_note({"type": "camera", "ir": false}), "")
	assert_eq(Hud.device_note({"type": "camera"}), "")
	assert_eq(Hud.device_note({"type": "turret", "ir": true}), "", "cameras only")


func test_the_view_rings_an_ir_cameras_lens() -> void:
	var e := _street(TacMap.T.FLOOR)
	_camera(e, Vector2i(4, 0), false)
	_camera(e, Vector2i(8, 0), true)
	var dv := DeviceView.new()
	dv.build(e.m, func(_v: Vector3i) -> float: return 0.0)
	var rings := 0
	for root in dv.get_children():
		if root.find_child("ir_ring", false, false) != null:
			rings += 1
	assert_eq(rings, 1, "only the infrared one")
	dv.free()


func test_looping_an_ir_camera_still_blinds_it() -> void:
	var e := _street(TacMap.T.FLOOR)
	var d := _camera(e, Vector2i(4, 5), true)
	e.units[0].pos = Vector3i(7, 5, 0)
	e.units[0].c.skills["stealth"] = 0
	e.disabled_devices[int(d.id)] = true   # looped, held or killed: off for the site
	for k in 30:
		e._spot_rolls.clear()
		assert_true(e._camera_spots().is_empty(), "a looped IR camera sees nothing")
