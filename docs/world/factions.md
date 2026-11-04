# Factions

Who is who in Night City for the game: the gig's target faction fields the guards; the others turn up as third parties (bystanders, Trauma Team, NCPD, MaxTac, rival crews). Each section is a short paraphrase with a citation, and a `world` data block that `tools/gen_world_data.py` turns into `data/world/factions.json`. Edit here, then regenerate.

Status: everything below is **RULES-UNVERIFIED**: Time of the Red common knowledge pending the Night City 2047 pass. Replace the notes with page-cited paraphrases as the material is distilled (numbers and short paraphrases only; never paste rulebook text).

## How the data reads

```world factions._doc
"Factions of Night City (World.faction). The gig's target faction fields the guards; others appear as third parties (bystanders, Trauma Team, NCPD, MaxTac, rival crews). kind sets defaults; relations are symmetric and resolved most-hostile-wins between kind defaults and per-faction overrides. roster: ranks name the NPC tiers; blocks list the stat blocks (npcs.json) the faction fields per tier, falling back to the tier's default pool; responder: who they send when called. look: what the view dresses them in (jacket/accent/pants colours, vest/helmet/gloves). gigs: the gig kinds (gigs.json templates) this faction can be the target of. doctrine: security style (data/world/security.json, task 41). Names follow CPR's Time of the Red; anything not checked against the book is RULES-UNVERIFIED until the Night City 2047 pass."
```

## Stat blocks in rosters

`roster.blocks` names, per tier, the printed stat blocks (data/rules/npcs.json) a faction fields:
their stats, skills, armour, guns (with the book's quality), cyberware and grenades come from the
block, never from here. Until the Night City 2047 pass supplies faction blocks, these use the core
book's generic ones (CPR core p.412-416) and the mapping is **RULES-UNVERIFIED**: corps, NCPD and
6th Street field Security Operatives and Officers; gangs field Boostergangers (the Wraiths, Road
Gangers) with Netrunner or Reclaimer Chief lieutenants and a Pyro or Outrider as mini boss. The core
book has no corporate mini boss, so corps put a Security Officer in that slot.

## Relations between kinds

Defaults by kind, symmetric (most hostile wins); a faction's own `relations` override replaces them.

```world factions.kind_relations
{
	"crew": {
		"crew": "ally",
		"corp": "hostile",
		"gang": "hostile",
		"police": "hostile",
		"service": "neutral",
		"civilian": "neutral",
		"captive": "neutral"
	},
	"corp": {
		"corp": "neutral",
		"gang": "hostile",
		"police": "neutral",
		"service": "neutral",
		"civilian": "neutral",
		"captive": "neutral"
	},
	"gang": {
		"gang": "neutral",
		"police": "hostile",
		"service": "neutral",
		"civilian": "neutral",
		"captive": "neutral"
	},
	"police": {
		"police": "ally",
		"service": "neutral",
		"civilian": "neutral",
		"captive": "neutral"
	},
	"service": {
		"service": "ally",
		"civilian": "neutral",
		"captive": "neutral"
	},
	"civilian": {
		"civilian": "neutral",
		"captive": "neutral"
	},
	"captive": {
		"captive": "neutral"
	}
}
```

## Factions

### The crew (`crew`)

The player's crew. Never a gig target. *RULES-UNVERIFIED.*

```world factions.factions.crew
{
	"name": "The crew",
	"kind": "crew"
}
```

### Bystanders (`bystanders`)

People on the street and in public rooms. They panic at gunfire and run for the map edge; hurting one costs rep and heat. *RULES-UNVERIFIED.*

```world factions.factions.bystanders
{
	"name": "Bystanders",
	"kind": "civilian",
	"look": {
		"jackets": [
			"6a5a4a",
			"4a5a6a",
			"7a6a5a",
			"5a4a5a",
			"3a4a3a",
			"8a7a6a",
			"6a3a3a"
		],
		"accent_from_jacket": 0.3,
		"visor": 0.0
	}
}
```

### Captive (`captive`)

The person a rescue gig is about. Neutral until freed, then on the crew's side. *RULES-UNVERIFIED.*

```world factions.factions.captive
{
	"name": "Captive",
	"kind": "captive"
}
```

### Private security (`security`)

Generic private security, used when a gig names no faction. At corporate sites they run the corporate doctrine. *RULES-UNVERIFIED.*

```world factions.factions.security
{
	"name": "Private security",
	"kind": "corp",
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Guard",
			"lieutenant": "Sergeant",
			"mini_boss": "Enforcer"
		},
		"blocks": {
			"mook": [
				"security_operative"
			],
			"lieutenant": [
				"security_officer"
			],
			"mini_boss": [
				"security_officer"
			]
		}
	},
	"look": {
		"jacket": "4e555e",
		"accent": "ff3030",
		"pants": "3a4048",
		"vest": true,
		"helmet": true,
		"gloves": true
	}
}
```

### Biotechnica (`biotechnica`)

Agricultural and biotech megacorp. *RULES-UNVERIFIED.*

```world factions.factions.biotechnica
{
	"name": "Biotechnica",
	"kind": "corp",
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Biotechnica Security",
			"lieutenant": "Biotechnica Sergeant",
			"mini_boss": "Biotechnica Enforcer"
		},
		"blocks": {
			"mook": [
				"security_operative"
			],
			"lieutenant": [
				"security_officer"
			],
			"mini_boss": [
				"security_officer"
			]
		}
	},
	"look": {
		"jacket": "3e6a4e",
		"accent": "ff3030",
		"pants": "2e3a32",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"sabotage",
		"assassination"
	]
}
```

### Petrochem (`petrochem`)

Fuel and chemicals megacorp. *RULES-UNVERIFIED.*

```world factions.factions.petrochem
{
	"name": "Petrochem",
	"kind": "corp",
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Petrochem Security",
			"lieutenant": "Petrochem Sergeant",
			"mini_boss": "Petrochem Enforcer"
		},
		"blocks": {
			"mook": [
				"security_operative"
			],
			"lieutenant": [
				"security_officer"
			],
			"mini_boss": [
				"security_officer"
			]
		}
	},
	"look": {
		"jacket": "6a5a3a",
		"accent": "ff3030",
		"pants": "3a3428",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"sabotage",
		"assassination"
	]
}
```

### Militech (`militech`)

Arms maker with a private army: more troopers, better kit, grenades. *RULES-UNVERIFIED.*

```world factions.factions.militech
{
	"name": "Militech",
	"kind": "corp",
	"doctrine": "corp_military",
	"roster": {
		"ranks": {
			"mook": "Militech Trooper",
			"lieutenant": "Militech Sergeant",
			"mini_boss": "Militech Lieutenant"
		},
		"blocks": {
			"mook": [
				"security_operative"
			],
			"lieutenant": [
				"security_officer"
			],
			"mini_boss": [
				"security_officer"
			]
		}
	},
	"look": {
		"jacket": "3a4232",
		"accent": "ff3030",
		"pants": "2a3026",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"sabotage",
		"assassination"
	]
}
```

### Zetatech (`zetatech`)

Computers and cyberware. *RULES-UNVERIFIED.*

```world factions.factions.zetatech
{
	"name": "Zetatech",
	"kind": "corp",
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Zetatech Security",
			"lieutenant": "Zetatech Sergeant",
			"mini_boss": "Zetatech Enforcer"
		},
		"blocks": {
			"mook": [
				"security_operative"
			],
			"lieutenant": [
				"security_officer"
			],
			"mini_boss": [
				"security_officer"
			]
		}
	},
	"look": {
		"jacket": "4a4a6a",
		"accent": "ff3030",
		"pants": "2e2e3e",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"sabotage",
		"assassination"
	]
}
```

### Kang Tao (`kang_tao`)

Smart-weapons maker. *RULES-UNVERIFIED.*

```world factions.factions.kang_tao
{
	"name": "Kang Tao",
	"kind": "corp",
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Kang Tao Security",
			"lieutenant": "Kang Tao Sergeant",
			"mini_boss": "Kang Tao Enforcer"
		},
		"blocks": {
			"mook": [
				"security_operative"
			],
			"lieutenant": [
				"security_officer"
			],
			"mini_boss": [
				"security_officer"
			]
		}
	},
	"look": {
		"jacket": "5a3a2a",
		"accent": "ff3030",
		"pants": "2e221c",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"sabotage",
		"assassination"
	]
}
```

### Rocklin Augmentics (`rocklin_augmentics`)

Cyberware and prosthetics. *RULES-UNVERIFIED.*

```world factions.factions.rocklin_augmentics
{
	"name": "Rocklin Augmentics",
	"kind": "corp",
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Rocklin Security",
			"lieutenant": "Rocklin Sergeant",
			"mini_boss": "Rocklin Enforcer"
		},
		"blocks": {
			"mook": [
				"security_operative"
			],
			"lieutenant": [
				"security_officer"
			],
			"mini_boss": [
				"security_officer"
			]
		}
	},
	"look": {
		"jacket": "4e5a62",
		"accent": "ff3030",
		"pants": "30383e",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"sabotage"
	]
}
```

### Trauma Team International (`trauma_team`)

Armed paramedics on subscription. As responders they land by AV for a downed cardholder; they can also be a gig target in their own right. *RULES-UNVERIFIED.*

```world factions.factions.trauma_team
{
	"name": "Trauma Team International",
	"kind": "service",
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Trauma Team Security",
			"lieutenant": "Trauma Team Sergeant",
			"mini_boss": "Trauma Team Enforcer"
		},
		"blocks": {
			"lieutenant": [
				"security_officer"
			],
			"mini_boss": [
				"security_officer"
			]
		},
		"responder": {
			"tier": "lieutenant",
			"count": 3,
			"rank": "Trauma Team",
			"armor": "heavy_armorjack"
		}
	},
	"look": {
		"jacket": "dfe6ea",
		"accent": "2a8cff",
		"pants": "3a4048",
		"vest": true,
		"helmet": true,
		"gloves": true,
		"visor": 1.0
	},
	"gigs": [
		"data_theft",
		"corp_extraction"
	]
}
```

### NCPD (`ncpd`)

Night City police. Answer escalating fights; at war with gangs, leave corp security alone. *RULES-UNVERIFIED.*

```world factions.factions.ncpd
{
	"name": "NCPD",
	"kind": "police",
	"roster": {
		"ranks": {
			"mook": "NCPD Officer",
			"lieutenant": "NCPD Sergeant",
			"mini_boss": "NCPD Lieutenant"
		},
		"blocks": {
			"mook": [
				"security_operative"
			],
			"lieutenant": [
				"security_officer"
			]
		},
		"responder": {
			"tiers": [
				"lieutenant",
				"mook",
				"mook"
			],
			"rank": "NCPD Officer"
		}
	},
	"look": {
		"jacket": "2a3448",
		"accent": "2a6aff",
		"pants": "1e2430",
		"vest": true,
		"helmet": true,
		"gloves": true
	}
}
```

### MaxTac (`maxtac`)

Police cyberpsycho squad. Answers instead of the NCPD when the crew's heat is high. *RULES-UNVERIFIED.*

```world factions.factions.maxtac
{
	"name": "MaxTac",
	"kind": "police",
	"roster": {
		"ranks": {
			"mook": "MaxTac",
			"lieutenant": "MaxTac",
			"mini_boss": "MaxTac"
		},
		"blocks": {
			"mini_boss": [
				"security_officer"
			]
		},
		"responder": {
			"tier": "mini_boss",
			"count": 4,
			"rank": "MaxTac",
			"armor": "metalgear"
		}
	},
	"look": {
		"jacket": "17191e",
		"accent": "ffcc00",
		"pants": "15171a",
		"vest": true,
		"helmet": true,
		"gloves": true,
		"visor": 1.0
	}
}
```

### Maelstrom (`maelstrom`)

Heavy-chrome gang; hostile to every other gang. *RULES-UNVERIFIED.*

```world factions.factions.maelstrom
{
	"name": "Maelstrom",
	"kind": "gang",
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Maelstrom Ganger",
			"lieutenant": "Maelstrom Boss",
			"mini_boss": "Maelstrom Warlord"
		},
		"blocks": {
			"mook": [
				"boosterganger"
			],
			"lieutenant": [
				"netrunner",
				"reclaimer_chief"
			],
			"mini_boss": [
				"pyro"
			]
		}
	},
	"look": {
		"jacket": "2a2224",
		"accent": "ff3030",
		"pants": "1c1a1c",
		"vest": false,
		"helmet": false,
		"gloves": true
	},
	"relations": {
		"gang": "hostile"
	},
	"gigs": [
		"gang_hit",
		"rescue",
		"sabotage",
		"assassination"
	]
}
```

### Tyger Claws (`tyger_claws`)

Blades and pistols; disciplined crew. *RULES-UNVERIFIED.*

```world factions.factions.tyger_claws
{
	"name": "Tyger Claws",
	"kind": "gang",
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Tyger Claw",
			"lieutenant": "Tyger Claws Boss",
			"mini_boss": "Tyger Claws Oyabun's Blade"
		},
		"blocks": {
			"mook": [
				"boosterganger"
			],
			"lieutenant": [
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "3a1e2a",
		"accent": "ff3030",
		"pants": "222226",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"rescue",
		"sabotage",
		"assassination"
	]
}
```

### Valentinos (`valentinos`)

Pistol-heavy gang. *RULES-UNVERIFIED.*

```world factions.factions.valentinos
{
	"name": "Valentinos",
	"kind": "gang",
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Valentino",
			"lieutenant": "Valentinos Boss",
			"mini_boss": "Valentinos Jefe"
		},
		"blocks": {
			"mook": [
				"boosterganger"
			],
			"lieutenant": [
				"reclaimer_chief"
			],
			"mini_boss": [
				"pyro"
			]
		}
	},
	"look": {
		"jacket": "4a3a22",
		"accent": "ff3030",
		"pants": "2a2420",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"rescue",
		"assassination"
	]
}
```

### 6th Street (`6th_street`)

Vigilante gang of ex-military; gets along with the NCPD. *RULES-UNVERIFIED.*

```world factions.factions.6th_street
{
	"name": "6th Street",
	"kind": "gang",
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "6th Street Patrol",
			"lieutenant": "6th Street Sergeant",
			"mini_boss": "6th Street Captain"
		},
		"blocks": {
			"mook": [
				"security_operative"
			],
			"lieutenant": [
				"security_officer"
			],
			"mini_boss": [
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "3e3a2e",
		"accent": "ff3030",
		"pants": "2a2a24",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"relations": {
		"police": "neutral"
	},
	"gigs": [
		"gang_hit",
		"rescue",
		"sabotage"
	]
}
```

### Wraiths (`wraiths`)

Nomad-style raiders on the city's edge. *RULES-UNVERIFIED.*

```world factions.factions.wraiths
{
	"name": "Wraiths",
	"kind": "gang",
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Wraith",
			"lieutenant": "Wraith Boss",
			"mini_boss": "Wraith Warlord"
		},
		"blocks": {
			"mook": [
				"road_ganger"
			],
			"lieutenant": [
				"reclaimer_chief"
			],
			"mini_boss": [
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "4a4034",
		"accent": "ff3030",
		"pants": "2e2a24",
		"vest": false,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"gang_hit",
		"rescue",
		"sabotage"
	]
}
```

### Bozos (`bozos`)

Clown-themed gang; melee and cheap guns. *RULES-UNVERIFIED.*

```world factions.factions.bozos
{
	"name": "Bozos",
	"kind": "gang",
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Bozo",
			"lieutenant": "Bozo Ringmaster",
			"mini_boss": "Bozo Headliner"
		},
		"blocks": {
			"mook": [
				"boosterganger"
			],
			"lieutenant": [
				"netrunner"
			],
			"mini_boss": [
				"pyro"
			]
		}
	},
	"look": {
		"jacket": "6a2a4a",
		"accent": "ff3030",
		"pants": "2a2a3a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"rescue"
	]
}
```
