extends TestCase
## The release export leaves out tools/, tests/ and docs/ (export_presets.cfg exclude_filter). Game
## code that names a class declared there compiles here, where those folders exist, but fails in the
## exported build. That is how v0.10.0-playtest shipped a dark safehouse and grey gigs: greybox.gd
## called SoakDriver.new() for a dev-only render flag. Dev-only code must load() such scripts by path
## behind ResourceLoader.exists. tools/export_smoke.sh checks the real exported pack as well.

const EXCLUDED := ["res://tools", "res://tests", "res://docs"]
const SHIPPED := ["res://src", "res://scenes"]


func _files(dir: String, ext: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		out.append_array(_files(dir.path_join(sub), ext))
	for f in d.get_files():
		if f.ends_with(ext):
			out.append(dir.path_join(f))
	return out


## class_name declarations in the folders the export leaves out.
func _excluded_classes() -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.create_from_string("^class_name\\s+(\\w+)")
	for dir in EXCLUDED:
		for f in _files(dir, ".gd"):
			for line in FileAccess.get_file_as_string(f).split("\n"):
				var m := re.search(line)
				if m:
					out.append(m.get_string(1))
	return out


## A line of GDScript without its comment and string literals (good enough for identifier search).
static func code_only(line: String) -> String:
	var out := ""
	var quote := ""
	var i := 0
	while i < line.length():
		var ch := line[i]
		if quote != "":
			if ch == "\\":
				i += 2
				continue
			if ch == quote:
				quote = ""
		elif ch == "\"" or ch == "'":
			quote = ch
		elif ch == "#":
			break
		else:
			out += ch
		i += 1
	return out


func test_code_only_strips_comments_and_strings() -> void:
	assert_eq(code_only("var d := SoakDriver.new()  # x").strip_edges(), "var d := SoakDriver.new()")
	assert_false(code_only("load(\"res://tools/soak_driver.gd\")  # SoakDriver").contains("SoakDriver"))
	assert_false(code_only("## SoakDriver's stand-in").contains("SoakDriver"))


func test_shipped_code_never_names_an_unexported_class() -> void:
	var names := _excluded_classes()
	assert_true(names.has("SoakDriver"), "the scan sees tools/")
	var bad: Array[String] = []
	for dir in SHIPPED:
		var files := _files(dir, ".gd")
		files.append_array(_files(dir, ".tscn"))
		for f in files:
			var lines := FileAccess.get_file_as_string(f).split("\n")
			for n in lines.size():
				var code := code_only(lines[n]) if f.ends_with(".gd") else lines[n]
				for c in names:
					if RegEx.create_from_string("\\b%s\\b" % c).search(code):
						bad.append("%s:%d uses %s" % [f, n + 1, c])
				if code.contains("res://tools/") and not f.ends_with(".gd"):
					bad.append("%s:%d loads from tools/" % [f, n + 1])
	assert_eq(bad, [], "classes from tools/, tests/ or docs/ are not in the export: load() them by path behind ResourceLoader.exists")
