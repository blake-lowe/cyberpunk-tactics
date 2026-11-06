class_name FixerScreen
extends SafehouseScreen
## The Fixer Network room: JOBS (the fixers' gig offers), HIRE (recruits) and the NIGHT MARKET
## that's up (CPR core p.337-339: a column per category of goods, its items listed directly) beside
## everything up to Premium, which needs no Night Market (p.385). Each item shows its Price
## Category (p.385). Every purchase, cyberware included, goes to safehouse storage; nothing is
## bought for a crew member and owning one never blocks buying another.

const OBJECTIVE_TEXT := {"data": "Download the target file, or eliminate all hostiles",
	"eliminate": "Eliminate all hostiles, including reinforcements",
	"snatch": "Recover the package and carry it to the extraction zone",
	"assassinate": "Down the mark before they reach an exit, then get out",
	"rescue": "Free the captive and walk them to the extraction zone",
	"sabotage": "Plant a charge on the target machine, get clear, get out"}

## A Security Code → tint, read from the crew's side: cool blue (low: a response rarely comes,
## NC2045 p.7) through teal to orange and hot red (high: it almost always does). No yellow or green:
## gold is selection's colour, green is health.
const CODE_RAMP := ["5f7cff", "4f88ff", "3d95ff", "17b5f2", "05d9e8", "2fd3bf", "ff9a3c", "ff7f2a", "ff5a3c", "ff3b4f", "ff1f55"]
## Faction names too long for a card line.
const SHORT_FACTION := {"san_luis_obispo_county_sheriff": "SLO SHERIFF", "norcal_cog_military_police": "NORCAL MP",
	"ncu_campus_security": "NCU SECURITY"}

signal take_gig(index: int)

var focus_gig := -1   ## a job opened from the CITY map: JOBS scrolls to it and marks it gold


func room_name() -> String:
	return "FIXER NETWORK"


func title() -> String:
	return {"jobs": "Jobs", "hire": "Hire", "market": "Night Market", "city": "City"}.get(tab, "Fixer Network")


func tabs() -> Array:
	return [["jobs", "JOBS"], ["hire", "HIRE"], ["market", "NIGHT MARKET"], ["city", "CITY"]]


## CITY: the Night City map (CityTab): pick an offer to plot the drive; its pin or button opens it in JOBS.
func build_body(body: VBoxContainer) -> void:
	if tab != "jobs":
		focus_gig = -1
	match tab:
		"jobs":
			_jobs(body)
			_focus_job(body)
		"hire": _hire(body)
		"market": _market(body)
		"city":
			var city := CityTab.new().setup(camp)
			city.open_job.connect(func(i: int): focus_gig = i; tab = "jobs"; _build.call_deferred())
			body.add_child(city)


## The job picked on the CITY map: its card edged in gold and scrolled into view.
func _focus_job(body: VBoxContainer) -> void:
	var scs := body.find_children("*", "ScrollContainer", true, false)
	if focus_gig < 0 or scs.is_empty():
		return
	var sc: ScrollContainer = scs[0]
	var list := sc.get_child(0)
	if focus_gig < list.get_child_count():
		var card := list.get_child(focus_gig) as PanelContainer
		card.add_theme_stylebox_override("panel", CutBox.make(Color(0.07, 0.06, 0.02, 0.95), Hud.GOLD, 12, 0b0101, Hud.GOLD, 12))
		sc.ensure_control_visible.call_deferred(card)


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
	var where := [String(g.fixer), Campaign.place_name(g), Campaign.district_name(g)].filter(func(s): return s != "")
	left.add_child(UiKit.label(" · ".join(where), 14, Hud.CYAN))   # fixer · place · district; the hook is the blurb
	var drive := Travel.label(camp.travel_minutes(g))   # NC2045 p.18: from the safehouse district
	if drive != "":
		left.add_child(UiKit.label(drive, 12, Hud.DIM))
	left.add_child(UiKit.body(String(g.blurb), 15))
	var mid := UiKit.vbox(6)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	mid.add_child(UiKit.body("★ " + String(OBJECTIVE_TEXT.get(Campaign.objective_for(g), "")), 15, Hud.TEXT))
	if g.get("unique", false):
		mid.add_child(UiKit.body("Personal job: %s has heard of the crew. Double pay." % String(g.fixer), 14, Hud.CYAN))
	for line in SetPieces.briefs(String(g.get("setpiece", ""))):   # the place's house rules (Totentanz: no fighting on the floor)
		mid.add_child(UiKit.body(line, 13, Hud.GOLD))
	var right := UiKit.vbox(6)
	right.custom_minimum_size.x = 240
	row.add_child(right)
	right.add_child(code_block(g, 17, 13))   # NC2045 p.7 Security Code
	right.add_child(UiKit.label("PAY", 12, Hud.DIM))
	right.add_child(UiKit.label("%s eb" % UiKit.money(int(g.pay)), 22, Hud.TEXT))
	var b := UiKit.button("TAKE THE GIG", UiKit.PRIMARY, func(): take_gig.emit(i), ready)
	right.add_child(b)
	return p


## A gig's Security Code in two lines, tinted by the code: "SECURITY 4" over
## "GOLD DRAGONS · HARDENED LIGHT" (the site's own people when the code names nobody).
static func code_block(gig: Dictionary, big: int, small: int) -> Control:
	var c := SecurityCode.normalise(gig.get("security_code"))
	if c.is_empty():
		c = SecurityCode.from_level(int(gig.get("security", 1)), String(gig.get("faction", "")))
	var who := String(c.faction) if String(c.faction) != "" else String(gig.get("faction", ""))
	var col := code_colour(int(c.n))
	var v := UiKit.vbox(0)
	v.add_child(UiKit.label("SECURITY %d" % int(c.n), big, col))
	var how := ("HARDENED " if bool(c.hardened) else "") + String(c.intensity).to_upper()
	v.add_child(UiKit.label("%s · %s" % [short_faction(who), how] if who != "" else how, small, col.lightened(0.25)))
	return v


static func code_colour(n: int) -> Color:
	return Color(CODE_RAMP[clampi(n, 0, CODE_RAMP.size() - 1)])


## "NCPD", "WHITEWATER", "SLO SHERIFF": a faction short enough for a card line.
static func short_faction(id: String) -> String:
	if SHORT_FACTION.has(id):
		return SHORT_FACTION[id]
	var n := SecurityCode.faction_name(id).to_upper().trim_prefix("THE ")
	var paren := RegEx.create_from_string("\\(([A-Z0-9]+)\\)").search(n)
	if paren:
		return paren.get_string(1)
	if n.length() <= 12:
		return n
	var words := n.split(" ", false)
	return words[0] if words[0].length() >= 4 or words.size() < 2 else words[0] + " " + words[1]


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
		info.add_child(UiKit.label("NIGHT MARKET UP UNTIL DAY %d" % int(camp.market.get("closes", camp.day)), 15, Hud.CYAN))
	info.add_child(UiKit.spacer())
	info.add_child(UiKit.label("Everything bought goes to storage (Armory)", 13, Hud.DIM))
	var cols := UiKit.hbox(10)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	var stock := {}
	for it in camp.market_stock():
		stock[String(it.key)] = it
	for cid in cats:   # p338: two categories of goods; their items listed directly, no sub-headings
		var keys: Array[String] = []
		for l in camp.market.get("listings", []):
			if String(l.get("category", "")) == String(cid):
				for k in l.get("keys", []):
					if stock.has(String(k)) and not String(k) in keys:
						keys.append(String(k))
		cols.add_child(_column(String(NightMarket.category(String(cid)).get("name", cid)), keys, stock))
	var cap := int(NightMarket.data().staples.get("max_cost", 100))
	var tier := Items.price_tier(cap)
	cols.add_child(_column("Up to " + tier, NightMarket.staples(), stock,
		"%s and cheaper (up to %s eb) needs no Night Market (p.385)." % [tier, UiKit.money(cap)]))


func _column(heading: String, keys: Array, stock: Dictionary, note := "") -> PanelContainer:
	var p := UiKit.panel(Hud.CYAN, 10)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(6)
	p.add_child(v)
	v.add_child(UiKit.head(heading, 28, Hud.TEXT))
	if note != "":
		v.add_child(UiKit.body(note, 13, Hud.DIM))
	var list := UiKit.vbox(6)
	v.add_child(UiKit.scroller(list))
	for k in keys:
		if stock.has(String(k)):
			list.add_child(_item_row(stock[String(k)]))
	if list.get_child_count() == 0:
		list.add_child(none("Nothing here the crew can use."))
	return p


## One item at its set quality: its name beside BUY · price, then its Price Category (p.385) and a
## description with room to wrap (owner: entries twice as tall, nothing cut off), and how many
## storage holds. Cyberware is bought the same way and installed
## later at the Med Bay.
func _item_row(it: Dictionary) -> Control:
	var p := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1, 0.025)
	box.border_color = Color(Hud.CYAN, 0.12)
	box.border_width_bottom = 1
	box.content_margin_left = 8
	box.content_margin_right = 4
	box.content_margin_top = 4
	box.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", box)
	p.custom_minimum_size.y = 72
	var v := UiKit.vbox(2)
	p.add_child(v)
	var top := UiKit.hbox(8)
	v.add_child(top)
	var chrome: bool = it.kind == "cyberware"
	var nm := UiKit.label(String(it.name), 15, Hud.VIOLET.lightened(0.3) if chrome else Hud.TEXT)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nm.custom_minimum_size.x = 60
	top.add_child(nm)
	var key: String = it.key
	var b := UiKit.button(UiKit.price_text("BUY", int(it.cost)), UiKit.NEUTRAL, Callable(), camp.eb >= int(it.cost))
	b.custom_minimum_size.x = 132
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nm2 := String(it.name)
	b.pressed.connect(func(): act(b, func(): camp.buy(key), "Bought " + nm2))
	top.add_child(b)
	var desc := String(it.info)
	if chrome:
		var id := Items.base_id(key)
		var need := String(Campaign.RIPPERDOC.get(id, [""])[0])
		desc += (" " if desc != "" else "") + "Humanity Loss %s." % String(RulesDB.cyberware(id).get("hl_dice", ""))
		if need != "":
			desc += " Needs %s." % String(RulesDB.cyberware(need).name)
		desc += " Installed at the Med Bay."
	if int(it.owned) > 0:
		desc += ("  ·  " if desc != "" else "") + "%d in storage" % int(it.owned)
	var line := UiKit.hbox(8)
	v.add_child(line)
	var tier := UiKit.label(Items.price_tier(int(it.cost)), 12, Hud.CYAN)
	tier.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tier.custom_minimum_size.y = 20
	tier.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(tier)
	line.add_child(UiKit.body(desc, 13, Hud.DIM))
	return p
