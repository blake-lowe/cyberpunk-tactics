class_name BodyShape
extends RefCounted
## A front-view human body as a signed distance field, for the "scan" and "facet" cyberware figures:
## tapered capsules (round cones) blended with a smooth minimum, each in a body region
## (ChromeBody.Reg). Units: the figure's height is 1, the crown at y 0 and the soles at y 1, x 0 on
## the centre line, +x the viewer's right (the figure faces us: its right side is at -x). Proportions
## after the eight-heads canon (a head 0.125; chin 1/8, nipples 2/8, navel 3/8, crotch 4/8, knees
## ~6/8), arms a little off the body. The shader (body_scan.gdshader) reads the same parts (parts()).

const RG := ChromeBody.Reg
## The frame's width over its height (the hands reach x ±0.235).
const ASPECT := 0.5

## The centre's parts and one side's: [from, to, r from, r to, blend, region]. Side parts are given
## at +x (the figure's left) and mirrored; their region names the kind (R_ARM an arm, L_FORE a
## forearm or hand, R_LEG a leg, TORSO the trunk) and parts() gives each side its own.
const CENTRE := [
	[Vector2(0, 0.050), Vector2(0, 0.064), 0.047, 0.046, 0.0, RG.HEAD],      # cranium
	[Vector2(0, 0.078), Vector2(0, 0.106), 0.039, 0.019, 0.012, RG.HEAD],    # jaw to chin
	[Vector2(0, 0.112), Vector2(0, 0.158), 0.025, 0.029, 0.012, RG.NECK],
	[Vector2(0, 0.214), Vector2(0, 0.318), 0.094, 0.082, 0.02, RG.TORSO],    # rib cage
	[Vector2(0, 0.318), Vector2(0, 0.405), 0.079, 0.074, 0.03, RG.TORSO],    # waist
	[Vector2(0, 0.420), Vector2(0, 0.478), 0.084, 0.070, 0.03, RG.TORSO],    # pelvis
]
const SIDE := [
	[Vector2(0.018, 0.150), Vector2(0.100, 0.176), 0.022, 0.020, 0.025, RG.TORSO],    # trapezius
	[Vector2(0.044, 0.222), Vector2(0.058, 0.234), 0.048, 0.042, 0.02, RG.TORSO],     # pectoral
	[Vector2(0.046, 0.410), Vector2(0.056, 0.455), 0.044, 0.050, 0.03, RG.TORSO],     # hip
	[Vector2(0.066, 0.240), Vector2(0.058, 0.330), 0.040, 0.030, 0.02, RG.TORSO],     # latissimus
	[Vector2(0.124, 0.190), Vector2(0.138, 0.232), 0.036, 0.029, 0.018, RG.R_ARM],    # deltoid
	[Vector2(0.136, 0.222), Vector2(0.163, 0.372), 0.031, 0.025, 0.012, RG.R_ARM],    # upper arm
	[Vector2(0.144, 0.262), Vector2(0.153, 0.318), 0.033, 0.029, 0.012, RG.R_ARM],    # biceps
	[Vector2(0.165, 0.378), Vector2(0.192, 0.497), 0.027, 0.018, 0.01, RG.L_FORE],    # forearm
	[Vector2(0.170, 0.395), Vector2(0.180, 0.440), 0.031, 0.025, 0.01, RG.L_FORE],    # forearm's swell
	[Vector2(0.194, 0.505), Vector2(0.200, 0.545), 0.022, 0.024, 0.008, RG.L_FORE],   # palm
	[Vector2(0.201, 0.548), Vector2(0.209, 0.590), 0.021, 0.012, 0.008, RG.L_FORE],   # fingers
	[Vector2(0.048, 0.485), Vector2(0.057, 0.700), 0.055, 0.035, 0.022, RG.R_LEG],    # thigh
	[Vector2(0.060, 0.520), Vector2(0.060, 0.600), 0.044, 0.040, 0.02, RG.R_LEG],     # outer thigh
	[Vector2(0.058, 0.702), Vector2(0.060, 0.744), 0.035, 0.032, 0.01, RG.R_LEG],     # knee
	[Vector2(0.061, 0.748), Vector2(0.066, 0.930), 0.034, 0.019, 0.01, RG.R_LEG],     # shin
	[Vector2(0.069, 0.770), Vector2(0.067, 0.840), 0.039, 0.033, 0.014, RG.R_LEG],    # calf
	[Vector2(0.066, 0.930), Vector2(0.071, 0.972), 0.020, 0.024, 0.008, RG.R_LEG],    # ankle, heel
	[Vector2(0.071, 0.972), Vector2(0.082, 0.990), 0.024, 0.012, 0.008, RG.R_LEG],    # foot
]

## Where each location's leader line meets the body (BodyShape units).
const ANCHORS := {"neural_link": Vector2(0, 0.02), "right_eye": Vector2(-0.016, 0.057), "left_eye": Vector2(0.016, 0.057),
	"cyberaudio": Vector2(0.046, 0.066), "chipware": Vector2(0, 0.136), "internal": Vector2(0.014, 0.252),
	"borgware": Vector2(0.112, 0.186), "right_arm": Vector2(-0.152, 0.300), "left_arm": Vector2(0.152, 0.300),
	"fashion": Vector2(0.182, 0.448), "external": Vector2(-0.112, 0.560), "right_leg": Vector2(-0.066, 0.805),
	"left_leg": Vector2(0.066, 0.805)}

static var _parts: Array = []


## Every part, the sides mirrored: [from, to, r from, r to, blend, region]. The figure's right side
## (at -x) takes the right regions; the forearm and hand are the left's L_FORE, the right's R_ARM.
static func parts() -> Array:
	if not _parts.is_empty():
		return _parts
	_parts = CENTRE.duplicate(true)
	for p in SIDE:
		var reg: int = p[5]
		var left := reg
		var right := reg
		match reg:
			RG.R_ARM, RG.L_FORE:
				left = RG.L_ARM if reg == RG.R_ARM else RG.L_FORE
				right = RG.R_ARM
			RG.R_LEG:
				left = RG.L_LEG
				right = RG.R_LEG
		_parts.append([p[0], p[1], p[2], p[3], p[4], left])
		_parts.append([Vector2(-p[0].x, p[0].y), Vector2(-p[1].x, p[1].y), p[2], p[3], p[4], right])
	return _parts


## The signed distance of a 2D point to a round cone (iq's uneven capsule).
static func cone(p: Vector2, a: Vector2, b: Vector2, ra: float, rb: float) -> float:
	p -= a
	var pb := b - a
	var h := pb.dot(pb)
	if h < 1e-10:
		return p.length() - ra
	var q := Vector2(p.dot(Vector2(pb.y, -pb.x)), p.dot(pb)) / h
	q.x = absf(q.x)
	var bb := ra - rb
	var c := Vector2(sqrt(maxf(h - bb * bb, 0.0)), bb)
	var k := c.x * q.y - c.y * q.x
	var m := c.dot(q)
	var n := q.dot(q)
	if k < 0.0:
		return sqrt(h * n) - ra
	if k > c.x:
		return sqrt(h * (n + 1.0 - 2.0 * q.y)) - rb
	return m - ra


static func smin(a: float, b: float, k: float) -> float:
	if k <= 0.0:
		return minf(a, b)
	var h := clampf(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
	return lerpf(b, a, h) - k * h * (1.0 - h)


## [distance (negative inside), region of the nearest part].
static func sample(p: Vector2) -> Array:
	var d := 1e9
	var best := 1e9
	var reg := 0
	for q in parts():
		var di := cone(p, q[0], q[1], q[2], q[3])
		d = smin(d, di, q[4])
		if di < best:
			best = di
			reg = q[5]
	return [d, reg]


static func dist(p: Vector2) -> float:
	return float(sample(p)[0])


## The parts packed for the shader: from.xy to.xy, and r from, r to, blend, region.
static func packed() -> Array:
	var a := PackedVector4Array()
	var b := PackedVector4Array()
	for q in parts():
		a.append(Vector4(q[0].x, q[0].y, q[1].x, q[1].y))
		b.append(Vector4(q[2], q[3], q[4], float(q[5])))
	return [a, b]
