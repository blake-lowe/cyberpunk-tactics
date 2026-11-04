class_name FixerScreen
extends SafehouseScreen
## The Fixer Network room: JOBS (the fixers' gig offers), HIRE (recruits) and the NIGHT MARKET
## that's up (CPR core p.337-339: its two categories of goods, listings grouped by category) beside
## the always-on-sale staples (p.385: anything up to Premium, 100eb). Every purchase goes to safehouse
## storage; nothing is bought for a crew member and owning one never blocks buying another.

const OBJECTIVE_TEXT := {"data": "Download the target file, or eliminate all hostiles",
	"eliminate": "Eliminate all hostiles, including reinforcements",
	"snatch": "Recover the package and carry it to the extraction zone",
	"assassinate": "Down the mark before they reach an exit, then get out",
	"rescue": "Free the captive and walk them to the extraction zone",
	"sabotage": "Plant a charge on the target machine, get clear, get out"}

signal take_gig(index: int)


func room_name() -> String:
	return "FIXER NETWORK"


func title() -> String:
	return {"jobs": "Jobs", "hire": "Hire", "market": "Night Market"}.get(tab, "Fixer Network")


func tabs() -> Array:
	return [["jobs", "JOBS"], ["hire", "HIRE"], ["market", "NIGHT MARKET"]]


func build_body(body: VBoxContainer) -> void:
	match tab:
		"jobs": _jobs(body)
		"hire": _hire(body)
		"market": _market(body)


# --- Jobs -----------------------------------------------------------------------------------

func _jobs(body: VBoxContainer) -> void:
	var ready := camp.alive_crew().any(func(c): return c.can_act() and c.wound_state() < Combatant.Wound.MORTAL)
	var head := UiKit.hbox(12)
	head.add_child(UiKit.body("%d offers. Better jobs come to a crew with a name: fixers go by the crew's best Reputation." % camp.board.size(), 15, Hud.DIM, false))
	body.add_child(head)
	if not ready:
		body.add_child(UiKit.body("Nobody on the crew is fit to work. Recover in the Bunks first.", 16, Hud.RED))
	var list := UiKit.vbox(8)
	for i in camp.board.size():
		list.add_child(_gig_card(i, ready))
	if camp.board.is_empty():
		list.add_child(none("No offers today."))
	body.add_child(UiKit.scroller(list))


func _gig_card(i: int, ready: bool) -> PanelContainer:
	var g: Dictionary = camp.board[i]
	var p := UiKit.panel(Hud.CYAN, 12)
	var row := UiKit.hbox(18)
	p.add_child(row)
	var left := UiKit.vbox(4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.6
	row.add_child(left)
	var t := UiKit.head(String(g.title), 30, Hud.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size.x = 100
	left.add_child(t)
	left.add_child(UiKit.label("%s · %s" % [String(g.fixer), Campaign.place_name(g)], 14, Hud.CYAN))
	left.add_child(UiKit.body(String(g.blurb), 15))
	var mid := UiKit.vbox(6)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	mid.add_child(UiKit.body("★ " + String(OBJECTIVE_TEXT.get(Campaign.objective_for(g), "")), 15, Hud.TEXT))
	if g.get("unique", false):
		mid.add_child(UiKit.body("Personal job: %s has heard of the crew. Double pay." % String(g.fixer), 14, Hud.CYAN))
	var tw := String(g.get("twist", ""))
	if tw != "":
		var td: Dictionary = RulesDB.gen("gigs.json").twists[tw]
		mid.add_child(UiKit.label("TWIST · " + String(td.name), 14, Hud.RED))
		mid.add_child(UiKit.body(String(td.desc), 14, Color(Hud.TEXT, 0.75)))
	var right := UiKit.vbox(6)
	right.custom_minimum_size.x = 190
	row.add_child(right)
	right.add_child(UiKit.label("SECURITY %d/3" % int(g.security), 15, Hud.CYAN))
	right.add_child(UiKit.label("PAY", 12, Hud.DIM))
	right.add_child(UiKit.label("%s eb" % UiKit.money(int(g.pay)), 22, Hud.TEXT))
	var b := UiKit.button("TAKE THE GIG", UiKit.PRIMARY, func(): take_gig.emit(i), ready)
	right.add_child(b)
	return p


# --- Hire -----------------------------------------------------------------------------------

func _hire(body: VBoxContainer) -> void:
	var full := camp.crew.size() >= 4
	body.add_child(UiKit.body("Crew %d of 4. Signing someone costs %s eb.%s" % [camp.crew.size(), UiKit.money(int(Campaign.ECON.hire)),
		"  The crew is full." if full else ""], 15, Hud.DIM, false))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for i in camp.recruits.size():
		grid.add_child(_recruit_card(i, full))
	if camp.recruits.is_empty():
		body.add_child(none("Nobody is looking for work."))
	body.add_child(UiKit.scroller(grid))


func _recruit_card(i: int, full: bool) -> PanelContainer:
	var r: Combatant = camp.recruits[i]
	var p := UiKit.panel(Hud.CYAN, 10)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := UiKit.vbox(5)
	p.add_child(col)
	var top := UiKit.hbox(10)
	col.add_child(top)
	top.add_child(UiKit.portrait(portraits, r, 1000 + maxi(0, r.look_seed), 56))
	var nm := UiKit.vbox(0)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	nm.add_child(UiKit.fit(UiKit.head(r.display_name, 28)))
	nm.add_child(UiKit.label("%s · RANK %d" % [r.role, r.role_rank], 14, Hud.CYAN))
	nm.add_child(UiKit.label("HP %d" % r.max_hp(), 14, Hud.GREEN))
	col.add_child(stat_grid(r))
	var sk: Array = r.skills.keys().filter(func(k): return int(r.skills[k]) > 0)
	sk.sort_custom(func(a, b): return r.skill_base(a) > r.skill_base(b))
	col.add_child(UiKit.body(", ".join(sk.slice(0, 5).map(func(k): return "%s %d" % [String(RulesDB.skill(k).get("name", k)), r.skill_base(k)])), 14, Color(Hud.TEXT, 0.75)))
	col.add_child(UiKit.body(", ".join(r.weapons.map(func(w): return w.display_name())), 14, Hud.DIM))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var cost := int(Campaign.ECON.hire)
	var b := UiKit.button(UiKit.price_text("HIRE", cost), UiKit.NEUTRAL, Callable(), camp.eb >= cost and not full)
	var nm2 := r.display_name
	b.pressed.connect(func(): act(b, func(): camp.hire(i), "Hired %s" % nm2))
	col.add_child(b)
	return p


## The ten STATs in two rows of five (the book's stat block layout, p.412).
static func stat_grid(c: Combatant) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 5)
	g.add_theme_constant_override("v_separation", 0)
	for st in ["INT", "REF", "DEX", "TECH", "COOL", "WILL", "LUCK", "MOVE", "BODY", "EMP"]:
		var h := UiKit.hbox(3)
		h.add_child(UiKit.label(st, 11, Hud.DIM))
		h.add_child(UiKit.label(str(c.stat(st)), 13, Hud.TEXT))
		g.add_child(h)
	return g


# --- Night Market ---------------------------------------------------------------------------

func _market(body: VBoxContainer) -> void:
	var cats: Array = camp.market.get("categories", [])
	var info := UiKit.hbox(10)
	body.add_child(info)
	if cats.is_empty():
		info.add_child(UiKit.body("No Night Market is up.", 15, Hud.DIM, false))
	else:
		info.add_child(UiKit.label("UP UNTIL DAY %d" % int(camp.market.get("closes", camp.day)), 15, Hud.CYAN))
		for cid in cats:
			info.add_child(UiKit.chip(String(NightMarket.category(String(cid)).get("name", cid)), Hud.CYAN))
	info.add_child(UiKit.spacer())
	info.add_child(UiKit.label("Everything bought goes to storage (Armory)", 13, Hud.DIM))
	var cols := UiKit.hbox(10)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	var stock := {}
	for it in camp.market_stock():
		stock[String(it.key)] = it
	for cid in cats:
		var listings: Array = camp.market.get("listings", []).filter(func(l): return String(l.get("category", "")) == String(cid))
		cols.add_child(_column(String(NightMarket.category(String(cid)).get("name", cid)), listings, stock))
	var staples: Array = []
	for grp in [["weapon", "Weapons"], ["armor", "Armor"], ["ammo", "Ammunition"], ["drugs", "Street Drugs"], ["gear", "Gear"]]:
		var ks: Array = NightMarket.staples().filter(func(k): return Items.section(k) == grp[0])
		if not ks.is_empty():
			staples.append({"name": grp[1], "keys": ks})
	cols.add_child(_column("Always on sale", staples, stock, "Anything up to 100 eb can be had without a Night Market."))


func _column(heading: String, listings: Array, stock: Dictionary, note := "") -> PanelContainer:
	var p := UiKit.panel(Hud.CYAN, 10)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(6)
	p.add_child(v)
	v.add_child(UiKit.head(heading, 28, Hud.TEXT))
	if note != "":
		v.add_child(UiKit.body(note, 13, Hud.DIM))
	var list := UiKit.vbox(4)
	v.add_child(UiKit.scroller(list))
	for l in listings:
		if String(l.get("name", "")) != "":
			list.add_child(section(String(l.name)))
		if (l.get("keys", []) as Array).is_empty():
			list.add_child(none("Nothing the crew can use."))
		for k in l.get("keys", []):
			if stock.has(String(k)):
				list.add_child(_item_row(stock[String(k)]))
	return p


## One listing: one item at its set quality, BUY · price (neutral), how many storage holds.
func _item_row(it: Dictionary) -> Control:
	var row := UiKit.hbox(8)
	var v := UiKit.vbox(-2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	var chrome: bool = it.kind == "cyberware"
	v.add_child(UiKit.fit(UiKit.label(String(it.name), 15, Hud.VIOLET.lightened(0.3) if chrome else Hud.TEXT)))
	var sub := ("%s eb · " % UiKit.money(int(it.cost)) if chrome else "") + String(it.info)
	if int(it.owned) > 0:
		sub += ("  ·  " if sub != "" else "") + "%d in storage" % int(it.owned)
	v.add_child(UiKit.fit(UiKit.body(sub, 13, Hud.DIM, false)))
	var key: String = it.key
	if chrome:   # bought and fitted at the Med Bay's Ripperdoc (p338: installed free)
		row.add_child(UiKit.button("RIPPERDOC ›", UiKit.CHROME, func(): navigate.emit("ripperdoc")))
	else:
		var b := UiKit.button(UiKit.price_text("BUY", int(it.cost)), UiKit.NEUTRAL, Callable(), camp.eb >= int(it.cost))
		b.custom_minimum_size.x = 132
		var nm := String(it.name)
		b.pressed.connect(func(): act(b, func(): camp.buy(key), "Bought " + nm))
		row.add_child(b)
	return row
