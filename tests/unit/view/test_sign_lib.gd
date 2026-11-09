extends TestCase
## The sign library (SignLib, data/gen/signs.json, SignBatch): its data validates (every glyph
## drawn, real CJK with its meaning, fictional names), text reads from outside on every face,
## facade signs are placed the same for the same map and stay sparse.

const MIN_SIGNS := 50


func _street_map(seed_value: int) -> TacMap:
	return SceneGen.generate(seed_value, "neighborhood", {"district": "little_china"})


func _build(m: TacMap) -> WorldBuilder:
	var wb := WorldBuilder.new(m, Vision.new(m, Los.new(m)), ImageTexture.create_from_image(Image.create(m.w, m.h * m.floors, false, Image.FORMAT_RG8)))
	var root := Node3D.new()
	wb.build(root)
	root.free()
	return wb


func test_the_library_data_validates() -> void:
	var sites: Dictionary = RulesDB.gen("sites.json")
	var ids := {}
	var cjk := 0
	var holo_forms := {}
	for e in SignLib.entries():
		var id := String(e.id)
		assert_false(ids.has(id), "%s: ids are unique" % id)
		ids[id] = true
		assert_true(String(e.kind) in SignLib.KINDS, "%s: a kind we draw (%s)" % [id, e.kind])
		var forms: Array = SignLib.NEON_FORMS if e.kind == "neon" else SignLib.HOLO_FORMS.keys()
		assert_true(String(e.form) in forms, "%s: a %s form we draw (%s)" % [id, e.kind, e.form])
		assert_true(String(e.anim) in SignLib.ANIMS, "%s: an animation we play (%s)" % [id, e.anim])
		assert_true(not (e.colors as Array).is_empty(), "%s: has its colours" % id)
		for c in e.colors:
			assert_true(Color.html_is_valid(String(c)), "%s: %s is a colour" % [id, c])
		for t in e.tags:
			assert_true(sites.has(t) or t in SignLib.PLACE_TAGS or t in ["bar", "food"], "%s: tag %s is a site kind or a placement" % [id, t])
		var text := String(e.get("text", ""))
		if e.kind == "neon":
			for i in text.length():
				assert_true(SignLib.has_glyph(text[i]), "%s: the neon font draws '%s'" % [id, text[i]])
				if SignLib.is_cjk(text[i]):
					cjk += 1
			if String(e.form) == "icon":
				assert_true(SignLib.has_glyph("@" + String(e.icon)), "%s: its icon %s is drawn" % [id, e.icon])
			if String(e.form) == "cjk" or (text.length() > 0 and SignLib.is_cjk(text[0])):
				assert_true(String(e.get("meaning", "")) != "", "%s: a CJK sign says what it reads (no gibberish)" % id)
			var lay := SignLib.layout(e)
			assert_true((lay.segs as Array).size() >= 2, "%s: laid out in tubes (%d)" % [id, (lay.segs as Array).size()])
			assert_true(lay.size.x > 0.0 and lay.size.y > 0.0, "%s: a size (%s)" % [id, lay.size])
		else:
			holo_forms[String(e.form)] = true
			for s in [text, String(e.get("line", ""))]:
				for i in s.length():
					assert_true(SignLib.FONT.has(s[i]), "%s: the pixel font draws '%s'" % [id, s[i]])
	assert_true(ids.size() >= MIN_SIGNS, "a library, not a handful (%d)" % ids.size())
	assert_true(cjk >= 8, "kanji, katakana and hangul signs (%d glyphs)" % cjk)
	for f in ["logo", "ticker", "dancer", "product"]:
		assert_true(holo_forms.has(f), "an animated holo %s" % f)
	assert_eq(SignLib.atlas().get_height(), SignLib.entries().filter(func(e): return e.kind == "holo").size() * 16, "one atlas row a holo ad")


func test_picks_suit_the_place() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 40:
		var e := SignLib.pick(rng, "neon", ["clinic"])
		assert_true("clinic" in (e.tags as Array), "a clinic's sign is a clinic's (%s)" % e.id)
	var b := SignLib.pick(rng, "neon", ["no_such_site"], ["blade"])
	assert_eq(String(b.form), "blade", "an unknown place still gets a sign of the form asked")
	assert_true(SignLib.site_tags("gun_shop").has("generic"), "every site may hang a generic street sign")


func test_sign_text_reads_from_outside() -> void:
	# owner: crown text once read flipped; every face's text runs left to right for a viewer
	# outside looking back at it (right = UP x out), first letter on the left
	var b := SignBatch.new()
	for out in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		for id in ["bar", "ja_ramen", "ko_ramen", "arrow_hotel", "clinic", "holo_veltrix"]:
			var rec := b.wall(SignLib.entry(id), Vector3(5, 1.4, 5), out, 1.5, 0.4, 3)
			_check_faces(rec, "%s facing %s" % [id, out])
			var ls: Array = rec.letters
			if ls.size() >= 2:
				var right: Vector3 = rec.faces[0][1]
				assert_true((ls[0][0] as Vector3).dot(right) < (ls[ls.size() - 1][0] as Vector3).dot(right), "%s facing %s: reads left to right" % [id, out])
				for l in ls:
					assert_true(((l[0] as Vector3) - Vector3(5, 1.4, 5)).dot(out) > 0.0, "%s: the letters stand in front of the wall" % id)
		var bl := b.blade(SignLib.entry("hotel_blade"), Vector3(5, 1.4, 5), out, 0.4, 1.4, 3)
		_check_faces(bl, "blade facing %s" % out)
		assert_eq((bl.faces as Array).size(), 2, "a blade has a face each side")
		var ls2: Array = bl.letters
		assert_true((ls2[0][0] as Vector3).y > (ls2[1][0] as Vector3).y, "a blade's letters run down it")
		assert_true(((bl.at as Vector3) - Vector3(5, 1.4, 5)).dot(out) > 0.0, "a blade stands out from its wall")


func _check_faces(rec: Dictionary, what: String) -> void:
	for f in rec.faces:
		var n: Vector3 = f[0]
		var right: Vector3 = f[1]
		assert_true(right.is_equal_approx(Vector3.UP.cross(n).normalized()), "%s: text runs along UP x out" % what)
		assert_near(right.dot(n), 0.0, 0.001, "%s: and along the face" % what)


func test_facade_signs_face_the_street() -> void:
	var m := _street_map(21)
	var wb := _build(m)
	var recs: Array = wb.sign_batch.placed
	assert_true(recs.size() >= 4, "the streets hang library signs (%d)" % recs.size())
	for r in recs:
		_check_faces(r, String(r.id))
		var at: Vector3 = r.at
		var probe := at + (r.out as Vector3) * 0.8
		var f := clampi(int(floor((at.y - 0.01) / WorldBuilder.FH)), 0, m.floors - 1)
		if m.inb(int(floor(probe.x)), int(floor(probe.z))):
			assert_true(m.t(f, int(floor(probe.x)), int(floor(probe.z))) != TacMap.T.WALL, "%s at %s: faces open air, not into a wall" % [r.id, at])


func test_placement_is_deterministic_and_sparse() -> void:
	var a := _build(_street_map(21))
	var b := _build(_street_map(21))
	var sig := func(wb: WorldBuilder) -> Array: return wb.sign_batch.placed.map(func(r): return "%s@%s" % [r.id, r.at])
	assert_eq(sig.call(a), sig.call(b), "the same map hangs the same signs in the same places")
	assert_eq(a.sign_batch.count(), b.sign_batch.count(), "and the same instances")
	var c := _build(_street_map(22))
	assert_true(sig.call(a) != sig.call(c), "another map, other signs")
	var m := _street_map(21)
	var spots: Array = a._sign_at
	assert_true(spots.size() <= maxi(4, m.w * m.h / WorldBuilder.SIGN_AREA), "a few a street, not wallpaper (%d)" % spots.size())
	for i in spots.size():
		for j in range(i + 1, spots.size()):
			var p: Vector3 = spots[i]
			var q: Vector3 = spots[j]
			assert_true(Vector2(p.x - q.x, p.z - q.z).length() >= WorldBuilder.SIGN_GAP, "facade signs stand apart")
	var ids := {}
	for r in a.sign_batch.placed:
		ids[r.id] = int(ids.get(r.id, 0)) + 1
	assert_true(ids.size() * 3 >= a.sign_batch.placed.size(), "varied: %d kinds over %d signs" % [ids.size(), a.sign_batch.placed.size()])


func test_a_batch_is_four_draws() -> void:
	var b := SignBatch.new()
	for id in ["bar", "holo_news", "dance"]:
		if SignLib.entry(id).form == "blade":
			b.blade(SignLib.entry(id), Vector3.ZERO, Vector3.BACK, 0.4, 1.4, 1)
		else:
			b.wall(SignLib.entry(id), Vector3.ZERO, Vector3.BACK, 1.4, 0.4, 1)
	var root := Node3D.new()
	var nodes := b.flush(root, Vector2(10, 10))
	assert_eq(nodes.size(), 4, "tubes, glow, boards and holo screens: one MultiMesh each")
	root.free()
