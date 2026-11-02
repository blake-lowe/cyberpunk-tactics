class_name Portraits
extends Node
## Procedural 32×32 pixel portraits for the HUD (M4b critique: the rendered busts read as cubes).
## Layered from parts picked by a hash of the unit: backdrop, shoulders/jacket, neck, head shape
## with two-tone shading, hair style and colour, eyes or a glowing visor, and cyberware (chrome
## jaw, cheek ports, optic). Guards get helmets and red visors. Drawn nearest-upscaled.

const S := 32
const SKIN := [Color("e8b896"), Color("c08a68"), Color("8a5a40"), Color("5a3a2a")]
const HAIR := [Color("141018"), Color("3a2418"), Color("8a6a3a"), Color("ff2a6d"), Color("05d9e8"), Color("b537f2"), Color("dfe6ea")]

var _cache := {}


func tex(u: Dictionary) -> Texture2D:
	if _cache.has(u.id):
		return _cache[u.id]
	var t := ImageTexture.create_from_image(make(u.id, u.team, String(u.c.role)))
	_cache[u.id] = t
	return t


static func make(id: int, team: int, role: String) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id * 7919 + team * 31 + 17)
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var accent: Color = UnitModel.CREW_ACCENTS[id % 4] if team == 0 else Color("ff3030")
	var jacket: Color = UnitModel.CREW_JACKETS[id % 4] if team == 0 else Color("4a4f56")
	var skin: Color = SKIN[rng.randi() % SKIN.size()]
	var hair: Color = HAIR[rng.randi() % HAIR.size()]
	# backdrop: dark, a diagonal team-tinted band and scanlines
	for y in S:
		for x in S:
			var c := Color("0b0e16").lerp(accent.darkened(0.75), clampf((x + y - 20) / 40.0, 0, 1) * 0.6)
			if y % 3 == 0:
				c = c.darkened(0.25)
			img.set_pixel(x, y, c)
	# shoulders and jacket with a collar and an accent stripe
	for y in range(23, S):
		var half := 9 + (y - 23)
		for x in range(16 - half, 16 + half):
			if x >= 0 and x < S:
				var c := jacket.darkened(0.25) if x > 16 else jacket
				if absi(x - 16) <= 1 and y > 25:
					c = accent if team == 0 else jacket.darkened(0.5)
				img.set_pixel(x, y, c)
	# neck
	for y in range(19, 24):
		for x in range(13, 19):
			img.set_pixel(x, y, skin.darkened(0.3))
	# head: rounded rectangle, lit from the left
	var hw := 6 + rng.randi() % 2
	for y in range(7, 21):
		for x in range(16 - hw, 16 + hw):
			var corner := (y < 9 or y > 18) and (x == 16 - hw or x == 16 + hw - 1)
			if corner:
				continue
			var c := skin
			if x >= 16 + hw - 3:
				c = skin.darkened(0.28)
			if y >= 18:
				c = c.darkened(0.15)
			img.set_pixel(x, y, c)
	if team == 1:
		# helmet and red visor
		for y in range(5, 12):
			for x in range(16 - hw - 1, 16 + hw + 1):
				img.set_pixel(x, y, Color("2a2e34") if x < 16 + hw - 2 else Color("1c1f24"))
		for x in range(16 - hw, 16 + hw):
			img.set_pixel(x, 12, Color("ff3030"))
			img.set_pixel(x, 13, Color("a01818"))
		return img
	# hair styles: 0 buzz, 1 mohawk, 2 long, 3 undercut sweep
	var style := rng.randi() % 4
	for y in range(4, 12):
		for x in range(16 - hw - 1, 16 + hw + 1):
			var on := false
			match style:
				0: on = y >= 6 and y <= 8
				1: on = absi(x - 16) <= 1 or (y >= 7 and y <= 8 and absi(x - 16) <= 3)
				2: on = y >= 5
				3: on = y >= 5 and x < 16 + 2
			if on:
				img.set_pixel(x, y, hair if (x + y) % 5 != 0 else hair.lightened(0.2))
	if style == 2:
		for y in range(11, 22):
			img.set_pixel(16 - hw - 1, y, hair)
			img.set_pixel(16 + hw, y, hair.darkened(0.2))
	# eyes or visor
	if role == "netrunner" or rng.randf() < 0.4:
		for x in range(16 - hw, 16 + hw):
			img.set_pixel(x, 12, accent)
			img.set_pixel(x, 13, accent.darkened(0.4))
	else:
		for ex in [13, 18]:
			img.set_pixel(ex, 13, Color("101014"))
			img.set_pixel(ex + 1, 13, accent if rng.randf() < 0.5 else Color("e8eef2"))
	# mouth
	for x in range(15, 18):
		img.set_pixel(x, 17, skin.darkened(0.45))
	# cyberware: chrome jaw or cheek ports
	match rng.randi() % 3:
		0:
			for x in range(16 - hw + 1, 16 + hw - 1):
				img.set_pixel(x, 19, Color("b4bec6") if x % 2 == 0 else Color("66717c"))
		1:
			img.set_pixel(16 + hw - 2, 15, accent)
			img.set_pixel(16 + hw - 2, 16, Color("66717c"))
	return img
