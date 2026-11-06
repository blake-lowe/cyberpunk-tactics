extends TestCase
## Save slots (SaveSlots, Campaign.slot), the slot listing's meta, the move from the single save,
## the overwrite confirmation and the options file (GameSettings). All under a temp user:// folder.

const DIR := "user://test_tmp/slot_tests"
var _old_dir := ""
var _old_slot := 1


func before_each() -> void:
	_old_dir = SaveSlots.dir
	_old_slot = Campaign.slot
	SaveSlots.dir = DIR
	DirAccess.make_dir_recursive_absolute(DIR)
	_clear()


func _clear() -> void:
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(f))


func _restore() -> void:
	_clear()
	SaveSlots.dir = _old_dir
	Campaign.slot = _old_slot


func test_slot_round_trip_and_active_slot() -> void:
	var c := Campaign.new_game(21)
	c.eb = 4321
	Campaign.slot = 2
	assert_true(c.save(), "autosave writes the active slot")
	assert_true(SaveSlots.exists(2))
	assert_false(SaveSlots.exists(1))
	assert_eq(SaveSlots.path(2), DIR + "/slot_2.json")
	var d := Campaign.load_from()
	assert_true(d != null)
	assert_eq(d.eb, 4321)
	assert_eq(d.crew[0].display_name, c.crew[0].display_name)
	assert_eq(JSON.stringify(d.to_dict()), JSON.stringify(c.to_dict()), "the meta line doesn't change what loads")
	_restore()


func test_meta_line_is_read_without_the_campaign() -> void:
	var c := Campaign.new_game(22)
	c.gigs_done = 3
	c.day = 9
	assert_true(c.save(SaveSlots.path(1)))
	var lines := FileAccess.get_file_as_string(SaveSlots.path(1)).split("\n")
	assert_true(lines[1].begins_with("\t\"meta\": {"), "meta is the save's first entry, on one line")
	var m := SaveSlots.meta(1)
	assert_eq(int(m.gigs_done), 3)
	assert_eq(int(m.day), 9)
	assert_eq(String(m.where), "safehouse")
	assert_true(absi(int(m.saved_unix) - int(Time.get_unix_time_from_system())) < 60)
	var shown := SaveSlots.describe(m)
	assert_eq(shown.gigs, "3 gigs completed")
	assert_eq(shown.where, "Safehouse")
	assert_eq(String(shown.when).length(), 16, "YYYY-MM-DD HH:MM")
	_restore()


func test_mid_gig_marker_and_gig_count() -> void:
	var c := Campaign.new_game(23)
	var place := Campaign.place_name(c.board[0])
	assert_false(c.accept(0).is_empty())
	assert_true(c.save(SaveSlots.path(3)))   # what taking a gig saves (BaseView._take_gig)
	var shown := SaveSlots.describe(SaveSlots.meta(3))
	assert_eq(shown.where, "Mid-gig: " + place)
	var back := Campaign.load_from(SaveSlots.path(3))
	assert_true(back.active_gig.is_empty(), "a gig is never saved half-played: it loads in the safehouse")
	assert_eq(back.board.size(), c.board.size(), "with the offer still on the board, to take again")
	c.gigs_done = 1
	assert_eq(SaveSlots.describe({"gigs_done": 1, "saved_unix": 0}).gigs, "1 gig completed")
	assert_eq(int(Campaign.from_dict(c.to_dict()).gigs_done), 1, "the count is saved")
	_restore()


func test_empty_slot_reads_empty() -> void:
	assert_true(SaveSlots.meta(2).is_empty())
	var shown := SaveSlots.describe(SaveSlots.meta(2))
	assert_true(shown.empty)
	assert_eq(shown.when, "Empty")
	assert_false(SaveSlots.any_used())
	_restore()


func test_overwrite_needs_confirmation_only_for_a_used_slot() -> void:
	assert_false(SaveSlots.needs_confirm(1), "an empty slot starts at once")
	Campaign.new_game(24).save(SaveSlots.path(1))
	assert_true(SaveSlots.needs_confirm(1), "a used one asks first")
	assert_false(SaveSlots.needs_confirm(2))
	_restore()


func test_single_save_moves_into_slot_1() -> void:
	var c := Campaign.new_game(25)
	var f := FileAccess.open(SaveSlots.legacy_path(), FileAccess.WRITE)   # the pre-slot format: no meta
	f.store_string(JSON.stringify(c.to_dict(), "\t"))
	f.close()
	assert_true(SaveSlots.migrate_legacy())
	assert_false(FileAccess.file_exists(SaveSlots.legacy_path()))
	assert_true(SaveSlots.exists(1))
	var m := SaveSlots.meta(1)
	assert_eq(String(m.where), "safehouse", "described from its contents")
	assert_eq(int(m.day), c.day)
	assert_eq(Campaign.load_from(SaveSlots.path(1)).eb, c.eb)
	# Once a slot is used, a stray single save is left alone.
	f = FileAccess.open(SaveSlots.legacy_path(), FileAccess.WRITE)
	f.store_string("{}")
	f.close()
	assert_false(SaveSlots.migrate_legacy())
	assert_true(FileAccess.file_exists(SaveSlots.legacy_path()))
	_restore()


func test_settings_persist() -> void:
	var old := GameSettings.path
	GameSettings.path = DIR + "/settings.cfg"
	assert_eq(GameSettings.load_values(), GameSettings.DEFAULTS, "defaults with no file")
	var v := {"master": 0.5, "music": 0.25, "sfx": 0.0, "fullscreen": true}
	assert_true(GameSettings.save_values(v))
	var back := GameSettings.load_values()
	assert_eq(float(back.master), 0.5)
	assert_eq(float(back.music), 0.25)
	assert_eq(float(back.sfx), 0.0)
	assert_eq(back.fullscreen, true)
	GameSettings.path = old
	_restore()
