class_name TowerGen
extends RefCounted
## Tower bands (docs/plans/towers.md, stage 1a: the sky band). A tower gig plays one band of a tall
## building, a few storeys near its top: Raven Microcybernetics' floors 48-50 and the roof
## (NC2045 p.124-125). The scene `tower_top` builds it:
## - the map is the band's floor plate with a ring of sky round it (MARGIN squares of VOID: the
##   facade impostor and the smog below are the view's, WorldBuilder);
## - one building (BuildingGen, sealed: no street door) from the tower's recipe (sites.json
##   tower_corp / tower_hotel), one storey programme per storey of the band, bottom up, as the
##   tower's record names them (World.tower, docs/world/towers.md); the roof above the top storey;
## - the lift car in the lift lobby on the band's lowest storey is the crew's deploy zone (they
##   ride up in it; riding it back down is getting out: the deploy zone is the extraction zone);
## - responders come out of the lift car on any storey of the band or up the fire stair
##   (`arrival` entrances: Encounter.arrival_cell), not from a street edge;
## - the floors are numbered by their real storey (TacMap.storey_base, TacMap.bands: 48, 49, 50, R).
## Stage 2 stacks several bands (TacMap.bands) with rides between them; stage 1a has one.

const T := TacMap.T
## Sky round the floor plate (squares): the view hangs the facade below the band in it.
const MARGIN := 3
## What a bare `tower_top` scene builds (tests, tools, the greybox without --tower): Raven's sky band.
const DEFAULT_TOWER := "the_glen_24"
const DEFAULT_BAND := "sky"
## The crew's squares in the lift lobby (SceneGen.DEPLOY_SIZE: the lift car and the squares in
## front of its doors).
const DEPLOY := 6


## The tower record (World.tower) and band a scene's params name, the defaults filled in:
## [tower, band def, band id]. The band falls back to the tower's first one.
static func resolve(p: Dictionary) -> Array:
	var t := World.tower(String(p.get("tower", "")))
	if t.is_empty():
		t = World.tower(DEFAULT_TOWER)
	var bands: Dictionary = t.get("bands", {})
	var bid := String(p.get("band", DEFAULT_BAND))
	if not bands.has(bid):
		bid = String(bands.keys()[0]) if not bands.is_empty() else DEFAULT_BAND
	return [t, bands.get(bid, {}), bid]


## The storeys a band plays, bottom up ([48, 49, 50]).
static func band_storeys(b: Dictionary) -> Array[int]:
	var out: Array[int] = []
	var s: Array = b.get("storeys", [1, 1])
	for k in range(int(s[0]), int(s[1]) + 1):
		out.append(k)
	return out


## The recipe site of a tower record (sites.json).
static func recipe(t: Dictionary) -> String:
	return String(t.get("recipe", "tower_corp"))


## Size the map before SceneGen builds it (SceneGen.generate, as _site_size does for a lone
## building): the plate (the tower's own, else its recipe's, squares) plus MARGIN all round; one
## TacMap floor per storey of the band (SceneGen adds the roof level). Sets p.tower to the
## location id, p.band, p.site to the recipe. Whatever the caller set explicitly wins for w / h.
static func size(dice: Dice, p: Dictionary, overrides: Dictionary) -> void:
	var r := resolve(p)
	var t: Dictionary = r[0]
	var b: Dictionary = r[1]
	p["tower"] = String(t.get("location", DEFAULT_TOWER))
	p["band"] = String(r[2])
	p["site"] = recipe(t)
	var plate: Array = t.get("plate", RulesDB.gen("sites.json").get(recipe(t), {}).get("plate", [[26, 30], [20, 24]]))
	if not overrides.has("w") and not overrides.has("h"):
		p.w = dice.rng.randi_range(int(plate[0][0]), int(plate[0][1])) + MARGIN * 2
		p.h = dice.rng.randi_range(int(plate[1][0]), int(plate[1][1])) + MARGIN * 2
	p.floors = band_storeys(b).size()
	p["verticality"] = 1   # the recipe's own lift car (BuildingGen._lift_car), not a generic shaft


## The scene planner (SceneGen._plan "tower_top").
static func plan(c: Dictionary) -> void:
	var m: TacMap = c.m
	var p: Dictionary = c.p
	var r := resolve(p)
	var t: Dictionary = r[0]
	var b: Dictionary = r[1]
	var storeys := band_storeys(b)
	var site := recipe(t)
	var sdef: Dictionary = RulesDB.gen("sites.json")[site]
	var lib: Dictionary = sdef.get("storeys", {})
	var prog_names: Array = b.get("programme", [])
	# The program: the shared plan's depths come from the lowest storey's programme ("ground"),
	# every storey f gets its own (Layouts._bands_for reads the floor's own key first).
	var program := {"mirror": true}
	for f in storeys.size():
		var pn := String(prog_names[mini(f, prog_names.size() - 1)]) if not prog_names.is_empty() else ""
		var rows: Array = lib.get(pn, sdef.layout.program.ground)
		program[str(f)] = rows
		if f == 0:
			program["ground"] = rows
	var shell := Rect2i(MARGIN, MARGIN, m.w - MARGIN * 2, m.h - MARGIN * 2)
	var params := {"program": program}
	for k in ["density", "loops", "net_threat", "net_scale"]:
		if c.overrides.has(k):
			params[k] = c.overrides[k]
	var st := BuildingGen.build(m, c.dice, c.hints, {"shell": shell, "site": site, "floors": storeys.size(),
		"security": int(p.get("security", 1)), "target": true, "base_zone": TacMap.Zone.PUBLIC, "entry_side": "S",
		"params": params, "sealed": true})
	st["name"] = String(t.get("name", site))
	st["tower"] = String(t.get("location", ""))
	# The band record and the storey numbers (TacMap.floor_name: 48, 49, 50, R).
	var roof := storeys.size() if bool(b.get("roof", true)) and storeys.size() < m.floors else -1
	m.storey_base = storeys[0] - 1
	m.bands.assign([{"id": String(r[2]), "kind": String(r[2]), "from_floor": 0, "to_floor": storeys.size() - 1,
		"storey_from": storeys[0], "roof_floor": roof}])
	m.tower = {"location": String(t.get("location", "")), "id": String(t.get("id", "")), "name": String(t.get("name", "")),
		"storeys": int(t.get("storeys", storeys[-1])), "recipe": site}
	_deploy(m, int(st.id))
	_arrivals(m, int(st.id), storeys.size())


## The lift car of structure `sid` (BuildingGen._lift_car): its vertical, or {}.
static func car(m: TacMap, sid := -1) -> Dictionary:
	for v in m.verticals:
		if bool(v.get("car", false)) and (sid < 0 or int(v.get("structure", -1)) == sid):
			return v
	return {}


## The deploy zone: the lift car on the band's lowest storey and the lobby squares in front of its
## doors (DEPLOY in all, nearest the car first). The crew rode up in it; standing in it again is
## riding it down (Encounter.extract_cells is the deploy zone).
static func _deploy(m: TacMap, sid: int) -> void:
	var v := car(m, sid)
	if v.is_empty():
		push_warning("TowerGen: no lift car, no deploy zone")
		return
	var at: Vector2i = v.pos
	var face: Vector2i = v.get("face", Vector2i.DOWN)
	var l := m.label(0, at.x, at.y)
	var cells: Array = [at]
	var seen := {at: true}
	var q: Array = [at + face] if m.walkable(0, at + face) else []
	if not q.is_empty():
		seen[at + face] = true
		cells.append(at + face)
	while not q.is_empty() and cells.size() < DEPLOY:
		var c0: Vector2i = q.pop_front()
		for d in MapGen.DIRS:
			var n: Vector2i = c0 + d
			if seen.has(n) or m.label(0, n.x, n.y) != l or m.t(0, n.x, n.y) != T.FLOOR or m.has_cover_at(0, n):
				continue
			seen[n] = true
			q.append(n)
			if cells.size() < DEPLOY:
				cells.append(n)
	m.entrances.append({"floor": 0, "pos": at, "main": false, "kind": "deploy", "lift": true, "cells": cells, "structure": sid})


## Where responders come from (Encounter.arrival_cell): the lift car on every storey of the band
## and the fire stair on every storey (people coming up from below step off at any floor). Only the
## lift car on the band's lowest storey leads out of the band for someone fleeing (`exit`: an
## assassination's mark rides down in it; the fire stair between bands is stage 2's transition).
## It is the crew's car too: a crew member standing in it holds it, and the mark is trapped
## (docs/plans/towers.md section 2: holding the lift traps the mark).
static func _arrivals(m: TacMap, sid: int, n: int) -> void:
	var v := car(m, sid)
	for f in n:
		if not v.is_empty():
			m.entrances.append({"floor": f, "pos": v.pos, "main": false, "kind": "spawn", "arrival": "lift", "exit": f == 0, "structure": sid})
		for s in m.verticals:
			if String(s.type) == "stairs" and int(s.get("structure", -1)) == sid and f >= int(s.from_floor) and f <= int(s.to_floor):
				m.entrances.append({"floor": f, "pos": s.pos, "main": false, "kind": "spawn", "arrival": "stairs", "exit": false, "structure": sid})
