extends TestCase
## The Fixer Network's CITY tab (M9 P3): the map builds from data/world/city.json at every
## supported window size, every district has a fillable outline and a label inside the view that
## doesn't overlap another, offers are pinned at their district, and a pin opens its job in JOBS.

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
			assert_true(CityMap.code_line(id).begins_with(str(CityMap.code_of(id)) + " · "), "the label carries the code")
		var ids: Array = m.labels.keys()
		for i in ids.size():
			for j in range(i + 1, ids.size()):
				assert_false((m.labels[ids[i]].rect as Rect2).intersects(m.labels[ids[j]].rect),
					"labels %s and %s overlap at %s" % [ids[i], ids[j], sz])
		m.free()


func test_map_data_is_whole() -> void:
	var map := CityMap.city_map()
	for id in map.districts:
		assert_true(World.districts().has(id), "map district %s is a city district" % id)
	for id in World.districts():
		assert_true(map.districts.has(id), "%s is on the map" % id)
	for key in map.ncart:
		assert_true(CityMap.LINES.has(key), "NCART line %s has a colour" % key)
	for lid in World.locations():
		assert_true(World.districts().has(String(World.locations()[lid].district)), "%s is in a known district" % lid)


func test_offers_are_pinned_and_picked() -> void:
	var camp := DemoState.make()
	var m := _map(camp, SIZES[0])
	var with_district := camp.board.filter(func(g): return World.districts().has(String(g.get("district", ""))))
	assert_false(with_district.is_empty(), "the demo board's offers carry districts")
	assert_eq(m.pins.size(), with_district.size(), "one pin per offer with a district")
	for pin in m.pins:
		assert_eq(m.pick(pin.pos), ["pin", str(pin.index)])
	assert_eq(m.pick(m.labels["watson_development"].rect.get_center()), ["district", "watson_development"], "a label picks its district")
	var sea := m.to_local_px(Vector2(150, 200))   # the bay, clear of the callouts
	for id in m.labels:
		assert_false((m.labels[id].rect as Rect2).has_point(sea), "no label over the test point (%s)" % id)
	assert_eq(m.pick(sea), ["", ""], "open water is nothing")
	m.free()


func test_code_colours_and_short_names() -> void:
	assert_true(CityMap.code_colour(2).b > CityMap.code_colour(2).r, "low codes are cool: help rarely comes")
	assert_true(CityMap.code_colour(9).r > CityMap.code_colour(9).b, "high codes are hot: it nearly always does")
	assert_eq(CityMap.short_faction("eri"), "ERI")
	assert_eq(CityMap.short_faction("ncpd"), "NCPD")
	assert_eq(CityMap.short_code({"n": 6, "faction": "ncpd", "intensity": "medium", "hardened": true}), "6 · NCPD · H-MED")
	assert_eq(CityMap.short_code({"n": 7, "faction": "thelas_marines", "intensity": "heavy", "hardened": false}), "7 · THELAS · HVY")
	assert_eq(CityTab.utility_text(6), "Power, water, CitiNet: each out 50% of the time")
	assert_eq(SecurityCode.chance(11), 100)
	assert_eq(SecurityCode.chance(1), 0)


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


func test_city_tab_builds_and_a_pin_opens_the_job() -> void:
	var camp := DemoState.make()
	Hud._fonts()
	var s := FixerScreen.new()
	s.setup(camp, null, "city", 0)
	(Engine.get_main_loop() as SceneTree).root.add_child(s)
	if not s.is_inside_tree():
		s._ready()
	var tabs := s.find_children("*", "CityTab", true, false)
	assert_eq(tabs.size(), 1, "the CITY tab holds the map")
	var city: CityTab = tabs[0]
	assert_eq(city.showing(), "", "the overview first")
	city.map.set_hover("district", "watson_development")
	assert_eq(city.showing(), "watson_development")
	var heads := city._panel.find_children("*", "Label", true, false).filter(func(l): return not l.is_queued_for_deletion() and (l as Label).text == "WATSON DEVELOPMENT")
	assert_false(heads.is_empty(), "the panel shows the hovered district")
	assert_true(CityTab.location_counts("watson_development").size() > 0)
	city.map.set_hover("pin", "0")
	assert_eq(city.showing(), "pin:0")
	city.open_job.emit(0)
	assert_eq(s.tab, "jobs", "a pin opens JOBS")
	assert_eq(s.focus_gig, 0, "on that job")
	s.free()
