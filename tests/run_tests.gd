extends SceneTree
## Headless test runner. Use tools/test.sh rather than calling this directly.
## Discovers res://tests/unit/**/test_*.gd and runs every `test_*` method.

const ROOT := "res://tests/unit"


func _initialize() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]

	var total := 0
	var failed := 0
	for path in _find_tests(ROOT):
		if filter != "" and not path.contains(filter):
			continue
		var script: GDScript = load(path)
		if script == null:
			print("FAIL load %s" % path)
			failed += 1
			continue
		for m in script.get_script_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			total += 1
			var inst: TestCase = script.new()
			inst.before_each()
			inst.call(name)
			if inst.failures.is_empty():
				continue
			failed += 1
			print("FAIL %s::%s" % [path.get_file(), name])
			for f in inst.failures:
				print("    " + f)

	print("%d tests, %d failed" % [total, failed])
	quit(1 if failed > 0 or total == 0 else 0)


func _find_tests(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub in dir.get_directories():
		out.append_array(_find_tests(dir_path.path_join(sub)))
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	out.sort()
	return out
