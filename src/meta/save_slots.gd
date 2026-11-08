class_name SaveSlots
extends RefCounted
## The three campaign save slots (user://slot_1.json … slot_3.json). Campaign.slot is the active
## one; every autosave writes it. Each save starts with a one-line `meta` block (when it was saved,
## gigs completed, safehouse or mid-gig and where) so the title screen lists the slots without
## loading whole campaigns. Before slots there was one save, user://campaign.json: the first launch
## that finds it and no slots moves it into slot 1.
##
## Mid-gig: a gig is never saved half-played. Taking a gig saves the campaign with the gig accepted
## (meta "Mid-gig: <place>"), and nothing is saved again until the gig is settled. A slot quit
## mid-gig therefore loads into the safehouse with the offer still on the board (the active gig
## itself isn't part of the save): taking it again plays it from the beginning.

const COUNT := 3
const LEGACY_FILE := "campaign.json"

## Where the slots live. Tests point this at a temp user:// subfolder (tests/run_tests.gd).
static var dir := "user://"


static func _dir() -> String:
	return dir if dir.ends_with("/") else dir + "/"


static func path(n: int) -> String:
	return _dir() + "slot_%d.json" % n


static func legacy_path() -> String:
	return _dir() + LEGACY_FILE


static func exists(n: int) -> bool:
	return FileAccess.file_exists(path(n))


static func any_used() -> bool:
	for n in range(1, COUNT + 1):
		if exists(n):
			return true
	return false


## New Game into slot `n` asks first only when it would overwrite a save.
static func needs_confirm(n: int) -> bool:
	return exists(n)


## The single pre-slot save moves into slot 1 when no slot is used yet. True if it moved.
static func migrate_legacy() -> bool:
	var old := legacy_path()
	if not FileAccess.file_exists(old) or any_used():
		return false
	DirAccess.make_dir_recursive_absolute(_dir())
	return DirAccess.rename_absolute(old, path(1)) == OK


## What a slot's listing shows of a campaign.
static func meta_for(c: Campaign) -> Dictionary:
	var m := {"saved_unix": int(Time.get_unix_time_from_system()), "gigs_done": c.gigs_done, "day": c.day,
		"crew": c.alive_crew().size(), "version": SaveMigrations.CURRENT}
	if c.active_gig.is_empty():
		m["where"] = "safehouse"
	else:
		m["where"] = "gig"
		m["place"] = Campaign.place_name(c.active_gig)
	if c.dev_gigs > 0 or c.active_gig.get("dev", false):   # DEV ONLY: custom gigs played (CustomGig)
		m["dev_gigs"] = c.dev_gigs
		m["dev"] = bool(c.active_gig.get("dev", false))
	return m


## Write `c` to `p`: the meta line first, then the campaign (Campaign.to_dict).
static func write(c: Campaign, p: String) -> bool:
	DirAccess.make_dir_recursive_absolute(p.get_base_dir())
	var body := JSON.stringify(c.to_dict(), "\t")
	var text := "{\n\t\"meta\": %s,\n%s" % [JSON.stringify(meta_for(c)), body.substr(2)]
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(text)
	return true


## Slot `n`'s meta, read from the top of the file; {} for an empty slot. A save without a meta line
## (the migrated single save) is parsed whole and described from its contents and file time.
static func meta(n: int) -> Dictionary:
	return read_meta(path(n))


static func read_meta(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {"unreadable": true}
	f.get_line()
	var line := f.get_line().strip_edges()
	if line.begins_with("\"meta\":"):
		var m: Variant = JSON.parse_string(line.trim_prefix("\"meta\":").trim_suffix(","))
		if m is Dictionary:
			return m
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not d is Dictionary:
		return {"unreadable": true}
	if (d as Dictionary).get("meta") is Dictionary:
		return d.meta
	return {"saved_unix": FileAccess.get_modified_time(p), "gigs_done": int(d.get("gigs_done", 0)),
		"day": int(d.get("day", 1)), "where": "safehouse"}


## The lines a slot shows: "Empty", or its save time, gigs completed and where the crew is.
static func describe(m: Dictionary) -> Dictionary:
	if m.is_empty():
		return {"empty": true, "when": "Empty", "gigs": "", "where": ""}
	if m.get("unreadable", false):
		return {"empty": false, "when": "Unreadable save", "gigs": "", "where": ""}
	var g := int(m.get("gigs_done", 0))
	var where := "Safehouse"
	if String(m.get("where", "")) == "gig":
		where = "Mid-gig: %s" % String(m.get("place", "unknown"))
		if m.get("dev", false):
			where += " (DEV GIG)"
	if int(m.get("dev_gigs", 0)) > 0:
		where += " · %d dev gig%s" % [int(m.dev_gigs), "" if int(m.dev_gigs) == 1 else "s"]
	return {"empty": false, "when": local_time(int(m.get("saved_unix", 0))),
		"gigs": "%d gig%s completed" % [g, "" if g == 1 else "s"], "where": where}


## "2026-11-06 21:04" in the player's time zone.
static func local_time(unix: int) -> String:
	var bias := int(Time.get_time_zone_from_system().get("bias", 0))
	return Time.get_datetime_string_from_unix_time(unix + bias * 60, true).left(16)
