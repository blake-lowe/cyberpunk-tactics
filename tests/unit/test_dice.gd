extends TestCase


func test_same_seed_same_rolls() -> void:
	var a := Dice.new(42)
	var b := Dice.new(42)
	assert_eq(a.roll_each(20, 10), b.roll_each(20, 10))


func test_roll_stays_in_range() -> void:
	var dice := Dice.new(7)
	for i in 1000:
		assert_between(dice.roll(3, 6), 3, 18)


func test_d10_hits_every_face() -> void:
	var dice := Dice.new(1)
	var seen := {}
	for i in 500:
		seen[dice.d(10)] = true
	assert_eq(seen.size(), 10)
