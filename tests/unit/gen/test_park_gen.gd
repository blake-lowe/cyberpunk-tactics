extends TestCase
## Theme parks (ParkGen, DistrictGen `midway` profiles; Playland by the Sea, NC2045 p.302-313):
## every land plays (the deploy zone reaches every room, the rides leave their lots walkable, the
## target's jack point is reachable on foot) over several seeds, and reads as a park: rides, booths,
## string lights, queue rails, the boardwalk and its pier; the Haunted Woods a dense fake forest on
## earth paths.

const SEEDS := [3, 7, 11, 23]
const RIDE_PIECES := ["wheel", "carousel", "drop_tower", "spinner", "swings"]

static var _cache := {}


func _map(profile: String, sd: int) -> TacMap:
	var k := "%s/%d" % [profile, sd]
	if not _cache.has(k):
		_cache[k] = SceneGen.generate(sd, "neighborhood", Campaign.scene_opts({"profile": profile, "district": "playland", "site": "club", "security": 2}))
	return _cache[k]


func _deploy(m: TacMap) -> Vector3i:
	for e in m.entrances:
		if e.kind == "deploy":
			return Vector3i(e.pos.x, e.pos.y, 0)
	return Vector3i(-1, -1, -1)


func test_park_lands_are_playable() -> void:
	for prof in ["theme_park", "haunted_woods"]:
		for sd in SEEDS:
			var m := _map(prof, sd)
			var tag := "%s seed %d" % [prof, sd]
			var d0 := _deploy(m)
			assert_true(d0.x >= 0 and m.walkable(0, Vector2i(d0.x, d0.y)), "%s: a deploy zone on open ground" % tag)
			if d0.x < 0:
				continue
			var reach := m.reachable(d0)
			for e in m.entrances:
				if e.kind == "deploy":
					for cell in e.get("cells", []):
						assert_true(reach.has(Vector3i(cell.x, cell.y, 0)), "%s: deploy square %s connected" % [tag, cell])
			for r in m.rooms:
				if r.cells == 0:
					continue
				var cells := Furnish.room_cells(m, r)
				assert_true(cells.any(func(c): return reach.has(Vector3i(c.x, c.y, r.floor))), "%s: %s %d unreachable" % [tag, r.kind, r.id])
				if r.kind == "ride":   # a ride never seals off part of its own lot
					for c in cells:
						if m.walkable(0, c):
							assert_true(reach.has(Vector3i(c.x, c.y, 0)), "%s: ride lot %d square %s cut off" % [tag, r.id, c])


func test_the_target_can_be_reached_on_foot() -> void:
	for prof in ["theme_park", "haunted_woods"]:
		for sd in SEEDS:
			var m := _map(prof, sd)
			var e := Encounter.setup(m, Dice.new(3), [Recruit.generate(Dice.new(1), "netrunner", "edgerunner")] as Array[Combatant])
			var field: Dictionary = e.nav.distance_field([e.units[0].pos], {}, 3000)
			var ok := false
			for sid in m.architectures:
				if not m.structures[sid].target:
					continue
				for ap in (m.architectures[sid] as NetArchitecture).access_points:
					var d: Dictionary = m.devices[ap.device]
					var dp := Vector3i(d.pos.x, d.pos.y, d.floor)
					for cell in field:
						if cell.z == dp.z and Los.distance_m(cell, dp) <= 6.0 and not e._wall_between(cell, dp):
							ok = true
							break
			assert_true(ok, "%s seed %d: a jack point reachable without breaching" % [prof, sd])


func test_a_theme_park_reads_as_one() -> void:
	for sd in SEEDS:
		var m := _map("theme_park", sd)
		var tag := "theme_park seed %d" % sd
		var kinds := {}
		for c in m.cover:
			if String(c.kind) in RIDE_PIECES:
				kinds[c.kind] = true
		for d in m.decor:
			kinds[d.kind] = true
		var rides := kinds.keys().filter(func(k): return k in RIDE_PIECES or k in ["coaster", "pavilion"])
		assert_true(rides.size() >= 4, "%s: several kinds of ride (%s)" % [tag, rides])
		assert_true(kinds.has("wheel"), "%s: a big wheel (on the pier)" % tag)
		for k in ["string_pole", "rail"]:
			assert_true(kinds.has(k), "%s: %s" % [tag, k])
		assert_true(m.cover.filter(func(c): return c.kind == "game_booth").size() >= 4, "%s: game booths along the midways" % tag)
		var water := 0
		var dock := 0
		for y in m.h:
			for x in m.w:
				if m.t(0, x, y) == TacMap.T.WATER:
					water += 1
				elif m.ground[y * m.w + x] == TacMap.G.DOCK:
					dock += 1
		assert_true(water > 0 and dock > m.w * 3, "%s: the boardwalk and pier on the sea" % tag)
		assert_false(m.cover.any(func(c): return c.kind in ["water_tank", "solar"]), "%s: no tenement water tanks on the park's roofs" % tag)
		# rides block movement where the real thing would: wheel legs, coaster supports, kiosks
		for c in m.cover:
			if String(c.kind) in ["wheel", "coaster_post", "kiosk", "game_booth"]:
				assert_false(m.walkable(0, c.pos), "%s: %s blocks movement" % [tag, c.kind])


func test_the_haunted_woods_are_a_dense_wood() -> void:
	for sd in SEEDS:
		var m := _map("haunted_woods", sd)
		var pines := m.cover.filter(func(c): return c.kind == "pine").size()
		var dirt := 0
		var paving := 0
		for g in m.ground:
			if g == TacMap.G.DIRT:
				dirt += 1
			elif g == TacMap.G.SIDEWALK:
				paving += 1
		assert_true(pines >= m.w * m.h / 40, "seed %d: a dense wood (%d pines)" % [sd, pines])
		assert_true(dirt > m.w * 4, "seed %d: earth paths through it" % sd)
		assert_true(paving < dirt / 4, "seed %d: paths, not pavements (%d paved squares)" % [sd, paving])
		assert_true(m.structures.any(func(s): return s.target), "seed %d: the attraction is the target building" % sd)


func test_a_profile_look_goes_over_the_district() -> void:
	var lk := DistrictLook.of_params({"scene": "neighborhood", "district": "playland", "profile": "haunted_woods"})
	assert_eq(String(lk.get("tree", "")), "pine", "the woods' own street tree")
	assert_eq(lk.get("neon"), RulesDB.gen("districts.json").haunted_woods.look.neon, "its own sign colours")
	assert_true(lk.get("mats", {}).has("dirt") and lk.get("mats", {}).has("sidewalk"), "its mats merged over the district's")
	assert_eq(DistrictLook.of_params({"scene": "neighborhood", "district": "playland"}), DistrictLook.of("playland"), "no profile, the district's look")
	var tp := DistrictLook.of_params({"scene": "neighborhood", "district": "playland", "profile": "theme_park"})
	var prof := DistrictLook.profile(RulesDB.gen("districts.json").theme_park, tp, 3)
	assert_false(prof.mix.has("park") and float(prof.mix.park) > 0.0, "green_lots 0: green streets without turning lots into parks")
