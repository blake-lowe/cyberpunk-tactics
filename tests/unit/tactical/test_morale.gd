extends TestCase
## Morale (Single Player Mode p.20-21, table p.32): NPCs break at stress points and flee or hide
## (HOUSE-RULE, owner: nobody surrenders).


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func _enc(kind := "data", seed_value := 11) -> Encounter:
	var m := SceneGen.generate(seed_value, "lone_building", {"security": 2, "site": "corp_office"})
	var dice := Dice.new(7)
	var e := Encounter.setup(m, dice, _crew(dice), kind)
	e.reinforcements = false
	return e


func _guards(e: Encounter) -> Array:
	return e.units.filter(func(u): return int(u.team) == Encounter.OPFOR and not u.get("vip", false) and not u.c.dead)


## A free square next to `at` with a clear line between them, on its floor.
func _beside(e: Encounter, at: Vector3i) -> Vector3i:
	var occ := e.occupied()
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(1, 1, 0), Vector3i(-1, -1, 0)]:
		var v: Vector3i = at + d
		if e.m.inb(v.x, v.y) and e.m.walkable(v.z, Vector2i(v.x, v.y)) and not occ.has(v) and e.los.trace(at, v).clear:
			return v
	return Vector3i(-1, -1, -1)


func _first_hardened_mook() -> String:
	var blocks: Dictionary = RulesDB.load_json("npcs.json")["blocks"]
	for id in blocks:
		if String(blocks[id].tier) == "mook" and bool(blocks[id].get("hardened", false)) and not bool(blocks[id].get("civilian", false)):
			return String(id)
	return ""


func _first_plain_mook() -> String:
	var blocks: Dictionary = RulesDB.load_json("npcs.json")["blocks"]
	for id in blocks:
		if String(blocks[id].tier) == "mook" and not bool(blocks[id].get("hardened", false)) and not bool(blocks[id].get("civilian", false)):
			return String(id)
	return ""


func test_thresholds_follow_the_book_by_tier() -> void:
	var e := _enc()
	var u: Dictionary = _guards(e)[0]
	u.c.role = "mook"
	u.c.block = _first_plain_mook()
	assert_eq(Morale.threshold(e, u), 9, "Mook: unsure streetrat, 1-9 ends the fight")
	u.c.block = _first_hardened_mook()
	assert_eq(Morale.threshold(e, u), 8, "Hardened Mook: inexperienced, 1-8")
	u.c.role = "lieutenant"
	assert_eq(Morale.threshold(e, u), 6, "Lieutenant: trained, 1-6")
	u.c.role = "mini_boss"
	assert_eq(Morale.threshold(e, u), 4, "Mini-Boss: experienced, 1-4")
	u.c.role = "boss"
	assert_eq(Morale.threshold(e, u), 2, "a Boss's last stand: fully committed")


func test_committed_units_use_two() -> void:
	var e := _enc()
	var u: Dictionary = _guards(e)[0]
	u.c.role = "mook"
	u.c.block = _first_plain_mook()
	u.c.drugs_taken.append("synthcoke")   # a complication's `drug` fx (Complication.dose)
	assert_eq(Morale.threshold(e, u), 2, "a ganger on combat drugs")
	u.c.drugs_taken.clear()
	u.c.block = "cyberpsycho"
	assert_eq(Morale.threshold(e, u), 2, "a raging cyberpsycho")
	u.c.block = _first_plain_mook()
	var mt := e.add_side("maxtac", "guard", true)
	u.team = mt
	assert_eq(Morale.threshold(e, u), 2, "MaxTac is committed (owner)")


func test_seriously_wounded_is_a_stress_point_rolled_once() -> void:
	var e := _enc()
	var u: Dictionary = _guards(e)[0]
	u.alerted = true
	assert_eq(Morale.pending(e, u), [] as Array[String], "unhurt: nothing to roll")
	u.c.hp = u.c.seriously_wounded_threshold() - 1
	assert_eq(Morale.pending(e, u), ["wounded"] as Array[String])
	Morale.sweep(e)
	assert_true(u.get("morale_rolls", {}).has("wounded"), "rolled at the stress point")
	var st := e.dice.rng.state
	Morale.sweep(e)
	assert_eq(e.dice.rng.state, st, "never twice for the same stress")


func test_unalerted_guards_and_the_mark_dont_roll() -> void:
	var e := _enc()
	var u: Dictionary = _guards(e)[0]
	u.alerted = false
	u.c.hp = u.c.seriously_wounded_threshold() - 1
	assert_false(Morale.eligible(e, u), "doesn't know there's a fight yet")
	var a := _enc("assassinate")
	var vip: Dictionary = a.units[int(a.objective.target)]
	vip.alerted = true
	vip.c.hp = vip.c.seriously_wounded_threshold() - 1
	assert_false(Morale.eligible(a, vip), "the mark already runs for an exit (AI._vip): no double flight")


func test_more_than_half_down_is_a_stress_point_for_the_rest() -> void:
	var e := _enc()
	var gs := _guards(e)
	var side := gs.filter(func(u): return not u.has("turret"))
	var total := e.units.filter(func(u): return int(u.team) == Encounter.OPFOR and not u.has("turret")).size()
	assert_true(total >= 3, "enough guards to test (%d)" % total)
	for u in side:
		u.alerted = true
	var last: Dictionary = side[-1]
	var downed := 0
	for u in side:
		if downed * 2 > total:
			break
		assert_false(bool(Morale.side_stress(e, Encounter.OPFOR).half), "%d of %d down: not yet" % [downed, total])
		u.c.dead = true
		downed += 1
	assert_true(bool(Morale.side_stress(e, Encounter.OPFOR).half), "more than half down")
	assert_true("half" in Morale.pending(e, last) or last.c.dead, "the ones left standing roll")


func test_the_leader_going_down_is_a_stress_point() -> void:
	var e := _enc()
	var gs := _guards(e)
	for u in gs:
		u.c.role = "mook"
		u.alerted = true
	gs[0].c.role = "lieutenant"
	assert_false(bool(Morale.side_stress(e, Encounter.OPFOR).leader))
	gs[0].c.dead = true
	assert_true(bool(Morale.side_stress(e, Encounter.OPFOR).leader), "their Lieutenant is down")
	assert_true("leader" in Morale.pending(e, gs[1]))
	# a side of nothing but Mooks has no leader to lose
	var e2 := _enc()
	for u in _guards(e2):
		u.c.role = "mook"
	_guards(e2)[0].c.dead = true
	assert_false(bool(Morale.side_stress(e2, Encounter.OPFOR).leader))


func test_breaking_takes_them_out_of_the_opposition() -> void:
	var e := _enc()
	var u: Dictionary = _guards(e)[0]
	u.alerted = true
	e.init.add(u.c)
	u.c.drugs_taken.clear()
	u.c.role = "mook"
	u.c.hp = u.c.seriously_wounded_threshold() - 1
	var before := e.opfor().size()
	# a Mook breaks on 1-9: over a few seeds it always does somewhere; force it for the check
	u["morale_rolls"] = {}
	e.start_flight(u, "wounded", 3, 9)
	assert_eq(e.opfor().size(), before - 1, "a runner doesn't count as opposition")
	assert_eq(String(u.broke), "flee")
	assert_true(e.events.any(func(ev): return String(ev.type) == "morale" and String(ev.result) == "flee"), "the view hears of it")
	assert_true(e.log[-1].contains("breaks and runs"), "a log line")


func test_flee_reaches_the_edge_and_leaves() -> void:
	var e := _enc()
	var u: Dictionary = _guards(e)[0]
	u.alerted = true
	e.init.add(u.c)
	e.start_flight(u, "half", 2, 9)
	e.cur = u   # the runner's own field: a guard has the keys to the doors behind them
	var field := Morale.flee_field(e)
	assert_true(field.has(u.pos), "there is a way off the map")
	var start_d := int(field[u.pos])
	for i in 40:
		if u.get("fled", false):
			break
		e.cur = u
		e.turn = TurnState.begin(e.dice, u.c)
		AI.flee(e, u)
	assert_true(u.get("fled", false), "gone off the map (from %d squares)" % start_d)
	assert_true(u.c.dead, "off the map like a bystander who ran")
	assert_false(e.init.order().has(u.c), "out of the Initiative order")
	assert_eq(e.fled, 1, "counted for the debrief")
	assert_eq(e.alarm, 0, "reinforcements off in this test: no alarm")
	assert_true(e.events.any(func(ev): return String(ev.type) == "fled"))


func test_a_guard_who_gets_away_raises_the_alarm() -> void:
	var e := _enc()
	e.reinforcements = true
	var u: Dictionary = _guards(e)[0]
	u.alerted = true
	e.init.add(u.c)
	assert_true(e.alarm < 2)
	e.start_flight(u, "wounded", 2, 9)
	e.flee_out(u)
	assert_eq(e.alarm, 2, "HOUSE-RULE: one who gets clear calls it in")


func test_hiding_keeps_them_on_their_side_out_of_the_fight() -> void:
	var e := _enc()
	e.next_turn()
	while int(e.cur.team) != Encounter.CREW:
		e.end_turn()
		e.next_turn()
	var me: Dictionary = e.cur
	var u: Dictionary = _guards(e)[0]
	u.alerted = true
	e.init.add(u.c)
	var team := int(u.team)
	var v := _beside(e, me.pos)
	assert_true(v.x >= 0)
	u.pos = v
	var guns: int = u.c.weapons.size()
	e.start_hiding(u, "wounded", 2, 9)
	assert_eq(String(u.broke), "hide")
	assert_eq(int(u.team), team, "stays on its side: nobody gives up")
	assert_eq(u.c.weapons.size(), guns, "keeps what it carries")
	assert_false(e.opfor().has(u), "doesn't count as opposition")
	assert_true(e.init.order().has(u.c), "still takes turns, to keep out of the way")
	assert_eq(e.hid, 1)
	assert_eq(e.morale_counts(), {"hid": 1, "fled": 0})
	var p := e.preview(u, me.c.weapons[0], Attack.Mode.SINGLE)
	assert_true(p.ok, "the crew can still attack them")
	assert_true(p.get("hiding", false), "the preview says they're hiding")
	assert_false(p.has("surrendered"))
	# an attack lands like any other: the hit event carries the damage the view floats
	me.c.skills["handgun"] = 10
	me.c.skills["shoulder_arms"] = 10
	var hit := false
	for k in 30:
		e.turn = TurnState.begin(e.dice, me.c)
		me.c.weapons[0].ammo = me.c.weapons[0].mag()
		e.events.clear()
		var r := e.attack(u, me.c.weapons[0], Attack.Mode.SINGLE)
		if u.c.dead:
			break
		if r.get("ok", false) and e.events.any(func(ev): return String(ev.type) == "attack" and int(ev.get("damage", 0)) > 0):
			hit = true
			break
	assert_true(hit or u.c.dead, "a hit on a hiding unit carries its damage for the numbers")


func test_a_unit_with_no_way_out_hides_and_a_runner_cut_off_hides() -> void:
	var e := _enc()
	var u: Dictionary = _guards(e)[0]
	u.alerted = true
	e.init.add(u.c)
	e.m.entrances.clear()   # no way off the map anywhere
	assert_eq(Morale.choose(e, u), "hide")
	e.start_flight(u, "half", 2, 9)
	e.cur = u
	e.turn = TurnState.begin(e.dice, u.c)
	AI.flee(e, u)
	assert_eq(String(u.broke), "hide", "nowhere to run: it hides")
	assert_eq(e.hid, 1)
	assert_true(e.log.any(func(l): return String(l).contains("nowhere left to run")))


func test_a_hiding_unit_gets_out_of_a_doorway() -> void:
	var e := _enc()
	var u: Dictionary = _guards(e)[0]
	u.alerted = true
	e.init.add(u.c)
	var door := Vector3i(-1, -1, -1)
	var occ := e.occupied(u)
	for d in e.m.doors:
		var v := Vector3i(d.pos.x, d.pos.y, d.floor)
		if not e.nav.locked.has(v) and not occ.has(v) and e.m.t(v.z, v.x, v.y) == TacMap.T.DOOR:
			door = v
			break
	assert_true(door.x >= 0, "a door to stand in")
	u.pos = door
	e.start_hiding(u, "wounded", 2, 9)
	e.cur = u
	e.turn = TurnState.begin(e.dice, u.c)
	assert_true(AI.in_the_way(e, u.pos))
	AI.hide(e, u)
	assert_true(u.pos != door, "off the doorway")
	assert_false(StreetLife.is_choke(e.m, u.pos), "not in a 1-wide way either")
	var at: Vector3i = u.pos
	e.turn = TurnState.begin(e.dice, u.c)
	if not AI.in_the_way(e, at):
		AI.hide(e, u)
		assert_eq(u.pos, at, "out of the way: it stays put")


func test_the_book_odds_per_stress_point() -> void:
	assert_eq(Morale.break_chance("mook"), 0.9, "a Mook breaks on 1-9 of 1d10")
	assert_eq(Morale.break_chance("hardened_mook"), 0.8)
	assert_eq(Morale.break_chance("lieutenant"), 0.6)
	assert_eq(Morale.break_chance("mini_boss"), 0.4)
	assert_eq(Morale.break_chance("committed"), 0.2)
	# and the dice agree: Seriously Wounded Lieutenants break about 60% of the time
	var broke := 0
	var n := 0
	for s in 40:
		var e := _enc("data", 11)
		e.dice = Dice.new(s + 100)
		for u in _guards(e):
			if u.has("turret"):
				continue
			u.alerted = true
			u.c.role = "lieutenant"
			u.c.drugs_taken.clear()
			u.c.hp = u.c.seriously_wounded_threshold() - 1
			u["morale_rolls"] = {"half": 10, "leader": 10}   # only the wound counts here
			n += 1
		Morale.sweep(e)
		broke += _guards(e).filter(func(u): return u.has("broke")).size()
	var rate := float(broke) / n
	assert_true(rate > 0.45 and rate < 0.75, "Lieutenants break %.2f of the time (book: 0.6)" % rate)


func test_eliminate_counts_the_hiding_and_the_fled_as_done() -> void:
	var e := _enc("eliminate")
	e.backup_in = -1
	var gs := e.units.filter(func(u): return bool(e.sides[int(u.team)].opfor) and not u.c.dead)
	assert_true(gs.size() >= 2)
	for i in gs.size():
		var u: Dictionary = gs[i]
		u.alerted = true
		match i % 3:
			0:
				e.start_hiding(u, "half", 1, 9)
			1:
				e.start_flight(u, "half", 1, 9)   # still running: out of the fight all the same
			2:
				e.start_flight(u, "half", 1, 9)
				e.flee_out(u)
	assert_true(e.opfor().is_empty(), "nobody left fighting")
	e._check_end()
	assert_eq(e.state, "won", "put every hostile down: done")


func test_morale_sweep_is_deterministic() -> void:
	var a := _enc()
	var b := _enc()
	for e in [a, b]:
		for u in _guards(e):
			u.alerted = true
		_guards(e)[0].c.dead = true
		_guards(e)[0].c.dead = true
		for u in _guards(e):
			u.c.hp = u.c.seriously_wounded_threshold() - 1
		Morale.sweep(e)
	var ra: Array = a.units.map(func(u): return [u.get("morale_rolls", {}), String(u.get("broke", ""))])
	var rb: Array = b.units.map(func(u): return [u.get("morale_rolls", {}), String(u.get("broke", ""))])
	assert_eq(str(ra), str(rb), "same seed, same breaks")
	assert_true(a.units.any(func(u): return u.has("broke")), "a hurt Mook side breaks somewhere")
