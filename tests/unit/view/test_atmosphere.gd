extends TestCase
## The weather over a gig (Atmosphere, data/gen/atmospheres.json): moods resolved the same for the
## same seed, weighted by the district, kept on the gig through a save, handed to the map, and only
## ever touching the air (sky, fog, smog), never the light the play area is lit by.


func test_every_mood_is_well_formed() -> void:
	var d := Atmosphere.data()
	assert_eq(Atmosphere.default_id(), "clear")
	assert_eq(String(Atmosphere.ids()[0]), "clear", "the default first")
	assert_true(Atmosphere.light("clear", false).is_empty() and Atmosphere.light("clear", true).is_empty(), "clear: the scene's own air")
	for id in ["overcast", "drizzle", "heavy_rain", "storm", "acid_rain", "blood_rain", "ash", "dust", "rad_wind", "smog", "heat_wave", "cold_snap", "flood"]:
		assert_true(Atmosphere.has(id), "a %s mood" % id)
	for id in Atmosphere.ids():
		var md: Dictionary = d.moods[id]
		assert_true(String(md.get("name", "")) != "", "%s: a name for the dev card" % id)
		assert_true(String(md.get("book", "")).contains("NCW p."), "%s: the Night City Weather row it plays" % id)
		for k in ["name", "hud"]:   # player-facing: never a page
			assert_false(String(md.get(k, "")).contains("p."), "%s: no cite in its %s" % [id, k])
		for day in [false, true]:
			var lk := Atmosphere.look(String(id), day)
			for k in ["fog", "smog", "cast", "glow", "rain_col", "dust_col", "haze_col", "flake_col", "mote_col"]:
				assert_true(String(lk.get(k, "")) == "" or Color.html_is_valid(String(lk[k])), "%s: %s is a colour" % [id, k])
			for c in lk.get("sky", []) + lk.get("lit", []):
				assert_true(Color.html_is_valid(String(c)), "%s: %s is a colour" % [id, c])
			if lk.has("sky"):
				assert_eq((lk.sky as Array).size(), 3, "%s: zenith, mid, horizon" % id)
			for k in Atmosphere.light(String(id), day):
				assert_true(k in Atmosphere.LIGHT_KEYS, "%s: sets only the air (%s)" % [id, k])
			# the play area's light is never the weather's (owner's light rounds)
			for k in ["ambient", "amb_e", "key", "key_e", "rim", "lights", "spill"]:
				assert_false(lk.has(k), "%s: leaves %s alone" % [id, k])
			if id != "clear":
				assert_true(lk.has("fog") and lk.has("sky") and lk.has("smog"), "%s %s: its own fog, sky and smog" % [id, "day" if day else "night"])
				assert_between(float(lk.get("fog_d", 0.0)), 0.0, 0.0035, "%s: the play area stays readable through its fog" % id)
	assert_eq(String(Atmosphere.look("no_such_mood").id), "clear", "an unknown mood: the default")


func test_the_mood_is_the_seeds_and_the_districts() -> void:
	for did in ["the_glen", "upper_marina", "heywood_industrial_zone", "outskirts", ""]:
		for s in range(1, 120):
			var a := Atmosphere.pick(s, did)
			assert_eq(Atmosphere.pick(s, did), a, "%s seed %d: the same mood every time" % [did, s])
			assert_true(Atmosphere.has(a), "a mood we have (%s)" % a)
	var seen := {}
	for s in range(1, 400):
		seen[Atmosphere.pick(s, "south_night_city")] = true
	assert_true(seen.size() >= 4, "seeds vary the weather (%s)" % str(seen.keys()))


func _share(did: String, mood: String, n := 1500) -> float:
	var hit := 0
	for s in range(1, n + 1):
		hit += int(Atmosphere.pick(s, did) == mood)
	return float(hit) / n


func test_districts_weight_the_weather() -> void:
	var w := Atmosphere.weights("outskirts")
	assert_true(int(w.get("dust", 0)) > int(Atmosphere.weights("the_glen").get("dust", 0)), "the Badlands edge leans dust")
	assert_between(_share("outskirts", "dust"), 0.2, 0.45, "dust storms regularly sweep through out there (NC2045 p.297)")
	assert_between(_share("the_glen", "dust"), 0.0, 0.04, "a dust storm over the Glen is Strange Weather: rare")
	assert_between(_share("heywood_industrial_zone", "smog"), 0.4, 0.6, "most days a yellow smog in the Industrial Zone (NC2045 p.256)")
	assert_true(_share("hot_zone", "rad_wind") > _share("the_glen", "rad_wind") + 0.05, "the Hot Zone's wind carries its dust")
	assert_true(_share("upper_marina", "drizzle") > _share("charter_hill", "drizzle"), "the marina leans sea drizzle")
	assert_true(_share("the_glen", "clear") > _share("south_night_city", "clear"), "the corporate centre stays clearer than the combat zone")
	var base: Dictionary = Atmosphere.data().weights.base
	var unknown := Atmosphere.weights("no_such_district")
	for k in base:
		assert_eq(int(unknown.get(k, 0)), int(base[k]), "an unknown district: the base weights (%s)" % k)
	for did in World.districts():
		var dw := Atmosphere.weights(String(did))
		assert_true(int(dw.get("clear", 0)) > 0, "%s: clear weather is always possible" % did)
		for k in dw:
			assert_true(Atmosphere.has(String(k)) and int(dw[k]) > 0, "%s: %s weighted" % [did, k])


func test_a_tower_gig_keeps_its_weather() -> void:
	var camp := Campaign.new_game(9)
	var g := RulesDB.gen("gigs.json")
	var found := {}
	for i in 60:
		var offer := camp.tower_gig(g, "upper_marina_40", "data_theft")
		assert_eq(String(offer.mood), Campaign.tower_mood(int(offer.seed), "upper_marina"), "the offer's mood is its seed's and district's")
		found[String(offer.mood)] = offer
	assert_true(found.size() >= 3, "several moods on offer (%s)" % str(found.keys()))
	var wet: Dictionary = found.get("acid_rain", found.values()[0])
	assert_eq(String(Campaign.scene_opts(wet).get("mood", "")), String(wet.mood), "the gig hands its mood to the map")
	var m := SceneGen.generate(int(wet.seed), String(wet.scene), Campaign.scene_opts(wet))
	assert_eq(Atmosphere.of(m), String(wet.mood), "and the map keeps it")
	wet["id"] = "test-wet"
	camp.board.append(wet)
	var back := Campaign.from_dict(JSON.parse_string(JSON.stringify(camp.to_dict())))
	assert_eq(String(back.board[-1].get("mood", "")), String(wet.mood), "a saved board keeps its tower gig's weather")
	var back_m := SceneGen.generate(int(back.board[-1].seed), String(back.board[-1].scene), Campaign.scene_opts(back.board[-1]))
	assert_eq(Atmosphere.of(back_m), String(wet.mood), "and the reloaded gig builds the same weather")
	var old := wet.duplicate()
	old.erase("mood")   # a gig saved before there was weather
	assert_eq(Atmosphere.of(SceneGen.generate(int(old.seed), String(old.scene), Campaign.scene_opts(old))), "clear", "plays in the clear night it always had")
	var dev := CustomGig.build({"tower": "ziggurat", "seed": int(wet.seed)})
	assert_eq(String(dev.mood), Campaign.tower_mood(int(wet.seed), "upper_marina"), "a dev tower gig's seed decides its weather the same way")
	assert_eq(String(CustomGig.build({"tower": "ziggurat", "seed": 5, "mood": "dust"}).mood), "dust", "or the dev card sets it")
	assert_eq(String(CustomGig.from_flags(PackedStringArray(["--tower=raven", "--mood=smog"])).mood), "smog", "and so does --mood")


func test_the_dressing_wears_the_weather() -> void:
	var m := SceneGen.generate(3, "tower_top", {"tower": "raven", "security": 1, "mood": "acid_rain"})
	var td := TowerDress.new(m)
	assert_eq(String(td.atmo.id), "acid_rain")
	var mt := td.tower_mat(1)
	assert_true((mt.get_shader_parameter("cast_col") as Color).is_equal_approx(Color(String(Atmosphere.look("acid_rain").cast))), "the far city takes the acid rain's cast")
	assert_true(float(mt.get_shader_parameter("wet")) > 0.0, "and its glass runs wet")
	var clear := TowerDress.new(SceneGen.generate(3, "tower_top", {"tower": "raven", "security": 1}))
	assert_eq(String(clear.atmo.id), "clear", "no mood: clear")
	assert_eq(float(clear.tower_mat(1).get_shader_parameter("cast_k")), 0.0, "and no cast")
	assert_eq(str(td.plan()), str(clear.plan()), "the weather never moves the dressing")
