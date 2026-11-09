extends TestCase
## The round tab, top right (owner: "consolidate the top right panel"): the objective's order, the
## one step that applies now (never the "OR ELIMINATE ALL HOSTILES" alternative), the alert state
## with its backup timer, and the clocks' dice rows: no ROUND counter, no OBJECTIVE or DETECTION
## label, no n/m count. Each objective module says its current step (Objective.current_step).


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func _job(kind: String, site := "corp_office", seed := 11, scene := "lone_building") -> Encounter:
	var m := SceneGen.generate(seed, scene, {"security": 2, "site": site})
	var dice := Dice.new(7)
	var e := Encounter.setup(m, dice, _crew(dice), kind)
	e.next_turn()
	return e


func _hud() -> Hud:
	var h := Hud.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(h)
	if not h.is_inside_tree():   # the test runner's tree isn't live yet: build by hand
		h._ready()
	return h


func _labels(n: Node) -> Array[String]:
	var out: Array[String] = []
	for l in n.find_children("*", "Label", true, false):
		if not (l as Label).is_queued_for_deletion():
			out.append((l as Label).text)
	return out


## Pretend crew member `u` is jacked into the target NET (the NET run itself isn't under test).
func _jack(e: Encounter, u: Dictionary) -> void:
	var a: NetArchitecture = e.m.architectures[int(e.objective.structure)]
	e.runs[int(u.id)] = NetRun.new(a, u.c)


func _crew_member(e: Encounter) -> Dictionary:
	return e.units.filter(func(u): return int(u.team) == Encounter.CREW and not e.is_hostage(u))[0]


func _step_ok(e: Encounter, what: String) -> void:
	var st := e.obj.current_step()
	assert_true(st != "" and st == st.to_upper(), "%s: an upper-case step: %s" % [what, st])
	assert_false(st.contains("\n") or st.begins_with("OR ") or st.contains("ELIMINATE ALL"), "%s: one step, never the alternative: %s" % [what, st])
	assert_true(st.length() <= 32, "%s: the step fits the narrow panel: %s" % [what, st])
	assert_true(e.obj.order() != "" and not e.obj.order().contains("\n"), "%s: a one-line order" % what)


# --- Every module's current step, across its phases ----------------------------------------------

func test_every_kind_has_an_order_and_a_current_step() -> void:
	for kind in Objective.kinds():
		var e := _job(String(kind))
		_step_ok(e, String(kind))


func test_data_theft_steps() -> void:
	var e := _job("data")
	assert_eq(e.obj.order(), "STEAL THE DATA")
	assert_eq(e.obj.current_step(), "GET TO AN ACCESS POINT")
	_jack(e, _crew_member(e))
	var fn: Dictionary = (e.m.architectures[int(e.objective.structure)] as NetArchitecture).nodes[int(e.objective.node)]
	assert_eq(e.obj.current_step(), "REACH NET LEVEL %d" % int(fn.zone))
	assert_true(e.obj.hud_text().contains("OR ELIMINATE"), "the full text still lists the alternative (not on the panel)")


func test_eliminate_steps() -> void:
	var e := _job("eliminate")
	var n := e.opfor().size()
	assert_eq(e.obj.current_step(), "%d HOSTILES LEFT" % n)
	for u in e.opfor().slice(1):
		u.c.dead = true
	assert_eq(e.obj.current_step(), "1 HOSTILE LEFT")


func test_snatch_and_deliver_steps() -> void:
	var e := _job("snatch")
	assert_true(e.obj.order().begins_with("RECOVER THE "), e.obj.order())
	assert_eq(e.obj.current_step(), "GRAB IT")
	e.objective.carrier = int(_crew_member(e).id)
	assert_eq(e.obj.current_step(), "GET IT TO EXTRACTION")
	assert_true(e.obj.order().begins_with("RECOVER THE "), "the order stays put")
	var d := _job("deliver")
	assert_eq(d.obj.order(), "DELIVER THE PACKAGE")
	assert_eq(d.obj.current_step(), "LEAVE IT AT THE DROP POINT")
	d.objective.carrier = -1
	assert_eq(d.obj.current_step(), "PICK IT UP")
	d.objective.delivered = true
	assert_eq(d.obj.current_step(), "REACH EXTRACTION")


func test_assassinate_steps() -> void:
	var e := _job("assassinate")
	assert_eq(e.obj.order(), "KILL %s" % String(e.objective.name).to_upper())
	assert_eq(e.obj.current_step(), "TRACK THEM DOWN")
	e.units[int(e.objective.target)].alerted = true
	assert_eq(e.obj.current_step(), "STOP THEM BEFORE THEY ESCAPE")
	e.objective.done = true
	assert_eq(e.obj.current_step(), "REACH EXTRACTION")
	assert_eq(e.obj.order(), "KILL %s" % String(e.objective.name).to_upper(), "the order stays put")


func test_rescue_steps() -> void:
	var e := _job("rescue")
	var nm := String(e.units[int(e.objective.captive)].c.display_name).to_upper()
	assert_eq(e.obj.order(), "RESCUE %s" % nm)
	assert_eq(e.obj.current_step(), "FIND AND FREE THEM")
	e.objective.freed = true
	assert_eq(e.obj.current_step(), "GET THEM TO EXTRACTION")


func test_sabotage_steps() -> void:
	var e := _job("sabotage")
	assert_eq(e.obj.order(), "DESTROY %s" % String(e.objective.name).to_upper())
	assert_eq(e.obj.current_step(), "PLANT A CHARGE ON IT")
	e.objective.planted = true
	e.objective.boom_round = e.init.round_num + 2
	assert_eq(e.obj.current_step(), "GET CLEAR · BLOWS IN 2 ROUNDS")
	e.objective.done = true
	assert_eq(e.obj.current_step(), "REACH EXTRACTION")


func test_escort_steps() -> void:
	var e := _job("escort")
	var cu: Dictionary = e.units[int(e.objective.client)]
	assert_eq(e.obj.order(), "ESCORT %s" % String(cu.c.display_name).to_upper())
	assert_eq(e.obj.current_step(), "GET THEM TO THE RENDEZVOUS")
	e.objective.met = false
	assert_eq(e.obj.current_step(), "MEET THEM INSIDE")
	e.objective.met = true
	e.objective.mode = "pickup"
	assert_eq(e.obj.current_step(), "GET THEM TO EXTRACTION")
	cu.c.hp = -1
	assert_eq(e.obj.current_step(), "THEY'RE BLEEDING OUT")


func _to_round(e: Encounter, r: int) -> void:
	while e.init.round_num < r and e.state == "playing":
		e.init.round_num += 1
		e.obj.tick()


func test_defend_steps() -> void:
	var e := _job("defend")
	var o := e.objective
	assert_true(e.obj.order().begins_with("HOLD THE "), e.obj.order())
	assert_eq(e.obj.current_step(), "TAKE COVER · THEY HIT IN 1")
	_to_round(e, 2)
	var left: int = e.obj.rounds_left()
	assert_eq(e.obj.current_step(), "HOLD %d MORE ROUNDS" % left)
	var a: Dictionary = e.opfor()[0]
	a.pos = (o.zone as Array)[0]
	for u in e.units:
		if int(u.team) == Encounter.CREW and (o.zone as Array).has(u.pos):
			u.pos = e.extract_cells.keys()[0]
	assert_eq(e.obj.current_step(), "TAKE THE ROOM BACK")


func test_plant_steps() -> void:
	var e := _job("plant")
	var o := e.objective
	var what := String(o.name).trim_prefix("the ").to_upper()
	assert_eq(e.obj.order(), "PLANT THE BUG")
	assert_eq(e.obj.current_step(), "GET TO THE %s" % what)
	o.progress = 1
	assert_eq(e.obj.current_step(), "%d MORE ACTION%s AT THE %s" % [e.obj.plant_actions() - 1, "" if e.obj.plant_actions() == 2 else "S", what])
	o.progress = 0
	if int(o.get("node", -1)) >= 0:
		_jack(e, _crew_member(e))
		assert_true(e.obj.current_step().begins_with("REACH NET LEVEL "), e.obj.current_step())


func test_distraction_steps() -> void:
	var e := _job("distraction")
	var o := e.objective
	assert_eq(e.obj.order(), "CAUSE A DISTRACTION")
	assert_eq(e.obj.current_step(), "RAISE THE ALARM")
	e.alarm = 2
	e.obj.before_check()
	assert_eq(e.obj.current_step(), "KEEP THEM BUSY %d MORE ROUNDS" % int(o.need))
	e.backup_in = 3
	e.init.round_num += int(o.need)
	assert_eq(e.obj.current_step(), "HOLD TILL %s ARRIVES" % e.backup_label)
	o.done = true
	assert_eq(e.obj.current_step(), "REACH EXTRACTION")


# --- The panel itself --------------------------------------------------------------------------

func test_panel_is_order_step_alert_only() -> void:
	var h := _hud()
	var e := _job("data")
	e.init.round_num = 3
	h.round_tab(e)
	var texts := _labels(h._round_box)
	assert_eq(texts, ["STEAL THE DATA", "GET TO AN ACCESS POINT", "UNDETECTED"], "order, step, alert: %s" % [texts])
	for t in texts:
		assert_false(t.begins_with("ROUND"), "no round counter")
		assert_false(t.contains("OR ELIMINATE"), "no alternative")
		assert_false(t.contains("OBJECTIVE") or t.contains("DETECTION"), "no labels")
	h.free()


func test_panel_alarm_has_the_backup_timer_and_no_counts() -> void:
	var h := _hud()
	var e := _job("data")
	e.alarm = 2
	e.backup_in = 2
	h.round_tab(e)
	var texts := _labels(h._round_box)
	assert_eq(texts.slice(2), ["ALARM", "%s IN 2 ROUNDS" % e.backup_label], "%s" % [texts])
	var re := RegEx.create_from_string("\\d+/\\d+")
	assert_false(texts.any(func(t): return re.search(t) != null), "no n/m count")
	h.free()


func test_clock_rows_are_bare_dice() -> void:
	var w := ClockWidget.make("detection", "DETECTION", Hud.CYAN, 6, 4, [], true)
	assert_true(w.bare)
	assert_eq(w.custom_minimum_size.y, float(ClockWidget.DIE + 10), "no label row above the dice")
	var full := ClockWidget.make("detection", "DETECTION", Hud.CYAN, 6, 4)
	assert_true(full.custom_minimum_size.y > w.custom_minimum_size.y)
	w.free()
	full.free()


func test_the_panel_is_compact() -> void:
	var h := _hud()
	var e := _job("defend")
	h.round_tab(e)
	h._round_tab.reset_size()
	assert_true(h._round_tab.get_combined_minimum_size().x <= Hud.ROUND_TAB_W + 20, "narrow: %s" % h._round_tab.get_combined_minimum_size())
	h.free()


func test_floor_stack_and_net_panel_sit_under_the_tab() -> void:
	var h := _hud()
	h.set_anchors_preset(Control.PRESET_TOP_LEFT)
	h.size = Vector2(1280, 720)
	var e := _job("data")
	h.round_tab(e)
	h.floor_stack({"name": "CORP OFFICE", "rows": [{"f": 0, "label": "1", "crew": 1, "foes": 0, "cur": true}], "up_ok": false, "down_ok": false, "hint_dir": 0})
	h._round_tab.reset_size()
	h._layout()
	var bottom := h._round_tab.position.y + h._round_tab.size.y
	assert_eq(h._round_tab.position, Vector2(1280 - h._round_tab.size.x - 14, 12), "top right corner")
	assert_true(h._stack.visible, "the stack shows")
	assert_eq(h._stack.position.y, bottom + 14, "the floor stack right under the tab")
	assert_eq(h._stack.position.x + h._stack.size.x, 1280.0 - 14, "flush right")
	h._net_panel.visible = true
	h._layout()
	assert_false(h._stack.visible, "the NET panel owns the corner while jacked in")
	assert_true(h._net_panel.position.y >= bottom + 10, "the NET panel never over the tab")
	assert_eq(h._net_panel.position.x + h._net_panel.size.x, 1280.0 - 14, "flush right")
	h.free()
