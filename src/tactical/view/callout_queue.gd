class_name CalloutQueue
extends RefCounted
## Where floating callouts go over a unit (Greybox._float), and the wound-state words.
## Each unit has a lane. A new callout spawns one line above the highest callout still up in its
## lane, so callouts that land together stack, and one that lands later never sits on an earlier one
## as both rise. Every callout rises the same way (`rise`: the same speed, capped). The cap makes the
## rise subadditive, so the gap between neighbours never shrinks below LINE.
## Wound-state words (WOUND) wait a beat after the hit's own callouts (the damage number, HEADSHOT,
## CRITICAL · ...) so they read last and on top, and back to back they keep a gap of WOUND_GAP_MS.

const LINE := 34.0          ## px between stacked callouts (the 30 px display face plus its outline)
const RISE := 46.0          ## px a callout climbs...
const RISE_MS := 1300       ## ...over this long, then it holds
const LIFE_MS := 1300       ## a plain callout's time on screen (it fades over the last 500 ms)
const WOUND_LIFE_MS := 1900 ## wound words stay up longer: they are what the player needs to read
const WOUND_DELAY_MS := 240 ## after the hit's other callouts
const WOUND_GAP_MS := 320   ## between two wound words on one unit (MORTALLY WOUNDED, then FLATLINED)

## Wound-state change → word, colour (by severity: green, cold blue, amber, red, magenta), sound
## (tools/gen_audio.py) and its level in dB. Owner: unconscious is a status, not a death (UNCONSCIOUS);
## the death states sound of impacts and breath only, no heartbeat or monitor tone.
const WOUND := {
	"stabilized": {"text": "STABILIZED", "col": Color("39f0a0"), "sfx": "sfx_stabilized", "vol": -4.0},
	"unconscious": {"text": "UNCONSCIOUS", "col": Color("8fb4ff"), "sfx": "sfx_unconscious", "vol": -3.0},
	"serious": {"text": "SERIOUSLY WOUNDED", "col": Color("ffb000"), "sfx": "sfx_wound_serious", "vol": -4.0},
	"mortal": {"text": "MORTALLY WOUNDED", "col": Color("ff3b4f"), "sfx": "sfx_wound_mortal", "vol": 0.0},
	"flatlined": {"text": "FLATLINED", "col": Color("ff2a6d"), "sfx": "sfx_collapse", "vol": -3.0},
}

var _lanes := {}       ## lane key → Array of {y, at, life}
var _wound_at := {}    ## lane key → msec the last wound word was booked for


## The wound-state word for a change ("" for none). `dead`: flatlined by this; `knocked_out`: knocked
## unconscious by this (a stun hit). A unit already Mortally Wounded that is hit again gets nothing
## new; going straight from on its feet to dead (no Death Saves, NPCs) is FLATLINED.
static func wound_key(before: int, after: int, dead: bool, knocked_out := false) -> String:
	if dead and before < Combatant.Wound.DEAD:
		return "flatlined"
	if knocked_out:
		return "unconscious"
	if before < Combatant.Wound.MORTAL and after == Combatant.Wound.MORTAL:
		return "mortal"
	if before < Combatant.Wound.SERIOUS and after == Combatant.Wound.SERIOUS:
		return "serious"
	return ""


## How far a callout has climbed `age_ms` after it appeared (px, upward).
static func rise(age_ms: float) -> float:
	return RISE * clampf(age_ms / RISE_MS, 0.0, 1.0)


## Book a wound word on `key` asked for at `now`: msec to wait before it shows.
func wound_delay(key: Variant, now: int) -> int:
	var at := maxi(now + WOUND_DELAY_MS, int(_wound_at.get(key, -100000)) + WOUND_GAP_MS)
	_wound_at[key] = at
	return at - now


## A callout appears on `key` now: its vertical offset from the lane's anchor (px, negative is up).
## `h`: its line height (a damage number's bigger face needs more than LINE: CalloutPop.line_height);
## `over`: how far its pop overshoots past that, up and down (CalloutPop.overshoot). It lands its own
## height plus both pops' overshoot above the highest callout still up, so a big crit number and the
## morale or wound word over it never touch.
func place(key: Variant, now: int, life := LIFE_MS, h := LINE, over := 0.0) -> float:
	var lane: Array = live(key, now)
	var y := 0.0
	if not lane.is_empty():
		var top := INF
		var top_over := 0.0
		for c in lane:
			var cy := y_at(c, now)
			if cy < top:
				top = cy
				top_over = float(c.get("over", 0.0))
		y = top - maxf(h, LINE) - top_over - over
	lane.append({"y": y, "at": now, "life": life, "over": over})
	_lanes[key] = lane
	return y


## Callouts still up on `key` at `now`.
func live(key: Variant, now: int) -> Array:
	return (_lanes.get(key, []) as Array).filter(func(c): return now < int(c.at) + int(c.life))


## Where callout `c` (from `live`) is at `now`: its offset plus the climb so far.
static func y_at(c: Dictionary, now: int) -> float:
	return float(c.y) - rise(now - int(c.at))
