extends SceneTree
## Generates maps and writes them as JSON for the debug viewer.
## godot --headless --path . -s tools/export_maps.gd -- OUT.json [stats]
## Exports every scene type × SEEDS × security 1 and 3.

const SEEDS := [11, 42]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := args[0] if args.size() > 0 else "user://maps.json"
	var stats_only := args.size() > 1 and args[1] == "stats"
	var maps := []
	var jobs := []
	for scene in SceneGen.scene_types():
		if scene in ["lone_building", "neighborhood"]:
			continue
		var demo: bool = RulesDB.gen("scenes.json")[scene].get("demo", false)
		for sec in ([3] if demo else [1, 3]):
			jobs.append([scene, SEEDS[0], {"security": sec}])
	for prof in RulesDB.gen("districts.json").keys():
		if not prof.begins_with("_"):
			jobs.append(["neighborhood", SEEDS[0], {"security": 2, "profile": prof}])
	for j in jobs:
		var t0 := Time.get_ticks_msec()
		var m := SceneGen.generate(j[1], j[0], j[2])
		var ms := Time.get_ticks_msec() - t0
		print("%-13s %-17s %5d ms  %dx%d  structures %d  nets %d" % [j[0], j[2].get("profile", ""), ms, m.w, m.h, m.structures.size(), m.architectures.size()])
		if not stats_only:
			maps.append(m.to_dict())
	if not stats_only:
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"maps": maps}))
		f.close()
		print("wrote ", maps.size(), " maps to ", out_path)
	quit(0)
