# Night City map geometry

Schematic geography for the game's own city map: where each district sits, a coarse outline, who borders whom,
the water, the NCART lines and the bridges. It is our own simplified trace of the district map (NC2045 p.9),
normalised to a 1000 x 1000 box with north up; it is not the book's map art and is not meant to be drawn as such.

How it was read:

- **Layout** (p.9): the Island (Little Europe, Downtown, the Hot Zone crater, Upper Marina, Little China, University,
  South Night City, the Port, Reclamation, the Glen, Old Japantown, the Old Combat Zone) sits between the bay to the
  west and north and the Morro canal to the south-east. Northside (the NorCal base on its peninsula, Watson, the
  narrow Kabuki strip, New Westbrook) lies across the bay to the north; Charter Hill wraps the walled Executive Zone
  on the north-east; the Heywoods and Santo Domingo lie south-east of the canal; Pacifica and Rancho Coronado form
  the south shore. Playland is the pier at Pacifica's south-west corner, the Orange Line's last stop (p.28, p.278).
  The Outskirts are everything beyond the city limit, out to the box edge.
- **Outlines** follow the dotted district borders on p.9, cut down to 6-12 points (the Outskirts ring has more).
  Borders the map leaves vague were settled with the district maps: Watson runs up to the north edge between the
  base and New Westbrook (p.188), and the Little Europe / Downtown line, which the book says is redrawn every
  year, is put at Morro Rock Boulevard.
- **NCART** (p.28): each line lists the districts its stations fall in, in station order (a district may recur when
  a line doubles back). Stations are placed by the district docs' own NCART lists; unnamed ones were read off the
  flashmap. The Executive monorail (Lazarus-run, Exec Rank 4+, p.19) is included as `exec_monorail`.
- **Bands** (p.18-20): average travel time per district crossed depends on Security Code: code 6+ is fast
  (15 min driving, 20 by NCART), 4-5 is middling (20 / 30), 3 or lower is slow (30 / 40); halve it by AV,
  triple it on foot. `band` is high / mid / low from `city.districts.<id>.security_code.n`.
- **Bridges**: road or rail crossings over water: the bay bridges from Watson to Little Europe, the channel
  crossing by Upper Marina, the canal crossing from Old Japantown to the Docks, and the road and Orange Line bridges
  from the Glen and Reclamation to Pacifica. The Del Coronado Bay tunnel (Watson to the Glen, p.19) is not listed.

```world city.map
{
	"_doc": "Schematic geography of Night City for the game's own schematic city map: our coarse trace of the NC2045 district map, normalised to bounds w x h (0..1000, north up); not the book's map art. water: polygons for the bay, ocean, Morro canal, the Kabuki lagoon and the east lake (draw over land). districts.<id>: x, y label anchor; r approx radius; outline a coarse polygon (neighbouring outlines may overlap or leave slivers); neighbours share a border or a bridge; band is the travel-time band from the district's Security Code (high >= 6, mid 4-5, low <= 3; p.18-20: NCART 20/30/40 min per district, driving 15/20/30). The outskirts outline is the land beyond the city limit (a C-shaped ring round the city to the map edge). ncart: NCART line -> districts it runs through in station order (p.28), plus the Exec monorail. bridges: road or rail crossings over water between districts. Land under no outline (the offshore spaceport site west of Little Europe) is plain land.",
	"bounds": {"w": 1000, "h": 1000},
	"water": [
		[[0, 104], [204, 86], [292, 114], [368, 148], [348, 186], [288, 198], [218, 272], [270, 266], [316, 312], [352, 356], [436, 354], [436, 382], [364, 386], [292, 393], [260, 404], [248, 380], [244, 336], [128, 336], [0, 336]],
		[[0, 336], [120, 336], [124, 432], [244, 432], [248, 380], [260, 404], [254, 460], [242, 468], [244, 524], [264, 580], [288, 606], [324, 620], [372, 622], [424, 598], [440, 630], [404, 646], [324, 634], [276, 654], [248, 678], [244, 724], [0, 768]],
		[[424, 598], [546, 466], [560, 470], [556, 486], [440, 630], [428, 616]],
		[[420, 358], [440, 336], [456, 342], [484, 380], [520, 428], [512, 434], [480, 404], [440, 382]],
		[[624, 592], [652, 588], [692, 608], [748, 636], [716, 668], [660, 708], [624, 708], [618, 660], [636, 628]]
	],
	"districts": {
		"charter_hill": {"x": 544, "y": 364, "r": 38, "band": "high",
			"outline": [[538, 328], [572, 330], [600, 346], [604, 376], [568, 368], [552, 362], [552, 404], [564, 432], [544, 444], [522, 444], [520, 404], [534, 388]],
			"neighbours": ["executive_zone", "heywood_docks", "little_china", "new_westbrook", "north_heywood", "outskirts", "upper_marina"]},
		"downtown": {"x": 318, "y": 454, "r": 33, "band": "high",
			"outline": [[282, 434], [310, 431], [356, 430], [353, 464], [350, 478], [290, 478], [284, 468], [276, 466]],
			"neighbours": ["hot_zone", "little_europe", "university_district"]},
		"executive_zone": {"x": 579, "y": 400, "r": 31, "band": "high",
			"outline": [[552, 362], [584, 374], [604, 378], [606, 412], [600, 428], [580, 434], [564, 430], [554, 408]],
			"neighbours": ["charter_hill", "north_heywood", "outskirts"]},
		"heywood_docks": {"x": 546, "y": 508, "r": 36, "band": "high",
			"outline": [[529, 444], [558, 438], [570, 464], [574, 492], [576, 526], [556, 540], [530, 568], [502, 552], [480, 580], [462, 606], [556, 486], [544, 466]],
			"neighbours": ["charter_hill", "heywood_industrial_zone", "little_china", "north_heywood", "old_japantown", "santo_domingo"]},
		"heywood_industrial_zone": {"x": 495, "y": 592, "r": 30, "band": "high",
			"outline": [[502, 552], [530, 568], [518, 594], [502, 620], [484, 630], [466, 618], [458, 602], [480, 580]],
			"neighbours": ["heywood_docks", "north_heywood", "santo_domingo"]},
		"hot_zone": {"x": 404, "y": 460, "r": 52, "band": "low",
			"outline": [[360, 412], [416, 414], [454, 438], [462, 460], [456, 488], [440, 502], [388, 506], [360, 496], [352, 472], [356, 430]],
			"neighbours": ["downtown", "little_china", "little_europe", "old_japantown", "the_glen", "university_district", "upper_marina"]},
		"kabuki": {"x": 429, "y": 312, "r": 36, "band": "high",
			"outline": [[426, 224], [430, 276], [448, 278], [450, 320], [468, 340], [440, 356], [404, 356], [410, 280]],
			"neighbours": ["new_westbrook", "watson_development"]},
		"little_china": {"x": 495, "y": 479, "r": 35, "band": "mid",
			"outline": [[462, 458], [522, 454], [529, 444], [544, 466], [498, 512], [460, 510], [456, 488]],
			"neighbours": ["charter_hill", "heywood_docks", "hot_zone", "old_japantown", "upper_marina"]},
		"little_europe": {"x": 304, "y": 418, "r": 40, "band": "high",
			"outline": [[260, 404], [296, 393], [340, 387], [366, 386], [360, 412], [356, 430], [310, 431], [282, 434], [276, 466], [254, 464], [252, 428]],
			"neighbours": ["downtown", "hot_zone", "university_district", "upper_marina", "watson_development"]},
		"new_westbrook": {"x": 488, "y": 296, "r": 68, "band": "high",
			"outline": [[430, 224], [464, 200], [500, 210], [528, 264], [540, 328], [534, 388], [520, 404], [484, 380], [456, 342], [450, 320], [448, 278], [430, 276]],
			"neighbours": ["charter_hill", "kabuki", "outskirts", "upper_marina", "watson_development"]},
		"norcal_military_base": {"x": 330, "y": 229, "r": 65, "band": "high",
			"outline": [[218, 272], [248, 228], [288, 198], [348, 186], [364, 146], [382, 140], [368, 174], [400, 196], [420, 216], [412, 240], [400, 258], [364, 270]],
			"neighbours": ["outskirts", "watson_development"]},
		"north_heywood": {"x": 604, "y": 540, "r": 54, "band": "high",
			"outline": [[558, 438], [584, 434], [602, 502], [658, 530], [644, 558], [614, 622], [588, 594], [564, 578], [530, 568], [556, 540], [576, 526], [570, 464]],
			"neighbours": ["charter_hill", "executive_zone", "heywood_docks", "heywood_industrial_zone", "outskirts", "santo_domingo"]},
		"old_combat_zone": {"x": 427, "y": 573, "r": 26, "band": "low",
			"outline": [[412, 548], [442, 550], [470, 550], [428, 594], [404, 610], [398, 598], [404, 580]],
			"neighbours": ["old_japantown", "the_glen"]},
		"old_japantown": {"x": 447, "y": 525, "r": 32, "band": "mid",
			"outline": [[412, 506], [440, 502], [456, 488], [460, 510], [498, 512], [470, 550], [442, 550], [412, 548]],
			"neighbours": ["heywood_docks", "hot_zone", "little_china", "old_combat_zone", "the_glen"]},
		"pacifica_playground": {"x": 332, "y": 695, "r": 65, "band": "high",
			"outline": [[276, 654], [356, 638], [436, 642], [448, 668], [408, 662], [376, 696], [340, 732], [340, 778], [312, 777], [280, 758], [264, 732], [270, 696]],
			"neighbours": ["outskirts", "playland", "rancho_coronado", "reclamation_zone", "santo_domingo", "the_glen"]},
		"playland": {"x": 257, "y": 704, "r": 19, "band": "high",
			"outline": [[248, 678], [262, 674], [271, 696], [266, 732], [254, 728], [244, 708]],
			"neighbours": ["outskirts", "pacifica_playground"]},
		"port_of_night_city": {"x": 268, "y": 548, "r": 31, "band": "high",
			"outline": [[242, 506], [280, 506], [282, 548], [294, 566], [286, 584], [288, 606], [270, 594], [256, 572], [244, 532]],
			"neighbours": ["reclamation_zone", "south_night_city", "university_district"]},
		"rancho_coronado": {"x": 422, "y": 736, "r": 69, "band": "low",
			"outline": [[408, 662], [448, 668], [468, 700], [500, 722], [486, 772], [468, 806], [440, 808], [404, 776], [340, 778], [340, 732], [376, 696]],
			"neighbours": ["outskirts", "pacifica_playground", "santo_domingo"]},
		"reclamation_zone": {"x": 317, "y": 588, "r": 32, "band": "high",
			"outline": [[294, 566], [310, 550], [334, 554], [336, 588], [344, 602], [364, 618], [324, 620], [288, 606], [286, 584]],
			"neighbours": ["pacifica_playground", "port_of_night_city", "south_night_city", "the_glen"]},
		"santo_domingo": {"x": 536, "y": 653, "r": 78, "band": "high",
			"outline": [[440, 630], [458, 602], [484, 630], [518, 594], [530, 568], [588, 594], [614, 622], [628, 652], [602, 708], [500, 722], [460, 688], [436, 648]],
			"neighbours": ["heywood_docks", "heywood_industrial_zone", "north_heywood", "outskirts", "pacifica_playground", "rancho_coronado"]},
		"south_night_city": {"x": 309, "y": 530, "r": 30, "band": "mid",
			"outline": [[280, 506], [340, 506], [338, 540], [334, 554], [310, 550], [294, 566], [282, 548]],
			"neighbours": ["port_of_night_city", "reclamation_zone", "the_glen", "university_district"]},
		"the_glen": {"x": 373, "y": 557, "r": 48, "band": "high",
			"outline": [[340, 506], [388, 506], [412, 506], [412, 548], [404, 580], [398, 598], [396, 610], [364, 618], [344, 602], [336, 588], [334, 554], [338, 540]],
			"neighbours": ["hot_zone", "old_combat_zone", "old_japantown", "pacifica_playground", "reclamation_zone", "south_night_city", "university_district"]},
		"university_district": {"x": 294, "y": 490, "r": 34, "band": "high",
			"outline": [[242, 468], [276, 466], [290, 478], [352, 478], [360, 496], [340, 506], [242, 506]],
			"neighbours": ["downtown", "hot_zone", "little_europe", "port_of_night_city", "south_night_city", "the_glen"]},
		"upper_marina": {"x": 447, "y": 416, "r": 44, "band": "high",
			"outline": [[366, 386], [436, 382], [460, 390], [484, 404], [512, 434], [524, 438], [522, 454], [462, 458], [454, 438], [416, 414], [360, 412]],
			"neighbours": ["charter_hill", "hot_zone", "little_china", "little_europe", "new_westbrook"]},
		"watson_development": {"x": 364, "y": 300, "r": 66, "band": "high",
			"outline": [[270, 268], [400, 258], [420, 216], [368, 174], [382, 140], [408, 130], [454, 200], [426, 224], [410, 280], [404, 356], [352, 356], [316, 312]],
			"neighbours": ["kabuki", "little_europe", "new_westbrook", "norcal_military_base", "outskirts"]},
		"outskirts": {"x": 764, "y": 588, "r": 385, "band": "mid",
			"outline": [[0, 0], [1000, 0], [1000, 1000], [0, 1000], [0, 768], [244, 724], [264, 732], [280, 758], [340, 778], [404, 776], [440, 808], [468, 806], [500, 722], [602, 708], [628, 652], [614, 622], [658, 530], [602, 502], [584, 434], [606, 412], [600, 346], [540, 328], [528, 264], [500, 210], [454, 200], [408, 130], [382, 140], [368, 148], [292, 114], [204, 86], [0, 104]],
			"neighbours": ["charter_hill", "executive_zone", "new_westbrook", "norcal_military_base", "north_heywood", "pacifica_playground", "playland", "rancho_coronado", "santo_domingo", "watson_development"]}
	},
	"ncart": {
		"red": ["watson_development", "little_europe", "upper_marina", "little_china", "heywood_docks", "heywood_industrial_zone"],
		"green": ["watson_development", "new_westbrook", "charter_hill", "north_heywood", "heywood_industrial_zone", "santo_domingo"],
		"blue": ["little_europe", "downtown", "little_europe", "university_district", "south_night_city", "the_glen"],
		"orange": ["south_night_city", "port_of_night_city", "reclamation_zone", "the_glen", "pacifica_playground", "playland"],
		"exec_monorail": ["executive_zone", "charter_hill", "upper_marina", "new_westbrook", "watson_development", "little_europe", "downtown", "university_district", "the_glen", "old_japantown", "north_heywood"]
	},
	"bridges": [["watson_development", "little_europe"], ["upper_marina", "new_westbrook"], ["old_japantown", "heywood_docks"], ["the_glen", "pacifica_playground"], ["reclamation_zone", "pacifica_playground"]],
	"cite": "NC2045 p.9, p.18-20, p.28"
}
```
