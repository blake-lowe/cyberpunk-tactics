extends TestCase
## The safehouse view's picking: a pixel of the 3D view → the floor → the room under the cursor
## (owner playtest: nothing hovered), and the fixed camera square-on to the walls (owner: 0° yaw, no
## rotation or zoom).

const PX := Vector2(640, 360)   # the low-res view at 720p


func _xf() -> Transform3D:
	return BaseView.view_xform(BaseView.overview_focus())


func test_default_view_is_square_on() -> void:
	assert_eq(BaseView.YAW, 0.0, "owner: 0° yaw")
	var bv := BaseView.new()
	assert_false("yaw" in bv, "no rotatable yaw left on the view (owner: no Q/E rotation)")
	bv.free()
	var xf := _xf()
	var a := BaseView.view_at(xf, BaseView.VIEW_SIZE, PX, Vector3(0, 0, 0))
	var b := BaseView.view_at(xf, BaseView.VIEW_SIZE, PX, Vector3(BaseView.W, 0, 0))
	var c := BaseView.view_at(xf, BaseView.VIEW_SIZE, PX, Vector3(0, 0, BaseView.D))
	assert_near(a.y, b.y, 0.01, "the back wall runs straight across the screen")
	assert_near(a.x, c.x, 0.01, "the side walls run straight up it")
	assert_true(c.y > a.y, "the near (south) edge is lower on screen")
	var pitch := rad_to_deg(atan2(BaseView.PITCH_UP, BaseView.PITCH_BACK))
	assert_between(pitch, 30.0, 50.0, "still looking down at an isometric-style pitch")


func test_whole_floor_fits_the_view() -> void:
	var xf := _xf()
	for corner: Vector3 in [Vector3(0, 0, 0), Vector3(BaseView.W, 0, 0), Vector3(0, 0, BaseView.D), Vector3(BaseView.W, 0, BaseView.D)]:
		var p := BaseView.view_at(xf, BaseView.VIEW_SIZE, PX, corner)
		assert_true(Rect2(Vector2.ZERO, PX).has_point(p), "corner %s on screen (%s)" % [corner, p])


func test_far_walls_are_north_and_west() -> void:
	var far := BaseView._far_sides()
	assert_true("north" in far, "the back wall is full height")
	assert_false("south" in far, "the near wall stays waist-high")


func test_screen_point_picks_the_room_under_it() -> void:
	var xf := _xf()
	for id: String in BaseView.ROOMS:
		var r := BaseView._rect(id)
		for at: Vector2 in [r.get_center(), r.position + Vector2(0.3, 0.3), r.end - Vector2(0.3, 0.3)]:
			var sp := BaseView.view_at(xf, BaseView.VIEW_SIZE, PX, Vector3(at.x, 0, at.y))
			var hit := BaseView.floor_at(xf, BaseView.VIEW_SIZE, PX, sp)
			assert_near(hit.x, at.x, 0.01, "floor point round trips (x)")
			assert_near(hit.z, at.y, 0.01, "floor point round trips (z)")
			assert_eq(BaseView._room_at(hit), id, "%s under its own pixel" % id)
	var xf0 := _xf()
	var corridor := Vector3(BaseView.W / 2, 0, (BaseView.CORRIDOR_Z + 0.5) * BaseView.MOD)
	var sp0 := BaseView.view_at(xf0, BaseView.VIEW_SIZE, PX, corridor)
	assert_eq(BaseView._room_at(BaseView.floor_at(xf0, BaseView.VIEW_SIZE, PX, sp0)), "", "the corridor is no room")
	assert_eq(BaseView._room_at(BaseView.floor_at(xf0, BaseView.VIEW_SIZE, PX, Vector2(2, 2))), "", "the dark outside the floor is no room")


func test_the_view_lets_the_mouse_through() -> void:
	# The scene root fills the screen; as a STOP control it took every motion and click before
	# _unhandled_input (the hover and click handler) saw them.
	var scene: Control = (load("res://scenes/base.tscn") as PackedScene).instantiate()
	assert_eq(scene.mouse_filter, Control.MOUSE_FILTER_IGNORE, "base.tscn root passes the mouse to the view")
	scene.free()
