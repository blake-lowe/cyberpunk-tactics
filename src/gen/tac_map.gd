class_name TacMap
extends RefCounted
## Generated tactical map: a stack of floors on a square grid (1 square = 2 m, p126).
## Pure data — the 3D scene is built from this in M3, the debug viewer reads to_dict().

enum T { VOID, FLOOR, WALL, DOOR, STAIRS, ELEVATOR, OUTSIDE, WATER, ROOF, BRIDGE }

## Outdoor ground (floor 0 only), for movement flavour and the viewer.
enum G { NONE, ASPHALT, SIDEWALK, GRAVEL, DIRT, CONCRETE, RAIL, DOCK, GRASS, SAND }

## Security zones, from the street inwards. Net Architecture depth follows these.
enum Zone { STREET, PUBLIC, STAFF, SECURE, VAULT }
const ZONE_NAMES := ["street", "public", "staff", "secure", "vault"]

var w: int
var h: int
var floors: int
var seed_value: int
var algorithm: String
var params: Dictionary
var tiles: Array[PackedByteArray] = []      ## per floor, T per cell
var labels: Array[PackedInt32Array] = []    ## per floor, room id per cell (-1 none)
var wall_mat: Array[PackedByteArray] = []   ## per floor, index into WALL_MATERIALS for wall cells
var ground := PackedByteArray()             ## floor 0, G per cell
var structures: Array[Dictionary] = []      ## {id, kind, site, rect, floors, security, target, base_zone}
var architectures: Dictionary = {}          ## structure id → NetArchitecture
var rooms: Array[Dictionary] = []           ## {id, floor, zone, kind, cells, bounds, structure}
var doors: Array[Dictionary] = []           ## {floor, pos, a, b, security: bool}
var cover: Array[Dictionary] = []           ## {floor, pos, kind, material, thick, hp}
var devices: Array[Dictionary] = []         ## {id, type, floor, pos, room, zone, group}
var entrances: Array[Dictionary] = []       ## {floor, pos, main: bool}
var verticals: Array[Dictionary] = []       ## {type, pos, from_floor, to_floor}: shafts at one x,y
var connectors: Array[Dictionary] = []      ## {type, a: Vector3i, b: Vector3i}: ladders, fire escapes
var net_links: Array[Dictionary] = []       ## {a, a_node (socket), b, b_node}: sockets between structure NETs
var posts: Array[Dictionary] = []           ## {floor, pos, structure, zone, kind}: guard positions
var architecture: NetArchitecture = null    ## the target structure's NET (convenience)

## Wall materials. fence: see-through, flimsy. rock: natural outcrop. Cover HP per material is
## resolved in M3 from the book's cover table (fence ≈ thin wood, rock ≈ thick stone).
const WALL_MATERIALS := ["plaster", "concrete", "steel", "fence", "rock", "glass", "armor_glass"]

## Walls and doors as cover, per the book's cover table (p182) and its examples (p183):
## office wall = thick plaster 15, exterior = thick concrete 25, vault = thick steel 50,
## rock outcrop ≈ boulder (thick stone 40), wooden door = thin wood 5, metal (security) door 20.
## Fences stop movement but not bullets: no cover, line of sight passes (like the book's cubicle).
## Windows: ordinary glass is no cover and see-through (book: windshield 0); bulletproof glass is
## thin bulletproof glass (15) and see-through.
const WALL_COVER := {0: ["plaster", true], 1: ["concrete", true], 2: ["steel", true], 3: [], 4: ["stone", true],
	5: [], 6: ["bulletproof_glass", false]}
const SEE_THROUGH := [3, 5, 6]
const DOOR_HP := 5
const SECURITY_DOOR_HP := 20  # p183 "metal door" example


func _init(p_w: int = 0, p_h: int = 0, p_floors: int = 1) -> void:
	w = p_w
	h = p_h
	floors = p_floors
	for f in floors:
		var t := PackedByteArray()
		t.resize(w * h)
		t.fill(T.VOID)
		tiles.append(t)
		var l := PackedInt32Array()
		l.resize(w * h)
		l.fill(-1)
		labels.append(l)
		var m := PackedByteArray()
		m.resize(w * h)
		wall_mat.append(m)
	ground.resize(w * h)


func inb(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h


func t(f: int, x: int, y: int) -> int:
	return tiles[f][y * w + x] if inb(x, y) else T.VOID


func set_t(f: int, x: int, y: int, v: int) -> void:
	tiles[f][y * w + x] = v


func set_ground(x: int, y: int, g: int) -> void:
	ground[y * w + x] = g


func label(f: int, x: int, y: int) -> int:
	return labels[f][y * w + x] if inb(x, y) else -1


func walkable_tile(v: int) -> bool:
	return v in [T.FLOOR, T.DOOR, T.STAIRS, T.ELEVATOR, T.OUTSIDE, T.ROOF, T.BRIDGE]


var _cover_index := {}  ## Vector3i(x, y, floor) → index in `cover`


func add_cover(c: Dictionary) -> void:
	_cover_index[Vector3i(c.pos.x, c.pos.y, c.floor)] = cover.size()
	cover.append(c)


## Destroyed cover stops blocking movement (it stays in `cover` with hp 0 as debris for the viewer).
func destroy_cover_at(f: int, p: Vector2i) -> void:
	var key := Vector3i(p.x, p.y, f)
	if _cover_index.has(key):
		cover[_cover_index[key]].hp = 0
		_cover_index.erase(key)


func pop_cover() -> void:
	var c: Dictionary = cover.pop_back()
	_cover_index.erase(Vector3i(c.pos.x, c.pos.y, c.floor))


func has_cover_at(f: int, p: Vector2i) -> bool:
	return _cover_index.has(Vector3i(p.x, p.y, f))


func walkable(f: int, p: Vector2i) -> bool:
	return walkable_tile(t(f, p.x, p.y)) and not has_cover_at(f, p)


func room(id: int) -> Dictionary:
	return rooms[id]


## Cells reachable from `start` (floor, pos) moving 4-way, using stairs/elevators between floors.
## Cover blocks movement. Returns a Dictionary keyed by Vector3i(x, y, floor).
func reachable(start: Vector3i) -> Dictionary:
	var blocked := _cover_index
	var links := {}
	for c in connectors:
		links.get_or_add(c.a, []).append(c.b)
		links.get_or_add(c.b, []).append(c.a)
	var seen := {start: true}
	var q: Array[Vector3i] = [start]
	while not q.is_empty():
		var p: Vector3i = q.pop_back()
		var nexts: Array[Vector3i] = []
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			nexts.append(Vector3i(p.x + d.x, p.y + d.y, p.z))
		if t(p.z, p.x, p.y) in [T.STAIRS, T.ELEVATOR]:
			for v in verticals:
				if v.pos == Vector2i(p.x, p.y) and p.z >= v.from_floor and p.z <= v.to_floor:
					for f in range(v.from_floor, v.to_floor + 1):
						nexts.append(Vector3i(p.x, p.y, f))
		nexts.append_array(links.get(p, []))
		for n in nexts:
			if seen.has(n) or blocked.has(n) or not walkable_tile(t(n.z, n.x, n.y)):
				continue
			seen[n] = true
			q.append(n)
	return seen


## Cells where a connector (ladder, fire escape) lands; furniture and props keep clear.
func is_connector_end(f: int, p: Vector2i) -> bool:
	var v := Vector3i(p.x, p.y, f)
	return connectors.any(func(c): return c.a == v or c.b == v)


## Cover properties of a wall or door cell: {cover, hp, material, blocks_los, blocks_move}.
## Open cells return {} (furniture/props are in `cover`).
func wall_cover(f: int, x: int, y: int) -> Dictionary:
	var v := t(f, x, y)
	if v == T.WALL:
		var mi := int(wall_mat[f][y * w + x])
		var spec: Array = WALL_COVER.get(mi, [])
		var los: bool = not mi in SEE_THROUGH
		if spec.is_empty():
			return {"cover": false, "hp": 0, "material": WALL_MATERIALS[mi], "blocks_los": los, "blocks_move": true}
		var hp := int(RulesDB.load_json("armor.json")["cover_hp"][spec[0]][0 if spec[1] else 1])
		return {"cover": true, "hp": hp, "material": spec[0], "blocks_los": los, "blocks_move": true}
	if v == T.DOOR:
		for d in doors:
			if d.floor == f and d.pos == Vector2i(x, y):
				var gate: bool = int(wall_mat[f][y * w + x]) == 3 or d.get("gate", false)
				if gate:
					return {"cover": false, "hp": 0, "material": "fence", "blocks_los": false, "blocks_move": false}
				return {"cover": true, "hp": SECURITY_DOOR_HP if d.security else DOOR_HP, "material": "steel" if d.security else "wood",
					"blocks_los": true, "blocks_move": false}
	return {}


func main_entrance() -> Dictionary:
	for e in entrances:
		if e.main:
			return e
	return {}


## Serializable snapshot for the debug viewer and save files.
func to_dict() -> Dictionary:
	var fl := []
	for f in floors:
		fl.append({"tiles": Array(tiles[f]), "labels": Array(labels[f]), "wall_mat": Array(wall_mat[f])})
	var archs := {}
	for sid in architectures:
		archs[str(sid)] = (architectures[sid] as NetArchitecture).to_dict()
	var conv := func(arr: Array) -> Array:
		var out := []
		for d in arr:
			var e: Dictionary = d.duplicate()
			for k in e:
				if e[k] is Vector2i:
					e[k] = [e[k].x, e[k].y]
				elif e[k] is Array and not e[k].is_empty() and e[k][0] is Vector2i:
					e[k] = e[k].map(func(v): return [v.x, v.y])
				elif e[k] is Rect2i:
					e[k] = [e[k].position.x, e[k].position.y, e[k].size.x, e[k].size.y]
			out.append(e)
		return out
	return {
		"w": w, "h": h, "floors": floors, "seed": seed_value, "algorithm": algorithm, "params": params,
		"floor_data": fl, "rooms": conv.call(rooms), "doors": conv.call(doors), "cover": conv.call(cover),
		"devices": conv.call(devices), "entrances": conv.call(entrances), "verticals": conv.call(verticals),
		"architecture": architecture.to_dict() if architecture else {},
		"architectures": archs, "ground": Array(ground), "structures": conv.call(structures), "net_links": net_links, "posts": conv.call(posts),
		"connectors": connectors.map(func(c): return {"type": c.type, "a": [c.a.x, c.a.y, c.a.z], "b": [c.b.x, c.b.y, c.b.z]}),
	}
