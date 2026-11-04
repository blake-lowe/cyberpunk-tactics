extends TestCase
## What the player sees around a gig on the map: the place and floor labels, the end-of-gig headline
## and the debrief's wording (which must agree), and a turret's stat card.

const GREYBOX := preload("res://src/tactical/greybox.gd")


func test_floor_and_place_labels() -> void:
	var m := TacMap.new(4, 4, 3)
	assert_eq(GREYBOX.floor_label(m, 0), "FLOOR 1")
	m.params["scene"] = "lone_building"
	assert_eq(GREYBOX.place_label(m, {}, "skirmish"), "lone building", "a dev map by its scene")
	var c := DemoState.make()
	var g: Dictionary = c.board[0]
	assert_eq(GREYBOX.place_label(m, g, "skirmish"), Campaign.place_name(g), "a board gig by its place")
	var e := SceneGen.generate(3, "lone_building", {"setpiece": "the_estates", "variant": "1d"})
	assert_true(GREYBOX.place_label(e, {}, "").contains("Kerry Eurodyne"), "an estate by its owner: " + GREYBOX.place_label(e, {}, ""))


func test_the_end_headline_and_the_debrief_agree() -> void:
	for st in ["won", "fled", "lost"]:
		var b: Dictionary = GREYBOX.end_banner(st)
		assert_true(String(b.text).begins_with(String(b.head)), "the banner starts with the headline")
		assert_eq(bool(b.good), st == "won", st)
		assert_eq(String(DebriefScreen.outcome({"won": st == "won", "state": st})[0]).to_upper(), String(b.head), "the debrief says the same: " + st)
	assert_eq(String(GREYBOX.end_banner("fled").head), "GIG ABANDONED")


func test_resolve_reports_how_the_map_ended() -> void:
	var c := DemoState.make()
	assert_false(c.accept(0).is_empty(), "the demo crew takes the first offer")
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
	assert_eq(String(DebriefScreen.outcome(r)[0]), "Gig abandoned")


func test_a_turret_card_has_rounds_and_no_row_of_zero_stats() -> void:
	var t := Turret.make(1)
	var card := Hud.stat_block(t, false)
	assert_false(card.contains("[table"), "a turret has no STATs to show")
	assert_true(card.contains("%d/%d" % [t.weapons[0].ammo, int(t.weapons[0].def.get("mag", 0))]), "its rounds left")
	var p := Recruit.generate(Dice.new(3), "solo", "edgerunner", "Vex")
	assert_true(Hud.stat_block(p, false).contains("[table"), "a person keeps the STAT line")
