extends TestCase
## The between-gigs screens build on the dev demo campaign and their buttons drive the model:
## a market BUY puts one in storage, CARRY moves a weapon from storage to the selected loadout,
## Recover heals. (Layout is checked by screenshots; this checks the wiring.)


func _open(s: SafehouseScreen, camp: Campaign, tab := "") -> SafehouseScreen:
	Hud._fonts()
	s.setup(camp, null, tab, 0)   # no portraits: they render 3D busts, which needs a live tree
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	if not s.is_inside_tree():   # the test runner's tree isn't live yet: build by hand
		s._ready()
	return s


func _buttons(n: Node, prefix: String) -> Array[Button]:
	var out: Array[Button] = []
	for b in n.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(prefix) and not (b as Button).disabled and not b.is_queued_for_deletion():
			out.append(b)
	return out


func test_every_screen_builds() -> void:
	var camp := DemoState.make()
	for pair in [[FixerScreen.new(), "jobs"], [FixerScreen.new(), "hire"], [FixerScreen.new(), "market"],
			[StorageScreen.new(), "loadouts"], [StorageScreen.new(), "workshop"], [MedBayScreen.new(), "ripperdoc"],
			[MedBayScreen.new(), "therapy"], [MedBayScreen.new(), "injuries"], [TrainingScreen.new(), ""], [CrewScreen.new(), ""]]:
		var s := _open(pair[0], camp, pair[1])
		assert_true(s.get_child_count() > 1, "%s/%s built" % [s.get_script().get_global_name(), pair[1]])
		assert_false(_buttons(s, "‹  BACK TO SAFEHOUSE").is_empty(), "the same BACK button on every screen")
		s.free()
	var d := DebriefScreen.new()
	d.report = DemoState.report(camp)
	_open(d, camp)
	assert_true(_buttons(d, "‹  BACK").is_empty(), "the debrief has CONTINUE instead")
	assert_false(_buttons(d, "CONTINUE").is_empty())
	d.free()
	assert_true(camp.has_meta("demo"), "the demo campaign is marked so screens never save it")


func test_market_buy_goes_to_storage() -> void:
	var camp := DemoState.make()
	var s := _open(FixerScreen.new(), camp, "market")
	var buys := _buttons(s, "BUY · ")
	assert_false(buys.is_empty())
	var eb := camp.eb
	var total := 0
	for k in camp.stash:
		total += int(camp.stash[k])
	buys[0].pressed.emit()
	var after := 0
	for k in camp.stash:
		after += int(camp.stash[k])
	assert_eq(after, total + 1, "one more item in storage")
	assert_true(camp.eb < eb, "paid for it")
	assert_true(camp.log[-1].begins_with("Bought "))
	s.free()


func test_carry_and_recover_buttons() -> void:
	var camp := DemoState.make()
	var s := _open(StorageScreen.new(), camp, "loadouts")
	var c: Combatant = camp.alive_crew()[0]
	var n := c.weapons.size()
	var carry := _buttons(s, "CARRY")
	assert_false(carry.is_empty())
	carry[0].pressed.emit()
	assert_eq(c.weapons.size(), n + 1, "the selected crew member carries it")
	s.free()
	var cs := _open(CrewScreen.new(), camp)
	var rec := _buttons(cs, "RECOVER UNTIL HEALED")
	assert_false(rec.is_empty())
	rec[0].pressed.emit()
	assert_eq(camp.days_to_recover(), 0, "everyone healed")
	cs.free()
