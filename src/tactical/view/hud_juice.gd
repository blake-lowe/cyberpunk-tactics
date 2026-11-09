class_name HudJuice
extends Control
## Short self-freeing HUD overlays for the juice pass, kept out of Hud's panels so they can't fight
## its layout (and the objective panel, which is reworked elsewhere, is only read for its rect):
## - edge_flash: a red (or any) scanlined edge glow that pulses once and goes; its own layer, so it
##   doesn't disturb the enemy-phase vignette (Hud.enemy_phase);
## - alarm_pulse: the alarm going up, two throbs of red edge like a siren sweep;
## - objective_flourish: gold brackets snap round the objective panel, a light sweeps across it,
##   a few gold sparks and OBJECTIVE COMPLETE slides out beside it.
## Reduced motion: one soft pulse, no sweep, sparks or slide. Nothing here takes input.

const EDGE_SHADER := """shader_type canvas_item;
uniform vec4 col : source_color = vec4(1.0, 0.15, 0.2, 1.0);
uniform float amount = 0.0;
void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	float e = smoothstep(0.72, 1.0, max(d.x, d.y));
	float scan = step(2.0, mod(FRAGCOORD.y, 4.0));
	COLOR = vec4(col.rgb, e * amount * (0.6 + 0.4 * scan));
}"""

## The alarm's two throbs: [time s, amount] keys, linear between (reduced: one soft swell).
const ALARM_KEYS := [[0.0, 0.0], [0.1, 0.8], [0.42, 0.2], [0.55, 0.6], [1.25, 0.0]]
const ALARM_KEYS_CALM := [[0.0, 0.0], [0.3, 0.5], [1.0, 0.0]]
const FLOURISH_SECS := 1.6
const GOLD := Color("f9c80e")

var kind := ""
var reduced := false
var target := Rect2()      ## the objective panel, in this overlay's coordinates
var text := "OBJECTIVE COMPLETE"
var _t := 0.0
var _secs := 1.0
var _mat: ShaderMaterial
var _keys: Array = []
var _sparks: Array = []    ## [start, velocity]


static func _make(host: Control, p_kind: String, p_reduced: bool) -> HudJuice:
	var j := HudJuice.new()
	j.kind = p_kind
	j.reduced = p_reduced
	j.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(j)
	j.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return j


## A single pulse of coloured edge up to `peak` and away over `secs`.
static func edge_flash(host: Control, col: Color, peak: float, secs: float, p_reduced := false) -> HudJuice:
	if host == null or not is_instance_valid(host):
		return null
	var j := _make(host, "edge", p_reduced)
	j._edge(col)
	j._keys = [[0.0, 0.0], [0.08, peak * (0.6 if p_reduced else 1.0)], [secs, 0.0]]
	j._secs = secs
	return j


## The alarm going up: two red throbs at the screen's edge (the siren swell is the view's sound).
static func alarm_pulse(host: Control, p_reduced := false) -> HudJuice:
	if host == null or not is_instance_valid(host):
		return null
	var j := _make(host, "edge", p_reduced)
	j._edge(Color(1.0, 0.1, 0.16))
	j._keys = ALARM_KEYS_CALM if p_reduced else ALARM_KEYS
	j._secs = float(j._keys[-1][0])
	return j


## The objective is done: a gold flourish round `rect` (global, the objective panel).
static func objective_flourish(host: Control, rect: Rect2, p_reduced := false, p_text := "OBJECTIVE COMPLETE") -> HudJuice:
	if host == null or not is_instance_valid(host) or rect.size.x <= 0.0:
		return null
	var j := _make(host, "objective", p_reduced)
	var inv := host.get_global_transform().affine_inverse()
	j.target = Rect2(inv * rect.position, inv.basis_xform(rect.size))
	j.text = p_text
	j._secs = FLOURISH_SECS
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 9:
		j._sparks.append([Vector2(rng.randf_range(0.0, 1.0), rng.randf_range(0.0, 1.0)), Vector2(rng.randf_range(-120, 40), rng.randf_range(-140, -30))])
	return j


## The edge layer's value `t` seconds in (piecewise linear through `keys`).
static func key_at(keys: Array, t: float) -> float:
	if keys.is_empty():
		return 0.0
	if t <= float(keys[0][0]):
		return float(keys[0][1])
	for i in range(1, keys.size()):
		var a: Array = keys[i - 1]
		var b: Array = keys[i]
		if t <= float(b[0]):
			return lerpf(float(a[1]), float(b[1]), (t - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0])))
	return float(keys[-1][1])


func _edge(col: Color) -> void:
	var sh := Shader.new()
	sh.code = EDGE_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("col", col)
	_mat.set_shader_parameter("amount", 0.0)
	material = _mat


func _process(delta: float) -> void:
	_t += delta
	if _mat:
		_mat.set_shader_parameter("amount", key_at(_keys, _t))
	queue_redraw()
	if _t >= _secs:
		queue_free()


func _draw() -> void:
	if kind == "edge":
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)   # the shader paints the edge
		return
	if kind != "objective":
		return
	var r := target
	var t := _t
	var fade := 1.0 - clampf((t - (_secs - 0.4)) / 0.4, 0.0, 1.0)
	# brackets closing in on the panel's corners
	var k := 1.0 if reduced else _ease_out(clampf(t / 0.18, 0.0, 1.0))
	var o := lerpf(26.0, 3.0, k)
	var arm := 14.0
	var col := Color(GOLD, fade * (k if reduced else 1.0))
	for c in [[r.position + Vector2(-o, -o), Vector2(1, 0), Vector2(0, 1)], [Vector2(r.end.x + o, r.position.y - o), Vector2(-1, 0), Vector2(0, 1)],
			[Vector2(r.position.x - o, r.end.y + o), Vector2(1, 0), Vector2(0, -1)], [r.end + Vector2(o, o), Vector2(-1, 0), Vector2(0, -1)]]:
		draw_polyline(PackedVector2Array([c[0] + c[1] * arm, c[0], c[0] + c[2] * arm]), col, 3.0)
	# the panel's outline flashes gold as the brackets land
	var fl := clampf(1.0 - (t - 0.12) / 0.3, 0.0, 1.0) if t >= 0.12 else 0.0
	if fl > 0.0:
		draw_rect(r.grow(2), Color(GOLD, 0.8 * fl), false, 2.0)
		draw_rect(r, Color(GOLD, 0.12 * fl))
	if not reduced:
		# a light sweeping across the panel
		var sw := clampf((t - 0.06) / 0.38, 0.0, 1.0)
		if sw > 0.0 and sw < 1.0:
			var x := lerpf(r.position.x - 30.0, r.end.x + 10.0, _ease_out(sw))
			var band := PackedVector2Array([Vector2(x, r.position.y), Vector2(x + 22, r.position.y), Vector2(x + 8, r.end.y), Vector2(x - 14, r.end.y)])
			draw_colored_polygon(band, Color(1.0, 0.95, 0.7, 0.35 * (1.0 - sw)))
		# sparks flung from the panel's lower left
		var st := t - 0.12
		if st > 0.0 and st < 0.8:
			for sp in _sparks:
				var p0: Vector2 = r.position + Vector2(r.size.x * float(sp[0].x) * 0.6, r.size.y * (0.4 + float(sp[0].y) * 0.6))
				var p: Vector2 = p0 + sp[1] * st + Vector2(0, 260.0) * st * st
				var a := 1.0 - st / 0.8
				var s := 3.0 * a + 1.0
				draw_colored_polygon(PackedVector2Array([p + Vector2(0, -s), p + Vector2(s, 0), p + Vector2(0, s), p + Vector2(-s, 0)]), Color(GOLD, a))
	# OBJECTIVE COMPLETE slides out to the panel's left, over the world (under it sits the floor stack)
	var lt := clampf((t - 0.15) / 0.2, 0.0, 1.0)
	if lt > 0.0:
		var f: Font = Hud.F_DISPLAY if Hud.F_DISPLAY else ThemeDB.fallback_font
		var fs := 22
		var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var slide := 0.0 if reduced else (1.0 - _ease_out(lt)) * 24.0
		var pos := Vector2(r.position.x - w - 22.0 + slide, r.end.y - 10.0)
		var a := (lt if reduced else minf(1.0, lt * 2.0)) * fade
		draw_rect(Rect2(pos + Vector2(-10, -20), Vector2(w + 20, 28)), Color(0.02, 0.028, 0.04, 0.85 * a))
		draw_rect(Rect2(pos + Vector2(-10, 6), Vector2((w + 20) * (1.0 if reduced else _ease_out(lt)), 2)), Color(GOLD, a))
		draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(GOLD, a))


static func _ease_out(x: float) -> float:
	return 1.0 - (1.0 - x) * (1.0 - x) * (1.0 - x)
