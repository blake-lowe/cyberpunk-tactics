extends TestCase
## District looks (data/gen/district_looks.json, DistrictLook): every Night City district has one,
## its values are in range, and a gig's district reaches the scene (generator and SceneTheme).


func test_every_district_has_a_look() -> void:
	for id in World.districts():
		assert_true(DistrictLook.has(String(id)), "%s has a look" % id)
	for id in DistrictLook.looks():
		assert_true(World.districts().has(id), "look %s is a city district" % id)


func test_look_values_in_range() -> void:
	var sites: Dictionary = RulesDB.gen("sites.json")
	for id in DistrictLook.looks():
		var lk: Dictionary = DistrictLook.of(id)
		assert_true(String(lk.get("why", "")).contains("NC2045 p."), "%s cites the book" % id)
		for k in DistrictLook.RANGES:
			assert_true(lk.has(k), "%s sets %s" % [id, k])
			var r: Array = DistrictLook.RANGES[k]
			assert_true(float(lk.get(k, 0)) >= float(r[0]) and float(lk.get(k, 0)) <= float(r[1]), "%s %s in %s" % [id, k, r])
		for k in DistrictLook.OPTIONAL:
			if lk.has(k):
				var r2: Array = DistrictLook.OPTIONAL[k]
				assert_true(float(lk[k]) >= float(r2[0]) and float(lk[k]) <= float(r2[1]), "%s %s in %s" % [id, k, r2])
		for role in ["neon", "lamp"]:
			assert_true((lk.get(role, []) as Array).size() >= 1, "%s has %s colours" % [id, role])
			for h in lk.get(role, []):
				assert_true(Color.html_is_valid(String(h)), "%s %s %s" % [id, role, h])
		var pal := String(lk.get("palette", ""))
		assert_true(pal == "" or pal == "sunset" or SceneTheme.palettes().has(pal), "%s palette %s exists" % [id, pal])
		assert_true(String(lk.get("surround", "skyline")) in ["skyline", "desert", "ruins"], "%s surround" % id)
		for piece in lk.get("street", []):
			assert_true(Furnish.PIECES.has(piece), "%s street piece %s" % [id, piece])
		for use in lk.get("mix", {}):
			assert_true(sites.has(use) or DistrictGen.YARDS.has(use), "%s lot use %s" % [id, use])
		for wm in lk.get("walls", {}):
			assert_true(WorldBuilder.LIB.has(wm), "%s walls %s" % [id, wm])
			for h in lk.walls[wm].get("colors", []):
				assert_true(Color.html_is_valid(String(h)), "%s walls %s" % [id, h])
		for mn in lk.get("mats", {}):
			assert_true(WorldBuilder.LIB.has(mn), "%s mats %s" % [id, mn])
		for a in lk.get("ambient", []):
			assert_true(a in ["embers", "steam", "drips", "motes"], "%s ambient %s" % [id, a])


func test_district_reaches_the_scene() -> void:
	var gig := {"security": 1, "district": "little_china", "profile": "market_streets", "seed": 4}
	var m := SceneGen.generate(4, "neighborhood", Campaign.scene_opts(gig))
	assert_eq(String(m.params.get("district", "")), "little_china")
	var th := SceneTheme.of(m)
	assert_eq(th.get("neon"), DistrictLook.of("little_china").neon, "the theme is the district's")
	assert_eq(SceneTheme.colors(m, "neon", [])[0], Color("ff3b4f"))
	assert_eq(SceneTheme.signs(m), 2.0)
	var stalls := m.cover.filter(func(c): return c.kind == "stall" and int(c.room) < 0).size()
	assert_true(stalls >= 3, "market stalls on the pavements (%d)" % stalls)
	# Themed scenes keep their own look even with a district.
	var uc := SceneGen.generate(4, "undercity", {"security": 1, "district": "little_china"})
	assert_eq(String(SceneTheme.of(uc).get("palette", "")), "toxic")


func test_lone_building_wears_its_district() -> void:
	var m := SceneGen.generate(9, "lone_building", {"security": 1, "site": "bar", "district": "executive_zone"})
	assert_eq(String(SceneTheme.of(m).get("palette", "")), "clinical")
	assert_true(SceneTheme.wall_look(m, "wall_plaster", 3).has("color"), "district facades")
	assert_true(SceneTheme.of(SceneGen.generate(9, "lone_building", {"security": 1, "site": "bar"})).is_empty(), "no district: the defaults")


func test_ruin_greenery_and_height_shape_the_neighbourhood() -> void:
	var hot := SceneGen.generate(6, "neighborhood", {"security": 1, "profile": "mixed_residential", "district": "hot_zone"})
	var exe := SceneGen.generate(6, "neighborhood", {"security": 1, "profile": "mixed_residential", "district": "executive_zone"})
	var rubble := func(m: TacMap) -> int: return m.cover.filter(func(c): return c.kind == "rubble" and int(c.room) < 0).size()
	var trees := func(m: TacMap) -> int: return m.cover.filter(func(c): return c.kind in ["tree", "planter"] and int(c.room) < 0).size()
	assert_true(rubble.call(hot) > rubble.call(exe) + 10, "rubble in the Hot Zone (%d vs %d)" % [rubble.call(hot), rubble.call(exe)])
	assert_true(trees.call(exe) > trees.call(hot) + 5, "trees in the Executive Zone (%d vs %d)" % [trees.call(exe), trees.call(hot)])
	var plan := LightPlan.plan(hot, hot.seed_value)
	assert_true(plan.filter(func(e): return e.kind == "sign").is_empty(), "no neon in the Hot Zone")
	assert_true(plan.filter(func(e): return e.kind == "blaze").size() >= 3, "the Hot Zone burns")
	# Watson's megabuildings: two storeys over the scene, the gig's target as tall as ever.
	var wat := SceneGen.generate(6, "neighborhood", {"security": 1, "profile": "mixed_residential", "district": "watson_development"})
	assert_eq(wat.floors, exe.floors + 2)
	var tgt: Array = wat.structures.filter(func(s): return s.target)
	assert_true(not tgt.is_empty() and int(tgt[0].floors) == int(exe.params.floors), "target keeps the scene's storeys")
	var prof := DistrictLook.profile(RulesDB.gen("districts.json")["mixed_residential"], DistrictLook.of("hot_zone"), 3)
	assert_true(float(prof.decay[0]) >= 0.5, "ruin replaces the profile's decay")
	assert_eq(float(RulesDB.gen("districts.json")["mixed_residential"].decay[1]), 0.2, "the profile data is not modified")
