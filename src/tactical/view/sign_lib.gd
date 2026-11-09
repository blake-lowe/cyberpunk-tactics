class_name SignLib
extends RefCounted
## The sign library (owner, 2026-11-09: "a library of holo ads and neon signs for use in things").
## data/gen/signs.json lists the signs; any system asks for one by kind (neon, holo), tags (the
## site it hangs on: bar, clinic, hotel... or generic, street, sky) and form, and hands it to a
## SignBatch to place (a wall sign, a blade standing out from the wall, a holo screen). This file
## is the pure part, testable headless: the data, the two fonts, a sign's layout in glyph units,
## the holo text atlas.
##
## Neon is drawn as strokes, not pixels: STROKES is a single-line font (latin on a 4 x 6 grid, CJK
## and the icons on 6 x 6; y down) whose polylines become lit tubes (neon_tube.gdshader) with a
## coloured glow round them (neon_halo.gdshader). The CJK glyphs are real words, drawn plainly
## (each entry's `meaning` says what it reads): katakana ラーメン ホテル バー クラブ, hangul 라면 커피
## 노래방, kanji 酒 医. Holo ads write their words in the 5x7 pixel FONT (shared with TowerDress)
## from one atlas texture (atlas()).

const DATA := "signs.json"
const KINDS := ["neon", "holo"]
const NEON_FORMS := ["word", "blade", "arrow", "icon", "cjk"]
const HOLO_FORMS := {"glyphs": 0, "emblem": 1, "screen": 2, "ad": 3, "logo": 4, "ticker": 5, "dancer": 6, "product": 7}
const ANIMS := {"steady": 0, "flicker": 1, "broken": 2, "buzz": 5, "chase": 4, "cycle": 0}
const PLACE_TAGS := ["generic", "street", "sky", "food", "garage"]
## Holo second colours by index (holo.gdshader `pal`): a library holo packs its second colour's
## index into its seed (seed + 1000 * (index + 1)); 0 keeps the material's own col2.
const PALETTE := ["ff2a6d", "05d9e8", "f9c80e", "b537f2", "39f0a0", "ff8a30", "ff3030", "fff4e0", "4f8bff", "c8e8ff"]

const LATIN_W := 4.0      ## a latin letter's width on its grid; all glyphs are 6 high
const LATIN_ADV := 5.6
const CJK_ADV := 7.4
const SPACE_ADV := 3.4
const BLADE_ADV := 7.8    ## stacked down a blade

## The stroke font: polylines "x,y x,y ..." joined by "|". Latin 4 wide, CJK and icons 6 wide.
const STROKES := {
	"A": "0,6 0,1.6 1.4,0 2.6,0 4,1.6 4,6|0,3.6 4,3.6", "B": "0,0 0,6 3,6 4,5 4,4 3,3 0,3|0,0 3,0 4,1 4,2 3,3",
	"C": "4,1 3,0 1,0 0,1 0,5 1,6 3,6 4,5", "D": "0,0 0,6 2.5,6 4,4.5 4,1.5 2.5,0 0,0", "E": "4,0 0,0 0,6 4,6|0,3 3,3",
	"F": "4,0 0,0 0,6|0,3 3,3", "G": "4,1 3,0 1,0 0,1 0,5 1,6 3,6 4,5 4,3.4 2.2,3.4", "H": "0,0 0,6|4,0 4,6|0,3 4,3",
	"I": "2,0 2,6|1,0 3,0|1,6 3,6", "J": "4,0 4,5 3,6 1,6 0,5", "K": "0,0 0,6|4,0 0,3.6|1.4,2.7 4,6", "L": "0,0 0,6 4,6",
	"M": "0,6 0,0 2,3.2 4,0 4,6", "N": "0,6 0,0 4,6 4,0", "O": "1,0 3,0 4,1 4,5 3,6 1,6 0,5 0,1 1,0",
	"P": "0,6 0,0 3,0 4,1 4,2 3,3 0,3", "Q": "1,0 3,0 4,1 4,5 3,6 1,6 0,5 0,1 1,0|2.5,4.5 4,6",
	"R": "0,6 0,0 3,0 4,1 4,2 3,3 0,3|2,3 4,6", "S": "4,1 3,0 1,0 0,1 0,2 1,3 3,3 4,4 4,5 3,6 1,6 0,5",
	"T": "0,0 4,0|2,0 2,6", "U": "0,0 0,5 1,6 3,6 4,5 4,0", "V": "0,0 2,6 4,0", "W": "0,0 1,6 2,3 3,6 4,0",
	"X": "0,0 4,6|4,0 0,6", "Y": "0,0 2,3 4,0|2,3 2,6", "Z": "0,0 4,0 0,6 4,6",
	"0": "1,0 3,0 4,1 4,5 3,6 1,6 0,5 0,1 1,0|3.4,1 0.6,5", "1": "1,1 2,0 2,6|1,6 3,6", "2": "0,1 1,0 3,0 4,1 4,2 0,6 4,6",
	"3": "0,1 1,0 3,0 4,1 4,2 3,3 4,4 4,5 3,6 1,6 0,5|1.4,3 3,3", "4": "3,6 3,0 0,4 4,4",
	"5": "4,0 0,0 0,3 3,3 4,4 4,5 3,6 1,6 0,5", "6": "3,0 1,0 0,1 0,5 1,6 3,6 4,5 4,4 3,3 0,3",
	"7": "0,0 4,0 1.6,6", "8": "1,3 0,2 0,1 1,0 3,0 4,1 4,2 3,3 1,3 0,4 0,5 1,6 3,6 4,5 4,4 3,3",
	"9": "4,3 1,3 0,2 0,1 1,0 3,0 4,1 4,5 3,6 1,6", "-": "1,3 3,3", "+": "2,1.6 2,4.4|0.6,3 3.4,3",
	".": "1.8,5.8 2.2,5.8", "!": "2,0 2,4|1.8,5.8 2.2,5.8", "&": "4,6 1,2 1,1 2,0 3,1 3,2 0,4 0,5 1,6 2,6 4,3.6",
	"'": "2,0 1.6,1.6", " ": "",
	# katakana (6 wide)
	"ラ": "1.2,0.4 4.8,0.4|0.4,2 5.6,2 5.2,3.8 3.8,5.2 1.8,6", "ー": "0.4,3 5.6,3",
	"メ": "4.8,0.2 4.2,2.4 2.8,4.4 0.6,6|1.2,1.8 4.8,5", "ン": "0.8,0.8 2.2,2|0.6,5.8 3,4.8 4.6,3.2 5.6,1.2",
	"ホ": "0.4,1.8 5.6,1.8|3,0 3,5.8 2.3,5.4|1.6,3.2 0.4,5|4.4,3.2 5.6,5", "テ": "1.2,0.4 4.8,0.4|0.2,2.2 5.8,2.2|3,2.2 3,4 1.8,6",
	"ル": "2,0.4 2,3.2 0.4,6|4,0.4 4,5.8 5.8,4.2", "バ": "2.2,1.4 0.4,5.6|3.6,1.4 5.6,5.6|4.4,0 4.9,0.9|5.4,0 5.9,0.9",
	"ク": "2.4,0 0.4,2.6|1.8,1 5.2,1 4.6,3.4 1.6,6", "ブ": "0.4,1 4.8,1 4.4,3.6 1.4,6|4.6,-0.4 5.1,0.4|5.6,-0.4 6.1,0.4",
	# hangul (6 wide): 라면 커피 노래방
	"라": "0.3,0.8 3,0.8 3,2.8 0.3,2.8 0.3,4.8 3.2,4.8|4.6,0 4.6,6|4.6,3 5.8,3",
	"면": "0.5,0.3 3,0.3 3,2.6 0.5,2.6 0.5,0.3|5.2,0 5.2,3.6|3.9,0.9 5.2,0.9|3.9,2.1 5.2,2.1|1,3.9 1,5.8 5.4,5.8",
	"커": "0.3,1 3.2,1 3.2,3 2,5.6|0.6,3 3.1,3|5,0 5,6|3.8,3 5,3",
	"피": "0.3,1 3.7,1|1.2,1 1.2,4.6|2.7,1 2.7,4.6|0.2,4.6 3.8,4.6|5,0 5,6",
	"노": "1.4,0.4 1.4,2.8 4.6,2.8|3,3.6 3,5|0.4,5 5.6,5",
	"래": "0.3,0.8 2.4,0.8 2.4,2.8 0.3,2.8 0.3,4.8 2.6,4.8|3.8,0.4 3.8,5.6|3.8,3 5,3|5,0 5,6",
	"방": "0.5,0.2 0.5,2.8 3,2.8 3,0.2|0.5,1.5 3,1.5|4.6,0 4.6,3.6|4.6,1.7 5.6,1.7|2.4,3.8 3.6,3.8 4.3,4.4 4.3,5.3 3.6,5.9 2.4,5.9 1.7,5.3 1.7,4.4 2.4,3.8",
	# kanji (6 wide): 酒 (sake, liquor) 医 (medicine)
	"酒": "0.3,0.4 1.2,1.1|0.1,2.3 1,2.9|0.2,5.8 1.3,3.8|1.8,0.4 6,0.4|2.2,1.6 2.2,6|2.2,1.6 5.8,1.6 5.8,6|3.4,0.4 3.4,3.2 2.6,3.6|4.6,0.4 4.6,3.6|2.2,3.6 5.8,3.6|2.2,4.8 5.8,4.8|2.2,6 5.8,6",
	"医": "5.6,0.4 0.4,0.4 0.4,6 5.8,6|2.2,1.1 1.6,2.4|1.9,1.9 4.9,1.9|1.1,3.5 5.1,3.5|3.2,1.1 3.2,3.5 1.6,5.3|3.2,3.5 5,5.3",
	# icons (6 wide)
	"@cocktail": "0,0 6,0 3,3.4 0,0|3,3.4 3,5.6|1.4,6 4.6,6|4.2,0 5.6,-1.2",
	"@bowl": "0,2.6 6,2.6|0,2.6 0.6,4.4 1.8,5.6 4.2,5.6 5.4,4.4 6,2.6|2,6 4,6|2.2,2.1 5.6,-0.6|3.4,2.1 6.2,0|1.4,1.8 1.1,1 1.5,0.2",
	"@cross": "2,0 4,0 4,2 6,2 6,4 4,4 4,6 2,6 2,4 0,4 0,2 2,2 2,0",
	"@heart": "3,1.4 2,0.3 0.9,0.3 0,1.4 0,2.6 3,6 6,2.6 6,1.4 5.1,0.3 4,0.3 3,1.4",
	"@eye": "0,3 1.5,1.4 3,0.9 4.5,1.4 6,3 4.5,4.6 3,5.1 1.5,4.6 0,3|3,2 3.9,3 3,4 2.1,3 3,2",
	"@star": "3,0 3.75,2.2 6,2.3 4.2,3.7 4.9,6 3,4.6 1.1,6 1.8,3.7 0,2.3 2.25,2.2 3,0",
	"@pill": "1.5,1.5 4.5,1.5 5.6,2.2 6,3 5.6,3.8 4.5,4.5 1.5,4.5 0.4,3.8 0,3 0.4,2.2 1.5,1.5|3,1.5 3,4.5",
}

## 5x7 pixel letters for holo text, crown logos and blade signs (rows top down, bit 4 the left
## column). TowerDress.FONT is this.
const FONT := {
	"A": [14, 17, 17, 31, 17, 17, 17], "B": [30, 17, 17, 30, 17, 17, 30], "C": [14, 17, 16, 16, 16, 17, 14],
	"D": [28, 18, 17, 17, 17, 18, 28], "E": [31, 16, 16, 30, 16, 16, 31], "F": [31, 16, 16, 30, 16, 16, 16],
	"G": [14, 17, 16, 23, 17, 17, 15], "H": [17, 17, 17, 31, 17, 17, 17], "I": [14, 4, 4, 4, 4, 4, 14],
	"J": [7, 2, 2, 2, 2, 18, 12], "K": [17, 18, 20, 24, 20, 18, 17], "L": [16, 16, 16, 16, 16, 16, 31],
	"M": [17, 27, 21, 21, 17, 17, 17], "N": [17, 17, 25, 21, 19, 17, 17], "O": [14, 17, 17, 17, 17, 17, 14],
	"P": [30, 17, 17, 30, 16, 16, 16], "Q": [14, 17, 17, 17, 21, 18, 13], "R": [30, 17, 17, 30, 20, 18, 17],
	"S": [15, 16, 16, 14, 1, 1, 30], "T": [31, 4, 4, 4, 4, 4, 4], "U": [17, 17, 17, 17, 17, 17, 14],
	"V": [17, 17, 17, 17, 17, 10, 4], "W": [17, 17, 17, 21, 21, 21, 10], "X": [17, 17, 10, 4, 10, 17, 17],
	"Y": [17, 17, 17, 10, 4, 4, 4], "Z": [31, 1, 2, 4, 8, 16, 31],
	"0": [14, 17, 19, 21, 25, 17, 14], "1": [4, 12, 4, 4, 4, 4, 14], "2": [14, 17, 1, 2, 4, 8, 31],
	"3": [31, 2, 4, 2, 1, 17, 14], "4": [2, 6, 10, 18, 31, 2, 2], "5": [31, 16, 30, 1, 1, 17, 14],
	"6": [6, 8, 16, 30, 17, 17, 14], "7": [31, 1, 2, 4, 8, 8, 8], "8": [14, 17, 17, 14, 17, 17, 14],
	"9": [14, 17, 17, 15, 1, 2, 12], "&": [12, 18, 20, 8, 21, 18, 13], "-": [0, 0, 0, 31, 0, 0, 0],
	".": [0, 0, 0, 0, 0, 12, 12], " ": [0, 0, 0, 0, 0, 0, 0], "?": [14, 17, 1, 2, 4, 0, 4],
	"!": [4, 4, 4, 4, 4, 0, 4], ":": [0, 12, 12, 0, 12, 12, 0], "+": [0, 4, 4, 31, 4, 4, 0], "/": [1, 1, 2, 4, 8, 16, 16],
	"'": [4, 4, 8, 0, 0, 0, 0],
}

static var _db: Dictionary = {}
static var _strokes: Dictionary = {}
static var _atlas: ImageTexture = null
static var _rows: Dictionary = {}   ## holo entry id → atlas row


static func entries() -> Array:
	if _db.is_empty():
		_db = RulesDB.gen(DATA)
	return _db.signs


static func entry(id: String) -> Dictionary:
	for e in entries():
		if String(e.id) == id:
			return e
	return {}


## Signs of a kind ("" any) suiting any of `tags` (none: any), of one of `forms` (none: any); when
## nothing suits the tags, the generic ones.
static func choices(kind: String, tags: Array = [], forms: Array = []) -> Array:
	var ok := func(e: Dictionary, tg: Array) -> bool:
		if kind != "" and String(e.kind) != kind:
			return false
		if not forms.is_empty() and not String(e.form) in forms:
			return false
		return tg.is_empty() or (e.tags as Array).any(func(t): return t in tg)
	var out := entries().filter(func(e): return ok.call(e, tags))
	if out.is_empty():
		out = entries().filter(func(e): return ok.call(e, ["generic"]))
	if out.is_empty():
		out = entries().filter(func(e): return ok.call(e, []))
	return out


static func pick(rng: RandomNumberGenerator, kind: String, tags: Array = [], forms: Array = []) -> Dictionary:
	var c := choices(kind, tags, forms)
	return c[rng.randi() % c.size()] if not c.is_empty() else {}


## The tags for a site kind (sites.json): the site itself, its trade (food for places that
## serve it, shop for the ones that sell), and generic street signs (OPEN, the arrows, the ads).
static func site_tags(site: String) -> Array:
	var t := [site] if site != "" else []
	if site in ["restaurant", "bar", "club"]:
		t.append("food" if site == "restaurant" else "bar")
	if site in ["gun_shop", "chop_shop", "bd_parlor", "clinic"]:
		t.append("shop")
	t.append("generic")
	return t


# --- Strokes and layout -----------------------------------------------------------------------

static func is_cjk(ch: String) -> bool:
	return ch.length() == 1 and ch.unicode_at(0) > 0x2000


static func strokes(key: String) -> Array:
	if _strokes.has(key):
		return _strokes[key]
	var out: Array = []
	var src := String(STROKES.get(key, ""))
	for line in src.split("|", false):
		var pl := PackedVector2Array()
		for pt in line.split(" ", false):
			var xy := pt.split(",")
			pl.append(Vector2(float(xy[0]), float(xy[1])))
		out.append(pl)
	_strokes[key] = out
	return out


static func has_glyph(ch: String) -> bool:
	return STROKES.has(ch)


static func _adv(ch: String) -> float:
	if ch == " ":
		return SPACE_ADV
	return CJK_ADV if is_cjk(ch) else LATIN_ADV


static func _gw(ch: String) -> float:
	return 6.0 if is_cjk(ch) or ch.begins_with("@") else LATIN_W


## A sign laid out in glyph units (x right, y down, origin top left; letters 6 high):
## {size: Vector2, segs: [[a, b, part, colour index]], bulbs: [[p, i, n]], parts: n, letters:
## [[centre, char]] in reading order}. part: the letter (or icon) a tube belongs to, so one can
## flicker or die alone. Blades stack their letters downward, each upright.
static func layout(e: Dictionary) -> Dictionary:
	var form := String(e.form)
	var text := String(e.get("text", ""))
	var segs: Array = []
	var letters: Array = []
	var bulbs: Array = []
	var part := 0
	var size := Vector2.ZERO
	if form == "blade":
		var y := 0.0
		var wmax := 0.0
		for i in text.length():
			wmax = maxf(wmax, _gw(text[i]))
		for i in text.length():
			var ch := text[i]
			if ch == " ":
				y += 3.0
				continue
			var o := Vector2((wmax - _gw(ch)) / 2.0, y)
			_glyph(segs, ch, o, 1.0, part, 0)
			letters.append([o + Vector2(_gw(ch), 6.0) / 2.0, ch])
			part += 1
			y += BLADE_ADV
		size = Vector2(wmax, y - (BLADE_ADV - 6.0))
	else:
		var x := 0.0
		var top := 0.0
		if form == "icon":
			_glyph(segs, "@" + String(e.icon), Vector2.ZERO, 1.0, part, 1 if (e.colors as Array).size() > 1 else 0)
			letters.append([Vector2(3, 3), "@" + String(e.icon)])
			part += 1
			top = 7.4
			size = Vector2(6, 6)
		var sc := 0.55 if form == "icon" else 1.0
		var tw := _text_w(text) * sc
		if form == "icon":
			x = (6.0 - tw) / 2.0
		var x0 := x
		for i in text.length():
			var ch := text[i]
			if ch != " ":
				_glyph(segs, ch, Vector2(x, top), sc, part, 0)
				letters.append([Vector2(x + _gw(ch) * sc / 2.0, top + 3.0 * sc), ch])
				part += 1
			x += _adv(ch) * sc
		if text != "":
			size = Vector2(maxf(size.x, maxf(tw, 6.0 if form == "icon" else 0.0)), top + 6.0 * sc)
			if form == "icon" and x0 < 0.0:   # a word wider than the icon: centre the icon over it
				for s in segs:
					s[0] -= Vector2(x0, 0)
					s[1] -= Vector2(x0, 0)
				for l in letters:
					l[0] -= Vector2(x0, 0)
		if form == "arrow":   # an outline round the word, an arrowhead to the right, bulbs chasing round it
			var r := Rect2(Vector2(-1.8, -1.8), size + Vector2(3.6, 3.6))
			var tip := Vector2(r.end.x + 3.6, r.get_center().y)
			var outline := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), Vector2(r.end.x, r.position.y - 1.6), tip,
				Vector2(r.end.x, r.end.y + 1.6), Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y), r.position])
			var ci := 1 if (e.colors as Array).size() > 1 else 0
			for k in outline.size() - 1:
				segs.append([outline[k], outline[k + 1], part, ci])
			part += 1
			var per := 0.0
			for k in outline.size() - 1:
				per += outline[k].distance_to(outline[k + 1])
			var n := int(per / 1.7)
			for i in n:   # bulbs evenly round the outline, just outside it
				var d := per * i / n
				for k in outline.size() - 1:
					var l := outline[k].distance_to(outline[k + 1])
					if d <= l:
						bulbs.append([outline[k].lerp(outline[k + 1], d / l), i, n])
						break
					d -= l
			for s in segs:   # shift everything so the outline's corner is the origin
				s[0] -= r.position - Vector2(0, 1.6)
				s[1] -= r.position - Vector2(0, 1.6)
			for b in bulbs:
				b[0] -= r.position - Vector2(0, 1.6)
			for l in letters:
				l[0] -= r.position - Vector2(0, 1.6)
			size = Vector2(tip.x - r.position.x, r.size.y + 3.2)
	return {"size": size, "segs": segs, "bulbs": bulbs, "parts": part, "letters": letters}


static func _text_w(text: String) -> float:
	var w := 0.0
	for i in text.length():
		w += _adv(text[i])
	if text.length() > 0:
		w -= _adv(text[text.length() - 1]) - _gw(text[text.length() - 1])
	return w


static func _glyph(segs: Array, key: String, o: Vector2, sc: float, part: int, ci: int) -> void:
	for pl: PackedVector2Array in strokes(key):
		if pl.size() == 1:
			segs.append([o + pl[0] * sc, o + pl[0] * sc, part, ci])
		for k in pl.size() - 1:
			segs.append([o + pl[k] * sc, o + pl[k + 1] * sc, part, ci])


## Per-part animation: [anim code per part] (sign_common sign_lit), from the entry's anim and a seed.
static func part_anims(e: Dictionary, parts: int, seed_value: int) -> Array:
	var a := String(e.get("anim", "steady"))
	var out: Array = []
	out.resize(parts)
	out.fill(5 if a == "buzz" else 0)
	if parts == 0:
		return out
	var k := posmod(seed_value, parts)
	if a == "flicker":
		out[k] = 1
	elif a == "broken":
		out[k] = 2   # a dead letter
		if parts > 2:
			out[posmod(k + 1 + posmod(seed_value / 7, parts - 1), parts)] = 3   # and one sputtering
	return out


# --- Holo text atlas ----------------------------------------------------------------------------

## The holo kind code of a holo entry (holo.gdshader).
static func holo_kind(e: Dictionary) -> int:
	return int(HOLO_FORMS.get(String(e.form), 2))


## Every holo entry's name and strap line in the pixel font: one 16-pixel row each (name on top).
static func atlas() -> ImageTexture:
	if _atlas != null:
		return _atlas
	var holos := entries().filter(func(e): return String(e.kind) == "holo")
	var img := Image.create(1024, maxi(1, holos.size()) * 16, false, Image.FORMAT_R8)
	for i in holos.size():
		_rows[String(holos[i].id)] = i
		_write(img, String(holos[i].get("text", "")), i * 16)
		_write(img, String(holos[i].get("line", "")), i * 16 + 8)
	_atlas = ImageTexture.create_from_image(img)
	return _atlas


static func _write(img: Image, text: String, y0: int) -> void:
	for i in mini(text.length(), 170):
		var rows: Array = FONT.get(text[i], FONT[" "])
		for r in 7:
			for c in 5:
				if int(rows[r]) & (16 >> c):
					img.set_pixel(i * 6 + c, y0 + r, Color(1, 0, 0))


static func text_px(text: String) -> int:
	return maxi(0, text.length() * 6 - 1)


## INSTANCE_CUSTOM.w for a holo entry: its atlas row and its name's width.
static func holo_text(e: Dictionary) -> float:
	atlas()
	return float(int(_rows.get(String(e.id), 0)) * 1024 + text_px(String(e.get("text", ""))))


## INSTANCE_CUSTOM.x for a holo entry: a seed with its second colour's palette index packed in.
static func holo_seed(e: Dictionary, seed_value: int) -> float:
	var cols: Array = e.get("colors", [])
	var i := PALETTE.find(String(cols[1])) if cols.size() > 1 else -1
	return float(posmod(seed_value, 997) + 1000 * (i + 1))


static func palette() -> PackedVector3Array:
	var out := PackedVector3Array()
	for c in PALETTE:
		var cc := Color(String(c)).srgb_to_linear()
		out.append(Vector3(cc.r, cc.g, cc.b))
	return out
