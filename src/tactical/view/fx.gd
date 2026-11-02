class_name Fx
extends Node3D
## Combat juice, all code-generated (spec: minimal high-impact VFX integrated with lighting):
## muzzle flash with a real light, tracers, spark / blood / debris bursts, dust, a blood pool,
## camera shake. Everything is short-lived and frees itself. Times are in seconds.

var shake := 0.0      ## current camera shake amplitude (world units); the view applies and decays it


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


## Muzzle flash: a hot star at the barrel plus a short-lived orange light that lights the scene.
func muzzle(at: Vector3, dir: Vector3, col := Color("ffd27a")) -> void:
	var star := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 0.16, 0.3)
	bm.material = _unlit(col, 2.0)
	star.mesh = bm
	add_child(star)
	star.global_position = at
	if dir.length() > 0.01:
		star.look_at(at + dir, Vector3.UP)
	star.rotate_object_local(Vector3.FORWARD, randf() * TAU)
	_fade_free(star, 0.07)
	var l := OmniLight3D.new()
	l.light_color = Color("ffb050")
	l.light_energy = 4.0
	l.omni_range = 4.5
	add_child(l)
	l.global_position = at
	var tw := create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.12)
	tw.tween_callback(l.queue_free)


## A bright streak from a to b that fades.
func tracer(a: Vector3, b: Vector3, col := Color("fff0b0")) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var span := a.distance_to(b)
	bm.size = Vector3(0.035, 0.035, span)
	bm.material = _unlit(col, 1.8)
	mi.mesh = bm
	add_child(mi)
	mi.global_position = (a + b) / 2
	mi.look_at(b, Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT)
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3(0.2, 0.2, 1.0), 0.12)
	tw.tween_callback(mi.queue_free)


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


func blood(at: Vector3, heavy := false) -> void:
	burst(at, Color("8a0f1e"), 18 if heavy else 10, 2.6 if heavy else 1.8, 0.06, 0.5, 0.0)


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
