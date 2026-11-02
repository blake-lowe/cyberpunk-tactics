extends Node3D
## M3b playable greybox: a generated scene as a 3D blockout, driven by Encounter.
##
## Controls
##   WASD / arrows   pan          Mouse wheel   zoom          Q / E   rotate 90°
##   PageUp/PageDown change the floor you're viewing (higher floors hide)
##   Left click      move the active crew member (the move grid shows while you plan)
##   Right click     attack the enemy under the cursor (or the cover in the way, with Shift)
##   1 / 2 / 3       single shot / autofire / aimed head shot
##   R reload    J jack in (Netrunner, within 6 m of a terminal)    Space  end turn
##   C toggle cutaway walls    F1 new gig
## Screenshot mode (for tests and reviews):  -- --shot=path.png [--scene=x] [--profile=y] [--seed=n]

const FH := 1.6           # floor height in squares
const LOW_WALL := 0.45    # cutaway height on the viewed floor

var m: TacMap
var enc: Encounter
var dice: Dice
var view_floor := 0
var cutaway := true
var mode := Attack.Mode.SINGLE
var move_opts := {}
var hover := Vector3i(-1, -1, -1)
var world: Node3D
var floor_nodes: Array[Node3D] = []
var unit_nodes := {}      ## unit id → MeshInstance3D
var grid_node: MultiMeshInstance3D
var cam: Camera3D
var cam_target := Vector3.ZERO
var cam_yaw := 45.0
var cam_dist := 40.0
var ui := {}
var gig := {"scene": "street_block", "profile": "", "seed": 11, "security": 2}
var _shot_path := ""
var _frames := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="): _shot_path = a.substr(7)
		elif a.begins_with("--scene="): gig.scene = a.substr(8)
		elif a.begins_with("--profile="): gig.profile = a.substr(10)
		elif a.begins_with("--seed="): gig.seed = int(a.substr(7))
	_build_env()
	_build_ui()
	new_gig()


func _process(delta: float) -> void:
	var pan := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): pan.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): pan.z += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): pan.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): pan.x += 1
	if pan != Vector3.ZERO:
		cam_target += pan.rotated(Vector3.UP, deg_to_rad(-cam_yaw + 45)).normalized() * delta * cam_dist * 0.9
		_place_camera()
	if _shot_path != "":
		_frames += 1
		if _frames == 8:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()


# --- Gig setup -------------------------------------------------------------------

func new_gig() -> void:
	var o := {"security": gig.security}
	if gig.profile != "":
		o["profile"] = gig.profile
	m = SceneGen.generate(gig.seed, "neighborhood" if gig.profile != "" else gig.scene, o)
	dice = Dice.new(gig.seed + 1)
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	enc = Encounter.setup(m, dice, crew)
	_build_world()
	var d: Dictionary = enc.units[0]
	cam_target = Vector3(d.pos.x, 0, d.pos.y)
	_place_camera()
	enc.next_turn()
	_after_action()


# --- World building --------------------------------------------------------------

func _build_env() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("0b0e12")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("8090a0")
	e.ambient_light_energy = 0.7
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 0.9
	add_child(sun)
	cam = Camera3D.new()
	cam.fov = 40
	add_child(cam)


func _mat(c: Color, alpha := 1.0) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color(c, alpha)
	if alpha < 1.0:
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mt


## One MultiMesh per (floor, kind) of boxes. Each entry: [Vector3 pos, Vector3 size].
func _boxes(parent: Node3D, entries: Array, color: Color, alpha := 1.0) -> void:
	if entries.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = _mat(color, alpha)
	mm.mesh = box
	mm.instance_count = entries.size()
	for i in entries.size():
		var e: Array = entries[i]
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(e[1]), e[0]))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	parent.add_child(mi)


const ZONE_COL := [Color("2a2f33"), Color("2b3f50"), Color("2e3a32"), Color("4a3c22"), Color("553034")]
const WALL_COL := [Color("7b858d"), Color("9aa3aa"), Color("b8c8d8"), Color("8a9878"), Color("7a6650")]
const GROUND_COL := [Color("15191c"), Color("2a2f33"), Color("3a4045"), Color("3d3a34"), Color("4a3a2a"), Color("383d42"), Color("332e2a"), Color("4a3a28"), Color("2a3a28"), Color("5a4a34")]


func _build_world() -> void:
	if world:
		world.queue_free()
	world = Node3D.new()
	add_child(world)
	floor_nodes.clear()
	unit_nodes.clear()
	for f in m.floors:
		var fn := Node3D.new()
		world.add_child(fn)
		floor_nodes.append(fn)
		_build_floor(fn, f)
	grid_node = MultiMeshInstance3D.new()
	world.add_child(grid_node)
	for u in enc.units:
		var mi := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.32
		cap.height = 1.3
		cap.material = _mat(Color("5fd38a") if u.team == 0 else Color("e2675f"))
		mi.mesh = cap
		world.add_child(mi)
		unit_nodes[u.id] = mi
	_refresh()


func _build_floor(fn: Node3D, f: int) -> void:
	var floors := {}
	var walls := {}
	var glass := []
	var doors := []
	var y0 := f * FH
	for y in m.h:
		for x in m.w:
			var t := m.t(f, x, y)
			var i := y * m.w + x
			var p := Vector3(x + 0.5, y0, y + 0.5)
			match t:
				TacMap.T.VOID:
					continue
				TacMap.T.WATER:
					floors.get_or_add(Color("10303f"), []).append([p - Vector3(0, 0.1, 0), Vector3(1, 0.05, 1)])
				TacMap.T.OUTSIDE:
					var gc: Color = GROUND_COL[m.ground[i]]
					var l := m.label(f, x, y)
					if l >= 0:
						gc = gc.lerp(ZONE_COL[clampi(m.rooms[l].zone, 0, 4)], 0.5)
					floors.get_or_add(gc, []).append([p - Vector3(0, 0.05, 0), Vector3(1, 0.1, 1)])
				TacMap.T.WALL:
					var mat := int(m.wall_mat[f][i])
					if mat in [5, 6]:
						glass.append(p)
					else:
						walls.get_or_add(mat, []).append(p)
				TacMap.T.DOOR:
					doors.append(p)
					floors.get_or_add(Color("222"), []).append([p - Vector3(0, 0.05, 0), Vector3(1, 0.1, 1)])
				_:
					var l2 := m.label(f, x, y)
					var c: Color = ZONE_COL[clampi(m.rooms[l2].zone, 0, 4)] if l2 >= 0 else Color("3a4148")
					if t == TacMap.T.ROOF: c = Color("3e464e")
					elif t == TacMap.T.BRIDGE: c = Color("59636c")
					elif t in [TacMap.T.STAIRS, TacMap.T.ELEVATOR]: c = Color("c6ced4")
					floors.get_or_add(c, []).append([p - Vector3(0, 0.05, 0), Vector3(1, 0.1, 1)])
	for c in floors:
		_boxes(fn, floors[c], c)
	var full := Node3D.new()
	full.name = "full"
	var low := Node3D.new()
	low.name = "low"
	fn.add_child(full)
	fn.add_child(low)
	for mat in walls:
		_boxes(full, walls[mat].map(func(p): return [p + Vector3(0, FH / 2, 0), Vector3(1, FH, 1)]), WALL_COL[mat])
		_boxes(low, walls[mat].map(func(p): return [p + Vector3(0, LOW_WALL / 2, 0), Vector3(1, LOW_WALL, 1)]), WALL_COL[mat])
	_boxes(full, glass.map(func(p): return [p + Vector3(0, FH / 2, 0), Vector3(1, FH, 0.98)]), Color("9fd3e8"), 0.35)
	_boxes(low, glass.map(func(p): return [p + Vector3(0, LOW_WALL / 2, 0), Vector3(1, LOW_WALL, 0.98)]), Color("9fd3e8"), 0.35)
	_boxes(fn, doors.map(func(p): return [p + Vector3(0, 0.6, 0), Vector3(0.5, 1.2, 0.5)]), Color("c49a4a"))
	var cov := {}
	for c in m.cover:
		if c.floor != f:
			continue
		var h := 0.9 if c.thick else 0.6
		var col: Color = Color("e1d3a6") if c.hp >= 40 else Color("b49b6c") if c.hp >= 20 else Color("8a7552") if c.hp >= 10 else Color("5f513b")
		if c.get("hazard", "") != "": col = Color("f08b4b")
		cov.get_or_add(col, []).append([Vector3(c.pos.x + 0.5, y0 + h / 2, c.pos.y + 0.5), Vector3(0.86, h, 0.86)])
	for col in cov:
		_boxes(fn, cov[col], col)


# --- Refresh: floors shown, units, grid, HUD -------------------------------------

func _refresh() -> void:
	for f in floor_nodes.size():
		var fn := floor_nodes[f]
		fn.visible = f <= view_floor
		fn.get_node("full").visible = not (cutaway and f == view_floor)
		fn.get_node("low").visible = cutaway and f == view_floor
	for u in enc.units:
		var mi: MeshInstance3D = unit_nodes[u.id]
		mi.visible = not u.c.dead and u.pos.z <= view_floor
		mi.position = Vector3(u.pos.x + 0.5, u.pos.z * FH + 0.65, u.pos.y + 0.5)
		mi.scale = Vector3.ONE * (1.25 if u == enc.cur else 1.0)
	_draw_grid()
	_update_hud()


func _draw_grid() -> void:
	move_opts = {}
	if enc.state == "playing" and not enc.cur.is_empty() and enc.cur.team == 0 and enc.turn.can_move():
		move_opts = enc.move_options()
	var entries := []
	for v in move_opts:
		if v.z == view_floor:
			entries.append(Transform3D(Basis.from_scale(Vector3(0.9, 0.02, 0.9)), Vector3(v.x + 0.5, v.z * FH + 0.06, v.y + 0.5)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.material = _mat(Color("8fc79a"), 0.35)
	mm.mesh = box
	mm.instance_count = entries.size()
	for i in entries.size():
		mm.set_instance_transform(i, entries[i])
	grid_node.multimesh = mm


func _place_camera() -> void:
	var off := Vector3(0, cam_dist * 0.8, cam_dist * 0.6).rotated(Vector3.UP, deg_to_rad(cam_yaw))
	cam.position = cam_target + Vector3(0, view_floor * FH, 0) + off
	cam.look_at(cam_target + Vector3(0, view_floor * FH, 0))


# --- Input ------------------------------------------------------------------------

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		hover = _pick(ev.position)
		_update_hover()
	elif ev is InputEventMouseButton and ev.pressed:
		match ev.button_index:
			MOUSE_BUTTON_WHEEL_UP: cam_dist = maxf(8, cam_dist * 0.9); _place_camera()
			MOUSE_BUTTON_WHEEL_DOWN: cam_dist = minf(160, cam_dist * 1.1); _place_camera()
			MOUSE_BUTTON_LEFT: _click_move()
			MOUSE_BUTTON_RIGHT: _click_attack(ev.shift_pressed)
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		match ev.keycode:
			KEY_Q: cam_yaw -= 90; _place_camera()
			KEY_E: cam_yaw += 90; _place_camera()
			KEY_PAGEUP: view_floor = mini(view_floor + 1, m.floors - 1); _place_camera(); _refresh()
			KEY_PAGEDOWN: view_floor = maxi(view_floor - 1, 0); _place_camera(); _refresh()
			KEY_C: cutaway = not cutaway; _refresh()
			KEY_1: mode = Attack.Mode.SINGLE; _update_hover()
			KEY_2: mode = Attack.Mode.AUTOFIRE; _update_hover()
			KEY_3: mode = Attack.Mode.AIMED_HEAD; _update_hover()
			KEY_R: _reload()
			KEY_J: _jack_in()
			KEY_SPACE: _end_turn()
			KEY_F1: gig.seed += 1; new_gig()


func _pick(screen: Vector2) -> Vector3i:
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	var hit: Variant = Plane(Vector3.UP, view_floor * FH).intersects_ray(o, d)
	if hit == null:
		return Vector3i(-1, -1, -1)
	return Vector3i(floori(hit.x), floori(hit.z), view_floor)


func _crew_turn() -> bool:
	return enc.state == "playing" and not enc.cur.is_empty() and enc.cur.team == 0


func _click_move() -> void:
	if _crew_turn() and move_opts.has(hover) and enc.move_to(hover):
		_after_action()


func _unit_at(v: Vector3i) -> Dictionary:
	for u in enc.units:
		if u.pos == v and not u.c.dead:
			return u
	return {}


func _click_attack(at_cover: bool) -> void:
	if not _crew_turn() or enc.cur.c.weapons.is_empty():
		return
	var w: Weapon = enc.cur.c.weapons[0]
	var t := _unit_at(hover)
	if at_cover or t.is_empty():
		var tgt := t if not t.is_empty() else {}
		if not tgt.is_empty():
			var p := enc.preview(tgt, w, mode)
			if p.blocker.x >= 0:
				enc.shoot_cover(p.blocker, w)
		elif enc.los.blocker(hover) != "":
			enc.shoot_cover(hover, w)
		_after_action()
		return
	if t.team == 0:
		return
	var before_hp: int = t.c.hp
	var r := enc.attack(t, w, mode)
	if r.get("ok", true) == false:
		_toast(r.reason)
	elif r.get("dodged", false):
		_float(t, "DODGE", Color("63c7d6"))
	elif r.get("hit", false):
		_float(t, "-%d" % (before_hp - t.c.hp), Color("e2675f"))
	else:
		_float(t, "MISS", Color("8d98a1"))
	_after_action()


func _reload() -> void:
	if _crew_turn() and not enc.cur.c.weapons.is_empty() and enc.turn.use_action():
		enc.cur.c.weapons[0].reload()
		enc.say("%s reloads." % enc.cur.c.display_name)
		_after_action()


func _jack_in() -> void:
	if not _crew_turn():
		return
	var pts := enc.jack_points(enc.cur)
	if pts.is_empty():
		_toast("No terminal within 6 m.")
	elif enc.jack_in(pts[0]):
		enc.net_left = NetRun.net_actions(NetRun.interface_rank(enc.cur.c)) - 1
	_after_action()


func _end_turn() -> void:
	if not _crew_turn():
		return
	var hp_before := {}
	for u in enc.units:
		hp_before[u.id] = u.c.hp
	enc.end_turn()
	enc.next_turn()
	for u in enc.units:
		if u.c.hp < hp_before[u.id]:
			_float(u, "-%d" % (hp_before[u.id] - u.c.hp), Color("e2675f"))
	_after_action()


func _after_action() -> void:
	if not enc.cur.is_empty():
		view_floor = maxi(view_floor, 0)
	_refresh()
	_update_hover()


func _float(u: Dictionary, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.modulate = col
	l.font_size = 64
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(u.pos.x + 0.5, u.pos.z * FH + 1.8, u.pos.y + 0.5)
	world.add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y + 1.2, 1.2)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.2)
	tw.tween_callback(l.queue_free)


# --- HUD --------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	ui.order = _label(root, Vector2(12, 8), 16)
	ui.unit = _label(root, Vector2(12, 560), 15)
	ui.hover = _label(root, Vector2(12, 40), 18)
	ui.log = _label(root, Vector2(980, 520), 13)
	ui.net = _label(root, Vector2(980, 40), 14)
	ui.toast = _label(root, Vector2(560, 70), 18)


func _label(root: Control, pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	root.add_child(l)
	return l


func _toast(text: String) -> void:
	ui.toast.text = text
	get_tree().create_timer(2.0).timeout.connect(func(): if ui.toast.text == text: ui.toast.text = "")


func _update_hud() -> void:
	var names := []
	for c in enc.init.order():
		if not c.dead:
			names.append(("▶ " if not enc.cur.is_empty() and enc.cur.c == c else "") + c.display_name)
	ui.order.text = "  ".join(names) + "     [%s]  floor %d" % [enc.state.to_upper(), view_floor + 1]
	if enc.cur.is_empty():
		return
	var c: Combatant = enc.cur.c
	var w: Weapon = c.weapons[0] if not c.weapons.is_empty() else null
	ui.unit.text = "%s (%s)  HP %d/%d  %s\nSP head %d  body %d   %s %s\nMove %d  Action %s   Mode: %s" % [
		c.display_name, c.role, c.hp, c.max_hp(), ["Unhurt", "Lightly wounded", "Seriously wounded", "Mortally wounded", "Dead"][c.wound_state()],
		c.sp("head"), c.sp("body"), w.def.name if w else "-", ("%d/%d" % [w.ammo, int(w.def.get("mag", 0))]) if w and w.uses_ammo() else "",
		enc.turn.squares_available(), "ready" if enc.turn.action_available or enc.turn.attacks_left > 0 else "used",
		["Single", "Autofire", "Aimed head", "Aimed leg", "Aimed held"][mode]]
	ui.log.text = "\n".join(enc.log.slice(maxi(0, enc.log.size() - 8)))
	var run: NetRun = enc.runs.get(enc.cur.id)
	ui.net.text = "" if run == null else _net_text(run)


func _net_text(run: NetRun) -> String:
	var n := run.cur_node()
	var lines := ["NET — %s  (%d NET Actions left)" % [nodelabel(n), enc.net_left]]
	for i in run.arch.ice_at(run.current):
		lines.append("  Black ICE here: %s" % i.kind)
	lines.append("Reachable:")
	var k := 0
	for id in run.movable():
		if id != run.current and k < 8:
			lines.append("  %d  %s" % [id, nodelabel(run.arch.nodes[id])])
			k += 1
	return "\n".join(lines)


func nodelabel(n: Dictionary) -> String:
	match n.type:
		"firewall": return "Firewall DV%d (L%d)" % [n.dv, n.zone]
		"file": return "File DV%d" % n.dv
		"control": return "Control: %s" % String(n.group).replace("_", " ")
		"socket": return "Socket → structure %d" % n.target_structure
	return "%s (L%d)" % [n.type.capitalize(), n.zone]


func _update_hover() -> void:
	if not _crew_turn():
		ui.hover.text = ""
		return
	var t := _unit_at(hover)
	if t.is_empty() or t.team == 0 or enc.cur.c.weapons.is_empty():
		ui.hover.text = "Move: %d squares" % enc.cur.c.stat("MOVE") if move_opts.has(hover) else ""
		return
	var p := enc.preview(t, enc.cur.c.weapons[0], mode)
	ui.hover.text = "%s — %s" % [t.c.display_name, ("%d%% to hit" % roundi(p.chance * 100)) if p.ok else p.reason]
