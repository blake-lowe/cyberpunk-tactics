extends TestCase
## Storeys below the street (TacMap.basements, BasementGen): Fort Sumter's members-only basement and
## sub-basement, Eurasiabank's drowned bank levels, the Combat Zone's guard tunnels. Street level is
## floor m.street; stairs, nav, sight, posts, objectives, bystanders and the HUD all follow it. Maps
## without basements must come out exactly as before (golden to_dict hashes taken before the change).

const SEEDS := [11, 2024, 77031, 5]
const DEEP := ["fort_sumter", "eurasiabank_plaza"]
static var _cache: Dictionary = {}

## sha256 of JSON.stringify(SceneGen.generate(seed, scene, overrides).to_dict()), captured on main
## before below-grade storeys existed. Scenes built from DistrictGen are left out (other work tunes
## district profiles), as are the three set pieces that now dig down.
const GOLDEN := {
	"arcology/6/": "19698c6c68dc271212904d6b0b0af700ecae2365629f6ba8a4042638447be298",
	"badlands/9/": "f204d14c1f8c24a162d960e17caa877b287e47ea22795d4609b16b2927130f74",
	"corp_campus/12/": "1e4b86bf9729842deabb18cd4e47cc68b293b19c82bbe3164071bb1a4bd63040",
	"lone_building/11/": "562f89e01e193064789db2fac9d1c3291a13fbe1ea7305bb80bf723d09365343",
	"lone_building/11/main_port": "6d14f9dad6364149d816a2128a0753e923f2b711a62f05f5c503a9537adffdbf",
	"lone_building/11/norcal_potentilla": "f3925d66689ccc6d78c7b4d59c6a82a5ed655029041a8f5a9b6dac1782e38339",
	"lone_building/11/trauma_team_tower": "fce099a85f43b5befdffa5ec6fdcb72683091826180f3dda8c2d2f1c667d11bb",
	"lone_building/11/ziggurat_hq": "be2ff245c5311a14834edcc260fe0e82d0d89443aae2c6dd74bf32aba3cfeb0c",
	"lone_building/2024/": "5658f12063c83286188985e7d999210f914c0f9f59debec1b3b86e683ed7dea1",
	"lone_building/2024/maxtac_hq": "01a2a054829f933197c6bed49e9f94645c73a17df37bd8d932eec0e7ffa8ad4e",
	"lone_building/2024/totentanz": "a22fdc11b88f7c6740bdb134e6f44738fe3d144ffc1076c47951007543752a66",
	"lone_building/77031/the_estates": "a4a873bd0d49dd9f601e158cb270ba4003a2fdc6832dc2a7d1ed26092c7fff6e",
	"megablock/5/": "705303ddd9affaaf15b2211f51ca3264029c04bcb4ac0f5268097368d9030228",
	"rail_yard/4/": "5ac31e4206140da6a03f0796279f0fbb191b4b911c4c45cca4b5fe7347610611",
	"shipyard/3/": "d8c318d1ea6adbe6076160061e44fca7e6853d468fc59b6f05f50a89a9f8e916",
	"skirmish/7/": "b801f36ee25d4f2dd4379c94054284663c7a70abedc4b3738c95f2bc48e18149",
	"undercity/8/": "295e8d5c20ebac3249dd74516bf95740d470b33368ad4345aadc99140212ee10",
}


func _map(id: String, s: int) -> TacMap:
	var key := "%s/%d" % [id, s]
	if not _cache.has(key):
		_cache[key] = SceneGen.generate(s, "lone_building", {"setpiece": id})
	return _cache[key]


func _deploy(m: TacMap) -> Vector3i:
	for e in m.entrances:
		if e.kind == "deploy":
			return Vector3i(e.pos.x, e.pos.y, int(e.floor))
	return Vector3i(-1, -1, -1)


func _crew(dice: Dice) -> Array[Combatant]:
	var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch")]
	return crew


func _part(m: TacMap, part: String) -> Dictionary:
	for st in m.structures:
		if String(st.get("part", "")) == part:
			return st
	return {}


func test_maps_without_basements_are_byte_identical() -> void:
	for key in GOLDEN:
		var k := String(key).split("/")
		var o := {"setpiece": k[2]} if k[2] != "" else {}
		var m := SceneGen.generate(int(k[1]), k[0], o)
		assert_eq(m.basements, 0, "%s: no basements" % key)
		assert_eq(m.street, 0, "%s: street level is floor 0" % key)
		assert_eq(JSON.stringify(m.to_dict()).sha256_text(), GOLDEN[key], "%s: to_dict unchanged" % key)


func test_floor_names_and_hud_label() -> void:
	var m := TacMap.new(4, 4, 4)
	assert_eq(m.floor_name(0), "1", "no basements: floor 0 is the first floor")
	m.lift(2)
	assert_eq(m.floors, 6, "two storeys added under")
	assert_eq(m.street, 2, "street level moves up")
	assert_eq([m.floor_name(0), m.floor_name(1), m.floor_name(2), m.floor_name(3)], ["B2", "B1", "1", "2"], "B2, B1, then 1 up")
	assert_eq(m.level(0), -2, "storey of the deepest floor")
	var gb: GDScript = load("res://src/tactical/greybox.gd")
	assert_eq(gb.floor_label(TacMap.new(4, 4, 4), 0), "FLOOR 1", "plain, no counter (owner): the street floor")
	assert_eq(gb.floor_label(TacMap.new(4, 4, 4), 1), "FLOOR 2", "the next one up")
	assert_eq(gb.floor_label(m, 0), "FLOOR B2", "the deepest basement")
	assert_eq(gb.floor_label(m, 1), "FLOOR B1", "a basement reads B1")
	assert_eq(gb.floor_label(m, 2), "FLOOR 1", "street level reads 1")
	assert_eq(gb.floor_label(m, 3), "FLOOR 2", "and up from there")
	assert_true(m.to_dict().get("basements", 0) == 2, "to_dict carries the count")
	assert_false(TacMap.new(4, 4, 1).to_dict().has("basements"), "a map without basements leaves the key out")


func test_lift_moves_every_floor_reference() -> void:
	var m := TacMap.new(6, 6, 2)
	m.set_t(0, 1, 1, TacMap.T.STAIRS)
	m.set_t(1, 1, 1, TacMap.T.STAIRS)
	m.verticals.append({"type": "stairs", "pos": Vector2i(1, 1), "from_floor": 0, "to_floor": 1})
	m.connectors.append({"type": "ladder", "a": Vector3i(3, 3, 0), "b": Vector3i(3, 3, 1)})
	m.add_cover({"floor": 0, "pos": Vector2i(2, 2), "kind": "crate", "hp": 5})
	m.rooms.append({"id": 0, "floor": 1, "cells": 1})
	m.lift(1)
	assert_eq(m.t(1, 1, 1), TacMap.T.STAIRS, "tiles move up")
	assert_eq(m.t(0, 1, 1), TacMap.T.VOID, "the new storey starts empty")
	assert_eq([m.verticals[0].from_floor, m.verticals[0].to_floor], [1, 2], "shafts move up")
	assert_eq(m.connectors[0].b, Vector3i(3, 3, 2), "connectors move up")
	assert_true(m.has_cover_at(1, Vector2i(2, 2)) and not m.has_cover_at(0, Vector2i(2, 2)), "the cover index follows")
	assert_eq(m.rooms[0].floor, 2, "rooms move up")


func test_basements_are_built_stairs_reach_them_and_nav_walks_down() -> void:
	for id in DEEP:
		for s in SEEDS:
			var m := _map(id, s)
			var tag := "%s seed %d" % [id, s]
			var main := _part(m, "main")
			assert_eq(m.basements, 2, "%s: two storeys below the street" % tag)
			assert_eq(int(main.get("basements", 0)), 2, "%s: under the main building" % tag)
			var down := m.verticals.filter(func(v): return int(v.structure) == int(main.id) and int(v.from_floor) == 0 and int(v.to_floor) >= m.street)
			assert_true(not down.is_empty(), "%s: a stair from B2 to the street" % tag)
			for v in down:
				for f in range(v.from_floor, m.street + 1):
					assert_eq(m.t(f, v.pos.x, v.pos.y), TacMap.T.STAIRS, "%s: stair square on floor %d" % [tag, f])
			var nav := Nav.new(m)
			nav.locked.clear()   # security doors are hacked or breached in play: this is about the stairs
			var d := _deploy(m)
			assert_eq(d.z, m.street, "%s: the crew goes in at street level" % tag)
			var field := nav.distance_field([d], {}, 5000)
			for f in m.basements:
				var rooms := m.rooms.filter(func(r): return r.cells > 0 and int(r.floor) == f)
				assert_true(rooms.size() >= 5, "%s: B%d has rooms (%d)" % [tag, m.basements - f, rooms.size()])
				for r in rooms:
					assert_eq(int(r.structure), int(main.id), "%s: basement rooms belong to the building" % tag)
					assert_false(r.get("outdoor", false), "%s: no outdoor room below grade" % tag)
					var any := Furnish.room_cells(m, r).any(func(c): return field.has(Vector3i(c.x, c.y, f)))
					assert_true(any, "%s: %s on B%d walkable from the deploy zone" % [tag, r.kind, m.basements - f])


func test_outdoor_ground_only_at_street_level() -> void:
	for id in DEEP + ["combat_zone"]:
		var m := _map(id, SEEDS[0])
		for f in m.floors:
			for y in m.h:
				for x in m.w:
					if f != m.street:
						assert_true(m.t(f, x, y) != TacMap.T.OUTSIDE, "%s: OUTSIDE only on the street floor (%d at %d,%d)" % [id, f, x, y])
					var l := m.label(f, x, y)
					if l >= 0 and m.rooms[l].get("outdoor", false):
						assert_true(f >= m.street, "%s: outdoor room %s above ground" % [id, m.rooms[l].kind])
		for e in m.entrances:
			assert_eq(int(e.floor), m.street, "%s: %s entrance at street level" % [id, e.kind])


func test_sight_in_a_basement() -> void:
	var m := _map("fort_sumter", SEEDS[0])
	var los := Los.new(m)
	var vis := Vision.new(m, los)
	for f in m.basements:
		for y in m.h:
			for x in m.w:
				if m.t(f, x, y) != TacMap.T.VOID:
					assert_false(vis.explored.has(Vector3i(x, y, f)), "basement squares start unknown")
	var gr: Dictionary = m.rooms.filter(func(r): return r.cells > 0 and r.kind == "gun_range")[0]
	var cells := Furnish.room_cells(m, gr).filter(func(c): return m.walkable(gr.floor, c))
	var a := Vector3i(cells[0].x, cells[0].y, gr.floor)
	vis.update([a])
	var seen := cells.filter(func(c): return vis.visible.has(Vector3i(c.x, c.y, gr.floor))).size()
	assert_true(seen * 2 > cells.size(), "standing in the gun range you see most of it (%d/%d)" % [seen, cells.size()])
	assert_false(vis.visible.has(Vector3i(a.x, a.y, m.street)), "not the floor above")


func test_posts_and_guards_below_ground() -> void:
	for id in DEEP:
		for s in SEEDS:
			var m := _map(id, s)
			var tag := "%s seed %d" % [id, s]
			var below := m.posts.filter(func(p): return int(p.floor) < m.street)
			assert_true(not below.is_empty(), "%s: guard posts below ground" % tag)
			for p in below:
				assert_true(m.walkable(int(p.floor), p.pos), "%s: post %s stands on floor" % [tag, p.kind])
	var m2 := _map("fort_sumter", SEEDS[0])
	var kinds := m2.posts.filter(func(p): return int(p.floor) < m2.street).map(func(p): return String(p.kind))
	assert_true("door_guard" in kinds and "armory" in kinds, "Fort Sumter: the security office (manned first) and armory are posts (%s)" % [kinds])
	var guarded := 0
	for s in SEEDS:
		var m := _map("fort_sumter", s)
		var dice := Dice.new(s)
		var e := Encounter.setup(m, dice, _crew(dice), "eliminate", {"faction": "deadwoods"})
		if e.units.any(func(u): return e.is_guard(u) and u.pos.z < m.street):
			guarded += 1
	assert_true(guarded > 0, "Fort Sumter: guards down in the basement on some seed (%d)" % guarded)


func test_objectives_anchor_in_basement_rooms() -> void:
	# Fort Sumter's armory (snatch) and Eurasiabank's vaults (rescue, snatch) are below ground.
	var cases := [["fort_sumter", "snatch", ["armory"]], ["eurasiabank_plaza", "snatch", ["bank_vault", "counting_room"]],
		["eurasiabank_plaza", "rescue", ["bank_vault", "storage"]]]
	for cs in cases:
		for s in SEEDS:
			var m := SceneGen.generate(s, "lone_building", {"setpiece": cs[0]})
			var dice := Dice.new(s + 3)
			var e := Encounter.setup(m, dice, _crew(dice), String(cs[1]), {"faction": String(SetPieces.get_def(cs[0]).faction)})
			var tag := "%s/%s seed %d" % [cs[0], cs[1], s]
			var cell: Vector3i = e.units[int(e.objective.captive)].pos if cs[1] == "rescue" else e.objective.cell
			var l := m.label(cell.z, cell.x, cell.y)
			assert_true(l >= 0 and String(m.rooms[l].kind) in cs[2], "%s: in a %s (%s)" % [tag, cs[2], m.rooms[l].kind if l >= 0 else "-"])
			assert_true(cell.z < m.street or String(m.rooms[l].kind) == "storage", "%s: below ground (floor %d)" % [tag, cell.z])
			var field := e.nav.distance_field([_deploy(m)], {}, 5000)
			var near := MapGen.DIRS.any(func(d): return field.has(cell + Vector3i(d.x, d.y, 0))) or field.has(cell)
			assert_true(near, "%s: reachable from the deploy zone" % tag)
			e.next_turn()
			assert_eq(e.state, "playing", "%s: playable" % tag)


func test_bystanders_only_in_public_street_level_rooms() -> void:
	for s in SEEDS:
		var m := _map("fort_sumter", s)
		var dice := Dice.new(s)
		var e := Encounter.setup(m, dice, _crew(dice), "eliminate", {"faction": "deadwoods"})
		var civs := e.units.filter(func(u): return u.get("civ", false))
		assert_true(not civs.is_empty(), "seed %d: Fort Sumter has its petitioners" % s)
		for u in civs:
			assert_eq(u.pos.z, m.street, "seed %d: bystanders at street level" % s)
			var l := m.label(u.pos.z, u.pos.x, u.pos.y)
			if l >= 0:
				assert_true(int(m.rooms[l].zone) <= TacMap.Zone.PUBLIC, "seed %d: in a public room (%s)" % [s, m.rooms[l].kind])


func test_eurasiabank_is_partly_flooded_deepest() -> void:
	for s in SEEDS:
		var m := _map("eurasiabank_plaza", s)
		var tag := "seed %d" % s
		var wet := []
		for f in m.basements:
			var n := 0
			for y in m.h:
				for x in m.w:
					if m.t(f, x, y) == TacMap.T.WATER:
						n += 1
						for d in MapGen.DIRS:
							assert_false(m.t(f, x + d.x, y + d.y) in [TacMap.T.DOOR, TacMap.T.STAIRS], "%s: doorways and stairs stay dry" % tag)
			wet.append(n)
		assert_true(wet[0] > wet[1] and wet[1] > 0, "%s: B2 wetter than B1, both flooded (%s)" % [tag, wet])
		for y in m.h:
			for x in m.w:
				assert_true(m.t(m.street, x, y) != TacMap.T.WATER or m.label(m.street, x, y) < 0, "%s: no flooding at street level" % tag)
		var vault_floors := m.rooms.filter(func(r): return r.cells > 0 and r.kind == "bank_vault").map(func(r): return int(r.floor))
		assert_true(not vault_floors.is_empty() and vault_floors.all(func(f): return f == 0), "%s: the vaults are deepest (%s)" % [tag, vault_floors])
		for r in m.rooms:
			if r.cells > 0 and int(r.floor) < m.street:
				var dry := Furnish.room_cells(m, r).filter(func(c): return m.t(r.floor, c.x, c.y) != TacMap.T.WATER).size()
				assert_true(dry * 2 >= r.cells, "%s: %s keeps half its floor dry" % [tag, r.kind])
		var hall: Array = m.rooms.filter(func(r): return r.cells > 0 and r.kind == "banking_hall")
		assert_true(not hall.is_empty() and int(hall[0].floor) == m.street - 1, "%s: the banking hall sank to B1" % tag)


func test_combat_zone_tunnels_link_the_hatches() -> void:
	for s in SEEDS:
		var m := _map("combat_zone", s)
		var tag := "seed %d" % s
		assert_eq(m.basements, 1, "%s: one storey of tunnels" % tag)
		var hatches := m.entrances.filter(func(e): return e.kind == "tunnel")
		var ladders := m.connectors.filter(func(c): return c.type == "hatch")
		assert_eq(ladders.size(), hatches.size(), "%s: a ladder down every hatch" % tag)
		var tunnels := m.rooms.filter(func(r): return r.cells > 0 and r.kind == "tunnel")
		assert_eq(tunnels.size(), 1, "%s: one tunnel system" % tag)
		var nav := Nav.new(m)
		var field := nav.distance_field([_deploy(m)], {}, 8000)
		for c in ladders:
			assert_eq(int(c.b.z), m.street, "%s: the hatch is in the street" % tag)
			assert_true(field.has(c.a), "%s: the tunnel under hatch %s is reachable" % [tag, c.a])
		for v in Furnish.room_cells(m, tunnels[0]):
			assert_true(field.has(Vector3i(v.x, v.y, 0)), "%s: every tunnel square joins up" % tag)
		var posts := m.posts.filter(func(p): return int(p.floor) == 0)
		assert_true(posts.size() >= 1, "%s: guards posted in the tunnels" % tag)


## AV landings shy from squares a second storey hides from the camera: the storey above the
## street (m.street + 1), not absolute floor 1, which on the Combat Zone is the street itself.
func test_av_hidden_reads_the_storey_above_the_street() -> void:
	var m := _map("combat_zone", SEEDS[0])
	var dice := Dice.new(9)
	var e := Encounter.setup(m, dice, _crew(dice), "rescue", {"faction": "network_54"})
	var up := m.street + 1
	var structural := [TacMap.T.FLOOR, TacMap.T.WALL, TacMap.T.DOOR, TacMap.T.STAIRS]
	var low := 0   # squares where only a street-level building lies toward the camera
	for y in range(0, m.h, 2):
		for x in range(0, m.w, 2):
			var street_only := false
			var upper := false
			for k in range(2, 9):
				for c in [Vector2i(x + k, y + k), Vector2i(x + k, y + k / 2), Vector2i(x + k / 2, y + k)]:
					if not m.inb(c.x, c.y):
						continue
					if m.t(up, c.x, c.y) in structural:
						upper = true
					elif m.t(m.street, c.x, c.y) in structural:
						street_only = true
			if street_only and not upper:
				low += 1
				assert_false(e._av_hidden(x, y), "(%d,%d): a street-level building alone doesn't hide a landing" % [x, y])
			elif upper:
				assert_true(e._av_hidden(x, y), "(%d,%d): a storey above the street does" % [x, y])
	assert_true(low > 50, "plenty of squares with only street-level buildings toward the camera (%d)" % low)


## A stair shaft whose rooms BuildingGen sealed off (no door reached them) goes with them: the
## Combat Zone's seed 3 once kept a squat's shaft that was wall on both floors it linked.
func test_no_shaft_runs_through_solid_wall() -> void:
	for s in [3] + SEEDS:
		var m := _map("combat_zone", s)
		for v in m.verticals:
			for f in range(int(v.from_floor), int(v.to_floor) + 1):
				assert_true(m.t(f, v.pos.x, v.pos.y) in [TacMap.T.STAIRS, TacMap.T.ELEVATOR], "seed %d: %s at %s open on floor %d" % [s, v.type, v.pos, f])


## The view's fire escapes climb from the street (floor m.street), not absolute floor 0.
func test_fire_escapes_climb_from_the_street() -> void:
	var m := _map("combat_zone", SEEDS[0])
	var los := Los.new(m)
	var wb := WorldBuilder.new(m, Vision.new(m, los), null)
	var root := Node3D.new()
	wb.build(root)
	assert_true(wb._escapes.size() >= 3, "the set's tenements keep their fire escapes (%d)" % wb._escapes.size())
	root.free()


## Ambient embers drift over the street, not inside the earth round the tunnels.
func test_embers_rise_from_the_street() -> void:
	var m := _map("combat_zone", SEEDS[0])
	var fx := AmbientFx.new()
	fx.build(m, ["embers"], m.seed_value)
	var p := fx.get_child(0) as CPUParticles3D
	assert_true(p != null, "an ember emitter")
	var gy := m.street * WorldBuilder.FH
	assert_near(p.position.y - p.emission_box_extents.y, gy, 0.001, "the emission box sits on the street")
	fx.free()

