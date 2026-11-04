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
	assert_true(CityMap.code_colour(2).r > CityMap.code_colour(2).b, "low codes are hot")
	assert_true(CityMap.code_colour(9).b > CityMap.code_colour(9).r, "high codes are cool")
	assert_eq(CityMap.short_faction("eri"), "ERI")
	assert_eq(CityMap.short_faction("ncpd"), "NCPD")


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
