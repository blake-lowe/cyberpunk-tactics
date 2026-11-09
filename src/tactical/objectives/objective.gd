class_name Objective
extends RefCounted
## A gig's goal as a plug-in: one module per kind (data_theft, eliminate, snatch, assassinate,
## rescue, sabotage, escort, defend, deliver, plant, distraction) in this folder, registered with its tuning in data/gen/objectives.json.
## Encounter, the AI, the HUD and the view talk only to this interface, so a new kind of job is a
## new module and a data entry.
##
## State lives in `o` (Encounter.objective): a plain Dictionary with at least {kind, done}, so the
## view, the campaign report and tests can read it and it stays easy to save. Modules keep no other
## state. Rules only: no Nodes; the view turns marks() into markers.

const DIR := "res://src/tactical/objectives/"

var e: Encounter
var o: Dictionary = {}     ## the objective state (Encounter.objective)
var cfg: Dictionary = {}   ## this kind's entry in data/gen/objectives.json


## The module for `kind` (unknown kinds play as "eliminate").
static func make(kind: String, enc: Encounter) -> Objective:
	var all := RulesDB.gen("objectives.json")
	var key := kind if all.has(kind) and kind != "_doc" else "eliminate"
	var c: Dictionary = all[key]
	var script: GDScript = load(DIR + String(c.script))
	var ob: Objective = script.new()
	ob.e = enc
	ob.cfg = c
	ob.o = {"kind": key, "done": false}
	return ob


## Every registered objective kind.
static func kinds() -> Array:
	return RulesDB.gen("objectives.json").keys().filter(func(k): return k != "_doc")


# --- Hooks (override what the kind needs) ------------------------------------------------

## Place what the job needs (the mark, the package, the machine) once the guards are posted.
## `origin` is the deploy zone's first square; `sec` the effective security level.
func setup(_target_sid: int, _origin: Vector2i, _sec: int) -> void:
	pass


## Runs before every end check (a downed carrier drops the package).
func before_check() -> void:
	pass


## "won", "lost", or "" to play on. Runs after the crew-wiped check.
func check_end() -> String:
	return _cleared()


## Start of every turn (timed things: the sabotage fuse).
func tick() -> void:
	pass


## The main part is done and only getting out is left: the book's "near completion" (SPM p.28),
## where a plot twist springs (Twist) and a detection clock rolls once (Clocks). Default: done().
func near_done() -> bool:
	return done()


## Crew actions the objective offers the active unit right now: "grab", "free", "plant".
func actions() -> Array[String]:
	return []


## Do one of actions() (spends the Action). {ok, reason?}.
func act(_action: String) -> Dictionary:
	return {"ok": false, "reason": "nothing to do here"}


## Leaving through the deploy zone finishes the job (after the hit, the sabotage) instead of fleeing.
func withdraw_wins() -> bool:
	return false


## Trauma Team got `patient` (a unit id) out alive (a flatlined body they carry off doesn't call this).
func on_evacuated(_patient: int) -> void:
	pass


## The objective's full text, upper case: line 1 the order (short imperative, what a game
## objective says), later lines context (every step, alternatives). The round tab shows order()
## and current_step() instead; this stays for the log, tests and anything wanting the whole brief.
func hud_text() -> String:
	return "ELIMINATE ALL HOSTILES"


## The round tab's top line: the order, upper case ("STEAL THE DATA"). It names the job and stays
## put while the job's steps go by. Default: hud_text()'s first line.
func order() -> String:
	return hud_text().get_slice("\n", 0)


## The round tab's second line: the one step that applies right now, upper case and short
## ("GET TO AN ACCESS POINT", "HOLD 2 MORE ROUNDS"). Never an alternative ("OR ELIMINATE ALL
## HOSTILES"), never a list. Default: every hostile left.
func current_step() -> String:
	return count_text(e.opfor().size(), "HOSTILE") + " LEFT"


## Where the view points: [{cell: Vector3i, h: metres above that square's floor, label: String,
## tone: "gold" | "red" | "cyan"}], or {extract: true} for the extraction zone. `fog`: whether the
## view hides what the crew hasn't seen.
## Labels start with "★ <WHAT>" and name the person or thing where there is one ("★ TARGET · MARA
## VOSS"); the view adds the distance. "unit": the unit a mark is over, if any. A module whose
## target moves marks where the crew last knew them to be (`_sighted`) while fog is on.
func marks(_fog: bool) -> Array:
	return []


## AI: extra wish for a guard to stand on `cell` (snatch: chase the carrier, mind the package).
func ai_pull(_u: Dictionary, _cell: Vector3i) -> float:
	return 0.0


## AI: how much more a guard wants to shoot `t` (snatch: the carrier).
func ai_target_mult(_t: Dictionary) -> float:
	return 1.0


## AI: the objective's own move for guard `u` on its turn, before it fights (defend: an attacker
## beside the asset with nobody worth shooting wrecks it). True if it spent the turn.
func ai_act(_u: Dictionary) -> bool:
	return false


## Whether the site's posts are manned at setup (Encounter.setup): false for a job where the crew
## is the one holding the place (defend: the opposition comes in waves instead).
func manned() -> bool:
	return true


## Where a ward (a freed captive, the escorted client: Encounter.is_hostage) is headed, for
## AI.follow: [] for the extraction zone.
func ward_goal() -> Array:
	return []


## Squares the view tints on the floor as the objective's ground (defend's zone, escort's
## rendezvous), like the extraction squares: [{cells: Array of Vector3i, tone}], or [].
func zones() -> Array:
	return []


## Auto-play (the soak's stand-in for the player): where crew member `u` heads, as an Array of
## squares ([] to just fight), or null for the driver's own reading of the objective's state.
func crew_goal(_u: Dictionary) -> Variant:
	return null


## The interact slot's title and glyph for one of actions() (Hud.interact_here).
func action_title(action: String) -> String:
	return action.to_upper()


func action_glyph(action: String) -> String:
	return action


## The end of the Eye-Dee log line when the target File is reached in the NET (the node `node`
## and `structure` fields name it): a data theft downloads it.
func net_line() -> String:
	return ": the target data, downloaded"


## The unit the objective is about (the mark, the captive), or -1. For cameras and review shots.
func focus_unit() -> int:
	return -1


## The square the objective is about (the package, the machine), or (-1, -1, -1).
func focus_cell() -> Vector3i:
	return Vector3i(-1, -1, -1)


# --- Helpers ---------------------------------------------------------------------------

func done() -> bool:
	return bool(o.get("done", false))


## "1 ROUND", "3 ROUNDS": a count and its noun, for the HUD's steps.
static func count_text(n: int, noun: String) -> String:
	return "%d %s%s" % [n, noun, "" if n == 1 else "S"]


## What the job is about, upper case for markers and the HUD ("PROTOTYPE"), or `fallback`: the
## gig's focus item (MissionBuilder; GigSetup.name_focus sets o.item), when it has one.
func item_marker(fallback: String) -> String:
	var it: Variant = o.get("item")
	return String(it.get("marker", "")) if it is Dictionary and String(it.get("marker", "")) != "" else fallback


## The focus item in a log line ("tech prototype"), or `fallback`.
func item_short(fallback: String) -> String:
	var it: Variant = o.get("item")
	return String(it.get("short", "")) if it is Dictionary and String(it.get("short", "")) != "" else fallback


## Every guard down wins (the default for data and elimination jobs).
func _cleared() -> String:
	if e.opfor().is_empty():
		e.say("All guards are down.")
		return "won"
	return ""


## The active unit is crew, it's their turn, and they're standing at or next to `cell`.
func _crew_beside(cell: Vector3i) -> bool:
	return not e.cur.is_empty() and int(e.cur.team) == Encounter.CREW and (e.cur.pos == cell or e.adjacent(e.cur.pos, cell))


## Whether the crew can see unit `u` right now.
func _in_sight(u: Dictionary) -> bool:
	return e.vision != null and e.vision.visible.has(u.pos)


## Crew intel on unit `u`: records where they stand while the crew sees them, in o.seen (id →
## square). Returns the last known square, or `fallback` when there's none yet (no sighting).
func _sighted(u: Dictionary, fallback := Vector3i(-1, -1, -1)) -> Vector3i:
	if not o.has("seen"):
		o["seen"] = {}
	if _in_sight(u):
		o.seen[int(u.id)] = u.pos
	return o.seen.get(int(u.id), fallback)


func _extract_mark() -> Dictionary:
	return {"extract": true, "label": "EXTRACT", "tone": "gold"}


## Spend the active unit's Action; {ok: false} if it's gone.
func _use_action() -> Dictionary:
	if not e.turn.use_action():
		return {"ok": false, "reason": "no action left"}
	return {"ok": true}
