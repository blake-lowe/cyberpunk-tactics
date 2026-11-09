class_name GameSettings
extends RefCounted
## Player options (title screen → Options), kept in user://settings.cfg and applied at startup:
## master volume, music and sound effects (0-1, scaling the AudioDirector's buses from their mixed
## levels; SFX covers the SFX, UI and Ambience buses), fullscreen or windowed; and developer mode
## (dev_mode, off by default), which shows the dev-only tools such as the custom gig builder on the
## Fixer Network's JOBS (CustomGig). Its toggle is hidden on the Options page (click the Options
## heading five times) so a release build has it too; `--dev` on the command line turns it on for
## one run. Reduced motion (reduced_motion, off by default) tones down the HUD's animations: the
## clock dice don't tumble, shatter or beat, callouts fade instead of slamming (ClockWidget, Hud).
## `--reduced_motion=1` turns it on for one run, and it also turns off screen shake and hit-stop.
## Screen shake (shake, 0-1, default 0.6): the tactical view's trauma shake and kicks (ScreenShake);
## `--shake=x` overrides it for one run (review renders).

const DEFAULTS := {"master": 1.0, "music": 1.0, "sfx": 1.0, "fullscreen": false, "dev_mode": false, "reduced_motion": false, "shake": 0.6}
const SFX_BUSES := ["SFX", "UI", "Ambience"]
const DEV_FLAG := "--dev"

## Tests point this at a temp user:// subfolder (tests/run_tests.gd).
static var path := "user://settings.cfg"
static var _applied := false
## Tests only: -1 reads the flag and the saved option, 0 forces developer mode off, 1 on.
static var dev_override := -1


## Developer mode: `--dev` on the command line, or the hidden Options toggle saved on.
static func dev_mode() -> bool:
	if dev_override >= 0:
		return dev_override == 1
	return DEV_FLAG in OS.get_cmdline_user_args() or bool(load_values().dev_mode)


## Reduced motion: `--reduced_motion=1` on the command line, or the Options toggle saved on.
static func reduced_motion() -> bool:
	if "--reduced_motion=1" in OS.get_cmdline_user_args():
		return true
	return bool(load_values().get("reduced_motion", false))


## Screen shake strength 0..1: `--shake=x` on the command line, or the Options slider.
static func shake() -> float:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shake="):
			return clampf(float(a.substr(8)), 0.0, 1.0)
	return float(load_values().get("shake", DEFAULTS.shake))


static func load_values() -> Dictionary:
	var v := DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return v
	for k in DEFAULTS:
		var x: Variant = cf.get_value("options", k, DEFAULTS[k])
		v[k] = bool(x) if DEFAULTS[k] is bool else clampf(float(x), 0.0, 1.0)
	return v


static func save_values(v: Dictionary) -> bool:
	var cf := ConfigFile.new()
	for k in DEFAULTS:
		cf.set_value("options", k, v.get(k, DEFAULTS[k]))
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	return cf.save(path) == OK


## Apply the saved settings once per run (the title screen; the safehouse when launched directly).
static func apply_at_startup(tree: SceneTree) -> void:
	if _applied:
		return
	_applied = true
	apply(load_values(), tree)


static func apply(v: Dictionary, tree: SceneTree) -> void:
	AudioDirector.get_or_make(tree)   # makes the buses
	_bus(0, 0.0, float(v.master))
	var mi := AudioServer.get_bus_index("Music")
	if mi >= 0:
		_bus(mi, float(AudioDirector.DEFAULT_DB.Music), float(v.music))
	for b in SFX_BUSES:
		var bi := AudioServer.get_bus_index(b)
		if bi >= 0:
			_bus(bi, float(AudioDirector.DEFAULT_DB[b]), float(v.sfx))
	if DisplayServer.get_name() != "headless":
		var fs := bool(v.fullscreen)
		var mode := DisplayServer.window_get_mode()
		var is_fs := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		if fs != is_fs:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fs else DisplayServer.WINDOW_MODE_WINDOWED)


static func _bus(i: int, base_db: float, gain: float) -> void:
	AudioServer.set_bus_mute(i, gain <= 0.001)
	AudioServer.set_bus_volume_db(i, base_db + linear_to_db(maxf(gain, 0.001)))
