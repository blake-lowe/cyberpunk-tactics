class_name DevMenu
extends SafehouseScreen
## DEV ONLY: the safehouse dev menu (developer mode, GameSettings.dev_mode), opened from the hub's
## DEV button or the ` key (BaseView). Money (add or set eb), the crew (heal, Humanity, Reputation,
## IP, the day) and every item storage can hold, put into storage by count (DevCheats.catalog,
## filtered by tab and search). Every change goes through DevCheats: logged "[DEV] ..." and counted
## on the campaign (Campaign.dev_cheats), so the save says it was cheated.

const ROW_LIMIT := 120   ## rows built at once: a search narrows the rest

var cat := "all"
var query := ""
var qty := 1
var picks := {}           ## entry key → the variant suffix picked
var _list: VBoxContainer
var _count: Label
var _search: LineEdit


func room_name() -> String:
	return "DEV"


func title() -> String:
	return "Dev menu"


func build_body(body: VBoxContainer) -> void:
	if not GameSettings.dev_mode():
		body.add_child(none("Developer mode is off."))
		return
	var row := UiKit.hbox(12)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(row)
	var left := UiKit.vbox(10)
	left.custom_minimum_size.x = 330
	row.add_child(left)
	left.add_child(_money())
	left.add_child(_crew())
	row.add_child(_equipment())


func _box(head: String) -> Array:
	var p := UiKit.panel(Hud.MAGENTA, 10)
	var v := UiKit.vbox(6)
	p.add_child(v)
	v.add_child(section(head, Hud.MAGENTA))
	return [p, v]


func _money() -> PanelContainer:
	var b: Array = _box("Money")
	var v: VBoxContainer = b[1]
	var quick := UiKit.hbox(6)
	v.add_child(quick)
	for n in [1000, 10000, 100000]:
		var amount: int = n
		var btn := UiKit.button("+%dk" % (n / 1000), UiKit.NEUTRAL, Callable(), true, 14, true)
		btn.name = "Eb%d" % n
		btn.pressed.connect(func(): act(btn, func(): DevCheats.add_eb(camp, amount), "+%s eb" % UiKit.money(amount)))
		quick.add_child(btn)
	var line := UiKit.hbox(6)
	v.add_child(line)
	var field := _spin(0, 99999999, 1, 1000)
	field.name = "EbField"
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(field)
	var add := UiKit.button("Add", UiKit.NEUTRAL, Callable(), true, 14, true)
	add.name = "EbAdd"
	add.pressed.connect(func(): act(add, func(): DevCheats.add_eb(camp, int(field.value)), "+%s eb" % UiKit.money(int(field.value))))
	line.add_child(add)
	var set_b := UiKit.button("Set", UiKit.NEUTRAL, Callable(), true, 14, true)
	set_b.name = "EbSet"
	set_b.pressed.connect(func(): act(set_b, func(): DevCheats.set_eb(camp, int(field.value)), "eb set"))
	line.add_child(set_b)
	return b[0]


func _crew() -> PanelContainer:
	var b: Array = _box("Crew")
	var v: VBoxContainer = b[1]
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	v.add_child(g)
	for x in [["Heal all", "Heal", UiKit.HEALTH, func(): DevCheats.heal_all(camp), "Healed"],
			["Restore Humanity", "Humanity", UiKit.CHROME, func(): DevCheats.restore_humanity(camp), "Humanity restored"],
			["+1 Reputation", "Rep", UiKit.NEUTRAL, func(): DevCheats.add_reputation(camp, 1), "+1 Reputation"],
			["+10 IP", "Ip10", UiKit.NEUTRAL, func(): DevCheats.give_ip(camp, 10), "+10 IP"],
			["+100 IP", "Ip100", UiKit.NEUTRAL, func(): DevCheats.give_ip(camp, 100), "+100 IP"]]:
		var btn := UiKit.button(String(x[0]), String(x[2]), Callable(), true, 14, true)
		btn.name = String(x[1])
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cb: Callable = x[3]
		var msg: String = x[4]
		btn.pressed.connect(func(): act(btn, cb, msg))
		g.add_child(btn)
	var line := UiKit.hbox(6)
	v.add_child(line)
	var dl := UiKit.label("Day", 13, Hud.DIM)
	dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(dl)
	var day := _spin(1, 9999, 1, camp.day)
	day.name = "DayField"
	day.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(day)
	var set_d := UiKit.button("Set day", UiKit.NEUTRAL, Callable(), true, 14, true)
	set_d.name = "DaySet"
	set_d.pressed.connect(func(): act(set_d, func(): DevCheats.set_day(camp, int(day.value)), "Day %d" % int(day.value)))
	line.add_child(set_d)
	v.add_child(UiKit.body("Cheats are logged and the save is marked.", 13, Hud.DIM))
	return b[0]


func _equipment() -> PanelContainer:
	var b: Array = _box("Equipment to storage")
	var p: PanelContainer = b[0]
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v: VBoxContainer = b[1]
	var tabs_row := UiKit.flow(4)
	v.add_child(tabs_row)
	for c in DevCheats.CATS:
		var id: String = c[0]
		var t := UiKit.button(String(c[1]), UiKit.PRIMARY if id == cat else UiKit.NAV, Callable(), true, 13, true)
		t.name = "Cat_" + id
		if id == cat:
			t.add_theme_stylebox_override("normal", UiKit._btn_box(Color(0.14, 0.11, 0.02, 0.97), Hud.GOLD, true))
		t.pressed.connect(func(): cat = id; _build())
		tabs_row.add_child(t)
	var line := UiKit.hbox(8)
	v.add_child(line)
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = "search"
	_search.text = query
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style(_search)
	_search.text_changed.connect(func(t: String): query = t; _fill_list())
	line.add_child(_search)
	var ql := UiKit.label("Count", 13, Hud.DIM)
	ql.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(ql)
	var qs := _spin(1, 99, 1, qty)
	qs.name = "Qty"
	qs.value_changed.connect(func(x: float): qty = int(x))
	line.add_child(qs)
	_count = UiKit.label("", 12, Hud.DIM)
	v.add_child(_count)
	_list = UiKit.vbox(3)
	var sc := UiKit.scroller(_list)
	sc.custom_minimum_size.y = 200
	v.add_child(sc)
	_fill_list()
	return p


## The rows for the tab and search (rebuilt as the search changes; the rest of the screen stays).
func _fill_list() -> void:
	if _list == null:
		return
	for ch in _list.get_children():
		ch.queue_free()
	var items := DevCheats.filter(cat, query)
	_count.text = UiKit.caps("%d items%s" % [items.size(), "  ·  first %d shown, search to narrow" % ROW_LIMIT if items.size() > ROW_LIMIT else ""])
	for e in items.slice(0, ROW_LIMIT):
		_list.add_child(_row(e))
	if items.is_empty():
		_list.add_child(none("Nothing matches."))


func _row(e: Dictionary) -> Control:
	var r := UiKit.hbox(8)
	r.name = "Row_" + String(e.key).replace("/", "_")
	var nm := UiKit.fit(UiKit.label(String(e.name), 14, Hud.TEXT))
	r.add_child(nm)
	if String(e.note) != "":
		var n := UiKit.label(String(e.note), 11, Hud.DIM)
		n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(n)
	var vs: Array = e.variants
	var opt: OptionButton = null
	if not vs.is_empty():
		opt = OptionButton.new()
		opt.name = "Variant"
		_style(opt)
		opt.fit_to_longest_item = false
		opt.clip_text = true
		opt.custom_minimum_size.x = 150
		var cur := String(picks.get(e.key, e.default))
		for i in vs.size():
			opt.add_item(String(vs[i][1]))
			opt.set_item_metadata(i, String(vs[i][0]))
			if String(vs[i][0]) == cur:
				opt.selected = i
		opt.item_selected.connect(func(i: int): picks[e.key] = String(opt.get_item_metadata(i)))
		r.add_child(opt)
	else:   # the counts and ADD stay in one column
		var gap := Control.new()
		gap.custom_minimum_size.x = 150
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(gap)
	var have := UiKit.label("", 12, Hud.CYAN)
	have.custom_minimum_size.x = 64
	have.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	have.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(have)
	var show_have := func(): have.text = UiKit.caps("have %d" % camp.stored(DevCheats.key_for(e, String(picks.get(e.key, e.default)))))
	show_have.call()
	if opt:
		opt.item_selected.connect(func(_i: int): show_have.call())
	var add := UiKit.button("Add", UiKit.NEUTRAL, Callable(), true, 13, true)
	add.name = "Add"
	add.pressed.connect(func():
		var key := DevCheats.key_for(e, String(picks.get(e.key, e.default)))
		if DevCheats.give(camp, key, qty):
			_save()
			show_have.call()
			toast(add, "+%d %s" % [qty, Items.display_name(key)]))
	r.add_child(add)
	return r


## Add an item: save without rebuilding the screen (the list, its scroll and the search stay put).
func _save() -> void:
	if not camp.has_meta("demo"):
		camp.save()


func _spin(lo: int, hi: int, step: int, v: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = v
	s.custom_minimum_size.x = 90
	s.get_line_edit().add_theme_font_override("font", Hud.F_BODY)
	s.get_line_edit().add_theme_font_size_override("font_size", 14)
	return s


static func _style(c: Control) -> void:
	c.add_theme_font_override("font", Hud.F_BODY)
	c.add_theme_font_size_override("font_size", 14)
	c.focus_mode = Control.FOCUS_CLICK if c is OptionButton else Control.FOCUS_ALL


func _unhandled_input(ev: InputEvent) -> void:   # the ` key that opened it closes it again
	if ev is InputEventKey and ev.pressed and not ev.echo and (ev as InputEventKey).keycode == BaseView.DEV_KEY:
		get_viewport().set_input_as_handled()
		_back()
