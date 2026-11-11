extends TestCase
## The move trace (PathTrace) rides over the walked surfaces: up a flight along its treads, never
## through a step, a floor or a riser (owner playtest: the spline cut through floors and walls).

const FH := 1.6


## A strip along x on storey 0 then 1: a flight on square (2, 0) rising +x from storey 0 to 1; a
## kerb (0.07) from x = 5 on storey 1; a hatch shaft at (8, 0).
func _surf(x: float, _z: float, f: int) -> float:
	var cx := int(floor(x))
	if f == 0 and cx == 2:
		return clampf(FH * ((x - 2.5) + 0.5 + 1.0 / 7.0), 0.0, FH)
	if f == 1 and cx >= 5:
		return FH + 0.07
	return f * FH


func _flight(c: Vector3i) -> Vector2:
	return Vector2(1, 0) if c == Vector3i(2, 0, 0) else Vector2.ZERO


## The highest step top under world x on storey 0's flight (WorldBuilder._stairs: 7 steps).
func _step_top(x: float) -> float:
	var s := x - 2.0
	if s < 0.0 or s >= 1.0:
		return -INF
	return FH * (floor(s * 7.0) + 1.0) / 7.0


func _up_path() -> Array:
	return [Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(2, 0, 0), Vector3i(2, 0, 1), Vector3i(3, 0, 1), Vector3i(4, 0, 1), Vector3i(5, 0, 1), Vector3i(6, 0, 1)]


func test_climbs_the_flight_over_its_steps() -> void:
	var pts := PathTrace.points(_up_path(), _surf, _flight, FH)
	assert_true(pts.size() > 8)
	assert_near(pts[0].y, PathTrace.LIFT, 0.001, "starts just over the street")
	assert_near(pts[-1].y, FH + 0.07 + PathTrace.LIFT, 0.001, "ends just over the kerb upstairs")
	for i in pts.size() - 1:   # every point and every segment's midpoint clear of the steps
		for q in [pts[i], (pts[i] + pts[i + 1]) * 0.5]:
			assert_true(q.y > _step_top(q.x) + 0.02, "clear of the steps at x %.2f (y %.2f)" % [q.x, q.y])
			assert_true(q.y > (FH if q.x > 3.0 else 0.0), "never under the floor at x %.2f" % q.x)
		assert_true(pts[i + 1].y >= pts[i].y - 0.001, "only ever climbs")


func test_no_vertical_through_the_flight() -> void:
	# the spline rose straight up the middle of the stair square; the trace climbs along it
	var pts := PathTrace.points(_up_path(), _surf, _flight, FH)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		if absf(b.y - a.y) > 0.3 and Vector2(b.x - a.x, b.z - a.z).length() < 0.05:
			assert_true(a.x > 2.98 or a.x < 2.0, "a steep rise only off the flight (x %.2f)" % a.x)


func test_kerb_jog_on_the_low_side() -> void:
	var pts := PathTrace.points([Vector3i(3, 0, 1), Vector3i(4, 0, 1), Vector3i(5, 0, 1), Vector3i(6, 0, 1)], _surf, _flight, FH)
	for q in pts:
		if q.x > 5.0:
			assert_true(q.y > FH + 0.07, "over the kerb once past its face")
	assert_true(pts.size() < 40, "a flat run stays light (%d points)" % pts.size())


func test_down_mirrors_up() -> void:
	var down := _up_path().duplicate()
	down.reverse()
	var pts := PathTrace.points(down, _surf, _flight, FH)
	for i in pts.size() - 1:
		for q in [pts[i], (pts[i] + pts[i + 1]) * 0.5]:
			assert_true(q.y > _step_top(q.x) + 0.02, "clear of the steps at x %.2f" % q.x)
		assert_true(pts[i + 1].y <= pts[i].y + 0.001, "only ever descends")


func test_hatch_and_jump() -> void:
	var hatch := PathTrace.points([Vector3i(7, 0, 0), Vector3i(8, 0, 0), Vector3i(8, 0, 1), Vector3i(9, 0, 1)], _surf, _flight, FH)
	var straight_up := false
	for i in hatch.size() - 1:
		if absf(hatch[i].x - 8.5) < 0.01 and absf(hatch[i + 1].x - 8.5) < 0.01 and hatch[i + 1].y - hatch[i].y > 1.0:
			straight_up = true
	assert_true(straight_up, "a hatch goes straight up the middle of its square")
	var jump := PathTrace.points([Vector3i(0, 0, 1), Vector3i(3, 0, 1)], _surf, _flight, FH)
	var top := 0.0
	for q in jump:
		top = maxf(top, q.y)
	assert_near(top, FH + PathTrace.LIFT + 0.9, 0.05, "a jump arcs over its gap")


func test_tube_mesh() -> void:
	var pts := PathTrace.points(_up_path(), _surf, _flight, FH)
	var mesh := PathTrace.tube(pts, 0.045, 0.2)
	assert_eq(mesh.get_surface_count(), 1)
	var n: int = (mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	assert_eq(n, (pts.size() - 1) * 24 + 6, "four faces a segment and the end diamond")


func test_ladder_goes_up_in_front_of_its_rungs_and_over_the_parapet() -> void:
	var pts := PathTrace.points([Vector3i(0, 3, 0), Vector3i(0, 2, 0), Vector3i(0, 1, 2), Vector3i(0, 0, 2)], _surf, _flight, FH)
	var climb := false
	var top := 0.0
	for i in pts.size() - 1:
		top = maxf(top, pts[i].y)
		if absf(pts[i].z - 2.65) < 0.01 and absf(pts[i + 1].z - 2.65) < 0.01 and pts[i + 1].y - pts[i].y > 2.0:
			climb = true
	assert_true(climb, "straight up the foot's square, off the wall")
	assert_near(top, 2.0 * FH + PathTrace.PARAPET + PathTrace.LIFT, 0.01, "over the roof edge")
	assert_near(pts[-1].y, 2.0 * FH + PathTrace.LIFT, 0.001, "then down onto the roof")
