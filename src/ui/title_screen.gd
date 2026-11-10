class_name TitleScreen
extends Control
## The title screen (scenes/title.tscn, the main scene): New Game, Load Game, Options, Credits,
## Quit; and, with `pause` set, the safehouse's Esc menu over the base view (Resume, Save, Load,
## Title, Quit). Save slots: SaveSlots / Campaign.slot. Options: GameSettings.
## Keyboard: arrows / Tab move, Enter picks, Esc goes back. Mouse: hover highlights what Enter picks.

const BASE := "res://scenes/base.tscn"
const TITLE := "res://scenes/title.tscn"

var pause := false        ## the safehouse's Esc menu rather than the title screen
var camp: Campaign        ## pause: the running campaign
var page := ""
var _box: VBoxContainer   ## the current page's contents
var _note: Label
var _opts := {}


func _ready() -> void:
	Hud._fonts()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not pause:
		UiScale.watch(get_window())
		GameSettings.apply_at_startup(get_tree())
		SaveSlots.migrate_legacy()
		AudioDirector.get_or_make(get_tree()).music("explore")
	_opts = GameSettings.load_values()
	var bg := ColorRect.new()   # title: flat dark UI colour; pause: a dim veil over the base view
	bg.color = Color(0.01, 0.015, 0.025, 0.86) if pause else Color(0.01, 0.015, 0.025)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 96)
	m.add_theme_constant_override("margin_top", 64 if not pause else 120)
	m.add_theme_constant_override("margin_bottom", 40)
	add_child(m)
	var col := UiKit.vbox(10)
	m.add_child(col)
	if pause:
		col.add_child(UiKit.head("Paused", 48, Hud.CYAN))
	else:
		var t := UiKit.vbox(-30)
		t.add_child(UiKit.head("Cyberpunk", 84, Hud.CYAN))
		t.add_child(UiKit.head("Tactics", 84, Hud.MAGENTA))
		col.add_child(t)
		col.add_child(UiKit.label("Turn-based edgerunning on the Cyberpunk RED rules", 16, Hud.DIM))
	var gap := Control.new()
	gap.custom_minimum_size.y = 18
	col.add_child(gap)
	_box = UiKit.vbox(10)
	_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_box)
	_note = UiKit.body("", 15, Hud.GOLD)
	col.add_child(_note)
	var open := "main"
	for a in OS.get_cmdline_user_args():   # review renders: --shot=out.png [--page=load] [--slots-dir=user://x]
		var k := a.trim_prefix("--").get_slice("=", 0)
		match k:
			"shot": _shot_path = a.get_slice("=", 1)
			"page": open = a.get_slice("=", 1)
			"slots-dir": SaveSlots.dir = a.get_slice("=", 1)
	show_page(open)


var _shot_path := ""
var _frames := 0


func _process(_dt: float) -> void:
	if _shot_path == "" or pause:
		return
	_frames += 1
	if _frames == 6:
		get_viewport().get_texture().get_image().save_png(_shot_path)
		get_tree().quit()


## Build a page: main, new, load, save, confirm:<n>, options, credits.
func show_page(p: String) -> void:
	page = p
	for ch in _box.get_children():
		_box.remove_child(ch)
		ch.queue_free()
	var first: Control = null
	match p.get_slice(":", 0):
		"main": first = _main()
		"new", "load", "save": first = _slots(p)
		"confirm": first = _confirm(int(p.get_slice(":", 2)), p.get_slice(":", 1))
		"options": first = _options()
		"credits": first = _credits()
	if first and is_inside_tree():
		first.grab_focus.call_deferred()


func _main() -> Control:
	var items: Array = []
	if pause:
		var demo := camp == null or camp.has_meta("demo")
		items = [["Resume", UiKit.PRIMARY, close, true], ["Save", UiKit.NAV, show_page.bind("save"), not demo],
			["Load", UiKit.NAV, show_page.bind("load"), SaveSlots.any_used()],
			["Title", UiKit.NAV, _to_title, true], ["Quit", UiKit.DANGER, _quit, true]]
	else:
		items = [["New Game", UiKit.PRIMARY, show_page.bind("new"), true],
			["Load Game", UiKit.NAV, show_page.bind("load"), SaveSlots.any_used()],
			["Options", UiKit.NAV, show_page.bind("options"), true],
			["Credits", UiKit.NAV, show_page.bind("credits"), true], ["Quit", UiKit.DANGER, _quit, true]]
	var first: Control = null
	for it in items:
		var b := _button(it[0], it[1], it[2], it[3])
		_box.add_child(b)
		if first == null and not b.disabled:
			first = b
	return first


func _slots(mode: String) -> Control:
	var heads := {"new": "New game: pick a slot", "load": "Load game", "save": "Save to slot"}
	_box.add_child(UiKit.label(heads[mode], 18, Hud.CYAN))
	var first: Control = null
	for n in range(1, SaveSlots.COUNT + 1):
		var d := SaveSlots.describe(SaveSlots.meta(n))
		var ok: bool = mode != "load" or not d.empty
		var card := _slot_card(n, d, ok, _slot_picked.bind(mode, n))
		_box.add_child(card)
		if first == null and ok:
			first = card
	var back := _button("Back", UiKit.NAV, show_page.bind("main"))
	_box.add_child(back)
	return first if first else back


func _slot_card(n: int, d: Dictionary, ok: bool, cb: Callable) -> Button:
	var active := pause and n == Campaign.slot
	var b := _button("", UiKit.PRIMARY if active else UiKit.NAV, cb, ok)
	b.custom_minimum_size = Vector2(560, 84)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.name = "Slot%d" % n
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 16 if side in ["left", "right"] else 8)
	b.add_child(m)
	var v := UiKit.vbox(2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(v)
	var top := UiKit.hbox(12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	top.add_child(UiKit.label("Slot %d%s" % [n, "  ·  current" if active else ""], 15, Hud.GOLD if active else Hud.CYAN))
	top.add_child(UiKit.label(d.when, 15, Hud.DIM if d.empty else Hud.TEXT))
	if not d.empty:
		v.add_child(UiKit.body(d.gigs, 15, Hud.TEXT, false))
		var mid := String(d.where).begins_with("Mid-gig")
		v.add_child(UiKit.body(d.where, 15, Hud.GOLD if mid else Hud.GREEN, false))
	return b


func _slot_picked(mode: String, n: int) -> void:
	var over := SaveSlots.needs_confirm(n) and not (mode == "save" and n == Campaign.slot)
	if mode != "load" and over:
		show_page("confirm:%s:%d" % [mode, n])
		return
	_do(mode, n)


func _confirm(n: int, mode: String) -> Control:
	var d := SaveSlots.describe(SaveSlots.meta(n))
	_box.add_child(UiKit.label("Overwrite slot %d?" % n, 18, Hud.RED))
	_box.add_child(UiKit.body("%s · %s · %s\nThat save will be lost." % [d.when, d.gigs, d.where], 16, Hud.TEXT, false))
	var cancel := _button("Cancel", UiKit.NAV, show_page.bind(mode))
	_box.add_child(_button("Overwrite", UiKit.DANGER, _do.bind(mode, n)))
	_box.add_child(cancel)
	return cancel


func _do(mode: String, n: int) -> void:
	match mode:
		"new":
			Campaign.slot = n
			Campaign.current = Campaign.new_game(int(Time.get_unix_time_from_system()) % 100000)
			Campaign.current.save()
			get_tree().change_scene_to_file(BASE)
		"load":
			var c := Campaign.load_from(SaveSlots.path(n))
			if c == null or c.crew.is_empty():
				_note.text = "Slot %d can't be loaded (damaged, or saved by a newer build)." % n
				return
			Campaign.slot = n
			Campaign.current = c
			get_tree().change_scene_to_file(BASE)
		"save":
			Campaign.slot = n
			_note.text = ("Saved to slot %d." % n) if camp.save() else "Couldn't save to slot %d." % n
			show_page("main")


## Clicks on the Options heading: five show the hidden Developer mode toggle (GameSettings.dev_mode).
const DEV_CLICKS := 5
var _dev_clicks := 0


func _options() -> Control:
	var head := UiKit.label("Options", 18, Hud.CYAN)
	head.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.add_child(head)
	var first: Control = null
	for k in ["master", "music", "sfx", "shake"]:
		var names := {"master": "Master volume", "music": "Music", "sfx": "Sound effects", "shake": "Screen shake"}
		var row := UiKit.hbox(16)
		var l := UiKit.label(names[k], 16, Hud.TEXT)
		l.custom_minimum_size.x = 200
		row.add_child(l)
		var s := _slider(float(_opts[k]))
		var val := UiKit.label("%d%%" % roundi(float(_opts[k]) * 100), 16, Hud.CYAN)
		s.value_changed.connect(func(x: float) -> void:
			val.text = "%d%%" % roundi(x * 100)
			_set_opt(k, x))
		if k == "shake":
			s.name = "ScreenShake"
			s.tooltip_text = "How hard the view shakes on shots, blasts and hits. Reduced motion turns it off."
		row.add_child(s)
		row.add_child(val)
		_box.add_child(row)
		if first == null:
			first = s
	var fs := _button("Display: " + ("Fullscreen" if _opts.fullscreen else "Windowed"), UiKit.NAV, Callable())
	fs.pressed.connect(func() -> void:
		_set_opt("fullscreen", not bool(_opts.fullscreen))
		fs.text = UiKit.caps("Display: " + ("Fullscreen" if _opts.fullscreen else "Windowed")))
	_box.add_child(fs)
	var rm := _button("Reduced motion: " + ("On" if bool(_opts.get("reduced_motion", false)) else "Off"), UiKit.NAV, Callable())
	rm.name = "ReducedMotion"
	rm.tooltip_text = "Calmer animations: no tumbling dice, screen shake or hit-stop; callouts fade in."
	rm.pressed.connect(func() -> void:
		_set_opt("reduced_motion", not bool(_opts.get("reduced_motion", false)))
		rm.text = UiKit.caps("Reduced motion: " + ("On" if bool(_opts.reduced_motion) else "Off")))
	_box.add_child(rm)
	# Hidden: developer mode (the custom gig builder on JOBS). Shown once it is on, or after
	# DEV_CLICKS clicks on the heading, so a release build can turn it on too.
	var dev := _button(_dev_text(), UiKit.NAV, Callable())
	dev.name = "DevMode"
	dev.visible = bool(_opts.dev_mode) or _dev_clicks >= DEV_CLICKS
	dev.pressed.connect(func() -> void:
		_opts.dev_mode = not bool(_opts.dev_mode)   # nothing to apply: saved, read by GameSettings.dev_mode
		GameSettings.save_values(_opts)
		dev.text = UiKit.caps(_dev_text()))
	head.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_dev_clicks += 1
			if _dev_clicks >= DEV_CLICKS:
				dev.visible = true)
	_box.add_child(dev)
	_box.add_child(_button("Back", UiKit.NAV, show_page.bind("main")))
	return first


func _dev_text() -> String:
	return "Developer mode: " + ("On (custom gig builder on GIGS)" if bool(_opts.dev_mode) else "Off")


func _set_opt(k: String, v: Variant) -> void:
	_opts[k] = v
	GameSettings.apply(_opts, get_tree())
	GameSettings.save_values(_opts)


func _credits() -> Control:
	_box.add_child(UiKit.label("Credits", 18, Hud.CYAN))
	var v := UiKit.vbox(10)
	var secs: Array = CREDITS.slice(0, CREDITS.size() - 1) + QualityText.font_credits() + [CREDITS[-1]]   # the exotic faces as data has them
	for sec in secs:
		v.add_child(UiKit.label(sec[0], 15, Hud.GOLD))
		v.add_child(UiKit.body(sec[1], 15))
	var sc := UiKit.scroller(v)
	sc.custom_minimum_size = Vector2(760, 300)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	sc.focus_mode = Control.FOCUS_NONE
	_box.add_child(sc)
	var back := _button("Back", UiKit.NAV, show_page.bind("main"))
	_box.add_child(back)
	return back


const CREDITS := [
	["Cyberpunk Tactics", "A turn-based tactical game on the Cyberpunk RED tabletop rules (R. Talsorian Games), with a crew-and-gig campaign. Made with the Godot Engine (MIT licence)."],
	["3D models and animations: Quaternius (quaternius.com)", "CC0 1.0 Universal, public domain: Universal Animation Library 1 and 2, Universal Base Characters, Ultimate Gun Pack, Modular Sci-Fi MegaKit, Sci-Fi Essentials Kit, Stylized Nature MegaKit."],
	["Fonts: SIL Open Font License 1.1", "Chakra Petch (The Chakra Petch Project Authors), Jersey 10 (The Soft Type Project Authors), VT323 (The VT323 Project Authors), Noto Sans Symbols 2 (The Noto Project Authors)."],
	["Licence texts", "The full licence texts ship with the game in the licenses folder."],
]


func _button(text: String, style: String, cb: Callable, enabled := true) -> Button:
	var b := UiKit.button(text, style, cb, enabled, 18)
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(320, 44)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var f := CutBox.make(Color(0, 0, 0, 0), Hud.GOLD, 7, 0b0101)
	b.add_theme_stylebox_override("focus", f)
	b.mouse_entered.connect(func() -> void: if not b.disabled: b.grab_focus())
	return b


func _slider(v: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = v
	s.custom_minimum_size = Vector2(280, 28)
	s.focus_mode = Control.FOCUS_ALL
	s.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.03, 0.045, 0.06, 0.95)
	track.border_color = Color(Hud.CYAN, 0.45)
	track.set_border_width_all(1)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(Hud.CYAN, 0.7)
	var hot := StyleBoxFlat.new()
	hot.bg_color = Hud.GOLD
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", hot)
	var foc := StyleBoxFlat.new()
	foc.draw_center = false
	foc.border_color = Hud.GOLD
	foc.set_border_width_all(1)
	foc.set_expand_margin_all(4)
	s.add_theme_stylebox_override("focus", foc)
	s.mouse_entered.connect(s.grab_focus)
	return s


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if page.begins_with("confirm"):
			show_page(page.get_slice(":", 1))
		elif page != "main":
			show_page("main")
		elif pause:
			close()


## Pause: back to the safehouse.
func close() -> void:
	queue_free()


func _to_title() -> void:
	_autosave()
	Campaign.current = null
	get_tree().change_scene_to_file(TITLE)


func _quit() -> void:
	_autosave()
	get_tree().quit()


func _autosave() -> void:
	if pause and camp != null and not camp.has_meta("demo"):
		camp.save()
