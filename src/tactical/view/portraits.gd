class_name Portraits
extends Node
## Procedural 40×40 pixel portraits (owner: "very basic now"; v2). Painted in layers from the
## unit's UnitLook, so the portrait matches the 3D model:
## - a backdrop: a night gradient, a skyline silhouette with lit windows, and team-coloured haze
## - shoulders in three tones with a collar and Role gear: Solo shoulder plates, Netrunner hood
##   and neck-jack cable, guard tactical vest
## - a head lit from the left key, a shadowed right side and a team-coloured rim; ears, brows,
##   eyes (or a glowing visor that tints the cheeks), nose and mouth
## - four hair styles with highlights; cyberware (chrome jaw, cheek port, optic implant)
## - guards: a helmet with a highlight arc and a red visor
## - a 1-pixel ink outline around the figure
## Shown nearest-upscaled at 2x on party cards.

const S := 40
const INK := Color("05060a")

var _cache := {}


func tex(u: Dictionary) -> Texture2D:
	if _cache.has(u.id):
		return _cache[u.id]
	var t := ImageTexture.create_from_image(make(UnitLook.make(u.id, u.team, String(u.c.role))))
	_cache[u.id] = t
	return t


class _Canvas:
	var img: Image
	var fig := PackedByteArray()
	func _init() -> void:
		img = Image.create(Portraits.S, Portraits.S, false, Image.FORMAT_RGBA8)
		fig.resize(Portraits.S * Portraits.S)
	func put(x: int, y: int, c: Color, figure := true) -> void:
		if x < 0 or y < 0 or x >= Portraits.S or y >= Portraits.S:
			return
		img.set_pixel(x, y, c)
		if figure:
			fig[y * Portraits.S + x] = 1
	func get_c(x: int, y: int) -> Color:
		return img.get_pixel(clampi(x, 0, Portraits.S - 1), clampi(y, 0, Portraits.S - 1))
	func is_fig(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < Portraits.S and y < Portraits.S and fig[y * Portraits.S + x] == 1


static func make(look: Dictionary) -> Image:
	var cv := _Canvas.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(look.skin) ^ hash(look.hair) ^ int(look.head_w)
	var team: int = look.team
	var role: String = look.role
	var accent: Color = look.accent
	var jacket: Color = look.jacket
	var skin: Color = look.skin
	var hair: Color = look.hair
	var cx := 20
	var cy := 18
	var rx: int = int(look.head_w) + 1
	var ry := 9

	# --- backdrop: night gradient, skyline with lit windows, haze in the team colour
	for y in S:
		for x in S:
			var t := float(y) / S
			cv.put(x, y, Color("070a12").lerp(Color("141a2a"), t).lerp(accent.darkened(0.7), clampf((t - 0.5) * 1.2, 0, 1) * 0.5), false)
	var bx := 0
	while bx < S:
		var bw := rng.randi_range(4, 8)
		var top := rng.randi_range(16, 28)
		for y in range(top, S):
			for x in range(bx, mini(bx + bw, S)):
				var lit := (x - bx) % 2 == 1 and (y - top) % 3 == 1 and rng.randf() < 0.25
				cv.put(x, y, (Color("ffc890") if rng.randf() < 0.6 else accent.lightened(0.3)).darkened(0.35) if lit else Color("0b0e16"), false)
		bx += bw + rng.randi_range(0, 1)

	# --- shoulders and torso
	for y in range(29, S):
		var half := 10 + (y - 29) * 2
		for x in range(cx - half, cx + half):
			var u := float(x - (cx - half)) / (half * 2)
			var c := jacket.lightened(0.12) if u < 0.3 else (jacket if u < 0.7 else jacket.darkened(0.3))
			cv.put(x, y, c)
	# collar: a V with a dark inner shirt
	for y in range(29, 35):
		var w := 3 - (y - 29) / 2
		for x in range(cx - w, cx + w + 1):
			cv.put(x, y, Color("101218") if team == 0 else Color("22262c"))
	for y in range(30, S):   # accent piping down the jacket front
		cv.put(cx - 4 - (y - 30) / 3, y, accent.darkened(0.15) if team == 0 else jacket.darkened(0.45))
	if role == "solo" or team == 1:   # shoulder plates (Solo) / vest straps (guard)
		for side in [-1, 1]:
			for y in range(30, 35):
				for x in range(4):
					var px: int = cx + side * (10 + x)
					var tone := Color("4a5560") if y > 30 else Color("8a96a0")
					cv.put(px, y, tone if side < 0 else tone.darkened(0.25))
		if team == 1:
			for y in range(31, S):
				cv.put(cx - 6, y, Color("1c1f24"))
				cv.put(cx + 6, y, Color("1c1f24"))
			cv.put(cx + 7, 34, Color("c8a020"))   # badge
	if role == "netrunner":   # hood behind the head and a neck-jack cable
		for y in range(7, 31):
			for x in range(cx - rx - 3, cx + rx + 3):
				var e := pow(float(x - cx) / (rx + 3), 2) + pow(float(y - cy - 2) / (ry + 4), 2)
				if e <= 1.0 and e > 0.55:
					cv.put(x, y, jacket.darkened(0.45) if x > cx else jacket.darkened(0.25))
		for i in 6:
			cv.put(cx + 3 + i / 2, 27 + i, accent)

	# --- neck with a shadow under the jaw
	for y in range(25, 31):
		for x in range(cx - 3, cx + 3):
			cv.put(x, y, skin.darkened(0.38) if y < 27 else skin.darkened(0.22))

	# --- head: ellipse, three-tone light from the left, team rim on the right
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var e := pow(float(x - cx) / rx, 2) + pow(float(y - cy) / ry, 2)
			if e > 1.0:
				continue
			var u := float(x - cx) / rx
			var c := skin.lightened(0.1) if u < -0.35 else (skin if u < 0.35 else skin.darkened(0.25))
			if y > cy + ry - 3:
				c = c.darkened(0.12)   # jaw shadow
			if u > 0.8 and e > 0.6:
				c = c.lerp(accent, 0.45)   # rim light in the team colour
			cv.put(x, y, c)
	for side in [-1, 1]:   # ears
		for y in range(cy - 1, cy + 3):
			cv.put(cx + side * (rx + 1), y, skin.darkened(0.3 if side > 0 else 0.15))

	# --- face
	var brow := hair.darkened(0.3) if team == 0 else skin.darkened(0.5)
	for i in 3:
		cv.put(cx - 5 + i, cy - 3, brow)
		cv.put(cx + 2 + i, cy - 3, brow)
	if bool(look.visor) and team == 0:
		for x in range(cx - rx, cx + rx + 1):
			cv.put(x, cy - 1, accent.lightened(0.35))
			cv.put(x, cy, accent)
			cv.put(x, cy + 1, accent.darkened(0.45))
			if cv.is_fig(x, cy + 2):
				cv.put(x, cy + 2, cv.get_c(x, cy + 2).lerp(accent, 0.25))   # glow on the cheeks
	elif team == 0:
		for ex in [cx - 4, cx + 2]:
			cv.put(ex, cy - 1, Color("e8eef2"))
			cv.put(ex + 1, cy - 1, accent if look.eye_glow else Color("2a2030"))
			cv.put(ex, cy, skin.darkened(0.2))
			cv.put(ex + 1, cy, skin.darkened(0.2))
	for y in range(cy + 1, cy + 4):   # nose
		cv.put(cx + 1, y, skin.darkened(0.2))
	cv.put(cx, cy + 3, skin.darkened(0.35))
	for x in range(cx - 2, cx + 3):   # mouth
		cv.put(x, cy + 5, skin.darkened(0.45))
	cv.put(cx - 1, cy + 6, skin.lightened(0.08))

	if team == 1:
		# helmet with a highlight arc and a red visor
		for y in range(cy - ry - 1, cy):
			for x in range(cx - rx - 1, cx + rx + 2):
				var e2 := pow(float(x - cx) / (rx + 1), 2) + pow(float(y - cy) / (ry + 1), 2)
				if e2 <= 1.0:
					var u2 := float(x - cx) / (rx + 1)
					cv.put(x, y, Color("4a5560") if u2 < -0.3 else (Color("2e333a") if u2 < 0.5 else Color("1c1f24")))
		for x in range(cx - 4, cx + 1):
			cv.put(x, cy - ry + 1, Color("8a96a0"))
		for x in range(cx - rx, cx + rx + 1):
			cv.put(x, cy - 1, Color("ff6060"))
			cv.put(x, cy, Color("ff3030"))
			cv.put(x, cy + 1, Color("8a1818"))
		for y in range(cy, cy + ry):
			cv.put(cx - rx, y, Color("1c1f24"))   # chin strap
	else:
		_hair(cv, String(look.style), cx, cy, rx, ry, hair)
		match int(look.cyber):
			0:   # chrome jaw plate
				for x in range(cx + 1, cx + rx - 1):
					cv.put(x, cy + 7, Color("dfe6ea") if x == cx + 2 else Color("8a96a0"))
					cv.put(x, cy + 8, Color("4a5560"))
			1:   # cheek port
				cv.put(cx + rx - 2, cy + 2, accent)
				cv.put(cx + rx - 2, cy + 3, Color("66717c"))
				cv.put(cx + rx - 3, cy + 3, Color("66717c"))
			2:   # optic implant on the left eye
				if not look.visor:
					cv.put(cx - 4, cy - 1, Color("ff3b4f"))
					cv.put(cx - 5, cy - 1, Color("8a96a0"))
					cv.put(cx - 4, cy - 2, Color("8a96a0"))

	# --- 1-px ink outline around the figure
	var edge: Array[Vector2i] = []
	for y in S:
		for x in S:
			if cv.is_fig(x, y):
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if cv.is_fig(x + d.x, y + d.y):
					edge.append(Vector2i(x, y))
					break
	for p in edge:
		cv.img.set_pixel(p.x, p.y, INK)
	return cv.img


static func _hair(cv: _Canvas, style: String, cx: int, cy: int, rx: int, ry: int, hair: Color) -> void:
	var hi := hair.lightened(0.3)
	var lo := hair.darkened(0.35)
	match style:
		"buzz":
			for y in range(cy - ry, cy - ry + 4):
				for x in range(cx - rx, cx + rx + 1):
					var e := pow(float(x - cx) / rx, 2) + pow(float(y - cy) / ry, 2)
					if e <= 1.0:
						cv.put(x, y, hair if (x + y) % 2 == 0 else lo)
		"mohawk":
			for y in range(cy - ry - 4, cy - ry + 5):
				for x in range(cx - 1, cx + 2):
					cv.put(x, y, hi if x == cx - 1 else (hair if x == cx else lo))
			for y in range(cy - ry + 2, cy - 3):   # shaved sides: stubble dots
				for x in [cx - rx + 1, cx + rx - 1]:
					if (y % 2) == 0:
						cv.put(x, y, lo.darkened(0.2))
		"long":
			for y in range(cy - ry - 1, cy - 2):
				for x in range(cx - rx - 1, cx + rx + 2):
					var e2 := pow(float(x - cx) / (rx + 1), 2) + pow(float(y - cy) / (ry + 1), 2)
					if e2 <= 1.0:
						cv.put(x, y, hi if (x < cx - 2 and y < cy - ry + 3) else (hair if x < cx + 3 else lo))
			for y in range(cy - 3, cy + ry + 6):   # drapes past the jaw onto the shoulders
				for side in [-1, 1]:
					for k in 2:
						cv.put(cx + side * (rx + k), y, hair if side < 0 else lo)
		"undercut":
			for y in range(cy - ry - 1, cy - 3):
				for x in range(cx - rx - 1, cx + 3):
					var e3 := pow(float(x - cx) / (rx + 1), 2) + pow(float(y - cy) / (ry + 1), 2)
					if e3 <= 1.0:
						cv.put(x, y, hi if y < cy - ry + 2 else hair)
			for y in range(cy - ry + 2, cy - 2):   # swept fringe over the left brow
				cv.put(cx - rx, y + 2, hair)
