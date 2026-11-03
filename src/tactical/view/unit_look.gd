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


static func make(id: int, team: int, role: String) -> Dictionary:
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
	# factions with their own clothes: bystanders in street colours, Trauma Team in white and
	# medical blue, MaxTac in black with hazard yellow
	match role:
		"civilian":
			look.jacket = [Color("6a5a4a"), Color("4a5a6a"), Color("7a6a5a"), Color("5a4a5a"), Color("3a4a3a"), Color("8a7a6a"), Color("6a3a3a")][rng.randi() % 7]
			look.accent = look.jacket.lightened(0.3)
		"trauma":
			look.jacket = Color("dfe6ea")
			look.accent = Color("2a8cff")
		"maxtac":
			look.jacket = Color("17191e")
			look.accent = Color("ffcc00")
	look["visor"] = role in ["netrunner", "trauma", "maxtac"] or (role != "civilian" and rng.randf() < 0.4)
	look["eye_glow"] = rng.randf() < 0.5
	look["cyber"] = rng.randi() % 3   # 0 chrome jaw, 1 cheek port, 2 none
	look["head"] = HEADS[rng.randi() % HEADS.size()]
	look["jaw"] = rng.randf_range(0.85, 1.15)
	return look
