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


## Muzzle flash per weapon class (owner: realistically large, very short-lived, weapon-specific).
## size: overall scale (world units); cone: forward plume length factor; prongs: side petals
## (muzzle-brake jets) count; wide: cone spread; light: pop energy and range; smoke: puff count.
const FLASH := {
	"medium_pistol": {"size": 0.32, "cone": 1.0, "prongs": 4, "wide": 0.5, "light": 3.0, "range": 3.5, "smoke": 1},
	"heavy_pistol": {"size": 0.42, "cone": 1.1, "prongs": 4, "wide": 0.55, "light": 4.0, "range": 4.0, "smoke": 1},
	"very_heavy_pistol": {"size": 0.55, "cone": 1.2, "prongs": 5, "wide": 0.6, "light": 5.0, "range": 4.5, "smoke": 2},
	"smg": {"size": 0.36, "cone": 1.3, "prongs": 3, "wide": 0.4, "light": 3.0, "range": 3.5, "smoke": 1},
	"heavy_smg": {"size": 0.44, "cone": 1.3, "prongs": 3, "wide": 0.45, "light": 3.5, "range": 4.0, "smoke": 1},
	"assault_rifle": {"size": 0.62, "cone": 1.6, "prongs": 3, "wide": 0.35, "light": 5.0, "range": 5.0, "smoke": 2},
	"shotgun": {"size": 0.8, "cone": 1.1, "prongs": 6, "wide": 1.0, "light": 6.5, "range": 5.5, "smoke": 3, "pellets": 9},
	"sniper_rifle": {"size": 0.95, "cone": 2.0, "prongs": 2, "wide": 0.3, "light": 7.0, "range": 6.0, "smoke": 3, "brake": true},
	"grenade_launcher": {"size": 0.7, "cone": 0.8, "prongs": 0, "wide": 0.8, "light": 4.0, "range": 4.5, "smoke": 4},
	"rocket_launcher": {"size": 0.9, "cone": 1.4, "prongs": 0, "wide": 0.7, "light": 6.0, "range": 6.0, "smoke": 6, "backblast": true},
}
const BALLISTIC_SPEED := 70.0   # world units/s: fast enough to read as a streak, not a beam


func _add_mat(col: Color, glow: float) -> StandardMaterial3D:
	var mt := _unlit(col, glow)
	mt.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mt


## A flash that exists for two or three frames: a white-hot core, a forward plume (cone), side
## petals at a random roll, scaled and jittered per shot; a strong, short light pop; then smoke.
func muzzle(at: Vector3, dir: Vector3, weapon := "assault_rifle") -> void:
	var p: Dictionary = FLASH.get(weapon, {})
	if p.is_empty():
		return   # bows, melee: no flash
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var root := Node3D.new()
	add_child(root)
	root.global_position = at
	root.look_at(at + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT)   # -Z points along the shot
	root.rotate_object_local(Vector3.FORWARD, randf() * TAU)
	var s: float = float(p.size) * randf_range(0.8, 1.25)
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	sm.material = _add_mat(Color("fff6d8"), 3.0)
	core.mesh = sm
	core.scale = Vector3.ONE * s * 0.45
	root.add_child(core)
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.5
	cm.height = 1.0
	cm.radial_segments = 7
	cm.rings = 1
	cm.material = _add_mat(Color("ffb040"), 2.2)
	cone.mesh = cm
	var cl: float = s * float(p.cone) * randf_range(0.8, 1.2)
	cone.scale = Vector3(s * float(p.wide), cl, s * float(p.wide))
	cone.rotation = Vector3(-PI / 2, 0, 0)   # cylinder +Y → the shot direction (-Z)
	cone.position = Vector3(0, 0, -cl * 0.5)
	root.add_child(cone)
	var n: int = int(p.prongs)
	var brake: bool = p.get("brake", false)
	for i in n:
		var pet := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.07, 0.07, 1.0)
		bm.material = _add_mat(Color("ffcf70"), 2.0)
		pet.mesh = bm
		var ang := TAU * i / n + randf_range(-0.3, 0.3)
		var length := s * randf_range(0.45, 0.8) * (1.4 if brake else 1.0)
		var out := Vector3(cos(ang), sin(ang), 0.05 if brake else -0.25).normalized()
		pet.basis = Basis.looking_at(out, Vector3.FORWARD if absf(out.z) < 0.99 else Vector3.UP).scaled_local(Vector3(s * 0.9, s * 0.9, length))
		pet.position = out * length * 0.5
		root.add_child(pet)
	if p.get("backblast", false):
		var bb := MeshInstance3D.new()
		bb.mesh = cm
		bb.scale = Vector3(s * 1.2, s * 1.6, s * 1.2)
		bb.rotation = Vector3(PI / 2, 0, 0)
		bb.position = Vector3(0, 0, s * 1.6)
		root.add_child(bb)
	var tw := create_tween()   # alive for ~2-3 frames, with a size pop
	tw.tween_property(root, "scale", Vector3.ONE * 1.15, 0.025)
	tw.tween_property(root, "scale", Vector3.ONE * 0.4, 0.025)
	tw.tween_callback(root.queue_free)
	var l := OmniLight3D.new()
	l.light_color = Color("ffb050")
	l.light_energy = float(p.light)
	l.omni_range = float(p.range)
	add_child(l)
	l.global_position = at + dir * s * 0.4
	var tl := create_tween()
	tl.tween_property(l, "light_energy", 0.0, 0.07)
	tl.tween_callback(l.queue_free)
	for k in int(p.smoke):   # soft grey puffs drifting up and out, lingering after the flash
		var puff := MeshInstance3D.new()
		var ps := SphereMesh.new()
		ps.radius = 0.5
		ps.height = 1.0
		ps.radial_segments = 6
		ps.rings = 3
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.55, 0.56, 0.6, 0.35)
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ps.material = pm
		puff.mesh = ps
		add_child(puff)
		puff.global_position = at + dir * randf_range(0.05, 0.3)
		puff.scale = Vector3.ONE * s * 0.3
		var drift := dir * randf_range(0.1, 0.35) + Vector3(randf_range(-0.1, 0.1), randf_range(0.15, 0.35), randf_range(-0.1, 0.1))
		var tp := create_tween()
		tp.set_parallel(true)
		tp.tween_property(puff, "global_position", puff.global_position + drift, 0.9)
		tp.tween_property(puff, "scale", Vector3.ONE * s * randf_range(0.7, 1.0), 0.9)
		tp.tween_property(pm, "albedo_color:a", 0.0, 0.9)
		tp.chain().tween_callback(puff.queue_free)


## Spent casing flicked out of the ejection port.
func brass(at: Vector3, right: Vector3) -> void:
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
	var land := at + right * randf_range(0.35, 0.6) + Vector3(randf_range(-0.1, 0.1), 0, randf_range(-0.1, 0.1))
	land.y = at.y - 0.75
	var peak := (at + land) / 2 + Vector3(0, 0.35, 0)
	var tw := create_tween()
	tw.tween_property(c, "global_position", peak, 0.12).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(c, "rotation", Vector3(randf() * 6, randf() * 6, 0), 0.3)
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
			to = b + Vector3(randf_range(-0.35, 0.35), randf_range(-0.2, 0.2), randf_range(-0.35, 0.35))
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
