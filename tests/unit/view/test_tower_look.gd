extends TestCase
## Tower looks (TowerLook, data/gen/tower_looks.json) and a tower band's exterior (TowerDress):
## every tower its own look, resolved tower > recipe > default; the dressing placed the same for
## the same map and never over the play area; the impostor facade carries the band's lowest storey
## down; the crown only shows with the roof.

const COLOUR_KEYS := ["glass", "spandrel", "mullion", "slab", "pier", "band_glass"]


func _band(tower: String, seed_value: int) -> TacMap:
	return SceneGen.generate(seed_value, "tower_top", {"tower": tower, "security": 1})


func test_every_tower_has_its_own_look() -> void:
	var data := TowerLook.data()
	var seen := {}
	for lid in World.towers():
		var t := World.tower(String(lid))
		var id := String(t.id)
		assert_true((data.towers as Dictionary).has(id), "%s: a look of its own in tower_looks.json" % id)
		var lk := TowerLook.resolve(id, String(t.recipe))
		for k in COLOUR_KEYS:
			assert_true(Color.html_is_valid(String(lk[k])), "%s: %s is a colour (%s)" % [id, k, lk[k]])
		for k in ["seam", "ledge", "trim", "crown_color", "logo_color", "blade_color", "blade_edge"]:
			assert_true(String(lk.get(k, "")) == "" or Color.html_is_valid(String(lk[k])), "%s: %s is a colour or none" % [id, k])
		assert_true(String(lk.crown) in ["fins", "logo", "ring", "tiers", "mast"], "%s: a crown we build (%s)" % [id, lk.crown])
		for text in [String(lk.get("logo", "")), String(lk.get("blade", ""))]:
			for ch in text.to_upper():
				assert_true(TowerDress.FONT.has(ch), "%s: the pixel font has %s" % [id, ch])
		if String(lk.crown) == "logo":
			assert_true(String(lk.logo) != "", "%s: a logo crown names its logo" % id)
		var sig := "%s|%s|%s|%s|%s" % [lk.spandrel, lk.glass, lk.seam, lk.crown, lk.get("logo", "")]
		assert_false(seen.has(sig), "%s: a look unlike %s's" % [id, seen.get(sig, "")])
		seen[sig] = id


func test_looks_resolve_tower_then_recipe_then_default() -> void:
	var raven := TowerLook.resolve("raven", "tower_corp")
	assert_eq(String(raven.seam), "05d9e8", "Raven: black glass, cyan seams")
	assert_eq(String(raven.crown), "fins")
	var hotel := TowerLook.resolve("highcourt", "tower_hotel")
	assert_eq(String(hotel.spandrel), String(TowerLook.data().recipes.tower_hotel.spandrel), "the hotel wears its recipe's stone")
	assert_eq(String(hotel.blade), "HIGHCOURT", "and its own blade sign")
	assert_true(bool(hotel.pad), "and an AV pad for the Aerocabs")
	var other_hotel := TowerLook.resolve("no_such_tower", "tower_hotel")
	assert_near(float(other_hotel.warm_share), float(TowerLook.data().recipes.tower_hotel.warm_share), 0.001, "an unknown hotel: the recipe's look")
	assert_eq(String(other_hotel.get("blade", "")), "", "but not Highcourt's sign")
	var plain := TowerLook.resolve("", "")
	assert_eq(String(plain.spandrel), String(TowerLook.data().default.spandrel), "no tower: the default")
	var m := _band("ziggurat", 5)
	assert_eq(String(TowerLook.of(m).crown), "tiers", "a band's map: its tower's look")
	assert_true(TowerLook.of(SceneGen.generate(5, "skirmish")).is_empty(), "no look off a tower")


func test_rooms_light_at_the_looks_odds() -> void:
	var lk := TowerLook.resolve("raven", "tower_corp")
	var lit := 0
	var n := 0
	for st in range(1, 60):
		for room in 30:
			n += 1
			lit += int(TowerLook.room_lit(lk, st, room, 77))
			assert_eq(TowerLook.room_lit(lk, st, room, 77), TowerLook.room_lit(lk, st, room, 77), "the same room, the same light")
	var want := float(lk.lit) * (1.0 - float(lk.dark_floors))
	assert_between(float(lit) / n, want - 0.08, want + 0.1, "about the look's share lit (%d of %d)" % [lit, n])


func test_the_dressing_is_deterministic_and_off_the_play_area() -> void:
	for spec in [["raven", 3], ["highcourt", 2], ["maf", 4], ["ziggurat", 5], ["n54", 4]]:
		var m := _band(String(spec[0]), int(spec[1]))
		var a := TowerDress.new(m).plan()
		var b := TowerDress.new(_band(String(spec[0]), int(spec[1]))).plan()
		assert_eq(str(a), str(b), "%s: the same map, the same dressing" % spec[0])
		var c := TowerDress.new(_band(String(spec[0]), int(spec[1]) + 1)).plan()
		assert_true(str(a) != str(c), "%s: another seed, another city" % spec[0])
		var td := TowerDress.new(m)
		var plate := td.face.grow(-0.005)
		var roof := td.rf * TowerDress.FH
		var kinds := {}
		for it in a:
			kinds[it.kind] = true
			var at: Vector3 = it.at
			var sz: Vector3 = it.size
			var foot := Rect2(Vector2(at.x - sz.x / 2, at.z - sz.z / 2), Vector2(sz.x, sz.z))
			if at.y + sz.y / 2 > 0.01:   # above the band's lowest floor: never over the plate
				assert_false(foot.intersects(plate), "%s: %s at %s stands over the play area" % [spec[0], it.kind, at])
			if it.crown:
				assert_true(at.y + sz.y / 2 > roof, "%s: the crown (%s) stands above the roof" % [spec[0], it.kind])
		for k in ["mast", "beacon", "far", "holo", "drone"]:
			assert_true(kinds.has(k), "%s: has %s" % [spec[0], k])
		if "cradle" in td.lk.greebles:
			assert_true(kinds.has("cradle"), "%s: a window-cleaning cradle" % spec[0])
	assert_true(TowerDress.new(_band("maf", 4)).plan().any(func(it): return it.kind == "twin"), "MA&F: its twin")
	assert_true(TowerDress.new(_band("maf", 4)).plan().any(func(it): return it.kind == "bridge"), "joined by walkways")
	assert_true(TowerDress.new(_band("highcourt", 2)).plan().any(func(it): return it.kind == "blade"), "Highcourt: its blade sign")
	assert_true(TowerDress.new(_band("ziggurat", 5)).tiers().size() >= 4, "Ziggurat: stepping out in tiers")


func test_the_facade_carries_the_bands_lowest_storey_down() -> void:
	for spec in [["raven", 3, 2], ["highcourt", 2, 3]]:
		var m := _band(String(spec[0]), int(spec[1]))
		var td := TowerDress.new(m)
		var img := td._facade_mask().get_image()
		var r := td.rect
		var found := 0
		for i in r.size.x:   # the -z face, square by square
			var x := r.position.x + i
			var y := r.position.y
			var kind := int(round(img.get_pixel(i, 0).r8 / 60.0))
			var glass := m.t(0, x, y) == TacMap.T.WALL and int(m.wall_mat[0][y * m.w + x]) in [5, 6]
			assert_eq(kind >= 2, glass, "%s: square %d glazed as the band's storey %s" % [spec[0], i, m.floor_name(0)])
			found += int(kind == int(spec[2]))
		assert_true(found > 0, "%s: its windows (%d) are in the mask" % [spec[0], spec[2]])


func test_the_band_wears_the_look_outside_and_the_city_is_batched() -> void:
	var m := _band("raven", 3)
	var vision := Vision.new(m, Los.new(m))
	var wb := WorldBuilder.new(m, vision, ImageTexture.create_from_image(Image.create(m.w, m.h * m.floors, false, Image.FORMAT_RG8)))
	var root := Node3D.new()
	wb.build(root)
	var sp := Color(String(TowerLook.of(m).spandrel))
	var skins := wb.materials().filter(func(mt): return (mt.get_shader_parameter("albedo") as Color).is_equal_approx(Color(sp, 1.0)) and bool(mt.get_shader_parameter("cuttable")))
	assert_true(skins.size() >= m.floors - 1, "the facade's skin on each storey of the band (%d)" % skins.size())
	var sky := root.get_node("skyline")
	assert_true(sky.get_child_count() < 80, "the city round the band in a few batches (%d)" % sky.get_child_count())
	assert_eq(wb._td, null, "the builder lets its tower dressing go")
	root.free()


func test_crown_signs_read_from_outside_the_footprint() -> void:
	# owner: the crown text read flipped (it faced in across the roof): every sign face now faces
	# out of the plate, its text running to the right of a viewer outside looking back at it
	for spec in [["continental", 4], ["maf", 4], ["segotari", 4], ["n54", 4], ["highcourt", 2]]:
		var m := _band(String(spec[0]), int(spec[1]))
		var td := TowerDress.new(m)
		var c := td.face.get_center()
		var centre := Vector3(c.x, 0, c.y)
		var signs := td.plan().filter(func(it): return it.kind in ["logo", "blade"])
		assert_true(not signs.is_empty(), "%s: has its sign" % spec[0])
		var normals := {}
		for it in signs:
			var at: Vector3 = it.at
			var sz: Vector3 = it.size
			var foot := Rect2(Vector2(at.x - sz.x / 2, at.z - sz.z / 2), Vector2(sz.x, sz.z))
			assert_false(foot.intersects(td.face.grow(-0.005)), "%s: the %s stands outside the footprint" % [spec[0], it.kind])
			for f in it.faces:
				var n: Vector3 = f[0]
				var right: Vector3 = f[1]
				assert_true(right.is_equal_approx(Vector3.UP.cross(n)), "%s: %s text runs left to right seen from its %s side" % [spec[0], it.kind, n])
				assert_near(right.dot(n), 0.0, 0.001, "and along the face")
				if it.kind == "logo":
					assert_true((at - centre).dot(n) > 0.0, "%s: the logo on face %s faces away from the plate's centre" % [spec[0], n])
					normals[n] = true
		if String(td.lk.crown) == "logo":
			assert_eq(normals.size(), 4, "%s: the name on every face" % spec[0])
			for it in signs:
				assert_true(it.at.y < td.rf * TowerDress.FH and it.at.y + it.size.y / 2 <= td.rf * TowerDress.FH, "%s: under the roof's edge, never over the play area" % spec[0])
