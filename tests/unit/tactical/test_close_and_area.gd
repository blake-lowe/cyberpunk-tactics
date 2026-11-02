extends TestCase
## M5: melee, suppressive fire, shotgun shells, grenades, stabilisation, reload as encounter actions.


## An open 16x10 floor with the crew member at (2,5) and the given guards; guards are alerted.
func _arena(guard_cells: Array, crew_weapon := "assault_rifle", seed := 3) -> Encounter:
	var m := TacMap.new(16, 10, 1)
	for y in 10:
		for x in 16:
			m.set_t(0, x, y, TacMap.T.FLOOR)
	m.entrances.append({"floor": 0, "pos": Vector2i(2, 5), "kind": "deploy", "main": false, "cells": [Vector2i(2, 5)]})
	var dice := Dice.new(seed)
	var crew: Array[Combatant] = [Fixtures.shooter("A")]
	crew[0].weapons.append(Weapon.from_id(crew_weapon))
	crew[0].grenades = 2
	var e := Encounter.setup(m, dice, crew)
	e.units = e.units.filter(func(u): return u.team == 0)
	for cell in guard_cells:
		var g := Fixtures.unarmored("G%d" % e.units.size(), {"REF": 4})
		e._add(g, cell, 1)
		e.units[-1].alerted = true
	e.units[0].pos = Vector3i(2, 5, 0)
	e.cur = e.units[0]
	e.turn = TurnState.begin(dice, e.cur.c)
	return e


func test_melee_needs_a_neighbour_and_counts_diagonals() -> void:
	var e := _arena([Vector3i(3, 6, 0), Vector3i(6, 5, 0)])
	assert_true(e.adjacent(e.cur.pos, e.units[1].pos), "diagonal neighbour is in reach (house rule)")
	assert_false(e.melee(e.units[2]).get("ok", false), "two squares away is out of reach")
	var r := e.melee(e.units[1])
	assert_true(r.get("ok", false), "fists on a neighbour: %s" % r.get("reason", ""))
	assert_eq(e.events[-1].weapon, "brawling", "no melee weapon carried: brawling")


func test_suppressive_fire_pins_and_forces_cover() -> void:
	var e := _arena([Vector3i(8, 5, 0)])
	e.m.set_t(0, 9, 3, TacMap.T.WALL)   # somewhere to hide
	e.m.set_t(0, 9, 4, TacMap.T.WALL)
	e.los = Los.new(e.m)
	e.nav = Nav.new(e.m)
	var pinned := false
	for k in 12:   # a contest: repeat until it lands
		e.turn = TurnState.begin(e.dice, e.cur.c)
		e.cur.c.weapons[0].reload()
		var r := e.suppress(e.cur.c.weapons[0])
		assert_true(r.ok)
		if not r.suppressed.is_empty():
			pinned = true
			break
	assert_true(pinned, "suppression lands eventually")
	var g: Dictionary = e.units[1]
	assert_true(g.has("suppressed_by"))
	e.cur = g
	e.turn = TurnState.begin(e.dice, g.c)
	e._take_cover(g)
	assert_false(e.los.sight(e.units[0].pos, g.pos).visible, "the pinned guard ends out of the suppressor's sight")


func test_shotgun_shell_catches_the_cone_only() -> void:
	var e := _arena([Vector3i(4, 5, 0), Vector3i(4, 4, 0), Vector3i(1, 5, 0), Vector3i(8, 5, 0)], "shotgun")
	e.cur.c.skills["shoulder_arms"] = 10
	var sg: Weapon = e.cur.c.weapons[0]
	var r := {}
	for k in 8:
		e.turn = TurnState.begin(e.dice, e.cur.c)
		sg.reload()
		r = e.shotgun_shell(e.units[1], sg)
		if r.hit:
			break
	assert_true(r.hit)
	var ids: Array = r.hits.map(func(h): return h.id)
	assert_true(1 in ids and 2 in ids, "both targets in front within 6 m")
	assert_false(3 in ids, "the one behind isn't in the cone")
	assert_false(4 in ids, "beyond 6 m isn't caught")


func test_grenade_blast_hits_the_area_and_breaks_weak_cover() -> void:
	var e := _arena([Vector3i(9, 5, 0), Vector3i(10, 6, 0), Vector3i(14, 5, 0)])
	e.cur.c.skills["athletics"] = 12
	e.m.add_cover(Furnish.cover_entry("desk", 0, Vector2i(8, 6), -1))   # thin wood: any 6d6 breaks it
	e.los = Los.new(e.m)
	var r := e.throw_grenade(Vector3i(9, 5, 0))
	assert_true(r.ok)
	assert_eq(e.cur.c.grenades, 1)
	var ids: Array = r.hits.map(func(h): return h.id)
	if r.hit:
		assert_true(1 in ids and 2 in ids, "everyone within the 5x5 is caught")
		assert_false(3 in ids, "outside the 5x5 isn't")
		assert_true(e.events[-1].destroyed.has(Vector3i(8, 6, 0)), "the desk in the blast breaks")
	assert_between(float(r.damage), 6.0, 36.0, "6d6 rolled once")
	assert_false(e.throw_grenade(Vector3i(9, 5, 0)).get("ok", false), "one Action per turn")


func test_stabilize_a_mortally_wounded_ally() -> void:
	var e := _arena([])
	var ally := Fixtures.shooter("B")
	e._add(ally, Vector3i(3, 5, 0), 0)
	ally.hp = 0
	e.cur.c.skills["first_aid"] = 12
	var ok := false
	for k in 10:
		e.turn = TurnState.begin(e.dice, e.cur.c)
		var r := e.stabilize(e.units[1])
		assert_true(r.ok)
		if r.success:
			ok = true
			break
	assert_true(ok)
	assert_eq(ally.hp, 1, "stabilized at 1 HP (p223)")
	assert_true(ally.unconscious)


func test_reload_is_an_action_with_an_event() -> void:
	var e := _arena([])
	var w: Weapon = e.cur.c.weapons[0]
	w.ammo = 3
	assert_true(e.reload(w))
	assert_eq(w.ammo, w.mag())
	assert_eq(e.events[-1].type, "reload")
	assert_false(e.reload(w), "full magazine / no action left")


func test_ai_throws_at_a_cluster_and_punches_when_empty() -> void:
	var e := _arena([Vector3i(9, 5, 0)])
	var ally := Fixtures.shooter("B")
	e._add(ally, Vector3i(3, 5, 0), 0)
	var g: Dictionary = e.units[1]
	g.c.weapons.append(Weapon.from_id("heavy_pistol"))
	g.c.grenades = 1
	g.c.skills["athletics"] = 8
	e.cur = g
	e.turn = TurnState.begin(e.dice, g.c)
	AI.act(e, g)
	assert_eq(g.c.grenades, 0, "two crew in one blast: the guard throws")
	assert_true(e.events.any(func(x): return x.type == "blast"))
	# an empty gun next to an enemy: fists
	g.pos = Vector3i(4, 5, 0)
	g.c.weapons[0].ammo = 0
	g.c.grenades = 0
	e.turn = TurnState.begin(e.dice, g.c)
	e.events.clear()
	AI.act(e, g)
	assert_true(e.events.any(func(x): return x.type == "attack" and x.weapon == "brawling"), "empty gun, enemy in reach: fists, not a reload")
