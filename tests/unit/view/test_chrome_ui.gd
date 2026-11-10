extends TestCase
## The cyberware silhouette (ChromeBody) in the Med Bay's ripperdoc and on the loadout screen:
## its slot markers follow the slot model (Cyber.capacity / used / free_slots), a blocked install
## says why, INSTALL and DESTROY IT go through Campaign, and chrome whose effect isn't played is
## never named (its slots show as occupied). Layout is checked by screenshots.


func _open(s: SafehouseScreen, camp: Campaign, tab := "", sel := 0) -> SafehouseScreen:
	Hud._fonts()
	s.setup(camp, null, tab, sel)
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	if not s.is_inside_tree():
		s._ready()
	return s


func _loadout(crew: Array, sel := 0) -> LoadoutScreen:
	Hud._fonts()
	var s := LoadoutScreen.new().setup(crew, sel)
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	if not s.is_inside_tree():
		s._ready()
	return s


func _stale(n: Node) -> bool:
	while n:
		if n.is_queued_for_deletion():
			return true
		n = n.get_parent()
	return false


func _live(n: Node, pattern: String, type := "") -> Array:
	return n.find_children(pattern, type, true, false).filter(func(x): return not _stale(x))


func _buttons(n: Node, prefix: String) -> Array[Button]:
	var out: Array[Button] = []
	for b in _live(n, "*", "Button"):
		if (b as Button).text.begins_with(prefix) and not (b as Button).disabled:
			out.append(b)
	return out


func _texts(n: Node) -> Array:
	var out: Array = _live(n, "*", "Label").map(func(l): return (l as Label).text)
	out.append_array(_live(n, "*", "Button").map(func(b): return (b as Button).text))
	return out


func _body(n: Node) -> ChromeBody:
	var b := _live(n, "ChromeBody", "ChromeBody")
	return b[0] if not b.is_empty() else null


func _key(s: Control, code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.pressed = true
	s._unhandled_input(ev)


## What a location's markers must be: as many pips as the Option Slots it holds (or uses, if a
## stat block overfilled it); a meat limb its one piece; no foundation yet: the slots it would open.
func _expected(implants: Array, loc: String) -> int:
	if loc == "borgware":
		return 0
	if Cyber.is_meat(implants, loc):
		return maxi(1, Cyber.meat_pieces(implants, loc).size())
	var cap := Cyber.capacity(implants, loc)
	if cap <= 0 and Cyber.used(implants, loc) == 0 and Cyber.foundation_at(implants, loc) == "":
		return int(ChromeBody.LOCKED_SLOTS.get(loc, 0))
	return maxi(cap, Cyber.used(implants, loc))


func test_pips_follow_the_slot_model() -> void:
	var imp: Array = [{"id": "neural_link", "loc": "neural_link"}, {"id": "kerenzikov", "loc": "neural_link"},
		{"id": "chipware_socket", "loc": "neural_link"}, {"id": "pain_editor", "loc": "chipware"},
		{"id": "cybereye", "loc": "right_eye"}, {"id": "targeting_scope", "loc": "right_eye"}, {"id": "teleoptics", "loc": "right_eye"},
		{"id": "subdermal_grip", "loc": "right_arm"}, {"id": "cyberarm", "loc": "left_arm"}, {"id": "skin_weave", "loc": "external"}]
	var states := func(loc: String) -> Array: return ChromeBody.pips(imp, loc).map(func(p): return String(p.state))
	assert_eq(states.call("right_eye"), ["filled", "hidden", "empty"], "a seen option, an unplayed one (occupied), a free slot")
	assert_eq(states.call("left_eye"), ["locked", "locked", "locked"], "a meat eye: the Cybereye's slots, locked")
	assert_eq(states.call("neural_link"), ["filled", "filled", "filled", "empty", "empty"], "Kerenzikov, the socket and the Grip's Neural Link slot")
	assert_eq(states.call("chipware"), ["filled"], "one chip per socket")
	assert_eq(states.call("right_arm"), ["filled"], "a meat arm holds one piece")
	assert_eq(states.call("left_arm"), ["empty", "empty", "empty", "empty"], "a cyberarm's four slots")
	assert_eq(states.call("internal").size(), 7, "seven open slots")
	assert_eq(states.call("borgware"), [], "borgware takes no slots")
	for loc in Cyber.LOCS:
		var ps := ChromeBody.pips(imp, loc)
		assert_eq(ps.size(), _expected(imp, loc), "pips at " + loc)
		var cap := Cyber.capacity(imp, loc)
		if cap > 0:
			assert_eq(ps.filter(func(p): return p.state == "empty").size(), maxi(0, Cyber.free_slots(imp, loc)), "free slots at " + loc)
	assert_eq(ChromeBody.line(imp, "right_eye"), "Cybereye · Targeting Scope", "the hidden Teleoptics isn't named")
	assert_eq(ChromeBody.line(imp, "left_eye"), "Meat")
	assert_eq(ChromeBody.line([{"id": "biomonitor", "loc": "fashion"}], "fashion"), "Occupied")


func test_med_bay_markers_match_capacity_for_every_crew_member() -> void:
	var camp := DemoState.make()
	for i in camp.alive_crew().size():
		var c: Combatant = camp.alive_crew()[i]
		var s := _open(MedBayScreen.new(), camp, "ripperdoc", i)
		var body := _body(s)
		assert_true(body != null, "the silhouette")
		assert_eq(body.cards.size(), Cyber.LOCS.size(), "a card per location")
		for loc in Cyber.LOCS:
			var card: Control = body.cards[loc]
			var ps: Array = card.get_meta("pips")
			assert_eq(ps.size(), _expected(c.implants, loc), "%s: %s" % [c.display_name, loc])
			var pr := card.find_child("Pips", true, false)
			assert_eq(pr.get_child_count() if pr else 0, ps.size(), "one marker per slot")
		assert_true(_texts(s).any(func(t): return String(t).begins_with("HUMANITY %d/%d" % [c.humanity, c.max_humanity])), "Humanity stays on screen")
		s.free()


func test_blocked_install_says_why() -> void:
	var camp := DemoState.make()
	var c: Combatant = camp.alive_crew()[2]   # a Cybereye already in the right eye
	assert_eq(Cyber.foundation_at(c.implants, "right_eye"), "cybereye")
	camp.stash["cyberware/cybereye"] = 1
	var s: MedBayScreen = _open(MedBayScreen.new(), camp, "ripperdoc", 2)
	s._select_loc("right_eye")
	var row := _live(s, "Stored_cybereye")
	assert_eq(row.size(), 1, "the Cybereye in storage is listed for the eye")
	var why := camp.install_block(c, "cybereye", "right_eye")
	assert_true(why != "")
	var blocked := (row[0] as Node).find_child("Blocked", true, false) as Label
	assert_true(blocked != null, "a blocked install shows its reason")
	assert_eq(blocked.text, UiKit.caps("⚠ " + why))
	assert_true(_buttons(row[0], "INSTALL").is_empty(), "and no INSTALL")
	s._select_loc("left_eye")
	assert_eq(_buttons(_live(s, "Stored_cybereye")[0], "INSTALL").size(), 1, "the other eye takes it")
	var card: Control = _body(s).cards["left_eye"]
	assert_true(card.find_child("Hint", true, false) != null, "the card says something in storage fits")
	s.free()


func test_install_and_remove_go_through_the_campaign() -> void:
	var camp := DemoState.make()
	var c: Combatant = camp.alive_crew()[1]
	camp.stash["cyberware/skin_weave"] = 1
	var s: MedBayScreen = _open(MedBayScreen.new(), camp, "ripperdoc", 1)
	s._select_loc("external")
	var hum := c.humanity
	_buttons(_live(s, "Stored_skin_weave")[0], "INSTALL")[0].pressed.emit()
	assert_true(c.implant("skin_weave", "external").size() > 0, "installed on the skin")
	assert_eq(camp.stored("cyberware/skin_weave"), 0, "out of storage")
	assert_true(c.humanity < hum, "Humanity Loss")
	assert_true(camp.log[-1].contains("Skin Weave installed"), camp.log[-1])
	# the keyboard: the installed piece is the first choice; Del asks, Enter destroys it
	assert_eq(s._pick, "remove:skin_weave")
	_key(s, KEY_DELETE)
	assert_eq(s._confirm, "skin_weave@external", "asked first")
	assert_true(c.implant("skin_weave", "external").size() > 0)
	assert_eq(_buttons(s, "DESTROY IT").size(), 1, "the confirmation is on the page")
	assert_true(_texts(s).any(func(t): return String(t).begins_with("Removing destroys the Skin Weave")), "and says what it costs")
	_key(s, KEY_ESCAPE)
	assert_eq(s._confirm, "", "Esc keeps it")
	_key(s, KEY_ENTER)
	_key(s, KEY_ENTER)
	assert_true(c.implant("skin_weave", "external").is_empty(), "destroyed")
	assert_eq(camp.stored("cyberware/skin_weave"), 0, "not back in storage")
	assert_true(camp.log[-1].contains("taken out"), camp.log[-1])
	# a piece something depends on says why it can't come out
	s._select_loc("neural_link")
	var nl := _live(s, "Installed_neural_link")
	assert_eq(nl.size(), 1)
	var bl := (nl[0] as Node).find_child("Blocked", true, false) as Label
	assert_eq(bl.text if bl else "", "⚠ " + UiKit.caps(MedBayScreen.plain_reason(c.implants, camp.remove_block(c, "neural_link", "neural_link"))), "a removal block in plain words")
	assert_false(bl.text.contains("INTERFACE PLUGS"), "never naming the hidden piece that holds it")
	s.free()


func test_keyboard_moves_between_places_and_crew() -> void:
	var camp := DemoState.make()
	var s: MedBayScreen = _open(MedBayScreen.new(), camp, "ripperdoc")
	s._select_loc("neural_link")
	_key(s, KEY_DOWN)
	assert_eq(s.loc, "chipware", "↓: the next place on the body")
	_key(s, KEY_UP)
	_key(s, KEY_UP)
	assert_eq(s.loc, "borgware", "↑ wraps")
	_key(s, KEY_E)
	assert_eq(s.sel, 1, "E: next crew member")
	var closed := []
	s.closed.connect(func(): closed.append(true))
	_key(s, KEY_ESCAPE)
	assert_eq(closed.size(), 1, "Esc goes back")
	s.free()


func test_hidden_pieces_never_show() -> void:
	var camp := DemoState.make()
	var c: Combatant = camp.alive_crew()[2]   # hidden Teleoptics in the right eye, a hidden Biomonitor
	var hidden: Array = c.implants.filter(func(p): return not Cyber.modelled(String(p.id))).map(func(p): return Cyber.display(String(p.id)).to_upper())
	assert_false(hidden.is_empty(), "the demo crew member carries unplayed chrome")
	var s: MedBayScreen = _open(MedBayScreen.new(), camp, "ripperdoc", 2)
	for loc in ["right_eye", "fashion"]:
		s._select_loc(loc)
		var texts := _texts(s)
		for h in hidden:
			assert_false(texts.any(func(t): return String(t).to_upper().contains(h)), "%s never named (%s)" % [h, loc])
		assert_eq(_live(s, "Occupied").size(), 1, "its slots show as occupied at " + loc)
		assert_true(_body(s).cards[loc].get_meta("pips").any(func(p): return p.state == "hidden"), "a grey occupied pip")
		assert_false(s._actions.any(func(a): return String(a).begins_with("remove:") and not Cyber.modelled(String(a).get_slice(":", 1))), "and it can't be removed")
	s.free()
	var lo := _loadout(camp.alive_crew(), 2)
	for h in hidden:
		assert_false(_texts(lo).any(func(t): return String(t).to_upper().contains(h)), "%s not on the loadout" % h)
	lo.free()


func test_loadout_screen_shows_the_body_and_the_gear() -> void:
	var camp := DemoState.make()
	var crew := camp.alive_crew()
	var lo := _loadout(crew, 0)
	var c: Combatant = crew[0]
	var body := _body(lo)
	assert_true(body != null, "the silhouette")
	for loc in Cyber.LOCS:
		assert_eq((body.cards[loc] as Control).get_meta("pips").size(), _expected(c.implants, loc), "read-only markers at " + loc)
	var texts := _texts(lo)
	assert_true("WEAPONS" in texts and "ARMOR" in texts and "KIT" in texts, "the gear to the side")
	for w in c.weapons:
		assert_true(texts.any(func(t): return String(t) == (Loadout.chrome_name(c, w) if w.builtin else w.display_name())), "weapon %s listed" % w.id())
	for nm in Cyber.shown_names(c.implants):
		assert_true(texts.any(func(t): return String(t) == nm.to_upper()), "chrome %s described" % nm)
	assert_true(_buttons(lo, "INSTALL").is_empty() and _buttons(lo, "REMOVE").is_empty(), "read-only")
	_key(lo, KEY_E)
	assert_eq(lo.sel, 1, "E: next crew member")
	_key(lo, KEY_DOWN)
	assert_eq(lo.loc, "neural_link", "↓ picks a place")
	var closed := []
	lo.closed.connect(func(): closed.append(true))
	_key(lo, KEY_ESCAPE)
	assert_eq(closed.size(), 1, "Esc closes")
	lo.free()
	# a plain crew member: meat everywhere, no chrome
	var plain := Combatant.new()
	plain.display_name = "Nobody"
	var lp := _loadout([plain])
	assert_true(_texts(lp).has("No cyberware."), "says so plainly")
	assert_true(_body(lp).cards.values().all(func(cd): return not (cd as Control).get_meta("pips").any(func(p): return p.state in ["filled", "hidden"])), "no filled slots")
	lp.free()


func test_armory_opens_the_full_loadout() -> void:
	var camp := DemoState.make()
	var s: StorageScreen = _open(StorageScreen.new(), camp, "loadouts")
	var b := _buttons(s, "FULL LOADOUT")
	assert_eq(b.size(), 1)
	b[0].pressed.emit()
	assert_eq(_live(s, "LoadoutScreen").size(), 1, "the loadout screen over the Armory")
	s.free()


func test_help_names_the_loadout_key() -> void:
	assert_true(Hud.help_text().contains("Loadout"), Hud.help_text())


## The hologram: the crew member's own model, every surface on the hologram material, each body
## vertex in its location's region, and the leader lines' anchors on the posed body's bones (head
## over chest over legs, the character's right on the viewer's left).
func test_hologram_anchors_sit_on_the_body() -> void:
	Hud._fonts()
	var camp := DemoState.make()
	var c: Combatant = camp.alive_crew()[1]
	var b := ChromeBody.new().setup(c, "left_arm")
	(Engine.get_main_loop() as SceneTree).root.add_child(b)
	b.size = Vector2(900, 520)
	b._pose()
	b._layout()
	assert_true(b._model != null, "the model is built")
	assert_false(b._model.gun.visible, "no gun on the scan")
	var regions := {}
	for mi: MeshInstance3D in b._model.find_children("*", "MeshInstance3D", true, false):
		if b._model.gun.is_ancestor_of(mi):
			continue
		assert_eq((mi.material_override as ShaderMaterial).shader, ChromeBody.HOLO, "%s on the hologram" % mi.name)
		var cols = (mi.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR] if mi.mesh is ArrayMesh else null
		if cols != null:
			for col: Color in cols:
				regions[int(round(col.r * 16.0))] = true
	for r in [ChromeBody.Reg.TORSO, ChromeBody.Reg.HEAD, ChromeBody.Reg.R_ARM, ChromeBody.Reg.L_ARM, ChromeBody.Reg.R_LEG, ChromeBody.Reg.L_LEG, ChromeBody.Reg.R_EYE, ChromeBody.Reg.L_EYE]:
		assert_true(regions.has(r), "body region %d painted" % r)
	var a := b.anchors
	assert_eq(a.size(), Cyber.LOCS.size(), "an anchor per location")
	assert_true(a.neural_link.y < a.right_eye.y and a.right_eye.y < a.internal.y and a.internal.y < a.right_leg.y, "head, eyes, chest, legs top to bottom")
	assert_true(a.right_eye.x < a.left_eye.x and a.right_arm.x < a.left_arm.x and a.right_leg.x < a.left_leg.x, "their right on the viewer's left")
	for loc in a:   # (out of the tree the idle doesn't play: a T-pose, the arms out wide)
		if not loc in ["right_arm", "left_arm", "fashion", "borgware"]:
			assert_true(b._holo.get_rect().has_point(a[loc]), "%s on the stage" % loc)
	assert_eq(ChromeBody._bone_region("LeftLowerArm"), ChromeBody.Reg.L_ARM)
	assert_eq(ChromeBody._bone_region("index_04_leaf_r"), ChromeBody.Reg.R_ARM)
	assert_eq(ChromeBody._bone_region("ball_leaf_l"), ChromeBody.Reg.L_LEG)
	assert_eq(ChromeBody._bone_region("RightShoulder"), ChromeBody.Reg.TORSO)
	b.free()
