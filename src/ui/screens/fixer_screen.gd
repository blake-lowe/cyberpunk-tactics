class_name FixerScreen
extends SafehouseScreen
## The Fixer Network room: JOBS (the fixers' gig offers), HIRE (recruits) and the NIGHT MARKET:
## a web shop (MarketTab) selling the Night Market that's up (CPR core p.337-339) and the fixer's
## own stock (everything up to Premium, which needs no Night Market, p.385) in one list with a cart. Each item
## shows its Price Category (p.385). Every purchase, cyberware included, goes to safehouse storage;
## nothing is bought for a crew member and owning one never blocks buying another.

const OBJECTIVE_TEXT := {"data": "Download the target file, or eliminate all hostiles",
	"eliminate": "Eliminate all hostiles, including reinforcements",
	"snatch": "Recover the package and carry it to the extraction zone",
	"assassinate": "Down the mark before they reach an exit, then get out",
	"rescue": "Free the captive and walk them to the extraction zone",
	"sabotage": "Plant a charge on the target machine, get clear, get out",
	"escort": "Walk the client to the rendezvous alive",
	"defend": "Hold the room through every wave"}

## A Security Code → tint, read from the crew's side: cool blue (low: a response rarely comes,
## NC2045 p.7) through teal to orange and hot red (high: it almost always does). No yellow or green:
## gold is selection's colour, green is health.
const CODE_RAMP := ["5f7cff", "4f88ff", "3d95ff", "17b5f2", "05d9e8", "2fd3bf", "ff9a3c", "ff7f2a", "ff5a3c", "ff3b4f", "ff1f55"]
## Faction names too long for a card line.
const SHORT_FACTION := {"san_luis_obispo_county_sheriff": "SLO SHERIFF", "norcal_cog_military_police": "NORCAL MP",
	"ncu_campus_security": "NCU SECURITY"}

signal take_gig(index: int)
## DEV ONLY: the CUSTOM GIG (DEV) card's form (CustomGigCard), developer mode only.
signal take_custom(form: Dictionary)

var focus_gig := -1   ## a job opened from the CITY map: JOBS scrolls to it and marks it gold
## DEV ONLY: the custom gig card's form, kept while the screen is open; a dev launch's gig flags
## (greybox's --setpiece, --objective, ...: CustomGig.from_flags) prefill it.
var custom_form := CustomGig.from_flags(OS.get_cmdline_user_args())
var focus_custom := "--focus=custom" in OS.get_cmdline_user_args()   ## review shots: JOBS opens scrolled to the custom card
var shop := {}   ## NIGHT MARKET: the shop's cart, filters and view while the screen is open (MarketTab.new_state)


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
	var card: Control = null
	if shows_custom():   # DEV ONLY: never offered without developer mode
		card = CustomGigCard.new().setup(camp, ready, custom_form)
		card.name = "CustomGig"
		(card as CustomGigCard).take.connect(func(f: Dictionary): take_custom.emit(f))
		list.add_child(card)
	var sc := UiKit.scroller(list)
	body.add_child(sc)
	if card and focus_custom:
		(func(): sc.scroll_vertical = int(card.position.y)).call_deferred()


## Is the dev-only custom gig card on JOBS? Only in developer mode (GameSettings.dev_mode).
static func shows_custom() -> bool:
	return GameSettings.dev_mode()


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
	# Who's hiring (Mission Builder step 1, SPM p.28): the client behind the fixer; older offers name the fixer.
	var client := MissionBuilder.client_text(g)
	left.add_child(UiKit.label("Client: " + client if client != "" else "Fixer: " + String(g.fixer), 14, Hud.CYAN))
	var where := [Campaign.place_name(g), Campaign.district_name(g)].filter(func(s): return s != "")
	var drive := Travel.label(camp.travel_minutes(g))   # NC2045 p.18: from the safehouse district
	if drive != "":
		where.append(drive)
	left.add_child(UiKit.label(" · ".join(where), 12, Hud.DIM))   # place · district · drive; the hook is the blurb
	left.add_child(UiKit.body(String(g.blurb), 15))
	var mid := UiKit.vbox(6)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	mid.add_child(UiKit.body("★ " + String(OBJECTIVE_TEXT.get(Campaign.objective_for(g), "")), 15, Hud.TEXT))
	var fc: Dictionary = g.get("focus", {}) if g.get("focus") is Dictionary else {}
	if not fc.is_empty():   # the focus (SPM p.73): what the job is about
		mid.add_child(UiKit.body("Focus: " + String(fc.get("label", "")), 14, Hud.GOLD))
	if g.has("intel"):   # paid for in information: the Oracle asked ahead (Campaign.foresee)
		var trouble := String(g.intel) == "trouble"
		mid.add_child(UiKit.body("Intel: expect a complication" if trouble else "Intel: it should run clean", 14, Hud.RED if trouble else Hud.GREEN))
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
	var extra := MissionBuilder.payment_extra(g.get("payment", {}) if g.get("payment") is Dictionary else {})
	if extra != "":   # paid partly in information, a favour or goods (SPM p.28 step 4)
		var x := UiKit.body("+ " + extra, 14, Hud.GOLD)
		x.custom_minimum_size.x = 220
		right.add_child(x)
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

## NIGHT MARKET: the shop (MarketTab; owner's verdict: the dark web portal with a list view and a
## cart). Its state, cart included, lives while the screen is open; a checkout saves and rebuilds.
func _market(body: VBoxContainer) -> void:
	if shop.is_empty():
		shop = MarketTab.new_state()
	var w := get_viewport_rect().size.x if is_inside_tree() else 1280.0
	var t := MarketTab.new().setup(camp, shop, w)
	t.name = "Market"
	t.bought.connect(refresh)
	body.add_child(t)
