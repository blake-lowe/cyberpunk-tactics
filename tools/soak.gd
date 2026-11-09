extends SceneTree
## Integration soak (headless): SoakDriver over many campaigns. Prints one line per campaign (per
## gig with --verbose), then the coverage, every invariant breach, and a determinism check (the
## first campaigns played again must give the same trace). Exit code 1 on any failure.
## Run it through tools/soak.sh, which also fails on script errors in Godot's output.
## Usage: godot --headless --path . -s tools/soak.gd -- [--campaigns=30] [--gigs=6] [--seed=1]
##   [--rounds=12] [--repeat=2] [--plan=board,setpiece,setpiece:<location>[:<kind>],tower,tower:<tower>[:<kind>],kind:<gig kind>] [--verbose] [--debug]
func _initialize() -> void:
	var campaigns := 30
	var gigs := 6
	var seed0 := 1
	var repeat := 2
	var d := SoakDriver.new()
	var plan: Array = []
	for a in OS.get_cmdline_user_args():
		var v := a.get_slice("=", 1)
		if a.begins_with("--campaigns="): campaigns = int(v)
		elif a.begins_with("--gigs="): gigs = int(v)
		elif a.begins_with("--seed="): seed0 = int(v)
		elif a.begins_with("--rounds="): d.max_rounds = int(v)
		elif a.begins_with("--repeat="): repeat = int(v)
		elif a.begins_with("--plan="): plan = Array(v.split(","))
		elif a == "--verbose": d.verbose = true
		elif a == "--debug":
			d.verbose = true
			d.debug = true
	var t0 := Time.get_ticks_msec()
	for s in range(seed0, seed0 + campaigns):
		var n0 := d.trace.size()
		d.run_campaign(s, gigs, plan)
		if d.verbose:
			for line in d.trace.slice(n0):
				print(line)
		print("campaign %d done: %d gigs so far, %d failures, %.0fs" % [s, d.stats.gigs, d.failures.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	# Determinism: the first campaigns again, trace for trace.
	for s in range(seed0, seed0 + mini(repeat, campaigns)):
		var a := SoakDriver.new()
		a.max_rounds = d.max_rounds
		a.run_campaign(s, gigs, plan)
		var b := SoakDriver.new()
		b.max_rounds = d.max_rounds
		b.run_campaign(s, gigs, plan)
		if a.trace != b.trace:
			d.failures.append("seed %d: not deterministic: %s" % [s, _diff(a.trace, b.trace)])
	print("--- soak: %d campaigns, %d gigs, %d rounds, %.0fs" % [campaigns, d.stats.gigs, d.stats.rounds, (Time.get_ticks_msec() - t0) / 1000.0])
	print("outcomes: won %d, fled %d, lost %d" % [d.stats.won, d.stats.fled, d.stats.lost])
	print("offers: %s" % JSON.stringify(d.stats.offers))
	print("objectives: %s" % JSON.stringify(d.stats.kinds))
	print("set pieces: %s" % JSON.stringify(d.stats.setpieces))
	print("towers: %s" % JSON.stringify(d.stats.towers))
	print("district looks: %s" % JSON.stringify(d.stats.looks))
	print("sides: %s" % JSON.stringify(d.stats.sides))
	print("neutral ground %d (peace broken %d)" % [d.stats.neutral, d.stats.peace_broken])
	print("complications %d, utility outages %d, turrets %d, held-turret shots %d, NET device ops %d" % [d.stats.complications, d.stats.utilities, d.stats.turret_units, d.stats.turret_shots, d.stats.device_ops])
	print("morale: %d surrendered, %d fled; bodies searched %d, finds %s, leads %d" % [d.stats.surrendered, d.stats.fled_units, d.stats.searched, JSON.stringify(d.stats.finds), d.stats.leads])
	print("twists: %d of %d offers (%.0f%%); armed on %d gigs, sprung %s" % [d.stats.offers_twisted, d.stats.offers_seen,
		100.0 * d.stats.offers_twisted / maxf(1.0, d.stats.offers_seen), d.stats.twists_armed, JSON.stringify(d.stats.twists_sprung)])
	print("detection clocks: %d gigs, %d ran out (%d escalated), %d rolls, %d dice won back; alarm raised on %d gigs" % [d.stats.clock_gigs,
		d.stats.clock_empty, d.stats.clock_escalated, d.stats.clock_rolls, d.stats.clock_reclaimed, d.stats.alarm_gigs])
	for f in d.failures:
		print("FAIL " + f)
	print("%d failures" % d.failures.size())
	quit(1 if not d.failures.is_empty() else 0)


static func _diff(a: Array, b: Array) -> String:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return "%s | %s" % [a[i], b[i]]
	return "%d vs %d lines" % [a.size(), b.size()]
