class_name RangeCurve
extends RefCounted
## Hit chance against distance for one shooter and one weapon, from the book's range tables
## (single shot: Range Table, CPR core p173; Autofire: its own table, p173), as a smooth curve for
## the Armory's comparison chart. Pure maths: the chart only draws what this returns.
##
## X axis, "band space" u: every range band (0-6, 7-12, 13-25, 26-50 ... 401-800 m) is one unit
## wide and linear inside the band, so u = 0 at 0 m, 1 at 6 m, 2 at 12 m ... 8 at 800 m. The book's
## bands roughly double, so this reads like a log axis, but it still starts at 0 m and gives every
## DV step the same width (a linear axis to 800 m would crush the pistol bands into a sliver).
##
## Curve fit: the table is a step function (one DV per band). For each band in range we take the
## exact hit chance P(base + d10 > DV) (Check.chance_vs_dv: exploding 10s, critical 1s) and put a
## knot at the band's midpoint (u = i + 0.5), plus flat end knots at u = 0 and at the weapon's
## maximum range. A monotone cubic Hermite spline (Fritsch-Carlson) runs through the knots: it
## passes exactly through every band's true chance at its midpoint, never overshoots between two
## neighbouring bands (no invented peaks or dips: a plateau in the table stays flat), and its peaks
## sit on the table's best band (the sniper rifle's 51-100 m). The curve ends at the last band with
## a DV; beyond it the weapon is out of range.

const SAMPLES_PER_BAND := 12


## Band upper edges in metres (weapons.json "range_bands_m").
static func edges() -> Array:
	return RulesDB.load_json("weapons.json")["range_bands_m"]


## DVs of the in-range bands, nearest first (the table's leading non-null entries).
static func band_dvs(table: String, autofire := false) -> Array[int]:
	var out: Array[int] = []
	var rows: Dictionary = RulesDB.load_json("weapons.json")["autofire_dv" if autofire else "range_dv"]
	if not rows.has(table):
		return out
	for v in rows[table]:
		if v == null:
			break
		out.append(int(v))
	return out


## Metres → band space (see above). Clamped to [0, number of bands].
static func band_u(metres: float) -> float:
	var e := edges()
	var lo := 0.0
	for i in e.size():
		var hi := float(e[i])
		if metres <= hi:
			return i + clampf((metres - lo) / (hi - lo), 0.0, 1.0)
		lo = hi
	return float(e.size())


## Band space → metres (inverse of band_u).
static func metres_at(u: float) -> float:
	var e := edges()
	var i := clampi(floori(u), 0, e.size() - 1)
	var lo := 0.0 if i == 0 else float(e[i - 1])
	return lo + (float(e[i]) - lo) * clampf(u - i, 0.0, 1.0)


## The furthest a weapon reaches in metres: the last band with a DV, cut to `cap` if given (a
## thrown weapon's 25 m, p177). 0 if the table has no bands.
static func max_range_m(table: String, autofire := false, cap := 0.0) -> float:
	var n := band_dvs(table, autofire).size()
	if n == 0:
		return 0.0
	var m := float(edges()[n - 1])
	return minf(m, cap) if cap > 0.0 else m


## Exact hit chance in each in-range band for an attack base (STAT + Skill + modifiers).
static func band_chances(base: int, table: String, autofire := false, no_fumble := false) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for dv in band_dvs(table, autofire):
		out.append(Check.chance_vs_dv(base, dv, no_fumble))
	return out


## The spline's knots (u, chance): band midpoints plus flat ends at 0 and at `end_u`.
static func knots(chances: PackedFloat32Array, end_u: float) -> PackedVector2Array:
	var k := PackedVector2Array()
	if chances.is_empty():
		return k
	k.append(Vector2(0.0, chances[0]))
	for i in chances.size():
		var u := i + 0.5
		if u < end_u:
			k.append(Vector2(u, chances[i]))
	var last_band := clampi(ceili(end_u) - 1, 0, chances.size() - 1)
	k.append(Vector2(end_u, chances[last_band]))
	return k


## Fritsch-Carlson tangents for monotone cubic Hermite interpolation through `k`.
static func tangents(k: PackedVector2Array) -> PackedFloat32Array:
	var n := k.size()
	var m := PackedFloat32Array()
	m.resize(n)
	if n < 2:
		return m
	var d := PackedFloat32Array()
	d.resize(n - 1)
	for i in n - 1:
		var dx := k[i + 1].x - k[i].x
		d[i] = 0.0 if dx <= 0.0 else (k[i + 1].y - k[i].y) / dx
	m[0] = d[0]
	m[n - 1] = d[n - 2]
	for i in range(1, n - 1):
		m[i] = 0.0 if d[i - 1] * d[i] <= 0.0 else (d[i - 1] + d[i]) / 2.0
	for i in n - 1:
		if is_zero_approx(d[i]):
			m[i] = 0.0
			m[i + 1] = 0.0
			continue
		var a := m[i] / d[i]
		var b := m[i + 1] / d[i]
		var s := a * a + b * b
		if s > 9.0:
			var t := 3.0 / sqrt(s)
			m[i] = t * a * d[i]
			m[i + 1] = t * b * d[i]
	return m


## The spline's value at `u` (held flat outside the knots).
static func evaluate(k: PackedVector2Array, m: PackedFloat32Array, u: float) -> float:
	if k.is_empty():
		return 0.0
	if u <= k[0].x:
		return k[0].y
	for i in k.size() - 1:
		if u <= k[i + 1].x:
			var h := k[i + 1].x - k[i].x
			if h <= 0.0:
				return k[i + 1].y
			var t := (u - k[i].x) / h
			var t2 := t * t
			var t3 := t2 * t
			return (2 * t3 - 3 * t2 + 1) * k[i].y + (t3 - 2 * t2 + t) * h * m[i] \
				+ (-2 * t3 + 3 * t2) * k[i + 1].y + (t3 - t2) * h * m[i + 1]
	return k[k.size() - 1].y


## The smooth curve as points (u, chance) from 0 m to the weapon's maximum range.
static func sample(base: int, table: String, autofire := false, no_fumble := false, cap := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var end_u := band_u(max_range_m(table, autofire, cap))
	if end_u <= 0.0:
		return pts
	var k := knots(band_chances(base, table, autofire, no_fumble), end_u)
	var m := tangents(k)
	var steps := maxi(2, ceili(end_u * SAMPLES_PER_BAND))
	for s in steps + 1:
		var u := end_u * s / steps
		pts.append(Vector2(u, clampf(evaluate(k, m, u), 0.0, 1.0)))
	return pts


## Everything the chart needs for `c` firing `w`: {melee, single: {...}, autofire: {...}} where
## each mode (absent if the weapon can't attack that way) is {points (u, chance), steps (exact
## chance per band), end_u, max_m, base}. The base is the game's own attack base (Attack.attack_base:
## skill, wound and armour penalties, Excellent Quality, Solo Precision Attack) and Solo Fumble
## Recovery turns off critical failures, just as in a fight.
static func for_weapon(c: Combatant, w: Weapon) -> Dictionary:
	var out := {"melee": w.is_melee()}
	if w.is_melee() or c == null:
		return out
	var nf := c.awareness_level("fumble_recovery") > 0
	var cap := float(w.fx().get("max_range_m", 0.0))
	var modes: Array = []
	if not w.fx().get("autofire_only", false):
		modes.append(["single", Attack.Mode.SINGLE, String(w.def.get("range", ""))])
	if w.autofire_mult() > 0 and w.def.has("autofire_range"):
		modes.append(["autofire", Attack.Mode.AUTOFIRE, String(w.def.autofire_range)])
	for md in modes:
		var auto: bool = md[1] == Attack.Mode.AUTOFIRE
		var table: String = md[2]
		var base := Attack.attack_base(c, w, md[1])
		var max_m := max_range_m(table, auto, cap)
		if max_m <= 0.0:
			continue
		out[md[0]] = {"points": sample(base, table, auto, nf, cap), "steps": band_chances(base, table, auto, nf),
			"end_u": band_u(max_m), "max_m": max_m, "base": base}
	return out
