class_name WeaponFx
extends RefCounted
## What a weapon's attack looks and sounds like, from data/gen/weapon_fx.json: weapon id → kind
## (else by the weapon's skill, else "gun", the firearm pipeline). Fx draws the kinds; the
## greybox asks here whether an attack is a swing, a shot that ejects brass, or one that winds up.

const FALLBACK := "gun"
const GUNSHOTS := ["sfx_shot_pistol", "sfx_shot_rifle", "sfx_shot_smg", "sfx_shot_shotgun"]


static func _db() -> Dictionary:
	return RulesDB.gen("weapon_fx.json")


## The kind id for a weapon id ("gun" when nothing matches).
static func kind_of(weapon_id: String) -> String:
	var db := _db()
	var by_id: Dictionary = db.get("weapons", {})
	if by_id.has(weapon_id):
		return String(by_id[weapon_id])
	var skill := ""
	var wdb: Dictionary = RulesDB.load_json("weapons.json")["weapons"]
	if wdb.has(weapon_id):
		skill = String((wdb[weapon_id] as Dictionary).get("skill", ""))
	var by_skill: Dictionary = db.get("skills", {})
	if skill != "" and by_skill.has(skill):
		return String(by_skill[skill])
	return FALLBACK


## The kind's entry, with "kind" filled in.
static func spec(weapon_id: String) -> Dictionary:
	var k := kind_of(weapon_id)
	var kinds: Dictionary = _db().get("kinds", {})
	var s: Dictionary = (kinds.get(k, kinds.get(FALLBACK, {"visual": "gun"})) as Dictionary).duplicate()
	s["kind"] = k if kinds.has(k) else FALLBACK
	return s


static func visual(weapon_id: String) -> String:
	return String(spec(weapon_id).get("visual", "gun"))


static func is_swing(weapon_id: String) -> bool:
	return visual(weapon_id) == "melee"


static func is_gun(weapon_id: String) -> bool:
	return visual(weapon_id) == "gun"


static func ejects_brass(weapon_id: String) -> bool:
	return bool(spec(weapon_id).get("brass", false))


## Seconds of wind-up before the shot (the railgun's capacitors), 0 for most.
static func charge_secs(weapon_id: String) -> float:
	return float(spec(weapon_id).get("charge", 0.0))


## The sound when it fires (melee: the swing). Guns without their own sound get the gunshot by class.
static func shot_sound(weapon_id: String) -> String:
	var s := spec(weapon_id)
	if String(s.visual) == "melee":
		return String(s.get("swing", "sfx_swing"))
	var snd := String(s.get("shot", ""))
	return snd if snd != "" else gunshot_by_class(weapon_id)


## A melee kind's contact sound.
static func hit_sound(weapon_id: String) -> String:
	return String(spec(weapon_id).get("hit", "sfx_melee_hit"))


## The firearm report by weapon class (the pre-table behaviour, kept for plain guns and unknown ids).
static func gunshot_by_class(weapon: String) -> String:
	if weapon.contains("shotgun"):
		return "sfx_shot_shotgun"
	if weapon.contains("smg"):
		return "sfx_shot_smg"
	if weapon.contains("pistol") or weapon.contains("revolver"):
		return "sfx_shot_pistol"
	return "sfx_shot_rifle"


## Every sound the table can ask for (tests check they exist).
static func all_sounds() -> Array[String]:
	var out: Array[String] = []
	for k in (_db().get("kinds", {}) as Dictionary).values():
		for key in ["shot", "swing", "hit", "impact", "charge_sound"]:
			var n := String((k as Dictionary).get(key, ""))
			if n != "" and not out.has(n):
				out.append(n)
	return out
