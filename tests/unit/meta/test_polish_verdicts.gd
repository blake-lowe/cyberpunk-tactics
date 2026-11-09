extends TestCase
## Owner verdicts 2026-11-09 on the Single Player Mode build, between gigs: intel is never free,
## the job card's focus item reads inline in the blurb, the debrief's left-behind line is short.


func _labels(n: Node) -> Array:
	return n.find_children("*", "Label", true, false).map(func(l): return String((l as Label).text))


func test_a_new_game_has_no_intel() -> void:
	for s in [1, 6, 42, 977]:
		var c := Campaign.new_game(s)
		assert_eq(c.intel, 0, "seed %d: no intel token at the start" % s)
		for k in 4:
			assert_false(c.board.any(func(g): return g.has("intel") or g.has("complication")), "seed %d: nothing foreseen on the board" % s)
			c.refresh_board()
		var back := Campaign.from_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
		assert_eq(back.intel, 0, "seed %d: none after a save and load" % s)


func test_only_an_information_payment_brings_intel() -> void:
	var c := Campaign.new_game(6)
	for kind in ["eb", "favour", "goods"]:
		var g: Dictionary = c.board[0].duplicate(true)
		g["pay"] = int(g.payment.base)
		MissionBuilder.payment_step(c.dice, g, kind, func(v: int) -> Array: return c.goods_pool(v))
		c._collect_payment(g)
		assert_eq(c.intel, 0, "%s pays no intel" % kind)
	var gi: Dictionary = c.board[0].duplicate(true)
	gi["pay"] = int(gi.payment.base)
	MissionBuilder.payment_step(c.dice, gi, "information")
	c._collect_payment(gi)
	assert_eq(c.intel, 1, "information does")


func test_the_focus_item_is_gold_inside_the_blurb() -> void:
	Hud._fonts()
	var gold := "[color=#%s]" % Hud.GOLD.to_html(false)
	var named := 0
	var offers := 0
	for s in [3, 17, 77]:
		var c := Campaign.new_game(s)
		for k in 4:
			var fs := FixerScreen.new()
			fs.camp = c
			for i in c.board.size():
				var g: Dictionary = c.board[i]
				if not g.get("focus") is Dictionary or (g.focus as Dictionary).is_empty():
					continue
				offers += 1
				var bb := FixerScreen.blurb_bbcode(g)
				assert_eq(bb.count(gold), 1, "one gold phrase: %s" % bb)
				var inside := bb.get_slice(gold, 1).get_slice("[/color]", 0)
				var slots := MissionBuilder.item_slots(g.focus)
				assert_true([slots.item, slots.the_item, slots.item_short].any(func(w): return String(w).to_lower() == inside.to_lower()), "the item's words: %s" % inside)
				if not bb.contains("It's about "):
					named += 1
				var card := fs._gig_card(i, true)
				assert_false(_labels(card).any(func(t): return String(t).begins_with("Focus:")), "no Focus line of its own")
				var rich: Array = card.find_children("*", "RichTextLabel", true, false)
				assert_true(rich.any(func(r): return String((r as RichTextLabel).text) == bb), "the blurb on the card is the gold one")
				card.free()
			fs.free()
			c.refresh_board()
	assert_true(offers >= 20, "offers checked (%d)" % offers)
	assert_true(named * 4 >= offers * 3, "most blurbs name the item themselves (%d of %d)" % [named, offers])


func test_blurb_phrases_match_whole_words() -> void:
	assert_eq(FixerScreen.phrase_at("A score to settle over the core.", "core"), 27)
	assert_eq(FixerScreen.phrase_at("Nothing here.", "core"), -1)
	var g := {"blurb": "Grab [it] now.", "focus": {"label": "a tech prototype", "short": "tech prototype"}}
	assert_eq(FixerScreen.blurb_bbcode(g), "Grab [lb]it] now. It's about [color=#%s]a tech prototype[/color]." % Hud.GOLD.to_html(false))


func test_debrief_left_behind_is_short() -> void:
	Hud._fonts()
	for n in [1, 3]:
		var p := DebriefScreen.loot_panel({"loot": [], "loot_lost": n})
		var texts := _labels(p)
		assert_true(texts.has("%d find%s left behind." % [n, "" if n == 1 else "s"]), "%d: %s" % [n, texts])
		assert_false(texts.any(func(t): return String(t).contains("didn't get out")))
		p.free()
