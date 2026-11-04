extends TestCase
## Night City 2045 Security and Utility Codes (NC2045 p.7-8, SecurityCode): the rolls, response
## timing, intensity on the p.399 budget, Hardened pools, utilities, and gigs carrying their codes.

const LIGHT := {"n": 11, "faction": "", "intensity": "light", "hardened": false}


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func _enc(seed_value: int, opts: Dictionary, site := "corp_office", security := 2) -> Encounter:
	var m := SceneGen.generate(11, "lone_building", {"security": security, "site": site})
	var dice := Dice.new(seed_value)
	return Encounter.setup(m, dice, _crew(dice), "data", opts)


# --- The code itself -------------------------------------------------------------------------

func test_codes_normalise_and_parse_the_printed_form() -> void:
	var c := SecurityCode.parse("Security Code 5: 6th Street, Hardened Light")
	assert_eq(c, {"n": 5, "faction": "6th_street", "intensity": "light", "hardened": true})
	assert_eq(SecurityCode.parse("7: NCPD, Heavy"), {"n": 7, "faction": "ncpd", "intensity": "heavy", "hardened": false})
	assert_eq(SecurityCode.normalise({"n": 6.0, "faction": "ncpd", "intensity": "MEDIUM", "hardened": true}).n, 6, "JSON floats come back as ints")
	assert_eq(SecurityCode.normalise({"n": 14, "intensity": "silly"}), {"n": 11, "faction": "", "intensity": "medium", "hardened": false}, "clamped, unknown intensity is Medium")
	assert_true(SecurityCode.normalise(null).is_empty())
	assert_true(SecurityCode.parse("Variable").is_empty())


func test_a_response_needs_a_d10_under_the_code() -> void:
	for n in [0, 1, 4, 7, 10, 11]:
		var code := {"n": n}
		var hits := 0
		for s in range(1, 201):
			var a := Dice.new(s)
			var b := Dice.new(s)
			var r := SecurityCode.responds(a, code)
			assert_eq(r, b.d(10) < n, "code %d seed %d: under the number (NC2045 p.7)" % [n, s])
			hits += int(r)
		if n <= 1:
			assert_eq(hits, 0, "code %d never responds" % n)
		elif n == 11:
			assert_eq(hits, 200, "code 11 always responds")
		else:
			assert_between(hits / 200.0, (n - 1) / 10.0 - 0.12, (n - 1) / 10.0 + 0.12, "code %d: about %d0%%" % [n, n - 1])


func test_response_time_is_minutes_at_two_rounds_each() -> void:
	var dice := Dice.new(3)
	var quick := {}
	var slow := {}
	for i in 400:
		quick[SecurityCode.response_rounds(dice, true)] = true
		slow[SecurityCode.response_rounds(dice, false)] = true
	var q := quick.keys()
	q.sort()
	var s := slow.keys()
	s.sort()
	assert_eq(q, [2, 4, 6, 8, 10, 12], "1d6 minutes x 2 rounds (HOUSE-RULE pacing)")
	assert_eq(s, [2, 4, 6, 8, 10, 12, 14, 16, 18, 20], "1d10 minutes x 2 rounds")
	assert_true(SecurityCode.quick({"n": 7}) and SecurityCode.quick({"n": 11}))
	assert_false(SecurityCode.quick({"n": 6}), "codes under 7 respond slowly (our reading)")


func test_intensity_moves_the_crew_size_on_the_budget() -> void:
	var dice := Dice.new(5)
	var seen := {}
	for i in 100:
		var n := SecurityCode.budget_crew_size(4, "light", dice)
		assert_true(n == 2 or n == 3, "Light: 1-2 smaller")
		seen[n] = true
		assert_eq(SecurityCode.budget_crew_size(1, "light", dice), 1, "never below 1")
	assert_eq(seen.size(), 2, "both 1 and 2 smaller turn up")
	assert_eq(SecurityCode.budget_crew_size(4, "medium", dice), 4)
	assert_eq(SecurityCode.budget_crew_size(4, "heavy", dice), 5, "Heavy: at least 1 larger")


func test_response_rosters_follow_the_intensity_table() -> void:
	var dice := Dice.new(8)
	for i in 50:
		var light := SecurityCode.response_roster(dice, {"intensity": "light"}, 4)
		assert_false("mini_boss" in light, "Light: Mooks and the odd Lieutenant")
		assert_true(light.count("lieutenant") <= 1)
		assert_true(light.has("mook"))
		var cost := 0
		for t in light:
			cost += int(SecurityCode.COST[t])
		assert_true(cost <= 3, "spent on a crew of 4 counted 1-2 smaller")
		var heavy := SecurityCode.response_roster(dice, {"intensity": "heavy"}, 4)
		assert_eq(heavy[0], "mini_boss", "Heavy: anything goes")
	# The book's example (p.8): a crew of 6 against a Light code gets about four Mooks.
	var six := SecurityCode.response_roster(Dice.new(1), {"intensity": "light"}, 6)
	assert_between(six.size(), 3, 5)


func test_hardened_pools_prefer_hardened_blocks_and_fall_back() -> void:
	var npcs := {"blocks": {"a": {}, "b": {}, "h1": {"hardened": true}, "h2": {"hardened": true}},
		"tiers": {"mook": {"blocks": ["a"], "hardened_blocks": ["h2"]}, "lieutenant": {"blocks": ["b"]}}}
	var mixed := {"blocks": {"mook": ["a", "h1"]}}
	assert_eq(SecurityCode.pool_from(mixed, npcs, "mook", true), ["h1"], "the roster's own Hardened blocks")
	assert_eq(SecurityCode.pool_from(mixed, npcs, "mook", false), ["a"], "ordinary codes keep to ordinary blocks")
	assert_eq(SecurityCode.pool_from({"blocks": {"mook": ["a"]}, "hardened_blocks": {"mook": ["h1"]}}, npcs, "mook", true), ["h1"], "the roster's hardened_blocks")
	assert_eq(SecurityCode.pool_from({"blocks": {"mook": ["a"]}}, npcs, "mook", true), ["h2"], "the tier's Hardened pool")
	assert_eq(SecurityCode.pool_from({}, npcs, "lieutenant", true), ["b"], "no Hardened blocks yet: the ordinary pool")
	assert_eq(SecurityCode.pool_from({"hardened_blocks": {"lieutenant": ["ghost"]}}, npcs, "lieutenant", true), ["b"], "unknown ids are skipped")
	# The real data: every faction and tier resolves to blocks that exist, Hardened or not.
	var blocks: Dictionary = RulesDB.load_json("npcs.json")["blocks"]
	for f in World.factions():
		for t in ["mook", "lieutenant", "mini_boss"]:
			for h in [false, true]:
				var pool := SecurityCode.tier_pool(String(f), t, h)
				assert_false(pool.is_empty(), "%s %s" % [f, t])
				assert_true(pool.all(func(id): return blocks.has(String(id))), "%s %s: blocks exist" % [f, t])
	assert_eq(World.npc(Dice.new(2), "militech", "mook", 1, "", true).faction, "militech", "a Hardened NPC is still the faction's")


func test_the_old_level_fallback_and_the_board_label() -> void:
	assert_eq(SecurityCode.from_level(1), {"n": 4, "faction": "", "intensity": "light", "hardened": false})
	assert_eq(SecurityCode.from_level(2, "militech"), {"n": 6, "faction": "militech", "intensity": "medium", "hardened": false})
	assert_eq(SecurityCode.from_level(3), {"n": 8, "faction": "", "intensity": "heavy", "hardened": true})
	for lv in [1, 2, 3]:
		assert_eq(SecurityCode.level(SecurityCode.from_level(lv)), lv, "level %d round-trips" % lv)
	assert_eq(SecurityCode.label({"n": 6, "faction": "ncpd", "intensity": "medium", "hardened": true}), "SECURITY 6 · NCPD · HARDENED MEDIUM")
	assert_eq(SecurityCode.label({"n": 5, "faction": "gold_dragons", "intensity": "light", "hardened": true}), "SECURITY 5 · GOLD DRAGONS · HARDENED LIGHT", "a faction not in factions.json yet")
	assert_eq(Campaign.code_label({"security": 3, "faction": "militech"}), "SECURITY 8 · MILITECH · HARDENED HEAVY", "a gig without a code shows its fallback")


# --- Utilities -----------------------------------------------------------------------------

func test_utilities_go_out_under_the_code() -> void:
	assert_true(SecurityCode.roll_utilities(Dice.new(1), 0).is_empty())
	assert_true(SecurityCode.roll_utilities(Dice.new(1), 1).is_empty(), "nothing is under 1")
	assert_eq(SecurityCode.roll_utilities(Dice.new(1), 11), ["power", "water", "citinet"] as Array[String])
	for s in range(1, 51):
		var a := Dice.new(s)
		var b := Dice.new(s)
		var want: Array[String] = []
		for u in SecurityCode.UTILITIES:
			if b.d(10) < 5:
				want.append(u)
		assert_eq(SecurityCode.roll_utilities(a, 5), want, "one d10 per utility, in order (NC2045 p.8)")


func test_power_out_kills_cameras_turrets_and_lights() -> void:
	var on := _enc(4, {})
	var off := _enc(4, {"utility_code": 11})   # every utility out
	assert_eq(off.outages, ["power", "water", "citinet"] as Array[String])
	assert_true(off.lights_out())
	assert_false(on.lights_out())
	var powered := off.m.devices.filter(func(d): return String(d.type) in ["camera", "turret"])
	assert_false(powered.is_empty(), "a corp office has cameras")
	assert_true(powered.all(func(d): return off.disabled_devices.has(d.id)), "cameras and turrets are dead")
	assert_false(off.m.devices.any(func(d): return String(d.type) == "door_lock" and off.disabled_devices.has(d.id)), "mechanical locks hold")
	assert_true(off.lit.size() < on.lit.size(), "the lights are off (%d lit vs %d)" % [off.lit.size(), on.lit.size()])
	for line in ["power's out", "CitiNet is down", "water's off"]:
		assert_true(off.log.any(func(l): return String(l).contains(line)), "the log says: %s" % line)


func test_citinet_out_doubles_the_response_time() -> void:
	var opts := {"security_code": {"n": 11, "faction": "", "intensity": "medium", "hardened": false}, "district_code": {}}
	var a := _enc(6, opts)
	var b := _enc(6, opts)
	b.outages = ["citinet"] as Array[String]
	a.call_it_in(a.units.filter(func(u): return u.team == Encounter.OPFOR)[0])
	b.call_it_in(b.units.filter(func(u): return u.team == Encounter.OPFOR)[0])
	assert_true(a.backup_in > 0)
	assert_eq(b.backup_in, 2 * a.backup_in, "CitiNet out: twice as long")
	assert_eq(a.ncpd_in, -1, "no district code, no street roll")


# --- Encounters --------------------------------------------------------------------------------

func _posts(e: Encounter) -> Array:
	return e.units.filter(func(u): return u.team == Encounter.OPFOR and not u.get("outer", false) and String(u.c.display_name).find("Patrol") < 0)


func _hardened(u: Dictionary) -> bool:
	return bool((RulesDB.load_json("npcs.json").blocks.get(String(u.c.block), {}) as Dictionary).get("hardened", false))


func test_the_security_level_sizes_the_guards_on_site_once() -> void:
	# The level (Light 1 .. Heavy 3, from the code via the campaign) is the one channel: the code's
	# intensity no longer also shifts the crew size for the posts.
	var light := 0
	var heavy := 0
	for s in range(1, 7):
		light += _posts(_enc(s, {"security_code": {"n": 5, "faction": "", "intensity": "light", "hardened": false}}, "corp_office", 1)).size()
		heavy += _posts(_enc(s, {"security_code": {"n": 5, "faction": "", "intensity": "heavy", "hardened": false}}, "corp_office", 3)).size()
	assert_true(heavy > light, "a Heavy place (level 3) has more guards than a Light one (%d vs %d)" % [heavy, light])
	for s in range(1, 5):
		var a := _posts(_enc(s, {"security_code": {"n": 5, "faction": "", "intensity": "light", "hardened": false}})).size()
		var b := _posts(_enc(s, {"security_code": {"n": 5, "faction": "", "intensity": "heavy", "hardened": false}})).size()
		assert_eq(a, b, "seed %d: at the same level the intensity doesn't count again" % s)


func test_an_outside_authoritys_code_neither_sizes_nor_hardens_the_posts() -> void:
	# NCPD's interest in a Militech office (NC2045 p.7): NCPD answers the call; Militech's own people
	# hold the posts at their ordinary strength, not Hardened.
	var ncpd := {"n": 11, "faction": "ncpd", "intensity": "heavy", "hardened": true}
	var own := {"n": 11, "faction": "militech", "intensity": "heavy", "hardened": true}
	var e := _enc(5, {"faction": "militech", "security_code": ncpd, "district_code": {}})
	var posts := _posts(e)
	assert_false(posts.is_empty())
	assert_eq(e.post_faction, "militech")
	assert_true(posts.all(func(u): return String(u.c.faction) == "militech"), "the target's people on the posts")
	assert_false(posts.any(_hardened), "an outside Hardened code doesn't harden them")
	var mine := _enc(5, {"faction": "militech", "security_code": own, "district_code": {}})
	assert_true(_posts(mine).any(_hardened), "their own Hardened code does")
	assert_eq(_posts(mine).size(), posts.size(), "same level, same budget: the code's intensity isn't added on top")
	e.call_it_in(posts[0])
	assert_eq(e.backup_label, "NCPD", "the authority still answers")


func test_a_contractor_holds_the_posts_of_the_place_it_guards() -> void:
	# Night Corp HQ: Security Code 10, Lazarus, Hardened Heavy (NC2045 p.61). Lazarus is at the
	# door; Night Corp is the target.
	var hq := World.location("little_europe_15")
	assert_eq(String(hq.owner), "night_corp")
	assert_eq(String(SecurityCode.normalise(hq.security_code).faction), "lazarus")
	var gig := {"faction": "night_corp", "location": "little_europe_15", "security": 3}
	Campaign._fit_location_security(gig)
	assert_eq(int(gig.security), 3, "a Heavy contractor's code keeps the place at level 3")
	gig.merge(Campaign.codes_for(gig, "little_europe"), true)
	var opts := Campaign.encounter_opts(gig)
	assert_eq(String(opts.guards), "lazarus")
	opts.erase("complications")
	var e := _enc(2, opts, "corp_office", 3)
	assert_eq(e.opfor_faction, "night_corp", "the job is still against Night Corp")
	assert_eq(e.post_faction, "lazarus")
	var posts := _posts(e)
	assert_false(posts.is_empty())
	assert_true(posts.all(func(u): return String(u.c.faction) == "lazarus"), "Lazarus on every post")
	assert_true(posts.any(_hardened), "Hardened, as the code says")
	assert_eq(String(e.doctrine.id), String(World.faction("lazarus").get("doctrine", "default")), "guarding Lazarus's way")
	e.code.n = 11
	e.call_it_in(posts[0])
	assert_eq(e.backup_label, "BACKUP", "Lazarus's own backup comes on the posts' side")


func test_who_guards_a_place_under_its_code() -> void:
	var c := func(f: String) -> Dictionary: return {"n": 7, "faction": f, "intensity": "medium", "hardened": true}
	assert_eq(SecurityCode.guarded_by(c.call("militech"), "militech", "militech"), "militech", "its own")
	assert_eq(SecurityCode.guarded_by(c.call(""), "maelstrom"), "maelstrom", "a code naming nobody is the site's own")
	assert_eq(SecurityCode.guarded_by(c.call("lazarus"), "night_corp", "night_corp"), "lazarus", "a contractor")
	assert_eq(SecurityCode.guarded_by(c.call("kimen_gumi"), "sanroo", "sanroo"), "kimen_gumi", "a district provider guarding a corp")
	assert_eq(SecurityCode.guarded_by(c.call("ncpd"), "digital_divinity", "digital_divinity"), "", "NCPD's interest in a private firm")
	assert_eq(SecurityCode.guarded_by(c.call("ncpd"), "city_government", "city_government"), "ncpd", "NCPD guards City Hall")
	assert_eq(SecurityCode.guarded_by(c.call("6th_street"), "americar", "americar"), "", "a gang is no contractor")
	assert_eq(SecurityCode.guarded_by(c.call("lazarus"), "maelstrom", ""), "", "nobody owns it to hire anyone")
	assert_eq(SecurityCode.guarded_by({}, "militech"), "")
	# The levels a gig at the place can be played at follow the same split.
	assert_eq(Campaign.location_levels(World.location("little_europe_15"), "night_corp"), [3, 3], "Lazarus Heavy at Night Corp HQ")
	assert_eq(Campaign.location_levels(World.location("upper_marina_11"), "digital_divinity"), [1, 3], "NCPD's interest: the target's own level")


# --- The street roll -----------------------------------------------------------------------------

func test_the_street_is_not_rolled_for_the_faction_that_already_answered() -> void:
	var ncpd7 := {"security_code": {"n": 7, "faction": "ncpd", "intensity": "medium", "hardened": true}}
	var killzone := {"security_code": {"n": 6, "faction": "ncpd", "intensity": "medium", "hardened": true}}
	assert_true(SecurityCode.for_gig(killzone, ncpd7, 1).district_code.is_empty(), "NCPD's place in NCPD's district: one roll (NC2045 p.7)")
	var other := {"security_code": {"n": 6, "faction": "militech", "intensity": "medium", "hardened": true}}
	assert_eq(String(SecurityCode.for_gig(other, ncpd7, 1).district_code.faction), "ncpd", "another faction's place keeps the street roll")
	# The data: no location gig pairs a code with a street code of the same faction.
	for id in World.locations():
		var l := World.location(String(id))
		var g := SecurityCode.for_gig(l, World.district(String(l.get("district", ""))), 1)
		if not (g.district_code as Dictionary).is_empty():
			assert_true(String(g.district_code.faction) != String(g.security_code.faction), "%s: one roll per faction" % id)
	# An old offer carrying both: the encounter still rolls the faction once.
	var both := {"faction": "maelstrom", "security_code": {"n": 11, "faction": "ncpd", "intensity": "light", "hardened": false},
		"district_code": {"n": 11, "faction": "ncpd", "intensity": "medium", "hardened": true}}
	var e := _enc(3, both, "gang_hideout")
	e.call_it_in(e.units.filter(func(u): return u.team == Encounter.OPFOR)[0])
	assert_true(e.backup_in > 0, "the site code answers")
	assert_eq(e.ncpd_in, -1, "no second NCPD wave")


func test_a_response_from_another_faction_comes_on_its_own_side() -> void:
	var e := _enc(3, {"faction": "maelstrom", "security_code": {"n": 11, "faction": "ncpd", "intensity": "light", "hardened": true}, "district_code": {}}, "gang_hideout")
	e.call_it_in(e.units.filter(func(u): return u.team == Encounter.OPFOR)[0])
	assert_eq(e.backup_label, "NCPD")
	assert_true(e.backup_in >= 2 and e.backup_in <= 12, "code 11 is quick: 1d6 minutes")
	var before := e.units.size()
	e.backup_in = 1
	e._backup_round = -5
	e._tick_backup()
	var cops := e.units.slice(before)
	assert_false(cops.is_empty(), "the NCPD arrives")
	assert_true(cops.all(func(u): return String(e.sides[int(u.team)].faction) == "ncpd" and u.alerted))
	assert_true(cops.all(func(u): return String(u.c.role) != "mini_boss"), "Light: no Mini Bosses")


func test_an_unknown_responder_turns_up_as_security_under_its_name() -> void:
	var e := _enc(3, {"faction": "militech", "security_code": {"n": 11, "faction": "acme_guards", "intensity": "medium", "hardened": false}, "district_code": {}})
	e.call_it_in(e.units.filter(func(u): return u.team == Encounter.OPFOR)[0])
	assert_eq(e.backup_label, "ACME GUARDS")
	var before := e.units.size()
	e.backup_in = 1
	e._backup_round = -5
	e._tick_backup()
	assert_true(e.units.size() > before)
	assert_true(e.units[-1].c.display_name.begins_with("Acme Guards"))


# --- Gigs carry their codes ----------------------------------------------------------------------

func test_gig_codes_come_from_the_location_then_the_district_then_the_level() -> void:
	var dist := {"security_code": {"n": 7, "faction": "ncpd", "intensity": "medium", "hardened": true}, "utility_code": 3}
	var loc := {"district": "little_europe", "security_code": {"n": 9, "faction": "militech", "intensity": "heavy", "hardened": true}, "utility_code": null}
	var a := SecurityCode.for_gig(loc, dist, 1, "militech")
	assert_eq(a.source, "location")
	assert_eq(int(a.security_code.n), 9)
	assert_eq(String(a.district_code.faction), "ncpd", "the district's code is the street-level response")
	assert_eq(a.utility_code, 3, "no override: the district's Utility Code")
	loc["utility_code"] = 8
	assert_eq(SecurityCode.for_gig(loc, dist, 1).utility_code, 8, "a location's own Utility Code overrides")
	var b := SecurityCode.for_gig({}, dist, 1, "militech")
	assert_eq(b.source, "district")
	assert_eq(String(b.security_code.faction), "ncpd")
	assert_true(b.district_code.is_empty(), "the district's code was the one roll")
	var c := SecurityCode.for_gig({}, {}, 3, "militech")
	assert_eq(c.source, "fallback")
	assert_eq(c.security_code, {"n": 8, "faction": "militech", "intensity": "heavy", "hardened": true}, "OWNER-ACCEPTED fallback")
	assert_eq(c.district_code, SecurityCode.STREET_FALLBACK)
	assert_eq(c.utility_code, SecurityCode.UTILITY_FALLBACK)
	assert_eq(SecurityCode.for_gig({}, {"utility_code": "Variable"}, 1).utility_code, SecurityCode.UTILITY_FALLBACK, "Outskirts' Variable")


func test_the_board_reads_codes_from_the_city_data() -> void:
	# A district and a location for the test, injected into the loaded data (the registries are
	# being filled by the M9 phase 1 pass).
	var city := RulesDB.world("city.json")
	var locs := RulesDB.world("locations.json")
	var saved_city: Dictionary = (city.get("districts", {}) as Dictionary).duplicate(true)
	var saved_locs: Dictionary = (locs.get("locations", {}) as Dictionary).duplicate(true)
	city["districts"] = {"test_zone": {"name": "Test Zone", "profile": "combat_zone", "utility_code": 8,
		"security_code": {"n": 3, "faction": "ncpd", "intensity": "heavy", "hardened": true}}}
	locs["locations"] = {"test_zone_1": {"name": "Test Depot", "district": "test_zone", "type": "warehouse", "owner": "militech",
		"security_code": {"n": 10, "faction": "militech", "intensity": "light", "hardened": true}, "utility_code": null,
		"gigs": ["sabotage", "corp_extraction", "data_theft"], "cite": "test"}}
	var l := World.location("test_zone_1")
	assert_eq(String(l.site), "warehouse", "the site comes from the type")
	assert_eq(l.security, [1, 1], "a Light code is the old security 1")
	assert_eq(World.districts_with_profile("combat_zone"), ["test_zone"] as Array[String])
	var camp := Campaign.new_game(5)
	var at_loc := {"location": "test_zone_1", "security": 1, "faction": "militech"}
	camp._code_gig(at_loc)
	assert_eq(String(at_loc.district), "test_zone")
	assert_eq(int(at_loc.security_code.n), 10, "the location's own code")
	assert_eq(int(at_loc.district_code.n), 3, "the district's for the street")
	assert_eq(int(at_loc.utility_code), 8)
	var in_dist := {"profile": "combat_zone", "security": 2, "faction": "maelstrom"}
	camp._code_gig(in_dist)
	assert_eq(String(in_dist.district), "test_zone", "a neighbourhood gig lands in a district with its profile")
	assert_eq(String(in_dist.security_code.faction), "ncpd")
	var anywhere := {"scene": "skirmish", "security": 2, "faction": "maelstrom"}
	camp._code_gig(anywhere)
	assert_eq(String(anywhere.district), "")
	assert_eq(String(anywhere.security_code.faction), "maelstrom", "the fallback: the target's own people")
	city["districts"] = saved_city
	locs["locations"] = saved_locs


func test_board_gigs_save_their_codes() -> void:
	var camp := Campaign.new_game(7)
	camp.refresh_board()
	assert_true(camp.board.all(func(g): return g.has("security_code") and g.has("district_code") and g.has("utility_code")), "every offer carries its codes")
	var back := Campaign.from_dict(JSON.parse_string(JSON.stringify(camp.to_dict())))
	for i in camp.board.size():
		assert_eq(SecurityCode.normalise(back.board[i].security_code), SecurityCode.normalise(camp.board[i].security_code), "offer %d's code survives a save" % i)
		assert_eq(Campaign.code_label(back.board[i]), Campaign.code_label(camp.board[i]))
		assert_eq(Campaign.encounter_opts(back.board[i]).keys().size(), 7,
			"faction, three codes, who guards, and the complication and utility rolls reach the encounter")


func test_a_v7_board_gets_codes_on_load() -> void:
	var d := Campaign.new_game(4).to_dict()
	d["version"] = 7
	# An offer at Night Corp HQ and one with no place at all, as v7 saved them (no codes yet).
	d["board"] = [{"id": "1-0", "kind": "data_theft", "fixer": "Mr. Blue", "faction": "night_corp", "location": "little_europe_15",
			"scene": "lone_building", "site": "corp_hq", "profile": "", "title": "t", "blurb": "b", "security": 3, "pay": 3000, "seed": 4},
		{"id": "1-1", "kind": "gang_hit", "fixer": "Mr. Blue", "faction": "maelstrom", "scene": "skirmish", "site": "", "profile": "",
			"title": "t", "blurb": "b", "security": 2, "pay": 1500, "seed": 5}]
	var raw: Dictionary = JSON.parse_string(JSON.stringify(d))
	var migrated := SaveMigrations.migrate(raw.duplicate(true))
	assert_eq(int(migrated.version), SaveMigrations.CURRENT)
	assert_false((migrated.board[0] as Dictionary).has("security_code"), "the migration is a pure dict step: it reads no city data")
	var c := Campaign.from_dict(raw)
	assert_true(c != null)
	var hq: Dictionary = c.board[0]
	assert_eq(SecurityCode.normalise(hq.security_code), SecurityCode.normalise(World.location("little_europe_15").security_code), "the location's own code (Lazarus 10)")
	assert_eq(String(hq.district), "little_europe")
	assert_eq(String(hq.district_code.faction), "ncpd", "Little Europe's street")
	assert_eq(int(hq.utility_code), 2, "Night Corp HQ's own Utility Code")
	var anywhere: Dictionary = c.board[1]
	assert_eq(SecurityCode.normalise(anywhere.security_code), SecurityCode.from_level(2, "maelstrom"), "no place: the fallback for its level, the target's own people")
	assert_eq(anywhere.district_code, SecurityCode.STREET_FALLBACK)
	var again := Campaign.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(SecurityCode.normalise(again.board[0].security_code), SecurityCode.normalise(hq.security_code), "and they're saved from then on")


func test_utilities_come_into_play_on_one_gig_in_three() -> void:
	# NC2045 p.8: an optional complication. With the roll on (the campaign's gigs), utility code 11
	# puts everything out on about a third of gigs and nothing out on the rest.
	var hits := 0
	for s in range(1, 31):
		var e := _enc(s, {"utility_code": 11, "utilities": true})
		assert_true(e.outages.is_empty() or e.outages.size() == 3)
		hits += int(not e.outages.is_empty())
	assert_between(hits, 4, 17, "about 1 in %d (%d of 30)" % [SecurityCode.UTILITY_CHANCE_IN, hits])
	assert_true(bool(Campaign.encounter_opts({"faction": "militech"}).get("utilities", false)), "campaign gigs roll for it")
