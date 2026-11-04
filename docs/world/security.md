# Security doctrines

How a faction guards a site and answers trouble. Factions name their doctrine in `factions.md`. All numbers are **HOUSE-RULE** tuning until the Night City 2047 pass gives us per-faction security detail. Data blocks build `data/world/security.json`.

```world security._doc
"Security doctrines (Security.doctrine): how a faction guards a site and answers trouble. A faction names its doctrine in factions.json; anything a doctrine leaves out comes from 'default'. All numbers are HOUSE-RULE until the Night City 2047 pass. budget: the guard roster is crew_size x (base + per_level x security) edgerunners' worth (CPR p399 costs: Mook 1, Lieutenant 2, Mini Boss 3), with officers by security level and at least min_mooks Mooks. outer_patrols: pairs of Mooks out in the open, one pair per area_per_pair squares over area_start, at most max_pairs. alarm: radio_range rouses the caller's side within that many squares, shout_range spreads an alert on a floor. backup: rounds after the call, then tier x (per_level x security + extra) at the far entrance. escalation: who answers if the fight keeps going (responder faction), when (min_security or min_heat), rounds after backup arrives (minus heat/2, at least 2), and maxtac_heat above which MaxTac comes instead. trauma_cards: the mark holds one (mark), officers (Lieutenants and Mini Bosses) at this chance. keycards: guards carry their zone's keycard."
```

## Doctrines

### Private security (`default`)

The baseline every doctrine starts from: today's tuned numbers (HOUSE-RULE).

```world security.doctrines.default
{
	"name": "Private security",
	"budget": {
		"base": 0.5,
		"per_level": 1.0,
		"min_mooks": 2
	},
	"officers": {
		"2": [
			"lieutenant"
		],
		"3": [
			"mini_boss",
			"lieutenant"
		]
	},
	"outer_patrols": {
		"area_start": 1500,
		"area_per_pair": 2500,
		"max_pairs": 4
	},
	"alarm": {
		"radio_range": 20,
		"shout_range": 8
	},
	"backup": {
		"rounds": 5,
		"tier": "mook",
		"per_level": 1,
		"extra": 0
	},
	"escalation": {
		"responder": "ncpd",
		"min_security": 2,
		"min_heat": 3,
		"rounds": 12,
		"maxtac_heat": 7
	},
	"trauma_cards": {
		"mark": false,
		"officers": 0.0
	},
	"keycards": true
}
```

### Corporate security (`corp_standard`)

Corporate site security: the baseline, plus Trauma Team cards for the mark and half the officers.

```world security.doctrines.corp_standard
{
	"name": "Corporate security",
	"trauma_cards": {
		"mark": true,
		"officers": 0.5
	}
}
```

### Militarised corporate security (`corp_military`)

A militarised corp (Militech): more guards and patrols, wider radio net, quicker and bigger backup, every officer carded.

```world security.doctrines.corp_military
{
	"name": "Militarised corporate security",
	"budget": {
		"base": 0.75,
		"per_level": 1.0,
		"min_mooks": 3
	},
	"outer_patrols": {
		"area_start": 1200,
		"area_per_pair": 2000,
		"max_pairs": 5
	},
	"alarm": {
		"radio_range": 30,
		"shout_range": 10
	},
	"backup": {
		"rounds": 4,
		"tier": "mook",
		"per_level": 1,
		"extra": 1
	},
	"escalation": {
		"responder": "ncpd",
		"min_security": 2,
		"min_heat": 3,
		"rounds": 10,
		"maxtac_heat": 7
	},
	"trauma_cards": {
		"mark": true,
		"officers": 1.0
	}
}
```

### Gang turf (`gang_den`)

Gang turf: more bodies, shouting instead of radios, friends called in fast, police only for big fights; no keycards.

```world security.doctrines.gang_den
{
	"name": "Gang turf",
	"budget": {
		"base": 0.75,
		"per_level": 1.0,
		"min_mooks": 3
	},
	"outer_patrols": {
		"area_start": 1200,
		"area_per_pair": 2000,
		"max_pairs": 3
	},
	"alarm": {
		"radio_range": 12,
		"shout_range": 10
	},
	"backup": {
		"rounds": 4,
		"tier": "mook",
		"per_level": 1,
		"extra": 1
	},
	"escalation": {
		"responder": "ncpd",
		"min_security": 3,
		"min_heat": 3,
		"rounds": 14,
		"maxtac_heat": 7
	},
	"keycards": false
}
```
