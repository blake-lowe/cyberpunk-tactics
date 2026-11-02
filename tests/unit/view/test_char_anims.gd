extends TestCase


func test_every_clip_loads_retargeted() -> void:
	var lib := CharAnims.library()
	for clip in CharAnims.CLIPS:
		assert_true(lib.has_animation(clip), "clip %s loads" % clip)
	var a := lib.get_animation("rifle_aim")
	assert_true(a.find_track(NodePath(CharAnims.HIPS), Animation.TYPE_ROTATION_3D) >= 0, "tracks target the humanoid profile skeleton")


func test_locomotion_is_in_place_with_native_speed() -> void:
	var lib := CharAnims.library()
	for clip in CharAnims.IN_PLACE:
		var a := lib.get_animation(clip)
		var t := a.find_track(NodePath(CharAnims.HIPS), Animation.TYPE_POSITION_3D)
		var p0: Vector3 = a.track_get_key_value(t, 0)
		var p1: Vector3 = a.track_get_key_value(t, a.track_get_key_count(t) - 1)
		assert_near(Vector2(p1.x - p0.x, p1.z - p0.z).length(), 0.0, 0.001, "%s loops in place" % clip)
	assert_between(CharAnims.speed["rifle_walk"], 1.0, 3.0, "walk speed in m/s")
	assert_between(CharAnims.speed["rifle_sprint"], 5.0, 9.0, "sprint speed in m/s")


func test_trim_and_rate_retime_clips() -> void:
	var lib := CharAnims.library()
	var cpr := lib.get_animation("medtech")
	var w: Array = CharAnims.TRIM["medtech"]
	assert_near(cpr.length, float(w[1]) - float(w[0]), 0.01, "CPR loops on the compressions only")
	var hb := lib.get_animation("hit_b")
	for tr in hb.get_track_count():
		if hb.track_get_key_count(tr) > 0:
			assert_true(hb.track_get_key_time(tr, hb.track_get_key_count(tr) - 1) <= hb.length + 0.001, "keys fit the faster length")
