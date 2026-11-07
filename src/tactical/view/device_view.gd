class_name DeviceView
extends Node3D
## Meatspace devices drawn in the world (they used to exist only in the NET overlay): terminals and
## jack points (Quaternius sci-fi kit models with a cyan screen), cameras on their mounts with a red
## eye (green once the crew holds them), door keypads beside security doors (red locked, green open),
## turrets, data cores, junction boxes. Status lights update with the encounter; jack points the
## crew can use pulse cyan. Built once per map; `refresh` restyles the lights.

const KITS := "res://assets/third_party/quaternius/scifi/models/%s.gltf"
const KIT := 0.6
const RED := Color("ff2a4a")
const GREEN := Color("3cf08c")
const CYAN := Color("39d8ff")
const AMBER := Color("ffb02e")

var _scenes := {}
var _lights := {}   ## device id → [MeshInstance3D led, OmniLight3D or null, kind]
var _jack := {}     ## device id → true: NET access points


func build(m: TacMap, gy: Callable) -> void:
	for ch in get_children():
		ch.queue_free()
	_lights.clear()
	_jack.clear()
	for sid in m.architectures:
		for ap in (m.architectures[sid] as NetArchitecture).access_points:
			_jack[int(ap.device)] = true
	for d in m.devices:
		var cell := Vector3i(d.pos.x, d.pos.y, d.floor)
		var base: Vector3 = Vector3(d.pos.x + 0.5, gy.call(cell), d.pos.y + 0.5)
		var face := _wall_dir(m, cell)   # out of the wall the device hangs on
		var yaw := atan2(face.x, face.y)
		var root := Node3D.new()
		root.position = base
		root.rotation.y = yaw
		root.set_meta("floor", int(d.floor))   # the greybox hides storeys above a basement view
		root.set_meta("cell", cell)   # and kit the crew hasn't seen yet
		add_child(root)
		var back := -0.42   # against the wall
		match String(d.type):
			"terminal", "med_scanner", "bd_rig", "ship_controls", "crane_controls", "engine_controls", "plant_controls", "gate_controls", "cooling_controls":
				_kit(root, "Prop_Computer", Vector3(0, 0, back + 0.12), 0.55)
				_led(d.id, root, Vector3(0, 0.62, back + 0.27), Vector3(0.22, 0.14, 0.01), CYAN, 2.2, "screen")
			"data_core", "junction":
				_kit(root, "Prop_AccessPoint", Vector3(0, -0.66 * KIT * 0.0, back + 0.12), 0.75)
				_led(d.id, root, Vector3(0, 0.75, back + 0.27), Vector3(0.18, 0.05, 0.01), CYAN, 2.6, "screen")
			"camera":
				var arm := _box(root, Vector3(0.04, 0.04, 0.18), Vector3(0, 1.32, back + 0.09), Color("2a2f3a"))
				arm.name = "arm"
				_box(root, Vector3(0.14, 0.1, 0.2), Vector3(0, 1.26, back + 0.22), Color("3a4250"))
				_led(d.id, root, Vector3(0, 1.31, back + 0.33), Vector3(0.05, 0.05, 0.01), RED, 3.0, "eye")
			"door_lock":
				_box(root, Vector3(0.12, 0.18, 0.03), Vector3(0.38, 0.62, 0.0), Color("1e232c"))
				_led(d.id, root, Vector3(0.38, 0.66, 0.02), Vector3(0.07, 0.07, 0.01), RED, 2.6, "lock")
			"turret":
				_box(root, Vector3(0.3, 0.12, 0.3), Vector3(0, 0, 0), Color("2a2f3a"))
				_box(root, Vector3(0.16, 0.16, 0.36), Vector3(0, 0.12, 0.05), Color("4a5262"))
				_box(root, Vector3(0.04, 0.04, 0.3), Vector3(0, 0.2, 0.3), Color("15181e"))
				_led(d.id, root, Vector3(0, 0.3, 0.12), Vector3(0.05, 0.03, 0.05), RED, 3.0, "eye")
			"alarm_panel", "sprinkler_valve", "shutter_control", "cell_locks", "light_rig", "floodlight", "assembly_line", "vault_lock", "pa_system":
				_box(root, Vector3(0.26, 0.32, 0.05), Vector3(0, 0.55, back + 0.03), Color("2a303c"))
				_led(d.id, root, Vector3(0, 0.62, back + 0.06), Vector3(0.12, 0.05, 0.01), AMBER, 2.0, "panel")
			_:
				pass
		if _jack.has(d.id):   # a jack point gets a faint cyan floor ring so the netrunner can find it
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.26
			tm.outer_radius = 0.3
			ring.mesh = tm
			var rm := StandardMaterial3D.new()
			rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			rm.albedo_color = Color(CYAN, 0.55)
			rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			ring.material_override = rm
			ring.position = base + Vector3(face.x, 0, face.y) * 0.15 + Vector3(0, 0.03, 0)
			ring.scale = Vector3(1, 0.15, 1)
			ring.name = "ring_%d" % d.id
			ring.set_meta("floor", int(d.floor))
			ring.set_meta("cell", cell)
			add_child(ring)


## Restyle status lights: held (controlled) devices go green, unlocked doors green.
func refresh(enc: Encounter) -> void:
	for id in _lights:
		var e: Array = _lights[id]
		var mi: MeshInstance3D = e[0]
		var off: bool = enc.disabled_devices.has(id)
		var col: Color = e[2]
		if String(e[3]) in ["eye", "lock"]:
			col = GREEN if off else RED
		elif off:
			col = GREEN
		(mi.material_override as StandardMaterial3D).albedo_color = col
		(mi.material_override as StandardMaterial3D).emission = col


func _process(_d: float) -> void:   # jack-point rings breathe
	var t := Time.get_ticks_msec() / 1000.0
	for ch in get_children():
		if ch.name.begins_with("ring_"):
			var a := 0.35 + 0.25 * sin(t * 2.4)
			((ch as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color(CYAN, a)


func _led(id: int, parent: Node3D, pos: Vector3, size: Vector3, col: Color, glow: float, kind: String) -> void:
	var mi := _box(parent, size, pos, col)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = glow
	mi.material_override = m
	_lights[id] = [mi, null, col, kind]


func _box(parent: Node3D, size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.6
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _kit(parent: Node3D, name: String, pos: Vector3, scl: float) -> void:
	if not _scenes.has(name):
		_scenes[name] = load(KITS % name)
	var n: Node3D = (_scenes[name] as PackedScene).instantiate()
	n.position = pos
	n.scale = Vector3.ONE * KIT * scl
	parent.add_child(n)


## The direction from the wall a device sits against into the room (z-forward in local space).
static func _wall_dir(m: TacMap, c: Vector3i) -> Vector2:
	for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]:
		if m.inb(c.x + d.x, c.y + d.y) and m.t(c.z, c.x + d.x, c.y + d.y) == TacMap.T.WALL:
			return Vector2(-d.x, -d.y)
	return Vector2(0, 1)
