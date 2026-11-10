extends TestCase
## Owner playtest v0.10.1, view fixes: the camera's clip range holds the whole scene at every zoom
## and angle (CamFrame.clip_range), the objective marker's label has no star and is 2/3 the size
## (Hud.marker_label), and a bystander never takes a gun stance (CharModel.hands_free_clip).


## The camera as greybox._place_camera puts it: `dist` out along the zoom's pitch at `yaw`.
func _cam(focus: Vector3, yaw: float, dist: float) -> Transform3D:
	var p := CamFrame.pitch(dist)
	var off := Vector3(0, sin(p), cos(p)).rotated(Vector3.UP, deg_to_rad(yaw)) * dist
	return Transform3D.IDENTITY.translated(focus + off).looking_at(focus)


func _depth(xf: Transform3D, p: Vector3) -> float:
	return (p - xf.origin).dot(-xf.basis.z)


func test_the_clip_range_holds_the_scene_at_every_zoom_and_angle() -> void:
	# a 60 x 50 map, a skyline ring 110 m out with towers up to 70 m, the far ground below grade
	var box := AABB(Vector3(-110, -60, -110), Vector3(280, 130, 270))
	var corners: Array[Vector3] = []
	for i in 8:
		corners.append(box.get_endpoint(i))
	var tower_top := Vector3(30, 70, 120)   # a tall tower on the camera side of the focus
	var worst_near := INF
	for dist in [8.0, 12.0, 20.0, 40.0, 70.0, 120.0, 160.0, CamFrame.MAX_DIST]:
		for yaw in range(0, 360, 15):
			for focus in [Vector3(0, 0, 0), Vector3(30, 0, 25), Vector3(60, 12, 50)]:
				var xf := _cam(focus, float(yaw), dist)
				var clip := CamFrame.clip_range(xf, box, true)
				for c in corners:
					var d := _depth(xf, c)
					assert_true(d >= clip.x and d <= clip.y, "dist %s yaw %s: a corner of the scene at depth %.1f sits inside [%.1f, %.1f]" % [dist, yaw, d, clip.x, clip.y])
				assert_true(_depth(xf, tower_top) >= clip.x, "dist %s yaw %s: the tower top is not cut by the near plane" % [dist, yaw])
				worst_near = minf(worst_near, clip.x)
	assert_true(worst_near < 0.0, "the orthographic near plane reaches behind the camera (the old 0.05 cut towers off)")


func test_the_perspective_look_keeps_a_small_positive_near() -> void:
	var box := AABB(Vector3(-100, -20, -100), Vector3(260, 90, 260))
	var xf := _cam(Vector3(30, 0, 30), 45.0, 40.0)
	var clip := CamFrame.clip_range(xf, box, false)
	assert_near(clip.x, CamFrame.PERSP_NEAR, 0.0001, "a perspective camera can't see behind itself")
	for i in 8:
		assert_true(_depth(xf, box.get_endpoint(i)) <= clip.y, "the far plane still holds every corner")


func test_the_far_plane_grows_with_the_zoom() -> void:
	var box := AABB(Vector3(-60, 0, -60), Vector3(180, 40, 180))
	var near_far := CamFrame.clip_range(_cam(Vector3(30, 0, 30), 0.0, 12.0), box, true)
	var far_far := CamFrame.clip_range(_cam(Vector3(30, 0, 30), 0.0, 160.0), box, true)
	assert_true(far_far.y > near_far.y, "zoomed out the far plane moves out with the camera")
	assert_true(far_far.y > 160.0, "at the zoom-out limit the focus itself (160 m off) is well inside")


func test_the_objective_marker_label_has_no_star() -> void:
	assert_eq(Hud.marker_label("★ ACCESS POINT", 13), "ACCESS POINT  13 M")
	assert_eq(Hud.marker_label("★ TARGET · MARA VOSS", 4), "TARGET · MARA VOSS  4 M")
	assert_eq(Hud.marker_label("EXTRACT", 20), "EXTRACT  20 M", "a label with no star is left as it is")
	assert_near(Hud.MARK_SCALE, 2.0 / 3.0, 0.001, "the pointer is 2/3 the old size")
	assert_true(Hud.MARK_FONT <= 11, "and so is the label (was 16)")


func test_every_objectives_marker_label_drops_the_star() -> void:
	for kind in Objective.kinds():
		var m := SceneGen.generate(11, "lone_building", {"security": 2, "site": "corp_office"})
		var dice := Dice.new(7)
		var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
		var e := Encounter.setup(m, dice, crew, String(kind))
		for mk in e.obj.marks(false):
			if mk.get("extract", false):
				continue
			var shown := Hud.marker_label(String(mk.label), 7)
			assert_false(shown.contains("★"), "%s: no star on the marker: %s" % [kind, shown])
			assert_true(shown.ends_with("  7 M") and not shown.begins_with(" "), "%s: what, then how far: %s" % [kind, shown])


func test_a_bystander_never_takes_a_gun_stance() -> void:
	assert_eq(CharModel.hands_free_clip("pistol_crouch", true), "cower", "the gunshot crouch is a cower, not a pistol kneel")
	assert_eq(CharModel.hands_free_clip("rifle_crouch", false), "cower")
	assert_eq(CharModel.hands_free_clip("pistol_aim", true), "cower")
	assert_eq(CharModel.hands_free_clip("pistol_run", true), "flee_run", "running away: a plain sprint")
	assert_eq(CharModel.hands_free_clip("pistol_sprint", true), "flee_run")
	assert_eq(CharModel.hands_free_clip("pistol_walk", false), "civ_walk")
	assert_eq(CharModel.hands_free_clip("pistol_idle", true), "cower", "standing scared: cowering")
	assert_eq(CharModel.hands_free_clip("pistol_idle", false), "idle_shift", "standing calm: an everyday idle")
	for keep in ["injured_walk", "injured_idle", "dying", "civ_walk", "sit", "hit_rifle", "death_front", "idle_phone"]:
		assert_eq(CharModel.hands_free_clip(keep, true), keep, "%s is already hands-free" % keep)
	var stances: Array = []
	for w in ["pistol", "rifle"]:
		for s in ["idle", "aim", "crouch", "walk", "run", "sprint"]:
			stances.append("%s_%s" % [w, s])
	for clip in stances:
		for scared in [false, true]:
			var got := CharModel.hands_free_clip(clip, scared)
			assert_false(got.begins_with("pistol_") or got.begins_with("rifle_"), "%s: no gun stance (%s)" % [clip, got])
			assert_true(CharAnims.CLIPS.has(got), "%s: %s is in the library" % [clip, got])
			assert_false(got in CharModel.PISTOL_GRIP_CLIPS, "%s: no pistol grip" % clip)
