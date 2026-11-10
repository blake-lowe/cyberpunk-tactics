extends TestCase
## Light by the hour (Daylight; owner verdict 2026-11-09): the hour → light-band mapping, the band
## agreeing with the scene event's table, the campaign gig carrying its arrival hour to the map,
## the hour surviving a save, the night look staying exactly what it was, and the day looks' data.

const GREYBOX := preload("res://src/tactical/greybox.gd")


## A bare map with these params (scene_look reads only params and the tower flag).
func _map(params: Dictionary, tower := false) -> TacMap:
	var m := TacMap.new(4, 4, 1)
	m.params = params.duplicate()
	if tower:
		m.tower = {"id": "raven"}
	return m


## The look as greybox _scene_look built it before the day pass (verbatim), for the night check.
func _legacy_look(m: TacMap, sky_flag := "") -> Dictionary:
	var LOOKS: Dictionary = GREYBOX.LOOKS
	var lk: Dictionary = LOOKS.get(String(m.params.get("scene", "")), LOOKS["default"])
	var day := m.is_tower() and (sky_flag == "day" or (sky_flag == "" and String(m.params.get("sky", "")) == "day"))
	var dl: Dictionary = SceneTheme.of(m).get("light", {}) if not day else {}
	if day:
		lk = LOOKS["tower_day"]
	var air := Atmosphere.light(Atmosphere.of(m), day) if m.is_tower() else {}
	if dl.is_empty() and air.is_empty():
		return lk
	lk = lk.duplicate()
	lk.merge(dl, true)
	lk.merge(air, true)
	return lk


func test_hour_bands() -> void:
	var want := {0: "after_midnight", 3: "after_midnight", 5: "after_midnight", 6: "dawn", 7: "day", 12: "day", 17: "day",
		18: "dusk", 19: "night", 22: "night", 23: "night"}
	for h in want:
		assert_eq(Daylight.band(h), want[h], "%02d:00" % h)
	assert_eq(Daylight.band(24), "after_midnight", "the clock wraps")
	for h in 24:   # a tower gig's sky wins, as it does for the scene event
		assert_eq(Daylight.band(h, "day"), "day", "a day sky at %d" % h)
		assert_eq(Daylight.band(h, "night"), "after_midnight" if h < 6 else "night", "a night sky at %d" % h)
	assert_eq(Daylight.of_params({}), "night", "no hour (dev renders without --hour): night, as before")
	assert_eq(Daylight.of_params({"hour": 13}), "day")
	assert_eq(Daylight.of_params({"sky": "day"}), "day", "a day tower without an hour")
	for b in Daylight.BANDS:
		assert_eq(Daylight.is_lit(b), b in ["dawn", "day", "dusk"], b)
	assert_eq(Daylight.factor("night"), 0.0)
	assert_eq(Daylight.factor("day"), 1.0)


func test_band_agrees_with_the_scene_event_clock() -> void:
	for h in 24:
		for mm in [0, 30, 59]:
			for sky in ["", "day", "night"]:
				var t := SceneEvent.time_of(h * 60 + mm, sky)
				assert_true(Daylight.agrees(Daylight.band(h, sky), t), "%02d:%02d sky '%s': band %s, scene event %s" % [h, mm, sky, Daylight.band(h, sky), t])


func test_sun_follows_the_hour() -> void:
	var dawn := Daylight.sun(6)
	var noon := Daylight.sun(12)
	var dusk := Daylight.sun(18)
	assert_true(float(noon[0]) < float(dawn[0]) and float(noon[0]) < float(dusk[0]), "highest at noon")
	assert_between(float(noon[0]), -55.0, -40.0, "a high midday sun that still casts shadows")
	assert_between(float(dawn[0]), -20.0, -10.0, "low at dawn: long shadows")
	assert_true(float(dawn[1]) != float(dusk[1]), "rises and sets on opposite sides")


## A campaign gig keeps the hour the crew arrives (after the drive) and hands it to the map; the
## map's band and the scene event's table agree, and a reload starts the same gig at the same hour.
func test_campaign_gig_hour_reaches_the_map_and_agrees_with_the_street() -> void:
	for start in [2 * 60, 6 * 60 + 40, 11 * 60, 17 * 60 + 50, 18 * 60 + 20, 21 * 60]:
		var c := Campaign.new_game(31)
		c.minutes = start
		var saved := c.to_dict()
		var g := c.accept(0)
		assert_false(g.is_empty(), "a board gig to take")
		assert_eq(int(g.hour), c.minutes / 60, "the hour after the drive (%d min)" % int(g.get("travel_minutes", 0)))
		var o := Campaign.scene_opts(g)
		assert_eq(int(o.get("hour", -1)), int(g.hour), "the map gets the hour")
		var m := SceneGen.generate(int(g.seed), String(g.scene), o)
		var band := Daylight.of_map(m)
		assert_eq(band, Daylight.band(int(g.hour), String(g.get("sky", ""))), "the map's band")
		if g.get("scene_event") is Dictionary:
			assert_true(Daylight.agrees(band, String(g.scene_event.time)), "the street's table (%s) agrees with the light (%s)" % [g.scene_event.time, band])
		assert_true(Daylight.agrees(band, SceneEvent.time_of(int(g.hour) * 60, String(g.get("sky", "")))), "the clock's time agrees")
		var r := Campaign.from_dict(JSON.parse_string(JSON.stringify(saved)))   # save, reload, take the same gig
		var g2 := r.accept(0)
		assert_eq(int(g2.hour), int(g.hour), "a reload plays the same hour")
		assert_eq(g2.get("scene_event"), g.get("scene_event"), "and the same street")


## The night look is exactly what it was: for every scene and district, a map with no hour, at night
## and after midnight gets the look the old _scene_look built, key for key.
func test_night_look_unchanged() -> void:
	var scenes: Array = RulesDB.gen("scenes.json").keys().filter(func(k): return not String(k).begins_with("_"))
	var districts: Array = [""] + DistrictLook.looks().keys()
	var n := 0
	for sc in scenes:
		for did in districts:
			for hour in [-1, 19, 22, 23, 0, 3, 5]:
				var p := {"scene": sc, "district": did}
				if hour >= 0:
					p["hour"] = hour
				var m := _map(p)
				assert_eq(GREYBOX.scene_look(m), _legacy_look(m), "%s in %s at %d" % [sc, did, hour])
				n += 1
	for sky in ["", "night", "day"]:   # tower bands: their own sky, as before
		for mood in ["", "acid_rain", "smog"]:
			var p := {"scene": "tower_top", "district": "kabuki", "sky": sky, "mood": mood, "hour": 13}
			var m := _map(p, true)
			assert_eq(GREYBOX.scene_look(m), _legacy_look(m), "a tower band, sky '%s' mood '%s'" % [sky, mood])
			n += 1
	assert_true(n > 1000, "checked %d looks" % n)
	assert_eq(GREYBOX.LOOKS["default"], {"ambient": "262c44", "amb_e": 0.65, "key": "8fa0e0", "key_e": 0.5, "fog": "0d1422", "fog_d": 0.0035},
		"the approved night city, value for value")


func test_day_looks_read_as_day() -> void:
	var night: Dictionary = GREYBOX.LOOKS["default"]
	for did in [""] + DistrictLook.looks().keys():
		for hour in [6, 12, 18]:
			var m := _map({"scene": "street_block", "district": did, "hour": hour})
			var lk: Dictionary = GREYBOX.scene_look(m)
			var where := "%s at %d" % [did, hour]
			assert_true(float(lk.amb_e) * Color(lk.ambient).get_luminance() > float(night.amb_e) * Color(night.ambient).get_luminance() * 2.0, "%s: a bright sky light" % where)
			assert_true(float(lk.key_e) > float(night.key_e) * 2.0, "%s: a sun, not a moon" % where)
			assert_eq((lk.sun as Array).size(), 2, "%s: the sun stays put in the world" % where)
			assert_true(float(lk.get("day_factor", 0.0)) > 0.0 and float(lk.get("lights", 1.0)) < 1.0, "%s: lamps and glow dimmed" % where)
			var pal := String(lk.get("palette", ""))
			assert_true(pal == "sunset" or SceneTheme.palettes().has(pal), "%s: palette %s exists" % [where, pal])
			assert_false((lk.get("window_light", []) as Array).is_empty(), "%s: daylight through the windows" % where)
	var uc := _map({"scene": "undercity", "hour": 12})
	assert_eq(GREYBOX.scene_look(uc), GREYBOX.LOOKS["undercity"], "no sky under the city: the same look at noon")
	var bl := _map({"scene": "badlands", "district": "outskirts", "hour": 18})
	assert_eq(GREYBOX.scene_look(bl).sun, GREYBOX.LOOKS["badlands"].sun, "the badlands' approved sunset is its dusk")
	var sm := _map({"scene": "street_block", "district": "kabuki", "hour": 13, "mood": "smog"})
	var plain := GREYBOX.scene_look(_map({"scene": "street_block", "district": "kabuki", "hour": 13}))
	var air := Atmosphere.ground_air("smog", true)
	assert_eq(GREYBOX.scene_look(sm).sky, air.sky, "a mood's sky over the day look")
	var want := Color(String(plain.fog)).lerp(Color(String(air.fog)), 0.5)
	assert_true(Color(String(GREYBOX.scene_look(sm).fog)).is_equal_approx(want) or Color(String(GREYBOX.scene_look(sm).fog)).to_html(false) == want.to_html(false), "its fog half-way to the mood's")
	assert_near(float(GREYBOX.scene_look(sm).fog_d), float(plain.fog_d) * float(air.fog_k), 0.000001, "the street's own fog, thicker")
	assert_false(GREYBOX.scene_look(sm).has("fog_k"), "fog_k is spent on the density")
	for k in ["key", "key_e", "ambient", "amb_e", "rim", "fog_h", "fog_hd"]:
		assert_eq(GREYBOX.scene_look(sm).get(k), plain.get(k), "but never the %s" % k)
	assert_eq(GREYBOX.scene_look(_map({"scene": "undercity", "hour": 13, "mood": "storm"})), GREYBOX.scene_look(_map({"scene": "undercity", "hour": 13})), "no weather under the city")


func test_bake_lights_by_day() -> void:
	var m := SceneGen.generate(9, "lone_building", {"security": 1})
	var e: Array = LightPlan.plan(m, m.seed_value) + LightPlan.fill(m, m.seed_value)
	assert_eq(Daylight.bake_lights(m, e, 1.0, 1.0), e, "night: the bake's lights unchanged")
	var d := Daylight.bake_lights(m, e, 0.2, 2.0)
	assert_eq(d.size(), e.size())
	var rooms := 0
	for i in e.size():
		if e[i].has("room"):
			rooms += 1
			assert_near(float(d[i].energy), float(e[i].energy) * 2.0, 0.0001, "room lights on and up by day (offices are lit under the roof's shadow)")
		elif String(e[i].kind) in ["lamp", "sign", "porch"]:
			assert_near(float(d[i].energy), float(e[i].energy) * 0.2, 0.0001, "%s outdoors drowned by the sun" % e[i].kind)
	assert_true(rooms > 0)
	var wl := Daylight.window_light(m, Color.WHITE, 0.9)
	assert_true(wl.size() > 0, "daylight comes in through the doors and glass")
	for w in wl:
		assert_eq(m.t(w.cell.z, w.cell.x, w.cell.y), TacMap.T.FLOOR, "a pool inside the opening")
	assert_eq(Daylight.window_light(m, Color.WHITE, 0.0), [], "none at night")
	assert_eq(LightPlan.plan(m, m.seed_value), LightPlan.plan(m, m.seed_value), "the rules' lit squares don't depend on the hour")
