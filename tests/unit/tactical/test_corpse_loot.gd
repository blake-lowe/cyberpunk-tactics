extends TestCase
## Corpse loot (Single Player Mode p.65-70): Search Body, the tables, the HOUSE-RULE rates.


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func _enc(seed_value := 11) -> Encounter:
	var m := SceneGen.generate(seed_value, "lone_building", {"security": 2, "site": "corp_office"})
	var dice := Dice.new(7)
	var e := Encounter.setup(m, dice, _crew(dice))
	e.reinforcements = false
	e.next_turn()
	while int(e.cur.team) != Encounter.CREW:
		e.end_turn()
		e.next_turn()
	return e


func _guards(e: Encounter) -> Array:
	return e.units.filter(func(u): return int(u.team) == Encounter.OPFOR and not u.c.dead and not u.has("turret"))


func _beside(e: Encounter, at: Vector3i) -> Vector3i:
	var occ := e.occupied()
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(1, 1, 0), Vector3i(-1, -1, 0)]:
		var v: Vector3i = at + d
		if e.m.inb(v.x, v.y) and e.m.walkable(v.z, Vector2i(v.x, v.y)) and not occ.has(v) and e.los.trace(at, v).clear:
			return v
	return Vector3i(-1, -1, -1)


func test_every_table_has_a_hundred_rows_in_order_with_our_own_short_labels() -> void:
	var t := CorpseLoot.tables()
	assert_eq(t.keys(), CorpseLoot.TABLES, "Streetrat, Edgerunner, Corporate")
	for id in t:
		var rows: Array = t[id].rows
		assert_true(String(t[id].cite).begins_with("SPM p."), "%s cited" % id)
		assert_eq(rows.size(), 100, "%s: a d100 table" % id)
		for i in rows.size():
			var r: Dictionary = rows[i]
			assert_eq(int(r.roll), i + 1, "%s: rows in roll order" % id)
			var words := String(r.label).split(" ").size()
			assert_true(words >= 2 and words <= 5, "%s %d: a 2-5 word label (%s)" % [id, r.roll, r.label])
			assert_true(r.has("unmodelled") or String(r.get("kind", "")) in ["eb", "item", "lead", "keycard", "net_code"], "%s %d: a kind" % [id, r.roll])
		assert_true(CorpseLoot.modelled(String(id)).size() >= 15, "%s: plenty plays" % id)


func test_each_table_maps_to_modelled_items() -> void:
	var dice := Dice.new(3)
	for id in CorpseLoot.TABLES:
		for r: Dictionary in CorpseLoot.modelled(id):
			match String(r.kind):
				"item":
					for k in r.items:
						assert_true(Items.is_stored(String(k)), "%s %d: storage takes %s" % [id, r.roll, k])
						assert_true(NightMarket.on_sale(String(k)), "%s %d: %s is something the game plays (sold)" % [id, r.roll, k])
						assert_true(CorpseLoot.amount(dice, r.items[k]) >= 1, "%s %d: a count" % [id, r.roll])
				"eb":
					for i in 5:
						assert_true(CorpseLoot.amount(dice, r.eb) > 0, "%s %d: worth something" % [id, r.roll])
				"lead":
					assert_true(String(r.get("hook", "")) != "", "%s %d: a hook kind" % [id, r.roll])
				"keycard":
					assert_true(String(r.zone) in ["low", "high"])


func test_which_table_a_body_rolls_on() -> void:
	var e := _enc()
	var u: Dictionary = _guards(e)[0]
	for fid in ["militech", "maelstrom", "ncpd"]:
		assert_true(World.has_faction(fid), fid)
	u.team = e.add_side("militech", "guard", true)
	assert_eq(CorpseLoot.table_for(e, u), "corporate", "corp security: Corporate")
	u.team = e.add_side("maelstrom", "guard", true)
	u.c.role = "mook"
	assert_eq(CorpseLoot.table_for(e, u), "streetrat", "a gang's Mook: Streetrat")
	u.c.role = "lieutenant"
	assert_eq(CorpseLoot.table_for(e, u), "edgerunner", "a gang's Lieutenant: Edgerunner")
	u.team = e.add_side("ncpd", "guard", true)
	u.c.role = "mook"
	assert_eq(CorpseLoot.table_for(e, u), "edgerunner", "police: Edgerunner")


func test_search_body_once_per_body() -> void:
	var e := _enc()
	var g: Dictionary = _guards(e)[0]
	var v := _beside(e, e.cur.pos)
	assert_true(v.x >= 0)
	g.pos = v
	assert_true(e.body_in_reach(e.cur).is_empty(), "a guard on their feet isn't a body")
	g.c.dead = true
	assert_eq(e.body_in_reach(e.cur), g, "a body beside you")
	g.erase("keycard")   # (a keycard on them comes first on B)
	assert_eq(String(Hud.interact_here(e)[0]), "search", "B searches it")
	var r := e.search_body()
	assert_true(r.ok)
	assert_false(e.turn.action_available, "an Action")
	assert_true(g.get("searched", false))
	assert_eq(e.loot.size(), 1, "the find is kept, even an empty pocket")
	assert_true(e.events.any(func(ev): return String(ev.type) == "search"), "the view plays it")
	e.turn.action_available = true
	assert_true(e.body_in_reach(e.cur).is_empty(), "searched once: not again")
	assert_false(e.search_body().ok)
	assert_eq(e.loot.size(), 1)


func test_a_hiding_guard_cant_be_searched_nor_a_bystander() -> void:
	var e := _enc()
	var g: Dictionary = _guards(e)[0]
	g.pos = _beside(e, e.cur.pos)
	e.start_hiding(g, "wounded", 1, 9)
	assert_true(e.body_in_reach(e.cur).is_empty(), "still on their feet: no frisking (nobody surrenders now)")
	g.c.dead = true
	assert_eq(e.body_in_reach(e.cur), g, "once they're down")
	var civ := e.units.filter(func(u): return u.get("civ", false))
	if not civ.is_empty():
		civ[0].c.dead = true
		assert_false(e.searchable(civ[0]), "bystanders aren't the opposition")


func _rate(e: Encounter, by: Dictionary, g: Dictionary, n: int) -> float:
	var got := 0
	for i in n:
		g.erase("searched")
		var f := CorpseLoot.search(e, by, g)
		if String(f.kind) != "nothing":
			got += 1
			assert_true(String(f.kind) in ["eb", "item", "lead", "keycard", "net_code"], "only modelled rows come up")
	return float(got) / n


func test_drop_chances_are_the_house_rule_rates() -> void:
	var e := _enc()
	var g: Dictionary = _guards(e)[0]
	g.c.dead = true
	var n := 3000
	g.c.role = "mook"
	assert_between(_rate(e, e.cur, g, n), 1.0 / 3.0 - 0.03, 1.0 / 3.0 + 0.03, "a Mook: 1 in 3")
	g.c.role = "lieutenant"
	assert_between(_rate(e, e.cur, g, n), 0.5 - 0.03, 0.5 + 0.03, "a Lieutenant: 1 in 2")
	g.c.role = "mini_boss"
	assert_between(_rate(e, e.cur, g, n), 2.0 / 3.0 - 0.03, 2.0 / 3.0 + 0.03, "a Mini Boss: 2 in 3")


func test_a_keycard_find_opens_the_doors_it_fits() -> void:
	var e: Encounter = null
	for sd in [17, 11, 23, 5, 31]:
		e = _enc(sd)
		if not e.nav.locked.is_empty():
			break
	if e.nav.locked.is_empty():
		return
	var g: Dictionary = _guards(e)[0]
	g.pos = _beside(e, e.cur.pos)
	g.c.dead = true
	g.erase("keycard")
	g.c.role = "mini_boss"   # Edgerunner or Corporate: both have a keycard row
	var f := {}
	for i in 4000:   # search again and again until the keycard row comes up
		g.erase("searched")
		e.turn.action_available = true
		f = e.search_body().find
		if String(f.kind) == "keycard":
			break
	assert_eq(String(f.kind), "keycard", "the keycard row comes up")
	assert_true(f.has("opened"), "used on the spot")
	assert_true(int(f.opened) > 0 or e.keycards.size() > 0, "it opens this site's doors (%s)" % f.zone)


func test_a_login_code_opens_one_password_without_a_roll() -> void:
	var m := SceneGen.generate(11, "lone_building", {"site": "corp_office", "security": 1})
	var dice := Dice.new(9)
	var e := Encounter.setup(m, dice, _crew(dice))
	var runner: Dictionary = e.units[1]
	var a: NetArchitecture = m.architecture
	var ap_dev: Dictionary = m.devices[a.access_points[0].device]
	runner.pos = Vector3i(ap_dev.pos.x, ap_dev.pos.y, ap_dev.floor)
	e.cur = runner
	e.turn = TurnState.begin(dice, runner.c)
	e.jack_in(e.jack_points(runner)[0])
	var run: NetRun = e.runs[runner.id]
	var fw: Array = run.arch.nodes_of_type("firewall")
	if fw.is_empty():
		return
	run.current = int(fw[0].id)
	e.turn = TurnState.begin(dice, runner.c)
	e.net_left = 3
	e._netting = false
	e.login_codes = 1
	var r := e.net_action("backdoor")
	assert_true(r.ok and r.success and r.get("login_code", false), "the code off a body opens it")
	assert_true(run.broken.has(fw[0].id))
	assert_eq(e.login_codes, 0, "one Password per code")


func test_finds_go_home_only_with_whoever_got_out() -> void:
	var e := _enc()
	var me: Dictionary = e.cur
	e.loot.append({"body": 5, "by": int(me.id), "kind": "eb", "eb": 100, "label": "loaded credstick"})
	e.loot.append({"body": 6, "by": int(me.id), "kind": "keycard", "zone": "low", "label": "janitor's access badge"})
	e.state = "won"
	assert_eq(CorpseLoot.kept(e).size(), 1, "cash goes home; a keycard was used on site")
	me.c.dead = true
	assert_eq(CorpseLoot.kept(e).size(), 0, "a finder who didn't come back takes it with them")
	me.c.dead = false
	e.state = "lost"
	assert_eq(CorpseLoot.kept(e).size(), 0, "the whole crew down: nothing comes home")
	e.state = "fled"
	assert_eq(CorpseLoot.kept(e).size(), 1, "a withdrawal keeps what those who got out carry")
