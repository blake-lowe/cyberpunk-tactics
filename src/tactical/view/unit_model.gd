class_name UnitModel
extends RefCounted
## Code-built blockout humanoids (spec: code-generated modular characters; real models and
## retargeted animations come later). 1 world unit = one 2 m square, so a person is ~0.9 tall.
## Each body gets an emissive accent (visor/stripe) so it reads through the pixel filter and bloom.

const CREW_JACKETS := [Color("2f4a66"), Color("5e2f5e"), Color("4a5e2f"), Color("5e4a2f")]
const CREW_ACCENTS := [Color("05d9e8"), Color("ff2a6d"), Color("f9c80e"), Color("39f0a0")]


static func build(team: int, index: int) -> Node3D:
	var root := Node3D.new()
	var jacket: Color = CREW_JACKETS[index % 4] if team == 0 else Color("5a6068")
	var accent: Color = CREW_ACCENTS[index % 4] if team == 0 else Color("ff3030")
	var skin := Color("c89a7a") if (index % 3) != 1 else Color("7a5640")
	var pants := Color("15181c")
	_box(root, Vector3(-0.065, 0.2, 0), Vector3(0.11, 0.4, 0.13), pants)
	_box(root, Vector3(0.065, 0.2, 0), Vector3(0.11, 0.4, 0.13), pants)
	_box(root, Vector3(0, 0.56, 0), Vector3(0.28, 0.32, 0.16), jacket)
	_box(root, Vector3(0, 0.56, 0.082), Vector3(0.05, 0.3, 0.01), accent, 2.5)   # chest stripe
	_box(root, Vector3(-0.18, 0.55, 0), Vector3(0.08, 0.3, 0.1), jacket)       # left arm
	_box(root, Vector3(0.17, 0.6, 0.1), Vector3(0.08, 0.1, 0.24), jacket)      # right arm, aiming
	_box(root, Vector3(0.17, 0.62, 0.27), Vector3(0.05, 0.07, 0.2), Color("101214"))  # gun
	_box(root, Vector3(0, 0.81, 0), Vector3(0.15, 0.17, 0.15), skin)
	_box(root, Vector3(0, 0.84, 0.077), Vector3(0.15, 0.04, 0.02), accent, 4.0)  # visor / optics
	_box(root, Vector3(0, 0.45, 0), Vector3(0.3, 0.03, 0.18), accent, 2.0)       # belt light: team colour at a glance
	if team == 1:
		_box(root, Vector3(0, 0.9, 0), Vector3(0.17, 0.05, 0.17), jacket)       # helmet
	return root


static func _box(parent: Node3D, pos: Vector3, size: Vector3, col: Color, glow := 0.0) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	var mt := StandardMaterial3D.new()
	mt.albedo_color = col
	mt.roughness = 0.6
	if glow > 0.0:
		mt.emission_enabled = true
		mt.emission = col
		mt.emission_energy_multiplier = glow
	b.material = mt
	mi.mesh = b
	mi.position = pos
	parent.add_child(mi)
