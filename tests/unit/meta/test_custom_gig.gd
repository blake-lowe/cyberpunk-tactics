extends TestCase
## DEV ONLY: the custom gig builder (CustomGig, the CUSTOM GIG (DEV) card on JOBS). The card's
## form and the dev flags are one system (the same gig, map and encounter options); auto fields
## resolve from the seed; a custom gig runs as a board gig and is marked dev; without developer
## mode the card is never offered.


func _map_json(gig: Dictionary) -> String:
	return JSON.stringify(SceneGen.generate(int(gig.seed), String(gig.scene), Campaign.scene_opts(gig)).to_dict())


func test_form_and_flags_build_the_same_gig() -> void:
	var form := {"setpiece": "totentanz", "objective": "snatch", "security": 2, "complication": "mook:2", "seed": 4242,
		"deploy": "near", "utility": "power", "code": "7:ncpd,hardened heavy", "pay": 3500}
	var flags := CustomGig.to_flags(form)
	assert_true("--setpiece=totentanz" in flags and "--complication=mook:2" in flags and "--seed=4242" in flags, "the greybox's own flag names")
	var from_flags := CustomGig.from_flags(flags)
	var want := CustomGig.defaults()
	want.merge(form, true)
	assert_eq(from_flags, want, "flags read back to the form")
	var a := CustomGig.build(form, Campaign.new_game(1))
	var b := CustomGig.build(from_flags, Campaign.new_game(2))
	assert_eq(a, b, "the same gig")
	assert_eq(Campaign.scene_opts(a), Campaign.scene_opts(b))
	assert_eq(Campaign.encounter_opts(a), Campaign.encounter_opts(b), "the same encounter options")
	assert_eq(_map_json(a), _map_json(b), "the same map")
	assert_eq(String(a.location), "hot_zone_11", "a set piece's own location")
	assert_eq(String(a.district), "hot_zone")
	assert_eq(int(a.security_code.n), 7)
	assert_true(bool(a.security_code.hardened))
	assert_eq(int(a.pay), 3500)
	var eo := Campaign.encounter_opts(a)
	assert_eq(eo.complication, {"tier": "mook", "roll": 2})
	assert_eq(eo.outages, ["power"])
	assert_eq(String(Campaign.scene_opts(a).deploy), "near")


## The greybox's standalone flag path builds SceneGen options from the same flags; a fully
## specified custom gig gets the very same map from them.
func test_flags_give_the_greybox_flag_map() -> void:
	var cases := [
		["--scene=lone_building", "--site=bar", "--district=kabuki", "--security=2", "--seed=7"],
		["--scene=lone_building", "--setpiece=totentanz", "--location=hot_zone_11", "--district=hot_zone", "--security=3", "--seed=9", "--faction=maelstrom"],
	]
	for flags: Array in cases:
		var gig := CustomGig.build(CustomGig.from_flags(PackedStringArray(flags)))
		var o := {}   # greybox new_gig, flag path
		var scene := "skirmish"
		var seed := 11
		for a in flags:
			var kv := String(a).trim_prefix("--").split("=")
			match kv[0]:
				"scene": scene = kv[1]
				"security": o["security"] = int(kv[1])
				"district": o["district"] = kv[1]
				"site": o["site"] = kv[1]
				"setpiece": o["setpiece"] = kv[1]
				"location": o["location"] = kv[1]
				"seed": seed = int(kv[1])
		assert_true(Atmosphere.has(String(gig.get("mood", ""))), "the builder draws the gig's weather")
		o["mood"] = String(gig.mood)   # greybox takes it as --mood (the flag map below)
		assert_eq(Campaign.scene_opts(gig), o, "%s: the greybox's scene options" % " ".join(flags))
		assert_eq(_map_json(gig), JSON.stringify(SceneGen.generate(seed, scene, o).to_dict()), "the greybox's map")


func test_auto_fields_resolve_from_the_seed() -> void:
	var a := CustomGig.build({"seed": 777}, Campaign.new_game(3))
	var b := CustomGig.build({"seed": 777}, Campaign.new_game(99))
	assert_eq(a, b, "one seed, one gig, whatever the campaign")
	assert_true(a.dev, "marked dev")
	assert_eq(int(a.form.seed), 777)
	assert_eq(CustomGig.build(a.form), a, "its form builds it again")
	var c := Campaign.new_game(5)
	var auto := CustomGig.build({}, c)
	assert_true(int(auto.seed) > 0, "an auto seed is drawn from the campaign's dice")
	assert_eq(CustomGig.build(auto.form), auto, "and kept in the form")
	var seen := {}
	for s in range(1, 9):
		var g := CustomGig.build({"seed": s})
		seen[String(g.get("location", "")) + String(g.kind)] = true
		assert_true(int(g.security) >= 1 and int(g.security) <= 3)
		assert_true(int(g.pay) > 0)
		assert_true(Campaign.OBJECTIVES.has(String(g.kind)))
		assert_false(String(g.get("district", "")) in Campaign.NO_GIGS, "never a district without gigs")
	assert_true(seen.size() > 3, "auto varies with the seed")


func test_partial_forms_build() -> void:
	for form in [{"district": "kabuki"}, {"objective": "rescue"}, {"profile": "industrial"}, {"site": "bank", "basements": "on"},
			{"scene": "badlands"}, {"location": CustomGig.NONE, "district": CustomGig.NONE}, {"code": "3:,light"}, {"faction": "militech"}]:
		var g := CustomGig.build(form.merged({"seed": 11}))
		assert_true(SceneGen.PLANNERS.has(String(g.scene)), "%s: a scene" % str(form))
		assert_true(int(g.pay) > 0)
	var k := CustomGig.build({"district": "kabuki", "seed": 3})
	assert_eq(String(k.district), "kabuki")
	assert_eq(String(World.location(String(k.location)).district), "kabuki", "an auto location in the district")
	assert_eq(String(CustomGig.build({"objective": "rescue", "seed": 3}).kind), "rescue")
	assert_eq(String(CustomGig.build({"faction": "militech", "seed": 3}).faction), "militech")
	var bank := CustomGig.build({"site": "bank", "basements": "on", "seed": 3, "district": "kabuki"})
	assert_eq(String(bank.scene), "lone_building")
	assert_true(CustomGig.basements_apply(bank))
	assert_true(SceneGen.generate(int(bank.seed), String(bank.scene), Campaign.scene_opts(bank)).basements > 0, "basements forced on")
	var off := bank.duplicate()
	off.basement_storeys = 0
	assert_eq(SceneGen.generate(int(off.seed), String(off.scene), Campaign.scene_opts(off)).basements, 0, "and off")
	assert_false(CustomGig.basements_apply(CustomGig.build({"setpiece": "totentanz", "seed": 3})), "a set piece keeps its recipe's")
	assert_eq(CustomGig.locations("kabuki").filter(func(id): return String(World.locations()[id].district) != "kabuki"), [])
	assert_true(CustomGig.locations("", "totentanz").has("hot_zone_11"), "searchable by name")
	assert_true(CustomGig.locations().all(func(id): return Campaign.offered_at(String(id))), "never in a district without gigs")


func test_custom_gig_runs_like_a_board_gig() -> void:
	var c := Campaign.new_game(21)
	var who: String = c.crew[0].display_name
	var board := c.board.duplicate(true)
	var gig := c.accept_custom({"district": "watson_development", "objective": "eliminate", "complication": "none",
		"utility": "none", "seed": 55, "crew": [who]})
	assert_false(gig.is_empty())
	assert_true(c.active_gig.dev)
	assert_true(c.log[-2].begins_with("[DEV] Took"), "the log says so")
	assert_true(int(c.active_gig.get("travel_minutes", 0)) > 0, "a drive across the city")
	assert_eq(c.board, board, "the board's offers stay as they were")
	assert_true(bool(SaveSlots.meta_for(c).dev), "a save mid-gig says DEV")
	var s := GigSetup.for_campaign(c)
	assert_eq(s.enc.alive(0).size(), 1, "only the crew member picked goes")
	assert_true(s.enc.complication.is_empty(), "complication none")
	assert_true(s.enc.outages.is_empty(), "no utilities out")
	assert_eq(Campaign.objective_for(c.active_gig), "eliminate")
	s.enc.state = "won"
	var eb := c.eb
	var rep := c.resolve(s.enc)
	assert_true(rep.dev, "the debrief's report is marked dev")
	assert_true(DebriefScreen.is_dev(rep))
	assert_eq(c.eb, eb + int(gig.pay), "paid")
	assert_true(int(rep.ip) > 0)
	assert_eq(c.dev_gigs, 1)
	assert_eq(int(c.last_custom.seed), 55)
	var back := Campaign.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.dev_gigs, 1, "the save keeps the dev mark")
	assert_eq(back.last_custom, c.last_custom, "and the last custom gig for REPEAT")
	assert_true(SaveSlots.describe(SaveSlots.meta_for(back)).where.contains("dev gig"))
	assert_false(back.board.any(func(g): return g.get("dev", false)), "custom gigs never go on the board")
	var again := back.accept_custom(back.last_custom)
	assert_eq(String(again.location), String(gig.location), "REPEAT builds the same gig")
	assert_eq(int(again.seed), 55)


func test_forced_outages_and_complication() -> void:
	var c := Campaign.new_game(8)
	c.accept_custom({"site": "bar", "district": "kabuki", "utility": "power,citinet", "complication": "mook:3", "seed": 31})
	var s := GigSetup.for_campaign(c)
	assert_eq(Array(s.enc.outages), ["power", "citinet"], "exactly the utilities out the builder set")
	assert_eq(String(s.enc.complication.get("tier", "")), "mook")
	assert_eq(int(s.enc.complication.get("roll", 0)), 3)


func test_card_only_in_dev_mode() -> void:
	var saved := GameSettings.load_values()
	var off := saved.duplicate()
	off.dev_mode = false
	GameSettings.save_values(off)
	assert_false(GameSettings.DEFAULTS.dev_mode, "off by default")
	assert_false(GameSettings.dev_mode(), "no --dev and the option off")
	var on := off.duplicate()
	on.dev_mode = true
	GameSettings.save_values(on)
	assert_true(GameSettings.dev_mode(), "the Options toggle turns it on")
	GameSettings.save_values(off)
	var camp := DemoState.make()
	for dev in [0, 1]:
		GameSettings.dev_override = dev
		Hud._fonts()
		var s := FixerScreen.new()
		s.setup(camp, null, "jobs", 0)
		(Engine.get_main_loop() as SceneTree).root.add_child(s)
		if not s.is_inside_tree():
			s._ready()
		var card := s.find_child("CustomGig", true, false)
		if dev == 0:
			assert_true(card == null, "no custom card without developer mode")
		else:
			assert_true(card is CustomGigCard, "the card in developer mode")
			var got := []
			s.take_custom.connect(func(f: Dictionary): got.append(f))
			var take := card.find_child("TakeCustom", true, false) as Button
			take.pressed.emit()
			assert_eq(got.size(), 1, "TAKE hands the form on")
			assert_eq(got[0], CustomGig.defaults(), "all auto")
			assert_true((card.find_child("Repeat", true, false) as Button).disabled, "nothing to repeat yet")
		s.free()
	GameSettings.dev_override = -1
	GameSettings.save_values(saved)


## The hidden Options toggle: five clicks on the Options heading show it; it saves dev_mode.
func test_options_hide_the_dev_toggle() -> void:
	var saved := GameSettings.load_values()
	var off := saved.duplicate()
	off.dev_mode = false
	GameSettings.save_values(off)
	Hud._fonts()
	var t := TitleScreen.new()
	t.pause = true   # the Esc menu builds without a window to scale or buses to set (the Options page is the same)
	(Engine.get_main_loop() as SceneTree).root.add_child(t)
	if not t.is_inside_tree():
		t._ready()
	t.show_page("options")
	var dev := t.find_child("DevMode", true, false) as Button
	assert_true(dev != null and not dev.visible, "hidden at first")
	var head: Label = null
	for l in t.find_children("*", "Label", true, false):
		if (l as Label).text == "OPTIONS":
			head = l
	assert_true(head != null)
	for i in TitleScreen.DEV_CLICKS:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = true
		head.gui_input.emit(ev)
	assert_true(dev.visible, "five clicks on the heading show it")
	dev.pressed.emit()
	assert_true(bool(GameSettings.load_values().dev_mode), "turned on and saved")
	assert_true(GameSettings.dev_mode())
	t.free()
	GameSettings.save_values(saved)
