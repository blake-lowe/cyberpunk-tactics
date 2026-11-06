extends TestCase
## Pure HUD layout logic (playtest r3): the log beside the action bar and its collapse state, the
## status line's segmented bars, and a foe portrait's blood level.


func test_segments_degrade_to_a_continuous_fill() -> void:
	assert_eq(Hud.seg_gap(8), 2.0, "few segments: 2 px gaps")
	assert_eq(Hud.seg_gap(25), 1.0, "many: 1 px gaps")
	assert_near(Hud.seg_width(86.0, 8, 2.0), (86.0 - 14.0) / 8.0)
	assert_near(Hud.seg_width(86.0, 25, 1.0), (86.0 - 24.0) / 25.0, 0.0001, "an assault rifle's 25 rounds: thin but segmented")
	assert_true(Hud.seg_width(86.0, 25, 1.0) >= Hud.MIN_SEG_PX)
	assert_eq(Hud.seg_width(86.0, 40, 1.0), 0.0, "40 rounds in 86 px: under 2 px each, one continuous fill")
	assert_eq(Hud.seg_width(10.0, 4, 2.0), 0.0, "exactly under the limit")
	assert_near(Hud.seg_width(14.0, 4, 2.0), 2.0, 0.0001, "2 px each: still segmented")


func test_blood_fills_with_damage_taken() -> void:
	assert_eq(Hud.blood_fill(40, 40), 0.0, "unhurt: empty")
	assert_near(Hud.blood_fill(30, 40), 0.25)
	assert_near(Hud.blood_fill(10, 40), 0.75)
	assert_eq(Hud.blood_fill(0, 40), 1.0)
	assert_eq(Hud.blood_fill(-5, 40), 1.0, "below zero: still full")
	assert_eq(Hud.blood_fill(5, 0), 0.0, "no max HP: no divide by zero")


func test_log_collapse_state_is_kept_for_the_session() -> void:
	var was := Hud.log_collapsed
	Hud.log_collapsed = false
	assert_true(Hud.flip_log_state(), "collapse")
	assert_true(Hud.log_collapsed, "a static: the next HUD (new gig) reads it")
	assert_false(Hud.flip_log_state(), "expand again")
	Hud.log_collapsed = was


func test_bar_moves_right_for_the_log_and_back_to_centre() -> void:
	var lw := Hud.log_width(1280.0, 900.0)
	assert_eq(lw, Hud.LOG_W, "room for the full log at 1280")
	var open := Hud.bar_x(1280.0, 900.0, lw, 1.0)
	assert_eq(Hud.bar_x(1280.0, 900.0, lw, 0.0), 190.0, "collapsed: centred")
	assert_true(open >= Hud.EDGE + lw + Hud.LOG_GAP, "open: clear of the log")
	assert_true(open + 900.0 <= 1280.0 - Hud.EDGE, "and inside the right margin")
	var mid := Hud.bar_x(1280.0, 900.0, lw, 0.5)
	assert_between(mid, 190.0, open, "mid-tween: between")
	assert_eq(Hud.bar_x(1920.0, 900.0, Hud.log_width(1920.0, 900.0), 1.0), 510.0, "wide screen: centred already clears the log")
	var tight := Hud.log_width(1280.0, 1010.0)
	assert_between(tight, Hud.LOG_MIN_W, Hud.LOG_W - 1.0, "a wider bar: a narrower log")
	assert_eq(Hud.bar_x(1280.0, 1010.0, tight, 1.0), 1280.0 - 1010.0 - Hud.EDGE, "pushed to the right margin")
	assert_eq(Hud.log_width(1067.0, 900.0), 0.0, "no room beside: the log stacks above the bar instead")
	assert_eq(Hud.bar_x(1067.0, 900.0, 0.0, 1.0), 83.5, "and the bar stays centred")


func test_status_name_calls_fists_brawling() -> void:
	assert_eq(Hud.status_name(null), "BRAWLING")
	assert_eq(Hud.status_name(Weapon.brawling(Combatant.new())), "BRAWLING")
	assert_eq(Hud.status_name(Weapon.from_id("heavy_melee")), Weapon.from_id("heavy_melee").display_name().to_upper())
