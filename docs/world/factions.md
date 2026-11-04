# Factions

Who is who in Night City for the game: the gig's target faction fields the guards; the others turn up as third parties (bystanders, Trauma Team, NCPD, MaxTac, district security, rival crews). Each section is a short paraphrase with a citation, and a `world` data block that `tools/gen_world_data.py` turns into `data/world/factions.json`. Edit here, then regenerate.

Source: **Night City 2045** (cited `NC2045 p.N`, PDF page numbers; the printed page is one less). Its Factions chapter (p.32-52) gives 44 gangs, 6 criminal organisations and the security providers; the City Council list (p.21-22) and the district chapters supply the corporations, services and nomads that own or guard places (`docs/world/nc_*.md`). Owner rulings: the factions are book-only (the Valentinos, Wraiths, Kang Tao and Zetatech are gone); venue placeholders the book prints as responders ("Patrons", "Staff", "Residents", "Various", "??") are one faction, `locals`.

What is **book-sourced** per faction: the name, `leader` (as printed), `activities` (the printed Activities/Themes, as tags), the look as described in the paraphrase (Identifiers), the armament line, and the rivalries/patrons the prose names. What is **ours**: `kind`, `territory` (derived from the district docs: districts that list the faction among their gangs, name it as provider, or hold places it owns), `relations` beyond what the prose names (each paraphrase says which are from the prose), the `look` colours (**RULES-UNVERIFIED: colours ours**, picked from the Identifiers where they name one), `gigs`, `doctrine` and the rank names. `roster.blocks` uses the faction's own printed district blocks (data/rules/npcs.json `faction`) and fills the tiers the book doesn't print from the core blocks (CPR core p.412-416) or, for factions whose own block is Hardened, the RTG Hardened series.

## How the data reads

```world factions._doc
"Factions of Night City (World.faction), from Night City 2045 (NC2045 p.32-52 and the district chapters). The gig's target faction fields the guards; others appear as third parties (bystanders, Trauma Team, NCPD, MaxTac, district security, rival crews). kind (crew/civilian/captive/corp/criminal/gang/police/service) sets defaults; relations are symmetric and resolved most-hostile-wins between kind defaults and per-faction overrides (by faction id, else by kind). leader and activities are as printed; territory is district ids (derived from docs/world/nc_*.md). roster: ranks name the NPC tiers (ours); blocks list the stat blocks (npcs.json) the faction fields per tier: its own printed NC2045 blocks, the rest core or Hardened stand-ins; a tier without blocks falls back to the tier's default pool; responder: who they send when called. look: what the view dresses them in (jacket/accent/pants colours are ours, RULES-UNVERIFIED; vest/helmet/gloves). gigs: the gig kinds (gigs.json templates) this faction can be the target of (ours, from activities, plus the gigs listed on places it owns; gangs never take data_theft/corp_extraction, only gangs take gang_hit). doctrine: security style (data/world/security.json). cite: where the book describes it."
```

## Stat blocks in rosters

`roster.blocks` names, per tier, the printed stat blocks (data/rules/npcs.json) a faction fields:
their stats, skills, armour, guns (with the book's quality), cyberware and grenades come from the
block, never from here. Night City 2045 prints one block for most factions (usually a Mook or
Hardened Mook, NC2045 district "STAT Blocks" pages), so the other tiers are stand-ins, chosen by family:

- gangs: Boosterganger; Reclaimer Chief or Netrunner; Pyro or Outrider (CPR core p.412-416), or the
  Hardened versions for gangs whose own block is Hardened;
- criminal organisations: Bodyguard; Security Officer or Netrunner; Outrider, or Hardened Bodyguard,
  Hardened Security Officer (Raid) / Netrunner (Anti-Personnel), Hardened Executive Protection or Sniper;
- police (deputized providers): Security Operative; Security Officer; no mini boss, or the Hardened
  Security Operative / Officers and Hardened Sniper;
- corps: Security Operative; Security Officer; Security Officer (the core book has no corporate mini
  boss), or Hardened Security Operative / Officers and Hardened Executive Protection;
- nomads: Road Ganger; Reclaimer Chief; Outrider.

All of this mapping is ours (**RULES-UNVERIFIED**); a few factions are set by hand (Lazarus and MAX-TAC
"don't recruit mooks", NC2045 p.50; the Willows are elite edgerunners; Militech fields the Hardened
Militech Veteran).

## Relations between kinds

Defaults by kind, symmetric (most hostile wins); a faction's own `relations` override replaces them. `criminal` (criminal organisations) is ours: at odds with the police, neutral to corps and gangs (the Skiv Family is "in bed with" corporations, NC2045 p.48).

```world factions.kind_relations
{
	"crew": {
		"crew": "ally",
		"corp": "hostile",
		"criminal": "hostile",
		"gang": "hostile",
		"police": "hostile",
		"service": "neutral",
		"civilian": "neutral",
		"captive": "neutral"
	},
	"corp": {
		"corp": "neutral",
		"criminal": "neutral",
		"gang": "hostile",
		"police": "neutral",
		"service": "neutral",
		"civilian": "neutral",
		"captive": "neutral"
	},
	"criminal": {
		"criminal": "neutral",
		"gang": "neutral",
		"police": "hostile",
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

### The game's own

### The crew (`crew`)

The player's crew. Never a gig target. *(Ours.)*

```world factions.factions.crew
{
	"name": "The crew",
	"kind": "crew",
	"cite": "ours"
}
```

### Bystanders (`bystanders`)

People on the street and in public rooms. They panic at gunfire and run for the map edge. *(Ours.)*

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
	},
	"cite": "ours"
}
```

### Captive (`captive`)

The person a rescue gig is about. Neutral until freed, then on the crew's side. *(Ours.)*

```world factions.factions.captive
{
	"name": "Captive",
	"kind": "captive",
	"cite": "ours"
}
```

### Private security (`security`)

Generic private security (World.DEFAULT_OPFOR), used when a gig names no faction. At corporate sites they run the corporate doctrine. The book's equivalent is Corporate Security (`corporate_security`, NC2045 p.49). *(Ours.)*

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
	},
	"cite": "ours"
}
```

### The locals (`locals`)

The place's own armed people: bouncers, regulars, residents, staff and friends of the owner. The book prints these as a venue's Security Code responder ("Patrons", "Staff", "Residents", "Various", "??", e.g. the Afterlife's patrons, NC2045 p.69); owner ruling: one faction for all of them. They field civilian and mook blocks: the core Bodyguard and Boosterganger and the book's Firing Range Patron (p.164), Deli Brawler (p.174) and Rupture Fighter (p.255). Never a gig target in their own right. When such a code responds, the code's `responder` (docs/world/locations.md) decides who comes: HOUSE-RULE (owner ruling 2026-11-04), patrons and residents are armed locals drawn from the district's civilian blocks (data/rules/npcs.json `civilian`), staff are the owner's people when the owner is a faction (else armed locals), "Various Gangs" one of the district's gangs, and various or "??" any one of those the place has; the locals' officers (Bouncer, Hard Case) still come from this roster. *(Ours; kind service: neutral to passers-by until the place is hit.)*

```world factions.factions.locals
{
	"name": "The locals",
	"kind": "service",
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Local",
			"lieutenant": "Bouncer",
			"mini_boss": "Hard Case"
		},
		"blocks": {
			"mook": [
				"bodyguard",
				"boosterganger",
				"firing_range_patron",
				"deli_brawler",
				"rupture_fighter"
			],
			"lieutenant": [
				"reclaimer_chief"
			]
		}
	},
	"look": {
		"jackets": [
			"5a4a3a",
			"3a4a5a",
			"4a3a3a",
			"3a3a3a",
			"6a5a4a"
		],
		"accent_from_jacket": 0.3,
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"cite": "ours"
}
```

### Gangs (NC2045 p.32-46)

The book's 44 gangs ("guardians, chromers, posers, and freaks", p.32), plus the Faded, the Old Combat Zone's own faction.

### 6th Street (`6th_street`)

Military veterans who went from vigilantes to a cut-price security firm; founder Solomon "X" Wright wants a PMC on Militech's scale. Deputized law in North Heywood under the City Manager's contract, and guards churches, Minimallism and Aerocab. Spending outruns contracts, so they top up with protection rackets, blackmail and selling what they seize. Well armed and armoured, assault rifles over sidearms; their base, the Armory, is fortified. Identifiers: the gang logo on military-style patches. Relations: gets along with the police (ours, from the deputized role). *(NC2045 p.33, p.49.)*

```world factions.factions.6th_street
{
	"name": "6th Street",
	"kind": "gang",
	"leader": "Solomon \"X\" Wright",
	"activities": [
		"security",
		"mercenary_work",
		"smuggling",
		"extortion"
	],
	"territory": [
		"little_europe",
		"new_westbrook",
		"north_heywood",
		"pacifica_playground",
		"rancho_coronado"
	],
	"relations": {
		"police": "neutral"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "6th Street Patrol",
			"lieutenant": "6th Street Sergeant",
			"mini_boss": "6th Street Captain"
		},
		"blocks": {
			"mook": [
				"6th_street_guard"
			],
			"lieutenant": [
				"hardened_reclaimer_chief_lightning",
				"hardened_reclaimer_chief_thunder",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_pyro",
				"hardened_outrider"
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
	"gigs": [
		"gang_hit",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.33, p.49"
}
```

### Albino Alligators (`albino_alligators`)

A party gang that matters because it holds a dead car wash still tapped into the mains: one of Rancho Coronado's few reliable water sources. Cheap guns, cheaper armour, scrounged gear. Identifiers: popped shirt collars and a white cartoon alligator mascot. *(NC2045 p.33.)*

```world factions.factions.albino_alligators
{
	"name": "Albino Alligators",
	"kind": "gang",
	"leader": "Big Bruno",
	"activities": [
		"partying",
		"extortion",
		"random_violence"
	],
	"territory": [
		"rancho_coronado"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "'Gator",
			"lieutenant": "'Gator Lieutenant",
			"mini_boss": "'Gator Enforcer"
		},
		"blocks": {
			"mook": [
				"albino_alligators_mook"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "e8e4d8",
		"accent": "ff3030",
		"pants": "3a4a3a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.33"
}
```

### The Andersons (`andersons`)

A family yogang whose members all take the gang's surname; now organised scavvers, thieves and muggers feeding leader Molly's Night Market supply chain. Molly's romance with a Piranha suggests the Piranhas will absorb them. Identifiers: denim, ANDERSONS tattooed across the knuckles. Territory isn't fixed (hangouts vary). *(NC2045 p.33.)*

```world factions.factions.andersons
{
	"name": "The Andersons",
	"kind": "gang",
	"leader": "Molly Anderson",
	"activities": [
		"scavving",
		"petty_theft",
		"mugging"
	],
	"relations": {
		"piranhas": "neutral"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Anderson",
			"lieutenant": "Anderson Lieutenant",
			"mini_boss": "Anderson Enforcer"
		},
		"blocks": {
			"mook": [
				"boosterganger"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "3a5a8a",
		"accent": "ff3030",
		"pants": "2a3a5a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"rescue"
	],
	"cite": "NC2045 p.33"
}
```

### Arzin Tynon (`arzin_tynon`)

Biker gang that found its niche in the 4th Corporate War smuggling black-market goods down the NorCal highways in saddlebags. Strong, heavily armed and mean, steeped in 20th-century biker culture; they respect anyone who stands up to them. Identifiers: armorjack with the logo embroidered on the back. *(NC2045 p.34.)*

```world factions.factions.arzin_tynon
{
	"name": "Arzin Tynon",
	"kind": "gang",
	"leader": "Jimmy \"Dequiallo\" Miles",
	"activities": [
		"smuggling",
		"drugs",
		"racing",
		"extortion",
		"random_violence"
	],
	"territory": [
		"new_westbrook",
		"watson_development"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Arzin Tynon",
			"lieutenant": "Arzin Tynon Lieutenant",
			"mini_boss": "Arzin Tynon Enforcer"
		},
		"blocks": {
			"mook": [
				"arzin_tynon_mook"
			],
			"lieutenant": [
				"hardened_reclaimer_chief_lightning",
				"hardened_reclaimer_chief_thunder",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_pyro",
				"hardened_outrider"
			]
		}
	},
	"look": {
		"jacket": "2a2420",
		"accent": "ff3030",
		"pants": "1e1c1a",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"gang_hit",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.34"
}
```

### The Bozos (`bozos`)

Bodysculpted circus clowns who went from harmless pranks to psychological cruelty under the "Great Bozo", rumoured a cyberpsycho Tech; now split into rival "circuses" fighting a clown civil war of ever-nastier pranks (brainwashed streetrat bombers, synthcoke bombs). Identifiers: they look like clowns. *(NC2045 p.34.)*

```world factions.factions.bozos
{
	"name": "The Bozos",
	"kind": "gang",
	"leader": "Multiple",
	"activities": [
		"terrorism",
		"torture",
		"random_violence",
		"targeted_violence"
	],
	"territory": [
		"charter_hill",
		"south_night_city"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Bozo",
			"lieutenant": "Bozo Ringmaster",
			"mini_boss": "Bozo Headliner"
		},
		"blocks": {
			"mook": [
				"bozo_mook"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
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
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.34"
}
```

### Culper Ring (`culper_ring`)

A secret cell of airmen, soldiers and sailors on the NorCal Military Base who want California back in a militarised United States and pass intelligence on NorCal and the Pacifica Confederation to the US government. Membership unknown; assume trained, military-armed soldiers, some high in the chain of command. Identifiers: the logo on jewellery or tattooed. Relations: works for the US government (from the prose). *(NC2045 p.34.)*

```world factions.factions.culper_ring
{
	"name": "Culper Ring",
	"kind": "gang",
	"leader": "Unknown",
	"activities": [
		"espionage"
	],
	"territory": [
		"norcal_military_base"
	],
	"relations": {
		"us_government": "ally"
	},
	"doctrine": "corp_military",
	"roster": {
		"ranks": {
			"mook": "Culper Soldier",
			"lieutenant": "Culper Sergeant",
			"mini_boss": "Culper Officer"
		},
		"blocks": {
			"mook": [
				"hardened_boosterganger"
			],
			"lieutenant": [
				"hardened_reclaimer_chief_lightning",
				"hardened_reclaimer_chief_thunder",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_pyro",
				"hardened_outrider"
			]
		}
	},
	"look": {
		"jacket": "4a4e3a",
		"accent": "ff3030",
		"pants": "3a3e2e",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"gang_hit",
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.34"
}
```

### DeadWoods (`deadwoods`)

Posergang, guardian gang and personality cult: founder Isaiah "Gunslinger" Hurston sells an Old West code of guarding the cargo trains through the city, free to Snake Nation and the shippers. Funded by the Molly May casino in the Glen; they ride escort on motorcycles or shotgun on the roofs, with revolvers and shotguns. Identifiers: cowboy clothes. Relations: allied with the Snake Nation rail nomads (from the prose). *(NC2045 p.35.)*

```world factions.factions.deadwoods
{
	"name": "DeadWoods",
	"kind": "gang",
	"leader": "Isaiah \"Gunslinger\" Hurston",
	"activities": [
		"extortion",
		"gambling",
		"sex_work",
		"security"
	],
	"territory": [
		"heywood_docks",
		"heywood_industrial_zone",
		"outskirts",
		"port_of_night_city",
		"south_night_city",
		"the_glen"
	],
	"relations": {
		"snake_nation": "ally",
		"groundhog_gulpers": "ally"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "DeadWood",
			"lieutenant": "DeadWood Lieutenant",
			"mini_boss": "DeadWood Enforcer"
		},
		"blocks": {
			"mook": [
				"deadwoods_mook"
			],
			"lieutenant": [
				"hardened_reclaimer_chief_lightning",
				"hardened_reclaimer_chief_thunder",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_pyro",
				"hardened_outrider"
			]
		}
	},
	"look": {
		"jacket": "6a4a2a",
		"accent": "ff3030",
		"pants": "3a3028",
		"vest": false,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"gang_hit",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.35"
}
```

### The Dirty Hippies (`dirty_hippies`)

Guerrilla gardeners and dealers of smokable street drugs ("Ganga": chemically sprayed weeds) who grow and cook in the middle of Voodoo Boys turf. Mellow, not peaceful: they carry pistols and rifles. Identifiers: faded tie-dye. Relations: operate inside Voodoo Boys territory (the prose names no war; ours: neutral). *(NC2045 p.35.)*

```world factions.factions.dirty_hippies
{
	"name": "The Dirty Hippies",
	"kind": "gang",
	"leader": "Canary",
	"activities": [
		"drugs"
	],
	"territory": [
		"rancho_coronado",
		"university_district"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Hippie",
			"lieutenant": "Hippie Lieutenant",
			"mini_boss": "Hippie Enforcer"
		},
		"blocks": {
			"mook": [
				"dirty_hippies_mook"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "8a6a9a",
		"accent": "ff3030",
		"pants": "5a5a3a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.35"
}
```

### Dragula Racers (`dragula_racers`)

Small, largely harmless gang of monster-sculpted hot-rodders who dominate the street-racing scene in souped-up hearses. Pistols on the members, machine guns and rocket launchers on the cars. Identifiers: monster-themed bodysculpts. *(NC2045 p.35.)*

```world factions.factions.dragula_racers
{
	"name": "Dragula Racers",
	"kind": "gang",
	"leader": "Frankie Sparks",
	"activities": [
		"racing"
	],
	"territory": [
		"watson_development"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Dragula",
			"lieutenant": "Dragula Lieutenant",
			"mini_boss": "Dragula Enforcer"
		},
		"blocks": {
			"mook": [
				"dragula_racers_driver"
			],
			"lieutenant": [
				"hardened_reclaimer_chief_lightning",
				"hardened_reclaimer_chief_thunder",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_pyro",
				"hardened_outrider"
			]
		}
	},
	"look": {
		"jacket": "1a1a1e",
		"accent": "ff3030",
		"pants": "2a1a2a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"sabotage"
	],
	"cite": "NC2045 p.35"
}
```

### The Enhanced (`enhanced`)

A secretive cult that holds cyberpsychosis to be humanity's next step. It owns or is invested in GunMart and floods the street with cheap guns, manipulating factions into fights rather than fighting itself; members choose explosive suicide over capture. Maybe tied to the old Brainiacs. Identifiers: the logo etched into cyberware or branded on skin. Relations: GunMart (from the prose). *(NC2045 p.35.)*

```world factions.factions.enhanced
{
	"name": "The Enhanced",
	"kind": "gang",
	"leader": "Unknown",
	"activities": [
		"promoting_megaviolence"
	],
	"territory": [
		"heywood_industrial_zone",
		"south_night_city",
		"upper_marina"
	],
	"relations": {
		"gunmart": "ally"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Enhanced",
			"lieutenant": "Enhanced Lieutenant",
			"mini_boss": "Enhanced Enforcer"
		},
		"blocks": {
			"mook": [
				"boosterganger"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "3a3a3e",
		"accent": "ff3030",
		"pants": "2a2a2e",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.35"
}
```

### Eurotrashers (`eurotrashers`)

A party gang in love with 1980s fashion and fake European accents, partying or rolling drunk tourists for party money. Blackjacks and knives before guns, except against the Undertow. Identifiers: 1980s fashion. Relations: rivals of the Undertow (from the prose). *(NC2045 p.36.)*

```world factions.factions.eurotrashers
{
	"name": "Eurotrashers",
	"kind": "gang",
	"leader": "Lys \"Refrain\" Schärer",
	"activities": [
		"partying",
		"mugging",
		"random_violence"
	],
	"territory": [
		"little_europe"
	],
	"relations": {
		"undertow": "hostile"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Eurotrasher",
			"lieutenant": "Eurotrasher Lieutenant",
			"mini_boss": "Eurotrasher Enforcer"
		},
		"blocks": {
			"mook": [
				"eurotrashers_mook"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "d84a9a",
		"accent": "ff3030",
		"pants": "2a2a3a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"rescue"
	],
	"cite": "NC2045 p.36"
}
```

### Fixie's Couriers (`fixies_couriers`)

An anarchist collective of bike and motorcycle couriers, modelled by Fixie on her grandfather's Mumbai dabbawalas; they carry at least half the city's messages and small parcels. Fastidiously neutral but not pacifist: they flee first, then draw melee weapons or handguns. Identifiers: reflective caps and arm bands. Relations: neutral to everyone (ours, from the prose). *(NC2045 p.36.)*

```world factions.factions.fixies_couriers
{
	"name": "Fixie's Couriers",
	"kind": "gang",
	"leader": "Fixie",
	"activities": [
		"courier_services"
	],
	"territory": [
		"heywood_industrial_zone"
	],
	"relations": {
		"gang": "neutral",
		"police": "neutral",
		"corp": "neutral",
		"criminal": "neutral"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Courier",
			"lieutenant": "Courier Dispatcher",
			"mini_boss": "Courier Captain"
		},
		"blocks": {
			"mook": [
				"bicycle_courier"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "e0d020",
		"accent": "ff3030",
		"pants": "2a2a2a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.36"
}
```

### G3 (`g3`)

A disturbingly violent anime posergang that runs the 100.0 G3 Gun-Gal radio station. Many, leader included, are close to cyberpsychosis behind their pretty sculpts and custom implants; expect mono-katanas. Identifiers: anime bodysculpts, J-Pop fashion. *(NC2045 p.36.)*

```world factions.factions.g3
{
	"name": "G3",
	"kind": "gang",
	"leader": "Hazumi Ihara",
	"activities": [
		"anime_piracy",
		"random_violence"
	],
	"territory": [
		"kabuki",
		"watson_development"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "G3",
			"lieutenant": "G3 Lieutenant",
			"mini_boss": "G3 Enforcer"
		},
		"blocks": {
			"mook": [
				"g3_mook"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "ff6ab0",
		"accent": "ff3030",
		"pants": "3a2a5a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.36"
}
```

### Generation Red (`generation_red`)

A resourceful yogang in the Old Combat Zone that just fought off the Kill Krashers' attack on its clubhouse; ERI and Danger Gal have both sent people to talk about its future. Identifiers: a logo patch somewhere on their clothes. Relations: enemies of the Kill Krashers (from the prose). *(NC2045 p.36.)*

```world factions.factions.generation_red
{
	"name": "Generation Red",
	"kind": "gang",
	"leader": "Apex",
	"activities": [
		"hanging_out"
	],
	"territory": [
		"old_combat_zone"
	],
	"relations": {
		"kill_krashers": "hostile"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Gen Red",
			"lieutenant": "Gen Red Lieutenant",
			"mini_boss": "Gen Red Enforcer"
		},
		"blocks": {
			"mook": [
				"generation_red_kid"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "8a2a2a",
		"accent": "ff3030",
		"pants": "3a3a3a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"rescue"
	],
	"cite": "NC2045 p.36"
}
```

### Gold Dragons (`gold_dragons`)

A street booster gang raised by its patron David Ling Po into Little China's deputized law; they also guard Tong businesses elsewhere. They live by a Hong Kong action-movie honour code: jump boosters and grip feet for acrobatic duels, SMGs in a gunfight, and cyberoptics Ling Po reputedly watches through. Identifiers: puffy gold jackets (Dirk Combat Jackets). Relations: the Weng Fang Tong's (from the prose); enemies of the Eastern Tigers Triad, who are after Ling Po (from the prose); get along with the police (ours, deputized). *(NC2045 p.36-37, p.49-50.)*

```world factions.factions.gold_dragons
{
	"name": "Gold Dragons",
	"kind": "gang",
	"leader": "Edwina \"Eddy\" Sing",
	"activities": [
		"security",
		"extortion"
	],
	"territory": [
		"little_china",
		"upper_marina"
	],
	"relations": {
		"police": "neutral",
		"weng_fang_tong": "ally",
		"lcra": "ally",
		"eastern_tigers_triad": "hostile"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Gold Dragon",
			"lieutenant": "Gold Dragon Lieutenant",
			"mini_boss": "Gold Dragon Enforcer"
		},
		"blocks": {
			"mook": [
				"gold_dragons_mook"
			],
			"lieutenant": [
				"hardened_reclaimer_chief_lightning",
				"hardened_reclaimer_chief_thunder",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_pyro",
				"hardened_outrider"
			]
		}
	},
	"look": {
		"jacket": "d4a020",
		"accent": "ff3030",
		"pants": "2a2420",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"assassination",
		"rescue"
	],
	"cite": "NC2045 p.36-37, p.49-50"
}
```

### Inquisitors (`inquisitors`)

An anti-cyberware secret society that stalks the night streets, attacking visibly chromed people and ripping their implants out, survival optional; lone boostergangers, especially Maelstrom, are favourite prey. Members come from every class (lately radicalised corpzoner teens) and know few others. Identifiers: logo jewellery or tattoos, white hoodies, gas masks. Relations: hunt Maelstrom (from the prose). *(NC2045 p.37.)*

```world factions.factions.inquisitors
{
	"name": "Inquisitors",
	"kind": "gang",
	"leader": "Unknown",
	"activities": [
		"targeted_violence"
	],
	"territory": [
		"charter_hill",
		"north_heywood"
	],
	"relations": {
		"maelstrom": "hostile"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Inquisitor",
			"lieutenant": "Inquisitor Lieutenant",
			"mini_boss": "Inquisitor Enforcer"
		},
		"blocks": {
			"mook": [
				"inquisitors_mook"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "e6e6e6",
		"accent": "ff3030",
		"pants": "8a8a8a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"assassination",
		"rescue"
	],
	"cite": "NC2045 p.37"
}
```

### Iron Sights (`iron_sights`)

An unkillable gang: smashed again and again (above all by Maelstrom), always back with a patron's help; the current sponsor, Hornet, has them dominant and growing. Old-school punks who still charge a toll in money or blood for crossing their turf. Pistols and cheap explosives low down, assault rifles and biotoxin higher up. Identifiers: facial scarification, mohawks, classic punk. Relations: Maelstrom's victims and the Red Chrome Legion's eternal enemies (from the prose). *(NC2045 p.37.)*

```world factions.factions.iron_sights
{
	"name": "Iron Sights",
	"kind": "gang",
	"leader": "BloodGuts",
	"activities": [
		"theft",
		"drugs",
		"sex_work",
		"extortion"
	],
	"territory": [
		"old_combat_zone",
		"old_japantown"
	],
	"relations": {
		"red_chrome_legion": "hostile",
		"maelstrom": "hostile"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Iron Sight",
			"lieutenant": "Iron Sight Lieutenant",
			"mini_boss": "Iron Sight Enforcer"
		},
		"blocks": {
			"mook": [
				"iron_sights_mook"
			],
			"lieutenant": [
				"hardened_reclaimer_chief_lightning",
				"hardened_reclaimer_chief_thunder",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_pyro",
				"hardened_outrider"
			]
		}
	},
	"look": {
		"jacket": "2a2a2a",
		"accent": "ff3030",
		"pants": "3a2a2a",
		"vest": false,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"gang_hit",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.37"
}
```

### Julliard Guild (`julliard_guild`)

Controls busking with a chrome fist: an invitation, a reminder, then weapons for anyone playing a corner unlicensed. Takes 15% of a performer's take for armed protection and the best spots, Night City Plaza above all; books members into Piranha parties. Pistols and light armour while performing; their bodyguards favour shotguns. Identifiers: logo stickers on instrument cases. Relations: deals with the Piranhas (from the prose). *(NC2045 p.37.)*

```world factions.factions.julliard_guild
{
	"name": "Julliard Guild",
	"kind": "gang",
	"leader": "Sebastian \"Shakespeare\" McBride",
	"activities": [
		"busking",
		"performances",
		"protection"
	],
	"territory": [
		"downtown",
		"the_glen"
	],
	"relations": {
		"piranhas": "ally"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Julliard Busker",
			"lieutenant": "Julliard Bodyguard",
			"mini_boss": "Julliard Bandleader"
		},
		"blocks": {
			"mook": [
				"night_city_plaza_busker"
			],
			"lieutenant": [
				"hardened_reclaimer_chief_lightning",
				"hardened_reclaimer_chief_thunder",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_pyro",
				"hardened_outrider"
			]
		}
	},
	"look": {
		"jacket": "5a2a3a",
		"accent": "ff3030",
		"pants": "2a2a2a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.37"
}
```

### Kill Krashers (`kill_krashers`)

A dorph gang of teens and young adults who love violence for its own sake: harmless in ones and twos, a storm of destruction in a mob. They loot their victims' bodies, so expect any weapon. Identifiers: black-and-red painted rippers. Roam at random. Relations: attacked Generation Red (from the prose). *(NC2045 p.38.)*

```world factions.factions.kill_krashers
{
	"name": "Kill Krashers",
	"kind": "gang",
	"leader": "Carrion",
	"activities": [
		"targeted_violence",
		"random_violence"
	],
	"territory": [
		"reclamation_zone",
		"south_night_city",
		"the_glen",
		"university_district"
	],
	"relations": {
		"generation_red": "hostile"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Kill Krasher",
			"lieutenant": "Kill Krasher Lieutenant",
			"mini_boss": "Kill Krasher Enforcer"
		},
		"blocks": {
			"mook": [
				"kill_krashers_mook"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "1a1a1a",
		"accent": "ff2020",
		"pants": "2a1414",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"assassination"
	],
	"cite": "NC2045 p.38"
}
```

### Lightning Cats (`lightning_cats`)

Cat exotics living wild in the wreck of the Old Med Center in the Hot Zone; the legend says botched sculpts made monsters, the truth is they just refuse to be domesticated. Mostly skilled hand-to-hand fighters (Aikido, Judo) with cyberweapons. Identifiers: feline bodysculpts. *(NC2045 p.38.)*

```world factions.factions.lightning_cats
{
	"name": "Lightning Cats",
	"kind": "gang",
	"leader": "Bengal Khan",
	"activities": [
		"survival",
		"scavving"
	],
	"territory": [
		"hot_zone"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Lightning Cat",
			"lieutenant": "Lightning Cat Lieutenant",
			"mini_boss": "Lightning Cat Enforcer"
		},
		"blocks": {
			"mook": [
				"lightning_cats_mook"
			],
			"lieutenant": [
				"hardened_reclaimer_chief_lightning",
				"hardened_reclaimer_chief_thunder",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_pyro",
				"hardened_outrider"
			]
		}
	},
	"look": {
		"jacket": "c88a3a",
		"accent": "ff3030",
		"pants": "4a3a2a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"rescue"
	],
	"cite": "NC2045 p.38"
}
```

### Maelstrom (`maelstrom`)

A combat gang since the 2010s with a near-religious faith in chrome; it absorbs beaten boostergangs, runs a huge drug and tech-trafficking network with Digger scavver crews in the Hot Zone and techs and ripperdocs kept on the payroll (often unwillingly). The NCPD wonders whether it's a syndicate now. More chrome means higher rank; weapons run big and heavy. Identifiers: the logo etched into cyberware. Relations: hostile to every other gang (ours: a combat gang that absorbs the rest; the prose names the Iron Sights). *(NC2045 p.38.)*

```world factions.factions.maelstrom
{
	"name": "Maelstrom",
	"kind": "gang",
	"leader": "Warlock",
	"activities": [
		"drugs",
		"extortion",
		"smuggling",
		"random_violence",
		"targeted_violence",
		"mercenary_work"
	],
	"territory": [
		"heywood_docks",
		"hot_zone",
		"little_europe",
		"old_japantown",
		"upper_marina"
	],
	"relations": {
		"gang": "hostile"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Maelstrom Ganger",
			"lieutenant": "Maelstrom Boss",
			"mini_boss": "Maelstrom Warlord"
		},
		"blocks": {
			"mook": [
				"maelstrom_mook"
			],
			"lieutenant": [
				"hardened_reclaimer_chief_lightning",
				"hardened_reclaimer_chief_thunder",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_pyro",
				"hardened_outrider"
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
	"gigs": [
		"gang_hit",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.38"
}
```

### Mudang Gumi (`mudang_gumi`)

The least-known gang in the city: thieves and Netrunners doing sabotage, espionage and cybercrime, possibly sponsored by Tanson. Identifiers unknown. Relations: rumoured Tanson's (from the prose). *(NC2045 p.38-39.)*

```world factions.factions.mudang_gumi
{
	"name": "Mudang Gumi",
	"kind": "gang",
	"leader": "Unknown",
	"activities": [
		"theft",
		"espionage",
		"identity_theft",
		"citinet_scams"
	],
	"territory": [
		"pacifica_playground"
	],
	"relations": {
		"tanson": "ally"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Mudang Gumi",
			"lieutenant": "Mudang Gumi Lieutenant",
			"mini_boss": "Mudang Gumi Enforcer"
		},
		"blocks": {
			"mook": [
				"boosterganger"
			],
			"lieutenant": [
				"mudang_gumi_data_thief"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "2a3a4a",
		"accent": "ff3030",
		"pants": "1e2a34",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.38-39"
}
```

### The Muses (`muses`)

A Woodland Park posergang of 1980s big hair and Grecian togas that is also a Wonderland League roller-derby squad, hosting parties at Xanadu, their arena and club. Rarely fight; when they do, derby cudgels and disco-ball pistols. Identifiers: togas and disco themes. *(NC2045 p.39.)*

```world factions.factions.muses
{
	"name": "The Muses",
	"kind": "gang",
	"leader": "Calliope",
	"activities": [
		"partying",
		"roller_derby"
	],
	"territory": [
		"north_heywood"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Muse",
			"lieutenant": "Muse Lieutenant",
			"mini_boss": "Muse Enforcer"
		},
		"blocks": {
			"mook": [
				"hardened_boosterganger"
			],
			"lieutenant": [
				"rollerderby_jammer"
			],
			"mini_boss": [
				"hardened_pyro",
				"hardened_outrider"
			]
		}
	},
	"look": {
		"jacket": "e8e0f0",
		"accent": "ff3030",
		"pants": "c8a040",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"rescue"
	],
	"cite": "NC2045 p.39"
}
```

### Philharmonic Vampyres (`philharmonic_vampyres`)

Prankers turned goths, named for a 2010s photobomb of the Symphony; now split between The Master's goth artists staging horror shows at Symphony Hall and Acme's pranksters, though most get along. More likely to flee than fight, but many know martial arts. Identifiers: goth fashion, vampyres. *(NC2045 p.39.)*

```world factions.factions.philharmonic_vampyres
{
	"name": "Philharmonic Vampyres",
	"kind": "gang",
	"leader": "The Master & Acme",
	"activities": [
		"theatrical_productions",
		"pranking"
	],
	"territory": [
		"charter_hill",
		"university_district"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Vampyre",
			"lieutenant": "Vampyre Lieutenant",
			"mini_boss": "Vampyre Enforcer"
		},
		"blocks": {
			"mook": [
				"philharmonic_vampyre_mook"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "1a1a22",
		"accent": "ff3030",
		"pants": "2a1a2a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"rescue"
	],
	"cite": "NC2045 p.39"
}
```

### Piranhas (`piranhas`)

Corpse Reviver made dorphed partiers into the city's party purveyors, absorbing the other party gangs into cells called shoals; wherever there's a party they sell drugs, sex or connections. Most reliably at Playland, kept free of gang war in exchange for free rein. Shoals carry pistols or SMGs, cybersnakes are common, big shoals bring one heavy-weapon enforcer; less-lethal at parties. Identifiers: a logo tattoo. *(NC2045 p.39-40.)*

```world factions.factions.piranhas
{
	"name": "Piranhas",
	"kind": "gang",
	"leader": "Corpse Reviver",
	"activities": [
		"drugs",
		"sex_work",
		"partying",
		"gambling",
		"running_parties"
	],
	"territory": [
		"pacifica_playground",
		"playland",
		"the_glen",
		"university_district"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Piranha",
			"lieutenant": "Piranha Lieutenant",
			"mini_boss": "Piranha Enforcer"
		},
		"blocks": {
			"mook": [
				"piranhas_mook"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "1a6a8a",
		"accent": "ff3030",
		"pants": "2a2a3a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.39-40"
}
```

### The Prime-Time Players (`prime_time_players`)

A loose umbrella of posergangs (the Kennedys, Castaways, Final Frontiers, Stallones...) under action star Vicktor Vang, or a convincing sim of him. Members are sculpted and armed to fit their show; a mob of them chanting their theme in a dark alley is the stuff of nightmares. Identifiers: media-inspired sculpts and costumes. *(NC2045 p.40.)*

```world factions.factions.prime_time_players
{
	"name": "The Prime-Time Players",
	"kind": "gang",
	"leader": "Vicktor Vang",
	"activities": [
		"extortion",
		"sex_work",
		"blackmail",
		"random_violence"
	],
	"territory": [
		"charter_hill",
		"new_westbrook",
		"upper_marina"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Prime-Time Player",
			"lieutenant": "Prime-Time Player Lieutenant",
			"mini_boss": "Prime-Time Player Enforcer"
		},
		"blocks": {
			"mook": [
				"prime_time_players_mook"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "aa6a2a",
		"accent": "ff3030",
		"pants": "3a3a5a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.40"
}
```

### Princesses of Justice (`princesses_of_justice`)

A cartoon posergang that shelters victims of domestic abuse at Princessland in the University District, with religious fervour under the formidable Adorable. Armed like the show: flaming swords, electrified whips, trick arrows, sticky grenades. Identifiers: costumes and sculpts from the Princesses of Justice show. Relations: get along with the police (ours, a guardian gang). *(NC2045 p.40.)*

```world factions.factions.princesses_of_justice
{
	"name": "Princesses of Justice",
	"kind": "gang",
	"leader": "Adorable",
	"activities": [
		"protection",
		"vigilante_justice"
	],
	"territory": [
		"university_district"
	],
	"relations": {
		"police": "neutral"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Princess",
			"lieutenant": "Princess Lieutenant",
			"mini_boss": "Princess Enforcer"
		},
		"blocks": {
			"mook": [
				"princesses_of_justice_mook"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "e070c0",
		"accent": "ff3030",
		"pants": "6a4aa0",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"rescue"
	],
	"cite": "NC2045 p.40"
}
```

### Rat Kings (`rat_kings`)

Kids of Megabuilding H4 run wild: random crime and violence, then vanishing into the building's guts; neighbours (usually relatives) never talk. Outside H4 they barely exist. Poor-quality melee weapons or pistols. Identifiers: the logo painted on jackets. *(NC2045 p.40-41.)*

```world factions.factions.rat_kings
{
	"name": "Rat Kings",
	"kind": "gang",
	"leader": "Mario \"Corona\" Fernandez",
	"activities": [
		"partying",
		"theft",
		"mugging",
		"extortion",
		"random_violence"
	],
	"territory": [
		"santo_domingo"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Rat King",
			"lieutenant": "Rat King Lieutenant",
			"mini_boss": "Rat King Enforcer"
		},
		"blocks": {
			"mook": [
				"rat_kings_mook"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "4a4a3a",
		"accent": "ff3030",
		"pants": "2a2a24",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"rescue"
	],
	"cite": "NC2045 p.40-41"
}
```

### Reckoners (`reckoners`)

The one doomsday cult that lasted: they preach the Gibbering Eye's coming Harvest of Souls but leave its timing to the Eye, beat "donations" out of people, feed and house runaways, broadcast sermons on 96.1 Fever Dream and sell plushies. Less-than-lethal weapons, often implanted: the dead can't be recruited. Identifiers: the logo as a medallion. *(NC2045 p.41.)*

```world factions.factions.reckoners
{
	"name": "Reckoners",
	"kind": "gang",
	"leader": "The Beloved Gaping Maw of the Gibbering Eye",
	"activities": [
		"proselytizing",
		"targeted_violence"
	],
	"territory": [
		"hot_zone",
		"south_night_city",
		"the_glen"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Reckoner",
			"lieutenant": "Reckoner Lieutenant",
			"mini_boss": "Reckoner Enforcer"
		},
		"blocks": {
			"mook": [
				"reckoner_mook"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "3a2a4a",
		"accent": "ff3030",
		"pants": "2a2a2a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.41"
}
```

### Red Chrome Legion (`red_chrome_legion`)

Teens cosplaying Nazis who became neo-fascists, waiting for their "Great Caesar"; in fact a mid-sized boostergang losing an endless war with the Iron Sights, its turf halved and a violent leadership change behind it. Poor pistols and shotguns low down, assault weapons and explosives higher up. Identifiers: gas masks with glowing red lenses. Relations: at war with the Iron Sights (from the prose). *(NC2045 p.41.)*

```world factions.factions.red_chrome_legion
{
	"name": "Red Chrome Legion",
	"kind": "gang",
	"leader": "Vox and Populi",
	"activities": [
		"extortion",
		"mugging",
		"theft",
		"random_violence",
		"targeted_violence"
	],
	"territory": [
		"little_china",
		"old_japantown"
	],
	"relations": {
		"iron_sights": "hostile"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Legionnaire",
			"lieutenant": "Legionnaire Lieutenant",
			"mini_boss": "Legionnaire Enforcer"
		},
		"blocks": {
			"mook": [
				"boosterganger"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "2a2a2a",
		"accent": "ff1010",
		"pants": "1e1e1e",
		"vest": false,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"gang_hit",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.41"
}
```

### Scavvers (`scavvers`)

Less a gang than a category: small crews picking junkyards, combat-zone wrecks and the Hot Zone for metals, old tech and weapons, and dying at it. Some (Crawling Cobras) are independent, others (Diggers) work for Maelstrom. Salvaged, poor-quality weapons. *(NC2045 p.41-42.)*

```world factions.factions.scavvers
{
	"name": "Scavvers",
	"kind": "gang",
	"leader": "Various",
	"activities": [
		"theft",
		"scavving"
	],
	"territory": [
		"hot_zone"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Scavver",
			"lieutenant": "Scavver Lieutenant",
			"mini_boss": "Scavver Enforcer"
		},
		"blocks": {
			"mook": [
				"scavver_mook"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "5a4a3a",
		"accent": "ff3030",
		"pants": "3a3428",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"rescue"
	],
	"cite": "NC2045 p.41-42"
}
```

### The Shroomers (`shroomers`)

Mycologists and survivalists who formed an underground fungus-farming community after the 4th Corporate War, trading only through Mrs. Suzuki's bodegas; their young spend a Wander Year topside. Nobody knows the tunnels like them, and they're well armed for dark underground fights. Identifiers: special cyberoptics and tokens. Relations: keep to themselves (ours: neutral to the police). *(NC2045 p.42.)*

```world factions.factions.shroomers
{
	"name": "The Shroomers",
	"kind": "gang",
	"leader": "Pa Saddlefoot and May",
	"activities": [
		"survival",
		"farming"
	],
	"territory": [
		"old_combat_zone"
	],
	"relations": {
		"police": "neutral"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Shroomer",
			"lieutenant": "Shroomer Lieutenant",
			"mini_boss": "Shroomer Enforcer"
		},
		"blocks": {
			"mook": [
				"shroomer_scout_trader"
			],
			"lieutenant": [
				"hardened_reclaimer_chief_lightning",
				"hardened_reclaimer_chief_thunder",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_pyro",
				"hardened_outrider"
			]
		}
	},
	"look": {
		"jacket": "4a5a3a",
		"accent": "ff3030",
		"pants": "3a3a2a",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"gang_hit",
		"rescue"
	],
	"cite": "NC2045 p.42"
}
```

### The Sinful Adams (`sinful_adams`)

A goth gang (some sculpted after goth icons) that runs a shanty town for the homeless in an old graveyard, the Boneyard, with food, berry booze, a small school and a Halloween carnival. War leader Ophelia trains everyone: pistols, long blades, cyberweapons, martial arts. Identifiers: goth fashion. *(NC2045 p.42.)*

```world factions.factions.sinful_adams
{
	"name": "The Sinful Adams",
	"kind": "gang",
	"leader": "Gomez and Ophelia",
	"activities": [
		"survival",
		"mercenary_work",
		"sex_work"
	],
	"territory": [
		"south_night_city"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Adams",
			"lieutenant": "Adams Lieutenant",
			"mini_boss": "Adams Enforcer"
		},
		"blocks": {
			"mook": [
				"sinful_adams_mook"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "1e1a22",
		"accent": "ff3030",
		"pants": "2a2228",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"rescue"
	],
	"cite": "NC2045 p.42"
}
```

### Steel Vaqueros (`steel_vaqueros`)

A nomad pack outside the Seven Nations: caravans work the coast trading and labouring while family hold shops in Salinas and Night City. Varied weapons including well-kept shoulder arms; vehicles always in top shape. Identifiers: the logo embroidered on the back of the jacket. *(NC2045 p.42-43.)*

```world factions.factions.steel_vaqueros
{
	"name": "Steel Vaqueros",
	"kind": "gang",
	"leader": "Ximena Rose",
	"activities": [
		"smuggling",
		"survival"
	],
	"territory": [
		"new_westbrook",
		"rancho_coronado"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Vaquero",
			"lieutenant": "Vaquero Lieutenant",
			"mini_boss": "Vaquero Enforcer"
		},
		"blocks": {
			"mook": [
				"hardened_boosterganger"
			],
			"lieutenant": [
				"steel_vaqueros_driver"
			],
			"mini_boss": [
				"hardened_pyro",
				"hardened_outrider"
			]
		}
	},
	"look": {
		"jacket": "6a5a4a",
		"accent": "ff3030",
		"pants": "3a3a4a",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"gang_hit",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.42-43"
}
```

### The Street Queens (`street_queens`)

Heirs of the Black Queens, protecting New Westbrook's queer community, runaway kids above all; also into drugs and sex work on the Mainland club scene. Leader Maxime Raunch scorns Greta's and Chatelaine's as sellouts. Pistols, cyberweapons, small blades. Identifiers: queer iconography as jewellery. Relations: clashes with the Weng Fang Tong, Voodoo Boys and Piranhas (from the prose). *(NC2045 p.43.)*

```world factions.factions.street_queens
{
	"name": "The Street Queens",
	"kind": "gang",
	"leader": "Maxime Raunch",
	"activities": [
		"security",
		"sex_work",
		"drugs",
		"survival"
	],
	"territory": [
		"new_westbrook",
		"upper_marina"
	],
	"relations": {
		"weng_fang_tong": "hostile",
		"voodoo_boys": "hostile",
		"piranhas": "hostile"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Street Queen",
			"lieutenant": "Street Queen Lieutenant",
			"mini_boss": "Street Queen Enforcer"
		},
		"blocks": {
			"mook": [
				"street_queens_mook"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "aa3a8a",
		"accent": "ff3030",
		"pants": "2a2a3a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.43"
}
```

### The Toecutters (`toecutters`)

A Raffen Shiv pack from the badlands whose raids hit Night City's east side as deep as North Heywood and New Westbrook, infamous for cutting off (and eating) victims' toes. Rifles, shotguns, very sharp blades; heavily armed and armoured vehicles. Identifiers: nomad leathers spattered with blood patterns. *(NC2045 p.43.)*

```world factions.factions.toecutters
{
	"name": "The Toecutters",
	"kind": "gang",
	"leader": "Unknown",
	"activities": [
		"smuggling",
		"random_violence",
		"targeted_violence"
	],
	"territory": [
		"north_heywood",
		"outskirts"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Toecutter",
			"lieutenant": "Toecutter Lieutenant",
			"mini_boss": "Toecutter Enforcer"
		},
		"blocks": {
			"mook": [
				"toecutters_mook"
			],
			"lieutenant": [
				"hardened_reclaimer_chief_lightning",
				"hardened_reclaimer_chief_thunder",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_pyro",
				"hardened_outrider"
			]
		}
	},
	"look": {
		"jacket": "4a3424",
		"accent": "ff3030",
		"pants": "2e2420",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"gang_hit",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.43"
}
```

### Tombstone Preservers (`tombstone_preservers`)

Formed by the assassin Mister Rieper to guard the Columbarium and every site for the dead when the NCPD couldn't. Each is a Solo he trained personally in several martial arts and weapons. Identifiers: shaved heads, sober tailored suits. Relations: do the police's job at the cemeteries (ours: neutral to the police). *(NC2045 p.43-44.)*

```world factions.factions.tombstone_preservers
{
	"name": "Tombstone Preservers",
	"kind": "gang",
	"leader": "Mister Rieper",
	"activities": [
		"security"
	],
	"territory": [
		"charter_hill",
		"new_westbrook",
		"reclamation_zone",
		"south_night_city"
	],
	"relations": {
		"police": "neutral"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Tombstone Preserver",
			"lieutenant": "Preserver Elder",
			"mini_boss": "Rieper's Hand"
		},
		"blocks": {
			"mook": [
				"tomb_preserver_guard"
			],
			"lieutenant": [
				"hardened_reclaimer_chief_lightning",
				"hardened_reclaimer_chief_thunder",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_pyro",
				"hardened_outrider"
			]
		}
	},
	"look": {
		"jacket": "1e1e22",
		"accent": "ff3030",
		"pants": "1e1e22",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"assassination"
	],
	"cite": "NC2045 p.43-44"
}
```

### Tyger Claws (`tyger_claws`)

Once Arasaka's puppet gang, abandoned after the bomb and re-formed to protect Japanese Night City and enforce the Night City Co-Prosperity Sphere. They run crime in Kabuki and Old Japantown, the law there through the Kimen-Gumi, and clinics, a taxi firm and a dojo. Katanas (mono-katanas above all) and firearms of every kind. Identifiers: logo jewellery, patch or tattoo. Relations: the NCCS's enforcers and the Kimen-Gumi's parent (from the prose); the Kanzaki Family is eating their turf (from the prose). *(NC2045 p.44.)*

```world factions.factions.tyger_claws
{
	"name": "Tyger Claws",
	"kind": "gang",
	"leader": "Shinobu the Second",
	"activities": [
		"security",
		"extortion",
		"theft",
		"mercenary_work",
		"gambling",
		"random_violence",
		"racing",
		"sex_work"
	],
	"territory": [
		"kabuki",
		"new_westbrook",
		"old_japantown",
		"south_night_city",
		"watson_development"
	],
	"relations": {
		"kimen_gumi": "ally",
		"nccs": "ally",
		"kanzaki_family": "hostile"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Tyger Claw",
			"lieutenant": "Tyger Claws Boss",
			"mini_boss": "Tyger Claws Oyabun's Blade"
		},
		"blocks": {
			"mook": [
				"tyger_claws_mook"
			],
			"lieutenant": [
				"hardened_reclaimer_chief_lightning",
				"hardened_reclaimer_chief_thunder",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_pyro",
				"hardened_outrider"
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
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.44"
}
```

### The Undertow (`undertow`)

Hotheads "keeping Downtown real" against the Chamber of Commerce's takeover, badly: no plan, whatever target and weapon is at hand, often drunk on Smash. 1950s greaser style and Molotovs; cheap pistols against the Eurotrashers or for drive-bys on corporate building sites. Identifiers: 1950s greaser fashion. Relations: against the Chamber of Commerce and rivals of the Eurotrashers (from the prose). *(NC2045 p.44.)*

```world factions.factions.undertow
{
	"name": "The Undertow",
	"kind": "gang",
	"leader": "Johnny Rydell",
	"activities": [
		"random_violence",
		"targeted_violence"
	],
	"territory": [
		"downtown"
	],
	"relations": {
		"chamber_of_commerce": "hostile",
		"eurotrashers": "hostile"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Undertow",
			"lieutenant": "Undertow Lieutenant",
			"mini_boss": "Undertow Enforcer"
		},
		"blocks": {
			"mook": [
				"undertow_mook"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "1a1a1a",
		"accent": "ff3030",
		"pants": "2a3a5a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.44"
}
```

### Voodoo Boys (`voodoo_boys`)

Once the city's biggest drug importers, they fell back to Rancho Coronado in the war and now make and sell drugs and vice, losing ground to the Piranhas, the Tong and the casinos; they hang on through brutality and low prices. Mostly white kids playing Hollywood "voodoo". Machetes and chainsaws to send a message, otherwise pistols and a few shoulder arms. Identifiers: "voodoo" fashion, bones, feather implants, tattoos. Relations: out-competed by the Piranhas and Weng Fang Tong (the prose names business rivalry; ours: neutral). *(NC2045 p.44-45.)*

```world factions.factions.voodoo_boys
{
	"name": "Voodoo Boys",
	"kind": "gang",
	"leader": "Baron D",
	"activities": [
		"extortion",
		"drugs",
		"gambling",
		"sex_work"
	],
	"territory": [
		"pacifica_playground",
		"rancho_coronado",
		"the_glen",
		"university_district"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Voodoo Boy",
			"lieutenant": "Voodoo Boy Lieutenant",
			"mini_boss": "Voodoo Boy Enforcer"
		},
		"blocks": {
			"mook": [
				"voodoo_boys_mook"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "3a2a1e",
		"accent": "ff3030",
		"pants": "2a221e",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.44-45"
}
```

### Wild Things (`wild_things`)

Drug-fuelled boosters reborn as a bloodsport club: they unleash their inner monster in gladiatorial fights at Redline and hire out now and then as muscle. Their code allows only weapons that are part or an extension of the body (martial arts, cyberweapons, melee), never guns. Identifiers: the logo scarred or branded on the chest. *(NC2045 p.45.)*

```world factions.factions.wild_things
{
	"name": "Wild Things",
	"kind": "gang",
	"leader": "Jenny Nails",
	"activities": [
		"bloodsport",
		"mercenary_work",
		"sex_work"
	],
	"territory": [
		"watson_development"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Wild Thing",
			"lieutenant": "Wild Thing Lieutenant",
			"mini_boss": "Wild Thing Enforcer"
		},
		"blocks": {
			"mook": [
				"hardened_boosterganger"
			],
			"lieutenant": [
				"wild_things_gladiator"
			],
			"mini_boss": [
				"hardened_pyro",
				"hardened_outrider"
			]
		}
	},
	"look": {
		"jacket": "6a2a1e",
		"accent": "ff3030",
		"pants": "2a1e1a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.45"
}
```

### Willows (`willows`)

A support group for women veterans that Ingénue, last of the Willow Sisterhood (a posergang of beauties-turned-bodyguards wiped out on a Zetatech job in the war), runs at the From the Ashes clinic. Members include Kissy, Roxxi, Rogue and Jenny Jett; rumour says they gear up together when one of them has a problem. Identifiers: a challenge coin with the logo. Relations: neutral to the police (ours). *(NC2045 p.45.)*

```world factions.factions.willows
{
	"name": "Willows",
	"kind": "gang",
	"leader": "Ingénue",
	"activities": [
		"therapy",
		"mutual_aid"
	],
	"territory": [
		"old_combat_zone"
	],
	"relations": {
		"police": "neutral"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Willow",
			"lieutenant": "Willow Lieutenant",
			"mini_boss": "Willow Enforcer"
		},
		"blocks": {
			"mook": [
				"hardened_bodyguard"
			],
			"lieutenant": [
				"hardened_netrunner_anti_personnel",
				"hardened_netrunner_anti_program"
			],
			"mini_boss": [
				"hardened_sniper",
				"hardened_executive_protection"
			]
		}
	},
	"look": {
		"jacket": "4a5a4a",
		"accent": "ff3030",
		"pants": "2a2a2a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"rescue"
	],
	"cite": "NC2045 p.45"
}
```

### Yellow Brick Road Gang (`yellow_brick_road_gang`)

An Oz posergang made dangerous by Dorothy, a genius drug engineer: cheapest source of the new drug Emerald City and custom-cooked designer drugs for rich clients. Armed by character: Lions and Totos with cyberweapons, Woodsmen with axes, Scarecrows with pistols. Identifiers: Wizard of Oz sculpts and costumes. Hangouts unknown. *(NC2045 p.46.)*

```world factions.factions.yellow_brick_road_gang
{
	"name": "Yellow Brick Road Gang",
	"kind": "gang",
	"leader": "Dorothy",
	"activities": [
		"drugs"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Yellow Bricker",
			"lieutenant": "Yellow Bricker Lieutenant",
			"mini_boss": "Yellow Bricker Enforcer"
		},
		"blocks": {
			"mook": [
				"boosterganger"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "d8c020",
		"accent": "ff3030",
		"pants": "3a6a3a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"assassination",
		"rescue"
	],
	"cite": "NC2045 p.46"
}
```

### The Zoners (`zoners`)

Not a gang, they'd say: a South Night City movement protesting that rebuilding money stops at the Glen. Refused permits, they march anyway, and NCPD's "restoring order" often turns it violent; arms vary person to person. Identifiers: none. Relations: clash with the NCPD (from the prose). *(NC2045 p.46.)*

```world factions.factions.zoners
{
	"name": "The Zoners",
	"kind": "gang",
	"leader": "Tearjerker & FreeFall",
	"activities": [
		"community_organization",
		"mutual_aid"
	],
	"territory": [
		"south_night_city"
	],
	"relations": {
		"ncpd": "hostile"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Zoner",
			"lieutenant": "Zoner Lieutenant",
			"mini_boss": "Zoner Enforcer"
		},
		"blocks": {
			"mook": [
				"zoner_mook"
			],
			"lieutenant": [
				"reclaimer_chief",
				"netrunner"
			],
			"mini_boss": [
				"pyro",
				"outrider"
			]
		}
	},
	"look": {
		"jacket": "6a6a5a",
		"accent": "ff3030",
		"pants": "3a3a3a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"gang_hit",
		"rescue"
	],
	"cite": "NC2045 p.46"
}
```

### The Faded (`faded`)

The Old Combat Zone's older generation, led by Lasky, who resettled the wrecked San Morro Industrial Zone and fused it into the Warren, a megabuilding fortress they police themselves. They resent the younger ERI and their brawls are growing. Not in the book's gang list: a district faction. Relations: at odds with ERI (from the prose). *(NC2045 p.167-173.)*

```world factions.factions.faded
{
	"name": "The Faded",
	"kind": "gang",
	"leader": "Lasky",
	"activities": [
		"security",
		"survival"
	],
	"territory": [
		"old_combat_zone"
	],
	"relations": {
		"eri": "hostile"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Faded Guard",
			"lieutenant": "Faded Old Hand",
			"mini_boss": "Lasky's Second"
		},
		"blocks": {
			"mook": [
				"faded_guard"
			],
			"lieutenant": [
				"hardened_reclaimer_chief_lightning",
				"hardened_reclaimer_chief_thunder",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_pyro",
				"hardened_outrider"
			]
		}
	},
	"look": {
		"jacket": "5a5a4a",
		"accent": "ff3030",
		"pants": "3a3a34",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"gang_hit",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.167-173"
}
```

### Criminal organisations (NC2045 p.46-49)

The traditional syndicates; their logos were made for the guide and they don't tag territory (p.46).

### The Consortium (`consortium`)

Night City's Bratva. A small share of most rackets but big in smuggling and piracy thanks to Vyriy nomad ships that don't need Thelas routes; seemingly allied with Zhirafa. It press-gangs civilian specialists for jobs: threats, then kidnapped family, then implanted bombs. Enforcers carry heavy Neo-Soviet melee and guns, nearly always with muscle and bone lace. Identifiers: a whole language of tattoos. Relations: Zhirafa (from the prose). *(NC2045 p.46-47.)*

```world factions.factions.consortium
{
	"name": "The Consortium",
	"kind": "criminal",
	"leader": "Valya",
	"activities": [
		"gambling",
		"sex_work",
		"extortion",
		"smuggling",
		"piracy",
		"blackmail",
		"theft"
	],
	"territory": [
		"heywood_industrial_zone",
		"port_of_night_city"
	],
	"relations": {
		"zhirafa": "ally"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Consortium Enforcer",
			"lieutenant": "Consortium Lieutenant",
			"mini_boss": "Consortium Underboss"
		},
		"blocks": {
			"mook": [
				"consortium_mook"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_executive_protection",
				"hardened_sniper"
			]
		}
	},
	"look": {
		"jacket": "2a2a30",
		"accent": "ff3030",
		"pants": "1e1e24",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"data_theft",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.46-47"
}
```

### Eastern Tigers Triad (`eastern_tigers_triad`)

The newest syndicate: Lu Zho hired edgerunners to steal dozens of corporate designs and counterfeits them for markets up the coast. Few friends, and contempt for David Ling Po and the Tong as decrepit and westernised; they're carving into Tong turf. High rate-of-fire weapons, common martial arts. Identifiers: numbers subtly embroidered into clothes. Relations: hostile to the Weng Fang Tong and its Gold Dragons (from the prose). *(NC2045 p.47.)*

```world factions.factions.eastern_tigers_triad
{
	"name": "Eastern Tigers Triad",
	"kind": "criminal",
	"leader": "Lu Zho",
	"activities": [
		"smuggling",
		"drugs",
		"counterfeiting",
		"piracy",
		"theft",
		"extortion",
		"sex_work"
	],
	"territory": [
		"downtown"
	],
	"relations": {
		"weng_fang_tong": "hostile",
		"gold_dragons": "hostile",
		"lcra": "hostile"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Triad Enforcer",
			"lieutenant": "Triad Lieutenant",
			"mini_boss": "Triad Underboss"
		},
		"blocks": {
			"mook": [
				"triad_enforcer"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_executive_protection",
				"hardened_sniper"
			]
		}
	},
	"look": {
		"jacket": "2a1e1e",
		"accent": "ff3030",
		"pants": "1e1a1a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"data_theft",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.47"
}
```

### El Norte Cartel (`el_norte_cartel`)

A Mexican cartel that got in once bribable corporate shipping opened the Panama route; it runs small pilot schemes (drugs, smuggling, extortion, identity theft, counterfeiting). Its big bet was financing Theresa Valentino's win as Santo Domingo's City Manager, and its local people now seem more loyal to her than to home. Heavier autofire weapons, reflex and accuracy implants. Identifiers: an orange bandanna, tattoos of pistols and knives. *(NC2045 p.47.)*

```world factions.factions.el_norte_cartel
{
	"name": "El Norte Cartel",
	"kind": "criminal",
	"leader": "Rubén Meza",
	"activities": [
		"drugs",
		"smuggling",
		"extortion",
		"theft",
		"identity_theft",
		"counterfeiting"
	],
	"territory": [
		"santo_domingo"
	],
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Cartel Enforcer",
			"lieutenant": "Cartel Lieutenant",
			"mini_boss": "Cartel Underboss"
		},
		"blocks": {
			"mook": [
				"cartel_enforcer"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_executive_protection",
				"hardened_sniper"
			]
		}
	},
	"look": {
		"jacket": "3a3024",
		"accent": "ff7a1a",
		"pants": "2a2a2a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"data_theft",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.47"
}
```

### Kanzaki Family (`kanzaki_family`)

What's left of the Yakuza: shut out of Japantown and Kabuki by the NCCS-backed Tyger Claws, Shin and Yasume Kanzaki bet everything on Future BuildWorks in Watson, which grew through intimidation and bribes into a major builder (Megabuilding H11). Now they're nibbling Tyger Claws turf. Brawlers and martial artists with heavy melee weapons, concealable guns and cyberware. Identifiers: elaborate tattoos, business fashion. Relations: rivals of the Tyger Claws (from the prose). *(NC2045 p.47-48.)*

```world factions.factions.kanzaki_family
{
	"name": "Kanzaki Family",
	"kind": "criminal",
	"leader": "Shin Kanzaki",
	"activities": [
		"construction",
		"embezzlement",
		"extortion",
		"theft",
		"smuggling"
	],
	"territory": [
		"south_night_city",
		"watson_development"
	],
	"relations": {
		"tyger_claws": "hostile",
		"kimen_gumi": "hostile"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Kanzaki Enforcer",
			"lieutenant": "Kanzaki Lieutenant",
			"mini_boss": "Kanzaki Underboss"
		},
		"blocks": {
			"mook": [
				"kanzaki_enforcer"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_executive_protection",
				"hardened_sniper"
			]
		}
	},
	"look": {
		"jacket": "1e1e26",
		"accent": "ff3030",
		"pants": "1e1e26",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.47-48"
}
```

### Skiv Family (`skiv_family`)

A mafia family that Lynn Skiv rebuilt on 20th-century mob lines: own the docks, the labour and construction, go legitimate. She revived HF&S Construction, founded SK Securities and got several corporations behind turning the Heywood Docks into a nomad-free rival to the Port. Street brawlers with simple melee and heavy pistols, assault rifles higher up. Identifiers: secret handshakes and code phrases. Relations: SK Securities is theirs (from the prose). *(NC2045 p.48.)*

```world factions.factions.skiv_family
{
	"name": "Skiv Family",
	"kind": "criminal",
	"leader": "Lynn Skiv",
	"activities": [
		"construction",
		"embezzlement",
		"extortion",
		"theft",
		"smuggling"
	],
	"territory": [
		"downtown",
		"heywood_docks",
		"upper_marina"
	],
	"relations": {
		"sk_securities": "ally"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Skiv Enforcer",
			"lieutenant": "Skiv Lieutenant",
			"mini_boss": "Skiv Underboss"
		},
		"blocks": {
			"mook": [
				"skiv_family_enforcer"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_executive_protection",
				"hardened_sniper"
			]
		}
	},
	"look": {
		"jacket": "2a2a2e",
		"accent": "ff3030",
		"pants": "1e1e22",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"data_theft",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.48"
}
```

### Weng Fang Tong (`weng_fang_tong`)

On the surface the most powerful syndicate: David Ling Po runs Little China, an import/export business, the Gold Dragons and the Tong, and much of the city's sex work and gambling; many powerful people owe him a favour. But he's old and distracted, the Triad is carving up his turf, and Tyger Claws, Maelstrom and DeadWoods work his patch unpunished. Quirky enforcers: body chrome, arc throwers and tasers, acid and drug weapons. Identifiers: secret hand signs. Relations: the Gold Dragons and LCRA (from the prose); the Triad (hostile, from the prose). *(NC2045 p.48-49.)*

```world factions.factions.weng_fang_tong
{
	"name": "Weng Fang Tong",
	"kind": "criminal",
	"leader": "David Ling Po",
	"activities": [
		"sex_work",
		"smuggling",
		"extortion",
		"theft",
		"gambling",
		"embezzlement"
	],
	"territory": [
		"little_china",
		"rancho_coronado"
	],
	"relations": {
		"gold_dragons": "ally",
		"lcra": "ally",
		"eastern_tigers_triad": "hostile"
	},
	"doctrine": "gang_den",
	"roster": {
		"ranks": {
			"mook": "Tong Enforcer",
			"lieutenant": "Tong Lieutenant",
			"mini_boss": "Tong Underboss"
		},
		"blocks": {
			"mook": [
				"tong_enforcer"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_netrunner_anti_personnel"
			],
			"mini_boss": [
				"hardened_executive_protection",
				"hardened_sniper"
			]
		}
	},
	"look": {
		"jacket": "3a1e1e",
		"accent": "ff3030",
		"pants": "1e1a1a",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"data_theft",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.48-49"
}
```

### Security providers (NC2045 p.49-52)

Deputized district police and private security firms ("in addition to the NCPD", p.49). Deputized providers are kind `police`; bodyguard and corporate firms are `corp`. 6th Street and the Gold Dragons are listed with the gangs, Militech with the corporations, the NCPD and MAX-TAC with the services below.

### Aldecaldo Peacekeepers (`aldecaldo_peacekeepers`)

Santo Domingo's deputized police, almost all Aldecaldo nomads. They talk before they draw, but always carry nomad-made weapons and ride tricked-out patrol bikes. Relations: the Aldecaldos' own (from the prose). *(NC2045 p.49.)*

```world factions.factions.aldecaldo_peacekeepers
{
	"name": "Aldecaldo Peacekeepers",
	"kind": "police",
	"leader": "Macario Custodio",
	"activities": [
		"security"
	],
	"territory": [
		"heywood_industrial_zone",
		"santo_domingo"
	],
	"relations": {
		"aldecaldos": "ally"
	},
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Peacekeeper Guard",
			"lieutenant": "Peacekeeper Sergeant",
			"mini_boss": "Peacekeeper Lieutenant"
		},
		"blocks": {
			"mook": [
				"aldecaldo_peacekeeper"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_security_officer_siege"
			],
			"mini_boss": [
				"hardened_sniper"
			]
		}
	},
	"look": {
		"jacket": "6a4a2a",
		"accent": "2a6aff",
		"pants": "3a3028",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.49"
}
```

### Corporate Security (`corporate_security`)

The guards of any corporation with a City Council seat, with full police powers on company property; armed by post, assignment and the budget. Generic: use the corp's own faction where it has one. *(NC2045 p.49.)*

```world factions.factions.corporate_security
{
	"name": "Corporate Security",
	"kind": "corp",
	"leader": "Various",
	"activities": [
		"security"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Corporate Security",
			"lieutenant": "Security Sergeant",
			"mini_boss": "Security Chief"
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
		"jacket": "4a4e56",
		"accent": "ff3030",
		"pants": "34383e",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"sabotage"
	],
	"cite": "NC2045 p.49"
}
```

### Danger Gal (`danger_gal`)

A cute-branded investigation and security neocorp with a Council seat with its own cartoon (Puma Squad): bodyguards for the elite and event and venue security, Club Atlantis above all. Always properly armed and armoured; Sanroo Hello Cutie sculpts are common, the weapons less pink. *(NC2045 p.21, p.49.)*

```world factions.factions.danger_gal
{
	"name": "Danger Gal",
	"kind": "corp",
	"leader": "Michiko Sanderson",
	"activities": [
		"investigation",
		"security",
		"bodyguarding"
	],
	"territory": [
		"little_europe"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Danger Gal Security",
			"lieutenant": "Danger Gal Sergeant",
			"mini_boss": "Danger Gal Enforcer"
		},
		"blocks": {
			"mook": [
				"danger_gal_detective"
			],
			"lieutenant": [
				"danger_gal_guard"
			],
			"mini_boss": [
				"hardened_executive_protection"
			]
		}
	},
	"look": {
		"jacket": "e870a0",
		"accent": "ff3030",
		"pants": "3a2a3a",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"sabotage"
	],
	"cite": "NC2045 p.21, p.49"
}
```

### Edgerunners Inc (ERI) (`eri`)

The Old Combat Zone's deputized police: City Manager Brick Coleman's followers, veteran edgerunners and young recruits drilled in small-squad tactics. Tough survivors who bring their own weapons and chrome. Relations: friction with the Faded (from the district prose). *(NC2045 p.49.)*

```world factions.factions.eri
{
	"name": "Edgerunners Inc (ERI)",
	"kind": "police",
	"leader": "Brick Coleman",
	"activities": [
		"security"
	],
	"territory": [
		"old_combat_zone"
	],
	"relations": {
		"faded": "hostile"
	},
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "ERI Guard",
			"lieutenant": "ERI Sergeant",
			"mini_boss": "ERI Lieutenant"
		},
		"blocks": {
			"mook": [
				"eri_guard"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_security_officer_siege"
			],
			"mini_boss": [
				"hardened_sniper"
			]
		}
	},
	"look": {
		"jacket": "4a3a2a",
		"accent": "2a6aff",
		"pants": "2e2a24",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.49"
}
```

### Kimen-Gumi (`kimen_gumi`)

Kabuki and Old Japantown's deputized police, in colourful oni masks on duty. Every one is a Tyger Claw, so Claws crime goes unseen. Swords (mono-katanas higher up) and firearms; most know Karate and Judo. Relations: the Tyger Claws' (from the prose). *(NC2045 p.50.)*

```world factions.factions.kimen_gumi
{
	"name": "Kimen-Gumi",
	"kind": "police",
	"leader": "Burai",
	"activities": [
		"security"
	],
	"territory": [
		"kabuki",
		"old_japantown"
	],
	"relations": {
		"tyger_claws": "ally",
		"nccs": "ally"
	},
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Kimen-Gumi Rookie",
			"lieutenant": "Kimen-Gumi Sergeant",
			"mini_boss": "Kimen-Gumi Swordmaster"
		},
		"blocks": {
			"mook": [
				"kimen_gumi_rookie"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_security_officer_siege"
			],
			"mini_boss": [
				"hardened_sniper"
			]
		}
	},
	"look": {
		"jacket": "2a1e2a",
		"accent": "ff3a6a",
		"pants": "1e1a1e",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"rescue"
	],
	"cite": "NC2045 p.50"
}
```

### Lazarus (`lazarus`)

Reckoned the world's best PMC: the Exec Zone's deputized police, and contracted for the Consulate Causeway, the World Stock Exchange, Network 54 Plaza and Trauma Team Tower. No mooks, except recruits kept out of the field; martial arts, military loadouts, combat chrome and excellent shoulder arms. *(NC2045 p.50.)*

```world factions.factions.lazarus
{
	"name": "Lazarus",
	"kind": "police",
	"leader": "Colonel Viola Basset",
	"activities": [
		"security",
		"mercenary_work"
	],
	"territory": [
		"executive_zone",
		"south_night_city",
		"the_glen"
	],
	"doctrine": "corp_military",
	"roster": {
		"ranks": {
			"mook": "Lazarus Rookie",
			"lieutenant": "Lazarus Operator",
			"mini_boss": "Lazarus Team Leader"
		},
		"blocks": {
			"mook": [
				"lazarus_rookie"
			],
			"lieutenant": [
				"lazarus_guard",
				"lazarus_sniper"
			],
			"mini_boss": [
				"hardened_militech_veteran",
				"hardened_sniper"
			]
		}
	},
	"look": {
		"jacket": "2a2e34",
		"accent": "2a6aff",
		"pants": "1e2228",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.50"
}
```

### Los Perros Guardianes (`los_perros_guardianes`)

The Reclamation Zone's deputized police: every adult is trained as an auxiliary, a small volunteer core does the daily work, and chromed K-9 units fill out the numbers. Volunteers bring their own blunt melee weapons and pistols, often in nomad leathers. Relations: serve the Dorado clan's district (ours, from the district prose). *(NC2045 p.50.)*

```world factions.factions.los_perros_guardianes
{
	"name": "Los Perros Guardianes",
	"kind": "police",
	"leader": "Chapel \"Titan\" Suluku",
	"activities": [
		"security"
	],
	"territory": [
		"reclamation_zone"
	],
	"relations": {
		"dorado_family": "ally"
	},
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Perro Guardián Guard",
			"lieutenant": "Perro Guardián Sergeant",
			"mini_boss": "Perro Guardián Lieutenant"
		},
		"blocks": {
			"mook": [
				"perro_guardian",
				"perro_guardian_canine"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_security_officer_siege"
			],
			"mini_boss": [
				"hardened_sniper"
			]
		}
	},
	"look": {
		"jacket": "5a4a34",
		"accent": "2a6aff",
		"pants": "3a3028",
		"vest": false,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"rescue"
	],
	"cite": "NC2045 p.50"
}
```

### McCain Security (`mccain_security`)

A small security company owned by Raven Microcybernetics that guards its Night City assets: better trained and armed than most corp guards but with standard-quality weapons; shotguns wait at each station, not on patrol. Relations: Raven Microcybernetics' own (from the prose). *(NC2045 p.50.)*

```world factions.factions.mccain_security
{
	"name": "McCain Security",
	"kind": "corp",
	"leader": "Bruce McCain",
	"activities": [
		"security"
	],
	"territory": [
		"heywood_industrial_zone",
		"the_glen"
	],
	"relations": {
		"raven_microcybernetics": "ally"
	},
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "McCain Security",
			"lieutenant": "McCain Sergeant",
			"mini_boss": "McCain Enforcer"
		},
		"blocks": {
			"mook": [
				"hardened_security_operative"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_security_officer_siege"
			],
			"mini_boss": [
				"hardened_executive_protection"
			]
		}
	},
	"look": {
		"jacket": "3a3e48",
		"accent": "ff3030",
		"pants": "2a2e36",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"sabotage"
	],
	"cite": "NC2045 p.50"
}
```

### NCU Campus Security (`ncu_campus_security`)

The University District's deputized police, the "Maxes": light armour and less-lethal sidearms on patrol, heavier arms in armouries around campus. *(NC2045 p.51.)*

```world factions.factions.ncu_campus_security
{
	"name": "NCU Campus Security",
	"kind": "police",
	"leader": "Renee Dorn",
	"activities": [
		"security"
	],
	"territory": [
		"university_district"
	],
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "NCU Guard",
			"lieutenant": "NCU Sergeant",
			"mini_boss": "NCU Lieutenant"
		},
		"blocks": {
			"mook": [
				"ncu_guard_max"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_security_officer_siege"
			],
			"mini_boss": [
				"hardened_sniper"
			]
		}
	},
	"look": {
		"jacket": "2a3a5a",
		"accent": "2a6aff",
		"pants": "2a2e3a",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.51"
}
```

### Netwatch (`netwatch`)

The global police of the NET, authorised by NorCal to investigate crimes touching the Old Net, the CitiNet and AIs; solo agents or small task forces with full police powers, whose suspects rarely survive to reach a cell. Heavy pistols and light armour, shotguns and rifles on hand, sensory chrome; many are Netrunners with stocked decks. *(NC2045 p.51.)*

```world factions.factions.netwatch
{
	"name": "Netwatch",
	"kind": "police",
	"leader": "Samuel Twist",
	"activities": [
		"investigation",
		"netrunning"
	],
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Netwatch Agent",
			"lieutenant": "Netwatch Investigator",
			"mini_boss": "Netwatch Task Lead"
		},
		"blocks": {
			"mook": [
				"hardened_security_operative"
			],
			"lieutenant": [
				"netwatch_investigator",
				"hardened_netrunner_anti_program"
			],
			"mini_boss": [
				"hardened_netrunner_anti_personnel"
			]
		}
	},
	"look": {
		"jacket": "1e2a3a",
		"accent": "2a6aff",
		"pants": "1a1e26",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft"
	],
	"cite": "NC2045 p.51"
}
```

### NorCal Marshal Service (`norcal_marshal_service`)

State law: the Highway Patrol watches the highways, Rangers under the State Executioner hunt fugitives, Inspectors take high-profile cases. Alone or in pairs, armed as if no backup is coming (heavy pistols, assault rifles, grenade launchers), heavier armour and nomad-grade motorcycles. *(NC2045 p.51.)*

```world factions.factions.norcal_marshal_service
{
	"name": "NorCal Marshal Service",
	"kind": "police",
	"leader": "John Jones",
	"activities": [
		"law_enforcement",
		"fugitive_hunting"
	],
	"territory": [
		"outskirts"
	],
	"doctrine": "corp_military",
	"roster": {
		"ranks": {
			"mook": "Highway Patrol Officer",
			"lieutenant": "Marshal",
			"mini_boss": "Ranger"
		},
		"blocks": {
			"mook": [
				"hardened_security_operative"
			],
			"lieutenant": [
				"highway_patrol_officer"
			],
			"mini_boss": [
				"ranger"
			]
		}
	},
	"look": {
		"jacket": "4a3e2a",
		"accent": "2a6aff",
		"pants": "2e2a24",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"rescue"
	],
	"cite": "NC2045 p.51"
}
```

### NorCal COG Military Police (`norcal_cog_military_police`)

The Estero Bay COG MPs: sole jurisdiction over the NorCal Military Base and its people (even those arrested in the city). Extremely well trained in hand-to-hand and armed for war every day. No printed block: Hardened series stand-ins. *(NC2045 p.51.)*

```world factions.factions.norcal_cog_military_police
{
	"name": "NorCal COG Military Police",
	"kind": "police",
	"leader": "Captain Jennifer Quick",
	"activities": [
		"military_police"
	],
	"territory": [
		"norcal_military_base"
	],
	"relations": {
		"estero_bay_military_cog": "ally"
	},
	"doctrine": "corp_military",
	"roster": {
		"ranks": {
			"mook": "MP",
			"lieutenant": "MP Sergeant",
			"mini_boss": "MP Lieutenant"
		},
		"blocks": {
			"mook": [
				"hardened_security_operative"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_security_officer_siege"
			],
			"mini_boss": [
				"hardened_militech_veteran"
			]
		}
	},
	"look": {
		"jacket": "4a4e3a",
		"accent": "2a6aff",
		"pants": "3a3e2e",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"rescue"
	],
	"cite": "NC2045 p.51"
}
```

### Protective Lightning (`protective_lightning`)

Playland by the Sea's on-site security: more drones (SMGs, dart guns, the odd grenade launcher) than people, and the people are rent-a-cops with pistols and light armour. *(NC2045 p.51-52.)*

```world factions.factions.protective_lightning
{
	"name": "Protective Lightning",
	"kind": "corp",
	"leader": "Andy Mayberry",
	"activities": [
		"security"
	],
	"territory": [
		"playland"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Lightning Guard",
			"lieutenant": "Lightning Supervisor",
			"mini_boss": "Lightning Chief"
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
		"jacket": "e0c020",
		"accent": "ff3030",
		"pants": "3a3a3a",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"sabotage"
	],
	"cite": "NC2045 p.51-52"
}
```

### San Luis Obispo County Sheriff (`san_luis_obispo_county_sheriff`)

Policing for the Outskirts, underfunded and staffed mostly by bullies who love guns, badges and petty power. Pistols, shotguns, light armorjack. *(NC2045 p.52.)*

```world factions.factions.san_luis_obispo_county_sheriff
{
	"name": "San Luis Obispo County Sheriff",
	"kind": "police",
	"leader": "Felicia Dixon",
	"activities": [
		"law_enforcement"
	],
	"territory": [
		"outskirts"
	],
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Sheriff's Deputy",
			"lieutenant": "Sheriff's Sergeant",
			"mini_boss": "Undersheriff"
		},
		"blocks": {
			"mook": [
				"sheriffs_deputy"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_security_officer_siege"
			],
			"mini_boss": [
				"hardened_sniper"
			]
		}
	},
	"look": {
		"jacket": "6a5a3a",
		"accent": "2a6aff",
		"pants": "3a3428",
		"vest": true,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"rescue"
	],
	"cite": "NC2045 p.52"
}
```

### Scythe Security (`scythe_security`)

South Night City's new deputized police, a small firm out of its depth and hiring fast: salvaged, patched light armour and GunMart shotguns. *(NC2045 p.52.)*

```world factions.factions.scythe_security
{
	"name": "Scythe Security",
	"kind": "police",
	"leader": "Andrew Scythe III",
	"activities": [
		"security"
	],
	"territory": [
		"south_night_city"
	],
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Scythe Guard",
			"lieutenant": "Scythe Sergeant",
			"mini_boss": "Scythe Lieutenant"
		},
		"blocks": {
			"mook": [
				"scythe_security_guard"
			],
			"lieutenant": [
				"security_officer"
			]
		}
	},
	"look": {
		"jacket": "4a4a40",
		"accent": "2a6aff",
		"pants": "34342e",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"rescue"
	],
	"cite": "NC2045 p.52"
}
```

### SK Securities (`sk_securities`)

The Heywood Docks' deputized police, run by the Skiv Family; most officers are known criminals. Adept brawlers with heavy pistols and shotguns, light armour some upgrade themselves. Relations: the Skiv Family's (from the prose). *(NC2045 p.52.)*

```world factions.factions.sk_securities
{
	"name": "SK Securities",
	"kind": "police",
	"leader": "Andrea Lee",
	"activities": [
		"security"
	],
	"territory": [
		"heywood_docks"
	],
	"relations": {
		"skiv_family": "ally"
	},
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "SK Guard",
			"lieutenant": "SK Sergeant",
			"mini_boss": "SK Lieutenant"
		},
		"blocks": {
			"mook": [
				"sk_securities_guard"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_security_officer_siege"
			],
			"mini_boss": [
				"hardened_sniper"
			]
		}
	},
	"look": {
		"jacket": "3a3a44",
		"accent": "2a6aff",
		"pants": "2a2a30",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.52"
}
```

### Thelas Marines (`thelas_marines`)

The Port of Night City's deputized police, all Thelas nomads trained for naval work: shotguns, backup pistols, light armour that won't drown them, and top-notch patrol boats. *(NC2045 p.52.)*

```world factions.factions.thelas_marines
{
	"name": "Thelas Marines",
	"kind": "police",
	"leader": "Calypso",
	"activities": [
		"security",
		"naval_patrol"
	],
	"territory": [
		"port_of_night_city"
	],
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Thelas Marine",
			"lieutenant": "Thelas Petty Officer",
			"mini_boss": "Thelas Captain"
		},
		"blocks": {
			"mook": [
				"hardened_security_operative"
			],
			"lieutenant": [
				"thelas_marine",
				"thelas_pilot"
			],
			"mini_boss": [
				"hardened_sniper"
			]
		}
	},
	"look": {
		"jacket": "2a4a5a",
		"accent": "2a6aff",
		"pants": "1e2a34",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.52"
}
```

### Ward Security (`ward_security`)

Bodyguards for the rich and famous, where visible armour, cyberweapons and guns are gauche: weapons are the bodyguard's choice, discretion first. *(NC2045 p.52.)*

```world factions.factions.ward_security
{
	"name": "Ward Security",
	"kind": "corp",
	"leader": "Tim Ward",
	"activities": [
		"bodyguarding"
	],
	"territory": [
		"charter_hill"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Ward Associate",
			"lieutenant": "Ward Bodyguard",
			"mini_boss": "Ward Principal Guard"
		},
		"blocks": {
			"mook": [
				"hardened_security_operative"
			],
			"lieutenant": [
				"ward_security_bodyguard"
			],
			"mini_boss": [
				"hardened_executive_protection"
			]
		}
	},
	"look": {
		"jacket": "1e1e22",
		"accent": "ff3030",
		"pants": "1e1e22",
		"vest": false,
		"helmet": false,
		"gloves": false
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"sabotage"
	],
	"cite": "NC2045 p.52"
}
```

### Whitewater Security (`whitewater_security`)

Downtown's deputized police, a small, well-funded firm led by former merchant-marine security officers: a show of force with visible sidearms and shoulder arms, lighter armour from their days at sea. Relations: housed in the Chamber of Commerce's New Libertine Tower (ours: allied). *(NC2045 p.52.)*

```world factions.factions.whitewater_security
{
	"name": "Whitewater Security",
	"kind": "police",
	"leader": "Helene Riese",
	"activities": [
		"security"
	],
	"territory": [
		"downtown"
	],
	"relations": {
		"chamber_of_commerce": "ally"
	},
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Whitewater Guard",
			"lieutenant": "Whitewater Sergeant",
			"mini_boss": "Whitewater Lieutenant"
		},
		"blocks": {
			"mook": [
				"whitewater_guard"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_security_officer_siege"
			],
			"mini_boss": [
				"hardened_sniper"
			]
		}
	},
	"look": {
		"jacket": "dfe6ea",
		"accent": "2a6aff",
		"pants": "2a3448",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"rescue"
	],
	"cite": "NC2045 p.52"
}
```

### Corporations and businesses

Megacorps with City Council seats (NC2045 p.21-22) and the companies that own or guard places in the district chapters.

### Arasaka (`arasaka`)

The Japanese security megacorp whose Night City HQ the 2023 nuke destroyed; it pulled out of the city afterwards, leaving its puppet gang (the Tygers Claw) behind. Absent in 2045: no places, no gigs; kept for history and future content. *(NC2045 p.12-13, p.44.)*

```world factions.factions.arasaka
{
	"name": "Arasaka",
	"kind": "corp",
	"activities": [
		"security",
		"weapons"
	],
	"doctrine": "corp_military",
	"roster": {
		"ranks": {
			"mook": "Arasaka Security",
			"lieutenant": "Arasaka Sergeant",
			"mini_boss": "Arasaka Enforcer"
		},
		"blocks": {
			"mook": [
				"hardened_security_operative"
			],
			"lieutenant": [
				"hardened_security_officer_raid"
			],
			"mini_boss": [
				"hardened_arasaka_assassin",
				"hardened_executive_protection"
			]
		}
	},
	"look": {
		"jacket": "2a2a2e",
		"accent": "ff3030",
		"pants": "1e1e22",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"cite": "NC2045 p.12-13, p.44"
}
```

### Militech (`militech`)

The war-and-security megacorp, nationalised by the US but highly independent, with a Council seat. Its security service is deputized police for Charter Hill and Pacifica Playground and guards WorldSat's offices and Playland's Segotari Discovery Zone. Militech weapons, chrome added at each promotion, sidearms and shoulder arms in tough flexible armour. *(NC2045 p.21, p.50-51.)*

```world factions.factions.militech
{
	"name": "Militech",
	"kind": "corp",
	"leader": "Captain Tommy Dominguez",
	"activities": [
		"security",
		"weapons"
	],
	"territory": [
		"charter_hill",
		"heywood_industrial_zone",
		"norcal_military_base",
		"outskirts",
		"pacifica_playground"
	],
	"relations": {
		"worldsat": "ally",
		"segotari": "ally"
	},
	"doctrine": "corp_military",
	"roster": {
		"ranks": {
			"mook": "Militech Trooper",
			"lieutenant": "Militech Sergeant",
			"mini_boss": "Militech Lieutenant"
		},
		"blocks": {
			"mook": [
				"hardened_security_operative",
				"security_operative"
			],
			"lieutenant": [
				"militech_security_guard"
			],
			"mini_boss": [
				"hardened_militech_veteran"
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
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.21, p.50-51"
}
```

### Biotechnica (`biotechnica`)

The world's leading biotech company, maker of CHOOH2, with a Council seat; strong in the University District and sponsoring Playland rides. *(NC2045 p.21.)*

```world factions.factions.biotechnica
{
	"name": "Biotechnica",
	"kind": "corp",
	"activities": [
		"biotech",
		"agriculture"
	],
	"territory": [
		"charter_hill",
		"little_europe",
		"university_district"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Biotechnica Security",
			"lieutenant": "Biotechnica Sergeant",
			"mini_boss": "Biotechnica Enforcer"
		},
		"blocks": {
			"mook": [
				"biotechnica_guard"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_security_officer_siege"
			],
			"mini_boss": [
				"hardened_executive_protection"
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
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.21"
}
```

### Petrochem (`petrochem`)

The classic US energy and plastics company, with a Council seat; its Watson facility shares guards with SovOil. *(NC2045 p.21.)*

```world factions.factions.petrochem
{
	"name": "Petrochem",
	"kind": "corp",
	"activities": [
		"energy",
		"plastics"
	],
	"territory": [
		"downtown",
		"heywood_industrial_zone",
		"outskirts",
		"santo_domingo",
		"watson_development"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Petrochem Security",
			"lieutenant": "Petrochem Sergeant",
			"mini_boss": "Petrochem Enforcer"
		},
		"blocks": {
			"mook": [
				"hardened_security_operative"
			],
			"lieutenant": [
				"petrochem_sovoil_guard"
			],
			"mini_boss": [
				"hardened_executive_protection"
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
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.21"
}
```

### SovOil (`sovoil`)

The classic Neo-Soviet energy and plastics company, Petrochem's twin, with a Council seat; plants in Heywood Industrial and Santo Domingo, CHOOH2 stations in the Outskirts. *(NC2045 p.21.)*

```world factions.factions.sovoil
{
	"name": "SovOil",
	"kind": "corp",
	"activities": [
		"energy",
		"plastics"
	],
	"territory": [
		"heywood_industrial_zone",
		"outskirts",
		"santo_domingo",
		"watson_development"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "SovOil Security",
			"lieutenant": "SovOil Sergeant",
			"mini_boss": "SovOil Enforcer"
		},
		"blocks": {
			"mook": [
				"hardened_security_operative"
			],
			"lieutenant": [
				"petrochem_sovoil_guard"
			],
			"mini_boss": [
				"hardened_executive_protection"
			]
		}
	},
	"look": {
		"jacket": "5a2a2a",
		"accent": "ff3030",
		"pants": "2e2222",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.21"
}
```

### Rocklin Augmentics (`rocklin_augmentics`)

American cybernetics and structural-enhancement firm known for artistic designs, with a Council seat. *(NC2045 p.21.)*

```world factions.factions.rocklin_augmentics
{
	"name": "Rocklin Augmentics",
	"kind": "corp",
	"activities": [
		"cyberware"
	],
	"territory": [
		"heywood_industrial_zone",
		"new_westbrook"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Rocklin Security",
			"lieutenant": "Rocklin Sergeant",
			"mini_boss": "Rocklin Enforcer"
		},
		"blocks": {
			"mook": [
				"rocklin_augmentics_guard"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_security_officer_siege"
			],
			"mini_boss": [
				"hardened_executive_protection"
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
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.21"
}
```

### Continental Brands (`continental_brands`)

North America's largest food manufacturer and distributor, owner of the Oasis store chain, with a Council seat. *(NC2045 p.21.)*

```world factions.factions.continental_brands
{
	"name": "Continental Brands",
	"kind": "corp",
	"activities": [
		"food",
		"retail"
	],
	"territory": [
		"downtown",
		"executive_zone",
		"heywood_docks",
		"heywood_industrial_zone",
		"kabuki",
		"little_europe",
		"playland",
		"watson_development"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Continental Security",
			"lieutenant": "Continental Sergeant",
			"mini_boss": "Continental Enforcer"
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
		"jacket": "5a6a3a",
		"accent": "ff3030",
		"pants": "34382a",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.21"
}
```

### Network 54 (`network_54`)

North America's most powerful mediacorp, making just over half of Night City's corporate media, with a Council seat; its Combat Zone set hosts the top death show. Lazarus guards Network 54 Plaza. *(NC2045 p.21.)*

```world factions.factions.network_54
{
	"name": "Network 54",
	"kind": "corp",
	"activities": [
		"media"
	],
	"territory": [
		"new_westbrook"
	],
	"relations": {
		"lazarus": "ally"
	},
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Net54 Security",
			"lieutenant": "Net54 Sergeant",
			"mini_boss": "Net54 Enforcer"
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
		"jacket": "3a3a5a",
		"accent": "ff3030",
		"pants": "2a2a3a",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.21"
}
```

### Tanson Group (`tanson`)

A Korean megacorp making a wide range of products, with a Council seat; its employees live in the Dream Forest near-arcology in Pacifica. Relations: rumoured sponsor of the Mudang Gumi (from the gang prose). *(NC2045 p.21.)*

```world factions.factions.tanson
{
	"name": "Tanson Group",
	"kind": "corp",
	"activities": [
		"manufacturing"
	],
	"territory": [
		"pacifica_playground"
	],
	"relations": {
		"mudang_gumi": "ally"
	},
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Tanson Security",
			"lieutenant": "Tanson Sergeant",
			"mini_boss": "Tanson Enforcer"
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
		"jacket": "4a6a8a",
		"accent": "ff3030",
		"pants": "2a3a4a",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.21"
}
```

### Zhirafa (`zhirafa`)

Drone and construction-equipment maker branching into architecture and building, with a Council seat; drones patrol its office park. Relations: seemingly allied with the Consortium (from the prose). *(NC2045 p.22.)*

```world factions.factions.zhirafa
{
	"name": "Zhirafa",
	"kind": "corp",
	"activities": [
		"drones",
		"construction"
	],
	"territory": [
		"heywood_industrial_zone"
	],
	"relations": {
		"consortium": "ally"
	},
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Zhirafa Security",
			"lieutenant": "Zhirafa Sergeant",
			"mini_boss": "Zhirafa Enforcer"
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
		"jacket": "6a6a4a",
		"accent": "ff3030",
		"pants": "3a3a2e",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.22"
}
```

### Ziggurat (`ziggurat`)

Creator of the modern CitiNets with a near-monopoly on North American data, with a Council seat (CEO: UR). *(NC2045 p.22.)*

```world factions.factions.ziggurat
{
	"name": "Ziggurat",
	"kind": "corp",
	"activities": [
		"data",
		"citinet"
	],
	"territory": [
		"heywood_industrial_zone",
		"upper_marina"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Ziggurat Security",
			"lieutenant": "Ziggurat Sergeant",
			"mini_boss": "Ziggurat Enforcer"
		},
		"blocks": {
			"mook": [
				"ziggurat_guard"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_security_officer_siege"
			],
			"mini_boss": [
				"hardened_executive_protection"
			]
		}
	},
	"look": {
		"jacket": "2a3a3a",
		"accent": "ff3030",
		"pants": "1e2a2a",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.22"
}
```

### Night Corp (`night_corp`)

Self-styled heir of Richard Night: developer and contractor behind public works from construction to garbage, broker of the current Council, payer of Hot Zone clearance; it built the solar station with PacCon Electric. Relations: backs Hydrosubsidium (from the prose). *(NC2045 p.61.)*

```world factions.factions.night_corp
{
	"name": "Night Corp",
	"kind": "corp",
	"activities": [
		"construction",
		"public_works"
	],
	"territory": [
		"little_europe",
		"outskirts"
	],
	"relations": {
		"hydrosubsidium": "ally"
	},
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Night Corp Security",
			"lieutenant": "Night Corp Sergeant",
			"mini_boss": "Night Corp Enforcer"
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
		"jacket": "1e2a3a",
		"accent": "ff3030",
		"pants": "1a1e26",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.61"
}
```

### AllNations Construction (`allnations_construction`)

The builder the Council hired for Megabuilding H8 in Upper Marina. *(NC2045 p.75.)*

```world factions.factions.allnations_construction
{
	"name": "AllNations Construction",
	"kind": "corp",
	"activities": [
		"construction"
	],
	"territory": [
		"upper_marina"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "AllNations Security",
			"lieutenant": "AllNations Sergeant",
			"mini_boss": "AllNations Enforcer"
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
		"jacket": "c8a040",
		"accent": "ff3030",
		"pants": "3a3a3a",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"sabotage"
	],
	"cite": "NC2045 p.75"
}
```

### AmeriCar (`americar`)

Midwestern carmaker whose first Pacifica distribution hub sits in North Heywood. *(NC2045 p.249.)*

```world factions.factions.americar
{
	"name": "AmeriCar",
	"kind": "corp",
	"activities": [
		"vehicles"
	],
	"territory": [
		"north_heywood"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "AmeriCar Security",
			"lieutenant": "AmeriCar Sergeant",
			"mini_boss": "AmeriCar Enforcer"
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
		"jacket": "4a4a5a",
		"accent": "ff3030",
		"pants": "2e2e38",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"sabotage"
	],
	"cite": "NC2045 p.249"
}
```

### Arroyo Concern (`arroyo_concern`)

The consortium of corporations that funds and runs the Heywood Industrial Zone's City Manager seat. *(NC2045 p.21, p.259.)*

```world factions.factions.arroyo_concern
{
	"name": "Arroyo Concern",
	"kind": "corp",
	"activities": [
		"governance"
	],
	"territory": [
		"heywood_industrial_zone"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Arroyo Security",
			"lieutenant": "Arroyo Sergeant",
			"mini_boss": "Arroyo Enforcer"
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
		"jacket": "4a4a40",
		"accent": "ff3030",
		"pants": "2e2e28",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.21, p.259"
}
```

### Belko Entertainment Company (`belko_entertainment`)

Anaheim entertainment firm that owns the Ascension, the drydocked cruise liner turned floating sin city. *(NC2045 p.277-279.)*

```world factions.factions.belko_entertainment
{
	"name": "Belko Entertainment Company",
	"kind": "corp",
	"activities": [
		"entertainment",
		"gambling"
	],
	"territory": [
		"pacifica_playground"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Belko Security",
			"lieutenant": "Belko Sergeant",
			"mini_boss": "Belko Enforcer"
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
		"jacket": "6a2a5a",
		"accent": "ff3030",
		"pants": "2a1e2a",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.277-279"
}
```

### Chamber of Commerce (`chamber_of_commerce`)

The business bloc remaking Downtown; it keeps its pet businesses and politicians in New Libertine Tower. Relations: the Undertow fight it (from the gang prose). *(NC2045 p.83-86.)*

```world factions.factions.chamber_of_commerce
{
	"name": "Chamber of Commerce",
	"kind": "corp",
	"activities": [
		"development",
		"politics"
	],
	"territory": [
		"downtown"
	],
	"relations": {
		"undertow": "hostile"
	},
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Chamber Security",
			"lieutenant": "Chamber Sergeant",
			"mini_boss": "Chamber Enforcer"
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
		"jacket": "3a3a4a",
		"accent": "ff3030",
		"pants": "2a2a34",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.83-86"
}
```

### Decker, Tanaka & Rogers (`decker_tanaka_rogers`)

Recovering shipping giant whose local office handles about half the Heywood Docks' cargo. *(NC2045 p.243.)*

```world factions.factions.decker_tanaka_rogers
{
	"name": "Decker, Tanaka & Rogers",
	"kind": "corp",
	"activities": [
		"shipping"
	],
	"territory": [
		"heywood_docks"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "DT&R Security",
			"lieutenant": "DT&R Sergeant",
			"mini_boss": "DT&R Enforcer"
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
		"jacket": "2a4a5a",
		"accent": "ff3030",
		"pants": "1e2a34",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"sabotage"
	],
	"cite": "NC2045 p.243"
}
```

### Digital Divinity Incorporated (`digital_divinity`)

A corporate church worshipping the online singularity and the Old Net as humanity's next divine stage; celebrities come to be purified. *(NC2045 p.71.)*

```world factions.factions.digital_divinity
{
	"name": "Digital Divinity Incorporated",
	"kind": "corp",
	"activities": [
		"religion"
	],
	"territory": [
		"upper_marina"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Digital Divinity Security",
			"lieutenant": "Digital Divinity Sergeant",
			"mini_boss": "Digital Divinity Enforcer"
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
		"jacket": "e8e8f0",
		"accent": "ff3030",
		"pants": "6a6a8a",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"sabotage"
	],
	"cite": "NC2045 p.71"
}
```

### Diverse Media Systems (`dms`)

The media firm that really runs the World News Service newsroom in Pacifica under a leased name. *(NC2045 p.283.)*

```world factions.factions.dms
{
	"name": "Diverse Media Systems",
	"kind": "corp",
	"activities": [
		"media"
	],
	"territory": [
		"pacifica_playground"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "DMS Security",
			"lieutenant": "DMS Sergeant",
			"mini_boss": "DMS Enforcer"
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
		"jacket": "3a4a6a",
		"accent": "ff3030",
		"pants": "2a2e3a",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"sabotage"
	],
	"cite": "NC2045 p.283"
}
```

### Dynalar (`dynalar`)

Owns a North Heywood campus and the Acorn Towers conapts for its young execs and techs. *(NC2045 p.247-250.)*

```world factions.factions.dynalar
{
	"name": "Dynalar",
	"kind": "corp",
	"activities": [
		"technology"
	],
	"territory": [
		"north_heywood"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Dynalar Security",
			"lieutenant": "Dynalar Sergeant",
			"mini_boss": "Dynalar Enforcer"
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
		"jacket": "3a5a6a",
		"accent": "ff3030",
		"pants": "2a3a44",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.247-250"
}
```

### EuroBank (`eurobank`)

The regional EuroBank, also the city's mint for physical and digital eurobucks, its printing run by an AI with Netwatch on site. *(NC2045 p.121.)*

```world factions.factions.eurobank
{
	"name": "EuroBank",
	"kind": "corp",
	"activities": [
		"banking"
	],
	"territory": [
		"the_glen"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "EuroBank Security",
			"lieutenant": "EuroBank Sergeant",
			"mini_boss": "EuroBank Enforcer"
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
		"jacket": "2a3a6a",
		"accent": "ff3030",
		"pants": "1e2234",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"sabotage"
	],
	"cite": "NC2045 p.121"
}
```

### 1st Night City Bank (`first_night_city_bank`)

Where most earners bank and Night Corp pays the city's contractors; about half of all cash spent in Night City passes through it. *(NC2045 p.117.)*

```world factions.factions.first_night_city_bank
{
	"name": "1st Night City Bank",
	"kind": "corp",
	"activities": [
		"banking"
	],
	"territory": [
		"the_glen"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "1st NC Bank Security",
			"lieutenant": "1st NC Bank Sergeant",
			"mini_boss": "1st NC Bank Enforcer"
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
		"jacket": "2a4a3a",
		"accent": "ff3030",
		"pants": "1e2a24",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"sabotage"
	],
	"cite": "NC2045 p.117"
}
```

### GunMart (`gunmart`)

Cheap-gun maker and retailer whose factory is staffed largely by the Enhanced, who own or back it. Relations: the Enhanced (from the gang prose). *(NC2045 p.35, p.143, p.260.)*

```world factions.factions.gunmart
{
	"name": "GunMart",
	"kind": "corp",
	"activities": [
		"weapons",
		"retail"
	],
	"territory": [
		"heywood_industrial_zone",
		"south_night_city"
	],
	"relations": {
		"enhanced": "ally"
	},
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "GunMart Security",
			"lieutenant": "GunMart Sergeant",
			"mini_boss": "GunMart Enforcer"
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
		"jacket": "6a3a2a",
		"accent": "ff3030",
		"pants": "3a2a24",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"sabotage"
	],
	"cite": "NC2045 p.35, p.143, p.260"
}
```

### Highcourt Plaza security (`highcourt_security`)

The in-house guards of the Highcourt Plaza, a pricey Art Deco hotel in Old Japantown whose guests come precisely because fans and detectives can't reach them. *(NC2045 p.132, p.137.)*

```world factions.factions.highcourt_security
{
	"name": "Highcourt Plaza security",
	"kind": "corp",
	"activities": [
		"security"
	],
	"territory": [
		"old_japantown"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Highcourt Guard",
			"lieutenant": "Highcourt Supervisor",
			"mini_boss": "Highcourt Chief"
		},
		"blocks": {
			"mook": [
				"highcourt_plaza_guard"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_security_officer_siege"
			],
			"mini_boss": [
				"hardened_executive_protection"
			]
		}
	},
	"look": {
		"jacket": "3a2a2a",
		"accent": "ff3030",
		"pants": "1e1e1e",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction"
	],
	"cite": "NC2045 p.132, p.137"
}
```

### Hydrosubsidium (`hydrosubsidium`)

Desalination and ocean-survey company that did well from the rebuilding and finds sunken cargo for a share of the salvage; Ling Po resents it on his turf, but Night Corp backs it. *(NC2045 p.73, p.101-102, p.281.)*

```world factions.factions.hydrosubsidium
{
	"name": "Hydrosubsidium",
	"kind": "corp",
	"activities": [
		"water",
		"salvage"
	],
	"territory": [
		"little_china",
		"pacifica_playground",
		"upper_marina"
	],
	"relations": {
		"night_corp": "ally"
	},
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Hydrosubsidium Security",
			"lieutenant": "Hydrosubsidium Sergeant",
			"mini_boss": "Hydrosubsidium Enforcer"
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
		"jacket": "2a5a7a",
		"accent": "ff3030",
		"pants": "1e3444",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.73, p.101-102, p.281"
}
```

### Kiroshi and Kendachi (`kiroshi`)

Regional HQ at Tengen Towers in Kabuki. *(NC2045 p.207.)*

```world factions.factions.kiroshi
{
	"name": "Kiroshi and Kendachi",
	"kind": "corp",
	"activities": [
		"cyberware",
		"weapons"
	],
	"territory": [
		"kabuki"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Kiroshi Security",
			"lieutenant": "Kiroshi Sergeant",
			"mini_boss": "Kiroshi Enforcer"
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
		"jacket": "3a2a3a",
		"accent": "ff3030",
		"pants": "2a1e2a",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"sabotage"
	],
	"cite": "NC2045 p.207"
}
```

### Little China Redevelopment Association (`lcra`)

David Ling Po's redevelopment body: it saved Guǎngbō Tower as an upscale container tower (Gold Dragons Security in the basement) and bought the Parisian hotel, clearing squatters with gunfire. Relations: Ling Po's Tong and Gold Dragons (from the prose). *(NC2045 p.99-102.)*

```world factions.factions.lcra
{
	"name": "Little China Redevelopment Association",
	"kind": "corp",
	"activities": [
		"development"
	],
	"territory": [
		"little_china"
	],
	"relations": {
		"weng_fang_tong": "ally",
		"gold_dragons": "ally"
	},
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "LCRA Security",
			"lieutenant": "LCRA Sergeant",
			"mini_boss": "LCRA Enforcer"
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
		"jacket": "6a2a2a",
		"accent": "ff3030",
		"pants": "2a1e1e",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"sabotage"
	],
	"cite": "NC2045 p.99-102"
}
```

### Merrill, Asukaga & Finch (`merrill_asukaga_finch`)

A financial firm atop Thurgood Towers that takes clients by referral only and escorts every visitor at gunpoint. *(NC2045 p.123.)*

```world factions.factions.merrill_asukaga_finch
{
	"name": "Merrill, Asukaga & Finch",
	"kind": "corp",
	"activities": [
		"finance"
	],
	"territory": [
		"the_glen"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "MA&F Security",
			"lieutenant": "MA&F Sergeant",
			"mini_boss": "MA&F Enforcer"
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
		"jacket": "2a2a3a",
		"accent": "ff3030",
		"pants": "1e1e2a",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.123"
}
```

### Midnight Arms (`midnight_arms`)

Gun retailer occupying the old Mustang Arms plant in Upper Marina. *(NC2045 p.75.)*

```world factions.factions.midnight_arms
{
	"name": "Midnight Arms",
	"kind": "corp",
	"activities": [
		"weapons",
		"retail"
	],
	"territory": [
		"upper_marina"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Midnight Arms Security",
			"lieutenant": "Midnight Arms Sergeant",
			"mini_boss": "Midnight Arms Enforcer"
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
		"jacket": "2a2a34",
		"accent": "ff3030",
		"pants": "1e1e26",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"sabotage"
	],
	"cite": "NC2045 p.75"
}
```

### Orbital Air (`orbital_air`)

Runs the Night City Spaceport and the Morro Rock company town, piping instructions and quota reminders to its workforce over its own radio. *(NC2045 p.295-298.)*

```world factions.factions.orbital_air
{
	"name": "Orbital Air",
	"kind": "corp",
	"activities": [
		"aerospace"
	],
	"territory": [
		"outskirts"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Orbital Air Security",
			"lieutenant": "Orbital Air Sergeant",
			"mini_boss": "Orbital Air Enforcer"
		},
		"blocks": {
			"mook": [
				"hardened_security_operative"
			],
			"lieutenant": [
				"orbital_air_guard"
			],
			"mini_boss": [
				"hardened_executive_protection"
			]
		}
	},
	"look": {
		"jacket": "dfe6ea",
		"accent": "ff3030",
		"pants": "4a5060",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.295-298"
}
```

### Pol-Bud (`pol_bud`)

SoCal firm supplying most of the rebuilding city's cement, owning its whole chain from mine and factory to security and worker housing. *(NC2045 p.299.)*

```world factions.factions.pol_bud
{
	"name": "Pol-Bud",
	"kind": "corp",
	"activities": [
		"construction",
		"mining"
	],
	"territory": [
		"outskirts"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Pol-Bud Security",
			"lieutenant": "Pol-Bud Sergeant",
			"mini_boss": "Pol-Bud Enforcer"
		},
		"blocks": {
			"mook": [
				"pol_bud_guard"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_security_officer_siege"
			],
			"mini_boss": [
				"hardened_executive_protection"
			]
		}
	},
	"look": {
		"jacket": "7a7a6a",
		"accent": "ff3030",
		"pants": "4a4a40",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.299"
}
```

### Pursuit Security Inc (`pursuit_security`)

SoCal maker of less-than-lethal weapons, with a small Pacifica showroom stocked by Jodes convoys. *(NC2045 p.281.)*

```world factions.factions.pursuit_security
{
	"name": "Pursuit Security Inc",
	"kind": "corp",
	"activities": [
		"weapons"
	],
	"territory": [
		"pacifica_playground"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Pursuit Security",
			"lieutenant": "Pursuit Sergeant",
			"mini_boss": "Pursuit Enforcer"
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
		"jacket": "3a4a5a",
		"accent": "ff3030",
		"pants": "2a2e36",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction"
	],
	"cite": "NC2045 p.281"
}
```

### Raven Microcybernetics (`raven_microcybernetics`)

Cyberware firm with offices in the Glen and a mostly automated factory in Heywood Industrial, guarded by its own McCain Security. Relations: McCain Security (from the prose). *(NC2045 p.124-125, p.261.)*

```world factions.factions.raven_microcybernetics
{
	"name": "Raven Microcybernetics",
	"kind": "corp",
	"activities": [
		"cyberware"
	],
	"territory": [
		"heywood_industrial_zone",
		"the_glen"
	],
	"relations": {
		"mccain_security": "ally"
	},
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Raven Security",
			"lieutenant": "Raven Sergeant",
			"mini_boss": "Raven Enforcer"
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
		"jacket": "1e1e2a",
		"accent": "ff3030",
		"pants": "1a1a22",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.124-125, p.261"
}
```

### Red Cab Company (`red_cab`)

The city's largest taxi firm: armoured red groundcars and AVs with Neo-Soviet branding, serving only secure districts; its Little Europe garage is a Maelstrom hangout (gang list p.38). *(NC2045 p.20, p.62.)*

```world factions.factions.red_cab
{
	"name": "Red Cab Company",
	"kind": "corp",
	"activities": [
		"transport"
	],
	"territory": [
		"little_europe"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Red Cab Security",
			"lieutenant": "Red Cab Sergeant",
			"mini_boss": "Red Cab Enforcer"
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
		"jacket": "8a1e1e",
		"accent": "ff3030",
		"pants": "2a1e1e",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"sabotage"
	],
	"cite": "NC2045 p.20, p.62"
}
```

### Sanroo (`sanroo`)

Japanese maker of cute-styled goods and weapons (Hello Cutie sculpts): a pastel-pink Pacifica HQ in Old Japantown makes most of what it sells here, plus the Neuro-land showroom in Kabuki. *(NC2045 p.134, p.206.)*

```world factions.factions.sanroo
{
	"name": "Sanroo",
	"kind": "corp",
	"activities": [
		"manufacturing",
		"weapons"
	],
	"territory": [
		"kabuki",
		"old_japantown"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Sanroo Security",
			"lieutenant": "Sanroo Sergeant",
			"mini_boss": "Sanroo Enforcer"
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
		"jacket": "f0a0c0",
		"accent": "ff3030",
		"pants": "6a4a5a",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.134, p.206"
}
```

### Segotari (`segotari`)

The world's biggest video-game company: Pacifica HQ over Kabuki's entertainment hub, a plush-prize factory (rumoured Elflines servers) and Playland attractions guarded by Militech. *(NC2045 p.135, p.206, p.310-311.)*

```world factions.factions.segotari
{
	"name": "Segotari",
	"kind": "corp",
	"activities": [
		"games",
		"entertainment"
	],
	"territory": [
		"kabuki",
		"old_japantown",
		"playland"
	],
	"relations": {
		"militech": "ally"
	},
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Segotari Security",
			"lieutenant": "Segotari Sergeant",
			"mini_boss": "Segotari Enforcer"
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
		"jacket": "3a2a6a",
		"accent": "ff3030",
		"pants": "2a2a3a",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.135, p.206, p.310-311"
}
```

### Tower of Dark (`tower_of_dark`)

Operator of Playland by the Sea's rides, stalls and venues (many sponsored by other corps), with Protective Lightning on site. *(NC2045 p.302-313.)*

```world factions.factions.tower_of_dark
{
	"name": "Tower of Dark",
	"kind": "corp",
	"activities": [
		"entertainment"
	],
	"territory": [
		"playland"
	],
	"relations": {
		"protective_lightning": "ally"
	},
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Tower of Dark Security",
			"lieutenant": "Tower of Dark Sergeant",
			"mini_boss": "Tower of Dark Enforcer"
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
		"jacket": "2a1e3a",
		"accent": "ff3030",
		"pants": "1e1a2a",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"sabotage"
	],
	"cite": "NC2045 p.302-313"
}
```

### WorldSat (`worldsat`)

Night City's main communications link to the outside world, guarded by Militech. Relations: Militech's client (from the provider prose). *(NC2045 p.221.)*

```world factions.factions.worldsat
{
	"name": "WorldSat",
	"kind": "corp",
	"activities": [
		"communications"
	],
	"territory": [
		"new_westbrook"
	],
	"relations": {
		"militech": "ally"
	},
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "WorldSat Security",
			"lieutenant": "WorldSat Sergeant",
			"mini_boss": "WorldSat Enforcer"
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
		"jacket": "3a4a6a",
		"accent": "ff3030",
		"pants": "2a2e3a",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.221"
}
```

### Night City Co-Prosperity Sphere (`nccs`)

The corporate alliance actor Shinobu Nakagawa assembled to rebuild a home for Japanese Night City; the Tyger Claws enforce its will. Relations: the Tyger Claws and Kimen-Gumi (from the prose). *(NC2045 p.44, p.189.)*

```world factions.factions.nccs
{
	"name": "Night City Co-Prosperity Sphere",
	"kind": "corp",
	"activities": [
		"development"
	],
	"territory": [
		"watson_development"
	],
	"relations": {
		"tyger_claws": "ally",
		"kimen_gumi": "ally"
	},
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "NCCS Security",
			"lieutenant": "NCCS Sergeant",
			"mini_boss": "NCCS Enforcer"
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
		"jacket": "3a1e2a",
		"accent": "ff3030",
		"pants": "222226",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"assassination",
		"sabotage"
	],
	"cite": "NC2045 p.44, p.189"
}
```

### Services, institutions and nomads

City services, government, Trauma Team, the NCPD and MAX-TAC, and the nomad families that own places.

### Night City government (`city_government`)

City Hall and the district City Managers' offices, firehouses and substations. Generic civic owner. *(NC2045 p.119.)*

```world factions.factions.city_government
{
	"name": "Night City government",
	"kind": "service",
	"activities": [
		"government"
	],
	"territory": [
		"executive_zone",
		"new_westbrook",
		"north_heywood",
		"santo_domingo",
		"south_night_city",
		"the_glen"
	],
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "City Guard",
			"lieutenant": "City Security Chief",
			"mini_boss": "City Marshal"
		},
		"blocks": {
			"mook": [
				"security_operative"
			],
			"lieutenant": [
				"security_officer"
			]
		}
	},
	"look": {
		"jacket": "3a4048",
		"accent": "2a6aff",
		"pants": "2a2e34",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.119"
}
```

### Canadian Consulate (`canadian_consulate`)

Canada's mission in Watson, run by an overworked consul with several secrets. *(NC2045 p.189.)*

```world factions.factions.canadian_consulate
{
	"name": "Canadian Consulate",
	"kind": "service",
	"activities": [
		"diplomacy"
	],
	"territory": [
		"watson_development"
	],
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Consulate Staff",
			"lieutenant": "Consulate Chief",
			"mini_boss": "Consulate Boss"
		},
		"blocks": {
			"mook": [
				"security_operative"
			],
			"lieutenant": [
				"security_officer"
			]
		}
	},
	"look": {
		"jacket": "8a1e1e",
		"accent": "dfe6ea",
		"pants": "2a2a2e",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.189"
}
```

### United States government (`us_government`)

The US, working in NorCal through spies: a rumoured military-intelligence post at Fortitude South and the Culper Ring on the base. Relations: the Culper Ring (from the prose). *(NC2045 p.34, p.143.)*

```world factions.factions.us_government
{
	"name": "United States government",
	"kind": "service",
	"activities": [
		"espionage"
	],
	"territory": [
		"south_night_city"
	],
	"relations": {
		"culper_ring": "ally"
	},
	"doctrine": "corp_military",
	"roster": {
		"ranks": {
			"mook": "US Operative",
			"lieutenant": "US Case Officer",
			"mini_boss": "US Station Chief"
		},
		"blocks": {
			"mook": [
				"hardened_security_operative"
			],
			"lieutenant": [
				"hardened_security_officer_raid"
			]
		}
	},
	"look": {
		"jacket": "3a4232",
		"accent": "ff3030",
		"pants": "2a3026",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"sabotage"
	],
	"cite": "NC2045 p.34, p.143"
}
```

### Estero Bay Military COG (`estero_bay_military_cog`)

NorCal's military command on the NorCal Military Base: airfield, academy, hospital and barracks, policed by its own MPs. Relations: the COG Military Police (from the prose). *(NC2045 p.178-185.)*

```world factions.factions.estero_bay_military_cog
{
	"name": "Estero Bay Military COG",
	"kind": "police",
	"activities": [
		"military"
	],
	"territory": [
		"norcal_military_base"
	],
	"relations": {
		"norcal_cog_military_police": "ally"
	},
	"doctrine": "corp_military",
	"roster": {
		"ranks": {
			"mook": "COG Soldier",
			"lieutenant": "COG Sergeant",
			"mini_boss": "COG Officer"
		},
		"blocks": {
			"mook": [
				"hardened_security_operative"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_security_officer_siege"
			],
			"mini_boss": [
				"hardened_militech_veteran"
			]
		}
	},
	"look": {
		"jacket": "4a4e3a",
		"accent": "ff3030",
		"pants": "3a3e2e",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.178-185"
}
```

### Night City Fire Department (`ncfd`)

Armed, armoured, cybered firefighters working out of fortified firehouses. *(NC2045 p.87, p.89.)*

```world factions.factions.ncfd
{
	"name": "Night City Fire Department",
	"kind": "service",
	"activities": [
		"firefighting"
	],
	"territory": [
		"downtown"
	],
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Firefighter",
			"lieutenant": "Fire Captain",
			"mini_boss": "Fire Chief"
		},
		"blocks": {
			"mook": [
				"ncfd_firefighter"
			]
		}
	},
	"look": {
		"jacket": "8a2a1e",
		"accent": "e0c020",
		"pants": "2a2a2a",
		"vest": true,
		"helmet": true,
		"gloves": true
	},
	"cite": "NC2045 p.87, p.89"
}
```

### REO Meatwagon (`reo_meatwagon`)

Cut-rate ambulances for people without Trauma Team cover; they won't enter combat zones or leave the city. *(NC2045 p.77, p.79.)*

```world factions.factions.reo_meatwagon
{
	"name": "REO Meatwagon",
	"kind": "service",
	"activities": [
		"ambulance"
	],
	"territory": [
		"upper_marina"
	],
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "REO EMT",
			"lieutenant": "REO Crew Chief",
			"mini_boss": "REO Supervisor"
		},
		"blocks": {
			"mook": [
				"reo_meatwagon_emt",
				"reo_meatwagon_driver"
			]
		}
	},
	"look": {
		"jacket": "dfe6ea",
		"accent": "e0c020",
		"pants": "3a4048",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"data_theft"
	],
	"cite": "NC2045 p.77, p.79"
}
```

### Combat Cabb (`combat_cabb`)

The legendary armed and armoured taxi firm that drives anywhere, combat zones included, from a walled bunker compound in South Night City. *(NC2045 p.20, p.141-142, p.148.)*

```world factions.factions.combat_cabb
{
	"name": "Combat Cabb",
	"kind": "service",
	"activities": [
		"transport"
	],
	"territory": [
		"south_night_city"
	],
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Cabbie",
			"lieutenant": "Cabb Dispatcher",
			"mini_boss": "Cabb Boss"
		},
		"blocks": {
			"mook": [
				"combat_cabb_driver"
			],
			"lieutenant": [
				"security_officer"
			]
		}
	},
	"look": {
		"jacket": "e0c020",
		"accent": "ff3030",
		"pants": "2a2a2a",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"sabotage"
	],
	"cite": "NC2045 p.20, p.141-142, p.148"
}
```

### NCART (`ncart`)

The city's buses and trains, run by the Dorado clan from the Reclamation Zone yards. Relations: the Dorado clan's (from the prose). *(NC2045 p.159, p.163, p.165.)*

```world factions.factions.ncart
{
	"name": "NCART",
	"kind": "service",
	"activities": [
		"transport"
	],
	"territory": [
		"reclamation_zone"
	],
	"relations": {
		"dorado_family": "ally",
		"los_perros_guardianes": "ally"
	},
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "NCART Worker",
			"lieutenant": "NCART Foreman",
			"mini_boss": "NCART Boss"
		},
		"blocks": {
			"mook": [
				"ncart_driver",
				"ncart_tech"
			]
		}
	},
	"look": {
		"jacket": "3a5a6a",
		"accent": "e0c020",
		"pants": "2a3a44",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"sabotage"
	],
	"cite": "NC2045 p.159, p.163, p.165"
}
```

### Nakagawa Foundation (`nakagawa_foundation`)

Charity of the Nakagawa family funding a Kabuki clinic, school and theatre. *(NC2045 p.203-205.)*

```world factions.factions.nakagawa_foundation
{
	"name": "Nakagawa Foundation",
	"kind": "service",
	"activities": [
		"charity"
	],
	"territory": [
		"kabuki"
	],
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Foundation Staff",
			"lieutenant": "Foundation Chief",
			"mini_boss": "Foundation Boss"
		},
		"blocks": {
			"mook": [
				"security_operative"
			],
			"lieutenant": [
				"security_officer"
			]
		}
	},
	"look": {
		"jacket": "3a2a3a",
		"accent": "ff3030",
		"pants": "2a2a2a",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"corp_extraction",
		"assassination",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.203-205"
}
```

### Nostradamus (`nostradamus`)

Keeper of a secret, invitation-only archive of physical books and a vast NET architecture of collected data. *(NC2045 p.145.)*

```world factions.factions.nostradamus
{
	"name": "Nostradamus",
	"kind": "service",
	"activities": [
		"archive",
		"netrunning"
	],
	"territory": [
		"south_night_city"
	],
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Archive Guard",
			"lieutenant": "Archive Netrunner",
			"mini_boss": "Archive Keeper"
		},
		"blocks": {
			"mook": [
				"security_operative"
			],
			"lieutenant": [
				"netrunner"
			]
		}
	},
	"look": {
		"jacket": "3a3a3a",
		"accent": "ff3030",
		"pants": "2a2a2a",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"data_theft"
	],
	"cite": "NC2045 p.145"
}
```

### Recluse (`recluse`)

A legendary Netrunner (at least 10,000eb a gig) laired in an abandoned Old Japantown strip mall circled by armed drones; she meets clients only as a giant spider in her NET. *(NC2045 p.132.)*

```world factions.factions.recluse
{
	"name": "Recluse",
	"kind": "service",
	"activities": [
		"netrunning"
	],
	"territory": [
		"old_japantown"
	],
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Drone Handler",
			"lieutenant": "Recluse's Runner",
			"mini_boss": "Recluse"
		},
		"blocks": {
			"mook": [
				"security_operative"
			],
			"lieutenant": [
				"netrunner"
			]
		}
	},
	"look": {
		"jacket": "1e1e1e",
		"accent": "ff3030",
		"pants": "1e1e1e",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"data_theft",
		"assassination"
	],
	"cite": "NC2045 p.132"
}
```

### Trauma Team International (`trauma_team`)

The concierge ambulance and paramedic service famous for flying emergency squads, with a Council seat; Trauma Team Tower in Watson is guarded by Lazarus. As responders they land by AV for a downed cardholder; they can also be a gig target in their own right. *(NC2045 p.21, p.199.)*

```world factions.factions.trauma_team
{
	"name": "Trauma Team International",
	"kind": "service",
	"activities": [
		"medical"
	],
	"territory": [
		"heywood_industrial_zone",
		"watson_development"
	],
	"doctrine": "corp_standard",
	"roster": {
		"ranks": {
			"mook": "Trauma Team Security",
			"lieutenant": "Trauma Team Sergeant",
			"mini_boss": "Trauma Team Enforcer"
		},
		"blocks": {
			"mook": [
				"trauma_team_medtech"
			],
			"lieutenant": [
				"security_officer"
			],
			"mini_boss": [
				"trauma_team_pilot"
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
		"corp_extraction",
		"sabotage"
	],
	"cite": "NC2045 p.21, p.199"
}
```

### NCPD (`ncpd`)

The municipal police, answering to the City Council (where they sit through the Patrolman's Benevolent Association) with jurisdiction almost everywhere; the default district security where no provider is deputized. Answer escalating fights; at war with gangs, leave corp security alone. *(NC2045 p.22, p.65, p.198.)*

```world factions.factions.ncpd
{
	"name": "NCPD",
	"kind": "police",
	"activities": [
		"law_enforcement"
	],
	"territory": [
		"heywood_industrial_zone",
		"hot_zone",
		"little_europe",
		"new_westbrook",
		"rancho_coronado",
		"santo_domingo",
		"the_glen",
		"upper_marina",
		"watson_development"
	],
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "NCPD Officer",
			"lieutenant": "NCPD Sergeant",
			"mini_boss": "NCPD Lieutenant"
		},
		"blocks": {
			"mook": [
				"ncpd_beat_cop",
				"ncpd_academy_trainee"
			],
			"lieutenant": [
				"hardened_security_officer_raid",
				"hardened_security_officer_siege"
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
	},
	"gigs": [
		"data_theft",
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.22, p.65, p.198"
}
```

### MAX-TAC (`maxtac`)

The famous cyberpsycho squad, no longer part of the NCPD: a private security and bounty-hunting outfit that swoops in on violent criminals and cyberpsychos in "self-defence" and bills the people saved. Anyone obviously chromed and violent counts. Agents are chromed to the edge and carry anti-tank-grade weapons; no mooks. Its CEO holds the police lobby's Council seat. Relations: allied with the NCPD (ours: kept as police). *(NC2045 p.50, p.148.)*

```world factions.factions.maxtac
{
	"name": "MAX-TAC",
	"kind": "police",
	"activities": [
		"security",
		"bounty_hunting"
	],
	"territory": [
		"south_night_city"
	],
	"doctrine": "corp_military",
	"roster": {
		"ranks": {
			"mook": "MaxTac",
			"lieutenant": "MaxTac",
			"mini_boss": "MaxTac"
		},
		"blocks": {
			"lieutenant": [
				"max_tac_rookie"
			],
			"mini_boss": [
				"max_tac_rookie",
				"hardened_militech_veteran"
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
	},
	"gigs": [
		"data_theft",
		"sabotage"
	],
	"cite": "NC2045 p.50, p.148"
}
```

### Dorado clan (`dorado_family`)

Former Snake Nation nomads, nearly all related, who took over NCART and were awarded the Reclamation Zone as a district in 2039. Relations: run NCART; protected by Los Perros Guardianes (from the district prose). *(NC2045 p.14, p.159.)*

```world factions.factions.dorado_family
{
	"name": "Dorado clan",
	"kind": "service",
	"leader": "Santos Dorado",
	"activities": [
		"transport",
		"survival"
	],
	"territory": [
		"reclamation_zone"
	],
	"relations": {
		"ncart": "ally",
		"los_perros_guardianes": "ally"
	},
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Dorado Nomad",
			"lieutenant": "Dorado Road Boss",
			"mini_boss": "Dorado Elder"
		},
		"blocks": {
			"mook": [
				"young_dorado_racer"
			],
			"lieutenant": [
				"hardened_reclaimer_chief_thunder"
			],
			"mini_boss": [
				"hardened_outrider"
			]
		}
	},
	"look": {
		"jacket": "6a4a2a",
		"accent": "e0c020",
		"pants": "3a3028",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"cite": "NC2045 p.14, p.159"
}
```

### Aldecaldos (`aldecaldos`)

The nomad nation whose de facto capital is the camp at Coronado Dam in Santo Domingo, hub of its trade, transport and labour; it leads the Nomad Collective's Council seat. Relations: the Peacekeepers are theirs (from the prose). *(NC2045 p.21, p.267-268.)*

```world factions.factions.aldecaldos
{
	"name": "Aldecaldos",
	"kind": "service",
	"leader": "Izzy Lobo",
	"activities": [
		"trade",
		"transport"
	],
	"territory": [
		"santo_domingo"
	],
	"relations": {
		"aldecaldo_peacekeepers": "ally"
	},
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Aldecaldo Nomad",
			"lieutenant": "Aldecaldo Road Boss",
			"mini_boss": "Aldecaldo Elder"
		},
		"blocks": {
			"mook": [
				"hardened_road_ganger"
			],
			"lieutenant": [
				"aldecaldo_driver"
			],
			"mini_boss": [
				"hardened_outrider"
			]
		}
	},
	"look": {
		"jacket": "6a4a2a",
		"accent": "e0c020",
		"pants": "3a3028",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"rescue",
		"sabotage"
	],
	"cite": "NC2045 p.21, p.267-268"
}
```

### Jodes (`jodes`)

Nomad nation, Nomad Collective funder; its Pacifica container camp refuels and resupplies convoys and polices itself. *(NC2045 p.21, p.280.)*

```world factions.factions.jodes
{
	"name": "Jodes",
	"kind": "service",
	"leader": "Solomon \"Old Greenjeans\" LaPlante",
	"activities": [
		"trade",
		"transport"
	],
	"territory": [
		"pacifica_playground"
	],
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Jodes Nomad",
			"lieutenant": "Jodes Road Boss",
			"mini_boss": "Jodes Elder"
		},
		"blocks": {
			"mook": [
				"hardened_road_ganger"
			],
			"lieutenant": [
				"jodes_driver"
			],
			"mini_boss": [
				"hardened_outrider"
			]
		}
	},
	"look": {
		"jacket": "4a5a3a",
		"accent": "e0c020",
		"pants": "2e3a2a",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"rescue"
	],
	"cite": "NC2045 p.21, p.280"
}
```

### Snake Nation (`snake_nation`)

Nomad nation that runs the cargo railways into the city, escorted by the DeadWoods. Relations: the DeadWoods (from the prose). *(NC2045 p.35, p.244.)*

```world factions.factions.snake_nation
{
	"name": "Snake Nation",
	"kind": "service",
	"activities": [
		"rail_freight"
	],
	"territory": [
		"heywood_docks"
	],
	"relations": {
		"deadwoods": "ally"
	},
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Snake Nation Nomad",
			"lieutenant": "Snake Nation Road Boss",
			"mini_boss": "Snake Nation Elder"
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
		"jacket": "5a4a2a",
		"accent": "e0c020",
		"pants": "3a3024",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"sabotage"
	],
	"cite": "NC2045 p.35, p.244"
}
```

### Groundhog Gulpers (`groundhog_gulpers`)

Snake Nation pack running the Union Railroad Station cargo transfer point on computers too old to netrun. Relations: Snake Nation and the DeadWoods (from the prose). *(NC2045 p.300.)*

```world factions.factions.groundhog_gulpers
{
	"name": "Groundhog Gulpers",
	"kind": "service",
	"activities": [
		"rail_freight"
	],
	"territory": [
		"outskirts"
	],
	"relations": {
		"snake_nation": "ally",
		"deadwoods": "ally"
	},
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Gulper Nomad",
			"lieutenant": "Gulper Road Boss",
			"mini_boss": "Gulper Elder"
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
		"jacket": "5a4a2a",
		"accent": "e0c020",
		"pants": "3a3024",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"gigs": [
		"sabotage"
	],
	"cite": "NC2045 p.300"
}
```

### Breaker 1-9s (`breaker_1_9s`)

A continent-wide nomad radio pack running ad-free, pledge-funded NoPR news radio from Santo Domingo. *(NC2045 p.265.)*

```world factions.factions.breaker_1_9s
{
	"name": "Breaker 1-9s",
	"kind": "service",
	"activities": [
		"media"
	],
	"territory": [
		"santo_domingo"
	],
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Breaker Nomad",
			"lieutenant": "Breaker Road Boss",
			"mini_boss": "Breaker Elder"
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
		"jacket": "4a3a5a",
		"accent": "e0c020",
		"pants": "2e2a34",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"cite": "NC2045 p.265"
}
```

### Nomads (`nomads`)

Short-stay nomad groups camping outside the city: approach slowly, hands visible, ideally bearing a gift. Generic, for camps no single family owns. *(NC2045 p.298.)*

```world factions.factions.nomads
{
	"name": "Nomads",
	"kind": "service",
	"activities": [
		"trade",
		"transport"
	],
	"territory": [
		"outskirts"
	],
	"doctrine": "default",
	"roster": {
		"ranks": {
			"mook": "Nomad Nomad",
			"lieutenant": "Nomad Road Boss",
			"mini_boss": "Nomad Elder"
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
		"jacket": "5a4a34",
		"accent": "e0c020",
		"pants": "3a3428",
		"vest": true,
		"helmet": false,
		"gloves": true
	},
	"cite": "NC2045 p.298"
}
```
