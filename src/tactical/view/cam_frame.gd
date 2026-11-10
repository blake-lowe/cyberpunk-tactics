class_name CamFrame
extends RefCounted
## Where the gig camera looks (greybox._frame_unit), as pure maths so it's testable headless:
## - the opening shot frames the first crew member and the target's street door together, zoomed
##   out as far as it takes (playtest round 4: a tester spent two minutes finding the door);
## - a new crew turn recentres on the active unit, panning only when it's off centre (owner: after
##   a death the camera stayed a little off the one unit left, since the same unit's next turn
##   didn't count as new).
## Ground coordinates are map squares (x, y); the camera orbits at `yaw` degrees, `dist` metres
## out, orthographic with a vertical size of dist * SIZE_PER_DIST (greybox._place_camera).

const SIZE_PER_DIST := 0.62
const LIFT := 0.12         ## the unit sits this share of `dist` above centre (the hotbar covers the bottom)
const FIT_W := 0.62        ## share of the half-width that's clear of the HUD panels (left party, right margin)
const FIT_H := 0.5         ## share of the half-height clear of the round box and the hotbar
const MAX_DIST := 240.0     ## past the wheel's 160: a far deploy's opening is an overview of the whole approach
const CENTRED := 0.25      ## squares: closer than this is already centred (no pan)
const CLIP_PAD := 12.0     ## metres the clip range reaches past the scene's bounds (units, fx and flyers stray)
const PERSP_NEAR := 0.05   ## the perspective look's near plane (it can't see behind itself)


## The camera's pitch at `dist` (as greybox._place_camera).
static func pitch(dist: float) -> float:
	return deg_to_rad(lerpf(36.0, 62.0, clampf(inverse_lerp(12.0, 70.0, dist), 0.0, 1.0)))


## Screen-up on the ground at `yaw`.
static func fwd(yaw: float) -> Vector2:
	return Vector2(-sin(deg_to_rad(yaw)), -cos(deg_to_rad(yaw)))


static func right(yaw: float) -> Vector2:
	return Vector2(cos(deg_to_rad(yaw)), -sin(deg_to_rad(yaw)))


## The focus that puts the square at `cell` a little above screen centre.
static func unit_focus(cell: Vector2, yaw: float, dist: float) -> Vector2:
	return cell + Vector2(0.5, 0.5) - fwd(yaw) * dist * LIFT


## Whether ground point `p` shows in the HUD-free part of the frame with the camera on `focus`.
static func fits(p: Vector2, focus: Vector2, yaw: float, dist: float, aspect: float) -> bool:
	var half_h := dist * SIZE_PER_DIST / 2.0 / sin(pitch(dist))   # ground depth: the view is tilted
	var half_w := dist * SIZE_PER_DIST / 2.0 * aspect
	var d := p - focus
	return absf(d.dot(right(yaw))) <= half_w * FIT_W and absf(d.dot(fwd(yaw))) <= half_h * FIT_H


## The opening shot: {focus: Vector2, dist: float, yaw: float} framing `unit` (a square) and
## `door` (a square) together, from `dist` out (never closer), zooming out up to MAX_DIST until
## both fit. A long way apart (a far deploy), the view turns by eighths of a turn from `yaw` to lay
## the approach across the wide screen if that needs less zoom.
static func opening(unit: Vector2, door: Vector2, yaw: float, dist: float, aspect: float) -> Dictionary:
	var best := {}
	for k in 8:
		var y := wrapf(yaw + 45.0 * k, 0.0, 360.0)
		var f := _fit(unit + Vector2(0.5, 0.5), door + Vector2(0.5, 0.5), y, dist, aspect)
		if best.is_empty() or float(f.dist) < float(best.dist) - 0.01:
			best = f
	return best


static func _fit(u: Vector2, dr: Vector2, yaw: float, dist: float, aspect: float) -> Dictionary:
	var d := dist
	var focus := (u + dr) / 2.0
	while true:
		focus = (u + dr) / 2.0 - fwd(yaw) * d * LIFT * 0.5
		if (fits(u, focus, yaw, d, aspect) and fits(dr, focus, yaw, d, aspect)) or d >= MAX_DIST:
			break
		d = minf(MAX_DIST, d * 1.1)
	return {"focus": focus, "dist": d, "yaw": yaw}


## Whether the camera on `from` needs to move to `to` (a pan, not a jump, when it does).
static func needs_recentre(from: Vector2, to: Vector2) -> bool:
	return from.distance_to(to) > CENTRED


## A new crew turn starts (and the camera recentres): a different unit, or the same unit's next
## turn (the last one standing after a death).
static func new_crew_turn(cur_id: int, crew_turn: bool, last_id: int, turn: Object, last_turn: Object) -> bool:
	return crew_turn and (cur_id != last_id or turn != last_turn)


## The camera's clip range, Vector2(near, far), holding every corner of `bounds` (the whole built
## scene: map, skyline, sky traffic) for a camera at `xf`. The orthographic camera sits only `dist`
## from its focus, so with Godot's default 0.05 near plane a tower between it and the focus rose
## through the plane and was cut off (owner, v0.10.1: background buildings clipped at low tilt). Its
## near is negative instead: an orthographic view sees behind its origin the same as in front. A
## perspective camera can't, so its near stays small.
static func clip_range(xf: Transform3D, bounds: AABB, ortho: bool) -> Vector2:
	var ahead := -xf.basis.z.normalized()
	var lo := INF
	var hi := -INF
	for i in 8:
		var d := (bounds.get_endpoint(i) - xf.origin).dot(ahead)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	var far := maxf(hi + CLIP_PAD, PERSP_NEAR + 1.0)
	return Vector2(minf(lo - CLIP_PAD, far - 1.0) if ortho else PERSP_NEAR, far)
