class_name MarketTab
extends PanelContainer
## The Fixer Network's NIGHT MARKET tab as a web shop (owner's verdicts: proposal A's dark web
## portal around proposal C's dense list; list only, no cards or art). A slim address bar (the
## node's address, a connection readout and, in plain words, how long the Night Market is here),
## then three columns: a rail (the shop's logo, categories with counts, filters), the list (search,
## sort, item count; a row per item and Quality Rating with its full description, tier, source,
## owned count, price and a − qty + stepper; category headers when sorted by type) and a cart that
## is always open. The fixer's stock and the market's listings are one list, market items badged
## with the days left. The cart is bought in one go (Campaign.buy_cart) into safehouse storage.
## Shop logic is Shop (src/meta/); the state (cart, filters, sort) belongs to the screen
## (FixerScreen.shop) and lasts while it's open.
##
## DEV ONLY (review shots, with --demo): --cart=<key>[:n],... fills the cart;
## --shop-filter=market,afford,owned; --shop-cat=<category>; --shop-sort=type|low|high;
## --shop-q=<text>; --checkout buys the cart once the tab is up.

signal bought   ## a checkout went through: the screen saves and rebuilds (the top bar's eb)

const RAIL_W := 168
const CART_W := 260
const RAIL_W_COMPACT := 148
const CART_W_COMPACT := 236
const COMPACT_BELOW := 1200.0   ## logical width (UiScale): 1600x900 lays out at 1067x600
## The portal's own darker inks (the mockup's), around the HUD palette.
const BG := Color("04060a")
const BAR_BG := Color("0a0e14")
const LINE := Color("1b2430")
const FIELD_BG := Color("020305")
const FIELD_LINE := Color("1d2a35")
const CART_BG := Color("070a0f")
const RAIL_ON := Color("120910")
const H_DIM := Color("5f7180")      ## rail and column headings
const FIXER_TEAL := Color("3f8f98")  ## the fixer's own stock (the market's badge is magenta)
const ADDR := Color("9fb2c2")
## List columns (logical px): item, tier, source, owned, price, qty; stats take the rest. Compact
## (narrow logical screens) folds the tier under the price.
const COLS := {"item": 150, "tier": 90, "source": 84, "owned": 40, "price": 70, "qty": 78}
const COLS_COMPACT := {"item": 128, "tier": 0, "source": 80, "owned": 36, "price": 84, "qty": 78}

var camp: Campaign
var state: Dictionary
var compact := false
var _all: Array[Dictionary] = []
var _rail: VBoxContainer
var _tools: HBoxContainer
var _search: LineEdit
var _count: Label
var _holder: VBoxContainer   ## the list header and the scrolling rows
var _scroll: ScrollContainer
var _stack: Control          ## results with the checkout toast over them
var _cart: VBoxContainer
var _wire: Button


## A fresh shop state: the cart (storage key → how many), the category, filters, search and sort.
static func new_state() -> Dictionary:
	return {"cart": {}, "cat": Shop.ALL, "market_only": false, "afford": false, "hide_owned": false, "query": "",
		"sort": "type", "toast": "", "toast_ok": true}


## `width`: the screen's logical width (below COMPACT_BELOW: narrower rail, cart and columns).
func setup(p_camp: Campaign, p_state: Dictionary, width := 1280.0) -> MarketTab:
	camp = p_camp
	state = p_state
	compact = width < COMPACT_BELOW
	var checkout_now := false
	if camp.has_meta("demo") and not state.get("_flags", false):
		state["_flags"] = true
		checkout_now = _dev_flags(OS.get_cmdline_user_args())
	_all = Shop.entries(camp)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", _flat(BG, LINE, [1, 1, 1, 1], 0))
	theme = _tip_theme()
	var col := UiKit.vbox(0)
	add_child(col)
	col.add_child(_address_bar())
	var main := UiKit.hbox(0)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(main)
	var rail := PanelContainer.new()
	rail.custom_minimum_size.x = RAIL_W_COMPACT if compact else RAIL_W
	rail.add_theme_stylebox_override("panel", _flat(Color(1, 1, 1, 0.006), LINE, [0, 0, 1, 0], 12))
	_rail = UiKit.vbox(10 if compact else 14)
	rail.add_child(UiKit.scroller(_rail))   # a short screen scrolls the rail rather than overflow
	main.add_child(rail)
	var centre := UiKit.vbox(0)
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(centre)
	centre.add_child(_toolbar())
	_stack = Control.new()
	_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stack.clip_contents = true
	centre.add_child(_stack)
	_holder = UiKit.vbox(0)
	_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stack.add_child(_holder)
	var cart := PanelContainer.new()
	cart.custom_minimum_size.x = CART_W_COMPACT if compact else CART_W
	cart.add_theme_stylebox_override("panel", _flat(CART_BG, LINE, [1, 0, 0, 0], 0))
	_cart = UiKit.vbox(0)
	cart.add_child(_cart)
	main.add_child(cart)
	_refresh(false)
	if String(state.get("toast", "")) != "":
		_show_toast(String(state.toast), bool(state.get("toast_ok", true)))
		state.toast = ""
	if checkout_now:
		checkout.call_deferred()
	return self


# --- Actions (the buttons call these; tests too) ------------------------------------------

func add(key: String, n := 1) -> void:
	Shop.cart_add(state.cart, key, n)
	_refresh(true)


func set_qty(key: String, n: int) -> void:
	Shop.cart_set(state.cart, key, n)
	_refresh(true)


func clear_cart() -> void:
	(state.cart as Dictionary).clear()
	_refresh(true)


func set_cat(c: String) -> void:
	state.cat = c
	_refresh(false)


## "market_only", "afford" or "hide_owned".
func toggle(flag: String) -> void:
	state[flag] = not bool(state.get(flag, false))
	_refresh(false)


func set_sort(s: String) -> void:
	state.sort = s
	_refresh(false)


func set_query(q: String) -> void:
	state.query = q
	if _search and _search.text != q:
		_search.text = q
	_refresh(false)


## Buy the whole cart (Campaign.buy_cart, all or nothing). On success the cart empties, the screen
## rebuilds (bought) and the new tab shows the toast; a refusal is a red toast here.
func checkout() -> Dictionary:
	var r := camp.buy_cart(state.cart)
	if bool(r.ok):
		(state.cart as Dictionary).clear()
		state.toast = "Bought %d item%s for %s eb" % [int(r.count), "" if int(r.count) == 1 else "s", UiKit.money(int(r.total))]
		state.toast_ok = true
		bought.emit()
	else:
		var why := {"short": "Not enough eb for the cart", "empty": "The cart is empty",
			"off_sale": "%s isn't on sale any more" % Items.display_name(String(r.key))}
		_show_toast(String(why.get(String(r.reason), "Couldn't buy the cart")), false)
	return r


## The entries the shop shows now, filtered and sorted.
func visible_entries() -> Array[Dictionary]:
	return Shop.sorted(Shop.filtered(_all, state, _budget(), state.cart), String(state.sort))


func _budget() -> int:
	return camp.eb - camp.cart_due(state.cart)


func _refresh(keep_scroll: bool) -> void:
	_build_rail()
	_build_tools()
	_build_results(keep_scroll)
	_build_cart()


# --- Address bar ---------------------------------------------------------------------------

## "nmkt://ghost-7f3a.node/bazaar/  ·  3 HOPS · ICE CLEAN" (flavour) and, in plain words, how long
## the Night Market is here (owner: no "node goes dark").
func _address_bar() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _flat(BAR_BG, LINE, [0, 0, 0, 1], 0, Vector4(10, 4, 12, 4)))
	var row := UiKit.hbox(10)
	p.add_child(row)
	row.add_child(_mono("‹  ›", 19, Color("4d5b68")))
	var addr := PanelContainer.new()
	addr.add_theme_stylebox_override("panel", _flat(FIELD_BG, FIELD_LINE, [1, 1, 1, 1], 0, Vector4(8, 0, 8, 0)))
	addr.custom_minimum_size = Vector2(380 if compact else 520, 24)
	var a := UiKit.hbox(8)
	addr.add_child(a)
	var up := Shop.days_left(camp) >= 0
	var lock := ColorRect.new()
	lock.color = Hud.GREEN if up else H_DIM
	lock.custom_minimum_size = Vector2(9, 9)
	lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	a.add_child(lock)
	var h := hash("%s|%s" % [camp.market.get("opened", camp.day), NightMarket.title(camp.market)])
	a.add_child(_mono("nmkt://ghost-%04x.node/bazaar/" % (absi(h) % 0x10000), 19, ADDR))
	a.add_child(UiKit.spacer())
	a.add_child(_mono("%d HOPS · ICE CLEAN" % (2 + absi(h) % 4) if up else "NO ROUTE", 17, Hud.GREEN if up else H_DIM))
	row.add_child(addr)
	row.add_child(UiKit.spacer())
	if up:
		var blink := ColorRect.new()
		blink.color = Hud.MAGENTA
		blink.custom_minimum_size = Vector2(8, 8)
		blink.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(blink)
		blink.ready.connect(func():
			var tw := blink.create_tween().set_loops()
			tw.tween_property(blink, "modulate:a", 0.15, 0.0).set_delay(0.6)
			tw.tween_property(blink, "modulate:a", 1.0, 0.0).set_delay(0.6))
	row.add_child(_mono(Shop.market_note(camp).to_upper(), 19, Hud.MAGENTA if up else H_DIM))
	return p


# --- Rail: logo, categories, filters ---------------------------------------------------------

func _build_rail() -> void:
	_clear(_rail)
	var logo := UiKit.vbox(0)
	logo.add_child(UiKit.head("NIGHT", 32 if compact else 40, Hud.TEXT))
	logo.add_child(UiKit.head("MARKET", 32 if compact else 40, Hud.MAGENTA))
	var title := NightMarket.title(camp.market)
	var sub := UiKit.body((title + " and the fixer's own stock") if title != "" else "No Night Market is up: the fixer's own stock", 12, Hud.DIM)
	logo.add_child(sub)
	_rail.add_child(logo)
	var cats := UiKit.vbox(1)
	cats.add_child(_rail_head("SHOP"))
	var n := Shop.counts(_all, state, _budget(), state.cart)
	for c in [Shop.ALL] + Shop.listed_categories(_all):
		cats.add_child(_cat_row(String(c), int(n.get(c, 0))))
	_rail.add_child(cats)
	var fl := UiKit.vbox(6)
	fl.add_child(_rail_head("FILTER"))
	for f in [["market_only", "Market only"], ["afford", "I can afford it"], ["hide_owned", "Hide what I own"]]:
		fl.add_child(_check(String(f[0]), String(f[1])))
	_rail.add_child(fl)


func _rail_head(s: String) -> Label:
	var l := UiKit.label(s, 11, H_DIM)
	l.add_theme_constant_override("outline_size", 0)
	return l


func _cat_row(c: String, count: int) -> Control:
	var on := String(state.cat) == c
	var p := PanelContainer.new()
	p.name = "Cat" + c
	p.add_theme_stylebox_override("panel", _flat(RAIL_ON if on else Color(0, 0, 0, 0), Hud.MAGENTA if on else Color(0, 0, 0, 0), [2, 0, 0, 0], 0, Vector4(8, 3, 6, 3)))
	var row := UiKit.hbox(6)
	p.add_child(row)
	row.add_child(UiKit.fit(UiKit.label(c, 14, Hud.TEXT if on else Hud.DIM)))
	row.add_child(_mono(str(count), 19, Hud.TEXT if on else H_DIM))
	UiKit.clickable(p, func(): set_cat(c))
	return p


func _check(flag: String, text: String) -> Control:
	var on := bool(state.get(flag, false))
	var row := UiKit.hbox(8)
	row.name = "Filter_" + flag
	var box := Panel.new()
	box.custom_minimum_size = Vector2(14, 14)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_theme_stylebox_override("panel", _flat(Hud.CYAN if on else Color(0, 0, 0, 0), Hud.CYAN if on else Color("3a4a58"), [1, 1, 1, 1], 0))
	row.add_child(box)
	row.add_child(UiKit.body(text, 14, Hud.TEXT if on else Hud.DIM, false))
	UiKit.clickable(row, func(): toggle(flag))
	return row


# --- Toolbar: search, sort, count, GRID / LIST --------------------------------------------

func _toolbar() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _flat(Color(0, 0, 0, 0), LINE, [0, 0, 0, 1], 0, Vector4(12, 8, 12, 8)))
	var row := UiKit.hbox(10)
	p.add_child(row)
	var field := PanelContainer.new()
	field.add_theme_stylebox_override("panel", _flat(FIELD_BG, FIELD_LINE, [1, 1, 1, 1], 0, Vector4(8, 0, 8, 0)))
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var f := UiKit.hbox(6)
	field.add_child(f)
	f.add_child(_mono(">", 19, Hud.DIM))
	_search = LineEdit.new()
	_search.name = "Search"
	_search.placeholder_text = "search the market"
	_search.text = String(state.query)
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.custom_minimum_size = Vector2(60, 28)
	_search.add_theme_font_override("font", Hud.F_MONO)
	_search.add_theme_font_size_override("font_size", 19)
	_search.add_theme_color_override("font_color", Hud.TEXT)
	_search.add_theme_color_override("font_placeholder_color", H_DIM)
	_search.add_theme_color_override("caret_color", Hud.CYAN)
	_search.add_theme_color_override("selection_color", Color(Hud.CYAN, 0.3))
	for s in ["normal", "focus", "read_only"]:
		_search.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	_search.clear_button_enabled = true
	_search.add_theme_color_override("clear_button_color", H_DIM)
	_search.add_theme_color_override("clear_button_color_pressed", Hud.CYAN)
	_search.text_changed.connect(func(t: String): state.query = t; _refresh(false))
	f.add_child(_search)
	row.add_child(field)
	_tools = UiKit.hbox(10)
	row.add_child(_tools)
	return p


func _build_tools() -> void:
	_clear(_tools)
	var sorts := UiKit.hbox(2)
	for s in [["type", "TYPE"], ["low", "PRICE ↑"], ["high", "PRICE ↓"]]:
		var id: String = s[0]
		sorts.add_child(_pill(String(s[1]), String(state.sort) == id, func(): set_sort(id), "Sort_" + id))
	_tools.add_child(sorts)
	_count = _mono("%d ITEMS" % visible_entries().size(), 19, H_DIM)
	_count.name = "Count"
	_tools.add_child(_count)


## A small square toggle button: cyan edge and text when on.
func _pill(text: String, on: bool, cb: Callable, nm: String) -> Button:
	var b := Button.new()
	b.name = nm
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", Hud.F_BOLD)
	b.add_theme_font_size_override("font_size", 13)
	var col := Hud.CYAN if on else Hud.DIM
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(st, col.lightened(0.25) if st == "font_hover_color" else col)
	b.add_theme_stylebox_override("normal", _flat(Color(Hud.CYAN, 0.08) if on else Color(0, 0, 0, 0), Hud.CYAN if on else FIELD_LINE, [1, 1, 1, 1], 0, Vector4(8, 3, 8, 3)))
	b.add_theme_stylebox_override("hover", _flat(Color(Hud.CYAN, 0.12), Color(Hud.CYAN, 0.7), [1, 1, 1, 1], 0, Vector4(8, 3, 8, 3)))
	b.add_theme_stylebox_override("pressed", b.get_theme_stylebox("hover"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pressed.connect(cb)
	return b


# --- Results: one row per entry, grouped by category when sorted by type ---------------------

func _build_results(keep_scroll: bool) -> void:
	var v := _scroll.scroll_vertical if keep_scroll and is_instance_valid(_scroll) else 0
	_clear(_holder)
	var list := visible_entries()
	_holder.add_child(_list_header())
	var content := UiKit.vbox(0)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_child(content)
	_scroll = UiKit.scroller(margin)
	_scroll.name = "Results"
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE   # the columns line up with the header, scrolling or not
	_holder.add_child(_scroll)
	if list.is_empty():
		var none := UiKit.body("Nothing for sale matches. Clear the search or a filter.", 15, Hud.DIM)
		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 12)
		pad.add_theme_constant_override("margin_top", 12)
		pad.add_child(none)
		content.add_child(pad)
	var by_type := String(state.sort) == "type"
	var last := ""
	for i in list.size():
		var e: Dictionary = list[i]
		if by_type and String(e.cat) != last:   # a group header per category when sorted by type
			last = String(e.cat)
			content.add_child(_group_head(last, list.filter(func(x): return String(x.cat) == last).size()))
		content.add_child(_row(e))
	if v > 0:
		(func(): if is_instance_valid(_scroll): _scroll.scroll_vertical = v).call_deferred()


func _group_head(cat: String, n: int) -> Control:
	var p := PanelContainer.new()
	p.name = "Group_" + cat
	p.add_theme_stylebox_override("panel", _flat(Color("0a0f15"), LINE, [0, 0, 0, 1], 0, Vector4(10, 6, 10, 2)))
	var row := UiKit.hbox(10)
	p.add_child(row)
	row.add_child(UiKit.head(cat, 28, Hud.TEXT))
	var c := _mono(str(n), 19, H_DIM)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(c)
	return p


## The full text behind a row (its tooltip): name, Price Category, price, where it's from, the description.
static func tooltip(e: Dictionary) -> String:
	var src := "Night Market" if bool(e.market) else "Fixer's stock"
	var own := ("  ·  %d in storage" % int(e.owned)) if int(e.owned) > 0 else ""
	return "%s\n%s · %s eb · %s%s\n%s" % [String(e.name), String(e.tier), UiKit.money(int(e.cost)), src, own, String(e.desc)]


func _list_header() -> Control:
	var p := PanelContainer.new()
	p.name = "ListHeader"
	p.add_theme_stylebox_override("panel", _flat(Color("0a0f15"), FIELD_LINE, [0, 0, 0, 1], 0, Vector4(10, 5, 18, 5)))
	var row := UiKit.hbox(6)
	p.add_child(row)
	for c in [["ITEM", "item"], ["STATS", ""], ["TIER", "tier"], ["SOURCE", "source"], ["OWNED", "owned"], ["PRICE", "price"], ["QTY", "qty"]]:
		var id := String(c[1])
		if id == "tier" and compact:
			continue
		var l := UiKit.label(String(c[0]), 11, H_DIM)
		_col(l, id)
		if id in ["owned", "price"]:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if id == "qty":
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(l)
	return p


## A row (C's ledger): the name in its quality's typography, the full description, Price
## Category, source badge, owned count (storage), price and a − qty + stepper. The row's tooltip
## repeats it all.
func _row(e: Dictionary) -> Control:
	var key := String(e.key)
	var n := int((state.cart as Dictionary).get(key, 0))
	var p := TipRow.new()
	p.name = "Row_" + key.replace("/", "_").replace("@", "_")
	p.add_theme_stylebox_override("panel", _flat(Color("0b1520") if n > 0 else Color(0, 0, 0, 0), Color("10171e"), [0, 0, 0, 1], 0, Vector4(10, 6, 10, 6)))
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	p.tooltip_text = tooltip(e)
	var row := UiKit.hbox(6)
	p.add_child(row)
	var nm := _name(e, 14)
	_col(nm, "item")
	row.add_child(nm)
	var st := UiKit.body(String(e.desc), 13, Hud.DIM)
	st.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(st)
	if not compact:
		var tier := UiKit.label(String(e.tier), 11, Hud.CYAN)
		tier.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_col(tier, "tier")
		tier.custom_minimum_size.y = 20
		tier.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(tier)
	var src := VBoxContainer.new()
	_col(src, "source")
	var chip := _source_chip(e)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	src.add_child(chip)
	row.add_child(src)
	var own := UiKit.label(str(int(e.owned)) if int(e.owned) > 0 else "", 14, Hud.TEXT)
	own.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_col(own, "owned")
	row.add_child(own)
	var pc := UiKit.vbox(0)
	_col(pc, "price")
	var price := UiKit.label("%s eb" % UiKit.money(int(e.cost)), 14, Hud.TEXT)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pc.add_child(price)
	if compact:   # the tier folds under the price
		var tier2 := UiKit.label(String(e.tier), 10, Hud.CYAN)
		tier2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pc.add_child(tier2)
	row.add_child(pc)
	var q := _stepper(key, n, int(e.cost) <= camp.eb, false)
	_col(q, "qty")
	q.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(q)
	return p


func _col(l: Control, id: String) -> void:
	if id == "":
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 60
		return
	l.custom_minimum_size.x = (COLS_COMPACT if compact else COLS)[id]
	l.size_flags_horizontal = Control.SIZE_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_BEGIN


## An item's name in its quality's typography (QualityText; never italic); cyberware in violet.
func _name(e: Dictionary, size: int) -> Label:
	var chrome := String(e.kind) == "cyberware"
	var l := QualityText.apply(UiKit.label(String(e.name), size, Hud.VIOLET.lightened(0.3) if chrome else Hud.TEXT), String(e.key))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 40
	return l


## "3 DAYS LEFT" in magenta for the market's listings, FIXER for the fixer's own stock.
func _source_chip(e: Dictionary) -> Control:
	var mk := bool(e.market)
	var col := Hud.MAGENTA if mk else FIXER_TEAL
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _flat(Color(col.r * 0.1, col.g * 0.1, col.b * 0.1, 0.95), Color(col, 0.6), [1, 1, 1, 1], 0, Vector4(5, 0, 5, 0)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(_mono(Shop.badge(Shop.days_left(camp)) if mk else "FIXER", 16, col))
	return p


## − n + : one fewer / one more of `key` in the cart.
func _stepper(key: String, n: int, can_add: bool, in_cart: bool) -> HBoxContainer:
	var h := UiKit.hbox(2)
	var minus := _small_button("−", func(): set_qty(key, n - 1), n > 0)
	minus.tooltip_text = "One fewer"
	h.add_child(minus)
	var q := UiKit.label(str(n) if n > 0 or in_cart else "·", 14, Hud.TEXT if n > 0 else H_DIM)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.custom_minimum_size.x = 24
	q.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(q)
	var plus := _small_button("+", func(): add(key), can_add)
	plus.tooltip_text = "One more" if can_add else "More than the crew's eb"
	h.add_child(plus)
	return h


func _small_button(text: String, cb: Callable, enabled: bool) -> Button:
	var b := UiKit.button(text, UiKit.NEUTRAL, cb, enabled, 14, true)
	b.custom_minimum_size = Vector2(24, 24)
	var pad := Vector4(4, 0, 4, 0)
	b.add_theme_stylebox_override("normal", _flat(Color("0d141b"), FIELD_LINE, [1, 1, 1, 1], 0, pad))
	b.add_theme_stylebox_override("hover", _flat(Color(Hud.MAGENTA, 0.18), Hud.MAGENTA, [1, 1, 1, 1], 0, pad))
	b.add_theme_stylebox_override("pressed", _flat(Color(Hud.GOLD, 0.2), Hud.GOLD, [1, 1, 1, 1], 0, pad))
	b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("pressed"))
	b.add_theme_stylebox_override("disabled", _flat(Color(0, 0, 0, 0), Color(FIELD_LINE, 0.6), [1, 1, 1, 1], 0, pad))
	b.add_theme_color_override("font_disabled_color", Color("3a4a58"))
	return b


# --- Cart -----------------------------------------------------------------------------------

func _build_cart() -> void:
	_clear(_cart)
	var lines: Dictionary = state.cart
	var count := Campaign.cart_count(lines)
	var favour := camp.favour_discount(lines)   # a fixer's market favour (Campaign.favours) covers one item
	var total := Campaign.cart_total(lines) - favour
	var left := camp.eb - total
	var head := PanelContainer.new()
	head.add_theme_stylebox_override("panel", _flat(Color(0, 0, 0, 0), LINE, [0, 0, 0, 1], 0, Vector4(14, 8, 12, 6)))
	var hr := UiKit.hbox(8)
	head.add_child(hr)
	hr.add_child(UiKit.head("CART", 28, Hud.TEXT))
	var cl := UiKit.label("%d item%s" % [count, "" if count == 1 else "s"], 13, Hud.DIM)
	cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(cl)
	hr.add_child(UiKit.spacer())
	if count > 0:
		var clr := UiKit.button("CLEAR", UiKit.NAV, clear_cart, true, 12, true)
		clr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hr.add_child(clr)
	_cart.add_child(head)
	var list := UiKit.vbox(0)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 4)
	m.add_child(list)
	var sc := UiKit.scroller(m)
	sc.name = "CartLines"
	_cart.add_child(sc)
	if lines.is_empty():
		var e := UiKit.body("Nothing in the cart yet. Add items and buy them together.", 14, Hud.DIM)
		e.custom_minimum_size.y = 50
		list.add_child(e)
	var by := {}
	for e in _all:
		by[String(e.key)] = e
	for k in lines:
		list.add_child(_cart_line(String(k), int(lines[k]), by.get(String(k), {})))
	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel", _flat(Color(0, 0, 0, 0), LINE, [0, 1, 0, 0], 0, Vector4(14, 10, 12, 12)))
	var fv := UiKit.vbox(3)
	foot.add_child(fv)
	fv.add_child(_sum_row("Items", str(count), 14, Hud.TEXT))
	if favour > 0:
		fv.add_child(_sum_row("Fixer's favour", "-%s eb" % UiKit.money(favour), 14, Hud.GOLD))
	fv.add_child(_sum_row("Total", "%s eb" % UiKit.money(total), 17, Hud.TEXT))
	fv.add_child(_sum_row("Wallet after", "%s eb" % UiKit.money(left), 14, Hud.RED if left < 0 else Hud.TEXT))
	var short := left < 0
	var label := "NOT ENOUGH eb" if short else ("WIRE · %s eb" % UiKit.money(total) if count > 0 else "WIRE")
	_wire = _mag_button(label, true, checkout, count > 0 and not short, false)
	_wire.name = "Wire"
	_wire.tooltip_text = ("Short by %s eb" % UiKit.money(-left)) if short else "Buy everything in the cart"
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	fv.add_child(gap)
	fv.add_child(_wire)
	fv.add_child(UiKit.body("Everything goes to safehouse storage (Armory). Cyberware is installed at the Med Bay.", 12, H_DIM))
	_cart.add_child(foot)


## One cart line: name and line total; Price Category and unit price; − n + and remove.
func _cart_line(key: String, n: int, e: Dictionary) -> Control:
	var p := PanelContainer.new()
	p.name = "Line_" + key.replace("/", "_").replace("@", "_")
	p.add_theme_stylebox_override("panel", _flat(Color(0, 0, 0, 0), Color("18222c"), [0, 0, 0, 1], 0, Vector4(0, 7, 0, 7)))
	var v := UiKit.vbox(3)
	p.add_child(v)
	var top := UiKit.hbox(8)
	v.add_child(top)
	var cost := Items.price(key)
	var nm := _name(e if not e.is_empty() else {"key": key, "name": Items.display_name(key), "kind": Items.section(key)}, 14)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	var tot := UiKit.label("%s eb" % UiKit.money(cost * n), 14, Hud.TEXT)
	tot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(tot)
	var bot := UiKit.hbox(6)
	v.add_child(bot)
	bot.add_child(UiKit.body("%s · %s eb each" % [Items.price_tier(cost), UiKit.money(cost)], 12, Hud.DIM))
	var st := _stepper(key, n, cost <= camp.eb, true)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bot.add_child(st)
	var rm := _small_button("×", func(): set_qty(key, 0), true)
	rm.tooltip_text = "Remove from the cart"
	rm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bot.add_child(rm)
	return p


func _sum_row(k: String, v: String, size: int, col: Color) -> HBoxContainer:
	var h := UiKit.hbox(8)
	h.add_child(UiKit.body(k, size, Hud.DIM if size < 16 else Hud.TEXT))
	var l := UiKit.label(v, size, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(l)
	return h


## The portal's magenta buttons: + CART (outlined) and WIRE (filled; dark text).
func _mag_button(text: String, filled: bool, cb: Callable, enabled: bool, compact_b: bool) -> Button:
	var b := UiKit.button(text, UiKit.NEUTRAL, cb, enabled, 16 if filled else 13, compact_b)
	var m := Hud.MAGENTA
	var ink := Color("05070a")
	var cut := 0b0100 if filled else 0
	var pad := 6.0 if compact_b else 10.0
	var fill_n := m if filled else Color(0, 0, 0, 0)
	b.add_theme_color_override("font_color", ink if filled else m)
	b.add_theme_color_override("font_hover_color", ink if filled else ink)
	b.add_theme_color_override("font_pressed_color", ink)
	b.add_theme_color_override("font_disabled_color", Color("6a4a58") if filled else Color("3a4a58"))
	b.add_theme_stylebox_override("normal", _cut(fill_n, m, cut, pad))
	b.add_theme_stylebox_override("hover", _cut(m.lightened(0.15), m.lightened(0.15), cut, pad))
	b.add_theme_stylebox_override("pressed", _cut(Hud.GOLD, Hud.GOLD, cut, pad))
	b.add_theme_stylebox_override("hover_pressed", _cut(Hud.GOLD, Hud.GOLD, cut, pad))
	b.add_theme_stylebox_override("disabled", _cut(Color("2a1a22") if filled else Color(0, 0, 0, 0), Color("2a1a22") if filled else Color("2a3540"), cut, pad))
	if filled:
		b.custom_minimum_size.y = 40
	return b


func _cut(fill: Color, edge: Color, corners: int, pad: float) -> StyleBox:
	var s := CutBox.make(fill, edge, 10, corners, Color(0, 0, 0, 0), pad)
	s.content_margin_top = 2 if pad < 8 else 6
	s.content_margin_bottom = 2 if pad < 8 else 6
	return s


# --- Toast ----------------------------------------------------------------------------------

## A banner at the top of the shop: green after a checkout, red when the cart can't be bought.
func _show_toast(text: String, ok: bool) -> void:
	var p := PanelContainer.new()
	p.name = "Toast"
	p.add_theme_stylebox_override("panel", _flat(Hud.GREEN if ok else Hud.RED, Color(0, 0, 0, 0), [0, 0, 0, 0], 0, Vector4(16, 6, 16, 6)))
	var l := UiKit.label(text, 15, Color("05070a"))
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.offset_top = 10
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.z_index = 5
	_stack.add_child(p)
	if is_inside_tree():
		var tw := p.create_tween()
		tw.tween_interval(2.6)
		tw.tween_property(p, "modulate:a", 0.0, 0.6)
		tw.tween_callback(p.queue_free)


# --- Helpers --------------------------------------------------------------------------------

func _mono(s: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", Hud.F_MONO)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


## A flat box: fill, border colour, border widths [left, top, right, bottom], and content margins
## (all `m`, or `pad` as left, top, right, bottom).
static func _flat(fill: Color, border: Color, w: Array, m: float, pad := Vector4(-1, -1, -1, -1)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.border_width_left = int(w[0])
	s.border_width_top = int(w[1])
	s.border_width_right = int(w[2])
	s.border_width_bottom = int(w[3])
	if pad.x >= 0:
		s.content_margin_left = pad.x
		s.content_margin_top = pad.y
		s.content_margin_right = pad.z
		s.content_margin_bottom = pad.w
	else:
		s.set_content_margin_all(m)
	return s


static func _clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


## Tooltips in the portal's look.
static func _tip_theme() -> Theme:
	var th := Theme.new()
	th.set_stylebox("panel", "TooltipPanel", _flat(Color("0a0f15"), Color(Hud.CYAN, 0.5), [1, 1, 1, 1], 0, Vector4(10, 6, 10, 7)))
	th.set_font("font", "TooltipLabel", Hud.F_BODY)
	th.set_font_size("font_size", "TooltipLabel", 14)
	th.set_color("font_color", "TooltipLabel", Hud.TEXT)
	return th


## DEV ONLY: the review-shot flags (see the header). Returns whether to check out once built.
func _dev_flags(args: PackedStringArray) -> bool:
	var go := false
	for a in args:
		var k := a.trim_prefix("--").get_slice("=", 0)
		var val := a.get_slice("=", 1) if a.contains("=") else ""
		match k:
			"cart":
				for part in val.split(",", false):
					Shop.cart_add(state.cart, part.get_slice(":", 0), int(part.get_slice(":", 1)) if part.contains(":") else 1)
			"shop-cat": state.cat = val
			"shop-sort": state.sort = val
			"shop-q": state.query = val
			"shop-filter":
				for f in val.split(",", false):
					state[{"market": "market_only", "owned": "hide_owned"}.get(f, f)] = true
			"checkout": go = true
	return go


## A row whose tooltip wraps instead of running off the screen.
class TipRow extends PanelContainer:
	func _make_custom_tooltip(for_text: String) -> Object:
		var l := Label.new()
		l.text = for_text
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 320
		l.add_theme_font_override("font", Hud.F_BODY)
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Hud.TEXT)
		return l
