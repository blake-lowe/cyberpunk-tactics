extends TestCase


func test_queue_sorted_descending_and_rotates() -> void:
	var init := Initiative.new(Dice.new(3))
	for i in 5:
		init.add(Fixtures.unarmored("C%d" % i, {"REF": i * 2}))
	for i in init.entries.size() - 1:
		assert_true(init.entries[i].roll >= init.entries[i + 1].roll)
	var first := init.next_turn()
	assert_eq(init.round_num, 1)
	for i in 4:
		init.next_turn()
	assert_eq(init.next_turn(), first)
	assert_eq(init.round_num, 2)


func test_dead_are_skipped() -> void:
	var init := Initiative.new(Dice.new(3))
	var a := Fixtures.unarmored("A")
	var b := Fixtures.unarmored("B")
	init.add(a)
	init.add(b)
	init.order()[1].dead = true
	var alive := init.order()[0]
	assert_eq(init.next_turn(), alive)
	assert_eq(init.next_turn(), alive)


func test_reinforcement_join_keeps_current_turn() -> void:
	var init := Initiative.new(Dice.new(9))
	for i in 4:
		init.add(Fixtures.unarmored("C%d" % i))
	init.next_turn()
	init.next_turn()
	var cur := init.current()
	for i in 6:
		init.add(Fixtures.unarmored("R%d" % i, {"REF": i * 3}))
	assert_eq(init.current(), cur)
	assert_eq(init.entries.size(), 10)


func test_cover_hp_and_destruction() -> void:
	var c := Cover.make("concrete", true)
	assert_eq(c.max_hp, 25)
	assert_true(c.blocks_explosion(24))
	assert_false(c.blocks_explosion(25))
	assert_false(c.take_damage(20))
	assert_true(c.take_damage(20))
	assert_false(c.is_cover())
	assert_false(Cover.make("plaster", false).is_cover(), "thin plaster is not cover")
