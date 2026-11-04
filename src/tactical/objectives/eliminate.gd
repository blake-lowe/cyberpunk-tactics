extends Objective
## Elimination (a gang hit): put every guard down, backup included.


func check_end() -> String:
	if e.opfor().is_empty() and e.backup_in > 0:
		return ""   # HOUSE-RULE: a gang hit isn't done while backup is still on its way
	return _cleared()


func hud_text() -> String:
	return "OBJECTIVE · ELIMINATE ALL HOSTILES (%d LEFT)" % e.opfor().size()
