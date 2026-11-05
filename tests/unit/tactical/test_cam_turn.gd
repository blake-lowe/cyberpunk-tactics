extends TestCase
## Held Q/E camera turn (CamTurn): a steady rate while held, eased in and out, frame-rate independent.


## Hold `dir` for `hold` seconds, then let go until it stops; total degrees turned.
func _turn(dir: float, hold: float, fps: float) -> float:
	var t := CamTurn.new()
	var total := 0.0
	var dt := 1.0 / fps
	var n := int(round(hold * fps))
	for i in n:
		total += t.step(dir, dt)
	var guard := 0
	while t.turning() and guard < 10000:
		total += t.step(0.0, dt)
		guard += 1
	assert_false(t.turning(), "comes to rest after release")
	return total


func test_a_hold_turns_at_the_steady_rate() -> void:
	# easing in loses RATE*EASE/2 and easing out gives it back: a hold of T turns RATE*T
	assert_near(_turn(1.0, 1.0, 60.0), CamTurn.RATE, 0.01, "1 s of E: 90°")
	assert_near(_turn(1.0, 2.0, 60.0), CamTurn.RATE * 2.0, 0.01, "2 s of E: 180°")
	assert_near(_turn(-1.0, 0.5, 60.0), -CamTurn.RATE * 0.5, 0.01, "Q turns the other way")


func test_a_tap_turns_a_little() -> void:
	var tap := _turn(1.0, 1.0 / 60.0, 60.0)
	assert_between(tap, 0.0001, 2.0, "one frame of E: a nudge, not a quarter turn")
	assert_true(_turn(1.0, 0.1, 60.0) > tap, "longer holds turn more")
	assert_true(_turn(1.0, 0.1, 60.0) < 15.0, "a short press stays small")


func test_full_speed_after_the_ease_and_steady_while_held() -> void:
	var t := CamTurn.new()
	var first := t.step(1.0, 1.0 / 60.0)
	assert_true(first < CamTurn.RATE / 60.0, "eases in: the first frame is slower than full rate")
	for i in 30:
		t.step(1.0, 1.0 / 60.0)
	assert_near(t.speed, CamTurn.RATE, 0.0001, "full rate after the ease")
	assert_near(t.step(1.0, 0.1), CamTurn.RATE * 0.1, 0.0001, "steady while held")


func test_frame_rate_does_not_change_the_turn() -> void:
	var a := _turn(1.0, 0.5, 30.0)
	var b := _turn(1.0, 0.5, 144.0)
	assert_near(a, b, 0.05, "30 fps and 144 fps turn alike")
	assert_near(a, CamTurn.RATE * 0.5, 0.05)


func test_reversing_and_free_angles() -> void:
	var t := CamTurn.new()
	for i in 30:
		t.step(1.0, 1.0 / 60.0)
	var yaw := 45.0
	for i in 60:   # reverse: decelerates through zero into the other direction
		yaw += t.step(-1.0, 1.0 / 60.0)
	assert_near(t.speed, -CamTurn.RATE, 0.0001, "now turning the other way at full rate")
	assert_true(absf(fposmod(yaw, 90.0)) > 0.5 and absf(fposmod(yaw, 90.0)) < 89.5, "lands on a free angle (no snap): %.2f" % yaw)
	assert_eq(t.step(1.0, 0.0), 0.0, "no time, no turn")
