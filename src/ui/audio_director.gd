class_name AudioDirector
extends Node
## All game audio (synthesised by tools/gen_audio.py into assets/audio). One instance lives on the
## scene tree root and survives scene changes, so music carries from the safehouse to a gig.
## Buses: Music, Ambience, SFX (a little room reverb, per scene) and UI, under Master.
## World sounds are AudioStreamPlayer2D placed at the sound's screen position: panned by where it is
## on screen, quieter the further off screen. Every Button in the game clicks and ticks on hover.
## Volumes persist in user://audio.cfg; M mutes everything.

const DIR := "res://assets/audio/%s.wav"
const BUSES := ["Music", "Ambience", "SFX", "UI"]
const CFG := "user://audio.cfg"
const DEFAULT_DB := {"Music": -10.0, "Ambience": -12.0, "SFX": -3.0, "UI": -9.0}

static var I: AudioDirector

var screen_of: Callable = Callable()   ## world Vector3 → screen Vector2 (set by the tactical view)
var _streams := {}
var _pool: Array[AudioStreamPlayer2D] = []
var _ui: Array[AudioStreamPlayer] = []
var _music := {}                       ## "explore"/"combat" → AudioStreamPlayer
var _music_state := ""
var _amb: AudioStreamPlayer
var _amb_name := ""
var _layer: AudioStreamPlayer          ## a second ambience loop over the bed (a club's beat, crowd murmur)
var _layer_name := ""
var _layer_db := 0.0
var _cue: AudioStreamPlayer            ## far-off one-shots on the Ambience bus (a siren, an AV passing)
var _muted := false
var _last := {}                        ## sound → msec last started (caps machine-gun stacking)
var _pending := {}                     ## music/ambience asked for before the director joined the tree


## The one director, created on first use.
static func get_or_make(tree: SceneTree) -> AudioDirector:
	if I and is_instance_valid(I):
		return I
	I = AudioDirector.new()
	I.name = "AudioDirector"
	tree.root.add_child.call_deferred(I)
	return I


func _init() -> void:
	_buses()
	for i in 24:
		var p := AudioStreamPlayer2D.new()
		p.bus = "SFX"
		p.max_distance = 2600.0
		p.attenuation = 1.6
		_pool.append(p)
		add_child(p)
	for i in 6:
		var u := AudioStreamPlayer.new()
		u.bus = "UI"
		_ui.append(u)
		add_child(u)
	for k in ["explore", "combat"]:
		var mp := AudioStreamPlayer.new()
		mp.bus = "Music"
		mp.volume_db = -60.0
		_music[k] = mp
		add_child(mp)
	_amb = AudioStreamPlayer.new()
	_amb.bus = "Ambience"
	add_child(_amb)
	_layer = AudioStreamPlayer.new()
	_layer.bus = "Ambience"
	add_child(_layer)
	_cue = AudioStreamPlayer.new()
	_cue.bus = "Ambience"
	add_child(_cue)
	_load_cfg()


func _ready() -> void:
	get_tree().node_added.connect(_hook_button)
	_hook_tree(get_tree().root)
	if _pending.has("music"):
		music(_pending.music)
	if _pending.has("ambience"):
		ambience(_pending.ambience)
	if _pending.has("layer"):
		layer(_pending.layer[0], _pending.layer[1])
	if _pending.has("space"):
		set_space(_pending.space[0], _pending.space[1])
	_pending.clear()


func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and (ev as InputEventKey).keycode == KEY_M:
		_muted = not _muted
		AudioServer.set_bus_mute(0, _muted)


# --- playback -----------------------------------------------------------------------------------

## A world sound at `at` (Vector3), or centred when `at` is null. `vol` in dB; small random pitch.
func sfx(name: String, at: Variant = null, vol := 0.0, pitch_var := 0.06, min_gap_ms := 25) -> void:
	var s := _stream(name)
	if s == null or not is_inside_tree():
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(name, -10000)) < min_gap_ms:
		return
	_last[name] = now
	var p := _free_player()
	p.stream = s
	p.volume_db = vol
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	var vp := get_viewport()
	var centre := vp.get_visible_rect().size / 2.0 if vp else Vector2.ZERO
	p.global_position = centre
	if at is Vector3 and screen_of.is_valid():
		p.global_position = screen_of.call(at)
	p.play()


## A UI sound (not positional).
func ui(name: String, vol := 0.0) -> void:
	var s := _stream(name)
	if s == null or not is_inside_tree():
		return
	for u in _ui:
		if not u.playing:
			u.stream = s
			u.volume_db = vol
			u.pitch_scale = 1.0 + randf_range(-0.03, 0.03)
			u.play()
			return


## Music state: "explore", "combat" or "" (silence); crossfades over `secs`.
func music(state: String, secs := 2.5) -> void:
	if not is_inside_tree():
		_pending["music"] = state
		return
	if state == _music_state:
		return
	_music_state = state
	for k in _music:
		var mp: AudioStreamPlayer = _music[k]
		var on: bool = k == state
		if on and not mp.playing:
			mp.stream = _looped("mus_" + k)
			mp.volume_db = -40.0
			mp.play()
		var tw := create_tween()
		tw.tween_property(mp, "volume_db", 0.0 if on else -60.0, secs)
		if not on:
			tw.tween_callback(func(): if _music_state != k: mp.stop())


## Ambience loop by name ("" stops it).
func ambience(name: String) -> void:
	if not is_inside_tree():
		_pending["ambience"] = name
		return
	if name == _amb_name:
		return
	_amb_name = name
	if name == "":
		_amb.stop()
		return
	_amb.stream = _looped(name)
	_amb.volume_db = -30.0
	_amb.play()
	create_tween().tween_property(_amb, "volume_db", 0.0, 2.0)


## A second ambience loop over the bed at `db` ("" fades it out): the street's own sound (a club's
## beat through a wall, a crowd's murmur) over the district's bed.
func layer(name: String, db := -6.0) -> void:
	if not is_inside_tree():
		_pending["layer"] = [name, db]
		return
	if name == _layer_name and is_equal_approx(db, _layer_db):
		return
	_layer_db = db
	if name == "":
		_layer_name = ""
		var tw := create_tween()
		tw.tween_property(_layer, "volume_db", -60.0, 1.5)
		tw.tween_callback(func(): if _layer_name == "": _layer.stop())
		return
	if name != _layer_name:
		_layer_name = name
		_layer.stream = _looped(name)
		_layer.volume_db = -40.0
		_layer.play()
	create_tween().tween_property(_layer, "volume_db", db, 2.0)


## A far-off one-shot on the Ambience bus (not positional): a siren a few blocks away, an AV
## passing over. One at a time.
func cue(name: String, db := -8.0) -> void:
	var s := _stream(name)
	if s == null or not is_inside_tree() or _cue.playing:
		return
	_cue.stream = s
	_cue.volume_db = db
	_cue.pitch_scale = 1.0 + randf_range(-0.05, 0.05)
	_cue.play()


## Room reverb on the SFX bus for this scene: tunnels ring, the badlands are dry.
func set_space(room: float, wet: float) -> void:
	if not is_inside_tree():
		_pending["space"] = [room, wet]
		return
	var bi := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(bi) > 0:
		var rv := AudioServer.get_bus_effect(bi, 0) as AudioEffectReverb
		rv.room_size = room
		rv.wet = wet


# --- internals ----------------------------------------------------------------------------------

func _stream(name: String) -> AudioStream:
	if _streams.has(name):
		return _streams[name]
	var path := DIR % name
	var s: AudioStream = load(path) if ResourceLoader.exists(path) else null
	_streams[name] = s
	return s


func _looped(name: String) -> AudioStream:
	var s := _stream(name)
	if s is AudioStreamWAV:
		var w := (s as AudioStreamWAV).duplicate() as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
		return w
	return s


func _free_player() -> AudioStreamPlayer2D:
	for p in _pool:
		if not p.playing:
			return p
	var oldest := _pool[0]   # all busy: steal the one that started first
	_pool.push_back(_pool.pop_front())
	return oldest


func _buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
			AudioServer.set_bus_volume_db(i, DEFAULT_DB[b])
			if b == "SFX":
				var rv := AudioEffectReverb.new()
				rv.room_size = 0.4
				rv.damping = 0.6
				rv.wet = 0.12
				rv.dry = 1.0
				AudioServer.add_bus_effect(i, rv)
			if b == "Music":
				var lim := AudioEffectLimiter.new()
				AudioServer.add_bus_effect(i, lim)


func _load_cfg() -> void:
	var cf := ConfigFile.new()
	if cf.load(CFG) != OK:
		return
	for b in BUSES:
		var bi := AudioServer.get_bus_index(b)
		if bi >= 0 and cf.has_section_key("volume_db", b):
			AudioServer.set_bus_volume_db(bi, float(cf.get_value("volume_db", b)))


func _hook_tree(n: Node) -> void:
	_hook_button(n)
	for ch in n.get_children():
		_hook_tree(ch)


func _hook_button(n: Node) -> void:
	if n is BaseButton and not n.has_meta("sfx"):
		n.set_meta("sfx", true)
		var b := n as BaseButton
		b.pressed.connect(func(): ui("sfx_ui_click"))
		b.mouse_entered.connect(func(): if not b.disabled: ui("sfx_ui_hover", -8.0))
