class_name QualityText
extends RefCounted
## Item name typography (roadmap M10 Flavour; data in data/gen/item_type.json):
##   Poor Quality (CPR core p.342): rust / orange-brown, varied a little per item, in aLtErNaTiNg
##     case (deterministic: letters only, counted across spaces, starting lower);
##   Standard: unchanged (the caller's text, colour and font);
##   Excellent: a faint light sweep across the name every few seconds;
##   exotic weapons (weapons.json category "exotic"): each in an odd display face, chosen per
##     weapon in data/gen/exotic_fonts.json.
## Items are named by storage key ("weapon/heavy_pistol@poor", "cyberware/vampyres") or a bare
## weapon id. One style dictionary drives every surface: a Label (apply), a RichTextLabel's BBCode
## (bbcode, with SheenFx installed) and custom-drawn buttons (draw_text).

const SHEEN_COL := Color(1.0, 0.8, 0.38)   ## a warm glint: the UI text is already near white

## Renders and tests pin the sweep's clock here (seconds; < 0 = the engine clock).
static var time_override := -1.0
static var _fonts := {}
static var _shader: Shader


static func data() -> Dictionary:
	return RulesDB.gen("item_type.json")


static func exotic_data() -> Dictionary:
	return RulesDB.gen("exotic_fonts.json")


## A display family's settings (exotic_fonts.json "families": license, scale, case).
static func family(fk: String) -> Dictionary:
	return (exotic_data().get("families", {}) as Dictionary).get(fk, {})


## Credits lines for the exotic faces in use, one per licence: [heading, "Family (author), ..."].
static func font_credits() -> Array:
	const NAMES := {"OFL-1.1": "SIL Open Font License 1.1", "Apache-2.0": "Apache License 2.0"}
	var by := {}
	for id in exotic_data().weapons:
		var fk := String(exotic_data().weapons[id].family)
		var lic := String(family(fk).get("license_id", "OFL-1.1"))
		var line := "%s (%s)" % [fk, String(family(fk).get("author", ""))]
		if not by.has(lic):
			by[lic] = []
		if not line in by[lic]:
			by[lic].append(line)
	var out := []
	for lic in by:
		out.append(["Exotic weapon fonts: " + String(NAMES.get(lic, lic)), ", ".join(by[lic]) + "."])
	return out


## A display family's font file (res:// path), from any weapon that uses it.
static func font_path(fk: String) -> String:
	for id in exotic_data().weapons:
		if String(exotic_data().weapons[id].family) == fk:
			return "res://assets/fonts/" + String(exotic_data().weapons[id].file)
	return ""


## A key's item quality: "poor", "standard" or "excellent".
static func quality_of(key: String) -> String:
	key = _norm(key)
	match Items.section(key):
		"weapon":
			var t := Items.tags(key)
			return t[0] if not t.is_empty() and t[0] in ["poor", "excellent"] else "standard"
		"cyberware":
			return "excellent" if Items.base_id(key) in (data().get("excellent_cyberware", []) as Array) else "standard"
		"", "armor":
			return "standard"
	var id := Items.base_id(key)   # gear with Quality Ratings as separate entries (cyberdeck_poor, p.353)
	if id.ends_with("_poor"):
		return "poor"
	return "excellent" if id.ends_with("_excellent") else "standard"


## The display family ("Rubik Glitch"...) of an exotic weapon, or "".
static func font_key(key: String) -> String:
	key = _norm(key)
	if Items.section(key) != "weapon":
		return ""
	return String((exotic_data().weapons as Dictionary).get(Items.base_id(key), {}).get("family", ""))


static func is_exotic(weapon_id: String) -> bool:
	return String(RulesDB.weapon(weapon_id).get("category", "")) == "exotic"


## The style for `base` (the name as the caller would show it) of item `key`:
## {text, colour (Color or null = keep), font (Font or null = keep), scale, sheen, quality, font_key}.
static func style(key: String, base: String) -> Dictionary:
	var q := quality_of(key)
	var fk := font_key(key)
	var st := {"text": base, "colour": null, "font": null, "scale": 1.0, "sheen": q == "excellent", "quality": q, "font_key": fk}
	if q == "poor":
		st.text = alt_case(base)
		st.colour = rust(Items.base_id(_norm(key)))
	if fk != "":
		var spec := family(fk)
		st.font = font(fk)
		st.scale = float(spec.get("scale", 1.0))
		if String(spec.get("case", "")) == "title":
			st.text = title_case(base)
	return st


## The style of a carried weapon (null or Brawling: plain).
static func weapon_style(w: Weapon, base: String) -> Dictionary:
	return style(Items.key_of_weapon(w) if w != null else "", base)


## "Poor Heavy Pistol" → "pOoR hEaVy PiStOl": every other letter upper, starting lower; anything
## that isn't a letter is kept and doesn't advance the count. A capital I stays "i" (in the HUD's
## sans it reads as an l: "rIfLe").
static func alt_case(s: String) -> String:
	var out := ""
	var n := 0
	for i in s.length():
		var ch := s[i]
		if ch.to_upper() != ch.to_lower():
			out += ch.to_lower() if n % 2 == 0 or ch.to_lower() == "i" else ch.to_upper()
			n += 1
		else:
			out += ch
	return out


## "MALORIAN ARMS 3516" → "Malorian Arms 3516" (a capital after anything that isn't a letter).
static func title_case(s: String) -> String:
	var out := ""
	var start := true
	for i in s.length():
		var ch := s[i]
		var letter := ch.to_upper() != ch.to_lower()
		out += (ch.to_upper() if start else ch.to_lower()) if letter else ch
		start = not letter and not ch.is_valid_int()
	return out


## A Poor item's rust: a stable pick per item id inside data poor_rust (HSV), so two Poor guns
## side by side differ slightly.
static func rust(id: String) -> Color:
	var r: Dictionary = data().poor_rust
	return Color.from_hsv(_lerp(r.hue, _hash01(id, 1)), _lerp(r.sat, _hash01(id, 2)), _lerp(r.val, _hash01(id, 3)))


## An exotic display face, imported (load(), like Hud's fonts: exports don't ship the raw .ttf),
## falling back to the HUD's bold sans for any glyph it lacks.
static func font(fk: String) -> Font:
	if not _fonts.has(fk):
		var f := (load(font_path(fk)) as FontFile).duplicate() as FontFile
		f.hinting = TextServer.HINTING_LIGHT
		if Hud.F_BOLD:
			f.fallbacks = [Hud.F_BOLD]
		_fonts[fk] = f
	return _fonts[fk]


## Style a Label in place: its current text is the base name. Returns it for chaining.
static func apply(l: Label, key: String) -> Label:
	var st := style(key, l.text)
	l.text = st.text
	if st.colour is Color:
		l.add_theme_color_override("font_color", st.colour)
	var cur := l.get_theme_font("font")
	if st.font != null:
		l.add_theme_font_override("font", st.font)
	elif st.quality == "poor" and Hud.F_DISPLAY and (cur == Hud.F_DISPLAY or cur == Hud.F_PIXEL):
		l.add_theme_font_override("font", Hud.F_BOLD)   # the pixel face is caps only
	if not is_equal_approx(float(st.scale), 1.0):
		l.add_theme_font_size_override("font_size", roundi(l.get_theme_font_size("font_size") * float(st.scale)))
	if st.sheen:
		var m := sheen_material()
		l.material = m
		var fit := func() -> void: m.set_shader_parameter("width_px", maxf(8.0, minf(l.size.x, _text_w(l))))
		l.resized.connect(fit)
		fit.call()
	return l


static func _text_w(l: Label) -> float:
	return l.get_theme_font("font").get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x


## BBCode for a RichTextLabel (the stat-block tooltip): colour, face and [sheen] (install SheenFx).
static func bbcode(key: String, base: String, size := 0) -> String:
	var st := style(key, base)
	var s := String(st.text).replace("[", "[lb]")
	if st.sheen:
		s = "[sheen n=%d]%s[/sheen]" % [String(st.text).length(), s]
	if st.font != null:
		s = "[font=%s]%s[/font]" % [font_path(st.font_key), s]
		if size > 0 and not is_equal_approx(float(st.scale), 1.0):   # the face at the same height as the text around it
			s = "[font_size=%d]%s[/font_size]" % [roundi(size * float(st.scale)), s]
	if st.colour is Color:
		s = "[color=#%s]%s[/color]" % [(st.colour as Color).to_html(false), s]
	return s


## Draw a centred one-line name in a custom-drawn control (the attack stage's weapon wheel), each
## glyph lit by the sweep when Excellent. `col` is the caller's colour (its alpha is kept).
static func draw_text(ci: CanvasItem, f: Font, pos: Vector2, width: float, fs: int, col: Color, st: Dictionary) -> void:
	var text: String = st.text
	var c: Color = Color(st.colour, col.a) if st.colour is Color else col
	if not st.sheen:
		ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, width, fs, c)
		return
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var x0 := pos.x + maxf(0.0, (width - tw) / 2.0)
	var k := float(data().sheen.strength)
	for i in text.length():
		var x := f.get_string_size(text.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var a := sheen_amount(x + 3.0, tw, now())
		ci.draw_char(f, Vector2(x0 + x, pos.y), text[i], fs, Color(c.lerp(SHEEN_COL, a * k), c.a))


static func now() -> float:
	return time_override if time_override >= 0.0 else Time.get_ticks_msec() / 1000.0


## The sweep at `x` px along a `width` px name at time `t`: 0..1. One pass of sweep_s every
## period_s, a soft band band_px wide. Mirrors the shader below.
static func sheen_amount(x: float, width: float, t: float) -> float:
	var sh: Dictionary = data().sheen
	var band := float(sh.band_px)
	var p := fposmod(t, float(sh.period_s)) / float(sh.sweep_s)
	if p > 1.0:
		return 0.0
	var a := clampf(1.0 - absf(x - lerpf(-band, width + band, p)) / band, 0.0, 1.0)
	return a * a * (3.0 - 2.0 * a)


## A fresh sweep material for one Label (each has its own width).
static func sheen_material(t_override := -1.0) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHEEN_SHADER
	var sh: Dictionary = data().sheen
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("period", float(sh.period_s))
	m.set_shader_parameter("sweep", float(sh.sweep_s))
	m.set_shader_parameter("band", float(sh.band_px))
	m.set_shader_parameter("strength", float(sh.strength))
	m.set_shader_parameter("time_override", t_override if t_override >= 0.0 else time_override)
	return m


## The sweep on glyphs only: the outline (dark) is left alone so the name keeps its edge.
const SHEEN_SHADER := """
shader_type canvas_item;
uniform float width_px = 120.0;
uniform float period = 4.0;
uniform float sweep = 0.9;
uniform float band = 16.0;
uniform float strength = 0.75;
uniform float time_override = -1.0;
uniform vec3 sheen_col = vec3(1.0, 0.8, 0.38);
varying vec2 lpos;
void vertex() {
	lpos = VERTEX;
}
void fragment() {
	float t = time_override >= 0.0 ? time_override : TIME;
	float p = mod(t, period) / sweep;
	float x = lpos.x + lpos.y * 0.35;
	float a = p <= 1.0 ? clamp(1.0 - abs(x - mix(-band, width_px + band, p)) / band, 0.0, 1.0) : 0.0;
	a = a * a * (3.0 - 2.0 * a);
	float lum = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	COLOR.rgb = mix(COLOR.rgb, sheen_col, a * strength * smoothstep(0.08, 0.3, lum));
}
"""


## [sheen n=<chars>]...[/sheen] for RichTextLabels.
class SheenFx extends RichTextEffect:
	var bbcode := "sheen"

	func _process_custom_fx(fx: CharFXTransform) -> bool:
		const PX := 9.0   # about one glyph at the tooltip's size
		var n := float(fx.env.get("n", 10))
		var a := QualityText.sheen_amount(fx.relative_index * PX + PX / 2.0, n * PX, QualityText.now())
		fx.color = Color(fx.color.lerp(QualityText.SHEEN_COL, a * float(QualityText.data().sheen.strength)), fx.color.a)
		return true


static func _norm(key: String) -> String:
	if key.contains("/") or key == "":
		return key
	return "weapon/" + key


static func _hash01(s: String, salt: int) -> float:
	var h := 2166136261 ^ (salt * 16777619)
	for b in s.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xffffffff
	return float(h % 10007) / 10006.0


static func _lerp(r: Array, t: float) -> float:
	return lerpf(float(r[0]), float(r[1]), t)
