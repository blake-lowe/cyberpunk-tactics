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
const NEUTRAL := Color("c8d0d8")   # bystanders, medics: neither crew nor foe
const GREEN := Color("39f0a0")
const VIOLET := Color("b537f2")
const DIM := Color("8796a4")   # secondary text: ~6.7:1 on the panel ink (was 6f7d8a, ~4.8:1)
const TEXT := Color("e8eef2")

static var F_DISPLAY: FontFile
static var F_BODY: FontFile
static var F_PIXEL: FontVariation
static var F_TERM: FontFile
static var F_BOLD: FontFile
static var F_MONO: FontFile


## Body-text size for a size written for the old terminal face (VT323 ran ~15% smaller), never
## below 15 logical px (22 screen px at 1080p).
static func ts(s: int) -> int:
	return maxi(15, roundi(s * 0.85))

var portraits: Portraits
var _party: VBoxContainer
var _init_strip: HBoxContainer
var _bar: PanelContainer
var _card: VBoxContainer
var _econ: HBoxContainer
var _buttons: HBoxContainer
var _tool_buttons := {}   ## id → ActBtn on the main bar
var _atk_buttons: HBoxContainer   ## the attack stage: weapon tabs, then the drawn weapon's attacks
var stage := "main"       ## "main" or "attack" (set by the view before refresh)
var atk_mode := "single"  ## the armed attack in the attack stage (Encounter.attack_modes ids)
## Main-bar actions: [id, title, key, signal, arg, tint]. Order is fixed so nothing moves.
const MAIN_ACTIONS := [["shot", "ATTACK", "F", "stage", "attack", Color("05d9e8")], ["reload", "RELOAD", "R", "reload", null, Color("05d9e8")],
	["kit0", "KIT", "G", "kit", 0, Color("f9c80e")], ["jack", "JACK IN", "J", "jack_in", null, Color("d68cff")],
	["interact", "INTERACT", "B", "interact", null, Color("f9c80e")], ["medic", "STABILIZE", "T", "tool", "stabilize", Color("39f0a0")],
	["role", "ROLE", "V", "role", null, Color("39f0a0")]]
## Attack-stage modes: id → [button title, glyph, the book's full name] (CPR core p.170-177).
const ATK_MODES := {"single": ["SINGLE", "shot", "Single Shot"], "aim_head": ["AIM HEAD", "head", "Aimed Shot: head"],
	"aim_leg": ["AIM LEG", "head", "Aimed Shot: leg"], "aim_held": ["AIM HELD", "head", "Aimed Shot: held item"],
	"auto": ["AUTOFIRE", "auto", "Autofire"], "suppress": ["SUPPRESS", "suppress", "Suppressive Fire"],
	"shell": ["SHELL", "shell", "Shotgun Shell"], "cover": ["COVER", "cover", "Shoot the cover in the way"],
	"melee": ["MELEE", "melee", "Melee Attack"], "brawl": ["BRAWL", "melee", "Brawling"]}
var tool := ""            ## active target-picking tool (set by the view before refresh)
var _end_btn: Button
var _withdraw_btn: Button   ## a gig-level choice, not a unit action: sits above END TURN, off the action bar
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
var _turn_banner: Label
var _turn_rule: ColorRect
var _turn_strip: ColorRect   ## the dark strip behind the turn banner, so it reads on bright ground
var hint: PanelContainer
var hint_tab: PanelContainer
var _hp_seen := {}            ## unit id → last HP fraction shown (for ghost drain)
var _banner_tw: Tween
var _flash: ColorRect
var _vignette: ColorRect
var _cards := {}
var _round_tab: PanelContainer
var _log_lines: Array = []
var _log_open := false
var roster_on := false    ## the crew roster slides in while Alt is held (owner: strip only by default)
var log_hold := false     ## the view holds the log while an action plays, so lines land with the callouts
var _overlay_lbl: Label   ## which overlays are on (sight lines, cutaway), under the round tab
var _log_tw: Tween
var end_toast := ""        ## the view's headline once the gig is over ("" = the plain GIG COMPLETE / ABANDONED / FAILED)
var leg_text := ""         ## an operation's leg on the round tab ("LEG 2/3"), set by the view
var _round_box: VBoxContainer              ## unit id → party card (hit shake)


static func _fonts() -> void:
	if F_BODY:
		return
	F_DISPLAY = FontFile.new()
	F_DISPLAY.load_dynamic_font("res://assets/fonts/Jersey10-Regular.ttf")
	F_DISPLAY.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	F_PIXEL = FontVariation.new()
	F_PIXEL.base_font = F_DISPLAY
	F_PIXEL.spacing_glyph = 1
	# Body and data text (owner round 6: legibility): Chakra Petch SemiBold, a squared-off tech sans
	# with open counters and clear figures, antialiased so it holds up at any UI scale. Jersey10
	# stays the pixel display face for names, buttons and banners. VT323 is kept for the NET's
	# terminal readouts only (F_MONO).
	F_TERM = FontFile.new()
	F_TERM.load_dynamic_font("res://assets/fonts/ChakraPetch-SemiBold.ttf")
	F_TERM.hinting = TextServer.HINTING_LIGHT
	F_TERM.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	F_BODY = F_TERM
	F_BOLD = FontFile.new()
	F_BOLD.load_dynamic_font("res://assets/fonts/ChakraPetch-Bold.ttf")
	F_BOLD.hinting = TextServer.HINTING_LIGHT
	F_MONO = FontFile.new()
	F_MONO.load_dynamic_font("res://assets/fonts/VT323-Regular.ttf")
	F_MONO.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	# Symbols the faces lack (★ ◇ ○ ● ⚠ ✓, and arrows/≤≥ in Jersey10) come from explicit fallbacks
	# instead of whatever the OS has.
	# They are subsets with short line metrics (tools/make_ui_symbols.py) so they never make a line taller.
	var sym := FontFile.new()
	sym.load_dynamic_font("res://assets/fonts/UiSymbols-Noto.ttf")
	var sym2 := FontFile.new()
	sym2.load_dynamic_font("res://assets/fonts/UiSymbols-Chakra.ttf")
	for f in [F_TERM, F_BOLD, F_MONO]:
		f.fallbacks = [sym]
	F_DISPLAY.fallbacks = [sym2, sym]


func _ready() -> void:
	_fonts()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = F_BODY
	th.default_font_size = ts(20)
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
	_round_tab = PanelContainer.new()
	_round_tab.add_theme_stylebox_override("panel", CutBox.make(INK, Color(CYAN, 0.5), 8, 0b1000, Color(0, 0, 0, 0), 8))
	_round_box = VBoxContainer.new()
	_round_box.add_theme_constant_override("separation", 0)
	_round_tab.add_child(_round_box)
	add_child(_round_tab)
	_overlay_lbl = _text("", F_TERM, Hud.ts(16), DIM)
	add_child(_overlay_lbl)
	_log_panel = _panel(CYAN, 0b0100)
	var lv := VBoxContainer.new()
	_log_panel.add_child(lv)
	_log = _text("", F_TERM, Hud.ts(19), Color("9fb4c4"))
	_log.custom_minimum_size = Vector2(380, 0)
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(_log)
	add_child(_log_panel)
	# bottom left above the bar's end: the last 3 lines, fading; hovering expands it (owner)
	_log_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_log_panel.mouse_entered.connect(func(): _log_open = true; _show_log())
	_log_panel.mouse_exited.connect(func(): _log_open = false; _show_log())
	_net_panel = _panel(VIOLET, 0b0101)
	_net_box = VBoxContainer.new()
	_net_box.add_theme_constant_override("separation", 3)
	_net_panel.add_child(_net_box)
	_net_panel.visible = false
	add_child(_net_panel)
	_tip = PanelContainer.new()
	_tip.add_theme_stylebox_override("panel", CutBox.make(Color(INK, 1.0), Color(CYAN, 0.7), 8, 0b0101, CYAN, 8))   # opaque: nothing shows through
	var tv := VBoxContainer.new()
	_tip.add_child(tv)
	_tip_head = _text("", F_PIXEL, 20, CYAN)
	tv.add_child(_tip_head)
	_tip_label = RichTextLabel.new()
	_tip_label.bbcode_enabled = true
	_tip_label.fit_content = true
	_tip_label.scroll_active = false
	_tip_label.custom_minimum_size = Vector2(290, 0)
	_tip_label.add_theme_font_override("normal_font", F_BODY)
	_tip_label.add_theme_font_override("bold_font", F_DISPLAY)
	_tip_label.add_theme_font_override("mono_font", F_TERM)
	_tip_label.add_theme_font_size_override("normal_font_size", ts(20))
	_tip_label.add_theme_font_size_override("bold_font_size", 30)
	_tip_label.add_theme_font_size_override("mono_font_size", ts(20))
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tv.add_child(_tip_label)
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.visible = false
	add_child(_tip)
	_toast = _text("", F_DISPLAY, 40, GOLD)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_shadow_color", Color(MAGENTA, 0.8))
	_toast.add_theme_constant_override("shadow_offset_x", 3)
	_toast.add_theme_constant_override("shadow_offset_y", 0)
	add_child(_toast)
	_flash = ColorRect.new()
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	add_child(_flash)
	_vignette = ColorRect.new()
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vs := Shader.new()
	vs.code = """shader_type canvas_item;
uniform vec4 col : source_color = vec4(1.0, 0.15, 0.2, 1.0);
uniform float amount = 0.0;
void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	float e = smoothstep(0.75, 1.0, max(d.x, d.y));
	float scan = step(2.0, mod(FRAGCOORD.y, 4.0));
	COLOR = vec4(col.rgb, e * amount * (0.6 + 0.4 * scan));
}"""
	var vm := ShaderMaterial.new()
	vm.shader = vs
	vm.set_shader_parameter("amount", 0.0)   # must exist before it can be tweened
	_vignette.material = vm
	add_child(_vignette)
	_turn_strip = ColorRect.new()
	_turn_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_strip.color = Color(INK, 0.82)
	_turn_strip.modulate.a = 0.0
	add_child(_turn_strip)
	_turn_banner = _text("", F_DISPLAY, 30, TEXT)
	_turn_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_banner.add_theme_color_override("font_shadow_color", Color(MAGENTA, 0.7))
	_turn_banner.add_theme_constant_override("shadow_offset_x", 3)
	_turn_banner.modulate.a = 0.0
	add_child(_turn_banner)
	_turn_rule = ColorRect.new()
	_turn_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_turn_rule.modulate.a = 0.0
	add_child(_turn_rule)
	_banner = _text("", F_DISPLAY, 20, Color("9fb4c4"))
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
	if (font == Hud.F_DISPLAY or font == Hud.F_PIXEL) and s != s.to_upper():   # the pixel face is for caps only
		font = Hud.F_TERM
		size = Hud.ts(size)
	elif (font == Hud.F_DISPLAY or font == Hud.F_PIXEL) and size < 30:   # r7 review: small pixel text drops columns ("UNDERQTY")
		font = Hud.F_BOLD
		size = Hud.ts(size)
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 2 if font != F_PIXEL else 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## A layer that draws with a callable (world-anchored HUD bits: cover shields).
class Painter extends Control:
	var fn: Callable
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if fn.is_valid():
			fn.call(self)


## Segmented, slanted meter (HP, MOVE).
class Meter extends Control:
	var frac := 1.0
	var ghost := -1.0   ## previous value: a pale chunk that holds, then drains (juice)
	var segs := 10
	var col := Color.WHITE
	var label := ""
	func _ready() -> void:
		if ghost > frac:
			var tw := create_tween()
			tw.tween_interval(0.25)
			tw.tween_method(func(v: float):
				ghost = v
				queue_redraw(), ghost, frac, 0.4).set_ease(Tween.EASE_OUT)
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
		var glit := ghost * segs
		for i in segs:
			var x := i * (sw + gap)
			var poly := PackedVector2Array([Vector2(x + h * 0.4, 0), Vector2(x + sw + h * 0.4, 0), Vector2(x + sw, h), Vector2(x, h)])
			var a := clampf(lit - i, 0.0, 1.0)
			draw_colored_polygon(poly, Color(col, 0.16))
			if ghost > frac and clampf(glit - i, 0.0, 1.0) > 0 and a < 1.0:
				draw_colored_polygon(poly, Color(1, 0.85, 0.85, 0.85))
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
			for p in poly:   # square mapping centred on the slot: no stretch whatever its size
				uvs.append(Vector2(0.5 + (p.x - w / 2.0) / h, p.y / h))
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
	var pct := -1
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
			"melee":   # a blade
				draw_colored_polygon(PackedVector2Array([o + Vector2(-r * 1.1, r * 1.1), o + Vector2(r * 0.9, -r * 1.2), o + Vector2(r * 1.2, -r * 0.9), o + Vector2(-r * 0.7, r * 1.2)]), c)
				draw_line(o + Vector2(-r * 0.2, r * 0.2), o + Vector2(r * 0.3, r * 0.7), c, 3.0)
			"shell":   # a spread of pellets
				for i in 5:
					var a := -0.5 + i * 0.25
					draw_circle(o + Vector2(-r, r * 0.6) + Vector2(cos(a - 0.6), sin(a - 0.6)) * r * 2.0, 2.5, c)
				draw_circle(o + Vector2(-r, r * 0.6), 3.0, c)
			"grenade":
				draw_arc(o + Vector2(0, r * 0.25), r * 0.85, 0, TAU, 16, c, 2.0)
				draw_rect(Rect2(o + Vector2(-r * 0.3, -r * 0.95), Vector2(r * 0.6, r * 0.4)), c)
				draw_arc(o + Vector2(r * 0.55, -r * 0.85), r * 0.3, PI * 0.8, PI * 2.2, 8, c, 1.5)
			"suppress":   # rounds raking a line
				for i in 3:
					var y := o.y - r * 0.8 + i * r * 0.8
					draw_line(Vector2(o.x - r * 1.3, y), Vector2(o.x + r * 0.6, y), Color(c, 0.6), 1.0)
					draw_colored_polygon(PackedVector2Array([Vector2(o.x + r * 0.6, y - 3), Vector2(o.x + r * 1.3, y), Vector2(o.x + r * 0.6, y + 3)]), c)
			"medic":
				draw_rect(Rect2(o + Vector2(-r * 0.35, -r), Vector2(r * 0.7, r * 2.0)), c)
				draw_rect(Rect2(o + Vector2(-r, -r * 0.35), Vector2(r * 2.0, r * 0.7)), c)
			"dose":   # an airhypo
				draw_rect(Rect2(o + Vector2(-r * 1.1, -r * 0.3), Vector2(r * 1.5, r * 0.6)), c, false, 2.0)
				draw_line(o + Vector2(r * 0.4, 0), o + Vector2(r * 1.3, 0), c, 2.0)
				draw_line(o + Vector2(-r * 1.1, 0), o + Vector2(-r * 1.5, 0), c, 3.0)
			"rig":   # a wrench
				draw_line(o + Vector2(-r * 1.0, r * 1.0), o + Vector2(r * 0.4, -r * 0.4), c, 3.0)
				draw_arc(o + Vector2(r * 0.6, -r * 0.6), r * 0.5, PI * 0.9, PI * 2.6, 10, c, 2.5)
			"bypass":   # a keypad with a spark
				draw_rect(Rect2(o + Vector2(-r * 0.7, -r * 1.0), Vector2(r * 1.4, r * 2.0)), c, false, 2.0)
				for i in 3:
					for j in 2:
						draw_rect(Rect2(o + Vector2(-r * 0.45 + j * r * 0.55, -r * 0.7 + i * r * 0.55), Vector2(r * 0.35, r * 0.3)), c)
				draw_line(o + Vector2(r * 0.9, -r * 1.2), o + Vector2(r * 1.4, -r * 0.5), Color(Hud.GOLD, c.a), 2.0)
			"keycard":   # a card with a stripe
				draw_rect(Rect2(o + Vector2(-r * 1.1, -r * 0.7), Vector2(r * 2.2, r * 1.4)), c, false, 2.0)
				draw_rect(Rect2(o + Vector2(-r * 1.1, -r * 0.35), Vector2(r * 2.2, r * 0.3)), c)
				draw_rect(Rect2(o + Vector2(r * 0.3, r * 0.15), Vector2(r * 0.5, r * 0.35)), c)
			"tamper":   # a camera with a slash
				draw_rect(Rect2(o + Vector2(-r * 1.0, -r * 0.5), Vector2(r * 1.4, r * 1.0)), c, false, 2.0)
				draw_colored_polygon(PackedVector2Array([o + Vector2(r * 0.4, -r * 0.3), o + Vector2(r * 1.1, -r * 0.6), o + Vector2(r * 1.1, r * 0.6), o + Vector2(r * 0.4, r * 0.3)]), c)
				draw_line(o + Vector2(-r * 1.2, r * 1.0), o + Vector2(r * 1.2, -r * 1.0), Color(Hud.RED, c.a), 2.0)
			"withdraw":   # an exit arrow
				draw_line(o + Vector2(-r * 1.2, 0), o + Vector2(r * 0.9, 0), c, 3.0)
				draw_colored_polygon(PackedVector2Array([o + Vector2(r * 1.3, 0), o + Vector2(r * 0.5, -r * 0.6), o + Vector2(r * 0.5, r * 0.6)]), c)
				draw_rect(Rect2(o + Vector2(-r * 1.4, -r), Vector2(r * 0.3, r * 2.0)), c)
			"plant":   # a charge: a block with a timer
				draw_rect(Rect2(o + Vector2(-r * 1.1, -r * 0.5), Vector2(r * 2.2, r * 1.2)), c, false, 2.0)
				draw_rect(Rect2(o + Vector2(-r * 0.5, -r * 0.25), Vector2(r * 1.0, r * 0.6)), Color(Hud.RED, c.a))
				draw_line(o + Vector2(r * 0.6, -r * 0.5), o + Vector2(r * 1.0, -r * 1.1), c, 2.0)
			"free":   # a broken shackle
				draw_arc(o + Vector2(-r * 0.6, 0), r * 0.55, 0.0, TAU, 12, c, 2.0)
				draw_arc(o + Vector2(r * 0.6, 0), r * 0.55, PI * 0.25, PI * 1.75, 12, c, 2.0)
				draw_line(o + Vector2(-r * 0.05, -r * 0.9), o + Vector2(r * 0.25, -r * 0.4), Color(Hud.GOLD, c.a), 2.0)
			"grab":   # a case with a handle
				draw_rect(Rect2(o + Vector2(-r * 1.1, -r * 0.4), Vector2(r * 2.2, r * 1.4)), c, false, 2.0)
				draw_rect(Rect2(o + Vector2(-r * 0.4, -r * 0.9), Vector2(r * 0.8, r * 0.5)), c, false, 2.0)
				draw_line(o + Vector2(-r * 1.1, r * 0.25), o + Vector2(r * 1.1, r * 0.25), c, 1.5)
			"end":
				draw_colored_polygon(PackedVector2Array([o + Vector2(-r * 1.2, -r), o + Vector2(r * 0.2, 0), o + Vector2(-r * 1.2, r)]), c)
				draw_colored_polygon(PackedVector2Array([o + Vector2(0, -r), o + Vector2(r * 1.4, 0), o + Vector2(0, r)]), c)
		var fs := Hud.ts(17)   # shrink to fit long titles (WITHDRAW, SUPPRESS)
		while fs > 8 and Hud.F_BOLD.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w - 4:
			fs -= 1
		draw_string(Hud.F_BOLD, Vector2(0, size.y - 7), title, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(Hud.TEXT, 0.45 if disabled else 1.0))
		if pct >= 0 and not disabled:   # live hit chance for this mode on the hovered target
			var pc := Hud.GREEN if pct >= 65 else (Hud.GOLD if pct >= 35 else Hud.RED)
			draw_string(Hud.F_BOLD, Vector2(4, 16), "%d%%" % pct, HORIZONTAL_ALIGNMENT_LEFT, 40, 14, pc)
		var kw := maxf(38.0, Hud.F_TERM.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x)   # room for "TAB 2/4"
		draw_string(Hud.F_TERM, Vector2(w - kw - 4, 16), key, HORIZONTAL_ALIGNMENT_RIGHT, kw, 14, Color(Hud.TEXT if not disabled else Hud.DIM, 0.85 if not disabled else 0.5))


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
	_card_sep = sep
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 8)
	row.add_child(mid)
	_econ = HBoxContainer.new()
	_econ.add_theme_constant_override("separation", 12)
	mid.add_child(_econ)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 5)
	mid.add_child(_buttons)
	# Main bar: the core actions in a fixed order (letters only); a slot hides when it can't apply.
	for spec in MAIN_ACTIONS:
		var b3 := ActBtn.new(spec[0], spec[1], spec[2], spec[5])
		b3.toggle_mode = spec[3] in ["tool", "kit", "stage"]
		var arg: Variant = spec[4]
		var act: String = spec[3]
		b3.pressed.connect(func(): action.emit(act, arg))
		_tool_buttons[spec[0]] = b3
		_buttons.add_child(b3)
	# Attack stage: the weapons you carry (drawing one is free, p.128), then what the drawn one can do.
	_atk_buttons = HBoxContainer.new()
	_atk_buttons.add_theme_constant_override("separation", 5)
	_atk_buttons.visible = false
	mid.add_child(_atk_buttons)
	_end_btn = ActBtn.new("end", "END TURN", "SPC", GOLD, 96, 66)
	_end_btn.pressed.connect(func(): action.emit("end_turn", null))
	row.add_child(_end_btn)
	add_child(_bar)
	_withdraw_btn = ActBtn.new("withdraw", "WITHDRAW", "L", RED, 96, 66)
	_withdraw_btn.pressed.connect(func(): action.emit("withdraw", null))
	_withdraw_btn.visible = false
	add_child(_withdraw_btn)


func _layout() -> void:
	var s := size
	_party.position = Vector2(14 if roster_on else -_party.size.x - 30, (hint_tab.position.y + hint_tab.size.y + 10) if hint_tab else 70.0)
	_init_strip.position = Vector2(s.x / 2 - _init_strip.size.x / 2, 12)
	_bar.position = Vector2(s.x / 2 - _bar.size.x / 2, s.y - _bar.size.y - 12)
	_place_withdraw()
	# log: bottom left, above the bar
	_log_panel.position = Vector2(14, _bar.position.y - _log_panel.size.y - 10)
	_net_panel.reset_size()   # it shrinks as rows go (a held turret's targets come and go)
	var net_y := _round_tab.position.y + _round_tab.size.y + 30
	net_y = maxf(_round_tab.position.y + _round_tab.size.y + _overlay_lbl.size.y + 10, minf(net_y, _bar.position.y - _net_panel.size.y - 10))   # never over the action bar or the overlay line
	_net_panel.position = Vector2(s.x - _net_panel.size.x - 14, net_y)
	_toast.position = Vector2(s.x / 2 - 400, 148)   # under the turn banner and its rule (y 100-136), never over them
	_toast.size = Vector2(800, 40)
	_banner_panel.position = Vector2(14, 12)
	_round_tab.position = Vector2(s.x - _round_tab.size.x - 14, 12)
	_overlay_lbl.reset_size()
	_overlay_lbl.position = Vector2(s.x - _overlay_lbl.size.x - 20, _round_tab.position.y + _round_tab.size.y + 4)
	if hint:   # top left, under the banner: clear of the unit card however wide the bar gets
		hint.reset_size()
		var top := _banner_panel.position.y + _banner_panel.size.y + 8
		hint.position = Vector2(14, top)
		hint_tab.position = Vector2(14, top)


func _clear(c: Node) -> void:
	for ch in c.get_children():
		c.remove_child(ch)
		ch.queue_free()


# --- Updates -----------------------------------------------------------------------

func _team_col(u: Dictionary, enc: Encounter = null) -> Color:
	if u.team == 0:
		return UnitLook.CREW_ACCENTS[u.id % 4]
	return RED if enc == null or enc.hostile(Encounter.CREW, int(u.team)) else NEUTRAL


## The hazard zone's line on the round tab: "MIST CLOSES IN 2", "MIST · FINAL CIRCLE", and when
## the active crew member stands outside it, what that costs a turn.
static func hazard_text(enc: Encounter) -> String:
	var z := enc.hazard
	var n := z.closes_in(enc.init.round_num)
	var s := "%s CLOSES IN %d" % [z.name, n] if n > 0 else ("%s CLOSING" % z.name if n == 0 else "%s · FINAL CIRCLE" % z.name)
	if not enc.cur.is_empty() and enc.cur.team == Encounter.CREW and z.bites("crew", enc.cur.pos):
		s += " · OUTSIDE %dD6" % z.damage_dice()
	return s


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
		var slot := Slot.new(portraits.tex(u), _team_col(u, enc), u == enc.cur, float(maxi(c.hp, 0)) / c.max_hp(), c.display_name.to_upper(), c.dead)
		slot.material = portraits.material()
		slot.modulate = Portraits.tint(c.wound_state())
		_init_strip.add_child(slot)
	_clear(_round_box)   # round and stealth state: top right corner
	_round_box.add_child(_text("ROUND %02d" % maxi(1, enc.init.round_num) + ("  ·  " + leg_text if leg_text != "" else ""), F_TERM, Hud.ts(20), CYAN))
	var state := "UNDETECTED"
	if enc.alarm >= 2:
		state = "ALARM · %s %d" % [enc.backup_label, enc.backup_in] if enc.backup_in > 0 else ("ALARM · %s %d" % [enc.ncpd_label, enc.ncpd_in] if enc.ncpd_in > 0 else "ALARM")
	elif enc.engaged():
		state = "ENGAGED"
	_round_box.add_child(_text(state, F_DISPLAY, 20, RED if state != "UNDETECTED" else CYAN))
	_round_box.add_child(_text(objective_text(enc), F_TERM, Hud.ts(18), GOLD))
	if not enc.outages.is_empty():   # Utility Codes (NC2045 p.8)
		_round_box.add_child(_text(" · ".join(enc.outages.map(func(o): return String(o).to_upper() + " OUT")), F_TERM, Hud.ts(18), RED))
	if enc.hazard != null:   # a shrinking safe circle (HazardZone: the Combat Zone's MIST)
		_round_box.add_child(_text(hazard_text(enc), F_TERM, Hud.ts(18), RED if enc.hazard.stage > 0 else GOLD))
	if enc.neutral != null:   # a house where nobody fights (NeutralGround: Totentanz's club floor)
		_round_box.add_child(_text(enc.neutral.hud_text(), F_TERM, Hud.ts(18), GOLD if enc.neutral.holds else RED))
	if not enc.complication.is_empty():   # the book's complication (Complication), shown once it springs
		var cx := _text("COMPLICATION · " + String(enc.complication.text).to_upper(), F_TERM, Hud.ts(18), RED)
		cx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cx.custom_minimum_size.x = 260
		_round_box.add_child(cx)
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
		nv.add_child(_text(c.display_name.to_upper(), F_DISPLAY, 40, GOLD if crew_turn else RED))
		nv.add_child(_text(c.role.to_upper() + "  ·  " + ["UNHURT", "LIGHT WOUNDS", "SERIOUS WOUNDS", "MORTAL", "DEAD"][c.wound_state()], F_DISPLAY, 20, CYAN if crew_turn else RED))
		_card.add_child(top)
		var hp := HBoxContainer.new()
		hp.add_theme_constant_override("separation", 8)
		hp.alignment = BoxContainer.ALIGNMENT_BEGIN
		var hm := _hp_meter(enc.cur.id, c, 150, 12)
		hm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hp.add_child(hm)
		hp.add_child(_text("%d/%d HP" % [c.hp, c.max_hp()], F_TERM, Hud.ts(20), _hp_col(c)))
		_card.add_child(hp)
		_card.add_child(_text("ARMOR  [HEAD %d]  [BODY %d]" % [c.sp("head"), c.sp("body")], F_TERM, Hud.ts(20), TEXT))
		if not c.injuries.is_empty():
			_card.add_child(_text("! " + ", ".join(c.injuries.map(func(i): return String(i.get("name", i.id)))).to_upper(), F_TERM, Hud.ts(20), RED))
		var t := enc.turn
		var act := t.action_available or t.attacks_left > 0
		_econ.add_child(_text("◆ ACTION" if act else "◇ ACTION", F_DISPLAY, 20, CYAN if act else Color(DIM, 0.6)))
		var mv := t.squares_available()
		var mvmax := maxi(1, c.stat("MOVE"))
		_econ.add_child(_text("MOVE %d · %d M" % [mv, mv * 2], F_DISPLAY, 20, CYAN if mv > 0 else Color(DIM, 0.6)))   # a square is 2 m (p.127)
		var mm := Meter.new(float(mv) / mvmax, mvmax, CYAN, 100, 11)
		mm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_econ.add_child(mm)
		var exhausted := not act and mv == 0
		(_end_btn as ActBtn).tint = GOLD if exhausted else Color("8a96a0")
		var w: Weapon = c.weapons[0] if not c.weapons.is_empty() else null
		if stage == "attack":
			_econ.add_child(_text("▸ " + String(ATK_MODES.get(atk_mode, ["", "", ""])[2]).to_upper(), F_DISPLAY, 20, GOLD))
		_econ.add_child(_text(("%s  %s" % [w.display_name().to_upper(), "JAMMED · R TO CLEAR" if w.jammed else (("%02d/%02d" % [w.ammo, int(w.def.get("mag", 0))]) if w.uses_ammo() else "")]) if w else "UNARMED", F_TERM, Hud.ts(20), TEXT))
		if enc.runs.has(enc.cur.id):
			_econ.add_child(_text("◆ NET %d" % enc.net_left, F_PIXEL, 20, Color("d68cff")))
	_refresh_tools(enc, crew_turn)
	_end_btn.disabled = not crew_turn
	_end_btn.queue_redraw()
	if not log_hold:
		var fresh := enc.log.size() != _log_lines.size()
		_log_lines = enc.log.duplicate()
		_show_log(fresh)
	_banner.text = floor_text
	_banner.add_theme_color_override("font_color", GOLD if not floor_text.ends_with("FLOOR 1") else Color("9fb4c4"))   # gold off the street floor
	_net_refresh(enc)
	for u2 in enc.units:   # remember what the bars showed, for the next ghost drain
		_hp_seen[u2.id] = float(maxi(u2.c.hp, 0)) / u2.c.max_hp()
	if enc.state != "playing":
		toast(end_toast if end_toast != "" else "GIG %s" % ("COMPLETE" if enc.state == "won" else ("ABANDONED" if enc.state == "fled" else "FAILED")), 1e9)
	_layout.call_deferred()


## The gig's goal in a few words, for the round tab.
static func objective_text(enc: Encounter) -> String:
	return enc.obj.hud_text()


## The interact action that applies where the active unit stands (B): [signal, title, glyph], or [].
static func interact_here(enc: Encounter) -> Array:
	var objs := enc.obj_actions()
	if not objs.is_empty():
		return [String(objs[0]), String(objs[0]).to_upper(), String(objs[0])]
	if enc.keycard_in_reach(enc.cur).size() > 0:
		return ["keycard", "KEYCARD", "keycard"]
	if enc.lock_in_reach(enc.cur).x >= 0:
		return ["bypass", "BYPASS", "bypass"]
	if not enc.camera_in_reach(enc.cur).is_empty():
		return ["tamper", "CAMERA", "tamper"]
	return []


## The active unit's role ability on V: [tool, title, glyph] (Medtech Pharmaceuticals, Tech
## Field Expertise), or [].
static func role_action(c: Combatant) -> Array:
	if c.role == "medtech" and c.doses > 0:
		return ["dose", "DOSE", "dose"]
	if int(c.maker.get("field", 0)) > 0:
		return ["rig", "RIG", "rig"]
	return []


## Main bar: show what applies to the active unit, dim what costs an Action once it's spent.
## Attack stage: the weapon tabs and the drawn weapon's attacks replace it.
func _refresh_tools(enc: Encounter, crew_turn: bool) -> void:
	if _tool_buttons.is_empty() or enc.cur.is_empty():
		return
	var c: Combatant = enc.cur.c
	var t := enc.turn
	var can_act := t.action_available or t.attacks_left > 0
	var near_dying := enc.units.any(func(o): return o.team == enc.cur.team and o != enc.cur and not o.c.dead \
		and o.c.wound_state() == Combatant.Wound.MORTAL and enc.can_reach_to_stabilize(enc.cur, o))
	var here := interact_here(enc)
	var role := role_action(c)
	var jacked := enc.runs.has(enc.cur.id)
	var show := {"shot": true, "reload": not c.weapons.is_empty() and c.weapons[0].uses_ammo(), "kit0": enc.kit_action(0) in ["grenade", "dose"],
		"jack": NetRun.interface_rank(c) > 0, "interact": not here.is_empty(), "medic": near_dying, "role": not role.is_empty()}
	for k in _tool_buttons:
		var b: ActBtn = _tool_buttons[k]
		b.visible = show[k]
		b.disabled = not crew_turn or (k != "jack" and not can_act) or (k == "reload" and not t.action_available)
		var armed: bool = {"shot": stage == "attack", "kit0": tool == "grenade", "medic": tool == "stabilize",
			"role": not role.is_empty() and tool == String(role[0])}.get(k, false)
		b.set_pressed_no_signal(b.toggle_mode and armed)
		match k:
			"kit0":
				if b.visible:   # the packed item: its own name and glyph
					b.title = Items.short_name(c.kit[0])
					b.glyph = "grenade" if Items.use(c.kit[0]) == "grenade" else "dose"
			"reload":   # always the weapon in hand (the one named in the header); Tab draws another first
				if b.visible:
					var wr: Weapon = c.weapons[0]
					b.tooltip_text = "Reload the %s in hand (%d/%d)" % [wr.display_name(), wr.ammo, wr.mag()]
					b.disabled = b.disabled or wr.ammo >= wr.mag() and not wr.jammed
			"jack":
				b.title = "JACK OUT" if jacked else "JACK IN"
			"interact":
				if b.visible:
					b.title = String(here[1])
					b.glyph = String(here[2])
			"role":
				if b.visible:
					b.title = String(role[1])
					b.glyph = String(role[2])
		b.queue_redraw()
	_buttons.visible = stage != "attack"
	_atk_buttons.visible = stage == "attack"
	_card.visible = stage != "attack"   # the attack stage gets the whole bar, so its buttons stay full size (owner)
	_card_sep.visible = _card.visible
	if stage != "attack":
		_wheel_idx = -1
	if stage == "attack":
		_build_attack_stage(enc, crew_turn and can_act)
	_bar.reset_size()
	_withdraw_btn.visible = crew_turn and enc.can_withdraw()   # owner: only shown once the crew can leave
	_withdraw_btn.disabled = false
	_withdraw_btn.queue_redraw()
	_place_withdraw()


var _atk_mode_btns := {}   ## mode id → ActBtn in the attack stage (for live hit chances)
var _card_sep: ColorRect   ## between the unit card and the actions (hidden with the card in the attack stage)
var _wheel: Control          ## the attack stage's weapon slot: one weapon shown, the rest stacked above/below
var _wheel_col: VBoxContainer
var _wheel_idx := -1         ## which weapon the slot shows (-1: not shown yet, so no slide)
var _wheel_tw: Tween
const WHEEL_W := 96.0
const WHEEL_H := 66.0


## One slot for the weapon in hand; Tab (or a click) slides the stack vertically to the next one
## (owner: keeps the bar narrow). A "2/4" count in the corner says how many you carry.
func _build_wheel(tabs: Array, drawn: Weapon, usable: bool) -> void:
	if _wheel == null:
		_wheel = Control.new()
		_wheel.clip_contents = true
		_wheel.custom_minimum_size = Vector2(WHEEL_W, WHEEL_H)
		_wheel_col = VBoxContainer.new()
		_wheel_col.add_theme_constant_override("separation", 0)
		_wheel.add_child(_wheel_col)
		_atk_buttons.add_child(_wheel)
		_atk_buttons.move_child(_wheel, 0)
	for ch in _wheel_col.get_children():
		_wheel_col.remove_child(ch)
		ch.queue_free()
	var idx := tabs.size() - 1 if atk_mode == "brawl" else maxi(0, tabs.find(drawn))
	for i in tabs.size():
		var w: Weapon = tabs[i]
		var nm := w.display_name().to_upper() if w else "BRAWLING"
		var tb := ActBtn.new("melee" if w == null or w.is_melee() else "shot", nm, "TAB %d/%d" % [i + 1, tabs.size()], GOLD, WHEEL_W, WHEEL_H)
		tb.toggle_mode = true
		tb.set_pressed_no_signal(true)
		tb.disabled = not usable
		tb.pressed.connect(func(): action.emit("draw_next", null))
		_wheel_col.add_child(tb)
	var target := -idx * WHEEL_H
	if _wheel_tw and _wheel_tw.is_valid():
		_wheel_tw.kill()
	if _wheel_idx < 0 or _wheel_idx == idx:
		_wheel_col.position.y = target
	else:   # slide: the next weapon comes up from below (back to the top after the last)
		_wheel_tw = create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		_wheel_tw.tween_property(_wheel_col, "position:y", target, 0.2)
	_wheel_idx = idx


## The attack stage's weapon tabs in a stable order (as acquired; drawing reorders c.weapons) and
## null for Brawling at the end.
static func weapon_tabs(c: Combatant) -> Array:
	var ws: Array = c.weapons.duplicate()
	ws.sort_custom(func(a, b): return a.get_instance_id() < b.get_instance_id())
	ws.append(null)
	return ws


## The attack stage: one tab per weapon carried plus Brawling (Tab cycles, drawing is free), then
## the drawn weapon's attacks by the book's names (F cycles), then BACK (Esc).
func _build_attack_stage(enc: Encounter, usable: bool) -> void:
	for ch in _atk_buttons.get_children():
		if ch == _wheel:
			continue   # the weapon slot persists so it can slide
		_atk_buttons.remove_child(ch)
		ch.queue_free()
	_atk_mode_btns.clear()
	var c: Combatant = enc.cur.c
	var drawn: Weapon = c.weapons[0] if not c.weapons.is_empty() else null
	var tabs := weapon_tabs(c)
	_build_wheel(tabs, drawn, usable)
	var sep := ColorRect.new()
	sep.custom_minimum_size = Vector2(1, 50)
	sep.color = Color(CYAN, 0.35)
	_atk_buttons.add_child(sep)
	var modes := Encounter.attack_modes(null if atk_mode == "brawl" else drawn)
	var aiming := atk_mode.begins_with("aim_")
	for m in modes:
		if m in ["aim_leg", "aim_held"]:
			continue   # one AIMED SHOT button: clicking it again moves the aim (head → leg → held item)
		var shown := atk_mode if (m == "aim_head" and aiming) else m
		var spec: Array = ATK_MODES[shown]
		var on: bool = shown == atk_mode or (m == "melee" and atk_mode == "brawl")
		if m == "melee" and atk_mode == "brawl":
			spec = ATK_MODES["brawl"]
		var mb := ActBtn.new(String(spec[1]), String(spec[0]), "F" if on else "", CYAN)
		mb.tooltip_text = String(spec[2])
		mb.toggle_mode = true
		mb.set_pressed_no_signal(on)
		mb.disabled = not usable
		var next := m
		if m == "aim_head" and aiming:
			next = {"aim_head": "aim_leg", "aim_leg": "aim_held", "aim_held": "aim_head"}[atk_mode]
		mb.pressed.connect(func(): action.emit("atk_mode", next))
		_atk_buttons.add_child(mb)
		_atk_mode_btns[shown] = mb
	var back := ActBtn.new("", "BACK", "ESC", Color("8a96a0"))
	back.pressed.connect(func(): action.emit("stage", "main"))
	_atk_buttons.add_child(back)
	# fit the screen: narrower buttons when the weapon has many options
	var n := _atk_buttons.get_child_count() - 1
	var badge := (hint_tab.size.x + 16.0) if hint_tab else 0.0
	var room := get_viewport_rect().size.x - 28 - 96 - 2.0 * badge   # no unit card in this stage
	var bw := clampf((room - WHEEL_W) / maxf(1.0, n - 1) - 5.0, 48.0, 66.0)
	bw = 66.0 if room - WHEEL_W >= (n - 1) * 71.0 else bw   # full size whenever it fits (owner)
	for ch in _atk_buttons.get_children():
		if ch is ActBtn:
			(ch as ActBtn).custom_minimum_size.x = bw


## Over the END TURN button, just above the bar's right end.
func _place_withdraw() -> void:
	if _withdraw_btn and _end_btn:
		_withdraw_btn.custom_minimum_size = Vector2(_end_btn.size.x, 66)
		_withdraw_btn.size = _withdraw_btn.custom_minimum_size
		_withdraw_btn.position = Vector2(_bar.position.x + _end_btn.get_global_transform().origin.x - _bar.get_global_transform().origin.x, _bar.position.y - 66 - 8)
		if _net_panel.visible and _net_panel.get_rect().intersects(_withdraw_btn.get_rect()):   # jacked in: over the bar's left end instead
			_withdraw_btn.position.x = _bar.position.x + 12


func _hp_meter(uid: int, c: Combatant, w: float, h: float) -> Meter:
	var f := float(maxi(c.hp, 0)) / c.max_hp()
	var mt := Meter.new(f, c.max_hp() / 5, _hp_col(c), w, h)
	var prev: float = _hp_seen.get(uid, f)
	if prev > f + 0.001:
		mt.ghost = prev
	return mt


func _hp_col(c: Combatant) -> Color:
	var f := float(c.hp) / c.max_hp()
	return GREEN if f > 0.6 else (GOLD if f > 0.3 else RED)


func _party_card(u: Dictionary, active: bool) -> Control:
	var c: Combatant = u.c
	var p := PanelContainer.new()
	_cards[u.id] = p
	p.add_theme_stylebox_override("panel", CutBox.make(INK, GOLD if active else Color(_team_col(u), 0.45), 10, 0b0101, GOLD if active else Color(0, 0, 0, 0), 6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	p.add_child(h)
	var face := TextureRect.new()
	face.texture = portraits.tex(u)
	face.material = portraits.material()
	face.modulate = Portraits.tint(c.wound_state() if not c.dead else 4)
	face.custom_minimum_size = Vector2(64, 64)   # 2x the 32 px render
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if c.dead:
		face.modulate = Color(1, 1, 1, 0.3)
	h.add_child(face)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	v.add_child(_text(c.display_name.to_upper(), F_DISPLAY, 30, GOLD if active else TEXT))
	v.add_child(_text(c.role.to_upper(), F_DISPLAY, 20, DIM))
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 6)
	var hm := _hp_meter(u.id, c, 80, 9)
	hm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(hm)
	hr.add_child(_text("%d/%d" % [c.hp, c.max_hp()], F_TERM, Hud.ts(20), _hp_col(c)))
	v.add_child(hr)
	var w: Weapon = c.weapons[0] if not c.weapons.is_empty() else null
	v.add_child(_text(("%s %s" % [w.display_name().to_upper(), ("%d/%d" % [w.ammo, int(w.def.get("mag", 0))]) if w.uses_ammo() else ""]) if w else "UNARMED", F_TERM, Hud.ts(16), DIM))
	var cond := conditions(c)
	if not cond.is_empty():
		var cl := _text(" · ".join(cond).to_upper(), F_TERM, Hud.ts(16), RED)
		cl.custom_minimum_size.x = 200
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(cl)
	return p


## A combatant as a dark take on the book's NPC stat blocks (CPR core p.412-416): labels dim,
## values bright. `full` (Alt inspect) adds every STAT, Seriously Wounded / Death Save, all the
## weapons, the top skills, cyberware and kit; the compact one is for hovering a target.
static func stat_block(c: Combatant, full: bool, extra: Array = []) -> String:
	const K := "[color=#7d8a96]%s[/color]"
	var out: Array[String] = ["[b]%s[/b]  [color=#7d8a96]%s[/color]" % [c.display_name, c.kind_name()]]
	var stats: Array = ["INT", "REF", "DEX", "TECH", "COOL", "WILL", "LUCK", "MOVE", "BODY", "EMP"] if full else ["REF", "DEX", "BODY", "MOVE"]
	if stats.any(func(st): return c.stat(st) != 0):   # a turret has no STATs (p.214): no row of zeros
		var tb := "[table=%d]" % mini(5, stats.size())   # rows of five, like the book's STAT line split in two
		for row in range(0, stats.size(), 5):
			var part: Array = stats.slice(row, row + 5)
			for st in part:
				tb += "[cell][code]" + (K % st) + "  [/code][/cell]"
			for st in part:
				tb += "[cell][code]%d[/code][/cell]" % c.stat(st)
		out.append(tb + "[/table]")
	var hp := (K % "HP") + " %d/%d" % [c.hp, c.max_hp()]
	if full:
		hp += "  [color=#7d8a96]·[/color] " + ["Unhurt", "Lightly Wounded", "Seriously Wounded", "Mortally Wounded", "Dead"][c.wound_state()] + "  " + (K % "DEATH SAVE") + " %d" % c.death_save_target()   # Seriously Wounded is always half HP: not worth a line (owner)
	else:
		hp += "  [color=#7d8a96]·[/color] " + ["Unhurt", "Lightly Wounded", "Seriously Wounded", "Mortally Wounded", "Dead"][c.wound_state()]
	out.append(hp)
	out.append((K % "ARMOR") + " head SP %d · body SP %d" % [c.sp("head"), c.sp("body")])
	var ws: Array = c.weapons if full else c.weapons.slice(0, 1)
	for w in ws:
		var q := "" if w.quality == "standard" else " (%s)" % w.quality.capitalize()
		var ap := " AP" if w.special_left > 0 and int(w.special_fx.get("ablate_sp", 1)) > 1 else ""   # a VH Pistol turret's AP rounds (Turret)
		out.append((K % "WEAPON") + " %s%s · %dd6 · ROF %d%s" % [w.def.name, q, w.dice(), w.rof(), (" · %d/%d%s" % [w.ammo, int(w.def.get("mag", 0)), ap]) if w.uses_ammo() else ""])
	if full:
		var sk: Array = c.skills.keys().filter(func(k): return int(c.skills[k]) > 0)
		sk.sort_custom(func(a, b): return c.skill_base(a) > c.skill_base(b))
		if not sk.is_empty():
			out.append((K % "SKILLS") + " " + ", ".join(sk.slice(0, 8).map(func(k): return "%s %d" % [String(k).replace("_", " ").capitalize(), c.skill_base(k)])))
		if not c.cyberware.is_empty():
			out.append((K % "CYBERWARE") + " " + ", ".join(c.cyberware.map(func(x): return String(RulesDB.cyberware(String(x)).get("name", x)))))
		var kit: Array = c.kit.filter(func(k): return k != "")
		if not kit.is_empty():
			out.append((K % "KIT") + " " + ", ".join(kit.map(func(k): return Items.display_name(String(k)))))
	var cond: Array = conditions(c) + extra
	if not cond.is_empty():
		out.append((K % "CONDITIONS") + " [color=#ff3b4f]%s[/color]" % ", ".join(cond))
	return "\n".join(out)


## What's wrong with someone at a glance: injuries, status, drugs, chrome knocked out.
static func conditions(c: Combatant) -> Array[String]:
	var out: Array[String] = []
	if c.unconscious:
		out.append("unconscious")
	if c.prone:
		out.append("prone")
	if c.burning > 0:
		out.append("on fire")
	for i in c.injuries:
		out.append(String(i.get("name", i.id)))
	for d in c.drugs_taken:
		out.append(String(d).replace("_", " "))
	if not c.cyber_off.is_empty():
		out.append("chrome offline")
	return out


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
	var pos := at + Vector2(28, 20)   # beside the cursor; flips left / up rather than covering it
	if pos.x + _tip.size.x > size.x - 4:
		pos.x = at.x - 28 - _tip.size.x
	if pos.y + _tip.size.y > size.y - 4:
		pos.y = at.y - 20 - _tip.size.y
	pos = pos.clamp(Vector2.ZERO, size - _tip.size - Vector2(4, 4))
	for r in [_round_tab.get_rect(), _init_strip.get_rect(), _net_panel.get_rect() if _net_panel.visible else Rect2()]:   # never cover the fixed panels
		if r.size.x > 0 and Rect2(pos, _tip.size).intersects(r):
			pos.y = r.end.y + 8
	_tip.position = pos.clamp(Vector2.ZERO, size - _tip.size - Vector2(4, 4))


## Turn banner, tucked under the turn-order strip (owner: less obtrusive, keep the style). It
## glitches in: the magenta split starts wide and snaps shut while the text slides a few pixels,
## an underline wipes across in the banner colour, then everything fades.
func turn_banner(text: String, col: Color) -> void:
	if _banner_tw and _banner_tw.is_valid():
		_banner_tw.kill()
	_turn_banner.text = text
	_turn_banner.add_theme_color_override("font_color", col)
	_turn_banner.reset_size()
	var w := _turn_banner.get_minimum_size().x
	var y := 100.0   # just under the turn-order strip (its size isn't settled yet on a new turn)
	var x := size.x / 2 - w / 2
	_turn_banner.position = Vector2(x + 24, y)
	_turn_banner.modulate.a = 0.0
	_turn_banner.add_theme_constant_override("shadow_offset_x", 10)
	_turn_rule.color = col
	_turn_rule.position = Vector2(x, y + 34)
	_turn_rule.size = Vector2(0, 2)
	_turn_rule.modulate.a = 1.0
	_turn_strip.position = Vector2(x - 18, y - 4)   # owner: a dark strip under every banner, rule included
	_turn_strip.size = Vector2(w + 36, 44)
	_turn_strip.modulate.a = 0.0
	var tw := create_tween()
	_banner_tw = tw
	tw.tween_property(_turn_banner, "position:x", x, 0.18).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_turn_banner, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_property(_turn_strip, "modulate:a", 1.0, 0.1)
	tw.parallel().tween_method(func(v: int): _turn_banner.add_theme_constant_override("shadow_offset_x", v), 10, 2, 0.22)
	tw.parallel().tween_property(_turn_rule, "size:x", w, 0.26).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.9)
	tw.tween_property(_turn_banner, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_property(_turn_rule, "modulate:a", 0.0, 0.25)
	tw.parallel().tween_property(_turn_strip, "modulate:a", 0.0, 0.25)


func _show_log(fresh := false) -> void:
	var n := 14 if _log_open else 3
	_log.text = "\n".join(_log_lines.slice(maxi(0, _log_lines.size() - n)).map(func(l): return "> " + l))
	_log_panel.visible = not _log_lines.is_empty()
	_log_panel.reset_size()
	if _log_tw and _log_tw.is_valid():
		_log_tw.kill()
	if _log_open or fresh:   # new lines show at full strength, then fade back after a few seconds
		_log_panel.modulate.a = 1.0
	if not _log_open:
		_log_tw = create_tween()
		_log_tw.tween_interval(5.0)
		_log_tw.tween_property(_log_panel, "modulate:a", 0.35, 0.6)
	_layout.call_deferred()


## Slide the crew roster in (Alt held) or out.
func show_roster(on: bool) -> void:
	roster_on = on
	var tw := create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(_party, "position:x", 14.0 if on else -_party.size.x - 30, 0.16)


## Which view overlays are on, shown small under the round tab.
func set_overlays(text: String) -> void:
	_overlay_lbl.text = text
	_layout.call_deferred()


## A one-frame-ish full-screen flash (crits, alerts).
func flash_screen(col: Color) -> void:
	_flash.color = col
	create_tween().tween_property(_flash, "color:a", 0.0, 0.18)


## Red scanlined edge glow for the whole enemy phase.
func enemy_phase(on: bool) -> void:
	create_tween().tween_property(_vignette.material, "shader_parameter/amount", 0.55 if on else 0.0, 0.25)


## A unit was hurt: its party card shakes and flashes red.
func hit_unit(uid: int) -> void:
	var card: Control = _cards.get(uid)
	if card == null or not is_instance_valid(card):
		return
	var tw := create_tween()
	for k in 4:
		tw.tween_property(card, "position:x", card.position.x + (3 if k % 2 == 0 else -3), 0.03)
	tw.tween_property(card, "position:x", card.position.x, 0.03)
	card.modulate = Color(1.6, 0.6, 0.6)
	create_tween().tween_property(card, "modulate", Color.WHITE, 0.18)


## Hit chance per attack while a target is hovered (mode id → %; empty clears): on the attack
## stage's buttons, and Single Shot's on the main bar's ATTACK.
func mode_pcts(pcts: Dictionary) -> void:
	for k in _atk_mode_btns:
		var b: ActBtn = _atk_mode_btns[k]
		if is_instance_valid(b):
			b.pct = pcts.get(k, -1)
			b.queue_redraw()
	var shot: ActBtn = _tool_buttons.get("shot")
	if shot:
		shot.pct = pcts.get(atk_mode, pcts.get("single", -1))
		shot.queue_redraw()


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
	b.add_theme_font_size_override("font_size", ts(18))
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
	var ice_db: Dictionary = RulesDB.load_json("black_ice.json")["ice"]
	_net_box.add_child(_text("// JACKED IN · %d NET ACTION%s" % [enc.net_left, "" if enc.net_left == 1 else "S"], F_PIXEL, 20, MAGENTA))
	var here := run.cur_node()
	_net_box.add_child(_text(_node_label(here, enc, run, true).to_upper(), F_DISPLAY, 20, Color("e2c8ff")))
	var status: Array[String] = []
	if run.armor_rez > 0:
		status.append("ARMOR ON")
	for p in run.runner.programs:
		if run.lost.has(p):
			status.append(p.to_upper() + " DESTROYED")
	if run.runner.burning:
		status.append("ON FIRE")
	if run.kraken_until >= enc.init.round_num:
		status.append("KRAKEN HOLD")
	if run.rank() < NetRun.interface_rank(run.runner):
		status.append("WOUNDED -%d" % (NetRun.interface_rank(run.runner) - run.rank()))
	if not status.is_empty():
		_net_box.add_child(_text(" · ".join(status), F_TERM, Hud.ts(18), GOLD))
	var ice := run.arch.ice_at(run.current)
	for i in ice:
		var st: Dictionary = ice_db[i.kind]
		_net_box.add_child(_text("!! %s  ATK %d DEF %d PER %d · REZ %d/%d" % [String(i.kind).to_upper(), int(st.atk), int(st.def), int(st.per), int(i.get("rez", st.rez)), int(st.rez)], F_TERM, Hud.ts(18), RED))
		_net_box.add_child(_text("   " + String(st.get("effect", "")), F_TERM, Hud.ts(16), Color(RED, 0.75)))
	# Only the actions that apply here, each with its odds.
	var acts := VBoxContainer.new()   # one row per option (owner)
	acts.add_theme_constant_override("separation", 3)
	var none := enc.net_left <= 0
	var add := func(label: String, kind: String, enabled := true):
		var nb := _net_button(label, func(): action.emit("net", kind), 296, 28, none or not enabled)
		nb.tooltip_text = "DV: the Difficulty Value; Interface + 1d10 must beat it" if label.contains("DV") else ""
		acts.add_child(nb)
	match String(here.type):
		"firewall":
			if not run.broken.has(run.current):
				add.call("BACKDOOR %d%% · DV%d" % [roundi(run.chance(int(here.dv)) * 100), int(here.dv)], "backdoor")
		"control":
			if not run.held.has(run.current):
				add.call("CONTROL %d%% · DV%d" % [roundi(run.chance(int(here.dv)) * 100), int(here.dv)], "control")
		"file":
			if not run.identified.has(run.current):
				add.call("EYE-DEE %d%% · DV%d" % [roundi(run.chance(int(here.dv)) * 100), int(here.dv)], "eye_dee")
		"socket":
			add.call("CROSS SOCKET", "cross")
	if not ice.is_empty():
		var st0: Dictionary = ice_db[ice[0].kind]
		add.call("ZAP %d%% · 1d6" % roundi(Check.chance_opposed(run.rank(), int(st0.def)) * 100), "zap")
		if run.has_program("sword"):
			add.call("SWORD %d%% · 3d6" % roundi(Check.chance_opposed(run.rank() + 1, int(st0.def)) * 100), "sword")
	if run.has_program("armor") and not run.armor_used:
		add.call("ARMOR (PROGRAM) · -4 BRAIN DAMAGE", "armor")
	add.call("PATHFINDER", "pathfinder")
	add.call("JACK OUT", "jack_out", run.kraken_until < enc.init.round_num)
	_net_box.add_child(acts)
	# Turrets on held Control Nodes: a NET Action fires one, each node once a turn, with the
	# runner's own Skill (p.199, p.213-214; Encounter.fire_turret)
	var turret_rows := 0
	for ht in enc.held_turrets(enc.cur.id):
		turret_rows += 1 + mini(4, (ht.targets as Array).size())
		var tu: Dictionary = enc.units[int(ht.id)]
		var tw: Weapon = tu.c.weapons[0]
		var why := String(ht.why)
		_net_box.add_child(_text("%s · %s %d/%d%s" % [tu.c.display_name.to_upper(), tw.display_name().to_upper(), tw.ammo, tw.mag(), (" · " + why.to_upper()) if why != "" else ""],
			F_PIXEL, 20, DIM if why != "" else Color("e2c8ff")))
		if why != "":
			continue
		if (ht.targets as Array).is_empty():
			_net_box.add_child(_text("   NOTHING IN ITS SIGHTS", F_TERM, Hud.ts(16), DIM))
		for tg in (ht.targets as Array).slice(0, 4):
			var pair := [int(ht.id), int(tg.id)]
			var fb := _net_button("FIRE TURRET → %s · %d%%" % [enc.units[int(tg.id)].c.display_name.to_upper(), roundi(float(tg.chance) * 100)],
				func(): action.emit("net_turret", pair), 296, 26, none or float(tg.chance) <= 0.0)
			fb.tooltip_text = "1 NET Action: the turret fires with your own REF + weapon Skill. Each node once a turn (p.199, p.214)"
			_net_box.add_child(fb)
	var unsafe := _net_button("UNSAFE JACK OUT", func(): action.emit("net", "jack_out_unsafe"), 296, 24)
	unsafe.tooltip_text = "Every Black ICE you've met gets an attack on the way out (p.198)"
	unsafe.add_theme_color_override("font_color", RED)
	_net_box.add_child(unsafe)
	if not ice.is_empty():   # pinned: Slide is the way out (p200)
		var st1: Dictionary = ice_db[ice[0].kind]
		var pct := roundi(Check.chance_opposed(run.rank() - 2 * run.skunks.size(), int(st1.per)) * 100)
		_net_box.add_child(_text("SLIDE AWAY (%d%% · ONCE A TURN)" % pct, F_PIXEL, 20, DIM))
		for nb in run.slide_targets():
			var id: int = nb
			_net_box.add_child(_net_button("» " + _node_label(run.arch.nodes[id], enc, run), func(): action.emit("net_slide", id), 296, 24, none or enc._slid_this_turn))
		return
	_net_box.add_child(_text("ROUTE (FREE)", F_PIXEL, 20, DIM))
	var dist := run.route()
	var ids := dist.keys()
	ids.sort_custom(func(x, y): return int(dist[x]) < int(dist[y]) or (int(dist[x]) == int(dist[y]) and _is_target(enc, run, x)))
	for id in ids.slice(0, maxi(2, 6 - turret_rows)):   # fewer route rows while turret rows take the room
		var nid: int = id
		var b := _net_button("%s %s" % ["›".repeat(mini(3, int(dist[id]))), _node_label(run.arch.nodes[nid], enc, run)], func(): action.emit("net_move", nid), 296, 24)
		if _is_target(enc, run, nid):
			b.add_theme_color_override("font_color", GOLD)
		_net_box.add_child(b)


static func _is_target(enc: Encounter, run: NetRun, id: int) -> bool:
	return int(enc.objective.get("node", -1)) == id and int(enc.objective.get("structure", -1)) == run.arch.structure


## A control node's group id ("cameras_public_f0") as words ("cameras, public, floor 1").
static func control_name(group: String) -> String:
	var parts := group.split("_")
	var out: Array[String] = []
	for p in parts:
		if p.length() > 1 and p[0] == "f" and p.substr(1).is_valid_int():
			out.append("floor %d" % (int(p.substr(1)) + 1))
		else:
			out.append(p)
	return ", ".join(out) if out.size() > 1 else group


static func _node_label(n: Dictionary, enc: Encounter = null, run: NetRun = null, here := false) -> String:
	var dv_known: bool = run == null or not run.scouted.has(int(n.id))   # Pathfinder shows contents, not DVs (p200)
	var dv := (" · DV %d" % int(n.dv)) if dv_known and n.has("dv") else ""
	var star := "★ TARGET " if enc != null and run != null and _is_target(enc, run, int(n.id)) else ""
	match n.type:
		"firewall":
			var open := run != null and run.broken.has(int(n.id))
			return "Firewall%s (L%d)%s" % ["" if open else dv, n.zone, " · open" if open else ""]
		"file":
			var known := run != null and run.identified.has(int(n.id))
			return "%sFile%s%s%s" % [star, dv, (" · " + String(n.get("label", "data")).to_upper()) if known or star != "" else "", " · IDENTIFIED" if known else ""]
		"control":
			var held := run != null and run.held.has(int(n.id))
			return "Control Node: %s%s%s" % [control_name(String(n.group)), "" if held else dv, " · HELD" if held else ""]
		"socket":
			var nm := "linked site"
			if enc != null:
				for st in enc.m.structures:
					if st.id == int(n.target_structure):
						nm = String(st.get("name", st.get("kind", "linked site"))).replace("_", " ")
			return "Socket → %s" % nm
	return "%s (L%d)" % [String(n.type).capitalize(), n.zone]


## Controls cheat sheet, bottom left (H toggles).
func build_hint(text: String) -> void:
	hint = _panel(CYAN, 0b0010)
	var v := VBoxContainer.new()
	hint.add_child(v)
	v.add_child(_text("CONTROLS", F_DISPLAY, 20, CYAN))
	v.add_child(_text(text, F_TERM, Hud.ts(20), Color("9fb4c4")))
	hint.visible = false
	add_child(hint)
	hint_tab = _panel(CYAN, 0b0010)
	hint_tab.add_child(_text("H · HELP", F_DISPLAY, 20, CYAN))
	add_child(hint_tab)
	_layout.call_deferred()


func toggle_hint() -> void:
	hint.visible = not hint.visible
	hint_tab.visible = not hint.visible
	_layout.call_deferred()


# --- Visual settings panel (F2) ---------------------------------------------------

func build_settings(vals: Dictionary, specs: Array, changed: Callable) -> void:
	settings = _panel(GOLD, 0b0101, GOLD)
	var v := VBoxContainer.new()
	settings.add_child(v)
	v.add_child(_text("// LOOK · F2", F_PIXEL, 20, GOLD))
	for s in specs:  # [key, label, min, max, step]
		var row := HBoxContainer.new()
		var l := _text(String(s[1]).to_upper(), F_PIXEL, 20, TEXT)
		l.custom_minimum_size = Vector2(120, 0)
		row.add_child(l)
		var sl := HSlider.new()
		sl.min_value = s[2]
		sl.max_value = s[3]
		sl.step = s[4]
		sl.value = float(vals[s[0]])
		sl.custom_minimum_size = Vector2(160, 18)
		var val := _text(str(vals[s[0]]), F_TERM, Hud.ts(20), CYAN)
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
