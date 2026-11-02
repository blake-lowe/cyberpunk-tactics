extends SceneTree
## Balance check (headless): AI crew of three vs an equal number of Mooks (CPR p399 says the crew
## should usually win). Usage: godot --headless --path . -s tools/balance_autoplay.gd
func _initialize() -> void:
	var wins := 0
	var games := 0
	for scene in ["skirmish", "street_block", "lone_building"]:
		for seed in range(1, 5):
			var m := SceneGen.generate(seed, scene, {"security": 1})
			var dice := Dice.new(seed * 11)
			var crew: Array[Combatant] = [Recruit.generate(dice, "solo", "edgerunner", "Vex"), Recruit.generate(dice, "netrunner", "edgerunner", "Patch"), Recruit.generate(dice, "medtech", "edgerunner", "Doc")]
			var e := Encounter.setup(m, dice, crew)
			e.reinforcements = OS.get_cmdline_user_args().has("--escalate")   # baseline: the p399 fight alone
			var kept := 0
			for u in e.units:   # p399: an equal number of Mooks
				if u.team == 1:
					if kept < crew.size() and u.c.role == "mook":
						kept += 1
						u.alerted = true
						e.init.add(u.c)
					else:
						u.c.dead = true
			e.next_turn()
			var turns := 0
			while e.state == "playing" and turns < 300:
				AI.act(e, e.cur)
				e.end_turn()
				e.next_turn()
				turns += 1
			games += 1
			if e.state == "won":
				wins += 1
			print("%s/%d: %s in %d (crew alive %d)" % [scene, seed, e.state, turns, e.alive(0).size()])
	print("crew won %d/%d" % [wins, games])
	quit()
