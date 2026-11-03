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
