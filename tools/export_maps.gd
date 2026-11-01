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
	for scene in SceneGen.scene_types():
		if scene == "lone_building":
			continue
		for s in SEEDS:
			for sec in [1, 3]:
				var t0 := Time.get_ticks_msec()
				var m := SceneGen.generate(s, scene, {"security": sec})
				var ms := Time.get_ticks_msec() - t0
				print("%-13s seed %-3d sec %d  %4d ms  %dx%d  structures %d  rooms %3d  cover %3d  devices %3d  nets %d" % [
					scene, s, sec, ms, m.w, m.h, m.structures.size(), m.rooms.filter(func(r): return r.cells > 0).size(),
					m.cover.size(), m.devices.size(), m.architectures.size()])
				if not stats_only:
					maps.append(m.to_dict())
	if not stats_only:
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"maps": maps}))
		f.close()
		print("wrote ", maps.size(), " maps to ", out_path)
	quit(0)
