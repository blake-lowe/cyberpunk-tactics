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
		if (b as Button).text.begins_with(prefix) and not (b as Button).disabled and not _stale(b):
			out.append(b)
	return out


## Part of a layout a rebuild has thrown away (it or an ancestor is queued for deletion).
func _stale(n: Node) -> bool:
	while n:
		if n.is_queued_for_deletion():
			return true
		n = n.get_parent()
	return false


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


func test_market_cyberware_has_a_buy_button_and_goes_to_storage() -> void:
	var camp := DemoState.make()
	var s := _open(FixerScreen.new(), camp, "market")
	var chrome: Array = camp.market_stock().filter(func(x): return x.kind == "cyberware" and not x.staple)
	assert_false(chrome.is_empty(), "the demo market has cyberware")
	var price := UiKit.price_text("BUY", int(chrome[0].cost))
	assert_true(_buttons(s, "RIPPERDOC").is_empty(), "no separate ripperdoc button: bought like other gear")
	var before := camp.cyberware_options().size()
	var n0 := camp.stored(String(chrome[0].key))
	for b in _buttons(s, price):
		var row := b.get_parent().get_parent()
		if row.find_children("*", "Label", true, false).any(func(l): return (l as Label).text == UiKit.caps(String(chrome[0].name))):
			b.pressed.emit()
			break
	assert_eq(camp.stored(String(chrome[0].key)), n0 + 1, "the piece goes into storage")
	assert_true(camp.cyberware_options().size() >= before)
	for l in s.find_children("*", "Label", true, false):
		assert_false((l as Label).text.contains("OF EXACTLY") or (l as Label).text.contains("OR LESS"), "no listing sub-headings: %s" % (l as Label).text)
	s.free()


func test_ripperdoc_installs_from_storage_and_removes_on_a_second_press() -> void:
	var camp := DemoState.make()
	var c: Combatant = camp.alive_crew()[0]
	camp.stash["cyberware/cybereye"] = 1
	c.cyberware.erase("cybereye")
	var s := _open(MedBayScreen.new(), camp, "ripperdoc")
	var eb := camp.eb
	var inst := _buttons(s, "INSTALL")
	assert_false(inst.is_empty())
	var n := c.cyberware.size()
	inst[0].pressed.emit()
	assert_eq(c.cyberware.size(), n + 1, "installed on the selected crew member")
	assert_eq(camp.eb, eb, "free (p338)")
	var rm := _buttons(s, "REMOVE")
	assert_false(rm.is_empty())
	rm[0].pressed.emit()
	assert_eq(c.cyberware.size(), n + 1, "the first press only asks")
	var confirm := _buttons(s, "DESTROY IT")
	assert_eq(confirm.size(), 1)
	confirm[0].pressed.emit()
	assert_eq(c.cyberware.size(), n, "the second takes it out")
	s.free()


func test_consumable_and_utility_terms() -> void:
	var camp := DemoState.make()
	var s := _open(StorageScreen.new(), camp, "loadouts")
	var texts: Array = s.find_children("*", "Label", true, false).map(func(l): return (l as Label).text)
	texts.append_array(s.find_children("*", "Button", true, false).map(func(b): return (b as Button).text))
	assert_true("CONSUMABLE" in texts and "UTILITY" in texts)
	assert_false(texts.any(func(t): return String(t).contains("PACK") or String(t).begins_with("KIT ")), "no PACK/UNPACK or KIT 1/2")
	assert_false(_buttons(s, "EQUIP").is_empty())
	s.free()


func test_equip_and_recover_buttons() -> void:
	var camp := DemoState.make()
	var s: StorageScreen = _open(StorageScreen.new(), camp, "loadouts")
	var c: Combatant = camp.alive_crew()[0]
	var n := c.weapons.size()
	assert_true(_buttons(s, "CARRY").is_empty() and _buttons(s, "WEAR").is_empty(), "one verb: EQUIP")
	s._select_slot("wadd")
	var eq := _buttons(s, "EQUIP · ENTER")
	assert_eq(eq.size(), 1, "one EQUIP, in the detail panel")
	var key := s.pick
	assert_true(Items.is_weapon(key), "the weapon slot picks a weapon from storage")
	eq[0].pressed.emit()
	assert_eq(c.weapons.size(), n + 1, "the selected crew member carries it")
	assert_eq(s.slot, "w%d" % n, "the new weapon's slot is selected")
	assert_true(_buttons(s, "MED BAY").size() >= 1, "installed chrome goes to the Med Bay, not storage")
	var st := _buttons(s, "STORE CURRENT · DEL")
	assert_eq(st.size(), 1)
	st[0].pressed.emit()
	assert_eq(c.weapons.size(), n, "STORE puts it back")
	assert_eq(camp.stored(key), 1)
	s.free()
	var cs := _open(CrewScreen.new(), camp)
	var rec := _buttons(cs, "RECOVER UNTIL HEALED")
	assert_false(rec.is_empty())
	rec[0].pressed.emit()
	assert_eq(camp.days_to_recover(), 0, "everyone healed")
	cs.free()


func test_armor_goes_to_the_clicked_slot_and_the_list_follows_the_slot() -> void:
	var camp := DemoState.make()
	var s: StorageScreen = _open(StorageScreen.new(), camp, "loadouts")
	var c: Combatant = camp.alive_crew()[0]
	s._select_slot("head")
	assert_true(s._keys.all(func(k): return Items.is_armor(k)), "the head slot lists armour")
	assert_eq(s.pick, "armor/leathers")
	var old := Items.key_of_armor(c.armor.head)
	_buttons(s, "EQUIP · ENTER")[0].pressed.emit()
	assert_eq((c.armor.head as ArmorPiece).id, "leathers", "worn on the head: the slot that was clicked")
	assert_eq(camp.stored(old), 1, "what was there goes to storage")
	assert_false(_buttons(s, "UPGRADE +1 SP").is_empty(), "the Workshop upgrade is in the armour slot's detail")
	s._select_slot("k1")
	assert_true(s._keys.all(func(k): return Items.fits(1, k)), "the utility slot lists utilities")
	s._pick("ammo/flashbang_ammo")
	assert_eq(s.slot, "k0", "picking a consumable under ALL selects the consumable slot")
	s.free()


func _key(s: SafehouseScreen, code: Key, ctrl := false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	ev.ctrl_pressed = ctrl
	s._unhandled_input(ev)


func test_armory_keyboard() -> void:
	var camp := DemoState.make()
	var s: StorageScreen = _open(StorageScreen.new(), camp, "loadouts")
	var crew := camp.alive_crew()
	_key(s, KEY_E)
	assert_eq(s.sel, 1, "E: next crew member")
	_key(s, KEY_Q)
	_key(s, KEY_Q)
	assert_eq(s.sel, crew.size() - 1, "Q wraps round")
	_key(s, KEY_E)
	var c: Combatant = crew[0]
	var first := c.weapons[0].id()
	_key(s, KEY_DOWN)
	assert_eq(s.slot, "w1", "↓: next slot")
	_key(s, KEY_UP, true)
	assert_eq(c.weapons[0].id(), "heavy_pistol", "Ctrl+↑ draws it first")
	assert_eq(s.slot, "w0", "the selection follows the weapon")
	assert_eq(c.weapons[1].id(), first)
	_key(s, KEY_DELETE)
	assert_eq(camp.stored("weapon/heavy_pistol"), 2, "Del stores the slot's item")
	_key(s, KEY_RIGHT)
	var picked := s.pick
	_key(s, KEY_ENTER)
	assert_eq(camp.stored(picked), 1 if picked == "weapon/heavy_pistol" else 0, "Enter equips the picked item")
	var closed := []
	s.closed.connect(func(): closed.append(true))
	_key(s, KEY_ESCAPE)
	assert_eq(closed.size(), 1, "Esc goes back")
	s.free()
