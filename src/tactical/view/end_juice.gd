class_name EndJuice
extends RefCounted
## The beat when a gig ends (Greybox._end_juice): a sting, a short screen treatment, the banner
## slamming in, then the end panel. Success and failure mirror each other so both read as deliberate:
## a failure drains the colour, pulses a red edge and pushes the camera in; a success flares gold and
## lifts the colour. Fires once per gig. The panel waits PANEL_DELAY (well under the 1.5 s budget).

const PANEL_DELAY := 0.75   ## s before the end panel fades in (the banner lands first)
const PANEL_FADE := 0.2

var fired := false


## What the end of a gig in `state` ("won", "lost", "fled") does on screen and in the ear.
static func plan(state: String) -> Dictionary:
	var won := state == "won"
	return {
		"good": won,
		"sting": "sfx_gig_win" if won else "sfx_gig_fail",
		"flash": Color(1.0, 0.85, 0.35, 0.28) if won else Color(1.0, 0.1, 0.15, 0.35),
		"vignette": Color(1.0, 0.8, 0.3) if won else Color(1.0, 0.08, 0.12),
		"vignette_peak": 0.6 if won else 1.0,   # the edge pulses to this...
		"vignette_rest": 0.0 if won else 0.3,   # ...and settles here behind the end panel
		"saturation": 1.35 if won else 0.25,    # x the look's saturation, eased in...
		"saturation_rest": 1.0 if won else 0.45, # ...and where it rests
		"push": 0.94 if won else 0.86,           # camera distance factor (a slight push in)
		"shake": 3.0 if won else 6.0,
		"panel_delay": PANEL_DELAY,
	}


## The plan the first time a gig ends; {} on any later call (the view settles once).
func fire(state: String) -> Dictionary:
	if fired:
		return {}
	fired = true
	return plan(state)
