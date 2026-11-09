extends SceneTree
## Review contact sheets of street props outside a map, in the world's own materials (WorldBuilder
## on a small flat TacMap), night look, the game's camera angle:
## - cars: every make (data/gen/cars.json) in a row, a wreck, paints by band, a person for scale
## - signs: the sign library (SignLib, data/gen/signs.json) on a dark wall
## timeout 200 xvfb-run -a -s "-screen 0 1600x900x24" godot --rendering-method gl_compatibility \
##   --resolution 1600x900 --path . -s tools/prop_sheet.gd -- --sheet=cars|signs --out=/some/dir [--view=iso|side]

var out := "."
var sheet := "cars"
var view := "iso"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--sheet="):
			sheet = a.substr(8)
		elif a.begins_with("--view="):
			view = a.substr(7)
	_run.call_deferred()


func _flat_map(w: int, h: int) -> TacMap:
	var m := TacMap.new(w, h, 2)
	m.seed_value = 7
	m.params = {"scene": "neighborhood"}
	for y in h:
		for x in w:
			m.set_t(0, x, y, TacMap.T.OUTSIDE)
			m.set_ground(x, y, TacMap.G.SIDEWALK if y < 3 else TacMap.G.ASPHALT)
	return m


func _run() -> void:
	var w := Node3D.new()
	root.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("07080c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("3a4466")
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in 7:
		env.set_glow_level(i, 1.0 if i in [1, 2, 3] else 0.0)
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_color = Color("8fa0e0")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	w.add_child(sun)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 200, 0)
	key.light_color = Color("ff9ad0")
	key.light_energy = 0.25
	w.add_child(key)
	var m: TacMap
	var target := Vector3.ZERO
	var dist := 16.0
	if sheet == "cars":
		var ids := CarProp.makes().keys()
		m = _flat_map(ids.size() * 3 + 8, 12)
		var bands := ["corporate", "moderate", "combat_zone"]
		for row in 3:   # one row a band: the same makes, each band's paint
			for i in ids.size() + 1:
				var kind := "car" if i < ids.size() else "wreck"
				var at := m.cover.size()
				Furnish.try_prop(m, 0, Rect2i(2 + i * 3, 3 + row * 3, 2, 1) if i < ids.size() else Rect2i(2 + i * 3, 3 + row * 3, 2, 2), kind, -1)
				for k in range(at, m.cover.size()):
					m.cover[k]["make"] = String(ids[i % ids.size()])
					m.cover[k]["band"] = bands[row]
		target = Vector3(m.w / 2.0, 0, 6.5)
		dist = 30.0
	else:
		_sign_sheet(w)
		var cam2 := Camera3D.new()
		cam2.projection = Camera3D.PROJECTION_ORTHOGONAL
		w.add_child(cam2)
		cam2.position = Vector3(15.0, 7.0, 40.0)
		cam2.look_at(Vector3(15.0, 6.0, 0.0))
		cam2.size = 17.6
		cam2.far = 200.0
		for f in 30:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/signs.png" % out)
		quit()
		return
	var los := Los.new(m)
	var fog := Image.create(m.w, m.h * m.floors, false, Image.FORMAT_RG8)
	fog.fill(Color(1, 1, 0))
	var wb := WorldBuilder.new(m, Vision.new(m, los), ImageTexture.create_from_image(fog))
	var nodes := wb.build(w)
	for mt in wb.materials():
		mt.set_shader_parameter("spill", 0.0)
	if sheet == "cars":   # people for scale (drawn 1.3x life, as in the game)
		for p in [Vector3(1.0, 0, 3.5), Vector3(1.0, 0, 9.5)]:
			var n := CharModel.build(0, 3, "solo", "heavy_pistol", "")
			w.add_child(n)
			n.position = p
			n.scale = Vector3.ONE * 1.3
			n.rotation.y = PI / 2
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	w.add_child(cam)
	var yaw := deg_to_rad(35.0 if view == "iso" else 0.0)
	var pitch := deg_to_rad(40.0 if view == "iso" else 8.0)
	cam.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 60.0
	cam.look_at(target)
	cam.size = dist * 0.62
	cam.far = 200.0
	for f in 12:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, sheet, view])
	quit()


## The whole library on a dark wall, night: neon by form, then the holo ads, nine to a row.
func _sign_sheet(w: Node3D) -> void:
	var wall := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(31, 17, 0.4)
	wall.mesh = bm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color("1a1c22")
	wm.roughness = 0.9
	wall.material_override = wm
	wall.position = Vector3(15, 6.3, -0.2)
	w.add_child(wall)
	var b := SignBatch.new(1, 0.012)
	var order := SignLib.entries().filter(func(e): return e.kind == "neon" and e.form != "blade") + SignLib.entries().filter(func(e): return e.form == "blade") \
		+ SignLib.entries().filter(func(e): return e.kind == "holo")
	var cols := 9
	var i := 0
	var row_forms := ""
	var cy := 14.3
	for e in order:
		var kind := "blade" if e.form == "blade" else String(e.kind)
		if kind != row_forms:   # each kind starts a row; blades stand ten to a row, two rows high
			if i % cols != 0:
				i += cols - i % cols
			cols = 10 if kind == "blade" else 9
			i = 0
			cy -= 1.5 if row_forms == "blade" else 0.0
		if i % cols == 0:
			cy -= 2.6 if kind == "blade" else 1.5
		row_forms = kind
		var cx := 1.8 + (i % cols) * (3.3 if kind != "blade" else 2.97)
		match kind:
			"blade":
				b.blade(e, Vector3(cx - 0.7, cy - 0.5, 0.0), Vector3(0, 0, 1).rotated(Vector3.UP, -0.85), 0.8, 2.3, i * 7 + 3)
			"holo":
				b.wall(e, Vector3(cx, cy, 0.0), Vector3(0, 0, 1), 2.6, 1.3, i * 7 + 3)
			_:
				b.wall(e, Vector3(cx, cy, 0.0), Vector3(0, 0, 1), 2.7, 0.95 if e.form in ["word", "cjk"] else 1.25, i * 7 + 3)
		i += 1
	b.flush(w, Vector2(1000, 1000))
