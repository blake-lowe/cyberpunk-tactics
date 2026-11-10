class_name WeatherFx
extends Node3D
## The weather over the play area (Atmosphere look of the gig's mood; data/gen/atmospheres.json):
## rain streaks, drifting ash or ice glints, blown dust, low haze, wet and frosted open ground and
## lightning. Everything sits over open sky only (Weather.surface): the rain lands on the street and
## on roofs, never inside a building, and what is over a building the cutaway opens hides with its
## roof (weather.gdshader reads the cut map). The light the play area and the units are lit by is
## never touched (owner): a flash lights the sky, the rain, the haze and the wet ground only.
##
## One MultiMesh per particle kind and a few haze layers, placed from their own random numbers (the
## view's, never the rules' Dice). The ground's wetness is the global `weather` (world.gdshader:
## outdoor materials), the flash the global `weather_flash`.

const SHADER := preload("res://src/tactical/view/weather.gdshader")
const FH := 1.6               ## floor height (greybox FH)
const M := 0.5                ## world units per metre (a square is 2 m)
const MARGIN := 10            ## squares of weather round the map's edge (the ground runs on past it)
const MAX_RAIN := 16000       ## caps per kind: a big map in a storm stays cheap
const MAX_BITS := 4000
const HAZE_LAYERS := [[0.25, 1.0], [0.75, 0.75], [1.5, 0.5]]   ## [height, share of the mood's haze]

var m: TacMap
var mood := ""
var lk := {}                  ## Atmosphere.look(mood, day)
var day := false
var mask_tex: ImageTexture    ## R: open ground at street level, G: open-sky surface floor + 1
var counts := {}              ## kind → particles placed (tests, the perf readout)
var sky_mat: ShaderMaterial   ## the greybox's sky (lightning lights it)
var _sky_base := {}
var _mats: Array[ShaderMaterial] = []
var _rng := RandomNumberGenerator.new()
var _rate := 0.0              ## flashes a second
var _next := 0.0
var _flash_t := -1.0
var _bolt: MeshInstance3D
static var current: WeatherFx   ## the one whose weather the ground's globals hold


## Build for map `p_m` in mood `p_mood`, by day or night; `sky` is the scene's sky material (or null).
func build(p_m: TacMap, p_mood: String, p_day: bool, sky: ShaderMaterial = null) -> void:
	for c in get_children():
		c.queue_free()
	_mats.clear()
	counts.clear()
	current = self
	m = p_m
	mood = p_mood
	day = p_day
	sky_mat = sky
	lk = Atmosphere.look(mood, day) if Atmosphere.has(mood) else {}
	_rng.seed = hash(Vector3i(m.seed_value, mood.hash(), 77))
	_mask()
	set_ground()
	if lk.is_empty() or mood == Atmosphere.default_id():
		_rate = 0.0
		return
	var spots := _spots()
	if float(lk.get("rain", 0.0)) > 0.0:
		_rain(spots, float(lk.rain))
	if float(lk.get("flakes", 0.0)) > 0.0:
		_flakes(spots, float(lk.flakes))
	if float(lk.get("motes", 0.0)) > 0.0:
		_motes(spots, float(lk.motes))
	if float(lk.get("haze", 0.0)) > 0.0 and not m.is_tower():
		_haze(float(lk.haze))
	_rate = float(lk.get("lightning", 0.0)) / 60.0
	_next = _rng.randf_range(1.0, 3.0)
	if _rate > 0.0:
		_bolt = MeshInstance3D.new()
		_bolt.visible = false
		_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_bolt)
	if sky_mat:
		for k in ["zenith", "mid", "horizon"]:
			_sky_base[k] = sky_mat.get_shader_parameter(k)


## The ground's weather for world.gdshader (wet, rain, ice, flood), from the mood's look.
static func ground(look: Dictionary) -> Vector4:
	return Vector4(clampf(float(look.get("wet", 0.0)), 0.0, 1.0), clampf(float(look.get("rain", 0.0)), 0.0, 1.0),
		clampf(float(look.get("ice", 0.0)), 0.0, 1.0), clampf(float(look.get("flood", 0.0)), 0.0, 1.0))


func set_ground() -> void:
	RenderingServer.global_shader_parameter_set("weather", ground(lk))
	RenderingServer.global_shader_parameter_set("weather_flash", 0.0)


## Dry again (the view leaves the gig): the ground's globals back to nothing.
func clear() -> void:
	RenderingServer.global_shader_parameter_set("weather", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("weather_flash", 0.0)


func _mask() -> void:
	var img := Image.create(m.w, m.h, false, Image.FORMAT_RG8)
	for y in m.h:
		for x in m.w:
			var f := Weather.surface(m, x, y)
			var street := f == m.street and m.t(f, x, y) != TacMap.T.WATER
			img.set_pixel(x, y, Color(1.0 if street else 0.0, float(f + 1) / 255.0, 0.0))
	mask_tex = ImageTexture.create_from_image(img)


## Where particles land: [x, z, y] over every open-sky square, and the street level round the map.
func _spots() -> Array:
	var out: Array = []
	var mg := 0 if m.is_tower() else MARGIN   # a tower band has a drop round it (TowerDress rains there)
	for y in range(-mg, m.h + mg):
		for x in range(-mg, m.w + mg):
			var f := m.street if not m.inb(x, y) else Weather.surface(m, x, y)
			if f >= 0:
				out.append(Vector3(x, f * FH, y))
	return out


func _mat(kind: int) -> ShaderMaterial:
	var mt := ShaderMaterial.new()
	mt.shader = SHADER
	mt.set_shader_parameter("kind", kind)
	mt.set_shader_parameter("sky_mask", mask_tex)
	mt.set_shader_parameter("map_size", Vector2(m.w, m.h))
	mt.set_shader_parameter("street_f", float(m.street))
	mt.set_shader_parameter("day", 1.0 if day else 0.0)
	_mats.append(mt)
	return mt


func _multimesh(mt: ShaderMaterial, pts: Array, name_: String) -> void:
	if pts.is_empty():
		return
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = pts.size()
	for i in pts.size():
		var p: Array = pts[i]
		mm.set_instance_transform(i, Transform3D(Basis(), p[0]))
		mm.set_instance_custom_data(i, p[1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mt
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-MARGIN - 5, -5.0, -MARGIN - 5), Vector3(m.w + 2 * MARGIN + 10, m.floors * FH + 40.0, m.h + 2 * MARGIN + 10))
	mi.name = name_
	add_child(mi)
	counts[name_] = pts.size()


## n per square (density * per), rounded at random, capped.
func _scatter(spots: Array, per: float, cap: int, y_lo := 0.0, y_hi := 0.0, size_lo := 0.8, size_hi := 1.2) -> Array:
	var pts: Array = []
	var want := per * spots.size()
	var keep := minf(1.0, cap / maxf(want, 1.0))
	for s in spots:
		var n := int(per * keep) + int(_rng.randf() < fmod(per * keep, 1.0))
		for i in n:
			var p := Vector3(s.x + _rng.randf(), s.y + _rng.randf_range(y_lo, y_hi), s.z + _rng.randf())
			pts.append([p, Color(_rng.randf(), _rng.randf_range(0.8, 1.25), 0.0, _rng.randf_range(size_lo, size_hi))])
	return pts


func _rain(spots: Array, k: float) -> void:
	var mt := _mat(0)
	mt.set_shader_parameter("col", Atmosphere.col(lk, "rain_col", Color("b0d8ff")))
	mt.set_shader_parameter("alpha", 0.75 if not day else 0.6)
	mt.set_shader_parameter("len", float(lk.get("rain_len", 0.7)) * M)
	mt.set_shader_parameter("width", 0.085)   # a low-res pixel wide (greybox _px): thinner streaks drop out
	mt.set_shader_parameter("span", 7.0)
	mt.set_shader_parameter("speed", float(lk.get("rain_speed", 10.0)) * M)
	var ang := _rng.randf() * TAU
	mt.set_shader_parameter("wind", Vector2(cos(ang), sin(ang)) * float(lk.get("slant", 0.1)))
	_multimesh(mt, _scatter(spots, 2.4 * k, MAX_RAIN, 0.0, 0.0, 0.7, 1.3), "rain")


func _flakes(spots: Array, k: float) -> void:
	var mt := _mat(1)
	mt.set_shader_parameter("col", Atmosphere.col(lk, "flake_col", Color("d0ccc4")))
	mt.set_shader_parameter("alpha", 0.8)
	mt.set_shader_parameter("size", maxf(0.11, float(lk.get("flake_size", 0.06)) * 2.0 * M))
	mt.set_shader_parameter("span", 6.0)
	mt.set_shader_parameter("speed", float(lk.get("flake_fall", 1.0)) * M)
	mt.set_shader_parameter("glow", float(lk.get("glow", 0.0)))
	var ang := _rng.randf() * TAU
	mt.set_shader_parameter("wind", Vector2(cos(ang), sin(ang)) * float(lk.get("wind", 1.0)) * M)
	_multimesh(mt, _scatter(spots, 1.1 * k, MAX_BITS, 0.0, 0.0, 0.6, 1.4), "flakes")


func _motes(spots: Array, k: float) -> void:
	var mt := _mat(2)
	mt.set_shader_parameter("col", Atmosphere.col(lk, "mote_col", Color("e8a868")))
	mt.set_shader_parameter("alpha", 0.6)
	mt.set_shader_parameter("size", 0.09)
	mt.set_shader_parameter("span", 5.0)
	mt.set_shader_parameter("speed", float(lk.get("wind", 4.0)) * M)
	mt.set_shader_parameter("glow", float(lk.get("glow", 0.0)))
	var ang := _rng.randf() * TAU
	mt.set_shader_parameter("wind", Vector2(cos(ang), sin(ang)) * float(lk.get("wind", 4.0)) * M)
	_multimesh(mt, _scatter(spots, 1.4 * k, MAX_BITS, 0.1, 2.2, 0.6, 1.6), "motes")


func _haze(k: float) -> void:
	var col := Atmosphere.col(lk, "haze_col", Atmosphere.col(lk, "fog", Color("202430")))
	var ang := _rng.randf() * TAU
	for i in HAZE_LAYERS.size():
		var mt := _mat(3)
		mt.set_shader_parameter("col", col)
		mt.set_shader_parameter("haze_k", k * float(HAZE_LAYERS[i][1]))
		mt.set_shader_parameter("layer", float(i))
		mt.set_shader_parameter("wind", Vector2(cos(ang), sin(ang)) * maxf(0.5, float(lk.get("wind", 1.0))))
		var pm := PlaneMesh.new()
		pm.size = Vector2(m.w + 2 * MARGIN + 40, m.h + 2 * MARGIN + 40)
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = mt
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(m.w / 2.0, m.street * FH + float(HAZE_LAYERS[i][0]), m.h / 2.0)
		mi.name = "haze%d" % i
		add_child(mi)
	counts["haze"] = HAZE_LAYERS.size()


# --- Lightning ---------------------------------------------------------------------------------

## A flash now (review renders: --flash): the next frames show it.
func flash_now() -> void:
	_flash_t = 0.0
	_place_bolt()


## A flash held at its peak (review renders: --flash=1), the timer stopped.
func hold_flash() -> void:
	_place_bolt()
	_rate = 0.0
	_light(1.0)


func _exit_tree() -> void:
	if current == self:   # the next gig's weather is set already when an old view goes
		clear()


func _process(delta: float) -> void:
	if _rate <= 0.0:
		return
	if _flash_t < 0.0:
		_next -= delta
		if _next <= 0.0:
			_next = -log(maxf(_rng.randf(), 0.001)) / _rate + 1.5
			flash_now()
		return
	_flash_t += delta
	var f := _envelope(_flash_t)
	_light(f)
	if _flash_t > 0.7:
		_flash_t = -1.0
		_light(0.0)


## A flash's brightness at time t: a bright stroke, a dip, a second flicker, gone by 0.7 s.
static func _envelope(t: float) -> float:
	if t < 0.06:
		return t / 0.06
	if t < 0.16:
		return lerpf(1.0, 0.25, (t - 0.06) / 0.1)
	if t < 0.24:
		return lerpf(0.25, 0.8, (t - 0.16) / 0.08)
	return maxf(0.0, lerpf(0.8, 0.0, (t - 0.24) / 0.46))


func _light(f: float) -> void:
	RenderingServer.global_shader_parameter_set("weather_flash", f)
	if _bolt:
		_bolt.visible = f > 0.35
	if sky_mat and not _sky_base.is_empty():
		var white := Color("c8ccff")
		for k in _sky_base:
			sky_mat.set_shader_parameter(k, (_sky_base[k] as Color).lerp(white, f * (0.5 if k == "horizon" else 0.3)))


## A jagged bolt out past the map's far side, from the cloud base to the ground.
func _place_bolt() -> void:
	if _bolt == null:
		return
	var side := _rng.randi() % 4
	var c := Vector2(m.w / 2.0, m.h / 2.0)
	var far := 170.0 + _rng.randf() * 90.0   # out on the horizon, never across the play area
	var dir := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)][side] as Vector2
	var base := c + dir * (far + maxf(m.w, m.h) * 0.5) + dir.orthogonal() * _rng.randf_range(-80.0, 80.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := 140.0
	var p := Vector3(base.x, top, base.y)
	var w := 1.6
	while p.y > 0.0:
		var q := p + Vector3(_rng.randf_range(-8.0, 8.0), -_rng.randf_range(8.0, 18.0), _rng.randf_range(-8.0, 8.0))
		q.y = maxf(q.y, 0.0)
		var side_v := Vector3(w, 0, 0)
		st.add_vertex(p - side_v)
		st.add_vertex(p + side_v)
		st.add_vertex(q + side_v * 0.8)
		st.add_vertex(p - side_v)
		st.add_vertex(q + side_v * 0.8)
		st.add_vertex(q - side_v * 0.8)
		p = q
		w *= 0.92
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = Color(2.2, 2.3, 3.0)
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	mt.disable_fog = false   # the storm's air softens it
	_bolt.mesh = st.commit()
	_bolt.material_override = mt
