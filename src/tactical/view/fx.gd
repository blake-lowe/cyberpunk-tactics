class_name Fx
extends Node3D
## Combat juice, all code-generated (spec: minimal high-impact VFX integrated with lighting):
## muzzle flash with a real light, tracers, spark / blood / debris bursts, dust, a blood pool,
## camera shake. Everything is short-lived and frees itself. Times are in seconds.

var shake := 0.0      ## legacy world shake (unused; the view shakes in screen space)
var rng := RandomNumberGenerator.new()   ## presentation-only randomness, seeded per gig (repeatable captures)
var _flashes: Array[Node3D] = []         ## live muzzle flashes, aged by rendered frames


func _unlit(col: Color, glow := 1.0, alpha := 1.0) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = Color(col * glow, alpha)
	if alpha < 1.0:
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mt


func _fade_free(n: Node3D, secs: float, prop := "scale", to: Variant = Vector3.ZERO) -> void:
	var tw := create_tween()
	tw.tween_property(n, prop, to, secs)
	tw.tween_callback(n.queue_free)


## Muzzle flash per weapon class (owner: realistically large, very short-lived, weapon-specific).
## size: overall scale (world units); cone: forward plume length factor; prongs: side petals
## (muzzle-brake jets) count; wide: cone spread; light: pop energy and range; smoke: puff count.
const FLASH := {
	"medium_pistol": {"size": 0.27, "cone": 1.0, "prongs": 4, "wide": 0.5, "light": 7.8, "range": 5.95, "smoke": 1},
	"heavy_pistol": {"size": 0.34, "cone": 1.1, "prongs": 4, "wide": 0.55, "light": 10.4, "range": 6.8, "smoke": 1},
	"very_heavy_pistol": {"size": 0.41, "cone": 1.2, "prongs": 5, "wide": 0.6, "light": 13, "range": 7.65, "smoke": 2},
	"smg": {"size": 0.34, "cone": 1.3, "prongs": 3, "wide": 0.4, "light": 7.8, "range": 5.95, "smoke": 1},
	"heavy_smg": {"size": 0.39, "cone": 1.3, "prongs": 3, "wide": 0.45, "light": 9.1, "range": 6.8, "smoke": 1},
	"assault_rifle": {"size": 0.51, "cone": 1.6, "prongs": 3, "wide": 0.35, "light": 13, "range": 8.5, "smoke": 2},
	"shotgun": {"size": 0.68, "cone": 1.1, "prongs": 6, "wide": 1.0, "light": 16.9, "range": 9.35, "smoke": 3, "pellets": 9},
	"sniper_rifle": {"size": 0.77, "cone": 2.0, "prongs": 2, "wide": 0.3, "light": 18.2, "range": 10.2, "smoke": 3, "brake": true},
	"grenade_launcher": {"size": 0.65, "cone": 0.8, "prongs": 0, "wide": 0.8, "light": 10.4, "range": 7.65, "smoke": 4},
	"rocket_launcher": {"size": 0.77, "cone": 1.4, "prongs": 0, "wide": 0.7, "light": 15.6, "range": 10.2, "smoke": 6, "backblast": true},
}
const BALLISTIC_SPEED := 70.0   # world units/s: fast enough to read as a streak, not a beam


func _add_mat(col: Color, glow: float) -> StandardMaterial3D:
	var mt := _unlit(col, glow)
	mt.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mt


## A flash that exists for two or three frames: a white-hot core, a forward plume (cone), side
## petals at a random roll, scaled and jittered per shot; a strong, short light pop; then smoke.
func muzzle(at: Vector3, dir: Vector3, weapon := "assault_rifle", light: OmniLight3D = null, core_on := true) -> void:
	var p: Dictionary = FLASH.get(weapon, {})
	if p.is_empty():
		return   # bows, melee: no flash
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var root := Node3D.new()
	add_child(root)
	root.global_position = at
	root.look_at(at + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)   # -Z points along the shot
	root.rotate_object_local(Vector3.FORWARD, rng.randf() * TAU)
	var s: float = float(p.size) * rng.randf_range(0.8, 1.25)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	sm.material = _add_mat(Color("fff6d8"), 1.4)
	core.mesh = sm
	core.scale = Vector3.ONE * s * 0.45
	core.visible = core_on   # autofire skips the core on some rounds: the burst flickers
	root.add_child(core)
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.5
	cm.height = 1.0
	cm.radial_segments = 7
	cm.rings = 1
	cm.material = _add_mat(Color("ffb040"), 1.1)
	cone.mesh = cm
	var cl: float = s * float(p.cone) * rng.randf_range(0.8, 1.2)
	cone.scale = Vector3(s * float(p.wide), cl, s * float(p.wide))
	cone.rotation = Vector3(-PI / 2, 0, 0)   # cylinder +Y → the shot direction (-Z)
	cone.position = Vector3(0, 0, -cl * 0.5)
	root.add_child(cone)
	var n: int = int(p.prongs)
	var brake: bool = p.get("brake", false)
	for i in n:
		var pet := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.0, 1.0, 1.0)
		bm.material = _add_mat(Color("ffcf70"), 1.1)
		pet.mesh = bm
		var ang := TAU * i / n + rng.randf_range(-0.3, 0.3)
		var length := s * rng.randf_range(0.45, 0.8) * (1.4 if brake else 1.0)
		var out := Vector3(cos(ang), sin(ang), 0.05 if brake else -0.25).normalized()
		pet.basis = Basis.looking_at(out, Vector3.FORWARD if absf(out.z) < 0.99 else Vector3.UP).scaled_local(Vector3(0.06, 0.06, length))   # ≥1 buffer px thick
		pet.position = out * length * 0.5
		root.add_child(pet)
	if p.get("backblast", false):
		var bb := MeshInstance3D.new()
		bb.mesh = cm
		bb.scale = Vector3(s * 1.2, s * 1.6, s * 1.2)
		bb.rotation = Vector3(PI / 2, 0, 0)
		bb.position = Vector3(0, 0, s * 1.6)
		root.add_child(bb)
	root.set_meta("age", 0)   # frame-aged: full size on frame 1, half on frame 2, gone on frame 3
	_flashes.append(root)
	# light pop: the shooter's pooled light if given (stacking one light per round hits the
	# compatibility renderer's per-object light limit), lights the world only, not the bodies
	var l := light
	if l == null:
		l = OmniLight3D.new()
		add_child(l)
		get_tree().create_timer(0.2).timeout.connect(l.queue_free)
	l.light_color = Color("ffb050")
	l.light_cull_mask = 1
	l.omni_range = float(p.range)
	l.global_position = at + dir * (s * 0.4 + 0.3)
	l.light_energy = float(p.light)
	var tl := create_tween()   # a hard pop, then a short falloff the eye can catch (2-3 frames)
	tl.tween_property(l, "light_energy", 0.0, 0.1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	for k in int(p.smoke):   # soft grey puffs drifting up and out, lingering after the flash
		var puff := MeshInstance3D.new()
		var ps := SphereMesh.new()
		ps.radius = 0.5
		ps.height = 1.0
		ps.radial_segments = 6
		ps.rings = 3
		var pm := StandardMaterial3D.new()   # shaded: unshaded grey would glow at night
		pm.albedo_color = Color(0.45, 0.46, 0.5, 0.35)
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.roughness = 1.0
		ps.material = pm
		puff.mesh = ps
		add_child(puff)
		puff.global_position = at + dir * rng.randf_range(0.05, 0.3)
		puff.scale = Vector3.ONE * s * 0.3
		var drift := dir * rng.randf_range(0.1, 0.35) + Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(0.15, 0.35), rng.randf_range(-0.1, 0.1))
		var tp := create_tween()
		tp.set_parallel(true)
		tp.tween_property(puff, "global_position", puff.global_position + drift, 0.9)
		tp.tween_property(puff, "scale", Vector3.ONE * s * rng.randf_range(0.7, 1.0), 0.9)
		tp.tween_property(pm, "albedo_color:a", 0.0, 0.9)
		tp.chain().tween_callback(puff.queue_free)


## Spent casing flicked out of the ejection port.
func brass(at: Vector3, right: Vector3, floor_y := -1e9) -> void:
	var c := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.025, 0.025, 0.05)
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color("c8a040")
	mt.metallic = 0.8
	mt.roughness = 0.3
	bm.material = mt
	c.mesh = bm
	add_child(c)
	c.global_position = at
	var land := at + right * rng.randf_range(0.35, 0.6) + Vector3(rng.randf_range(-0.1, 0.1), 0, rng.randf_range(-0.1, 0.1))
	land.y = floor_y + 0.015 if floor_y > -1e8 else at.y - 0.75
	var peak := (at + land) / 2 + Vector3(0, 0.35, 0)
	var tw := create_tween()
	tw.tween_property(c, "global_position", peak, 0.12).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(c, "rotation", Vector3(rng.randf() * 6, rng.randf() * 6, 0), 0.3)
	tw.tween_property(c, "global_position", land, 0.14).set_ease(Tween.EASE_IN)
	tw.tween_interval(1.5)
	tw.tween_callback(c.queue_free)


## A ballistic round: a short, faint streak that travels muzzle → impact in a few hundredths of
## a second (not a beam). Shotguns fire a spread of pellets. Calls `on_hit` on arrival.
func bullet(a: Vector3, b: Vector3, weapon := "assault_rifle", on_hit := Callable()) -> void:
	var pellets: int = int(FLASH.get(weapon, {}).get("pellets", 1))
	for i in pellets:
		var to := b
		if pellets > 1:
			to = b + Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.35, 0.35))
		var streak := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.018, 0.018, 0.45 if pellets == 1 else 0.25)
		bm.material = _add_mat(Color("ffe2a0"), 1.1)
		streak.mesh = bm
		add_child(streak)
		streak.global_position = a
		streak.look_at(to, Vector3.UP if absf((to - a).normalized().y) < 0.99 else Vector3.RIGHT)
		var t := maxf(0.03, a.distance_to(to) / BALLISTIC_SPEED)
		var tw := create_tween()
		tw.tween_property(streak, "global_position", to, t)
		tw.tween_callback(streak.queue_free)
		if i == 0 and on_hit.is_valid():
			tw.tween_callback(on_hit)


## One-shot particle burst: sparks, blood or debris.
func burst(at: Vector3, col: Color, count: int, speed: float, size: float, life := 0.45, glow := 1.0, gravity := -9.0) -> void:
	var p := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * size
	mesh.material = _unlit(col, glow) if glow > 0.0 else StandardMaterial3D.new()
	if glow <= 0.0:
		(mesh.material as StandardMaterial3D).albedo_color = col
	p.mesh = mesh
	p.amount = count
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = life
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, gravity, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


func sparks(at: Vector3) -> void:
	burst(at, Color("ffd27a"), 14, 4.0, 0.04, 0.3, 2.0)


## A round that gets through: a spray out of the far side along the shot, a quick red mist, and
## splats that land on the floor behind the target (they stay for the rest of the gig).
## `scale` 0.4 for one round of a burst, 1 for the hit that resolves, 1.6 for crits and kills.
func blood(at: Vector3, dir: Vector3 = Vector3.ZERO, scale := 1.0, floor_y := -1e9) -> void:
	var flat := Vector3(dir.x, 0, dir.z).normalized() if Vector3(dir.x, 0, dir.z).length() > 0.01 else Vector3.FORWARD
	var p := CPUParticles3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * 0.05
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color("7a0a16")
	mt.roughness = 0.3
	mesh.material = mt
	p.mesh = mesh
	p.amount = int(28 * scale) + 4
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = 0.55
	p.direction = (flat + Vector3(0, 0.35, 0)).normalized()
	p.spread = 22.0
	p.initial_velocity_min = 2.0 * maxf(scale, 0.6)
	p.initial_velocity_max = 4.5 * maxf(scale, 0.6)
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.4
	add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)
	# mist: a soft red puff that blooms and fades in a quarter second
	var mist := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.55, 0.02, 0.06, 0.55)
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.material = mm
	mist.mesh = sm
	add_child(mist)
	mist.global_position = at + flat * 0.12
	mist.scale = Vector3.ONE * 0.12 * scale
	var tm := create_tween().set_parallel()
	tm.tween_property(mist, "scale", Vector3.ONE * 0.5 * scale, 0.25).set_ease(Tween.EASE_OUT)
	tm.tween_property(mist, "global_position", mist.global_position + flat * 0.3, 0.25)
	tm.tween_property(mm, "albedo_color:a", 0.0, 0.25)
	tm.chain().tween_callback(mist.queue_free)
	# splats on the floor behind, landing in order of distance
	if floor_y > -1e8:
		var side := flat.cross(Vector3.UP)
		for k in int(3 + 5 * scale):
			var dist := rng.randf_range(0.25, 1.5) * maxf(scale, 0.5)
			var spot := at + flat * dist + side * rng.randf_range(-0.25, 0.25) * dist
			spot.y = floor_y + 0.012 + k * 0.0004   # stacked a hair apart so splats don't z-fight
			var sz := rng.randf_range(0.08, 0.22) * (1.3 - dist / 2.5)
			get_tree().create_timer(0.08 + dist * 0.12).timeout.connect(_splat.bind(spot, sz, flat))


func _splat(at: Vector3, size: float, along: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.5
	cm.bottom_radius = 0.5
	cm.height = 0.004
	cm.radial_segments = 7
	cm.rings = 1
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color("8a0c1a")   # bright enough to read on dark floors at pixel scale
	mt.roughness = 0.15
	cm.material = mt
	mi.mesh = cm
	add_child(mi)
	mi.global_position = at
	mi.rotation.y = atan2(along.x, along.z) + rng.randf_range(-0.3, 0.3)
	var stretch := rng.randf_range(1.2, 2.2)   # elongated along the spray
	mi.scale = Vector3(size * 0.4, 1, size * 0.4 * stretch)
	create_tween().tween_property(mi, "scale", Vector3(size, 1, size * stretch), 0.12).set_ease(Tween.EASE_OUT)


func debris(at: Vector3, big := false) -> void:
	burst(at, Color("6a6e73"), 24 if big else 10, 3.5 if big else 2.2, 0.09 if big else 0.06, 0.7, 0.0)
	burst(at + Vector3(0, 0.1, 0), Color("8a8478"), 12 if big else 5, 0.8, 0.22, 1.1, 0.0, 0.6)   # dust puffs


## A dark pool that spreads under a body.
func pool(at: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.5
	cm.bottom_radius = 0.5
	cm.height = 0.01
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color("3a0408")
	mt.roughness = 0.1
	cm.material = mt
	mi.mesh = cm
	add_child(mi)
	mi.global_position = at + Vector3(0, 0.015, 0)
	mi.scale = Vector3(0.05, 1, 0.05)
	create_tween().tween_property(mi, "scale", Vector3(0.9, 1, 0.7), 1.6).set_ease(Tween.EASE_OUT)


func kick(amount: float) -> void:
	shake = maxf(shake, amount)


func _process(_delta: float) -> void:
	for f in _flashes.duplicate():
		if not is_instance_valid(f):
			_flashes.erase(f)
			continue
		var age: int = f.get_meta("age") + 1
		f.set_meta("age", age)
		if age == 2:
			f.scale = Vector3.ONE * 0.5
		elif age >= 3:
			_flashes.erase(f)
			f.queue_free()
