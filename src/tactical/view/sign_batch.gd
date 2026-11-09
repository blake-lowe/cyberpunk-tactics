class_name SignBatch
extends RefCounted
## Places library signs (SignLib) and draws them all in a few MultiMeshes: the lit tubes (one
## cylinder a stroke, neon_tube.gdshader), their glow (one quad a stroke, neon_halo.gdshader),
## the dark raceways and blade boards (boxes, in the tube shader, dead), the holo screens (quads,
## holo.gdshader with the text atlas). One batch per placement (place 0: street facades, which go
## with their walls in the cutaway; 1: over the city), so a map's whole sign library costs four
## draw calls a batch whatever it holds.
##
## Text reads from outside: a face's text runs along `right` = UP x out, the facing seen from the
## street (the owner caught crown text flipped once: test_sign_lib checks every face). `placed`
## keeps each sign's faces and letter positions for that test; `lights` the light each sign
## spills (WorldBuilder bakes them into the LightField).

const HOLO_SHADER := preload("res://src/tactical/view/holo.gdshader")
const TUBE_SHADER := preload("res://src/tactical/view/neon_tube.gdshader")
const HALO_SHADER := preload("res://src/tactical/view/neon_halo.gdshader")
const PLATE := Color("0c0d12")
const ENERGY := 2.3

var place := 0
## The thinnest tube (world units): a tube under a pixel of the low-res view drops out between
## frames, so street signs keep theirs at about two pixels at the game's zoom; close-up review
## sheets can go thinner.
var min_tube := 0.04
var tubes: Array = []    ## [Transform3D, Color, Color custom]
var halos: Array = []
var plates: Array = []   ## [Transform3D, Color]
var holos: Array = []    ## [Transform3D, Color, Color custom]
var placed: Array = []   ## {id, at, faces: [[normal, right]], letters: [[world centre, char]]}
var lights: Array = []   ## {at: Vector3, color, energy, range}


func _init(p_place := 0, p_min_tube := 0.04) -> void:
	place = p_place
	min_tube = p_min_tube


static func _col(e: Dictionary, i: int) -> Color:
	var cols: Array = e.get("colors", ["ff2a6d"])
	return Color(String(cols[mini(i, cols.size() - 1)]))


## The sign's size in world units fitted into max_w x max_h (neon: its layout's proportions).
static func fit(e: Dictionary, max_w: float, max_h: float) -> Vector2:
	if String(e.kind) == "holo":
		return Vector2(max_w, max_h)
	var s: Vector2 = SignLib.layout(e).size
	var u := minf(max_w / maxf(s.x, 0.1), max_h / maxf(s.y, 0.1))
	return s * u


## A sign flat on a wall: `at` the middle of its face (on the wall's surface), `out` the wall's
## outward normal. Fitted into max_w x max_h. Returns its record.
func wall(e: Dictionary, at: Vector3, out: Vector3, max_w: float, max_h: float, seed_value: int) -> Dictionary:
	out = out.normalized()
	var right := Vector3.UP.cross(out).normalized()
	var rec := {"id": String(e.id), "at": at, "out": out, "faces": [[out, right]], "letters": []}
	if String(e.kind) == "holo":
		var sz := Vector2(max_w, max_h)
		_holo(e, at + out * 0.02, right, out, sz, seed_value)
		rec["size"] = sz
	else:
		var lay := SignLib.layout(e)
		var s: Vector2 = lay.size
		var u := minf(max_w / maxf(s.x, 0.1), max_h / maxf(s.y, 0.1))
		var t := clampf(u * 0.5, min_tube, 0.1)
		var pad := u * 1.4
		var pt := 0.04 + t
		_box(at + out * (pt / 2.0), Basis(right, Vector3.UP, out), Vector3(s.x * u + pad * 2.0, s.y * u + pad * 2.0, pt))
		var origin := at + out * (pt + t * 0.6) - right * (s.x * u / 2.0) + Vector3.UP * (s.y * u / 2.0)
		_strokes(e, lay, origin, right, out, u, t, seed_value, rec)
		rec["size"] = s * u
	lights.append({"at": at + out * 0.6, "color": _col(e, 0), "energy": 0.9 if String(e.kind) == "neon" else 0.6, "range": 3.5})
	placed.append(rec)
	return rec


## A blade sign standing out from a wall: `at` where it meets the wall, `out` the wall's outward
## normal; its text runs down both faces, each read from its own side. The board's edge is lit.
func blade(e: Dictionary, at: Vector3, out: Vector3, max_w: float, max_h: float, seed_value: int) -> Dictionary:
	out = out.normalized()
	var side := Vector3.UP.cross(out).normalized()
	var lay := SignLib.layout(e) if String(e.form) == "blade" else SignLib.layout({"form": "blade", "text": e.get("text", "BAR"), "colors": e.colors})
	var s: Vector2 = lay.size
	var u := minf(max_w / maxf(s.x, 0.1), max_h / maxf(s.y, 0.1))
	var t := clampf(u * 0.5, min_tube, 0.1)
	var pad := u * 1.6
	var bw := s.x * u + pad * 2.0
	var bh := s.y * u + pad * 2.0
	var pt := 0.05
	var c := at + out * (bw / 2.0 + 0.04)
	_box(c, Basis(out, Vector3.UP, side), Vector3(bw, bh, pt))
	_box(at + out * 0.02 + Vector3.UP * (bh * 0.3), Basis(out, Vector3.UP, side), Vector3(0.08, 0.03, 0.03))   # brackets
	_box(at + out * 0.02 - Vector3.UP * (bh * 0.3), Basis(out, Vector3.UP, side), Vector3(0.08, 0.03, 0.03))
	var rec := {"id": String(e.id), "at": c, "out": out, "faces": [], "letters": [], "size": Vector2(bw, bh)}
	var edge := _col(e, 1)
	var cus_edge := Color(float(seed_value % 97) * 0.1, 0.0, 0.0, ENERGY * 0.8)
	# the lit rim along the board's outer edge and top and bottom
	var tip := c + out * (bw / 2.0)
	_seg(tip + Vector3.UP * bh / 2.0, tip - Vector3.UP * bh / 2.0, side, edge, cus_edge, t * 0.8)
	for sg in [-1.0, 1.0]:
		var y: Vector3 = Vector3.UP * (bh / 2.0) * sg
		_seg(c - out * (bw / 2.0) + y, tip + y, side, edge, cus_edge, t * 0.8)
	for n in [side, -side]:
		var right := Vector3.UP.cross(n).normalized()
		rec.faces.append([n, right])
		var origin: Vector3 = c + n * (pt / 2.0 + t * 0.6) - right * (s.x * u / 2.0) + Vector3.UP * (s.y * u / 2.0)
		_strokes(e, lay, origin, right, n, u, t, seed_value, rec)
	lights.append({"at": tip + out * 0.3, "color": _col(e, 0), "energy": 1.1, "range": 4.5})
	placed.append(rec)
	return rec


## A free-standing holo screen (rooftop billboards, the far city): centre, facing, size.
func screen(e: Dictionary, at: Vector3, out: Vector3, size: Vector2, seed_value: int, bright := 1.0) -> Dictionary:
	out = out.normalized()
	var right := Vector3.UP.cross(out).normalized()
	_holo(e, at, right, out, size, seed_value, bright)
	var rec := {"id": String(e.id), "at": at, "out": out, "faces": [[out, right]], "letters": [], "size": size}
	placed.append(rec)
	return rec


func _holo(e: Dictionary, at: Vector3, right: Vector3, out: Vector3, size: Vector2, seed_value: int, bright := 1.0) -> void:
	var xf := Transform3D(Basis(right * size.x, Vector3.UP * size.y, out), at)
	var cus := Color(SignLib.holo_seed(e, seed_value), float(SignLib.holo_kind(e)), bright, SignLib.holo_text(e))
	holos.append([xf, _col(e, 0), cus])


func _strokes(e: Dictionary, lay: Dictionary, origin: Vector3, right: Vector3, out: Vector3, u: float, t: float, seed_value: int, rec: Dictionary) -> void:
	var anims := SignLib.part_anims(e, int(lay.parts), seed_value)
	var to3 := func(p: Vector2) -> Vector3: return origin + right * (p.x * u) + Vector3.DOWN * (p.y * u)
	for sg in lay.segs:
		var part: int = sg[2]
		var cus := Color(fmod(float(seed_value) * 0.13 + part * 0.37, 1.0), float(anims[part] if part < anims.size() else 0), 0.0, ENERGY)
		_seg(to3.call(sg[0]), to3.call(sg[1]), out, _col(e, int(sg[3])), cus, t)
	for b in lay.bulbs:   # chasing bulbs: short, fat tubes in a running phase
		var p: Vector3 = to3.call(b[0])
		var cus2 := Color(float(b[1]) / float(b[2]), 4.0, 0.7, ENERGY * 1.1)
		_seg(p - right * t * 0.4, p + right * t * 0.4, out, _col(e, 0), cus2, t * 1.25)
	for l in lay.letters:
		rec.letters.append([to3.call(l[0]), String(l[1])])


## One tube from a to b (world), facing `out`, its glow round it.
func _seg(a: Vector3, b: Vector3, out: Vector3, col: Color, cus: Color, t: float) -> void:
	var d := b - a
	var ln := d.length()
	var dir := d / ln if ln > 0.0001 else Vector3.UP.cross(out).normalized()
	var x := dir.cross(out).normalized()
	var c := (a + b) / 2.0
	tubes.append([Transform3D(Basis(x * t, dir * (ln + t * 0.8), out * t), c), col, cus])
	var r := t * 2.4 + 0.012
	halos.append([Transform3D(Basis(dir * (ln + r * 2.0), -x * (r * 2.0), out), c - out * (t * 0.5)), col, cus])


func _box(c: Vector3, bs: Basis, size: Vector3) -> void:
	plates.append([Transform3D(bs.orthonormalized() * Basis.from_scale(size), c), PLATE])


## How many instances it holds.
func count() -> int:
	return tubes.size() + halos.size() + plates.size() + holos.size()


## The batch as MultiMesh nodes under `parent` (none for an empty part). `map_size` for the
## cutaway's lookups.
func flush(parent: Node3D, map_size: Vector2) -> Array:
	var out: Array = []
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.rings = 1
	var quad := QuadMesh.new()
	var box := BoxMesh.new()
	var dead := Color(0, 2, 0, 1)   # the plates: the tube shader's dead glass, near black
	for part in [[tubes, cyl, TUBE_SHADER, "tubes"], [halos, quad, HALO_SHADER, "glow"], [plates, box, TUBE_SHADER, "boards"], [holos, quad, HOLO_SHADER, "holo"]]:
		var items: Array = part[0]
		if items.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = part[1]
		mm.instance_count = items.size()
		for i in items.size():
			mm.set_instance_transform(i, items[i][0])
			mm.set_instance_color(i, items[i][1])
			mm.set_instance_custom_data(i, items[i][2] if items[i].size() > 2 else dead)
		var mt := ShaderMaterial.new()
		mt.shader = part[2]
		mt.set_shader_parameter("place", place)
		mt.set_shader_parameter("map_size", map_size)
		if part[2] == HOLO_SHADER:
			mt.set_shader_parameter("atlas", SignLib.atlas())
			mt.set_shader_parameter("pal", SignLib.palette())
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mt
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.name = "signs_%d_%s" % [place, part[3]]
		parent.add_child(mi)
		out.append(mi)
	return out
