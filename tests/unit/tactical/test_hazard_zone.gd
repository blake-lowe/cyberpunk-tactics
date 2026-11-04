extends TestCase
## HazardZone: a shrinking safe circle as an encounter rule (the Combat Zone's MIST, setpieces.json
## rules.hazard_zone). It closes on schedule, bites units outside it at the end of their turn and
## spares the sides it names; any map can carry one (Encounter.setup opts.hazard_zone).

const SPEC := {"name": "MIST", "start": 3, "every": 3, "steps": 4, "final_r": 6, "dice": [1, 2, 3, 4], "spare": ["guard", "civilian", "trauma"]}


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


## An open square of the zone's area at least `d` squares from its centre (or within it, d < 0).
func _cell_at(m: TacMap, z: HazardZone, d: float) -> Vector3i:
	for y in range(z.area.position.y, z.area.end.y):
		for x in range(z.area.position.x, z.area.end.x):
			var dist := Vector2(x + 0.5, y + 0.5).distance_to(z.center)
			if m.walkable(m.street, Vector2i(x, y)) and ((d >= 0 and dist > d) or (d < 0 and dist < -d)):
				return Vector3i(x, y, m.street)
	return Vector3i(-1, -1, -1)


func test_the_schedule() -> void:
	var m := SceneGen.generate(7, "skirmish")
	var z := HazardZone.from_spec(SPEC, m, Dice.new(3))
	assert_eq(z.stage, 0, "not closing before round 3")
	assert_eq(z.closes_in(1), 2, "MIST CLOSES IN 2 on round 1")
	assert_false(z.tick(2), "nothing on round 2")
	assert_true(z.tick(3), "closes on round 3")
	assert_eq(z.stage, 1, "first close")
	assert_eq(z.closes_in(3), 3, "the next in 3 rounds")
	var r1 := z.radius()
	assert_false(z.tick(5), "nothing on round 5")
	assert_true(z.tick(6), "closes on round 6")
	assert_true(z.radius() < r1, "smaller each close")
	z.tick(40)
	assert_eq(z.stage, 4, "four closes and no more")
	assert_near(z.radius(), 6.0, 0.001, "down to the final circle")
	assert_eq(z.closes_in(40), -1, "as small as it gets")
	assert_eq(z.damage_dice(), 4, "4d6 at the last stage")
	assert_true(z.area.has_point(Vector2i(z.center)), "closes on a point inside its area")
	assert_true(z.radii[1] >= Vector2(z.area.size).length() / 2.0 * 0.6, "the first circle still takes in most of the area")


func test_outside_bites_inside_and_guards_dont() -> void:
	var m := SceneGen.generate(7, "skirmish")
	var dice := Dice.new(5)
	var e := Encounter.setup(m, dice, _crew(dice), "eliminate", {"hazard_zone": SPEC})
	assert_true(e.hazard != null, "the zone from the options")
	e.hazard.force_stage(1)
	var out := _cell_at(m, e.hazard, e.hazard.radius() + 1.0)
	var ins := _cell_at(m, e.hazard, -(e.hazard.radius() - 1.0))
	assert_true(out.x >= 0 and ins.x >= 0, "squares either side of the edge")
	var u: Dictionary = e.alive(Encounter.CREW)[0]
	u.pos = out
	var hp: int = u.c.hp
	e._hazard_harm(u)
	assert_between(hp - u.c.hp, 1, 6, "1d6 outside at the first close")
	assert_true(e.events.any(func(ev): return ev.type == "harm" and ev.source == "MIST"), "a harm event the view plays")
	u.pos = ins
	hp = u.c.hp
	e._hazard_harm(u)
	assert_eq(u.c.hp, hp, "safe inside the circle")
	var g: Dictionary = e.opfor()[0]
	g.pos = out
	hp = g.c.hp
	e._hazard_harm(g)
	assert_eq(g.c.hp, hp, "the owner's people are spared")
	e.hazard.force_stage(3)
	u.pos = out
	hp = u.c.hp
	e._hazard_harm(u)
	assert_between(hp - u.c.hp, 3, 18, "3d6 at the third close")


func test_it_closes_as_the_rounds_go() -> void:
	var m := SceneGen.generate(7, "skirmish")
	var dice := Dice.new(5)
	var e := Encounter.setup(m, dice, _crew(dice), "eliminate", {"hazard_zone": SPEC})
	e.next_turn()
	var guard := 0
	while e.state == "playing" and e.init.round_num < 7 and guard < 200:
		e.end_turn()
		e.next_turn()
		guard += 1
	assert_true(e.init.round_num >= 6, "reached round 6 (%d)" % e.init.round_num)
	assert_eq(e.hazard.stage, 2, "closed on rounds 3 and 6")
	assert_true(e.log.any(func(l): return l.begins_with("The MIST closes in")), "the log says so")


func test_no_zone_without_a_rule() -> void:
	var m := SceneGen.generate(7, "skirmish")
	var dice := Dice.new(5)
	var e := Encounter.setup(m, dice, _crew(dice), "eliminate")
	assert_true(e.hazard == null, "ordinary gigs have none")


func test_hud_line() -> void:
	var m := SceneGen.generate(7, "skirmish")
	var dice := Dice.new(5)
	var e := Encounter.setup(m, dice, _crew(dice), "eliminate", {"hazard_zone": SPEC})
	e.next_turn()
	assert_eq(Hud.hazard_text(e).get_slice(" · ", 0), "MIST CLOSES IN %d" % (3 - e.init.round_num), "the round tab counts down")
	e.hazard.force_stage(4)
	assert_true(Hud.hazard_text(e).begins_with("MIST · FINAL CIRCLE"), "then the final circle")
