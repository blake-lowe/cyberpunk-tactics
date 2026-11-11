extends TestCase
## The safehouse hub turns (owner playtest): Q/E orbit the camera round the floor, eased while held
## (CamTurn), a 45° snap per press with reduced motion; never while a room screen is open (the Med
## Bay and Armory use Q/E for the crew). Rooms still pick under the cursor at any angle.

const PX := Vector2(640, 360)   # the low-res view at 720p


func _key(code: Key, pressed: bool, echo := false) -> InputEventKey:
	var k := InputEventKey.new()
	k.keycode = code
	k.pressed = pressed
	k.echo = echo
	return k


## A view with just a camera and its picking pieces (no 3D world, no live tree).
func _view() -> BaseView:
	var bv := BaseView.new()
	bv.cam = Camera3D.new()
	bv.cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	bv.svp = SubViewport.new()
	bv.svp.size = Vector2i(PX)
	bv.screen = TextureRect.new()
	bv.screen.size = PX * 2.0   # a 2x pixel scale, as at 1440p... any scale picks the same
	bv.set_yaw(0.0)
	return bv


func _free(bv: BaseView) -> void:
	bv.cam.free()
	bv.svp.free()
	bv.screen.free()
	bv.free()


func test_held_q_and_e_turn_the_hub() -> void:
	var bv := _view()
	bv._unhandled_input(_key(KEY_E, true))
	for i in 30:
		bv.turn_step(1.0 / 60.0)
	var after_e := bv.yaw
	assert_between(after_e, 20.0, 60.0, "half a second of E turns the view (%s°)" % after_e)
	assert_near(bv.cam.transform.basis.get_euler().y, deg_to_rad(after_e), 0.01, "the camera turned with it")
	bv._unhandled_input(_key(KEY_E, false))
	for i in 30:
		bv.turn_step(1.0 / 60.0)
	assert_false(bv.turn.turning(), "let go: it eases to a stop")
	var rest := bv.yaw
	assert_true(rest > after_e and rest < after_e + 10.0, "a short ease out after the release")
	bv._unhandled_input(_key(KEY_Q, true))
	for i in 60:
		bv.turn_step(1.0 / 60.0)
	bv._unhandled_input(_key(KEY_Q, false))
	for i in 30:
		bv.turn_step(1.0 / 60.0)
	assert_true(bv.yaw < rest - 60.0 or bv.yaw > 300.0, "Q turns the other way (%s°)" % bv.yaw)
	_free(bv)


func test_reduced_motion_snaps_a_step_per_press() -> void:
	var bv := _view()
	bv._reduced = true
	bv._unhandled_input(_key(KEY_E, true))
	assert_eq(bv.yaw, BaseView.SNAP_STEP, "one press: one step, at once")
	bv._unhandled_input(_key(KEY_E, true, true))
	assert_eq(bv.yaw, BaseView.SNAP_STEP, "a held key's repeats don't spin it")
	assert_false(bv.turn_step(0.5), "nothing glides")
	bv._unhandled_input(_key(KEY_E, false))
	bv._unhandled_input(_key(KEY_Q, true))
	bv._unhandled_input(_key(KEY_Q, true))
	assert_eq(bv.yaw, 360.0 - BaseView.SNAP_STEP, "Q steps back past 0")
	_free(bv)


func test_q_and_e_belong_to_an_open_room_screen() -> void:
	var bv := _view()
	bv._screen = StorageScreen.new()   # the Armory (not built: only its presence matters to the hub)
	bv._unhandled_input(_key(KEY_E, true))
	for i in 30:
		bv.turn_step(1.0 / 60.0)
	assert_eq(bv.yaw, 0.0, "the hub doesn't turn under the Armory")
	assert_true(bv._turn_keys.is_empty())
	bv._screen.free()
	bv._screen = null
	_free(bv)


func test_rooms_pick_under_the_cursor_at_any_angle() -> void:
	var bv := _view()
	for deg in [0.0, 30.0, 45.0, 90.0, 135.0, 180.0, 250.0, 315.0]:
		bv.set_yaw(deg)
		assert_near(bv.cam.size, BaseView.view_size(deg), 0.001)
		for id: String in BaseView.ROOMS:
			var c := BaseView._rect(id).get_center()
			var px := BaseView.view_at(bv.cam.transform, bv.cam.size, PX, Vector3(c.x, 0, c.y))
			assert_true(Rect2(Vector2.ZERO, PX).has_point(px), "%s on screen at %s°" % [id, deg])
			var mouse := px * (bv.screen.size.x / PX.x)
			assert_eq(BaseView._room_at(bv._pick_floor(mouse)), id, "%s picks under its own pixel at %s°" % [id, deg])
		for corner: Vector3 in [Vector3(0, 0, 0), Vector3(BaseView.W, 0, 0), Vector3(0, 0, BaseView.D), Vector3(BaseView.W, 0, BaseView.D)]:
			var p := BaseView.view_at(bv.cam.transform, bv.cam.size, PX, corner)
			assert_true(Rect2(Vector2.ZERO, PX).has_point(p), "the whole floor framed at %s° (corner %s)" % [deg, corner])
	_free(bv)


func test_full_walls_follow_the_far_sides() -> void:
	assert_eq(BaseView._far_sides(0.0), ["north"] as Array[String], "from the south: the north wall is full")
	var back := BaseView._far_sides(180.0)
	assert_true("south" in back and not "north" in back, "turned round: the south wall is full, the north one low")
	var diag := BaseView._far_sides(45.0)
	assert_true("north" in diag and "west" in diag, "on the diagonal both far sides are full")
