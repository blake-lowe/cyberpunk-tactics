class_name AmbientFx
extends Node3D
## Scene ambience from SceneTheme "ambient" (decoration only, never rules): embers drifting over a
## burning district, flames and smoke columns on burning wrecks, steam off the undercity's runoff
## and water dripping from its pipes, dust motes and shafts of light in the arcology atrium.

var _flames: Array = []   ## [MeshInstance3D, base scale, phase]
var _blinks: Array = []   ## [Node3D, period s, duty 0..1, phase]: AV and drone beacons, hazard lights
var _movers: Array = []   ## [Node3D, from, to, speed (units/s), phase 0..1]: AVs and drones crossing the sky
var _flicker: Array = []  ## [OmniLight3D, base energy, MeshInstance3D or null, seed]: a failing neon or streetlight
var _sweep: Array = []    ## [SpotLight3D, centre, radius, phase]: a police AV's searchlight


func build(m: TacMap, kinds: Array, seed_value: int) -> void:
	for ch in get_children():
		ch.queue_free()
	_flames.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 61 + 5
	var gy := m.street * WorldBuilder.FH   # everything rises from the street, not the lowest basement
	var sf := m.street
	var mid := Vector3(m.w / 2.0, gy, m.h / 2.0)
	for k in kinds:
		match String(k):
			"embers":
				var p := _particles(mini(700, m.w * m.h / 9), 8.0, _unlit_quad(Color("ffb050"), true))
				p.position = mid + Vector3(0, 1.4, 0)
				p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
				p.emission_box_extents = Vector3(m.w / 2.0, 1.4, m.h / 2.0)
				p.direction = Vector3(0.3, 1, 0.1)
				p.spread = 35.0
				p.initial_velocity_min = 0.15
				p.initial_velocity_max = 0.5
				p.gravity = Vector3(0.35, 0.12, 0.12)
				p.scale_amount_min = 0.07
				p.scale_amount_max = 0.14
				p.color_ramp = _ramp([Color("fff0a0", 0.0), Color("ffb050"), Color("ff5a1a"), Color("8a1a0a", 0.0)], [0.0, 0.08, 0.6, 1.0])
			"motes":
				var p := _particles(mini(320, m.w * m.h / 16), 12.0, _unlit_quad(Color("ffffff"), true))
				p.position = mid + Vector3(0, 1.6, 0)
				p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
				p.emission_box_extents = Vector3(m.w / 2.0, 1.6, m.h / 2.0)
				p.direction = Vector3(0.2, 0.3, 0.1)
				p.spread = 180.0
				p.initial_velocity_min = 0.02
				p.initial_velocity_max = 0.08
				p.gravity = Vector3(0.02, 0.01, 0.0)
				p.scale_amount_min = 0.05
				p.scale_amount_max = 0.09
				p.color_ramp = _ramp([Color(1, 1, 1, 0), Color(1, 1, 1, 0.8), Color(1, 0.95, 0.95, 0)], [0.0, 0.5, 1.0])
				_shafts(m, rng, gy)
			"steam":
				var spots: Array = []
				for i in 400:
					var v := Vector2i(rng.randi_range(0, m.w - 1), rng.randi_range(0, m.h - 1))
					if m.t(sf, v.x, v.y) == TacMap.T.WATER and spots.all(func(q): return q.distance_to(v) > 7):
						spots.append(v)
					if spots.size() >= 9:
						break
				for v in spots:
					var s := _particles(10, 4.5, _soft_quad(Color("c8f0d0")))
					s.position = Vector3(v.x + 0.5, gy + 0.1, v.y + 0.5)
					s.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
					s.emission_sphere_radius = 0.6
					s.direction = Vector3.UP
					s.spread = 15.0
					s.initial_velocity_min = 0.2
					s.initial_velocity_max = 0.35
					s.gravity = Vector3(0.04, 0.02, 0)
					s.scale_amount_min = 0.5
					s.scale_amount_max = 0.9
					s.scale_amount_curve = _curve(0.4, 1.0, 2.0)
					s.color_ramp = _ramp([Color(0.8, 1, 0.85, 0), Color(0.8, 1, 0.85, 0.22), Color(0.8, 1, 0.85, 0)], [0.0, 0.3, 1.0])
			"drips":
				var pts := PackedVector3Array()
				for i in 1600:
					var v := Vector2i(rng.randi_range(1, m.w - 2), rng.randi_range(1, m.h - 2))
					if not m.walkable_tile(m.t(sf, v.x, v.y)) and m.t(sf, v.x, v.y) != TacMap.T.WATER:
						continue
					var by_wall := false
					for d in MapGen.DIRS:
						if m.t(sf, v.x + d.x, v.y + d.y) == TacMap.T.WALL:
							by_wall = true
					if by_wall:
						pts.append(Vector3(v.x + rng.randf(), gy, v.y + rng.randf()) - mid)
					if pts.size() >= 160:
						break
				if not pts.is_empty():
					var d := _particles(90, 0.75, _unlit_quad(Color("d0fff0"), false))
					d.position = mid + Vector3(0, 1.45, 0)
					d.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
					d.emission_points = pts
					d.direction = Vector3.DOWN
					d.spread = 0.0
					d.initial_velocity_min = 0.0
					d.initial_velocity_max = 0.2
					d.gravity = Vector3(0, -2.6, 0)
					d.scale_amount_min = 0.04
					d.scale_amount_max = 0.06
					d.color_ramp = _ramp([Color(0.8, 1, 0.95, 0.9), Color(0.8, 1, 0.95, 0.9), Color(0.8, 1, 0.95, 0)], [0.0, 0.85, 1.0])


## A burning wreck or rubble heap: a cluster of flickering flame blobs, sparks and a smoke column.
func flame(at: Vector3, size: float, smoke: bool) -> void:
	# tongues of flame: tapered cones, outer red-orange round a yellow core, each flickering
	var cols := [Color("e8400c"), Color("ff6a14"), Color("ff8a24"), Color("ffb030"), Color("ffe080")]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(at * 10.0))
	for i in 7:
		var core := i >= 5
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		var r := size * (rng.randf_range(0.1, 0.16) if not core else 0.09)
		var h := size * (rng.randf_range(0.45, 0.8) if not core else 0.42)
		cm.top_radius = 0.0
		cm.bottom_radius = r
		cm.height = h
		cm.radial_segments = 5
		cm.rings = 1
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.albedo_color = cols[4] if core else cols[i % 4]
		cm.material = mt
		mi.mesh = cm
		var ang := i * 2.4 + rng.randf()
		var off := Vector3(cos(ang), 0, sin(ang)) * size * (rng.randf_range(0.08, 0.26) if not core else 0.04)
		mi.position = at + off + Vector3(0, h / 2, 0)
		mi.rotation = Vector3(rng.randf_range(-0.2, 0.2), 0, rng.randf_range(-0.2, 0.2))
		add_child(mi)
		_flames.append([mi, Vector3.ONE, rng.randf() * TAU, off])
	var sp := _particles(int(10 * size), 1.6, _unlit_quad(Color("ffd070"), false))
	sp.position = at + Vector3(0, size * 0.4, 0)
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = size * 0.3
	sp.direction = Vector3.UP
	sp.spread = 25.0
	sp.initial_velocity_min = 1.0
	sp.initial_velocity_max = 2.0
	sp.gravity = Vector3(0.3, -0.4, 0.1)
	sp.scale_amount_min = 0.06
	sp.scale_amount_max = 0.1
	sp.color_ramp = _ramp([Color("fff0a0"), Color("ff8a24"), Color("a02008", 0.0)], [0.0, 0.5, 1.0])
	if smoke:
		var s := _particles(18, 7.0, _soft_quad(Color("ffffff")))
		s.position = at + Vector3(0, size * 0.8, 0)
		s.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		s.emission_sphere_radius = size * 0.3
		s.direction = Vector3.UP
		s.spread = 12.0
		s.initial_velocity_min = 0.5
		s.initial_velocity_max = 0.8
		s.gravity = Vector3(0.28, 0.06, 0.12)
		s.scale_amount_min = 0.7 * size
		s.scale_amount_max = 1.0 * size
		s.scale_amount_curve = _curve(0.6, 1.6, 3.2)
		s.color_ramp = _ramp([Color(0.9, 0.42, 0.16, 0), Color(0.62, 0.32, 0.2, 0.5), Color(0.4, 0.34, 0.32, 0.42), Color(0.46, 0.42, 0.4, 0)], [0.0, 0.1, 0.45, 1.0])


func _process(_d: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for b in _blinks:
		var n: Node3D = b[0]
		n.visible = fmod(t / float(b[1]) + float(b[3]), 1.0) < float(b[2])
	for mv in _movers:
		var n: Node3D = mv[0]
		var a: Vector3 = mv[1]
		var z: Vector3 = mv[2]
		var span := maxf(1.0, a.distance_to(z))
		var k := fmod(t * float(mv[3]) / span + float(mv[4]), 1.0)
		n.position = a.lerp(z, k)
	for fl in _flicker:
		var l: OmniLight3D = fl[0]
		var s: int = fl[3]
		var slot := int(t * 9.0)
		var off := posmod(hash(Vector2i(slot, s)), 100) < 9 or (posmod(hash(Vector2i(int(t * 0.5), s)), 7) == 0 and posmod(slot, 3) == 0)
		l.light_energy = float(fl[1]) * (0.12 if off else 1.0)
		if fl[2] != null:
			(fl[2] as Node3D).visible = not off
	for sw in _sweep:
		var sl: SpotLight3D = sw[0]
		var c: Vector3 = sw[1]
		var r: float = sw[2]
		var ang := t * 0.35 + float(sw[3])
		var aim := c + Vector3(cos(ang) * r, 0.0, sin(ang * 1.3) * r)
		if sl.global_position.distance_to(aim) > 0.01:
			sl.look_at(aim, Vector3.FORWARD)
	for f in _flames:
		var mi: MeshInstance3D = f[0]
		var ph: float = f[2]
		var s := 1.0 + 0.22 * sin(t * 9.0 + ph) + 0.12 * sin(t * 23.0 + ph * 2.0)
		mi.scale = Vector3(1.0 / sqrt(s), s, 1.0 / sqrt(s))
		mi.rotation.y = t * 0.6 + ph


# --- Everyday life on the street (owner 2026-11-09: "more everyday events around maps") ------------

## Life over an ordinary street, decoration only (never rules; its own seeded RNG): steam from a few
## manholes, litter skittering along the pavements, holo-ads on walls that cycle, parked cars with
## their hazards blinking, AVs and drones crossing the sky. Cheap by construction: one particle
## node per kind, one MultiMesh for every ad, a few small unlit meshes; counts scale with the map
## and are capped. `sky`: the scene event's sky cue (SceneEvent: drone, av, spotlight, flare,
## light, fireball, av_crash).
func street(m: TacMap, seed_value: int, sky := "") -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 97 + 11
	var scene := String(m.params.get("scene", ""))
	var open_sky := scene not in ["undercity", "arcology"]
	var gy := m.street * WorldBuilder.FH
	if not m.is_tower() and scene not in ["undercity", "arcology"]:
		_vents(m, rng, gy)
		_litter(m, rng, gy)
		_hazards(m, rng, gy)
		_ads(m, rng, gy)
	if open_sky:
		_sky_traffic(m, rng, gy, sky)


## Outdoor street squares at street level (no building's ground, no cover).
static func _open_cells(m: TacMap, ground := -1) -> Array:
	var out: Array = []
	var sl := m.street
	for y in range(1, m.h - 1):
		for x in range(1, m.w - 1):
			if m.t(sl, x, y) != TacMap.T.OUTSIDE or m.has_cover_at(sl, Vector2i(x, y)) or m.label(sl, x, y) >= 0:
				continue
			if ground >= 0 and m.ground[y * m.w + x] != ground:
				continue
			out.append(Vector2i(x, y))
	return out


## Steam from a few manholes in the road (a steaming open manhole, SPM p.37's sights).
func _vents(m: TacMap, rng: RandomNumberGenerator, gy: float) -> void:
	var cells := _open_cells(m, TacMap.G.ASPHALT)
	if cells.is_empty():
		return
	var lid := StandardMaterial3D.new()
	lid.albedo_color = Color("1a1c1e")
	lid.roughness = 0.6
	lid.metallic = 0.5
	var spots: Array = []
	for i in 200:
		if spots.size() >= clampi(m.w * m.h / 1600, 1, 5):
			break
		var v: Vector2i = cells[rng.randi() % cells.size()]
		if spots.any(func(q): return q.distance_to(v) < 12):
			continue
		spots.append(v)
		var disc := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.3
		cm.bottom_radius = 0.3
		cm.height = 0.02
		cm.radial_segments = 10
		cm.material = lid
		disc.mesh = cm
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		disc.position = Vector3(v.x + 0.5, gy + 0.012, v.y + 0.5)
		add_child(disc)
		var s := _particles(10, 4.0, _soft_quad(Color("d8e0e8")))
		s.position = disc.position + Vector3(0, 0.05, 0)
		s.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		s.emission_sphere_radius = 0.2
		s.direction = Vector3.UP
		s.spread = 12.0
		s.initial_velocity_min = 0.25
		s.initial_velocity_max = 0.4
		s.gravity = Vector3(0.08, 0.02, 0.03)
		s.scale_amount_min = 0.35
		s.scale_amount_max = 0.6
		s.scale_amount_curve = _curve(0.5, 1.2, 2.2)
		s.color_ramp = _ramp([Color(0.85, 0.9, 1, 0), Color(0.85, 0.9, 1, 0.18), Color(0.85, 0.9, 1, 0)], [0.0, 0.25, 1.0])


## Paper and wrappers skittering along the pavement in the wind.
func _litter(m: TacMap, rng: RandomNumberGenerator, gy: float) -> void:
	var cells := _open_cells(m)
	if cells.is_empty():
		return
	var pts := PackedVector3Array()
	for i in mini(240, cells.size()):
		var v: Vector2i = cells[rng.randi() % cells.size()]
		pts.append(Vector3(v.x + rng.randf(), gy + 0.04, v.y + rng.randf()))
	var p := _particles(mini(70, m.w * m.h / 110), 7.0, _unlit_quad(Color(0.62, 0.6, 0.55, 0.75), false))
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_POINTS
	p.emission_points = pts
	p.direction = Vector3(1, 0.25, 0.4)
	p.spread = 30.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.5
	p.gravity = Vector3(0.18, -0.05, 0.08)
	p.angular_velocity_min = -180.0
	p.angular_velocity_max = 180.0
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.1
	p.color_ramp = _ramp([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)], [0.0, 0.1, 0.85, 1.0])


## A few parked cars with their hazard lights blinking.
func _hazards(m: TacMap, rng: RandomNumberGenerator, gy: float) -> void:
	var cars := {}
	for c in m.cover:
		if String(c.kind) == "car" and int(c.floor) == m.street:
			var k := int(c.get("prop", -1))
			var r: Rect2 = cars.get(k, [Rect2(Vector2(c.pos), Vector2.ZERO)])[0]
			cars[k] = [r.expand(Vector2(c.pos)).expand(Vector2(c.pos) + Vector2.ONE), String(c.get("make", ""))]
	var amber := StandardMaterial3D.new()
	amber.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	amber.albedo_color = Color(1.0, 0.62, 0.12)
	var n := 0
	for k in cars:
		if n >= 4 or rng.randf() > 0.3:
			continue
		n += 1
		var r: Rect2 = cars[k][0]
		var ph := rng.randf()
		# the car's own corners (CarProp: the frame WorldBuilder drew it in, same hash)
		for q: Vector3 in CarProp.corners(CarProp.frame_on(m, "car", r, hash(k * 10 + m.street), String(cars[k][1])), gy):
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.05, 0.035, 0.05)
			bm.material = amber
			mi.mesh = bm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.position = q
			add_child(mi)
			_blinks.append([mi, 0.9, 0.5, ph])


## Holo-ads from the sign library on a few street walls (SignBatch: one MultiMesh): logos cycling,
## tickers running, dancers, products turning.
func _ads(m: TacMap, rng: RandomNumberGenerator, gy: float) -> void:
	var sl := m.street
	var spots: Array = []   # [wall-side square, outward]
	for y in range(1, m.h - 1):
		for x in range(1, m.w - 1):
			if m.t(sl, x, y) != TacMap.T.OUTSIDE or m.label(sl, x, y) >= 0:
				continue
			for d in MapGen.DIRS:
				if m.t(sl, x - d.x, y - d.y) == TacMap.T.WALL and m.t(sl, x + d.y, y + d.x) != TacMap.T.DOOR and m.t(sl, x - d.y, y - d.x) != TacMap.T.DOOR:
					spots.append([Vector2i(x, y), d])
					break
	if spots.is_empty():
		return
	var want := clampi(m.w * m.h / 1100, 2, 7)
	var chosen: Array = []
	for i in 300:
		if chosen.size() >= want:
			break
		var s: Array = spots[rng.randi() % spots.size()]
		if chosen.any(func(q): return (q[0] as Vector2i).distance_to(s[0]) < 9):
			continue
		chosen.append(s)
	var b := SignBatch.new(0)   # the sign library's holo ads (SignLib): street-side ones, in one batch
	for i in chosen.size():
		var v: Vector2i = chosen[i][0]
		var d: Vector2i = chosen[i][1]
		var w := rng.randf_range(0.9, 1.4)
		var h := w * rng.randf_range(0.45, 0.65)
		var e := SignLib.pick(rng, "holo", ["street"])
		b.wall(e, Vector3(v.x + 0.5 - d.x * 0.47, gy + 1.22, v.y + 0.5 - d.y * 0.47), Vector3(d.x, 0, d.y), w, h, rng.randi())
	b.flush(self, Vector2(m.w, m.h))


## Traffic overhead: AVs' running lights crossing high up, drones lower down, blinking. A scene
## event's sky cue adds its own (a police searchlight, a flare, a glow on the horizon).
func _sky_traffic(m: TacMap, rng: RandomNumberGenerator, gy: float, sky: String) -> void:
	var red := _glow_mat(Color(1.0, 0.18, 0.2))
	var white := _glow_mat(Color(0.9, 0.95, 1.0))
	var cyan := _glow_mat(Color(0.3, 0.9, 1.0))
	var span := Vector2(m.w, m.h)
	var avs := clampi(int(span.length() / 45.0), 2, 4) + (2 if sky in ["av", "av_crash"] else 0)
	var drones := clampi(int(span.length() / 60.0), 1, 3) + (3 if sky == "drone" else 0)
	for i in avs + drones:
		var av := i < avs
		var y := gy + (rng.randf_range(15.0, 24.0) if av else rng.randf_range(6.0, 9.0))
		var from := Vector3(-20.0, y, rng.randf_range(-10, m.h + 10))
		var to := Vector3(m.w + 20.0, y + rng.randf_range(-2, 2), rng.randf_range(-10, m.h + 10))
		if rng.randf() < 0.5:
			from = Vector3(rng.randf_range(-10, m.w + 10), y, -20.0)
			to = Vector3(rng.randf_range(-10, m.w + 10), y, m.h + 20.0)
		if rng.randf() < 0.5:
			var tmp := from
			from = to
			to = tmp
		var craft := Node3D.new()
		add_child(craft)
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.9, 0.18, 1.4) if av else Vector3(0.22, 0.05, 0.22)
		bm.material = _glow_mat(Color(0.05, 0.06, 0.08))
		body.mesh = bm
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		craft.add_child(body)
		craft.look_at_from_position(from, to, Vector3.UP)
		for s in ([-1, 1] if av else [0]):
			var lamp := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.09 if av else 0.05
			sm.height = sm.radius * 2.0
			sm.radial_segments = 6
			sm.rings = 3
			sm.material = (red if s < 0 else white) if av else cyan
			lamp.mesh = sm
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			lamp.position = Vector3(0.5 * s, 0, 0) if av else Vector3(0, 0.05, 0)
			craft.add_child(lamp)
			_blinks.append([lamp, 1.1 if av else 0.6, 0.35, rng.randf()])
		_movers.append([craft, from, to, rng.randf_range(4.0, 7.0) if av else rng.randf_range(1.2, 2.2), rng.randf()])
	match sky:
		"spotlight":   # a police AV hovering over a block, its searchlight sweeping the street
			var c := Vector3(rng.randf_range(m.w * 0.3, m.w * 0.7), gy, rng.randf_range(m.h * 0.3, m.h * 0.7))
			var av := Node3D.new()
			av.position = c + Vector3(0, 14.0, 0)
			add_child(av)
			var body := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.2, 0.3, 2.0)
			bm.material = _glow_mat(Color(0.05, 0.06, 0.1))
			body.mesh = bm
			av.add_child(body)
			for s in [-1, 1]:
				var lamp := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.12
				sm.height = 0.24
				sm.material = red if s < 0 else _glow_mat(Color(0.2, 0.4, 1.0))
				lamp.mesh = sm
				lamp.position = Vector3(0.65 * s, 0.1, 0)
				av.add_child(lamp)
				_blinks.append([lamp, 0.5, 0.5, 0.5 if s < 0 else 0.0])
			var sl := SpotLight3D.new()
			sl.light_color = Color(0.85, 0.92, 1.0)
			sl.light_energy = 6.0
			sl.spot_range = 30.0
			sl.spot_angle = 9.0
			sl.shadow_enabled = false
			sl.position = Vector3(0, -0.2, 0)
			av.add_child(sl)
			_sweep.append([sl, c, 7.0, rng.randf() * TAU])
		"flare", "light", "fireball", "av_crash":   # a glow in the sky off the map's edge
			var col := {"flare": Color(1.0, 0.25, 0.2), "light": Color(0.6, 1.0, 0.9), "fireball": Color(1.0, 0.55, 0.15), "av_crash": Color(1.0, 0.5, 0.2)}[sky] as Color
			var g := MeshInstance3D.new()
			g.mesh = _unlit_quad(Color(col, 0.85), true)
			g.scale = Vector3.ONE * (2.5 if sky != "flare" else 1.2)
			g.position = Vector3(m.w * rng.randf_range(0.2, 0.8), gy + rng.randf_range(10.0, 16.0), -6.0 if rng.randf() < 0.5 else m.h + 6.0)
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(g)
			_blinks.append([g, 2.6 if sky != "light" else 0.4, 0.8, 0.0])
			if sky == "flare":   # it drifts down
				_movers.append([g, g.position, g.position - Vector3(0, 9.0, 0), 0.6, 0.0])


static func _glow_mat(c: Color) -> StandardMaterial3D:
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = c
	return mt


## A failing light: the greybox registers the odd neon sign or streetlamp (and its glowing mesh).
func flicker(l: OmniLight3D, glow: Node3D, seed_value: int) -> void:
	_flicker.append([l, l.light_energy, glow, seed_value])


## A sparking drone wreck or a tech shop's sparks (SceneEvent dressing): a burst every few seconds.
func sparks(at: Vector3, drone: bool) -> void:
	if drone:
		var body := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.45, 0.1, 0.45)
		bm.material = _glow_mat(Color(0.08, 0.08, 0.09))
		body.mesh = bm
		body.position = at + Vector3(0, 0.05, 0)
		body.rotation = Vector3(0.15, 0.6, -0.1)
		add_child(body)
	var sp := _particles(14, 0.5, _unlit_quad(Color("bfe8ff"), false))
	sp.position = at + Vector3(0, 0.15 if drone else 0.9, 0)
	sp.explosiveness = 0.9
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = 0.08
	sp.direction = Vector3.UP
	sp.spread = 70.0
	sp.initial_velocity_min = 1.2
	sp.initial_velocity_max = 2.4
	sp.gravity = Vector3(0, -6.0, 0)
	sp.scale_amount_min = 0.03
	sp.scale_amount_max = 0.06
	sp.color_ramp = _ramp([Color("ffffff"), Color("8fd8ff"), Color(0.3, 0.6, 1.0, 0.0)], [0.0, 0.4, 1.0])
	_blinks.append([sp, 2.3, 0.25, fmod(at.x * 0.37, 1.0)])


## Arcology: shafts of light falling from the atrium's roof, slanted, additive and faint.
func _shafts(m: TacMap, rng: RandomNumberGenerator, gy: float) -> void:
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	mt.no_depth_test = false
	mt.albedo_color = Color(1.0, 0.97, 0.94, 0.035)   # r7 review: shafts read as glass slabs at 0.07
	for i in maxi(4, m.w * m.h / 900):
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(2.5, 4.5), 16.0, rng.randf_range(2.5, 4.5))
		bm.material = mt
		mi.mesh = bm
		mi.position = Vector3(rng.randf_range(6, m.w - 6), gy + 8.0, rng.randf_range(6, m.h - 6))
		mi.rotation = Vector3(deg_to_rad(14), deg_to_rad(20), 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)


func _particles(n: int, life: float, mesh: Mesh) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(1, n)
	p.lifetime = life
	p.mesh = mesh
	p.preprocess = life
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


## Particle sprites: a camera-facing quad (keeps the particle's scale), coloured by the particle's
## colour ramp, round and soft-edged (smoke, steam, motes) or hard (sparks, drips).
const SPRITE := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float soft = 1.0;
void vertex() {
	mat4 bb = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	bb = bb * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * bb;
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = mix(1.0, smoothstep(1.0, 0.15, d), soft);
	ALBEDO = tint.rgb * COLOR.rgb;
	ALPHA = tint.a * COLOR.a * a;
}
"""
static var _sprite: Shader


func _unlit_quad(col: Color, soft: bool) -> QuadMesh:
	if _sprite == null:
		_sprite = Shader.new()
		_sprite.code = SPRITE
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	var mt := ShaderMaterial.new()
	mt.shader = _sprite
	mt.set_shader_parameter("tint", col)
	mt.set_shader_parameter("soft", 1.0 if soft else 0.0)
	q.material = mt
	return q


func _soft_quad(col: Color) -> QuadMesh:
	return _unlit_quad(col, true)


func _ramp(cols: Array, offs: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	return g


func _curve(a: float, b: float, c: float) -> Curve:
	var cv := Curve.new()
	cv.max_value = maxf(c, 1.0)
	cv.add_point(Vector2(0, a))
	cv.add_point(Vector2(0.5, b))
	cv.add_point(Vector2(1, c))
	return cv
