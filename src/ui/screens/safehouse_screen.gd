class_name SafehouseScreen
extends Control
## A between-gigs screen, opened full screen from its room in the safehouse (owner: the
## safehouse is the hub; one screen = one job). Every screen has the same top bar (where you are,
## day, eb, the crew's best Reputation) with BACK TO SAFEHOUSE in the same place, then optional
## tabs, then the screen's body. Subclasses fill `build_body`. Long lists scroll inside their own
## panels; nothing scrolls sideways.

signal closed
signal navigate(screen_id: String)

var camp: Campaign
var portraits: Portraits
var tab := ""             ## the open tab's id (tabs())
var sel := 0              ## the selected crew member (index into camp.alive_crew())
var show_back := true     ## the debrief has CONTINUE instead
var _content: Control


func setup(p_camp: Campaign, p_portraits: Portraits, p_tab := "", p_sel := 0) -> SafehouseScreen:
	camp = p_camp
	portraits = p_portraits
	sel = p_sel
	var t := tabs()
	tab = p_tab if t.any(func(x): return x[0] == p_tab) else (String(t[0][0]) if not t.is_empty() else "")
	return self


## The room the screen belongs to (breadcrumb) and its heading.
func room_name() -> String:
	return ""


func title() -> String:
	return ""


## [[id, label], ...]; one entry or none: no tab row.
func tabs() -> Array:
	return []


func build_body(_body: VBoxContainer) -> void:
	pass


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("06080c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_build()
	if is_inside_tree():   # layouts that depend on the width (Training's skill columns) follow the window
		get_viewport().size_changed.connect(func(): if is_inside_tree(): _build.call_deferred())


## Rebuild after a change, and save (never in a dev demo).
func refresh() -> void:
	if not camp.has_meta("demo"):
		camp.save()
	_build()


func _build() -> void:
	if _content:
		_content.queue_free()
	sel = clampi(sel, 0, maxi(0, camp.alive_crew().size() - 1))
	var root := UiKit.vbox(10)
	_content = root
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 14
	root.offset_right = -14
	root.offset_top = 10
	root.offset_bottom = -12
	add_child(root)
	root.add_child(top_bar(camp, title(), room_name(), _back if show_back else Callable()))
	var t := tabs()
	if t.size() > 1:
		var row := UiKit.hbox(8)
		for x in t:
			var id: String = x[0]
			row.add_child(UiKit.tab(String(x[1]), id == tab, func(): tab = id; _build()))
		root.add_child(row)
	var body := UiKit.vbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	build_body(body)


func _back() -> void:
	closed.emit()


## The bar along the top of every screen (and the safehouse itself): heading, breadcrumb, day, eb,
## the crew's best Reputation, and BACK TO SAFEHOUSE at the right end when `back` is valid.
static func top_bar(c: Campaign, heading: String, crumb: String, back: Callable) -> PanelContainer:
	var p := UiKit.panel(Hud.CYAN, 8)
	var row := UiKit.hbox(18)
	p.add_child(row)
	var names := UiKit.hbox(12)
	if crumb != "":
		var cl := UiKit.label("SAFEHOUSE  ›  " + crumb, 14, Hud.CYAN)
		cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		names.add_child(cl)
	names.add_child(UiKit.head(heading, 34, Hud.TEXT))
	row.add_child(names)
	row.add_child(UiKit.spacer())
	for s in [["DAY", str(c.day)], ["EB", UiKit.money(c.eb)], ["BEST REPUTATION", str(c.best_reputation())]]:
		var v := UiKit.vbox(-4)
		v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		v.add_child(UiKit.label(s[0], 12, Hud.DIM))
		v.add_child(UiKit.label(s[1], 19, Hud.TEXT))
		row.add_child(v)
	if back.is_valid():
		var b := UiKit.button("‹  BACK TO SAFEHOUSE", UiKit.NAV, back, true, 15)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
	return p


## A short message floating up from `at` (a purchase confirmed at the button).
func toast(at: Control, text: String, col := Hud.GREEN) -> void:
	if not is_inside_tree():
		return
	var l := UiKit.label(text, 15, col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.z_index = 10
	add_child(l)
	l.reset_size()
	var r := at.get_global_rect() if is_instance_valid(at) else Rect2(size / 2, Vector2.ZERO)
	var pos := Vector2(r.position.x + r.size.x / 2 - l.size.x / 2, r.position.y - l.size.y - 2)
	l.position = pos.clamp(Vector2(4, 4), size - l.size - Vector2(4, 4))
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 22, 1.1).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.5)
	tw.tween_callback(l.queue_free)


## A button whose action changes the campaign: run it, rebuild, then toast at the new button in
## the same place (the old one is gone after the rebuild).
func act(b: Button, cb: Callable, msg := "", col := Hud.GREEN) -> void:
	var r := b.get_global_rect() if b.is_inside_tree() else Rect2()
	cb.call()
	refresh()
	if msg != "" and is_inside_tree():
		var marker := Control.new()
		add_child(marker)
		marker.position = r.position
		marker.size = r.size
		toast(marker, msg, col)
		marker.queue_free.call_deferred()


# --- Shared pieces -----------------------------------------------------------------------

## The crew down the left: compact cards (portrait, name, role, HP); the selected one in gold.
## `extra` (optional) gives one more line per member; `marks` (optional) the last-gig marks to show
## as chips (Campaign.marks_for, filtered to what the room is about).
func crew_picker(extra := Callable(), width := 290, marks := Callable()) -> VBoxContainer:
	var col := UiKit.vbox(6)
	col.custom_minimum_size.x = width
	col.add_child(UiKit.label("CREW", 14, Hud.CYAN))
	var cards := UiKit.vbox(6)   # scrolls if the marks make the cards taller than the screen
	var sc := UiKit.scroller(cards)
	col.add_child(sc)
	var crew := camp.alive_crew()
	for i in crew.size():
		var c: Combatant = crew[i]
		var on := i == sel
		var card := UiKit.selected_panel(8) if on else UiKit.panel(Hud.CYAN, 8)
		var row := UiKit.hbox(10)
		card.add_child(row)
		row.add_child(UiKit.portrait(portraits, c, 1000 + maxi(0, c.look_seed), 52))
		var v := UiKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		v.add_child(UiKit.fit(UiKit.head(c.display_name, 28, Hud.GOLD if on else Hud.TEXT)))
		v.add_child(UiKit.role_hp(c))
		if extra.is_valid():
			var e: Variant = extra.call(c)
			if e is String and e != "":
				v.add_child(UiKit.fit(UiKit.label(String(e), 13, Hud.CYAN)))
		if marks.is_valid():
			var ms: Array = marks.call(c)
			if not ms.is_empty():
				var f := UiKit.flow(4)
				for m in ms:
					f.add_child(mark_chip(String(m)))
				v.add_child(f)
		var idx := i
		UiKit.clickable(card, func(): sel = idx; _build())
		card.mouse_filter = Control.MOUSE_FILTER_PASS   # the wheel still scrolls the list
		cards.add_child(card)
	return col


## A last-gig mark in its colour meaning: IP and Reputation are information (cyan), injuries and
## addictions danger (red), Humanity chrome (violet).
static func mark_chip(m: String) -> PanelContainer:
	var col := Hud.CYAN
	if m.begins_with("ADDICTED") or not (m.begins_with("+") or m.begins_with("REPUTATION") or m.ends_with("HUMANITY")):
		col = Hud.RED
	elif m.ends_with("HUMANITY"):
		col = Hud.VIOLET.lightened(0.3)
	return UiKit.chip(m, col)


func selected() -> Combatant:
	var crew := camp.alive_crew()
	return crew[sel] if sel < crew.size() else null


## A section heading inside a panel.
static func section(text: String, col := Hud.CYAN) -> Label:
	return UiKit.label(text, 14, col)


## An empty-state line.
static func none(text: String) -> Label:
	return UiKit.body(text, 15, Hud.DIM)
