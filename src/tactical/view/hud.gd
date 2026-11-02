class_name Hud
extends Control
## Tactical HUD, laid out after Baldur's Gate 3 (M3 playtest verdict): party portraits down the
## left, the initiative strip across the top, and a bottom hotbar holding the active character
## card, the action economy (Action pip, Move bar), the action buttons and End Turn. A cursor
## tooltip shows hit chances; the combat log sits bottom right; the NET panel opens on the right
## while jacked in. Cyberpunk skin: dark glass panels, neon edges, high-contrast numbers.
## Emits `action(name, arg)`; the greybox owns the rules calls.

signal action(name: String, arg: Variant)

const BG := Color(0.035, 0.045, 0.06, 0.88)
const EDGE := Color("05d9e8")
const GOLD := Color("f9c80e")
const RED := Color("ff3b4f")
const GREEN := Color("39f0a0")
const DIM := Color("7d8a96")
const TEXT := Color("e6edf3")

var font_scale := 1.0
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
var _tip_label: RichTextLabel
var _toast: Label
var _banner: Label
var settings: PanelContainer
var _mode_buttons := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_party = VBoxContainer.new()
	_party.add_theme_constant_override("separation", 8)
	add_child(_party)
	_init_strip = HBoxContainer.new()
	_init_strip.add_theme_constant_override("separation", 6)
	add_child(_init_strip)
	_build_bar()
	_log_panel = _panel()
	_log_panel.custom_minimum_size = Vector2(380, 0)
	_log = _text(13, DIM)
	_log.custom_minimum_size = Vector2(360, 0)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_panel.add_child(_log)
	add_child(_log_panel)
	_net_panel = _panel(Color("b537f2"))
	_net_box = VBoxContainer.new()
	_net_panel.add_child(_net_box)
	_net_panel.visible = false
	add_child(_net_panel)
	_tip = _panel()
	_tip_label = RichTextLabel.new()
	_tip_label.bbcode_enabled = true
	_tip_label.fit_content = true
	_tip_label.scroll_active = false
	_tip_label.custom_minimum_size = Vector2(230, 0)
	_tip_label.add_theme_font_size_override("normal_font_size", 14)
	_tip_label.add_theme_font_size_override("bold_font_size", 15)
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.add_child(_tip_label)
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	add_child(_tip)
	_toast = _text(20, GOLD)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_toast)
	_banner = _text(15, DIM)
	add_child(_banner)
	resized.connect(_layout)
	_layout()


# --- Building blocks ---------------------------------------------------------------

func _style(edge: Color, bg := BG, width := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(width)
	s.set_corner_radius_all(3)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s


func _panel(edge := EDGE) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(Color(edge, 0.55)))
	return p


func _text(size: int, col := TEXT) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar_meter(frac: float, w: float, h: float, col: Color, label := "") -> Control:
	var back := Panel.new()
	back.custom_minimum_size = Vector2(w, h)
	back.add_theme_stylebox_override("panel", _style(Color(col, 0.5), Color(0, 0, 0, 0.7)))
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = col
	fill.position = Vector2(1, 1)
	fill.size = Vector2(maxf(0.0, (w - 2) * clampf(frac, 0, 1)), h - 2)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)
	if label != "":
		var l := _text(int(h) - 3)
		l.text = label
		l.position = Vector2(4, -1)
		back.add_child(l)
	return back


func _button(text: String, key: String, cb: Callable, edge := EDGE, w := 74.0) -> Button:
	var b := Button.new()
	b.text = text + ("\n" + key if key != "" else "")
	b.custom_minimum_size = Vector2(w, 58)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_stylebox_override("normal", _style(Color(edge, 0.55)))
	b.add_theme_stylebox_override("hover", _style(edge, Color(0.07, 0.1, 0.13, 0.95)))
	b.add_theme_stylebox_override("pressed", _style(GOLD, Color(0.12, 0.1, 0.03, 0.95), 2))
	b.add_theme_stylebox_override("disabled", _style(Color(DIM, 0.25), Color(0.03, 0.03, 0.04, 0.7)))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_disabled_color", Color(DIM, 0.6))
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


func _build_bar() -> void:
	_bar = _panel()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_bar.add_child(row)
	_card = VBoxContainer.new()
	_card.custom_minimum_size = Vector2(250, 0)
	row.add_child(_card)
	var mid := VBoxContainer.new()
	row.add_child(mid)
	_econ = HBoxContainer.new()
	_econ.add_theme_constant_override("separation", 10)
	mid.add_child(_econ)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	mid.add_child(_buttons)
	for spec in [["Shoot", "1", "mode", 0], ["Autofire", "2", "mode", 1], ["Head shot", "3", "mode", 2]]:
		var b := _button(spec[0], spec[1], func(): action.emit(spec[2], spec[3]))
		b.toggle_mode = true
		_mode_buttons[spec[3]] = b
		_buttons.add_child(b)
	_buttons.add_child(_button("Shoot\ncover", "X", func(): action.emit("cover_mode", null)))
	_buttons.add_child(_button("Reload", "R", func(): action.emit("reload", null)))
	_buttons.add_child(_button("Jack in", "J", func(): action.emit("jack_in", null), Color("b537f2")))
	_end_btn = _button("END TURN", "Space", func(): action.emit("end_turn", null), GOLD, 110)
	_end_btn.custom_minimum_size.y = 84
	row.add_child(_end_btn)
	add_child(_bar)


func _layout() -> void:
	var s := size
	_party.position = Vector2(14, 90)
	_init_strip.position = Vector2(s.x / 2 - _init_strip.size.x / 2, 10)
	_bar.position = Vector2(s.x / 2 - _bar.size.x / 2, s.y - _bar.size.y - 10)
	var log_y := s.y - _log_panel.size.y - 10
	if _bar.position.x + _bar.size.x > s.x - _log_panel.size.x - 20:
		log_y = _bar.position.y - _log_panel.size.y - 8  # narrow window: stack the log above the hotbar
	_log_panel.position = Vector2(s.x - _log_panel.size.x - 14, log_y)
	_net_panel.position = Vector2(s.x - _net_panel.size.x - 14, 100)
	_toast.position = Vector2(s.x / 2 - 300, 110)
	_toast.size = Vector2(600, 30)
	_banner.position = Vector2(14, s.y - 26)


func _clear(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()


# --- Updates -----------------------------------------------------------------------

## Full refresh from the encounter. `mode` is the selected fire mode index.
func refresh(enc: Encounter, mode: int, cover_mode: bool, floor_text: String) -> void:
	_clear(_party)
	for u in enc.units:
		if u.team == 0:
			_party.add_child(_portrait(u, u == enc.cur, false))
	_clear(_init_strip)
	for c in enc.init.order():
		if c.dead:
			continue
		var u := enc.unit_of(c)
		_init_strip.add_child(_portrait(u, u == enc.cur, true))
	var round_l := _text(13, DIM)
	round_l.text = "ROUND %d" % maxi(1, enc.init.round_num)
	_init_strip.add_child(round_l)
	_clear(_card)
	_clear(_econ)
	var crew_turn: bool = enc.state == "playing" and not enc.cur.is_empty() and enc.cur.team == 0
	if not enc.cur.is_empty():
		var c: Combatant = enc.cur.c
		var name_l := _text(18, GOLD if crew_turn else RED)
		name_l.text = c.display_name.to_upper()
		_card.add_child(name_l)
		var sub := _text(12, DIM)
		sub.text = "%s · %s" % [c.role.capitalize(), ["Unhurt", "Lightly wounded", "Seriously wounded", "Mortally wounded", "Dead"][c.wound_state()]]
		_card.add_child(sub)
		_card.add_child(_bar_meter(float(c.hp) / c.max_hp(), 240, 16, _hp_col(c), "HP %d / %d" % [c.hp, c.max_hp()]))
		var sp := _text(13)
		sp.text = "SP  head %d · body %d" % [c.sp("head"), c.sp("body")]
		_card.add_child(sp)
		if not c.injuries.is_empty():
			var inj := _text(12, RED)
			inj.text = "⚠ " + ", ".join(c.injuries.map(func(i): return String(i.get("name", i.id))))
			_card.add_child(inj)
		var t := enc.turn
		var act := t.action_available or t.attacks_left > 0
		var pip := _text(15, GREEN if act else Color(DIM, 0.5))
		pip.text = "● ACTION"
		_econ.add_child(pip)
		var mv := t.squares_available()
		var mvmax := c.stat("MOVE")
		_econ.add_child(_bar_meter(float(mv) / maxf(1, mvmax), 150, 16, Color("ffb000"), "MOVE %d" % mv))
		var w: Weapon = c.weapons[0] if not c.weapons.is_empty() else null
		var wl := _text(14)
		wl.text = ("%s  %s" % [w.def.name, ("%d/%d" % [w.ammo, int(w.def.get("mag", 0))]) if w.uses_ammo() else ""]) if w else "Unarmed"
		_econ.add_child(wl)
		if enc.runs.has(enc.cur.id):
			var na := _text(14, Color("d68cff"))
			na.text = "◆ NET %d" % enc.net_left
			_econ.add_child(na)
	for k in _mode_buttons:
		_mode_buttons[k].button_pressed = (k == mode) and not cover_mode
		_mode_buttons[k].disabled = not crew_turn
	for b in _buttons.get_children():
		if b is Button:
			b.disabled = not crew_turn
	_buttons.get_child(5).disabled = not crew_turn or enc.cur.is_empty() or NetRun.interface_rank(enc.cur.c) <= 0
	_end_btn.disabled = not crew_turn
	_log.text = "\n".join(enc.log.slice(maxi(0, enc.log.size() - 7)))
	_banner.text = floor_text
	_net_refresh(enc)
	if enc.state != "playing":
		toast("GIG %s" % ("COMPLETE" if enc.state == "won" else "FAILED"), 1e9)
	_layout.call_deferred()


func _hp_col(c: Combatant) -> Color:
	var f := float(c.hp) / c.max_hp()
	return GREEN if f > 0.6 else (GOLD if f > 0.3 else RED)


## A portrait card: coloured face block with initials, name, HP bar. BG3-style party / turn order.
func _portrait(u: Dictionary, active: bool, small: bool) -> Control:
	var c: Combatant = u.c
	var p := PanelContainer.new()
	var edge := GOLD if active else (Color(EDGE, 0.6) if u.team == 0 else Color(RED, 0.6))
	p.add_theme_stylebox_override("panel", _style(edge, BG, 2 if active else 1))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var face := ColorRect.new()
	var w := 54.0 if small else 72.0
	face.custom_minimum_size = Vector2(w, w * 0.8)
	face.color = (UnitModel.CREW_JACKETS[u.id % 4] if u.team == 0 else Color("3b3f45")).lightened(0.15)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ini := _text(20 if small else 26, UnitModel.CREW_ACCENTS[u.id % 4] if u.team == 0 else RED)
	var initials := ""
	for part in c.display_name.split(" "):
		initials += part.substr(0, 1)
	ini.text = initials
	ini.position = Vector2(6, 2)
	face.add_child(ini)
	v.add_child(face)
	if not small:
		var n := _text(12)
		n.text = c.display_name
		v.add_child(n)
	v.add_child(_bar_meter(float(maxi(c.hp, 0)) / c.max_hp(), w, 7, _hp_col(c)))
	if c.dead:
		p.modulate = Color(1, 1, 1, 0.35)
	return p


## Cursor tooltip (BG3-style): bbcode text near the mouse. Empty text hides it.
func tip(text: String, at: Vector2) -> void:
	_tip.visible = text != ""
	if text == "":
		return
	_tip_label.text = text
	_tip.reset_size()
	_tip.position = (at + Vector2(22, 18)).clamp(Vector2.ZERO, size - _tip.size - Vector2(4, 4))


func toast(text: String, secs := 2.2) -> void:
	_toast.text = text
	if secs < 1e8:
		get_tree().create_timer(secs).timeout.connect(func(): if _toast.text == text: _toast.text = "")


func _net_refresh(enc: Encounter) -> void:
	_clear(_net_box)
	var run: NetRun = enc.runs.get(enc.cur.id) if not enc.cur.is_empty() else null
	_net_panel.visible = run != null
	if run == null:
		return
	var n := run.cur_node()
	var h := _text(15, Color("d68cff"))
	h.text = "NET · %s" % _node_label(n)
	_net_box.add_child(h)
	for i in run.arch.ice_at(run.current):
		var l := _text(13, RED)
		l.text = "BLACK ICE: %s" % String(i.kind).capitalize()
		_net_box.add_child(l)
	var acts := HBoxContainer.new()
	for spec in [["Backdoor", "backdoor"], ["Control", "control"], ["Eye-Dee", "eye_dee"], ["Zap", "zap"], ["Cross", "cross"], ["Jack out", "jack_out"]]:
		var b := _button(spec[0], "", func(): action.emit("net", spec[1]), Color("b537f2"), 64)
		b.custom_minimum_size.y = 34
		b.disabled = enc.net_left <= 0 and spec[1] != "jack_out"
		acts.add_child(b)
	_net_box.add_child(acts)
	var sub := _text(12, DIM)
	sub.text = "Move to (free):"
	_net_box.add_child(sub)
	var k := 0
	for id in run.movable():
		if id == run.current or k >= 10:
			continue
		k += 1
		var b2 := _button(_node_label(run.arch.nodes[id]), "", func(): action.emit("net_move", id), Color("b537f2"), 300)
		b2.custom_minimum_size.y = 26
		b2.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_net_box.add_child(b2)


static func _node_label(n: Dictionary) -> String:
	match n.type:
		"firewall": return "Firewall DV%d (L%d)" % [n.dv, n.zone]
		"file": return "File DV%d" % n.dv
		"control": return "Control: %s" % String(n.group).replace("_", " ")
		"socket": return "Socket → structure %d" % n.target_structure
	return "%s (L%d)" % [String(n.type).capitalize(), n.zone]


# --- Visual settings panel (F2) ---------------------------------------------------

## Sliders for the look (spec: expose pixel scale, contrast and bloom). `vals` is mutated and
## `changed` is called after every edit.
func build_settings(vals: Dictionary, specs: Array, changed: Callable) -> void:
	settings = _panel(GOLD)
	var v := VBoxContainer.new()
	settings.add_child(v)
	var h := _text(15, GOLD)
	h.text = "LOOK  (F2)"
	v.add_child(h)
	for s in specs:  # [key, label, min, max, step]
		var row := HBoxContainer.new()
		var l := _text(13)
		l.text = s[1]
		l.custom_minimum_size = Vector2(110, 0)
		row.add_child(l)
		var sl := HSlider.new()
		sl.min_value = s[2]
		sl.max_value = s[3]
		sl.step = s[4]
		sl.value = float(vals[s[0]])
		sl.custom_minimum_size = Vector2(160, 18)
		var val := _text(13, DIM)
		val.text = str(vals[s[0]])
		sl.value_changed.connect(func(x):
			vals[s[0]] = x
			val.text = str(snappedf(x, 0.01))
			changed.call())
		row.add_child(sl)
		row.add_child(val)
		v.add_child(row)
	settings.position = Vector2(14, 90)
	settings.visible = false
	add_child(settings)
