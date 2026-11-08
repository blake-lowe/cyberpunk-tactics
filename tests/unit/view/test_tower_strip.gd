extends TestCase
## The tower strip (docs/plans/towers.md T1/T3; stage 1a): on a tower band the floor stack names
## each storey by its real number and programme, marks the lift car's storey and (towers only, owner)
## the objective's storey, and stands for the storeys below the band with a hairline and the street
## lobby as a dim row, off the map.
const GREYBOX := preload("res://src/tactical/greybox.gd")


func _hud() -> Hud:
	var h := Hud.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(h)
	if not h.is_inside_tree():
		h._ready()
	return h


func _rows(m: TacMap, cur: int) -> Array:
	var out := []
	for f in range(m.floors - 1, -1, -1):
		out.append({"f": f, "label": "R" if f == m.floors - 1 else m.floor_name(f), "crew": 2 if f == 0 else 0, "foes": 1 if f == 2 else 0, "cur": f == cur})
	return out


func test_the_strip_names_storeys_programmes_the_car_and_the_objective() -> void:
	var m := SceneGen.generate(3, "tower_top", {"tower": "raven", "security": 2})
	var data := {"name": "RAVEN", "rows": _rows(m, 1), "up_ok": true, "down_ok": true, "hint_dir": -1}
	GREYBOX.tower_strip(m, data, [-1, Vector3i(5, 5, 2), 0])
	var rows: Array = data.rows
	assert_eq(rows.map(func(r): return String(r.label)), ["R", "50", "49", "48"], "real storeys, roof on top")
	assert_eq(rows.map(func(r): return String(r.prog)), ["roof", "exec suite", "labs", "sky lobby"], "each storey's programme")
	assert_eq(rows.map(func(r): return bool(r.car)), [false, false, false, true], "the car waits at 48, where the crew came up")
	assert_eq(rows.map(func(r): return bool(r.obj)), [false, true, false, false], "a gold notch on the objective's storey")
	assert_eq(String(data.name), "RAVEN MICROCYBERNETICS")
	assert_eq(int(data.tower.storeys), 50)
	assert_eq(int(data.tower.below_n), 47, "47 storeys under the band")
	var h := _hud()
	h.floor_stack(data)
	assert_eq(h._stack_rows.get_child_count(), rows.size() + 2, "the band's rows, the hairline, the lobby")
	assert_true(h._stack_rows.get_child(rows.size()) is Hud.StackGap, "the run of storeys below: a hairline, not a button")
	var lobby: Hud.StackRow = h._stack_rows.get_child(rows.size() + 1)
	assert_true(lobby.disabled and String(lobby.r.prog).contains("off map"), "the street lobby: off the map, dead")
	assert_true(h._stack_head.text.contains("50 F"), "the header gives the tower's height: %s" % h._stack_head.text)
	assert_eq(h._floor_up.custom_minimum_size.x, Hud.STACK_W_TOWER, "the strip is wider than a building's stack")
	h.floor_stack({"name": "BD PARLOR", "rows": [{"f": 0, "label": "1", "crew": 1, "foes": 0, "cur": true}], "up_ok": false, "down_ok": false, "hint_dir": 0})
	assert_eq(h._stack_rows.get_child_count(), 1, "an ordinary building's stack is as it was")
	assert_eq(h._floor_up.custom_minimum_size.x, Hud.STACK_W)
	h.free()


func test_the_lift_car_is_built_with_its_floor_indicator() -> void:
	var m := SceneGen.generate(3, "tower_top", {"tower": "raven", "security": 2})
	var vision := Vision.new(m, Los.new(m))
	var wb := WorldBuilder.new(m, vision, ImageTexture.create_from_image(Image.create(m.w, m.h * m.floors, false, Image.FORMAT_RG8)))
	assert_eq(wb._surround(), "sky", "a tower band hangs over the city, no street skyline")
	var root := Node3D.new()
	var floors := wb.build(root)
	assert_eq(floors.size(), m.floors)
	assert_true(root.get_node_or_null("skyline") != null, "the facade, the smog and the far city")
	assert_true(WorldBuilder.SEGS.has("4") and WorldBuilder.SEGS.has("8"), "seven-segment digits for the indicator")
	root.free()


func test_alt_shows_a_lift_plate_over_the_car() -> void:
	var m := SceneGen.generate(3, "tower_top", {"tower": "raven", "security": 2})
	var car := TowerGen.car(m)
	var all := func(_v: Vector3i) -> bool: return true
	for f in m.floors - 1:
		var lifts := FloorNav.signs(m, f, all).filter(func(s): return s.kind == "lift")
		assert_eq(lifts.size(), 1, "one lift plate on %s" % m.floor_name(f))
		assert_eq(Vector2i(lifts[0].cell.x, lifts[0].cell.y), Vector2i(car.pos), "over the car")
	assert_true(FloorNav.signs(m, 0, all).any(func(s): return s.kind == "stairs"), "the fire stair keeps its stairs plate")
	var plain := SceneGen.generate(4100, "lone_building", {"site": "hotel", "security": 1, "basement_storeys": 0})
	assert_false(FloorNav.signs(plain, 0, all).any(func(s): return s.kind == "lift"), "an ordinary building's lift is as it was")
