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
		var ht: String = e.obj.hud_text()
		assert_true(ht != "" and not ht.contains("OBJECTIVE ·") and ht == ht.to_upper(), "%s: a short upper-case order, no prefix" % kind)
		assert_true(ht.split("\n")[0].length() <= 40, "%s: the order fits one line: %s" % [kind, ht])
		for mk in e.obj.marks(false):
			assert_true(mk.get("extract", false) or (mk.has("cell") and mk.has("label") and String(mk.tone) in ["gold", "red", "cyan"]), "%s: well-formed marks" % kind)
		e.next_turn()
		assert_eq(e.state, "playing", "%s: playable" % kind)
		var acts := e.obj.actions()   # typed even when empty: the HUD's interact slot keeps it as Array[String]
		assert_true(acts.is_typed() and acts.get_typed_builtin() == TYPE_STRING, "%s: actions() is an Array[String]" % kind)
		var none := e.obj_actions()
		assert_true(none.is_typed(), "%s: obj_actions() is an Array[String]" % kind)
		e.state = "won"
		assert_true(e.obj_actions().is_typed() and e.obj_actions().is_empty(), "%s: nothing to do once it's over, still typed" % kind)
		assert_true(Hud.interact_here(e) is Array, "%s: the interact slot reads it" % kind)


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


func _job(kind: String, site := "corp_office") -> Encounter:
	var m := SceneGen.generate(11, "lone_building", {"security": 2, "site": site})
	var dice := Dice.new(7)
	var e := Encounter.setup(m, dice, _crew(dice), kind)
	e.next_turn()
	return e


func test_every_job_with_a_person_or_thing_marks_it() -> void:
	# owner: in an assassination you couldn't tell where or who the mark was. Each module names its
	# own marker target (the view only draws marks()); the label starts "★ <WHAT>" and names it.
	var want := {"data": "★ ACCESS POINT", "assassinate": "★ TARGET · ", "rescue": "★ CAPTIVE · ", "snatch": "★ PACKAGE", "sabotage": "★ SABOTAGE · "}
	for kind in want:
		var e := _job(kind)
		for fog in [false, true]:
			var mk: Array = e.obj.marks(fog)
			assert_eq(mk.size(), 1, "%s (fog %s): one marker" % [kind, fog])
			if mk.is_empty():
				continue
			assert_true(String(mk[0].label).begins_with(want[kind]), "%s: %s" % [kind, mk[0].label])
			assert_true(mk[0].cell is Vector3i and e.m.inb(mk[0].cell.x, mk[0].cell.y), "%s: on the map" % kind)
	var a := _job("assassinate")
	assert_true(String(a.obj.marks(true)[0].label).contains(String(a.objective.name).to_upper()), "the mark is named")
	assert_true(a.obj.hud_text().contains(String(a.objective.name).to_upper()), "and so is the objective line")
	var r := _job("rescue")
	assert_eq(r.obj.marks(true)[0].cell, r.units[int(r.objective.captive)].pos, "over the captive")
	var s := _job("sabotage")
	assert_eq(s.obj.marks(true)[0].cell, s.objective.cell, "over the machine")
	var sl := String(s.obj.marks(true)[0].label)
	assert_true(sl.contains(String(s.objective.name).trim_prefix("the ").to_upper()), "names the machine: " + sl)


func test_the_mark_is_shown_where_the_crew_last_knew_them() -> void:
	var e := _job("assassinate")
	var vip: Dictionary = e.units[int(e.objective.target)]
	var intel: Vector3i = e.objective.intel
	assert_eq(intel, vip.pos, "the fixer's intel: the room the mark is in")
	e.vision.visible.erase(vip.pos)
	var mk: Dictionary = e.obj.marks(true)[0]
	assert_eq(mk.cell, intel, "unseen: marked at the briefed spot")
	assert_true(String(mk.label).ends_with("LAST SEEN"), "and says it's intel, not a live fix")
	assert_false(mk.has("unit"), "an unseen mark isn't tied to the unit (the view would give them away)")
	var moved: Vector3i = vip.pos + Vector3i(1, 0, 0)
	vip.pos = moved   # slips off unseen: the marker stays on the old fix
	e.vision.visible.erase(moved)
	e.obj.before_check()
	assert_eq(e.obj.marks(true)[0].cell, intel, "moves unseen: still the old fix")
	assert_eq(e.obj.marks(false)[0].cell, moved, "fog off: always the live square")
	e.vision.visible[moved] = true   # spotted
	e.obj.before_check()
	mk = e.obj.marks(true)[0]
	assert_eq(mk.cell, moved, "in sight: the live square")
	assert_eq(int(mk.get("unit", -1)), int(vip.id), "and rides the unit")
	assert_false(String(mk.label).contains("LAST SEEN"))
	e.vision.visible.erase(moved)
	vip.pos = moved + Vector3i(0, 1, 0)
	e.obj.before_check()
	assert_eq(e.obj.marks(true)[0].cell, moved, "out of sight again: where they were last seen")
	vip.c.dead = true
	e.objective.done = true
	assert_true(bool(e.obj.marks(true)[0].get("extract", false)), "down: the marker moves to the extraction zone")


func test_elimination_points_at_the_last_known_hostile_when_none_is_in_sight() -> void:
	var e := _job("eliminate", "gang_hideout")
	var left := e.opfor()
	assert_false(left.is_empty())
	e.vision.visible.clear()
	e.objective.erase("seen")
	assert_true(e.obj.marks(true).is_empty(), "never seen: no intel, no marker")
	var g: Dictionary = left[0]
	e.vision.visible[g.pos] = true
	e.obj.before_check()
	assert_true(e.obj.marks(true).is_empty(), "a hostile in sight is its own marker")
	var seen_at: Vector3i = g.pos
	e.vision.visible.clear()
	var mk: Array = e.obj.marks(true)
	assert_eq(mk.size(), 1, "out of sight: an arrow to where they were")
	if mk.is_empty():
		return
	assert_eq(mk[0].cell, seen_at)
	assert_true(String(mk[0].label).begins_with("★ HOSTILE · %d LEFT" % left.size()), String(mk[0].label))
	assert_eq(e.obj.marks(false).size(), 1, "fog off: the nearest hostile")


func test_gang_hit_names_the_gang() -> void:
	var El = load("res://src/tactical/objectives/eliminate.gd")
	assert_eq(El.target_name("Tyger Claws"), "THE TYGER CLAWS")
	assert_eq(El.target_name("Maelstrom"), "MAELSTROM")
	assert_eq(El.target_name("The Bozos"), "THE BOZOS")
	assert_eq(El.target_name("6th Street"), "6TH STREET")
	assert_eq(El.target_name(""), "ALL HOSTILES")
