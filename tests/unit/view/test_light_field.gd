extends TestCase
## The baked light (LightPlan + LightField). Owner light review: no interior boost, and no
## "darkening vignette on the edges of every room": a room light fills its room evenly.


func test_a_room_light_fills_its_room_evenly() -> void:
	var m := SceneGen.generate(4, "lone_building", {"security": 2})
	var plan := LightPlan.plan(m, m.seed_value)
	var room_lights := plan.filter(func(e): return e.kind == "room")
	assert_true(room_lights.size() >= 3, "rooms have lights (%d)" % room_lights.size())
	var img := LightField.bake(m, Los.new(m), room_lights).get_image()
	var tpc := img.get_width() / m.w
	var checked := 0
	for e in room_lights.slice(0, 4):
		var c: Vector3i = e.cell
		var room := int(e.room)
		var mid := img.get_pixel(c.x * tpc + tpc / 2, (c.z * m.h + c.y) * tpc + tpc / 2)
		assert_true(maxf(mid.r, maxf(mid.g, mid.b)) > 0.1, "the room is lit")
		for y in m.h:
			for x in m.w:
				if m.label(c.z, x, y) != room:
					continue
				var p := img.get_pixel(x * tpc + tpc / 2, (c.z * m.h + y) * tpc + tpc / 2)
				assert_true(absf(p.r - mid.r) < 0.02 and absf(p.g - mid.g) < 0.02, "square %s is as lit as the middle (no pool)" % Vector2i(x, y))
				checked += 1
	assert_true(checked > 20, "squares checked (%d)" % checked)


func test_fill_adds_no_interior_light() -> void:
	var m := SceneGen.generate(4, "lone_building", {"security": 2})
	for e in LightPlan.fill(m, m.seed_value):
		assert_eq(String(e.kind), "porch", "fill() is only porch lamps over street doors")
		assert_true(e.get("bake", false), "view-only")
