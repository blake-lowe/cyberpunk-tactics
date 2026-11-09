# Name data: sources and licences

The game's people names, street handles and name filter (`data/gen/names.json`, `data/gen/handles.json`,
`data/gen/name_filter.json`, read by `src/meta/names.gd`) are built by `tools/gen_names_data.py` from the
sources below. Each data file repeats its own provenance under `_provenance`.

| Source | What we take | Licence |
|---|---|---|
| [Wikidata](https://www.wikidata.org/) | (1) Given names (P735) and family names (P734) of people by citizenship (P27), counted per name, with each name item's English label and type (male, female or unisex given name), for the countries the query service let us count before rate-limiting us. (2) Given-name and family-name items by language (P407), most linked first (Wikidata's search sorted by incoming links), for every culture. | CC0 1.0 (public domain dedication): <https://www.wikidata.org/wiki/Wikidata:Licensing> |
| sigpwned, [popular-names-by-country-dataset](https://github.com/sigpwned/popular-names-by-country-dataset) | The most popular given names by sex and the commonest surnames per country (romanised), compiled in 2023 from Wikipedia's lists of most popular given names and most common surnames. | CC0 1.0 (the dataset's LICENSE). Name lists are facts rather than creative text. |
| US Census Bureau, [Frequently Occurring Surnames from the 2010 Census](https://www.census.gov/topics/population/genealogy/data/2010_surnames.html) | The most common US surnames with their share by race and Hispanic origin (Anglo and Latino family names). | Public domain: a work of the US federal government (17 U.S.C. 105). |
| Darius Kazemi, [corpora](https://github.com/dariusk/corpora) | Curated picks from its word lists (adjectives, nouns, moods, animals, colours, gemstones, metals, elements, monsters, winds, hazards, geographic features, pre-modern weapons) for the handle word pools. Each pool names the files it picked from. | CC0 1.0: <https://creativecommons.org/publicdomain/zero/1.0/> |
| [LDNOOBW](https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words), "List of Dirty, Naughty, Obscene, and Otherwise Bad Words" (en) | The profanity and slur filter's word list, unmodified apart from a short allow-list (`BLOCK_ALLOW` in the tool). | CC BY 4.0, (c) Shutterstock, Inc. and contributors: `LICENSE-ldnoobw-cc-by-4.0.txt` |
| This project | The handle patterns, the authored word pools, the curated handles, the filter's supplement of slurs, the reserved (canon) and famous names, the cultures and their Night City weights (HOUSE-RULE). | The repository's licence. |

Not used:
- **Cyberpunk RED: Single Player Mode** (R. Talsorian Games): its Names lists (SPM p.52-54) and Handles table (SPM p.55)
  are copyrighted lists. They were a style guide only (the kinds of handle words, the spread of names); none of their
  entries are copied. People of Night City (`data/gen/people.json`, SPM p.50-51) keeps only short paraphrased role labels
  with page cites.
- **SSA baby names** (public domain) were the first choice for US given names, but ssa.gov refused the download (403)
  from the build container; Wikidata's US data stands in.

## Rebuilding

    python3 tools/gen_names_data.py --cache /some/cache/dir --fetch

downloads what the cache lacks (curl with its default user agent; Wikidata's rate limits are honoured) and rewrites
the three data files. Without `--fetch` it rebuilds from the cache.
