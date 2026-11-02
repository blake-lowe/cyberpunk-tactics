class_name CharModel
extends Node3D
## Animated characters (replacing the primitive UnitModel): a Quaternius base body (CC0) with
## rigged hair, clothing painted by body region in char.gdshader, Role gear as simple shapes on
## bones, and a Quaternius gun in the right hand. Every clip in CharAnims plays on it.
## Looks come from UnitLook (shared with the HUD portrait).
##
## The view drives it with the same node metas as before, so playback code stays put:
## walk/run (moving), aim 0..1, crouch_goal / slump_goal, wound, calm (unalerted guard),
## jack (in the NET), recoil / recoil_kick, hit_t / hit_dir / hit_amp. One-shots: die(), hit.
## Clip choice is a small state picker in _process; locomotion playback speed follows the real
## ground speed, so feet don't skate. Recoil and hit jolts are layered procedurally on top of
## the clip (CharModel.Pose), so they stay frame-exact with the shots.
##
## Facing +Z. 1 world unit = 2 m, so the 1.8 m body is scaled by 0.5 (the view scales units ×1.3).

const SCALE := 0.5
const SHADER := preload("res://src/tactical/view/char.gdshader")
const Q := "res://assets/third_party/quaternius/"
const BODY := {"male": Q + "characters/Superhero_Male_FullBody.gltf", "female": Q + "characters/Superhero_Female_FullBody.gltf"}
const SKIN_TEX := {"male": Q + "characters/T_Superhero_Male_Ligh.png", "female": Q + "characters/T_Superhero_Female_Light_BaseColor.png"}
const HAIR_MESH := {"buzz": "Hair_Buzzed", "mohawk": "Hair_BuzzedFemale", "long": "Hair_Long", "undercut": "Hair_SimpleParted",
	"bob": "Hair_SimpleParted", "ponytail": "Hair_Buns", "curly": "Hair_Buzzed", "bald": "", "topknot": "Hair_Buns"}
## weapon id → [model, length in m, anim set]
## Lengths are a touch under real (owner: guns read too large at this scale).
const GUNS := {"medium_pistol": ["Pistol_1", 0.17, "pistol"], "heavy_pistol": ["Pistol_1", 0.19, "pistol"],
	"very_heavy_pistol": ["Revolver_1", 0.24, "pistol"], "smg": ["SubmachineGun_1", 0.38, "rifle"],
	"heavy_smg": ["SubmachineGun_1", 0.44, "rifle"], "assault_rifle": ["AssaultRifle_1", 0.68, "rifle"],
	"shotgun": ["Shotgun_1", 0.76, "rifle"], "sniper_rifle": ["SniperRifle_1", 0.88, "rifle"]}
## Clips where the left hand does its own thing (reloading): the gun holds still in the right hand.
const ANCHOR_CLIPS := ["rifle_reload", "pistol_reload"]
## How much a held-still rifle follows the chest (the rest is the body root): a reload keeps it
## steady; a dodge ducks with it.
const ANCHOR_CHEST := {"rifle_reload": 0.3}
## Two-handed pistol clips: the left hand is pulled onto the grip by IK.
const PISTOL_GRIP_CLIPS := ["pistol_idle", "pistol_aim", "pistol_walk", "pistol_run", "pistol_crouch"]
## Region ids painted into the body's vertex colour (see char.gdshader).
enum R { SKIN, JACKET, SLEEVE, PANTS, BOOTS, GLOVES, BELT, FOREARM }

static var _bodies := {}     ## body → ArrayMesh with clothing regions in COLOR
static var _gun_info := {}   ## model → {aabb, sign, grip}

var look: Dictionary
var skel: Skeleton3D
var anim: AnimationPlayer
var gun_kind := "rifle"
var mats: Array[ShaderMaterial] = []
var state := ""
var _oneshot := ""
var _last_pos := Vector3.ZERO
var _speed := 0.0
var _last_hit := 9.0
var index := 0
var _duck_until := 0
var _perform := ""
var _perform_until := 0
var hold_state := false   ## review tools: keep the clip they set (no state picking), everything else runs
var gun: Node3D
var gun_sign := 1.0
var gun_scale := 1.0
var gun_grip := Vector3.ZERO
var _gun_rel: Variant = null   ## gun relative to the right hand, frozen at death
var _death_t := -1.0           ## seconds since a death clip started (the gun lets go at 0.3)
var _drop_v := Vector3.ZERO    ## falling gun: velocity and spin (world units)
var _drop_w := Vector3.ZERO
var _dropping := false
var _anchored := ""            ## anchor clip the gun is currently held still for
var _anchor_rel := Transform3D.IDENTITY
var _ready_rel: Variant = null   ## last normal rifle hold relative to the chest (seeds reload/dodge holds)
var _ready_chest: Variant = null ## and the chest pose it was taken at (the hold is replayed where it was)
var _support: Marker3D         ## pistols: where the left wrist goes (IK target)
var _ik: TwoBoneIK3D           ## left arm → pistol support
var _ik_r: TwoBoneIK3D         ## right arm → rifle grip during reloads
var _grip_mark: Marker3D
const PALM := Vector3(0.0, 0.08, 0.03)      ## palm centre in hand-bone space (fingers +Y, palm +Z)
const GRIP_TILT := 0.35                     ## pistol grip angle: barrel above the finger line


static func build(team: int, index: int, role := "", weapon := "assault_rifle") -> CharModel:
	var c := CharModel.new()
	c._make(team, index, role, weapon)
	return c


func _make(team: int, idx: int, role: String, weapon: String) -> void:
	index = idx
	look = UnitLook.make(idx, team, role)
	set_meta("team", team)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(idx * 131 + team * 7 + 3)
	var sex := "female" if rng.randf() < 0.45 else "male"
	look["body"] = sex
	var body: Node3D = (load(BODY[sex]) as PackedScene).instantiate()
	body.scale = Vector3.ONE * SCALE
	add_child(body)
	skel = body.find_child("GeneralSkeleton", true, false)
	# --- outfit: colours per team/role, a few cut options
	var jacket: Color = look.jacket
	var accent: Color = look.accent
	var o := {"short": team == 0 and rng.randf() < 0.3, "gloves": team == 1 or rng.randf() < 0.5,
		"coat": role == "netrunner"}
	var pants: Color = jacket.darkened(0.5).lerp(Color("3a4660"), 0.5) if team == 0 else Color("3a4048")
	var vest := role == "solo" or team == 1   # armour vest over the jacket: torso dark, sleeves in colour
	var cloth := {"skin": look.skin, "jacket": Color("23262c") if vest else jacket, "sleeve": jacket,
		"forearm": look.skin if o.short else jacket.darkened(0.1), "pants": pants, "boots": Color("22262c"),
		"gloves": Color("1a1c20") if o.gloves else look.skin,
		"belt": Color("1c1712") if rng.randf() < 0.6 else Color("15171a")}
	for mi: MeshInstance3D in skel.find_children("*", "MeshInstance3D", false, false):
		mi.layers = 2
		match String(mi.name):
			"Eyes":
				mi.material_override = _mat(3, Color.WHITE, mi.get_active_material(0))
			"Eyebrows":
				mi.material_override = _mat(1, (look.hair as Color).darkened(0.3), mi.get_active_material(0))
			_:
				mi.mesh = _region_mesh(mi, sex)
				var m := _mat(0, Color.WHITE, null)
				m.set_shader_parameter("tex", load(SKIN_TEX[sex]))
				for k in cloth:
					m.set_shader_parameter(k, cloth[k])
				var hy := skel.get_bone_global_rest(skel.find_bone("Hips")).origin.y
				m.set_shader_parameter("belt_y", hy + 0.05)
				m.set_shader_parameter("coat_y", hy - 0.35 if o.coat else hy + 0.02)
				mi.material_override = m
	# --- hair (rigged to the head bone: rebind its mesh to our skeleton)
	var style := String(look.style)
	if team == 1:
		style = "bald"   # under the helmet
	if HAIR_MESH.get(style, "") != "":
		_add_hair(HAIR_MESH[style], look.hair)
	if sex == "male" and team == 0 and rng.randf() < 0.35:
		_add_hair("Hair_Beard", (look.hair as Color).darkened(0.2))
	# --- gear on bones: matte, practical kit (owner: no glowing trim)
	var kit := Color("1e2126")
	var metal := Color("6a6e74")
	var hb := _bone("Head")
	if team == 1:
		_part(hb, _sphere(0.132, 0.24), Vector3(0, 0.125, -0.01), Vector3(1.0, 0.85, 1.08), Color("2e333a"), 0.0, 0.7)    # ballistic helmet
		_part(hb, _box(Vector3(0.19, 0.06, 0.03)), Vector3(0, 0.085, 0.11), Vector3.ONE, Color("0c0e10"), 0.0, 0.12)        # smoked visor
	elif look.get("visor", false):
		_part(hb, _box(Vector3(0.15, 0.028, 0.02)), Vector3(0, 0.088, 0.1), Vector3.ONE, Color("0e1114"), 0.0, 0.12)        # dark glasses
	var hips := _bone("Hips")
	var by := 0.05
	_part(hips, _box(Vector3(0.045, 0.035, 0.012)), Vector3(0, by, 0.125 if sex == "male" else 0.115), Vector3.ONE, metal, 0.0, 0.3)   # buckle
	for side in [-1.0, 1.0]:   # belt pouches
		_part(hips, _box(Vector3(0.05, 0.07, 0.045)), Vector3(side * 0.15, by - 0.01, 0.03), Vector3.ONE, kit)
	_part(hips, _box(Vector3(0.11, 0.06, 0.04)), Vector3(0, by - 0.01, -0.12), Vector3.ONE, kit)   # dump pouch at the back
	for side in ["Left", "Right"]:   # boot shells over the base body's bare feet, aligned heel → toe
		var fi := skel.find_bone(side + "Foot")
		var frest := skel.get_bone_global_rest(fi)
		var toe := frest.affine_inverse() * skel.get_bone_global_rest(skel.find_bone(side + "Toes")).origin
		var up := (frest.basis.inverse() * Vector3.UP).normalized()
		var fwd := Vector3(toe - up * toe.dot(up)).normalized()
		var right := fwd.cross(up).normalized()
		var fb := _bone(side + "Foot")
		var ankle_h := frest.origin.y
		var shoe := CapsuleMesh.new()   # rounded toe and heel; lying along the foot
		shoe.radius = 0.058
		shoe.height = 0.31
		shoe.radial_segments = 10
		shoe.rings = 3
		var sh := _part(fb, shoe, Vector3.ZERO, Vector3.ONE, cloth.boots, 0.0, 0.5)
		sh.transform = Transform3D(Basis(right, fwd, -up).scaled(Vector3(1.0, 1.0, 0.85)), fwd * 0.065 + up * (-ankle_h + 0.05))
		var sole := _part(fb, _box(Vector3(0.105, 0.02, 0.29)), Vector3.ZERO, Vector3.ONE, Color("0e0f11"), 0.0, 0.9)
		sole.transform = Transform3D(Basis(right, up, fwd), fwd * 0.065 + up * (-ankle_h + 0.01))
	if vest:   # plate carrier: magazine pouches across the front
		var ch := _bone("UpperChest")
		for k in 3:
			_part(ch, _box(Vector3(0.055, 0.09, 0.035)), Vector3((k - 1) * 0.065, -0.15, 0.165 if sex == "male" else 0.15), Vector3.ONE, kit)
	# --- weapon in the right hand
	_add_gun(weapon)
	# --- animation
	anim = AnimationPlayer.new()
	body.add_child(anim)
	anim.root_node = NodePath("..")
	anim.add_animation_library("", CharAnims.library())
	var pose := Pose.new()
	pose.model = self
	skel.add_child(pose)
	# IK after Pose, so the hands reach for the gun where Pose just put it: the left hand onto a
	# pistol grip, the right hand onto a rifle's grip while a reload holds the rifle still
	_support = Marker3D.new()
	gun.add_child(_support)
	_ik = _arm_ik("Left", _support)
	_grip_mark = Marker3D.new()
	gun.add_child(_grip_mark)
	_grip_mark.position = gun_grip
	_ik_r = _arm_ik("Right", _grip_mark)
	set_meta("mats", mats)
	set_meta("outlines", [])
	_pick(true)


# --- outfit ---------------------------------------------------------------------------

## The body mesh with each vertex's clothing region in COLOR.r, from its dominant bone (cached
## per body and cut).
func _region_mesh(mi: MeshInstance3D, sex: String) -> Mesh:
	if _bodies.has(sex):
		return _bodies[sex]
	var src := mi.mesh as ArrayMesh
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
		var per := bones.size() / maxi(1, verts.size())
		var cols := PackedColorArray()
		cols.resize(verts.size())
		for v in verts.size():
			var best := 0
			for k in per:
				if weights[v * per + k] > weights[v * per + best]:
					best = k
			var bname := _bind_name(mi, bones[v * per + best])
			cols[v] = Color(_region(bname) / 8.0, verts[v].y / 2.0, 0)
		arr[Mesh.ARRAY_COLOR] = cols
		for c in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arr[c] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, src.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
	_bodies[sex] = out
	return out


func _bind_name(mi: MeshInstance3D, bind: int) -> String:
	if mi.skin == null or bind >= mi.skin.get_bind_count():
		return ""
	var nm := String(mi.skin.get_bind_name(bind))
	if nm == "" and mi.skin.get_bind_bone(bind) >= 0:
		nm = skel.get_bone_name(mi.skin.get_bind_bone(bind))
	return nm


## Trunk and legs share one region: the shader splits pants, belt, coat and boots by rest height
## (COLOR.g), which keeps those lines straight instead of following triangle edges.
static func _region(b: String) -> int:
	if b in ["Head", "Neck", "Jaw", "LeftEye", "RightEye"]:
		return R.SKIN
	if b.ends_with("Foot") or b.ends_with("Toes"):
		return R.BOOTS
	if b.ends_with("LowerArm"):
		return R.FOREARM
	if b.ends_with("UpperArm"):
		return R.SLEEVE
	if b.ends_with("Hand") or b.contains("Thumb") or b.contains("Index") or b.contains("Middle") or b.contains("Ring") or b.contains("Little"):
		return R.GLOVES
	return R.JACKET


func _mat(mode: int, col: Color, src: Material) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("albedo", col)
	if src is BaseMaterial3D and (src as BaseMaterial3D).albedo_texture:
		m.set_shader_parameter("tex", (src as BaseMaterial3D).albedo_texture)
	mats.append(m)
	return m


func _add_hair(nm: String, col: Color) -> void:
	var h: Node = (load(Q + "hair/%s.gltf" % nm) as PackedScene).instantiate()
	for mi: MeshInstance3D in h.find_children("*", "MeshInstance3D", true, false):
		var mat := mi.get_active_material(0)
		mi.get_parent().remove_child(mi)
		mi.owner = null
		skel.add_child(mi)
		mi.skeleton = NodePath("..")
		mi.layers = 2
		mi.material_override = _mat(1, col, mat)
	h.free()


func _bone(nm: String) -> BoneAttachment3D:
	var ba := BoneAttachment3D.new()
	ba.bone_name = nm
	skel.add_child(ba)
	return ba


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, scl: Vector3, col: Color, glow := 0.0, rough := 0.85) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scl
	mi.layers = 2
	var m := _mat(2, col, null)
	m.set_shader_parameter("roughness", rough)
	if glow > 0.0:
		m.set_shader_parameter("emission", col)
		m.set_shader_parameter("emission_energy", glow)
	mi.material_override = m
	parent.add_child(mi)
	return mi


static func _sphere(r: float, h: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = h
	s.radial_segments = 12
	s.rings = 6
	return s


static func _box(sz: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = sz
	return b


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 10
	c.rings = 1
	return c


# --- weapon -----------------------------------------------------------------------------

## The gun model at its real length. Pose places it every frame after the clip: two-handed guns
## run from the right palm toward the left palm (so rifles sit in both hands whatever the clip
## does with the arms), one-handed or free-handed it follows the right hand: barrel along the
## fingers (+Y) tipped up by the grip angle, top toward the thumb (+X). A Marker3D "muzzle" sits
## at the barrel end for the muzzle flash.
func _add_gun(weapon: String) -> void:
	var g: Array = GUNS.get(weapon, GUNS.assault_rifle)
	gun_kind = g[2]
	var model: Node3D = (load(Q + "guns/%s.fbx" % g[0]) as PackedScene).instantiate()
	var info := _gun_measure(String(g[0]), model)
	var aabb: AABB = info.aabb
	gun_sign = info.sign
	gun_scale = float(g[1]) / aabb.size.x
	gun_grip = info.grip
	gun = Node3D.new()
	gun.name = "weapon"
	skel.add_child(gun)
	gun.add_child(model)
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		mi.layers = 2
		var m := _mat(2, Color("26292e"), null)
		m.set_shader_parameter("roughness", 0.35)
		mi.material_override = m
	var muzzle := Marker3D.new()
	muzzle.name = "muzzle"
	var mx := aabb.end.x if gun_sign > 0 else aabb.position.x
	muzzle.position = Vector3(mx, aabb.get_center().y + aabb.size.y * 0.2, aabb.get_center().z)
	gun.add_child(muzzle)
	var pivot := gun
	set_meta("j", {"weapon": pivot, "muzzle": muzzle})


## Bounds of a gun model in its own space, which end is the barrel (the thinner end), and where
## the hand grips it (behind the magazine, toward the bottom of the receiver).
static func _gun_measure(nm: String, model: Node3D) -> Dictionary:
	if _gun_info.has(nm):
		return _gun_info[nm]
	var pts := PackedVector3Array()
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var xf := model.global_transform.affine_inverse() * mi.global_transform if mi.is_inside_tree() else _rel(model, mi)
		for s in mi.mesh.get_surface_count():
			for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				pts.append(xf * v)
	var aabb := AABB(pts[0], Vector3.ZERO)
	for p in pts:
		aabb = aabb.expand(p)
	var lo := aabb.position.x + aabb.size.x * 0.1
	var hi := aabb.end.x - aabb.size.x * 0.1
	var ext_lo := Vector2(INF, -INF)
	var ext_hi := Vector2(INF, -INF)
	for p in pts:
		if p.x < lo:
			ext_lo = Vector2(minf(ext_lo.x, p.y), maxf(ext_lo.y, p.y))
		elif p.x > hi:
			ext_hi = Vector2(minf(ext_hi.x, p.y), maxf(ext_hi.y, p.y))
	var sgn := 1.0 if (ext_hi.y - ext_hi.x) < (ext_lo.y - ext_lo.x) else -1.0
	var rear := aabb.position.x if sgn > 0 else aabb.end.x
	var short := aabb.size.x < aabb.size.y * 2.2   # pistols: grip near the back
	var gx := rear + sgn * aabb.size.x * (0.18 if short else 0.3)
	var info := {"aabb": aabb, "sign": sgn, "grip": Vector3(gx, aabb.position.y + aabb.size.y * 0.55, aabb.get_center().z)}
	_gun_info[nm] = info
	return info


static func _rel(root: Node3D, n: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf


# --- animation state --------------------------------------------------------------------

func _process(delta: float) -> void:
	_drop_gun(delta)
	if anim == null or not is_visible_in_tree():
		return
	var p := global_position
	var v := Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length() / maxf(delta, 0.001)
	_last_pos = p
	_speed = lerpf(_speed, v, minf(1.0, delta * 12.0))
	var ht: float = get_meta("hit_t", 9.0)
	if ht < _last_hit and float(get_meta("hit_amp", 0.0)) >= 1.0 and not get_meta("fallen", false):
		play_once("hit_rifle", 0.05)
	_last_hit = ht
	if not hold_state:
		_pick(false)


func _pick(now: bool) -> void:
	if get_meta("fallen", false):
		return
	if _oneshot != "":
		if anim.is_playing() and anim.current_animation == _oneshot:
			return
		_oneshot = ""
	var w := gun_kind
	var serious := int(get_meta("wound", 0)) >= Combatant.Wound.SERIOUS
	var clip := "%s_idle" % w
	if float(get_meta("slump_goal", 0.0)) > 0.5:
		clip = "dying"
	elif Time.get_ticks_msec() < _perform_until:
		clip = _perform
	elif Time.get_ticks_msec() < _duck_until:   # dodge: a snap down into the crouch, rifle still up
		clip = w + "_crouch"
	elif get_meta("walk", false):
		clip = "injured_walk" if serious else w + ("_sprint" if get_meta("run", false) else "_run")
	elif get_meta("jack", false):
		clip = "jack"
	elif float(get_meta("aim", 0.0)) > 0.3:   # always standing: a crouched muzzle would fire into the cover (owner)
		clip = w + "_aim"
	elif float(get_meta("crouch_goal", 0.0)) > 0.5:
		clip = w + "_crouch"
	elif get_meta("calm", false):
		clip = ["idle_look", "idle_phone", "idle_shift", "idle_talk"][index % 4]
	elif serious:
		clip = "injured_idle"
	if clip != state:
		var quick: bool = clip.ends_with("_crouch") and Time.get_ticks_msec() < _duck_until or state.ends_with("_crouch") and _duck_until > 0
		state = clip
		anim.play(clip, 0.0 if now else (0.07 if quick else 0.18))
		if now:   # desync idles between units
			anim.seek(fmod(index * 0.73, anim.current_animation_length), true)
	var native: float = CharAnims.speed.get(clip, 0.0)
	anim.speed_scale = clampf(ground_speed() / native, 0.4, 2.5) if native > 0.0 and get_meta("walk", false) else 1.0


## Ground speed in the body's own metres per second (world speed over the drawn body scale), so
## the stride matches the ground covered.
func ground_speed() -> float:
	return _speed / (scale.x * SCALE)


func _arm_ik(side: String, target: Node3D) -> TwoBoneIK3D:
	var ik := TwoBoneIK3D.new()
	ik.setting_count = 1
	ik.set_root_bone_name(0, side + "UpperArm")
	ik.set_middle_bone_name(0, side + "LowerArm")
	ik.set_end_bone_name(0, side + "Hand")
	skel.add_child(ik)
	ik.set_target_node(0, ik.get_path_to(target))
	ik.influence = 0.0
	return ik


## World position of the middle of the face in the current pose.
func head_point() -> Vector3:
	var h := skel.find_bone("Head")
	return skel.global_transform * (skel.get_bone_global_pose(h) * Vector3(0, 0.09, 0.03))


## Freeze on one frame of a clip (portrait studio).
func pose_still(clip: String, at: float) -> void:
	set_process(false)   # call after the model is in the tree
	state = clip
	anim.play(clip)
	anim.seek(at, true)
	anim.pause()


## Hold a (looping) clip for `secs`, e.g. CPR while stabilizing; then back to the state picker.
func perform(clip: String, secs: float) -> void:
	if not anim.has_animation(clip):
		return
	_perform = clip
	_perform_until = Time.get_ticks_msec() + int(secs * 1000.0)


## Dodge (owner: the dodging clips read as steps or runs): duck into the crouch for `secs`.
func duck(secs := 0.5) -> void:
	_duck_until = Time.get_ticks_msec() + int(secs * 1000.0)


func play_once(clip: String, blend := 0.1) -> void:
	if not anim.has_animation(clip):
		return
	_oneshot = clip
	anim.play(clip, blend)


## Death: a clip chosen by where the shot came from (front, back or side; headshots and
## crouched bodies have their own). The body stays on the clip's last frame.
func die(dir: Vector3, head := false, instant := false) -> void:
	var local := global_transform.basis.inverse() * Vector3(dir.x, 0, dir.z)
	var clip := "death_front"
	if float(get_meta("crouch", get_meta("crouch_goal", 0.0))) > 0.5 or state == "dying":   # from a crouch or a knee
		clip = "death_crouch"
	elif local.x > absf(local.z) * 1.4:   # round travelling toward the body's left (+X): shot from the right
		clip = "death_side"
	elif local.z > 0.0:   # the round travels the way the body faces: shot from behind, falls forward
		clip = "death_head_back" if head else "death_back"
	elif head:
		clip = "death_head"
	else:
		clip = "death_front"
	if gun and gun.get_parent() == skel:   # the gun stays as it was in the hand while the body goes down
		_gun_rel = skel.get_bone_global_pose(skel.find_bone("RightHand")).affine_inverse() * gun.transform
	set_meta("fallen", true)
	_oneshot = clip
	state = clip
	anim.speed_scale = 1.0
	anim.play(clip, 0.0 if instant else 0.22)   # a longer blend: no jump from the hit pose
	if instant:
		anim.seek(anim.current_animation_length, true)


const STOW_CLIPS := ["idle_look", "idle_phone", "idle_talk", "idle_shift", "jack", "medtech",
	"melee", "melee_blade", "grenade", "injured_idle", "injured_walk", "injured_run", "dying", "hit_a", "hit_b"]


func _stowed() -> bool:
	return state in STOW_CLIPS and not get_meta("fallen", false)


## Seat the gun for the current pose (called by Pose after the clip and recoil are applied).
func place_gun(s: Skeleton3D) -> void:
	if gun == null or gun.get_parent() != s:
		return   # dropped
	var alive: bool = not get_meta("fallen", false)
	if _ik:
		var want := 1.0 if gun_kind == "pistol" and state in PISTOL_GRIP_CLIPS and alive else 0.0
		_ik.influence = move_toward(_ik.influence, want, 0.15)
		_support.position = gun_grip + Vector3(0.0, -0.035, -gun_sign * 0.075) / gun_scale   # left wrist: beside and under the grip
		_ik_r.influence = move_toward(_ik_r.influence, 1.0 if gun_kind == "rifle" and state in ANCHOR_CLIPS and alive else 0.0, 0.15)
	var rh_pose := s.get_bone_global_pose(s.find_bone("RightHand"))
	var chest := s.get_bone_global_pose(s.find_bone("UpperChest"))
	# reloads: a rifle holds still against the chest (the right hand follows it by IK) while the
	# left hand swaps the magazine; a pistol stays in the right hand
	var anchor := Transform3D.IDENTITY.interpolate_with(chest, float(ANCHOR_CHEST.get(state, 0.3))) if gun_kind == "rifle" else rh_pose
	if state not in ANCHOR_CLIPS:
		_anchored = ""
	if _gun_rel != null:
		gun.transform = rh_pose * (_gun_rel as Transform3D)
		return
	if _anchored != "":
		gun.transform = anchor * _anchor_rel
		return
	if _stowed():   # hands busy with something else: rifles slung flat across the back, pistols holstered
		var holder := s.get_bone_global_pose(s.find_bone("UpperChest" if gun_kind == "rifle" else "Hips"))
		var sf := Vector3(-0.7, 0.71, 0.0).normalized() if gun_kind == "rifle" else Vector3(0, -1, 0.15).normalized()
		var su := Vector3(0.71, 0.7, 0.0).normalized() if gun_kind == "rifle" else Vector3(-1, 0, 0)   # side of the gun against the back
		var sr := sf.cross(su).normalized()
		var at := Vector3(0.0, -0.06, -0.15) if gun_kind == "rifle" else Vector3(-0.19, -0.02, 0.0)
		var lb := Basis(sf * gun_sign, su, sr * gun_sign).scaled(Vector3.ONE * gun_scale)
		var local := Transform3D(lb, at - lb * gun_grip)
		gun.transform = holder * local
		return
	var rh := s.find_bone("RightHand")
	var lh := s.find_bone("LeftHand")
	var r := s.get_bone_global_pose(rh)
	var grip := r * PALM
	var fwd := Vector3.ZERO
	var up := Vector3.UP
	if gun_kind == "rifle" and lh >= 0 and not get_meta("fallen", false):
		var d := s.get_bone_global_pose(lh) * PALM - grip
		if d.length() > 0.12 and d.length() < 0.8:
			fwd = d.normalized()
			up = (Vector3.UP - fwd * fwd.dot(Vector3.UP)).normalized()
	if fwd == Vector3.ZERO:   # one hand: the barrel follows the forearm (the fingers curl round the grip)
		var b := r.basis.orthonormalized()
		var fore := r.origin - s.get_bone_global_pose(s.find_bone("RightLowerArm")).origin
		fwd = fore.normalized() if fore.length() > 0.01 else b.y
		var thumb := (b.x - fwd * fwd.dot(b.x)).normalized()
		var level := (Vector3.UP - fwd * fwd.dot(Vector3.UP)).normalized()
		up = level if level.dot(thumb) > -0.3 else thumb   # held upright, not canted with the wrist (owner); thumb only when it's upside down
		fwd = fwd.rotated(fwd.cross(up).normalized(), GRIP_TILT * 0.4).normalized()   # muzzle a touch above the wrist line
		up = (up - fwd * fwd.dot(up)).normalized()
	var aim_w := clampf(float(get_meta("aim", 0.0)), 0.0, 1.0)
	if aim_w > 0.01 and has_meta("aim_at"):   # while aiming, the barrel points at the aim point, so tracers leave along it
		var ad := (s.global_transform.affine_inverse() * (get_meta("aim_at") as Vector3) - grip).normalized()
		fwd = fwd.slerp(ad, aim_w).normalized()
		up = (Vector3.UP - fwd * fwd.dot(Vector3.UP)).normalized()
	var right := fwd.cross(up).normalized()
	up = right.cross(fwd)
	var gb := Basis(fwd * gun_sign, up, right * gun_sign).scaled(Vector3.ONE * gun_scale)
	gun.transform = Transform3D(gb, grip - gb * gun_grip)
	if state.begins_with("death"):   # first frame of a death: the gun stays as it is in the hand until it falls
		_gun_rel = rh_pose.affine_inverse() * gun.transform
	if state in ANCHOR_CLIPS:   # first frame: keep the gun as it was last held normally (else where the hands have it)
		_anchored = state
		var held: Transform3D = (_ready_chest as Transform3D) * (_ready_rel as Transform3D) if _ready_rel != null and gun_kind == "rifle" else gun.transform
		_anchor_rel = anchor.affine_inverse() * held
	elif gun_kind == "rifle" and state.begins_with("rifle_") and not state.begins_with("rifle_reload"):
		_ready_rel = chest.affine_inverse() * gun.transform   # the last ordinary two-handed hold, relative to the chest
		_ready_chest = chest


## Swap the carried gun's model (review tools; later, weapon switching).
func set_weapon(weapon: String) -> void:
	if gun:
		for mk in [_support, _grip_mark]:
			if mk and mk.get_parent() == gun:
				gun.remove_child(mk)
		gun.queue_free()
	_gun_rel = null
	_anchored = ""
	_ready_rel = null
	_add_gun(weapon)
	for mk in [_support, _grip_mark]:
		if mk:
			gun.add_child(mk)
	if _grip_mark:
		_grip_mark.position = gun_grip


## Put a dropped gun back in the hands (review tools play deaths and then other clips).
func reset_gun() -> void:
	if gun and gun.get_parent() != skel:
		gun.get_parent().remove_child(gun)
		skel.add_child(gun)
	_gun_rel = null
	_dropping = false
	_death_t = -1.0


## Deaths: shortly after the body starts to go, the gun leaves the hand, falls with a little spin
## and lands on its side by the body (owner: it twisted unnaturally while held).
func _drop_gun(delta: float) -> void:
	if gun == null or not is_instance_valid(gun):
		return
	if not state.begins_with("death"):
		_death_t = -1.0
		return
	_death_t = maxf(_death_t, 0.0) + delta
	if _death_t > 0.3 and gun.get_parent() == skel:
		var gx := gun.global_transform
		gun.get_parent().remove_child(gun)
		add_child(gun)
		gun.global_transform = gx
		var away := -global_transform.basis.z.normalized()
		_drop_v = away * 0.25 + Vector3(randf_range(-0.2, 0.2), 0.4, randf_range(-0.2, 0.2))
		_drop_w = Vector3(randf_range(-6, 6), randf_range(-4, 4), randf_range(-6, 6))
		_dropping = true
	if not _dropping:
		return
	var floor_y := global_position.y + 0.025
	var g := gun.global_transform
	_drop_v.y -= 7.0 * delta
	g.origin += _drop_v * delta
	var sc := g.basis.get_scale()
	var rb := g.basis.orthonormalized()
	if _drop_w.length() > 0.01:
		rb = Basis(_drop_w.normalized(), _drop_w.length() * delta) * rb
	if g.origin.y <= floor_y:   # landed: lie on its side, along the way it was pointing
		var f := Vector3(rb.x.x, 0, rb.x.z).normalized() if Vector2(rb.x.x, rb.x.z).length() > 0.01 else Vector3.RIGHT
		rb = Basis(f, Vector3.UP.cross(f), Vector3.UP)
		g.origin.y = floor_y
		_dropping = false
	gun.global_transform = Transform3D(rb.scaled(sc), g.origin)


## Procedural layer after the clip: recoil climbs the chest and kicks the arms; hits jolt the
## upper body away from the shot and spring back.
class Pose extends SkeletonModifier3D:
	var model: CharModel

	func _process_modification() -> void:
		var s := get_skeleton()
		if s == null or model == null:
			return
		var rc: float = model.get_meta("recoil", 0.0)
		var kick: float = model.get_meta("recoil_kick", 0.0)
		var ht: float = model.get_meta("hit_t", 9.0)
		var env := exp(-ht * 9.0) * sin(minf(ht * 26.0, PI * 2.5)) * float(model.get_meta("hit_amp", 0.0)) if ht < 0.6 else 0.0
		var hd: Vector3 = model.get_meta("hit_dir", Vector3.ZERO)
		var lh := Vector3.ZERO
		if hd.length() > 0.01:
			lh = model.global_transform.basis.inverse() * Vector3(hd.x, 0, hd.z).normalized()
		var pitch := -(rc * 0.8 + kick * 0.05) + lh.z * 0.3 * env
		var roll := -lh.x * 0.3 * env
		if absf(pitch) + absf(roll) < 0.0001:
			model.place_gun(s)
			return
		for b in ["Chest", "UpperChest"]:
			var i := s.find_bone(b)
			if i >= 0:
				s.set_bone_pose_rotation(i, s.get_bone_pose_rotation(i) * Quaternion.from_euler(Vector3(pitch * 0.5, 0, roll * 0.5)))
		model.place_gun(s)
