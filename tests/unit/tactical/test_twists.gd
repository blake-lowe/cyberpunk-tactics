extends TestCase
## Plot Twists (Twist; data/gen/twists.json; SPM p.75-76): the table, how often an offer gets one
## (the Oracle, HOUSE-RULE by security level), each played row's fx, when it springs, the dev
## builder's field and flag, the save, and the debrief.

const PLAYED := ["hired_muscle", "no_way_back", "police_sting", "target_escapes", "target_fights_back", "time_limit",
	"too_much_heat", "trap_location", "unexpected_ally", "unexpected_rival", "unexpected_weather"]

static var _maps := {}


func _map(sec := 2) -> TacMap:
	if not _maps.has(sec):
		_maps[sec] = SceneGen.generate(11, "lone_building", {"site": "corp_office", "security": sec})
	return _maps[sec]


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


## An encounter carrying twist `id`, its trigger `on` (default: one that never comes, so the test
## springs it by hand), on a code that always answers.
func _enc(id: String, kind := "data", on := "round99", sec := 2) -> Encounter:
	var dice := Dice.new(5)
	var t := Twist.make(Dice.new(1), Twist.row(id), -1, on)
	var e := Encounter.setup(_map(sec), dice, _crew(dice), kind, {"twist": t,
		"security_code": {"n": 11, "faction": "", "intensity": "medium", "hardened": false}})
	e.next_turn()
	return e


func test_the_table_has_the_books_fifty_rows() -> void:
	var rows := Twist.rows()
	assert_eq(rows.size(), 50, "SPM p.75-76")
	var ids := {}
	for i in rows.size():
		var r: Dictionary = rows[i]
		assert_eq([int(r.roll[0]), int(r.roll[1])], [i * 2 + 1, i * 2 + 2], "%s: two points each, in the book's order" % r.id)
		assert_false(ids.has(r.id), "unique id %s" % r.id)
		ids[r.id] = true
		var words := String(r.label).split(" ", false).size()
		assert_between(words, 2, 5, "%s: our own 2-5 word label" % r.id)
		assert_true(r.has("fx") and r.has("trigger"), "%s: an fx and a trigger" % r.id)
		assert_true(String(r.trigger.on) in Twist.TRIGGERS, "%s: a known trigger" % r.id)
		if not r.has("unmodelled"):
			for k in r.fx:
				assert_true(String(k) in Twist.FX, "%s: fx %s is implemented" % [r.id, k])
	assert_eq(Twist.enabled_rows().map(func(r): return String(r.id)), PLAYED, "the eleven rows that play")
	assert_eq(Twist.row("53").id, "police_sting", "a d100 roll finds its row")
	assert_eq(Twist.row("54").id, "police_sting")


func test_not_every_gig_has_a_twist() -> void:
	var want := {1: 0.25, 2: 0.25, 3: 0.40}   # HOUSE-RULE: a plain yes at Unlikely / Unlikely / 50-50 (SPM p.13)
	for lv in want:
		assert_near(Twist.chance(lv), float(want[lv]), 0.0001, "exact, security %d" % lv)
		var hits := 0
		for s in 4000:
			hits += int(Twist.roll(Dice.new(s + 1), {"kind": "data_theft", "security": lv}) != null)
		assert_near(hits / 4000.0, float(want[lv]), 0.03, "rolled, security %d" % lv)
	# Over real boards (mostly street jobs for a crew nobody knows): between 1 in 5 and 1 in 3.
	var offers := 0
	var twisted := 0
	for s in 30:
		var c := Campaign.new_game(s + 100)
		for k in 3:
			for g in c.board:
				offers += 1
				twisted += int(g.get("twist") is Dictionary)
			c.refresh_board()
	var rate := float(twisted) / offers
	assert_between(rate, 0.18, 0.36, "board twist rate %.2f over %d offers" % [rate, offers])


func test_a_twist_fits_its_gig_and_hides_on_the_board() -> void:
	for s in 300:
		var t: Variant = Twist.roll(Dice.new(s + 1), {"kind": "data_theft", "security": 3})
		if t != null:
			assert_true(Twist.valid(t))
			assert_false(String(t.id) in ["target_escapes", "target_fights_back", "no_way_back"], "%s needs a mark or a way out" % t.id)
			assert_true(String(t.trigger.on) in Twist.TRIGGERS)
			if String(t.trigger.on) == "round":
				assert_true(t.trigger.n is int, "a round range is rolled at offer time")
	var c := Campaign.new_game(77)
	for k in 6:
		c.refresh_board()
		Hud._fonts()
		var fs := FixerScreen.new()
		fs.camp = c
		for i in c.board.size():
			var g: Dictionary = c.board[i]
			if not g.get("twist") is Dictionary:
				continue
			var card := fs._gig_card(i, true)
			var texts := card.find_children("*", "Label", true, false).map(func(l): return String((l as Label).text).to_lower())
			assert_false(texts.any(func(x): return x.contains(String(g.twist.label).to_lower()) or x.contains("twist")), "never shown on the board card")
			card.free()
		fs.free()


func test_hired_muscle_brings_armed_reinforcements() -> void:
	var e := _enc("hired_muscle")
	var n := e.opfor().size()
	Twist.spring(e)
	var hired := e.units.filter(func(u): return u.get("twist", false) and int(u.team) == Encounter.OPFOR)
	assert_between(hired.size(), 2, 3)
	assert_eq(e.opfor().size(), n + hired.size())
	for u in hired:
		assert_true(String(u.c.display_name).begins_with("Hired Gun"))
		assert_true(u.alerted and String(u.c.block).begins_with("hardened_security_officer"), "Hardened Security Officers (RTG)")
	assert_true(e.events.any(func(ev): return String(ev.type) == "twist" and String(ev.id) == "hired_muscle"))
	assert_true(e.events.any(func(ev): return String(ev.type) == "backup"), "the view builds them")
	assert_true(e.log.any(func(l): return String(l).begins_with("Plot twist: Heavies Called In.")))


func test_no_way_back_moves_the_extraction_point() -> void:
	var e := _enc("no_way_back", "snatch")
	var old: Array = e.extract_cells.keys()
	Twist.spring(e)
	assert_true("extraction" in e.twist.applied)
	assert_false(e.extract_cells.is_empty())
	for v in e.extract_cells:
		assert_false(v in old, "the deploy zone is no way out now")
	var c0: Vector3i = old[0]
	e.units[0].pos = c0
	e.units[1].pos = old[1] if old.size() > 1 else c0
	assert_false(e.can_withdraw(), "withdrawing from the old zone doesn't work")


func test_police_sting_brings_ncpd_within_two_rounds_hostile() -> void:
	for s in 6:
		var e := _enc("police_sting")
		e.dice = Dice.new(s + 1)
		Twist.spring(e)
		assert_true(bool(e._street.get("sting", false)))
		assert_true(String(e._street.code.faction) == "ncpd")
		assert_between(e.ncpd_in, 0, 2, "fast (seed %d)" % s)
		var n := e.units.size()
		var guard := 0
		while e.ncpd_in > 0 and guard < 3:
			e.init.round_num += 1
			e._tick_backup()
			guard += 1
		assert_true(e.units.size() > n or e.units.any(func(u): return String(u.c.faction) == "ncpd"), "they arrive")
		var cop: Dictionary = e.units.filter(func(u): return String(u.c.faction) == "ncpd")[0]
		assert_true(e.hostile(int(cop.team), Encounter.CREW), "and came for the crew")


func test_target_escapes_tips_the_mark_off() -> void:
	var e := _enc("target_escapes", "assassinate")
	var mark: Dictionary = e.units[int(e.objective.target)]
	assert_false(mark.alerted)
	Twist.spring(e)
	assert_true(mark.alerted, "it runs (AI._vip runs an alerted mark)")
	assert_true(e.init.entries.any(func(x): return x.c == mark.c), "and takes turns")


func test_target_fights_back_steps_the_mark_up_a_tier() -> void:
	var e := _enc("target_fights_back", "assassinate")
	var mark: Dictionary = e.units[int(e.objective.target)]
	var was := String(mark.c.role)
	var hp_was: int = mark.c.max_hp()
	mark.c.hp -= 3
	Twist.spring(e)
	assert_eq(String(mark.c.role), String(Twist.NEXT_TIER[was]), "one tier up")
	assert_true(mark.get("fights", false), "a mark that fights instead of running")
	assert_eq(mark.c.max_hp() - mark.c.hp, 3, "the damage it had stays")
	assert_true(mark.c.max_hp() >= hp_was or mark.c.block != "", "a tougher block")
	var e2 := _enc("target_fights_back", "eliminate")
	Twist.spring(e2)
	assert_true("tier_up" in e2.twist.applied, "on a gang hit, the toughest of them")


func test_time_limit_starts_a_clock() -> void:
	var e := _enc("time_limit")
	Twist.spring(e)
	var c := Clocks.get_clock(e, "time_limit")
	assert_true(c != null and c.running() and c.size == 4)
	assert_true(e.events.any(func(ev): return String(ev.type) == "clock_new"), "its dice drop in on the HUD")


func test_too_much_heat_halves_the_response_timers() -> void:
	var e := _enc("too_much_heat")
	e.backup_in = 6
	e.ncpd_in = 9
	Twist.spring(e)
	assert_eq(e.backup_in, 3)
	assert_eq(e.ncpd_in, 5, "rounded up")
	var e2 := _enc("too_much_heat")
	e2.backup_in = -1
	e2.ncpd_in = -1
	Twist.spring(e2)
	assert_true(e2.ncpd_in > 0, "nothing coming: the street's code answers anyway")


func test_trap_location_rigs_the_site_from_the_start() -> void:
	var dice := Dice.new(5)
	var plain := Encounter.setup(_map(), dice, _crew(dice))
	var e := _enc("trap_location", "data", "start")
	assert_true(bool(e.twist.sprung), "springs as the gig starts")
	var traps: Array = e.m.devices.filter(func(d): return d.get("trap", false))
	assert_true(traps.any(func(d): return String(d.type) == "camera"), "extra cameras")
	assert_true(traps.any(func(d): return String(d.type) == "turret"), "and a turret")
	assert_true(e.units.filter(func(u): return u.has("turret")).size() > plain.units.filter(func(u): return u.has("turret")).size(), "mounted")
	for d in traps:   # off the NET: no Control Node holds them
		e.m.devices.erase(d)   # the cached map is shared: put it back as it was


func test_unexpected_ally_fights_beside_the_crew() -> void:
	var e := _enc("unexpected_ally")
	Twist.spring(e)
	var ally: Array = e.units.filter(func(u): return u.get("twist", false))
	assert_eq(ally.size(), 1)
	var a: Dictionary = ally[0]
	assert_true(e.allied(int(a.team), Encounter.CREW), "on the crew's side")
	assert_true(e.hostile(int(a.team), Encounter.OPFOR), "against the opposition")
	assert_true(e.is_guard(a), "run by the AI")
	assert_false(bool(e.sides[int(a.team)].opfor))
	assert_eq(String(a.c.display_name), "Stranger")


func test_unexpected_rival_is_at_war_with_everyone() -> void:
	var e := _enc("unexpected_rival")
	var opfor_before := e.opfor().size()
	Twist.spring(e)
	var rivals: Array = e.units.filter(func(u): return u.get("twist", false))
	assert_between(rivals.size(), 3, 4)
	var t := int(rivals[0].team)
	assert_true(e.hostile(t, Encounter.CREW) and e.hostile(t, Encounter.OPFOR), "against both")
	assert_eq(e.opfor().size(), opfor_before, "not the opposition the job needs put down")


func test_triggers_spring_at_their_moment_and_once() -> void:
	var e := _enc("hired_muscle", "data", "round3")
	var g := 0
	while e.init.round_num < 3 and g < 300 and e.state == "playing":
		assert_false(bool(e.twist.sprung), "not before round 3 (round %d)" % e.init.round_num)
		e.end_turn()
		e.next_turn()
		g += 1
	assert_true(bool(e.twist.sprung), "at the top of round 3")
	assert_eq(int(e.twist.round), 3)
	Twist.poll(e)
	Twist.spring(e)
	assert_eq(e.events.filter(func(ev): return String(ev.type) == "twist").size(), 1, "once")
	# alarm: when the call goes out (sprung at the next poll)
	var a := _enc("too_much_heat", "data", "alarm")
	Twist.poll(a)
	assert_false(bool(a.twist.sprung))
	var guard: Dictionary = a.units.filter(func(u): return int(u.team) == Encounter.OPFOR)[0]
	guard.alerted = true
	a.call_it_in(guard)
	var timer := a.backup_in
	a._check_end()
	assert_true(bool(a.twist.sprung), "springs with the alarm")
	assert_eq(a.backup_in, maxi(1, ceili(timer * 0.5)), "and halves the timer just set")
	# objective_done: the book's near completion (the package in hand)
	var o := _enc("hired_muscle", "snatch", "objective_done")
	o._check_end()
	assert_false(bool(o.twist.sprung))
	o.units[0].pos = o.objective.cell   # off the deploy zone, so carrying it isn't the end yet
	o.objective.carrier = int(o.units[0].id)
	o._check_end()
	assert_true(bool(o.twist.sprung), "the package grabbed")
	# or_round: a fallback round
	var f := Twist.make(Dice.new(1), Twist.row("hired_muscle"))
	assert_eq(String(f.trigger.on), "objective_done")
	assert_eq(int(f.trigger.or_round), 8, "it comes anyway by round 8")


func test_the_custom_gig_field_and_flag() -> void:
	var form := CustomGig.from_flags(PackedStringArray(["--twist=police_sting@round3", "--seed=55", "--location=hot_zone_11"]))
	assert_eq(String(form.twist), "police_sting@round3")
	assert_true("--twist=police_sting@round3" in CustomGig.to_flags(form), "round trip")
	var g := CustomGig.build(form, Campaign.new_game(1))
	assert_eq(String(g.twist.id), "police_sting")
	assert_eq(g.twist.trigger, {"on": "round", "n": 3})
	assert_eq(Campaign.encounter_opts(g).twist.id, "police_sting", "the encounter gets it")
	assert_true(CustomGig.build({"twist": "none", "seed": 55}, Campaign.new_game(1)).twist == null)
	assert_eq(String(CustomGig.build({"twist": "84", "seed": 55}, Campaign.new_game(1)).twist.id), "trap_location", "by d100 roll")
	assert_eq(String(CustomGig.defaults().twist), "auto")
	assert_false("--twist=auto" in CustomGig.to_flags(CustomGig.defaults()), "auto is left out")


func test_saves_keep_the_twist_and_old_saves_load() -> void:
	var c := Campaign.new_game(31)
	c.board[0]["twist"] = Twist.make(c.dice, Twist.row("hired_muscle"), 41)
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	assert_eq(int(d.version), SaveMigrations.CURRENT)
	var back := Campaign.from_dict(d)
	assert_eq(back.board[0].twist, c.board[0].twist, "the hidden twist survives a save")
	var old: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	old["version"] = 16
	for g in old.board:
		g["twist"] = null
	old.board[1]["twist"] = "heavy"   # junk
	old.board[2].erase("twist")
	old["last_custom"] = {"seed": 4}
	var mig := SaveMigrations.migrate(JSON.parse_string(JSON.stringify(old)))
	assert_eq(int(mig.version), SaveMigrations.CURRENT)
	for g in mig.board:
		assert_true(g.has("twist") and Twist.valid(g.twist))
	assert_true(mig.board[1].twist == null, "junk drops to no twist")
	assert_eq(String(mig.last_custom.twist), "auto")
	assert_true(Campaign.from_dict(JSON.parse_string(JSON.stringify(old))) != null, "a v16 save loads")


func test_the_debrief_names_the_twist_that_sprang() -> void:
	var c := Campaign.new_game(9)
	var gig: Dictionary = c.board[0].duplicate(true)
	gig["twist"] = Twist.make(c.dice, Twist.row("time_limit"), 79, "start")
	c.board[0] = gig
	c.accept(0)
	var gs := GigSetup.for_campaign(c)
	var e := gs.enc
	assert_true(bool(e.twist.sprung))
	e.state = "fled"
	var rep := c.resolve(e)
	assert_eq(String(rep.twist.id), "time_limit")
	assert_true(DebriefScreen.twist_line(rep).begins_with("Clock Running Out, round 0: the window is closing fast."), DebriefScreen.twist_line(rep))
	assert_eq(DebriefScreen.twist_line({"twist": {}}), "", "none sprang: nothing said")
	Hud._fonts()
	var ds := DebriefScreen.new()
	ds.camp = c
	ds.report = rep
	var body := VBoxContainer.new()
	ds.build_body(body)
	assert_true(body.find_child("Twist", true, false) != null, "the debrief shows it")
	body.free()
	ds.free()
