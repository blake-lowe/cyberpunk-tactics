extends TestCase
## Gig actions from the owner's playtest (2026-11-11): the Esc menu's Options mid-gig, JACK IN only
## where it works, OPEN / CLOSE DOOR, the camera's two-strike sighting, DISABLE CAMERA beside the
## camera (and its outline target), and chrome melee weapons (Wolvers) in the attack menu. Scan is
## in test_access_points.gd, flee-or-hide Morale in test_morale.gd.

static var _maps := {}


func _map(sec := 1) -> TacMap:
	if not _maps.has(sec):
		_maps[sec] = SceneGen.generate(11, "lone_building", {"site": "corp_office", "security": sec})
	return _maps[sec]


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


## A stealth gig (the detection clock runs) with the crew's first member up.
func _enc(clocks: Variant = "auto") -> Encounter:
	var dice := Dice.new(3)
	var o := {"clocks": clocks, "security_code": {"n": 11, "faction": "", "intensity": "medium", "hardened": false}}
	var e := Encounter.setup(_map(), dice, _crew(dice), "data", o)
	e.cur = e.units[0]
	e.turn = TurnState.begin(e.dice, e.cur.c)
	return e


func _texts(n: Node) -> Array:
	return n.find_children("*", "Button", true, false).map(func(b): return (b as Button).text.to_lower())


# --- 1. The Esc menu mid-gig -------------------------------------------------------------------

func test_the_gig_esc_menu_offers_options_and_no_save() -> void:
	var t := TitleScreen.new()
	t.pause = true
	t.in_gig = true
	(Engine.get_main_loop() as SceneTree).root.add_child(t)
	if not t.is_inside_tree():
		t._ready()
	var main := _texts(t)
	for want in ["resume", "options", "title", "quit"]:
		assert_true(main.has(want), "the gig menu has %s (%s)" % [want, main])
	assert_false(main.has("save"), "a gig is never saved half-played")
	assert_false(main.has("load"))
	t.show_page("options")
	assert_true(t.find_children("*", "HSlider", true, false).size() >= 4, "the title screen's volumes and shake")
	assert_true(t.find_child("ReducedMotion", true, false) != null)
	t.show_page("main")
	assert_true(_texts(t).has("options"), "Back returns to the gig menu")
	t.free()
	var s := TitleScreen.new()   # the safehouse's Esc menu gains Options too
	s.pause = true
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	if not s.is_inside_tree():
		s._ready()
	assert_true(_texts(s).has("options") and _texts(s).has("save"))
	s.free()


# --- 4. JACK IN only where it works ------------------------------------------------------------

func test_jack_in_shows_only_in_range_of_an_access_point() -> void:
	var e := _enc(false)
	var runner: Dictionary = e.units[1]
	var solo: Dictionary = e.units[0]
	e.cur = runner
	e.turn = TurnState.begin(e.dice, runner.c)
	var ap: Vector3i = AccessPoints.all(e)[0].cell
	runner.pos = ap
	assert_true(Hud.jack_shown(e), "beside (on) an access point")
	var far := Vector3i(-1, -1, -1)
	for y in e.m.h:
		for x in e.m.w:
			var v := Vector3i(x, y, ap.z)
			if e.m.walkable(v.z, Vector2i(x, y)) and Los.distance_m(v, ap) > 30.0:
				far = v
	runner.pos = far
	assert_true(e.jack_points(runner).is_empty())
	assert_false(Hud.jack_shown(e), "out of range: hidden")
	runner.pos = ap
	assert_true(e.jack_in(e.jack_points(runner)[0]))
	assert_true(Hud.jack_shown(e), "jacked in: JACK OUT stays")
	e.cur = solo
	solo.pos = ap
	assert_false(Hud.jack_shown(e), "never for a non-Netrunner")


# --- 5. Doors ----------------------------------------------------------------------------------

## A closed, unlocked door and a free square beside it (side by side).
func _door(e: Encounter) -> Array:
	var occ := e.occupied()
	for d in e.m.doors:
		var v := Vector3i(d.pos.x, d.pos.y, d.floor)
		if e.nav.locked.has(v) or e.los.open_doors.has(v) or e.m.t(v.z, v.x, v.y) != TacMap.T.DOOR or occ.has(v):
			continue
		for dd in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0)]:
			var s := Vector3i(v.x + dd.x, v.y + dd.y, v.z)
			if e.m.inb(s.x, s.y) and e.m.walkable(s.z, Vector2i(s.x, s.y)) and e.m.t(s.z, s.x, s.y) != TacMap.T.DOOR and not occ.has(s):
				return [v, s]
	return []


func test_open_and_close_a_door_for_free() -> void:
	var e := _enc(false)
	var ds := _door(e)
	assert_false(ds.is_empty(), "a door to work")
	var door: Vector3i = ds[0]
	var u: Dictionary = e.cur
	u.pos = ds[1]
	var d := e.door_in_reach(u)
	assert_eq(d.cell, door)
	assert_false(bool(d.open))
	assert_eq(Hud.door_action(e)[0], "OPEN DOOR")
	assert_eq(e.los.blocker(door), "wall", "closed: blocks sight")
	var move0 := e.turn.squares_available()
	assert_true(e.toggle_door().ok)
	assert_true(e.los.open_doors.has(door))
	assert_eq(e.los.blocker(door), "", "open: sight passes")
	assert_true(e.turn.action_available, "HOUSE-RULE: no Action")
	assert_eq(e.turn.squares_available(), move0, "nor any movement")
	assert_eq(Hud.door_action(e)[0], "CLOSE DOOR")
	assert_true(e.events.any(func(ev): return String(ev.type) == "door" and bool(ev.open)))
	# someone in the doorway: it won't shut on them
	var o: Dictionary = e.units[1]
	var was: Vector3i = o.pos
	o.pos = door
	assert_false(e.toggle_door().ok, "someone's in the way")
	assert_true(String(Hud.door_action(e)[2]) != "", "the button says why")
	o.pos = was
	assert_true(e.toggle_door().ok)
	assert_false(e.los.open_doors.has(door), "closed again")
	assert_eq(e.los.blocker(door), "wall")


func test_a_locked_door_wont_open_by_hand() -> void:
	var e := _enc(false)
	var ds := _door(e)
	var door: Vector3i = ds[0]
	e.cur.pos = ds[1]
	e.nav.locked[door] = true
	assert_false(e.toggle_door().ok, "needs a bypass, a keycard or the NET")
	assert_false(e.los.open_doors.has(door))
	assert_eq(Hud.door_action(e)[0], "OPEN DOOR")
	assert_true(String(Hud.door_action(e)[2]).begins_with("Locked"), "shown, but dimmed with the reason")


func test_closing_a_door_hides_what_is_behind_it() -> void:
	var e := _enc(false)
	var ds := _door(e)
	var door: Vector3i = ds[0]
	var u: Dictionary = e.cur
	u.pos = ds[1]
	var beyond: Vector3i = door + (door - Vector3i(ds[1]))   # the square past the door, straight through
	for o in e.units:
		if o != u and o.team == 0:
			o.pos = u.pos   # the rest of the crew out of the picture (same square: eyes on one spot)
	e.toggle_door()
	e.refresh_vision()
	var seen_open := e.vision.visible.has(beyond)
	e.toggle_door()
	assert_false(e.los.open_doors.has(door))
	if e.m.walkable(beyond.z, Vector2i(beyond.x, beyond.y)):
		assert_true(seen_open, "open: the room beyond is in view")
		assert_false(e.vision.visible.has(beyond), "closed: out of view at once")


# --- 3. Cameras: flagged first, a guard on the second sighting ---------------------------------

func _camera_on(e: Encounter, u: Dictionary) -> int:
	var at := Vector2i(-1, -1)
	for dd in [Vector2i(3, 0), Vector2i(-3, 0), Vector2i(0, 3), Vector2i(0, -3), Vector2i(2, 2), Vector2i(-2, -2)]:
		var c := Vector3i(u.pos.x + dd.x, u.pos.y + dd.y, u.pos.z)
		if e.m.inb(c.x, c.y) and e.m.walkable(c.z, Vector2i(c.x, c.y)) and not e.los.wall_between(c, u.pos):
			at = Vector2i(c.x, c.y)
			break
	e.m.devices.append({"id": e.m.devices.size(), "type": "camera", "pos": at, "floor": u.pos.z, "group": "cameras", "ir": true})
	var d: Dictionary = e.m.devices[-1]
	e._cam_facing[d.id] = Vector2.ZERO   # sees all round: the test is about what a sighting does
	return int(d.id)


func test_a_camera_flags_first_and_sends_a_guard_the_second_time() -> void:
	var e := _enc()
	var c := Clocks.get_clock(e, "detection")
	assert_true(c != null, "a stealth gig: the clock runs")
	var u: Dictionary = e.cur
	u.c.skills["stealth"] = 0
	var cam := _camera_on(e, u)
	assert_true(e.camera_sees(e.m.devices[cam], u.pos))
	var rolls0 := c.rolls
	var first := false
	for k in 40:   # a new round each time (the roll is once per camera, crew member and round)
		e._spot_rolls.clear()
		e._clock_hits.clear()
		var g := e._camera_spots()
		if (e.cam_flagged.get(cam, {}) as Dictionary).has(u.id):
			assert_true(g.is_empty(), "the first sighting sends nobody")
			first = true
			break
	assert_true(first, "the camera catches a clumsy sneak")
	assert_eq(e.alarm, 0, "no alarm")
	assert_false(e.units.any(func(o): return bool(o.get("alerted", false)) and int(o.team) == Encounter.OPFOR), "nobody roused")
	assert_true(c.rolls > rolls0, "the detection clock rolled (a failed Stealth check)")
	assert_true(e.events.any(func(ev): return String(ev.type) == "camera_seen"), "the view flags it")
	var sent := {}
	for k in 40:
		e._spot_rolls.clear()
		e._clock_hits.clear()
		sent = e._camera_spots()
		if not sent.is_empty():
			break
	assert_false(sent.is_empty(), "caught again: a guard comes")
	assert_true(e.events.any(func(ev): return String(ev.type) == "camera"))
	assert_eq(Hud.camera_toast("Patch", ""), "CAMERA SPOTTED PATCH · FLAGGED")
	assert_eq(Hud.camera_toast("Patch", "Guard 3"), "CAMERA SPOTTED PATCH AGAIN · GUARD 3 IS ON THE WAY")


func test_a_camera_rolls_once_a_round() -> void:
	var e := _enc()
	var u: Dictionary = e.cur
	u.c.skills["stealth"] = 0
	var cam := _camera_on(e, u)
	e._camera_spots()
	var st := e.dice.rng.state
	for k in 5:
		assert_true(e._camera_spots().is_empty(), "the same round: no second roll, no guard")
	assert_eq(e.dice.rng.state, st, "no dice spent")
	assert_true(cam >= 0)


# --- 6. Disable camera -------------------------------------------------------------------------

func test_disable_camera_works_beside_the_camera_at_the_books_dv() -> void:
	var e := _enc(false)
	var u: Dictionary = e.cur
	var p: Vector3i = u.pos
	assert_eq(Encounter.CAMERA_TAMPER_DV, 9, "Observation Cameras: DV9 to counter (p.213)")
	assert_eq(Encounter.CAMERA_REACH, 1)
	assert_eq(int(Clocks.db().reclaim.range), Encounter.CAMERA_REACH, "SPOOF has the same reach")
	var spot := Vector2i(-1, -1)
	for dx in [1, -1]:
		if e.m.inb(p.x + dx, p.y) and e.m.walkable(p.z, Vector2i(p.x + dx, p.y)) and e.m.inb(p.x + 2 * dx, p.y) and e.m.walkable(p.z, Vector2i(p.x + 2 * dx, p.y)):
			spot = Vector2i(p.x + dx, p.y)
	assert_true(spot.x >= 0, "room for a camera beside")
	e.m.devices.append({"id": e.m.devices.size(), "type": "camera", "pos": spot, "floor": p.z, "group": "cameras"})
	var cam: int = e.m.devices[-1].id
	assert_eq(int(e.camera_in_reach(u).get("id", -1)), cam, "beside it: in reach")
	assert_eq(Hud.interact_here(e)[1], "DISABLE CAMERA", "named for what it does")
	assert_eq(Hud.interact_device(e), cam, "the camera the hovered button outlines")
	assert_true(Hud.interact_card(e, "interact").contains("DV9"), "its card gives the roll")
	u.pos = Vector3i(spot.x + (spot.x - p.x) * 2, spot.y, p.z)
	if e.m.inb(u.pos.x, u.pos.y) and Vector2i(u.pos.x, u.pos.y).distance_to(spot) >= 2:
		assert_true(e.camera_in_reach(u).is_empty(), "two squares off: out of reach")
	u.pos = p
	u.c.skills["electronics_security_tech"] = 10
	var done := false
	for k in 10:
		e.turn = TurnState.begin(e.dice, u.c)
		var r := e.tamper_camera()
		assert_true(r.ok)
		if r.success:
			done = true
			break
	assert_true(done)
	assert_true(e.disabled_devices.has(cam))
	assert_eq(Hud.interact_device(e), -1, "nothing left to outline")


# --- 7. Chrome melee weapons in the attack menu ------------------------------------------------

func test_a_solo_with_wolvers_finds_them_in_the_attack_menu() -> void:
	var c: Combatant = null
	for s in 60:
		var r := Recruit.generate(Dice.new(s), "solo", "edgerunner", "Vex")
		if r.has_cyberware("wolvers"):
			c = r
			break
	assert_true(c != null, "a Solo recruit rolls Wolvers (the Role's chrome list)")
	var tabs := Hud.weapon_tabs(c)
	var claws: Array = tabs.filter(func(w): return w != null and w.chrome == "wolvers")
	assert_eq(claws.size(), 1, "the attack menu lists them")
	var w: Weapon = claws[0]
	assert_eq(w.display_name(), "Wolvers", "by their name, not 'Heavy Melee Weapon'")
	assert_true(w.is_melee() and w.builtin)
	assert_eq(w.dice(), 3, "a Heavy Melee Weapon: 3d6 (p.364)")
	assert_eq(Encounter.attack_modes(w), ["melee"] as Array[String])
	# in a gig: drawn and used on someone beside them
	var dice := Dice.new(5)
	var crew: Array[Combatant] = [c]
	var e := Encounter.setup(_map(), dice, crew)
	var me: Dictionary = e.units[0]
	var foe: Dictionary = e.units.filter(func(o): return int(o.team) == Encounter.OPFOR and not o.has("turret"))[0]
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0)]:
		var v: Vector3i = me.pos + d
		if e.m.inb(v.x, v.y) and e.m.walkable(v.z, Vector2i(v.x, v.y)) and not e.occupied().has(v) and not e.los.wall_between(me.pos, v):
			foe.pos = v
			break
	e.cur = me
	e.turn = TurnState.begin(dice, me.c)
	var inhand: Weapon = me.c.weapons.filter(func(x): return x.chrome == "wolvers")[0]
	e.draw(inhand)
	assert_eq(me.c.weapons[0], inhand, "drawn")
	assert_true(e.preview(foe, inhand, Attack.Mode.SINGLE).ok, "a melee attack with them")


func test_every_chrome_melee_piece_is_its_own_weapon_and_survives_a_save() -> void:
	var c := Combatant.new("X", {"BODY": 6, "MOVE": 6, "REF": 6, "DEX": 6, "TECH": 5, "COOL": 5, "WILL": 5, "LUCK": 5, "INT": 5, "EMP": 5}, {})
	for id in ["cyberarm", "wolvers", "big_knucks", "cybersnake", "talon_foot", "vampyres"]:
		c.install_cyberware(id, null, true)
	var names := c.weapons.map(func(w): return w.display_name())
	for want in ["Wolvers", "Big Knucks", "Cybersnake", "Talon Foot", "Excellent Vampyres"]:
		assert_true(names.has(want), "%s in %s" % [want, names])
	var back := Combatant.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.weapons.map(func(w): return w.display_name()), names, "the same weapons, in order, after a save")
	assert_true(c.remove_cyberware("big_knucks"))
	assert_false(c.weapons.any(func(w): return w.chrome == "big_knucks"), "taken out: its weapon goes")
	assert_true(c.weapons.any(func(w): return w.chrome == "wolvers"), "the others stay")
	# an older save kept only the hardest-hitting built-in weapon: the rest come back on load
	var d := c.to_dict()
	d.weapons = (d.weapons as Array).filter(func(wd): return String(wd.get("chrome", "")) != "cybersnake")
	for wd in d.weapons:
		wd.erase("chrome")
	var old := Combatant.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_true(old.weapons.any(func(w): return w.chrome == "cybersnake"), "a piece's missing weapon is rebuilt")
	assert_true(old.weapons.any(func(w): return w.chrome == "wolvers"), "an old entry is matched to its piece")
	assert_eq(old.weapons.filter(func(w): return w.builtin).size(), 4)
