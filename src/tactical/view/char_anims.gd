class_name CharAnims
extends RefCounted
## The shared animation library for CharModel. Every clip is retargeted at import onto Godot's
## humanoid profile (tools/retarget_imports.py), so Mixamo and Quaternius clips play on any
## character. Clips come from the curated Mixamo set in assets/mixamo (picked from the owner's
## library by tools/import_mixamo.py), plus a few CC0 Quaternius UAL clips Mixamo lacks.
## Locomotion clips are made in-place (the hips' forward drift is removed) and their native
## ground speed is kept in `speed`, so the view can scale playback to the walk speed.

const MX := "res://assets/mixamo/%s.fbx"
const UAL := {"ual1": "res://assets/third_party/quaternius/animations/UAL1_Standard.glb",
	"ual2": "res://assets/third_party/quaternius/animations/UAL2_Standard.glb"}

## name → source: "mx:<file>" or "ual1:<anim>" / "ual2:<anim>".
const CLIPS := {
	"rifle_idle": "mx:rifle_idle",
	"rifle_aim": "mx:rifle_aim",
	"rifle_crouch": "mx:rifle_crouch",
	"rifle_crouch_aim": "mx:rifle_crouch_aim",
	"rifle_walk": "mx:rifle_walk",
	"rifle_run": "mx:rifle_run",
	"rifle_sprint": "mx:rifle_sprint",
	"rifle_reload": "mx:rifle_reload",
	"pistol_idle": "mx:pistol_idle",
	"pistol_aim": "ual1:Pistol_Aim_Neutral",
	"pistol_walk": "mx:pistol_walk",
	"pistol_run": "mx:pistol_run",
	"pistol_sprint": "ual1:Sprint",   # owner: was a duplicate of pistol_run; a full sprint, pistol in one hand
	"pistol_crouch": "mx:pistol_kneel",
	"pistol_reload": "ual1:Pistol_Reload",
	"injured_idle": "mx:injured_idle",
	"injured_walk": "mx:injured_walk",
	"injured_run": "mx:injured_run",
	"dying": "mx:kneel_inspect",
	"hit_a": "mx:hit_1",
	"hit_b": "mx:hit_2",
	"hit_rifle": "mx:rifle_hit",
	"dodge_l": "mx:dodge_l",   # rifle side-steps (owner cut the stepping "Dodging" clip)
	"dodge_r": "mx:dodge_r",
	"death_front": "mx:death_back",   # owner: Mixamo's two are named the other way round from how they read
	"death_back": "mx:death_front",
	"death_side": "mx:death_right",
	"death_head": "mx:death_head_front",
	"death_head_back": "mx:death_head_back",
	"death_crouch": "mx:death_crouch_head",
	"grenade": "mx:grenade_toss",
	"jack": "mx:kneel_inspect",
	"medtech": "mx:medtech_cpr",
	"melee": "mx:melee_jab",
	"melee_blade": "mx:melee_stab",
	"idle_look": "mx:idle_look",
	"idle_phone": "mx:idle_phone",
	"idle_talk": "mx:idle_talk",
	"idle_shift": "mx:idle_shift",
	"cover_idle": "mx:cover_idle",
}
const LOOP := ["rifle_idle", "rifle_aim", "rifle_crouch", "rifle_crouch_aim", "rifle_walk", "rifle_run", "rifle_sprint",
	"pistol_idle", "pistol_aim", "pistol_walk", "pistol_run", "pistol_sprint", "pistol_crouch", "injured_idle", "injured_walk",
	"injured_run", "jack", "medtech", "idle_look", "idle_phone", "idle_talk", "idle_shift", "cover_idle", "dying"]
## Sub-ranges of clips, in seconds: the CPR clip loops on its chest compressions only (owner).
const TRIM := {"medtech": [0.13, 1.47]}
## Playback rate baked in: the big stagger reads better faster (owner).
const RATE := {"hit_b": 1.6, "dodge_l": 1.3, "dodge_r": 1.3}
const IN_PLACE := ["dodge_l", "dodge_r", "rifle_walk", "rifle_run", "rifle_sprint", "pistol_walk", "pistol_run", "pistol_sprint", "injured_walk", "injured_run"]
const HIPS := "%GeneralSkeleton:Hips"

static var _lib: AnimationLibrary
static var speed := {}         ## clip → native ground speed (m/s) before it was made in-place


static func library() -> AnimationLibrary:
	if _lib:
		return _lib
	_lib = AnimationLibrary.new()
	var ual := {}
	for k in UAL:
		if ResourceLoader.exists(UAL[k]):
			ual[k] = load(UAL[k])
	for clip in CLIPS:
		var a := _find(String(CLIPS[clip]), ual)
		if a == null:
			push_error("CharAnims: missing clip %s (%s)" % [clip, CLIPS[clip]])
			continue
		a = a.duplicate(true)
		a.loop_mode = Animation.LOOP_LINEAR if clip in LOOP else Animation.LOOP_NONE
		if clip in IN_PLACE:
			speed[clip] = _make_in_place(a)
		if clip in TRIM or clip in RATE:
			var w: Array = TRIM.get(clip, [0.0, a.length])
			_retime(a, float(w[0]), float(w[1]), float(RATE.get(clip, 1.0)))
		_lib.add_animation(clip, a)
	return _lib


static func _find(cand: String, ual: Dictionary) -> Animation:
	var kind := cand.get_slice(":", 0)
	var nm := cand.get_slice(":", 1)
	if kind == "mx":
		var lib := load(MX % nm) as AnimationLibrary
		if lib == null:
			return null
		var best: Animation = null   # some files carry a second, empty take: keep the busiest
		for an in lib.get_animation_list():
			var a := lib.get_animation(an)
			if best == null or a.get_track_count() * a.length > best.get_track_count() * best.length:
				best = a
		return best
	var l: AnimationLibrary = ual.get(kind)
	if l and l.has_animation(nm):
		return l.get_animation(nm)
	return null


## Remove the hips' horizontal drift (root motion baked into the hips) and return the speed it had.
static func _make_in_place(a: Animation) -> float:
	var t := a.find_track(NodePath(HIPS), Animation.TYPE_POSITION_3D)
	if t < 0 or a.track_get_key_count(t) < 2:
		return 0.0
	var n := a.track_get_key_count(t)
	var p0: Vector3 = a.track_get_key_value(t, 0)
	var p1: Vector3 = a.track_get_key_value(t, n - 1)
	var t0 := a.track_get_key_time(t, 0)
	var t1 := a.track_get_key_time(t, n - 1)
	if t1 - t0 < 0.01:
		return 0.0
	var drift := Vector3(p1.x - p0.x, 0, p1.z - p0.z)
	for k in n:
		var f := (a.track_get_key_time(t, k) - t0) / (t1 - t0)
		a.track_set_key_value(t, k, (a.track_get_key_value(t, k) as Vector3) - drift * f)
	return drift.length() / (t1 - t0)


## Keep only keys in [t0, t1], shift them to start at 0 and play `rate` times faster.
static func _retime(a: Animation, t0: float, t1: float, rate: float) -> void:
	for tr in a.get_track_count():
		for k in range(a.track_get_key_count(tr) - 1, -1, -1):
			var kt := a.track_get_key_time(tr, k)
			if kt < t0 - 0.001 or kt > t1 + 0.001:
				a.track_remove_key(tr, k)
		for k in a.track_get_key_count(tr):
			a.track_set_key_time(tr, k, (a.track_get_key_time(tr, k) - t0) / rate)
	a.length = (t1 - t0) / rate
