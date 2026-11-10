extends TestCase
## M10 feel: wound-state words over a unit (CalloutQueue), the Seriously Wounded limp's pace, and
## the end-of-gig beat (EndJuice).

const W := Combatant.Wound


func test_wound_changes_map_to_their_words() -> void:
	assert_eq(CalloutQueue.wound_key(W.LIGHT, W.SERIOUS, false), "serious")
	assert_eq(CalloutQueue.wound_key(W.UNHURT, W.SERIOUS, false), "serious")
	assert_eq(CalloutQueue.wound_key(W.SERIOUS, W.MORTAL, false), "mortal")
	assert_eq(CalloutQueue.wound_key(W.UNHURT, W.MORTAL, false), "mortal", "straight to Mortally Wounded: the worse word only")
	assert_eq(CalloutQueue.wound_key(W.MORTAL, W.DEAD, true), "flatlined")
	assert_eq(CalloutQueue.wound_key(W.LIGHT, W.DEAD, true), "flatlined", "an NPC with no Death Saves drops dead")
	assert_eq(CalloutQueue.wound_key(W.LIGHT, W.SERIOUS, false, true), "unconscious", "a stun hit: unconscious, not the wound")
	assert_eq(CalloutQueue.wound_key(W.MORTAL, W.MORTAL, false), "", "hit again while down: nothing new")
	assert_eq(CalloutQueue.wound_key(W.SERIOUS, W.SERIOUS, false), "")
	assert_eq(CalloutQueue.wound_key(W.UNHURT, W.LIGHT, false), "")
	assert_eq(CalloutQueue.wound_key(W.DEAD, W.DEAD, true), "", "already dead")
	var words := {"stabilized": "STABILIZED", "unconscious": "UNCONSCIOUS", "serious": "SERIOUSLY WOUNDED",
		"mortal": "MORTALLY WOUNDED", "flatlined": "FLATLINED"}
	for k in words:
		assert_eq(String(CalloutQueue.WOUND[k].text), words[k], k)
		assert_true(ResourceLoader.exists("res://assets/audio/%s.wav" % CalloutQueue.WOUND[k].sfx), "%s has its sound" % k)
	var sounds := {}
	for k in words:
		sounds[CalloutQueue.WOUND[k].sfx] = true
	assert_eq(sounds.size(), words.size(), "every state sounds different")


## No two callouts on a unit ever come closer than a line, at any moment while both are up.
func _assert_no_overlap(q: CalloutQueue, key: Variant, until: int) -> void:
	for now in range(0, until, 10):
		var lane := q.live(key, now)
		for i in lane.size():
			for j in range(i + 1, lane.size()):
				var gap := absf(CalloutQueue.y_at(lane[i], now) - CalloutQueue.y_at(lane[j], now))
				assert_true(gap >= CalloutQueue.LINE - 0.001, "callouts %d and %d %.1f px apart at %d ms" % [i, j, gap, now])
				if gap < CalloutQueue.LINE - 0.001:
					return


func test_a_hit_s_callouts_stack_with_the_wound_word_last_and_on_top() -> void:
	var q := CalloutQueue.new()
	# a crit that Mortally Wounds: the damage number, HEADSHOT, CRITICAL · ... in one frame
	var ys: Array = []
	for i in 3:
		ys.append(q.place(7, 1000))
	assert_eq(ys, [0.0, -CalloutQueue.LINE, -2 * CalloutQueue.LINE], "same-frame callouts stack upward a line apart")
	var d := q.wound_delay(7, 1000)
	assert_eq(d, CalloutQueue.WOUND_DELAY_MS, "the wound word waits a beat")
	var yw := q.place(7, 1000 + d, CalloutQueue.WOUND_LIFE_MS)
	for c in q.live(7, 1000 + d):
		if int(c.at) == 1000:
			assert_true(yw <= CalloutQueue.y_at(c, 1000 + d) - CalloutQueue.LINE + 0.001, "the wound word lands above the crit")
	_assert_no_overlap(q, 7, 4000)
	# FLATLINED right after on the same unit keeps its own gap after MORTALLY WOUNDED
	var d2 := q.wound_delay(7, 1000)
	assert_eq(d2, CalloutQueue.WOUND_DELAY_MS + CalloutQueue.WOUND_GAP_MS, "wound words queue one after the other")
	q.place(7, 1000 + d2, CalloutQueue.WOUND_LIFE_MS)
	_assert_no_overlap(q, 7, 4000)


func test_late_callouts_never_land_on_rising_ones() -> void:
	var q := CalloutQueue.new()
	for at in [0, 0, 90, 300, 300, 650, 900, 1250, 1290, 1700, 2600, 2610]:
		q.place(1, at, CalloutQueue.WOUND_LIFE_MS if at % 300 == 0 else CalloutQueue.LIFE_MS)
	_assert_no_overlap(q, 1, 5000)
	assert_eq(q.place(2, 0), 0.0, "lanes are per unit")
	assert_eq(q.place(1, 9000), 0.0, "an empty lane starts at the anchor again")


func test_the_limp_matches_its_stride() -> void:
	var step := CharModel.injured_step()
	var native: float = CharAnims.speed.get("injured_walk", CharModel.INJURED_NATIVE)
	var playback := (1.0 / step) / CharModel.SCALE / native   # what CharModel._pick sets: ground / native
	assert_near(playback, CharModel.INJURED_RATE, 0.001, "playback at the limp's rate, so the feet don't slide")
	assert_near(CharModel.INJURED_RATE, 2.5 * 0.8, 0.001, "0.8x the old capped rate")
	assert_true(step > 0.33, "slower than a healthy walker's square (%.2f s)" % step)


func test_the_end_beat_fires_once_and_both_ways_mirror() -> void:
	var j := EndJuice.new()
	var a := j.fire("lost")
	assert_eq(String(a.sting), "sfx_gig_fail")
	assert_true(float(a.saturation) < 1.0, "a failure drains the colour")
	assert_true(float(a.push) < 1.0, "and pushes the camera in")
	assert_true(j.fire("lost").is_empty(), "the second call does nothing")
	assert_true(j.fire("won").is_empty(), "nor any later end")
	var w := EndJuice.plan("won")
	assert_eq(String(w.sting), "sfx_gig_win")
	assert_eq(w.keys(), a.keys(), "success does the same beats as failure")
	assert_true(float(w.saturation) > 1.0, "a win lifts the colour")
	assert_eq(String(EndJuice.plan("fled").sting), "sfx_gig_fail", "walking away is a failure beat")
	for p in [a, w]:
		assert_true(float(p.panel_delay) + EndJuice.PANEL_FADE <= 1.5, "the end panel is up within 1.5 s")
		assert_true(ResourceLoader.exists("res://assets/audio/%s.wav" % p.sting), "%s exists" % p.sting)


## A morale or wound word over a crit number clears the number's bigger face and its pop.
func test_a_word_over_a_crit_number_clears_its_face_and_pop() -> void:
	var q := CalloutQueue.new()
	var yc := q.place(3, 1000, CalloutQueue.LIFE_MS, CalloutPop.line_height("crit", "-26"), CalloutPop.overshoot("crit", "-26"))
	var t := 1000 + q.wound_delay(3, 1000)
	var yw := q.place(3, t, CalloutQueue.WOUND_LIFE_MS, CalloutPop.line_height("", "GUARD 3 SURRENDERS"), CalloutPop.overshoot("", "GUARD 3 SURRENDERS"))
	var crit_c: Dictionary = q.live(3, t)[0]
	var gap := CalloutQueue.y_at(crit_c, t) - yw
	assert_true(gap >= CalloutPop.line_height("", "GUARD 3 SURRENDERS") + CalloutPop.overshoot("crit", "-26"), "the word clears the crit's pop (%.1f px)" % gap)
	assert_true(CalloutPop.line_height("crit", "-26") > CalloutQueue.LINE, "a crit number is taller than a word line")
	assert_eq(yc, 0.0)
