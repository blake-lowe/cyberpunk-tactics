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
## Stairs (FloorNav.go): [id, title, glyph, dir]. Shown while the active unit stands on a stair
## square (or elevator / ladder end) that leads that way; lit when the move fits this turn.
const STAIR_ACTIONS := [["go_up", "GO UP", "go_up", 1], ["go_down", "GO DOWN", "go_down", -1]]
var stairs := {}          ## FloorNav.go results by direction (1 up, -1 down), set by the view before refresh
## Close-quarters actions (CPR core p.168-169, p.177, p.184): [id, title, key, glyph, tint, tool].
## Shown when Encounter.grapple_options() offers them; `tool` ones pick a target with a left click
## (ClickIntent.TOOL), the rest act at once. Hover cards: data/rules/action_help.json.
const GRAPPLE_ACTIONS := [["grab", "GRAB", "X", "hold", Color("ff8a3d"), true], ["choke", "CHOKE", "X", "choke", Color("ff3b4f"), false],
	["throw", "THROW", "Y", "throw", Color("ff3b4f"), false], ["shield", "HUMAN SHIELD", "I", "hshield", Color("f9c80e"), false],
	["release", "RELEASE", "O", "release", Color("8a96a0"), false], ["escape", "ESCAPE", "X", "free", Color("05d9e8"), false],
	["break", "BREAK HOLD", "P", "free", Color("39f0a0"), true], ["get_up", "GET UP", "U", "getup", Color("05d9e8"), false],
	["put_out", "PUT OUT FIRE", "C", "flame", Color("ff8a3d"), false]]   # only while On Fire (p.180)
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
var _log_tw: Tween
var end_toast := ""        ## the view's headline once the gig is over ("" = the plain GIG COMPLETE / ABANDONED / FAILED)
var _round_box: VBoxContainer              ## unit id → party card (hit shake)


## An imported font as its own FontFile copy (so per-face settings stay local). load() works in the
## editor and in exports; load_dynamic_font() needs the raw .ttf, which exports don't ship.
static func _font_file(path: String) -> FontFile:
	return (load(path) as FontFile).duplicate()


static func _fonts() -> void:
	if F_BODY:
		return
	F_DISPLAY = _font_file("res://assets/fonts/Jersey10-Regular.ttf")
	F_DISPLAY.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	F_PIXEL = FontVariation.new()
	F_PIXEL.base_font = F_DISPLAY
	F_PIXEL.spacing_glyph = 1
	# Body and data text (owner round 6: legibility): Chakra Petch SemiBold, a squared-off tech sans
	# with open counters and clear figures, antialiased so it holds up at any UI scale. Jersey10
	# stays the pixel display face for names, buttons and banners. VT323 is kept for the NET's
	# terminal readouts only (F_MONO).
	F_TERM = _font_file("res://assets/fonts/ChakraPetch-SemiBold.ttf")
	F_TERM.hinting = TextServer.HINTING_LIGHT
	F_TERM.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	F_BODY = F_TERM
	F_BOLD = _font_file("res://assets/fonts/ChakraPetch-Bold.ttf")
	F_BOLD.hinting = TextServer.HINTING_LIGHT
	F_MONO = _font_file("res://assets/fonts/VT323-Regular.ttf")
	F_MONO.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	# Symbols the faces lack (★ ◇ ○ ● ⚠ ✓, and arrows/≤≥ in Jersey10) come from explicit fallbacks
	# instead of whatever the OS has.
	# They are subsets with short line metrics (tools/make_ui_symbols.py) so they never make a line taller.
	var sym := _font_file("res://assets/fonts/UiSymbols-Noto.ttf")
	var sym2 := _font_file("res://assets/fonts/UiSymbols-Chakra.ttf")
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
	_build_log()
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
	_tip_label.install_effect(QualityText.SheenFx.new())   # Excellent weapons in stat blocks
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
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 6)
	_banner_panel.add_child(brow)
	_banner.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brow.add_child(_banner)
	add_child(_banner_panel)
	_build_stack()
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


var _floor_up: FloorBtn
var _floor_down: FloorBtn
var _stack: PanelContainer      ## the floor stack (owner-approved H1/H3): the focused building's storeys
var _stack_head: Label
var _stack_rows: VBoxContainer
var stack_data := {}            ## the last floor_stack() data (tests, review renders)
var crew_where := {}            ## unit id → where they stand, "BD PARLOR · 2" (greybox.where_label): the Alt roster's line


## The floor stack (A's stack with crew pips, driven by one focused building: FloorNav.slices).
## Right edge, under the round tab: header (the building), ▲ (SHIFT), one row per storey top
## down (R the roof, a street line over the B rows), ▼ (CTRL). Where the rest of the crew stands
## is on the Alt roster's cards (crew_where), not here.
func _build_stack() -> void:
	_stack = _panel(CYAN, 0b0101)
	_stack.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	_stack.add_child(v)
	_stack_head = _text("", F_PIXEL, 20, TEXT)
	v.add_child(_stack_head)
	_floor_up = FloorBtn.new(1, "SHIFT")
	_floor_up.custom_minimum_size = Vector2(STACK_W, 22)
	_floor_up.pressed.connect(func(): action.emit("floor", 1))
	_floor_up.tooltip_text = "View the floor above (SHIFT, PG UP or ])"
	v.add_child(_floor_up)
	_stack_rows = VBoxContainer.new()
	_stack_rows.add_theme_constant_override("separation", 2)
	v.add_child(_stack_rows)
	_floor_down = FloorBtn.new(-1, "CTRL")
	_floor_down.custom_minimum_size = Vector2(STACK_W, 22)
	_floor_down.pressed.connect(func(): action.emit("floor", -1))
	_floor_down.tooltip_text = "View the floor below (CTRL, PG DN or [)"
	v.add_child(_floor_down)
	_stack.visible = false
	add_child(_stack)


const STACK_W := 96.0
const STACK_W_TOWER := 190.0   ## a tower strip's rows also name their storey's programme


## Fill the floor stack: {name, rows: [{f, label, crew, foes, cur, street}] top down (`street`:
## the street line is drawn under that row), up_ok, down_ok, hint_dir (the objective lies that way
## in this building: that arrow breathes, never a floor named)}.
## Empty: hidden (no buildings, the NET owns the clicks).
func floor_stack(data: Dictionary) -> void:
	stack_data = data
	if _stack == null:
		return
	_stack.visible = not data.is_empty()
	if data.is_empty():
		return
	var tw: Dictionary = data.get("tower", {})
	_stack_head.text = String(data.get("name", "")).left(14) if tw.is_empty() else "%s · %d F" % [String(data.get("name", "")).left(16).strip_edges(), int(tw.storeys)]
	var w := STACK_W if tw.is_empty() else STACK_W_TOWER
	_floor_up.custom_minimum_size.x = w
	_floor_down.custom_minimum_size.x = w
	_clear(_stack_rows)
	for r in data.get("rows", []):
		var row := StackRow.new(r)
		row.custom_minimum_size.x = w
		var f := int(r.f)
		row.pressed.connect(func(): action.emit("floor_to", f))
		_stack_rows.add_child(row)
	if not tw.is_empty():   # the tower strip: the storeys below the band, off the map
		if int(tw.below_n) > 1:
			_stack_rows.add_child(StackGap.new("2-%d · %d floors" % [int(tw.below_n), int(tw.below_n) - 1], w))
		_stack_rows.add_child(StackRow.new({"f": -1, "label": "1", "prog": "lobby · off map", "off": true}, w))
	floor_nav(bool(data.get("up_ok", false)), bool(data.get("down_ok", false)), int(data.get("hint_dir", 0)))
	_stack.reset_size()
	_layout()


## One storey in the floor stack: its name, a green square per crew member on it, a red diamond when
## a foe is seen there; the viewed one lit. Click: view that storey. In a tower strip (Hud.floor_stack
## `tower`) also its programme ("labs"), the lift car on its row (a green car outline at the left),
## a gold notch on the objective's storey; an `off` row (the street lobby, off the map) is dim and dead.
class StackRow extends Button:
	var r: Dictionary
	func _init(p_r: Dictionary, w := Hud.STACK_W) -> void:
		r = p_r
		custom_minimum_size = Vector2(w, 22)
		focus_mode = Control.FOCUS_NONE
		var lit: bool = r.get("cur", false)
		if r.get("off", false):
			disabled = true
			mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_theme_stylebox_override("disabled", CutBox.make(Color(0.02, 0.03, 0.04, 0.6), Color(Hud.DIM, 0.25), 4, 0b0101))
		add_theme_stylebox_override("normal", CutBox.make(Color(0.02, 0.1, 0.12, 0.97) if lit else Color(0.03, 0.045, 0.06, 0.9), Color(Hud.CYAN, 0.95 if lit else 0.25), 4, 0b0101))
		add_theme_stylebox_override("hover", CutBox.make(Color(0.02, 0.12, 0.14, 0.97), Hud.CYAN, 4, 0b0101))
		add_theme_stylebox_override("pressed", CutBox.make(Color(0.14, 0.11, 0.02, 0.97), Hud.GOLD, 4, 0b0101))
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		tooltip_text = "" if r.get("off", false) else "View this floor"
	func _draw() -> void:
		var lit: bool = r.get("cur", false)
		var off: bool = r.get("off", false)
		var x0 := 8.0
		if r.get("car", false):   # the lift car stands at this storey
			draw_rect(Rect2(Vector2(5, size.y / 2 - 5), Vector2(7, 10)), Hud.GREEN, false, 1.5)
			draw_line(Vector2(8.5, size.y / 2 - 4), Vector2(8.5, size.y / 2 + 4), Hud.GREEN, 1.0)
			x0 = 17.0
		var lc := Hud.TEXT if lit else Color(Hud.DIM, 0.95)
		if off:
			lc = Color(Hud.DIM, 0.5)
		draw_string(Hud.F_BOLD, Vector2(x0, size.y / 2 + 6), String(r.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, Hud.ts(16), lc)
		var prog := String(r.get("prog", ""))
		if prog != "":   # the storey's programme, small and dim
			draw_string(Hud.F_TERM, Vector2(x0 + 30, size.y / 2 + 5), prog, HORIZONTAL_ALIGNMENT_LEFT, size.x - x0 - 72, Hud.ts(12), Color(Hud.DIM, 0.45 if off else 0.8))
		var x := size.x - 10.0
		if r.get("obj", false):   # the objective's storey (towers only): a gold notch at the edge
			var o2 := Vector2(size.x - 3, size.y / 2)
			draw_colored_polygon(PackedVector2Array([o2 + Vector2(0, -5), o2 + Vector2(0, 5), o2 + Vector2(-6, 0)]), Hud.GOLD)
			x -= 9.0
		if int(r.get("foes", 0)) > 0:   # a seen foe on this storey
			var o := Vector2(x, size.y / 2)
			draw_colored_polygon(PackedVector2Array([o + Vector2(0, -5), o + Vector2(4, 0), o + Vector2(0, 5), o + Vector2(-4, 0)]), Hud.RED)
			x -= 11.0
		for i in mini(int(r.get("crew", 0)), 3):   # crew on this storey
			draw_rect(Rect2(Vector2(x - 3, size.y / 2 - 3), Vector2(6, 6)), Hud.GREEN)
			x -= 9.0
		if r.get("street", false):   # the street line: the B rows sit under it
			draw_line(Vector2(-4, size.y + 1), Vector2(size.x + 4, size.y + 1), Color(Hud.DIM, 0.8), 1.0)


## The tower strip's run of storeys between the band and the street lobby, off the map: hairlines
## with break marks and a count ("2-47 · 46 floors"). Not a button.
class StackGap extends Control:
	var text := ""
	func _init(p_text: String, w: float) -> void:
		text = p_text
		custom_minimum_size = Vector2(w, 26)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		for i in 4:
			var y := 3.0 + i * 6.5
			draw_line(Vector2(14, y), Vector2(size.x - 14, y), Color(Hud.DIM, 0.22), 1.0)
		for sx in [6.0, size.x - 6.0]:   # break marks
			draw_line(Vector2(sx - 4, size.y / 2 + 3), Vector2(sx + 4, size.y / 2 - 3), Color(Hud.DIM, 0.6), 1.0)
		var fs := Hud.ts(12)
		var tw := Hud.F_TERM.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_rect(Rect2(Vector2((size.x - tw) / 2 - 4, size.y / 2 - fs * 0.6), Vector2(tw + 8, fs * 1.2)), Color(0.02, 0.03, 0.04, 0.95))
		draw_string(Hud.F_TERM, Vector2((size.x - tw) / 2, size.y / 2 + fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Hud.DIM, 0.85))


## The floor stack's ▲ / ▼: greyed when there is no floor that way; `pulse` (the objective lies that
## way, owner: subtle, never named) breathes the outline gently. `key`: its hold key, small and dim
## grey at the right end (SHIFT up, CTRL down).
class FloorBtn extends Button:
	var dir := 1
	var pulse := false
	var key := ""
	func _init(p_dir: int, p_key := "") -> void:
		dir = p_dir
		key = p_key
		custom_minimum_size = Vector2(26, 26)
		focus_mode = Control.FOCUS_NONE
		add_theme_stylebox_override("normal", CutBox.make(Color(0.03, 0.045, 0.06, 0.95), Color(Hud.CYAN, 0.4), 5, 0b0101))
		add_theme_stylebox_override("hover", CutBox.make(Color(0.02, 0.12, 0.14, 0.97), Hud.CYAN, 5, 0b0101))
		add_theme_stylebox_override("pressed", CutBox.make(Color(0.14, 0.11, 0.02, 0.97), Hud.GOLD, 5, 0b0101))
		add_theme_stylebox_override("disabled", CutBox.make(Color(0.02, 0.025, 0.03, 0.6), Color(Hud.DIM, 0.2), 5, 0b0101))
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	func _process(_d: float) -> void:
		if pulse:
			queue_redraw()
	func _draw() -> void:
		var r := 6.0
		var o := size / 2 if key == "" else Vector2(8 + r, size.y / 2)   # with a key hint: left, under the rows' labels
		var col := Color(Hud.DIM, 0.45) if disabled else Hud.CYAN
		if pulse and not disabled:
			var k := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 2.4)
			col = Hud.CYAN.lerp(Hud.GOLD, 0.35 + 0.4 * k)
			draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(Hud.GOLD, 0.1 + 0.18 * k), false, 1.5)
		var dy := -r * 0.75 * dir
		draw_colored_polygon(PackedVector2Array([o + Vector2(-r, -dy), o + Vector2(0, dy), o + Vector2(r, -dy)]), col)
		if key != "":   # the smallest legible HUD size (Hud.ts floor), dim grey: a hint, not a label
			var fs := Hud.ts(12)
			draw_string(Hud.F_TERM, Vector2(0, size.y / 2 + fs * 0.35), key, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 6, fs, Color(Hud.DIM, 0.4 if disabled else 0.75))


## The floor buttons' state: whether there is a floor up / down, and which way the objective lies
## (FloorNav.objective_dir: that button pulses).
func floor_nav(up_ok: bool, down_ok: bool, hint_dir: int) -> void:
	if _floor_up == null:
		return
	_floor_up.disabled = not up_ok
	_floor_down.disabled = not down_ok
	_floor_up.pulse = hint_dir > 0 and up_ok
	_floor_down.pulse = hint_dir < 0 and down_ok
	_floor_up.queue_redraw()
	_floor_down.queue_redraw()


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
		var gap := Hud.seg_gap(segs)
		var sw := Hud.seg_width(w - h * 0.4, segs, gap)
		if sw <= 0.0:   # too many segments to read (a 40-round drum): one continuous slanted fill
			var full := PackedVector2Array([Vector2(h * 0.4, 0), Vector2(w, 0), Vector2(w - h * 0.4, h), Vector2(0, h)])
			draw_colored_polygon(full, Color(col, 0.16))
			var fw := (w - h * 0.4) * clampf(frac, 0.0, 1.0)
			if fw > 0.0:
				draw_colored_polygon(PackedVector2Array([Vector2(h * 0.4, 0), Vector2(fw + h * 0.4, 0), Vector2(fw, h), Vector2(0, h)]), col)
			return
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


## Segment geometry for a Meter `w` px wide: small gaps (1 px once there are many segments) and
## each segment's width, or 0 when it would fall under MIN_SEG_PX (the meter then fills continuously).
const MIN_SEG_PX := 2.0


static func seg_gap(segs: int) -> float:
	return 2.0 if segs <= 12 else 1.0


static func seg_width(w: float, segs: int, gap: float) -> float:
	var n := maxi(1, segs)
	var sw := (w - gap * (n - 1)) / n
	return sw if sw >= MIN_SEG_PX else 0.0


## A foe portrait's blood level: the share of their HP lost (owner: it fills from the bottom).
static func blood_fill(hp: int, max_hp: int) -> float:
	return clampf(1.0 - float(hp) / maxf(1.0, float(max_hp)), 0.0, 1.0)


## The status line's weapon name: Brawling by its skill (its data name is "Fists").
static func status_name(w: Weapon) -> String:
	return "BRAWLING" if w == null or w.id() == "brawling" else w.display_name().to_upper()


## Where the magazine bar would be, for weapons with no magazine (melee, Brawling): an italic
## infinity sign, stretched a little wide, centred.
class Infinity extends Control:
	var col := Color.WHITE
	func _init(p_col: Color, w: float, h: float) -> void:
		col = p_col
		custom_minimum_size = Vector2(w, h)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var fs := 26
		var f: Font = Hud.F_BOLD
		var gs := f.get_string_size("∞", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var sx := 1.35
		# x-scale 1.35, skewed right ~12 degrees (italic), centred on the box
		var xf := Transform2D(Vector2(sx, 0), Vector2(-0.22, 1.0), Vector2(size.x / 2.0, size.y / 2.0))
		draw_set_transform_matrix(xf)
		draw_string(f, Vector2(-gs.x / 2.0, f.get_ascent(fs) - gs.y / 2.0), "∞", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		draw_set_transform_matrix(Transform2D.IDENTITY)


## A slanted turn-order slot with the unit's rendered bust.
class Slot extends Control:
	var tex: Texture2D
	var team_col := Color.WHITE
	var active := false
	var hp := 1.0
	var tag := ""
	var dead := false
	var uid := -1
	var hot := false   ## under the mouse: lit like a target
	var foe := false   ## hostile: a solid red outline, and the bust fills with blood as they're hurt
	var blood := 0.0
	var blood_from := 0.0   ## the level last shown: the blood rises from it (juice)
	func _ready() -> void:
		if not foe:
			return
		var ov := Hud.Painter.new()   # the outline on its own canvas item: the palette shader would wash the red out
		ov.fn = _draw_foe_frame
		add_child(ov)
		if not material is ShaderMaterial:
			return
		var mt := material as ShaderMaterial
		mt.set_shader_parameter("blood", blood_from)
		if blood > blood_from:
			var tw := create_tween()
			tw.tween_method(func(v: float): mt.set_shader_parameter("blood", v), blood_from, blood, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			mt.set_shader_parameter("blood", blood)
	func _notification(what: int) -> void:
		if what in [NOTIFICATION_MOUSE_ENTER, NOTIFICATION_MOUSE_EXIT]:
			hot = what == NOTIFICATION_MOUSE_ENTER
			queue_redraw()
	func _init(p_tex: Texture2D, p_col: Color, p_active: bool, p_hp: float, p_tag: String, p_dead: bool) -> void:
		tex = p_tex
		team_col = p_col
		active = p_active
		hp = p_hp
		tag = p_tag
		dead = p_dead
		custom_minimum_size = Vector2(76, 76) if active else Vector2(56, 56)
		mouse_filter = Control.MOUSE_FILTER_STOP   # hover / click a foe's portrait to target them
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
		if not foe:
			draw_polyline(loop, Hud.GOLD if active or hot else Color(team_col, 0.6), 2.0 if active or hot else 1.0)
		if hot:   # targeted from the strip: corner brackets outside the frame
			var o := 4.0
			for cn in [[Vector2(sk - o, -o), Vector2(1, 0), Vector2(0, 1)], [Vector2(w + o, -o), Vector2(-1, 0), Vector2(0, 1)], [Vector2(-o, h + o), Vector2(1, 0), Vector2(0, -1)], [Vector2(w - sk + o, h + o), Vector2(-1, 0), Vector2(0, -1)]]:
				draw_polyline(PackedVector2Array([cn[0] + cn[1] * 10, cn[0], cn[0] + cn[2] * 10]), Hud.RED, 3.0)
		var bw := (w - sk) * clampf(hp, 0, 1)
		draw_rect(Rect2(0, h + 3, w - sk, 4), Color(team_col, 0.18))
		draw_rect(Rect2(0, h + 3, bw, 4), Hud.GREEN if hp > 0.6 else (Hud.GOLD if hp > 0.3 else Hud.RED))
		pass
	func _draw_foe_frame(c: Control) -> void:
		var w := size.x
		var h := size.y - 12
		var sk := 12.0
		c.draw_polyline(PackedVector2Array([Vector2(sk, 0), Vector2(w, 0), Vector2(w - sk, h), Vector2(0, h), Vector2(sk, 0)]), Hud.GOLD if active or hot else Hud.RED, 2.0)


## Hotbar action: chamfered square with a drawn glyph, a pixel-font name and its key.
class ActBtn extends Button:
	var glyph := ""
	var title := ""
	var key := ""
	var tint := Color.WHITE
	var pct := -1
	var qstyle := {}   ## QualityText style of the title (a weapon on the attack stage's wheel), {} = plain
	func set_quality(st: Dictionary) -> void:
		qstyle = st
		set_process(bool(st.get("sheen", false)))
	func _process(_dt: float) -> void:
		queue_redraw()   # the Excellent sweep
	## The title's lines, font and size: shrunk to fit the tile, and a long name (a weapon on the
	## wheel) broken over two lines rather than shrunk below MIN_FS (owner: exotic faces too small).
	func _title_layout(w: float) -> Array:
		const MIN_FS := 13
		var tf: Font = Hud.F_BOLD
		var tt := title
		var base := Hud.ts(17)   # shrink to fit long titles (WITHDRAW, SUPPRESS)
		if not qstyle.is_empty():   # a weapon's quality typography (QualityText)
			tt = qstyle.text
			tf = qstyle.font if qstyle.font else tf
			base = roundi(base * float(qstyle.scale))
		var fit := func(ls: Array, floor_fs: int) -> int:
			var f := base
			while f > floor_fs and ls.any(func(l): return tf.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x > w - 4):
				f -= 1
			return f
		var min_fs := roundi(MIN_FS * float(qstyle.get("scale", 1.0)))   # a face with small caps (Iceland) breaks sooner
		var fs: int = fit.call([tt], min_fs)
		if tf.get_string_size(tt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w - 4 or not tt.contains(" "):
			return [[tt], tf, fit.call([tt], 8)]
		var best := -1   # break at the space nearest the middle
		for i in tt.length():
			if tt[i] == " " and (best < 0 or absi(i - tt.length() / 2) < absi(best - tt.length() / 2)):
				best = i
		var two := [tt.substr(0, best), tt.substr(best + 1)]
		return [two, tf, mini(fit.call(two, 8), base - 2)]
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
		var tl := _title_layout(w)
		var o := Vector2(w / 2, size.y * (0.4 if tl[0].size() == 1 else 0.27))
		var r := minf(w, size.y) * (0.17 if tl[0].size() == 1 else 0.12)
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
			"search":   # a magnifier over a pocket
				draw_rect(Rect2(o + Vector2(-r * 1.1, -r * 0.2), Vector2(r * 1.3, r * 1.2)), c, false, 2.0)
				draw_line(o + Vector2(-r * 1.1, r * 0.2), o + Vector2(r * 0.2, r * 0.2), c, 1.5)
				draw_arc(o + Vector2(r * 0.45, -r * 0.45), r * 0.55, 0, TAU, 14, c, 2.0)
				draw_line(o + Vector2(r * 0.85, -r * 0.05), o + Vector2(r * 1.35, r * 0.5), c, 3.0)
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
			"hold":   # two hands locked together
				draw_arc(o + Vector2(-r * 0.45, 0), r * 0.7, -PI * 0.5, PI * 0.5, 10, c, 3.0)
				draw_arc(o + Vector2(r * 0.45, 0), r * 0.7, PI * 0.5, PI * 1.5, 10, c, 3.0)
				draw_line(o + Vector2(-r * 1.4, 0), o + Vector2(-r * 0.8, 0), c, 3.0)
				draw_line(o + Vector2(r * 0.8, 0), o + Vector2(r * 1.4, 0), c, 3.0)
			"choke":   # a ring closing on a neck
				draw_arc(o, r * 0.9, PI * 0.15, PI * 1.85, 16, c, 3.0)
				draw_line(o + Vector2(r * 0.9, -r * 0.4), o + Vector2(r * 1.4, -r * 0.4), c, 2.0)
				draw_line(o + Vector2(r * 0.9, r * 0.4), o + Vector2(r * 1.4, r * 0.4), c, 2.0)
				draw_circle(o, r * 0.3, c)
			"throw":   # an arc over the shoulder down to the ground
				draw_arc(o + Vector2(0, r * 0.6), r * 1.1, PI * 1.05, PI * 1.95, 14, c, 2.5)
				draw_colored_polygon(PackedVector2Array([o + Vector2(r * 1.1, r * 1.0), o + Vector2(r * 0.7, r * 0.3), o + Vector2(r * 1.4, r * 0.4)]), c)
				draw_line(o + Vector2(-r * 1.4, r * 1.2), o + Vector2(r * 1.4, r * 1.2), Color(c, 0.6), 1.5)
			"hshield":   # a figure in front of a shield edge
				draw_arc(o + Vector2(0, -r * 0.6), r * 0.35, 0, TAU, 10, c, 2.0)
				draw_line(o + Vector2(0, -r * 0.25), o + Vector2(0, r * 0.7), c, 2.5)
				draw_line(o + Vector2(-r * 0.6, 0), o + Vector2(r * 0.6, 0), c, 2.0)
				draw_arc(o + Vector2(-r * 1.6, 0), r * 1.3, -PI * 0.3, PI * 0.3, 8, Color(c, 0.6), 2.0)
			"release":   # hands opening apart
				draw_arc(o + Vector2(-r * 0.8, 0), r * 0.6, -PI * 0.5, PI * 0.5, 10, c, 2.5)
				draw_arc(o + Vector2(r * 0.8, 0), r * 0.6, PI * 0.5, PI * 1.5, 10, c, 2.5)
				draw_line(o + Vector2(-r * 0.2, -r * 0.9), o + Vector2(-r * 0.2, r * 0.9), Color(c, 0.5), 1.0)
				draw_line(o + Vector2(r * 0.2, -r * 0.9), o + Vector2(r * 0.2, r * 0.9), Color(c, 0.5), 1.0)
			"flame":   # a flame, struck through
				draw_colored_polygon(PackedVector2Array([o + Vector2(0, -r * 1.3), o + Vector2(r * 0.8, -r * 0.1), o + Vector2(r * 0.7, r * 0.7),
					o + Vector2(0, r * 1.1), o + Vector2(-r * 0.7, r * 0.7), o + Vector2(-r * 0.8, -r * 0.1), o + Vector2(-r * 0.3, -r * 0.4)]), Color(c, 0.35))
				draw_colored_polygon(PackedVector2Array([o + Vector2(0, -r * 0.3), o + Vector2(r * 0.35, r * 0.4), o + Vector2(0, r * 0.8), o + Vector2(-r * 0.35, r * 0.4)]), c)
				draw_line(o + Vector2(-r * 1.2, r * 1.0), o + Vector2(r * 1.2, -r * 1.0), Color(Hud.TEXT, c.a), 2.0)
			"getup":   # an arrow up off the floor
				draw_line(o + Vector2(0, r * 1.0), o + Vector2(0, -r * 0.6), c, 3.0)
				draw_colored_polygon(PackedVector2Array([o + Vector2(0, -r * 1.2), o + Vector2(-r * 0.6, -r * 0.4), o + Vector2(r * 0.6, -r * 0.4)]), c)
				draw_line(o + Vector2(-r * 1.3, r * 1.1), o + Vector2(r * 1.3, r * 1.1), Color(c, 0.6), 1.5)
			"go_up", "go_down":   # a flight of steps with an arrow up or down it
				for i in 3:
					var sx := o.x - r * 1.3 + i * r * 0.8
					var sy := o.y + r * 1.0 - i * r * 0.6
					draw_line(Vector2(sx, sy), Vector2(sx + r * 0.8, sy), c, 2.0)
					draw_line(Vector2(sx + r * 0.8, sy), Vector2(sx + r * 0.8, sy - r * 0.6), c, 2.0)
				var up := glyph == "go_up"
				var ax := o.x + r * 0.9
				var tipy := o.y - r * 1.2 if up else o.y + r * 0.6
				draw_line(Vector2(ax, o.y - r * 0.9 if not up else o.y + r * 0.3), Vector2(ax, tipy), c, 2.5)
				var dd := 1.0 if up else -1.0
				draw_colored_polygon(PackedVector2Array([Vector2(ax, tipy - dd * 3), Vector2(ax - r * 0.45, tipy + dd * r * 0.5), Vector2(ax + r * 0.45, tipy + dd * r * 0.5)]), c)
			"end":
				draw_colored_polygon(PackedVector2Array([o + Vector2(-r * 1.2, -r), o + Vector2(r * 0.2, 0), o + Vector2(-r * 1.2, r)]), c)
				draw_colored_polygon(PackedVector2Array([o + Vector2(0, -r), o + Vector2(r * 1.4, 0), o + Vector2(0, r)]), c)
		var lines: Array = tl[0]
		var tf: Font = tl[1]
		var fs: int = tl[2]
		var tcol := Color(Hud.TEXT, 0.45 if disabled else 1.0)
		for i in lines.size():
			var y := size.y - 7 - (lines.size() - 1 - i) * (fs + 1)
			if qstyle.is_empty():
				draw_string(tf, Vector2(0, y), lines[i], HORIZONTAL_ALIGNMENT_CENTER, w, fs, tcol)
			else:
				var st := qstyle.duplicate()
				st.text = lines[i]
				QualityText.draw_text(self, tf, Vector2(0, y), w, fs, tcol, st)
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
		if spec[0] == "interact":   # what B does here, when it has a card (Search Body)
			b3.mouse_entered.connect(func(): _interact_tip(b3))
			b3.mouse_exited.connect(func(): _tip.visible = false)
		_tool_buttons[spec[0]] = b3
		_buttons.add_child(b3)
	for spec in STAIR_ACTIONS:   # stairs: up or down the flight you stand on (FloorNav.go)
		var sb := ActBtn.new(spec[2], spec[1], "", Color("05d9e8"))
		var sdir: int = spec[3]
		sb.pressed.connect(func(): action.emit("go_floor", sdir))
		_tool_buttons[spec[0]] = sb
		_buttons.add_child(sb)
	for spec in GRAPPLE_ACTIONS:   # close quarters: only what the grapple state allows shows (Encounter.grapple_options)
		var gb := ActBtn.new(spec[3], spec[1], spec[2], spec[4])
		gb.toggle_mode = spec[5]
		var gid: String = spec[0]
		gb.pressed.connect(func(): action.emit("grapple", gid))
		gb.mouse_entered.connect(func(): _bar_tip(gb, gid))
		gb.mouse_exited.connect(func(): _tip.visible = false)
		_tool_buttons[gid] = gb
		_buttons.add_child(gb)
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
	_layout_log_and_bar(s)
	_place_withdraw()
	_net_panel.reset_size()   # it shrinks as rows go (a held turret's targets come and go)
	var net_y := _round_tab.position.y + _round_tab.size.y + 30
	net_y = maxf(_round_tab.position.y + _round_tab.size.y + 10, minf(net_y, _bar.position.y - _net_panel.size.y - 10))   # never over the action bar or the round tab
	_net_panel.position = Vector2(s.x - _net_panel.size.x - 14, net_y)
	_toast.position = Vector2(s.x / 2 - 400, 148)   # under the turn banner and its rule (y 100-136), never over them
	_toast.size = Vector2(800, 40)
	_banner_panel.position = Vector2(14, 12)
	_round_tab.position = Vector2(s.x - _round_tab.size.x - 14, 12)
	if _stack:   # right edge, under the round tab; the NET panel owns that corner while jacked in
		_stack.visible = not stack_data.is_empty() and not _net_panel.visible
		_stack.reset_size()
		_stack.position = Vector2(s.x - _stack.size.x - 14, _round_tab.position.y + _round_tab.size.y + 14)
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
	return stance_col(stance(enc, int(u.team)))


## The line under a crew member's name: their role, or HOSTAGE for a rescue's freed captive (on
## the crew's side and the player's to move, but not one of the crew).
static func crew_tag(u: Dictionary) -> String:
	return "HOSTAGE" if bool(u.get("captive", false)) else String(u.c.role).to_upper()


## Where side `team` stands with the crew: one query (Encounter.hostile/allied) for every label,
## the hover tip, the Alt inspect card and the unit colours. No encounter: HOSTILE.
static func stance(enc: Encounter, team: int) -> String:
	if enc == null or enc.hostile(Encounter.CREW, team):
		return "HOSTILE"
	return "ALLIED" if enc.allied(Encounter.CREW, team) else "NEUTRAL"


## A stance's colour: hostile red, neutral grey, allied cyan.
static func stance_col(s: String) -> Color:
	return RED if s == "HOSTILE" else (CYAN if s == "ALLIED" else NEUTRAL)


## The alarm's countdown for the HUD: "BACKUP IN 3 ROUNDS" while it counts down, "BACKUP ARRIVING"
## the round it lands (0), "NOBODY ANSWERS" when nothing is coming (-1 and below).
static func countdown_text(label: String, n: int) -> String:
	if n > 0:
		return "ALARM · %s IN %d ROUND%s" % [label, n, "" if n == 1 else "S"]
	if n == 0:
		return "ALARM · %s ARRIVING" % label
	return "ALARM · NOBODY ANSWERS"


## The round box's alarm line: the site's response counting down, then the street's.
static func alarm_text(enc: Encounter) -> String:
	if enc.backup_in >= 0:
		return countdown_text(enc.backup_label, enc.backup_in)
	if enc.ncpd_in >= 0:
		return countdown_text(enc.ncpd_label, enc.ncpd_in)
	return "ALARM"


func refresh(enc: Encounter, mode: int, cover_mode: bool, floor_text: String) -> void:
	interact_enc = enc
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
		slot.uid = int(u.id)
		slot.material = portraits.material()
		if u.team != 0 and enc.hostile(Encounter.CREW, int(u.team)) and slot.material:   # foes: their own material for the blood level
			slot.foe = true
			slot.material = slot.material.duplicate()
			slot.blood = blood_fill(c.hp, c.max_hp())
			slot.blood_from = 1.0 - float(_hp_seen.get(u.id, 1.0 - slot.blood))
		var uid := int(u.id)   # with an attack armed, a foe's portrait targets them (greybox)
		slot.mouse_entered.connect(func(): action.emit("portrait_hover", [uid, slot.get_global_rect()]))
		slot.mouse_exited.connect(func(): action.emit("portrait_hover", [-1, Rect2()]))
		slot.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
				action.emit("portrait_click", uid))
		slot.modulate = Portraits.tint(c.wound_state())
		_init_strip.add_child(slot)
	_clear(_round_box)   # round and stealth state: top right corner
	_round_box.add_child(_text("ROUND %02d" % maxi(1, enc.init.round_num), F_TERM, Hud.ts(20), CYAN))
	var state := "UNDETECTED"
	if enc.alarm >= 2:
		state = alarm_text(enc)
	elif enc.engaged():
		state = "ENGAGED"
	_round_box.add_child(_text(state, F_DISPLAY, 20, RED if state != "UNDETECTED" else CYAN))
	# The objective: a small OBJECTIVE label, the order in gold, then dim context lines.
	_round_box.add_child(_text("OBJECTIVE", F_TERM, Hud.ts(14), Color(DIM, 0.9)))
	var olines := objective_text(enc).split("\n", false)
	for i in olines.size():
		_round_box.add_child(_text(olines[i], F_TERM, Hud.ts(18 if i == 0 else 15), GOLD if i == 0 else Color(DIM, 0.95)))
	if not enc.outages.is_empty():   # Utility Codes (NC2045 p.8)
		_round_box.add_child(_text(" · ".join(enc.outages.map(func(o): return String(o).to_upper() + " OUT")), F_TERM, Hud.ts(18), RED))
	if enc.neutral != null:   # a house where nobody fights (NeutralGround: Totentanz's club floor)
		_round_box.add_child(_text(enc.neutral.hud_text(), F_TERM, Hud.ts(18), GOLD if enc.neutral.holds else RED))
	if not enc.complication.is_empty():   # the book's complication (Complication), shown once it springs
		var cx := _text("COMPLICATION · " + String(enc.complication.get("hud", enc.complication.text)).to_upper(), F_TERM, Hud.ts(18), RED)
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
		nv.add_child(_text(crew_tag(enc.cur) + "  ·  " + ["UNHURT", "LIGHT WOUNDS", "SERIOUS WOUNDS", "MORTALLY WOUNDED", "FLATLINED"][c.wound_state()], F_DISPLAY, 20, CYAN if crew_turn else RED))
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
		var gs := status_label(c)
		if gs != "":   # GRAPPLED / GRAPPLING / PRONE: the state that changes what the bar offers
			_card.add_child(_text(gs, F_DISPLAY, 20, Color("ff8a3d")))
		var t := enc.turn
		var act := t.action_available or t.attacks_left > 0
		_econ.add_child(_text(action_text(t), F_DISPLAY, 20, CYAN if act else Color(DIM, 0.6)))
		var mv := t.squares_available()
		var mvmax := maxi(1, c.stat("MOVE"))
		_econ.add_child(_text("MOVE", F_DISPLAY, 20, CYAN if mv > 0 else Color(DIM, 0.6)))   # squares and metres: the move tooltip (owner: just MOVE + bar)
		var mm := Meter.new(float(mv) / mvmax, mvmax, CYAN, STATUS_BAR_W, 11)
		mm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_econ.add_child(mm)
		var exhausted := not act and mv == 0
		(_end_btn as ActBtn).tint = GOLD if exhausted else Color("8a96a0")
		var w: Weapon = c.weapons[0] if not c.weapons.is_empty() else null
		if stage == "attack":
			var aw: Weapon = Weapon.brawling(c) if atk_mode == "brawl" else (enc.melee_weapon(c) if atk_mode == "melee" and (w == null or not w.is_melee()) else w)
			var n_atk := attacks_per_action(aw, atk_mode) if t.action_available else 0
			_econ.add_child(_text("▸ " + String(ATK_MODES.get(atk_mode, ["", "", ""])[2]).to_upper() + (" · %d ATTACKS THIS TURN" % n_atk if n_atk > 1 else ""), F_DISPLAY, 20, GOLD))
		_add_weapon_status(c, enc, w)
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


## The one-word close-quarters state for a unit card: GRAPPLED BY X, GRAPPLING X (HUMAN SHIELD),
## PRONE; "" when none.
static func status_label(c: Combatant) -> String:
	var out: Array[String] = []
	var g: Grapple = c.grapple
	if g != null and g.holder == c:
		out.append(("GRAPPLING %s" % g.held.display_name.to_upper()) + (" · HUMAN SHIELD" if g.shield else "") if g.live() else "CORPSE SHIELD")
	elif g != null and g.live():
		out.append("GRAPPLED BY %s" % g.holder.display_name.to_upper())
	if c.prone:
		out.append("PRONE")
	return " · ".join(out)


## The unit card's ACTION line: lit while the Action is unspent, and after the first attack of a
## 2 ROF Action it says a second one is left (p169: two attack checks, split around movement).
static func action_text(t: TurnState) -> String:
	if not t.action_available and t.attacks_left > 0:
		return "◆ %d MORE ATTACK%s (ROF 2)" % [t.attacks_left, "" if t.attacks_left == 1 else "S"]
	return "◆ ACTION" if t.action_available else "◇ ACTION"


## Attack checks one Action of `atk_mode` with `w` gives (p169): a 2 ROF weapon's single attack,
## melee or Brawling (Brawling and Martial Arts are ROF 2, p176-178) gives two; Autofire, Aimed
## Shots, Suppressive Fire, a Shell and ROF 1 weapons one.
static func attacks_per_action(w: Weapon, atk_mode: String) -> int:
	if w == null or atk_mode not in ["single", "melee", "brawl", "cover"]:
		return 1
	return mini(2, maxi(1, w.rof()))


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
	if not enc.body_in_reach(enc.cur).is_empty():
		return ["search", "SEARCH BODY", "search"]
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
	var gopts := enc.grapple_options()
	var g: Grapple = c.grapple
	for spec in GRAPPLE_ACTIONS:
		show[spec[0]] = String(spec[0]) in gopts
	for spec in STAIR_ACTIONS:
		show[spec[0]] = stairs.has(spec[3])
	for k in _tool_buttons:
		var b: ActBtn = _tool_buttons[k]
		b.visible = show[k]
		b.disabled = not crew_turn or (k != "jack" and not can_act) or (k == "reload" and not t.action_available)
		if show[k] and k in ["go_up", "go_down"]:   # a move, not an Action: lit when the flight fits this turn
			var sg: Dictionary = stairs[1 if k == "go_up" else -1]
			b.disabled = not crew_turn or not sg.ok
			b.tooltip_text = ("Take the stairs %s" % ("up" if k == "go_up" else "down")) + (" (Run: spends your Action)" if sg.run else "") + ("" if sg.ok else " · " + String(sg.reason))
		if show[k] and _is_grapple(k):   # every one is an Action, bar letting go of someone alive (p.177, p.184)
			b.disabled = not crew_turn or (not t.action_available and not (k == "release" and g != null and g.live()))
		var armed: bool = {"shot": stage == "attack", "kit0": tool == "grenade", "medic": tool == "stabilize",
			"role": not role.is_empty() and tool == String(role[0]), "grab": tool == "grab", "break": tool == "break"}.get(k, false)
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
		if w:
			tb.set_quality(QualityText.weapon_style(w, nm))
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
	v.add_child(_text(crew_tag(u), F_DISPLAY, 20, GOLD if bool(u.get("captive", false)) else DIM))
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 6)
	var hm := _hp_meter(u.id, c, 80, 9)
	hm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(hm)
	hr.add_child(_text("%d/%d" % [c.hp, c.max_hp()], F_TERM, Hud.ts(20), _hp_col(c)))
	v.add_child(hr)
	var w: Weapon = c.weapons[0] if not c.weapons.is_empty() else null
	var wl := _text(("%s %s" % [w.display_name().to_upper(), ("%d/%d" % [w.ammo, int(w.def.get("mag", 0))]) if w.uses_ammo() else ""]) if w else "UNARMED", F_TERM, Hud.ts(16), DIM)
	v.add_child(QualityText.apply(wl, Items.key_of_weapon(w)) if w else wl)
	var wh := String(crew_where.get(int(u.id), ""))
	if wh != "" and not c.dead:   # where they stand: the building (or STREET) and the floor
		var whl := _text(wh, F_TERM, Hud.ts(14), Color(DIM, 0.8))
		whl.name = "Where"
		v.add_child(whl)
	var gs := status_label(c)
	if gs != "":
		var gl := _text(gs, F_DISPLAY, 18, Color("ff8a3d"))
		gl.custom_minimum_size.x = 200
		gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(gl)
	var gc := grapple_conditions(c)
	var cond := conditions(c).filter(func(x): return x != "prone" and not x in gc)   # the label above says it
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
		hp += "  [color=#7d8a96]·[/color] " + ["Unhurt", "Lightly Wounded", "Seriously Wounded", "Mortally Wounded", "Flatlined"][c.wound_state()] + "  " + (K % "DEATH SAVE") + " %d" % c.death_save_target()   # Seriously Wounded is always half HP: not worth a line (owner)
	else:
		hp += "  [color=#7d8a96]·[/color] " + ["Unhurt", "Lightly Wounded", "Seriously Wounded", "Mortally Wounded", "Flatlined"][c.wound_state()]
	out.append(hp)
	out.append((K % "ARMOR") + " head SP %d · body SP %d" % [c.sp("head"), c.sp("body")])
	var ws: Array = c.weapons if full else c.weapons.slice(0, 1)
	for w in ws:
		var q := QualityText.quality_note(Items.key_of_weapon(w))
		var ap := " AP" if w.special_left > 0 and int(w.special_fx.get("ablate_sp", 1)) > 1 else ""   # a VH Pistol turret's AP rounds (Turret)
		out.append((K % "WEAPON") + " %s · %dd6 · ROF %d%s" % [QualityText.bbcode(Items.key_of_weapon(w), String(w.def.name), ts(20)), w.dice(), w.rof(), (" · %d/%d%s" % [w.ammo, int(w.def.get("mag", 0)), ap]) if w.uses_ammo() else ""])
		if q != "":   # the names carry quality as typography only; the card says it in words
			out.append((K % "QUALITY") + " " + q)
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


static func _is_grapple(id: String) -> bool:
	return GRAPPLE_ACTIONS.any(func(sp): return sp[0] == id)


## A close-quarters action's hover card from data/rules/action_help.json (the NET panel's style,
## net_help): name, cost, what it does, its roll, the page. `live` adds a NOW line. "" if unknown.
static func action_help(id: String, live := "") -> String:
	const K := "[color=#7d8a96]%s[/color]"
	var e: Dictionary = (RulesDB.load_json("action_help.json").actions as Dictionary).get(id, {})
	if e.is_empty():
		return ""
	var out: Array[String] = ["[b]%s[/b]  %s" % [String(e.name), K % String(e.cost)], String(e.text)]
	if String(e.get("key", "")) != "":
		out.append((K % "ROLL") + " [code]%s[/code]" % String(e.key))
	if live != "":
		out.append((K % "NOW") + " " + live)
	out.append(K % ("%s %s" % [String(e.get("book", "CPR core")), String(e.get("page", ""))]))
	return "\n".join(out)


## The interact button's hover card, for the interacts that have one (Search Body: whose body,
## and that it's searched once).
var interact_enc: Encounter = null   ## set by the view each refresh (the bar has no Encounter of its own)


func _interact_tip(b: Control) -> void:
	if interact_enc == null or interact_enc.cur.is_empty():
		return
	var here := interact_here(interact_enc)
	if here.is_empty() or String(here[0]) != "search":
		return
	tip(search_help(interact_enc), b.get_global_rect().position - global_position + Vector2(-28, -40), "// SEARCH BODY", GOLD)


## Search Body's card (action_help.json search_body) with the body in reach and its odds now.
static func search_help(enc: Encounter) -> String:
	var g := enc.body_in_reach(enc.cur)
	var live := ""
	if not g.is_empty():
		var state := "surrendered" if String(g.get("broke", "")) == "surrender" else ("flatlined" if g.c.dead else "down")
		live = "%s (%s): something on them on 1-%d of 1d6" % [g.c.display_name, state, CorpseLoot.has_loot_target(g)]
	return action_help("search_body", live)


## The hover card above a bar button.
func _bar_tip(b: Control, id: String) -> void:
	var r := b.get_global_rect()
	tip(action_help(id), r.position - global_position + Vector2(-28, -40), "// ON FIRE" if id == "put_out" else "// CLOSE QUARTERS", Color("ff8a3d"))


## The grapple a combatant is in, for cards: who's holding whom.
static func grapple_conditions(c: Combatant) -> Array[String]:
	var out: Array[String] = []
	var g: Grapple = c.grapple
	if g == null:
		return out
	if g.holder == c:
		if not g.live():
			out.append("holding a corpse shield" + (" (%d HP)" % g.corpse_hp if g.corpse_hp > 0 else " (spent)"))
		else:
			out.append("grappling %s: -%d to all Actions%s" % [g.held.display_name, Grapple.PENALTY, " · human shield" if g.shield else ""])
	elif g.live():
		out.append("grappled by %s: -%d to all Actions, no Move Action%s" % [g.holder.display_name, Grapple.PENALTY, " · held as a human shield" if g.shield else ""])
	return out


## What's wrong with someone at a glance: injuries, status, drugs, chrome knocked out.
static func conditions(c: Combatant) -> Array[String]:
	var out: Array[String] = grapple_conditions(c)
	if c.wound_state() == Combatant.Wound.MORTAL:   # p.220: still acts, at these penalties
		out.append("mortally wounded: -%d to all Actions, -%d MOVE (min 1)" % [Combatant.WOUND_ACTION_PENALTY[Combatant.Wound.MORTAL], Combatant.MORTAL_MOVE_PENALTY])
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


## The gig is over (EndJuice): the banner slams down from oversize instead of sliding in, the rule
## snaps across, and it stays up over the end panel.
func end_banner(text: String, col: Color) -> void:
	turn_banner(text, col)
	_banner_tw.kill()
	var w := _turn_banner.get_minimum_size().x
	var x := size.x / 2 - w / 2
	_turn_banner.position.x = x
	_turn_banner.pivot_offset = _turn_banner.get_minimum_size() / 2.0
	_turn_banner.scale = Vector2(2.4, 2.4)
	_turn_banner.add_theme_constant_override("shadow_offset_x", 14)
	var tw := create_tween()
	_banner_tw = tw
	tw.tween_property(_turn_banner, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_turn_banner, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(_turn_strip, "modulate:a", 1.0, 0.2)
	tw.tween_callback(func(): flash_screen(Color(col, 0.18)))   # the impact
	tw.tween_method(func(v: int): _turn_banner.add_theme_constant_override("shadow_offset_x", v), 14, 3, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_turn_rule, "size:x", w, 0.16).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## A pulse of coloured edge glow (the enemy-phase vignette's shader) up to `peak`, settling at `rest`.
func edge_pulse(col: Color, peak: float, rest: float) -> void:
	var vm := _vignette.material as ShaderMaterial
	vm.set_shader_parameter("col", col)
	var tw := create_tween()
	tw.tween_property(vm, "shader_parameter/amount", peak, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(vm, "shader_parameter/amount", rest, 0.7).set_trans(Tween.TRANS_SINE)


# --- Combat log: bottom left, beside the action bar (owner, playtest r3) ----------------------
# Docked at the screen's bottom left with its bottom on the bar's; the bar moves right to make
# room and slides back to centre when the log is collapsed (the chevron, or K). Hovering it grows it
# upward to LOG_OPEN_LINES. Too narrow a screen for both side by side: it sits above the bar's left
# instead, as before. The collapsed state is kept for the session.

const LOG_W := 320.0         ## preferred width (logical px, the HUD's 720-line layout)
const LOG_MIN_W := 220.0     ## narrower than this beside the bar: stack it above the bar instead
const LOG_OPEN_LINES := 14
const EDGE := 14.0           ## screen margin
const LOG_GAP := 12.0        ## between the log and the bar
const LOG_SLIDE_S := 0.25
const STATUS_BAR_W := 90.0   ## the MOVE and magazine bars on the status line

static var log_collapsed := false   ## the session's choice: survives new gigs and scene changes
var _log_t := 1.0             ## 1 docked open .. 0 collapsed (tweened)
var _log_slide_tw: Tween
var _log_head: HBoxContainer
var _log_tab: Button          ## the collapsed log: a small chevron tab at the bottom left


## Flip the session's log state; returns the new collapsed state.
static func flip_log_state() -> bool:
	log_collapsed = not log_collapsed
	return log_collapsed


## The log's width beside a bar `bar_w` wide on a `screen_w` screen: LOG_W, or what's left
## between the margin and a bar pushed to the right margin; 0 when under LOG_MIN_W (stack instead).
static func log_width(screen_w: float, bar_w: float) -> float:
	var room := screen_w - bar_w - EDGE * 2.0 - LOG_GAP
	var w := minf(LOG_W, room)
	return w if w >= LOG_MIN_W else 0.0


## The action bar's left edge: centred when the log is collapsed (`t` 0), and when open (`t` 1)
## pushed right just enough to clear a `log_w` log, never past the right margin. Eased between.
static func bar_x(screen_w: float, bar_w: float, log_w: float, t: float) -> float:
	var centre := (screen_w - bar_w) / 2.0
	if log_w <= 0.0:
		return centre
	var docked := clampf(maxf(centre, EDGE + log_w + LOG_GAP), centre, maxf(centre, screen_w - bar_w - EDGE))
	return lerpf(centre, docked, clampf(t, 0.0, 1.0))


func _build_log() -> void:
	_log_t = 0.0 if log_collapsed else 1.0
	_log_panel = _panel(CYAN, 0b0100)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
	_log_panel.add_child(lv)
	_log_head = HBoxContainer.new()
	_log_head.add_child(_text("// LOG", F_TERM, 14, DIM))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_head.add_child(sp)
	_log_head.add_child(_chevron("‹", "Collapse the log (K)"))
	lv.add_child(_log_head)
	_log = _text("", F_TERM, Hud.ts(19), Color("9fb4c4"))
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.clip_text = true
	_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lv.add_child(_log)
	add_child(_log_panel)
	_log_panel.mouse_filter = Control.MOUSE_FILTER_STOP   # hovering grows it upward (owner)
	_log_panel.mouse_entered.connect(func(): _log_open = true; _show_log())
	_log_panel.mouse_exited.connect(func():
		if not _log_panel.get_global_rect().has_point(get_global_mouse_position()):   # not when moving onto the chevron
			_log_open = false
			_show_log())
	_log_tab = _chevron("›  LOG", "Show the log (K)")
	_log_tab.add_theme_stylebox_override("normal", CutBox.make(INK, Color(CYAN, 0.45), 6, 0b0100))
	_log_tab.add_theme_stylebox_override("hover", CutBox.make(INK, CYAN, 6, 0b0100))
	add_child(_log_tab)


## A small flat chevron button that toggles the log.
func _chevron(text: String, tip_text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip_text
	b.add_theme_font_override("font", F_BOLD)
	b.add_theme_font_size_override("font_size", 15)
	for st in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(st, CYAN if st != "font_color" else Color(CYAN, 0.7))
	b.add_theme_constant_override("h_separation", 0)
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.pressed.connect(toggle_log)
	return b


## Collapse or expand the log (chevron or K): the bar eases to centre and back.
func toggle_log() -> void:
	flip_log_state()
	if _log_slide_tw and _log_slide_tw.is_valid():
		_log_slide_tw.kill()
	_log_slide_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_log_slide_tw.tween_method(func(v: float):
		_log_t = v
		_layout(), _log_t, 0.0 if log_collapsed else 1.0, LOG_SLIDE_S)


## Review renders: hold the slide at `t` (0 collapsed .. 1 open), as if mid-tween.
func set_log_t(t: float) -> void:
	if _log_slide_tw and _log_slide_tw.is_valid():
		_log_slide_tw.kill()
	_log_t = t
	_layout()


func _layout_log_and_bar(s: Vector2) -> void:
	var bw := _bar.size.x
	var lw := log_width(s.x, bw) if not _log_lines.is_empty() else 0.0   # nothing logged yet: the bar stays centred
	var beside := lw > 0.0
	var w := lw if beside else LOG_W
	var bar_y := s.y - _bar.size.y - 12
	_bar.position = Vector2(bar_x(s.x, bw, lw, _log_t), bar_y)
	# the log's text box: as tall as the bar (docked) or a few lines (stacked); taller while hovered
	var pad := (_log_panel.get_theme_stylebox("panel") as StyleBox).get_minimum_size()
	var lh := float(_log.get_line_height()) + _log.get_theme_constant("line_spacing")
	var closed_h := (_bar.size.y - pad.y - _log_head.size.y - 2) if beside else lh * 3
	var text_h := maxf(closed_h, lh * LOG_OPEN_LINES) if _log_open else closed_h
	_log.custom_minimum_size = Vector2(w - pad.x, maxf(lh, text_h))
	_log.max_lines_visible = maxi(1, floori((text_h + _log.get_theme_constant("line_spacing")) / lh))
	_log.lines_skipped = maxi(0, _log.get_line_count() - _log.max_lines_visible)
	_log_panel.reset_size()
	var bottom := (s.y - 12) if beside else (bar_y - 10)
	_log_panel.position = Vector2(lerpf(-w - EDGE * 2.0, EDGE, _log_t), bottom - _log_panel.size.y)
	_log_tab.reset_size()
	_log_tab.position = Vector2(EDGE, bottom - _log_tab.size.y)
	_log_tab.modulate.a = 1.0 - _log_t
	_log_tab.visible = _log_t < 0.999 and not _log_lines.is_empty()
	_log_panel.visible = _log_t > 0.001 and not _log_lines.is_empty()


func _show_log(fresh := false) -> void:
	_log.text = "\n".join(_log_lines.slice(maxi(0, _log_lines.size() - 60)).map(func(l): return "> " + l))
	if _log_tw and _log_tw.is_valid():
		_log_tw.kill()
	if _log_open or fresh:   # new lines show at full strength, then fade back after a few seconds
		_log_panel.modulate.a = 1.0
	if not _log_open:
		_log_tw = create_tween()
		_log_tw.tween_interval(5.0)
		_log_tw.tween_property(_log_panel, "modulate:a", 0.6, 0.6)
	_layout.call_deferred()


## The status line's weapon part: the selected weapon's name, then its magazine (one segment per
## round, lit while loaded) or, for melee and Brawling, an infinity sign where the bar would be.
func _add_weapon_status(c: Combatant, enc: Encounter, w: Weapon) -> void:
	var sel: Weapon = w
	if stage == "attack" and atk_mode == "brawl":
		sel = Weapon.brawling(c)
	elif stage == "attack" and atk_mode == "melee" and (w == null or not w.is_melee()):
		sel = enc.melee_weapon(c)
	if sel == null:
		sel = Weapon.brawling(c)
	var nm := _text(status_name(sel), F_TERM, Hud.ts(20), TEXT)
	_econ.add_child(QualityText.apply(nm, Items.key_of_weapon(sel)) if sel.id() != "brawling" else nm)
	if sel.jammed:
		_econ.add_child(_text("JAMMED · R TO CLEAR", F_TERM, Hud.ts(20), RED))
	elif sel.uses_ammo():
		var mag := maxi(1, int(sel.def.get("mag", 0)))
		var mb := Meter.new(float(sel.ammo) / mag, mag, CYAN if sel.ammo > 0 else RED, STATUS_BAR_W, 11)
		mb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_econ.add_child(mb)
	else:
		_econ.add_child(Infinity.new(TEXT, STATUS_BAR_W, 16))


## Slide the crew roster in (Alt held) or out.
func show_roster(on: bool) -> void:
	roster_on = on
	var tw := create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(_party, "position:x", 14.0 if on else -_party.size.x - 30, 0.16)


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
	var head_row := _text("// JACKED IN · %d NET ACTION%s" % [enc.net_left, "" if enc.net_left == 1 else "S"], F_PIXEL, 20, MAGENTA)
	_net_hover(head_row, "net_actions", "%d of %d left this turn" % [enc.net_left, enc.net_actions_for(run.runner)])
	_net_box.add_child(head_row)
	var here := run.cur_node()
	_net_box.add_child(_text(_node_label(here, enc, run, true).to_upper(), F_DISPLAY, 20, Color("e2c8ff")))
	if String(here.type) == "file" and run.identified.has(run.current):   # Eye-Dee's answer (p.199)
		var fi := NetDevices.file_info(enc, here)
		var fl := _text("EYE-DEE · VALUE %d/5 · %s%s" % [int(fi.value), String(fi.tier).to_upper(), " · THE JOB'S FILE" if _is_target(enc, run, run.current) else ""],
			F_TERM, Hud.ts(18), GOLD)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.custom_minimum_size.x = 296
		_net_hover(fl, "eye_dee", "%s, value %d of 5 (%s)" % [String(fi.what), int(fi.value), String(fi.tier)])
		_net_box.add_child(fl)
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
	var progs: Array = run.runner.programs.filter(func(pg): return not run.lost.has(pg))
	if not progs.is_empty():   # the deck's Programs, each with its card
		var prow := HBoxContainer.new()
		prow.add_theme_constant_override("separation", 10)
		prow.add_child(_text("PROGRAMS", F_PIXEL, 20, DIM))
		for pg in progs:
			var pl := _text(String(pg).to_upper(), F_TERM, Hud.ts(18), Color("e2c8ff"))
			_net_hover(pl, String(pg))
			prow.add_child(pl)
		_net_box.add_child(prow)
	var ice := run.arch.ice_at(run.current)
	for i in ice:
		var st: Dictionary = ice_db[i.kind]
		var il := _text("!! %s  ATK %d DEF %d PER %d · REZ %d/%d" % [String(i.kind).to_upper(), int(st.atk), int(st.def), int(st.per), int(i.get("rez", st.rez)), int(st.rez)], F_TERM, Hud.ts(18), RED)
		_net_hover(il, "ice:" + String(i.kind), "REZ %d/%d left" % [int(i.get("rez", st.rez)), int(st.rez)])
		_net_box.add_child(il)
		_net_box.add_child(_text("   " + String(st.get("effect", "")), F_TERM, Hud.ts(16), Color(RED, 0.75)))
	# Only the actions that apply here, each with its odds.
	var acts := VBoxContainer.new()   # one row per option (owner)
	acts.add_theme_constant_override("separation", 3)
	var none := enc.net_left <= 0
	var add := func(label: String, kind: String, enabled := true):
		var nb := _net_button(label, func(): action.emit("net", kind), 296, 28, none or not enabled)
		_net_hover(nb, kind, label)
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
	var turret_rows := _net_held(enc, none)
	var unsafe := _net_button("UNSAFE JACK OUT", func(): action.emit("net", "jack_out_unsafe"), 296, 24)
	_net_hover(unsafe, "jack_out_unsafe")
	unsafe.add_theme_color_override("font_color", RED)
	_net_box.add_child(unsafe)
	if not ice.is_empty():   # pinned: Slide is the way out (p200)
		var st1: Dictionary = ice_db[ice[0].kind]
		var pct := roundi(Check.chance_opposed(run.rank() - 2 * run.skunks.size(), int(st1.per)) * 100)
		_net_box.add_child(_text("SLIDE AWAY (%d%% · ONCE A TURN)" % pct, F_PIXEL, 20, DIM))
		for nb in run.slide_targets():
			var id: int = nb
			var sb := _net_button("» " + _node_label(run.arch.nodes[id], enc, run), func(): action.emit("net_slide", id), 296, 24, none or enc._slid_this_turn)
			_net_hover(sb, "slide", "%d%% to get away" % pct)
			_net_box.add_child(sb)
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


const HELD_ROWS := 7   ## held-node rows the NET panel shows before folding the rest into "+N MORE"
const OPS_PER_NODE := 3   ## device rows per held node (nearest the crew first), the rest folded


## The NET panel's held Control Nodes (p.199): a HELD badge and the node's name, then a row for
## each thing on it that can be worked (a NET Action each, every node once a turn: Encounter
## net_device) and its turrets' FIRE rows (Encounter.fire_turret). Nodes with something to do
## come first. Returns the rows used (the route list shrinks to fit).
func _net_held(enc: Encounter, none: bool) -> int:
	var nodes: Array = enc.device_ops(enc.cur.id)
	var turrets: Array = enc.held_turrets(enc.cur.id)
	if nodes.is_empty():
		return 0
	var ready := func(row: Dictionary) -> bool:
		return (row.ops as Array).any(func(o): return String(o.why) == "") or turrets.any(func(t): return int(t.node) == int(row.node) and String(t.why) == "")
	nodes.sort_custom(func(a, b): return ready.call(a) and not ready.call(b))
	_net_box.add_child(_text("HELD NODES · 1 NET ACTION EACH · ONCE A TURN", F_PIXEL, 20, DIM))
	var rows := 1
	var shown := 0
	for row in nodes:
		var mine := turrets.filter(func(t): return int(t.node) == int(row.node))
		var need := 1 + mini((row.ops as Array).size(), OPS_PER_NODE) + mine.size()
		if rows + need > HELD_ROWS and shown > 0:
			_net_box.add_child(_text("   +%d MORE HELD" % (nodes.size() - shown), F_TERM, Hud.ts(16), DIM))
			return rows + 1
		shown += 1
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		head.add_child(held_badge())
		var nl := _text(control_name(String(row.group)).to_upper() + (" · USED THIS TURN" if row.used else ""), F_TERM, Hud.ts(18), DIM if row.used else Color("e2c8ff"))
		_net_hover(nl, "held", "%d thing%s to work here" % [(row.ops as Array).size() + mine.size(), "" if (row.ops as Array).size() + mine.size() == 1 else "s"])
		head.add_child(nl)
		_net_box.add_child(head)
		rows += 1
		for o in (row.ops as Array).slice(0, OPS_PER_NODE):
			var why := String(o.why)
			var pair := [int(o.node), int(o.device)]
			var b := _net_button("  %s · %s%s" % [String(o.label), String(o.name).to_upper(), (" · " + why.to_upper()) if why != "" and not row.used else ""],
				func(): action.emit("net_device", pair), 296, 24, none or why != "")
			_net_hover(b, "dev_" + String(o.op), ("%s: %s" % [String(o.name), "on" if o.on else "off"]) if String(o.op) not in ["sprinklers", "distract"] else String(o.name))
			_net_box.add_child(b)
			rows += 1
		if (row.ops as Array).size() > OPS_PER_NODE:
			_net_box.add_child(_text("     +%d MORE ON THIS NODE (FARTHER FROM THE CREW)" % ((row.ops as Array).size() - OPS_PER_NODE), F_TERM, Hud.ts(16), DIM))
			rows += 1
		for ht in mine:   # its turrets: a NET Action fires one with the runner's own Skill (p.199, p.213-214)
			rows += _net_turret(enc, ht, none)
	return rows


## One held turret: its line (gun, rounds, why it can't fire) and a FIRE row per target in its sights.
func _net_turret(enc: Encounter, ht: Dictionary, none: bool) -> int:
	var tu: Dictionary = enc.units[int(ht.id)]
	var tw: Weapon = tu.c.weapons[0]
	var why := String(ht.why)
	_net_box.add_child(_text("  %s · %s %d/%d%s" % [tu.c.display_name.to_upper(), tw.display_name().to_upper(), tw.ammo, tw.mag(), (" · " + why.to_upper()) if why != "" else ""],
		F_PIXEL, 20, DIM if why != "" else Color("e2c8ff")))
	if why != "":
		return 1
	if (ht.targets as Array).is_empty():
		_net_box.add_child(_text("     NOTHING IN ITS SIGHTS", F_TERM, Hud.ts(16), DIM))
		return 2
	var n := 1
	for tg in (ht.targets as Array).slice(0, 3):
		var pair := [int(ht.id), int(tg.id)]
		var fb := _net_button("  FIRE TURRET → %s · %d%%" % [enc.units[int(tg.id)].c.display_name.to_upper(), roundi(float(tg.chance) * 100)],
			func(): action.emit("net_turret", pair), 296, 26, none or float(tg.chance) <= 0.0)
		_net_hover(fb, "fire_turret", "%d%% to hit %s" % [roundi(float(tg.chance) * 100), enc.units[int(tg.id)].c.display_name])
		_net_box.add_child(fb)
		n += 1
	return n


## The small HELD pill (violet, cut corner) the NET panel puts beside a node the runner holds.
func held_badge() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", CutBox.make(Color(VIOLET, 0.85), Color(VIOLET, 1.0), 4, 0b0100, Color(0, 0, 0, 0), 4))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _text("HELD", F_PIXEL, 16, Color(0.05, 0.0, 0.08))
	p.add_child(l)
	return p


## The NET panel's hover card for `id` (bbcode, in the stat_block style: labels dim, values bright):
## a NET Action or the NET Actions header (net_help.json "actions"), a Program ("programs"), or
## "ice:<kind>" for Black ICE (black_ice.json). `live` adds this moment's odds. "" if unknown.
static func net_help(id: String, live := "") -> String:
	const K := "[color=#7d8a96]%s[/color]"
	var db: Dictionary = RulesDB.load_json("net_help.json")
	var out: Array[String] = []
	if id.begins_with("ice:"):
		var kind := id.substr(4)
		var st: Dictionary = RulesDB.load_json("black_ice.json")["ice"].get(kind, {})
		if st.is_empty():
			return ""
		out.append("[b]%s[/b]  %s" % [kind.capitalize(), K % ("Black ICE · " + String(st.get("class", "")).replace("_", "-").capitalize())])
		out.append(String(st.get("effect", "")))
		out.append((K % "STATS") + " [code]PER %d · SPD %d · ATK %d · DEF %d · REZ %d[/code]" % [int(st.per), int(st.spd), int(st.atk), int(st.def), int(st.rez)])
		out.append((K % "PER") + " what a Slide must beat  " + (K % "SPD") + " its speed when you meet it")
		out.append((K % "ATTACKS") + " its ATK + 1d10 vs your Interface + 1d10, once a turn; it chases you through the NET")
		if live != "":
			out.append((K % "NOW") + " " + live)
		out.append(K % ("CPR core " + String(db.get("ice_page", "p.204-207"))))
		return "\n".join(out)
	var e: Dictionary = (db.actions as Dictionary).get(id, (db.programs as Dictionary).get(id, {}))
	if e.is_empty():
		return ""
	out.append("[b]%s[/b]  %s" % [String(e.name), K % String(e.cost)])
	out.append(String(e.text))
	if String(e.get("key", "")) != "":
		var what := "STATS" if (db.programs as Dictionary).has(id) else "ROLL"
		out.append((K % what) + " [code]%s[/code]" % String(e.key))
	if live != "":
		out.append((K % "NOW") + " " + live)
	var page := String(e.get("page", ""))
	out.append(K % (("CPR core " + page) if page.begins_with("p.") else page))
	return "\n".join(out)


## Hovering `c` shows its NET card (net_help) beside the NET panel, in the cursor tooltip's style.
func _net_hover(c: Control, id: String, live := "") -> void:
	var body := net_help(id, live)
	if body == "":
		return
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var head := "// " + ("BLACK ICE" if id.begins_with("ice:") else ("PROGRAM" if (RulesDB.load_json("net_help.json").programs as Dictionary).has(id) else "NET"))
	c.mouse_entered.connect(func(): _tip_beside_net(body, head, c))
	c.mouse_exited.connect(func(): _tip.visible = false)


## The tooltip panel to the left of the NET panel, level with the hovered row.
func _tip_beside_net(text: String, head: String, row: Control) -> void:
	_tip.visible = true
	_tip_head.text = head
	_tip_head.visible = true
	_tip_head.add_theme_color_override("font_color", MAGENTA)
	_tip_label.text = text
	_tip.reset_size()
	var r := row.get_global_rect()
	var pos := Vector2(_net_panel.position.x - _tip.size.x - 10, r.position.y - global_position.y - 8)
	_tip.position = pos.clamp(Vector2.ZERO, size - _tip.size - Vector2(4, 4))


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
			if known and enc != null:   # Eye-Dee told what it is and its worth (p.199)
				var fi := NetDevices.file_info(enc, n)
				return "%sFile · %s · VALUE %d/5" % [star, String(fi.what).to_upper(), int(fi.value)]
			return "%sFile%s%s" % [star, dv, (" · " + String(n.get("label", "data")).to_upper()) if star != "" else " · UNIDENTIFIED"]
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


## The H panel (owner, playtest r3): only the mouse and camera, one control per row; the
## keyboard actions are on the action bar's buttons already. Every control here is one
## greybox._unhandled_input / _process / the portrait strip handles. [section, [[input, does], ...]].
const HELP := [
	["MOUSE", [
		["LEFT-CLICK", "Attack the enemy under the cursor"],
		["RIGHT-CLICK", "Move or run to a square"],
		["CLICK PORTRAIT", "Target an enemy from the turn order"],
		["LEFT-CLICK A BUILDING", "Focus its floors (the floor stack)"],
		["HOVER ENEMY", "Line of fire and hit chance"],
		["HOLD ALT", "Inspect, enemy outlines, stairs and exits, range bands"],
	]],
	["CAMERA", [
		["WHEEL", "Zoom"],
		["MIDDLE-DRAG", "Rotate freely"],
		["Q / E", "Rotate"],
		["W A S D", "Pan"],
		["SHIFT / CTRL", "View one floor up / down (hold to keep going)"],
		["PG UP / PG DN  ·  ] / [", "The same (or the floor stack's arrows and rows)"],
		["HOME", "Back to the selected unit's building and floor"],
	]],
	["OVERLAYS", [
		["Z", "Guard sight lines: near your move / always / off"],
	]],
]


## The H panel as plain text (tests, logs): one "INPUT  does" line per control.
static func help_text() -> String:
	var out: Array[String] = []
	for sec in HELP:
		out.append(String(sec[0]))
		for r in sec[1]:
			out.append("%s  %s" % [r[0], r[1]])
	return "\n".join(out)


## Screen rect of a unit's portrait in the turn-order strip (Rect2() if it has none).
## `light`: draw it as hovered (review renders, where no real mouse is over it).
func portrait_rect(uid: int, light := false) -> Rect2:
	for s in _init_strip.get_children():
		if s is Slot and (s as Slot).uid == uid:
			if light:
				(s as Slot).hot = true
				(s as Slot).queue_redraw()
			return (s as Slot).get_global_rect()
	return Rect2()


func build_hint() -> void:
	hint = _panel(CYAN, 0b0010)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	hint.add_child(v)
	var g := GridContainer.new()   # one grid for every section: the key caps line up
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 3)
	v.add_child(g)
	for sec in HELP:
		g.add_child(_text(String(sec[0]), F_DISPLAY, 20, CYAN))
		var pad := Control.new()
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.add_child(pad)
		for r in sec[1]:
			var cap := PanelContainer.new()   # the input as a key cap, the action beside it
			cap.add_theme_stylebox_override("panel", CutBox.make(Color(0.06, 0.08, 0.1, 0.95), Color(GOLD, 0.45), 4, 0b0101, Color(0, 0, 0, 0), 6))
			cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var kl := _text(String(r[0]), F_BOLD, 14, GOLD)
			kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cap.add_child(kl)
			g.add_child(cap)
			var dl := _text(String(r[1]), F_TERM, Hud.ts(19), TEXT)
			dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			g.add_child(dl)
	v.add_child(_text("H  HIDE", F_TERM, 14, DIM))
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
