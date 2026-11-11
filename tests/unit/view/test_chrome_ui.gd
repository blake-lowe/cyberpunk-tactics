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
	assert_eq(s.loc, "borgware", "↑ wraps")
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
	for loc in Cyber.LOCS:
		assert_eq((body.cards[loc] as Control).get_meta("pips").size(), _expected(c.implants, loc), "read-only markers at " + loc)
	var texts := _texts(lo)
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
	var opts := s._install_choices(c, "skill_chip")
	assert_eq(opts.map(func(o): return o[1]), ["Stealth", "Handgun"], "one option per chip in storage, by its Skill")
	assert_eq(camp.install_block(c, "skill_chip", "chipware"), "", "a chip is in storage")
	_buttons(_live(s, "Stored_skill_chip")[0], "INSTALL")[0].pressed.emit()
	assert_eq(s._choose, "skill_chip", "asks which first")
	_buttons(_live(s, "Stored_skill_chip")[0], "STEALTH")[0].pressed.emit()
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
## silhouette) in its own body region (the eyes on the eyes, the ear on the ear, the Fashionware on
## the left forearm...), and every bone runs over the figure. On screen each keeps an anchor per
## location (head over chest over legs, the character's right on the viewer's left), between the
## card columns so no leader line runs back under its card; the figure fills the height, clear of
## the cards, at the Med Bay's and the loadout's sizes; the regions take chrome's violet and the
## selected location's gold; and under reduced motion the glitch holds still.
func test_plates_anchor_on_the_body() -> void:
	var want := {"neural_link": ChromeBody.Reg.HEAD, "right_eye": ChromeBody.Reg.R_EYE, "left_eye": ChromeBody.Reg.L_EYE,
		"cyberaudio": ChromeBody.Reg.EAR, "chipware": ChromeBody.Reg.NECK, "internal": ChromeBody.Reg.TORSO,
		"borgware": ChromeBody.Reg.L_ARM, "right_arm": ChromeBody.Reg.R_ARM, "left_arm": ChromeBody.Reg.L_ARM,
		"fashion": ChromeBody.Reg.L_FORE, "external": ChromeBody.Reg.R_LEG, "right_leg": ChromeBody.Reg.R_LEG,
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
		assert_eq((g.anchors as Dictionary).size(), Cyber.LOCS.size(), "%s: an anchor per location" % pl)
		for loc in Cyber.LOCS:
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
			assert_eq(a.size(), Cyber.LOCS.size(), "%s %s: an anchor per location" % [body, sz])
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
