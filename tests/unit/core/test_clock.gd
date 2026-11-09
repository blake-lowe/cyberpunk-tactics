extends TestCase
## Solo Play Clocks (Clock; SPM p.25-26): the pool, the triggers' maths against the book's figures,
## the variants, save/load and determinism.


## Triggers until a fresh clock empties, on `dice`.
func _run(dice: Dice, n: int, drop: Array = [1]) -> int:
	var c := Clock.make("t", n, drop)
	var k := 0
	while c.running() and k < 1000:
		c.trigger(dice)
		k += 1
	return k


func test_a_roll_drops_every_die_showing_a_1() -> void:
	var c := Clock.make("t", 5)
	var r := c.trigger(Dice.new(1), [1, 4, 1, 6, 2])
	assert_eq(r.removed, [0, 2], "the two 1s")
	assert_eq(int(r.left), 3)
	assert_eq(c.pool, 3)
	assert_false(bool(r.emptied))
	assert_eq(c.rolls, 1)
	assert_eq(c.last, [1, 4, 1, 6, 2])


func test_expected_triggers_match_the_book() -> void:
	# SPM p.25: about 10.5 rolls for 3d6, 13 for 5d6, 15 for 8d6 (drop on 1).
	var book := {3: 10.5, 5: 13.0, 8: 15.0}
	for n in book:
		var exact := Clock.expected_rolls(n, 1.0 / 6.0)
		assert_near(exact, float(book[n]), 0.45, "%dd6 exact mean %.2f vs the book's" % [n, exact])
		var sum := 0
		var runs := 3000
		for s in runs:
			sum += _run(Dice.new(s + 1), n)
		var mean := float(sum) / runs
		assert_near(mean, exact, 0.45, "%dd6 simulated mean %.2f vs exact %.2f" % [n, mean, exact])


func test_the_harder_variant_empties_about_twice_as_fast() -> void:
	var easy := Clock.expected_rolls(5, 1.0 / 6.0)
	var hard := Clock.expected_rolls(5, 2.0 / 6.0)
	assert_between(easy / hard, 1.8, 2.3, "drop on 1 or 6 (SPM p.26)")
	var sum := 0
	for s in 3000:
		sum += _run(Dice.new(s + 7), 5, [1, 6])
	assert_near(float(sum) / 3000.0, hard, 0.3, "simulated")
	var c := Clock.make("t", 3, [1, 6])
	assert_eq(c.trigger(Dice.new(1), [6, 1, 3]).removed, [0, 1], "a 6 goes too")
	assert_near(c.drop_chance(), 1.0 / 3.0, 0.0001)


func test_degrees_of_consequence() -> void:
	var c := Clock.make("t", 2)
	var r := c.trigger(Dice.new(1), [1, 1])
	assert_true(bool(r.emptied) and bool(r.escalated), "the last two dice in one roll")
	assert_true(c.is_empty() and c.escalated)
	var one := Clock.make("t", 2)
	one.trigger(Dice.new(1), [1, 4])
	var r2 := one.trigger(Dice.new(1), [1])
	assert_true(bool(r2.emptied) and not bool(r2.escalated), "one at a time: the plain outcome")
	var off := Clock.make("t", 2, [1], false)
	assert_false(bool(off.trigger(Dice.new(1), [1, 1]).escalated), "variant off")
	assert_true(c.trigger(Dice.new(1)).is_empty(), "an empty clock rolls no more")


func test_add_die_back_never_past_the_start() -> void:
	var c := Clock.make("t", 4)
	assert_eq(c.add_die(), 0, "full")
	c.trigger(Dice.new(1), [1, 1, 3, 4])
	assert_eq(c.add_die(), 1)
	assert_eq(c.pool, 3)
	assert_eq(c.add_die(3), 1, "capped at the starting pool")
	assert_eq(c.pool, 4)
	assert_eq(c.reclaimed, 2)
	c.stop()
	assert_eq(c.add_die(), 0, "a stopped clock takes none")
	assert_eq(c.state, "stopped")


func test_save_and_load_keeps_the_clock() -> void:
	var c := Clock.make("detection", 6, [1], true, ["noise", "failed_tech"], "DETECTION")
	var d := Dice.new(99)
	for i in 4:
		c.trigger(d)
	c.add_die()
	c.meta["event"] = "alarm"
	var back := Clock.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(back.to_dict(), c.to_dict(), "the same clock after a JSON round trip")
	var d2 := Dice.new(1)
	d2.rng.state = d.rng.state
	for i in 6:
		assert_eq(back.trigger(d2), c.trigger(d), "rolls on as the original does (roll %d)" % i)


func test_the_same_seed_rolls_the_same_clock() -> void:
	var a := Clock.make("t", 5)
	var b := Clock.make("t", 5)
	var da := Dice.new(4242)
	var db := Dice.new(4242)
	while a.running():
		assert_eq(a.trigger(da), b.trigger(db))
	assert_eq(a.rolls, b.rolls)
