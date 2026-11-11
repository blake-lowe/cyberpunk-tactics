extends TestCase
## The cyberware silhouette (ChromeBody) in the Med Bay's ripperdoc and on the loadout screen:
## its slot markers follow the slot model (Cyber.capacity / used / free_slots), a blocked install
## says why, INSTALL and DESTROY IT go through Campaign, and chrome whose effect isn't played yet is
## shown and named like any other (owner, 2026-11-11). Layout is checked by screenshots.


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
		{"id": "cybereye", "loc": "right_eye"}, {"id": "targeting_scope", "loc": "right_eye"}, {"id": "microoptics", "loc": "right_eye"},
		{"id": "subdermal_grip", "loc": "right_arm"}, {"id": "cyberarm", "loc": "left_arm"}, {"id": "skin_weave", "loc": "external"}]
	var states := func(loc: String) -> Array: return ChromeBody.pips(imp, loc).map(func(p): return String(p.state))
	assert_eq(states.call("right_eye"), ["filled", "filled", "empty"], "two options (one not played yet: filled all the same), a free slot")
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
	assert_eq(ChromeBody.line(imp, "right_eye"), "Cybereye · Targeting Scope · " + Cyber.display("microoptics"), "the unplayed MicroOptics is named")
	assert_eq(ChromeBody.line(imp, "left_eye"), "Meat")
	assert_eq(ChromeBody.line([{"id": "biomonitor", "loc": "fashion"}], "fashion"), "Biomonitor", "never \"Occupied\"")
	assert_eq(ChromeBody.line([{"id": "cyberleg", "loc": "right_leg"}], "right_leg"), "Cyberleg", "an unplayed foundation by its name")
	# the cards' lines (owner, playtest): the foundation, greyed "not installed" without one, then the pieces
	assert_eq(ChromeBody.foundation_line(imp, "right_eye"), ["Cybereye", true])
	assert_eq(ChromeBody.foundation_line(imp, "left_eye"), ["Cybereye · not installed", false])
	assert_eq(ChromeBody.foundation_line([], "neural_link"), ["Neural Link · not installed", false], "no Neural Link: greyed")
	assert_eq(ChromeBody.foundation_line(imp, "chipware"), ["Chipware Socket", true])
	assert_eq(ChromeBody.foundation_line(imp, "right_arm"), ["Cyberarm · not installed", false], "a meat arm")
	assert_eq(ChromeBody.foundation_line(imp, "internal"), ["", false], "the open categories take no foundation")
	assert_eq(ChromeBody.options_line(imp, "right_eye"), "Targeting Scope · " + Cyber.display("microoptics"))
	assert_eq(ChromeBody.options_line(imp, "right_arm"), Cyber.display("subdermal_grip"), "a meat arm's one piece")
	assert_eq(ChromeBody.options_line(imp, "internal"), "Empty")
	assert_eq(ChromeBody.options_line(imp, "left_eye"), "")


func test_med_bay_markers_match_capacity_for_every_crew_member() -> void:
	var camp := DemoState.make()
	for i in camp.alive_crew().size():
		var c: Combatant = camp.alive_crew()[i]
		var s := _open(MedBayScreen.new(), camp, "ripperdoc", i)
		var body := _body(s)
		assert_true(body != null, "the silhouette")
		assert_eq(body.cards.size(), ChromeBody.LOCS.size(), "a card per shown location")
		assert_false(body.cards.has("borgware"), "no Borgware card (descoped)")
		for loc in ChromeBody.LOCS:
			var card: Control = body.cards[loc]
			var ps: Array = card.get_meta("pips")
			assert_eq(ps.size(), _expected(c.implants, loc), "%s: %s" % [c.display_name, loc])
			var pr := card.find_child("Pips", true, false)
			assert_eq(pr.get_child_count() if pr else 0, ps.size(), "one marker per slot")
			assert_eq((card.find_child("Heading", true, false) as Label).text, UiKit.caps(String(ChromeBody.CATEGORY[loc])), "%s: headed by its book category" % loc)
			var side := card.find_child("Side", true, false) as Label
			assert_eq(side.text if side else "", UiKit.caps(String(ChromeBody.SIDE.get(loc, ""))), "%s: left/right kept for eyes, arms, legs" % loc)
			var fnd := card.find_child("Foundation", true, false) as Label
			if ChromeBody.FOUNDATION.has(loc):
				var fl := ChromeBody.foundation_line(c.implants, loc)
				assert_eq(fnd.text.replace("\n", " · "), String(fl[0]), "%s: its foundation line" % loc)
				assert_eq(fnd.get_theme_color("font_color") == Hud.TEXT, bool(fl[1]), "%s: greyed when not installed" % loc)
			else:
				assert_true(fnd == null, "%s: no foundation" % loc)
		var hum: Control = _live(s, "Humanity")[0]
		assert_eq([int(hum.get_meta("value")), int(hum.get_meta("max"))], [c.humanity, c.max_humanity], "Humanity stays on screen, as a bar")
		s.free()


func test_blocked_install_says_why() -> void:
	var camp := DemoState.make()
	var c: Combatant = camp.alive_crew()[2]   # a Cybereye already in the right eye
	assert_eq(Cyber.foundation_at(c.implants, "right_eye"), "cybereye")
	camp.stash["cyberware/cybereye"] = 1
	camp.stash["cyberware/anti_dazzle"] = 2   # paired: two in storage, a cybereye in each eye
	var s: MedBayScreen = _open(MedBayScreen.new(), camp, "ripperdoc", 2)
	s._select_loc("right_eye")
	assert_true(_live(s, "InstallFoundation").is_empty(), "a cybereye already: no INSTALL CYBEREYE")
	s._open_picker("slot")
	assert_true(_live(s, "Stored_cybereye").is_empty(), "a free slot lists options, not another cybereye")
	var row := _live(s, "Stored_anti_dazzle")
	assert_eq(row.size(), 1, "the stored option for the eye is listed")
	var why := camp.install_block(c, "anti_dazzle", "right_eye")
	assert_eq(why, "Needs two cybereyes")
	var blocked := (row[0] as Node).find_child("Blocked", true, false) as Label
	assert_true(blocked != null, "a blocked install shows its reason")
	assert_eq(blocked.text, UiKit.caps("⚠ " + why))
	assert_true(_buttons(row[0], "INSTALL").is_empty(), "and no INSTALL")
	s._select_loc("left_eye")
	assert_true(s._picker == "", "another place closes the picker")
	_buttons(s, "INSTALL CYBEREYE")[0].pressed.emit()
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
	# the keyboard: the first free slot is picked; Enter opens storage filtered to it
	assert_eq(s._pick, "slot")
	_key(s, KEY_ENTER)
	assert_eq(s._picker, "slot")
	_buttons(_live(s, "Stored_skin_weave")[0], "INSTALL")[0].pressed.emit(); _confirm_install(s)
	assert_true(c.implant("skin_weave", "external").size() > 0, "installed on the skin")
	assert_eq(s._picker, "", "the picker closes")
	assert_eq(camp.stored("cyberware/skin_weave"), 0, "out of storage")
	assert_true(c.humanity < hum, "Humanity Loss")
	assert_true(camp.log[-1].contains("Skin Weave installed"), camp.log[-1])
	# the installed piece is the first choice; Del asks, Enter destroys it
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
	assert_eq(bl.text if bl else "", "⚠ " + UiKit.caps(camp.remove_block(c, "neural_link", "neural_link")), "a removal block in plain words")
	assert_true(bl.text.contains("INTERFACE PLUGS"), "naming the piece that holds it, played yet or not: " + bl.text)
	# the unplayed piece comes out like any other, and then the foundation can
	assert_true(camp.remove(c, "interface_plugs", "neural_link"), "Interface Plugs out first")
	s._select_loc("neural_link")
	assert_true((_live(s, "Installed_neural_link")[0] as Node).find_child("Blocked", true, false) == null, "the empty Neural Link isn't blocked")
	assert_eq(_buttons(_live(s, "Installed_neural_link")[0], "REMOVE").size(), 1, "REMOVE offered")
	assert_true(camp.remove(c, "neural_link", "neural_link"), "and it comes out")
	s.free()


func test_keyboard_moves_between_places_and_crew() -> void:
	var camp := DemoState.make()
	var s: MedBayScreen = _open(MedBayScreen.new(), camp, "ripperdoc")
	s._select_loc("neural_link")
	_key(s, KEY_DOWN)
	assert_eq(s.loc, "chipware", "↓: the next place on the body")
	_key(s, KEY_UP)
	_key(s, KEY_UP)
	assert_eq(s.loc, "fashion", "↑ wraps (no Borgware stop)")
	_key(s, KEY_E)
	assert_eq(s.sel, 1, "E: next crew member")
	var closed := []
	s.closed.connect(func(): closed.append(true))
	_key(s, KEY_ESCAPE)
	assert_eq(closed.size(), 1, "Esc goes back")
	s.free()


## Owner, 2026-11-11: chrome whose effect isn't played yet isn't hidden while it's being built: the
## Med Bay and the loadout screen name it, its pips are filled, and it comes out like any piece.
func test_unplayed_pieces_show_by_name() -> void:
	var camp := DemoState.make()
	var c: Combatant = camp.alive_crew()[2]   # an unplayed Biomonitor (its TeleOptics play since phase 1)
	assert_false(Cyber.modelled("biomonitor"), "the demo crew member carries unplayed chrome")
	var s: MedBayScreen = _open(MedBayScreen.new(), camp, "ripperdoc", 2)
	s._select_loc("fashion")
	assert_true(_texts(s).any(func(t): return String(t).to_upper() == "BIOMONITOR"), "named on the Med Bay")
	assert_eq(_live(s, "Installed_biomonitor").size(), 1, "an installed row of its own")
	assert_eq(_live(s, "Occupied").size(), 0, "no anonymous occupied row")
	assert_true(_body(s).cards["fashion"].get_meta("pips").all(func(p): return p.state in ["filled", "empty"]), "ordinary pips")
	assert_eq(_body(s).cards["fashion"].get_meta("pips").filter(func(p): return p.state == "filled").size(), 1, "its slot filled")
	assert_true("remove:biomonitor" in s._actions, "it can be removed")
	assert_eq(_buttons(_live(s, "Installed_biomonitor")[0], "REMOVE").size(), 1, "REMOVE offered")
	s.free()
	var lo := _loadout(camp.alive_crew(), 2)
	assert_true(_texts(lo).any(func(t): return String(t).to_upper() == "BIOMONITOR"), "named on the loadout")
	lo.free()
	var crew := _open(CrewScreen.new(), camp, "", 2)
	assert_true(_texts(crew).any(func(t): return String(t).to_upper() == "BIOMONITOR"), "and on the crew screen")
	crew.free()


func test_loadout_screen_shows_the_body_and_the_gear() -> void:
	var camp := DemoState.make()
	var crew := camp.alive_crew()
	var lo := _loadout(crew, 0)
	var c: Combatant = crew[0]
	var body := _body(lo)
	assert_true(body != null, "the silhouette")
	for loc in ChromeBody.LOCS:
		assert_eq((body.cards[loc] as Control).get_meta("pips").size(), _expected(c.implants, loc), "read-only markers at " + loc)
	var texts := _texts(lo)
	assert_false(texts.any(func(t): return String(t).contains("ESC CLOSE") or String(t).contains("↑↓")), "no key hints along the bottom")
	assert_true("WEAPONS" in texts and "ARMOR" in texts and "KIT" in texts, "the gear to the side")
	for w in c.weapons:
		assert_true(texts.any(func(t): return String(t) == (Loadout.chrome_name(c, w) if w.builtin else w.display_name())), "weapon %s listed" % w.id())
	for nm in Cyber.names(c.implants):
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
	assert_true(_body(lp).cards.values().all(func(cd): return not (cd as Control).get_meta("pips").any(func(p): return p.state == "filled")), "no filled slots")
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
	assert_true(Hud.help_text().contains("L  Loadout"), "L opens the loadout (owner, 2026-11-11): " + Hud.help_text())


## Phase 1's options step (_install_choices): a Skill Chip goes in as the Skill it was bought for.
func test_a_chip_installs_as_what_it_was_bought_for() -> void:
	var camp := DemoState.make()
	var c: Combatant = camp.alive_crew()[1]
	for k in ["cyberware/neural_link", "cyberware/chipware_socket"]:
		camp._put(k)
	if not c.has_cyberware("neural_link"):
		camp.install(c, "neural_link")
	camp.install(c, "chipware_socket")
	camp.stash["cyberware/skill_chip@stealth"] = 1
	camp.stash["cyberware/skill_chip@handgun"] = 1
	var s: MedBayScreen = _open(MedBayScreen.new(), camp, "ripperdoc", 1)
	s._select_loc("chipware")
	assert_eq(_live(s, "Slot_*").size(), 1, "one free socket: one slot card")
	s._open_picker("slot")
	var opts := s._install_choices(c, "skill_chip")
	assert_eq(opts.map(func(o): return o[1]), ["Stealth", "Handgun"], "one option per chip in storage, by its Skill")
	assert_eq(camp.install_block(c, "skill_chip", "chipware"), "", "a chip is in storage")
	_buttons(_live(s, "Stored_skill_chip")[0], "INSTALL")[0].pressed.emit()
	assert_eq(s._choose, "skill_chip", "asks which first")
	_buttons(_live(s, "Stored_skill_chip")[0], "STEALTH")[0].pressed.emit(); _confirm_install(s)
	assert_eq(String(c.implant("skill_chip").get("choice", "")), "stealth")
	assert_eq(camp.stored("cyberware/skill_chip@stealth"), 0)
	assert_eq(camp.stored("cyberware/skill_chip@handgun"), 1, "the other stays")
	assert_eq(c.skill_level("stealth"), maxi(3, int(c.skills.get("stealth", 0))))
	s._select_loc("chipware")
	var row: Node = _live(s, "Installed_skill_chip")[0]
	assert_true(_buttons(row, "DESTROY IT").is_empty() and _buttons(row, "REMOVE").is_empty(), "a chip isn't destroyed")
	_buttons(row, "TAKE OUT")[0].pressed.emit()
	assert_false(c.has_cyberware("skill_chip"))
	assert_eq(camp.stored("cyberware/skill_chip@stealth"), 1, "back in storage, no confirmation")



## A crew member of `body` ("female" or "male"): one of the demo crew with a look seed that rolls
## that body (Recruit.body_of, as CharModel does).
func _crew_of(body: String) -> Combatant:
	var c: Combatant = DemoState.make().alive_crew()[1]
	for look in 64:
		if Recruit.body_of(look) == body:
			c.look_seed = look
			return c
	return c


## The figure is the crew member's body: the woman's plate for a female body, the man's otherwise,
## the same body their 3D model is built with (CharModel's look roll).
func test_the_plate_follows_the_body_type() -> void:
	Hud._fonts()
	for body in ["female", "male"]:
		var c := _crew_of(body)
		assert_eq(Recruit.body_of(c.look_seed), body, "a %s crew member" % body)
		assert_eq(ChromeBody.plate_of(c), body, "%s: their plate" % body)
		var m := CharModel.build(0, c.look_seed, String(c.role), "heavy_pistol")
		assert_eq(String(m.look.body), body, "%s: the 3D model's body agrees" % body)
		m.free()
		var b := ChromeBody.new().setup(c, "left_arm")
		(Engine.get_main_loop() as SceneTree).root.add_child(b)
		b.size = Vector2(860, 690)
		b._layout()
		assert_eq(b._art.plate, body, "%s: the figure drawn" % body)
		assert_eq((b._art.find_child("Ink", true, false) as TextureRect).texture, BodyAnatomy.PLATES[body].ink, "%s: its ink" % body)
		b.free()
	var unset := _crew_of("male")
	unset.look_seed = -1   # no look yet (a dev gig's sample crew): the safehouse's model, seed 0
	assert_eq(ChromeBody.plate_of(unset), Recruit.body_of(0), "an unset look reads as seed 0")


## Each plate (the man's, the woman's): every anchor sits on the figure (inside the plate's
## silhouette) in its own body region (the eyes on the eyes, the ear on the ear, the Fashionware's
## light tattoo at the collarbone and the External Cyberware on the flank's skin, both on the
## trunk...), and every bone runs over the figure. On screen each keeps an anchor per
## location (head over chest over legs, the character's right on the viewer's left), between the
## card columns so no leader line runs back under its card; the figure fills the height, clear of
## the cards, at the Med Bay's and the loadout's sizes; the regions take chrome's violet and the
## selected location's gold; and under reduced motion the glitch holds still.
func test_plates_anchor_on_the_body() -> void:
	var want := {"neural_link": ChromeBody.Reg.HEAD, "right_eye": ChromeBody.Reg.R_EYE, "left_eye": ChromeBody.Reg.L_EYE,
		"cyberaudio": ChromeBody.Reg.EAR, "chipware": ChromeBody.Reg.NECK, "internal": ChromeBody.Reg.TORSO,
		"right_arm": ChromeBody.Reg.R_ARM, "left_arm": ChromeBody.Reg.L_ARM,
		"fashion": ChromeBody.Reg.TORSO, "external": ChromeBody.Reg.TORSO, "right_leg": ChromeBody.Reg.R_LEG,
		"left_leg": ChromeBody.Reg.L_LEG}
	# the parts of each figure a ripperdoc points at, each in its region (texture pixels)
	var spots := {
		"male": [[Vector2(520, 90), ChromeBody.Reg.HEAD], [Vector2(536, 600), ChromeBody.Reg.TORSO], [Vector2(150, 1200), ChromeBody.Reg.R_ARM],
			[Vector2(895, 1200), ChromeBody.Reg.L_FORE], [Vector2(810, 600), ChromeBody.Reg.L_ARM], [Vector2(420, 1300), ChromeBody.Reg.R_LEG],
			[Vector2(690, 1800), ChromeBody.Reg.L_LEG], [Vector2(360, 1960), ChromeBody.Reg.R_LEG], [Vector2(530, 300), ChromeBody.Reg.NECK]],
		# (her left arm lowered: the forearm and the hand hang by her side)
		"female": [[Vector2(440, 110), ChromeBody.Reg.HEAD], [Vector2(440, 650), ChromeBody.Reg.TORSO], [Vector2(190, 1000), ChromeBody.Reg.R_ARM],
			[Vector2(780, 860), ChromeBody.Reg.L_FORE], [Vector2(755, 690), ChromeBody.Reg.L_FORE], [Vector2(645, 470), ChromeBody.Reg.L_ARM],
			[Vector2(370, 1300), ChromeBody.Reg.R_LEG], [Vector2(520, 1700), ChromeBody.Reg.L_LEG], [Vector2(410, 1960), ChromeBody.Reg.R_LEG],
			[Vector2(435, 300), ChromeBody.Reg.NECK], [Vector2(570, 1950), ChromeBody.Reg.L_LEG]],
	}
	assert_eq(BodyAnatomy.PLATES.keys(), ["male", "female"], "two plates")
	for pl: String in BodyAnatomy.PLATES:
		var g: Dictionary = BodyAnatomy.PLATES[pl]
		var img: Image = (g.ink as Texture2D).get_image()
		assert_eq(Vector2(img.get_size()), g.size as Vector2, "%s: the geometry is in the plate's pixels" % pl)
		if img.is_compressed():
			img.decompress()
		assert_eq((g.anchors as Dictionary).size(), ChromeBody.LOCS.size(), "%s: an anchor per shown location" % pl)
		for loc in ChromeBody.LOCS:
			var p: Vector2 = g.anchors[loc]
			assert_true(img.get_pixelv(Vector2i(p)).g > 0.5, "%s %s: on the body" % [pl, loc])
			assert_eq(BodyAnatomy.region_at(p, pl), int(want[loc]), "%s %s: in its region" % [pl, loc])
		for b in g.bones:
			for k in 5:
				var q: Vector2 = (b[0] as Vector2).lerp(b[1], k / 4.0)
				assert_true(img.get_pixelv(Vector2i(q)).g > 0.5, "%s: a bone of region %d on the body at %s" % [pl, b[3], q])
		for sp in spots[pl]:
			assert_true(img.get_pixelv(Vector2i(sp[0])).g > 0.5, "%s: %s is on the body" % [pl, sp[0]])
			assert_eq(BodyAnatomy.region_at(sp[0], pl), int(sp[1]), "%s: the plate at %s" % [pl, sp[0]])
		assert_true((g.bones as Array).size() <= 24, "%s: the shader's bone arrays hold them" % pl)
		for lv: float in g.levels:
			assert_true(lv >= float(g.crown) - 0.5 and lv <= float(g.sole) + 0.5, "%s: a level within the figure" % pl)
	Hud._fonts()
	for body in ["male", "female"]:
		var c := _crew_of(body)
		for sz in [Vector2(860, 690), Vector2(690, 540), Vector2(732, 560), Vector2(640, 540), Vector2(900, 520)]:   # Med Bay 1600/1280, the loadout...
			var b := ChromeBody.new().setup(c, "left_arm", "", {}, sz.y < 600)
			(Engine.get_main_loop() as SceneTree).root.add_child(b)
			b.size = sz
			b._layout()
			assert_eq(b._art.plate, body)
			var a := b.anchors
			assert_eq(a.size(), ChromeBody.LOCS.size(), "%s %s: an anchor per shown location" % [body, sz])
			assert_true(a.neural_link.y < a.right_eye.y and a.right_eye.y < a.internal.y and a.internal.y < a.right_leg.y, "%s: head, eyes, chest, legs top to bottom" % body)
			assert_true(a.right_eye.x < a.left_eye.x and a.right_arm.x < a.left_arm.x and a.right_leg.x < a.left_leg.x, "%s: their right on the viewer's left" % body)
			for loc in ChromeBody.LEFT_COL:
				assert_true(a[loc].x > (b.cards[loc] as Control).get_rect().end.x, "%s %s %s: right of its card" % [body, sz, loc])
			for loc in ChromeBody.RIGHT_COL:
				assert_true(a[loc].x < (b.cards[loc] as Control).position.x, "%s %s %s: left of its card" % [body, sz, loc])
			if sz.x >= 690:
				assert_true(b._fig.size.y >= sz.y - 8.0, "%s %s: the figure fills the height" % [body, sz])
				for loc in ChromeBody.LEFT_COL + ChromeBody.RIGHT_COL:
					assert_false((b.cards[loc] as Control).get_rect().intersects(b._fig), "%s %s: %s clear of the figure" % [body, sz, loc])
			var t := b.region_tints()
			assert_true((t[ChromeBody.Reg.L_ARM][0] as Color).is_equal_approx(Color(Hud.GOLD, 0.8)), "the selected arm gold")
			if ChromeBody.chromed(c.implants, "neural_link"):
				assert_true((t[ChromeBody.Reg.HEAD][0] as Color).a > 0.0 and float(t[ChromeBody.Reg.HEAD][1]) > 0.0, "the Neural Link's head chromed")
			assert_eq(float(b._art._mat.get_shader_parameter("motion")), 1.0, "the glitch moves")
			assert_eq(int(b._art._mat.get_shader_parameter("selected")), ChromeBody.Reg.L_ARM, "the selected region pulses")
			b.free()
	var keep := GameSettings.load_values()
	var v := keep.duplicate()
	v.reduced_motion = true
	GameSettings.save_values(v)
	for body in ["male", "female"]:
		var r := ChromeBody.new().setup(_crew_of(body), "left_arm")
		(Engine.get_main_loop() as SceneTree).root.add_child(r)
		r.size = Vector2(860, 690)
		r._layout()
		assert_eq(float(r._art._mat.get_shader_parameter("motion")), 0.0, "%s, reduced motion: the glitch holds still" % body)
		r.free()
	GameSettings.save_values(keep)


## Her left arm, once held out with the drape, hangs lowered (owner: "change the lifted hand and arm
## pose to be lower (bend at wrist and elbow joint)"): shoulder over elbow over wrist over the hand's
## end, the forearm and hand near upright, the figure's frame no wider than the man's; the place the
## arm was held out is empty, the arm is clear of her flank, and it is on the body along every bone.
func test_her_left_arm_hangs_lowered() -> void:
	var g: Dictionary = BodyAnatomy.PLATES.female
	var img: Image = (g.ink as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	var arm: Array = (g.bones as Array).filter(func(b: Array) -> bool: return int(b[3]) in [ChromeBody.Reg.L_ARM, ChromeBody.Reg.L_FORE])
	assert_eq(arm.size(), 3, "upper arm, forearm, hand")
	for i in arm.size():
		var a: Vector2 = arm[i][0]
		var e: Vector2 = arm[i][1]
		assert_true(e.y > a.y, "each joint below the one before (%s)" % i)
		if i > 0:
			assert_true(absf((e - a).angle_to(Vector2.DOWN)) < deg_to_rad(30.0), "forearm and hand hang near upright (%s)" % i)
	var tip: Vector2 = arm[2][1]
	assert_true(tip.y > float(g.navel.y), "her hand hangs below her navel")
	assert_true((g.size as Vector2).x <= (BodyAnatomy.PLATES.male.size as Vector2).x, "no wider a frame than the man's")
	for p in [Vector2(800, 600), Vector2(850, 560)]:   # where the forearm and hand were held out
		assert_true(img.get_pixelv(Vector2i(p)).g < 0.2, "nothing left where the arm was held out (%s)" % p)
	assert_true(img.get_pixelv(Vector2i(670, 734)).g < 0.2, "the arm clear of her flank")
	assert_true(img.get_pixelv(Vector2i(760, 734)).g > 0.5, "the forearm by her side")


## The figure is always the skeletal hybrid (owner: "drop the skin on versions and baseline both the
## male and female skeleton engraving hybrid images"): on both plates the skeleton channel lights the
## whole figure, along every bone; the shader prints the skeleton with a faint body over it everywhere
## (no surface-only path left); chromed regions are violet and plated (a circuit, barer and brighter
## bones), unchromed ones cyan meat, the selected one gold; reduced motion stills it and keeps the hybrid.
func test_the_figure_is_the_skeleton_hybrid() -> void:
	for pl: String in BodyAnatomy.PLATES:
		var g: Dictionary = BodyAnatomy.PLATES[pl]
		var img: Image = (g.ink as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		for b in g.bones:
			if int(b[3]) in [ChromeBody.Reg.R_EYE, ChromeBody.Reg.L_EYE, ChromeBody.Reg.EAR]:
				continue
			var lit := 0
			for k in 9:
				var q: Vector2 = (b[0] as Vector2).lerp(b[1], k / 8.0)
				var best := 0.0
				for dy in range(-12, 13, 4):
					for dx in range(-12, 13, 4):
						var pp := Vector2i(q) + Vector2i(dx, dy)
						if pp.x >= 0 and pp.y >= 0 and pp.x < img.get_width() and pp.y < img.get_height():
							best = maxf(best, img.get_pixelv(pp).b)
				lit += 1 if best > 0.4 else 0
			assert_true(lit >= 6, "%s: the skeleton lights the bone of region %d from %s (%d/9)" % [pl, b[3], b[0], lit])
	var sh := FileAccess.get_file_as_string("res://src/ui/screens/body_anatomy.gdshader")
	assert_true(sh.contains("mix(tx.b, tx.r, sk)"), "the print is the skeleton with the body over it")
	for gone in ["dp1", "dp2", "mix(tx.r, tx.b"]:
		assert_false(sh.contains(gone), "no surface-only (skin-on) path: %s" % gone)
	assert_true(BodyAnatomy.SKIN > 0.05 and BodyAnatomy.SKIN < 0.5, "a faint body, the bones through it")
	Hud._fonts()
	for body in ["male", "female"]:
		var c := _crew_of(body)
		c.implants = [{"id": "cyberarm", "loc": "right_arm"}]
		var b := ChromeBody.new().setup(c, "left_arm")
		(Engine.get_main_loop() as SceneTree).root.add_child(b)
		b.size = Vector2(860, 690)
		b._layout()
		var m := b._art._mat
		assert_eq(float(m.get_shader_parameter("skin")), BodyAnatomy.SKIN, "%s: the hybrid" % body)
		var t := b.region_tints()
		var cols: PackedColorArray = m.get_shader_parameter("tints")
		var plated: PackedFloat32Array = m.get_shader_parameter("plated")
		assert_eq(cols.size(), ChromeBody.REGIONS, "%s: a tint per region" % body)
		for r in ChromeBody.REGIONS:
			assert_true(cols[r].is_equal_approx(t[r][0]) and is_equal_approx(plated[r], float(t[r][1])), "%s: region %d drawn as tinted" % [body, r])
		assert_true(cols[ChromeBody.Reg.R_ARM].is_equal_approx(Color(ChromeBody.CHROME, 0.85)) and plated[ChromeBody.Reg.R_ARM] == 1.0, "%s: the cyberarm violet and plated" % body)
		for r in [ChromeBody.Reg.R_LEG, ChromeBody.Reg.L_LEG, ChromeBody.Reg.HEAD, ChromeBody.Reg.TORSO]:
			assert_true(cols[r].a == 0.0 and plated[r] == 0.0, "%s: meat region %d cyan, unplated" % [body, r])
		assert_true(cols[ChromeBody.Reg.L_ARM].is_equal_approx(Color(Hud.GOLD, 0.8)), "%s: the selected arm gold" % body)
		assert_eq(int(m.get_shader_parameter("selected")), ChromeBody.Reg.L_ARM, "%s: and pulsing" % body)
		b.free()
	var keep := GameSettings.load_values()
	var v := keep.duplicate()
	v.reduced_motion = true
	GameSettings.save_values(v)
	var r := ChromeBody.new().setup(_crew_of("female"), "left_arm")
	(Engine.get_main_loop() as SceneTree).root.add_child(r)
	r.size = Vector2(860, 690)
	r._layout()
	assert_eq(float(r._art._mat.get_shader_parameter("motion")), 0.0, "reduced motion: still")
	assert_eq(float(r._art._mat.get_shader_parameter("skin")), BodyAnatomy.SKIN, "reduced motion: still the hybrid")
	r.free()
	GameSettings.save_values(keep)


## The cut figure styles are gone: one figure, no switch.
func test_one_figure_no_styles() -> void:
	var src := FileAccess.get_file_as_string("res://src/ui/screens/chrome_body.gd")
	for gone in ["style_override", "--body=", "SubViewport", "CharModel.build"]:
		assert_false(src.contains(gone), "ChromeBody has no %s" % gone)
	for path in ["res://src/ui/screens/body_vitruvian.gd", "res://src/ui/screens/holo_body.gdshader", "res://src/ui/screens/holo_glow.gdshader",
			"res://assets/third_party/vitruvian/vitruvian_ink.png", "res://src/ui/screens/body_art.gd"]:
		assert_false(FileAccess.file_exists(path), "%s removed" % path)
	assert_true(FileAccess.get_file_as_string("res://assets/third_party/anatomy_female/README.md").contains("Public Domain Mark"), "the woman's plates' licence is recorded")



# --- Owner's playtest notes (2026-11-11) ------------------------------------------------------

func _click(n: Control) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	n.gui_input.emit(ev)


## A demo campaign whose first crew member has no chrome and storage holds no cyberware.
func _bare() -> Campaign:
	var camp := DemoState.make()
	(camp.alive_crew()[0] as Combatant).implants.clear()
	for k in camp.stash.keys():
		if Items.is_cyberware(String(k)):
			camp.stash.erase(k)
	return camp


func _status(s: Node) -> String:
	return (_live(s, "Status")[0] as Label).text


## The figure keeps its look but loses the asemic notes and the gold crosshair at the navel.
func test_no_notes_or_crosshair_round_the_figure() -> void:
	var src := FileAccess.get_file_as_string("res://src/ui/screens/body_anatomy.gd")
	for gone in ["script_line", "GLYPHS", "g.notes", "_p(g.navel)"]:
		assert_false(src.contains(gone), "the figure has no %s" % gone)
	for pl: String in BodyAnatomy.PLATES:
		assert_false((BodyAnatomy.PLATES[pl] as Dictionary).has("notes"), "%s: no notes" % pl)
	for kept in ["_reg_mark(", "_dashed(", "_dim(", "g.levels"]:
		assert_true(src.contains(kept), "the rest of the page stays: %s" % kept)


## The glitch grows as Humanity falls: smoothly with Humanity / max, a little at full, strong (and
## always so) in the cyberpsychosis range, full at none. The figure's shader gets it; under reduced
## motion it holds still but keeps the strength (a still distortion).
func test_the_glitch_follows_humanity() -> void:
	var c := _crew_of("male")
	assert_true(c.tracks_humanity)
	c.max_humanity = 60
	var last := -1.0
	for h in range(60, -1, -1):
		c.humanity = h
		var g := ChromeBody.glitch_of(c)
		assert_true(g >= last - 1e-6, "no calmer as Humanity falls (%d: %.3f)" % [h, g])
		assert_true(g - maxf(last, 0.0) < 0.1, "a smooth ramp, no jumps (%d)" % h)
		last = g
	c.humanity = 60
	assert_true(ChromeBody.glitch_of(c) < 0.05, "full Humanity: barely (the shader's base fuzz)")
	c.humanity = 48
	assert_true(ChromeBody.glitch_of(c) < 0.2, "a little lost: a little more")
	c.humanity = 25
	assert_true(c.psychosis_tier() >= 1, "Humanity 25: at risk of cyberpsychosis")
	assert_true(ChromeBody.glitch_of(c) > 0.75, "at risk: clearly unsettling (%.2f)" % ChromeBody.glitch_of(c))
	c.humanity = 0
	assert_eq(ChromeBody.glitch_of(c), 1.0, "none left: all of it")
	var mook := Combatant.new()
	assert_eq(ChromeBody.glitch_of(mook), 0.0, "no Humanity tracked: the base fuzz only")
	var sh := FileAccess.get_file_as_string("res://src/ui/screens/body_anatomy.gdshader")
	for part in ["uniform float psycho", "shove", "drop", "split"]:
		assert_true(sh.contains(part), "the shader scales the glitch: %s" % part)
	Hud._fonts()
	var seen := []
	for h in [60, 25]:
		c.humanity = h
		var b := ChromeBody.new().setup(c, "left_arm")
		(Engine.get_main_loop() as SceneTree).root.add_child(b)
		b.size = Vector2(860, 690)
		b._layout()
		seen.append(float(b._art._mat.get_shader_parameter("psycho")))
		assert_near(seen[-1], ChromeBody.glitch_of(c), 1e-4, "Humanity %d: the figure's glitch" % h)
		b.free()
	assert_true(seen[1] > seen[0] + 0.5, "low Humanity glitches far harder")
	var keep := GameSettings.load_values()
	var v := keep.duplicate()
	v.reduced_motion = true
	GameSettings.save_values(v)
	var r := ChromeBody.new().setup(c, "left_arm")
	(Engine.get_main_loop() as SceneTree).root.add_child(r)
	r.size = Vector2(860, 690)
	r._layout()
	assert_eq(float(r._art._mat.get_shader_parameter("motion")), 0.0, "reduced motion: still")
	assert_near(float(r._art._mat.get_shader_parameter("psycho")), ChromeBody.glitch_of(c), 1e-4, "but as strong, held still")
	r.free()
	GameSettings.save_values(keep)


## Across the top of both screens: the name, EMP, then Humanity as a bar (current of max). The
## ripperdoc's crew cards carry neither (EMP was cut off there), and no key hints run along the bottom.
func test_the_header_shows_emp_and_a_humanity_bar() -> void:
	var camp := DemoState.make()
	var c: Combatant = camp.alive_crew()[0]
	c.humanity = c.max_humanity - 7
	var s: MedBayScreen = _open(MedBayScreen.new(), camp, "ripperdoc", 0)
	var lo := _loadout(camp.alive_crew(), 0)
	for screen: Node in [s, lo]:
		var hdr: Node = _live(screen, "Header")[0]
		assert_eq(hdr.get_children().slice(0, 3).map(func(n): return String(n.name)), ["Name", "EMP", "Humanity"], "name, EMP, Humanity in order")
		assert_eq((hdr.get_node("Name") as Label).text, c.display_name.to_upper())
		assert_eq((hdr.get_node("EMP").find_child("Value", true, false) as Label).text, str(c.raw_stat("EMP")))
		var hum: Node = hdr.get_node("Humanity")
		assert_eq((hum.find_child("Value", true, false) as Label).text, "%d/%d" % [c.humanity, c.max_humanity], "current of max")
		var bar: ChromeBody.Bar = hum.find_child("Bar", true, false)
		assert_eq([bar.value, bar.top], [c.humanity, c.max_humanity], "the bar's fill")
		assert_eq(bar.col, ChromeBody.hum_colour(c))
		assert_false(_texts(screen).any(func(t): return String(t).contains("Q/E") or String(t).contains("Q / E") or String(t).contains("↑↓")), "no key hints")
	assert_false(_texts(s).any(func(t): return String(t).contains("· EMP")), "no EMP or Humanity on the crew cards")
	s.free()
	lo.free()


## Each location's line in the panel (owner: a meat eye just "Meat."; a Cybereye "Cybereye. 3 option
## slots available", then 2 as options go in), extrapolated to every place.
func test_the_panel_says_what_a_place_holds() -> void:
	var none_in: Array = []
	assert_eq(MedBayScreen.slot_status(none_in, "left_eye"), "Meat.")
	assert_eq(MedBayScreen.slot_status(none_in, "neural_link"), "No Neural Link.")
	assert_eq(MedBayScreen.slot_status(none_in, "cyberaudio"), "No Cyberaudio Suite.")
	assert_true(MedBayScreen.slot_status(none_in, "chipware").begins_with("No Chipware Socket."))
	assert_eq(MedBayScreen.slot_status(none_in, "right_arm"), "Meat. 1 slot available.")
	assert_eq(MedBayScreen.slot_status([{"id": "wolvers", "loc": "right_arm"}], "right_arm"), "Meat. No slot available.")
	assert_eq(MedBayScreen.slot_status(none_in, "internal"), "7 option slots available.")
	var eye: Array = [{"id": "cybereye", "loc": "left_eye"}]
	assert_eq(MedBayScreen.slot_status(eye, "left_eye"), "Cybereye. 3 option slots available.")
	eye.append({"id": "targeting_scope", "loc": "left_eye"})
	assert_eq(MedBayScreen.slot_status(eye, "left_eye"), "Cybereye. 2 option slots available.")
	eye.append({"id": "teleoptics", "loc": "left_eye"})
	assert_eq(MedBayScreen.slot_status(eye, "left_eye"), "Cybereye. 1 option slot available.")
	assert_eq(MedBayScreen.slot_status([{"id": "cyberleg", "loc": "left_leg"}], "left_leg"), "Cyberleg. 3 option slots available.")
	for l in ChromeBody.LOCS:
		var st := MedBayScreen.slot_status(none_in, l)
		assert_false(st.contains("holds") or st.contains(" p."), "%s: short and plain: %s" % [l, st])


## Every free slot is a + card (none on a meat eye); a click opens storage filtered to what goes in
## that slot (not the foundation, nothing for elsewhere); installing takes one; an empty filter says so.
func test_slot_cards_and_the_filtered_picker() -> void:
	var camp := _bare()
	var c: Combatant = camp.alive_crew()[0]
	var s: MedBayScreen = _open(MedBayScreen.new(), camp, "ripperdoc", 0)
	s._select_loc("left_eye")
	assert_eq(_status(s), "Meat.")
	assert_true(_live(s, "Slot_*").is_empty(), "a meat eye has no option slots")
	c.implants.append({"id": "cybereye", "loc": "left_eye"})
	for k in ["cyberware/targeting_scope", "cyberware/teleoptics", "cyberware/cybereye", "cyberware/skin_weave"]:
		camp.stash[k] = 1
	s._build()
	assert_eq(_status(s), "Cybereye. 3 option slots available.")
	assert_eq(_live(s, "Slot_*").size(), 3, "a + card per free slot")
	var plus := (_live(s, "Slot_0")[0] as Node).find_child("Plus", true, false)
	assert_true(plus != null and (plus.get_child(0) as Label).text == "+", "a + in a small square")
	assert_true(_live(s, "Stored_*").is_empty(), "no FROM STORAGE list on the panel")
	assert_false(_texts(s).has("FROM STORAGE"))
	_click(_live(s, "Slot_1")[0])
	assert_eq(s._picker, "slot", "a click opens the picker")
	var picker: Node = _live(s, "Picker")[0]
	assert_eq(picker.get_parent(), s, "over the whole screen")
	var rows: Array = _live(picker, "Stored_*").map(func(n): return String(n.name))
	rows.sort()
	assert_eq(rows, ["Stored_targeting_scope", "Stored_teleoptics"], "only what goes in the eye's slot")
	_buttons(_live(s, "Stored_targeting_scope")[0], "INSTALL")[0].pressed.emit(); _confirm_install(s)
	assert_true(c.implant("targeting_scope", "left_eye").size() > 0, "installed")
	assert_eq(_status(s), "Cybereye. 2 option slots available.")
	assert_eq(_live(s, "Slot_*").size(), 2, "one card fewer")
	assert_true(_live(s, "Picker").is_empty(), "the picker closes")
	s._select_loc("internal")
	_click(_live(s, "Slot_0")[0])
	assert_true(_live(s, "Stored_*").is_empty())
	assert_true(_texts(s).has("Nothing in storage fits."), "an empty filter says so plainly")
	_key(s, KEY_ESCAPE)
	assert_true(_live(s, "Picker").is_empty() and s._picker == "", "Esc closes it")
	s.free()


## A meat arm or leg keeps its one slot and gets INSTALL CYBERLIMB (a meat eye INSTALL CYBEREYE, no
## Neural Link INSTALL NEURAL LINK...): disabled with a short reason when storage has none, else a
## picker of the foundations that go there.
func test_install_cyberlimb_button() -> void:
	var camp := _bare()
	var c: Combatant = camp.alive_crew()[0]
	var s: MedBayScreen = _open(MedBayScreen.new(), camp, "ripperdoc", 0)
	s._select_loc("right_arm")
	assert_eq(_status(s), "Meat. 1 slot available.")
	assert_eq(_live(s, "Slot_*").size(), 1, "the meat arm's one slot")
	var b: Button = _live(s, "InstallFoundation")[0]
	assert_eq(b.text, "INSTALL CYBERLIMB")
	assert_true(b.disabled, "none in storage")
	assert_eq((_live(s, "FoundationWhy")[0] as Label).text, "No cyberlimb in storage.")
	camp.stash["cyberware/cyberarm"] = 1
	camp.stash["cyberware/wolvers"] = 1
	s._build()
	b = _live(s, "InstallFoundation")[0]
	assert_false(b.disabled)
	assert_true(_live(s, "FoundationWhy").is_empty())
	b.pressed.emit()
	assert_eq(s._picker, "foundation")
	assert_eq(_live(s, "Stored_cyberarm").size(), 1, "the cyberarm")
	assert_true(_live(s, "Stored_wolvers").is_empty(), "not the meat arm's pieces")
	_buttons(s, "CANCEL")[0].pressed.emit()
	assert_eq(s._picker, "")
	_click(_live(s, "Slot_0")[0])
	assert_eq(_live(s, "Stored_wolvers").size(), 1, "the slot's picker: Wolvers")
	assert_true(_live(s, "Stored_cyberarm").is_empty(), "not the cyberarm")
	_key(s, KEY_ESCAPE)
	_live(s, "InstallFoundation")[0].pressed.emit()
	_buttons(_live(s, "Stored_cyberarm")[0], "INSTALL")[0].pressed.emit(); _confirm_install(s)
	assert_eq(Cyber.foundation_at(c.implants, "right_arm"), "cyberarm", "a cyberarm in the right arm")
	assert_eq(_status(s), "Cyberarm. 4 option slots available.")
	assert_true(_live(s, "InstallFoundation").is_empty(), "no button once it's chrome")
	assert_eq(_live(s, "Slot_*").size(), 4)
	var want := {"left_leg": "INSTALL CYBERLIMB", "left_eye": "INSTALL CYBEREYE", "neural_link": "INSTALL NEURAL LINK",
		"cyberaudio": "INSTALL CYBERAUDIO SUITE"}
	for l: String in want:
		s._select_loc(l)
		var fb: Button = _live(s, "InstallFoundation")[0]
		assert_eq(fb.text, want[l], l)
		assert_true(fb.disabled, "%s: none in storage" % l)
	assert_eq((_live(s, "FoundationWhy")[0] as Label).text, "No cyberaudio suite in storage.")
	for l in ["chipware", "internal", "external", "fashion"]:
		s._select_loc(l)
		assert_true(_live(s, "InstallFoundation").is_empty(), "%s: no foundation button" % l)
	s.free()


## REMOVE asks in a popup over the screen, not by growing the card: every card keeps its size. Keep
## it closes the popup; DESTROY IT takes the piece out.
func test_removal_asks_in_a_popup() -> void:
	var camp := DemoState.make()
	var c: Combatant = camp.alive_crew()[1]
	camp.stash["cyberware/skin_weave"] = 1
	camp.install(c, "skin_weave", "external")
	var s: MedBayScreen = _open(MedBayScreen.new(), camp, "ripperdoc", 1)
	s._select_loc("external")
	var row: Control = _live(s, "Installed_skin_weave")[0]
	var h0 := row.get_combined_minimum_size()
	_buttons(row, "REMOVE")[0].pressed.emit()
	var pop: Array = _live(s, "Confirm")
	assert_eq(pop.size(), 1, "a popup")
	assert_eq((pop[0] as Node).get_parent(), s, "over the screen")
	var row2: Control = _live(s, "Installed_skin_weave")[0]
	assert_eq(row2.get_combined_minimum_size(), h0, "the card keeps its size")
	assert_true(_buttons(row2, "DESTROY IT").is_empty(), "nothing added to the card")
	assert_eq(_live(s, "Slot_*").size(), 6, "the slot cards stay as they were")
	_buttons(pop[0], "KEEP IT")[0].pressed.emit()
	assert_true(_live(s, "Confirm").is_empty(), "kept: the popup closes")
	assert_true(c.implant("skin_weave", "external").size() > 0)
	_buttons(_live(s, "Installed_skin_weave")[0], "REMOVE")[0].pressed.emit()
	_buttons(_live(s, "Confirm")[0], "DESTROY IT")[0].pressed.emit()
	assert_true(c.implant("skin_weave", "external").is_empty(), "destroyed")
	assert_true(_live(s, "Confirm").is_empty())
	s.free()


## The cards stand in pair rows: the eyes, the arms, the legs side by side; the Neural Link beside
## the Cyberaudio Suite, the Chipware beside the Fashionware, the External beside the Internal
## Cyberware. A row's two cards share a y and a height; rows don't overlap; down each column the
## anchors run top to bottom, so no leader lines cross.
func test_pairs_share_a_row() -> void:
	assert_eq(ChromeBody.ROWS, [["neural_link", "cyberaudio"], ["right_eye", "left_eye"], ["chipware", "fashion"],
		["external", "internal"], ["right_arm", "left_arm"], ["right_leg", "left_leg"]])
	assert_eq(ChromeBody.LEFT_COL, ChromeBody.ROWS.map(func(r): return r[0]))
	assert_eq(ChromeBody.RIGHT_COL, ChromeBody.ROWS.map(func(r): return r[1]))
	for pl: String in BodyAnatomy.PLATES:
		var an: Dictionary = BodyAnatomy.PLATES[pl].anchors
		for col in [ChromeBody.LEFT_COL, ChromeBody.RIGHT_COL]:
			for i in range(1, col.size()):
				assert_true((an[col[i]] as Vector2).y > (an[col[i - 1]] as Vector2).y, "%s: %s's anchor below %s's" % [pl, col[i], col[i - 1]])
	Hud._fonts()
	for body in ["male", "female"]:
		var c := _crew_of(body)
		c.implants.append({"id": "cybereye", "loc": "left_eye"})
		c.implants.append({"id": "targeting_scope", "loc": "left_eye"})
		for sz in [Vector2(860, 690), Vector2(690, 540), Vector2(640, 540), Vector2(900, 520)]:
			var b := ChromeBody.new().setup(c, "left_eye", "", {}, sz.y < 600)
			(Engine.get_main_loop() as SceneTree).root.add_child(b)
			b.size = sz
			b._layout()
			var last := -INF
			for row in ChromeBody.ROWS:
				var l: Control = b.cards[row[0]]
				var r: Control = b.cards[row[1]]
				assert_eq(l.position.y, r.position.y, "%s %s: %s and %s on one row" % [body, sz, row[0], row[1]])
				assert_eq(l.size.y, r.size.y, "%s %s: %s and %s one height" % [body, sz, row[0], row[1]])
				assert_true(l.position.x < r.position.x, "the viewer's left first")
				assert_true(l.position.y >= last, "%s %s: %s below the row above" % [body, sz, row[0]])
				assert_true(l.get_rect().end.y <= sz.y + 0.5, "%s %s: inside the bottom edge" % [body, sz])
				last = l.get_rect().end.y
			b.free()


# --- Owner's second playtest round ------------------------------------------------------------

## The second press on an armed INSTALL (CONFIRM): exactly one is live.
func _confirm_install(s: Node) -> void:
	var b := _buttons(s, "CONFIRM")
	assert_eq(b.size(), 1, "INSTALL armed to CONFIRM")
	if not b.is_empty():
		b[0].pressed.emit()


## No reminder line or NIGHT MARKET link at the foot of the ripperdoc's panel.
func test_no_reminder_or_market_link_on_the_panel() -> void:
	var camp := DemoState.make()
	var s: MedBayScreen = _open(MedBayScreen.new(), camp, "ripperdoc", 0)
	var panel: Node = _live(s, "SlotPanel")[0]
	assert_false(_texts(panel).any(func(t): return String(t).begins_with("Installing is free")), "no reminder")
	assert_true(_buttons(panel, "NIGHT MARKET").is_empty(), "no market link")
	s.free()


## INSTALL arms first (CONFIRM), the second press installs; Esc, a click elsewhere or another key
## disarms; Enter follows the same two steps. The install goes into the campaign at once and the
## surgery plays over it: a bar across the new card, the figure's place flaring.
func test_install_arms_then_confirms() -> void:
	var camp := _bare()
	var c: Combatant = camp.alive_crew()[0]
	camp.stash["cyberware/toxin_binders"] = 1
	camp.stash["cyberware/nasal_filters"] = 1
	var s: MedBayScreen = _open(MedBayScreen.new(), camp, "ripperdoc", 0)
	s._select_loc("internal")
	s._open_picker("slot")
	var row: Node = _live(s, "Stored_toxin_binders")[0]
	_buttons(row, "INSTALL")[0].pressed.emit()
	assert_true(c.implant("toxin_binders").is_empty(), "the first press only arms it")
	assert_eq(_buttons(_live(s, "Stored_toxin_binders")[0], "CONFIRM").size(), 1, "INSTALL now reads CONFIRM")
	_key(s, KEY_ESCAPE)
	assert_eq(s._armed, "", "Esc disarms")
	assert_eq(s._picker, "slot", "and leaves the picker open")
	assert_true(_buttons(s, "CONFIRM").is_empty())
	_buttons(_live(s, "Stored_toxin_binders")[0], "INSTALL")[0].pressed.emit()
	_click(_live(s, "Stored_nasal_filters")[0])
	assert_eq(s._armed, "", "a click elsewhere disarms")
	# the keyboard: Enter arms, Enter again installs
	s._pick = "install:toxin_binders"
	_key(s, KEY_ENTER)
	assert_eq(s._armed, "toxin_binders", "Enter arms")
	assert_true(c.implant("toxin_binders").is_empty())
	_key(s, KEY_ENTER)
	assert_false(c.implant("toxin_binders", "internal").is_empty(), "Enter again installs, at once (deterministic)")
	assert_eq(s.last_install, {"id": "toxin_binders", "loc": "internal"}, "the surgery plays for it")
	var card: Node = _live(s, "Installed_toxin_binders")[0]
	assert_true(card.find_child("InstallBar", true, false) != null, "a progress bar across the new card")
	var fig := _body(s)
	assert_true(float(fig._art._mat.get_shader_parameter("flare")) > 0.0, "the figure's place flares")
	assert_eq(int(fig._art._mat.get_shader_parameter("flare_region")), ChromeBody.Reg.TORSO, "the internal chrome's region")
	s.free()
	assert_true(ResourceLoader.exists("res://assets/audio/sfx_surgery.wav"), "the surgery sound is generated")
	var sh := FileAccess.get_file_as_string("res://src/ui/screens/body_anatomy.gdshader")
	assert_true(sh.contains("uniform float flare") and sh.contains("flare_region"), "the shader's install flare")
	assert_eq(ChromeBody.region_of("left_arm"), ChromeBody.Reg.L_ARM)
	assert_eq(ChromeBody.region_of("fashion"), -1, "no region: a disc round the anchor")


## Under reduced motion the surgery is a still version: the bar full and a steady glow, briefly.
func test_install_presentation_under_reduced_motion() -> void:
	var keep := GameSettings.load_values()
	var v := keep.duplicate()
	v.reduced_motion = true
	GameSettings.save_values(v)
	var camp := _bare()
	camp.stash["cyberware/skin_weave"] = 1
	var s: MedBayScreen = _open(MedBayScreen.new(), camp, "ripperdoc", 0)
	s._select_loc("external")
	s._open_picker("slot")
	_buttons(_live(s, "Stored_skin_weave")[0], "INSTALL")[0].pressed.emit()
	_confirm_install(s)
	var bar: MedBayScreen.InstallBar = (_live(s, "Installed_skin_weave")[0] as Node).find_child("InstallBar", true, false)
	assert_true(bar != null and is_equal_approx(bar.t, 1.0), "the bar shown full, not sliding")
	var fig := _body(s)
	assert_eq(float(fig._art._mat.get_shader_parameter("motion")), 0.0)
	assert_near(float(fig._art._mat.get_shader_parameter("flare")), 0.35, 1e-4, "a steady glow")
	assert_eq(int(fig._art._mat.get_shader_parameter("flare_region")), -1, "the skin: round its anchor")
	s.free()
	GameSettings.save_values(keep)


## A paired option (Skate Foot, Low Light/Infrared/UV...) goes into both legs or eyes at once, two
## from storage, a slot (or two) taken on each side; it comes out of both. One in storage isn't
## enough; one cyberleg isn't either.
func test_a_paired_option_goes_into_both_sides() -> void:
	var camp := _bare()
	var c: Combatant = camp.alive_crew()[0]
	c.implants.append({"id": "cyberleg", "loc": "right_leg"})
	camp.stash["cyberware/skate_foot"] = 1
	assert_eq(camp.install_block(c, "skate_foot", "right_leg"), "Paired: needs two in storage")
	camp.stash["cyberware/skate_foot"] = 2
	assert_eq(camp.install_block(c, "skate_foot", "right_leg"), "Needs two cyberlegs")
	c.implants.append({"id": "cyberleg", "loc": "left_leg"})
	assert_eq(camp.install_block(c, "skate_foot", "left_leg"), "")
	var s: MedBayScreen = _open(MedBayScreen.new(), camp, "ripperdoc", 0)
	s._select_loc("left_leg")
	s._open_picker("slot")
	assert_true(_texts(s).any(func(t): return String(t).contains("goes into both legs")), "the picker says so")
	_buttons(_live(s, "Stored_skate_foot")[0], "INSTALL")[0].pressed.emit()
	_confirm_install(s)
	for l in Cyber.LEGS:
		assert_false(c.implant("skate_foot", l).is_empty(), "a Skate Foot in the %s" % l)
		assert_eq(Cyber.free_slots(c.implants, l), 2, "%s: one of its three slots taken" % l)
	assert_eq(camp.stored("cyberware/skate_foot"), 0, "both from storage")
	assert_true("skate_foot" in Cyber.active_ids(c.implants), "and the pair works")
	assert_true(camp.log[-1].contains("pair of Skate Foot"), camp.log[-1])
	var m := _body(s)._art._mat
	assert_eq([int(m.get_shader_parameter("flare_region")), int(m.get_shader_parameter("flare_region2"))], [ChromeBody.Reg.L_LEG, ChromeBody.Reg.R_LEG], "both legs flare")
	# out of both
	s._select_loc("right_leg")
	_buttons(_live(s, "Installed_skate_foot")[0], "REMOVE")[0].pressed.emit()
	assert_true(_texts(s).any(func(t): return String(t).contains("Skate Foot in both legs")), "the popup says both")
	_buttons(_live(s, "Confirm")[0], "DESTROY IT")[0].pressed.emit()
	for l in Cyber.LEGS:
		assert_true(c.implant("skate_foot", l).is_empty(), "out of the %s" % l)
	s.free()
	# two slots a side: Low Light / Infrared / UV, and a side without the room blocks the pair
	var eyes: Array = [{"id": "cybereye", "loc": "right_eye"}, {"id": "cybereye", "loc": "left_eye"}, {"id": "microvideo", "loc": "left_eye"}]
	c.implants.assign(eyes)
	camp.stash["cyberware/low_light_infrared_uv"] = 2
	assert_eq(camp.install_block(c, "low_light_infrared_uv", "right_eye"), "Needs 2 free slots in the left eye", "the left eye has 1 slot left of 3")
	c.implants.assign(eyes.slice(0, 2))
	assert_true(camp.install(c, "low_light_infrared_uv", "right_eye") >= 0)
	for l in Cyber.EYES:
		assert_eq(Cyber.free_slots(c.implants, l), 1, "%s: two of three slots taken" % l)


## The slot model against the book's tables (CPR core p.111-116, p.358-367): foundations' Option
## Slots, the pieces that take more (or none), the paired options, the meat-limb pieces, chipware.
func test_slot_counts_match_the_book() -> void:
	var cap := {"neural_link": 5, "cybereye": 3, "cyberaudio_suite": 3, "cyberarm": 4, "cyberleg": 3}
	for f in cap:
		assert_eq(int(Cyber.def(f).capacity), cap[f], "%s's Option Slots" % f)
	var two := ["microvideo", "low_light_infrared_uv", "medscanner", "popup_grenade_launcher", "popup_melee_weapon",
		"popup_ranged_weapon", "shoulder_cam", "techscanner", "jump_booster"]
	var three := ["dartgun", "cyberdeck", "popup_shield"]
	var none := ["standard_hand", "standard_foot", "plastic_covering", "realskinn_covering", "superchrome_covering", "sensor_array"]
	for id in Cyber.db():
		var d: Dictionary = Cyber.def(id)
		var want := 2 if id in two else 3 if id in three else 0 if (id in none or d.get("foundation", false) or String(d.host) in ["chipware", "borgware"]) else 1
		assert_eq(int(d.slots), want, "%s takes %d Option Slot(s)" % [id, want])
	var pairs := ["anti_dazzle", "image_enhance", "low_light_infrared_uv", "virtuality", "grip_foot", "jump_booster", "skate_foot", "web_foot"]
	var meat := ["big_knucks", "rippers", "scratchers", "slice_n_dice", "subdermal_grip", "tool_hand", "wolvers", "standard_hand", "talon_foot", "standard_foot"]
	for id in Cyber.db():
		assert_eq(Cyber.paired(id), id in pairs, "%s paired" % id)
		assert_eq(bool(Cyber.def(id).get("meat_ok", false)), id in meat, "%s fits a meat limb" % id)
	assert_eq(String(Cyber.def("chipware_socket").host), "neural_link", "a socket is a Neuralware option: a Neural Link slot")
	assert_eq(int(Cyber.def("chipware_socket").slots), 1)
	assert_eq(int(Cyber.def("subdermal_grip").get("neural_slot", 0)), 1, "the Grip takes a Neuralware slot too")
	for loc in ["fashion", "internal", "external"]:
		assert_eq(Cyber.capacity([], loc), 7, "%s: 7 Option Slots" % loc)
	assert_eq(Cyber.capacity([{"id": "cyberaudio_suite", "loc": "cyberaudio"}, {"id": "sensor_array", "loc": "cyberaudio"}], "cyberaudio"), 8, "a Sensor Array: 5 more")
