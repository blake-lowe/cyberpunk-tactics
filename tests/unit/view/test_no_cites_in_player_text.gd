extends TestCase
## Owner rule (2026-11-09): no source-book page cites in player-facing text (TextCites). The cites
## stay in comments and in the data's own cite fields (`cite`, `page`, `book`, `source`, `_doc`...).

## Data keys whose strings reach the player somewhere (cards, logs, the board, the shop, the debrief).
const SHOWN := ["name", "label", "text", "desc", "note", "hud", "cost", "key", "effect", "title", "blurb", "short", "hint",
	"description", "pitch", "summary", "tooltip", "brief", "briefs", "debrief", "headline", "toast"]
## Files read only by tools or docs, never shown.
const SKIP := ["res://data/gen/names.json"]


func _scan(v: Variant, key: String, where: String, bad: Array) -> void:
	if v is Dictionary:
		for k in v:
			if not String(k).begins_with("_"):
				_scan(v[k], String(k), where + "." + String(k), bad)
	elif v is Array:
		for x in v:
			_scan(x, key, where, bad)
	elif v is String and key in SHOWN and TextCites.has_cite(v):
		bad.append("%s: %s" % [where, String(v).left(100)])


func _json_files(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		_json_files(dir.path_join(d), out)


func test_the_guard_catches_cites() -> void:
	for s in ["(p.385)", "p.180", "CPR core p.94", "SPM p.57", "NC2045 p.33", "Heal (p223).", "RAW", "HOUSE-RULE: x"]:
		assert_true(TextCites.has_cite(s), s)
	for s in ["Put Out Fire", "a tech prototype", "10 squares", "Pistol 2d6", "pp", "up.5"]:
		assert_false(TextCites.has_cite(s), s)


func test_no_cites_in_player_facing_data() -> void:
	var files: Array = []
	_json_files("res://data", files)
	assert_true(files.size() >= 20, "data files scanned (%d)" % files.size())
	var bad: Array = []
	for f in files:
		if f in SKIP:
			continue
		_scan(JSON.parse_string(FileAccess.get_file_as_string(f)), "", String(f).get_file(), bad)
	assert_eq(bad, [], "page cites in player-facing data text")


func test_no_cites_on_the_cards() -> void:
	var db: Dictionary = RulesDB.load_json("action_help.json")
	for id in db.actions:
		assert_false(TextCites.has_cite(Hud.action_help(String(id))), "action card %s" % id)
	var nh: Dictionary = RulesDB.load_json("net_help.json")
	for id in (nh.actions as Dictionary).keys() + (nh.programs as Dictionary).keys():
		assert_false(TextCites.has_cite(Hud.net_help(String(id))), "NET card %s" % id)
	for kind in RulesDB.load_json("black_ice.json")["ice"]:
		assert_false(TextCites.has_cite(Hud.net_help("ice:" + String(kind))), "ICE card %s" % kind)
	for k in Campaign.DOWNTIME:
		assert_false(TextCites.has_cite(String(Campaign.DOWNTIME[k].desc)), "downtime %s" % k)


func test_no_cites_in_the_shop_and_the_board() -> void:
	var c := Campaign.new_game(5)
	for k in 3:
		for g in c.board:
			for f in ["title", "blurb"]:
				assert_false(TextCites.has_cite(String(g.get(f, ""))), "board %s: %s" % [f, g.get(f, "")])
		c.refresh_board()
	Hud._fonts()
	var s := StorageScreen.new()
	for key in ["weapon/heavy_pistol", "armor/light_armorjack"]:
		assert_false(TextCites.has_cite(s._subtitle(key)), "storage subtitle %s: %s" % [key, s._subtitle(key)])
	s.free()


## Player-facing strings written in the code: quoted text on non-comment lines of the UI and
## tactical view scripts (comments may cite; strings may not).
func test_no_cites_in_ui_strings() -> void:
	var quoted := RegEx.create_from_string("\"([^\"\\\\]|\\\\.)*\"")
	var bad: Array = []
	var files: Array = []
	for dir in ["res://src/ui", "res://src/ui/screens", "res://src/tactical/view", "res://src/meta"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				files.append(dir.path_join(f))
	files.append("res://src/tactical/greybox.gd")
	files.append("res://src/tactical/encounter.gd")
	files.erase("res://src/ui/text_cites.gd")   # the guard's own pattern
	for f in files:
		var n := 0
		for line in FileAccess.get_file_as_string(f).split("\n"):
			n += 1
			var code := String(line)
			var t := code.strip_edges()
			if t.begins_with("#"):
				continue
			for mt in quoted.search_all(code):
				var s := mt.get_string()
				if code.find(s) > code.find("#") and code.find("#") >= 0 and not code.left(code.find("#")).contains("\""):
					continue   # inside a trailing comment
				if TextCites.has_cite(s) and not s.contains("\\\\("):   # a regex pattern for stripping cites is not text
					bad.append("%s:%d %s" % [f.get_file(), n, s.left(90)])
	assert_eq(bad, [], "page cites in strings the player can see")
