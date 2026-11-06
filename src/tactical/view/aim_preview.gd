class_name AimPreview
extends RefCounted
## The attack preview's shape while an enemy is hovered (playtest: nobody could tell how to attack).
## Pure: the shape comes from the weapon or kit item data, the curves are plain geometry; the
## tactical view (greybox.gd) projects them and draws them. Line of fire and cover stay with Los.
##
##   "line"   guns and other direct-fire weapons: a straight line of fire, shooter to target
##   "swing"  melee and brawling: a short arc swept across the target
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


## A swing: an arc of `radius` round `centre`, facing back toward `from`, sweeping `deg` degrees
## from high on one side to lower on the other (a diagonal cut). n + 1 points.
static func swing_points(centre: Vector3, from: Vector3, radius := 0.7, deg := 110.0, n := 12) -> PackedVector3Array:
	var out := PackedVector3Array()
	var back := Vector3(from.x - centre.x, 0, from.z - centre.z)
	back = back.normalized() if back.length() > 0.001 else Vector3.BACK
	for i in n + 1:
		var t := float(i) / n
		var ang := deg_to_rad(-deg * 0.5 + deg * t)
		var p := centre + back.rotated(Vector3.UP, ang) * radius
		p.y += lerpf(0.35, -0.25, t)
		out.append(p)
	return out


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
