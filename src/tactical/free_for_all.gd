class_name FreeForAll
extends RefCounted
## A side at war with everyone: an encounter rule any set piece can carry (setpieces.json
## rules.free_for_all, or Encounter.setup opts.free_for_all). A handful of fighters from the
## printed stat blocks roam the map on a side of their own, hostile to the crew, the opposition and
## every responder who turns up (Encounter.add_side's `at_war`), not to bystanders or medics. They
## walk a beat until they see the crew or hear shooting, then hunt whoever is nearest (AI.act).
## The Combat Zone's implanted contestants (NC2045 p.216) are the first.
##
## spec: {faction (the side's id), rank (their name: "Contestant 2"), count: [a, b], blocks:
## [npcs.json ids, drawn per fighter], keep_out: [room kinds they never start in], brief, source}
## They start inside the map's set_area when it has one (the set, not the street outside), on
## the street floor, off the target building, 15+ squares from the deploy zone, 6+ apart.

const MIN_FROM_DEPLOY := 15.0
const MIN_APART := 6.0


## Put the side and its fighters on the map. Returns their unit ids ([] for an empty spec).
static func place(e: Encounter, spec: Dictionary, deploy: Vector2i) -> Array:
	if spec.is_empty():
		return []
	var m := e.m
	var fid := String(spec.get("faction", "free_for_all"))
	var blocks: Array = spec.get("blocks", ["boosterganger"])
	var cnt: Array = spec.get("count", [3, 5])
	var n := int(cnt[0]) + e.dice.d(int(cnt[-1]) - int(cnt[0]) + 1) - 1
	var a: Array = m.params.get("set_area", [0, 0, m.w, m.h])
	var area := Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))
	var keep_out: Array = spec.get("keep_out", [])
	var tsid := -1
	for st in m.structures:
		if st.target:
			tsid = int(st.id)
	var occ := e.occupied()
	var cand: Array = []
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var v := Vector3i(x, y, m.street)
			if not m.inb(x, y) or not m.walkable(m.street, Vector2i(x, y)) or m.has_cover_at(m.street, Vector2i(x, y)) or occ.has(v):
				continue
			if Vector2(x - deploy.x, y - deploy.y).length() < MIN_FROM_DEPLOY:
				continue
			var l := m.label(m.street, x, y)
			if l >= 0 and (int(m.rooms[l].get("structure", -1)) == tsid or String(m.rooms[l].kind) in keep_out):
				continue
			cand.append(v)
	if cand.is_empty() or n <= 0:
		return []
	var team := e.add_side(fid, "guard", false, {"at_war": true})
	var ids := []
	var placed: Array = []
	for k in n * 20:
		if ids.size() >= n:
			break
		var v: Vector3i = cand[e.dice.d(cand.size()) - 1]
		if placed.any(func(q): return Vector2(q.x - v.x, q.y - v.y).length() < MIN_APART):
			continue
		var block := String(blocks[e.dice.d(blocks.size()) - 1])
		var c := Recruit.from_block(e.dice, block, "%s %d" % [String(spec.get("rank", "Fighter")), ids.size() + 1])
		c.role = String(RulesDB.load_json("npcs.json")["blocks"][block].get("tier", "mook"))
		c.faction = fid
		e._add(c, v, team)
		e.units[-1]["roam"] = true   # walks a beat from the start (Encounter._post_guards)
		ids.append(int(e.units[-1].id))
		placed.append(v)
	return ids
