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
	var ws := WeaponFx.spec(weapon)   # data/gen/weapon_fx.json: what this weapon's shot is
	_snd(WeaponFx.shot_sound(weapon), at, float(ws.get("vol", 0.0)), 0.05, 30)
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	if String(ws.visual) != "gun":
		_launch(at, dir, ws, light)   # the non-firearm discharge: a puff, a glow, a spark, a backblast
	var p: Dictionary = FLASH.get(String(ws.get("flash", weapon)), {})
	if p.is_empty():
		return   # bows, air, beams, sonics, melee: no muzzle flash
	p = p.duplicate()
	p.size = float(p.size) * float(ws.get("flash_scale", 1.0))
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
	_snd("sfx_brass", at, -16.0, 0.15, 60)
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
	var ws := WeaponFx.spec(weapon)
	if String(ws.visual) != "gun":
		_projectile_for(a, b, ws, on_hit)   # arrows, darts, beams, flame, rails...
		return
	var pellets: int = int(FLASH.get(String(ws.get("flash", weapon)), {}).get("pellets", 1))
	var tint := Color(String(ws.get("col", "ffe2a0")))
	for i in pellets:
		var to := b
		if pellets > 1:
			to = b + Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.2, 0.2), rng.randf_range(-0.35, 0.35))
		var streak := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.018, 0.018, 0.45 if pellets == 1 else 0.25)
		bm.material = _add_mat(tint, 1.1)
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


## A lock being worked: a crackle of cyan sparks and a short white flash (or a red buzz on a loud fail).
func lock_crackle(at: Vector3, ok: bool) -> void:
	_snd("sfx_zap", at, -4.0)
	var col := Color("6ff4ff") if ok else Color("ff3048")
	burst(at, col, 14, 1.6, 0.025, 0.35, 3.0, -4.0)
	burst(at, Color.WHITE, 4, 0.8, 0.02, 0.18, 4.0, 0.0)


## NET work on a device (a Control Node taken, a device switched): a puff of violet data bits off
## its lamp, rising, and a short white tick.
func net_take(at: Vector3) -> void:
	burst(at, Color("d68cff"), 12, 1.2, 0.03, 0.55, 3.0, 1.2)
	burst(at, Color.WHITE, 3, 0.5, 0.02, 0.15, 4.0, 0.0)


## A camera feed patched through (or looped: `looped` adds a red-green glitch): a flat cyan frame
## that blinks open over the lens and a scatter of scan bits.
func feed(at: Vector3, looped := false) -> void:
	var fr := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.34, 0.22, 0.01)
	fr.mesh = bm
	fr.material_override = _unlit(Color("39d8ff"), 2.0, 0.35)
	fr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fr)
	fr.global_position = at + Vector3(0, 0.15, 0)
	fr.scale = Vector3(0.1, 1.0, 1.0)
	var tw := create_tween()
	tw.tween_property(fr, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(fr, "scale", Vector3(1.0, 0.05, 1.0), 0.3).set_delay(0.35)
	tw.tween_callback(fr.queue_free)
	burst(at, Color("39d8ff"), 8, 0.7, 0.02, 0.4, 3.0, 0.0)
	if looped:
		burst(at, Color("ff3048"), 5, 0.6, 0.02, 0.25, 3.0, 0.0)
		burst(at, Color("3cf08c"), 5, 0.6, 0.02, 0.35, 3.0, 0.0)


## A lock thrown from the NET: a burst in the lamp's new colour (red locked, green open) and a
## brief spark of white where the bolt goes.
func lock_flip(at: Vector3, locked: bool) -> void:
	var col := Color("ff2a4a") if locked else Color("3cf08c")
	burst(at, col, 10, 1.0, 0.025, 0.4, 3.0, -2.0)
	burst(at, Color.WHITE, 3, 0.4, 0.02, 0.12, 4.0, 0.0)


## Eye-Dee: a thin gold column of data rising out of the runner and a shower of gold bits (a
## bigger one on the target File).
func eye_dee(at: Vector3, target := false) -> void:
	var col := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.05, 1.0, 0.05)
	col.mesh = bm
	col.material_override = _unlit(Color("f9c80e"), 2.5, 0.6)
	col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(col)
	col.global_position = at
	col.scale = Vector3(1.0, 0.05, 1.0)
	var tw := create_tween()
	tw.tween_property(col, "scale", Vector3(1.0, 1.2, 1.0), 0.18)
	tw.parallel().tween_property(col, "position:y", col.position.y + 0.6, 0.18)
	tw.tween_property(col, "scale", Vector3(0.1, 1.4, 0.1), 0.35)
	tw.tween_callback(col.queue_free)
	burst(at + Vector3(0, 0.4, 0), Color("f9c80e"), 22 if target else 12, 1.4, 0.03, 0.7, 3.0, 0.6)


## A keycard lifted off a body: a gold glint that rises and pops.
func glint(at: Vector3) -> void:
	_snd("sfx_beep", at, -2.0)
	burst(at, Color("ffd060"), 10, 1.1, 0.02, 0.5, 3.0, 1.5)


func sparks(at: Vector3) -> void:
	_snd("sfx_ricochet", at, -7.0, 0.15, 80)
	burst(at, Color("ffd27a"), 14, 4.0, 0.04, 0.3, 2.0)


## A round that gets through: a spray out of the far side along the shot, a quick red mist, and
## splats that land on the floor behind the target (they stay for the rest of the gig).
## `scale` 0.4 for one round of a burst, 1 for the hit that resolves, 1.6 for crits and kills.
func blood(at: Vector3, dir: Vector3 = Vector3.ZERO, scale := 1.0, floor_y := -1e9) -> void:
	_snd("sfx_hit_flesh", at, -2.0, 0.1, 40)
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
	_snd("sfx_debris", at, -6.0 if not big else 0.0, 0.1, 80)
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


## A cover piece breaks apart: chunks in its material's colour burst out along the shot, tumble,
## and settle on the floor where they stay for the rest of the gig (owner: leave something behind
## instead of snapping out of existence).
const MATERIAL_COL := {"wood": Color("5a4028"), "steel": Color("5a626c"), "concrete": Color("6a6e73"),
	"stone": Color("67625b"), "plaster": Color("8a8478"), "glass": Color("9fd8ee"), "brick": Color("6a3a2c")}
var _bits: Array = []   ## falling chunks: [node, velocity, spin, floor y]


func shatter(at: Vector3, material: String, dir: Vector3, floor_y: float, big := false) -> void:
	_snd("sfx_glass_break" if material.contains("glass") else "sfx_debris", at, -2.0, 0.1, 80)
	var col: Color = MATERIAL_COL.get(material, Color("6a6e73"))
	var mt := StandardMaterial3D.new()
	mt.albedo_color = col
	mt.roughness = 0.85
	var flat := Vector3(dir.x, 0, dir.z).normalized() if Vector3(dir.x, 0, dir.z).length() > 0.01 else Vector3.FORWARD
	for k in (26 if big else 18):
		var c := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var s := rng.randf_range(0.06, 0.22) * (1.3 if big else 1.0)
		bm.size = Vector3(s, s * rng.randf_range(0.35, 0.8), s * rng.randf_range(0.6, 1.4))
		bm.material = mt
		c.mesh = bm
		add_child(c)
		c.global_position = at + Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.15, 0.2), rng.randf_range(-0.25, 0.25))
		c.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		var v := flat * rng.randf_range(0.6, 2.2) + Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(0.8, 2.4), rng.randf_range(-1.2, 1.2))
		var w := Vector3(rng.randf_range(-12, 12), rng.randf_range(-12, 12), rng.randf_range(-12, 12))
		_bits.append([c, v, w, floor_y + bm.size.y * 0.5])


## A frag grenade: an arc from the hand to the landing point over `secs`, tumbling.
func grenade_arc(a: Vector3, b: Vector3, secs: float, on_land := Callable()) -> void:
	_snd("sfx_throw", a, -3.0)
	var g := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.1
	sm.radial_segments = 6
	sm.rings = 3
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color("3a4030")
	sm.material = mt
	g.mesh = sm
	add_child(g)
	var peak := maxf(a.y, b.y) + 0.6 + a.distance_to(b) * 0.18
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var p := a.lerp(b, t)
		p.y = lerpf(a.y, b.y, t) + (peak - maxf(a.y, b.y)) * 4.0 * t * (1.0 - t) + (maxf(a.y, b.y) - lerpf(a.y, b.y, t)) * 0.0
		g.global_position = p
		g.rotation = Vector3(t * 14.0, t * 9.0, 0), 0.0, 1.0, secs)
	tw.tween_callback(func():
		g.queue_free()
		if on_land.is_valid():
			on_land.call())


## Explosion: a white-hot flash and a light pop that lights the whole area, a fireball that
## swells and cools, debris and grit, smoke that lingers, and a scorch mark that stays.
func explosion(at: Vector3, floor_y: float, light: OmniLight3D = null) -> void:
	_snd("sfx_explosion", at, 2.0, 0.05, 100)
	var l := light
	if l == null:
		l = OmniLight3D.new()
		add_child(l)
		get_tree().create_timer(0.8).timeout.connect(l.queue_free)
	l.light_color = Color("ffb060")
	l.light_cull_mask = 0xFFFFF
	l.omni_range = 9.0
	l.global_position = at + Vector3(0, 0.8, 0)
	l.light_energy = 22.0
	create_tween().tween_property(l, "light_energy", 0.0, 0.55).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 10
	sm.rings = 6
	var bm := _add_mat(Color("fff2c0"), 2.2)
	sm.material = bm
	ball.mesh = sm
	add_child(ball)
	ball.global_position = at + Vector3(0, 0.35, 0)
	ball.scale = Vector3.ONE * 0.4
	var tb := create_tween()
	tb.set_parallel(true)
	tb.tween_property(ball, "scale", Vector3.ONE * 1.9, 0.12).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tb.tween_property(bm, "albedo_color", Color("ff6a10"), 0.12)
	tb.chain().tween_property(ball, "scale", Vector3.ONE * 2.2, 0.2)
	tb.parallel().tween_property(bm, "albedo_color", Color.BLACK, 0.2)   # additive: black is invisible
	tb.chain().tween_callback(ball.queue_free)
	burst(at + Vector3(0, 0.2, 0), Color("ffd27a"), 30, 9.0, 0.05, 0.35, 2.0, -6.0)   # sparks
	burst(at + Vector3(0, 0.1, 0), Color("4a4440"), 22, 5.0, 0.08, 0.9, 0.0, -9.0)    # grit
	for k in 8:   # smoke: dark puffs rising and spreading, lingering after the fire
		var puff := MeshInstance3D.new()
		var ps := SphereMesh.new()
		ps.radius = 0.5
		ps.height = 1.0
		ps.radial_segments = 7
		ps.rings = 4
		var pm := StandardMaterial3D.new()
		pm.albedo_color = Color(0.16, 0.15, 0.15, 0.6)
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.roughness = 1.0
		ps.material = pm
		puff.mesh = ps
		add_child(puff)
		var off := Vector3(rng.randf_range(-0.9, 0.9), rng.randf_range(0.1, 0.5), rng.randf_range(-0.9, 0.9))
		puff.global_position = at + off
		puff.scale = Vector3.ONE * 0.5
		var tp := create_tween().set_parallel(true)
		tp.tween_property(puff, "global_position", at + off * 1.6 + Vector3(0, rng.randf_range(1.2, 2.2), 0), 2.6).set_delay(0.1)
		tp.tween_property(puff, "scale", Vector3.ONE * rng.randf_range(1.4, 2.2), 2.6).set_delay(0.1)
		tp.tween_property(pm, "albedo_color:a", 0.0, 2.6).set_delay(0.3)
		tp.chain().tween_callback(puff.queue_free)
	var scorch := MeshInstance3D.new()   # stays
	var cm := CylinderMesh.new()
	cm.top_radius = 0.5
	cm.bottom_radius = 0.5
	cm.height = 0.004
	cm.radial_segments = 10
	cm.rings = 1
	var sc := StandardMaterial3D.new()
	sc.albedo_color = Color(0.03, 0.025, 0.02, 0.85)
	sc.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sc.roughness = 1.0
	cm.material = sc
	scorch.mesh = cm
	add_child(scorch)
	scorch.global_position = Vector3(at.x, floor_y + 0.011, at.z)
	scorch.scale = Vector3(2.4, 1, 2.1)
	scorch.rotation.y = rng.randf() * TAU


func _settle_bits(delta: float) -> void:
	for i in range(_bits.size() - 1, -1, -1):
		var b: Array = _bits[i]
		var c: MeshInstance3D = b[0]
		if not is_instance_valid(c):
			_bits.remove_at(i)
			continue
		var v: Vector3 = b[1]
		v.y -= 9.0 * delta
		c.global_position += v * delta
		c.rotation += (b[2] as Vector3) * delta
		if c.global_position.y <= b[3]:
			if absf(v.y) > 1.2:   # one small bounce, then rest flat-ish on the floor
				c.global_position.y = b[3]
				b[1] = Vector3(v.x * 0.35, -v.y * 0.25, v.z * 0.35)
				b[2] = (b[2] as Vector3) * 0.4
				continue
			c.global_position.y = b[3]
			c.rotation = Vector3(0, c.rotation.y, 0)
			_bits.remove_at(i)
			continue
		b[1] = v


func _process(_delta: float) -> void:
	_settle_bits(_delta)
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


## Sound for an effect (AudioDirector; silent when there is none, e.g. headless tests).
func _snd(name: String, at: Vector3, vol := 0.0, pitch_var := 0.06, gap := 25) -> void:
	if AudioDirector.I and is_instance_valid(AudioDirector.I):
		AudioDirector.I.sfx(name, at, vol, pitch_var, gap)


static func _shot_sound(weapon: String) -> String:
	return WeaponFx.shot_sound(weapon)


# --- non-firearm shots (data/gen/weapon_fx.json kinds; WeaponFx resolves a weapon to one) -------

## How long the shot takes to reach `b` (the view waits this long for the impact).
func flight_secs(a: Vector3, b: Vector3, weapon: String) -> float:
	return _flight(a, b, WeaponFx.spec(weapon))


func _flight(a: Vector3, b: Vector3, ws: Dictionary) -> float:
	var d := a.distance_to(b)
	match String(ws.visual):
		"gun":
			return maxf(0.03, d / BALLISTIC_SPEED)
		"arc", "rail":
			return 0.04
		"microwave":
			return 0.1
		"lob":
			return 0.3 + d / float(ws.get("speed", 16.0))
	return maxf(0.05, d / float(ws.get("speed", 30.0)))


## Wind-up before the shot (the railgun's capacitors): a glow swelling at the muzzle and the
## charge whine, over `secs`.
func charge(at: Vector3, weapon: String, secs: float) -> void:
	var ws := WeaponFx.spec(weapon)
	var col := Color(String(ws.get("col", "a8f0ff")))
	_snd(String(ws.get("charge_sound", "sfx_rail_charge")), at, -2.0, 0.02, 0)
	var g := _ball(col, 1.6, 0.03)
	g.global_position = at
	var tw := create_tween()
	tw.tween_property(g, "scale", Vector3.ONE * 0.2, secs).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(g.queue_free)
	var l := OmniLight3D.new()
	add_child(l)
	l.light_color = col
	l.light_cull_mask = 1
	l.omni_range = 2.5
	l.global_position = at
	l.light_energy = 0.0
	var tl := create_tween()
	tl.tween_property(l, "light_energy", 3.0, secs)
	tl.tween_callback(l.queue_free)
	for k in 3:   # sparks crawling round the rails as the charge builds
		get_tree().create_timer(secs * (0.3 + 0.25 * k)).timeout.connect(burst.bind(at, col, 4, 0.8, 0.02, 0.15, 3.0, 0.0))


## A melee contact: the weapon's hit sound and what it leaves in the air (a blade arc, a blunt
## shock ring, a stun arc, a knuckle flash). `dir` is the swing's direction.
func melee_contact(at: Vector3, dir: Vector3, weapon: String) -> void:
	var ws := WeaponFx.spec(weapon)
	_snd(WeaponFx.hit_sound(weapon), at, 0.0, 0.08, 40)
	var col := Color(String(ws.get("col", "e8e0d0")))
	var flat := Vector3(dir.x, 0, dir.z).normalized() if Vector3(dir.x, 0, dir.z).length() > 0.01 else Vector3.FORWARD
	if ws.get("slash", false):   # a bright arc swept across the target, gone in a few frames
		var root := Node3D.new()
		add_child(root)
		root.global_position = at - flat * 0.25
		root.look_at(at + flat, Vector3.UP)
		root.rotate_object_local(Vector3.FORWARD, rng.randf_range(-0.9, 0.9))
		var n := 9
		for i in n:
			var ang := lerpf(-1.1, 1.1, float(i) / (n - 1))
			var seg := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.12, 0.03, 0.03)
			bm.material = _add_mat(col, 1.6 - absf(ang) * 0.5)
			seg.mesh = bm
			seg.position = Vector3(sin(ang) * 0.45, 0, -cos(ang) * 0.45 + 0.3)
			seg.rotation.y = -ang
			root.add_child(seg)
		_fade_free(root, 0.14, "scale", Vector3(1.15, 0.2, 1.15))
	if ws.get("arc", false):   # stun: arcs crawling over the body
		for k in 3:
			var o := Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.35, 0.35), rng.randf_range(-0.3, 0.3))
			_bolt(at - flat * 0.3, at + o, col, 0.08, 0.02, 0.16)
		burst(at, col, 16, 2.5, 0.025, 0.3, 3.0, -3.0)
		_pop_light(at, col, 4.0, 3.0, 0.15)
	elif String(ws.get("hit", "")) == "sfx_hit_blunt":   # a shock ring of dust off the impact
		_ring(at, flat, Color(0.75, 0.7, 0.62, 0.5), 0.1, 0.6, 0.2, false)
		burst(at, Color("8a8478"), 6, 1.0, 0.06, 0.4, 0.0, -2.0)
	elif not ws.get("slash", false):   # fists: a white knuckle flash
		burst(at, Color("fff0d0"), 6, 1.6, 0.03, 0.15, 2.0, 0.0)


## The discharge at the muzzle for the non-firearm kinds (firearms get muzzle()'s flash).
func _launch(at: Vector3, dir: Vector3, ws: Dictionary, light: OmniLight3D) -> void:
	var col := Color(String(ws.get("col", "ffffff")))
	match String(ws.visual):
		"air", "dart":   # a little pneumatic puff, no fire, no light
			for k in 2:
				var puff := _ball(Color(0.85, 0.88, 0.92), 1.0, 0.04, 0.45, false)
				puff.global_position = at + dir * 0.06 * (k + 1)
				var tp := create_tween().set_parallel(true)
				tp.tween_property(puff, "scale", Vector3.ONE * 0.16, 0.35)
				tp.tween_property(puff, "global_position", puff.global_position + dir * 0.2 + Vector3(0, 0.06, 0), 0.35)
				tp.tween_property(puff.mesh.material, "albedo_color:a", 0.0, 0.35)
				tp.chain().tween_callback(puff.queue_free)
		"microwave":   # an emitter glow, violet, humming
			var g := _ball(col, 1.4, 0.12)
			g.global_position = at
			_fade_free(g, 0.45)
			_pop_light(at, col, 3.0, 3.5, 0.45, light)
		"sonic":   # the first wave bursting off the emitter
			_ring(at, dir, Color(col, 0.8), 0.05, 0.45, 0.18, true)
			_pop_light(at, col, 1.5, 2.5, 0.12, light)
		"arc":   # the prongs spark
			burst(at, col, 8, 1.5, 0.02, 0.15, 3.0, 0.0)
			_pop_light(at, col, 6.0, 4.0, 0.12, light)
		"flame":   # the pilot light flares: the jet itself carries the glow
			_pop_light(at + dir * 0.8, Color("ff8a30"), 9.0, 7.0, 0.6, light)
		"rail":   # a white-hot flash and a hard cyan pop; the sabot ring blows off the muzzle
			var g := _ball(Color.WHITE, 2.0, 0.3)
			g.global_position = at
			g.set_meta("age", 0)
			_flashes.append(g)
			_ring(at + dir * 0.1, dir, Color(col, 0.9), 0.08, 0.7, 0.2, true)
			_pop_light(at, col, 7.0, 6.0, 0.2, light)


## The projectile / beam for a non-firearm kind, calling `on_hit` when it lands.
func _projectile_for(a: Vector3, b: Vector3, ws: Dictionary, on_hit: Callable) -> void:
	var col := Color(String(ws.get("col", "ffffff")))
	var secs := _flight(a, b, ws)
	var impact := String(ws.get("impact", ""))
	var land := func():
		if impact != "":
			_snd(impact, b, -2.0, 0.08, 40)
		if on_hit.is_valid():
			on_hit.call()
	match String(ws.visual):
		"air":
			var pel := _ball(col, 1.3, 0.05)
			_fly(pel, a, b, secs, 0.05, Vector3.ZERO, func():
				burst(b, col, 12, 1.8, 0.03, 0.3, 1.4, -6.0)   # the acid paint splats
				land.call())
		"dart":
			_fly(_dart(col), a, b, secs, 0.02, Vector3.ZERO, land)
		"arrow":
			_fly(_arrow(col, String(ws.kind) == "crossbow"), a, b, secs, 0.12 + a.distance_to(b) * 0.02, Vector3.ZERO, land)
		"throw":
			var blade := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.03, 0.06, 0.32)
			var mt := StandardMaterial3D.new()
			mt.albedo_color = col
			mt.metallic = 0.8
			mt.roughness = 0.25
			bm.material = mt
			blade.mesh = bm
			_fly(blade, a, b, secs, 0.15 + a.distance_to(b) * 0.03, Vector3(22.0, 0, 0), land)
		"lob":
			var g := _ball(col, 0.0, 0.07)
			var arc := 0.4 + a.distance_to(b) * 0.18
			_fly(g, a, b, secs, arc, Vector3(14.0, 9.0, 0), func():
				_pop_blast(b, 1.0)
				land.call())
		"rocket":
			_fly(_rocket(col), a, b, secs, 0.0, Vector3.ZERO, func():
				_pop_blast(b, 1.5)
				land.call(), true)
		"microwave":
			_wave_beam(a, b, col)
			get_tree().create_timer(secs).timeout.connect(land)
		"sonic":
			_sonic(a, b, col, secs)
			get_tree().create_timer(secs).timeout.connect(func():
				_ring(b, (b - a).normalized(), Color(col, 0.7), 0.1, 0.9, 0.25, true)
				land.call())
		"arc":
			_bolt(a, b, col, 0.14, 0.022, 0.07)
			for k in 2:   # the bolt re-forms twice: a crackling flicker
				get_tree().create_timer(0.06 * (k + 1)).timeout.connect(_bolt.bind(a, b, col, 0.14, 0.022, 0.07))
			get_tree().create_timer(secs).timeout.connect(func():
				burst(b, col, 18, 2.8, 0.025, 0.3, 3.0, -3.0)
				_pop_light(b, col, 5.0, 3.5, 0.2)
				land.call())
		"flame":
			_flame_jet(a, b, col, secs)
			get_tree().create_timer(secs).timeout.connect(land)
		"rail":
			_rail(a, b, col)
			get_tree().create_timer(secs).timeout.connect(func():
				burst(b, col, 20, 5.0, 0.03, 0.3, 3.0, -4.0)
				land.call())
		_:
			get_tree().create_timer(secs).timeout.connect(land)


## Moves `n` from a to b over `secs` on an arc `arc_h` high, nose along the path (-Z), spinning
## by `spin` (rad/s, local); `smoke` leaves a trail of puffs. Frees it and calls `done` on arrival.
func _fly(n: Node3D, a: Vector3, b: Vector3, secs: float, arc_h: float, spin: Vector3, done: Callable, smoke := false) -> void:
	if n.get_parent() == null:
		add_child(n)
	n.global_position = a
	var state := {"last": a, "puff": 0.0}
	var tw := create_tween()
	tw.tween_method(func(k: float):
		var p := a.lerp(b, k) + Vector3(0, arc_h * 4.0 * k * (1.0 - k), 0)
		var v: Vector3 = p - (state.last as Vector3)
		n.global_position = p
		if v.length() > 0.001:
			n.look_at(p + v, Vector3.UP if absf(v.normalized().y) < 0.99 else Vector3.RIGHT)
			if spin != Vector3.ZERO:
				n.rotate_object_local(Vector3.RIGHT, spin.x * k * secs)
				n.rotate_object_local(Vector3.UP, spin.y * k * secs)
		if smoke and k - float(state.puff) > 0.06:
			state.puff = k
			_smoke_puff(p, 0.12, 0.9)
		state.last = p, 0.0, 1.0, secs)
	tw.tween_callback(func():
		n.queue_free()
		if done.is_valid():
			done.call())


## A wavering, distorting microwave beam: two translucent ribbons of beads writhing round the
## line, a faint haze sheath, for under half a second. No tracer, no round.
func _wave_beam(a: Vector3, b: Vector3, col: Color) -> void:
	var d := b - a
	var L := d.length()
	if L < 0.05:
		return
	var fwd := d / L
	var side := fwd.cross(Vector3.UP).normalized() if absf(fwd.y) < 0.99 else Vector3.RIGHT
	var up := side.cross(fwd).normalized()
	var root := Node3D.new()
	add_child(root)
	var beads: Array = []
	var n := clampi(int(L / 0.14), 6, 90)
	for strand in 2:
		var mat := _add_mat(col if strand == 0 else Color("3a8cff"), 0.75)
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05, 0.05, 0.16)
		bm.material = mat
		for i in n:
			var mi := MeshInstance3D.new()
			mi.mesh = bm
			mi.visible = false
			root.add_child(mi)
			beads.append([mi, float(i) / (n - 1), strand])
	var haze := MeshInstance3D.new()   # the heat-shimmer sheath: pale, barely there
	var cm := CylinderMesh.new()
	cm.top_radius = 0.11
	cm.bottom_radius = 0.11
	cm.height = 1.0
	cm.radial_segments = 8
	cm.rings = 1
	var hm := _unlit(Color(0.85, 0.8, 1.0), 1.0, 0.12)
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	cm.material = hm
	haze.mesh = cm
	root.add_child(haze)
	haze.global_position = a + d * 0.5
	_orient_y(haze, fwd)
	var hb := haze.global_basis
	var dur := 0.45
	var phase := rng.randf() * TAU
	var tw := create_tween()
	tw.tween_method(func(k: float):
		var amp := 0.09 * (1.0 - k * 0.6)
		for bd in beads:
			var u: float = bd[1]
			var s := 1.0 if int(bd[2]) == 0 else -1.0
			var ph := u * L * 7.0 - k * 40.0 + phase
			var off := side * sin(ph) * amp * s + up * cos(ph * 0.7 + s) * amp * 0.8
			var mi: MeshInstance3D = bd[0]
			mi.global_position = a + d * u + off
			mi.look_at(mi.global_position + fwd, up)
			mi.visible = u <= minf(1.0, k * 6.0)   # the beam reaches out in the first few frames
		haze.global_basis = hb.scaled_local(Vector3(1.0 + 0.5 * sin(k * 30.0), L, 1.0 + 0.5 * cos(k * 27.0)))
		hm.albedo_color.a = 0.12 * (1.0 - k), 0.0, 1.0, dur)
	tw.tween_callback(root.queue_free)


## Shrieker: a train of shockwave rings rolling down the line, swelling as they go.
func _sonic(a: Vector3, b: Vector3, col: Color, secs: float) -> void:
	var dir := (b - a).normalized()
	for k in 5:
		get_tree().create_timer(0.001 + 0.05 * k).timeout.connect(func():
			var r := _torus(col * (1.0 - k * 0.12), 0.16, true, 0.55)
			r.global_position = a
			_orient_y(r, dir)
			var tw := create_tween().set_parallel(true)
			tw.tween_property(r, "global_position", b, secs)
			tw.tween_property(r, "scale", Vector3.ONE * (3.2 + k * 0.4), secs)
			tw.chain().tween_callback(r.queue_free))


## A jagged electric bolt a → b, gone after `life`.
func _bolt(a: Vector3, b: Vector3, col: Color, jitter: float, thick: float, life: float) -> void:
	var d := b - a
	var L := d.length()
	if L < 0.02:
		return
	var fwd := d / L
	var side := fwd.cross(Vector3.UP).normalized() if absf(fwd.y) < 0.99 else Vector3.RIGHT
	var up := side.cross(fwd).normalized()
	var root := Node3D.new()
	add_child(root)
	var n := clampi(int(L / 0.3) + 2, 3, 30)
	var prev := a
	var mat := _add_mat(col, 1.8)
	for i in range(1, n + 1):
		var u := float(i) / n
		var p := a + d * u
		if i < n:
			p += (side * rng.randf_range(-1, 1) + up * rng.randf_range(-1, 1)) * jitter * (1.0 + L * 0.08)
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var sl := prev.distance_to(p)
		bm.size = Vector3(thick, thick, sl)
		bm.material = mat
		seg.mesh = bm
		root.add_child(seg)
		seg.global_position = (prev + p) * 0.5
		var sd := (p - prev).normalized()
		if sl > 0.001:
			seg.look_at(p, up if absf(sd.dot(up)) < 0.99 else side)
		prev = p
	get_tree().create_timer(life).timeout.connect(root.queue_free)


## A flame jet: fireballs streaming out of the nozzle in a widening cone, cooling from white to
## orange to nothing (additive), with pale heat-haze bubbles rising off it.
func _flame_jet(a: Vector3, b: Vector3, col: Color, reach_secs: float) -> void:
	var d := b - a
	var L := d.length()
	if L < 0.05:
		return
	var fwd := d / L
	var side := fwd.cross(Vector3.UP).normalized() if absf(fwd.y) < 0.99 else Vector3.RIGHT
	var up := side.cross(fwd).normalized()
	var stream := 0.5   # seconds the jet keeps pouring out
	var count := 36
	for k in count:
		get_tree().create_timer(0.001 + stream * float(k) / count).timeout.connect(func():
			var spread := rng.randf_range(0.0, 0.26)
			var ang := rng.randf() * TAU
			var dir := (fwd + (side * cos(ang) + up * sin(ang)) * spread).normalized()
			var reach := L * rng.randf_range(0.75, 1.1)
			var ball := _ball(Color("ffd070"), 1.0, 0.06)
			ball.global_position = a
			var m: StandardMaterial3D = ball.mesh.material
			var secs := reach_secs * reach / L
			var tw := create_tween().set_parallel(true)
			tw.tween_property(ball, "global_position", a + dir * reach + Vector3(0, reach * 0.06, 0), secs)
			tw.tween_property(ball, "scale", Vector3.ONE * (0.18 + reach * 0.07), secs)
			tw.tween_property(m, "albedo_color", Color(col, 1.0), secs * 0.2)
			tw.chain().tween_property(m, "albedo_color", Color(0.45, 0.05, 0.0), secs * 0.5)
			tw.chain().tween_property(m, "albedo_color", Color.BLACK, secs * 0.3)
			tw.chain().tween_callback(ball.queue_free)
			if k % 3 == 0:   # heat haze: a faint, pale, slowly rising shimmer
				var h := _ball(Color(1.0, 0.92, 0.8), 1.0, 0.2, 0.1, false)
				h.global_position = a + fwd * reach * rng.randf_range(0.3, 0.9) + Vector3(0, 0.2, 0)
				var th := create_tween().set_parallel(true)
				th.tween_property(h, "global_position", h.global_position + Vector3(0, 0.7, 0), 0.8)
				th.tween_property(h, "scale", Vector3.ONE * 0.6, 0.8)
				th.tween_property(h.mesh.material, "albedo_color:a", 0.0, 0.8)
				th.chain().tween_callback(h.queue_free))
	get_tree().create_timer(reach_secs).timeout.connect(func(): burst(b, Color("ffb040"), 14, 2.0, 0.04, 0.5, 2.0, 1.5))   # embers


## The railgun's slug: a bright line drawn the whole way at once, a corkscrew of rings round it,
## both fading in a quarter second.
func _rail(a: Vector3, b: Vector3, col: Color) -> void:
	var d := b - a
	var L := d.length()
	if L < 0.05:
		return
	var fwd := d / L
	for layer in [[0.025, Color.WHITE, 2.0], [0.07, col, 1.2]]:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = float(layer[0])
		cm.bottom_radius = float(layer[0])
		cm.height = 1.0
		cm.radial_segments = 6
		cm.rings = 1
		cm.material = _add_mat(layer[1], float(layer[2]))
		mi.mesh = cm
		add_child(mi)
		mi.global_position = a + d * 0.5
		_orient_y(mi, fwd)
		mi.scale = Vector3(1, L, 1)
		_fade_free(mi, 0.28, "scale", Vector3(0.0, L, 0.0))
	var n := clampi(int(L / 0.7), 2, 20)
	for i in n:   # the ionised corkscrew
		var r := _torus(Color(col, 0.7), 0.09)
		r.global_position = a + d * (float(i) + 0.5) / n
		_orient_y(r, fwd)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(r, "scale", Vector3.ONE * 2.2, 0.35).set_delay(0.02 * i)
		tw.tween_property(r.mesh.material, "albedo_color", Color.BLACK, 0.35).set_delay(0.02 * i)
		tw.chain().tween_callback(r.queue_free)


## A small explosive burst where a launched grenade or rocket lands (no scorch: the floor is not
## known here).
func _pop_blast(at: Vector3, big: float) -> void:
	_snd("sfx_explosion", at, -2.0 + big * 2.0, 0.05, 100)
	var ball := _ball(Color("fff2c0"), 2.2, 0.3 * big)
	ball.global_position = at
	var m: StandardMaterial3D = ball.mesh.material
	var tb := create_tween().set_parallel(true)
	tb.tween_property(ball, "scale", Vector3.ONE * 1.3 * big, 0.1).set_ease(Tween.EASE_OUT)
	tb.tween_property(m, "albedo_color", Color("ff6a10"), 0.1)
	tb.chain().tween_property(m, "albedo_color", Color.BLACK, 0.2)
	tb.chain().tween_callback(ball.queue_free)
	_pop_light(at, Color("ffb060"), 14.0 * big, 7.0, 0.45)
	burst(at, Color("ffd27a"), int(18 * big), 6.0, 0.045, 0.35, 2.0, -6.0)
	for k in int(4 * big):
		_smoke_puff(at + Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(0.0, 0.3), rng.randf_range(-0.4, 0.4)), 0.4, 1.8)


func _smoke_puff(at: Vector3, size: float, life: float) -> void:
	var puff := _ball(Color(0.5, 0.5, 0.52), 1.0, size, 0.45, false)
	var pm: StandardMaterial3D = puff.mesh.material
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL   # shaded: unshaded grey glows at night
	pm.roughness = 1.0
	puff.global_position = at
	var tp := create_tween().set_parallel(true)
	tp.tween_property(puff, "global_position", at + Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(0.2, 0.5), rng.randf_range(-0.1, 0.1)), life)
	tp.tween_property(puff, "scale", Vector3.ONE * size * 2.5, life)
	tp.tween_property(pm, "albedo_color:a", 0.0, life)
	tp.chain().tween_callback(puff.queue_free)


## An expanding ring facing along `dir` (a shockwave, a sabot blast, a blunt impact).
func _ring(at: Vector3, dir: Vector3, col: Color, r0: float, r1: float, secs: float, additive: bool) -> void:
	var r := _torus(col, r0, additive)
	r.global_position = at
	_orient_y(r, dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(r, "scale", Vector3.ONE * (r1 / r0), secs).set_ease(Tween.EASE_OUT)
	if additive:
		tw.tween_property(r.mesh.material, "albedo_color", Color.BLACK, secs)
	else:
		tw.tween_property(r.mesh.material, "albedo_color:a", 0.0, secs)
	tw.chain().tween_callback(r.queue_free)


## A short coloured light pop: the shooter's pooled light when given (see muzzle()).
func _pop_light(at: Vector3, col: Color, energy: float, reach: float, secs: float, light: OmniLight3D = null) -> void:
	var l := light
	if l == null:
		l = OmniLight3D.new()
		add_child(l)
		get_tree().create_timer(secs + 0.1).timeout.connect(l.queue_free)
	l.light_color = col
	l.light_cull_mask = 1
	l.omni_range = reach
	l.global_position = at
	l.light_energy = energy
	create_tween().tween_property(l, "light_energy", 0.0, secs).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


## A sphere `radius` big, added to the scene: additive glow, or alpha-blended unlit, or (glow 0)
## a solid lit object.
func _ball(col: Color, glow: float, radius: float, alpha := 1.0, additive := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	if glow <= 0.0:
		var mt := StandardMaterial3D.new()
		mt.albedo_color = col
		mt.roughness = 0.6
		sm.material = mt
	else:
		sm.material = _add_mat(col, glow) if additive else _unlit(col, glow, alpha)
	mi.mesh = sm
	add_child(mi)
	mi.scale = Vector3.ONE * radius * 2.0
	return mi


func _torus(col: Color, radius: float, additive := true, inner := 0.72) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = radius * inner
	tm.outer_radius = radius
	tm.rings = 16
	tm.ring_segments = 4
	tm.material = _add_mat(col, 1.4) if additive else _unlit(col, 1.0, col.a)
	mi.mesh = tm
	add_child(mi)
	return mi


## Point a node's +Y along `dir` (cylinders and tori are built round Y); resets its scale.
func _orient_y(n: Node3D, dir: Vector3) -> void:
	var y := dir.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.99 else Vector3.RIGHT).normalized()
	var z := x.cross(y).normalized()
	n.global_basis = Basis(x, y, z)


func _dart(col: Color) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.02, 0.02, 0.18)
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color("b8bcc4")
	mt.metallic = 0.7
	bm.material = mt
	body.mesh = bm
	root.add_child(body)
	var tail := MeshInstance3D.new()   # the coloured payload band that reads at pixel scale
	var tb := BoxMesh.new()
	tb.size = Vector3(0.05, 0.05, 0.06)
	tb.material = _unlit(col, 1.2)
	tail.mesh = tb
	tail.position = Vector3(0, 0, 0.08)
	root.add_child(tail)
	return root


func _arrow(col: Color, bolt: bool) -> Node3D:
	var root := Node3D.new()
	var length := 0.42 if bolt else 0.68
	var shaft := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.022, 0.022, length)
	var mt := StandardMaterial3D.new()
	mt.albedo_color = col
	mt.roughness = 0.7
	bm.material = mt
	shaft.mesh = bm
	root.add_child(shaft)
	var head := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.04, 0.04, 0.07)
	var hm := StandardMaterial3D.new()
	hm.albedo_color = Color("d8dce0")
	hm.metallic = 0.9
	hm.roughness = 0.2
	hb.material = hm
	head.mesh = hb
	head.position = Vector3(0, 0, -length * 0.5)
	root.add_child(head)
	var fl := MeshInstance3D.new()   # fletching: red on arrows, cyan vanes on bolts
	var fb := BoxMesh.new()
	fb.size = Vector3(0.07, 0.07, 0.1)
	fb.material = _unlit(Color("e04040") if not bolt else Color("40c0e0"), 1.0)
	fl.mesh = fb
	fl.position = Vector3(0, 0, length * 0.42)
	root.add_child(fl)
	return root


func _rocket(col: Color) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.08, 0.08, 0.38)
	var mt := StandardMaterial3D.new()
	mt.albedo_color = Color("4a5048")
	bm.material = mt
	body.mesh = bm
	root.add_child(body)
	var plume := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = _add_mat(col, 2.0)
	plume.mesh = sm
	plume.scale = Vector3(0.14, 0.14, 0.3)
	plume.position = Vector3(0, 0, 0.3)
	root.add_child(plume)
	return root
