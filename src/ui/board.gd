class_name Board
extends Control
## Between gigs (M6, spec: Gigs & Mission Structure, Meta Progression): the crew, the fixer board,
## recruits, rest and treatment. Same visual language as the tactical HUD (chamfered panels, pixel
## and terminal fonts, no rounded corners). Main scene: dev flags (--shot, --reel, --scene, ...) skip
## straight to the tactical view so the review tooling keeps working.

const GREYBOX := "res://scenes/greybox.tscn"
const DEV_FLAGS := ["shot", "reel", "scene", "profile", "attack", "jack", "walk"]

var camp: Campaign
var report: Dictionary = {}   ## the last gig's results, shown once
var portraits: Portraits
var _root: VBoxContainer
var _shot_path := ""
var _frames := 0
var _shop_for := 0   ## crew index the night market is buying for
var _train_for := -1 ## crew index whose training panel is open
## Skills offered for training, by Role first (the rest of the list follows).
const TRAIN_SKILLS := {"solo": ["handgun", "shoulder_arms", "autofire", "evasion", "melee_weapon", "athletics"],
	"netrunner": ["handgun", "evasion", "stealth", "perception", "concentration"],
	"medtech": ["first_aid", "paramedic", "shoulder_arms", "evasion", "athletics", "concentration"]}
const TRAIN_COMMON := ["handgun", "shoulder_arms", "evasion", "stealth", "perception", "athletics", "concentration", "first_aid"]


func _ready() -> void:
	var dev := false
	var board_shot := false
	for a in OS.get_cmdline_user_args():
		var k := a.trim_prefix("--").get_slice("=", 0)
		if k in DEV_FLAGS:
			dev = true
		if k == "shot":
			_shot_path = a.get_slice("=", 1)
		if k == "board":   # --board --shot=x.png screenshots this screen
			board_shot = true
		if k == "train":   # --train=n opens crew member n's training panel (screenshots)
			_train_for = int(a.get_slice("=", 1))
	if dev and not board_shot:
		get_tree().change_scene_to_file.call_deferred(GREYBOX)
		return
	Hud._fonts()
	camp = Campaign.current
	if camp == null:
		camp = Campaign.load_from()
		if camp == null or camp.crew.is_empty():
			camp = Campaign.new_game(int(Time.get_unix_time_from_system()) % 100000)
		Campaign.current = camp
	if camp.has_meta("report"):
		report = camp.get_meta("report")
		camp.remove_meta("report")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("06080c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	portraits = Portraits.new()
	add_child(portraits)
	_build()


func _process(_d: float) -> void:
	if _shot_path != "":
		_frames += 1
		if _frames == 20:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()


func _text(s: String, font: Font, size: int, col := Hud.TEXT, wrap := false) -> Label:
	var l := Label.new()
	l.text = s
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if wrap:   # only in vertical stacks: in a row a wrapping label collapses to one letter per line
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _panel(accent: Color) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", CutBox.make(Hud.INK, Color(accent, 0.5), 12, 0b0101, accent, 12))
	return p


func _button(label: String, col: Color, cb: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = label
	b.focus_mode = Control.FOCUS_NONE
	b.disabled = not enabled
	b.add_theme_font_override("font", Hud.F_DISPLAY)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", col)
	b.add_theme_stylebox_override("normal", CutBox.make(Color(0.03, 0.045, 0.06, 0.95), Color(col, 0.5), 7, 0b0101))
	b.add_theme_stylebox_override("hover", CutBox.make(Color(col.r * 0.15, col.g * 0.15, col.b * 0.15, 0.97), col, 7, 0b0101))
	b.add_theme_stylebox_override("pressed", CutBox.make(Color(0.14, 0.11, 0.02, 0.97), Hud.GOLD, 7, 0b0101))
	b.add_theme_stylebox_override("disabled", CutBox.make(Color(0.02, 0.025, 0.03, 0.8), Color(Hud.DIM, 0.2), 7, 0b0101))
	b.pressed.connect(cb)
	return b


func _rebuild() -> void:
	camp.save()
	for ch in get_children():
		if ch is ScrollContainer:
			ch.queue_free()
	_build()


func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	scroll.add_child(margin)
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 18)
	margin.add_child(_root)
	# header
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 24)
	_root.add_child(head)
	var title := _text("NIGHT CITY", Hud.F_DISPLAY, 56, Hud.GOLD)
	head.add_child(title)
	for s in [["DAY %d" % camp.day, Hud.CYAN], ["%s eb" % _money(camp.eb), Hud.GREEN], ["REP %d" % camp.rep, Hud.MAGENTA],
			["HEAT %d" % camp.heat, Hud.RED if camp.heat >= 5 else (Hud.GOLD if camp.heat > 0 else Hud.DIM)]]:
		var l := _text(s[0], Hud.F_TERM, 34, s[1])
		l.size_flags_vertical = Control.SIZE_SHRINK_END
		head.add_child(l)
	if not report.is_empty():
		_root.add_child(_report_panel())
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	_root.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	left.add_theme_constant_override("separation", 12)
	cols.add_child(left)
	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 12)
	cols.add_child(mid)
	left.add_child(_text("// CREW", Hud.F_PIXEL, 22, Hud.CYAN))
	for c in camp.crew:
		left.add_child(_crew_card(c))
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 8)
	acts.add_child(_button("REST 1 DAY", Hud.CYAN, func(): camp.rest(1); _rebuild()))
	acts.add_child(_button("REST UNTIL HEALED", Hud.CYAN, func(): _rest_full(); _rebuild()))
	left.add_child(acts)
	left.add_child(_text("// SAFEHOUSE", Hud.F_PIXEL, 22, Hud.GREEN))
	for f in Campaign.FACILITIES:
		left.add_child(_facility(f))
	if not camp.fallen.is_empty():
		left.add_child(_text("// FLATLINED", Hud.F_PIXEL, 22, Hud.RED))
		for f in camp.fallen:
			left.add_child(_text("%s · %s · day %d · %s" % [String(f.name).to_upper(), String(f.role).capitalize(), int(f.day), f.gig], Hud.F_TERM, 20, Color(Hud.RED, 0.8), true))
	mid.add_child(_text("// FIXER BOARD", Hud.F_PIXEL, 22, Hud.GOLD))
	for i in camp.board.size():
		mid.add_child(_gig_card(i))
	mid.add_child(_text("// FOR HIRE  (%s eb · crew of 4 max)" % _money(int(Campaign.ECON.hire)), Hud.F_PIXEL, 22, Hud.GREEN))
	var hires := HBoxContainer.new()
	hires.add_theme_constant_override("separation", 10)
	mid.add_child(hires)
	for i in camp.recruits.size():
		hires.add_child(_recruit_card(i))
	if not camp.crew.is_empty():
		mid.add_child(_shop())
		mid.add_child(_ripperdoc())
	mid.add_child(_text("// LOG", Hud.F_PIXEL, 22, Hud.DIM))
	for l in camp.log.slice(-6):
		mid.add_child(_text("> " + l, Hud.F_TERM, 20, Color(Hud.TEXT, 0.7), true))


func _facility(f: String) -> PanelContainer:
	var d: Dictionary = Campaign.FACILITIES[f]
	var lv := camp.level(f)
	var p := _panel(Hud.GREEN if lv > 0 else Hud.DIM)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	p.add_child(col)
	var top := HBoxContainer.new()
	col.add_child(top)
	var nm := _text(String(d.name).to_upper(), Hud.F_DISPLAY, 22, Hud.TEXT if lv > 0 else Color(Hud.TEXT, 0.6))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	top.add_child(_text("◆".repeat(lv) + "◇".repeat(d.costs.size() - lv), Hud.F_TERM, 20, Hud.GREEN))
	for i in d.desc.size():
		if String(d.desc[i]) != "":
			col.add_child(_text(("✓ " if lv > i else "· ") + String(d.desc[i]), Hud.F_TERM, 17, Color(Hud.TEXT, 0.85 if lv > i else 0.5), true))
	var cost := camp.upgrade_cost(f)
	if cost >= 0:
		col.add_child(_button(("BUILD" if lv == 0 else "UPGRADE") + "  %s eb" % _money(cost), Hud.GREEN, func(): camp.upgrade(f); _rebuild(), camp.eb >= cost))
	return p


## Night market: pick who you're shopping for, then buy. Guns become the primary weapon; armour
## goes on the chosen location; replaced gear sells back at half price.
func _shop() -> VBoxContainer:
	_shop_for = clampi(_shop_for, 0, camp.crew.size() - 1)
	var c: Combatant = camp.crew[_shop_for]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_text("// NIGHT MARKET  (more stock with reputation · old gear sells at half)", Hud.F_PIXEL, 22, Hud.MAGENTA))
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 8)
	box.add_child(who)
	who.add_child(_text("BUYING FOR", Hud.F_TERM, 20, Hud.DIM))
	for i in camp.crew.size():
		var idx := i
		var b := _button(camp.crew[i].display_name.to_upper(), Hud.GOLD if i == _shop_for else Hud.CYAN, func(): _shop_for = idx; _rebuild())
		who.add_child(b)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	var owned := c.weapons.map(func(w): return w.id())
	for it in camp.shop_stock():
		var p := _panel(Hud.MAGENTA if it.kind == "weapon" else Hud.CYAN)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		p.add_child(col)
		col.add_child(_text(String(it.name).to_upper(), Hud.F_DISPLAY, 20, Hud.TEXT))
		col.add_child(_text("%s · %s eb%s" % [it.info, _money(int(it.cost)), "  (via fixer +20%)" if it.get("fixer", false) else ""], Hud.F_TERM, 18, Color(Hud.TEXT, 0.7), true))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		col.add_child(row)
		var id: String = it.id
		var afford: bool = camp.eb >= int(it.cost)
		if it.kind == "weapon":
			var have: bool = id in owned
			row.add_child(_button("OWNED" if have else "BUY", Hud.GREEN, func(): camp.buy(c, id); _rebuild(), afford and not have))
		else:
			for loc in ["body", "head"]:
				var l: String = loc
				var have2: bool = c.armor.get(l) != null and (c.armor[l] as ArmorPiece).id == id
				row.add_child(_button(l.to_upper() if not have2 else "WORN", Hud.GREEN, func(): camp.buy(c, id, l); _rebuild(), afford and not have2))
		grid.add_child(p)
	return box


## Ripperdoc: chrome for the crew member the market is buying for. Price includes surgery (p110).
func _ripperdoc() -> VBoxContainer:
	var c: Combatant = camp.crew[_shop_for]
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_text("// RIPPERDOC  (for %s · HUM %d/%d · chrome costs Humanity)" % [c.display_name.to_upper(), c.humanity, c.max_humanity], Hud.F_PIXEL, 22, Hud.VIOLET))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	box.add_child(grid)
	for id in Campaign.RIPPERDOC:
		var d := RulesDB.cyberware(id)
		var p := _panel(Hud.VIOLET)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		p.add_child(col)
		col.add_child(_text(String(d.name).to_upper(), Hud.F_DISPLAY, 20, Hud.TEXT))
		col.add_child(_text(String(Campaign.RIPPERDOC[id][1]), Hud.F_TERM, 17, Color(Hud.TEXT, 0.8), true))
		col.add_child(_text("%s eb · HL %s%s" % [_money(int(d.cost)), d.hl_dice, " · %s" % String(d.install).to_upper()], Hud.F_TERM, 17, Color(Hud.TEXT, 0.6)))
		var why := camp.install_block(c, id)
		var cid: String = id
		col.add_child(_button("INSTALL" if why == "" else why.to_upper(), Hud.VIOLET, func(): camp.install(c, cid); _rebuild(), why == ""))
		grid.add_child(p)
	return box


static func _money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out


func _rest_full() -> void:
	var days := 0
	while days < 14 and camp.crew.any(func(c): return c.hp < c.max_hp()):
		camp.rest(1)
		days += 1


func _crew_card(c: Combatant) -> PanelContainer:
	var p := _panel(UnitLook.CREW_ACCENTS[maxi(0, c.look_seed) % 4])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var pic := TextureRect.new()
	pic.texture = portraits.tex({"id": 1000 + maxi(0, c.look_seed), "team": 0, "c": c})
	pic.custom_minimum_size = Vector2(72, 72)
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	row.add_child(pic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	col.add_child(_text(c.display_name.to_upper(), Hud.F_DISPLAY, 30, Hud.TEXT))
	col.add_child(_text("%s · RANK %d · %d IP" % [c.role.to_upper(), c.role_rank, c.ip], Hud.F_TERM, 20, Hud.CYAN))
	var hpcol := Hud.GREEN if c.hp >= c.max_hp() else (Hud.GOLD if c.wound_state() < Combatant.Wound.SERIOUS else Hud.RED)
	col.add_child(_text("HP %d/%d   SP %d/%d" % [c.hp, c.max_hp(), c.sp("head"), c.sp("body")], Hud.F_TERM, 20, hpcol))
	if c.tracks_humanity:
		var hum_col := Hud.GREEN if c.psychosis_tier() == 0 else (Hud.GOLD if c.psychosis_tier() == 1 else Hud.RED)
		var hr := HBoxContainer.new()
		hr.add_theme_constant_override("separation", 8)
		hr.add_child(_text("HUM %d/%d  EMP %d" % [c.humanity, c.max_humanity, c.raw_stat("EMP")], Hud.F_TERM, 20, hum_col))
		if c.humanity < c.max_humanity:
			hr.add_child(_button("THERAPY %d eb · 1 WEEK" % int(Campaign.THERAPY.cost), Hud.GREEN, func(): camp.therapy(c); _rebuild(), camp.eb >= int(Campaign.THERAPY.cost)))
		col.add_child(hr)
	if not c.cyberware.is_empty():
		col.add_child(_text("CHROME: " + ", ".join(c.cyberware.map(func(x): return String(RulesDB.cyberware(x).name))), Hud.F_TERM, 17, Color(Hud.VIOLET, 0.9), true))
	var tech := camp.best_tech()
	if tech != null:   # the crew's Tech can upgrade armour in the workshop (p148)
		var wr := HBoxContainer.new()
		wr.add_theme_constant_override("separation", 6)
		for loc in ["body", "head"]:
			var a: ArmorPiece = c.armor.get(loc)
			if a and not a.upgraded:
				var l: String = loc
				var b := _button("UPGRADE %s +1 SP · %d eb · %dd" % [loc.to_upper(), a.price(), Campaign.maker_days(a.price())], Hud.CYAN,
					func(): camp.upgrade_armor(c, l); _rebuild(), camp.eb >= a.price())
				b.add_theme_font_size_override("font_size", 15)
				wr.add_child(b)
		if wr.get_child_count() > 0:
			col.add_child(wr)
	if c.grenades > 0 or not c.weapons.is_empty():
		col.add_child(_text(", ".join(c.weapons.map(func(w): return String(w.def.name))) + ("  · frag ×%d" % c.grenades if c.grenades > 0 else ""), Hud.F_TERM, 18, Color(Hud.TEXT, 0.7), true))
	for i in c.injuries.size():
		var inj: Dictionary = c.injuries[i]
		var r := HBoxContainer.new()
		r.add_child(_text("! " + String(inj.get("name", "injury")).to_upper(), Hud.F_TERM, 20, Hud.RED))
		var idx := i
		r.add_child(_button("TREAT %d eb" % camp.treat_cost(), Hud.GREEN, func(): camp.treat(c, idx); _rebuild(), camp.eb >= camp.treat_cost()))
		col.add_child(r)
	var keys: Array = Campaign.DOWNTIME.keys()
	var nxt: String = keys[(keys.find(c.downtime) + 1) % keys.size()]
	var dt := _button("DOWNTIME: %s · %s" % [String(Campaign.DOWNTIME[c.downtime].name).to_upper(), Campaign.DOWNTIME[c.downtime].desc], Hud.GREEN,
		func(): c.downtime = nxt; _rebuild())
	dt.add_theme_font_size_override("font_size", 15)
	col.add_child(dt)
	var idx2 := camp.crew.find(c)
	var open := _train_for == idx2
	col.add_child(_button("TRAINING ▲" if open else "TRAINING ▼  (%d IP)" % c.ip, Hud.MAGENTA, func(): _train_for = -1 if open else idx2; _rebuild()))
	if open:
		col.add_child(_training(c))
	return p


## Spend IP: Role Rank (p411), the Role's perk tree (two tiers, one pick each), and skills.
func _training(c: Combatant) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(_button("ROLE RANK %d → %d  (%d IP)" % [c.role_rank, c.role_rank + 1, c.rank_raise_cost()], Hud.GOLD,
		func(): c.raise_rank(); _rebuild(), c.ip >= c.rank_raise_cost() and c.role_rank < 10))
	var tree := Combatant.perk_tree(c.role)
	for t in tree.size():
		box.add_child(_text("TIER %d PERK%s" % [t + 1, "  · needs Rank %d" % int(RulesDB.load_json("perks.json").tier2_rank) if t > 0 else ""], Hud.F_TERM, 18, Hud.DIM))
		for pk in tree[t]:
			var id: String = pk.id
			var taken: bool = id in c.perks
			var why := c.perk_block(id)
			var b := _button(("✓ " if taken else "") + "%s · %s" % [String(pk.name).to_upper(), pk.desc] + ("" if taken else "  (%d IP)" % c.perk_cost(id)),
				Hud.GREEN if taken else Hud.CYAN, func(): c.take_perk(id); _rebuild(), why == "" and not taken)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_override("font", Hud.F_TERM)
			b.add_theme_font_size_override("font_size", 17)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.custom_minimum_size.x = 260
			box.add_child(b)
	box.add_child(_text("SKILLS", Hud.F_TERM, 18, Hud.DIM))
	var grid := GridContainer.new()
	grid.columns = 2
	box.add_child(grid)
	var list: Array = TRAIN_SKILLS.get(c.role, []).duplicate()
	for sk in TRAIN_COMMON:
		if sk not in list:
			list.append(sk)
	for sk in list.slice(0, 8):
		if not RulesDB.load_json("skills.json")["skills"].has(sk):
			continue
		var skid: String = sk
		var lv := int(c.skills.get(sk, 0))
		var cost := c.skill_raise_cost(sk)
		var b2 := _button("%s %d→%d · %d" % [sk.replace("_", " ").to_upper(), lv, lv + 1, cost], Hud.MAGENTA, func(): c.raise_skill(skid); _rebuild(), c.ip >= cost and lv < 10)
		b2.add_theme_font_size_override("font_size", 15)
		grid.add_child(b2)
	return box


func _gig_card(i: int) -> PanelContainer:
	var g: Dictionary = camp.board[i]
	var p := _panel(Hud.GOLD)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	p.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	col.add_child(top)
	var t := _text(String(g.title).to_upper(), Hud.F_DISPLAY, 30, Hud.GOLD, true)
	top.add_child(t)
	top.add_child(_text("%s eb" % _money(int(g.pay)), Hud.F_TERM, 30, Hud.GREEN))
	col.add_child(_text("%s (REP %d) · %s · SECURITY %s" % [String(g.fixer).to_upper(), camp.rep_with(String(g.fixer)), String(RulesDB.gen("scenes.json")[g.scene].get("name", g.scene)).to_upper(), "◆".repeat(int(g.security)) + "◇".repeat(3 - int(g.security))], Hud.F_TERM, 20, Hud.CYAN))
	col.add_child(_text(String(g.blurb), Hud.F_BODY, 20, Color(Hud.TEXT, 0.85), true))
	if g.get("unique", false):
		col.add_child(_text("PERSONAL JOB · %s TRUSTS YOU · DOUBLE PAY" % String(g.fixer).to_upper(), Hud.F_TERM, 18, Hud.MAGENTA))
	var tw := String(g.get("twist", ""))
	if tw != "":
		var td: Dictionary = RulesDB.gen("gigs.json").twists[tw]
		col.add_child(_text("TWIST · %s: %s" % [String(td.name).to_upper(), td.desc], Hud.F_TERM, 18, Hud.RED, true))
	col.add_child(_text({"data": "OBJECTIVE · PULL THE FILE IN THE NET, OR CLEAR THE SITE", "eliminate": "OBJECTIVE · NOBODY LEFT STANDING, BACKUP INCLUDED",
		"snatch": "OBJECTIVE · GRAB THE PACKAGE, CARRY IT OUT THE WAY YOU CAME"}[Campaign.objective_for(g)], Hud.F_TERM, 18, Hud.GOLD))
	var ready := camp.alive_crew().any(func(c): return c.can_act() and c.wound_state() < Combatant.Wound.MORTAL)
	col.add_child(_button("TAKE THE GIG", Hud.GOLD, func(): _take(i), ready))
	return p


func _recruit_card(i: int) -> PanelContainer:
	var r: Combatant = camp.recruits[i]
	var p := _panel(Hud.GREEN)
	var col := VBoxContainer.new()
	p.add_child(col)
	col.add_child(_text(r.display_name.to_upper(), Hud.F_DISPLAY, 26, Hud.TEXT))
	col.add_child(_text(r.role.to_upper(), Hud.F_TERM, 20, Hud.GREEN))
	col.add_child(_button("HIRE", Hud.GREEN, func(): camp.hire(i); _rebuild(), camp.eb >= int(Campaign.ECON.hire) and camp.crew.size() < 4))
	return p


func _report_panel() -> PanelContainer:
	var won: bool = report.won
	var p := _panel(Hud.GREEN if won else Hud.RED)
	var col := VBoxContainer.new()
	p.add_child(col)
	col.add_child(_text(("GIG COMPLETE · " if won else "GIG FAILED · ") + String(report.gig.get("title", "")).to_upper(), Hud.F_DISPLAY, 34, Hud.GREEN if won else Hud.RED, true))
	var parts := ["%+d eb" % (int(report.pay) - int(report.fees)), "%+d rep" % int(report.rep), "%d IP each" % int(report.ip)]
	for nm in report.get("episodes", []):
		parts.append("%s: CYBERPSYCHOTIC EPISODE" % String(nm).to_upper())
	if int(report.get("heat", 0)) != 0:
		parts.append("%+d heat" % int(report.heat))
	if int(report.get("salvage", 0)) > 0:
		parts.insert(1, "+%d eb salvage" % int(report.salvage))
	col.add_child(_text("   ".join(parts), Hud.F_TERM, 26, Hud.TEXT))
	if not report.dead.is_empty():
		col.add_child(_text("FLATLINED: " + ", ".join(report.dead).to_upper(), Hud.F_TERM, 24, Hud.RED))
	if not report.hurt.is_empty():
		col.add_child(_text("Hurt: " + ", ".join(report.hurt) + " (rest to heal; clinics treat Critical Injuries)", Hud.F_TERM, 20, Hud.GOLD, true))
	return p


func _take(i: int) -> void:
	if camp.accept(i).is_empty():
		return
	camp.save()
	get_tree().change_scene_to_file(GREYBOX)
