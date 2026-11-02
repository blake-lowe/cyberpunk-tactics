#!/usr/bin/env python3
"""Pick clips from the owner's Mixamo library into assets/mixamo (committed).

Reads the owner's Google Drive asset folder (downloaded with gdown, or a local copy via --src),
copies the curated clips in CLIPS under stable snake_case names (src/tactical/view/char_anims.gd
refers to them by these names), then imports them in Godot with retargeting onto the humanoid
profile (tools/retarget_imports.py). To add a clip: add a CLIPS entry and re-run. Safe to re-run.
"""
import argparse, pathlib, shutil, subprocess, sys, zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
DRIVE = "https://drive.google.com/drive/folders/1gboly3uvOolVPVwoF891kd2bTNcxTyo_"
OUT = ROOT / "assets/mixamo"

# clip name -> (zip in the mixamo folder or None for a loose file, file name)
CLIPS = {
	# rifle (Pro Rifle Pack, Basic Shooter Pack)
	"rifle_idle": ("Pro Rifle Pack.zip", "idle.fbx"),
	"rifle_aim": ("Pro Rifle Pack.zip", "idle aiming.fbx"),
	"rifle_crouch": ("Pro Rifle Pack.zip", "idle crouching.fbx"),
	"rifle_crouch_aim": ("Pro Rifle Pack.zip", "idle crouching aiming.fbx"),
	"rifle_walk": ("Pro Rifle Pack.zip", "walk forward.fbx"),
	"rifle_run": ("Pro Rifle Pack.zip", "run forward.fbx"),
	"rifle_sprint": ("Pro Rifle Pack.zip", "sprint forward.fbx"),
	"rifle_crouch_walk": ("Pro Rifle Pack.zip", "walk crouching forward.fbx"),
	"rifle_fire": ("Basic Shooter Pack.zip", "firing rifle.fbx"),
	"rifle_reload": ("Basic Shooter Pack.zip", "reloading.fbx"),
	"rifle_hit": ("Basic Shooter Pack.zip", "hit reaction.fbx"),
	"grenade_toss": ("Basic Shooter Pack.zip", "toss grenade.fbx"),
	"death_front": ("Pro Rifle Pack.zip", "death from the front.fbx"),
	"death_back": ("Pro Rifle Pack.zip", "death from the back.fbx"),
	"death_right": ("Pro Rifle Pack.zip", "death from right.fbx"),
	"death_head_front": ("Pro Rifle Pack.zip", "death from front headshot.fbx"),
	"death_head_back": ("Pro Rifle Pack.zip", "death from back headshot.fbx"),
	"death_crouch_head": ("Pro Rifle Pack.zip", "death crouching headshot front.fbx"),
	# pistol
	"pistol_idle": ("Pistol_Handgun Locomotion Pack.zip", "pistol idle.fbx"),
	"pistol_walk": ("Pistol_Handgun Locomotion Pack.zip", "pistol walk.fbx"),
	"pistol_run": ("Pistol_Handgun Locomotion Pack.zip", "pistol run.fbx"),
	"pistol_kneel": ("Pistol_Handgun Locomotion Pack.zip", "pistol kneeling idle.fbx"),
	# wounded
	"injured_idle": ("Male Injured Pack.zip", "injured idle.fbx"),
	"injured_hurt": ("Male Injured Pack.zip", "injured hurting idle.fbx"),
	"injured_walk": ("Male Injured Pack.zip", "injured walk.fbx"),
	"injured_run": ("Male Injured Pack.zip", "injured run.fbx"),
	# cover
	"cover_enter": ("Action Adventure Pack.zip", "stand to cover.fbx"),
	"cover_exit": ("Action Adventure Pack.zip", "cover to stand.fbx"),
	"cover_idle": (None, "Taking Cover Idle.fbx"),
	"cover_take": (None, "Taking Cover.fbx"),
	"cover_peek": (None, "Crouch Look Around Corner.fbx"),
	"cover_sneak_l": (None, "Left Cover Sneak.fbx"),
	"cover_sneak_r": (None, "Right Cover Sneak.fbx"),
	# reactions
	"hit_1": (None, "Hit Reaction.fbx"),
	"hit_2": (None, "Hit Reaction (1).fbx"),
	"hit_3": (None, "Hit Reaction (2).fbx"),
	"dodge_l": ("Pro Rifle Pack.zip", "run left.fbx"),    # a quick side-step (owner cut "Dodging")
	"dodge_r": ("Pro Rifle Pack.zip", "run right.fbx"),
	"death_alt_front": (None, "Death From Front Headshot.fbx"),
	# work and NET
	"typing": (None, "Typing.fbx"),
	"kneel": (None, "Kneel.fbx"),
	"kneel_inspect": (None, "Kneeling Inspecting.fbx"),
	"medtech_cpr": (None, "Administering Cpr.fbx"),
	# melee
	"melee_stab": (None, "Stabbing.fbx"),
	"melee_jab": (None, "Jab Cross.fbx"),
	"melee_hook": (None, "Hook.fbx"),
	"melee_heavy": (None, "Heavy Weapon Swing.fbx"),
	"melee_kick": (None, "Roundhouse Kick.fbx"),
	"knife_idle": (None, "Knife Idle.fbx"),
	# ambient (unalerted guards, crew between turns)
	"idle": (None, "Idle.fbx"),
	"idle_look": (None, "Looking.fbx"),
	"idle_phone": (None, "Talking On A Cell Phone.fbx"),
	"idle_argue": (None, "Standing Arguing.fbx"),
	"idle_talk": (None, "Talking.fbx"),
	"idle_shift": ("Gestures Pack Basic.zip", "weight shift.fbx"),
	"sit_idle": (None, "Sitting Idle.fbx"),
	"scared": (None, "Scared.fbx"),
}


def godot() -> str:
	for c in ("godot", "/opt/godot/godot"):
		if shutil.which(c):
			return c
	sys.exit("godot not found (tools/install_godot.sh)")


def main() -> None:
	ap = argparse.ArgumentParser()
	ap.add_argument("--src", help="local copy of the Drive folder (skips the download)")
	ap.add_argument("--no-import", action="store_true")
	a = ap.parse_args()
	src = pathlib.Path(a.src) if a.src else ROOT / "build/mixamo_download"
	if not a.src:
		src.mkdir(parents=True, exist_ok=True)
		if not (src / "mixamo").exists():
			try:
				import gdown  # noqa: F401
			except ImportError:
				sys.exit("pip install gdown, or pass --src with a downloaded copy")
			subprocess.run([sys.executable, "-m", "gdown", "--folder", DRIVE, "-O", str(src)], check=True)
	mx = next((p for p in [src / "mixamo", src] if (p / "Pro Rifle Pack.zip").exists()), None)
	if mx is None:
		sys.exit("no mixamo folder under %s" % src)
	OUT.mkdir(parents=True, exist_ok=True)
	zips: dict = {}
	missing = []
	for name, (zname, fname) in CLIPS.items():
		dst = OUT / (name + ".fbx")
		if dst.exists():
			continue
		if zname is None:
			p = mx / fname
			if p.exists():
				shutil.copyfile(p, dst)
			else:
				missing.append(fname)
			continue
		z = zips.get(zname) or zipfile.ZipFile(mx / zname)
		zips[zname] = z
		hit = [n for n in z.namelist() if n.split("/")[-1].lower() == fname.lower()]
		if not hit:
			missing.append("%s/%s" % (zname, fname))
			continue
		with z.open(hit[0]) as f, open(dst, "wb") as o:
			shutil.copyfileobj(f, o)
	print("clips:", len(list(OUT.glob("*.fbx"))), "missing:", missing or "none")
	if a.no_import:
		return
	g = godot()
	# first import creates default .import files; then retarget settings; then reimport
	subprocess.run(["timeout", "600", g, "--headless", "--import", "--path", str(ROOT)], capture_output=True)
	subprocess.run([sys.executable, str(ROOT / "tools/retarget_imports.py")], check=True)
	subprocess.run(["timeout", "600", g, "--headless", "--import", "--path", str(ROOT)], capture_output=True)
	print("imported")


if __name__ == "__main__":
	main()
