extends TestCase
## The floor stack (owner, UI fixes 5): the building, ▲ SHIFT / ▼ CTRL key hints, the storey rows;
## no subtitle line and no ELSEWHERE rows. The Alt roster's cards say where each crew member is.
const GREYBOX := preload("res://src/tactical/greybox.gd")


func _hud() -> Hud:
	var h := Hud.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(h)
	if not h.is_inside_tree():   # the test runner's tree isn't live yet: build by hand
		h._ready()
	return h


func _labels(n: Node) -> Array[String]:
	var out: Array[String] = []
	for l in n.find_children("*", "Label", true, false):
		if not (l as Label).is_queued_for_deletion():
			out.append((l as Label).text)
	return out


func test_stack_has_the_building_key_hints_and_no_elsewhere_or_subtitle() -> void:
	var h := _hud()
	h.floor_stack({"name": "BD PARLOR", "rows": [{"f": 2, "label": "2", "crew": 1, "foes": 1, "cur": true}, {"f": 1, "label": "1", "crew": 0, "foes": 0, "street": true}],
		"up_ok": true, "down_ok": true, "hint_dir": 0, "elsewhere": [{"unit": {"id": 3}, "label": "OTHER 1"}], "why": "selected"})
	var texts := _labels(h._stack)
	assert_eq(texts, ["BD PARLOR"], "the building's name is the stack's only text label: %s" % [texts])
	assert_false(texts.any(func(t): return t.contains("ELSEWHERE") or t == "selected"), "no ELSEWHERE row, no subtitle")
	assert_eq(h._stack_rows.get_child_count(), 2, "one row per storey")
	assert_eq(h._floor_up.key, "SHIFT", "▲ shows its hold key")
	assert_eq(h._floor_down.key, "CTRL", "▼ too")
	h.free()


func test_roster_card_shows_building_and_floor() -> void:
	var h := _hud()
	var u := {"id": 0, "team": 0, "c": Fixtures.shooter("Vex")}
	h.portraits._cache[0] = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))   # no 3D bust in a unit test
	h.crew_where = {0: GREYBOX.where_label("BD PARLOR", "2")}
	var card := h._party_card(u, true)
	assert_true(_labels(card).has("BD PARLOR · 2"), "one dim line: building · floor (%s)" % [_labels(card)])
	card.free()
	h.crew_where = {}
	card = h._party_card(u, true)
	assert_false(_labels(card).any(func(t): return t.contains(" · ")), "no data: no line")
	card.free()
	assert_eq(GREYBOX.where_label("STREET", "1"), "STREET · 1", "outdoors")
	assert_eq(GREYBOX.where_label("A VERY LONG BUILDING NAME", "R"), "A VERY LONG BUIL · R", "long names cut, roofs read R")
	h.free()
