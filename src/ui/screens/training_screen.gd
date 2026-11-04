class_name TrainingScreen
extends SafehouseScreen
## The Training Room: spending Improvement Points (CPR core p410-411). Raise a Skill (20 IP x the
## new Level, doubled for (x2) Skills), raise the Role's Rank (60 IP x the new Rank), or take a
## Role perk (the game's HOUSE-RULE perk tree, data/rules/perks.json).

## The book's Skill categories, in its order (p.80-86); the Role category (Surgery) is raised with
## the Medtech's Medicine Rank, not with IP.
const CATEGORIES := ["Awareness", "Body", "Control", "Education", "Fighting", "Performance", "Ranged Weapon", "Social", "Technique"]


func room_name() -> String:
	return "TRAINING ROOM"


func title() -> String:
	return "Improvement Points"


func build_body(body: VBoxContainer) -> void:
	var crew := camp.alive_crew()
	if crew.is_empty():
		body.add_child(none("Nobody on the crew."))
		return
	var cols := UiKit.hbox(12)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	cols.add_child(crew_picker(func(m): return "%d IP" % m.ip, 250))
	var c := selected()
	# Role Rank and perks
	var mid := UiKit.panel(Hud.CYAN, 12)
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.custom_minimum_size.x = 330
	cols.add_child(mid)
	var mv := UiKit.vbox(8)
	mid.add_child(mv)
	var hr := UiKit.hbox(12)
	mv.add_child(hr)
	hr.add_child(UiKit.head(c.display_name, 30))
	var ipl := UiKit.label("%d IP" % c.ip, 20, Hud.CYAN)
	ipl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(ipl)
	mv.add_child(section("ROLE · %s" % c.role))
	mv.add_child(UiKit.label("RANK %d" % c.role_rank, 18, Hud.TEXT))
	var rc := c.rank_raise_cost()
	var rb := UiKit.button("RANK %d · %d IP" % [c.role_rank + 1, rc], UiKit.NEUTRAL, Callable(), c.ip >= rc and c.role_rank < 10)
	rb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	rb.pressed.connect(func(): act(rb, func(): c.raise_rank(), "Rank %d" % (c.role_rank + 1)))
	mv.add_child(rb)
	var tree := Combatant.perk_tree(c.role)
	if not tree.is_empty():
		mv.add_child(section("ROLE PERKS · ONE PER TIER"))
		var cfg: Dictionary = RulesDB.load_json("perks.json")
		var perks := UiKit.vbox(6)
		mv.add_child(UiKit.scroller(perks))
		for t in tree.size():
			perks.add_child(UiKit.label("TIER %d · %d IP%s" % [t + 1, int(cfg.tier_cost[t]), " · RANK %d" % int(cfg.tier2_rank) if t > 0 else ""], 13, Hud.DIM))
			for pk in tree[t]:
				perks.add_child(_perk(c, pk))
	# Skills
	var right := UiKit.panel(Hud.CYAN, 12)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var rv := UiKit.vbox(6)
	right.add_child(rv)
	rv.add_child(section("SKILLS · LEVEL → NEXT LEVEL"))
	var list := UiKit.vbox(2)
	rv.add_child(UiKit.scroller(list))
	var all: Dictionary = RulesDB.load_json("skills.json")["skills"]
	for cat in CATEGORIES:
		list.add_child(UiKit.label(String(cat), 13, Hud.CYAN))
		var grid := GridContainer.new()
		grid.columns = 2 if size.x >= 1500 else 1   # two columns only where they fit
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 2)
		list.add_child(grid)
		var ids: Array = all.keys().filter(func(k): return String(all[k].category) == cat)
		ids.sort_custom(func(a, b): return int(c.skills.get(a, 0)) > int(c.skills.get(b, 0)) or (int(c.skills.get(a, 0)) == int(c.skills.get(b, 0)) and String(all[a].name) < String(all[b].name)))
		for id in ids:
			grid.add_child(_skill_row(c, String(id), all[id]))


func _perk(c: Combatant, pk: Dictionary) -> Control:
	var id: String = pk.id
	var taken: bool = id in c.perks
	var why := c.perk_block(id)
	var p := UiKit.selected_panel(8) if taken else UiKit.panel(Hud.CYAN, 8)
	var v := UiKit.vbox(2)
	p.add_child(v)
	var h := UiKit.hbox(8)
	v.add_child(h)
	h.add_child(UiKit.fit(UiKit.label(String(pk.name), 15, Hud.GOLD if taken else Hud.TEXT)))
	if taken:
		h.add_child(UiKit.label("TAKEN", 13, Hud.GOLD))
	else:
		var b := UiKit.button("TAKE · %d IP" % c.perk_cost(id), UiKit.NEUTRAL, Callable(), why == "")
		b.custom_minimum_size.y = 28
		b.pressed.connect(func(): act(b, func(): c.take_perk(id), String(pk.name)))
		h.add_child(b)
	v.add_child(UiKit.body(String(pk.desc) + ("" if why == "" or taken or why.ends_with("IP") else "  (%s)" % why), 13, Hud.DIM))
	return p


func _skill_row(c: Combatant, id: String, d: Dictionary) -> Control:
	var row := UiKit.hbox(6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lv := int(c.skills.get(id, 0))
	var nm := UiKit.fit(UiKit.label(String(d.name) + (" ×2" if d.get("x2", false) else ""), 14, Hud.TEXT if lv > 0 else Color(Hud.TEXT, 0.6)))
	nm.custom_minimum_size.x = 110
	row.add_child(nm)
	var st := UiKit.label(String(d.stat), 12, Hud.DIM)
	st.custom_minimum_size.x = 38
	row.add_child(st)
	var l := UiKit.label(str(lv), 15, Hud.TEXT)
	l.custom_minimum_size.x = 20
	row.add_child(l)
	var cost := c.skill_raise_cost(id)
	var b := UiKit.button("%d · %d IP" % [lv + 1, cost] if lv < 10 else "MAX", UiKit.NEUTRAL, Callable(), c.ip >= cost and lv < 10, 13)
	b.custom_minimum_size = Vector2(104, 26)
	b.pressed.connect(func(): act(b, func(): c.raise_skill(id), "%s %d" % [String(d.name), lv + 1]))
	row.add_child(b)
	return row
