class_name UiKit
extends RefCounted
## The between-gigs screens' building blocks, in the tactical HUD's look (Hud fonts and colours,
## CutBox chamfered panels). Owner's rules (UI audit):
##   fonts: the pixel display face for names and headings; sans caps for labels and buttons;
##   mixed-case sans for sentences. Buttons are always the readable sans, never tiny pixel text.
##   colours: gold = selected / primary action; cyan = interface and information; red = hostile
##   and danger only; green = health / success; violet = NET and chrome; objectives white with ★.
##   Role colours only as small portrait accents.

## Button styles: text colour and edge.
const NEUTRAL := "neutral"   ## purchases and routine actions (BUY · 50 eb)
const PRIMARY := "primary"   ## the screen's main action, and what's selected (gold)
const NAV := "nav"           ## interface: tabs, back, navigation (cyan)
const CHROME := "chrome"     ## cyberware (violet)
const HEALTH := "health"     ## healing and recovery (green)
const DANGER := "danger"     ## dangerous choices (red)


static func colour(style: String) -> Color:
	match style:
		PRIMARY: return Hud.GOLD
		NAV: return Hud.CYAN
		CHROME: return Hud.VIOLET.lightened(0.25)
		HEALTH: return Hud.GREEN
		DANGER: return Hud.RED
	return Hud.TEXT


## A heading or a name in the pixel display face (caps; below 28 px it drops columns, so smaller
## headings fall back to the bold sans).
static func head(s: String, size := 32, col := Hud.TEXT) -> Label:
	var l := _label(s.to_upper(), Hud.F_DISPLAY if size >= 28 else Hud.F_BOLD, size, col)
	if size >= 28:
		l.add_theme_constant_override("line_spacing", -size / 4)
	return l


## A label: sans caps.
static func label(s: String, size := 15, col := Hud.DIM) -> Label:
	return _label(caps(s), Hud.F_BOLD, size, col)


## A sentence: mixed-case sans, wrapping to its container's width.
static func body(s: String, size := 16, col := Color(Hud.TEXT, 0.85), wrap := true) -> Label:
	var l := _label(s, Hud.F_BODY, size, col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 60
	return l


## Caps for labels and buttons, keeping the book's lower-case "eb" (eurobucks).
static func caps(s: String) -> String:
	return RegEx.create_from_string("(\\bEB|(?<=\\d)EB)\\b").sub(s.to_upper(), "eb", true)


## A one-line label that takes the free width of its row and trims with "…" rather than pushing
## the row wider than the screen.
static func fit(l: Label) -> Label:
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 40
	l.clip_text = true
	return l


static func _label(s: String, font: Font, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A button in sans caps. `style` is one of the constants above.
static func button(text: String, style: String, cb: Callable, enabled := true, size := 15, compact := false) -> Button:
	var col := colour(style)
	var b := Button.new()
	b.text = caps(text)
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size.y = 26 if compact else 34
	b.add_theme_font_override("font", Hud.F_BOLD)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col.lightened(0.3))
	b.add_theme_color_override("font_pressed_color", Hud.GOLD)
	b.add_theme_color_override("font_disabled_color", Color(Hud.DIM, 0.7))
	var edge := Color(col, 0.55) if style != NEUTRAL else Color(Hud.DIM, 0.6)
	b.add_theme_stylebox_override("normal", _btn_box(Color(0.03, 0.045, 0.06, 0.95), edge, compact))
	b.add_theme_stylebox_override("hover", _btn_box(Color(col.r * 0.15, col.g * 0.15, col.b * 0.15, 0.97), col, compact))
	b.add_theme_stylebox_override("pressed", _btn_box(Color(0.14, 0.11, 0.02, 0.97), Hud.GOLD, compact))
	b.add_theme_stylebox_override("hover_pressed", _btn_box(Color(0.14, 0.11, 0.02, 0.97), Hud.GOLD, compact))
	b.add_theme_stylebox_override("disabled", _btn_box(Color(0.02, 0.025, 0.03, 0.8), Color(Hud.DIM, 0.2), compact))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


## A tab or a selected item: gold fill and edge when `on`.
static func tab(text: String, on: bool, cb: Callable, size := 16) -> Button:
	var b := button(text, PRIMARY if on else NAV, cb, true, size)
	b.custom_minimum_size = Vector2(0, 38)
	if on:
		b.add_theme_stylebox_override("normal", _btn_box(Color(0.14, 0.11, 0.02, 0.97), Hud.GOLD))
	return b


static func _btn_box(fill: Color, edge: Color, compact := false) -> CutBox:
	var s := CutBox.make(fill, edge, 7, 0b0101)
	s.content_margin_left = 7 if compact else 12
	s.content_margin_right = 7 if compact else 12
	s.content_margin_top = 1 if compact else 4
	s.content_margin_bottom = 1 if compact else 4
	return s


## A panel; `edge` tints its border (gold when selected).
static func panel(edge := Hud.CYAN, margin := 12.0, accent := Color(0, 0, 0, 0)) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", CutBox.make(Hud.INK, Color(edge, 0.5), 12, 0b0101, accent, margin))
	return p


## A selected panel: gold edge and accent.
static func selected_panel(margin := 12.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", CutBox.make(Color(0.07, 0.06, 0.02, 0.95), Hud.GOLD, 12, 0b0101, Hud.GOLD, margin))
	return p


## A small tag ("+30 IP", "Broken Arm").
static func chip(text: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := CutBox.make(Color(col.r * 0.12, col.g * 0.12, col.b * 0.12, 0.95), Color(col, 0.6), 4, 0b0101, Color(0, 0, 0, 0), 3)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", s)
	p.add_child(label(text, 13, col))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func vbox(sep := 6) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 8) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


## Chips that wrap onto more lines when there are many.
static func flow(sep := 6) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.add_theme_constant_override("h_separation", sep)
	f.add_theme_constant_override("v_separation", 4)
	return f


## A list that scrolls inside its own panel (never sideways).
static func scroller(content: Control) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(content)
	return sc


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


## A portrait bust (the HUD's Portraits renderer) with the crew member's accent as a thin frame.
static func portrait(portraits: Portraits, c: Combatant, id: int, px := 56) -> Control:
	var frame := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.02, 0.03, 0.04)
	s.border_color = UnitLook.CREW_ACCENTS[maxi(0, c.look_seed) % 4]   # the role accent, small
	s.set_border_width_all(2)
	frame.add_theme_stylebox_override("panel", s)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var pic := TextureRect.new()
	pic.texture = portraits.tex({"id": id, "team": 0, "c": c}) if portraits else null   # null: headless tests
	pic.custom_minimum_size = Vector2(px, px)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(pic)
	return frame


## "SOLO · HP 20/45": the Role as information, HP in its health colour.
static func role_hp(c: Combatant) -> HBoxContainer:
	var h := hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(label(c.role, 13, Hud.DIM))
	h.add_child(label("HP %d/%d" % [c.hp, c.max_hp()], 13, hp_colour(c)))
	return h


## Health colour by Wound State (p220): green unhurt, gold lightly, red seriously or worse.
static func hp_colour(c: Combatant) -> Color:
	if c.hp >= c.max_hp():
		return Hud.GREEN
	return Hud.GOLD if c.wound_state() < Combatant.Wound.SERIOUS else Hud.RED


static func money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


## "BUY · 1,000 eb" and friends.
static func price_text(verb: String, eb: int) -> String:
	return "%s · %s eb" % [verb, money(eb)]


## Make a whole panel clickable.
static func clickable(c: Control, cb: Callable) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			cb.call())
	for ch in c.find_children("*", "Control", true, false):
		if not ch is Button:
			(ch as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
