class_name UnitModel
extends RefCounted
## Code-built blockout humanoids (spec: code-generated modular characters; real models and
## retargeted animations come later). 1 world unit = one 2 m square, so a person is ~0.9 tall.
## Each body gets an emissive accent (visor/stripe) so it reads through the pixel filter and bloom.

const CREW_JACKETS := [Color("3f6a92"), Color("8a4a8a"), Color("6a8a42"), Color("8a6a42")]
const CREW_ACCENTS := [Color("05d9e8"), Color("ff2a6d"), Color("f9c80e"), Color("39f0a0")]


static func build(team: int, index: int) -> Node3D:
	var root := Node3D.new()
	root.set_meta("team", team)
	var jacket: Color = CREW_JACKETS[index % 4] if team == 0 else Color("5a6068")
	var accent: Color = CREW_ACCENTS[index % 4] if team == 0 else Color("ff3030")
	var skin := Color("c89a7a") if (index % 3) != 1 else Color("7a5640")
	var pants := Color("15181c")
	_box(root, Vector3(-0.065, 0.2, 0), Vector3(0.11, 0.4, 0.13), pants)
	_box(root, Vector3(0.065, 0.2, 0), Vector3(0.11, 0.4, 0.13), pants)
	_box(root, Vector3(0, 0.56, 0), Vector3(0.28, 0.32, 0.16), jacket)
	_box(root, Vector3(0, 0.56, 0.082), Vector3(0.05, 0.3, 0.01), accent, 1.5)   # chest stripe
	_box(root, Vector3(-0.18, 0.55, 0), Vector3(0.08, 0.3, 0.1), jacket)       # left arm
	_box(root, Vector3(0.17, 0.6, 0.1), Vector3(0.08, 0.1, 0.24), jacket)      # right arm, aiming
	_box(root, Vector3(0.17, 0.62, 0.27), Vector3(0.05, 0.07, 0.2), Color("101214"))  # gun
	_box(root, Vector3(0, 0.83, 0), Vector3(0.2, 0.2, 0.19), skin)   # oversized head reads at ~24 px
	_box(root, Vector3(0, 0.86, 0.1), Vector3(0.2, 0.05, 0.02), accent, 1.5)  # visor / optics
	_box(root, Vector3(0, 0.45, 0), Vector3(0.3, 0.03, 0.18), accent, 1.2)       # belt light: team colour at a glance
	if team == 1:
		_box(root, Vector3(0, 0.94, 0), Vector3(0.22, 0.06, 0.21), jacket)       # helmet
	return root


static func _box(parent: Node3D, pos: Vector3, size: Vector3, col: Color, glow := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	var mt := StandardMaterial3D.new()
	mt.albedo_color = col
	mt.roughness = 0.6
	mt.rim_enabled = true   # silhouettes read against dark streets
	mt.rim = 0.7
	mt.rim_tint = 0.6
	if glow > 0.0:
		mt.emission_enabled = true
		mt.emission = col
		mt.emission_energy_multiplier = glow
	b.material = mt
	mi.mesh = b
	mi.position = pos
	mi.layers = 3   # layer 2: the crew's own light only lights bodies
	parent.add_child(mi)
	# inverted-hull outline: a slightly larger back-face-only shell in ink = a 1-pixel silhouette line
	var ol := MeshInstance3D.new()
	var ob := BoxMesh.new()
	ob.size = size * 1.12 + Vector3.ONE * 0.025
	var om := StandardMaterial3D.new()
	om.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	om.cull_mode = BaseMaterial3D.CULL_FRONT
	om.albedo_color = Color("05060a") if parent.get_meta("team", 0) == 0 else Color("3a0608")
	ob.material = om
	ol.mesh = ob
	ol.position = pos
	parent.add_child(ol)
