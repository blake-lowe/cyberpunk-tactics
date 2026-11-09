# Fixers

Night City's named Fixers, from the `## Fixers` lists in the district docs (`docs/world/nc_<district>.md`),
which come from the Night City 2045 sourcebook (cited `NC2045 p.N`, PDF page numbers; the printed page is one
less). The fixer board (`Campaign.refresh_board`) gives each job to a Fixer working the district the job is in.
Names, ranks and a few tags only; never paste the book's text.

## Schema

At `fixers.fixers.<id>` (id: snake_case of the name, nickname dropped, e.g. `barry_delvecchio`):

- `name`: as printed, nickname included (`Barry "Big Deal" Delvecchio`).
- `rank`: the Fixer Role Rank as printed; `roles`: the full printed Role string (`Medtech 7/Fixer 6`).
- `district`: the `city.districts` id of the district whose doc lists them; `also`: other districts whose
  docs list them too (Mister Kernaghan works The Glen, Downtown and the Executive Zone).
- `location`: the `locations.locations` id of where they do business (`""` when they have no fixed place).
- `deals_in`: short tags for what they broker. Vocabulary: antiques, armor, art, betting, braindance,
  clothing, combat (hires out muscle and combat jobs), construction, crime (runs or fronts for a
  gang or mob), cyberware, deliveries, diplomacy, drugs, entertainment, exfiltration, favours, fights,
  food, gigs (books jobs for edgerunners), guide, ids, information, investments, labour, loans, luxury,
  media, mediation, medical, netrunning, nomads, programs, property, sabotage, salvage, smuggling,
  supplies, vehicles, veterans, weapons. `data/gen/gigs.json` `fixer_tags` says which tags suit which gig kind.
- `cite`: `"NC2045 p.N"`; a district chapter range where the Fixers list gives no page. Fixers from the
  Single Player Mode book (below) cite `"SPM p.N"` (printed page).
- `district` is `""` for a Fixer no source places in a district (the SPM canon fixers below): they work
  the whole city and only get jobs where no district Fixer is at hand (`Campaign._pick_fixer`'s fallback).
- `faction` (optional): the `factions.factions` id of a gang or outfit the Fixer leads.

Left out on purpose (no Fixer rank, or no name): New Westbrook's brokers (Diana, Sizzle Jams, Tom Dolby:
the doc notes no Fixer is named there), Ginkgo (Little China, Tech 4), "The Knife" (Kabuki, an assassin a few
fixers can reach), and the unnamed Fixers of the Bella Vista Night Market and Diplomatic Immunity.
Districts without a Fixer of their own (New Westbrook) get jobs from Fixers in neighbouring districts.

```world fixers
{
	"_doc": "Night City's Fixers (World.fixers / World.fixers_in), one per Fixer-ranked person named in the NC2045 district docs' Fixers lists: name, rank (Fixer Role Rank), roles (as printed), district (city.districts id), also (other districts they work), location (locations.locations id or \"\"), deals_in tags, cite. Generated from docs/world/fixers.md.",
	"fixers": {
		"johnathan_downey": {"name": "Johnathan Downey", "rank": 8, "roles": "Fixer 8", "district": "charter_hill", "location": "charter_hill_4", "deals_in": ["art", "luxury"], "cite": "NC2045 p.227"},
		"magretta_cippolina": {"name": "Magretta Cippolina", "rank": 5, "roles": "Exec 4/Fixer 5", "district": "charter_hill", "location": "charter_hill_6", "deals_in": ["media", "braindance", "entertainment"], "cite": "NC2045 p.227, p.230"},
		"carolina_albaz": {"name": "Carolina Albaz", "rank": 4, "roles": "Fixer 4/Rockerboy 4", "district": "charter_hill", "location": "charter_hill_12", "deals_in": ["investments", "sabotage"], "cite": "NC2045 p.229-230"},

		"hercule_moleharty": {"name": "Hercule Moleharty", "rank": 7, "roles": "Fixer 7", "district": "downtown", "location": "downtown_16", "deals_in": ["antiques", "smuggling"], "cite": "NC2045 p.86"},
		"cassandra_vey": {"name": "Cassandra Vey", "rank": 6, "roles": "Fixer 6", "district": "downtown", "location": "downtown_9", "deals_in": ["investments", "luxury"], "cite": "NC2045 p.84"},
		"jack_skorkowsky": {"name": "Jack Skorkowsky", "rank": 5, "roles": "Solo 4/Fixer 5", "district": "downtown", "location": "downtown_7", "deals_in": ["property", "combat"], "cite": "NC2045 p.84"},
		"monsieur_jacques": {"name": "Monsieur Jacques", "rank": 4, "roles": "Fixer 4", "district": "downtown", "location": "downtown_3", "deals_in": ["information"], "cite": "NC2045 p.83"},
		"leo_stone": {"name": "Leo Stone", "rank": 1, "roles": "Fixer 1", "district": "downtown", "location": "", "deals_in": ["information"], "cite": "NC2045 p.80-89"},

		"dallas_mckennon": {"name": "Dallas McKennon", "rank": 8, "roles": "Fixer 8", "district": "executive_zone", "location": "executive_zone_2", "deals_in": ["entertainment", "luxury"], "cite": "NC2045 p.238"},
		"audrey_sanchez": {"name": "Audrey Sanchez", "rank": 5, "roles": "Fixer 5", "district": "executive_zone", "location": "", "deals_in": ["salvage"], "cite": "NC2045 p.238"},
		"margaret_pacer": {"name": "Margaret \"Peggy\" Pacer", "rank": 4, "roles": "Fixer 4", "district": "executive_zone", "location": "executive_zone_9", "deals_in": ["drugs", "luxury"], "cite": "NC2045 p.238"},

		"lynn_skiv": {"name": "Lynn Skiv", "rank": 7, "roles": "Fixer 7", "district": "heywood_docks", "location": "heywood_docks_9", "deals_in": ["crime", "construction", "smuggling"], "cite": "NC2045 p.241, p.245"},
		"tony_vilshenko": {"name": "Tony \"Nutcracker\" Vilshenko", "rank": 5, "roles": "Fixer 5", "district": "heywood_docks", "location": "", "deals_in": ["crime"], "cite": "NC2045 p.244-245"},

		"fixie": {"name": "Fixie", "rank": 6, "roles": "Fixer 6", "district": "heywood_industrial_zone", "location": "heywood_industrial_zone_5", "deals_in": ["deliveries"], "cite": "NC2045 p.259, p.263"},
		"gabriel_yang": {"name": "Gabriel Yang", "rank": 4, "roles": "Fixer 4/Nomad 2", "district": "heywood_industrial_zone", "location": "heywood_industrial_zone_16", "deals_in": ["vehicles"], "cite": "NC2045 p.262"},
		"boris_agron": {"name": "Boris Agron", "rank": 3, "roles": "Fixer 3", "district": "heywood_industrial_zone", "location": "heywood_industrial_zone_2", "deals_in": ["loans", "crime"], "cite": "NC2045 p.259"},
		"memo": {"name": "Memo", "rank": 1, "roles": "Fixer 1", "district": "heywood_industrial_zone", "location": "", "deals_in": ["supplies", "information"], "cite": "NC2045 p.263"},

		"hamilton_parker": {"name": "Hamilton \"Guzz\" Parker", "rank": 4, "roles": "Fixer 4/Nomad 4", "district": "hot_zone", "location": "", "deals_in": ["nomads", "labour"], "cite": "NC2045 p.90-95"},

		"yoshiki_murakami": {"name": "Yoshiki Murakami", "rank": 6, "roles": "Fixer 6", "district": "kabuki", "location": "kabuki_11", "deals_in": ["smuggling", "supplies"], "cite": "NC2045 p.201, p.205"},
		"hikaru_murakami": {"name": "Hikaru Murakami", "rank": 5, "roles": "Fixer 5", "district": "kabuki", "location": "kabuki_11", "deals_in": ["supplies", "weapons", "armor", "vehicles"], "cite": "NC2045 p.205"},
		"hamada": {"name": "Hamada", "rank": 4, "roles": "Fixer 4", "district": "kabuki", "location": "kabuki_9", "deals_in": ["food", "crime"], "cite": "NC2045 p.204"},
		"alan_lam": {"name": "Alan Lam", "rank": 5, "roles": "Fixer 5", "district": "kabuki", "location": "kabuki_24", "deals_in": ["mediation", "crime"], "cite": "NC2045 p.207"},

		"david_ling_po": {"name": "David Ling Po", "rank": 8, "roles": "Fixer 8", "district": "little_china", "location": "little_china_4", "deals_in": ["crime", "construction", "investments"], "cite": "NC2045 p.97"},
		"old_yau": {"name": "Old Yau", "rank": 4, "roles": "Fixer 4", "district": "little_china", "location": "little_china_6", "deals_in": ["food", "information"], "cite": "NC2045 p.100-101"},

		"80_20": {"name": "80/20", "rank": 3, "roles": "Fixer 3", "district": "little_europe", "location": "little_europe_5", "deals_in": ["cyberware"], "cite": "NC2045 p.58"},
		"3_piece": {"name": "3-Piece", "rank": 5, "roles": "Fixer 5/Media 2", "district": "little_europe", "location": "little_europe_21", "deals_in": ["programs", "supplies"], "cite": "NC2045 p.63"},
		"artie_murdock": {"name": "Artie Murdock", "rank": 3, "roles": "Fixer 3", "district": "little_europe", "location": "little_europe_14", "deals_in": ["weapons", "armor"], "cite": "NC2045 p.61"},
		"fast_eddie": {"name": "Fast Eddie", "rank": 1, "roles": "Fixer 1", "district": "little_europe", "location": "little_europe_6", "deals_in": ["guide"], "cite": "NC2045 p.59"},
		"polly": {"name": "Polly", "rank": 3, "roles": "Fixer 3", "district": "little_europe", "location": "little_europe_17", "deals_in": ["information"], "cite": "NC2045 p.62"},

		"walt_henshaw": {"name": "Corporal Walt Henshaw", "rank": 4, "roles": "Fixer 4", "district": "norcal_military_base", "location": "", "deals_in": ["drugs", "supplies"], "cite": "NC2045 p.185"},

		"barry_delvecchio": {"name": "Barry \"Big Deal\" Delvecchio", "rank": 6, "roles": "Fixer 6", "district": "north_heywood", "location": "north_heywood_14", "deals_in": ["favours", "property"], "cite": "NC2045 p.247, p.252"},
		"john_freeman": {"name": "John \"The Professor\" Freeman", "rank": 8, "roles": "Fixer 8", "district": "north_heywood", "location": "north_heywood_8", "deals_in": ["veterans"], "cite": "NC2045 p.250, p.253"},
		"marianne_freeman": {"name": "Marianne Freeman", "rank": 6, "roles": "Fixer 6/Tech 4", "district": "north_heywood", "location": "north_heywood_8", "deals_in": ["veterans", "combat"], "cite": "NC2045 p.250, p.253"},
		"nana_meow": {"name": "Nana Meow", "rank": 4, "roles": "Fixer 4", "district": "north_heywood", "location": "north_heywood_11", "deals_in": ["food", "supplies"], "cite": "NC2045 p.250-251"},
		"crux": {"name": "Crux", "rank": 4, "roles": "Fixer 4", "district": "north_heywood", "location": "north_heywood_15", "deals_in": ["fights", "betting"], "cite": "NC2045 p.252"},
		"monique_curse": {"name": "Monique Curse", "rank": 3, "roles": "Fixer 3", "district": "north_heywood", "location": "north_heywood_1", "deals_in": ["drugs", "crime"], "cite": "NC2045 p.247"},
		"anika_raines": {"name": "Anika Raines", "rank": 3, "roles": "Fixer 3/Medtech 6", "district": "north_heywood", "location": "north_heywood_9", "deals_in": ["ids", "exfiltration", "medical"], "cite": "NC2045 p.251"},
		"riley": {"name": "Riley", "rank": 3, "roles": "Fixer 3/Tech 3", "district": "north_heywood", "location": "north_heywood_12", "deals_in": ["braindance", "entertainment"], "cite": "NC2045 p.251"},
		"billy_flight": {"name": "Billy Flight", "rank": 3, "roles": "Fixer 3/Tech 2", "district": "north_heywood", "location": "north_heywood_18", "deals_in": ["vehicles"], "cite": "NC2045 p.253"},
		"ella_corella": {"name": "Ella Corella", "rank": 2, "roles": "Fixer 2", "district": "north_heywood", "location": "north_heywood_18", "deals_in": ["supplies", "information"], "cite": "NC2045 p.253"},

		"phoenix_redwyne": {"name": "Phoenix Redwyne", "rank": 6, "roles": "Medtech 7/Fixer 6", "district": "old_combat_zone", "location": "old_combat_zone_7", "deals_in": ["medical", "supplies"], "cite": "NC2045 p.170"},
		"mal_devincher": {"name": "Mal \"Flasher\" Devincher", "rank": 2, "roles": "Fixer 2", "district": "old_combat_zone", "location": "old_combat_zone_6", "deals_in": ["supplies", "information"], "cite": "NC2045 p.170"},
		"blades": {"name": "Blades", "rank": 2, "roles": "Fixer 2", "district": "old_combat_zone", "location": "old_combat_zone_5", "deals_in": ["crime"], "cite": "NC2045 p.173"},

		"hornet": {"name": "Hornet", "rank": 9, "roles": "Fixer 9/Medtech 4/Tech 4", "district": "old_japantown", "location": "old_japantown_4", "deals_in": ["cyberware", "combat", "crime"], "cite": "NC2045 p.129, p.131, p.136"},
		"yomotsu_hirasaka": {"name": "Yomotsu Hirasaka", "rank": 5, "roles": "Fixer 5", "district": "old_japantown", "location": "old_japantown_1", "deals_in": ["antiques"], "cite": "NC2045 p.129"},
		"kanezou_tsuruta": {"name": "Kanezou Tsuruta", "rank": 5, "roles": "Fixer 5", "district": "old_japantown", "location": "old_japantown_7", "deals_in": ["food", "crime"], "cite": "NC2045 p.131"},
		"hiro": {"name": "Hiro", "rank": 5, "roles": "Fixer 5", "district": "old_japantown", "location": "old_japantown_9", "deals_in": ["vehicles"], "cite": "NC2045 p.132"},
		"mrs_suzuki": {"name": "Mrs. Suzuki", "rank": 5, "roles": "Exec 6/Fixer 5", "district": "old_japantown", "location": "old_japantown_16", "deals_in": ["food", "supplies"], "cite": "NC2045 p.133-134"},
		"kotone_shiomi": {"name": "Kotone Shiomi", "rank": 5, "roles": "Rockerboy 2/Fixer 5", "district": "old_japantown", "location": "old_japantown_24", "deals_in": ["entertainment"], "cite": "NC2045 p.135"},
		"matsu": {"name": "Matsu", "rank": 3, "roles": "Fixer 3", "district": "old_japantown", "location": "", "deals_in": ["labour"], "cite": "NC2045 p.136"},

		"pawel_ward": {"name": "Paweł Ward", "rank": 4, "roles": "Fixer 4", "district": "outskirts", "location": "outskirts_12", "deals_in": ["betting"], "cite": "NC2045 p.299"},
		"ma_block": {"name": "Ma Block", "rank": 2, "roles": "Fixer 2", "district": "outskirts", "location": "outskirts_17", "deals_in": ["information"], "cite": "NC2045 p.300"},

		"cyrus_finch": {"name": "Cyrus Finch", "rank": 3, "roles": "Fixer 3/Media 3", "district": "pacifica_playground", "location": "pacifica_playground_1", "deals_in": ["information"], "cite": "NC2045 p.277-279"},
		"ojo": {"name": "Ojo", "rank": 6, "roles": "Fixer 6", "district": "pacifica_playground", "location": "pacifica_playground_6", "deals_in": ["vehicles"], "cite": "NC2045 p.280"},
		"dalton_knee": {"name": "Dalton \"Dizzy\" Knee", "rank": 5, "roles": "Fixer 5", "district": "pacifica_playground", "location": "pacifica_playground_16", "deals_in": ["salvage", "supplies"], "cite": "NC2045 p.282"},

		"ricky_hamilton": {"name": "Ricky Hamilton", "rank": 4, "roles": "Fixer 4", "district": "playland", "location": "", "deals_in": ["crime"], "cite": "NC2045 p.304"},

		"valya": {"name": "Valya", "rank": 6, "roles": "Fixer 6", "district": "port_of_night_city", "location": "port_of_night_city_1", "deals_in": ["crime", "smuggling"], "cite": "NC2045 p.153, p.156"},
		"william_maze": {"name": "William \"Mr. AMAAAZE!\" Maze", "rank": 8, "roles": "Fixer 8", "district": "port_of_night_city", "location": "port_of_night_city_2", "deals_in": ["salvage"], "cite": "NC2045 p.153"},
		"della_glass": {"name": "Della Glass", "rank": 5, "roles": "Fixer 5", "district": "port_of_night_city", "location": "port_of_night_city_8", "deals_in": ["supplies", "smuggling", "gigs"], "cite": "NC2045 p.155-156"},
		"skitter": {"name": "Skitter", "rank": 4, "roles": "Fixer 4", "district": "port_of_night_city", "location": "", "deals_in": ["salvage"], "cite": "NC2045 p.156"},

		"granny_bliss": {"name": "Granny Bliss", "rank": 5, "roles": "Fixer 5", "district": "rancho_coronado", "location": "rancho_coronado_7", "deals_in": ["gigs"], "cite": "NC2045 p.290"},
		"ms_mynah": {"name": "Ms. Mynah", "rank": 6, "roles": "Fixer 6", "district": "rancho_coronado", "location": "rancho_coronado_11", "deals_in": ["clothing"], "cite": "NC2045 p.291"},
		"ximena_rose": {"name": "Ximena Rose", "rank": 4, "roles": "Fixer 4/Nomad 1", "district": "rancho_coronado", "location": "rancho_coronado_11", "deals_in": ["crime", "nomads"], "cite": "NC2045 p.291"},

		"phoebe_baro": {"name": "Phoebe \"Deadeye\" Baro", "rank": 6, "roles": "Fixer 6", "district": "reclamation_zone", "location": "reclamation_zone_15", "deals_in": ["gigs", "betting", "weapons"], "cite": "NC2045 p.164"},
		"earl_mahoney": {"name": "Earl Mahoney", "rank": 4, "roles": "Fixer 4", "district": "reclamation_zone", "location": "reclamation_zone_3", "deals_in": ["supplies", "loans"], "cite": "NC2045 p.161"},

		"skinny_james": {"name": "Skinny James", "rank": 4, "roles": "Fixer 4/Nomad 2", "district": "santo_domingo", "location": "santo_domingo_2", "deals_in": ["nomads", "smuggling", "labour"], "cite": "NC2045 p.267-268"},
		"woodchipper": {"name": "Woodchipper", "rank": 5, "roles": "Fixer 5/Nomad 4", "district": "santo_domingo", "location": "santo_domingo_19", "deals_in": ["mediation", "nomads"], "cite": "NC2045 p.271"},
		"two_toes": {"name": "Two-Toes", "rank": 3, "roles": "Fixer 3/Medtech 3", "district": "santo_domingo", "location": "santo_domingo_13", "deals_in": ["cyberware", "medical"], "cite": "NC2045 p.270"},

		"garven_haakensen": {"name": "Garven Haakensen", "rank": 7, "roles": "Fixer 7", "district": "south_night_city", "location": "south_night_city_6", "deals_in": ["mediation", "favours"], "cite": "NC2045 p.139"},
		"melinda_joy": {"name": "Melinda Joy", "rank": 3, "roles": "Rockerboy 2/Fixer 3", "district": "south_night_city", "location": "south_night_city_3", "deals_in": ["supplies"], "cite": "NC2045 p.142"},
		"jessigames": {"name": "JessiGames", "rank": 4, "roles": "Fixer 4", "district": "south_night_city", "location": "south_night_city_13", "deals_in": ["fights", "betting"], "cite": "NC2045 p.146"},
		"jomari_jackson": {"name": "Jomari Jackson", "rank": 2, "roles": "Exec 2/Fixer 2", "district": "south_night_city", "location": "south_night_city_12", "deals_in": ["property"], "cite": "NC2045 p.145-146"},

		"mister_kernaghan": {"name": "Mister Kernaghan", "rank": 9, "roles": "Fixer 9", "district": "the_glen", "also": ["downtown", "executive_zone"], "location": "the_glen_8", "deals_in": ["luxury", "supplies", "favours"], "cite": "NC2045 p.119, p.80-81, p.235"},
		"kris_kane": {"name": "Kris Kane", "rank": 8, "roles": "Fixer 8", "district": "the_glen", "location": "the_glen_9", "deals_in": ["diplomacy"], "cite": "NC2045 p.120"},
		"zhao_li": {"name": "Zhao Li", "rank": 6, "roles": "Fixer 6", "district": "the_glen", "location": "the_glen_4", "deals_in": ["property", "crime"], "cite": "NC2045 p.118"},
		"ariel_flores": {"name": "Ariel Flores", "rank": 6, "roles": "Fixer 6", "district": "the_glen", "location": "the_glen_9", "deals_in": ["diplomacy", "ids"], "cite": "NC2045 p.120"},
		"kasymbek": {"name": "Kasymbek", "rank": 4, "roles": "Fixer 4", "district": "the_glen", "location": "the_glen_16", "deals_in": ["smuggling", "food"], "cite": "NC2045 p.122"},
		"edna_wilston": {"name": "Edna Wilston", "rank": 4, "roles": "Fixer 4", "district": "the_glen", "location": "the_glen_7", "deals_in": ["information"], "cite": "NC2045 p.126"},

		"edward_michaels": {"name": "Dr. Edward Michaels", "rank": 6, "roles": "Exec 4/Fixer 6/Tech 4", "district": "university_district", "location": "university_district_11", "deals_in": ["favours", "nomads"], "cite": "NC2045 p.105, p.109"},
		"bebe_gcabashe": {"name": "Bebe Gcabashe", "rank": 3, "roles": "Fixer 3", "district": "university_district", "location": "university_district_14", "deals_in": ["clothing"], "cite": "NC2045 p.111"},
		"jessie_stuart_hedley": {"name": "Jessie Stuart-Hedley", "rank": 2, "roles": "Fixer 2", "district": "university_district", "location": "university_district_19", "deals_in": ["information"], "cite": "NC2045 p.112"},

		"rogue_amendiares": {"name": "Rogue Amendiares", "rank": 7, "roles": "Solo 7/Fixer 7", "district": "upper_marina", "location": "upper_marina_1", "deals_in": ["combat", "gigs"], "cite": "NC2045 p.69"},
		"marion_robinson": {"name": "Marion Robinson", "rank": 6, "roles": "Fixer 6", "district": "upper_marina", "location": "upper_marina_4", "deals_in": ["loans", "investments"], "cite": "NC2045 p.69"},
		"patrice_marsh": {"name": "Patrice Marsh", "rank": 3, "roles": "Fixer 3", "district": "upper_marina", "location": "upper_marina_6", "deals_in": ["food"], "cite": "NC2045 p.70"},
		"will_maine": {"name": "Will Maine", "rank": 4, "roles": "Fixer 4", "district": "upper_marina", "location": "upper_marina_10", "deals_in": ["programs", "netrunning"], "cite": "NC2045 p.71"},
		"maurice": {"name": "Maurice", "rank": 3, "roles": "Fixer 3", "district": "upper_marina", "location": "upper_marina_21", "deals_in": ["luxury"], "cite": "NC2045 p.73"},
		"pixie_stix": {"name": "Pixie Stix", "rank": 3, "roles": "Fixer 3", "district": "upper_marina", "location": "upper_marina_31", "deals_in": ["information"], "cite": "NC2045 p.76"},
		"lola_lola": {"name": "Lola Lola", "rank": 4, "roles": "Rockerboy 4/Fixer 4", "district": "upper_marina", "location": "upper_marina_15", "deals_in": ["art", "drugs"], "cite": "NC2045 p.67, p.72"},
		"ricardo_ashanti": {"name": "Ricardo Ashanti", "rank": 3, "roles": "Fixer 3/Exec 5", "district": "upper_marina", "location": "", "deals_in": ["property", "construction"], "cite": "NC2045 p.66-79"},
		"dino_dinovic": {"name": "Dino Dinovic", "rank": 4, "roles": "Fixer 4", "district": "upper_marina", "location": "", "deals_in": ["drugs"], "cite": "NC2045 p.66-79"},

		"bobby_ballard": {"name": "Bobby \"Buggy\" Ballard", "rank": 5, "roles": "Fixer 5", "district": "watson_development", "location": "watson_development_5", "deals_in": ["weapons"], "cite": "NC2045 p.189"},
		"morgan": {"name": "Morgan", "rank": 3, "roles": "Fixer 3", "district": "watson_development", "location": "watson_development_15", "deals_in": ["weapons", "armor"], "cite": "NC2045 p.192"},
		"dahlia_vdb": {"name": "Dahlia VDB", "rank": 5, "roles": "Netrunner 2/Fixer 5", "district": "watson_development", "location": "watson_development_13", "deals_in": ["netrunning", "information"], "cite": "NC2045 p.196"},
		"akira_119": {"name": "Akira-119", "rank": 5, "roles": "Fixer 5", "district": "watson_development", "location": "watson_development_34", "deals_in": ["vehicles"], "cite": "NC2045 p.196"},
		"jenny_nails": {"name": "Jenny Nails", "rank": 3, "roles": "Fixer 3/Solo 6", "district": "watson_development", "location": "watson_development_25", "deals_in": ["fights", "crime"], "cite": "NC2045 p.194"}
	}
}
```

## Canon fixers from Single Player Mode

The Single Player Mode book's NPCs by Role list ten canon Fixers (SPM p.57). Six are already above from
NC2045: 3-Piece, Mister Kernaghan, Ms. Mynah, Woodchipper, Flasher (Mal "Flasher" Devincher) and Willy Maze
(William "Mr. AMAAAZE!" Maze, Port of Night City). The other four follow. SPM gives each a one-line note but
no Fixer rank and no district, so each has `district` `""` and a rank picked from the note.
HOUSE-RULE: the ranks (SPM prints none).

**Grease.** A street-level Fixer who is still making his name; a natural first contact for a crew nobody
knows. Rank 2 (HOUSE-RULE). *(SPM p.57.)*

```world fixers.fixers.grease
{"name": "Grease", "rank": 2, "roles": "Fixer 2", "district": "", "location": "", "deals_in": ["gigs", "combat"], "cite": "SPM p.57"}
```

**Lowball.** A Fixer whose clients are corporations. Rank 5 (HOUSE-RULE). *(SPM p.57.)*

```world fixers.fixers.lowball
{"name": "Lowball", "rank": 5, "roles": "Fixer 5", "district": "", "location": "", "deals_in": ["gigs", "information"], "cite": "SPM p.57"}
```

**Molly Anderson.** Leads the Andersons, an ageing family yogang (`factions.andersons`, whose scavvers and
thieves feed her Night Market supply chain, NC2045 p.33; the gang has no fixed territory). Rank 4
(HOUSE-RULE). *(SPM p.57; NC2045 p.33.)*

```world fixers.fixers.molly_anderson
{"name": "Molly Anderson", "rank": 4, "roles": "Fixer 4", "district": "", "location": "", "deals_in": ["salvage", "crime", "supplies"], "faction": "andersons", "cite": "SPM p.57; NC2045 p.33"}
```

**Rex Royale.** A casino-themed Fixer who sells weapons and combat gear. Rank 5 (HOUSE-RULE). *(SPM p.57.)*

```world fixers.fixers.rex_royale
{"name": "Rex Royale", "rank": 5, "roles": "Fixer 5", "district": "", "location": "", "deals_in": ["weapons", "armor", "betting"], "cite": "SPM p.57"}
```
