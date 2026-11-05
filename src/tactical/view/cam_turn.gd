class_name CamTurn
extends RefCounted
## Held camera turn (Q/E in gigs, owner): while a key is held the yaw turns at a steady RATE,
## easing in from rest and out to rest over EASE seconds, so a tap turns a little and a hold turns
## more. Free angles: nothing snaps on release (the cutaway, picking, panning and the markers all
## read the live camera, so no system needs a multiple of 90°). Pure maths, testable headless.

const RATE := 90.0   ## degrees a second at full speed
const EASE := 0.15   ## seconds to reach full speed from rest (and to stop from it)

var speed := 0.0     ## current turn rate, degrees a second (signed: + is E)


## Advance by `delta` seconds with `dir` held (-1 Q, +1 E, 0 neither). Returns the yaw change in
## degrees over the step, integrated exactly (constant acceleration until the goal rate is reached),
## so the total turn doesn't depend on the frame rate.
func step(dir: float, delta: float) -> float:
	if delta <= 0.0:
		return 0.0
	var goal := clampf(dir, -1.0, 1.0) * RATE
	var acc := RATE / EASE
	var v0 := speed
	var t1 := minf(absf(goal - v0) / acc, delta)   # time spent accelerating this step
	var v1 := move_toward(v0, goal, acc * t1)
	speed = v1
	return (v0 + v1) * 0.5 * t1 + v1 * (delta - t1)


func turning() -> bool:
	return speed != 0.0
