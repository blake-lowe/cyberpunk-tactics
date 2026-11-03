class_name AVModel
extends Node3D
## An AV (aerodyne): a flying armoured van on four vectored thrust pods. Trauma Team's is white
## with medical-blue stripes and a cross; MaxTac's is matte black with hazard-yellow chevrons and a
## red light bar. It comes down out of the sky on its thrusters with a searchlight, kicks up dust,
## hovers just off the ground while the team deploys, and lifts away again. Decoration only.

var kind := "trauma"
var _pods: Array[MeshInstance3D] = []
var _beacons: Array[MeshInstance3D] = []
var _flames: Array[MeshInstance3D] = []
var _light: SpotLight3D
var _t := 0.0


static func make(p_kind: String) -> AVModel:
	var av := AVModel.new()
	av.kind = p_kind
	av._build()
	return av


func _mat(col: Color, metal := 0.4, rough := 0.5, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	return m


func _box(size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi


func _build() -> void:
	var tt := kind == "trauma"
	var hull := _mat(Color("e8ecef") if tt else Color("16181c"), 0.3, 0.35 if tt else 0.7)
	var trim := _mat(Color("2a8cff") if tt else Color("ffcc00"), 0.2, 0.4, 0.4)
	var dark := _mat(Color("22262c"), 0.6, 0.4)
	var glass := _mat(Color("6ab8e8") if tt else Color("ff3030"), 0.1, 0.05, 0.8)
	# body: a long armoured hull, tapered nose, raised cabin
	_box(Vector3(1.7, 0.75, 3.6), Vector3(0, 0.55, 0), hull)
	_box(Vector3(1.5, 0.45, 1.2), Vector3(0, 0.45, 2.15), hull, Vector3(deg_to_rad(-12), 0, 0))
	_box(Vector3(1.3, 0.5, 1.9), Vector3(0, 1.12, -0.2), hull)
	_box(Vector3(1.25, 0.32, 0.06), Vector3(0, 1.1, 0.78), glass, Vector3(deg_to_rad(-30), 0, 0))   # windscreen
	for sx in [-1, 1]:
		_box(Vector3(0.05, 0.25, 1.2), Vector3(sx * 0.66, 1.16, -0.2), glass)                    # side windows
		_box(Vector3(0.04, 0.12, 3.4), Vector3(sx * 0.86, 0.6, 0), trim)                          # livery stripe
	_box(Vector3(1.72, 0.08, 3.62), Vector3(0, 0.2, 0), dark)                                      # skid line
	if tt:   # the cross on the roof and doors
		var crs := _mat(Color("2a8cff"), 0.1, 0.4, 0.6)
		_box(Vector3(0.7, 0.03, 0.22), Vector3(0, 1.39, -0.2), crs)
		_box(Vector3(0.22, 0.03, 0.7), Vector3(0, 1.39, -0.2), crs)
		for sx in [-1, 1]:
			_box(Vector3(0.03, 0.4, 0.13), Vector3(sx * 0.87, 0.6, -0.9), crs)
			_box(Vector3(0.03, 0.13, 0.4), Vector3(sx * 0.87, 0.6, -0.9), crs)
	else:    # hazard chevrons, a red/blue light bar
		for i in 4:
			_box(Vector3(0.25, 0.03, 0.12), Vector3(-0.45 + i * 0.3, 1.39, 0.5), trim, Vector3(0, deg_to_rad(35), 0))
	var bar_cols := [Color("ff2020"), Color("2a8cff")] if not tt else [Color("2a8cff"), Color("ffffff")]
	for i in 2:
		_beacons.append(_box(Vector3(0.45, 0.1, 0.16), Vector3(-0.25 + i * 0.5, 1.42, 0.55), _mat(bar_cols[i], 0.0, 0.3, 3.0)))
	# four thrust pods on stub wings, each with a glowing intake ring and a flame cone below
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var pos := Vector3(sx * 1.35, 0.55, sz * 1.25)
			_box(Vector3(0.7, 0.14, 0.3), Vector3(sx * 0.95, 0.6, sz * 1.25), hull)   # stub wing
			var pod := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.34
			cm.bottom_radius = 0.28
			cm.height = 0.5
			cm.radial_segments = 12
			pod.mesh = cm
			pod.material_override = dark
			pod.position = pos
			add_child(pod)
			_pods.append(pod)
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.24
			tm.outer_radius = 0.3
			ring.mesh = tm
			ring.material_override = _mat(Color("ffb060"), 0.0, 0.4, 3.0)
			ring.position = pos + Vector3(0, -0.24, 0)
			add_child(ring)
			var flame := MeshInstance3D.new()
			var fm := CylinderMesh.new()
			fm.top_radius = 0.17
			fm.bottom_radius = 0.0
			fm.height = 0.45
			flame.mesh = fm
			var fmat := StandardMaterial3D.new()
			fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fmat.albedo_color = Color(1.0, 0.55, 0.2, 0.8) if kind == "maxtac" else Color(0.45, 0.75, 1.0, 0.8)
			flame.material_override = fmat
			flame.position = pos + Vector3(0, -0.48, 0)
			add_child(flame)
			_flames.append(flame)
	var glow := OmniLight3D.new()
	glow.light_color = Color("ffb060")
	glow.omni_range = 5.0
	glow.light_energy = 2.0
	glow.position = Vector3(0, -0.3, 0)
	add_child(glow)
	_light = SpotLight3D.new()   # the searchlight sweeping the ground
	_light.light_color = Color("e8f4ff") if tt else Color("fff0c0")
	_light.light_energy = 6.0
	_light.spot_range = 22.0
	_light.spot_angle = 16.0
	_light.position = Vector3(0, 0.3, 1.6)
	_light.rotation = Vector3(deg_to_rad(-70), 0, 0)
	add_child(_light)
	scale = Vector3.ONE * 0.8


func _process(delta: float) -> void:
	_t += delta
	for i in _beacons.size():
		_beacons[i].visible = int(_t * 4.0 + i) % 2 == 0
	for i in _flames.size():
		var f := _flames[i]
		f.scale = Vector3(1, 0.8 + 0.3 * sin(_t * 31.0 + i * 1.7), 1)
	if _light:
		_light.rotation.y = sin(_t * 0.7) * 0.5


## Come down from the sky onto `at` (ground point), hovering a little above it at the end.
func land(at: Vector3, secs := 2.6) -> Tween:
	position = at + Vector3(-10, 16, -6)
	rotation.y = atan2(10.0, 6.0)
	var tw := create_tween()
	tw.tween_property(self, "position", at + Vector3(0, 0.55, 0), secs).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	return tw


func lift_off(secs := 2.4) -> Tween:
	var tw := create_tween()
	tw.tween_property(self, "position", position + Vector3(0, 1.5, 0), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position", position + Vector3(12, 18, 10), secs).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
	return tw
