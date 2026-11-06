extends TestCase
## The Fixer Network's CITY tab (M9 P3): the map builds from data/world/city.json at every
## supported window size, every district has a fillable outline and a name label inside the view
## that doesn't overlap another; picking an offer plots the drive from the safehouse (a route over
## district neighbours, animated) and pins it; hovering never resizes anything; a pin opens JOBS.

## The map's logical size at 1280x720 / 1920x1080 (UiScale 1 / 1.5) and 1600x900 (1.5), roughly.
const SIZES := [Vector2(924, 568), Vector2(711, 466), Vector2(1100, 700)]


func _map(camp: Campaign, sz: Vector2) -> CityMap:
	Hud._fonts()
	var m := CityMap.new().setup(camp)
	m.size = sz
	m.layout()
	return m


func test_every_district_has_an_outline_and_a_label() -> void:
	var camp := DemoState.make()
	for sz in SIZES:
		var m := _map(camp, sz)
		var view := Rect2(Vector2.ZERO, sz)
		for id in World.districts():
			assert_true(CityMap.outline(id).size() >= 3, "%s has an outline" % id)
			assert_false((m._fills[id] as Array).is_empty(), "%s's outline can be filled" % id)
			assert_true(m.labels.has(id), "%s has a label" % id)
			var r: Rect2 = m.labels[id].rect
			assert_true(view.encloses(r), "%s's label is inside the %s view" % [id, sz])
		var ids: Array = m.labels.keys()
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				assert_false((m.labels[ids[i]].rect as Rect2).intersects(m.labels[ids[j]].rect),
					"labels %s and %s overlap at %s" % [ids[i], ids[j], sz])
		m.free()


func test_callout_leaders_neither_cross_nor_run_through_labels() -> void:
	var camp := DemoState.make()
	for sz in SIZES:
		var m := _map(camp, sz)
		var ids: Array = m.labels.keys().filter(func(id): return bool(m.labels[id].callout))
		for i in ids.size():
			var L: Dictionary = m.labels[ids[i]]
			var li := CityMap.leader(L.rect, int(L.align), L.anchor, L.via)
			assert_true(Geometry2D.is_point_in_polygon(L.anchor, m._polys[ids[i]]), "%s's leader ends in the district" % ids[i])
			for j in range(i + 1, ids.size()):
				var M: Dictionary = m.labels[ids[j]]
				if int(M.align) == int(L.align):
					assert_false(CityMap._leaders_cross(li, CityMap.leader(M.rect, int(M.align), M.anchor, M.via)),
						"leaders of %s and %s cross at %s" % [ids[i], ids[j], sz])
			for id in m.labels:
				if id != ids[i] and not bool(m.labels[id].callout):
					for k in range(1, li.size() - 1):
						assert_false(CityMap._seg_hits_rect(li[k], li[k + 1], m.labels[id].rect), "%s's leader runs through %s's label at %s" % [ids[i], id, sz])
		m.free()


func test_map_data_is_whole() -> void:
	var map := CityMap.city_map()
	for id in map.districts:
		assert_true(World.districts().has(id), "map district %s is a city district" % id)
	for id in World.districts():
		assert_true(map.districts.has(id), "%s is on the map" % id)
	for lid in World.locations():
		assert_true(World.districts().has(String(World.locations()[lid].district)), "%s is in a known district" % lid)


func test_route_points_follow_the_drive() -> void:
	assert_eq(CityMap.route_points("little_china", "little_china"), PackedVector2Array([CityMap.anchor("little_china")]), "same district: one point")
	assert_true(CityMap.route_points("little_china", "nowhere").is_empty(), "off the map: no route")
	for to in World.districts():
		var r := Travel.route("little_china", String(to))
		var pts := CityMap.route_points("little_china", String(to))
		assert_eq(pts.size(), r.size(), "a point per district crossed to %s" % to)
		if pts.is_empty():
			continue
		assert_eq(pts[0], CityMap.anchor("little_china"), "starts at the safehouse district")
		assert_eq(pts[pts.size() - 1], CityMap.anchor(String(to)), "ends at %s" % to)
		for k in range(1, r.size()):
			assert_true(String(r[k]) in World.neighbours(r[k - 1]), "%s → %s are neighbours" % [r[k - 1], r[k]])


func test_trace_draws_by_length() -> void:
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 30)])   # 40 long
	assert_eq(CityMap.trace(pts, 0.0), PackedVector2Array([Vector2(0, 0)]), "nothing drawn yet: the start")
	assert_eq(CityMap.trace(pts, 0.125), PackedVector2Array([Vector2(0, 0), Vector2(5, 0)]))
	assert_eq(CityMap.trace(pts, 0.5), PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10)]), "round the corner")
	assert_eq(CityMap.trace(pts, 1.0), pts, "whole")
	assert_eq(CityMap.trace(PackedVector2Array([Vector2(3, 3)]), 0.5).size(), 1)


func test_picking_a_gig_plots_it() -> void:
	var camp := DemoState.make()
	var m := _map(camp, SIZES[0])
	assert_eq(m.safehouse, camp.safehouse_district)
	assert_true(m.pins.is_empty(), "no gig picked: only the safehouse")
	assert_eq(m.homes.size(), 1)
	var before := {}
	for id in m.labels:
		before[id] = m.labels[id].rect
	var gi := -1
	for i in camp.board.size():
		if String(camp.board[i].get("district", "")) != camp.safehouse_district and World.districts().has(String(camp.board[i].get("district", ""))):
			gi = i
	assert_true(gi >= 0, "the demo board has an offer across town")
	m.select_gig(gi)
	assert_eq(m.pins.size(), 1, "the picked gig is pinned")
	assert_eq(m.pick(m.pins[0].pos), ["pin", str(gi)])
	assert_eq(m.route, Travel.route(camp.safehouse_district, String(camp.board[gi].district)))
	assert_eq(m._route_px.size(), m.route.size(), "the drawn route: house, the districts between, pin")
	assert_eq(m._route_px[0], m.homes[0])
	assert_eq(m._route_px[m._route_px.size() - 1], m.pins[0].pos)
	assert_eq(m.drive_text(), Travel.label(camp.travel_minutes(camp.board[gi])))
	assert_true(m.drive_text().ends_with("DRIVE"))
	for id in m.labels:
		assert_eq(m.labels[id].rect, before[id], "a pick never moves %s's label" % id)
	m.select_gig(-1)
	assert_true(m.pins.is_empty() and m._route_px.is_empty() and m.route.is_empty(), "cleared: only the safehouse again")
	var sea := m.to_local_px(Vector2(150, 200))   # the bay, clear of the callouts
	assert_eq(m.pick(sea), ["", ""], "open water is nothing")
	m.free()


## Owner playtest: the UI went crazy hovering the districts. Hover rebuilt the side panel, whose
## content set its width, which resized the map, which moved the labels under the mouse. Now hover
## only redraws and the panel's width is fixed.
func test_hover_never_resizes_the_map() -> void:
	var camp := DemoState.make()
	Hud._fonts()
	var s := FixerScreen.new()
	s.setup(camp, null, "city", 0)
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	if not s.is_inside_tree():
		s._ready()
	var city: CityTab = s.find_children("*", "CityTab", true, false)[0]
	var panel_child := city._panel.get_child(0)
	assert_eq(city._side.get_combined_minimum_size().x, float(CityTab.PANEL_W))
	for id in World.districts():
		city.map.set_hover("district", String(id))
		assert_eq(city._panel.get_child(0), panel_child, "hovering %s leaves the panel alone" % id)
	for i in range(-1, camp.board.size()):
		city.select_gig(i)
		assert_eq(city._side.get_combined_minimum_size().x, float(CityTab.PANEL_W), "the panel's width doesn't follow its content (gig %d)" % i)
	s.free()


func test_a_pin_opens_the_job() -> void:
	var camp := DemoState.make()
	Hud._fonts()
	var s := FixerScreen.new()
	s.setup(camp, null, "city", 0)
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	if not s.is_inside_tree():
		s._ready()
	var city: CityTab = s.find_children("*", "CityTab", true, false)[0]
	city.select_gig(0)
	assert_eq(city.map.gig, 0)
	var heads := city._panel.find_children("*", "Label", true, false).filter(func(l): return not l.is_queued_for_deletion() and (l as Label).text == String(camp.board[0].title))
	assert_false(heads.is_empty(), "the panel shows the picked job")
	city._on_click("pin", "0")
	assert_eq(s.tab, "jobs", "a pin opens JOBS")
	assert_eq(s.focus_gig, 0, "on that job")
	s.free()


func test_security_code_card_line() -> void:
	assert_true(FixerScreen.code_colour(2).b > FixerScreen.code_colour(2).r, "low codes are cool: help rarely comes")
	assert_true(FixerScreen.code_colour(9).r > FixerScreen.code_colour(9).b, "high codes are hot: it nearly always does")
	assert_eq(FixerScreen.short_faction("eri"), "ERI")
	assert_eq(FixerScreen.short_faction("ncpd"), "NCPD")
	assert_eq(SecurityCode.chance(11), 100)
	assert_eq(SecurityCode.chance(1), 0)
