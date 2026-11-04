extends TestCase
## What the player sees of an operation (Playland) and the set-piece HUD lines: the board card's
## tag, route and carry-over line, the event's effects, the map's place / leg / floor labels, the
## end-of-gig headline and the debrief's wording, which must all agree.

const GREYBOX := preload("res://src/tactical/greybox.gd")


func _offer() -> Dictionary:
	var c := DemoState.make()
	return DemoState.operation_offer(c, "playland")


func _open(s: SafehouseScreen, camp: Campaign, tab := "") -> SafehouseScreen:
	Hud._fonts()
	s.setup(camp, null, tab, 0)
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	if not s.is_inside_tree():
		s._ready()
	return s


func _texts(n: Node) -> String:
	var out: Array[String] = []
	for l in n.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	for b in n.find_children("*", "Button", true, false):
		out.append((b as Button).text)
	return "\n".join(out)


func test_an_operation_reads_as_one_on_the_board() -> void:
	var g := _offer()
	assert_false(g.is_empty(), "the demo finds a Playland offer")
	var n := (g.legs as Array).size()
	assert_eq(FixerScreen.op_tag(g), "%d-MAP OPERATION" % n)
	var route := FixerScreen.op_route(g)
	assert_eq(route.split(" → ").size(), n, "one land per map: " + route)
	for l in g.legs:
		assert_true(route.contains(String(l.land_name)), "%s on the route" % l.land_name)
	assert_true(FixerScreen.CARRY_LINE.contains("wounds") and FixerScreen.CARRY_LINE.contains("ammo"), "says what carries over")
	assert_eq(FixerScreen.op_tag({"title": "one map"}), "0-MAP OPERATION", "only asked of operations; harmless on a plain gig")


func test_the_jobs_card_shows_the_tag_route_carry_over_and_van() -> void:
	var camp := DemoState.make()
	camp.board.insert(0, DemoState.operation_offer(camp, "playland"))
	var s := _open(FixerScreen.new(), camp, "jobs")
	var t := _texts(s)
	var g: Dictionary = camp.board[0]
	assert_true(t.contains(FixerScreen.op_tag(g)), "the tag")
	assert_true(t.contains(FixerScreen.CARRY_LINE), "the carry-over line")
	assert_true(t.contains("Stays in the van:"), "what the gate keeps out")
	for l in g.legs:
		assert_true(t.contains(String(l.leg_title)), "leg %s listed" % l.leg_title)
	for l in s.find_children("*", "Label", true, false):   # nothing on the card refuses to wrap and widens the screen
		var lb := l as Label
		if lb.text.contains("★") and lb.text.contains(" eb"):
			assert_true(lb.autowrap_mode != TextServer.AUTOWRAP_OFF, "a leg's detail line wraps: " + lb.text)
	s.queue_free()


func test_the_city_job_panel_says_it_is_an_operation() -> void:
	var camp := DemoState.make()
	camp.board.insert(0, DemoState.operation_offer(camp, "playland"))
	Hud._fonts()
	var city := CityTab.new().setup(camp)
	var v := UiKit.vbox()
	city._job(v, 0)
	var t := _texts(v)
	assert_true(t.contains(FixerScreen.op_tag(camp.board[0])), "the tag on the job panel")
	assert_true(t.contains(FixerScreen.CARRY_LINE), "and what carries over")
	city.free()
	v.free()


func test_event_effects_in_words() -> void:
	assert_eq(FixerScreen.event_effects({"fx": {}}), "", "colour only")
	assert_eq(FixerScreen.event_effects({"fx": {"police": 2}}), "NCPD on every map (2 officers).")
	assert_eq(FixerScreen.event_effects({"fx": {"lights_off": ["haunted_woods"]}}), "The lights are down in Haunted Woods.")
	assert_eq(FixerScreen.event_effects({"fx": {"civilians": ["junior_executive"]}}), "Junior Executives in the crowd.")


func test_floor_place_and_leg_labels() -> void:
	var m := TacMap.new(4, 4, 3)
	assert_eq(GREYBOX.floor_label(m, 0), "FLOOR 1")
	m.params["scene"] = "lone_building"
	assert_eq(GREYBOX.place_label(m, {}, "skirmish"), "lone building", "a dev map by its scene")
	var g := _offer()
	assert_eq(GREYBOX.place_label(m, g, "skirmish"), Campaign.place_name(g), "an operation's leg by its location")
	assert_eq(GREYBOX.leg_label(g), "LEG 1/%d" % (g.legs as Array).size())
	assert_eq(GREYBOX.leg_label({"title": "one map"}), "", "no leg line for a plain gig")
	var e := SceneGen.generate(3, "lone_building", {"setpiece": "the_estates", "variant": "1d"})
	assert_true(GREYBOX.place_label(e, {}, "").contains("Kerry Eurodyne"), "an estate by its owner: " + GREYBOX.place_label(e, {}, ""))


func test_the_end_headline_and_the_debrief_agree() -> void:
	var g := _offer()
	g["leg"] = 1
	g["done"] = [{}]
	var n := (g.legs as Array).size()
	var cases := [["won", true, "OPERATION ENDED EARLY", "Operation ended early"],   # a won leg, then WITHDRAW
		["fled", true, "OPERATION ENDED EARLY", "Operation ended early"],
		["lost", true, "OPERATION FAILED", "Operation failed"]]
	for cs in cases:
		var b: Dictionary = GREYBOX.end_banner(String(cs[0]), g, bool(cs[1]))
		assert_eq(String(b.head), String(cs[2]), String(cs[0]))
		assert_true(String(b.text).begins_with(String(b.head)), "the banner starts with the headline")
		var rep := {"won": false, "state": cs[0], "legs": [{}, {}] if cs[0] == "won" else [{}], "leg_count": n}
		assert_eq(String(DebriefScreen.outcome(rep)[0]).to_upper(), String(cs[2]), "the debrief says the same: " + String(cs[0]))
	assert_eq(String(GREYBOX.end_banner("won", g, false).head), "OPERATION COMPLETE")
	assert_eq(String(DebriefScreen.outcome({"won": true, "legs": [{}, {}]})[0]), "Operation complete")
	for st in ["won", "fled", "lost"]:
		var plain: Dictionary = GREYBOX.end_banner(st, {"title": "x"}, false)
		assert_eq(String(DebriefScreen.outcome({"won": st == "won", "state": st})[0]).to_upper(), String(plain.head), "a plain gig: " + st)


func test_resolve_reports_how_the_map_ended() -> void:
	var c := DemoState.operation(DemoState.make(), "playland", 0)
	var g := c.active_gig
	var m := SceneGen.generate(int(g.seed), String(g.scene), Campaign.scene_opts(g))
	var crew: Array[Combatant] = []
	for x in c.alive_crew():
		if x.can_act():
			crew.append(x)
	var e := Encounter.setup(m, c.dice, crew, Campaign.objective_for(g), Campaign.encounter_opts(g))
	e.state = "fled"
	var r := c.resolve(e)
	assert_eq(String(r.get("state", "")), "fled")
	assert_eq(String(DebriefScreen.outcome(r)[0]), "Operation ended early")


func test_the_demo_operation_starts_at_the_asked_leg() -> void:
	var c := DemoState.operation(DemoState.make(), "playland", 1)
	assert_eq(int(c.active_gig.leg), 1)
	assert_eq((c.active_gig.done as Array).size(), 1, "the leg before it done")
	assert_true(c.has_meta("demo"), "never saved over a real campaign")


func test_every_leg_briefs_what_is_in_the_van() -> void:
	var c := DemoState.operation(DemoState.make(), "playland", 0)
	var van := c.van_list()
	assert_false(van.is_empty(), "the demo crew carries something the gate stops")
	var first := GREYBOX.brief_lines(c.active_gig, van)
	assert_true(first[0].begins_with("Leg 1 of "), first[0])
	assert_true(first.any(func(l): return l.begins_with("No weapons past the gate. In the van:")), "the gate on leg 1")
	var g: Dictionary = c.active_gig.duplicate(true)
	g["leg"] = 1
	var later := GREYBOX.brief_lines(g, van)
	assert_true(later[0].begins_with("Leg 2 of "), later[0])
	assert_true(later.has("Still in the van: %s." % ", ".join(van)), "a reminder on later legs")
	assert_false(later.any(func(l): return l.begins_with("No weapons past the gate")), "the gate was passed once")
	var empty: Array[String] = []
	assert_false(GREYBOX.brief_lines(g, empty).any(func(l): return l.begins_with("Still in the van")), "nothing in the van: no line")


func test_a_turret_card_has_rounds_and_no_row_of_zero_stats() -> void:
	var t := Turret.make(1)
	var card := Hud.stat_block(t, false)
	assert_false(card.contains("[table"), "a turret has no STATs to show")
	assert_true(card.contains("%d/%d" % [t.weapons[0].ammo, int(t.weapons[0].def.get("mag", 0))]), "its rounds left")
	var p := Recruit.generate(Dice.new(3), "solo", "edgerunner", "Vex")
	assert_true(Hud.stat_block(p, false).contains("[table"), "a person keeps the STAT line")


func test_the_mist_tag_sits_on_the_line_being_watched() -> void:
	var m := TacMap.new(40, 40, 1)
	var z := HazardZone.from_spec({"name": "MIST", "start": 3, "every": 3, "steps": 4, "final_r": 6}, m, Dice.new(2))
	assert_eq(HazardView.tag_text(z), "MIST · NEXT", "before the first close: the dashed line")
	var p := HazardView.tag_point(z, Vector2(0, 0))
	assert_true(p.is_finite() and Rect2(z.area).has_point(p), "a point inside the drawn area")
	assert_near(p.distance_to(z.center), z.next_radius(), 0.01, "on the next edge")
	z.force_stage(2)
	assert_eq(HazardView.tag_text(z), "MIST")
	var q := HazardView.tag_point(z, z.center + Vector2(100, 0))
	assert_near(q.distance_to(z.center), z.radius(), 0.01, "on the safe edge once closed")
	assert_true(q.x > z.center.x, "the side nearest the view")
