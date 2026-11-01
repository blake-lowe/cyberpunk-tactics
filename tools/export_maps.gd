extends SceneTree
## Generates maps and writes them as JSON for the debug viewer.
## godot --headless --path . -s tools/export_maps.gd -- OUT.json [stats]
## Set (algorithm × seed × security) is defined below; edit to taste.

const SITES := ["corp_office", "warehouse", "gang_hideout"]
const SEEDS := [11, 23, 42]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := args[0] if args.size() > 0 else "user://maps.json"
	var stats_only := args.size() > 1 and args[1] == "stats"
	var maps := []
	for site in SITES:
		for s in SEEDS:
			for sec in [1, 3]:
				var t0 := Time.get_ticks_msec()
				var m := MapGen.generate(s, site, {"security": sec, "floors": 2, "verticality": 2})
				var ms := Time.get_ticks_msec() - t0
				var a := m.architecture
				print("%-13s seed %-3d sec %d  %4d ms  rooms %2d  cover %3d  devices %2d  net nodes %2d edges %2d subnets %d ice %d (%d pts)" % [
					site, s, sec, ms, m.rooms.filter(func(r): return r.cells > 0).size(), m.cover.size(), m.devices.size(),
					a.nodes.size(), a.edges.size(), a.subnets.size(), a.ice.size(), a.spent])
				if not stats_only:
					maps.append(m.to_dict())
	if not stats_only:
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"maps": maps}))
		f.close()
		print("wrote ", maps.size(), " maps to ", out_path)
	quit(0)
