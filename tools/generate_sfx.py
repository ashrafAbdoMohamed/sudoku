#!/usr/bin/env python3
"""Synthesizes the game's sound effects into assets/sfx/*.wav.

Everything is generated from scratch (sine/triangle oscillators, envelopes,
filtered noise), so the sounds are original and free to ship. Pure standard
library, no dependencies. Tweak a recipe below and re-run:

    python3 tools/generate_sfx.py

The palette is "glass marimba": warm mallet plucks for letters and words,
inharmonic glass bells for magic (hint/reveal/stars/coins), soft airy
whooshes for transitions.
"""

import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sfx')


# ---------------------------------------------------------------- building blocks

def silence(seconds):
    return [0.0] * int(SR * seconds)


def mix(base, layer, at=0.0, gain=1.0):
    """Adds [layer] into [base] starting at [at] seconds, growing base if needed."""
    start = int(at * SR)
    end = start + len(layer)
    if end > len(base):
        base.extend([0.0] * (end - len(base)))
    for i, v in enumerate(layer):
        base[start + i] += v * gain
    return base


def note(freq):
    """Note name like 'C6' or 'F#5' -> Hz."""
    names = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2}
    semis = names[freq[0]]
    rest = freq[1:]
    if rest.startswith('#'):
        semis += 1
        rest = rest[1:]
    elif rest.startswith('b'):
        semis -= 1
        rest = rest[1:]
    octave = int(rest)
    return 440.0 * 2 ** ((semis + (octave - 4) * 12) / 12)


def marimba(freq, seconds=0.35, gain=1.0):
    """Mallet pluck: fundamental + the marimba's characteristic 4x partial,
    plus a tiny noise click for the mallet strike."""
    n = int(SR * seconds)
    out = []
    for i in range(n):
        t = i / SR
        body = math.sin(2 * math.pi * freq * t) * math.exp(-t * 9)
        overtone = 0.35 * math.sin(2 * math.pi * freq * 4 * t) * math.exp(-t * 40)
        click = (random.random() * 2 - 1) * 0.25 * math.exp(-t * 900)
        attack = min(1.0, t / 0.002)
        out.append((body + overtone + click) * attack * gain)
    return out


def soft_mallet(freq, seconds=0.3, decay=12):
    """A muffled mallet: pure sine, rounded attack, no click or overtones."""
    n = int(SR * seconds)
    out = []
    for i in range(n):
        t = i / SR
        attack = min(1.0, t / 0.012)
        out.append(math.sin(2 * math.pi * freq * t) * math.exp(-t * decay) * attack)
    return out


def glass_bell(freq, seconds=0.9, gain=1.0, decay=5.0):
    """Struck glass: inharmonic partials that decay at different speeds."""
    partials = [(1.0, 1.0, 1.0), (2.76, 0.45, 1.8), (5.40, 0.25, 3.0), (8.93, 0.12, 4.5)]
    n = int(SR * seconds)
    out = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for ratio, amp, speed in partials:
            v += amp * math.sin(2 * math.pi * freq * ratio * t) * math.exp(-t * decay * speed)
        attack = min(1.0, t / 0.003)
        out.append(v * attack * gain * 0.6)
    return out


def glide(f0, f1, seconds, wave_fn='sine', gain=1.0, decay=6.0, vibrato=0.0):
    """A pitch sweep from f0 to f1 (exponential), for pops, boings and bonks."""
    n = int(SR * seconds)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = f0 * (f1 / f0) ** (t / seconds)
        f *= 1 + vibrato * math.sin(2 * math.pi * 18 * t)
        phase += 2 * math.pi * f / SR
        if wave_fn == 'tri':
            s = 2 / math.pi * math.asin(math.sin(phase))
        else:
            s = math.sin(phase)
        attack = min(1.0, t / 0.003)
        out.append(s * math.exp(-t * decay) * attack * gain)
    return out


def airy_noise(seconds, f_start, f_end, gain=1.0, q=0.35, shape='swell'):
    """Band-passed noise with a sweeping center frequency (state-variable filter)."""
    n = int(SR * seconds)
    low = band = 0.0
    out = []
    for i in range(n):
        p = i / n
        fc = f_start * (f_end / f_start) ** p
        f = 2 * math.sin(math.pi * min(fc, SR / 6) / SR)
        x = random.random() * 2 - 1
        low += f * band
        high = x - low - q * band
        band += f * high
        if shape == 'swell':
            env = math.sin(math.pi * p) ** 1.5
        else:  # 'fall'
            env = (1 - p) ** 2
        out.append(band * env * gain)
    return out


def finish(samples, peak=0.8, fade=0.01):
    """Normalizes, adds a short fade-out to avoid clicks."""
    top = max(abs(s) for s in samples) or 1.0
    k = peak / top
    out = [s * k for s in samples]
    nfade = int(SR * fade)
    for i in range(1, nfade + 1):
        out[-i] *= (i - 1) / nfade
    return out


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + '.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s)) * 32767)) for s in samples))
    print(f'{name:10s} {len(samples) / SR:.2f}s')


# ---------------------------------------------------------------- the sounds

# Dragging across letters walks up a major pentatonic scale, so every word
# you trace plays a little rising melody.
# Kept low and muffled: these play many times a second while dragging.
SCALE = ['C5', 'D5', 'E5', 'G5', 'A5', 'C6', 'D6', 'E6', 'G6', 'A6']


def letter_ticks():
    for i, n in enumerate(SCALE):
        write(f'tick_{i}', finish(soft_mallet(note(n), 0.16, decay=22), peak=0.25))


def word_found():
    s = silence(0.0)
    for i, n in enumerate(['C6', 'E6', 'G6', 'C7']):
        mix(s, marimba(note(n), 0.4), at=i * 0.045)
    mix(s, glass_bell(note('E7'), 0.6, decay=6), at=0.16, gain=0.5)
    write('found', finish(s, peak=0.75))


def miss():
    # A quiet, muffled "doo-dum" stepping down: a gentle "not quite".
    s = soft_mallet(note('E5'), 0.2)
    mix(s, soft_mallet(note('C5'), 0.3), at=0.09)
    write('miss', finish(s, peak=0.28))


def hint():
    # Twinkle: quick glass sparkles, high then settling.
    s = silence(0.0)
    for i, n in enumerate(['E7', 'B6', 'G#6', 'E7', 'B7']):
        mix(s, glass_bell(note(n), 0.45, decay=9), at=i * 0.055, gain=0.7)
    write('hint', finish(s, peak=0.6))


def reveal():
    # Magic wand: rising airy whoosh resolving into a bright glass chord.
    s = airy_noise(0.45, 600, 6000, gain=1.0)
    for n in ['C6', 'G6', 'E7']:
        mix(s, glass_bell(note(n), 0.9, decay=4), at=0.36, gain=0.9)
    write('reveal', finish(s, peak=0.7))


def coin():
    s = glass_bell(note('B6'), 0.25, decay=10)
    mix(s, glass_bell(note('E7'), 0.5, decay=6), at=0.07)
    write('coin', finish(s, peak=0.55))


def stars():
    # Each star lands with a soft low thump plus a chime, one step higher each time.
    for i, n in enumerate(['C6', 'E6', 'G6']):
        s = glide(120, 55, 0.25, decay=14, gain=0.9)
        mix(s, glass_bell(note(n), 0.8, decay=4), gain=1.0)
        mix(s, glass_bell(note(n) * 2, 0.5, decay=7), at=0.02, gain=0.35)
        write(f'star_{i + 1}', finish(s, peak=0.75))


def win_jingle():
    # Bouncy marimba run up, then a ringing glass chord with a sparkle tail.
    s = silence(0.0)
    melody = [('C6', 0.00), ('E6', 0.10), ('G6', 0.20), ('C7', 0.30), ('G6', 0.42), ('C7', 0.52)]
    for n, at in melody:
        mix(s, marimba(note(n), 0.45), at=at)
    for n in ['C6', 'E6', 'G6', 'C7']:
        mix(s, glass_bell(note(n), 1.6, decay=2.2), at=0.64, gain=0.55)
    mix(s, marimba(note('C5'), 0.8, gain=0.8), at=0.64)
    for i in range(8):
        mix(s, glass_bell(note(random.choice(['E7', 'G7', 'C8'])), 0.3, decay=12), at=0.75 + i * 0.07, gain=0.25)
    write('win', finish(s, peak=0.8))


def tap():
    # Bubbly UI pop.
    s = glide(950, 420, 0.07, decay=30)
    write('tap', finish(s, peak=0.45))


def whoosh():
    s = airy_noise(0.5, 300, 3000, gain=1.0, shape='swell')
    write('whoosh', finish(s, peak=0.45))


def no_coins():
    # Two short low "uh-uh" notes.
    s = glide(200, 185, 0.11, 'tri', decay=10)
    mix(s, glide(170, 150, 0.16, 'tri', decay=10), at=0.13)
    write('no_coins', finish(s, peak=0.55))


RECIPES = [letter_ticks, word_found, miss, hint, reveal, coin, stars, win_jingle, tap, whoosh, no_coins]

if __name__ == '__main__':
    for i, recipe in enumerate(RECIPES):
        # Seeded per recipe, so editing one sound never changes another's noise.
        random.seed(i)
        recipe()
