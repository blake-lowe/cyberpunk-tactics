#!/usr/bin/env python3
"""Checks the Night City 2045 world docs (docs/world/nc_*.md) against the schemas in
docs/world/city.md and docs/world/locations.md. Run from the repo root:
    python3 tools/check_nc_world.py [docs/world/nc_little_europe.md ...]
Errors fail (exit 1); unknown faction ids are listed as warnings (the factions pass adds them)."""
import glob, json, re, sys
sys.path.insert(0, "tools")
from gen_world_data import BLOCK

GIGS = {"data_theft", "gang_hit", "corp_extraction", "assassination", "rescue", "sabotage"}
INTENSITY = {"light", "medium", "heavy"}
RESPONDERS = {"patrons", "staff", "residents", "various", "gangs", "unknown"}
REGIONS = {"island", "northside", "mainland", "southside", "outskirts", "playland"}
PROFILES = {"corporate_center", "executive_zone", "market_streets", "mixed_residential", "combat_zone", "hot_zone", "burning_zone", "industrial", "pacifica"}

def known_factions():
    ids = set(json.load(open("data/world/factions.json"))["factions"].keys())
    for line in open("tools/nc_faction_ids.txt"):
        if line.strip() and not line.startswith("#"):
            ids.add(line.split()[0])
    return ids

def types():
    text = open("docs/world/locations.md").read()
    for m in BLOCK.finditer(text):
        if m.group(1) == "locations.types":
            return set(json.loads(m.group(2)).keys())
    return set()

def code_ok(c, where, errs, unknown, facs):
    if not isinstance(c, dict):
        errs.append("%s: security_code must be an object" % where); return
    if not isinstance(c.get("n"), int) or not 0 <= c["n"] <= 11:
        errs.append("%s: security_code.n must be 0-11" % where)
    if c.get("intensity") not in INTENSITY:
        errs.append("%s: security_code.intensity must be light|medium|heavy" % where)
    if not isinstance(c.get("hardened"), bool):
        errs.append("%s: security_code.hardened must be true/false" % where)
    if c.get("faction") not in facs:
        unknown.add(c.get("faction"))
    if "or_faction" in c and (c["or_faction"] not in facs or c["or_faction"] == c.get("faction")):
        errs.append("%s: security_code.or_faction must be another known faction" % where)
    if "responder" in c and (c.get("faction") != "locals" or c["responder"] not in RESPONDERS):
        errs.append("%s: security_code.responder only on a locals code, one of %s" % (where, sorted(RESPONDERS)))
    if c.get("faction") == "locals" and "responder" not in c:
        errs.append("%s: a locals code names its printed responder" % where)

def main():
    files = sys.argv[1:] or sorted(glob.glob("docs/world/nc_*.md"))
    facs, tys = known_factions(), types()
    errs, unknown, counts = [], set(), {"districts": 0, "locations": 0}
    for f in files:
        text = open(f).read()
        for m in BLOCK.finditer(text):
            target, body = m.group(1), m.group(2)
            where = "%s:%d %s" % (f, text.count("\n", 0, m.start()) + 1, target)
            try:
                v = json.loads(body)
            except json.JSONDecodeError as ex:
                errs.append("%s: bad JSON: %s" % (where, ex)); continue
            if target.startswith("city.districts."):
                counts["districts"] += 1
                for k in ["name", "region", "manager", "population", "security_code", "utility_code", "provider", "gangs", "ncart", "profile", "look", "history", "cite"]:
                    if k not in v: errs.append("%s: missing %s" % (where, k))
                if v.get("region") not in REGIONS: errs.append("%s: region" % where)
                if v.get("profile") not in PROFILES: errs.append("%s: profile %s" % (where, v.get("profile")))
                if "security_code" in v: code_ok(v["security_code"], where, errs, unknown, facs)
                for g in v.get("gangs", []) + [v.get("provider")]:
                    if g and g not in facs: unknown.add(g)
            elif target.startswith("locations.locations."):
                counts["locations"] += 1
                for k in ["name", "district", "number", "type", "owner", "owner_name", "security_code", "utility_code", "npcs", "hooks", "gigs", "interior", "cite"]:
                    if k not in v: errs.append("%s: missing %s" % (where, k))
                if v.get("type") not in tys: errs.append("%s: type %s not in the vocabulary" % (where, v.get("type")))
                if "security_code" in v and v["security_code"] is not None: code_ok(v["security_code"], where, errs, unknown, facs)
                if v.get("owner") and v["owner"] not in facs: unknown.add(v["owner"])
                for g in v.get("gigs", []):
                    if g not in GIGS: errs.append("%s: gig %s" % (where, g))
                for h in v.get("hooks", []):
                    if not isinstance(h, dict) or "text" not in h or any(g not in GIGS for g in h.get("gigs", [])):
                        errs.append("%s: bad hook %s" % (where, h))
                if not re.match(r"NC2045 p\.\d+", str(v.get("cite", ""))): errs.append("%s: cite" % where)
            else:
                errs.append("%s: unexpected target" % where)
    for e in errs: print("ERROR", e)
    if unknown: print("WARN unknown faction ids (add to the factions pass):", " ".join(sorted(x for x in unknown if x)))
    print("checked %d district(s), %d location(s): %d error(s)" % (counts["districts"], counts["locations"], len(errs)))
    sys.exit(1 if errs else 0)

if __name__ == "__main__":
    main()
