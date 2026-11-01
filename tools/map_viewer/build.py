#!/usr/bin/env python3
"""Builds the map/net review page from an export_maps.gd JSON dump.

  timeout 300 godot --headless --path . -s tools/export_maps.gd -- /path/maps.json
  python3 tools/map_viewer/build.py /path/maps.json /path/out.html

Grids are packed into strings (one char per cell) to keep the page small.
"""
import json
import sys
from pathlib import Path

HERE = Path(__file__).parent


def pack(m):
    w, h = m["w"], m["h"]
    zone_of = {r["id"]: r["zone"] for r in m["rooms"]}
    floors = []
    for fd in m["floor_data"]:
        tiles = "".join(str(t) for t in fd["tiles"])
        zones = "".join(str(zone_of.get(l, 0)) if l >= 0 else "." for l in fd["labels"])
        mats = "".join(str(v) for v in fd["wall_mat"])
        floors.append({"t": tiles, "z": zones, "m": mats})
    rooms = [{"id": r["id"], "f": r["floor"], "k": r["kind"], "z": r["zone"], "b": r["bounds"]}
             for r in m["rooms"] if r["cells"] > 0]

    def slim_arch(a):
        fl = []
        for f in a["floors"]:
            e = {k: f[k] for k in ("id", "parent", "branch", "depth", "type", "zone") if k in f}
            for k in ("dv", "ice", "devices", "group", "device", "value", "gate", "lobby"):
                if k in f:
                    e[k] = int(f[k]) if k == "dv" else f[k]
            fl.append(e)
        return {"difficulty": a["difficulty"], "style": a["style"], "floors": fl, "aps": a["access_points"]}

    return {
        "algo": m["algorithm"], "seed": m["seed"], "sec": m["params"]["security"], "w": w, "h": h,
        "nf": m["floors"], "floors": floors, "rooms": rooms,
        "doors": [{"f": d["floor"], "p": d["pos"], "s": d["security"]} for d in m["doors"]],
        "cover": [{"f": c["floor"], "p": c["pos"], "k": c["kind"], "hp": c["hp"]} for c in m["cover"]],
        "dev": [{"id": d["id"], "f": d["floor"], "p": d["pos"], "t": d["type"], "g": d["group"], "z": d["zone"],
                 "ap": d.get("access_point", False), "fv": d.get("file_value", 0)} for d in m["devices"]],
        "ent": [{"f": e["floor"], "p": e["pos"], "main": e["main"], "k": e["kind"]} for e in m["entrances"]],
        "vert": [{"t": v["type"], "p": v["pos"]} for v in m["verticals"]],
        "net": {"stack": slim_arch(m["architecture"]), "mirrored": slim_arch(m["architecture_mirrored"])},
    }


def main():
    src, out = sys.argv[1], sys.argv[2]
    maps = [pack(m) for m in json.load(open(src))["maps"]]
    html = (HERE / "template.html").read_text()
    html = html.replace("/*__DATA__*/null", json.dumps(maps, separators=(",", ":")))
    Path(out).write_text(html)
    print(f"{len(maps)} maps, {len(html) // 1024} KB → {out}")


if __name__ == "__main__":
    main()
