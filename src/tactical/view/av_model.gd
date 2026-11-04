class_name AVModel
extends Node3D
## An AV (aerodyne, CPR's AV-4 class): a bus-sized armoured lifting body on four thruster pods
## set out on pylons at its corners, with a framed windscreen, a light bar, a ribbed roof spine,
## a chin gun, side doors between the pods and a rear ramp. The pods tilt for forward flight and
## swing level to hover. Faceted (chamfered, flat-shaded) so it keeps clean tones under the pixel
## post-process. Two liveries:
##   trauma: white and pale grey, teal pod tops and panels, a red asterisk on the roof and doors.
##   maxtac: dark gunmetal with harder chamfers, blue edge lights, a red/blue police bar, a roof
##           turret and twin guns under the front pods.
## Thrust glows blue-white from the fan exits; a soft shadow sits on the ground beneath.
## Decoration only (no rules).

const TILT_FLY := 0.65   ## nacelle tilt (radians, exhaust aft) in forward flight
const HOVER := 0.9       ## height of the hull origin above the ground once landed

var kind := "trauma"
var _body: Node3D             ## everything visible; bobs while hovering
var _pivots: Array[Node3D] = []
var _beacons: Array[MeshInstance3D] = []
var _flames: Array[MeshInstance3D] = []
var _light: SpotLight3D
var _t := 0.0
var _hover := false
var _shadow: MeshInstance3D
var ground_y := 0.0      ## where the contact shadow lies


static func make(p_kind: String) -> AVModel:
	var av := AVModel.new()
	av.kind = p_kind
	av._build()
	return av


func _mat(col: Color, metal := 0.3, rough := 0.5, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = metal
	m.roughness = rough
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = glow
	return m


func _box(size: Vector3, pos: Vector3, m: Material, parent: Node3D, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _cyl(r_top: float, r_bot: float, h: float, pos: Vector3, m: Material, parent: Node3D, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = 14
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


## A closed tube through rounded-rectangle sections along z: each section is
## [z, half_width, bottom_y, top_y, corner_radius]. `seg` is arc steps per corner (1 = a single
## chamfer); `flat` shades the sides flat instead of smooth. End caps are always flat.
func _loft(secs: Array, m: Material, parent: Node3D, seg := 4, flat := false) -> MeshInstance3D:
	var SEG := seg
	var rings: Array = []
	for s in secs:
		var z: float = s[0]
		var hw: float = s[1]
		var yb: float = s[2]
		var yt: float = s[3]
		var r: float = minf(float(s[4]), minf(hw, (yt - yb) * 0.5) - 0.001)
		var ring: Array[Vector3] = []
		var corners := [[Vector2(hw - r, yb + r), -PI / 2.0], [Vector2(hw - r, yt - r), 0.0],
			[Vector2(-hw + r, yt - r), PI / 2.0], [Vector2(-hw + r, yb + r), PI]]
		for c in corners:
			for k in SEG + 1:
				var a: float = float(c[1]) + PI / 2.0 * k / SEG
				var p: Vector2 = (c[0] as Vector2) + Vector2(cos(a), sin(a)) * r
				ring.append(Vector3(p.x, p.y, z))
		rings.append(ring)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0xFFFFFFFF if flat else 1)
	var n: int = (rings[0] as Array).size()
	for i in rings.size() - 1:
		for j in n:
			var j2 := (j + 1) % n
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i][j2]
			var c: Vector3 = rings[i + 1][j2]
			var d: Vector3 = rings[i + 1][j]
			for v in [a, c, b, a, d, c]:   # clockwise seen from outside (Godot's front face)
				st.add_vertex(v)
	st.set_smooth_group(0xFFFFFFFF)   # flat caps
	for cap in [0, rings.size() - 1]:
		var ring: Array = rings[cap]
		var ctr := Vector3.ZERO
		for p in ring:
			ctr += p
		ctr /= ring.size()
		for j in n:
			var p: Vector3 = ring[j]
			var q: Vector3 = ring[(j + 1) % n]
			for v in ([ctr, p, q] if cap == 0 else [ctr, q, p]):
				st.add_vertex(v)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	parent.add_child(mi)
	return mi


## The Trauma Team mark: a six-armed asterisk, laid on a plane facing `normal_axis` ("y" or "x").
func _asterisk(at: Vector3, size: float, m: Material, parent: Node3D, normal_axis := "y") -> void:
	for i in 3:
		var ang := PI / 3.0 * i
		if normal_axis == "y":
			_box(Vector3(size * 0.26, 0.02, size), at, m, parent, Vector3(0, ang, 0))
		else:
			_box(Vector3(0.02, size, size * 0.26), at, m, parent, Vector3(ang, 0, 0))


## Lettering on the hull. `rot` turns the label (it faces +z); `spin` then turns the text within
## its plane (for lettering that runs along the roof).
func _label(text: String, at: Vector3, height: float, parent: Node3D, rot: Vector3, spin := 0.0, col := Color("e8ecf0")) -> void:
	var holder := Node3D.new()
	holder.position = at
	holder.rotation = Vector3(0, spin, 0) if spin != 0.0 else Vector3.ZERO
	parent.add_child(holder)
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/ChakraPetch-Bold.ttf")
	l.font_size = 64
	l.outline_size = 0
	l.pixel_size = height / 64.0
	l.modulate = col
	l.shaded = true
	l.double_sided = false
	l.rotation = rot
	holder.add_child(l)


func _build() -> void:
	var tt := kind == "trauma"
	_body = Node3D.new()
	add_child(_body)
	var b := _body
	# palette
	var hull := _mat(Color("eceef0") if tt else Color("1d2025"), 0.25 if tt else 0.55, 0.35 if tt else 0.4)
	var hull2 := _mat(Color("a9b1b8") if tt else Color("353a42"), 0.5, 0.45)    # lower flank, pods (MaxTac), roof spine
	var mech := _mat(Color("2a2e34") if tt else Color("0c0d10"), 0.6, 0.45)     # ribs, pylons, fans, guns, belly
	var accent := _mat(Color("169aa6") if tt else Color("2a6aff"), 0.2, 0.4, 0.0 if tt else 1.6)
	var glass := _mat(Color("0e2a3c") if tt else Color("1a2a44"), 0.6, 0.08, 0.35 if tt else 0.25)
	glass.emission = Color("4ab8ff") if tt else Color("3a6aff")
	var mark := _mat(Color("e2302a"), 0.1, 0.4, 0.5)
	var plate := _mat(Color("f2f4f5"), 0.2, 0.4)
	var r := 0.3 if tt else 0.14   # chamfer: Trauma's hull softer, MaxTac's harder armour

	# --- hull: a bus-sized lifting body, faceted so it holds three tones under the pixel filter --
	_loft([
		[-3.2, 1.05, 0.45, 1.95, r],
		[-3.0, 1.3, 0.3, 2.2, r],
		[1.2, 1.32, 0.3, 2.2, r],
		[2.1, 1.25, 0.35, 1.9, r],
		[2.8, 1.05, 0.45, 1.35, r],
		[3.1, 0.75, 0.55, 1.0, r * 0.6],
	], hull, b, 1, true)
	_box(Vector3(2.0 if tt else 2.3, 0.08, 4.6), Vector3(0, 0.28, -0.7), mech, b)         # belly plate
	for sx in [-1, 1]:   # two-tone: grey lower flank under a livery stripe, broken by the door
		for seg in [[-1.9, 2.0], [0.8, 0.6]]:   # [centre z, length] either side of the door
			_box(Vector3(0.03, 0.4, seg[1]), Vector3(sx * 1.33, 0.8 if tt else 0.66, seg[0]), hull2, b)
			_box(Vector3(0.03, 0.1, seg[1]), Vector3(sx * 1.335, 1.05 if tt else 0.9, seg[0]), accent, b)
	# canopy: Trauma's windscreen runs up onto the roof; MaxTac's is a visor on the nose slope
	if tt:
		_loft([
			[1.5, 1.32, 1.25, 2.125, r],
			[2.1, 1.27, 1.15, 1.92, r],
			[2.8, 1.07, 0.95, 1.37, r],
			[2.95, 0.93, 0.9, 1.2, r * 0.8],
		], glass, b, 1, true)
		_box(Vector3(1.9, 0.07, 0.16), Vector3(0, 2.16, 1.5), hull, b)                         # brow
		_box(Vector3(0.14, 0.05, 0.64), Vector3(0, 2.06, 1.8), hull, b, Vector3(deg_to_rad(18.9), 0, 0))   # centre post
	else:
		_loft([
			[2.1, 1.27, 1.55, 1.92, r],
			[2.8, 1.07, 1.05, 1.37, r],
			[2.95, 0.93, 0.95, 1.2, r * 0.8],
		], glass, b, 1, true)
		_box(Vector3(1.9, 0.03, 0.06), Vector3(0, 1.94, 2.1), accent, b)                       # lit visor brow
	_box(Vector3(0.14, 0.05, 0.9), Vector3(0, 1.685, 2.45), hull, b, Vector3(deg_to_rad(38.2), 0, 0))       # centre post
	# side doors (sliding, between the pods) and the rear ramp
	for sx in [-1, 1]:
		_box(Vector3(0.04, 1.35, 1.3), Vector3(sx * 1.345, 1.18 if tt else 1.24, -0.2), mech, b)
		_box(Vector3(0.035, 1.2, 0.05), Vector3(sx * 1.34, 1.18 if tt else 1.24, 0.5), hull2, b)  # door rail
	_box(Vector3(1.6, 1.2, 0.04), Vector3(0, 1.2, -3.21), mech, b)                            # rear ramp
	for sx in [-1, 1]:
		_box(Vector3(0.22, 0.1, 0.04), Vector3(sx * 0.75, 1.75, -3.22), _mat(Color("ff2020"), 0.0, 0.4, 2.5), b)   # tail lights
		_box(Vector3(0.18, 0.08, 0.04), Vector3(sx * 0.42, 0.66, 3.11), _mat(Color("f4f8ff"), 0.0, 0.3, 3.0), b)    # headlights
	# roof: a wide light bar at the front, a raised spine with slats, sensors, antennae
	var bar_cols: Array = [Color("ff2a2a"), Color("f4f4f4")] if tt else [Color("ff2020"), Color("2a6aff")]
	_box(Vector3(1.8, 0.1, 0.26), Vector3(0, 2.25, 1.05), mech, b)
	for i in 2:
		_beacons.append(_box(Vector3(0.86, 0.11, 0.22), Vector3(-0.44 + i * 0.88, 2.31, 1.05), _mat(bar_cols[i], 0.0, 0.3, 1.8), b))
	var spine_z := -2.0 if tt else -2.3
	var spine_l := 1.6 if tt else 1.3
	_box(Vector3(1.1, 0.18, spine_l), Vector3(0, 2.29, spine_z), hull2, b)
	for k in 4:
		_box(Vector3(1.0, 0.04, 0.08), Vector3(0, 2.4, spine_z - spine_l * 0.375 + k * spine_l * 0.25), mech, b)
	for sx in [-1, 1]:
		_box(Vector3(0.03, 0.55, 0.03), Vector3(sx * 0.7, 2.47, -2.9), mech, b, Vector3(deg_to_rad(-15), 0, 0))
	if tt:   # the red asterisk on white on the roof and on the door plates; a teal band
		_asterisk(Vector3(0, 2.215, -0.3), 1.3, mark, b)
		_box(Vector3(1.95, 0.02, 0.26), Vector3(0, 2.21, 0.72), accent, b)
		_box(Vector3(0.4, 0.2, 0.3), Vector3(0.75, 2.3, -1.0), hull2, b)                      # sensor box
		for sx in [-1, 1]:
			_box(Vector3(0.02, 0.72, 0.72), Vector3(sx * 1.375, 1.35, -0.2), plate, b)
			_asterisk(Vector3(sx * 1.39, 1.35, -0.2), 0.58, mark, b, "x")
	else:    # roof turret, blue running lights, lettering on the roof and the doors
		_box(Vector3(0.55, 0.32, 0.5), Vector3(0, 2.36, 0.65), mech, b)                       # roof turret
		_cyl(0.045, 0.045, 0.7, Vector3(0, 2.45, 1.1), mech, b, Vector3(PI / 2.0, 0, 0))
		for sx in [-1, 1]:
			_box(Vector3(0.06, 0.02, 4.0), Vector3(sx * 1.05, 2.21, -0.9), accent, b)
			_label("MAX-TAC", Vector3(sx * 1.375, 1.62, -0.2), 0.22, b, Vector3(0, sx * PI / 2.0, 0))
		_label("MAXTAC", Vector3(0, 2.215, -0.85), 0.46, b, Vector3(-PI / 2.0, 0, 0), PI / 2.0)
	# chin gun under the nose (MaxTac: twin heavy barrels)
	_box(Vector3(0.5, 0.26, 0.55), Vector3(0, 0.3, 2.2), mech, b)
	for gx in ([-0.1, 0.1] if not tt else [0.0]):
		_cyl(0.045, 0.045, 0.75 if not tt else 0.5, Vector3(gx, 0.28, 2.7 if not tt else 2.6), mech, b, Vector3(PI / 2.0, 0, 0))

	# --- four thruster pods on pylons, set out from the hull, hanging below the belly ----------
	var pod_r := 0.16 if tt else 0.1
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var piv := Node3D.new()
			piv.position = Vector3(sx * 1.98, 0.95, 2.0 if sz > 0 else -2.3)
			b.add_child(piv)
			_pivots.append(piv)
			_box(Vector3(0.5, 0.35, 0.9), Vector3(-sx * 0.6, 0.2, 0), mech, piv)              # pylon
			_loft([
				[-1.05, 0.34, -0.7, 0.38, pod_r * 0.6],
				[-0.85, 0.48, -0.95, 0.55, pod_r],
				[0.7, 0.48, -0.95, 0.55, pod_r],
				[1.0, 0.36, -0.6, 0.4, pod_r * 0.75],
			], hull if tt else hull2, piv, 1, true)
			if tt:   # teal pod tops and lower outer panels
				_box(Vector3(0.6, 0.02, 1.4), Vector3(0, 0.56, -0.05), accent, piv)
				_box(Vector3(0.03, 0.45, 1.4), Vector3(sx * 0.485, -0.6, -0.05), accent, piv)
			else:    # blue edge lights along the top
				_box(Vector3(0.04, 0.03, 1.4), Vector3(sx * 0.36, 0.57, -0.05), accent, piv)
			# a raised armour plate over the front half, sloping to the nose; intake slats behind it
			_box(Vector3(0.62, 0.07, 0.7), Vector3(0, 0.6, 0.35), accent if tt else hull, piv, Vector3(deg_to_rad(8), 0, 0))
			for k in 5:
				_box(Vector3(0.5, 0.04, 0.06), Vector3(0, 0.58 if tt else 0.57, -0.7 + k * 0.15), mech, piv)
			_box(Vector3(0.22, 0.05, 1.5), Vector3(sx * 0.42, 0.5, -0.05), hull if tt else hull2, piv, Vector3(0, 0, sx * deg_to_rad(35)))   # shoulder
			for k in 5:   # deep vertical ribs on the outer face
				_box(Vector3(0.12, 0.9, 0.08), Vector3(sx * 0.53, -0.2, -0.6 + k * 0.3), mech, piv)
			var guns: bool = not tt and sz > 0
			var ez: float = -0.25 if guns else -0.05   # exhaust sits back to clear the gun mount
			if guns:   # MaxTac: twin guns under the front pods
				_box(Vector3(0.3, 0.2, 0.5), Vector3(0, -1.03, 0.45), mech, piv)
				for gx in [-0.08, 0.08]:
					_cyl(0.04, 0.04, 0.55, Vector3(gx, -1.05, 0.975), mech, piv, Vector3(PI / 2.0, 0, 0))
				_box(Vector3(0.28, 0.12, 0.12), Vector3(0, -1.05, 1.3), mech, piv)                # muzzle block
			_cyl(0.36, 0.36, 0.06, Vector3(0, -0.96, ez), mech, piv)                           # fan exit
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.32
			tm.outer_radius = 0.42
			ring.mesh = tm
			ring.material_override = _mat(Color("9ad8ff"), 0.0, 0.4, 3.5)
			ring.position = Vector3(0, -0.99, ez)
			piv.add_child(ring)
			var flame := MeshInstance3D.new()
			var fm := CylinderMesh.new()
			fm.top_radius = 0.34
			fm.bottom_radius = 0.06
			fm.height = 0.7
			flame.mesh = fm
			var fmat := StandardMaterial3D.new()
			fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fmat.albedo_color = Color(0.25, 0.55, 1.0, 0.4)
			flame.material_override = fmat
			flame.position = Vector3(0, -1.37, ez)
			piv.add_child(flame)
			_flames.append(flame)
	var glow := OmniLight3D.new()   # thrust wash on the ground
	glow.light_color = Color("8ac8ff")
	glow.omni_range = 6.5
	glow.light_energy = 2.4
	glow.position = Vector3(0, -0.6, 0)
	b.add_child(glow)
	_light = SpotLight3D.new()   # the searchlight under the nose, sweeping the ground
	_light.light_color = Color("e8f4ff") if tt else Color("f0f4ff")
	_light.light_energy = 6.0
	_light.spot_range = 22.0
	_light.spot_angle = 16.0
	_light.position = Vector3(0, 0.15, 2.5)
	_light.rotation = Vector3(deg_to_rad(-70), 0, 0)
	b.add_child(_light)
	_shadow = MeshInstance3D.new()   # soft contact shadow, kept on the ground under the craft
	var pm := PlaneMesh.new()
	pm.size = Vector2(5.5, 7.5)
	_shadow.mesh = pm
	var gt := GradientTexture2D.new()
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(0.5, 0.0)
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.6))
	g.set_color(1, Color(0, 0, 0, 0.0))
	gt.gradient = g
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_texture = gt
	sm.albedo_color = Color(1, 1, 1, 0.0)
	_shadow.material_override = sm
	_shadow.top_level = true
	add_child(_shadow)
	_set_tilt(TILT_FLY)


func _set_tilt(a: float) -> void:
	for p in _pivots:
		p.rotation.x = a


func _process(delta: float) -> void:
	_t += delta
	for i in _beacons.size():
		_beacons[i].visible = int(_t * 4.0 + i) % 2 == 0
	for i in _flames.size():
		_flames[i].scale = Vector3(1, 0.8 + 0.3 * sin(_t * 31.0 + i * 1.7), 1)
	if _light:
		_light.rotation.y = sin(_t * 0.7) * 0.5
	_body.position.y = sin(_t * 2.1) * 0.05 if _hover else 0.0
	if _shadow and is_inside_tree():   # darker the closer the craft is to the ground
		var h := global_position.y - ground_y
		_shadow.global_position = Vector3(global_position.x, ground_y + 0.03, global_position.z)
		_shadow.global_rotation = Vector3(0, global_rotation.y, 0)
		(_shadow.material_override as StandardMaterial3D).albedo_color.a = clampf(1.0 - (h - 0.9) / 8.0, 0.0, 1.0)


## Come down from the sky onto `at` (ground point) facing `yaw` (square to the grid, so it fits
## the clearing Encounter.av_spot found) at `size`, the pods swinging level as it slows, and
## hover just above it at the end.
func land(at: Vector3, yaw := 0.0, size := 1.0, secs := 2.6) -> Tween:
	ground_y = at.y
	scale = Vector3.ONE * size
	_shadow.scale = scale
	rotation.y = yaw
	position = at + Vector3(0, 9, -6).rotated(Vector3.UP, yaw)   # comes in nose first, from astern
	_hover = false
	_set_tilt(TILT_FLY)
	var tw := create_tween()
	tw.tween_property(self, "position", at + Vector3(0, HOVER * size, 0), secs).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_set_tilt, TILT_FLY, 0.0, secs * 0.8).set_delay(secs * 0.2).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _hover = true)
	return tw


func lift_off(secs := 2.4) -> Tween:
	_hover = false
	var tw := create_tween()
	tw.tween_property(self, "position", position + Vector3(0, 1.5, 0), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_method(_set_tilt, 0.0, TILT_FLY, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "position", position + Vector3(0, 18, 14).rotated(Vector3.UP, rotation.y), secs).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
	return tw
