extends SceneTree
## Specimen sheet for item name typography (QualityText): every exotic weapon in its display face,
## then Poor / Standard / Excellent versions of a few weapons as the HUD (caps), the safehouse lists
## (mixed case), the attack wheel (drawn) and the stat-block tooltip (BBCode) show them. One PNG per
## sheen phase (the Excellent sweep pinned at each time).
## timeout 180 xvfb-run -a -s "-screen 0 1400x1060x24" godot --rendering-method gl_compatibility \
##   --resolution 1400x1060 --path . -s tools/quality_specimen.gd -- --out=/some/dir [--times=0.2,0.45,0.7]
## --compare-poor instead writes specimen_poor_lower.png: Poor names alternating vs all lowercase.

const WEAPONS := ["heavy_pistol", "assault_rifle", "shotgun", "smg", "light_melee", "sniper_rifle"]

var out := "."
var times: Array = [0.2, 0.45, 0.7]
var _mats: Array[ShaderMaterial] = []
var compare_poor := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--times="):
			times = Array(a.substr(8).split(",")).map(func(x): return float(x))
		elif a == "--compare-poor":
			compare_poor = true
	_run.call_deferred()


func _lbl(s: String, f: Font, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 2)
	return l


func _styled(key: String, base: String, f: Font, size: int, col := Hud.TEXT) -> Label:
	var l := QualityText.apply(_lbl(base, f, size, col), key)
	if l.material is ShaderMaterial:
		_mats.append(l.material)
	return l


func _run() -> void:
	Hud._fonts()
	QualityText.time_override = float(times[0])
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.028, 0.04)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 18)
	bg.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)
	if compare_poor:
		await _poor_sheet(v)
		quit()
		return
	v.add_child(_lbl("EXOTIC WEAPONS  ·  HUD 20 px caps  ·  list 15 px  ·  face (data/gen/exotic_fonts.json)", Hud.F_BOLD, 14, Hud.CYAN))
	var ex := GridContainer.new()
	ex.columns = 3
	ex.add_theme_constant_override("h_separation", 28)
	ex.add_theme_constant_override("v_separation", 2)
	v.add_child(ex)
	for id in RulesDB.load_json("weapons.json").weapons:
		if not QualityText.is_exotic(String(id)):
			continue
		var nm := String(RulesDB.weapon(String(id)).name)
		ex.add_child(_styled("weapon/" + id, nm.to_upper(), Hud.F_TERM, 20))
		ex.add_child(_styled("weapon/" + id, nm.to_upper(), Hud.F_BOLD, 15))
		ex.add_child(_lbl(QualityText.font_key(String(id)), Hud.F_BODY, 13, Hud.DIM))
	v.add_child(HSeparator.new())
	v.add_child(_lbl("QUALITY  ·  POOR / STANDARD / EXCELLENT  ·  HUD 20 px caps, then the list's 15 px mixed case", Hud.F_BOLD, 14, Hud.CYAN))
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 28)
	g.add_theme_constant_override("v_separation", 2)
	v.add_child(g)
	for id in WEAPONS:
		for q in ["poor", "standard", "excellent"]:
			var w := Weapon.from_id(id, q)
			g.add_child(_styled(Items.key_of_weapon(w), w.display_name().to_upper(), Hud.F_TERM, 20))
		for q in ["poor", "standard", "excellent"]:
			var w := Weapon.from_id(id, q)
			g.add_child(_styled(Items.key_of_weapon(w), w.display_name(), Hud.F_BODY, 15, Color(Hud.TEXT, 0.9)))
	v.add_child(HSeparator.new())
	v.add_child(_lbl("ATTACK WHEEL (drawn)  ·  STAT BLOCK (BBCode)", Hud.F_BOLD, 14, Hud.CYAN))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	for k in ["heavy_pistol@poor", "heavy_pistol", "assault_rifle@excellent", "malorian_arms_3516", "microwaver", "stun_baton", "flamethrower"]:
		var w := Items.make_weapon("weapon/" + k)
		var b := Hud.ActBtn.new("melee" if w.is_melee() else "shot", w.display_name().to_upper(), "TAB 1/3", Hud.GOLD, 150, 66)
		b.set_quality(QualityText.weapon_style(w, w.display_name().to_upper()))
		b.toggle_mode = true
		b.set_pressed_no_signal(true)
		row.add_child(b)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(900, 0)
	rt.add_theme_font_override("normal_font", Hud.F_BODY)
	rt.add_theme_font_size_override("normal_font_size", 18)
	rt.install_effect(QualityText.SheenFx.new())
	var lines: Array[String] = []
	for k in ["heavy_pistol@poor", "assault_rifle@excellent", "malorian_arms_3516", "shotgun"]:
		var w := Items.make_weapon("weapon/" + k)
		lines.append("[color=#7d8a96]WEAPON[/color] %s · %dd6 · ROF %d" % [QualityText.bbcode(Items.key_of_weapon(w), String(w.def.name), 18), w.dice(), w.rof()])
	rt.text = "\n".join(lines)
	v.add_child(rt)
	DirAccess.make_dir_recursive_absolute(out)
	for i in times.size():
		QualityText.time_override = float(times[i])
		for mat in _mats:
			mat.set_shader_parameter("time_override", float(times[i]))
		for b in row.get_children():
			b.queue_redraw()
		for _f in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		var p := out.path_join("specimen_t%d.png" % i)
		img.save_png(p)
		print("wrote ", p)
	quit()


## Poor names both ways, side by side: HUD 20 px caps and list 15 px mixed case.
func _poor_sheet(v: VBoxContainer) -> void:
	v.add_child(_lbl("POOR QUALITY  ·  ALTERNATING CASE  vs  ALL LOWERCASE  ·  HUD 20 px, list 15 px", Hud.F_BOLD, 14, Hud.CYAN))
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 36)
	g.add_theme_constant_override("v_separation", 4)
	v.add_child(g)
	for h in ["ALTERNATING · HUD", "ALTERNATING · LIST", "LOWERCASE · HUD", "LOWERCASE · LIST"]:
		g.add_child(_lbl(h, Hud.F_BOLD, 12, Hud.DIM))
	for id in WEAPONS + ["very_heavy_pistol", "heavy_smg", "medium_melee", "grenade_launcher"]:
		if not Weapon.can_have_quality(String(id), "poor"):
			continue
		var w := Weapon.from_id(String(id), "poor")
		for mode in ["alternating", "lower"]:
			QualityText.poor_case_override = mode
			g.add_child(_styled(Items.key_of_weapon(w), w.display_name().to_upper(), Hud.F_TERM, 20))
			g.add_child(_styled(Items.key_of_weapon(w), w.display_name(), Hud.F_BODY, 15, Color(Hud.TEXT, 0.9)))
	QualityText.poor_case_override = ""
	# the grid fills row by row: alternating HUD, alternating list, lower HUD, lower list
	DirAccess.make_dir_recursive_absolute(out)
	for _f in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var p := out.path_join("specimen_poor_lower.png")
	root.get_texture().get_image().save_png(p)
	print("wrote ", p)
