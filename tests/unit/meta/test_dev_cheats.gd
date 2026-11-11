extends TestCase
## DEV ONLY: the safehouse dev menu (DevMenu, DevCheats). Only in developer mode; money and items
## land where the game keeps them (eb, storage under the Night Market's keys); every cheat is logged
## and marks the campaign; a cheated save loads back whole.


func _open(camp: Campaign) -> DevMenu:
	Hud._fonts()
	var s := DevMenu.new()
	s.setup(camp, null, "", 0)
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	if not s.is_inside_tree():
		s._ready()
	return s


func _live(n: Node, name: String) -> Array:
	return n.find_children(name, "", true, false).filter(func(x: Node) -> bool:
		var p := x
		while p:
			if p.is_queued_for_deletion():
				return false
			p = p.get_parent()
		return true)


func test_hidden_without_developer_mode() -> void:
	GameSettings.dev_override = 0
	assert_false(BaseView.dev_tools(), "no dev tools")
	var bv := BaseView.new()
	bv.open_screen("dev")
	assert_true(bv._screen == null, "the hub won't open the dev menu")
	bv.free()
	var s := _open(DemoState.make())
	assert_true(_live(s, "Add").is_empty() and _live(s, "Eb10000").is_empty(), "the menu itself offers nothing")
	s.free()
	GameSettings.dev_override = 1
	assert_true(BaseView.dev_tools(), "developer mode: the DEV button and key")
	GameSettings.dev_override = -1


func test_money_buttons_add_eb_and_mark_the_campaign() -> void:
	GameSettings.dev_override = 1
	var camp := DemoState.make()
	var eb := camp.eb
	var s := _open(camp)
	(_live(s, "Eb10000")[0] as Button).pressed.emit()
	assert_eq(camp.eb, eb + 10000, "+10k")
	assert_eq(camp.dev_cheats, 1, "marked")
	assert_eq(camp.log[-1], "[DEV] +10,000 eb.", "logged")
	var field: SpinBox = _live(s, "EbField")[0]
	field.value = 250
	(_live(s, "EbSet")[0] as Button).pressed.emit()
	assert_eq(camp.eb, 250, "SET")
	(_live(s, "Heal")[0] as Button).pressed.emit()
	assert_true(camp.alive_crew().all(func(c: Combatant) -> bool: return c.hp == c.max_hp() and c.injuries.is_empty()), "everyone healed")
	(_live(s, "Humanity")[0] as Button).pressed.emit()
	assert_true(camp.alive_crew().all(func(c: Combatant) -> bool: return c.humanity == c.max_humanity), "Humanity back")
	var ip := camp.crew[0].ip
	(_live(s, "Ip100")[0] as Button).pressed.emit()
	assert_eq(camp.crew[0].ip, ip + 100)
	var rep := camp.crew[1].reputation
	(_live(s, "Rep")[0] as Button).pressed.emit()
	assert_eq(camp.crew[1].reputation, rep + 1)
	(_live(s, "DayField")[0] as SpinBox).value = 40
	(_live(s, "DaySet")[0] as Button).pressed.emit()
	assert_eq(camp.day, 40)
	assert_eq(camp.dev_cheats, 7)
	s.free()
	GameSettings.dev_override = -1


func test_every_category_lands_in_storage_under_its_key() -> void:
	var cats := DevCheats.CATS.map(func(c): return String(c[0])).filter(func(c): return c != "all")
	for cat in cats:
		var items := DevCheats.filter(cat, "")
		assert_false(items.is_empty(), "%s: something to add" % cat)
		for e in items:
			for v in (e.variants as Array) if not (e.variants as Array).is_empty() else [["", ""]]:
				var k := DevCheats.key_for(e, String(v[0]))
				assert_true(Items.is_stored(k), "%s is a storage key" % k)
	var camp := Campaign.new_game(3)
	var want := {"weapon": "weapon/heavy_pistol@excellent", "armor": "armor/kevlar", "ammo": "ammo/flashbang_ammo",
		"drugs": "drugs/synthcoke", "cyberware": "cyberware/skill_chip@handgun", "deck": "gear/cyberdeck_standard",
		"programs": "programs/sword", "hardware": "hardware/" + String(DevCheats.filter("hardware", "")[0].key).get_slice("/", 1)}
	var unmodelled := DevCheats.catalog().filter(func(e): return String(e.cat) == "cyberware" and String(e.note) == "unmodelled")
	assert_false(unmodelled.is_empty(), "unmodelled cyberware is on the list too")
	want["unmodelled"] = String(unmodelled[0].key)
	var popup := DevCheats.catalog().filter(func(e): return String(e.key) == "cyberware/popup_ranged_weapon")
	assert_eq(popup.size(), 1, "the popup gun")
	want["popup"] = DevCheats.key_for(popup[0], String(popup[0].default))
	for cat in want:
		var k := String(want[cat])
		assert_true(DevCheats.give(camp, k, 2), "%s: %s added" % [cat, k])
		assert_eq(camp.stored(k), 2, "%s in storage ×2" % k)
	assert_false(DevCheats.give(camp, "weapon/no_such_gun"), "storage holds only real items")
	# the menu's own Add, on a filtered row with a variant picked
	GameSettings.dev_override = 1
	var demo := DemoState.make()
	var s := _open(demo)
	s.cat = "weapon"
	s.query = "heavy pistol"
	s._build()
	var row: Node = _live(s, "Row_weapon_heavy_pistol")[0]
	var opt: OptionButton = row.find_child("Variant", true, false)
	opt.select(2)
	opt.item_selected.emit(2)
	var before := demo.stored("weapon/heavy_pistol@excellent")
	(row.find_child("Add", true, false) as Button).pressed.emit()
	assert_eq(demo.stored("weapon/heavy_pistol@excellent"), before + 1, "the picked quality")
	s.free()
	GameSettings.dev_override = -1


func test_search_narrows_the_list() -> void:
	var all := DevCheats.filter("all", "")
	var chips := DevCheats.filter("all", "skill chip")
	assert_true(chips.size() >= 1 and chips.size() < all.size())
	assert_true(DevCheats.filter("cyberware", "handgun").any(func(e): return String(e.key) == "cyberware/skill_chip"), "a choice's name finds its piece")
	assert_true(DevCheats.filter("armor", "pistol").is_empty(), "the tab filters too")


func test_a_cheated_save_loads_back() -> void:
	var camp := Campaign.new_game(9)
	DevCheats.add_eb(camp, 100000)
	var keys := ["weapon/assault_rifle@poor", "cyberware/skill_chip@handgun", "programs/sword", "gear/cyberdeck_excellent"]
	var unmod := DevCheats.catalog().filter(func(e): return String(e.cat) == "cyberware" and String(e.note) == "unmodelled" and (e.variants as Array).is_empty())
	keys.append(String(unmod[0].key))
	for k in keys:
		assert_true(DevCheats.give(camp, k, 3), k)
	DevCheats.set_day(camp, 20)
	var back := Campaign.from_dict(JSON.parse_string(JSON.stringify(camp.to_dict())))
	assert_true(back != null, "loads")
	assert_eq(back.eb, camp.eb)
	assert_eq(back.day, 20)
	for k in keys:
		assert_eq(back.stored(k), 3, "%s kept" % k)
	assert_eq(back.dev_cheats, camp.dev_cheats, "the dev mark kept")
	assert_true(SaveSlots.describe(SaveSlots.meta_for(back)).where.contains("dev cheats"), "the slot says so")
	assert_true(camp.save(SaveSlots.path(4)), "writes")
	var loaded := Campaign.load_from(SaveSlots.path(4))
	assert_eq(loaded.stored(keys[1]), 3, "through the file too")
