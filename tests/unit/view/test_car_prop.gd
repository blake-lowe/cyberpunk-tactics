extends TestCase
## Street cars (CarProp, data/gen/cars.json). Owner verdicts: "the car proportions are laughably
## wrong"; "a smooth car model and different makes and colors". A square is 2 m (CPR core p.127).

const SQ := 2.0   # metres a square


func _fr(make: String, kind := "car", band := "moderate") -> Dictionary:
	return CarProp.frame(kind, Rect2(10, 10, 2, 1), 77, 5, band, make)


func test_a_groundcar_is_real_world_size() -> void:
	var ab := CarProp.bounds(_fr("compact"))
	assert_near(ab.size.x * SQ, 4.5, 0.35, "a groundcar is about 4.5 m long (%.2f m)" % (ab.size.x * SQ))
	assert_near(ab.size.z * SQ, 1.8, 0.12, "about 1.8 m wide (%.2f m)" % (ab.size.z * SQ))
	assert_near(ab.size.y * SQ, 1.45, 0.12, "about 1.45 m tall (%.2f m)" % (ab.size.y * SQ))
	assert_near(ab.position.y, 0.0, 0.01, "standing on the ground")


func test_every_make_is_car_sized_and_sound() -> void:
	for id in CarProp.makes():
		var mk := CarProp.make(String(id))
		assert_true(String(mk.src).contains("p."), "%s: cites its page" % id)
		var ab := CarProp.bounds(_fr(String(id)))
		assert_true(ab.size.x * SQ > 3.4 and ab.size.x * SQ < 5.4, "%s: 3.4-5.4 m long (%.2f)" % [id, ab.size.x * SQ])
		assert_true(ab.size.z * SQ > 1.6 and ab.size.z * SQ < 2.05, "%s: 1.6-2.05 m wide (%.2f)" % [id, ab.size.z * SQ])
		assert_true(ab.size.y * SQ > 1.0 and ab.size.y * SQ < 2.1, "%s: 1.0-2.1 m tall (%.2f)" % [id, ab.size.y * SQ])
		assert_true(ab.size.y < WorldBuilder.FH * 0.7, "%s: well under a storey" % id)
		var r := float(mk.wheel[0])
		var hw := float(mk.width) / 2
		for p in CarProp.parts(_fr(String(id))):
			if p.mat == "tyre":
				assert_true(absf(p.at.z) + p.size.y / 2 <= hw + 0.001, "%s: tyres inset under the body" % id)
				assert_true(CarProp._sill(mk, p.at.x) >= r * 1.9, "%s: an arch over each wheel (sill %.2f over a %.2f tyre)" % [id, CarProp._sill(mk, p.at.x), r * 2])
		var knots: Array = mk.top
		for i in range(1, knots.size()):
			assert_true(float(knots[i][0]) > float(knots[i - 1][0]), "%s: profile knots run front-ward" % id)
		assert_near(float(knots[knots.size() - 1][0]) - float(knots[0][0]), float(mk.length), 0.02, "%s: the profile spans the car" % id)
		var body: Dictionary = CarProp.body(String(id))
		assert_true((body.paint as Mesh).get_aabb().size.x > 0.0 and (body.glass as Mesh).get_aabb().size.x > 0.0, "%s: a lofted body and its glass" % id)


func test_makes_and_paint_by_street() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var zone := {}
	for i in 300:
		zone[CarProp.pick_make(rng, "combat_zone")] = true
	assert_false(zone.has("super"), "no supercars parked in the Combat Zone")
	assert_true(zone.size() >= 4, "several makes on a street (%d)" % zone.size())
	var corp_cols: Array = CarProp.db().paint.corporate.colors
	for i in 30:
		var fr := CarProp.frame("car", Rect2(i, 0, 2, 1), i, 9, "corporate")
		if not fr.cab:
			assert_true(String((fr.paint as Color).to_html(false)) in corp_cols, "corporate paint (%s)" % (fr.paint as Color).to_html(false))
	var a := CarProp.frame("car", Rect2(4, 4, 2, 1), 11, 21, "moderate")
	var b := CarProp.frame("car", Rect2(4, 4, 2, 1), 11, 21, "moderate")
	assert_eq(str(a), str(b), "the same map parks the same car")


func test_a_wreck_is_a_burnt_car_lengthwise() -> void:
	var fr := CarProp.frame("wreck", Rect2(0, 0, 2, 2), 5, 1, "moderate", "compact")
	assert_true(fr.wreck and (fr.paint as Color).is_equal_approx(CarProp.BURNT), "burnt out")
	assert_eq(CarProp.parts(fr).filter(func(p): return p.mat == "tyre").size(), 3, "on three wheels")
	assert_true(absf(fmod(absf(float(fr.yaw)), PI / 2)) > 0.15, "skewed across its square footprint, not drawn square")
	assert_eq(CarProp.corners(_fr("compact"), 0.0).size(), 4, "hazard lamps at its four corners")
