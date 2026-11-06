extends TestCase
## The hovered attack's preview shape follows the weapon / item data (AimPreview), the curves land
## where they should, and the H panel tells you how to attack.


func test_guns_fire_straight() -> void:
	for id in ["medium_pistol", "smg", "assault_rifle", "sniper_rifle", "shotgun", "bow", "rocket_launcher"]:
		assert_eq(AimPreview.for_weapon(Weapon.from_id(id)), AimPreview.LINE, id)


func test_melee_and_brawling_swing() -> void:
	assert_eq(AimPreview.for_weapon(Weapon.from_id("light_melee")), AimPreview.SWING)
	assert_eq(AimPreview.for_weapon(Weapon.from_id("heavy_melee")), AimPreview.SWING)
	assert_eq(AimPreview.for_weapon(null), AimPreview.SWING, "bare hands")
	assert_eq(AimPreview.for_armed("", "brawl", Weapon.from_id("assault_rifle")), AimPreview.SWING, "brawling with a rifle drawn")
	assert_eq(AimPreview.for_armed("melee", "melee", Weapon.from_id("assault_rifle")), AimPreview.SWING)


func test_thrown_and_lobbed_arc() -> void:
	assert_eq(AimPreview.for_weapon(Weapon.from_id("thrown_grenade")), AimPreview.THROW, "Athletics throw (p.177)")
	assert_eq(AimPreview.for_weapon(Weapon.from_id("thrown_melee")), AimPreview.THROW)
	assert_eq(AimPreview.for_weapon(Weapon.from_id("grenade_launcher")), AimPreview.THROW, "lobbed")
	assert_eq(AimPreview.for_item("ammo/armor_piercing_ammo"), AimPreview.THROW, "a kit grenade")
	assert_eq(AimPreview.for_item("drugs/black_lace"), "", "a drug has no attack preview")
	assert_eq(AimPreview.for_armed("grenade", "single", null, "ammo/armor_piercing_ammo"), AimPreview.THROW)
	assert_eq(AimPreview.for_armed("stabilize", "single", null), "", "no line to a patient")


func test_blast_comes_from_the_item() -> void:
	assert_eq(AimPreview.blast_half("ammo/armor_piercing_ammo"), Encounter.BLAST_HALF, "5x5 (p174)")
	assert_eq(AimPreview.blast_half("drugs/black_lace"), 0)


func test_throw_arc_ends_on_target_and_rises() -> void:
	var a := Vector3(0, 1, 0)
	var b := Vector3(8, 0, 0)
	var pts := AimPreview.arc_points(a, b, 2.0, 16)
	assert_eq(pts.size(), 17)
	assert_true(pts[0].is_equal_approx(a) and pts[16].is_equal_approx(b), "starts in the hand, lands on the square")
	assert_near(pts[8].y, 3.0, 0.001, "apex the peak above the higher end")
	assert_true(pts[4].y > a.y and pts[12].y > b.y, "a parabola, not a line")


func test_line_starts_ahead_of_the_muzzle() -> void:
	var mz := Vector3(1, 1, 1)
	var o := AimPreview.muzzle_origin(mz, Vector3(11, 1, 1))
	assert_true(o.is_equal_approx(Vector3(1.5, 1, 1)), "1 m (half a square) along the aim: %s" % o)
	var o2 := AimPreview.muzzle_origin(mz, Vector3(1, 1, 1.4))
	assert_true(o2.is_equal_approx(Vector3(1, 1, 1.2)), "point blank: never past half way: %s" % o2)
	assert_true(AimPreview.muzzle_origin(mz, mz).is_equal_approx(mz))
	var o3 := AimPreview.muzzle_origin(mz, Vector3(1, 5, 4))   # aims up a storey: along the 3D aim
	assert_near(o3.distance_to(mz), 0.5, 0.001)
	assert_true(o3.y > mz.y)


func test_line_ends_centre_mass_or_head() -> void:
	var base := Vector3(4.5, 3.0, 2.5)
	var body := AimPreview.aim_point(base, false)
	var head := AimPreview.aim_point(base, true)
	assert_true(body.is_equal_approx(base + Vector3(0, AimPreview.CENTRE_MASS, 0)))
	assert_true(head.is_equal_approx(base + Vector3(0, AimPreview.HEAD, 0)))
	assert_true(head.y > body.y and body.y > base.y, "the head above centre mass")


func test_blocked_line_stops_on_the_line() -> void:
	var p := AimPreview.stop_point(Vector3(0, 1, 0), Vector3(10, 2, 0), Vector3(4, 0, 0.5))
	assert_true(p.is_equal_approx(Vector3(4, 1.4, 0)), "%s" % p)


func test_slice_faces_the_target() -> void:
	assert_near(AimPreview.face_yaw(Vector3.ZERO, Vector3(0, 0, 3)), 0.0, 0.001)
	assert_near(AimPreview.face_yaw(Vector3.ZERO, Vector3(2, 5, 0)), PI / 2, 0.001)
	assert_eq(AimPreview.windup("light_melee")[0], "melee_blade")
	assert_eq(AimPreview.windup("brawling")[0], "melee")


func test_last_known_squares() -> void:
	var alive := Combatant.new()
	var dead := Combatant.new()
	dead.dead = true
	var known := {3: Vector3i(1, 1, 0)}
	var foes := [{"id": 1, "pos": Vector3i(2, 2, 0), "c": alive}, {"id": 2, "pos": Vector3i(9, 9, 0), "c": alive}, {"id": 3, "pos": Vector3i(4, 4, 0), "c": dead}]
	var seen := func(v: Vector3i) -> bool: return v.x < 5
	AimPreview.remember(known, foes, seen)
	assert_eq(known.get(1), Vector3i(2, 2, 0), "seen: remembered where they are")
	assert_false(known.has(2), "never seen: unknown")
	assert_false(known.has(3), "seen dead: forgotten")
	foes[0].pos = Vector3i(8, 8, 0)   # walks out of sight
	AimPreview.remember(known, foes, seen)
	assert_eq(known.get(1), Vector3i(2, 2, 0), "out of sight: last-known square kept")


func test_help_says_how_to_attack() -> void:
	var h := Hud.help_text()
	assert_true(h.begins_with("MOUSE\nLEFT-CLICK  Attack"), "the left-click attacks, first")
	assert_true(h.contains("PORTRAIT"), "targeting from the turn order")
	for k in ["RIGHT-CLICK  Move", "SHIFT + LEFT-CLICK", "MIDDLE-DRAG", "WHEEL", "ALT", "W A S D", "Q / E"]:
		assert_true(h.contains(k), k)
	for k in ["RELOAD", "SPACE", "JACK"]:   # the action bar shows its own keys (owner)
		assert_false(h.to_upper().contains(k), "no bar key in the help: " + k)


func test_range_ticks_are_short_arcs_centred_on_the_shooter() -> void:
	var c := Vector3(0, 1, 0)
	var p := Vector3(20, 1, 0)   # a bracket edge 20 m down the line
	var eye := Vector3(30, 30, 30)
	var segs := AimFx.tick_arc(p, c, eye, 0.22, Vector3.RIGHT)
	assert_eq(segs.size(), AimFx.TICK_SEGS)
	var a: Vector3 = segs[0][0]
	var b: Vector3 = segs[-1][1]
	for q in [a, b, segs[2][1]]:
		assert_near(q.distance_to(c), 20.0, 0.001, "every point is on the circle about the shooter")
	assert_near(rad_to_deg((a - c).angle_to(b - c)), AimFx.TICK_ARC_DEG * 2.0, 0.01, "a few degrees wide")
	assert_true(a.lerp(b, 0.5).distance_to(c) < 20.0, "bowed away from the shooter, not a straight cross-tick")
	assert_eq(AimFx.tick_arc(p, Vector3.INF, eye, 0.22).size(), 1, "no shooter known: a straight tick")


func test_click_intent_right_moves_left_attacks() -> void:
	var L := MOUSE_BUTTON_LEFT
	var R := MOUSE_BUTTON_RIGHT
	assert_eq(ClickIntent.of(R, false, false, "", false, false), ClickIntent.MOVE, "right on ground moves")
	assert_eq(ClickIntent.of(R, false, false, "", false, true), ClickIntent.MOVE, "right on a foe never attacks")
	assert_eq(ClickIntent.of(R, false, false, "grenade", false, false), ClickIntent.MOVE, "right moves with a tool armed")
	assert_eq(ClickIntent.of(L, false, false, "", false, true), ClickIntent.ATTACK, "left on a foe attacks")
	assert_eq(ClickIntent.of(L, false, false, "", false, false), ClickIntent.NONE, "left on ground / a friendly: nothing")
	assert_eq(ClickIntent.of(L, true, false, "", false, false), ClickIntent.COVER, "shift+left shoots cover")
	assert_eq(ClickIntent.of(L, false, false, "", true, false), ClickIntent.COVER, "Shoot Cover armed")
	assert_eq(ClickIntent.of(L, false, false, "melee", false, true), ClickIntent.TOOL, "left uses the armed tool")
	assert_eq(ClickIntent.of(L, false, true, "", false, true), ClickIntent.NET, "NET: left picks a node")
	assert_eq(ClickIntent.of(R, false, true, "", false, false), ClickIntent.NET, "NET: right picks a node")
	assert_eq(ClickIntent.of(MOUSE_BUTTON_MIDDLE, false, false, "", false, true), ClickIntent.NONE, "middle is the camera's")
