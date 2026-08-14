#!/usr/bin/env python3
"""Generates the placeholder synthesized SFX/music set for What The Tetris.

These are programmatically synthesized (sine/square waves, simple envelopes,
noise) so the game ships with real, distinct audio feedback immediately.
Per docs/GDD.md SS7 and docs/ROADMAP.md Phase 0, this placeholder set is meant
to be swapped for a commissioned pack later -- it exists so "no audio at all"
stops being true today, not as the final art pass.

Usage: python3 tool/generate_audio.py
Writes 16-bit mono PCM WAV files to assets/audio/.
"""

import math
import os
import struct
import wave

SAMPLE_RATE = 22050
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def _clamp(x, lo=-1.0, hi=1.0):
    return max(lo, min(hi, x))


def silence(duration):
    return [0.0] * int(SAMPLE_RATE * duration)


def sine(freq, duration, amp=0.5, fade_in=0.005, fade_out=0.03, detune=0.0):
    n = int(SAMPLE_RATE * duration)
    out = []
    fi = int(SAMPLE_RATE * fade_in)
    fo = int(SAMPLE_RATE * fade_out)
    for i in range(n):
        t = i / SAMPLE_RATE
        f = freq + detune * t
        v = math.sin(2 * math.pi * f * t)
        env = 1.0
        if i < fi:
            env = i / max(fi, 1)
        if i > n - fo:
            env = min(env, (n - i) / max(fo, 1))
        out.append(v * amp * env)
    return out


def square(freq, duration, amp=0.35, fade_in=0.004, fade_out=0.05, duty=0.5):
    n = int(SAMPLE_RATE * duration)
    out = []
    fi = int(SAMPLE_RATE * fade_in)
    fo = int(SAMPLE_RATE * fade_out)
    for i in range(n):
        t = i / SAMPLE_RATE
        phase = (freq * t) % 1.0
        v = amp if phase < duty else -amp
        env = 1.0
        if i < fi:
            env = i / max(fi, 1)
        if i > n - fo:
            env = min(env, (n - i) / max(fo, 1))
        out.append(v * env)
    return out


def noise_burst(duration, amp=0.4, fade_out=0.08, seed=12345):
    n = int(SAMPLE_RATE * duration)
    fo = int(SAMPLE_RATE * fade_out)
    state = seed
    out = []
    for i in range(n):
        # xorshift32 PRNG -- deterministic, no external deps.
        state ^= (state << 13) & 0xFFFFFFFF
        state ^= (state >> 17)
        state ^= (state << 5) & 0xFFFFFFFF
        v = ((state / 0xFFFFFFFF) * 2 - 1)
        env = 1.0
        if i > n - fo:
            env = (n - i) / max(fo, 1)
        out.append(v * amp * env)
    return out


def sweep(f_start, f_end, duration, amp=0.4, fade_out=0.04):
    n = int(SAMPLE_RATE * duration)
    fo = int(SAMPLE_RATE * fade_out)
    out = []
    phase = 0.0
    for i in range(n):
        t = i / n
        f = f_start + (f_end - f_start) * t
        phase += f / SAMPLE_RATE
        v = math.sin(2 * math.pi * phase)
        env = 1.0
        if i > n - fo:
            env = (n - i) / max(fo, 1)
        out.append(v * amp * env)
    return out


def mix(*tracks):
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return [_clamp(v) for v in out]


def concat(*tracks):
    out = []
    for t in tracks:
        out.extend(t)
    return out


def overlay_at(base, addition, offset_seconds):
    base = list(base)
    offset = int(SAMPLE_RATE * offset_seconds)
    for i, v in enumerate(addition):
        idx = offset + i
        if idx >= len(base):
            base.append(0.0)
        base[idx] = _clamp(base[idx] + v)
    return base


def write_wav(name, samples):
    path = os.path.join(OUT_DIR, name)
    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SAMPLE_RATE)
        frames = b"".join(struct.pack("<h", int(_clamp(s) * 32767)) for s in samples)
        f.writeframes(frames)
    print(f"wrote {path} ({len(samples) / SAMPLE_RATE:.2f}s)")


# Note frequencies (equal temperament, A4 = 440Hz).
NOTE = {
    "C4": 261.63, "D4": 293.66, "E4": 329.63, "F4": 349.23, "G4": 392.00,
    "A4": 440.00, "B4": 493.88, "C5": 523.25, "D5": 587.33, "E5": 659.25,
    "F5": 698.46, "G5": 783.99, "A5": 880.00, "B5": 987.77, "C6": 1046.50,
}


def arpeggio(notes, note_dur, amp=0.4, wave_fn=square):
    return concat(*[wave_fn(NOTE[n], note_dur, amp=amp) for n in notes])


def build_sfx():
    write_wav("move.wav", sine(880, 0.035, amp=0.25, fade_out=0.02))
    write_wav("rotate.wav", sine(1046, 0.045, amp=0.28, fade_out=0.025))
    write_wav("mirror.wav", sweep(500, 1400, 0.14, amp=0.35))
    write_wav("soft_drop.wav", sine(180, 0.06, amp=0.3, fade_out=0.04))
    write_wav("hard_drop.wav", mix(
        sine(90, 0.12, amp=0.5, fade_out=0.08),
        noise_burst(0.05, amp=0.25),
    ))
    write_wav("lock.wav", sine(320, 0.05, amp=0.22, fade_out=0.03))
    write_wav("clear_1.wav", arpeggio(["C5", "E5"], 0.06, amp=0.3))
    write_wav("clear_2.wav", arpeggio(["C5", "E5", "G5"], 0.06, amp=0.3))
    write_wav("clear_3.wav", arpeggio(["C5", "E5", "G5", "C6"], 0.06, amp=0.32))
    write_wav("clear_tetris.wav", arpeggio(["C5", "E5", "G5", "C6", "G5", "C6"], 0.07, amp=0.38))
    write_wav("fusion_bonus.wav", mix(
        sweep(700, 1800, 0.18, amp=0.3),
        sine(1800, 0.18, amp=0.15, fade_in=0.05, fade_out=0.05),
    ))
    write_wav("combo_tick.wav", sweep(600, 900, 0.05, amp=0.28))
    write_wav("cavity_fill.wav", mix(
        noise_burst(0.03, amp=0.3),
        sine(700, 0.04, amp=0.25, fade_out=0.03),
    ))
    write_wav("level_up.wav", arpeggio(["E5", "G5", "C6"], 0.08, amp=0.34))
    write_wav("game_over.wav", arpeggio(["G4", "E4", "C4"], 0.16, amp=0.3, wave_fn=sine))
    write_wav("new_best.wav", arpeggio(["C5", "E5", "G5", "C6", "E5", "C6"], 0.07, amp=0.36))
    write_wav("menu_tap.wav", sine(700, 0.025, amp=0.2, fade_out=0.015))
    write_wav("pause.wav", sine(500, 0.06, amp=0.25, fade_out=0.04))
    write_wav("danger.wav", concat(
        square(220, 0.09, amp=0.28),
        silence(0.03),
        square(180, 0.09, amp=0.28),
    ))
    write_wav("achievement_unlock.wav", mix(
        arpeggio(["G5", "C6"], 0.1, amp=0.32, wave_fn=sine),
        sine(1567.98, 0.18, amp=0.14, fade_in=0.05, fade_out=0.1),
    ))


def build_music():
    # Menu loop: calm, slow arpeggio bed, ~4.8s, designed to loop cleanly.
    bar = arpeggio(["C4", "E4", "G4", "C5", "G4", "E4"], 0.4, amp=0.16, wave_fn=sine)
    write_wav("music_menu_loop.wav", concat(bar, bar))

    # Marathon loop: a four-chord I-V-vi-IV progression (the classic pop
    # progression -- pleasant and familiar rather than grating) with a soft
    # sine arpeggio lead over a gentle bass pulse per chord, ~9.6s total.
    # Replaces an earlier 8-note square-wave riff that only ran ~1.1s before
    # repeating -- fine as a sting, unbearable on loop for a whole run.
    progression = [
        (["C4", "E4", "G4", "C5", "G4", "E4", "C4", "G4"], NOTE["C4"] / 2),
        (["G4", "B4", "D5", "G4", "D5", "B4", "G4", "D5"], NOTE["G4"] / 2),
        (["A4", "C5", "E5", "A4", "E5", "C5", "A4", "E5"], NOTE["A4"] / 2),
        (["F4", "A4", "C5", "F4", "C5", "A4", "F4", "C5"], NOTE["F4"] / 2),
    ]
    bars = []
    for notes, bass_freq in progression:
        lead = arpeggio(notes, 0.15, amp=0.15, wave_fn=sine)
        bass = sine(
            bass_freq, len(notes) * 0.15, amp=0.09, fade_in=0.05, fade_out=0.2
        )
        bars.append(mix(lead, bass))
    riff = concat(*bars)
    write_wav("music_marathon_loop.wav", concat(riff, riff))

    # Zen loop: sparse, slow pad tones, ~8s, for Zen/Chill's low-pressure feel.
    pad = mix(
        sine(NOTE["C4"], 4.0, amp=0.12, fade_in=0.6, fade_out=1.2),
        sine(NOTE["G4"], 4.0, amp=0.08, fade_in=0.6, fade_out=1.2),
    )
    write_wav("music_zen_loop.wav", concat(pad, pad))

    # Arcade loop: a driving lead over a pulsing bass, ~2.16s -- built for
    # Arcade's manual speed-boost adrenaline, punchier than Marathon's
    # steady climb rather than just faster.
    lead = arpeggio(
        ["E5", "G5", "A5", "G5", "E5", "D5", "E5", "G5"], 0.135, amp=0.2
    )
    bass = concat(*[square(164.81, 0.27, amp=0.15) for _ in range(4)])
    bar = mix(lead, bass)
    write_wav("music_arcade_loop.wav", concat(bar, bar))


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    build_sfx()
    build_music()
