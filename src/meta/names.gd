class_name Names
extends RefCounted
## Night City's names: real names for its people and street handles for edgerunners.
## Data (all built by tools/gen_names_data.py from openly licensed sources, see each file's
## `_provenance` and assets/third_party/names/):
## - data/gen/names.json: given names (masc, femme, neutral) and family names per culture, in
##   order of how common they are, with each culture's share of Night City;
## - data/gen/handles.json: word pools, handle patterns and a curated list of street handles;
## - data/gen/name_filter.json: the profanity and slur filter, and reserved and famous names.
## Every draw comes from the passed Dice, so the same seed gives the same people. Lists are in
## order of frequency and picks lean toward the head (HEAD_BIAS), so common names come up most.

const GENDERS := ["masc", "femme", "nonbinary"]
## HOUSE-RULE: a recruit's gender when nothing fixes it (SPM p.52-54 gives three name lists).
const GENDER_WEIGHTS := {"masc": 0.46, "femme": 0.46, "nonbinary": 0.08}
## A pick from a frequency-ordered list takes index floor(n * u^HEAD_BIAS): 2 puts about a third of
## the picks in the top tenth of the list.
const HEAD_BIAS := 2.0
const MAX_TRIES := 40

static var _norm_cache := {}


static func names_data() -> Dictionary:
	return RulesDB.gen("names.json")


static func handles_data() -> Dictionary:
	return RulesDB.gen("handles.json")


static func filter_data() -> Dictionary:
	return RulesDB.gen("name_filter.json")


## A fresh Dice for a sub-roll, seeded from one draw of `dice` (so a caller that drew one die for a
## name before still draws exactly one: the rest of its sequence is unchanged).
static func sub_dice(dice: Dice) -> Dice:
	var s := int(dice.rng.randi())
	return Dice.new(s if s != 0 else 1)   # Dice.new(0) would randomise


## An element of frequency-ordered `list`, leaning toward the head.
static func pick(dice: Dice, list: Array) -> Variant:
	if list.is_empty():
		return null
	var i := int(floor(float(list.size()) * pow(dice.rng.randf(), HEAD_BIAS)))
	return list[clampi(i, 0, list.size() - 1)]


## An element of `list`, uniformly.
static func pick_flat(dice: Dice, list: Array) -> Variant:
	return null if list.is_empty() else list[dice.d(list.size()) - 1]


## A key of `weights` (key -> weight), with probability proportional to its weight.
static func pick_weighted(dice: Dice, weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := dice.rng.randf() * total
	var last := ""
	for k in weights:
		last = String(k)
		r -= float(weights[k])
		if r < 0.0:
			return last
	return last


# --- Real names ------------------------------------------------------------------------------

## Culture ids (names.json cultures), in data order.
static func cultures() -> Array[String]:
	var out: Array[String] = []
	for c in names_data().cultures:
		out.append(String(c))
	return out


static func roll_gender(dice: Dice) -> String:
	return pick_weighted(dice, GENDER_WEIGHTS)


static func roll_culture(dice: Dice) -> String:
	var ws := {}
	for c in names_data().cultures:
		ws[c] = float(names_data().cultures[c].weight)
	return pick_weighted(dice, ws)


## A given name of `gender` (masc, femme, nonbinary) from culture `cid`. Masc and femme names come
## from their own list, now and then a neutral one; nonbinary people mostly get neutral names.
static func given_name(dice: Dice, gender: String, cid: String) -> String:
	var g: Dictionary = names_data().cultures[cid].given
	var mix: Dictionary = names_data().given_mix[gender if gender in GENDERS else "nonbinary"]
	var ws := {}
	for k in mix:
		if not (g.get(k, []) as Array).is_empty():
			ws[k] = float(mix[k])
	if ws.is_empty():
		ws = {"masc": 1.0, "femme": 1.0, "neutral": 1.0}
	var l: Array = g.get(pick_weighted(dice, ws), [])
	return String(pick(dice, l)) if not l.is_empty() else ""


## A family name from culture `cid` that suits `gender` where the culture's surnames have gendered
## forms (Novak / Nováková: family_masc, family_femme).
static func family_name(dice: Dice, gender: String, cid: String) -> String:
	var c: Dictionary = names_data().cultures[cid]
	var ws := {"family": float((c.get("family", []) as Array).size())}
	if gender != "femme":
		ws["family_masc"] = float((c.get("family_masc", []) as Array).size())
	if gender != "masc":
		ws["family_femme"] = float((c.get("family_femme", []) as Array).size())
	var l: Array = c.get(pick_weighted(dice, ws), [])
	return String(pick(dice, l)) if not l.is_empty() else ""


## A person: {given, family, full, gender, culture}. `gender` and `culture` are rolled when "" (the
## culture by its Night City weight); the family name now and then comes from another culture
## (names.json family_mix: Night City's families mix). A name in `taken` (full names), a famous
## person's or one the filter blocks is rolled again.
static func person(dice: Dice, gender := "", culture := "", taken: Array = []) -> Dictionary:
	if not gender in GENDERS:
		gender = roll_gender(dice)
	var fixed: bool = names_data().cultures.has(culture)
	var out := {}
	for i in MAX_TRIES:
		var cid := culture if fixed else roll_culture(dice)
		var fcid := cid
		if dice.rng.randf() < float(names_data().get("family_mix", 0.0)):
			fcid = roll_culture(dice)
		var given := given_name(dice, gender, cid)
		var family := family_name(dice, gender, fcid)
		out = {"given": given, "family": family, "full": "%s %s" % [given, family], "gender": gender, "culture": cid}
		if given != "" and family != "" and is_clean(out.full) and not is_famous(out.full) and not out.full in taken:
			break
	return out


static func full_name(dice: Dice, gender := "", culture := "", taken: Array = []) -> String:
	return String(person(dice, gender, culture, taken).full)


## True when `full` is "Given Family" with both parts from the name lists (any culture).
static func is_person_name(full: String) -> bool:
	var parts := full.split(" ", false)
	if parts.size() != 2:
		return false
	return _known("given").has(parts[0]) and _known("family").has(parts[1])


static var _known_sets := {}


static func _known(kind: String) -> Dictionary:
	if not _known_sets.has(kind):
		var s := {}
		for cid in names_data().cultures:
			var c: Dictionary = names_data().cultures[cid]
			var lists: Array = (c.given as Dictionary).values() if kind == "given" else [c.get("family", []), c.get("family_masc", []), c.get("family_femme", [])]
			for l in lists:
				for n in l:
					s[String(n)] = true
		_known_sets[kind] = s
	return _known_sets[kind]


# --- Handles ---------------------------------------------------------------------------------

## A street handle (handles.json patterns): a curated handle, one word, two words, a compound, a
## word and a number, or a pun on the given name `given` when there is one. A handle in `taken`,
## a reserved (canon) or famous name, or one the filter blocks is rolled again.
static func handle(dice: Dice, given := "", taken: Array = []) -> String:
	var hd := handles_data()
	var ws := {}
	for p in hd.patterns:
		if given == "" and bool(hd.patterns[p].get("needs_given", false)):
			continue
		ws[p] = float(hd.patterns[p].weight)
	var h := ""
	for i in MAX_TRIES:
		h = _pattern(dice, pick_weighted(dice, ws), given)
		if h != "" and is_clean(h, true) and not is_reserved(h) and not is_famous(h) and not h in taken:
			return h
	return "%s %d" % [h, dice.d(99)]


static func _pattern(dice: Dice, p: String, given: String) -> String:
	var hd := handles_data()
	var pat: Dictionary = hd.patterns[p]
	match p:
		"curated":
			return String(pick_flat(dice, hd.curated))
		"word":
			return _word(dice, pat.pools)
		"pair":
			return "%s %s" % [_word(dice, pat.first), _word(dice, pat.second)]
		"compound":
			var a := _word(dice, pat.first)
			var b := String(pick_flat(dice, hd.compound_tails))
			return a + b.to_lower() if a.length() + b.length() <= int(pat.get("max_len", 11)) else a
		"number":
			var fmt := String(pick_flat(dice, pat.formats))
			var n := String(pick_flat(dice, hd.numbers))
			if fmt == "{w}{n}" and not n.is_valid_int():   # run together only with digits (Sphinx909, not SphinxIX)
				fmt = "{w}-{n}"
			return fmt.format({"w": _word(dice, pat.pools), "n": n})
		"alliterate":   # a pun on the given name: "Razor Rosa", "Kenji the Knife"
			var w := _initial_word(dice, pat.pools, given.left(1))
			return "" if w == "" else String(pick_flat(dice, pat.formats)).format({"w": w, "g": given})
		"the":
			return "The %s" % _word(dice, pat.pools)
	return ""


## A word from one of `pools` (handles.json words.<pool>.list), the pool picked by its size.
static func _word(dice: Dice, pools: Array) -> String:
	var ws := {}
	for pl in pools:
		ws[pl] = float((handles_data().words[pl].list as Array).size())
	return String(pick_flat(dice, handles_data().words[pick_weighted(dice, ws)].list))


## A word from `pools` starting with `initial` (case-insensitive), "" when none does.
static func _initial_word(dice: Dice, pools: Array, initial: String) -> String:
	var fits: Array = []
	for pl in pools:
		for w in handles_data().words[pl].list:
			if String(w).left(1).to_lower() == initial.to_lower():
				fits.append(w)
	return String(pick_flat(dice, fits)) if not fits.is_empty() else ""


# --- The filter ------------------------------------------------------------------------------

## Lower case, letters and spaces only, accents stripped, hyphens as spaces ("Zoë-Ann" -> "zoe ann").
static func normalise(text: String) -> String:
	if _norm_cache.has(text):
		return _norm_cache[text]
	var out := ""
	var fold: Dictionary = filter_data().get("fold", {})
	for ch in text.to_lower():
		var f: String = fold.get(ch, ch)
		if (f >= "a" and f <= "z") or f == " ":
			out += f
	if _norm_cache.size() > 20000:   # a long campaign rolls many names: keep the cache small
		_norm_cache.clear()
	_norm_cache[text] = out
	return out


## False when `text` holds a blocked word (name_filter.json blocked): any of its words, or all
## its words run together. With `substrings` (handles, whose compounds join words), also a blocked
## word of 4+ letters anywhere in it.
static func is_clean(text: String, substrings := false) -> bool:
	var blocked: Dictionary = _lookup("blocked")
	var n := normalise(text)
	var joined := n.replace(" ", "")
	if blocked.has(joined):
		return false
	for w in n.split(" ", false):
		if blocked.has(w):
			return false
	if substrings:
		for b in _long_blocked():
			if joined.contains(b):
				return false
	return true


## A canon Cyberpunk character's or fixer's handle (name_filter.json reserved).
static func is_reserved(text: String) -> bool:
	return _lookup("reserved").has(normalise(text).replace(" ", ""))


## A famous real person or fictional character, a band or a brand (name_filter.json famous).
static func is_famous(text: String) -> bool:
	return _lookup("famous").has(normalise(text).replace(" ", ""))


static var _sets := {}
static var _long: Array = []


static func _lookup(key: String) -> Dictionary:
	if not _sets.has(key):
		var s := {}
		for w in filter_data().get(key, []):
			s[normalise(String(w)).replace(" ", "")] = true
		_sets[key] = s
	return _sets[key]


static func _long_blocked() -> Array:
	if _long.is_empty():
		for w in _lookup("blocked"):
			if String(w).length() >= 4:
				_long.append(w)
	return _long
