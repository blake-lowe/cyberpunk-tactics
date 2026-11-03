#!/usr/bin/env python3
"""Import a curated subset of Quaternius' CC0 Sci-Fi Essentials Kit and Modular SciFi MegaKit
(owner's Drive folder) into assets/third_party/quaternius/scifi/.

The game renders at ~360 lines through a palette post-process, so only base colour (and emissive)
textures matter: normal / ORM / detail maps are dropped from the glTF materials and the kept
textures are downscaled to 512 px. That keeps the repo small (~a few MB instead of ~110 MB).

Usage: python3 tools/import_scifi.py ESSENTIALS_DIR MEGAKIT_DIR
  ESSENTIALS_DIR: the unzipped "Sci-Fi Essentials Kit[Standard]" (has glTF/ and Textures/)
  MEGAKIT_DIR:    the unzipped "Modular SciFi MegaKit[Standard]" (has glTF/<group>/ and Textures/)
"""
import json
import os
import shutil
import sys

from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets/third_party/quaternius/scifi")
TEX_SIZE = 512

ESSENTIALS = ["Prop_Chair", "Prop_Desk_L", "Prop_Desk_Medium", "Prop_Desk_Small", "Prop_Locker",
              "Prop_Shelves_ThinShort", "Prop_Shelves_ThinTall", "Prop_Shelves_WideShort", "Prop_Shelves_WideTall",
              "Prop_Crate", "Prop_Crate_Large", "Prop_Crate_Tarp", "Prop_Crate_Tarp_Large", "Prop_Barrel1",
              "Prop_Barrel2_Closed", "Prop_Chest", "Prop_HealthPack", "Prop_HealthPack_Tube", "Prop_Ammo",
              "Prop_Ammo_Closed", "Prop_Ammo_Small", "Prop_Grenade", "Prop_Mug", "Prop_Syringe", "Prop_KeyCard"]
MEGAKIT = {
    "Props": ["Prop_Computer", "Prop_AccessPoint", "Prop_Light_Floor", "Prop_Light_Small", "Prop_Light_Wide",
              "Prop_Light_Corner", "Prop_Vent_Big", "Prop_Vent_Small", "Prop_Vent_Wide", "Prop_Cable_1", "Prop_Cable_3",
              "Prop_Fan_Small", "Prop_Crate3", "Prop_Crate4", "Prop_Barrel_Large", "Prop_ItemHolder", "Prop_PipeHolder"],
    "Columns": ["Column_Simple", "Column_Pipes", "Column_MetalSupport"],
    "Walls": ["WallBand_Straight", "WallAstra_Straight", "WallWindow_Straight", "ShortWall_DarkMetal2_Straight",
              "ShortWall_MetalPlates_Straight", "ShortWall_Simple1_Straight"],
    "Platforms": ["Platform_Metal", "Platform_Simple", "Platform_DarkPlates", "Platform_Squares"],
}
KEEP_SLOTS = ("baseColorTexture", "emissiveTexture")


def _strip(g: dict) -> list:
    """Keep only base colour / emissive textures; return the image file names still used."""
    used_tex = set()
    for m in g.get("materials", []):
        for k in ("normalTexture", "occlusionTexture"):
            m.pop(k, None)
        pbr = m.get("pbrMetallicRoughness", {})
        pbr.pop("metallicRoughnessTexture", None)
        m.pop("extensions", None)   # detail masks etc.
        for slot in ("baseColorTexture",):
            if slot in pbr:
                used_tex.add(pbr[slot]["index"])
        if "emissiveTexture" in m:
            used_tex.add(m["emissiveTexture"]["index"])
    textures = g.get("textures", [])
    images = g.get("images", [])
    keep_tex = sorted(used_tex)
    tex_map = {old: new for new, old in enumerate(keep_tex)}
    keep_img = sorted({textures[i]["source"] for i in keep_tex})
    img_map = {old: new for new, old in enumerate(keep_img)}
    g["textures"] = [dict(textures[i], source=img_map[textures[i]["source"]]) for i in keep_tex]
    g["images"] = [images[i] for i in keep_img]
    for m in g.get("materials", []):
        pbr = m.get("pbrMetallicRoughness", {})
        if "baseColorTexture" in pbr:
            pbr["baseColorTexture"]["index"] = tex_map[pbr["baseColorTexture"]["index"]]
        if "emissiveTexture" in m:
            m["emissiveTexture"]["index"] = tex_map[m["emissiveTexture"]["index"]]
    if not g["textures"]:
        g.pop("textures")
        g.pop("images")
        g.pop("samplers", None)
    names = []
    for im in g.get("images", []):
        names.append(os.path.basename(im["uri"]))
        im["uri"] = "../textures/" + os.path.basename(im["uri"])
    return names


def _import(src_gltf: str, tex_dir: str, name: str, needed: set) -> None:
    g = json.load(open(src_gltf))
    needed.update((n, tex_dir) for n in _strip(g))
    for b in g.get("buffers", []):
        shutil.copy(os.path.join(os.path.dirname(src_gltf), b["uri"]), os.path.join(OUT, "models", name + ".bin"))
        b["uri"] = name + ".bin"
    json.dump(g, open(os.path.join(OUT, "models", name + ".gltf"), "w"), indent=1)


def main() -> None:
    ess, mega = sys.argv[1], sys.argv[2]
    os.makedirs(os.path.join(OUT, "models"), exist_ok=True)
    os.makedirs(os.path.join(OUT, "textures"), exist_ok=True)
    needed: set = set()
    for n in ESSENTIALS:
        _import(os.path.join(ess, "glTF", n + ".gltf"), os.path.join(ess, "Textures"), n, needed)
    for group, names in MEGAKIT.items():
        for n in names:
            out_name = ("Mega_" + n) if n in ESSENTIALS else n
            _import(os.path.join(mega, "glTF", group, n + ".gltf"), os.path.join(mega, "Textures"), out_name, needed)
    tex_dirs = [os.path.join(ess, "Textures"), os.path.join(mega, "Textures")]
    for fname in sorted({n for n, _ in needed}):   # the kits share trim sheets; look in both
        path = next(p for p in (os.path.join(d, fname) for d in tex_dirs) if os.path.exists(p))
        im = Image.open(path)
        im.thumbnail((TEX_SIZE, TEX_SIZE), Image.LANCZOS)
        im.save(os.path.join(OUT, "textures", fname), optimize=True)
    shutil.copy(os.path.join(ess, "License_Standard.txt"), os.path.join(OUT, "LICENSE-scifi-essentials.txt"))
    shutil.copy(os.path.join(mega, "License_Standard.txt"), os.path.join(OUT, "LICENSE-scifi-megakit.txt"))
    print("models:", len(ESSENTIALS) + sum(len(v) for v in MEGAKIT.values()), "textures:", len({n for n, _ in needed}))


if __name__ == "__main__":
    main()
