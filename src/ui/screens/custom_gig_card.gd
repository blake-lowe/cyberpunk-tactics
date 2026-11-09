class_name CustomGigCard
extends PanelContainer
## DEV ONLY: the CUSTOM GIG (DEV) card at the foot of the Fixer Network's JOBS, shown in developer
## mode (GameSettings.dev_mode; FixerScreen). A form over every parameter a gig has (CustomGig.FIELDS):
## where (district, a canon location searched by name, or a set piece, scene, profile or site
## directly), the objective, the target, the security level and Security Code, the utilities, the
## complication, the pay, the seed, the deploy zone, basements and who goes. Every field starts
## auto. The line under the form is the same gig as greybox flags. TAKE starts it
## (Campaign.accept_custom), REPEAT the last one taken (Campaign.last_custom, its seed fixed).

signal take(form: Dictionary)

const AUTO := "Auto"
const LABEL_W := 110
const FIELD_W := 196   ## four fields a row fit a 1067-px-wide logical screen (1600x900 at 1.5x)

var camp: Campaign
var form := CustomGig.defaults()
var _ready_to_go := true
var _loc: OptionButton
var _loc_search: LineEdit
var _variant: OptionButton
var _basements: OptionButton
var _flags: Label
var _code_box: HBoxContainer
var _code := {"n": 5, "faction": "", "intensity": "medium", "hardened": false}
var _cx_roll := 0


func setup(p_camp: Campaign, ready_to_go: bool, p_form: Dictionary = {}) -> CustomGigCard:
	camp = p_camp
	_ready_to_go = ready_to_go
	if not p_form.is_empty():
		form = p_form   # the screen's own, so the form survives the screen rebuilding
		for k in CustomGig.FIELDS:
			if not form.has(k):
				form[k] = CustomGig.FIELDS[k]
	add_theme_stylebox_override("panel", CutBox.make(Hud.INK, Color(Hud.MAGENTA, 0.7), 12, 0b0101, Color(0, 0, 0, 0), 12))
	_build()
	return self


func _build() -> void:
	var v := UiKit.vbox(8)
	add_child(v)
	var top := UiKit.hbox(14)
	v.add_child(top)
	top.add_child(UiKit.head("Custom gig (dev)", 30, Hud.MAGENTA))
	var note := UiKit.body("Developer mode. Every field set here, the rest auto (drawn from the seed). Runs as a board gig: travel, pay, IP, injuries; marked DEV in the save and the debrief.", 13, Hud.DIM)
	note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(note)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	# Where.
	_field(grid, "District", _opt("district", [["", AUTO], [CustomGig.NONE, "None"]] + _pairs(CustomGig.districts(),
		func(d): return String(World.district(String(d)).get("name", d))), _district_changed))
	var loc_box := UiKit.hbox(4)
	_loc_search = LineEdit.new()
	_loc_search.placeholder_text = "search"
	_loc_search.custom_minimum_size.x = 64
	_style_field(_loc_search)
	_loc_search.text_changed.connect(func(_t: String): _fill_locations())
	loc_box.add_child(_loc_search)
	_loc = OptionButton.new()
	_style_field(_loc)
	_loc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_loc.custom_minimum_size.x = 120
	_loc.item_selected.connect(func(i: int): form.location = String(_loc.get_item_metadata(i)); _changed())
	loc_box.add_child(_loc)
	_field(grid, "Location", loc_box)
	_fill_locations()
	_field(grid, "Set piece", _opt("setpiece", [["", "From location"]] + _pairs(SetPieces.ids(),
		func(id): return String(SetPieces.get_def(String(id)).get("name", id))), _setpiece_changed))
	_variant = _opt("variant", [["", "Random"]])
	_fill_variants()
	_field(grid, "Variant", _variant)
	_field(grid, "Scene", _opt("scene", [["", AUTO]] + _pairs(SceneGen.scene_types(),
		func(id): return String(RulesDB.gen("scenes.json")[id].get("name", id)))))
	_field(grid, "Profile", _opt("profile", [["", AUTO]] + _pairs(_keys(RulesDB.gen("districts.json")), func(id): return String(id).capitalize())))
	_field(grid, "Site", _opt("site", [["", AUTO]] + _pairs(_keys(RulesDB.gen("sites.json")),
		func(id): return String(RulesDB.gen("sites.json")[id].get("name", String(id).capitalize())))))
	# What and against whom.
	var objs: Array = [["", AUTO]]
	for k in Campaign.OBJECTIVES:
		objs.append([String(Campaign.OBJECTIVES[k]), String(Campaign.OBJECTIVES[k]).capitalize()])
	_field(grid, "Objective", _opt("objective", objs))
	var facs: Array = World.factions().keys()
	facs.sort()
	_field(grid, "Target", _opt("faction", [["", AUTO]] + _pairs(facs, func(id): return World.display_name(String(id)))))
	_field(grid, "Security", _opt("security", [[0, AUTO], [1, "1"], [2, "2"], [3, "3"]]))
	_field(grid, "Utilities", _opt("utility", [["auto", "Auto (1 in 3)"], ["none", "None out"], ["roll", "Roll the code"],
		["power", "Power out"], ["water", "Water out"], ["citinet", "CitiNet out"], ["power,water,citinet", "All out"]]))
	_field(grid, "Deploy", _opt("deploy", [["", AUTO], ["near", "Near"], ["far", "Far"]]))
	_basements = _opt("basements", [["", AUTO], ["on", "Forced on"], ["off", "Forced off"]])
	_basements.tooltip_text = "Ordinary target buildings whose site has below-grade storeys; a set piece keeps its recipe's."
	_field(grid, "Basements", _basements)
	var towers: Array = [["", "Off (street level)"], ["any", "Any tower"]]
	var tids: Array = World.towers().keys()
	tids.sort()
	for lid in tids:
		var tw := World.tower(String(lid))
		var b: Dictionary = (tw.get("bands", {}) as Dictionary).get(TowerGen.DEFAULT_BAND, {})
		var fl := " %d-%d" % [int(b.storeys[0]), int(b.storeys[1])] if b.has("storeys") else ""
		towers.append([String(tw.get("id", lid)), String(tw.get("name", lid)) + fl])
	var tower_opt := _opt("tower", towers)
	tower_opt.tooltip_text = "A tower gig: the sky band of a tall building (TowerGen; the crew rides up in the lift). Off plays a tower's location as its street-level building."
	_field(grid, "Tower", tower_opt)
	var moods: Array = [["", AUTO]]
	for id in Atmosphere.ids():
		moods.append([String(id), String(Atmosphere.data().moods[id].get("name", id))])
	var mood_opt := _opt("mood", moods)
	mood_opt.tooltip_text = "A tower gig's weather (Atmosphere): auto draws it from the seed, weighted by the district."
	_field(grid, "Weather", mood_opt)
	_field(grid, "Pay (eb)", _spin("pay", 0, 200000, 500))
	_field(grid, "Seed", _spin("seed", 0, 99999, 1))
	_field(grid, "Complication", _complication())
	# Security Code: from the location, or set.
	var code_row := UiKit.hbox(8)
	v.add_child(code_row)
	var cl := UiKit.label("Security Code", 13, Hud.CYAN)
	cl.custom_minimum_size.x = LABEL_W
	code_row.add_child(cl)
	_code_from_form()
	var mode := OptionButton.new()
	_style_field(mode)
	mode.add_item("From location")
	mode.add_item("Set")
	mode.custom_minimum_size.x = 150
	mode.selected = 0 if String(form.code) == "" else 1
	code_row.add_child(mode)
	_code_box = UiKit.hbox(8)
	_code_box.visible = mode.selected == 1
	code_row.add_child(_code_box)
	mode.item_selected.connect(func(i: int):
		_code_box.visible = i == 1
		form.code = _code_text() if i == 1 else ""
		_changed())
	_code_fields()
	# Who goes.
	var crew_row := UiKit.flow(10)
	v.add_child(crew_row)
	var wl := UiKit.label("Crew", 13, Hud.CYAN)
	wl.custom_minimum_size.x = LABEL_W
	crew_row.add_child(wl)
	var names: Array = form.crew
	for c in camp.alive_crew():
		var cb := CheckBox.new()
		cb.text = "%s (%s)" % [c.display_name, c.role]
		cb.add_theme_font_override("font", Hud.F_BODY)
		cb.add_theme_font_size_override("font_size", 14)
		cb.button_pressed = c.can_act() and (names.is_empty() or c.display_name in names)
		cb.disabled = not c.can_act()
		cb.set_meta("name", c.display_name)
		cb.toggled.connect(func(_on: bool): _crew_changed(crew_row))
		crew_row.add_child(cb)
	# The same gig as flags, and the actions.
	_flags = UiKit.body("", 13, Color(Hud.TEXT, 0.6))
	v.add_child(_flags)
	var bottom := UiKit.hbox(10)
	v.add_child(bottom)
	bottom.add_child(UiKit.button("RESET TO AUTO", UiKit.NAV, _reset))
	bottom.add_child(UiKit.spacer())
	var last := camp.last_custom
	var rep := UiKit.button("REPEAT LAST CUSTOM GIG", UiKit.NAV, func(): take.emit(camp.last_custom.duplicate(true)), _ready_to_go and not last.is_empty())
	rep.name = "Repeat"
	rep.tooltip_text = " ".join(CustomGig.to_flags(last)) if not last.is_empty() else "No custom gig taken yet."
	bottom.add_child(rep)
	var go := UiKit.button("TAKE CUSTOM GIG", UiKit.PRIMARY, func(): take.emit(form.duplicate(true)), _ready_to_go)
	go.name = "TakeCustom"
	bottom.add_child(go)
	_changed()


# --- Fields -----------------------------------------------------------------------------------

## A field: its label over it.
func _field(grid: GridContainer, text: String, c: Control) -> void:
	var cell := UiKit.vbox(2)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_child(UiKit.label(text, 12, Hud.CYAN))
	c.custom_minimum_size.x = maxf(c.custom_minimum_size.x, FIELD_W)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.add_child(c)
	grid.add_child(cell)


func _style_field(c: Control) -> void:
	c.add_theme_font_override("font", Hud.F_BODY)
	c.add_theme_font_size_override("font_size", 14)
	c.focus_mode = Control.FOCUS_CLICK
	if c is OptionButton:   # long names (locations, sites) must not widen the card past the screen
		(c as OptionButton).fit_to_longest_item = false
		(c as OptionButton).clip_text = true
		(c as OptionButton).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


## [[value, text], ...] for ids, each named by `name_of`.
static func _pairs(ids: Array, name_of: Callable) -> Array:
	return ids.map(func(id): return [String(id), String(name_of.call(id))])


static func _keys(d: Dictionary) -> Array:
	var out: Array = d.keys().filter(func(k): return not String(k).begins_with("_"))
	out.sort()
	return out


## An OptionButton over `items` ([value, text]) bound to form[key].
func _opt(key: String, items: Array, then := Callable()) -> OptionButton:
	var o := OptionButton.new()
	_style_field(o)
	_set_items(o, items, form[key])
	o.item_selected.connect(func(i: int):
		form[key] = o.get_item_metadata(i)
		if then.is_valid():
			then.call()
		_changed())
	return o


static func _set_items(o: OptionButton, items: Array, current: Variant) -> void:
	o.clear()
	var sel := 0
	for i in items.size():
		o.add_item(String(items[i][1]))
		o.set_item_metadata(i, items[i][0])
		if typeof(items[i][0]) == typeof(current) and items[i][0] == current:
			sel = i
	o.selected = sel


## A SpinBox bound to form[key] (0 is auto).
func _spin(key: String, lo: int, hi: int, step: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = int(form[key])
	s.allow_greater = false
	s.prefix = ""
	s.suffix = "(auto)" if int(form[key]) == 0 else ""
	s.get_line_edit().add_theme_font_override("font", Hud.F_BODY)
	s.get_line_edit().add_theme_font_size_override("font_size", 14)
	s.value_changed.connect(func(x: float):
		form[key] = int(x)
		s.suffix = "(auto)" if int(x) == 0 else ""
		_changed())
	return s


## The canon locations of the chosen district matching the search (CustomGig.locations).
func _fill_locations() -> void:
	var did := String(form.district)
	var items: Array = [["", AUTO], [CustomGig.NONE, "None (scene direct)"]]
	var ids := CustomGig.locations(did, _loc_search.text if _loc_search else "")
	for id in ids:
		var l: Dictionary = World.locations()[id]
		var extra := "" if did != "" else " · " + String(World.district(String(l.get("district", ""))).get("name", ""))
		items.append([String(id), String(l.get("name", id)) + extra])
	var cur := String(form.location)
	if cur != "" and cur != CustomGig.NONE and not cur in ids and _loc_search and _loc_search.text == "":
		form.location = ""   # not in the district any more
	_set_items(_loc, items, String(form.location))
	_loc.tooltip_text = "%d locations" % ids.size()


func _district_changed() -> void:
	_fill_locations()


func _setpiece_changed() -> void:
	form.variant = ""
	_fill_variants()


func _fill_variants() -> void:
	var items: Array = [["", "Random"]]
	for vr in SetPieces.get_def(String(form.setpiece)).get("variants", []):
		items.append([String(vr.get("id", "")), "%s · %s" % [String(vr.get("id", "")), String(vr.get("name", ""))]])
	_set_items(_variant, items, String(form.variant))
	_variant.disabled = items.size() == 1


func _complication() -> Control:
	var h := UiKit.hbox(4)
	var cx := String(form.complication)
	var tier := cx.get_slice(":", 0)
	if cx.contains(":"):
		_cx_roll = int(cx.get_slice(":", 1))
	var o := OptionButton.new()
	_style_field(o)
	o.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var items := [["auto", "Auto (1 in 3)"], ["none", "None"], ["random", "Random"]]
	for t in Complication.TIERS:
		items.append([String(t), String(Complication.TIER_NAMES[t])])
	_set_items(o, items, tier)
	h.add_child(o)
	var roll := SpinBox.new()
	roll.min_value = 0
	roll.max_value = 10
	roll.value = _cx_roll
	roll.prefix = "roll"
	roll.tooltip_text = "1d10 roll on the tier's table; 0 rolls it."
	roll.get_line_edit().add_theme_font_size_override("font_size", 14)
	h.add_child(roll)
	var apply := func():
		var t := String(o.get_item_metadata(o.selected))
		_cx_roll = int(roll.value)
		roll.editable = t in Complication.TIERS
		form.complication = "%s:%d" % [t, _cx_roll] if t in Complication.TIERS else t
		_changed()
	o.item_selected.connect(func(_i: int): apply.call())
	roll.value_changed.connect(func(_x: float): apply.call())
	roll.editable = tier in Complication.TIERS
	return h


func _code_from_form() -> void:
	var c := SecurityCode.normalise(String(form.code)) if String(form.code) != "" else {}
	if not c.is_empty():
		_code = {"n": int(c.n), "faction": String(c.faction), "intensity": String(c.intensity), "hardened": bool(c.hardened)}


## "6:ncpd,hardened heavy": SecurityCode.parse's printed form (an empty faction: the target's own people).
func _code_text() -> String:
	return "%d:%s,%s%s" % [int(_code.n), String(_code.faction), "hardened " if bool(_code.hardened) else "", String(_code.intensity)]


func _code_fields() -> void:
	var n := SpinBox.new()
	n.min_value = 0
	n.max_value = SecurityCode.ALWAYS
	n.value = int(_code.n)
	n.prefix = "n"
	n.get_line_edit().add_theme_font_size_override("font_size", 14)
	_code_box.add_child(n)
	var fac := OptionButton.new()
	_style_field(fac)
	fac.custom_minimum_size.x = 190
	var facs: Array = World.factions().keys()
	facs.sort()
	_set_items(fac, [["", "Target's own people"]] + _pairs(facs, func(id): return World.display_name(String(id))), String(_code.faction))
	_code_box.add_child(fac)
	var inten := OptionButton.new()
	_style_field(inten)
	inten.custom_minimum_size.x = 110
	_set_items(inten, SecurityCode.INTENSITIES.map(func(i): return [String(i), String(i).capitalize()]), String(_code.intensity))
	_code_box.add_child(inten)
	var hard := CheckBox.new()
	hard.text = "Hardened"
	hard.add_theme_font_override("font", Hud.F_BODY)
	hard.add_theme_font_size_override("font_size", 14)
	hard.button_pressed = bool(_code.hardened)
	_code_box.add_child(hard)
	var apply := func():
		_code = {"n": int(n.value), "faction": String(fac.get_item_metadata(fac.selected)),
			"intensity": String(inten.get_item_metadata(inten.selected)), "hardened": hard.button_pressed}
		form.code = _code_text()
		_changed()
	n.value_changed.connect(func(_x: float): apply.call())
	fac.item_selected.connect(func(_i: int): apply.call())
	inten.item_selected.connect(func(_i: int): apply.call())
	hard.toggled.connect(func(_on: bool): apply.call())


func _crew_changed(row: Container) -> void:
	var on: Array = []
	var all := true
	for cb in row.get_children():
		if cb is CheckBox:
			if (cb as CheckBox).button_pressed:
				on.append(String(cb.get_meta("name")))
			elif not (cb as CheckBox).disabled:
				all = false
	form.crew = [] if all else on
	_changed()


func _reset() -> void:
	form.clear()
	form.merge(CustomGig.defaults())
	_code = {"n": 5, "faction": "", "intensity": "medium", "hardened": false}
	_cx_roll = 0
	for ch in get_children():
		remove_child(ch)
		ch.queue_free()
	_build()


## Basements only where the chosen place can have them; the flags line follows the form.
func _changed() -> void:
	if _basements:
		var place := {"setpiece": String(form.setpiece), "scene": String(form.scene), "site": String(form.site)}
		var lid := String(form.location)
		if String(form.scene) == "" and String(form.site) == "" and String(form.profile) == "" and lid != "" and lid != CustomGig.NONE:
			var l := World.location(lid)
			place.merge({"scene": String(l.get("scene", "neighborhood" if l.has("profile") else "lone_building")),
				"site": String(l.get("site", ""))}, true)
			if place.setpiece == "":
				place.setpiece = String(l.get("setpiece", ""))
		elif String(form.scene) == "":
			place.scene = "lone_building" if String(form.site) != "" else ("" if lid == "" else "neighborhood")
		var ok: bool = place.scene == "" or CustomGig.basements_apply(place)
		_basements.disabled = not ok
		_basements.tooltip_text = "Ordinary target buildings whose site has below-grade storeys; a set piece keeps its recipe's." + ("" if ok else " (Not this place.)")
	if _flags:
		var fl := CustomGig.to_flags(form)
		_flags.text = "Flags: " + (" ".join(fl) if not fl.is_empty() else "(all auto)")
