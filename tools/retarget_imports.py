#!/usr/bin/env python3
"""Write Godot .import settings that retarget rigged assets onto Godot's humanoid profile.

Every skeleton (Quaternius UE-style rig, Mixamo rig) is renamed to SkeletonProfileHumanoid bone
names with a unique-named "GeneralSkeleton" and rest-fixed, so any clip plays on any character.
Animation-only files import as AnimationLibrary resources. Run after adding assets, then
`godot --headless --import --path .`.
"""
import pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
UE = "res://assets/retarget/ue_bonemap.tres"
MX = "res://assets/retarget/mixamo_bonemap.tres"


def write(path: pathlib.Path, importer: str, skel: str, bonemap: str, extra: str = "") -> None:
	imp = path.with_name(path.name + ".import")
	sub = ('_subresources={\n"nodes": {\n"PATH:%s": {\n"retarget/bone_map": Resource("%s")\n}\n}\n}' % (skel, bonemap))
	if imp.exists():
		txt = imp.read_text()
		txt = re.sub(r'importer="[^"]*"', 'importer="%s"' % importer, txt, count=1)
		txt = re.sub(r'_subresources=\{.*?\n\}(?=\n[a-z_]+/|\n*$)|_subresources=\{\}', sub, txt, count=1, flags=re.S)
		if importer == "animation_library":
			txt = re.sub(r'\ntype="[^"]*"', '\ntype="AnimationLibrary"', txt, count=1)
		imp.write_text(txt)
	else:
		imp.write_text('[remap]\n\nimporter="%s"\n\n[params]\n\n%s\n%s' % (importer, sub, extra))


def main() -> None:
	q = ROOT / "assets/third_party/quaternius"
	for f in sorted((q / "characters").glob("*.gltf")) + sorted((q / "hair").glob("*.gltf")):
		write(f, "scene", "Armature/Skeleton3D", UE)
	for f in sorted((q / "animations").glob("*.glb")):
		write(f, "animation_library", "Armature/Skeleton3D", UE)
	for f in sorted((ROOT / "assets/mixamo").rglob("*.fbx")):
		write(f, "animation_library", "Skeleton3D", MX)
	print("ok")


if __name__ == "__main__":
	main()
