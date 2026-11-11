extends TestCase
## Owner playtest, gig visuals: the focus brackets frame a building only while that tells you
## something, and cut buildings keep their walls up except in front of what you care about.


func test_brackets_only_round_a_building_that_fits() -> void:
	var screen := Rect2(0, 0, 1200, 600)
	assert_true(CamFrame.bounds_fit(Rect2(300, 150, 400, 250), screen), "a building in view with room round it")
	assert_false(CamFrame.bounds_fit(Rect2(-40, 100, 500, 300), screen), "partly off screen")
	assert_false(CamFrame.bounds_fit(Rect2(20, 20, 1150, 560), screen), "fills the view (zoomed in)")
	assert_false(CamFrame.bounds_fit(Rect2(-500, -500, 3000, 2000), screen), "far bigger than the view")


func test_walls_open_in_holes_not_half_runs() -> void:
	var src := FileAccess.get_file_as_string("res://src/tactical/view/world.gdshader")
	assert_true(src.contains("global uniform sampler2D cut_holes"), "the wall holes")
	assert_false(src.contains("vec2 piv"), "no camera-side half walls round the focus")
	assert_true(ProjectSettings.has_setting("shader_globals/cut_holes") and ProjectSettings.has_setting("shader_globals/cut_hole_count"))
