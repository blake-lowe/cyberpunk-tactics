extends TestCase
## The themed scenes (undercity, arcology, warzone) and their look data (SceneTheme, LightPlan).


func test_undercity_is_cut_from_rock() -> void:
	var m := SceneGen.generate(7, "undercity", {"security": 2})
	var void_n := 0
	var water := 0
	var planks := 0
	for y in m.h:
		for x in m.w:
			var t := m.t(0, x, y)
			if t == TacMap.T.VOID:
				void_n += 1
				for d in Nav.DIRS8:   # rock never touches open ground directly: a wall is between
					var n: Vector2i = Vector2i(x, y) + d
					if m.inb(n.x, n.y):
						assert_true(m.t(0, n.x, n.y) in [TacMap.T.VOID, TacMap.T.WALL], "rock at %s touches %d" % [Vector2i(x, y), m.t(0, n.x, n.y)])
			elif t == TacMap.T.WATER:
				water += 1
			elif t == TacMap.T.OUTSIDE and m.ground[y * m.w + x] == TacMap.G.DOCK:
				planks += 1
	assert_true(void_n > m.w * m.h / 4, "mostly solid rock (%d)" % void_n)
	assert_true(water > 60, "runoff channels (%d)" % water)
	assert_true(planks >= 6, "plank crossings (%d)" % planks)


func test_undercity_lamps_hang_on_walls() -> void:
	var m := SceneGen.generate(7, "undercity", {"security": 1})
	var lamps := LightPlan.plan(m, m.seed_value).filter(func(e): return e.kind == "lamp")
	assert_true(lamps.size() >= 4, "work lamps (%d)" % lamps.size())
	for e in lamps:
		var c: Vector3i = e.cell
		var back := Vector2i(c.x, c.y) - (e.out as Vector2i)
		assert_true(e.out != Vector2i.ZERO and m.t(0, back.x, back.y) == TacMap.T.WALL, "lamp at %s is on a wall" % c)


func test_warzone_burns() -> void:
	var m := SceneGen.generate(5, "warzone", {"security": 1})
	var plan := LightPlan.plan(m, m.seed_value)
	var blazes := plan.filter(func(e): return e.kind == "blaze")
	assert_true(blazes.size() >= 6, "fires (%d)" % blazes.size())
	for e in blazes:
		var c: Vector3i = e.cell
		assert_true(m.has_cover_at(0, Vector2i(c.x, c.y)), "a blaze sits on a wreck or rubble")
	var city := SceneGen.generate(5, "neighborhood", {"security": 1, "profile": "burning_zone"})
	assert_true(LightPlan.plan(city, city.seed_value).filter(func(e): return e.kind == "blaze").is_empty(), "untheme'd scenes don't burn")


func test_arcology_has_a_security_line_and_a_pool() -> void:
	var m := SceneGen.generate(3, "arcology", {"security": 2})
	var barriers := m.cover.filter(func(c): return c.kind == "barrier").size()
	assert_true(barriers >= 4, "barriers in front of the offices (%d)" % barriers)
	var pool := 0
	for y in m.h:
		for x in m.w:
			if m.t(0, x, y) == TacMap.T.WATER:
				pool += 1
	assert_true(pool >= 20, "reflecting pool (%d)" % pool)


func test_theme_palettes_and_recolours() -> void:
	for th in SceneTheme.themes():
		var pal := String(SceneTheme.themes()[th].get("palette", ""))
		assert_true(SceneTheme.palettes().has(pal), "%s palette %s exists" % [th, pal])
	for name in SceneTheme.palettes():
		var p: Array = SceneTheme.palettes()[name]
		assert_true(int(p[0]) < (p[1] as Array).size() and (p[1] as Array).size() <= 64, "%s fits the post shader" % name)
		for h in p[1]:
			assert_true(Color.html_is_valid(h), "%s: %s" % [name, h])
	var m := SceneGen.generate(3, "arcology", {"security": 1})
	var e := SceneTheme.lib_entry(m, "cornice", WorldBuilder.LIB["cornice"])
	assert_eq(e[0], Color("c8102e"))
	assert_true(float(e[6].get("glow", 0.0)) > 0.0, "red trims glow")
	assert_eq(WorldBuilder.LIB["cornice"][0], Color("4e5c78"), "the shared LIB is not modified")
