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
	assert_true(h.contains("RIGHT-CLICK AN ENEMY"), "the right-click, first")
	assert_true(h.contains("PORTRAIT"), "targeting from the turn order")
	for k in ["LMB", "RMB", "SHIFT + RMB", "MIDDLE-DRAG", "WHEEL", "ALT"]:
		assert_true(h.contains(k), k)
