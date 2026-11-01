class_name TacMap
extends RefCounted
## Generated tactical map: a stack of floors on a square grid (1 square = 2 m, p126).
## Pure data — the 3D scene is built from this in M3, the debug viewer reads to_dict().

enum T { VOID, FLOOR, WALL, DOOR, STAIRS, ELEVATOR, OUTSIDE, WATER }

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
var verticals: Array[Dictionary] = []       ## {type, pos, from_floor, to_floor}
var architecture: NetArchitecture = null    ## the target structure's NET (convenience)

## Wall materials. fence: see-through, flimsy. rock: natural outcrop. Cover HP per material is
## resolved in M3 from the book's cover table (fence ≈ thin wood, rock ≈ thick stone).
const WALL_MATERIALS := ["plaster", "concrete", "steel", "fence", "rock"]


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
	return v in [T.FLOOR, T.DOOR, T.STAIRS, T.ELEVATOR, T.OUTSIDE]


var _cover_index := {}  ## Vector3i(x, y, floor) → index in `cover`


func add_cover(c: Dictionary) -> void:
	_cover_index[Vector3i(c.pos.x, c.pos.y, c.floor)] = cover.size()
	cover.append(c)


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
		for n in nexts:
			if seen.has(n) or blocked.has(n) or not walkable_tile(t(n.z, n.x, n.y)):
				continue
			seen[n] = true
			q.append(n)
	return seen


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
				elif e[k] is Rect2i:
					e[k] = [e[k].position.x, e[k].position.y, e[k].size.x, e[k].size.y]
			out.append(e)
		return out
	return {
		"w": w, "h": h, "floors": floors, "seed": seed_value, "algorithm": algorithm, "params": params,
		"floor_data": fl, "rooms": conv.call(rooms), "doors": conv.call(doors), "cover": conv.call(cover),
		"devices": conv.call(devices), "entrances": conv.call(entrances), "verticals": conv.call(verticals),
		"architecture": architecture.to_dict() if architecture else {},
		"architectures": archs, "ground": Array(ground), "structures": conv.call(structures),
	}
