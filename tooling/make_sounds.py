#!/usr/bin/env python3
"""Synthesize the TileWise sound effects as 16-bit mono WAVs (zero licensing)."""
import math
import os
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sounds")
os.makedirs(OUT, exist_ok=True)


def write_wav(name, samples):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(
            struct.pack("<h", max(-32768, min(32767, int(s * 32767))))
            for s in samples
        )
        w.writeframes(frames)
    print("wrote", path, len(samples), "samples")


def tone(freq, dur, vol=0.5, slide_to=None):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        f = freq if slide_to is None else freq + (slide_to - freq) * (i / n)
        env = math.exp(-4.0 * i / n)
        out.append(vol * env * math.sin(2 * math.pi * f * t))
    return out


def noise(dur, vol=0.4, decay=6.0):
    import random
    rng = random.Random(3)
    n = int(SR * dur)
    return [vol * math.exp(-decay * i / n) * (rng.random() * 2 - 1)
            for i in range(n)]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    peak = max(1e-6, max(abs(s) for s in out))
    return [s / peak * 0.9 for s in out]


def seq(notes, note_dur=0.11, gap=0.02, vol=0.5):
    out = []
    gap_n = int(SR * gap)
    for freq in notes:
        out.extend(tone(freq, note_dur, vol))
        out.extend([0.0] * gap_n)
    return out


# click: short UI blip
write_wav("click", tone(1350, 0.055, vol=0.45))
# place: wooden knock (low thump + click)
write_wav("place", mix(tone(240, 0.10, vol=0.7), noise(0.05, vol=0.35)))
# invalid: dull buzz
write_wav("invalid", tone(165, 0.20, vol=0.5, slide_to=120))
# win: happy arpeggio C5 E5 G5 C6
write_wav("win", seq([523.25, 659.25, 783.99, 1046.5], note_dur=0.12))
# turn: soft chime
write_wav("turn", tone(660, 0.09, vol=0.35))
# shuffle: tile rattle
write_wav("shuffle", noise(0.16, vol=0.5, decay=4.0))

print("done")
