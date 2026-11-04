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
	a._call_it_in(a.units.filter(func(u): return u.team == Encounter.OPFOR)[0])
	b._call_it_in(b.units.filter(func(u): return u.team == Encounter.OPFOR)[0])
	assert_true(a.backup_in > 0)
	assert_eq(b.backup_in, 2 * a.backup_in, "CitiNet out: twice as long")
	assert_eq(a.ncpd_in, -1, "no district code, no street roll")


# --- Encounters --------------------------------------------------------------------------------

func test_intensity_sizes_the_guards_on_site() -> void:
	var count := func(e: Encounter) -> int: return e.units.filter(func(u): return u.team == Encounter.OPFOR and not u.get("outer", false)).size()
	var light := 0
	var heavy := 0
	for s in range(1, 7):
		light += count.call(_enc(s, {"security_code": {"n": 5, "faction": "", "intensity": "light", "hardened": false}}))
		heavy += count.call(_enc(s, {"security_code": {"n": 5, "faction": "", "intensity": "heavy", "hardened": false}}))
	assert_true(heavy > light, "Heavy brings more guards than Light (%d vs %d)" % [heavy, light])


func test_a_response_from_another_faction_comes_on_its_own_side() -> void:
	var e := _enc(3, {"faction": "maelstrom", "security_code": {"n": 11, "faction": "ncpd", "intensity": "light", "hardened": true}, "district_code": {}}, "gang_hideout")
	e._call_it_in(e.units.filter(func(u): return u.team == Encounter.OPFOR)[0])
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
	e._call_it_in(e.units.filter(func(u): return u.team == Encounter.OPFOR)[0])
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
		assert_eq(Campaign.encounter_opts(back.board[i]).keys().size(), 5, "faction, three codes and the complication roll reach the encounter")


func test_a_v7_board_gets_codes_on_load() -> void:
	var d := Campaign.new_game(4).to_dict()
	d["version"] = 7
	for g in d.board:
		for k in ["security_code", "district_code", "utility_code", "district"]:
			g.erase(k)
	var c := Campaign.from_dict(JSON.parse_string(JSON.stringify(d)))
	assert_true(c != null)
	for g in c.board:   # a code from its place, its district or (with neither) its old level
		var code := SecurityCode.normalise(g.security_code)
		assert_false(code.is_empty(), "every migrated gig has a Security Code")
		assert_between(float(code.n), 0.0, 11.0)
		assert_between(float(g.utility_code), 0.0, 11.0)
