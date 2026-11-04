extends SceneTree
## Campaign smoke test (headless): an AI crew takes gigs off the board, fights them with the guard
## AI, gets paid or hurt, rests, hires, shops and trains, for N gigs. Prints one line per gig and a
## summary; catches crashes and shows how the economy trends.
## Usage: godot --headless --path . -s tools/campaign_autoplay.gd -- [--gigs=12] [--seed=3]
func _initialize() -> void:
	var gigs := 12
	var seed := 3
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--gigs="): gigs = int(a.get_slice("=", 1))
		if a.begins_with("--seed="): seed = int(a.get_slice("=", 1))
	var camp := Campaign.new_game(seed)
	var wins := 0
	for n in gigs:
		if camp.alive_crew().is_empty():
			print("crew wiped out after %d gigs" % n)
			break
		# downtime: heal up, hire to three, spend IP
		var guard := 0
		while camp.crew.any(func(c): return c.hp < c.max_hp()) and guard < 10:
			camp.rest(1)
			guard += 1
		while camp.crew.size() < 3 and not camp.recruits.is_empty() and camp.eb >= int(Campaign.ECON.hire):
			camp.hire(0)
		for c in camp.crew:
			for s in ["handgun", "shoulder_arms", "evasion"]:
				c.raise_skill(s)
		var gi := 0
		var cost := func(b: Dictionary) -> int: return int(b.security)
		for i in camp.board.size():   # the easiest gig
			if cost.call(camp.board[i]) < cost.call(camp.board[gi]):
				gi = i
		var gig := camp.accept(gi)
		print("gig %d start: %s sec %d" % [n + 1, gig.scene, int(gig.security)])
		var m := SceneGen.generate(int(gig.seed), String(gig.scene), Campaign.scene_opts(gig))
		var crew: Array[Combatant] = []
		for c in camp.alive_crew():
			if c.can_act():
				crew.append(c)
		var e := Encounter.setup(m, camp.dice, crew, Campaign.objective_for(gig), Campaign.encounter_opts(gig))
		e.nav.locked = {}   # stand-in for a player who hacks or shoots security doors (the AI crew can't)
		e.next_turn()
		var turns := 0
		while e.state == "playing" and turns < 400 and e.init.round_num <= 30:
			if e.cur.team == 0:
				if e.objective.get("kind", "") == "snatch" and e.can_grab():
					e.grab()
				AI.act(e, e.cur)
			e.end_turn()
			e.next_turn()
			turns += 1
			if OS.get_cmdline_user_args().has("--trace") and turns % 20 == 0:
				print("  turn %d round %d alarm %d crew up %d guards %d" % [turns, e.init.round_num, e.alarm, e.alive(0).size(), e.opfor().size()])
		if e.state == "playing":   # stalemate: the crew pulls out
			e.state = "fled"
		var r := camp.resolve(e)
		if r.won:
			wins += 1
		print("gig %d %-16s %-9s %-6s sec %d %s: %d turns, %+d eb, best rep %d, dead %s, crew %d, eb %d" % [n + 1,
			gig.scene, Campaign.objective_for(gig), e.state, int(gig.security), String(e.complication.get("text", "")).left(24), turns,
			int(r.pay), camp.best_reputation(), r.dead, camp.crew.size(), camp.eb])
	print("won %d/%d · day %d · eb %d · best rep %d · fallen %d" % [wins, gigs, camp.day, camp.eb, camp.best_reputation(), camp.fallen.size()])
	quit()
