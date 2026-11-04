extends TestCase
## Night City's Fixers (data/world/fixers.json, docs/world/fixers.md) and the fixer board built from
## them and the canon locations (M9 P3, Campaign.refresh_board).


func test_fixers_resolve() -> void:
	var fs := World.fixers()
	assert_true(fs.size() >= 90, "every Fixer-ranked person in the district docs (%d)" % fs.size())
	for id in fs:
		var f := World.fixer(String(id))
		assert_true(String(f.get("name", "")) != "", "%s: a name" % id)
		assert_between(float(f.get("rank", 0)), 1.0, 10.0, "%s: a Fixer rank" % id)
		assert_true(String(f.roles).contains("Fixer %d" % int(f.rank)), "%s: rank matches the printed roles" % id)
		assert_true(World.districts().has(String(f.district)), "%s: district %s exists" % [id, f.district])
		for d in f.get("also", []):
			assert_true(World.districts().has(String(d)), "%s: also-district %s exists" % [id, d])
		var lid := String(f.get("location", ""))
		if lid != "":
			assert_false(World.location(lid).is_empty(), "%s: location %s exists" % [id, lid])
			assert_eq(String(World.location(lid).district), String(f.district), "%s: works where their place is" % id)
		assert_true(not (f.get("deals_in", []) as Array).is_empty(), "%s: deals in something" % id)
		assert_true(String(f.get("cite", "")).begins_with("NC2045 p."), "%s: cited" % id)


func test_each_fixer_is_named_in_their_district_doc() -> void:
	for id in World.fixers():
		var f := World.fixer(String(id))
		for d in [String(f.district)] + Array(f.get("also", [])):
			var text := FileAccess.get_file_as_string("res://docs/world/nc_%s.md" % d)
			assert_true(text.contains(String(f.name)), "%s is in docs/world/nc_%s.md" % [f.name, d])


func test_every_district_but_new_westbrook_has_a_fixer() -> void:
	for did in World.districts():
		if did == "new_westbrook":   # the doc names no Fixer there: neighbours' fixers cover it
			assert_true(World.fixers_in(did).is_empty())
			assert_true(World.neighbours(did).any(func(n): return not World.fixers_in(String(n)).is_empty()))
			continue
		assert_false(World.fixers_in(String(did)).is_empty(), "%s has a fixer" % did)
	assert_eq(World.fixers_in("downtown").has("mister_kernaghan"), true, "works his also-districts")


func test_fixer_tags_are_in_the_vocabulary() -> void:
	var used := {}
	for id in World.fixers():
		for t in World.fixers()[id].deals_in:
			used[String(t)] = true
	for kind in RulesDB.gen("gigs.json").fixer_tags:
		assert_true((RulesDB.gen("gigs.json").fixer_tags[kind] as Array).any(func(t): return used.has(String(t))), "%s: some fixer deals in it" % kind)


# --- The board ----------------------------------------------------------------------------

func test_offers_come_from_district_fixers_at_canon_locations() -> void:
	var camp := Campaign.new_game(21)
	var city := 0
	var hooked := 0
	for day in 8:
		camp.refresh_board()
		for g in camp.board:
			if g.get("unique", false) or String(g.get("hook", "~")) == "~":
				continue   # generic stand-ins (none fitted) and personal jobs
			city += 1
			var l := World.location(String(g.location))
			assert_false(l.is_empty(), "a canon location")
			assert_eq(String(g.district), String(l.district))
			var kinds: Array = []
			for h in l.hooks:
				kinds.append_array(h.gigs)
			assert_true(String(g.kind) in kinds or String(g.kind) in (l.gigs as Array), "%s fits %s" % [g.kind, l.name])
			var f := World.fixer(String(g.fixer_id))
			var near: Array = [String(g.district)] + World.neighbours(String(g.district))
			assert_true(String(f.district) in near or (f.get("also", []) as Array).any(func(d): return d in near), "%s works near %s" % [f.name, g.district])
			assert_eq(String(g.fixer), String(f.name))
			assert_true(String(g.blurb).begins_with("%s has work at %s (%s): " % [f.name, l.name, World.district(String(g.district)).name]), g.blurb)
			if String(g.hook) != "":
				hooked += 1
				assert_true(String(g.blurb).ends_with(String(g.hook).substr(1)), "the hook is the pitch")
				assert_false(String(g.hook).contains("(p."), "no page cite in the pitch")
				assert_true((l.hooks as Array).any(func(h): return String(g.kind) in h.gigs), "a hook naming the job")
			var rng := Campaign.location_levels(l, String(g.faction))   # the code's level when it guards the place
			assert_between(float(g.security), float(rng[0]), float(rng[1]), "the place's own level")
			assert_eq(int(g.pay), int(RulesDB.gen("gigs.json").pay[str(int(g.security))]))
			assert_true(World.has_faction(String(g.faction)) and String(g.kind) in World.targets_for_any(String(g.faction)), "a target that takes the job")
			assert_eq(SecurityCode.normalise(g.security_code), SecurityCode.normalise(l.security_code), "the location's code")
	assert_true(city >= 20, "most offers are canon (%d)" % city)
	assert_true(hooked > city / 2, "hooks preferred (%d of %d)" % [hooked, city])


func test_a_crew_nobody_knows_gets_light_jobs_in_low_code_districts() -> void:
	var camp := Campaign.new_game(22)
	var codes := 0.0
	var n := 0
	for day in 10:
		camp.refresh_board()
		for g in camp.board:
			assert_eq(int(g.security), 1, "Reputation 0: security 1 only (rep_for_security)")
			if String(g.get("location", "")) != "":
				codes += float(SecurityCode.normalise(g.security_code).n)
				n += 1
	var known := Campaign.new_game(22)
	known.crew[0].reputation = 6
	var kcodes := 0.0
	var kn := 0
	for day in 10:
		known.refresh_board()
		for g in known.board:
			if String(g.get("location", "")) != "" and not g.get("unique", false):
				kcodes += float(SecurityCode.normalise(g.security_code).n)
				kn += 1
	assert_true(n > 0 and kn > 0)
	assert_true(codes / n < kcodes / kn, "a name reaches higher Security Codes (%.1f vs %.1f)" % [codes / n, kcodes / kn])
	assert_eq(Campaign.code_weight(3, 0), 1.0)
	assert_true(Campaign.code_weight(8, 5) > Campaign.code_weight(3, 5))


func test_strip_cite() -> void:
	assert_eq(Campaign.strip_cite("A shootout with Whitewater (p.81)."), "A shootout with Whitewater.")
	assert_eq(Campaign.strip_cite("Gangs fight here (NC2045 p.100-101)"), "Gangs fight here")
	assert_eq(Campaign.strip_cite("No cite."), "No cite.")


func test_fallback_to_generic_offers_when_nothing_fits() -> void:
	var data := RulesDB.world("locations.json")
	var saved: Dictionary = (data.get("locations", {}) as Dictionary).duplicate(true)
	data["locations"] = {}
	var camp := Campaign.new_game(23)
	camp.refresh_board()
	data["locations"] = saved
	assert_between(float(camp.board.size()), 3.0, 4.0)
	for g in camp.board:
		assert_false(String(g.title).contains("{"))
		assert_true(World.fixers().has(String(g.fixer_id)), "a Fixer from the data even so")
		assert_true(g.has("security_code"))
