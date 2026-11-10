class_name ScreenShake
extends RefCounted
## Trauma-based screen shake and hit-stop budgets for the tactical view (juice pass, owner: "slight
## screen shake on shots, stuff like that"). View-only: nothing here touches the rules.
##
## Events add trauma (0..1); trauma decays linearly at DECAY a second; the offset is smooth value
## noise scaled by trauma² (so small hits stay small and big ones fall off fast) times MAX_PX buffer
## pixels times the player's strength. The greybox rounds the offset to whole buffer pixels, so the
## pixel-art post shader never shimmers. The old directional kicks (recoil, impacts: Greybox._kick)
## scale by the same factor (kick_scale), so the Options slider and Reduced motion cover both.
##
## Strength is the Options "Screen shake" slider (GameSettings "shake", 0..1, DEFAULT 0.6): the
## tuned look is at the default, 100% is DEFAULT⁻¹ of it. Reduced motion turns shake and hit-stop off.

const DEFAULT := 0.6       ## the slider's default: the tuned amplitudes below are at this setting
const MAX_PX := 5.0        ## buffer pixels of offset at full trauma and the default strength
const DECAY := 1.8         ## trauma lost a second (a full-trauma blast settles in ~0.55 s)
const FREQ := 22.0         ## noise samples a second: a fast rattle, not a sway

## Trauma by event (added; trauma clamps at 1). Shots are by weapon (shot_trauma).
const MELEE := 0.16
const CRIT := 0.18         ## a crit's extra
const ARMOR_BREAK := 0.12  ## SP ablated by the hit
const KILL := 0.18         ## a foe flatlined
const CREW_DOWN := 0.5     ## one of the crew Mortally Wounded, knocked out or killed
const COVER_GONE := 0.22   ## a cover piece shot apart
const EXPLOSION := 0.62    ## a grenade or launcher round
const CHARGE := 0.85       ## the sabotage charge (three blasts)
const FOE_SHOT := 0.6      ## a shot fired by someone hostile to the crew shakes this much of the crew's own (blasts stay full)

## Hit-stop: a few frames' freeze (tweens, effects and units pause; input is never held).
const STOP_CRIT_MS := 80
const STOP_KILL_MS := 60
const STOP_CREW_DOWN_MS := 90
const STOP_MAX_MS := 160

## Per shot by weapon id. Autofire rounds (BURST) are each light: a burst rattles, it doesn't heave.
const SHOT := {
	"medium_pistol": 0.1, "air_pistol": 0.04, "dartgun": 0.04, "stun_gun": 0.06, "microwaver": 0.06, "shrieker": 0.08,
	"heavy_pistol": 0.15, "very_heavy_pistol": 0.2, "malorian_arms_3516": 0.26,
	"smg": 0.1, "heavy_smg": 0.13,
	"assault_rifle": 0.18, "hurricane_assault_weapon": 0.2, "sniper_rifle": 0.3,
	"shotgun": 0.34,
	"bow": 0.05, "crossbow": 0.07, "thrown_melee": 0.04, "thrown_grenade": 0.0,
	"grenade_launcher": 0.3, "cowboy_u56": 0.3, "rocket_launcher": 0.4, "rhinemetall_emg86": 0.42, "flamethrower": 0.12,
	"tsunami_helix": 0.03,
}
const BURST := 0.045
const BY_SKILL := {"handgun": 0.12, "shoulder_arms": 0.2, "heavy_weapons": 0.3, "archery": 0.05, "autofire": 0.04}
const FALLBACK := 0.14

var trauma := 0.0
var strength := DEFAULT    ## the Options slider, 0..1
var reduced := false       ## Reduced motion: no shake, no kicks, no hit-stop
var _t := 0.0
var _table := PackedFloat32Array()


func _init(p_strength := DEFAULT, p_reduced := false, seed := 2077) -> void:
	strength = p_strength
	reduced = p_reduced
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for i in 128:
		_table.append(rng.randf_range(-1.0, 1.0))


## Add trauma (clamped to 0..1).
func add(amount: float) -> void:
	trauma = clampf(trauma + maxf(amount, 0.0), 0.0, 1.0)


## Advance `delta` seconds: trauma decays, the noise moves on.
func step(delta: float) -> void:
	if delta <= 0.0:
		return
	_t += delta
	trauma = maxf(0.0, trauma - DECAY * delta)


## The amplitude factor for the player's settings: 1 at the default strength, 0 under reduced motion.
func kick_scale() -> float:
	return 0.0 if reduced else clampf(strength, 0.0, 1.0) / DEFAULT


## Peak offset (buffer px) at the current trauma.
func amplitude() -> float:
	return MAX_PX * trauma * trauma * kick_scale()


## The shake offset now, in buffer pixels (unrounded; the view rounds it).
func offset() -> Vector2:
	var a := amplitude()
	if a <= 0.0:
		return Vector2.ZERO
	return Vector2(_noise(_t * FREQ), _noise(_t * FREQ + 61.3)) * a


func _noise(x: float) -> float:
	var i := int(floorf(x))
	var f := x - floorf(x)
	var n := _table.size()
	var a := _table[posmod(i, n)]
	var b := _table[posmod(i + 1, n)]
	return lerpf(a, b, f * f * (3.0 - 2.0 * f))


## Trauma for one shot of `weapon_id` (`burst`: one round of an autofire burst).
static func shot_trauma(weapon_id: String, burst := false) -> float:
	if burst:
		return 0.02 if weapon_id == "tsunami_helix" else BURST
	if SHOT.has(weapon_id):
		return float(SHOT[weapon_id])
	var wdb: Dictionary = RulesDB.load_json("weapons.json").get("weapons", {})
	var skill := String((wdb.get(weapon_id, {}) as Dictionary).get("skill", ""))
	return float(BY_SKILL.get(skill, FALLBACK))


## A shot's trauma by who fired it: the crew's at full strength, a foe's at FOE_SHOT of it.
static func shot_by(amount: float, foe: bool) -> float:
	return amount * (FOE_SHOT if foe else 1.0)


## A hit-stop's length under the player's settings: none with reduced motion, capped at STOP_MAX_MS.
static func hit_stop_ms(ms: int, reduced_motion: bool) -> int:
	return 0 if reduced_motion else clampi(ms, 0, STOP_MAX_MS)
