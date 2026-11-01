extends SceneTree
## Generates maps and writes them as JSON for the debug viewer.
## godot --headless --path . -s tools/export_maps.gd -- OUT.json [stats]
## Set (algorithm × seed × security) is defined below; edit to taste.

const ALGOS := ["bsp", "treemap", "growth"]
const SEEDS := [11, 23, 42]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path := args[0] if args.size() > 0 else "user://maps.json"
	var stats_only := args.size() > 1 and args[1] == "stats"
	var maps := []
	for algo in ALGOS:
		for s in SEEDS:
			for sec in [1, 3]:
				var t0 := Time.get_ticks_msec()
				var m := MapGen.generate(s, algo, {"security": sec, "floors": 2, "verticality": 2,
					"net_style": "stack"})
				var ms := Time.get_ticks_msec() - t0
				var kinds := {}
				for r in m.rooms:
					if r.cells > 0:
						kinds[r.kind] = kinds.get(r.kind, 0) + 1
				print("%-8s seed %-3d sec %d  %4d ms  rooms %2d  cover %3d  devices %2d  net floors %2d  %s" % [
					algo, s, sec, ms, kinds.values().reduce(func(a, b): return a + b, 0), m.cover.size(),
					m.devices.size(), m.architecture.floors.size(), kinds])
				if not stats_only:
					var d := m.to_dict()
					# Mirrored-style architecture for the same map, for side-by-side comparison.
					var m2 := MapGen.generate(s, algo, {"security": sec, "floors": 2, "verticality": 2, "net_style": "mirrored"})
					d["architecture_mirrored"] = m2.architecture.to_dict()
					maps.append(d)
	if not stats_only:
		var f := FileAccess.open(out_path, FileAccess.WRITE)
		f.store_string(JSON.stringify({"maps": maps}))
		f.close()
		print("wrote ", maps.size(), " maps to ", out_path)
	quit(0)
