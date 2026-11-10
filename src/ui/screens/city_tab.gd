class_name CityTab
extends HBoxContainer
## The Fixer Network's CITY tab (M9 P3): the CityMap and a side panel with the job offers. Picking
## an offer (its row, again to clear it) plots it on the map: the drive from the safehouse district,
## animated, and the gig's pin. The panel then shows the drive (time and the districts crossed) and
## the job, with a button to open it in JOBS, where gigs are taken; clicking the pin does the same.
## The panel is a fixed width whatever it holds, so the map never resizes under the mouse.

signal open_job(index: int)

const PANEL_W := 318

var camp: Campaign
var map: CityMap
var _side: Control        ## a plain Control: its minimum width is PANEL_W, never its content's
var _panel: PanelContainer


func setup(p_camp: Campaign) -> CityTab:
	camp = p_camp
	add_theme_constant_override("separation", 10)
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var frame := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = CityMap.LAND
	box.border_color = Color(Hud.CYAN, 0.25)
	box.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel", box)
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(frame)
	map = CityMap.new().setup(camp)
	map.custom_minimum_size = Vector2(320, 240)
	frame.add_child(map)
	map.clicked.connect(_on_click)
	_side = Control.new()
	_side.custom_minimum_size.x = PANEL_W
	_side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_side.clip_contents = true
	add_child(_side)
	_panel = UiKit.panel(Hud.CYAN, 12)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_side.add_child(_panel)
	var pick := -1
	if camp.has_meta("demo"):   # DEV: --pin=<board index> starts with that offer plotted, for review shots
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--pin="):
				pick = int(a.get_slice("=", 1))
	select_gig(pick)
	return self


## Plot offer `i` on the map (-1: none) and show it in the panel.
func select_gig(i: int) -> void:
	map.select_gig(i)
	_refresh()


func _on_click(kind: String, id: String) -> void:
	if kind == "pin":
		open_job.emit(int(id))


func _refresh() -> void:
	for c in _panel.get_children():
		_panel.remove_child(c)
		c.queue_free()
	var v := UiKit.vbox(8)
	v.add_child(UiKit.head("NIGHT CITY", 32, Hud.TEXT))
	var home := String(World.district(map.safehouse).get("name", "")) if map.safehouse != "" else ""
	v.add_child(UiKit.body("Pick a gig to plot the drive%s." % ((" from the safehouse in " + home) if home != "" else ""), 13, Hud.DIM))
	v.add_child(SafehouseScreen.section("GIG OFFERS"))
	if camp.board.is_empty():
		v.add_child(SafehouseScreen.none("No offers today."))
	for i in camp.board.size():
		v.add_child(_offer_row(i))
	if map.gig >= 0:
		_drive(v, map.gig)
	var pad := MarginContainer.new()   # clear of the scroll bar
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_child(v)
	_panel.add_child(UiKit.scroller(pad))


## The selected job: the drive (time, the districts crossed) and the offer, with a way to JOBS.
func _drive(v: VBoxContainer, i: int) -> void:
	var g: Dictionary = camp.board[i]
	v.add_child(SafehouseScreen.section("THE DRIVE", Hud.GOLD))
	var t := map.drive_text()
	v.add_child(UiKit.label(t if t != "" else "NO ROUTE ON THE MAP", 20, Hud.GOLD))
	if not map.route.is_empty():
		v.add_child(UiKit.body(" › ".join(map.route.map(func(d): return String(World.district(d).get("name", d)))), 13, Color(Hud.TEXT, 0.8)))
	v.add_child(UiKit.body(" · ".join([String(g.fixer), Campaign.place_name(g), Campaign.district_name(g)].filter(func(s): return s != "")), 13, Hud.CYAN))
	var obj := String(FixerScreen.OBJECTIVE_TEXT.get(Campaign.objective_for(g), ""))
	if obj != "":
		v.add_child(UiKit.body("★ " + obj, 13, Hud.TEXT))
	v.add_child(UiKit.button("OPEN IN GIGS", UiKit.NEUTRAL, func(): open_job.emit(i)))


## An offer as a selectable row: its number, title, district and pay (gold-filled when picked).
func _offer_row(i: int) -> Control:
	var g: Dictionary = camp.board[i]
	var p := UiKit.selected_panel(6) if i == map.gig else UiKit.panel(Hud.GOLD, 6)
	var h := UiKit.hbox(8)
	p.add_child(h)
	var num := UiKit.label(str(i + 1), 15, Hud.GOLD)
	num.custom_minimum_size.x = 14
	num.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(num)
	var t := UiKit.vbox(0)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	t.add_child(UiKit.body(String(g.title), 13, Hud.TEXT))
	var did := String(g.get("district", ""))
	t.add_child(UiKit.label("%s · %s eb" % [String(World.district(did).get("name", "Night City")) if did != "" else "Night City", UiKit.money(int(g.get("pay", 0)))], 11, Hud.DIM))
	UiKit.clickable(p, func(): select_gig.call_deferred(-1 if map.gig == i else i))
	return p
