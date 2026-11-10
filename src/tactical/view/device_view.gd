class_name DeviceView
extends Node3D
## Meatspace devices drawn in the world (they used to exist only in the NET overlay): terminals and
## jack points (Quaternius sci-fi kit models with a cyan screen), cameras on their mounts with a red
## eye, door keypads beside security doors (red locked, green open), turrets, data cores, junction
## boxes. Status lights update with the encounter; jack points the crew can use pulse cyan. A device
## a Netrunner holds through the NET (NetDevices) wears a small violet HELD diamond above its lamp
## and its lamp goes violet (a held turret; a held camera's eye stays red until it's looped); a looped camera's eye and a
## switched device's panel go green. Built once per map; `refresh` restyles the lights.

const KITS := "res://assets/third_party/quaternius/scifi/models/%s.gltf"
const KIT := 0.6
const RED := Color("ff2a4a")
const GREEN := Color("3cf08c")
const CYAN := Color("39d8ff")
const AMBER := Color("ffb02e")
const VIOLET := Color("d68cff")   ## held through the NET (the NET panel's HELD badge)

var _scenes := {}
var _lights := {}   ## device id → [MeshInstance3D led, OmniLight3D or null, colour, kind, cell, led position]
var _jack := {}     ## device id → true: NET access points
var _roots := {}    ## device id → its Node3D (the HELD badge hangs off it)
var _badges := {}   ## device id → the HELD diamond while a Netrunner holds it
var _types := {}    ## device id → device type
var ap_led := true ## access-point way-finding (owner: on; greybox --ap_led=0 turns it off): a slow-pulsing cyan port LED on each access point
var _ports: Array[MeshInstance3D] = []


func build(m: TacMap, gy: Callable) -> void:
	for ch in get_children():
		ch.queue_free()
	_lights.clear()
	_jack.clear()
	_roots.clear()
	_badges.clear()
	_types.clear()
	_ports.clear()
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
		_roots[int(d.id)] = root
		_types[int(d.id)] = String(d.type)
		var back := -0.42   # against the wall
		var port_at := Vector3(0, 0.44, back + 0.33)   # where an access point's port LED sits
		match String(d.type):
			"terminal", "med_scanner", "bd_rig", "ship_controls", "crane_controls", "engine_controls", "plant_controls", "gate_controls", "cooling_controls":
				if _jack.has(int(d.id)):
					port_at = _access_point_model(int(d.id), root, back)
				else:
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
		if ap_led and _jack.has(d.id):   # an access point's own port: a cyan socket LED that breathes slowly
			var port := _box(root, Vector3(0.24, 0.09, 0.05), port_at, CYAN)
			var pm := StandardMaterial3D.new()
			pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			pm.albedo_color = CYAN
			pm.emission_enabled = true
			pm.emission = CYAN
			pm.emission_energy_multiplier = 3.0
			port.material_override = pm
			port.name = "port_%d" % d.id
			_ports.append(port)
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


## Restyle status lights and the HELD badges. Door keypads: red while the door is locked, green
## open. Camera eyes: red live (held and feeding the crew too: the site still sees it until it's
## looped; owner, playtest v0.10.1), green looped or dead. Turret eyes:
## red, violet held. Panels and screens: their own colour, violet held, green switched (dark, cut,
## sealed, halted).
func refresh(enc: Encounter) -> void:
	var held := NetDevices.held_map(enc)
	for id in _lights:
		var e: Array = _lights[id]
		var mi: MeshInstance3D = e[0]
		var off: bool = enc.disabled_devices.has(id)
		var col: Color = e[2]
		var kind := String(e[3])
		var t := String(_types.get(id, ""))
		if kind == "lock":
			col = RED if enc.nav.locked.has(e[4]) else GREEN
		elif kind == "eye" and t == "camera":
			col = GREEN if off else RED   # the HELD badge says it's the runner's; the eye says the site still sees
		elif kind == "eye":
			col = VIOLET if held.has(id) else (GREEN if off else RED)
		elif held.has(id):
			col = GREEN if NetDevices.is_on(enc, enc.m.devices[id]) else VIOLET
		elif off:
			col = GREEN
		(mi.material_override as StandardMaterial3D).albedo_color = col
		(mi.material_override as StandardMaterial3D).emission = col
	for id in _badges.keys():
		if not held.has(id):
			(_badges[id] as Node3D).queue_free()
			_badges.erase(id)
	for id in held:
		if not _badges.has(id) and _roots.has(id):
			_badges[id] = _badge(id)


## The HELD diamond: a small violet chip that hovers above the device's lamp and turns slowly.
func _badge(id: int) -> Node3D:
	var root: Node3D = _roots[id]
	var at: Vector3 = (_lights[id][5] as Vector3) if _lights.has(id) else Vector3(0, 1.0, 0)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.09, 0.09, 0.02)
	mi.mesh = bm
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = VIOLET
	mt.emission_enabled = true
	mt.emission = VIOLET
	mt.emission_energy_multiplier = 2.0
	mi.material_override = mt
	mi.position = at + Vector3(0, 0.24, 0.04)
	mi.rotation.z = PI / 4
	mi.name = "held_%d" % id
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi


func _process(_d: float) -> void:   # jack-point rings breathe, HELD badges turn
	var t := Time.get_ticks_msec() / 1000.0
	for id in _badges:
		(_badges[id] as Node3D).rotation.y = t * 1.6
	var k := 0.5 + 0.5 * sin(t * 1.7)   # the access-point port LEDs: a slow breath, ~3.7 s
	for pt in _ports:
		var pm := pt.material_override as StandardMaterial3D
		pm.emission_energy_multiplier = lerpf(1.2, 4.5, k)
		pm.albedo_color = CYAN.lerp(CYAN.darkened(0.55), 1.0 - k)
	for ch in get_children():
		if ch.name.begins_with("ring_"):
			var a := 0.35 + 0.25 * sin(t * 2.4)
			((ch as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = Color(CYAN, a)


## Access points come in a few models (owner: variety), picked by device id so a map keeps its
## look: 0 a desk terminal, 1 the kit's wall access unit, 2 a slim wall jack box on a cable
## conduit, 3 a floor-standing server pillar. Each has its cyan screen lamp (the status light);
## returns where its port LED sits.
const AP_MODELS := 4


static func access_point_model(id: int) -> int:
	return posmod(id * 7 + 3, AP_MODELS)


func _access_point_model(id: int, root: Node3D, back: float) -> Vector3:
	match access_point_model(id):
		1:
			_kit(root, "Prop_AccessPoint", Vector3(0, 0, back + 0.12), 0.75)
			_led(id, root, Vector3(0, 0.75, back + 0.27), Vector3(0.18, 0.05, 0.01), CYAN, 2.6, "screen")
			return Vector3(0, 0.44, back + 0.33)
		2:
			_box(root, Vector3(0.05, 1.6, 0.05), Vector3(0.12, 1.5, back + 0.03), Color("1b1f27"))   # the conduit up the wall
			_box(root, Vector3(0.34, 0.46, 0.08), Vector3(0, 0.78, back + 0.05), Color("252b36"))
			_box(root, Vector3(0.3, 0.04, 0.09), Vector3(0, 0.58, back + 0.05), Color("3a4250"))   # a lip under the sockets
			_led(id, root, Vector3(0, 0.9, back + 0.1), Vector3(0.2, 0.08, 0.01), CYAN, 2.4, "screen")
			return Vector3(0, 0.7, back + 0.1)
		3:
			_box(root, Vector3(0.42, 1.3, 0.4), Vector3(0, 0.65, back + 0.2), Color("1e232c"))
			for k in 4:   # vent slots down the face
				_box(root, Vector3(0.3, 0.03, 0.01), Vector3(0, 0.25 + k * 0.08, back + 0.405), Color("0d1015"))
			_led(id, root, Vector3(0, 1.12, back + 0.405), Vector3(0.26, 0.1, 0.01), CYAN, 2.4, "screen")
			return Vector3(0, 0.82, back + 0.42)
		_:
			_kit(root, "Prop_Computer", Vector3(0, 0, back + 0.12), 0.55)
			_led(id, root, Vector3(0, 0.62, back + 0.27), Vector3(0.22, 0.14, 0.01), CYAN, 2.2, "screen")
			return Vector3(0, 0.44, back + 0.33)


func _led(id: int, parent: Node3D, pos: Vector3, size: Vector3, col: Color, glow: float, kind: String) -> void:
	var mi := _box(parent, size, pos, col)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = glow
	mi.material_override = m
	var cell: Vector3i = parent.get_meta("cell", Vector3i(-1, -1, -1))
	_lights[id] = [mi, null, col, kind, cell, pos]


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
