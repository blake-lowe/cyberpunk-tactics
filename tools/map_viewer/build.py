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

    def slim_net(a):
        nodes = []
        for n in a["nodes"]:
            e = {"id": n["id"], "t": n["type"], "z": n["zone"], "s": n["subnet"], "no": n.get("net_only", False)}
            for k in ("dv", "devices", "group", "device", "value", "label"):
                if k in n:
                    e[k] = int(n[k]) if k in ("dv", "device", "value") else n[k]
            nodes.append(e)
        return {"difficulty": a["difficulty"], "complexity": a["complexity"], "budget": a["budget"], "spent": a["spent"],
                "nodes": nodes, "edges": a["edges"], "subnets": a["subnets"], "ice": a["ice"], "aps": a["access_points"]}

    return {
        "site": m["params"].get("site", ""), "algo": m["algorithm"], "seed": m["seed"], "sec": m["params"]["security"], "w": w, "h": h,
        "nf": m["floors"], "floors": floors, "rooms": rooms,
        "doors": [{"f": d["floor"], "p": d["pos"], "s": d["security"]} for d in m["doors"]],
        "cover": [{"f": c["floor"], "p": c["pos"], "k": c["kind"], "hp": c["hp"], "pr": c.get("prop", -1)} for c in m["cover"]],
        "dev": [{"id": d["id"], "f": d["floor"], "p": d["pos"], "t": d["type"], "g": d["group"], "z": d["zone"],
                 "ap": d.get("access_point", False), "fv": d.get("file_value", 0), "s": d.get("structure", -1)} for d in m["devices"]],
        "ent": [{"f": e["floor"], "p": e["pos"], "main": e["main"], "k": e["kind"]} for e in m["entrances"]],
        "vert": [{"t": v["type"], "p": v["pos"]} for v in m["verticals"]],
        "nets": {k: slim_net(v) for k, v in m["architectures"].items()},
        "ground": "".join(chr(48 + g) for g in m["ground"]),
        "structures": [{"id": st["id"], "kind": st["kind"], "site": st["site"], "rect": st["rect"], "floors": st["floors"],
                        "sec": st["security"], "target": st["target"]} for st in m["structures"]],
        "scene": m["params"].get("scene", ""),
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
