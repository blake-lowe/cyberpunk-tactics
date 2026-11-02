class_name UnitModel
extends RefCounted
## Code-built humanoids, smooth rather than blocky (owner: "non-blocky, not Minecraft"). Tapered
## capsule limbs, a tapered torso, rounded head, hands and boots, built as a joint hierarchy (hips,
## spine, neck, shoulders, elbows, hips/knees) so procedural animation can drive it later. Modular
## gear per Role: Solo armour vest and shoulder plates, Netrunner long coat and glowing interface
## band, guard helmet with a red visor and a tactical vest. Every part gets an inverted-hull ink
## outline (1 buffer pixel at tactical zoom) and the body sits on render layer 2 so the crew's own
## light only lights bodies. 1 world unit = one 2 m square; a person stands ~0.9 tall.
## Facing is +Z. Joint nodes are named (hips, spine, neck, head, shoulder_l/r, elbow_l/r,
## leg_l/r, knee_l/r) for animation.

const CREW_JACKETS := [Color("3f6a92"), Color("8a4a8a"), Color("6a8a42"), Color("8a6a42")]
const CREW_ACCENTS := [Color("05d9e8"), Color("ff2a6d"), Color("f9c80e"), Color("39f0a0")]
const SKIN := [Color("e0b090"), Color("b07a58"), Color("7a5038"), Color("c89a7a")]
const HAIR := [Color("16121a"), Color("4a2c1a"), Color("ff2a6d"), Color("dfe6ea"), Color("05d9e8")]


static func build(team: int, index: int, role := "") -> Node3D:
	var b := _Builder.new()
	b.ink = Color("05060a") if team == 0 else Color("2a0406")
	var root := Node3D.new()
	root.set_meta("team", team)
	var jacket: Color = CREW_JACKETS[index % 4] if team == 0 else Color("4e555e")
	var accent: Color = CREW_ACCENTS[index % 4] if team == 0 else Color("ff3030")
	var skin: Color = SKIN[(index * 7 + team) % SKIN.size()]
	var pants := Color("1c2026") if team == 0 else Color("2a2e34")
	var boots := Color("101214")
	var dark := Color("181b20")
	var is_runner := role == "netrunner"
	var is_solo := role == "solo" or team == 1

	# --- hips and legs (slight stance, knees a touch bent)
	var hips := b.joint(root, "hips", Vector3(0, 0.44, 0))
	b.sphere(hips, Vector3(0, 0, 0), Vector3(0.2, 0.12, 0.13), pants)
	for side in [-1, 1]:
		var leg := b.joint(hips, "leg_l" if side < 0 else "leg_r", Vector3(side * 0.055, -0.02, 0), Vector3(deg_to_rad(-4 if side < 0 else 6), 0, side * deg_to_rad(4)))
		b.capsule(leg, Vector3(0, -0.11, 0), 0.052, 0.25, pants)
		var knee := b.joint(leg, "knee_l" if side < 0 else "knee_r", Vector3(0, -0.215, 0), Vector3(deg_to_rad(6), 0, 0))
		b.capsule(knee, Vector3(0, -0.1, 0), 0.042, 0.22, pants)
		b.sphere(knee, Vector3(0, -0.205, 0.025), Vector3(0.085, 0.06, 0.14), boots)   # boot

	# --- torso
	var spine := b.joint(hips, "spine", Vector3(0, 0.03, 0))
	b.tapered(spine, Vector3(0, 0.15, 0), 0.115, 0.085, 0.27, Vector3(1.0, 1.0, 0.66), jacket)
	if is_solo:  # armour vest over the jacket
		b.tapered(spine, Vector3(0, 0.17, 0.006), 0.118, 0.1, 0.17, Vector3(1.05, 1.0, 0.74), dark)
	b.torus(spine, Vector3(0, 0.02, 0), 0.105, 0.012, Vector3(1.0, 1.0, 0.7), accent, 1.2)   # belt light
	if is_runner:  # long coat skirt
		b.tapered(spine, Vector3(0, -0.12, -0.005), 0.1, 0.15, 0.26, Vector3(1.0, 1.0, 0.75), jacket.darkened(0.15))
	# collar
	b.tapered(spine, Vector3(0, 0.29, -0.01), 0.06, 0.08, 0.04, Vector3(1.0, 1.0, 0.8), jacket.darkened(0.2))

	# --- head
	var neck := b.joint(spine, "neck", Vector3(0, 0.3, 0))
	b.capsule(neck, Vector3(0, 0.03, 0), 0.03, 0.08, skin)
	var head := b.joint(neck, "head", Vector3(0, 0.065, 0.005))
	b.sphere(head, Vector3(0, 0.075, 0), Vector3(0.15, 0.17, 0.155), skin)   # slightly oversized: reads at ~24 px
	b.sphere(head, Vector3(0, 0.02, 0.035), Vector3(0.1, 0.07, 0.1), skin.darkened(0.08))   # jaw
	if team == 1:
		b.sphere(head, Vector3(0, 0.11, -0.005), Vector3(0.17, 0.13, 0.175), Color("2e333a"))   # helmet
		b.tapered(head, Vector3(0, 0.08, 0.06), 0.06, 0.06, 0.03, Vector3(1.25, 1.0, 0.5), accent, 1.5)  # red visor
	else:
		var hair: Color = HAIR[(index * 3 + 1) % HAIR.size()]
		match index % 3:
			0: b.sphere(head, Vector3(0, 0.12, -0.012), Vector3(0.155, 0.1, 0.16), hair)    # short crop
			1: b.sphere(head, Vector3(0, 0.1, -0.03), Vector3(0.16, 0.15, 0.15), hair)      # long, swept back
			2: b.capsule(head, Vector3(0, 0.15, -0.01), 0.022, 0.16, hair, Vector3(deg_to_rad(90), 0, 0))  # mohawk
		if is_runner:  # interface band / visor glowing in the crew colour
			b.torus(head, Vector3(0, 0.085, 0), 0.077, 0.011, Vector3(1.0, 1.0, 1.0), accent, 1.5)
		else:
			b.tapered(head, Vector3(0, 0.085, 0.066), 0.045, 0.045, 0.022, Vector3(1.3, 1.0, 0.4), accent, 1.3)  # optics

	# --- arms: a two-handed aim, rifle across the chest
	for side in [-1, 1]:
		var sh := b.joint(spine, "shoulder_l" if side < 0 else "shoulder_r", Vector3(side * 0.125, 0.25, 0),
			Vector3(deg_to_rad(-70 if side > 0 else -55), 0, deg_to_rad(side * -8 if side > 0 else 28)))
		if is_solo:
			b.sphere(sh, Vector3(side * 0.012, 0.01, 0), Vector3(0.1, 0.07, 0.1), dark)   # shoulder plate
		b.capsule(sh, Vector3(0, -0.09, 0), 0.038, 0.2, jacket)
		var el := b.joint(sh, "elbow_l" if side < 0 else "elbow_r", Vector3(0, -0.18, 0), Vector3(deg_to_rad(-25 if side > 0 else -45), 0, 0))
		b.capsule(el, Vector3(0, -0.085, 0), 0.032, 0.18, jacket)
		b.sphere(el, Vector3(0, -0.18, 0), Vector3(0.06, 0.06, 0.06), skin if team == 0 else dark)   # hand
	# rifle, held at the chest pointing forward
	var gun := Node3D.new()
	gun.name = "weapon"
	gun.position = Vector3(0.06, 0.2, 0.17)
	spine.add_child(gun)
	b.box(gun, Vector3(0, 0, 0.02), Vector3(0.045, 0.06, 0.3), Color("14161a"))
	b.box(gun, Vector3(0, -0.05, -0.03), Vector3(0.035, 0.07, 0.04), Color("14161a"))   # grip / mag
	b.box(gun, Vector3(0, 0.02, 0.19), Vector3(0.022, 0.022, 0.12), Color("2a2e34"))  # barrel
	b.box(gun, Vector3(0, 0.045, 0.02), Vector3(0.02, 0.012, 0.08), accent, 1.2)      # sight glow
	return root


## Part factory: caches materials, adds outlines, puts bodies on layers 1+2.
class _Builder:
	var ink := Color.BLACK
	var _mats := {}
	var _ink_mat: StandardMaterial3D

	func joint(parent: Node3D, n: String, pos: Vector3, rot := Vector3.ZERO) -> Node3D:
		var j := Node3D.new()
		j.name = n
		j.position = pos
		j.rotation = rot
		parent.add_child(j)
		return j

	func _mat(col: Color, glow: float) -> StandardMaterial3D:
		var key := col.to_html() + str(glow)
		if _mats.has(key):
			return _mats[key]
		var mt := StandardMaterial3D.new()
		mt.albedo_color = col
		mt.roughness = 0.55
		mt.rim_enabled = true   # silhouettes read against dark streets
		mt.rim = 0.7
		mt.rim_tint = 0.6
		if glow > 0.0:
			mt.emission_enabled = true
			mt.emission = col
			mt.emission_energy_multiplier = glow
		_mats[key] = mt
		return mt

	func _outline_mat() -> StandardMaterial3D:
		if _ink_mat == null:
			_ink_mat = StandardMaterial3D.new()
			_ink_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_ink_mat.cull_mode = BaseMaterial3D.CULL_FRONT
			_ink_mat.albedo_color = ink
		return _ink_mat

	func _add(parent: Node3D, mesh: PrimitiveMesh, pos: Vector3, scl: Vector3, rot: Vector3, col: Color, glow: float, outline := true) -> void:
		mesh.material = _mat(col, glow)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = pos
		mi.rotation = rot
		mi.scale = scl
		mi.layers = 3   # layer 2: the crew's own light only lights bodies
		parent.add_child(mi)
		if outline and glow <= 0.0:
			# inverted hull: a slightly larger back-face-only copy in ink
			var ol := MeshInstance3D.new()
			var om: PrimitiveMesh = mesh.duplicate()
			om.material = _outline_mat()
			ol.mesh = om
			ol.position = pos
			ol.rotation = rot
			ol.scale = scl * 1.13 + Vector3.ONE * 0.012
			parent.add_child(ol)

	func sphere(parent: Node3D, pos: Vector3, size: Vector3, col: Color, glow := 0.0) -> void:
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 12
		s.rings = 6
		_add(parent, s, pos, size, Vector3.ZERO, col, glow)

	func capsule(parent: Node3D, pos: Vector3, r: float, h: float, col: Color, rot := Vector3.ZERO, glow := 0.0) -> void:
		var c := CapsuleMesh.new()
		c.radius = r
		c.height = maxf(h, r * 2.0)
		c.radial_segments = 10
		c.rings = 3
		_add(parent, c, pos, Vector3.ONE, rot, col, glow)

	func tapered(parent: Node3D, pos: Vector3, top: float, bottom: float, h: float, scl: Vector3, col: Color, glow := 0.0) -> void:
		var c := CylinderMesh.new()
		c.top_radius = top
		c.bottom_radius = bottom
		c.height = h
		c.radial_segments = 12
		c.rings = 1
		_add(parent, c, pos, scl, Vector3.ZERO, col, glow)

	func torus(parent: Node3D, pos: Vector3, r: float, thick: float, scl: Vector3, col: Color, glow := 0.0) -> void:
		var t := TorusMesh.new()
		t.inner_radius = r - thick
		t.outer_radius = r + thick
		t.rings = 16
		t.ring_segments = 6
		_add(parent, t, pos, scl, Vector3.ZERO, col, glow)

	func box(parent: Node3D, pos: Vector3, size: Vector3, col: Color, glow := 0.0) -> void:
		var bm := BoxMesh.new()
		bm.size = size
		_add(parent, bm, pos, Vector3.ONE, Vector3.ZERO, col, glow)
