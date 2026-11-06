class_name UnitLook
extends RefCounted
## One character's look, shared by the 3D model and the HUD portrait so they always agree
## (round-4 critique: the portrait had a magenta mohawk, the model a brown crop).
## Crew accents avoid red/pink, which is reserved for hostiles.

const CREW_JACKETS := [Color("3f6a92"), Color("6a4a92"), Color("6a8a42"), Color("8a6a42")]
const CREW_ACCENTS := [Color("05d9e8"), Color("b537f2"), Color("f9c80e"), Color("39f0a0")]
const SKIN := [Color("e8b896"), Color("c08a68"), Color("8a5a40"), Color("5a3a2a")]
const HAIR := [Color("141018"), Color("3a2418"), Color("8a6a3a"), Color("ff2a6d"), Color("05d9e8"), Color("b537f2"), Color("dfe6ea")]
const STYLES := ["buzz", "mohawk", "long", "undercut", "bob", "ponytail", "curly", "bald", "topknot"]
## Head shapes as sphere scale (width, height, depth): narrow, wide, long, round, square-jawed.
const HEADS := [Vector3(0.135, 0.19, 0.155), Vector3(0.16, 0.18, 0.165), Vector3(0.14, 0.2, 0.155), Vector3(0.155, 0.175, 0.16), Vector3(0.15, 0.185, 0.158)]


## `team` seeds the face and picks the casual (0: crew, bystanders, captives) or uniformed (1)
## defaults; `faction` (World id) then dresses them from data/world/factions.json look.
static func make(id: int, team: int, role: String, faction := "") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id * 7919 + team * 31 + 17)
	var look := {
		"team": team,
		"role": role,
		"accent": CREW_ACCENTS[id % 4] if team == 0 else Color("ff3030"),
		"jacket": CREW_JACKETS[id % 4] if team == 0 else Color("4e555e"),
		"skin": SKIN[rng.randi() % SKIN.size()],
		"hair": HAIR[rng.randi() % HAIR.size()],
		"head_w": 6 + rng.randi() % 2,
		"style": STYLES[rng.randi() % STYLES.size()],
	}
	look["visor"] = role == "netrunner" or rng.randf() < 0.4
	look["eye_glow"] = rng.randf() < 0.5
	look["cyber"] = rng.randi() % 3   # 0 chrome jaw, 1 cheek port, 2 none
	look["head"] = HEADS[rng.randi() % HEADS.size()]
	look["jaw"] = rng.randf_range(0.85, 1.15)
	if faction != "" and faction != "crew":   # a faction's colours and kit (its own rng: faces stay put)
		var fl := World.look(faction)
		look["faction_look"] = fl
		var r2 := RandomNumberGenerator.new()
		r2.seed = hash(id * 104729 + 5)
		if fl.has("jacket"):
			look.jacket = Color(String(fl.jacket))
		elif fl.has("jackets"):
			look.jacket = Color(String(fl.jackets[r2.randi() % (fl.jackets as Array).size()]))
		if fl.has("accent"):
			look.accent = Color(String(fl.accent))
		elif fl.has("accent_from_jacket"):
			look.accent = (look.jacket as Color).lightened(float(fl.accent_from_jacket))
		if fl.has("visor"):
			look.visor = r2.randf() < float(fl.visor)
	look["trim"] = trim_of(look.get("faction_look", {}), look.accent)
	return look


## The light or coloured highlight a unit wears (armbands, helmet band, pouch flaps): the faction's
## `trim`, else its accent. Owner light review: no all-black designs, so it is lifted to at least
## TRIM_MIN_LUMA; but lighter highlights, not neon or white outfits (round 5), so it is capped at
## TRIM_MAX_S saturation and TRIM_MAX_V value: a lift raises value up to the cap, then desaturates.
const TRIM_MIN_LUMA := 0.3
const TRIM_MAX_S := 0.7
const TRIM_MAX_V := 0.8
static func trim_of(fl: Dictionary, accent: Color) -> Color:
	var c: Color = Color(String(fl.trim)) if fl.has("trim") else accent
	var h := c.h
	var s := minf(c.s, TRIM_MAX_S)
	var v := minf(c.v, TRIM_MAX_V)
	c = Color.from_hsv(h, s, v)
	for i in 12:
		if luma(c) >= TRIM_MIN_LUMA:
			break
		if v < TRIM_MAX_V:
			v = minf(v + 0.1, TRIM_MAX_V)
		else:
			s = maxf(s - 0.1, 0.0)
		c = Color.from_hsv(h, s, v)
	return c


## Display (sRGB-encoded) Rec.709 luma, 0..1.
static func luma(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## The seed team for a unit's look: 0 for the crew and people in street clothes (bystanders,
## captives), 1 for everyone in a uniform or gang colours.
static func seed_team(u: Dictionary) -> int:
	if int(u.team) == 0 and String(u.c.faction) == "crew":
		return 0
	return 0 if World.kind(String(u.c.faction)) in ["crew", "civilian", "captive"] else 1
