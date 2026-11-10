class_name CalloutPop
extends RefCounted
## How a floating callout pops in (Greybox._float_at), by style. Pure numbers, testable headless.
## - "" (words: HEADSHOT, DODGE, wound states): the plain slam, 1.25x settling to 1 (unchanged).
## - "dmg": a damage number pops from small past full size and settles, drifting aside on an
##   ease-out arc with a little tilt, while it rises like every callout (CalloutQueue.rise).
## - "crit": the same, bigger and hotter (the view colours it), with more overshoot.
## - "ping": an armour tick (ARMOR, SP 11→10) that hops sideways fast and small, like a ricochet.
## Reduced motion: no overshoot, drift or tilt; the callout fades in at its resting size.
## The vertical stacking is CalloutQueue's and untouched: only scale, x and rotation move here.

const STYLES := {
	"": {"from": 1.25, "peak": 1.25, "up": 0.0, "rest": 1.0, "settle": 0.12, "drift": 0.0, "tilt": 0.0, "arc_ms": 1.0, "size": 30, "size_short": 40},
	"dmg": {"from": 0.4, "peak": 1.45, "up": 0.07, "rest": 1.0, "settle": 0.16, "drift": 16.0, "tilt": 0.1, "arc_ms": 420.0, "size": 40, "size_short": 40},
	"crit": {"from": 0.3, "peak": 1.7, "up": 0.08, "rest": 1.0, "settle": 0.22, "drift": 22.0, "tilt": 0.16, "arc_ms": 480.0, "size": 46, "size_short": 46},
	"ping": {"from": 1.35, "peak": 1.35, "up": 0.0, "rest": 0.9, "settle": 0.1, "drift": 26.0, "tilt": 0.22, "arc_ms": 200.0, "size": 22, "size_short": 26},
}


## The pop for `style` ("" when unknown). `right`: which way it drifts (the view picks at random).
static func plan(style: String, reduced: bool, right := true) -> Dictionary:
	var p: Dictionary = (STYLES.get(style, STYLES[""]) as Dictionary).duplicate()
	var sgn := 1.0 if right else -1.0
	p.drift = float(p.drift) * sgn
	p.tilt = -float(p.tilt) * sgn   # leans into the way it flies
	p.fade_in = false
	if reduced:   # no overshoot, drift or tilt: it fades in where it rests
		p.from = p.rest
		p.peak = p.rest
		p.up = 0.0
		p.drift = 0.0
		p.tilt = 0.0
		p.fade_in = true
	return p


## The callout's font size (px) for `style` and its text (short words and numbers set larger).
static func font_size(style: String, text: String) -> int:
	var p: Dictionary = STYLES.get(style, STYLES[""])
	return int(p.size_short) if text.length() <= 3 else int(p.size)


## How far along its sideways arc a callout is `ms` after it appeared (0..1, ease-out).
static func arc(ms: float, arc_ms: float) -> float:
	var k := clampf(ms / maxf(arc_ms, 1.0), 0.0, 1.0)
	return 1.0 - (1.0 - k) * (1.0 - k)


## The callout's line in a lane (CalloutQueue.place): its face plus the outline.
static func line_height(style: String, text: String) -> float:
	return float(font_size(style, text)) + 4.0


## How far its pop's overshoot reaches past its line, up and down (it scales about its middle).
static func overshoot(style: String, text: String) -> float:
	var p: Dictionary = STYLES.get(style, STYLES[""])
	return maxf(0.0, float(p.peak) - 1.0) * line_height(style, text) / 2.0
