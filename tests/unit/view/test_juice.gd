extends TestCase
## Juice pass: the trauma shake's maths (decay, clamping, the Options slider and reduced motion),
## hit-stop off under reduced motion, the callout pops, the HUD overlays' curves, the settings
## persisting, and the new stingers existing.


func test_trauma_adds_clamps_and_decays_linearly() -> void:
	var s := ScreenShake.new()
	assert_eq(s.trauma, 0.0, "starts still")
	s.add(0.3)
	s.add(0.3)
	assert_near(s.trauma, 0.6, 0.0001, "trauma adds")
	s.add(5.0)
	assert_eq(s.trauma, 1.0, "clamped at 1")
	s.add(-3.0)
	assert_eq(s.trauma, 1.0, "negative trauma is ignored")
	s.step(0.25)
	assert_near(s.trauma, 1.0 - ScreenShake.DECAY * 0.25, 0.0001, "decays at DECAY a second")
	s.step(10.0)
	assert_eq(s.trauma, 0.0, "never below 0")
	assert_eq(s.offset(), Vector2.ZERO, "no trauma, no offset")
	s.step(-1.0)
	assert_eq(s.trauma, 0.0, "a negative step does nothing")


func test_a_full_blast_settles_in_well_under_a_second() -> void:
	var s := ScreenShake.new()
	s.add(1.0)
	var t := 0.0
	while s.trauma > 0.0 and t < 5.0:
		s.step(1.0 / 60.0)
		t += 1.0 / 60.0
	assert_true(t < 0.7, "full trauma gone in %.2f s" % t)


func test_offset_is_bounded_by_trauma_squared_and_the_slider() -> void:
	var s := ScreenShake.new()
	s.add(0.5)
	var peak := 0.0
	for i in 400:
		var o := s.offset()
		peak = maxf(peak, maxf(absf(o.x), absf(o.y)))
		s._t += 0.013   # move the noise without decaying the trauma
	var bound := ScreenShake.MAX_PX * 0.25
	assert_true(peak <= bound + 0.0001, "|offset| <= MAX_PX * trauma^2 (%.2f <= %.2f)" % [peak, bound])
	assert_true(peak > bound * 0.4, "and it does move (%.2f)" % peak)
	assert_near(s.amplitude(), bound, 0.0001, "the default slider is the tuned amplitude")
	s.strength = 1.0
	assert_near(s.amplitude(), bound / ScreenShake.DEFAULT, 0.0001, "100% is DEFAULT^-1 of the tuned shake")
	assert_near(s.kick_scale(), 1.0 / ScreenShake.DEFAULT, 0.0001, "the kicks scale the same way")
	s.strength = 0.0
	assert_eq(s.amplitude(), 0.0, "0% is still")
	assert_eq(s.offset(), Vector2.ZERO)
	assert_eq(s.kick_scale(), 0.0, "and no kicks")
	s.strength = 3.0
	assert_near(s.kick_scale(), 1.0 / ScreenShake.DEFAULT, 0.0001, "the slider clamps at 100%")


func test_reduced_motion_turns_shake_kicks_and_hit_stop_off() -> void:
	var s := ScreenShake.new(1.0, true)
	s.add(1.0)
	assert_eq(s.kick_scale(), 0.0, "no kicks")
	assert_eq(s.amplitude(), 0.0, "no shake")
	for i in 20:
		assert_eq(s.offset(), Vector2.ZERO)
		s.step(0.01)
	assert_eq(ScreenShake.hit_stop_ms(ScreenShake.STOP_CRIT_MS, true), 0, "no hit-stop on a crit")
	assert_eq(ScreenShake.hit_stop_ms(ScreenShake.STOP_KILL_MS, true), 0, "nor on a kill")
	assert_eq(ScreenShake.hit_stop_ms(ScreenShake.STOP_CRIT_MS, false), ScreenShake.STOP_CRIT_MS, "with motion on it holds")
	assert_eq(ScreenShake.hit_stop_ms(5000, false), ScreenShake.STOP_MAX_MS, "never longer than a few frames")
	assert_true(ScreenShake.STOP_MAX_MS <= 200, "a hit-stop is a beat, not a pause")


func test_the_shake_is_deterministic_and_smooth() -> void:
	var a := ScreenShake.new(0.6, false, 5)
	var b := ScreenShake.new(0.6, false, 5)
	a.add(0.8)
	b.add(0.8)
	var prev := a.offset()
	for i in 30:
		a.step(1.0 / 60.0)
		b.step(1.0 / 60.0)
		assert_eq(a.offset(), b.offset(), "same seed, same shake")
		assert_true(a.offset().distance_to(prev) <= ScreenShake.MAX_PX * 0.9, "no single-frame teleports")
		prev = a.offset()


func test_shots_shake_by_weapon_weight() -> void:
	var pistol := ScreenShake.shot_trauma("medium_pistol")
	var rifle := ScreenShake.shot_trauma("assault_rifle")
	var shotgun := ScreenShake.shot_trauma("shotgun")
	var heavy := ScreenShake.shot_trauma("rocket_launcher")
	assert_true(pistol < rifle and rifle < shotgun and shotgun < heavy, "pistol < rifle < shotgun < heavy")
	assert_true(heavy < ScreenShake.EXPLOSION, "a blast is the biggest")
	assert_true(ScreenShake.shot_trauma("smg", true) < pistol, "each round of a burst is lighter than a pistol shot")
	assert_true(ScreenShake.KILL < ScreenShake.CREW_DOWN, "losing one of the crew hits harder than a kill")
	assert_true(ScreenShake.shot_trauma("no_such_gun") > 0.0, "unknown weapons still tick")
	# the whole weapon table resolves
	for wid in (RulesDB.load_json("weapons.json")["weapons"] as Dictionary):
		var tr := ScreenShake.shot_trauma(String(wid))
		assert_true(tr >= 0.0 and tr <= 0.5, "%s: %.2f" % [wid, tr])
	# a pistol shot at the default strength stays a light tick: a pixel or so
	var s := ScreenShake.new()
	s.add(pistol)
	assert_true(s.amplitude() < 1.0, "a pistol tick is under a buffer pixel of noise (%.2f)" % s.amplitude())


func test_callout_pops() -> void:
	var dmg := CalloutPop.plan("dmg", false, true)
	assert_true(float(dmg.peak) > float(dmg.rest) and float(dmg.from) < float(dmg.rest), "a damage number overshoots")
	assert_true(float(dmg.drift) > 0.0, "drifts the way asked")
	assert_true(float(CalloutPop.plan("dmg", false, false).drift) < 0.0)
	var crit := CalloutPop.plan("crit", false)
	assert_true(float(crit.peak) > float(dmg.peak) and float(crit.rest) >= float(dmg.rest), "a crit pops bigger")
	assert_true(CalloutPop.font_size("crit", "-12") > CalloutPop.font_size("dmg", "-12"))
	assert_eq(CalloutPop.font_size("", "HEADSHOT"), 30, "plain words keep their size")
	assert_eq(CalloutPop.font_size("", "!"), 40)
	var plain := CalloutPop.plan("", false)
	assert_eq(float(plain.from), 1.25, "the plain slam is unchanged")
	assert_eq(float(plain.drift), 0.0)
	for st in ["", "dmg", "crit", "ping"]:
		var r := CalloutPop.plan(st, true)
		assert_eq(float(r.from), float(r.rest), "%s: no overshoot in reduced motion" % st)
		assert_eq(float(r.peak), float(r.rest))
		assert_eq(float(r.drift), 0.0)
		assert_eq(float(r.tilt), 0.0)
		assert_true(bool(r.fade_in), "it fades in instead")
	assert_eq(CalloutPop.arc(0.0, 400.0), 0.0)
	assert_eq(CalloutPop.arc(400.0, 400.0), 1.0)
	assert_eq(CalloutPop.arc(9000.0, 400.0), 1.0)
	assert_true(CalloutPop.arc(100.0, 400.0) > 0.25, "ease-out: quick off the mark")


func test_overlay_curves() -> void:
	assert_eq(HudJuice.key_at(HudJuice.ALARM_KEYS, 0.0), 0.0)
	assert_near(HudJuice.key_at(HudJuice.ALARM_KEYS, 0.1), 0.8, 0.0001, "the first throb")
	assert_true(HudJuice.key_at(HudJuice.ALARM_KEYS, 0.42) < HudJuice.key_at(HudJuice.ALARM_KEYS, 0.55), "and a second")
	assert_eq(HudJuice.key_at(HudJuice.ALARM_KEYS, 5.0), 0.0, "then gone")
	var calm_peak := 0.0
	for i in 100:
		calm_peak = maxf(calm_peak, HudJuice.key_at(HudJuice.ALARM_KEYS_CALM, i * 0.012))
	assert_true(calm_peak < 0.6, "reduced motion: one soft swell")


func test_the_overlays_free_themselves() -> void:
	var host := Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	host.size = Vector2(1280, 720)
	var j := HudJuice.objective_flourish(host, Rect2(1000, 10, 260, 90))
	assert_true(j != null and j.get_parent() == host, "the flourish is its own overlay")
	assert_eq(j.mouse_filter, Control.MOUSE_FILTER_IGNORE, "and never takes the mouse")
	j._process(HudJuice.FLOURISH_SECS + 0.1)
	assert_true(j.is_queued_for_deletion(), "gone after FLOURISH_SECS")
	var e := HudJuice.alarm_pulse(host)
	e._process(10.0)
	assert_true(e.is_queued_for_deletion())
	assert_eq(HudJuice.objective_flourish(host, Rect2()), null, "no panel, no flourish")
	host.queue_free()


func test_shake_setting_persists_and_defaults() -> void:
	var saved := GameSettings.load_values()
	assert_near(float(GameSettings.DEFAULTS.shake), 0.6, 0.0001, "default ~60%")
	var v := saved.duplicate()
	v.shake = 0.35
	v.reduced_motion = true
	GameSettings.save_values(v)
	var back := GameSettings.load_values()
	assert_near(float(back.shake), 0.35, 0.0001, "the slider is saved")
	assert_true(bool(back.reduced_motion), "and reduced motion with it")
	assert_near(GameSettings.shake(), 0.35, 0.0001)
	v.shake = 7.0
	GameSettings.save_values(v)
	assert_eq(float(GameSettings.load_values().shake), 1.0, "clamped on load")
	GameSettings.save_values(saved)


func test_stingers_exist() -> void:
	for n in ["sfx_kill_sting", "sfx_crew_down", "sfx_siren_swell", "sfx_objective_done"]:
		assert_true(ResourceLoader.exists("res://assets/audio/%s.wav" % n), n)


func test_the_hp_ghost_holds_then_catches_up() -> void:
	var g := [0.8, 1000]
	assert_eq(Hud.ghost_value(g, 0.5, 1000), 0.8, "the lost chunk holds at first")
	assert_eq(Hud.ghost_value(g, 0.5, 1000 + int(Hud.GHOST_HOLD * 1000.0) - 10), 0.8, "for GHOST_HOLD")
	var mid := Hud.ghost_value(g, 0.5, 1000 + int((Hud.GHOST_HOLD + Hud.GHOST_DRAIN / 2.0) * 1000.0))
	assert_true(mid < 0.8 and mid > 0.5, "then drains (%.2f)" % mid)
	assert_eq(Hud.ghost_value(g, 0.5, 99999), 0.5, "and catches up")
	assert_eq(Hud.ghost_value([], 0.5, 0), -1.0, "no hit, no ghost")
	assert_true(Hud.GHOST_HOLD + Hud.GHOST_DRAIN < 1.0, "under a second: never holds the turn up")


func test_foe_gunfire_shakes_less_than_the_crew_s() -> void:
	var t := ScreenShake.shot_trauma("assault_rifle")
	assert_eq(ScreenShake.shot_by(t, false), t, "the crew's own shots: full")
	assert_near(ScreenShake.shot_by(t, true), t * 0.6, 0.0001, "a foe's: about 60%")
