class_name MedBayScreen
extends SafehouseScreen
## The Med Bay: the RIPPERDOC (cyberware on sale at the Night Market that's up, bought there and
## installed free, CPR core p338; the price includes the surgery, p110; Humanity Loss on install),
## THERAPY (Addiction and Humanity Loss Therapy by a Medtech, p229-230) and Treatment for
## Critical Injuries (p223).


func room_name() -> String:
	return "MED BAY"


func title() -> String:
	return {"ripperdoc": "Ripperdoc", "therapy": "Therapy", "injuries": "Critical Injuries"}.get(tab, "Med Bay")


func tabs() -> Array:
	return [["ripperdoc", "RIPPERDOC"], ["therapy", "THERAPY"], ["injuries", "CRITICAL INJURIES"]]


func build_body(body: VBoxContainer) -> void:
	if camp.alive_crew().is_empty():
		body.add_child(none("Nobody on the crew."))
		return
	match tab:
		"ripperdoc": _ripperdoc(body)
		"therapy": _therapy(body)
		"injuries": _injuries(body)


func _humanity_line(c: Combatant) -> String:
	return "HUMANITY %d/%d · EMP %d" % [c.humanity, c.max_humanity, c.raw_stat("EMP")] if c.tracks_humanity else ""


# --- Ripperdoc --------------------------------------------------------------------------------

func _ripperdoc(body: VBoxContainer) -> void:
	var cols := UiKit.hbox(12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	cols.add_child(crew_picker(_humanity_line))
	var c := selected()
	var right := UiKit.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var top := UiKit.panel(Hud.VIOLET, 10)
	right.add_child(top)
	var tv := UiKit.vbox(4)
	top.add_child(tv)
	var hl := UiKit.hbox(14)
	tv.add_child(hl)
	hl.add_child(UiKit.head(c.display_name, 30, Hud.TEXT))
	if c.tracks_humanity:
		hl.add_child(UiKit.label(_humanity_line(c), 15, _hum_colour(c)))
	var have: Array = c.cyberware.map(func(x): return String(RulesDB.cyberware(String(x)).get("name", x)))
	tv.add_child(UiKit.body("Installed: " + (", ".join(have) if not have.is_empty() else "none"), 15, Hud.VIOLET.lightened(0.35) if not have.is_empty() else Hud.DIM))
	tv.add_child(UiKit.body("Cyberware is bought from the Night Market that has it on sale; its ripperdoc installs it free. Every piece costs Humanity.", 14, Hud.DIM))
	var p := UiKit.panel(Hud.VIOLET, 10)
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(p)
	var pv := UiKit.vbox(6)
	p.add_child(pv)
	pv.add_child(section("AT THIS NIGHT MARKET", Hud.VIOLET.lightened(0.35)))
	var list := UiKit.vbox(6)
	pv.add_child(UiKit.scroller(list))
	var away: Array[String] = []
	for id in Campaign.RIPPERDOC:
		if not camp.on_sale("cyberware/" + id):
			away.append(String(RulesDB.cyberware(id).name))
			continue
		list.add_child(_chrome_row(c, id))
	if list.get_child_count() == 0:
		list.add_child(none("This Night Market has no cyberware the crew can use." if not camp.market.is_empty() else "No Night Market is up."))
	if not away.is_empty():
		pv.add_child(UiKit.body("Not on sale now: " + ", ".join(away), 13, Hud.DIM))


func _chrome_row(c: Combatant, id: String) -> Control:
	var d := RulesDB.cyberware(id)
	var row := UiKit.hbox(10)
	var v := UiKit.vbox(-2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	v.add_child(UiKit.fit(UiKit.label(String(d.name), 16, Hud.VIOLET.lightened(0.35))))
	var need := String(Campaign.RIPPERDOC[id][0])
	var sub := String(Campaign.RIPPERDOC[id][1]) + " Humanity Loss %s." % String(d.hl_dice)
	if need != "":
		sub += " Needs %s." % String(RulesDB.cyberware(need).name)
	v.add_child(UiKit.body(sub, 13, Hud.DIM))
	var why := camp.install_block(c, id)
	var cost := int(d.cost)
	if why == "installed":
		row.add_child(UiKit.label("INSTALLED", 14, Hud.GREEN))
	elif why.begins_with("needs"):
		var l := UiKit.label(why, 13, Hud.DIM)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(l)
	else:
		var b := UiKit.button(UiKit.price_text("INSTALL", cost), UiKit.NEUTRAL, Callable(), why == "")
		b.custom_minimum_size.x = 170
		var nm := String(d.name)
		b.pressed.connect(func():
			var lost := [0]
			act(b, func(): lost[0] = camp.install(c, id), "")
			toast(b, "%s installed · -%d Humanity" % [nm, lost[0]], Hud.VIOLET.lightened(0.35)))
		row.add_child(b)
	return row


static func _hum_colour(c: Combatant) -> Color:
	return [Hud.GREEN, Hud.GOLD, Hud.RED, Hud.RED][clampi(c.psychosis_tier(), 0, 3)]


# --- Therapy ----------------------------------------------------------------------------------

func _therapy(body: VBoxContainer) -> void:
	var cols := UiKit.hbox(12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	cols.add_child(crew_picker(func(m): return _humanity_line(m) if m.addictions.is_empty() else "ADDICTED · " + _humanity_line(m)))
	var c := selected()
	var p := UiKit.panel(Hud.CYAN, 12)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(p)
	var v := UiKit.vbox(10)
	p.add_child(v)
	v.add_child(UiKit.head(c.display_name, 30))
	var doc := camp.therapist_for(c)
	v.add_child(UiKit.body(("Therapy is a week with %s (the crew's Medtech): TECH + Medical Tech against the therapy's DV. The crew rests meanwhile; materials are bought either way." % doc.display_name)
		if doc else "Therapy needs a Medtech on the crew, and a Medtech can't treat themselves.", 15, Hud.DIM if doc else Hud.GOLD))
	# Addiction (p229)
	v.add_child(section("ADDICTION"))
	if c.addictions.is_empty():
		v.add_child(none("Not addicted to anything."))
	var afx: Dictionary = RulesDB.gear("therapy", "addiction_therapy").get("fx", {})
	for drug in c.addictions:
		var dg: String = drug
		var row := UiKit.hbox(10)
		v.add_child(row)
		row.add_child(UiKit.fit(UiKit.label("Addicted to " + String(RulesDB.gear("drugs", dg).get("name", dg)), 16, Hud.RED)))
		var cost := int(afx.get("materials_cost", 500))
		var b := UiKit.button("ADDICTION THERAPY · %s eb · 1 WEEK" % UiKit.money(cost), UiKit.NEUTRAL, Callable(), doc != null and camp.eb >= cost)
		b.pressed.connect(func():
			var r := {}
			act(b, func(): r.merge(camp.treat_addiction(c, dg)), "")
			toast(b, "Clean" if r.get("success", false) else "The therapy didn't take", Hud.GREEN if r.get("success", false) else Hud.TEXT))
		row.add_child(b)
	# Humanity Loss (p229-230)
	v.add_child(section("HUMANITY"))
	if not c.tracks_humanity:
		v.add_child(none("—"))
		return
	v.add_child(UiKit.label(_humanity_line(c) + ("" if c.psychosis_tier() == 0 else " · AT RISK OF CYBERPSYCHOSIS"), 16, _hum_colour(c)))
	if c.humanity >= c.max_humanity:
		v.add_child(none("No Humanity to regain: they're at their maximum (each piece of chrome lowers it)."))
		return
	for kind in ["standard", "extreme"]:
		var k: String = kind
		var fx: Dictionary = RulesDB.gear("therapy", String(Campaign.HUMANITY_THERAPY[k])).get("fx", {})
		var row := UiKit.hbox(10)
		v.add_child(row)
		row.add_child(UiKit.fit(UiKit.body("%s: regain %s Humanity, DV%d." % [String(RulesDB.gear("therapy", String(Campaign.HUMANITY_THERAPY[k])).get("name", k)), String(fx.get("regain_humanity", "")), int(fx.get("dv", 15))], 15, Hud.TEXT, false)))
		var cost := Campaign.humanity_therapy_cost(k)
		var b := UiKit.button("%s · %s eb · 1 WEEK" % [k, UiKit.money(cost)], UiKit.NEUTRAL, Callable(), doc != null and camp.eb >= cost)
		b.custom_minimum_size.x = 230
		b.pressed.connect(func():
			var r := {}
			act(b, func(): r.merge(camp.humanity_therapy(c, k)), "")
			toast(b, ("+%d Humanity" % int(r.get("gained", 0))) if r.get("success", false) else "The therapy didn't take", Hud.GREEN if r.get("success", false) else Hud.TEXT))
		row.add_child(b)


# --- Critical Injuries ------------------------------------------------------------------------

func _injuries(body: VBoxContainer) -> void:
	body.add_child(UiKit.body("Rest doesn't heal a Critical Injury: Treatment removes it for good. A street clinic does it for %s eb each." % UiKit.money(camp.treat_cost()), 15, Hud.DIM))
	var list := UiKit.vbox(8)
	body.add_child(UiKit.scroller(list))
	var any := false
	for c in camp.alive_crew():
		if c.injuries.is_empty():
			continue
		any = true
		var p := UiKit.panel(Hud.CYAN, 10)
		list.add_child(p)
		var v := UiKit.vbox(6)
		p.add_child(v)
		var h := UiKit.hbox(12)
		v.add_child(h)
		h.add_child(UiKit.portrait(portraits, c, 1000 + maxi(0, c.look_seed), 40))
		h.add_child(UiKit.head(c.display_name, 28))
		var hp := UiKit.label("HP %d/%d · %s" % [c.hp, c.max_hp(), Campaign.WOUND_NAMES[c.wound_state()]], 14, UiKit.hp_colour(c))
		hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(hp)
		for i in c.injuries.size():
			var inj: Dictionary = c.injuries[i]
			var row := UiKit.hbox(10)
			v.add_child(row)
			var t: Dictionary = inj.get("treatment") if inj.get("treatment") is Dictionary else {}
			var txt := "%s (%s)" % [String(inj.get("name", "injury")), String(inj.get("location", ""))]
			row.add_child(UiKit.fit(UiKit.label(txt, 16, Hud.RED)))
			if not t.is_empty():
				row.add_child(UiKit.label("Treatment: %s DV%d" % [String(RulesDB.load_json("skills.json")["skills"].get(String(t.get("skill", "")), {}).get("name", t.get("skill", ""))), int(t.get("dv", 0))], 13, Hud.DIM))
			var idx := i
			var cc: Combatant = c
			var nm := String(inj.get("name", "injury"))
			var b := UiKit.button(UiKit.price_text("TREAT", camp.treat_cost()), UiKit.NEUTRAL, Callable(), camp.eb >= camp.treat_cost())
			b.pressed.connect(func(): act(b, func(): camp.treat(cc, idx), nm + " treated"))
			row.add_child(b)
	if not any:
		list.add_child(none("Nobody has a Critical Injury."))
