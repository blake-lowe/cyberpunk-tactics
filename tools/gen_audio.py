#!/usr/bin/env python3
"""Synthesise the game's audio (owner: code-generated assets are fine; no sound packs reachable).

Writes 16-bit mono WAVs to assets/audio/: sound effects (sfx_*), per-scene ambience loops (amb_*)
and two music loops (mus_*). Everything is procedural (numpy only), seeded, so a rerun gives the same
files. Tweak a recipe below and rerun:  python3 tools/gen_audio.py [name ...]
Loops are rendered with their reverb/decay tails wrapped onto the start, so they loop seamlessly.
"""
import os
import sys
import wave
import zlib

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(2077)


# --- building blocks ------------------------------------------------------------------------------

def t(sec):
    return np.arange(int(sec * SR)) / SR


def noise(sec):
    return rng.uniform(-1, 1, int(sec * SR))


def env(sec, attack=0.002, tau=0.1):
    x = t(sec)
    a = np.clip(x / max(attack, 1e-4), 0, 1)
    return a * np.exp(-np.maximum(x - attack, 0) / tau)


def lp(x, hz):
    a = np.exp(-2 * np.pi * hz / SR)
    y = np.empty_like(x)
    s = 0.0
    for i, v in enumerate(x):
        s = (1 - a) * v + a * s
        y[i] = s
    return y


def lp_fast(x, hz, passes=2):
    # vectorised-ish one-pole via exponential smoothing on blocks (good enough for noise beds)
    y = x
    for _ in range(passes):
        y = lp(y, hz)
    return y


def hp(x, hz):
    return x - lp(x, hz)


def bp(x, lo, hi):
    return lp(hp(x, lo), hi)


def sweep(sec, f0, f1, shape="sine", curve=1.0):
    x = t(sec)
    k = (x / sec) ** curve
    f = f0 + (f1 - f0) * k
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "square":
        return np.sign(np.sin(ph))
    if shape == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1.0) - 1
    return np.sin(ph)


def tone(sec, hz, shape="sine"):
    return sweep(sec, hz, hz, shape)


def drive(x, k=2.0):
    return np.tanh(x * k) / np.tanh(k)


def pad(x, sec):
    n = int(sec * SR)
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(x, sec, total):
    out = np.zeros(int(total * SR))
    i = int(sec * SR)
    j = min(len(out), i + len(x))
    if i < len(out):
        out[i:j] += x[:j - i]
    return out


def reverb(x, size=0.3, wet=0.3, decay=0.5):
    """Small Schroeder reverb (4 combs + 2 allpasses)."""
    tail = int(SR * (size * 4 + 0.5))
    y = np.concatenate([x, np.zeros(tail)])
    out = np.zeros_like(y)
    for d in [0.0297, 0.0371, 0.0411, 0.0437]:
        n = int(SR * d * (size / 0.3))
        buf = np.zeros_like(y)
        g = decay ** (d / 0.03)
        for i in range(len(y)):
            buf[i] = y[i] + (g * buf[i - n] if i >= n else 0.0)
        out += buf
    for d, g in [(0.005, 0.7), (0.0017, 0.7)]:
        n = int(SR * d)
        z = np.zeros_like(out)
        for i in range(len(out)):
            xn = out[i - n] if i >= n else 0.0
            zn = z[i - n] if i >= n else 0.0
            z[i] = -g * out[i] + xn + g * zn
        out = z
    out /= 4
    return np.concatenate([x, np.zeros(tail)]) * (1 - wet) + out * wet


def norm(x, peak=0.89):
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def fade(x, fin=0.002, fout=0.02):
    n = len(x)
    a = np.ones(n)
    i = min(n, int(fin * SR))
    o = min(n, int(fout * SR))
    if i:
        a[:i] = np.linspace(0, 1, i)
    if o:
        a[n - o:] *= np.linspace(1, 0, o)
    return x * a


def loop_self(x, length_sec, xfade=1.5):
    """Seamless ambience loop (beds have no material past the end): fold tails onto the start,
    then crossfade the loop's own last `xfade` seconds into its first, shortening it by that much."""
    y = loop_wrap(x, length_sec, 0.0)
    xf = int(xfade * SR)
    w = np.sin(np.linspace(0, np.pi / 2, xf)) ** 2
    out = y[:len(y) - xf].copy()
    out[:xf] = y[:xf] * w + y[len(y) - xf:] * (1 - w)
    return out


def loop_wrap(x, length_sec, xfade=1.0):
    """Make a seamless loop of `length_sec`: the material just past the end crossfades into the
    start (so the last sample runs straight on into the first), and longer tails fold back on."""
    n = int(length_sec * SR)
    xf = min(int(xfade * SR), n // 4)
    if xf == 0:
        out = np.zeros(n)
        for i in range(0, len(x), n):
            seg = x[i:i + n]
            out[:len(seg)] += seg
        return out
    if len(x) < n + xf:
        x = np.concatenate([x, np.zeros(n + xf - len(x))])
    out = x[:n].copy()
    w = np.sin(np.linspace(0, np.pi / 2, xf)) ** 2
    out[:xf] = x[:xf] * w + x[n:n + xf] * (1 - w)
    rest = x[n + xf:]
    for i in range(0, len(rest), n):
        seg = rest[i:i + n]
        out[xf:xf + len(seg)] += seg[:n - xf]
    return out


def write(name, x, peak=0.89, trim=False):
    os.makedirs(OUT, exist_ok=True)
    y = norm(x, peak)
    if trim:   # drop the silent end of a reverb tail (-60 dB), with a short fade
        loud = np.nonzero(np.abs(y) > peak * 0.001)[0]
        if len(loud):
            y = fade(y[:min(len(y), loud[-1] + int(0.02 * SR))], 0.0, 0.03)
    data = (np.clip(y, -1, 1) * 32767).astype("<i2").tobytes()
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data)
    print("%-22s %5.2fs" % (name, len(y) / SR))


# --- sound effects ---------------------------------------------------------------------------------

def gunshot(crack_hz, body_hz, tau_body, thump_hz, tail, size, drive_k=2.5):
    crack = hp(noise(0.05), crack_hz) * env(0.05, 0.0005, 0.008)
    body = lp(noise(0.5), body_hz) * env(0.5, 0.001, tau_body)
    thump = sweep(0.2, thump_hz * 2.2, thump_hz, curve=0.4) * env(0.2, 0.001, 0.05)
    x = mix(crack * 0.9, body * 1.4, thump * 1.0)
    x = drive(x, drive_k)
    return fade(reverb(x, size=size, wet=tail, decay=0.45), 0.0005, 0.08)


SFX = {}


def sfx(fn):
    SFX[fn.__name__] = fn
    return fn


@sfx
def sfx_shot_pistol():
    return gunshot(1800, 3200, 0.035, 140, 0.25, 0.25)


@sfx
def sfx_shot_rifle():
    return gunshot(1400, 2600, 0.05, 110, 0.3, 0.32, 3.0)


@sfx
def sfx_shot_smg():
    return gunshot(2200, 3600, 0.025, 160, 0.2, 0.2)


@sfx
def sfx_shot_shotgun():
    return gunshot(900, 1500, 0.09, 70, 0.35, 0.4, 3.5)


@sfx
def sfx_ricochet():
    x = sweep(0.35, 3400, 1300, curve=0.6) * env(0.35, 0.002, 0.12) * 0.6
    return fade(reverb(mix(x, hp(noise(0.04), 3000) * env(0.04, 0.0005, 0.01)), 0.2, 0.25))


@sfx
def sfx_hit_flesh():
    thud = lp(noise(0.2), 500) * env(0.2, 0.001, 0.04)
    slap = bp(noise(0.06), 800, 2500) * env(0.06, 0.0005, 0.012)
    return fade(mix(thud * 1.6, slap * 0.5), 0.0005)


@sfx
def sfx_hit_armor():
    x = sum(np.sin(2 * np.pi * f * t(0.5)) * np.exp(-t(0.5) / d) * a
            for f, d, a in [(880, 0.12, 0.6), (2410, 0.07, 0.4), (3690, 0.05, 0.3), (5200, 0.03, 0.2)])
    return fade(reverb(mix(x, hp(noise(0.03), 2500) * env(0.03, 0.0003, 0.006)), 0.15, 0.2))


@sfx
def sfx_glass_break():
    total = 0.9
    x = np.zeros(int(total * SR))
    for k in range(40):
        st = rng.uniform(0, 0.5) ** 1.5
        f = rng.uniform(2500, 7000)
        p = np.sin(2 * np.pi * f * t(0.12)) * env(0.12, 0.0005, rng.uniform(0.01, 0.04)) * rng.uniform(0.2, 0.6)
        x += at(p, st, total)
    x += hp(noise(total), 2000) * env(total, 0.001, 0.08) * 0.6
    return fade(reverb(x, 0.25, 0.2))


@sfx
def sfx_debris():
    total = 0.8
    x = lp(noise(total), 700) * env(total, 0.002, 0.15) * 1.2
    for k in range(25):
        g = lp(noise(0.04), rng.uniform(400, 1500)) * env(0.04, 0.0005, 0.01)
        x += at(g * rng.uniform(0.3, 0.8), rng.uniform(0, 0.6), total)
    return fade(x)


@sfx
def sfx_explosion():
    total = 2.4
    boom = lp(lp(noise(total), 260), 400) * env(total, 0.003, 0.45) * 3.0
    sub = sweep(1.2, 70, 32, curve=0.5) * env(1.2, 0.002, 0.3) * 1.5
    crack = hp(noise(0.08), 1200) * env(0.08, 0.0005, 0.02)
    crackle = np.zeros(int(total * SR))
    for k in range(60):
        g = hp(noise(0.01), 1500) * env(0.01, 0.0002, 0.002)
        crackle += at(g * rng.uniform(0.1, 0.4), 0.05 + rng.uniform(0, 1.2) ** 2, total)
    x = drive(mix(boom, sub, crack, crackle), 2.0)
    return fade(reverb(x, 0.6, 0.35, 0.6), 0.001, 0.4)


@sfx
def sfx_throw():
    x = bp(noise(0.35), 400, 1800) * np.sin(np.pi * t(0.35) / 0.35) ** 2
    return fade(x * 0.8)


@sfx
def sfx_swing():
    x = bp(noise(0.25), 600, 2600) * np.sin(np.pi * t(0.25) / 0.25) ** 3
    return fade(x)


@sfx
def sfx_melee_hit():
    return fade(mix(lp(noise(0.25), 400) * env(0.25, 0.001, 0.05) * 1.6, bp(noise(0.05), 1500, 4000) * env(0.05, 0.0003, 0.01) * 0.6,
                    sweep(0.15, 160, 60) * env(0.15, 0.001, 0.04)))


def click(hz=2500, tau=0.004, sec=0.03):
    return bp(noise(sec), hz * 0.6, hz * 1.6) * env(sec, 0.0003, tau)


@sfx
def sfx_reload():
    total = 0.9
    x = at(click(1800, 0.006), 0.0, total) * 0.9 + at(bp(noise(0.12), 500, 2500) * env(0.12, 0.01, 0.04), 0.12, total) * 0.4
    x += at(click(2600, 0.005), 0.55, total) + at(click(1400, 0.008), 0.62, total) * 0.8
    return fade(reverb(x, 0.1, 0.15))


@sfx
def sfx_step():
    return fade(mix(lp(noise(0.09), 900) * env(0.09, 0.001, 0.018), at(lp(noise(0.05), 1600) * env(0.05, 0.001, 0.01) * 0.5, 0.035, 0.09)))


@sfx
def sfx_door():
    x = mix(tone(0.5, 95, "saw") * 0.25 * np.sin(np.pi * t(0.5) / 0.5), bp(noise(0.5), 300, 1200) * 0.3 * np.sin(np.pi * t(0.5) / 0.5),
            at(click(900, 0.02, 0.08), 0.45, 0.55))
    return fade(x)


@sfx
def sfx_zap():
    total = 0.5
    x = tone(total, 120, "square") * 0.3 * env(total, 0.005, 0.2)
    for k in range(18):
        x += at(hp(noise(0.015), 2000) * env(0.015, 0.0002, 0.004) * rng.uniform(0.3, 1.0), rng.uniform(0, 0.4), total)
    return fade(drive(x, 2.0))


@sfx
def sfx_beep():
    return fade(mix(tone(0.08, 1320) * env(0.08, 0.002, 0.04), at(tone(0.12, 1760) * env(0.12, 0.002, 0.06), 0.09, 0.22)) * 0.6)


@sfx
def sfx_ui_click():
    return fade(mix(click(3000, 0.003, 0.03), tone(0.03, 1800) * env(0.03, 0.0005, 0.006) * 0.4))


@sfx
def sfx_ui_hover():
    return fade(tone(0.04, 2400) * env(0.04, 0.001, 0.008) * 0.4)


@sfx
def sfx_ui_confirm():
    return fade(mix(tone(0.1, 880, "square") * 0.2 * env(0.1, 0.002, 0.05), at(tone(0.16, 1320, "square") * 0.2 * env(0.16, 0.002, 0.07), 0.07, 0.25)))


@sfx
def sfx_ui_error():
    return fade(tone(0.25, 170, "square") * env(0.25, 0.003, 0.12) * 0.5)


@sfx
def sfx_turn():
    def bell(f, sec):
        x = t(sec)
        return np.sin(2 * np.pi * f * x + 2.0 * np.exp(-x / 0.2) * np.sin(2 * np.pi * f * 1.41 * x)) * np.exp(-x / 0.35)
    return fade(reverb(mix(bell(660, 0.8) * 0.5, at(bell(990, 0.9) * 0.4, 0.12, 1.0)), 0.3, 0.3))


@sfx
def sfx_jack_in():
    total = 1.2
    x = sweep(total, 200, 2400, "square", 2.0) * 0.18 * np.sin(np.pi * t(total) / total)
    for k, f in enumerate([523, 659, 784, 1046, 1318, 1568]):
        x += at(tone(0.07, f, "square") * env(0.07, 0.002, 0.03) * 0.25, 0.1 + k * 0.12, total)
    crushed = np.round(x * 8) / 8
    return fade(reverb(crushed, 0.3, 0.3))


@sfx
def sfx_net_blip():
    return fade(mix(tone(0.05, 880, "square") * 0.3 * env(0.05, 0.001, 0.02), at(tone(0.05, 1175, "square") * 0.25 * env(0.05, 0.001, 0.02), 0.05, 0.1)))


@sfx
def sfx_ice_hit():
    x = sweep(0.6, 1800, 90, "saw", 0.5) * env(0.6, 0.002, 0.25) + hp(noise(0.6), 1000) * env(0.6, 0.001, 0.08) * 0.5
    return fade(drive(np.round(x * 6) / 6, 3.0))


@sfx
def sfx_alarm():
    total = 2.0   # loops: one siren period
    x = t(total)
    f = 700 + 250 * np.sin(2 * np.pi * x / total)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR))
    return s * 0.5


@sfx
def sfx_death():
    total = 0.7
    return fade(mix(lp(noise(0.4), 300) * env(0.4, 0.002, 0.08) * 1.8, at(lp(noise(0.25), 600) * env(0.25, 0.002, 0.05), 0.18, total),
                    at(bp(noise(0.3), 800, 3000) * env(0.3, 0.01, 0.08) * 0.3, 0.05, total)))


@sfx
def sfx_dodge():
    return fade(bp(noise(0.18), 900, 3500) * np.sin(np.pi * t(0.18) / 0.18) ** 2 * 0.8)


@sfx
def sfx_inject():
    return fade(mix(click(1600, 0.006), at(hp(noise(0.35), 3000) * env(0.35, 0.01, 0.12) * 0.6, 0.04, 0.4)))


@sfx
def sfx_brass():
    return fade(sum(np.sin(2 * np.pi * f * t(0.12)) * np.exp(-t(0.12) / 0.02) for f in [4100, 5900, 7300]) * 0.3)


# --- wound states and gig ends (CalloutQueue.WOUND, Greybox._end_juice) ----------------------------
# Own seeded generator per sound, so these render the same alone or in a full run and don't shift
# the shared `rng` stream the older recipes draw from.

def _rn(seed, sec):
    return np.random.default_rng(seed).uniform(-1, 1, int(sec * SR))


def _body_hit(seed, weight=1.0):
    """A body taking a blow: a low sub thump with a muffled flesh slap on top."""
    sub = sweep(0.35, 110 * weight + 40, 38, curve=0.35) * env(0.35, 0.001, 0.07 + 0.05 * weight)
    meat = lp(_rn(seed, 0.3), 380) * env(0.3, 0.001, 0.035 + 0.03 * weight)
    slap = bp(_rn(seed + 1, 0.05), 700, 2400) * env(0.05, 0.0004, 0.01)
    return drive(mix(sub * 1.2 * weight, meat * 1.7, slap * 0.45), 1.5 + weight)


def _heartbeat(seed, gain=1.0):  # STABILIZED only (owner: no heartbeat on the death states)
    """One lub-dub: two dull chest thuds, the second softer."""
    def thud(sec, f0, s):
        return (sweep(sec, f0, f0 * 0.6, curve=0.5) + lp(_rn(s, sec), 150) * 0.5) * env(sec, 0.004, 0.045)
    return mix(thud(0.22, 62, seed) * gain, at(thud(0.18, 52, seed + 1) * 0.6 * gain, 0.17, 0.4))


def _breath(seed, sec, lo, hi, rasp=0.0, rate=11.0):
    """Breath through the teeth: band-passed air under a swell; `rasp` adds a ragged flutter."""
    x = t(sec)
    swell = np.sin(np.pi * x / sec) ** 1.5
    jitter = np.random.default_rng(seed + 7).uniform(0.6, 1.0, int(sec * rate) + 2)
    flutter = 1.0 - rasp + rasp * np.interp(x * rate, np.arange(len(jitter)), jitter) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * rate * x)))
    return bp(_rn(seed, sec), lo, hi) * swell * flutter


@sfx
def sfx_wound_serious():
    """SERIOUSLY WOUNDED: a body hit and a sharp pained breath out."""
    total = 0.75
    return fade(reverb(mix(_body_hit(301, 0.7), at(_breath(302, 0.42, 600, 2000, 0.25) * 0.55, 0.1, total)), 0.15, 0.12))


@sfx
def sfx_wound_mortal():
    """MORTALLY WOUNDED: a heavy body hit, the knees hitting the floor, and a ragged pained breath."""
    total = 1.6
    x = at(_body_hit(311, 1.4) * 1.3, 0.0, total)
    x += at(_body_hit(313, 0.8) * 0.7, 0.34, total)                            # down on the knees
    x += at(_breath(316, 0.4, 800, 2600, 0.55, 13.0) * 0.45, 0.16, total)     # the gasp in
    x += at(_breath(318, 0.7, 450, 1500, 0.8, 9.0) * 0.42, 0.62, total)       # the rattle out
    return fade(reverb(x, 0.2, 0.15, 0.4), 0.0005, 0.15)


@sfx
def sfx_unconscious():
    """UNCONSCIOUS: a dull drop and the air knocked out."""
    total = 0.8
    return fade(mix(_body_hit(321, 0.5), at(_body_hit(323, 0.35) * 0.5, 0.2, total), at(_breath(322, 0.3, 300, 1100, 0.1) * 0.45, 0.06, total)))


@sfx
def sfx_stabilized():
    """STABILIZED: two steady heartbeats and a clean monitor blip."""
    total = 1.0
    blip = np.sin(2 * np.pi * 1320 * t(0.09)) * env(0.09, 0.003, 0.05) * 0.22
    x = mix(at(_heartbeat(331, 0.8), 0.0, total), at(_heartbeat(333, 0.7), 0.52, total), at(blip, 0.06, total), at(blip * 0.8, 0.58, total))
    return fade(reverb(x, 0.12, 0.1))


@sfx
def sfx_collapse():
    """FLATLINED: impacts only. A final hit, the body folding, and the dead weight hitting the floor."""
    total = 1.3
    x = at(_body_hit(341, 1.2), 0.0, total)
    x += at(_body_hit(343, 0.6) * 0.55, 0.22, total)                           # knees
    drop = drive(mix(sweep(0.6, 70, 30, curve=0.4) * env(0.6, 0.002, 0.16) * 1.4,
                     lp(_rn(345, 0.5), 300) * env(0.5, 0.002, 0.07) * 1.6, bp(_rn(346, 0.12), 400, 1800) * env(0.12, 0.001, 0.03) * 0.5), 2.5)
    x += at(drop, 0.42, total)                                                  # the body lands
    x += at(lp(_rn(347, 0.15), 600) * env(0.15, 0.001, 0.03) * 0.4, 0.62, total)   # an arm after it
    return fade(reverb(x, 0.2, 0.15, 0.4), 0.0005, 0.12)


@sfx
def sfx_gig_fail():
    """Gig failed: a deep impact, then a detuned minor chord sagging down and out."""
    total = 2.2
    boom = drive(mix(sweep(0.9, 75, 28, curve=0.4) * env(0.9, 0.002, 0.3), lp(_rn(351, 0.6), 220) * env(0.6, 0.002, 0.12)), 2.0)
    chord = np.zeros(int(total * SR))
    for k, n in enumerate([45, 48, 52, 57]):   # A minor, sagging a minor third over the hold
        f0 = midi(n)
        sw = sweep(1.9, f0, f0 * 0.84, "saw", 0.8) + sweep(1.9, f0 * 1.007, f0 * 0.847, "saw", 0.8)
        chord += at(lp(sw, 900 - 120 * k) * env(1.9, 0.04, 0.8) * 0.16, 0.05, total)
    return fade(reverb(mix(boom * 1.2, chord), 0.5, 0.3, 0.5), 0.0005, 0.3)


@sfx
def sfx_gig_win():
    """Gig complete: a bright impact and a major chord opening up, a quick climbing arpeggio on top."""
    total = 1.9
    hit = drive(mix(sweep(0.4, 140, 55, curve=0.4) * env(0.4, 0.001, 0.09), hp(_rn(361, 0.08), 3000) * env(0.08, 0.0005, 0.02) * 0.5), 2.0)
    chord = np.zeros(int(total * SR))
    for n in [57, 61, 64, 69]:   # A major
        chord += at(synth_note(midi(n), 1.5, "saw", 2600, 0.6, 0.008, 0.02) * 0.14, 0.03, total)
    arp = np.zeros(int(total * SR))
    for i, n in enumerate([69, 73, 76, 81]):
        arp += at(synth_note(midi(n), 0.14, "square", 3200, 0.06, 0.0, 0.003) * 0.06, 0.08 + 0.07 * i, total)
    return fade(reverb(mix(hit, chord, arp), 0.4, 0.25, 0.45), 0.0005, 0.3)


# --- non-firearm weapon sounds (data/gen/weapon_fx.json kinds) ------------------------------------
# Each recipe runs on its own seeded generator (own_rng), so adding or tweaking one never changes
# the sounds rendered after it.

def own_rng(fn):
    def wrapped():
        global rng
        saved = rng
        rng = np.random.default_rng(zlib.crc32(fn.__name__.encode()))
        try:
            return fn()
        finally:
            rng = saved
    wrapped.__name__ = fn.__name__
    return wrapped


def pluck(hz, sec, damp=0.996, bright=0.5):
    """Karplus-Strong string: a bow or crossbow string let go."""
    n = int(sec * SR)
    p = max(2, int(SR / hz))
    buf = rng.uniform(-1, 1, p)
    buf = lp(buf, 6000 * bright)
    out = np.empty(n)
    for i in range(n):
        j = i % p
        out[i] = buf[j]
        buf[j] = damp * 0.5 * (buf[j] + buf[(j + 1) % p])
    return out


def grains(total, count, lo_hz, spread, amp=(0.2, 0.8), sec=0.012, tau=0.003):
    """`count` short high-passed noise clicks scattered over `spread` seconds (crackle)."""
    x = np.zeros(int(total * SR))
    for k in range(count):
        g = hp(noise(sec), lo_hz) * env(sec, 0.0002, tau)
        x += at(g * rng.uniform(*amp), rng.uniform(0, spread), total)


# --- grappling (CPR core p.177: Grab, Choke, Throw; Greybox._anim_grapple) -----------------------
# Own seeded generators, like the wound states, so adding these shifts no other recipe.

def _scuffle(seed, sec, lo=250, hi=1600):
    """Cloth and kevlar bunched in a fist: a few quick rough rustles."""
    x = np.zeros(int(sec * SR))
    g = np.random.default_rng(seed)
    for k in range(5):
        d = g.uniform(0.04, 0.09)
        burst = bp(_rn(seed + 10 + k, d), lo, hi) * env(d, 0.002, d * 0.35) * g.uniform(0.5, 1.0)
        x += at(burst, g.uniform(0.0, sec - d), sec)
    return x


@sfx
@own_rng
def sfx_shot_air():
    """Air Pistol (p.347): a soft pneumatic puff, a click, no bang."""
    puff = bp(noise(0.14), 300, 2400) * env(0.14, 0.002, 0.03)
    pop = sweep(0.06, 320, 120) * env(0.06, 0.001, 0.015) * 0.6
    return fade(reverb(mix(puff, pop, click(1400, 0.003) * 0.5), 0.1, 0.1) * 0.7)


@sfx
@own_rng
def sfx_shot_dart():
    """Dartgun (p.348): a quiet thwip."""
    whip = sweep(0.09, 2600, 650, curve=0.5) * env(0.09, 0.001, 0.025)
    hiss = hp(noise(0.12), 3500) * env(0.12, 0.002, 0.03) * 0.5
    return fade(mix(click(1800, 0.003) * 0.5, whip * 0.7, hiss) * 0.7)


@sfx
@own_rng
def sfx_shot_microwave():
    """Microwaver (p.348): an electrical hum with a wavering whine; no report."""
    total = 0.8
    x = t(total)
    hum = lp(tone(total, 60, "square") * 0.35 + tone(total, 120, "saw") * 0.3, 1200)
    f = 2300 + 380 * np.sin(2 * np.pi * 9.0 * x) + 200 * np.sin(2 * np.pi * 2.3 * x)
    whine = np.sin(2 * np.pi * np.cumsum(f) / SR) * (0.6 + 0.4 * np.sin(2 * np.pi * 13 * x))
    body = hum * 1.2 + whine * 0.35 + grains(total, 14, 2500, total * 0.9, (0.1, 0.35))
    shape = np.clip(x / 0.03, 0, 1) * np.clip((total - x) / 0.25, 0, 1)
    return fade(reverb(drive(body * shape, 1.8), 0.2, 0.2))


@sfx
@own_rng
def sfx_shot_sonic():
    """Shrieker (p.349): a piercing sonic screech riding a low pressure thump."""
    total = 0.6
    x = t(total)
    f = 3300 + 260 * np.sin(2 * np.pi * 27 * x)
    ph = 2 * np.pi * np.cumsum(f) / SR
    scream = (np.sin(ph) + 0.5 * np.sin(ph * 1.42) + 0.3 * np.sign(np.sin(ph * 0.5)))
    scream = bp(scream, 1800, 7000) * np.clip(x / 0.01, 0, 1) * np.exp(-x / 0.28)
    thump = sweep(0.2, 190, 55, curve=0.4) * env(0.2, 0.001, 0.05)
    return fade(reverb(drive(mix(scream * 1.2, thump * 0.9), 2.2), 0.25, 0.25))


@sfx
@own_rng
def sfx_shot_stun():
    """Stun Gun (p.349): a snapping electric zap and crackle."""
    total = 0.4
    x = t(total)
    gate = (rng.uniform(0, 1, int(total * 120) + 1) > 0.35).repeat(int(SR / 120) + 1)[:len(x)]
    buzz = tone(total, 190, "square") * 0.35 * gate * np.exp(-x / 0.18)
    snap = hp(noise(0.02), 2500) * env(0.02, 0.0002, 0.004) * 1.4
    crackle = grains(total, 40, 2000, 0.3, (0.3, 1.0), 0.01, 0.002)
    return fade(drive(mix(buzz, snap, crackle), 2.2))


@sfx
@own_rng
def sfx_hit_stun():
    """A stun baton / stun gun contact: a crack of discharge and a buzzing jolt."""
    total = 0.35
    x = t(total)
    buzz = (tone(total, 140, "square") * 0.4 + tone(total, 283, "saw") * 0.2) * np.exp(-x / 0.12)
    thud = lp(noise(0.15), 400) * env(0.15, 0.001, 0.03)
    return fade(drive(mix(buzz, thud * 1.2, grains(total, 30, 2200, 0.22, (0.3, 1.0), 0.01, 0.002)), 2.4))


@sfx
@own_rng
def sfx_shot_flame():
    """Flamethrower (p.348): an ignition pop, then a roaring whoosh of fire with crackle."""
    total = 1.2
    x = t(total)
    swell = np.clip(x / 0.08, 0, 1) * np.clip((total - x) / 0.5, 0, 1)
    roar = (lp_fast(noise(total), 500) * 2.6 + bp(noise(total), 250, 1600) * 0.9) * swell
    roar *= 1.0 + 0.25 * np.sin(2 * np.pi * 7 * x) * np.sin(2 * np.pi * 3.1 * x)
    pop = lp(noise(0.08), 900) * env(0.08, 0.001, 0.02) * 1.5
    crackle = grains(total, 70, 1500, total * 0.85, (0.1, 0.45), 0.008, 0.002)
    return fade(reverb(drive(mix(roar, pop, crackle), 1.6), 0.4, 0.25), 0.002, 0.15)


@sfx
@own_rng
def sfx_rail_charge():
    """Rhinemetall EMG-86 (p.349): the capacitor whine building before the shot (0.42 s)."""
    total = 0.42
    x = t(total)
    f = 320 + 3600 * (x / total) ** 2
    ph = 2 * np.pi * np.cumsum(f) / SR
    trem = 0.7 + 0.3 * np.sin(2 * np.pi * (8 + 50 * x / total) * x)
    whine = (np.sin(ph) * 0.7 + np.sign(np.sin(ph)) * 0.12) * trem * (x / total) ** 1.2
    return whine * 0.8   # no tail: it cuts into the crack


@sfx
@own_rng
def sfx_shot_rail():
    """Rhinemetall EMG-86 (p.349): a supersonic slug: a heavy electric crack, a metallic ring and a sub thump."""
    crack = hp(noise(0.04), 2800) * env(0.04, 0.0002, 0.006) * 2.0
    sub = sweep(0.5, 95, 32, curve=0.4) * env(0.5, 0.001, 0.12) * 1.4
    ring = sum(np.sin(2 * np.pi * f * t(0.5)) * np.exp(-t(0.5) / d) * a
               for f, d, a in [(1240, 0.18, 0.35), (2830, 0.1, 0.25), (4410, 0.06, 0.2)])
    zap = hp(noise(0.25), 1800) * env(0.25, 0.001, 0.05) * 0.5
    return fade(reverb(drive(mix(crack, sub, ring, zap), 3.0), 0.45, 0.32, 0.55), 0.0005, 0.1)


@sfx
@own_rng
def sfx_shot_bow():
    """Bow (p.94): the string's twang and the arrow's whoosh away."""
    twang = pluck(98, 0.45, 0.994, 0.6) * env(0.45, 0.001, 0.15)
    whoosh = bp(noise(0.22), 500, 2200) * np.sin(np.pi * t(0.22) / 0.22) ** 2 * 0.35
    return fade(mix(twang, at(whoosh, 0.02, 0.3), click(900, 0.004) * 0.4))


@sfx
@own_rng
def sfx_shot_crossbow():
    """Crossbow (p.94): a trigger clack, a short hard string snap, the bolt away."""
    clack = mix(click(1600, 0.004), at(click(900, 0.006), 0.012, 0.05))
    twang = pluck(160, 0.3, 0.985, 0.8) * env(0.3, 0.001, 0.06)
    whoosh = bp(noise(0.15), 700, 2800) * np.sin(np.pi * t(0.15) / 0.15) ** 2 * 0.3
    return fade(mix(clack * 0.9, at(twang, 0.01, 0.32), at(whoosh, 0.02, 0.2)))


@sfx
@own_rng
def sfx_hit_arrow():
    """An arrow or bolt striking home: a woody thunk."""
    return fade(mix(lp(noise(0.09), 700) * env(0.09, 0.001, 0.02) * 1.2, sweep(0.12, 230, 90) * env(0.12, 0.001, 0.03),
                    click(2000, 0.003) * 0.4))


@sfx
@own_rng
def sfx_hit_paint():
    """An acid paintball bursting: a wet splat and a hiss."""
    splat = bp(noise(0.08), 400, 2500) * env(0.08, 0.0008, 0.018)
    hiss = hp(noise(0.3), 3500) * env(0.3, 0.02, 0.1) * 0.25
    return fade(mix(splat, sweep(0.05, 260, 110) * env(0.05, 0.001, 0.012) * 0.5, at(hiss, 0.03, 0.35)))


@sfx
@own_rng
def sfx_shot_launcher():
    """Grenade launchers (p.94, Cowboy U-56 p.349): the hollow thoomp of a lobbed round."""
    thoomp = sweep(0.4, 150, 45, curve=0.35) * env(0.4, 0.002, 0.08) * 1.4
    tube = tone(0.25, 210) * env(0.25, 0.002, 0.05) * 0.35
    air = lp(noise(0.12), 500) * env(0.12, 0.001, 0.03)
    return fade(reverb(drive(mix(thoomp, tube, air, click(800, 0.004) * 0.5), 1.8), 0.3, 0.2))


@sfx
@own_rng
def sfx_shot_rocket():
    """Rocket launcher (p.94): an ignition bang and the motor's roaring whoosh away."""
    total = 1.3
    x = t(total)
    bang = mix(lp(noise(0.15), 600) * env(0.15, 0.001, 0.04) * 1.6, sweep(0.3, 120, 40) * env(0.3, 0.001, 0.07))
    motor = (bp(noise(total), 300, 2400) * 0.9 + lp_fast(noise(total), 300) * 1.2) * np.clip(x / 0.03, 0, 1) * np.exp(-x / 0.4)
    return fade(reverb(drive(mix(bang, motor), 1.8), 0.5, 0.25), 0.001, 0.2)


@sfx
@own_rng
def sfx_shot_malorian():
    """Malorian Arms 3516 (p.348): a 5d6 hand cannon: a deep, booming report."""
    x = gunshot(1000, 2100, 0.08, 72, 0.4, 0.45, 4.0)
    boom = sweep(0.5, 70, 30, curve=0.4) * env(0.5, 0.001, 0.12) * 0.9
    return fade(mix(x, boom))


@sfx
@own_rng
def sfx_shot_helix():
    """Tsunami Arms Helix (p.349): a rifle report over a motorised, electric spin whine."""
    x = gunshot(1600, 2900, 0.035, 125, 0.22, 0.28, 3.0)
    whine = sweep(0.22, 3100, 4300, curve=0.7) * env(0.22, 0.004, 0.08) * 0.35
    buzz = lp(tone(0.2, 230, "saw"), 2000) * env(0.2, 0.002, 0.06) * 0.15
    return fade(mix(x, whine, buzz))


@sfx
@own_rng
def sfx_shot_hurricane():
    """Constitution Arms Hurricane (p.348): a drum-fed shotgun, heavier and lower than a pump."""
    return gunshot(700, 1300, 0.11, 58, 0.4, 0.45, 4.0)


@sfx
@own_rng
def sfx_swing_heavy():
    """Very heavy melee (sledgehammer, naginata): a slow, low whoosh."""
    return fade(bp(noise(0.45), 220, 1100) * np.sin(np.pi * t(0.45) / 0.45) ** 3 * 1.2)


@sfx
@own_rng
def sfx_swing_light():
    """Fists and the Battleglove: a short, quick whoosh."""
    return fade(bp(noise(0.14), 900, 3500) * np.sin(np.pi * t(0.14) / 0.14) ** 2)


@sfx
@own_rng
def sfx_swing_mono():
    """Kendachi Mono-Three (p.348): a whoosh with the monoblade's thin, singing edge."""
    total = 0.3
    x = t(total)
    w = np.sin(np.pi * x / total) ** 3
    air = bp(noise(total), 700, 3000) * w
    sing = (np.sin(2 * np.pi * np.cumsum(5200 + 300 * np.sin(2 * np.pi * 6 * x)) / SR) + 0.4 * np.sin(2 * np.pi * 7810 * x)) * w * 0.25
    return fade(mix(air, sing))


@sfx
@own_rng
def sfx_hit_blade():
    """A blade connecting: a sharp slice and a wet cut."""
    slice_ = hp(noise(0.14), 2400) * env(0.14, 0.002, 0.03)
    wet = bp(noise(0.08), 600, 2000) * env(0.08, 0.001, 0.015) * 0.8
    glint = tone(0.1, 3300) * env(0.1, 0.001, 0.02) * 0.2
    return fade(mix(slice_, at(wet, 0.01, 0.12), glint))


@sfx
@own_rng
def sfx_hit_blunt():
    """A club, pipe or hammer landing: a dull body thud with a hard edge."""
    thud = lp(noise(0.25), 320) * env(0.25, 0.001, 0.06) * 2.0
    low = sweep(0.2, 120, 48) * env(0.2, 0.001, 0.05)
    edge = bp(noise(0.04), 900, 3000) * env(0.04, 0.0004, 0.008) * 0.6
    return fade(drive(mix(thud, low, edge), 1.6))


@sfx
@own_rng
def sfx_hit_punch():
    """Brawling / Martial Arts: a punch: a skin slap over a short low thump."""
    slap = bp(noise(0.05), 1200, 4000) * env(0.05, 0.0004, 0.008)
    body = lp(noise(0.12), 650) * env(0.12, 0.001, 0.025) * 1.5
    low = sweep(0.1, 140, 70) * env(0.1, 0.001, 0.025) * 0.8
    return fade(mix(slap, body, low))


def sfx_grab():
    """GRAB: a lunge of air, a body pulled in (a dull chest thump) and fabric wrenched in a fist."""
    total = 0.6
    lunge = bp(_rn(401, 0.16), 500, 2200) * np.sin(np.pi * t(0.16) / 0.16) ** 2 * 0.5
    x = mix(at(lunge, 0.0, total), at(_body_hit(403, 0.45) * 0.8, 0.1, total), at(_scuffle(405, 0.4) * 0.9, 0.14, total))
    return fade(reverb(x, 0.12, 0.1), 0.001, 0.08)


@sfx
def sfx_choke():
    """CHOKE: a squeezing creak of grip and a strangled, fluttering gasp that cuts off."""
    total = 0.95
    grip = _scuffle(411, 0.3, 180, 900) * 0.7
    gasp = _breath(413, 0.55, 500, 1700, 0.85, 17.0) * 0.6
    gasp *= np.clip(1.6 - t(0.55) / 0.55 * 1.6, 0.0, 1.0)   # throttled: it chokes off
    gurgle = lp(_rn(415, 0.4), 260) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 23 * t(0.4)))) * env(0.4, 0.01, 0.15) * 0.5
    return fade(reverb(mix(at(grip, 0.0, total), at(gasp, 0.12, total), at(gurgle, 0.3, total)), 0.1, 0.08), 0.002, 0.1)


@sfx
def sfx_body_slam():
    """THROW: a whoosh over the shoulder and a whole body slammed flat on the floor."""
    total = 0.9
    whoosh = bp(_rn(421, 0.3), 300, 1400) * np.sin(np.pi * t(0.3) / 0.3) ** 2 * 0.6
    slam = drive(mix(sweep(0.5, 90, 32, curve=0.4) * env(0.5, 0.001, 0.12) * 1.5, lp(_rn(423, 0.4), 320) * env(0.4, 0.001, 0.06) * 1.7,
                     bp(_rn(424, 0.08), 600, 2400) * env(0.08, 0.0005, 0.02) * 0.6), 2.4)
    x = mix(at(whoosh, 0.0, total), at(slam, 0.24, total), at(_breath(426, 0.25, 400, 1300, 0.3) * 0.35, 0.3, total))
    return fade(reverb(x, 0.2, 0.15, 0.4), 0.0005, 0.12)


# --- NET device work (CPR core p.199: Control, Eye-Dee; Greybox._ev_net_control / _ev_net_device /
# _ev_eye_dee). Own seeded generators (own_rng), so adding these shifts no other recipe. Bit-crushed
# square-wave blips in the jack-in sound's family.

def _crush(x, steps=8):
    return np.round(x * steps) / steps


@sfx
@own_rng
def sfx_net_take():
    """A Control Node taken: three rising square blips and a short handshake chirp, crushed."""
    total = 0.55
    x = np.zeros(int(total * SR))
    for k, f in enumerate([392, 587, 880]):
        x += at(tone(0.06, f, "square") * env(0.06, 0.001, 0.025) * 0.3, k * 0.07, total)
    x += at(sweep(0.18, 900, 2600, "square", 1.5) * env(0.18, 0.002, 0.07) * 0.16, 0.22, total)
    x += at(hp(rng.standard_normal(int(0.03 * SR)), 3000) * env(0.03, 0.0005, 0.008) * 0.15, 0.21, total)
    return fade(reverb(_crush(x), 0.15, 0.15))


@sfx
@own_rng
def sfx_net_lock():
    """A lock thrown shut from the NET: a falling blip and a heavy electric bolt clunk."""
    total = 0.45
    blip = sweep(0.09, 1400, 500, "square", 1.0) * env(0.09, 0.001, 0.04) * 0.25
    clunk = drive(lp(rng.standard_normal(int(0.12 * SR)), 700) * env(0.12, 0.0005, 0.03) * 1.2 + tone(0.12, 70) * env(0.12, 0.001, 0.05), 2.0)
    return fade(mix(at(_crush(blip), 0.0, total), at(clunk * 0.7, 0.08, total)))


@sfx
@own_rng
def sfx_net_unlock():
    """A lock released from the NET: a rising blip and a light bolt snap back."""
    total = 0.4
    blip = sweep(0.09, 600, 1600, "square", 1.0) * env(0.09, 0.001, 0.04) * 0.25
    snap = hp(rng.standard_normal(int(0.05 * SR)), 1500) * env(0.05, 0.0005, 0.012) * 0.6 + tone(0.05, 180) * env(0.05, 0.001, 0.02) * 0.4
    return fade(mix(at(_crush(blip), 0.0, total), at(snap, 0.09, total)))


@sfx
@own_rng
def sfx_net_feed():
    """A camera feed patched through: a short burst of video static that settles into a hum."""
    total = 0.6
    stat = bp(rng.standard_normal(int(0.25 * SR)), 1500, 6000) * env(0.25, 0.002, 0.09) * 0.35
    hum = tone(0.5, 120, "square") * 0.06 * np.sin(np.pi * t(0.5) / 0.5) + tone(0.5, 15734 / 4) * 0.02 * np.sin(np.pi * t(0.5) / 0.5)
    return fade(mix(at(stat, 0.0, total), at(hum, 0.08, total)))


@sfx
@own_rng
def sfx_net_eyedee():
    """Eye-Dee: a fast run of data ticks climbing in pitch, ending on a bright two-note read-out."""
    total = 0.75
    x = np.zeros(int(total * SR))
    for k in range(10):
        f = 700 + 90 * k + rng.uniform(-30, 30)
        x += at(tone(0.025, f, "square") * env(0.025, 0.0005, 0.01) * 0.18, k * 0.035, total)
    x += at(tone(0.12, 1318, "square") * env(0.12, 0.002, 0.06) * 0.22, 0.4, total)
    x += at(tone(0.18, 1760, "square") * env(0.18, 0.002, 0.08) * 0.2, 0.5, total)
    return fade(reverb(_crush(x), 0.2, 0.2))


# --- Solo Play Clocks and Plot Twists (Clocks, Twist; ClockWidget, Greybox._ev_clock / _ev_twist) ----

def _clack(hz, sec=0.03, tau=0.006, body=0.5):
    """One hard plastic knock: a bright band of noise and a short resonant ping."""
    knock = bp(rng.standard_normal(int(sec * SR)), hz * 0.55, hz * 1.7) * env(sec, 0.0002, tau)
    ping = tone(sec, hz * 1.9) * env(sec, 0.0002, tau * 1.6) * body
    return knock + ping * 0.35


@sfx
@own_rng
def sfx_dice_rattle():
    """A handful of dice tumbling across a hard tabletop: a burst of clacks thinning out, each die's
    last bounce, then a settle."""
    total = 0.7
    x = np.zeros(int(total * SR))
    for k in range(26):   # dense first, then sparser and softer as they come to rest
        u = rng.uniform(0, 1) ** 1.7
        when = u * 0.52
        amp = (1.0 - u * 0.7) * rng.uniform(0.35, 1.0)
        x += at(_clack(rng.uniform(1700, 3400), 0.028, rng.uniform(0.003, 0.007)) * amp, when, total)
    for k in range(4):   # the last little hops
        x += at(_clack(rng.uniform(2200, 3000), 0.02, 0.004) * 0.3, 0.5 + k * 0.04 + rng.uniform(0, 0.015), total)
    x += at(lp(rng.standard_normal(int(0.4 * SR)), 900) * env(0.4, 0.01, 0.12) * 0.18, 0.0, total)   # the tumble's rumble
    return fade(reverb(x, 0.12, 0.12))


@sfx
@own_rng
def sfx_die_break():
    """A die cracking apart: a sharp snap, a brittle shatter of small pieces skittering off."""
    total = 0.55
    snap = hp(rng.standard_normal(int(0.03 * SR)), 2500) * env(0.03, 0.0002, 0.005)
    thud = sweep(0.08, 420, 160, curve=0.5) * env(0.08, 0.0005, 0.02) * 0.6
    x = mix(at(snap * 1.1, 0.0, total), at(thud, 0.0, total))
    for k in range(14):
        x += at(_clack(rng.uniform(3000, 6000), 0.015, 0.002, 0.2) * rng.uniform(0.15, 0.5), 0.02 + rng.uniform(0, 0.3) ** 1.5, total)
    return fade(reverb(drive(x, 1.6), 0.15, 0.15))


@sfx
@own_rng
def sfx_die_add():
    """A die won back: a quick rising chime with a glassy shimmer, and the die landing."""
    total = 0.6
    x = np.zeros(int(total * SR))
    for k, f in enumerate([880, 1175, 1568]):
        x += at(tone(0.22, f) * env(0.22, 0.003, 0.09) * 0.28 + tone(0.22, f * 2.01) * env(0.22, 0.003, 0.05) * 0.08, k * 0.055, total)
    x += at(_clack(2600, 0.03, 0.006) * 0.5, 0.34, total)
    x += at(_clack(2900, 0.02, 0.004) * 0.25, 0.42, total)
    return fade(reverb(x, 0.25, 0.25))


@sfx
@own_rng
def sfx_klaxon():
    """The clock runs out: a harsh two-tone klaxon blast over a low impact."""
    total = 1.4
    x = np.zeros(int(total * SR))
    for k in range(3):   # bwaa-bwaa-bwaa, the last held
        sec = 0.26 if k < 2 else 0.62
        f0 = 330.0
        s = tone(sec, f0, "square") * 0.5 + tone(sec, f0 * 1.5, "saw") * 0.35 + tone(sec, f0 * 0.5, "square") * 0.25
        a = np.clip(t(sec) / 0.01, 0, 1) * np.clip((sec - t(sec)) / 0.04, 0, 1)
        x += at(lp(s * a, 2600), 0.02 + k * 0.32, total)
    hit = mix(sweep(0.5, 90, 38, curve=0.6) * env(0.5, 0.001, 0.18) * 0.9, lp(rng.standard_normal(int(0.3 * SR)), 500) * env(0.3, 0.001, 0.08) * 0.5)
    x += at(hit, 0.0, total)
    return fade(reverb(drive(x, 2.2), 0.35, 0.22))


@sfx
@own_rng
def sfx_twist():
    """A plot twist springs: a detuned synth stab sliding down a semitone, with a glitch stutter."""
    total = 1.2
    sec = 0.9
    x = np.zeros(int(total * SR))
    for f, a in [(220.0, 0.35), (261.6, 0.3), (311.1, 0.28), (110.0, 0.35)]:   # A minor-ish stab
        s = sweep(sec, f, f * 0.94, "saw", 2.0) * a + sweep(sec, f * 1.006, f * 0.946, "saw", 2.0) * a * 0.8
        x += at(lp(s, 1800) * env(sec, 0.004, 0.32), 0.0, total)
    for k in range(5):   # stutter
        x += at(bp(rng.standard_normal(int(0.025 * SR)), 800, 5000) * env(0.025, 0.0003, 0.006) * 0.4, 0.05 + k * 0.045, total)
    return fade(reverb(drive(x, 1.8), 0.4, 0.3))


# --- ambience loops -------------------------------------------------------------------------------

AMB = {}


def amb(fn):
    AMB[fn.__name__] = fn
    return fn


def brown(sec, hz=200):
    return lp(np.cumsum(noise(sec)) * 0.02 - lp(np.cumsum(noise(sec)) * 0.02, 5), hz)


@amb
def amb_city():
    L = 24.0
    x = lp_fast(noise(L), 180) * 3.0                      # traffic rumble
    x += tone(L, 60) * 0.05 + tone(L, 120) * 0.02          # mains hum
    for k in range(6):                                     # cars passing
        st = rng.uniform(0, L)
        d = rng.uniform(2.5, 4.5)
        car = bp(noise(d), 200, 900) * np.sin(np.pi * t(d) / d) ** 2 * rng.uniform(0.3, 0.6)
        x += at(car, st, L + d)[:int(L * SR)] if st + d < L else np.concatenate([at(car, st, L + d)])[:int(L * SR)]
    siren_t = t(5.0)
    siren = np.sin(2 * np.pi * np.cumsum(900 + 200 * np.sin(2 * np.pi * siren_t / 1.3)) / SR) * np.sin(np.pi * siren_t / 5.0) ** 2 * 0.04
    x += at(lp(siren, 1500), rng.uniform(2, 15), L)
    return loop_self(reverb(x, 0.6, 0.25), L)


@amb
def amb_undercity():
    L = 20.0
    x = tone(L, 55) * 0.12 + tone(L, 82.5) * 0.05
    flow = bp(noise(L), 300, 1400) * (0.5 + 0.5 * np.sin(2 * np.pi * t(L) / 7.0) ** 2) * 0.6
    x += flow
    for k in range(40):
        f = rng.uniform(900, 2200)
        drip = sweep(0.15, f * 1.5, f, curve=0.3) * env(0.15, 0.001, 0.03) * rng.uniform(0.15, 0.4)
        x += at(drip, rng.uniform(0, L - 0.2), L)
    return loop_self(reverb(x, 0.9, 0.4, 0.65), L)


@amb
def amb_arcology():
    L = 20.0
    x = lp_fast(noise(L), 500) * 1.5 + tone(L, 120) * 0.04 + tone(L, 240) * 0.015
    for k in range(4):
        f = rng.choice([880, 1046, 1318])
        ch = np.sin(2 * np.pi * f * t(2.0)) * np.exp(-t(2.0) / 0.6) * 0.05
        x += at(ch, rng.uniform(0, L - 2), L)
    return loop_self(reverb(x, 0.9, 0.35, 0.6), L)


@amb
def amb_warzone():
    L = 24.0
    x = lp_fast(noise(L), 160) * 3.5                       # the roar of fires
    for k in range(260):                                   # crackle
        g = hp(noise(0.008), 1200) * env(0.008, 0.0002, 0.002)
        x += at(g * rng.uniform(0.1, 0.5), rng.uniform(0, L - 0.01), L)
    shot = lp(sfx_shot_rifle(), 900)
    for k in range(7):                                     # distant gunfire, in bursts
        st = rng.uniform(0, L - 2)
        for b in range(rng.integers(1, 5)):
            x += at(shot * rng.uniform(0.15, 0.3), st + b * 0.11, L)
    boom = lp(sfx_explosion(), 300) * 0.25
    x += at(boom, rng.uniform(4, 18), L)
    return loop_self(reverb(x, 0.8, 0.3), L)


@amb
def amb_badlands():
    L = 20.0
    w = noise(L)
    gust = 0.4 + 0.6 * np.sin(2 * np.pi * t(L) / 9.0 + 1.0) ** 2
    x = bp(w, 250, 900) * gust * 1.2 + lp_fast(noise(L), 120) * 1.5
    return loop_self(reverb(x, 0.5, 0.2), L)


@amb
def amb_safehouse():
    L = 16.0
    x = tone(L, 60) * 0.06 + tone(L, 180) * 0.02 + lp_fast(noise(L), 400) * 0.6
    fridge = tone(L, 117, "saw") * 0.015 * (np.sin(2 * np.pi * t(L) / L) > -0.2)
    return loop_self(reverb(x + lp(fridge, 600), 0.4, 0.3), L)


# --- music ------------------------------------------------------------------------------------------

MUS = {}


def mus(fn):
    MUS[fn.__name__] = fn
    return fn


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def synth_note(f, sec, kind="saw", cut=1500, tau=None, detune=0.006, attack=0.01):
    x = t(sec)
    if kind == "saw":
        v = sum(2 * (((f * (1 + d)) * x) % 1.0) - 1 for d in (-detune, 0, detune)) / 3
    elif kind == "square":
        v = np.sign(np.sin(2 * np.pi * f * x))
    else:
        v = np.sin(2 * np.pi * f * x)
    e = np.clip(x / attack, 0, 1) * (np.exp(-x / tau) if tau else 1.0)
    rel = np.clip((sec - x) / 0.05, 0, 1)
    return lp(v, cut) * e * rel


def kick(sec=0.4):
    return sweep(sec, 150, 45, curve=0.3) * env(sec, 0.001, 0.12) * 1.2


def snare(sec=0.25):
    return mix(bp(noise(sec), 900, 5000) * env(sec, 0.001, 0.06), tone(sec, 190) * env(sec, 0.001, 0.04) * 0.4)


def hat(sec=0.06):
    return hp(noise(sec), 7000) * env(sec, 0.0005, 0.015) * 0.5


@mus
def mus_explore():
    """Dark, slow synth pads over a sub bass, a sparse arpeggio: sneaking music. 88 BPM, 16 bars."""
    bpm = 88.0
    beat = 60.0 / bpm
    bars = 16
    L = bars * 4 * beat
    out = np.zeros(int((L + 4) * SR))
    prog = [(57, [57, 60, 64]), (53, [53, 57, 60]), (50, [50, 53, 57]), (52, [52, 56, 59])]   # Am F Dm E
    for b in range(bars):
        root, chord = prog[(b // 2) % 4]
        st = b * 4 * beat
        for n in chord:
            p = synth_note(midi(n), 4 * beat, "saw", 900, None, 0.008, 0.6) * 0.12
            out += at(p, st, L + 4)
        out += at(synth_note(midi(root - 24), 4 * beat, "sine", 300, None, 0, 0.05) * 0.4, st, L + 4)
        for k in range(8):
            if rng.random() < 0.55:
                n = chord[k % 3] + 12 * (1 + (k // 3) % 2)
                out += at(synth_note(midi(n), beat * 0.45, "square", 2200, 0.12, 0, 0.003) * 0.06, st + k * beat / 2, L + 4)
    out = reverb(out, 0.9, 0.45, 0.7)
    return loop_wrap(out, L)


@mus
def mus_combat():
    """Driving synthwave: four-on-the-floor kick, snare on 2 and 4, a pumping bass and a minor riff. 124 BPM."""
    bpm = 124.0
    beat = 60.0 / bpm
    bars = 16
    L = bars * 4 * beat
    out = np.zeros(int((L + 3) * SR))
    prog = [45, 41, 43, 40]   # A F G E (bass roots)
    riff = [69, 72, 76, 74, 72, 69, 67, 69]
    for b in range(bars):
        st = b * 4 * beat
        root = prog[(b // 2) % 4]
        for k in range(4):
            out += at(kick() * 0.9, st + k * beat, L + 3)
            out += at(hat(), st + k * beat + beat / 2, L + 3)
        for k in (1, 3):
            out += at(snare() * 0.6, st + k * beat, L + 3)
        for k in range(16):   # pumping 16th bass, ducked under the kick
            duck = 0.35 if k % 4 == 0 else 1.0
            out += at(synth_note(midi(root), beat / 4 * 0.9, "saw", 700, 0.08, 0.004, 0.003) * 0.22 * duck, st + k * beat / 4, L + 3)
        if b >= 4:
            for k, n in enumerate(riff):
                if (b + k) % 3 != 0:
                    out += at(synth_note(midi(n - (0 if (b // 4) % 2 == 0 else 2)), beat * 0.45, "square", 2600, 0.15, 0, 0.004) * 0.07, st + k * beat / 2, L + 3)
        chord = [root + 24, root + 27, root + 31]
        for n in chord:
            out += at(synth_note(midi(n), 4 * beat, "saw", 1100, None, 0.01, 0.3) * 0.05, st, L + 3)
    out = reverb(out, 0.5, 0.25, 0.5)
    return loop_wrap(drive(out, 1.4), L)


def main():
    want = set(sys.argv[1:])
    for table in (SFX, AMB, MUS):
        for name, fn in table.items():
            if want and name not in want:
                continue
            write(name, fn(), 0.89 if table is SFX else 0.7, trim=table is SFX and name != "sfx_alarm")


if __name__ == "__main__":
    main()
