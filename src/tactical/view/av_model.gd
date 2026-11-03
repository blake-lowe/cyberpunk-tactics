class_name AVModel
extends Node3D
## An AV (aerodyne, CPR's AV-4 class): a short, bulbous armoured lifting body on four ducted-fan
## nacelles at its corners, with a wraparound cockpit, a light bar, a chin gun and a rear ramp.
## The nacelles tilt for forward flight and swing level to hover. Two liveries:
##   trauma: white and pale grey, teal-blue panels, a red asterisk on the roof and doors.
##   maxtac: matte black and gunmetal, blue running lights, a red/blue police bar, heavier guns.
## Thrust glows blue-white from the fan exits. Decoration only (no rules), built from lofted
## rounded-rectangle sections so it reads as one rounded hull rather than a stack of boxes.

const TILT_FLY := 0.65   ## nacelle tilt (radians, exhaust aft) in forward flight

var kind := "trauma"
var _body: Node3D             ## everything visible; bobs while hovering
var _pivots: Array[Node3D] = []
var _beacons: Array[MeshInstance3D] = []
var _flames: Array[MeshInstance3D] = []
var _light: SpotLight3D
var _t := 0.0
var _hover := false


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
## [z, half_width, bottom_y, top_y, corner_radius]. Sides are smooth-shaded, end caps flat.
func _loft(secs: Array, m: Material, parent: Node3D, pos := Vector3.ZERO, rot := Vector3.ZERO) -> MeshInstance3D:
	const SEG := 4
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
	st.set_smooth_group(1)
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
	mi.position = pos
	mi.rotation = rot
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
	var hull := _mat(Color("eceef0") if tt else Color("141619"), 0.25, 0.35 if tt else 0.75)
	var hull2 := _mat(Color("a9b1b8") if tt else Color("2a2e34"), 0.5, 0.5)     # lower hull, nacelles' inner faces
	var mech := _mat(Color("2a2e34") if tt else Color("0c0d10"), 0.6, 0.45)     # louvres, fans, guns, belly
	var accent := _mat(Color("1f9fd8") if tt else Color("2a6aff"), 0.2, 0.4, 0.0 if tt else 1.6)
	var glass := _mat(Color("0e2a3c") if tt else Color("0e1218"), 0.6, 0.08, 0.35 if tt else 0.2)
	glass.emission = Color("4ab8ff") if tt else Color("3a5a8a")
	var mark := _mat(Color("e2302a"), 0.1, 0.4, 0.5)
	var plate := _mat(Color("d8dcdf"), 0.2, 0.4)

	# --- hull: a rounded lifting body, blunt tail, sloped nose -----------------------------
	_loft([
		[-2.55, 1.05, 0.42, 1.55, 0.35],
		[-2.35, 1.28, 0.25, 1.78, 0.45],
		[0.9, 1.3, 0.25, 1.8, 0.45],
		[1.7, 1.25, 0.3, 1.6, 0.45],
		[2.3, 1.05, 0.4, 1.2, 0.4],
		[2.6, 0.75, 0.5, 0.95, 0.22],
	], hull, b)
	_box(Vector3(2.3, 0.08, 4.5), Vector3(0, 0.24, 0.0), mech, b)                     # belly plate
	for sx in [-1, 1]:   # two-tone: grey lower flank under a livery stripe
		_box(Vector3(0.03, 0.42, 4.2), Vector3(sx * 1.305, 0.55, -0.6), hull2, b)
		_box(Vector3(0.03, 0.12, 4.2), Vector3(sx * 1.31, 0.82, -0.6), accent, b)
	# wraparound canopy over the nose, with a frame (centre post, brow, A-pillars)
	_loft([
		[1.15, 1.315, 1.0, 1.805, 0.45],
		[1.7, 1.27, 0.95, 1.62, 0.45],
		[2.3, 1.07, 0.85, 1.22, 0.4],
		[2.47, 0.93, 0.8, 1.09, 0.33],
	], glass, b)
	_box(Vector3(0.12, 0.06, 1.45), Vector3(0, 1.58, 1.8), hull, b, Vector3(deg_to_rad(-22), 0, 0))
	_box(Vector3(2.5, 0.08, 0.14), Vector3(0, 1.79, 1.18), hull, b)
	for sx in [-1, 1]:
		_box(Vector3(0.06, 0.6, 0.12), Vector3(sx * 1.29, 1.38, 1.72), hull, b, Vector3(deg_to_rad(-25), 0, 0))
		_box(Vector3(0.05, 0.3, 0.9), Vector3(sx * 1.305, 1.4, 0.35), glass, b)        # cabin side window
	# side doors (sliding, recessed) and the rear ramp
	for sx in [-1, 1]:
		_box(Vector3(0.03, 0.95, 1.25), Vector3(sx * 1.31, 1.02, -0.85), mech, b)
		_box(Vector3(0.035, 0.85, 0.05), Vector3(sx * 1.315, 1.02, -0.2), hull2, b)    # door rail
	_box(Vector3(1.7, 1.0, 0.04), Vector3(0, 0.95, -2.56), mech, b)
	for sx in [-1, 1]:
		_box(Vector3(0.22, 0.1, 0.04), Vector3(sx * 0.7, 1.35, -2.57), _mat(Color("ff2020"), 0.0, 0.4, 2.5), b)   # tail lights
		_box(Vector3(0.18, 0.08, 0.04), Vector3(sx * 0.42, 0.6, 2.61), _mat(Color("f4f8ff"), 0.0, 0.3, 3.0), b)   # headlights
	# roof: light bar behind the canopy, a hatch, antennae
	var bar_cols: Array = [Color("ff2a2a"), Color("f4f4f4")] if tt else [Color("ff2020"), Color("2a6aff")]
	_box(Vector3(1.3, 0.1, 0.24), Vector3(0, 1.84, 0.95), mech, b)
	for i in 2:
		_beacons.append(_box(Vector3(0.6, 0.11, 0.2), Vector3(-0.32 + i * 0.64, 1.9, 0.95), _mat(bar_cols[i], 0.0, 0.3, 3.0), b))
	_box(Vector3(0.8, 0.08, 0.55), Vector3(0, 1.82, -1.9), hull2, b)
	for sx in [-1, 1]:
		_box(Vector3(0.03, 0.5, 0.03), Vector3(sx * 0.55, 2.05, -2.15), mech, b, Vector3(deg_to_rad(-15), 0, 0))
	if tt:   # the red asterisk on the roof and the doors; teal roof band
		_asterisk(Vector3(0, 1.815, -0.45), 0.95, mark, b)
		_box(Vector3(2.0, 0.02, 0.22), Vector3(0, 1.81, 0.55), accent, b)
		_label("TRAUMA TEAM", Vector3(0, 1.825, -1.22), 0.24, b, Vector3(-PI / 2.0, 0, 0), 0.0, Color("2a3036"))
		for sx in [-1, 1]:
			_box(Vector3(0.02, 0.62, 0.62), Vector3(sx * 1.325, 1.12, -0.85), plate, b)
			_asterisk(Vector3(sx * 1.34, 1.12, -0.85), 0.5, mark, b, "x")
	else:    # blue running lights down the roof, a grey unit number plate on the doors
		for sx in [-1, 1]:
			_box(Vector3(0.06, 0.02, 3.2), Vector3(sx * 0.95, 1.81, -0.7), accent, b)
			_label("MAX-TAC", Vector3(sx * 1.33, 1.3, -0.85), 0.2, b, Vector3(0, sx * PI / 2.0, 0))
		_label("MAXTAC", Vector3(0, 1.825, -0.55), 0.42, b, Vector3(-PI / 2.0, 0, 0), PI / 2.0)
	# chin gun under the nose (MaxTac: twin heavy barrels)
	_box(Vector3(0.5, 0.26, 0.55), Vector3(0, 0.12, 1.75), mech, b)
	for gx in ([-0.1, 0.1] if not tt else [0.0]):
		_cyl(0.045, 0.045, 0.75 if not tt else 0.5, Vector3(gx, 0.1, 2.25 if not tt else 2.15), mech, b, Vector3(PI / 2.0, 0, 0))

	# --- four ducted-fan nacelles on pylons at the corners ----------------------------------
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			var piv := Node3D.new()
			piv.position = Vector3(sx * 1.72, 0.85, 1.25 if sz > 0 else -1.65)
			b.add_child(piv)
			_pivots.append(piv)
			_box(Vector3(0.3, 0.3, 0.7), Vector3(-sx * 0.42, 0.15, 0), hull2, piv)           # pylon
			_loft([
				[-0.95, 0.3, -0.42, 0.4, 0.08],
				[-0.78, 0.4, -0.62, 0.6, 0.12],
				[0.7, 0.4, -0.62, 0.6, 0.12],
				[0.95, 0.28, -0.32, 0.46, 0.08],
			], hull if tt else hull2, piv)
			_cyl(0.3, 0.3, 0.04, Vector3(0, 0.6, -0.05), mech, piv)                            # fan intake
			_cyl(0.08, 0.08, 0.06, Vector3(0, 0.62, -0.05), hull2 if tt else hull, piv)        # hub
			for k in 2:   # struts across the intake
				_box(Vector3(0.6, 0.03, 0.05), Vector3(0, 0.625, -0.05), hull2 if tt else hull, piv, Vector3(0, PI / 4.0 + k * PI / 2.0, 0))
			_box(Vector3(0.035, 0.5, 1.2), Vector3(sx * 0.405, -0.25, 0), accent if tt else mech, piv)   # outer panel
			for k in 4:   # vertical vents on the outer face
				_box(Vector3(0.03, 0.42, 0.06), Vector3(sx * 0.42, 0.25, -0.45 + k * 0.3), mech, piv)
			_cyl(0.34, 0.34, 0.06, Vector3(0, -0.6, 0), mech, piv)                             # fan exit
			var ring := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.27
			tm.outer_radius = 0.34
			ring.mesh = tm
			ring.material_override = _mat(Color("9ad8ff"), 0.0, 0.4, 3.5)
			ring.position = Vector3(0, -0.63, 0)
			piv.add_child(ring)
			var flame := MeshInstance3D.new()
			var fm := CylinderMesh.new()
			fm.top_radius = 0.26
			fm.bottom_radius = 0.06
			fm.height = 0.55
			flame.mesh = fm
			var fmat := StandardMaterial3D.new()
			fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			fmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			fmat.albedo_color = Color(0.5, 0.8, 1.0, 0.55)
			flame.material_override = fmat
			flame.position = Vector3(0, -0.93, 0)
			piv.add_child(flame)
			_flames.append(flame)
	var glow := OmniLight3D.new()   # thrust wash on the ground
	glow.light_color = Color("8ac8ff")
	glow.omni_range = 5.5
	glow.light_energy = 2.2
	glow.position = Vector3(0, -0.4, 0)
	b.add_child(glow)
	_light = SpotLight3D.new()   # the searchlight under the nose, sweeping the ground
	_light.light_color = Color("e8f4ff") if tt else Color("f0f4ff")
	_light.light_energy = 6.0
	_light.spot_range = 22.0
	_light.spot_angle = 16.0
	_light.position = Vector3(0, 0.1, 2.0)
	_light.rotation = Vector3(deg_to_rad(-70), 0, 0)
	b.add_child(_light)
	scale = Vector3.ONE * 0.85
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


## Come down from the sky onto `at` (ground point), the nacelles swinging level as it slows,
## and hover a little above it at the end.
func land(at: Vector3, secs := 2.6) -> Tween:
	position = at + Vector3(-10, 16, -6)
	rotation.y = atan2(10.0, 6.0)
	_hover = false
	_set_tilt(TILT_FLY)
	var tw := create_tween()
	tw.tween_property(self, "position", at + Vector3(0, 0.45, 0), secs).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_set_tilt, TILT_FLY, 0.0, secs * 0.8).set_delay(secs * 0.2).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _hover = true)
	return tw


func lift_off(secs := 2.4) -> Tween:
	_hover = false
	var tw := create_tween()
	tw.tween_property(self, "position", position + Vector3(0, 1.5, 0), 0.7).set_trans(Tween.TRANS_SINE)
	tw.tween_method(_set_tilt, 0.0, TILT_FLY, 0.6).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(self, "position", position + Vector3(12, 18, 10), secs).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
	return tw
