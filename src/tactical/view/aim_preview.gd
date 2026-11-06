class_name AimPreview
extends RefCounted
## The attack preview's shape while an enemy is hovered (playtest: nobody could tell how to attack).
## Pure: the shape comes from the weapon or kit item data, the curves are plain geometry; the
## tactical view (greybox.gd) projects them and draws them. Line of fire and cover stay with Los.
##
##   "line"   guns and other direct-fire weapons: a straight line of fire, shooter to target
##   "swing"  melee and brawling: the attacker winds up, a slice sweeps the floor toward the target
##   "throw"  thrown weapons, lobbed grenades and kit grenades: a parabola to the target square

const LINE := "line"
const SWING := "swing"
const THROW := "throw"


## A weapon's shape (null = bare hands). Melee and brawling swing; anything thrown by hand
## (Athletics, p.177), flagged `thrown`, or on the grenade launcher's lobbing range table arcs;
## every other weapon fires straight.
static func for_weapon(w: Weapon) -> String:
	if w == null or w.is_melee():
		return SWING
	if w.def.get("thrown", false) or w.skill() == "athletics" or String(w.def.get("range", "")) == "grenade_launcher":
		return THROW
	return LINE


## A kit item's shape: grenades are thrown; anything else has no attack preview ("").
static func for_item(key: String) -> String:
	return THROW if Items.use(key) == "grenade" else ""


## A kit item's blast half-width in squares (0 = no blast): every kit grenade bursts 5x5 like a frag
## (Encounter.throw_grenade, p174) unless its data gives its own area.
static func blast_half(key: String) -> int:
	if Items.use(key) != "grenade":
		return 0
	return int(Items.fx(key).get("area_half", Encounter.BLAST_HALF))


## The shape for what the active unit has armed: a target-picking tool (melee, shell, grenade ...)
## or the attack stage's mode with the drawn weapon. "" = nothing to preview.
static func for_armed(tool: String, atk_mode: String, w: Weapon, kit_key := "") -> String:
	match tool:
		"melee":
			return SWING
		"grenade":
			return for_item(kit_key) if kit_key != "" else THROW
		"shell":
			return LINE
		"":
			return SWING if atk_mode == "brawl" else for_weapon(w)
	return ""   # suppress, stabilize, jury-rig, dose: no line to one target


## A throw's parabola from a to b, peaking `peak` above the higher end: n + 1 points, a and b exact.
static func arc_points(a: Vector3, b: Vector3, peak: float, n := 16) -> PackedVector3Array:
	var out := PackedVector3Array()
	var top := maxf(a.y, b.y) + peak
	for i in n + 1:
		var t := float(i) / n
		var p := a.lerp(b, t)
		# quadratic through a.y at t=0, b.y at t=1 and the apex `top` near the middle
		p.y = (1.0 - t) * (1.0 - t) * a.y + 2.0 * (1.0 - t) * t * (2.0 * top - 0.5 * (a.y + b.y)) + t * t * b.y
		out.append(p)
	return out


## A sensible apex for a throw: higher for longer throws, never flat.
static func peak_for(dist_squares: float) -> float:
	return clampf(0.6 + dist_squares * 0.22, 0.8, 4.0)


const SQUARE_M := 2.0           ## metres per grid square (Los.distance_m)
const MUZZLE_FWD_M := 1.0       ## the line starts this far ahead of the muzzle (owner)
const CENTRE_MASS := 0.72       ## aim heights above a unit's floor, as the shot animation aims
const HEAD := 0.95
const SLICE_REACH_M := 2.0      ## the melee slice: a ~90° wedge reaching about 2 m (owner)


## Where the line of fire starts: `fwd_m` metres from the weapon toward `aim_at`, never more than
## half way there (point blank, the line still shows).
static func muzzle_origin(muzzle: Vector3, aim_at: Vector3, fwd_m := MUZZLE_FWD_M) -> Vector3:
	var d := aim_at - muzzle
	if d.length() < 0.001:
		return muzzle
	return muzzle + d.normalized() * minf(fwd_m / SQUARE_M, d.length() * 0.5)


## Where the shot goes on a unit standing at `base` (its floor point): centre mass, or the head for
## an aimed head shot.
static func aim_point(base: Vector3, head: bool) -> Vector3:
	return base + Vector3(0, HEAD if head else CENTRE_MASS, 0)


## Where a blocked line stops: on the line from `origin` to `end`, level with the blocking square's
## centre `stop` (only its x/z count).
static func stop_point(origin: Vector3, end: Vector3, stop: Vector3) -> Vector3:
	var h := Vector2(end.x - origin.x, end.z - origin.z)
	if h.length_squared() < 0.000001:
		return origin
	var t := clampf(Vector2(stop.x - origin.x, stop.z - origin.z).dot(h) / h.length_squared(), 0.0, 1.0)
	return origin.lerp(end, t)


## The yaw that faces from `from` to `to` (units face +Z at yaw 0).
static func face_yaw(from: Vector3, to: Vector3) -> float:
	return atan2(to.x - from.x, to.z - from.z)


## The melee wind-up: the attack clip a weapon swings with and the anticipation frame to hold.
static func windup(weapon_id: String) -> Array:
	return ["melee_blade", 0.22] if weapon_id.ends_with("_melee") else ["melee", 0.2]


## Last-known enemy squares (Alt marks them faintly through walls): `foes` are unit dictionaries
## (id, pos, c); `seen` says whether a square is in the crew's sight now. Foes in sight update their
## square; one seen dead is forgotten; one out of sight keeps where it was last seen.
static func remember(known: Dictionary, foes: Array, seen: Callable) -> Dictionary:
	for u in foes:
		if not seen.call(u.pos):
			continue
		if u.c.dead:
			known.erase(u.id)
		else:
			known[u.id] = u.pos
	return known
