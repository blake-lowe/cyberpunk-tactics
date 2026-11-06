extends TestCase
## Owner light review, round 5: "lighter-coloured highlights, not whole light outfits". A unit's
## trim colour goes on a few small parts (armbands, helmet band, pouch flaps) and a narrow shoulder
## edge; the outfit itself keeps its own, darker colours, and no cloth is white or neon.


func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.02


func test_trim_goes_on_small_parts_not_the_whole_outfit() -> void:
	for f in ["arasaka", "tyger_claws", "maelstrom", "trauma_team", "crew"]:
		var team := 0 if f == "crew" else 1
		var c := CharModel.build(team, 3, "solo", "assault_rifle", f)
		var trim: Color = c.look.trim
		var trim_parts := 0
		var body_checked := 0
		for mi: MeshInstance3D in c.find_children("*", "MeshInstance3D", true, false):
			var m := mi.material_override as ShaderMaterial
			if m == null:
				continue
			var mode := int(m.get_shader_parameter("mode"))
			if mode == 0:   # the body: cloth regions keep their own colours
				body_checked += 1
				assert_true(float(m.get_shader_parameter("trim_sheen")) <= 0.4, "%s: shoulder sheen is a partial blend" % f)
				for k in ["jacket", "sleeve", "pants"]:
					var cl: Color = m.get_shader_parameter(k)
					assert_false(_close(cl, trim), "%s: the %s is not in the trim colour" % [f, k])
					assert_true(cl.v <= CharModel.CLOTH_MAX_V + 0.01, "%s: the %s is not white (v %.2f)" % [f, k, cl.v])
					assert_true(cl.s <= CharModel.CLOTH_MAX_S + 0.01, "%s: the %s is not neon (s %.2f)" % [f, k, cl.s])
			elif mode == 2:
				var al: Color = m.get_shader_parameter("albedo")
				if _close(al, trim) or _close(al, trim.darkened(0.25)):
					trim_parts += 1
					var sz := mi.mesh.get_aabb().size * mi.scale
					assert_true(maxf(sz.x, maxf(sz.y, sz.z)) <= 0.3, "%s: trim part %s is small (%s)" % [f, mi.mesh, sz])
		assert_true(body_checked > 0, "%s: body material found" % f)
		assert_true(trim_parts >= 2, "%s: wears its trim (%d parts)" % [f, trim_parts])
		assert_true(trim_parts <= 6, "%s: trim on a few parts only (%d)" % [f, trim_parts])
		c.free()
