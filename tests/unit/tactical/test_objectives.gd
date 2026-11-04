extends TestCase
## Objectives as plug-in modules (data/gen/objectives.json + src/tactical/objectives/).


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func test_every_registered_kind_loads_sets_up_and_reports() -> void:
	for kind in Objective.kinds():
		var m := SceneGen.generate(11, "lone_building", {"security": 2, "site": "corp_office"})
		var dice := Dice.new(7)
		var e := Encounter.setup(m, dice, _crew(dice), String(kind))
		assert_eq(String(e.objective.kind), String(kind), "%s: the module is the one asked for" % kind)
		assert_true(e.obj is Objective, "%s: a module" % kind)
		assert_true(e.objective == e.obj.o, "%s: one state dictionary, shared" % kind)
		assert_true(e.obj.hud_text().begins_with("OBJECTIVE") or e.obj.hud_text().begins_with("CHARGE"), "%s: a HUD line" % kind)
		for mk in e.obj.marks(false):
			assert_true(mk.get("extract", false) or (mk.has("cell") and mk.has("label") and String(mk.tone) in ["gold", "red", "cyan"]), "%s: well-formed marks" % kind)
		e.next_turn()
		assert_eq(e.state, "playing", "%s: playable" % kind)


func test_unknown_kinds_play_as_elimination() -> void:
	var m := SceneGen.generate(7, "street_block", {"security": 1})
	var dice := Dice.new(5)
	var e := Encounter.setup(m, dice, _crew(dice), "no_such_job")
	assert_eq(String(e.objective.kind), "eliminate")


func test_every_gig_kind_maps_to_a_registered_objective() -> void:
	for gk in Campaign.OBJECTIVES:
		assert_true(String(Campaign.OBJECTIVES[gk]) in Objective.kinds(), "%s → %s" % [gk, Campaign.OBJECTIVES[gk]])


func test_objective_actions_go_through_one_interface() -> void:
	var m := SceneGen.generate(11, "lone_building", {"security": 2, "site": "gang_hideout"})
	var dice := Dice.new(7)
	var e := Encounter.setup(m, dice, _crew(dice), "snatch")
	e.next_turn()
	assert_true(e.obj_actions().is_empty(), "nothing to grab from the deploy zone")
	e.cur.pos = e.objective.cell
	assert_eq(e.obj_actions(), ["grab"] as Array[String], "beside the package: grab")
	var r := e.obj_act("grab")
	assert_true(r.ok)
	assert_eq(int(e.objective.carrier), e.cur.id)
