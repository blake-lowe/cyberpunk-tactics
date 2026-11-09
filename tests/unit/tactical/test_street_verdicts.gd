extends TestCase
## Owner verdicts 2026-11-09 on scene events and everyday life: a street gang war leaves the crew
## alone until the crew joins in (Encounter `spares_crew`, _provoke); the other street sides keep
## their stance; the street shows rather than tells (no HUD line, no deploy card); bystanders
## scatter from a gunfight (Encounter._panic_near, _civilians_tick).


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func _enc(id: String, seed_value := 77) -> Encounter:
	var dice := Dice.new(5)
	var key := SceneEvent.table_of(id)
	var spec := SceneEvent.make(key, SceneEvent.row(key, id), 1)
	var m := SceneGen.generate(seed_value, "street_block", {"security": 2, "district": "watson_development"})
	return Encounter.setup(m, dice, _crew(dice), "data", {"scene_event": spec, "district": "watson_development",
		"security_code": {"n": 11, "faction": "", "intensity": "medium", "hardened": false}})


func _life_enc(seed_value: int) -> Encounter:
	var dice := Dice.new(seed_value)
	var m := SceneGen.generate(seed_value, "street_block", {"security": 2, "district": "kabuki"})
	return Encounter.setup(m, dice, _crew(dice), "data", {"district": "kabuki"})


func _fighters(e: Encounter) -> Array:
	return e.units.filter(func(u): return u.get("street_event", false) and not u.get("civ", false))


func test_street_war_gangs_leave_the_crew_alone_until_provoked() -> void:
	for id in ["gang_war", "turf_argument", "raiders_home"]:
		var e := _enc(id)
		var fighters := _fighters(e)
		assert_true(not fighters.is_empty(), "%s: gangers out" % id)
		var crew: Dictionary = e.units[0]
		for u in fighters:
			assert_false(e.hostile(int(u.team), Encounter.CREW), "%s: not hostile to the crew" % id)
			assert_false(bool(e.sides[int(u.team)].opfor), "%s: not the gig's opposition" % id)
			assert_false(e.foes(crew).has(u), "%s: not a foe of the crew's" % id)
			assert_false(AI._enemies(e, u).has(crew), "%s: their AI doesn't target the crew" % id)
		assert_false(e.opfor().any(func(u): return u in fighters), "%s: objectives don't count them" % id)
		assert_false(e.engaged(), "%s: the crew isn't engaged by a fight that isn't theirs" % id)
		# The crew opens fire on one of them: that gang turns, the other (if any) stays out of it.
		var t: Dictionary = fighters[0]
		var others: Array = fighters.filter(func(u): return int(u.team) != int(t.team))
		var alarm := e.alarm
		e._keep_peace(crew, [t.pos])
		assert_true(e.hostile(int(t.team), Encounter.CREW), "%s: shot at, they turn on the crew" % id)
		assert_false(bool(e.sides[int(t.team)].opfor), "%s: still not the gig's opposition" % id)
		assert_eq(e.alarm, alarm, "%s: no alarm of the site's for it" % id)
		for o in others:
			assert_false(e.hostile(int(o.team), Encounter.CREW), "%s: the other gang stays out of it" % id)
		assert_true(e.log.any(func(l): return String(l).ends_with("turn on the crew.")), "%s: the log says so" % id)


func test_a_gang_war_plays_out_without_the_crew() -> void:
	var e := _enc("gang_war")
	var crew_hp: Array = e.units.filter(func(u): return u.team == Encounter.CREW).map(func(u): return u.c.hp)
	for i in 40:   # the crew sits tight; the gangs shoot it out
		e.next_turn()
		if e.state != "playing":
			break
		if e.cur.team == Encounter.CREW:
			e.end_turn()
		if e.init.round_num > 3:
			break
	assert_true(e.events.any(func(ev): return String(ev.type) == "attack") or e.log.any(func(l): return String(l).contains("→")), "the gangs fight")
	assert_eq(e.units.filter(func(u): return u.team == Encounter.CREW).map(func(u): return u.c.hp), crew_hp, "nobody shot at the crew")
	assert_true(_fighters(e).all(func(u): return not e.hostile(int(u.team), Encounter.CREW)), "and nobody turned on them")


func test_a_stray_blast_provokes_and_the_crews_allies_share_the_peace() -> void:
	var e := _enc("gang_war")
	var fighters := _fighters(e)
	var crew: Dictionary = e.units[0]
	var ally := e.add_side("crew_turrets", "turret", false, {"stands_with": Encounter.CREW})
	assert_false(e.hostile(ally, int(fighters[0].team)), "standing with the crew: spared too")
	e._keep_peace(crew, [Vector3i(-50, -50, 0), fighters[-1].pos])   # the blast's middle elsewhere, a ganger caught in it
	assert_true(e.hostile(int(fighters[-1].team), Encounter.CREW), "caught in the crew's blast: provoked")
	assert_true(e.hostile(ally, int(fighters[-1].team)), "and the crew's allies with them")
	var late := e.add_side("crew_drones", "turret", false, {"stands_with": Encounter.CREW})
	assert_true(e.hostile(late, int(fighters[-1].team)), "a later ally too")


func test_other_street_sides_keep_their_stance() -> void:
	var e := _enc("ncpd_standoff")
	var cops: Array = _fighters(e)
	assert_true(not cops.is_empty() and cops.all(func(u): return not e.hostile(int(u.team), Encounter.CREW)), "NCPD: neutral to start")
	e._keep_peace(e.units[0], [cops[0].pos])
	assert_true(e.hostile(int(cops[0].team), Encounter.CREW), "NCPD: shot at, provoked")
	e = _enc("cyberpsycho")
	var psy: Dictionary = e.units[int(e.scene_event.psycho)]
	assert_true(e.hostile(int(psy.team), Encounter.CREW) and e.hostile(int(psy.team), Encounter.CIV_TEAM), "the psycho: hostile to everyone")


func test_the_street_shows_it_doesnt_tell() -> void:
	assert_false(SceneEvent.new().has_method("hud_line"), "no HUD line for a scene event")
	var h := Hud.new()
	assert_false(h.has_method("street_callout"), "no ON THE STREET card")
	h.free()
	var e := _enc("gang_war")
	var lines: Array = e.log.filter(func(l): return String(l).begins_with("On the street: "))
	assert_eq(lines.size(), 1, "one quiet log line")
	assert_false(String(lines[0]).contains("shoot anyone"), "it shows, it doesn't explain")
	assert_false(e.scene_event.has("text"), "nothing kept to explain it with")


func test_bystanders_scatter_from_a_gunfight() -> void:
	assert_eq(Encounter.panic_chance(2.0), 1.0, "right next to it: everyone")
	assert_true(Encounter.panic_chance(12.0) > Encounter.panic_chance(18.0), "a distant shot spooks fewer")
	assert_eq(Encounter.panic_chance(Encounter.PANIC_FAR + 1.0), 0.0, "too far to care")
	var near_total := 0
	var gone_total := 0
	var ways := {}
	for s in [23, 37, 11]:
		var e := _life_enc(s)
		var at := Vector3i(-1, -1, -1)
		var best := -1
		for u in e.units:
			if u.get("civ", false) and StreetLife.outdoors(e.m, u.pos):
				var nn := e.units.filter(func(o): return o.get("civ", false) and Vector2(o.pos.x - u.pos.x, o.pos.y - u.pos.y).length() <= 8.0).size()
				if nn > best:
					best = nn
					at = u.pos
		var near: Array = e.units.filter(func(u): return u.get("civ", false) and not u.c.dead and absi(u.pos.z - at.z) <= 1 \
			and Vector2(u.pos.x - at.x, u.pos.y - at.y).length() <= Encounter.PANIC_NEAR)
		var start := {}
		for u in near:
			start[u.id] = u.pos
		for r in 2:   # two rounds of shooting at the same spot
			e.init.round_num = r + 1
			e._noise(at)
			e._civilians_tick()
		for u in near:
			near_total += 1
			assert_true(u.panic, "%d: within %d squares, everyone is spooked (%s)" % [s, int(Encounter.PANIC_NEAR), u.pos])
			ways[String(u.scatter)] = true
			if u.get("fled", false) or String(u.scatter) == "hidden":
				gone_total += 1   # off the street: gone off the map, or inside out of sight
			elif String(u.scatter) != "cower":
				assert_true(u.pos != start[u.id], "%d: a runner still on the street is on the move (%s)" % [s, u.scatter])
			if not u.c.dead and u.pos != start[u.id]:
				assert_false(StreetLife.is_choke(e.m, u.pos), "%d: not stopped in a 1-wide way" % s)
	assert_true(near_total >= 6, "people about (%d)" % near_total)
	assert_true(gone_total * 2 >= near_total, "most of the street is gone or indoors after two rounds (%d of %d)" % [gone_total, near_total])
	assert_true(ways.size() >= 2, "not all the same way: %s" % [ways.keys()])


func test_scatter_is_deterministic() -> void:
	var a := _life_enc(23)
	var b := _life_enc(23)
	for e in [a, b]:
		e._noise(e.units.filter(func(u): return u.get("civ", false))[0].pos)
		e._civilians_tick()
		e._civilians_tick()
	assert_eq(a.units.map(func(u): return [u.pos, u.get("scatter", "")]), b.units.map(func(u): return [u.pos, u.get("scatter", "")]))
