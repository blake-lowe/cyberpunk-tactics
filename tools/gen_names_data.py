#!/usr/bin/env python3
"""Builds the name data the game draws people's names and street handles from (src/meta/names.gd):

    data/gen/names.json        given names (masc, femme, neutral) and family names per culture
    data/gen/handles.json      handle word pools, patterns and a curated list of street handles
    data/gen/name_filter.json  the profanity and slur filter, reserved (canon) and famous names

Sources (licences and provenance in assets/third_party/names/README.md and in each file):
  - Wikidata (CC0): given names (P735) and family names (P734) of people by citizenship (P27),
    counted per name, with the name item's English label and type (male/female/unisex given name);
    and name items by language (P407), most linked first (the search API: it rate-limits far less
    than the query service, which allowed only a few countries' counts per quarter hour).
  - sigpwned/popular-names-by-country-dataset (CC0): top given names by sex and surnames by country.
  - US Census Bureau, 2010 Census surnames (public domain, US government work), with the share of
    each surname by race and Hispanic origin.
  - dariusk/corpora (CC0): word lists the handle pools pick from.
  - LDNOOBW, "List of Dirty, Naughty, Obscene, and Otherwise Bad Words" (CC BY 4.0): the filter.
  - Words, handles and filter supplements written for this project.
The Single Player Mode book's name and handle tables (SPM p.52-55) were a style guide only: none of
their lists are copied.

Run from the repo root:
    python3 tools/gen_names_data.py --cache DIR --fetch   # download what DIR lacks, then build
    python3 tools/gen_names_data.py --cache DIR           # build from DIR
Downloads use curl with its default user agent; Wikidata queries honour Retry-After.
"""
import argparse
import csv
import io
import json
import os
import re
import subprocess
import sys
import time
import unicodedata
import zipfile

OUT = "data/gen"
FONTS = ["assets/fonts/ChakraPetch-Bold.ttf", "assets/fonts/ChakraPetch-SemiBold.ttf", "assets/fonts/Jersey10-Regular.ttf"]

CENSUS_URL = "https://www2.census.gov/topics/genealogy/2010surnames/names.zip"
CORPORA = "https://cdn.jsdelivr.net/gh/dariusk/corpora@master/data/"   # jsDelivr's mirror of github.com/dariusk/corpora
SIGPWNED = "https://cdn.jsdelivr.net/gh/sigpwned/popular-names-by-country-dataset@main/"   # mirror of github.com/sigpwned/popular-names-by-country-dataset
LDNOOBW_URL = "https://raw.githubusercontent.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words/master/en"
WDQS = "https://query.wikidata.org/sparql"
WDAPI = "https://www.wikidata.org/w/api.php"
WD_COUNT = "SELECT ?name (COUNT(?p) AS ?n) WHERE { ?p wdt:P27 wd:%s ; wdt:%s ?name . } GROUP BY ?name HAVING (COUNT(?p) > 1)"
MALE_NAME, FEMALE_NAME, UNISEX_NAME = "Q12308941", "Q11879590", "Q3409032"

# Night City's mix (HOUSE-RULE: a 2045 West Coast free city, heavily Latino and Asian; the core book
# and SPM give no census). weight = share of people; countries = Wikidata ids of the citizenships
# whose names the culture draws on; census = which 2010 Census surnames join its family names.
CULTURES = {
    "anglo": {"name": "Anglo", "weight": 15, "iso": ["US", "GB", "CA", "AU", "IE", "NZ", "JM"], "countries": ["Q30", "Q145", "Q16", "Q408", "Q27", "Q664", "Q766"], "census": "anglo"},
    "latino": {"name": "Latino", "weight": 20, "iso": ["MX", "CO", "AR", "ES", "CU", "CL", "PE", "VE", "DO", "GT", "SV", "PR", "EC", "BO", "PY", "UY", "PA", "CR"], "countries": ["Q96", "Q739", "Q414", "Q29", "Q241", "Q298", "Q419", "Q717", "Q786", "Q774", "Q792"], "census": "hispanic"},
    "lusophone": {"name": "Brazilian and Portuguese", "weight": 3, "iso": ["BR", "PT"], "countries": ["Q155", "Q45"]},
    "japanese": {"name": "Japanese", "weight": 7, "iso": ["JP"], "ascii": True, "countries": ["Q17"]},
    "chinese": {"name": "Chinese", "weight": 9, "iso": ["CN", "TW"], "ascii": True, "countries": ["Q148", "Q865"]},
    "korean": {"name": "Korean", "weight": 4, "iso": ["KR"], "ascii": True, "countries": ["Q884"]},
    "southeast_asian": {"name": "Southeast Asian", "weight": 7, "iso": ["VN", "PH", "TH", "ID", "MY", "KH"], "ascii": True, "countries": ["Q881", "Q928", "Q869", "Q252", "Q833"]},
    "south_asian": {"name": "South Asian", "weight": 7, "iso": ["IN", "PK", "BD", "LK", "NP"], "countries": ["Q668", "Q843", "Q902", "Q854", "Q837"]},
    "african": {"name": "African", "weight": 7, "iso": ["NG", "GH", "KE", "ET", "ZA", "SN", "CM", "CD", "UG", "TZ", "ZW", "CI", "SO", "ML"], "countries": ["Q1033", "Q117", "Q114", "Q115", "Q258", "Q1041", "Q1009", "Q974", "Q1036", "Q924", "Q954", "Q1008", "Q1045"]},
    "eastern_european": {"name": "Eastern European", "weight": 6, "iso": ["RU", "UA", "PL", "CZ", "RS", "HR", "RO", "HU", "BG", "LT", "BY", "SK", "SI", "BA", "ME", "MK", "MD", "LV", "EE", "AL", "XK"], "countries": ["Q159", "Q212", "Q36", "Q213", "Q403", "Q224", "Q218", "Q28", "Q219", "Q37", "Q184"], "gendered_family": True},
    "middle_eastern": {"name": "Middle Eastern and North African", "weight": 6, "iso": ["IR", "TR", "EG", "LB", "SY", "IQ", "IL", "SA", "MA", "AM", "JO", "DZ", "AE", "KW", "LY", "TN", "AZ", "GE"], "countries": ["Q794", "Q43", "Q79", "Q822", "Q858", "Q796", "Q801", "Q851", "Q1028", "Q399", "Q810", "Q262", "Q889"]},
    "european": {"name": "Western European", "weight": 5, "iso": ["DE", "FR", "NL", "IT", "SE", "NO", "DK", "FI", "GR", "BE", "AT", "CH", "LU", "IS"], "countries": ["Q183", "Q142", "Q55", "Q38", "Q34", "Q20", "Q35", "Q33", "Q41", "Q31", "Q40"]},
    "pacific": {"name": "Pacific Islander", "weight": 1, "iso": ["WS", "TO", "FJ", "PF"], "countries": ["Q683", "Q678"]},
}
# Wikidata name items by language (P407 "language of work or name"), most linked first (Wikidata's
# search, sorted by incoming links: roughly, how many people carry the name). Fills the cultures whose
# people rarely have P735/P734 set (Chinese, Korean, South Asian, African family names...).
LANGS = {
    "anglo": [], "japanese": ["Q5287"],   # Anglo: well covered by the citizenship counts and the Census
    "latino": ["Q1321"], "lusophone": ["Q5146"],
    "chinese": ["Q7850", "Q727694", "Q9186"], "korean": ["Q9176"],
    "southeast_asian": ["Q9199", "Q34057", "Q9217", "Q9240", "Q9237"],
    "south_asian": ["Q1568", "Q9610", "Q1617", "Q5885", "Q58635", "Q1571", "Q8097", "Q13267", "Q33823", "Q5137"],
    "african": ["Q34311", "Q33578", "Q56475", "Q7838", "Q28244", "Q10179", "Q28026", "Q13275", "Q34257", "Q13218", "Q34004", "Q33368"],
    "eastern_european": ["Q7737", "Q8798", "Q809", "Q9056", "Q9299", "Q6654", "Q7913", "Q9067", "Q7918", "Q9083", "Q9058"],
    "middle_eastern": ["Q13955", "Q9168", "Q256", "Q9288", "Q8785", "Q36368", "Q58680"],
    "european": ["Q188", "Q150", "Q7411", "Q652", "Q9027", "Q9043", "Q9035", "Q1412", "Q9129"],
    "pacific": ["Q34011", "Q34094", "Q33569", "Q36451", "Q33295"],
}
FAMILY_NAME = "Q101352"
# Mandarin given names are mostly two syllables picked for meaning, so lists of whole names are short
# everywhere (Wikidata rarely has items for them). Authored for this project: common pinyin syllables
# that lean masculine or feminine (or either); a culture's lists are topped up with two-syllable
# names built from them, likeliest pairs first.
COMPOSE = {
    "chinese": {
        "masc": "Hao Jun Wei Jie Ming Tao Lei Bo Qiang Peng Gang Long Jian Kai Cheng Zhi Yong Hong Feng Bin Hui Xiang Rui Yu Zi".split(),
        "femme": "Mei Ling Xin Yan Jing Hui Fang Na Lan Xiu Ying Qing Yue Lian Ning Shan Xue Li Ting Yi Wen Jia Yu Zi Hua".split(),
        "second": {"masc": "yu ran ze xuan hao chen yang ming jie wei long yi bo tao hui".split(),
                   "femme": "xin han yi ting jing yan ling mei qi xuan tong yue ning lin wen".split()},
    },
}

SEARCH_N = {MALE_NAME: 300, FEMALE_NAME: 300, UNISEX_NAME: 100, FAMILY_NAME: 400}   # per language, at most (one call each)
GIVEN_N = {"masc": 200, "femme": 200, "neutral": 50}   # per culture, the most common
META_TOP = {"given": 450, "family": 200}   # per country, the names looked up (twice as many for DEEP)
DEEP = {c for cfg in CULTURES.values() if len(cfg["countries"]) <= 2 for c in cfg["countries"]}
FAMILY_N = 300
CENSUS_N = {"anglo": 500, "hispanic": 300}
SMALL = 3   # cultures of weight below this keep half as many
# Gendered surname forms (Novak/Nováková, Kowalski/Kowalska, Ivanov/Ivanova, Kazlauskas/Kazlauskienė).
FEMME_ENDS = ("ová", "ova", "eva", "ina", "aya", "ska", "cka", "dzka", "ská", "cká", "ienė", "aitė", "ytė", "utė", "ūtė")
MASC_ENDS = ("ov", "ev", "in", "sky", "ski", "cki", "dzki", "ský", "cký", "as", "is", "us", "ys")
# HOUSE-RULE: how often a person's family name comes from another culture than their given name.
FAMILY_MIX = 0.2
# How a gender's given name is drawn: from which lists, with what weight.
GIVEN_MIX = {"masc": {"masc": 0.92, "neutral": 0.08}, "femme": {"femme": 0.92, "neutral": 0.08},
             "nonbinary": {"neutral": 0.7, "masc": 0.15, "femme": 0.15}}


# --- Handle words ---------------------------------------------------------------------------------
# Each pool: (source, words). A corpora source names the file the words were picked from; the pick
# is curated (street-flavoured, short, no trademarks or famous names). "authored" pools were written
# for this project, after the kinds of word SPM p.55's Handles table suggests (an animal, a colour,
# a gemstone, a Greek letter, a military rank, a playing card, a weapon, a natural disaster...).
WORDS = {
    "adjective": ("corpora data/words/adjs.json, data/humans/moods.json", """
        Blackened Brazen Bronze Charcoal Cosmic Crypto Defaced Deviant Devilish Dread Elastic Fearless
        Flawed Foggy Freelance Gilded Glaring Gleaming Hooded Ignited Indigo Livid Lucid Luckless Metallic
        Mighty Mirrored Morbid Motley Muted Mythic Networked Nitrous North Outlaw Primal Razed Recycled
        Regal Rubber Scarlet Shadowy Shiny Sleek Sleepless Smokeless Stainless Starlight Stolen Synthetic
        Twisted Unmasked Upstart Valiant Vinyl Wireless Vaunted Visceral Tanked Suave Sticky Spiky Speedy
        Bitter Brave Calm Cold Cross Daring Defiant Desperate Devious Edgy Feisty Frantic Furious Guarded
        Haunted Jaded Manic Moody Restless Ruthless Savage Sober Somber Spiteful Stoic Sullen Wary Weary
        Wistful Brooding Callous Caustic Cynical Dazed Detached Dismal Dreamy Dreary Empty Evasive Giddy
        Gloomy Groggy Grumpy Hollow Lonely Numb Reckless Smug Shaky Steady Tense Unhinged Vicious"""),
    "adjective_street": ("authored", """
        Dark Bright Dead Lucky Quick Wired Silent Feral Grim Mad Lone Slick Hard Sharp Burnt Static Rusty
        Iron Glass Zero Lost Wild Broken Blind Sly Swift Toxic Raw Velvet Atomic Turbo Hyper Mono Solar
        Lunar Polar Rapid Neon Chrome Cheap Dirty Crooked Bent Loose Lean Mean Tiny Big Little Old Young
        Sweet Sour Heavy Low High Fast Slow Late Early Sick Sleepy Lazy Hungry Pale Blank Hot Soft Tough
        Funky Stormy Rowdy Shady Sketchy Jumpy Twitchy Crusty Grimy Greasy Gritty Dusty Smoky Sparky
        Spooky Plucky Wonky Busted Bootleg Knockoff Secondhand Overclocked Underground Offworld Orbital
        Midnight Bulletproof Fireproof Hardwired Unplugged Off-Grid Gutter Backstreet
        Lowdown Uptown Downtown Crosstown Upstate Nocturnal Analog Digital Virtual Plastic Liquid Frozen
        Molten Electric Magnetic Radioactive Ultraviolet Infrared Silver Golden Copper Black White Red
        Blue Green Grey Violet Crimson Cobalt Rust Ashen Sunken Hungover Wide-Eyed Two-Faced"""),
    "colour": ("corpora data/colors/web_colors.json (single-word names) and authored", """
        Aqua Azure Black Blue Chartreuse Coral Crimson Cyan Gold Gray Green Indigo Ivory Khaki Lavender
        Lime Magenta Maroon Navy Olive Orchid Red Salmon Sienna Silver Teal Tomato Violet White Yellow
        Plum Orange Purple Tan Scarlet Vermilion Cerulean Ochre Umber Sepia Mauve Taupe Ebony Carmine
        Saffron Cinnabar Viridian Celadon Fuchsia Rose Ruby Jet Slate Ash Smoke Cream Bone Rust"""),
    "metal": ("corpora data/materials/layperson-metals.json, data/materials/metals.json, data/science/elements.json", """
        Chrome Cobalt Copper Iron Steel Titanium Tungsten Mercury Nickel Platinum Silver Gold Zinc Tin
        Brass Bronze Pewter Lead Radium Osmium Iridium Cesium Lithium Neon Argon Xenon Helium Carbon
        Plutonium Uranium Thorium Boron Sulfur Arsenic Bismuth Cadmium Chromium Gallium Indium Iodine
        Magnesium Palladium Rhodium Silicon Sodium Tantalum Thallium Vanadium Zirconium Electrum"""),
    "gem": ("corpora data/materials/gemstones.json", """
        Agate Amber Amethyst Beryl Coral Diamond Emerald Garnet Jade Jasper Jet Onyx Opal Pearl Quartz Ruby
        Sapphire Topaz Zircon Obsidian Flint Citrine Peridot Cinnabar Malachite Moonstone Sunstone Spinel
        Turquoise Carnelian Hematite Pyrite Azurite Iolite Kunzite Larimar Lapis Sodalite Tanzanite Rutile"""),
    "animal": ("corpora data/animals/common.json and authored", """
        Badger Bat Bear Boar Bull Cat Cheetah Cougar Coyote Crow Dingo Ferret Finch Fox Gopher Hyena Ibex
        Iguana Jackal Jaguar Lemur Leopard Lion Lizard Lynx Mink Mole Mongoose Moose Mule Mustang Newt
        Ocelot Otter Panther Puma Rat Ram Shrew Skunk Sloth Snake Tiger Toad Walrus Weasel Wildcat Wolf
        Wombat Yak Zebra Hog Viper Cobra Mamba Raven Hawk Falcon Kestrel Magpie Shrike Vulture Heron
        Osprey Condor Owl Shark Barracuda Eel Moray Scorpion Spider Wasp Hornet Mantis Locust Cricket
        Beetle Moth Firefly Tick Flea Roach Gecko Python Adder Asp Gator Jackdaw Rook Stingray Marlin
        Pike Gar Orca Squid Octopus Hound Mutt Stray Alleycat Mosquito Termite Cicada Hyena Dodo"""),
    "insect": ("authored", """
        Wasp Hornet Mantis Locust Cricket Beetle Moth Firefly Tick Flea Roach Cicada Termite Mosquito
        Weevil Midge Gnat Hoverfly Dragonfly Damselfly Earwig Silverfish Ladybug Scarab Aphid Botfly"""),
    "myth": ("corpora data/mythology/monsters.json, data/mythology/greek_monsters.json", """
        Bugbear Centaur Chimera Chupacabra Cyclops Djinn Dragon Draugr Gargoyle Genie Ghast Ghost Ghoul
        Giant Goblin Golem Gorgon Gremlin Griffon Harpy Hydra Imp Kappa Kobold Kraken Lich Manticore
        Minotaur Naga Ogre Oni Phoenix Pixie Poltergeist Roc Satyr Selkie Siren Spectre Sphinx Sprite
        Sylph Thunderbird Troll Valkyrie Warg Wendigo Wight Wraith Wyvern Yeti Zombie Typhon Lamia Mormo
        Charybdis Banshee Basilisk Bogeyman Revenant Shade Specter Phantom Kelpie Tengu Yokai Kitsune"""),
    "disaster": ("corpora data/geography/environmental_hazards.json, data/geography/winds.json and authored", """
        Avalanche Blizzard Cyclone Drought Hailstorm Landslide Lahar Mudslide Rockfall Tsunami Squall
        Monsoon Typhoon Tornado Twister Wildfire Tremor Sandstorm Whiteout Whirlwind Eclipse Comet Meteor
        Nova Zephyr Sirocco Mistral Chinook Bora Simoom Khamsin Firestorm Flashflood Aftershock Riptide
        Undertow Rockslide Brushfire Thunderhead Downpour Deluge Inferno Hurricane Wildfire Fallout Smog"""),
    "nature": ("corpora data/geography/geographic_features.json and authored", """
        Atoll Bayou Delta Fjord Geyser Quarry Reef Shore Tarn Weir Ridge Summit Glacier Mesa Butte Dune
        Marsh Bramble Thorn Moss Ash Cinder Ember Frost Flint Briar Ivy Nettle Thistle Hemlock Willow
        Cypress Cedar Birch Rowan Oak Pine Juniper Sage Clover Lotus Orchid Tide Surf Shoal Gulch Ravine
        Crag Cliff Boulder Pebble Gravel Silt Clay Peat Tundra Steppe Prairie Badlands Canyon Arroyo"""),
    "weapon": ("corpora data/objects/premodern_weapons.json and authored", """
        Dagger Falchion Scimitar Katana Knife Sabre Rapier Axe Club Flail Mace Maul Glaive Halberd Lance
        Pike Spear Whip Hammer Javelin Harpoon Boomerang Longbow Crossbow Sling Slingshot Blowgun Shiv
        Stiletto Cleaver Machete Shank Razor Blade Bullet Buckshot Slug Shrapnel Pistol Rifle Derringer
        Sixgun Grenade Flechette Garrote Kukri Bolo Kris Sai Tanto Cutlass Bayonet Musket Mortar Howitzer
        Carbine Shotgun Revolver Holdout Switchblade Butterfly Bowie Trident Cudgel Bludgeon Knuckles"""),
    "tool": ("authored", """
        Wrench Hammer Pliers Crowbar Chisel Spanner Drill Rivet Socket Torque Solder Ratchet Jack Vise Clamp
        Awl File Rasp Lever Pulley Winch Anvil Tongs Shears Scalpel Probe Gauge Plumb Trowel Hacksaw Bolt
        Nail Pickaxe Shovel Spade Sledge Mallet Grinder Lathe Jigsaw Bandsaw Router Crimper Multimeter
        Scope Torch Blowtorch Welder Hoist Jackhammer Wirecutter Prybar Tape Staple Hook Skewer"""),
    "greek": ("authored (the Greek alphabet)", """
        Alpha Beta Gamma Delta Epsilon Zeta Eta Theta Iota Kappa Lambda Mu Nu Xi Omicron Pi Rho Sigma
        Tau Upsilon Phi Chi Psi Omega"""),
    "rank": ("authored (military ranks)", """
        Private Corporal Sergeant Lieutenant Captain Major Colonel General Admiral Commodore Marshal
        Ensign Cadet Warrant Chief Gunny Sarge Skipper Commander Brigadier Provost Quartermaster"""),
    "card": ("authored (playing cards and games of chance)", """
        Ace Deuce Trey Jack Queen King Spade Club Diamond Wild Trump Flush Royal Blackjack Dealer Bluff
        River Kicker Ante Jackpot Snake Craps Roulette Keno Faro Domino Dice Gambit Wager Longshot Lucky"""),
    "tech": ("authored", """
        Byte Glitch Proxy Cache Daemon Kernel Patch Ping Root Socket Vector Pixel Signal Cipher Codec Router
        Wire Chip Circuit Diode Servo Relay Volt Amp Laser Plasma Sonar Radar Echo Fuse Spark Static Hex
        Hash Loop Null Void Zero Binary Buffer Cursor Script Packet Uplink Modem Node Mainframe Firewall
        Backdoor Overclock Baud Ohm Flux Pulse Qubit Cog Gear Piston Turbine Rotor Dynamo Transistor
        Capacitor Resistor Ion Photon Neutron Proton Quark Halogen Strobe Holo Optic Lens Prism Lag Spoof
        Hack Reboot Boot Kill Sudo Cron Grep Ping Bit Nibble Kilo Mega Giga Tera Nano Micro Pico Femto
        Logic Gate Bus Port Stack Heap Thread Fork Pipe Shell Token Sector Track Rig Deck Jack Link"""),
    "street": ("authored", """
        Hustle Grift Racket Score Heat Juice Hype Scratch Gutter Alley Curb Stoop Rooftop Fence Mule Runner
        Lookout Hustler Drifter Stray Busker Scrapper Slick Smokes Bones Ashes Cinders Rust Chrome Neon
        Razor Ghost Shade Shadow Phantom Wire Spike Tag Block Corner Dumpster Junker Scav Bounty Riot Havoc
        Mayhem Chaos Ruckus Brawl Rumble Scuffle Wreck Crash Bang Boom Blast Wildcard Longshot Jackpot
        Payday Overtime Nightshift Graveyard Deadline Lockdown Curfew Blackout Brownout Flatline Redline
        Overdrive Afterburn Backfire Misfire Ricochet Crossfire Sidewinder Hotwire Haywire Livewire
        Tripwire Razorwire Deadbolt Lockjaw Brick Concrete Asphalt Gravel Sawdust Rebar Girder Scaffold
        Slag Soot Grime Sludge Acid Bleach Kerosene Diesel Nitro Octane Propane Napalm Thermite Cordite
        Gunpowder Rush Buzz Fix Kick Dose Sugar Candy Dust Static Snitch Scrap Rivet Stitch Splice Tinker
        Patch Bodge Kludge Glitch Gremlin Hex Jinx Curse Omen Hunch Vex Mox Kilo Torque Sable Rook Saint
        Dice Wraith Lotus Bones Echo Razor Chrome Ghost Static"""),
    "noun": ("corpora data/words/nouns.json", """
        Arrow Baron Battery Bomber Breaker Cabal Cartridge Cassette Catfish Circus Conduit Coyote Culprit
        Cursor Cutter Cyclone Cylinder Daybreak Demon Diver Dossier Driver Envoy Flask Fluke Frigate Fusion
        Genesis Glitter Gridlock Hacker Headset Hurricane Ignition Infamy Intruder Lifeline Lookout
        Mainframe Mantra Matrix Mayhem Momentum Nexus Nightmare Nobody Noodle Nucleus Oasis Oracle Outage
        Outpost Oxygen Paradox Pendulum Persona Pointer Poker Processor Prophecy Prototype Pundit Radiance
        Ranger Roadblock Robber Saucer Savior Schism Scissors Scooter Slugger Snark Specimen Spectre
        Spoiler Squid Stylus Syntax Tempo Terror Thriller Ticker Trauma Tycoon Tyrant Underdog Uprising
        Vampire Vanguard Voltage Watchdog Widget Windfall Wiring"""),
    "body": ("authored", """
        Hand Eye Fist Tooth Jaw Skull Bone Knuckle Spine Heart Tongue Lip Nail Claw Fang Rib Thumb Finger
        Heel Elbow Neck Throat Lung Vein Nerve Iris Pupil Temple Brow Chin Cheek Ear Wrist Palm"""),
    "occupation": ("authored", """
        Butcher Surgeon Prophet Mechanic Preacher Accountant Professor Plumber Janitor Dentist Tailor
        Undertaker Florist Librarian Bishop Deacon Magistrate Tourist Courier Locksmith Gardener Juror
        Notary Auditor Barber Bellhop Chaplain Chemist Collector Conductor Cook Curator Doorman Druggist
        Electrician Engineer Ferryman Gambler Hangman Landlord Lineman Mortician Organist Pharmacist
        Pilgrim Pilot Priest Referee Roofer Salesman Sculptor Sexton Sheriff Shepherd Stranger Surveyor
        Tinker Tutor Umpire Vicar Watchman Welder Widow Wizard Accountant Bookie Bouncer Bartender
        Caretaker Chauffeur Clerk Cobbler Dispatcher Exterminator Fisherman Foreman Gravedigger Janitor
        Jeweller Junkman Lifeguard Milkman Porter Paperboy Pawnbroker Ragman Repoman Taxman"""),
}
COMPOUND_TAILS = """jack bone byte wire fox hound jaw eye hand tooth fang heart lock spark shot burn line drop fall
    rat cat crow wolf switch blade nail head skull dog rider runner walker maker breaker cutter jumper diver
    hook tail wing light glass smith works box star field ghost lane crack fire storm back neck kid""".split()
NUMBERS = ["2", "3", "4", "5", "6", "7", "8", "9", "11", "12", "13", "19", "21", "23", "33", "42", "51", "66", "77", "88",
           "99", "101", "303", "404", "808", "909", "1000", "2K", "X", "V", "VI", "IX", "Zero", "One", "Two", "Nine"]
PATTERNS = {
    "curated": {"weight": 18, "_doc": "a handle from the curated list"},
    "word": {"weight": 28, "pools": ["street", "tech", "animal", "myth", "gem", "metal", "weapon", "tool", "greek", "rank", "card",
             "disaster", "nature", "noun", "insect", "colour"], "_doc": "one word: Torque, Kestrel, Omega"},
    "pair": {"weight": 24, "first": ["adjective", "adjective_street", "colour", "metal"],
             "second": ["animal", "myth", "weapon", "tool", "tech", "street", "card", "rank", "body", "gem", "noun", "disaster", "insect"],
             "_doc": "two words: Cold Viper, Cobalt Hand, Twitchy Jack"},
    "compound": {"weight": 10, "pools": ["adjective_street", "colour", "metal", "tech", "street", "animal"], "first": ["compound_head"], "max_len": 11,
                 "_doc": "two words run together: Wirefox, Coldjaw, Neonrat"},
    "number": {"weight": 8, "pools": ["street", "tech", "animal", "greek", "card", "myth", "weapon", "tool"],
               "formats": ["{w}-{n}", "{w} {n}", "{w}{n}"], "_doc": "a word and a number: Kilo-9, Hex 404"},
    "alliterate": {"weight": 7, "needs_given": True, "pools": ["adjective_street", "weapon", "tool", "tech", "street", "animal", "occupation"],
                   "formats": ["{w} {g}", "{w} {g}", "{g} the {w}"], "_doc": "a pun on the given name: Razor Rosa, Kenji the Knife"},
    "the": {"weight": 5, "pools": ["occupation"], "_doc": "The Undertaker, The Tailor"},
}
CURATED = """
Two-Tone; Halfpipe; Ratchet; Lockjaw; Deadbolt; Nine Lives; Sidewinder; Busker; Tinman; Gutterball; Sixgun; Hotwire;
Quickdraw; Switchblade; Low Tide; Backwash; Breakbeat; Slow Burn; Redline; Overdrive; Killswitch; Ricochet; Firewall;
Skyhook; Dumpster; Stray; Whisper; Nightjar; Rooftop; Neon Saint; Tin Can; Sugar Skull; Glass Jaw; Paper Tiger;
Rust Bucket; Short Fuse; Long Odds; Half Price; Cold Brew; Hot Sauce; Static Cling; Dead Air; White Noise;
Low Battery; Blue Screen; Kernel Panic; Null Pointer; Stack Trace; Bit Rot; Packet Loss; Ping Pong; Brownout;
Hard Reset; Soft Lock; Burner; Dial Tone; Busy Signal; Voicemail; Off-Hook; Payphone; Collect Call; Bad Signal;
Moxie; Gristle; Cartilage; Knucklebones; Jawbreaker; Gobstopper; Bubblegum; Chewtoy; Hush Money; Fast Cash;
Petty Cash; Loose Change; Two Bits; Dime Store; Nickel Bag; Pocket Lint; Scrapheap; Junkyard; Tow Truck; Hubcap;
Fender; Tailpipe; Muffler; Hood Ornament; Dashboard; Glovebox; Rearview; Blind Spot; Cul-de-Sac; Dead End; Detour;
One Way; No Parking; Red Light; Green Light; Jaywalk; Crosswalk; Overpass; Underpass; Storm Drain; Manhole; Grate;
Sewer Rat; Tunnel Rat; Gutter Punk; Street Saint; Alley Cat; Fire Escape; Lightbulb; Fusebox; Breaker Box;
Ground Wire; Hot Wire; Live Wire; Spare Parts; Odd Job; Sidequest; Errand; Overtime; Night Owl; Early Bird; Insomnia;
Snooze; Caffeine; Espresso; Sriracha; Kibble; Saffron; Ginger Snap; Habanero; Jalapeño; Poblano; Bad Penny;
Wooden Nickel; Lucky Dog; Underdog; Top Dog; Hot Dog; Sea Dog; Mad Dog; Junkyard Dog; Stray Dog; Dog Tags; Hanger-On;
Sidekick; Backseat; Shotgun Rider; Wheelman; Getaway; Lookout; Wingman; Second Fiddle; One-Man Band; Busk; Encore;
Feedback; Reverb; Distortion; Overdub; Remix; B-Side; Bootleg; Mixtape; Lo-Fi; Hi-Fi; Needle Drop; Vinyl; Cassette;
Eight-Track; Mono; Stereo; Subwoofer; Bassline; Downbeat; Upbeat; Off-Beat; Backbeat; Snare; Kick Drum; Cymbal;
Banjo; Fiddle; Tuba; Theremin; Synth; Sampler; Sandman; Lamplighter; Chimney Sweep; Rag-and-Bone; Ragpicker;
Bottle Cap; Pull Tab; Can Opener; Corkscrew; Bottle Rocket; Roman Candle; Firecracker; Sparkler; Cherry Bomb;
Smoke Bomb; Stink Bomb; Helium; Yo-Yo; Hula; Pogo; Skate Key; Kickflip; Ollie; Grind Rail; Wipeout; Faceplant;
Road Rash; Scab; Stitches; Gauze; Tourniquet; Splint; Sling; Crutch; Kneecap; Shin Splint; Funny Bone; Wishbone;
Backbone; Jawline; Cheekbone; Collarbone; Ironside; Steelyard; Copperhead; Cottonmouth; Rattler; Sidewalk;
Chalk Line; Spray Can; Drip; Fat Cap; Wildstyle; Burner Wall; Blackbook; Scribble; Doodle; Smudge; Inkblot;
Fingerprint; Thumbprint; Ghost Print; Alibi; Patsy; Fall Guy; Wiseguy; Button Man; Bagman; Fixer-Upper; Handyman;
Odd Socks; Mismatch; Lefty; Righty; Southpaw; Ambidex; Hairtrigger; Hairline; Hairpin; Bobby Pin; Safety Pin; Zipper;
Snap; Buckle; Grommet; Eyelet; Denim; Corduroy; Tweed; Plaid; Paisley; Houndstooth; Argyle; Pinstripe; Polka;
Leopard Print; Camo; Hi-Vis; Reflector; Visor; Goggles; Balaclava; Bandana; Beanie; Trucker Cap; Fedora; Trilby;
Porkpie; Bowler; Panama; Beret; Monocle; Spyglass; Periscope; Kaleidoscope; Stethoscope; Gyroscope; Horoscope; Tarot;
Ouija; Crystal Ball; Tea Leaves; Palm Reader; Coin Flip; Heads; Tails; Double Six; Boxcars; Hard Eight; Yo-Eleven;
Seven Out; Point; Come Bet; Pass Line; Vigorish; Vig; Juice Man; Loan Shark; Card Shark; Pool Shark; Hustler;
Eight Ball; Corner Pocket; Bank Shot; Cue Ball; Scratch; Masse; Bridge; Rack; Chalk; Felt; Rail; Kitchen; Lag; Break;
Combo; Kiss Shot
""".replace("\n", " ")

# Canon Cyberpunk characters' handles and the game's named fixers and gang lieutenants: never a
# generated recruit's handle (World data and SPM p.57-61 NPCs by Role; names only).
RESERVED = """Johnny Silverhand; Silverhand; Morgan Blackhand; Blackhand; Rogue; Alt; Spider Murphy; Rache Bartmoss; Bartmoss;
Adam Smasher; Smasher; Kerry Eurodyne; Santiago; Thompson; Lazarus; Nix; Kerenzikov; Grease; Lowball; Flasher; Woodchipper;
3-Piece; Three Piece; Mynah; Kernaghan; Rex Royale; Willy Maze; Mr Amaaaze; Quake; Flenser; Apex; Ophelia; Neo; Trinity; Morpheus;
Case; Molly; Wintermute; Neuromancer; Deckard; Batty; Hiro Protagonist; Y.T.; Johnny Mnemonic; Zero Cool; Acid Burn; Crash Override;
Cereal Killer; Lord Nikon; Phantom Phreak; The Plague; V; Jackie; Panam; Judy; Takemura; Dex; Evelyn; T-Bug; Viktor; Misty;
Delamain; Hanako; Saburo; Yorinobu; Songbird; Reed; Kurt Hansen; Placide; Sasquatch; Royce; Maelstrom; Tyger Claws; Valentinos;
Voodoo Boys; Animals; Mox; Moxes; Piranhas; Iron Sights; Bozos; Philharmonic Vampyres; Inquisitors; Wraiths; Aldecaldos"""
# Famous people, characters, bands and brands a generated name or handle must not equal.
FAMOUS = """Michael Jordan; Michael Jackson; John Lennon; Paul McCartney; George Harrison; Ringo Starr; David Bowie; Tom Hanks;
Tom Cruise; Brad Pitt; Will Smith; James Brown; Bruce Lee; Jackie Chan; Jet Li; John Wayne; Elvis Presley; Bob Marley; Bob Dylan;
George Bush; George Washington; Abraham Lincoln; John Kennedy; Martin Luther King; Bill Gates; Steve Jobs; Elon Musk; Jeff Bezos;
Mark Zuckerberg; Donald Trump; Barack Obama; Joe Biden; Hillary Clinton; Bill Clinton; Ronald Reagan; Richard Nixon; Taylor Swift;
Harry Potter; James Bond; Jason Bourne; John Wick; Luke Skywalker; Han Solo; Indiana Jones; Sherlock Holmes; Bruce Wayne;
Peter Parker; Tony Stark; Clark Kent; Keanu Reeves; Mike Pondsmith; Bruce Springsteen; Lionel Messi; Cristiano Ronaldo;
David Beckham; Diego Maradona; Michael Schumacher; Lewis Hamilton; Serena Williams; Venus Williams; Tiger Woods; Muhammad Ali;
Mike Tyson; Floyd Mayweather; Kobe Bryant; LeBron James; Magic Johnson; Oprah Winfrey; Kim Kardashian; Justin Bieber;
Selena Gomez; Ricky Martin; Jennifer Lopez; Salma Hayek; Frida Kahlo; Pablo Picasso; Pablo Escobar; Che Guevara; Fidel Castro;
Kim Jong-un; Xi Jinping; Vladimir Putin; Boris Johnson; Angela Merkel; Narendra Modi; Shah Rukh Khan; Aamir Khan; Salman Khan;
Amitabh Bachchan; Akira Kurosawa; Hayao Miyazaki; Yoko Ono; Haruki Murakami; Ichiro Suzuki; Shohei Ohtani; Ken Watanabe;
Hideo Kojima; Shigeru Miyamoto; Bong Joon-ho; Park Ji-sung; Yao Ming; Lang Lang; Jack Ma; Chow Yun-fat; Andy Lau; Tony Leung;
Neil Armstrong; Buzz Aldrin; Isaac Newton; Albert Einstein; Stephen Hawking; Nikola Tesla; Charles Darwin; William Shakespeare;
Charles Dickens; Mark Twain; Ernest Hemingway; Jack London; Stephen King; George Orwell; William Gibson; Bruce Sterling;
Philip Dick; Ridley Scott; Rick Deckard; Roy Batty; Molly Millions; Henry Case; John Smith Jr; Adolf Hitler; Joseph Stalin;
Mao Zedong; Osama bin Laden; Saddam Hussein; Kim Il-sung; Pol Pot; Charles Manson; Ted Bundy; Jeffrey Dahmer; Jack Ripper;
Al Capone; John Gotti; Bonnie Parker; Clyde Barrow; Billy Kid; Jesse James; Wyatt Earp; Doc Holliday; Mad Max; Max Rockatansky;
Slick Rick; Ice Cube; Ice-T; Vanilla Ice; Snoop Dogg; Kid Rock; Kid Cudi; Big Sean; Lil Wayne; Lil Kim; Lil Jon; Daft Punk;
Iron Maiden; Black Sabbath; Deep Purple; Pink Floyd; Pearl Jam; Green Day; Maroon 5; Blink-182; Sum 41; Agent 47; Area 51;
Apollo 13; Catch-22; District 9; Jackson 5; Matchbox 20; UB40; Front 242; Def Leppard; Iron Man; Black Widow; Green Lantern;
Black Panther; Silver Surfer; Dark Knight; Red Skull; Ghost Rider; Nightcrawler; Star-Lord; Black Canary; Blue Beetle;
Iron Fist; Moon Knight; Black Bolt; Green Arrow; Scarlet Witch; Winter Soldier; Red Hood; Black Adam; Red Sonja; Hulk; Thor;
Loki; Wolverine; Venom; Storm; Batman; Superman; Joker; Flash; Sting; Slash; Bono; Drake; Cher; Moby; Seal; Pink; Prince;
Usher; Eminem; Banksy; Madonna; Rihanna; Beyonce; Adele; Shakira; Pitbull; Skrillex; Deadmau5; Marshmello; Tiesto; Avicii;
Kevlar; Taser; Velcro; Jeep; Xerox; Zippo; Glock; Uzi; Lego; Hummer; Teflon; Jacuzzi; Frisbee; Rolex; Walkman; Kleenex;
Tupperware; Post-It; Sharpie; Ziploc; Popsicle; Roomba; Segway; Tamagotchi; Pokemon; Pikachu; Nintendo; Sega;
Atari; Sony; Tesla; Arasaka; Militech; Kang Tao; Biotechnica; Petrochem; Zetatech; Trauma Team; Netwatch; Max-Tac;
Terminator; RoboCop; Robocop; Predator; Alien; Rambo; Rocky; Tron; Akira; Ghost in the Shell; Major Kusanagi; Neo Tokyo;
Snake Plissken; Solid Snake; Snake Eyes; Storm Shadow; Duke Nukem; Master Chief; Lara Croft; Sonic; Mario; Luigi; Zelda;
Link; Kratos; Gordon Freeman; Agent Smith"""

# Words the LDNOOBW list lacks that the filter must also block (slurs, and a few words no handle
# should be built from). Written for this project.
BLOCK_SUPPLEMENT = """chink gook jap dyke retard retarded gyppo gypsy gyp wop dago kyke honky cracker redskin squaw halfbreed
wigger nazi hitler pedo molester tard spaz spazz mong mongoloid cripple midget junkie crackhead tranny trannie shemale
lezzie lesbo homo poof poofter queer fairy nancy pansy sissy gaylord coolie wog golliwog sambo darkie darky pickaninny
jigaboo jiggaboo porchmonkey towelhead camel jockey sandnigger zipperhead slant slope yellowskin redbone mulatto
octoroon injun savage bimbo skank hoe ho thot incel rapey rape rapist""".split()
# Not blocked although some lists hold them: plain words that are also names or harmless here.
BLOCK_ALLOW = {"savage", "fairy", "camel", "slope", "slant", "nancy", "ho"}


# --- Fetching -------------------------------------------------------------------------------------

def curl(args, binary=False):
    p = subprocess.run(["curl", "-sS", "--fail", "--max-time", "180"] + args, capture_output=True)
    if p.returncode != 0:
        raise RuntimeError("curl failed: %s %s" % (args[-1][:120], p.stderr.decode()[:200]))
    return p.stdout if binary else p.stdout.decode("utf-8")


def wdqs(query):
    """A Wikidata Query Service query, waiting out 429s (Retry-After)."""
    return polite(["-H", "Accept: application/sparql-results+json", WDQS, "--data-urlencode", "query=" + query])


def polite(args):
    """curl, waiting out 429s (Retry-After): Wikimedia rate-limits by address."""
    while True:
        p = subprocess.run(["curl", "-sS", "--max-time", "170", "-D", "-"] + args, capture_output=True)
        out = p.stdout.decode("utf-8", "replace")
        head, _, body = out.partition("\r\n\r\n")
        while body.startswith("HTTP/"):   # a proxy's CONNECT reply comes first
            head, _, body = body.partition("\r\n\r\n")
        status = head.split("\r\n", 1)[0]
        if " 200" in status:
            return json.loads(body)
        if " 429" in status:
            wait = 60
            for line in head.split("\r\n"):
                if line.lower().startswith("retry-after:"):
                    wait = int(line.split(":", 1)[1].strip())
            print("  Wikimedia says wait %ds" % wait, flush=True)
            time.sleep(wait + 5)
            continue
        print("  Wikimedia request failed: %s" % status, flush=True)
        return None


def fetch(cache):
    os.makedirs(cache, exist_ok=True)
    cen = os.path.join(cache, "census", "Names_2010Census.csv")
    if not os.path.exists(cen):
        os.makedirs(os.path.dirname(cen), exist_ok=True)
        z = zipfile.ZipFile(io.BytesIO(curl([CENSUS_URL], binary=True)))
        open(cen, "wb").write(z.read("Names_2010Census.csv"))
    cdir = os.path.join(cache, "corpora")
    os.makedirs(cdir, exist_ok=True)
    for f in ["words/adjs.json", "words/nouns.json", "animals/common.json", "colors/web_colors.json", "materials/gemstones.json",
              "materials/metals.json", "materials/layperson-metals.json", "mythology/monsters.json", "mythology/greek_monsters.json",
              "objects/premodern_weapons.json", "geography/geographic_features.json", "geography/environmental_hazards.json",
              "geography/winds.json", "humans/moods.json", "science/elements.json"]:
        out = os.path.join(cdir, f.replace("/", "__"))
        if not os.path.exists(out):
            open(out, "w").write(curl([CORPORA + f]))
    for f in ["common-forenames-by-country.csv", "common-surnames-by-country.csv"]:
        out = os.path.join(cache, "sigpwned_" + f.split("-")[1] + ".csv")
        if not os.path.exists(out):
            open(out, "w").write(curl([SIGPWNED + f]))
    lb = os.path.join(cache, "ldnoobw_en")
    if not os.path.exists(lb):
        open(lb, "w").write(curl([LDNOOBW_URL]))
    wd = os.path.join(cache, "wd")
    os.makedirs(wd, exist_ok=True)
    for kind, prop in [("given", "P735"), ("family", "P734")]:
        for cid in CULTURES:
            for c in CULTURES[cid]["countries"]:
                out = os.path.join(wd, "%s_%s.json" % (kind, c))
                if os.path.exists(out):
                    continue
                res = wdqs(WD_COUNT % (c, prop))
                if res is None:
                    continue
                rows = {b["name"]["value"].rsplit("/", 1)[1]: int(b["n"]["value"]) for b in res["results"]["bindings"]}
                json.dump(rows, open(out, "w"))
                print("  %s %s: %d names" % (kind, c, len(rows)), flush=True)
                time.sleep(3)
    fetch_search(cache)
    fetch_meta(cache)


def fetch_search(cache):
    """Each culture's languages' given names (male, female, unisex) and family names, most linked first."""
    sdir = os.path.join(cache, "search")
    os.makedirs(sdir, exist_ok=True)
    order = ["japanese", "korean", "chinese", "southeast_asian", "south_asian", "lusophone", "pacific", "european", "middle_eastern",
             "latino", "eastern_european", "african"]   # the thinnest cultures first
    for cid in order:
        for lang in LANGS.get(cid, []):
            for typ, n in SEARCH_N.items():
                out = os.path.join(sdir, "%s_%s.json" % (lang, typ))
                if os.path.exists(out):
                    continue
                rows = []
                offset = 0
                while len(rows) < n:
                    url = ("%s?action=query&format=json&generator=search&gsrsearch=haswbstatement:P31=%s%%20haswbstatement:P407=%s"
                           "&gsrsort=incoming_links_desc&gsrlimit=max&gsroffset=%d&prop=entityterms&wbetterms=label&wbetlanguage=en") % (WDAPI, typ, lang, offset)
                    d = polite([url])
                    if d is None:
                        break
                    pages = sorted(d.get("query", {}).get("pages", {}).values(), key=lambda x: x["index"])
                    rows += [[pg["title"], pg.get("entityterms", {}).get("label", [""])[0]] for pg in pages]
                    if "continue" not in d or not pages:
                        break
                    offset = d["continue"]["gsroffset"]
                    time.sleep(1.0)
                json.dump(rows[:n], open(out, "w"), ensure_ascii=False)
                print("  search %s %s %s: %d" % (cid, lang, typ, len(rows)), flush=True)
                time.sleep(1.0)


def searched(cache, cid, typ, flt, ascii_only):
    """Culture `cid`'s searched names of item type `typ`, its languages interleaved, most linked first."""
    lists = []
    for lang in LANGS.get(cid, []):
        fn = os.path.join(cache, "search", "%s_%s.json" % (lang, typ))
        if os.path.exists(fn):
            labs = [good_label(lab, ascii_only) for _, lab in json.load(open(fn))]
            lists.append([x for x in labs if x and flt.clean(x)])
    return interleave(*lists) if lists else []


def fetch_meta(cache):
    """English labels and types (P31) of every name item the counts mention, 50 per API call."""
    path = os.path.join(cache, "meta.json")
    meta = json.load(open(path)) if os.path.exists(path) else {}
    need = set()
    for fn in os.listdir(os.path.join(cache, "wd")):
        rows = json.load(open(os.path.join(cache, "wd", fn)))
        k = META_TOP[fn.split("_")[0]] * (2 if fn.split("_")[1].split(".")[0] in DEEP else 1)
        for q in sorted(rows, key=lambda q: (-rows[q], q))[:k]:   # only the most common can make the cut
            if q not in meta:
                need.add(q)
    need = sorted(need)
    print("  labels to fetch: %d" % len(need), flush=True)
    for i in range(0, len(need), 50):
        ids = need[i:i + 50]
        d = polite(["%s?action=wbgetentities&ids=%s&props=labels%%7Cclaims&languages=en&format=json" % (WDAPI, "%7C".join(ids))])
        if d is None:
            continue
        for q, e in d.get("entities", {}).items():
            p31 = []
            for c in e.get("claims", {}).get("P31", []):
                v = c.get("mainsnak", {}).get("datavalue", {}).get("value", {})
                if isinstance(v, dict) and "id" in v:
                    p31.append(v["id"])
            meta[q] = {"label": e.get("labels", {}).get("en", {}).get("value", ""), "p31": p31}
        if i % 1000 == 0:
            json.dump(meta, open(path, "w"), ensure_ascii=False)
            print("  labels: %d of %d" % (i, len(need)), flush=True)
        time.sleep(1.0)
    json.dump(meta, open(path, "w"), ensure_ascii=False)


# --- Building -------------------------------------------------------------------------------------

def font_chars():
    try:
        from fontTools.ttLib import TTFont
    except ImportError:
        return None
    sets = [set(TTFont(f).getBestCmap()) for f in FONTS if os.path.exists(f)]
    return set.intersection(*sets) if sets else None


FONT = None


def fold(s, ascii_only=False):
    """Strip any accent the game's fonts can't draw (lower or upper case), any outside Latin-1 and
    Latin Extended-A, and every accent for a culture usually romanised without them (Sato, Nguyen)."""
    out = ""
    for ch in s:
        if ord(ch) < 128 or (not ascii_only and ord(ch) <= 0x17F and (FONT is None or (ord(ch) in FONT and ord(ch.upper()[0]) in FONT))):
            out += ch
        else:
            ch = {"Đ": "D", "đ": "d", "ı": "i", "Ł": "L", "ł": "l", "Ø": "O", "ø": "o", "ß": "ss"}.get(ch, ch)
            out += "".join(c for c in unicodedata.normalize("NFKD", ch) if not unicodedata.combining(c))
    return out


PART = re.compile(r"^[A-ZÀ-ÞĀ-ſ][a-zß-ÿĀ-ſ']*$")


DROP_NAMES = {"Ferndo"}   # typos spotted in the sources


def good_label(s, ascii_only=False):
    s = s.replace("’", "'").strip()
    if not s or s in DROP_NAMES or len(s) < 2 or len(s) > 14 or "(" in s or " " in s or "/" in s:
        return ""
    s = fold(s, ascii_only)
    parts = s.split("-")
    if len(parts) > 2 or not PART.match(parts[0]) or not all(PART.match(p[:1].upper() + p[1:]) for p in parts[1:]):
        return ""
    if any(p.upper() == p and len(p) > 1 for p in parts):
        return ""
    return s


def load_blocked(cache):
    words = set()
    for line in open(os.path.join(cache, "ldnoobw_en"), encoding="utf-8"):
        w = line.strip().lower()
        if w:
            words.add(w)
    words |= set(BLOCK_SUPPLEMENT)
    words -= BLOCK_ALLOW
    return sorted(words)


def norm(s):
    s = "".join(c for c in unicodedata.normalize("NFKD", s.lower()) if not unicodedata.combining(c))
    s = s.replace("ß", "ss").replace("ł", "l").replace("ø", "o").replace("æ", "ae").replace("œ", "oe").replace("đ", "d").replace("ı", "i")
    return "".join(c for c in s if "a" <= c <= "z" or c == " ")


class Filter:
    def __init__(self, blocked):
        self.blocked = set(norm(b).replace(" ", "") for b in blocked)
        self.long = [b for b in self.blocked if len(b) >= 4]

    def clean(self, text, substrings=False):
        n = norm(text)
        j = n.replace(" ", "")
        if j in self.blocked or any(w in self.blocked for w in n.split()):
            return False
        return not (substrings and any(b in j for b in self.long))


def census_surnames(cache, which, flt):
    out = []
    for r in csv.DictReader(open(os.path.join(cache, "census", "Names_2010Census.csv"), encoding="utf-8")):
        name = r["name"]
        if name == "ALL OTHER NAMES" or not name.isalpha() or len(name) < 2:
            continue
        def pct(k):
            try:
                return float(r[k])
            except ValueError:
                return 0.0   # "(S)": suppressed for privacy
        white, black, api, hisp = pct("pctwhite"), pct("pctblack"), pct("pctapi"), pct("pcthispanic")
        if which == "anglo" and not (white + black >= 85 and hisp < 10 and api < 5):
            continue
        if which == "hispanic" and hisp < 75:
            continue
        if name.startswith(("DELA", "DELOS", "DELAS", "VANDER", "VANDE", "VANDEN")):
            continue   # the Census strips the spaces from De la Rosa, Van der Berg
        t = name.capitalize()
        if t.startswith("Mc") and len(t) > 3:
            t = "Mc" + t[2:].capitalize()
        if t in ("Obrien", "Oconnor", "Oneil", "Oneill", "Odonnell", "Oconnell", "Oreilly", "Orourke", "Osullivan", "Ohara", "Oleary",
                 "Okeefe", "Omalley", "Otoole", "Ohalloran", "Oshea", "Odonoghue", "Oneal"):
            t = "O'" + t[1:].capitalize()
        if flt.clean(t):
            out.append(t)
        if len(out) >= CENSUS_N[which]:
            break
    return out


# Slavic surname forms: masculine ending -> feminine ending (HOUSE-RULE: the commonest patterns).
FORMS = [("skiy", "skaya"), ("sky", "skaya"), ("ský", "ská"), ("cký", "cká"), ("ski", "ska"), ("cki", "cka"), ("dzki", "dzka"),
         ("ov", "ova"), ("ev", "eva"), ("in", "ina")]


def other_form(label):
    """The other gender's form of a gendered surname, or "" (Ivanov -> Ivanova, Kowalska -> Kowalski)."""
    for m, f in FORMS:
        if label.endswith(f):
            return label[: -len(f)] + m
    for m, f in FORMS:
        if label.endswith(m):
            return label[: -len(m)] + f
    return ""


def gendered(label):
    low = label.lower()
    if any(low.endswith(e) for e in FEMME_ENDS):
        return "femme"
    if any(low.endswith(e) for e in MASC_ENDS):
        return "masc"
    return ""


def unaccented_once(lst):
    """Each name once whatever its accents (the Census drops them: Garcia and García are one name)."""
    seen = set()
    out = []
    for x in lst:
        k = norm(x)
        if k not in seen:
            seen.add(k)
            out.append(x)
    return out


def composed(c, k):
    """Two-syllable names from c[k] and c["second"][k], the pairs of the most common syllables first."""
    pairs = [(i + j, a + b) for i, a in enumerate(c[k]) for j, b in enumerate(c["second"][k]) if a.lower() != b]
    return [name for _, name in sorted(pairs)]


def interleave(*srcs):
    """a[0], b[0], a[1], b[1]...: frequency orders merged, each name once."""
    out = []
    seen = set()
    for i in range(max([len(x) for x in srcs] + [0])):
        for src in srcs:
            if i < len(src) and src[i] not in seen:
                seen.add(src[i])
                out.append(src[i])
    return out


def popular(cache, cfg, flt):
    """A culture's countries' most popular given names (recent birth years) and family names from the
    sigpwned dataset (CC0), in rank order, one country after another."""
    given = {"masc": [], "femme": []}
    family = []
    fn = os.path.join(cache, "sigpwned_forenames.csv")
    if os.path.exists(fn):
        rows = list(csv.DictReader(open(fn, encoding="utf-8-sig")))
        by = {}
        for r in rows:
            if r["Country"] in cfg["iso"]:
                lab = good_label(r["Romanized Name"], cfg.get("ascii", False))
                k = "masc" if r["Gender"] == "M" else "femme"
                if lab and flt.clean(lab):
                    by.setdefault((r["Country"], k), []).append(lab)
        for k in given:
            lists = [by.get((c, k), []) for c in cfg["iso"]]
            for i in range(max([len(x) for x in lists] + [0])):
                for x in lists:
                    if i < len(x) and x[i] not in given[k]:
                        given[k].append(x[i])
    fn = os.path.join(cache, "sigpwned_surnames.csv")
    if os.path.exists(fn):
        rows = list(csv.DictReader(open(fn, encoding="utf-8-sig")))
        lists = []
        for c in cfg["iso"]:
            labs = []
            groups = set()
            for r in rows:   # one spelling per surname (the dataset lists variants: Kim, Gim, Ghim)
                if r["Country"] == c and (r["Name Group"] not in groups or cfg.get("gendered_family")):
                    lab = good_label(r["Romanized Name"], cfg.get("ascii", False))
                    if lab and flt.clean(lab):
                        groups.add(r["Name Group"])
                        labs.append(lab)
            lists.append(labs)
        for i in range(max([len(x) for x in lists] + [0])):
            for x in lists:
                if i < len(x) and x[i] not in family:
                    family.append(x[i])
    return given, family


def build_names(cache, flt, famous):
    meta = json.load(open(os.path.join(cache, "meta.json")))
    wd = os.path.join(cache, "wd")
    cultures = {}
    used_countries = {}
    for cid, cfg in CULTURES.items():
        small = cfg["weight"] < SMALL
        given = {}   # label -> [count, kind]
        family = {}
        for c in cfg["countries"]:
            for kind, acc in (("given", given), ("family", family)):
                fn = os.path.join(wd, "%s_%s.json" % (kind, c))
                if not os.path.exists(fn):
                    continue
                used_countries.setdefault(cid, set()).add(c)
                rows = json.load(open(fn))
                total = float(sum(rows.values())) or 1.0
                for q, n in rows.items():
                    m = meta.get(q)
                    if not m:
                        continue
                    lab = good_label(m["label"], cfg.get("ascii", False))
                    if not lab or not flt.clean(lab):
                        continue
                    # each country counts by share, so big countries don't drown small ones
                    share = n / total
                    if kind == "given":
                        p31 = m["p31"]
                        g = "masc" if MALE_NAME in p31 and FEMALE_NAME not in p31 else "femme" if FEMALE_NAME in p31 and MALE_NAME not in p31 else "neutral" if UNISEX_NAME in p31 else ""
                        if not g:
                            continue
                        e = acc.setdefault(lab, [0.0, g])
                        e[0] += share
                    else:
                        e = acc.setdefault(lab, [0.0, ""])
                        e[0] += share
        out = {"name": cfg["name"], "weight": cfg["weight"], "countries": sorted(used_countries.get(cid, [])), "iso": cfg["iso"]}
        pop_given, pop_family = popular(cache, cfg, flt)
        g = {}
        for k, n in GIVEN_N.items():
            n = n // 2 if small else n
            lst = sorted((lab for lab, e in given.items() if e[1] == k), key=lambda lab: (-given[lab][0], lab))
            typ = {"masc": MALE_NAME, "femme": FEMALE_NAME, "neutral": UNISEX_NAME}[k]
            g[k] = unaccented_once(interleave(pop_given.get(k, []), lst, searched(cache, cid, typ, flt, cfg.get("ascii", False))))[:n]
            if cid in COMPOSE and k in COMPOSE[cid]["second"] and len(g[k]) < n:
                g[k] += [x for x in composed(COMPOSE[cid], k) if x not in g[k] and flt.clean(x)][:n - len(g[k])]
        out["given"] = g
        fam = interleave(pop_family, sorted(family, key=lambda lab: (-family[lab][0], lab)), searched(cache, cid, FAMILY_NAME, flt, cfg.get("ascii", False)))
        if cfg.get("census"):
            cen = census_surnames(cache, cfg["census"], flt)
            merged = []
            for i in range(max(len(cen), len(fam))):   # interleave: Census (US-born) and the old countries
                for src in (cen, fam):
                    if i < len(src) and src[i] not in merged:
                        merged.append(src[i])
            fam = merged
        n = FAMILY_N // 2 if small else FAMILY_N + (CENSUS_N.get(cfg.get("census", ""), 0))
        fam = unaccented_once(fam)[:n]
        if cfg.get("gendered_family"):
            out["family"] = [f for f in fam if not gendered(f)]
            masc = [f for f in fam if gendered(f) == "masc"]
            femme = [f for f in fam if gendered(f) == "femme"]
            # each form's partner (Ivanov / Ivanova, Kowalski / Kowalska), in the same order
            out["family_masc"] = interleave(masc, [x for x in (other_form(f) for f in femme) if x])
            out["family_femme"] = interleave(femme, [x for x in (other_form(f) for f in masc) if x])
        else:
            out["family"] = fam
        cultures[cid] = out
    return cultures


def words_list(src):
    seen = []
    for w in src.split():
        if w not in seen:
            seen.append(w)
    return seen


def build_handles(flt, reserved, famous):
    words = {}
    for pool, (source, text) in WORDS.items():
        lst = [w for w in words_list(text)]
        lst = [w for w in lst if flt.clean(w, True) and norm(w).replace(" ", "") not in reserved and norm(w).replace(" ", "") not in famous]
        words[pool] = {"source": source, "list": lst}
    # the first half of a run-together handle: a short word with no hyphen
    heads = []
    for pool in PATTERNS["compound"]["pools"]:
        heads += [w for w in words[pool]["list"] if w.isalpha() and len(w) <= 6 and w not in heads]
    words["compound_head"] = {"source": "the short words of pools " + ", ".join(PATTERNS["compound"]["pools"]), "list": heads}
    curated = []
    for h in CURATED.split(";"):
        h = " ".join(h.split())
        if not h or h in curated:
            continue
        k = norm(h).replace(" ", "")
        if flt.clean(h, True) and k not in reserved and k not in famous:
            curated.append(h)
    tails = [t for t in COMPOUND_TAILS if flt.clean(t, True)]
    return {"words": words, "compound_tails": tails, "numbers": NUMBERS, "patterns": PATTERNS, "curated": curated}


def semis(text):
    return [" ".join(x.split()) for x in text.split(";") if x.strip()]


def main():
    global FONT
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", required=True)
    ap.add_argument("--fetch", action="store_true")
    a = ap.parse_args()
    if a.fetch:
        fetch(a.cache)
    FONT = font_chars()
    blocked = load_blocked(a.cache)
    flt = Filter(blocked)
    reserved_l = semis(RESERVED)
    famous_l = semis(FAMOUS)
    reserved = set(norm(x).replace(" ", "") for x in reserved_l)
    famous = set(norm(x).replace(" ", "") for x in famous_l)
    cultures = build_names(a.cache, flt, famous)
    prov_names = {
        "wikidata": "Given names (P735) and family names (P734) of people by citizenship (P27), counted per name, with each name item's English label and type (male, female or unisex given name), where the query service allowed; and given-name and family-name items by language (P407), most linked first (search sorted by incoming links), for every culture. Wikidata, CC0 1.0 (https://www.wikidata.org/wiki/Wikidata:Licensing). Queried %s." % time.strftime("%Y-%m"),
        "sigpwned": "Popular names by country (https://github.com/sigpwned/popular-names-by-country-dataset), CC0 1.0: the top given names by sex and the commonest surnames per country, compiled in 2023 from Wikipedia's lists of most popular given names and most common surnames (name lists: facts, not creative text). Interleaved with Wikidata's order so recent popular names show up beside long-standing ones.",
        "us_census_2010": "Frequently Occurring Surnames from the 2010 Census (US Census Bureau), with the share by race and Hispanic origin: the Anglo culture takes surnames mostly held by White or Black Americans, the Latino culture those mostly held by Hispanic Americans. Public domain (a work of the US federal government, 17 U.S.C. 105). %s" % CENSUS_URL,
        "composed": "Chinese given names beyond the sourced ones are built from authored lists of common pinyin syllables (COMPOSE in the tool).",
        "curation": "tools/gen_names_data.py: Latin-script labels only (accents the game's fonts lack are folded), filtered by data/gen/name_filter.json, lists cut to the most common names. Cultures, weights and the mixing rate are HOUSE-RULE for Night City 2045. The name tables of Cyberpunk RED: Single Player Mode (SPM p.52-54) were a style guide only; none of their lists are copied.",
        "licences": "assets/third_party/names/README.md",
    }
    names = {
        "_doc": "Real names for Night City's people (Names.person / Names.full_name). cultures.<id>: name, weight (share of Night City's people, HOUSE-RULE), countries (the Wikidata citizenships drawn on), given.{masc,femme,neutral} and family (family_masc / family_femme where the culture's surnames are gendered), each list most common first. family_mix: chance a person's family name comes from another culture. given_mix: which given-name lists each gender draws from. Generated by tools/gen_names_data.py: rerun it rather than editing by hand.",
        "_provenance": prov_names,
        "family_mix": FAMILY_MIX,
        "given_mix": GIVEN_MIX,
        "cultures": cultures,
    }
    handles = {
        "_doc": "Street handles (Names.handle). patterns.<id>: weight and the word pools it draws on (words.<pool>.list); curated: whole handles; compound_tails: the second half of a run-together handle; numbers: suffixes. Generated by tools/gen_names_data.py.",
        "_provenance": {
            "corpora": "Word pools marked corpora are curated picks from Darius Kazemi's corpora (https://github.com/dariusk/corpora), CC0 1.0; each pool's `source` names the file.",
            "authored": "Pools marked authored, the patterns, the compound tails and the curated handles were written for this project (the repository's licence).",
            "style": "The kinds of words follow the idea of the Handles table in Cyberpunk RED: Single Player Mode (SPM p.55): no entries are copied.",
            "licences": "assets/third_party/names/README.md",
        },
    }
    handles.update(build_handles(flt, reserved, famous))
    filt = {
        "_doc": "The name filter (Names.is_clean, is_reserved, is_famous). blocked: profanity and slurs; a name or handle holding one as a word is rejected, and a handle holding a blocked word of 4+ letters anywhere (compounds join words). reserved: canon Cyberpunk characters' and the game's fixers' handles. famous: real people, fictional characters, bands and brands. fold: letters to strip of accents when comparing. Generated by tools/gen_names_data.py.",
        "_provenance": {
            "ldnoobw": "List of Dirty, Naughty, Obscene, and Otherwise Bad Words (en), https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words, CC BY 4.0 (attribution: Shutterstock and contributors). Used unmodified apart from the allow-list in tools/gen_names_data.py (BLOCK_ALLOW).",
            "authored": "The supplement of slurs the list lacks, the reserved and famous names: written for this project.",
            "licences": "assets/third_party/names/README.md",
        },
        "blocked": blocked,
        "reserved": reserved_l,
        "famous": famous_l,
        "fold": {"à": "a", "á": "a", "â": "a", "ã": "a", "ä": "a", "å": "a", "ā": "a", "ă": "a", "ą": "a", "æ": "a", "ç": "c", "ć": "c", "č": "c",
                 "ď": "d", "đ": "d", "è": "e", "é": "e", "ê": "e", "ë": "e", "ē": "e", "ė": "e", "ę": "e", "ě": "e", "ğ": "g", "ì": "i", "í": "i",
                 "î": "i", "ï": "i", "ī": "i", "į": "i", "ı": "i", "ķ": "k", "ļ": "l", "ľ": "l", "ł": "l", "ñ": "n", "ń": "n", "ņ": "n", "ň": "n",
                 "ò": "o", "ó": "o", "ô": "o", "õ": "o", "ö": "o", "ø": "o", "ō": "o", "ő": "o", "œ": "o", "ŕ": "r", "ř": "r", "ś": "s", "ş": "s",
                 "š": "s", "ș": "s", "ß": "s", "ţ": "t", "ť": "t", "ț": "t", "ù": "u", "ú": "u", "û": "u", "ü": "u", "ū": "u", "ů": "u", "ű": "u",
                 "ų": "u", "ý": "y", "ÿ": "y", "ź": "z", "ż": "z", "ž": "z", "-": " ", "'": "", ".": ""},
    }
    for fn, d in [("names.json", names), ("handles.json", handles), ("name_filter.json", filt)]:
        with open(os.path.join(OUT, fn), "w", encoding="utf-8") as f:
            f.write(json.dumps(d, indent="\t", ensure_ascii=False) + "\n")
    giv = set()
    fam = set()
    for c in cultures.values():
        for k in c["given"]:
            giv |= set(c["given"][k])
        for k in ("family", "family_masc", "family_femme"):
            fam |= set(c.get(k, []))
    words = sum(len(p["list"]) for p in handles["words"].values())
    print("names: %d cultures, %d distinct given names, %d distinct family names" % (len(cultures), len(giv), len(fam)))
    for cid, c in cultures.items():
        print("  %-17s given m/f/n %d/%d/%d  family %d (+%d m, %d f)  countries %d" % (cid, len(c["given"]["masc"]), len(c["given"]["femme"]),
              len(c["given"]["neutral"]), len(c["family"]), len(c.get("family_masc", [])), len(c.get("family_femme", [])), len(c["countries"])))
    print("handles: %d pool words, %d curated, %d tails; filter: %d blocked, %d reserved, %d famous" % (words, len(handles["curated"]),
          len(handles["compound_tails"]), len(blocked), len(reserved_l), len(famous_l)))


if __name__ == "__main__":
    main()
