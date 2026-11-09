class_name TextCites
extends RefCounted
## Owner rule (2026-11-09): player-facing game text never cites the source books. Page cites live in
## code comments and in data fields the UI doesn't show (`cite`, `page`, `book`, `_doc`, `_source`).
## has_cite() is the guard the tests use (tests/unit/view/test_no_cites_in_player_text.gd).

const PATTERN := "(\\bpp?\\.\\s?\\d|\\bp\\d{2,3}\\b|\\b(CPR|SPM|NC2045|RAW|HOUSE-RULE|RULES-UNVERIFIED|Demiplane)\\b)"

static var _re: RegEx


## Does `s` carry a book or page cite ("p.180", "p223", "CPR core", "SPM", "NC2045", "RAW", "HOUSE-RULE")?
static func has_cite(s: String) -> bool:
	if _re == null:
		_re = RegEx.create_from_string(PATTERN)
	return _re.search(s) != null
