class_name DebriefScreen
extends SafehouseScreen
## After a gig, before the safehouse: how it went (pay, Improvement Points, the Reputation the deed
## earned, CPR core p193 and p410) and, per crew member, what it cost them (Critical Injuries, Wound
## State, consumables used, a new addiction, Humanity, death; the fallen's LOST GEAR one item a line). CONTINUE goes to the safehouse; the
## room screens' crew cards keep the marks until the next gig (Campaign.marks_for).

var report: Dictionary = {}


func _init() -> void:
	show_back = false


func title() -> String:
	return "Debrief"


func build_body(body: VBoxContainer) -> void:
	var gig: Dictionary = report.get("gig", {})
	var out := outcome(report)
	var top := UiKit.panel(out[1], 14)
	body.add_child(top)
	var tv := UiKit.vbox(6)
	top.add_child(tv)
	var h := UiKit.hbox(16)
	tv.add_child(h)
	var res := UiKit.head(String(out[0]), 36, out[1])
	h.add_child(res)
	var t := UiKit.head(String(gig.get("title", "")), 30, Hud.TEXT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.custom_minimum_size.x = 100
	h.add_child(t)
	var sums := UiKit.hbox(28)
	tv.add_child(sums)
	_sum(sums, "PAY", "%s eb" % UiKit.money(int(report.get("pay", 0))), Hud.TEXT)
	_sum(sums, "IMPROVEMENT POINTS", "%d each" % int(report.get("ip", 0)), Hud.CYAN)
	if String(gig.get("fixer", "")) != "":
		_sum(sums, "FIXER", String(gig.fixer), Hud.TEXT)
	var members: Array = report.get("members", [])
	var grid := GridContainer.new()
	grid.columns = clampi(members.size(), 1, 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	for m in members:
		grid.add_child(_member(m))
	var sc := UiKit.scroller(grid)
	body.add_child(sc)
	var bottom := UiKit.hbox(12)
	body.add_child(bottom)
	bottom.add_child(UiKit.body("The crew cards in the Bunks, Med Bay and Training Room keep these marks until the next gig.", 14, Hud.DIM, false))
	bottom.add_child(UiKit.spacer())
	var b := UiKit.button("CONTINUE  ›", UiKit.PRIMARY, func(): closed.emit(), true, 17)
	b.custom_minimum_size = Vector2(220, 44)
	bottom.add_child(b)


## The headline and its colour, worded as the map's end banner was (greybox end_banner): a gig
## not done says how it ended (Campaign.resolve `state`).
static func outcome(rep: Dictionary) -> Array:
	var won: bool = rep.get("won", false)
	var state := String(rep.get("state", "won" if won else "lost"))
	if won:
		return ["Gig complete", Hud.GREEN]
	return ["Gig abandoned" if state == "fled" else "Gig failed", Hud.RED]


func _sum(row: HBoxContainer, k: String, v: String, col: Color) -> void:
	var box := UiKit.vbox(-2)
	box.add_child(UiKit.label(k, 12, Hud.DIM))
	box.add_child(UiKit.label(v, 20, col))
	row.add_child(box)


func _member(m: Dictionary) -> PanelContainer:
	var dead: bool = m.get("dead", false)
	var p := UiKit.panel(Hud.RED if dead else Hud.CYAN, 10)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var v := UiKit.vbox(6)
	p.add_child(v)
	var h := UiKit.hbox(10)
	v.add_child(h)
	var c: Combatant = null
	for x in camp.crew:
		if x.display_name == String(m.get("name", "")):
			c = x
	if c:
		h.add_child(UiKit.portrait(portraits, c, 1000 + maxi(0, c.look_seed), 56))
	var nv := UiKit.vbox(0)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nv)
	nv.add_child(UiKit.fit(UiKit.head(String(m.get("name", "")), 30, Hud.TEXT)))
	nv.add_child(UiKit.label(String(m.get("role", "")), 13, Hud.DIM))
	if dead:
		v.add_child(UiKit.head("Flatlined", 30, Hud.RED))
		var lost: Array = m.get("lost", m.get("kit", []))
		if not lost.is_empty():
			v.add_child(UiKit.label("LOST GEAR", 12, Hud.DIM))
			var keys: Array = m.get("lost_keys", [])
			for i in lost.size():
				var ll := UiKit.body(String(lost[i]), 15, Hud.TEXT)
				v.add_child(QualityText.apply(ll, String(keys[i])) if i < keys.size() and String(keys[i]) != "" else ll)
		return p
	var hpc := Hud.GREEN if int(m.get("hp", 0)) >= int(m.get("max_hp", 1)) else (Hud.GOLD if String(m.get("wound", "")) == "Lightly Wounded" else Hud.RED)
	v.add_child(UiKit.label("HP %d/%d · %s" % [int(m.get("hp", 0)), int(m.get("max_hp", 0)), String(m.get("wound", ""))], 15, hpc))
	_line(v, "IMPROVEMENT POINTS", "+%d IP" % int(m.get("ip", 0)), Hud.CYAN)
	_line(v, "REPUTATION", ("now %d" % int(m.reputation)) if int(m.get("reputation", 0)) > 0 else "unchanged", Hud.CYAN if int(m.get("reputation", 0)) > 0 else Hud.DIM)
	var inj: Array = m.get("injuries", [])
	_line(v, "CRITICAL INJURIES", ", ".join(inj) if not inj.is_empty() else "none", Hud.RED if not inj.is_empty() else Hud.DIM)
	var kit: Array = m.get("kit", [])
	_line(v, "CONSUMABLES USED", ", ".join(kit) if not kit.is_empty() else "none", Hud.TEXT if not kit.is_empty() else Hud.DIM)
	var hooked: Array = m.get("addicted", [])
	if not hooked.is_empty():
		_line(v, "ADDICTED", ", ".join(hooked), Hud.RED)
	if int(m.get("humanity_lost", 0)) > 0:
		_line(v, "HUMANITY", "-%d" % int(m.humanity_lost), Hud.VIOLET.lightened(0.3))
	if m.get("episode", false):
		_line(v, "CYBERPSYCHOSIS", "an episode after the job", Hud.RED)
	return p


func _line(v: VBoxContainer, k: String, val: String, col: Color) -> void:
	var box := UiKit.vbox(-2)
	box.add_child(UiKit.label(k, 12, Hud.DIM))
	box.add_child(UiKit.body(val, 15, col))
	v.add_child(box)
