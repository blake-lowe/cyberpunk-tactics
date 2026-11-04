# Security doctrines

How a faction guards its own site: guard budget, officers, patrols, radio, Trauma Team cards, keycards. Factions name their doctrine in `factions.md`. Data blocks build `data/world/security.json`. All numbers are **HOUSE-RULE** tuning: the Night City 2045 book has no per-faction guard detail.

**Who answers trouble is not a doctrine any more** (M9 P2): it comes from the Security Codes (NC2045 p.7, `src/world/security_code.gd`). When the alarm goes up (a guard who knows the crew is there calls it in; gunfire rouses guards, who then call it in), the gig's site code is rolled once: 1d10 under `n` and its faction arrives after 1d6 (code 7+, our reading of "higher codes are faster") or 1d10 minutes, 1 minute = 2 rounds (HOUSE-RULE pacing), sized by intensity on the p.399 budget (Light: the crew counts 1-2 smaller, Mooks and the odd Lieutenant; Medium: as is, Lieutenants and occasionally a Mini Boss; Heavy: at least 1 larger, anything) and built from Hardened blocks if the code is Hardened. The district's code (city.json) is rolled too, for a street-level second response (often NCPD) that arrives after the first. The doctrine's old `backup` and `escalation` blocks are gone. A code's intensity also sizes the on-site guards: the budget below is spent for the crew size `SecurityCode.budget_crew_size` gives, and a Hardened code whose faction is the site's own puts Hardened guards on the posts. Utility Codes (p.8) are rolled at gig start: power out kills cameras, turrets and lights; CitiNet out doubles response times; water out is flavour.

```world security._doc
"Security doctrines (Security.doctrine): how a faction guards a site and answers trouble. A faction names its doctrine in factions.json; anything a doctrine leaves out comes from 'default'. All numbers are HOUSE-RULE (the Night City 2045 book has no per-faction guard detail). budget: the guard roster is crew_size x (base + per_level x security) edgerunners' worth (CPR p399 costs: Mook 1, Lieutenant 2, Mini Boss 3), with officers by security level and at least min_mooks Mooks. outer_patrols: pairs of Mooks out in the open, one pair per area_per_pair squares over area_start, at most max_pairs. The crew size is first adjusted by the Security Code's intensity (SecurityCode.budget_crew_size, NC2045 p.7). alarm: radio_range rouses the caller's side within that many squares, shout_range spreads an alert on a floor. Who responds to the call, and when, comes from the gig's Security Codes (SecurityCode), not the doctrine. trauma_cards: the mark holds one (mark), officers (Lieutenants and Mini Bosses) at this chance. keycards: guards carry their zone's keycard."
```

## Doctrines

### Private security (`default`)

The baseline every doctrine starts from: the tuned numbers (HOUSE-RULE).

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

A militarised corp (Militech): more guards and patrols, wider radio net, every officer carded.

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
	"trauma_cards": {
		"mark": true,
		"officers": 1.0
	}
}
```

### Gang turf (`gang_den`)

Gang turf: more bodies and shouting instead of radios; no keycards.

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
	"keycards": false
}
```
