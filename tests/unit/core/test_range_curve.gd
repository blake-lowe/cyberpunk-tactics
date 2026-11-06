extends TestCase
## RangeCurve: the Armory chart's hit chance by range, fitted to the book's range tables.


func test_band_space_puts_every_band_one_unit_wide() -> void:
	assert_near(RangeCurve.band_u(0.0), 0.0)
	assert_near(RangeCurve.band_u(6.0), 1.0)
	assert_near(RangeCurve.band_u(9.0), 1.5, 0.0001, "linear inside the 7-12 band")
	assert_near(RangeCurve.band_u(50.0), 4.0)
	assert_near(RangeCurve.band_u(800.0), 8.0)
	assert_near(RangeCurve.band_u(5000.0), 8.0, 0.0001, "clamped past the table")
	for m in [0.0, 3.0, 6.0, 18.5, 75.0, 300.0, 800.0]:
		assert_near(RangeCurve.metres_at(RangeCurve.band_u(m)), m, 0.001, "metres_at inverts band_u at %s m" % m)


func test_max_range_is_the_last_band_with_a_dv() -> void:
	assert_eq(RangeCurve.max_range_m("pistol"), 200.0, "pistol: no DV past 200 m (p173)")
	assert_eq(RangeCurve.max_range_m("assault_rifle"), 800.0)
	assert_eq(RangeCurve.max_range_m("smg"), 400.0)
	assert_eq(RangeCurve.max_range_m("assault_rifle", true), 100.0, "autofire table stops at 100 m")
	assert_eq(RangeCurve.max_range_m("grenade_launcher", false, 25.0), 25.0, "a thrown weapon's cap")
	assert_eq(RangeCurve.max_range_m("no_such_table"), 0.0)


func test_curve_passes_through_each_bands_exact_chance() -> void:
	var base := 12
	var dvs := RangeCurve.band_dvs("pistol")
	var pts := RangeCurve.sample(base, "pistol")
	var k := RangeCurve.knots(RangeCurve.band_chances(base, "pistol"), RangeCurve.band_u(200.0))
	var m := RangeCurve.tangents(k)
	for i in dvs.size():
		var exact := Check.chance_vs_dv(base, dvs[i])
		assert_near(RangeCurve.evaluate(k, m, i + 0.5), exact, 0.0001, "band %d midpoint is the table's chance" % i)
		# the step function agrees with the rules lookup at a distance inside the band
		var mid_m := RangeCurve.metres_at(i + 0.5)
		assert_eq(RulesDB.range_dv("pistol", mid_m), dvs[i])
	assert_near(pts[0].x, 0.0)
	assert_near(pts[pts.size() - 1].x, 6.0, 0.0001, "the curve ends at the pistol's 200 m")


func test_curve_never_overshoots_its_neighbouring_bands() -> void:
	for table in ["pistol", "smg", "assault_rifle", "sniper_rifle", "rocket_launcher", "bow"]:
		var ch := RangeCurve.band_chances(10, table)
		var k := RangeCurve.knots(ch, RangeCurve.band_u(RangeCurve.max_range_m(table)))
		var m := RangeCurve.tangents(k)
		for i in k.size() - 1:
			var lo := minf(k[i].y, k[i + 1].y)
			var hi := maxf(k[i].y, k[i + 1].y)
			for s in 11:
				var u := lerpf(k[i].x, k[i + 1].x, s / 10.0)
				assert_between(RangeCurve.evaluate(k, m, u), lo - 0.0001, hi + 0.0001, "%s: monotone between knots at u=%.2f" % [table, u])


func test_sniper_peaks_at_its_best_band() -> void:
	var pts := RangeCurve.sample(14, "sniper_rifle")
	var best := Vector2(-1, -1)
	for p in pts:
		if p.y > best.y:
			best = p
	assert_between(RangeCurve.metres_at(best.x), 51.0, 100.0, "DV15 at 51-100 m is the sniper's best (p173)")


func test_for_weapon_uses_the_attack_base_and_modes() -> void:
	var c := Fixtures.shooter()
	var ar := Weapon.from_id("assault_rifle")
	var d := RangeCurve.for_weapon(c, ar)
	assert_false(d.melee)
	assert_true(d.has("single") and d.has("autofire"), "assault rifle: single shot and autofire")
	assert_eq(int(d.single.base), Attack.attack_base(c, ar, Attack.Mode.SINGLE))
	assert_eq(int(d.autofire.base), Attack.attack_base(c, ar, Attack.Mode.AUTOFIRE))
	assert_eq(float(d.autofire.max_m), 100.0)
	var pistol := RangeCurve.for_weapon(c, Weapon.from_id("heavy_pistol"))
	assert_false(pistol.has("autofire"), "no autofire on a pistol")
	assert_true(RangeCurve.for_weapon(c, Weapon.from_id("light_melee")).melee, "melee: no curve")
	var helix := RangeCurve.for_weapon(c, Weapon.from_id("tsunami_helix"))
	assert_true(helix.has("autofire") and not helix.has("single"), "the Helix is autofire only (p349)")


func test_brackets_mark_where_the_dv_changes() -> void:
	# Pistol row (p173): 13 | 15 | 20 | 25 | 30 | 30 | N/A: the two DV 30 bands merge, reach 200 m
	assert_eq(RangeCurve.brackets("pistol"), [[0.0, 13], [6.0, 15], [12.0, 20], [25.0, 25], [50.0, 30]])
	# Assault rifle autofire (p173): its own row, to 100 m
	assert_eq(RangeCurve.brackets("assault_rifle", true), [[0.0, 22], [6.0, 20], [12.0, 17], [25.0, 20], [50.0, 25]])
	assert_eq(RangeCurve.brackets("pistol", false, 25.0), [[0.0, 13], [6.0, 15], [12.0, 20]], "a 25 m cap drops the bands past it")
	assert_eq(RangeCurve.brackets("no_such_table"), [])


func test_brackets_for_follow_the_weapon_and_mode() -> void:
	var ar := Weapon.from_id("assault_rifle")
	assert_eq(RangeCurve.brackets_for(ar, Attack.Mode.SINGLE), RangeCurve.brackets(String(ar.def.range)))
	assert_eq(RangeCurve.brackets_for(ar, Attack.Mode.AUTOFIRE), RangeCurve.brackets(String(ar.def.autofire_range), true))
	assert_eq(RangeCurve.brackets_for(Weapon.from_id("light_melee"), Attack.Mode.SINGLE), [], "melee: no ticks")
