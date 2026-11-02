class_name Hud
extends Control
## Tactical HUD. Layout after Baldur's Gate 3 (M3 playtest): party down the left, the turn order
## across the top, a hotbar at the bottom (character card, action economy, actions, End Turn), a
## cursor tooltip, the combat log bottom right, the NET panel on the right while jacked in.
## Skin (M4a review: stylised, no rounded corners, no generic fonts): chamfered square panels
## (CutBox) with scanlines, and two pixel faces that share the world's pixel language: Jersey 10
## for names and labels, VT323 for numbers, body text and the log. Procedural pixel portraits.
## Colour meanings are fixed: gold = active/selected, cyan = friendly/info, red = enemy/danger,
## green = health only, magenta/violet = the NET.
## Emits `action(name, arg)`; the greybox owns the rules calls.

signal action(name: String, arg: Variant)

const INK := Color(0.02, 0.028, 0.04, 0.93)
const CYAN := Color("05d9e8")
const MAGENTA := Color("ff2a6d")
const GOLD := Color("f9c80e")
const RED := Color("ff3b4f")
const GREEN := Color("39f0a0")
const VIOLET := Color("b537f2")
const DIM := Color("6f7d8a")
const TEXT := Color("e8eef2")

static var F_DISPLAY: FontFile
static var F_BODY: FontFile
static var F_PIXEL: FontVariation
static var F_TERM: FontFile

var portraits: Portraits
var _party: VBoxContainer
var _init_strip: HBoxContainer
var _bar: PanelContainer
var _card: VBoxContainer
var _econ: HBoxContainer
var _buttons: HBoxContainer
var _end_btn: Button
var _log: Label
var _log_panel: PanelContainer
var _net_panel: PanelContainer
var _net_box: VBoxContainer
var _tip: PanelContainer
var _tip_head: Label
var _tip_label: RichTextLabel
var _toast: Label
var _banner: Label
var _banner_panel: PanelContainer
var settings: PanelContainer
var _mode_buttons := {}


static func _fonts() -> void:
	if F_BODY:
		return
	F_DISPLAY = FontFile.new()
	F_DISPLAY.load_dynamic_font("res://assets/fonts/Jersey10-Regular.ttf")
	F_DISPLAY.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	F_PIXEL = FontVariation.new()
	F_PIXEL.base_font = F_DISPLAY
	F_PIXEL.spacing_glyph = 1
	F_TERM = FontFile.new()
	F_TERM.load_dynamic_font("res://assets/fonts/VT323-Regular.ttf")
	F_TERM.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	F_BODY = F_TERM


func _ready() -> void:
	_fonts()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = F_BODY
	th.default_font_size = 19
	theme = th
	portraits = Portraits.new()
	add_child(portraits)
	_party = VBoxContainer.new()
	_party.add_theme_constant_override("separation", 6)
	add_child(_party)
	_init_strip = HBoxContainer.new()
	_init_strip.add_theme_constant_override("separation", -6)
	add_child(_init_strip)
	_build_bar()
	_log_panel = _panel(CYAN, 0b0100)
	var lv := VBoxContainer.new()
	_log_panel.add_child(lv)
	lv.add_child(_text("// COMBAT LOG", F_PIXEL, 18, DIM))
	_log = _text("", F_TERM, 19, Color("9fb4c4"))
	_log.custom_minimum_size = Vector2(340, 0)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(_log)
	add_child(_log_panel)
	_net_panel = _panel(VIOLET, 0b0101)
	_net_box = VBoxContainer.new()
	_net_box.add_theme_constant_override("separation", 3)
	_net_panel.add_child(_net_box)
	_net_panel.visible = false
	add_child(_net_panel)
	_tip = PanelContainer.new()
	_tip.add_theme_stylebox_override("panel", CutBox.make(INK, Color(CYAN, 0.7), 8, 0b0101, CYAN, 8))
	var tv := VBoxContainer.new()
	_tip.add_child(tv)
	_tip_head = _text("", F_PIXEL, 18, CYAN)
	tv.add_child(_tip_head)
	_tip_label = RichTextLabel.new()
	_tip_label.bbcode_enabled = true
	_tip_label.fit_content = true
	_tip_label.scroll_active = false
	_tip_label.custom_minimum_size = Vector2(240, 0)
	_tip_label.add_theme_font_override("normal_font", F_BODY)
	_tip_label.add_theme_font_override("bold_font", F_DISPLAY)
	_tip_label.add_theme_font_override("mono_font", F_TERM)
	_tip_label.add_theme_font_size_override("normal_font_size", 19)
	_tip_label.add_theme_font_size_override("bold_font_size", 26)
	_tip_label.add_theme_font_size_override("mono_font_size", 22)
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(_tip_label)
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	add_child(_tip)
	_toast = _text("", F_DISPLAY, 44, GOLD)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_shadow_color", Color(MAGENTA, 0.8))
	_toast.add_theme_constant_override("shadow_offset_x", 3)
	_toast.add_theme_constant_override("shadow_offset_y", 0)
	add_child(_toast)
	_banner = _text("", F_DISPLAY, 18, Color("9fb4c4"))
	_banner_panel = _panel(CYAN, 0b0100)
	_banner_panel.add_child(_banner)
	add_child(_banner_panel)
	resized.connect(_layout)
	_layout()


# --- Building blocks ---------------------------------------------------------------

func _panel(edge := CYAN, corners := 0b0101, accent := Color(0, 0, 0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", CutBox.make(INK, Color(edge, 0.55), 12, corners, accent))
	return p


func _text(s: String, font: Font, size: int, col := TEXT) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 2 if font != F_PIXEL else 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Segmented, slanted meter (HP, MOVE).
class Meter extends Control:
	var frac := 1.0
	var segs := 10
	var col := Color.WHITE
	var label := ""
	func _init(p_frac: float, p_segs: int, p_col: Color, w: float, h: float, p_label := "") -> void:
		frac = p_frac
		segs = maxi(1, p_segs)
		col = p_col
		label = p_label
		custom_minimum_size = Vector2(w, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w := size.x
		var h := size.y
		var gap := 2.0
		var sw := (w - gap * (segs - 1) - h * 0.4) / segs
		var lit := frac * segs
		for i in segs:
			var x := i * (sw + gap)
			var poly := PackedVector2Array([Vector2(x + h * 0.4, 0), Vector2(x + sw + h * 0.4, 0), Vector2(x + sw, h), Vector2(x, h)])
			var a := clampf(lit - i, 0.0, 1.0)
			draw_colored_polygon(poly, Color(col, 0.16))
			if a > 0:
				draw_colored_polygon(poly, Color(col, 0.35 + 0.65 * a))
		pass


## A slanted turn-order slot with the unit's rendered bust.
class Slot extends Control:
	var tex: Texture2D
	var team_col := Color.WHITE
	var active := false
	var hp := 1.0
	var tag := ""
	var dead := false
	func _init(p_tex: Texture2D, p_col: Color, p_active: bool, p_hp: float, p_tag: String, p_dead: bool) -> void:
		tex = p_tex
		team_col = p_col
		active = p_active
		hp = p_hp
		tag = p_tag
		dead = p_dead
		custom_minimum_size = Vector2(76, 76) if active else Vector2(56, 56)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w := size.x
		var h := size.y - 12
		var sk := 12.0
		var poly := PackedVector2Array([Vector2(sk, 0), Vector2(w, 0), Vector2(w - sk, h), Vector2(0, h)])
		draw_colored_polygon(poly, Color(0.03, 0.04, 0.06, 0.95))
		if tex:
			var uvs := PackedVector2Array()
			for p in poly:
				uvs.append(Vector2(0.05 + 0.9 * p.x / w, 0.0 + 1.0 * p.y / h))
			draw_colored_polygon(poly, Color(1, 1, 1, 0.35 if dead else 1.0), uvs, tex)
		draw_colored_polygon(PackedVector2Array([Vector2(sk, 0), Vector2(sk + 18, 0), Vector2(sk + 14, 4), Vector2(sk - 1, 4)]), team_col)
		var loop := poly.duplicate()
		loop.append(poly[0])
		draw_polyline(loop, Hud.GOLD if active else Color(team_col, 0.6), 2.0 if active else 1.0)
		var bw := (w - sk) * clampf(hp, 0, 1)
		draw_rect(Rect2(0, h + 3, w - sk, 4), Color(team_col, 0.18))
		draw_rect(Rect2(0, h + 3, bw, 4), Hud.GREEN if hp > 0.6 else (Hud.GOLD if hp > 0.3 else Hud.RED))
		pass


## Hotbar action: chamfered square with a drawn glyph, a pixel-font name and its key.
class ActBtn extends Button:
	var glyph := ""
	var title := ""
	var key := ""
	var tint := Color.WHITE
	func _init(p_glyph: String, p_title: String, p_key: String, p_tint: Color, w := 66.0, h := 66.0) -> void:
		glyph = p_glyph
		title = p_title
		key = p_key
		tint = p_tint
		custom_minimum_size = Vector2(w, h)
		focus_mode = Control.FOCUS_NONE
		add_theme_stylebox_override("normal", CutBox.make(Color(0.03, 0.045, 0.06, 0.95), Color(tint, 0.45), 9, 0b0101))
		add_theme_stylebox_override("hover", CutBox.make(Color(tint.r * 0.15, tint.g * 0.15, tint.b * 0.15, 0.97), tint, 9, 0b0101))
		add_theme_stylebox_override("pressed", CutBox.make(Color(0.14, 0.11, 0.02, 0.97), Hud.GOLD, 9, 0b0101, Hud.GOLD))
		add_theme_stylebox_override("hover_pressed", CutBox.make(Color(0.14, 0.11, 0.02, 0.97), Hud.GOLD, 9, 0b0101, Hud.GOLD))
		add_theme_stylebox_override("disabled", CutBox.make(Color(0.02, 0.025, 0.03, 0.8), Color(Hud.DIM, 0.2), 9, 0b0101))
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	func _draw() -> void:
		var c := Color(Hud.GOLD if button_pressed else tint, 0.55 if disabled else 1.0)
		if disabled:
			c = Color(Hud.DIM, 0.8)
		var w := size.x
		var o := Vector2(w / 2, size.y * 0.4)
		var r := minf(w, size.y) * 0.17
		match glyph:
			"shot":
				draw_arc(o, r, 0, TAU, 20, c, 2.0)
				for d in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
					draw_line(o + d * r * 0.5, o + d * r * 1.5, c, 2.0)
			"auto":
				for i in 3:
					var x := o.x - r + i * r
					draw_colored_polygon(PackedVector2Array([Vector2(x - 3, o.y + r), Vector2(x + 3, o.y + r), Vector2(x + 3, o.y - r * 0.4), Vector2(x, o.y - r), Vector2(x - 3, o.y - r * 0.4)]), c)
			"head":
				draw_arc(o + Vector2(0, -r * 0.3), r * 0.6, 0, TAU, 16, c, 2.0)
				draw_line(o + Vector2(-r, r), o + Vector2(r, r), c, 2.0)
				draw_line(o + Vector2(-r * 1.4, -r * 0.3), o + Vector2(r * 1.4, -r * 0.3), Color(Hud.RED, c.a), 1.0)
			"cover":
				var sh := PackedVector2Array([o + Vector2(-r, -r), o + Vector2(r, -r), o + Vector2(r, r * 0.3), o + Vector2(0, r * 1.2), o + Vector2(-r, r * 0.3)])
				draw_colored_polygon(sh, Color(c, 0.25))
				sh.append(sh[0])
				draw_polyline(sh, c, 2.0)
				draw_line(o + Vector2(-r * 0.6, r * 0.6), o + Vector2(r * 0.6, -r * 0.6), Color(Hud.RED, c.a), 2.0)
			"reload":
				draw_arc(o, r, 0.3, TAU - 0.6, 18, c, 2.0)
				var tip := o + Vector2(r * 0.95, r * 0.3)
				draw_colored_polygon(PackedVector2Array([tip + Vector2(4, 0), tip + Vector2(-4, 0), tip + Vector2(0, 6)]), c)
			"jack":
				draw_rect(Rect2(o + Vector2(-r * 0.6, -r), Vector2(r * 1.2, r * 1.2)), c, false, 2.0)
				draw_line(o + Vector2(-r * 0.25, -r * 1.5), o + Vector2(-r * 0.25, -r), c, 2.0)
				draw_line(o + Vector2(r * 0.25, -r * 1.5), o + Vector2(r * 0.25, -r), c, 2.0)
				draw_line(o + Vector2(0, r * 0.2), o + Vector2(0, r * 1.2), c, 2.0)
			"end":
				draw_colored_polygon(PackedVector2Array([o + Vector2(-r * 1.2, -r), o + Vector2(r * 0.2, 0), o + Vector2(-r * 1.2, r)]), c)
				draw_colored_polygon(PackedVector2Array([o + Vector2(0, -r), o + Vector2(r * 1.4, 0), o + Vector2(0, r)]), c)
		draw_string(Hud.F_DISPLAY, Vector2(0, size.y - 7), title, HORIZONTAL_ALIGNMENT_CENTER, w, 18, Color(Hud.TEXT, 0.45 if disabled else 1.0))
		draw_string(Hud.F_TERM, Vector2(w - 30, 19), key, HORIZONTAL_ALIGNMENT_RIGHT, 26, 22, Color(Hud.GOLD if not disabled else Hud.DIM, 1.0 if not disabled else 0.6))


func _build_bar() -> void:
	_bar = PanelContainer.new()
	_bar.add_theme_stylebox_override("panel", CutBox.make(INK, Color(CYAN, 0.5), 16, 0b0011, CYAN, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_bar.add_child(row)
	_card = VBoxContainer.new()
	_card.custom_minimum_size = Vector2(220, 0)
	_card.add_theme_constant_override("separation", 3)
	row.add_child(_card)
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(1, 0)
	sep.color = Color(CYAN, 0.25)
	row.add_child(sep)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 8)
	row.add_child(mid)
	_econ = HBoxContainer.new()
	_econ.add_theme_constant_override("separation", 12)
	mid.add_child(_econ)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 5)
	mid.add_child(_buttons)
	for spec in [["shot", "SHOOT", "1", 0], ["auto", "AUTO", "2", 1], ["head", "HEAD", "3", 2]]:
		var b := ActBtn.new(spec[0], spec[1], spec[2], CYAN)
		b.toggle_mode = true
		b.pressed.connect(func(): action.emit("mode", spec[3]))
		_mode_buttons[spec[3]] = b
		_buttons.add_child(b)
	for spec in [["cover", "COVER", "X", "cover_mode", CYAN], ["reload", "RELOAD", "R", "reload", CYAN], ["jack", "JACK IN", "J", "jack_in", VIOLET]]:
		var b2 := ActBtn.new(spec[0], spec[1], spec[2], spec[4])
		if spec[3] == "cover_mode":
			b2.toggle_mode = true
		b2.pressed.connect(func(): action.emit(spec[3], null))
		_buttons.add_child(b2)
	_end_btn = ActBtn.new("end", "END TURN", "SPC", GOLD, 96, 66)
	_end_btn.pressed.connect(func(): action.emit("end_turn", null))
	row.add_child(_end_btn)
	add_child(_bar)


func _layout() -> void:
	var s := size
	_party.position = Vector2(14, 70)
	_init_strip.position = Vector2(s.x / 2 - _init_strip.size.x / 2, 12)
	_bar.position = Vector2(s.x / 2 - _bar.size.x / 2, s.y - _bar.size.y - 12)
	# log: flush above the hotbar's right end
	_log_panel.position = Vector2(_bar.position.x + _bar.size.x - _log_panel.size.x, _bar.position.y - _log_panel.size.y - 4)
	_net_panel.position = Vector2(s.x - _net_panel.size.x - 14, 110)
	_toast.position = Vector2(s.x / 2 - 400, 120)
	_toast.size = Vector2(800, 40)
	_banner_panel.position = Vector2(14, 12)


func _clear(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()


# --- Updates -----------------------------------------------------------------------

func _team_col(u: Dictionary) -> Color:
	return UnitModel.CREW_ACCENTS[u.id % 4] if u.team == 0 else RED


func refresh(enc: Encounter, mode: int, cover_mode: bool, floor_text: String) -> void:
	_clear(_party)
	for u in enc.units:
		if u.team == 0:
			_party.add_child(_party_card(u, u == enc.cur))
	_clear(_init_strip)
	for c in enc.init.order():
		if c.dead:
			continue
		var u := enc.unit_of(c)
		_init_strip.add_child(Slot.new(portraits.tex(u), _team_col(u), u == enc.cur, float(maxi(c.hp, 0)) / c.max_hp(), c.display_name.to_upper(), c.dead))
	var tab := PanelContainer.new()
	tab.add_theme_stylebox_override("panel", CutBox.make(INK, Color(CYAN, 0.5), 6, 0b0100, Color(0, 0, 0, 0), 6))
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 0)
	tab.add_child(tv)
	tv.add_child(_text("RND %02d" % maxi(1, enc.init.round_num), F_TERM, 22, CYAN))
	tv.add_child(_text("ENGAGED" if enc.engaged() else "UNDETECTED", F_DISPLAY, 18, RED if enc.engaged() else GREEN))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(14, 0)
	_init_strip.add_child(gap)
	_init_strip.add_child(tab)
	_clear(_card)
	_clear(_econ)
	var crew_turn: bool = enc.state == "playing" and not enc.cur.is_empty() and enc.cur.team == 0
	if not enc.cur.is_empty():
		var c: Combatant = enc.cur.c
		var top := HBoxContainer.new()
		top.add_theme_constant_override("separation", 10)
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", 0)
		top.add_child(nv)
		nv.add_child(_text(c.display_name.to_upper(), F_DISPLAY, 38, GOLD if crew_turn else RED))
		nv.add_child(_text(c.role.to_upper() + "  ·  " + ["UNHURT", "LIGHT WOUNDS", "SERIOUS WOUNDS", "MORTAL", "DEAD"][c.wound_state()], F_DISPLAY, 18, CYAN if crew_turn else RED))
		_card.add_child(top)
		var hp := HBoxContainer.new()
		hp.add_theme_constant_override("separation", 8)
		hp.alignment = BoxContainer.ALIGNMENT_BEGIN
		var hm := Meter.new(float(maxi(c.hp, 0)) / c.max_hp(), c.max_hp() / 5, _hp_col(c), 150, 12)
		hm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hp.add_child(hm)
		hp.add_child(_text("%d/%d HP" % [c.hp, c.max_hp()], F_TERM, 22, _hp_col(c)))
		_card.add_child(hp)
		_card.add_child(_text("SP  HEAD %02d   BODY %02d" % [c.sp("head"), c.sp("body")], F_TERM, 20, Color("9fb4c4")))
		if not c.injuries.is_empty():
			_card.add_child(_text("! " + ", ".join(c.injuries.map(func(i): return String(i.get("name", i.id)))).to_upper(), F_TERM, 17, RED))
		var t := enc.turn
		var act := t.action_available or t.attacks_left > 0
		_econ.add_child(_text("◆ ACTION" if act else "◇ ACTION", F_DISPLAY, 20, CYAN if act else Color(DIM, 0.6)))
		var mv := t.squares_available()
		var mvmax := maxi(1, c.stat("MOVE"))
		_econ.add_child(_text("MOVE %d" % mv, F_DISPLAY, 20, CYAN if mv > 0 else Color(DIM, 0.6)))
		var mm := Meter.new(float(mv) / mvmax, mvmax, CYAN, 100, 11)
		mm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_econ.add_child(mm)
		var exhausted := not act and mv == 0
		(_end_btn as ActBtn).tint = GOLD if exhausted else Color("8a96a0")
		var w: Weapon = c.weapons[0] if not c.weapons.is_empty() else null
		_econ.add_child(_text(("%s  %s" % [String(w.def.name).to_upper(), ("%02d/%02d" % [w.ammo, int(w.def.get("mag", 0))]) if w.uses_ammo() else ""]) if w else "UNARMED", F_TERM, 22, TEXT))
		if enc.runs.has(enc.cur.id):
			_econ.add_child(_text("◆ NET %d" % enc.net_left, F_PIXEL, 18, Color("d68cff")))
	for k in _mode_buttons:
		_mode_buttons[k].set_pressed_no_signal((k == mode) and not cover_mode)
	for b in _buttons.get_children():
		if b is Button:
			b.disabled = not crew_turn
			b.queue_redraw()
	(_buttons.get_child(3) as Button).set_pressed_no_signal(cover_mode)
	(_buttons.get_child(5) as Button).disabled = not crew_turn or enc.cur.is_empty() or NetRun.interface_rank(enc.cur.c) <= 0
	_end_btn.disabled = not crew_turn
	_end_btn.queue_redraw()
	_log.text = "\n".join(enc.log.slice(maxi(0, enc.log.size() - 4)).map(func(l): return "> " + l))
	_log_panel.visible = not enc.log.is_empty()
	_log_panel.reset_size()
	_banner.text = floor_text
	_net_refresh(enc)
	if enc.state != "playing":
		toast("GIG %s" % ("COMPLETE" if enc.state == "won" else "FAILED"), 1e9)
	_layout.call_deferred()


func _hp_col(c: Combatant) -> Color:
	var f := float(c.hp) / c.max_hp()
	return GREEN if f > 0.6 else (GOLD if f > 0.3 else RED)


func _party_card(u: Dictionary, active: bool) -> Control:
	var c: Combatant = u.c
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", CutBox.make(INK, GOLD if active else Color(_team_col(u), 0.45), 10, 0b0101, GOLD if active else Color(0, 0, 0, 0), 6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	var face := TextureRect.new()
	face.texture = portraits.tex(u)
	face.custom_minimum_size = Vector2(64, 64)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if c.dead:
		face.modulate = Color(1, 1, 1, 0.3)
	h.add_child(face)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	v.add_child(_text(c.display_name.to_upper(), F_DISPLAY, 26, GOLD if active else TEXT))
	v.add_child(_text(c.role.to_upper(), F_PIXEL, 18, _team_col(u)))
	v.add_child(Meter.new(float(maxi(c.hp, 0)) / c.max_hp(), c.max_hp() / 5, _hp_col(c), 110, 9))
	v.add_child(_text("%d/%d HP" % [c.hp, c.max_hp()], F_TERM, 19, _hp_col(c)))
	return p


## Cursor tooltip: a small pixel header and a bbcode body. Empty text hides it.
func tip(text: String, at: Vector2, head := "", head_col := CYAN) -> void:
	_tip.visible = text != ""
	if text == "":
		return
	_tip_head.text = head
	_tip_head.visible = head != ""
	_tip_head.add_theme_color_override("font_color", head_col)
	_tip_label.text = text
	_tip.reset_size()
	_tip.position = (at + Vector2(24, 20)).clamp(Vector2.ZERO, size - _tip.size - Vector2(4, 4))


func toast(text: String, secs := 2.2) -> void:
	_toast.text = text
	if secs < 1e8:
		get_tree().create_timer(secs).timeout.connect(func(): if _toast.text == text: _toast.text = "")


func _net_button(text: String, cb: Callable, w: float, h: float, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", F_TERM)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color("e2c8ff"))
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.5))
	b.add_theme_stylebox_override("normal", CutBox.make(Color(0.06, 0.02, 0.08, 0.9), Color(VIOLET, 0.4), 6, 0b0100, Color(0, 0, 0, 0), 6))
	b.add_theme_stylebox_override("hover", CutBox.make(Color(0.14, 0.04, 0.18, 0.95), VIOLET, 6, 0b0100, Color(0, 0, 0, 0), 6))
	b.add_theme_stylebox_override("pressed", CutBox.make(Color(0.2, 0.06, 0.26, 0.95), MAGENTA, 6, 0b0100, Color(0, 0, 0, 0), 6))
	b.add_theme_stylebox_override("disabled", CutBox.make(Color(0.03, 0.02, 0.04, 0.8), Color(DIM, 0.2), 6, 0b0100, Color(0, 0, 0, 0), 6))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.disabled = disabled
	b.pressed.connect(cb)
	return b


func _net_refresh(enc: Encounter) -> void:
	_clear(_net_box)
	var run: NetRun = enc.runs.get(enc.cur.id) if not enc.cur.is_empty() else null
	_net_panel.visible = run != null
	if run == null:
		return
	_net_box.add_child(_text("// NET SESSION · %d ACTIONS" % enc.net_left, F_PIXEL, 18, MAGENTA))
	_net_box.add_child(_text(_node_label(run.cur_node()).to_upper(), F_DISPLAY, 18, Color("e2c8ff")))
	for i in run.arch.ice_at(run.current):
		_net_box.add_child(_text("!! BLACK ICE: %s" % String(i.kind).to_upper(), F_TERM, 19, RED))
	var acts := GridContainer.new()
	acts.columns = 3
	for spec in [["BACKDOOR", "backdoor"], ["CONTROL", "control"], ["EYE-DEE", "eye_dee"], ["ZAP", "zap"], ["CROSS", "cross"], ["JACK OUT", "jack_out"]]:
		acts.add_child(_net_button(spec[0], func(): action.emit("net", spec[1]), 96, 28, enc.net_left <= 0 and spec[1] != "jack_out"))
	_net_box.add_child(acts)
	_net_box.add_child(_text("ROUTE (FREE)", F_PIXEL, 18, DIM))
	var k := 0
	for id in run.movable():
		if id == run.current or k >= 10:
			continue
		k += 1
		_net_box.add_child(_net_button("› " + _node_label(run.arch.nodes[id]), func(): action.emit("net_move", id), 296, 24))


static func _node_label(n: Dictionary) -> String:
	match n.type:
		"firewall": return "Firewall DV%d (L%d)" % [n.dv, n.zone]
		"file": return "File DV%d" % n.dv
		"control": return "Control: %s" % String(n.group).replace("_", " ")
		"socket": return "Socket → structure %d" % n.target_structure
	return "%s (L%d)" % [String(n.type).capitalize(), n.zone]


# --- Visual settings panel (F2) ---------------------------------------------------

func build_settings(vals: Dictionary, specs: Array, changed: Callable) -> void:
	settings = _panel(GOLD, 0b0101, GOLD)
	var v := VBoxContainer.new()
	settings.add_child(v)
	v.add_child(_text("// LOOK · F2", F_PIXEL, 18, GOLD))
	for s in specs:  # [key, label, min, max, step]
		var row := HBoxContainer.new()
		var l := _text(String(s[1]).to_upper(), F_PIXEL, 18, TEXT)
		l.custom_minimum_size = Vector2(120, 0)
		row.add_child(l)
		var sl := HSlider.new()
		sl.min_value = s[2]
		sl.max_value = s[3]
		sl.step = s[4]
		sl.value = float(vals[s[0]])
		sl.custom_minimum_size = Vector2(160, 18)
		var val := _text(str(vals[s[0]]), F_TERM, 18, CYAN)
		sl.value_changed.connect(func(x):
			vals[s[0]] = x
			val.text = str(snappedf(x, 0.01))
			changed.call())
		row.add_child(sl)
		row.add_child(val)
		v.add_child(row)
	settings.position = Vector2(14, 104)
	settings.visible = false
	add_child(settings)
