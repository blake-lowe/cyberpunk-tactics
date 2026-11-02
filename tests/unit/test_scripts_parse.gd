extends TestCase
## Loads every script under res://src so a parse error anywhere fails the suite (and shows up in
## tools/test.sh's script-error check) instead of hanging a later `godot -s` run.


func _all(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_all(dir.path_join(sub)))
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out


func test_every_script_loads() -> void:
	var files := _all("res://src")
	assert_true(files.size() > 20)
	for f in files:
		assert_true(load(f) != null, f)
