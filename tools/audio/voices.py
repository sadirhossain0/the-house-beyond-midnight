"""Character voices: a small formant synthesiser that speaks an invented syllable language.

Each voice is a glottal source (additive harmonics with spectral tilt, jitter and shimmer, optional
vibrato and tremble) shaped by vocal-tract resonances whose spacing follows the speaker's tract
length, with consonants made of bursts, frication and nasal murmur. Nothing is sampled and nothing
is text-to-speech: the game strings syllables from each bank deterministically from the line text,
so the same line always sounds the same, and each person sounds like themselves.

    python3 tools/audio/voices.py
"""
import os, sys
import numpy as np
from scipy import signal
from common import SR, AUDIO, write_wav, normalize, fade, reverb, lowpass, highpass, bandpass

VOICE_DIR = os.path.join(AUDIO, 'voice')

VOWELS = {'a': (730, 1090, 2440), 'e': (530, 1840, 2480), 'i': (300, 2250, 3000), 'o': (570, 840, 2410), 'u': (320, 870, 2240),
          '@': (500, 1450, 2500), 'ae': (660, 1720, 2410), 'ai': ((730, 1090, 2440), (300, 2250, 3000)), 'ou': ((570, 840, 2410), (320, 870, 2240)),
          'ei': ((530, 1840, 2480), (300, 2250, 3000)), 'm': (250, 1100, 2400)}
CONS = ['', 'b', 'd', 'g', 'p', 't', 'k', 'm', 'n', 'l', 'r', 'w', 'y', 's', 'sh', 'f', 'h', 'v', 'z', 'th']

PROFILES = {
    # f0, formant scale, breathiness, tilt, vibrato (rate, depth), tremble, speed, rasp
    'avery': dict(f0=168, fs=1.07, breath=0.14, tilt=1.25, vib=(5.2, 0.006), trem=0.0, speed=1.0, rasp=0.0, seed=11),
    'mara': dict(f0=222, fs=1.16, breath=0.1, tilt=1.1, vib=(5.6, 0.018), trem=0.0, speed=1.06, rasp=0.0, seed=23),
    'porter': dict(f0=112, fs=0.95, breath=0.34, tilt=1.45, vib=(4.4, 0.01), trem=0.022, speed=0.82, rasp=0.15, seed=37),
    'pip': dict(f0=330, fs=1.3, breath=0.2, tilt=1.2, vib=(6.5, 0.012), trem=0.0, speed=1.4, rasp=0.0, seed=41),
    'host': dict(f0=104, fs=0.9, breath=0.08, tilt=1.05, vib=(5.0, 0.014), trem=0.0, speed=0.95, rasp=0.05, seed=53),
    'edmund': dict(f0=98, fs=0.92, breath=0.22, tilt=1.35, vib=(4.6, 0.008), trem=0.008, speed=0.76, rasp=0.08, seed=67),
    'king': dict(f0=98, fs=0.92, breath=0.22, tilt=1.35, vib=(4.6, 0.008), trem=0.008, speed=0.76, rasp=0.08, seed=67),
    'guide': dict(f0=190, fs=1.1, breath=0.12, tilt=1.2, vib=(5.0, 0.008), trem=0.0, speed=1.12, rasp=0.0, seed=71),
}


def resonator(x, f, bw):
    f = min(f, SR * 0.45)
    r = np.exp(-np.pi * bw / SR); th = 2 * np.pi * f / SR
    a = [1, -2 * r * np.cos(th), r * r]
    b = [(1 - r * r) * 0.5, 0, -(1 - r * r) * 0.5]
    return signal.lfilter(b, a, x)


class Voice:
    def __init__(self, name):
        self.name = name
        self.p = PROFILES[name]
        self.r = np.random.default_rng(self.p['seed'])

    # ------------------------------------------------------------------ source
    def source(self, f0_curve, breath=None):
        p = self.p; n = len(f0_curve)
        tt = np.arange(n) / SR
        vib = 1 + p['vib'][1] * np.sin(2 * np.pi * p['vib'][0] * tt + self.r.random() * 6)
        trem = 1 + p['trem'] * np.sin(2 * np.pi * 9.0 * tt) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.7 * tt))
        jitter = 1 + np.cumsum(self.r.standard_normal(n)) * 0.00002
        jitter = 1 + (jitter - np.linspace(jitter[0], jitter[-1], n)) * 0.6
        f0 = f0_curve * vib * trem * jitter
        ph = 2 * np.pi * np.cumsum(f0) / SR
        out = np.zeros(n)
        K = int(5500 / max(60, f0.max()))
        for k in range(1, K + 1):
            amp = 1.0 / k ** p['tilt']
            out += amp * np.sin(k * ph)
        shimmer = 1 + 0.04 * signal.lfilter([1], [1, -0.995], self.r.standard_normal(n)) * 0.05
        out *= shimmer
        b = p['breath'] if breath is None else breath
        asp = highpass(self.r.standard_normal(n), 500) * b * 0.9
        if p['rasp'] > 0:
            out *= 1 + p['rasp'] * np.sign(np.sin(ph * 0.5)) * 0.5
        return out * (1 - b * 0.5) + asp

    def tract(self, x, formants, open_=1.0):
        fs = self.p['fs']
        y = np.zeros_like(x)
        for i, (f, bw, g) in enumerate(zip(formants, (80, 100, 140), (1.0, 0.55, 0.28))):
            y += resonator(x, f * fs, bw * fs) * g
        return y * open_

    # ------------------------------------------------------------------ pieces
    def vowel(self, v, dur, f0a, f0b):
        n = int(dur * SR)
        f0 = np.linspace(f0a, f0b, n)
        src = self.source(f0)
        spec = VOWELS[v]
        if isinstance(spec[0], tuple):   # diphthong: crossfade two tracts
            h = n // 2
            a = self.tract(src, spec[0]); b = self.tract(src, spec[1])
            w = np.clip((np.arange(n) - h * 0.6) / (h * 0.8), 0, 1)
            y = a * (1 - w) + b * w
        else:
            y = self.tract(src, spec)
        env = np.minimum(1, np.arange(n) / (0.012 * SR)) * np.minimum(1, (n - np.arange(n)) / (0.045 * SR))
        return y * env

    def consonant(self, c, f0):
        r = self.r
        if c == '': return np.zeros(0)
        def burst(lo, hi, d=0.012, asp=0.02):
            n = int(d * SR); b = bandpass(r.standard_normal(n), lo, hi) * np.exp(-np.arange(n) / (0.003 * SR))
            na = int(asp * SR); a = highpass(r.standard_normal(na), 800) * 0.25 * np.linspace(1, 0.2, na)
            return np.concatenate([b, a])
        def fric(lo, hi, d, g=0.5):
            n = int(d * SR); x = bandpass(r.standard_normal(n), lo, min(hi, 20000)) * g
            return x * np.sin(np.pi * np.arange(n) / n) ** 0.6
        def voiced(form, d, g=0.5):
            n = int(d * SR); return self.tract(self.source(np.full(n, f0)), form) * g * np.sin(np.pi * np.arange(n) / n * 0.5 + 0.0) ** 0.3
        fs = self.p['fs']
        table = {
            'p': lambda: burst(500 * fs, 2000 * fs, 0.008, 0.03), 't': lambda: burst(3000 * fs, 7000 * fs, 0.008, 0.025), 'k': lambda: burst(1500 * fs, 3500 * fs, 0.012, 0.03),
            'b': lambda: burst(300 * fs, 1500 * fs, 0.006, 0.004) * 0.7, 'd': lambda: burst(2500 * fs, 5000 * fs, 0.006, 0.004) * 0.7, 'g': lambda: burst(1200 * fs, 3000 * fs, 0.008, 0.005) * 0.7,
            's': lambda: fric(4500 * fs, 9500 * fs, 0.075), 'sh': lambda: fric(2200 * fs, 5000 * fs, 0.075), 'f': lambda: fric(1500, 9000, 0.06, 0.2),
            'th': lambda: fric(1800, 8000, 0.05, 0.16), 'h': lambda: fric(500, 4000, 0.05, 0.15), 'v': lambda: fric(1500, 7000, 0.05, 0.15) + voiced((280, 1200, 2300), 0.05, 0.25),
            'z': lambda: fric(4000 * fs, 9000 * fs, 0.06, 0.3) + voiced((280, 1600, 2500), 0.06, 0.25),
            'm': lambda: voiced((250, 1100, 2300), 0.055, 0.45), 'n': lambda: voiced((260, 1500, 2600), 0.05, 0.45),
            'l': lambda: voiced((360, 1300, 2900), 0.04, 0.6), 'r': lambda: voiced((420, 1250, 1600), 0.045, 0.6),
            'w': lambda: voiced((300, 700, 2200), 0.04, 0.6), 'y': lambda: voiced((280, 2300, 3000), 0.035, 0.6),
        }
        return table[c]()

    def syllable(self, c, v, dur=0.15, f0=None, fall=0.06):
        f0 = f0 or self.p['f0']
        cons = self.consonant(c, f0)
        vow = self.vowel(v, dur / self.p['speed'], f0 * (1 + fall * 0.3), f0 * (1 - fall))
        ov = int(0.01 * SR)
        if len(cons) > ov:
            out = np.zeros(len(cons) + len(vow) - ov)
            out[:len(cons)] += cons
            out[len(cons) - ov:] += vow
        else:
            out = vow
        return out

    # ------------------------------------------------------------------ banks
    def bank(self, n=32):
        r = np.random.default_rng(self.p['seed'] + 1000)
        vowels = ['a', 'e', 'i', 'o', 'u', '@', 'ae', 'ai', 'ou', 'ei']
        out = []
        for i in range(n):
            c = CONS[r.integers(0, len(CONS))] if r.random() > 0.12 else ''
            v = vowels[r.integers(0, len(vowels))]
            dur = 0.11 + r.random() * 0.08
            f0 = self.p['f0'] * (0.94 + r.random() * 0.14)
            s = self.syllable(c, v, dur, f0, fall=0.03 + r.random() * 0.06)
            out.append(self.finish(s))
        return out

    def finish(self, s, room=0.06):
        s = highpass(s, 70)
        s = lowpass(s, 9000)
        s = fade(normalize(s, -4.0), 0.003, 0.02)
        return s

    def phrase(self, parts):
        """parts: list of (consonant, vowel, dur, f0_mult, gap)."""
        segs = []
        for c, v, d, m, gap in parts:
            segs.append(self.syllable(c, v, d, self.p['f0'] * m, fall=0.08))
            if gap > 0: segs.append(np.zeros(int(gap * SR)))
        return np.concatenate(segs)

    def breath(self, dur, inhale=False, g=0.4):
        n = int(dur * SR); x = bandpass(self.r.standard_normal(n), 400, 5000) * g
        e = np.sin(np.pi * np.arange(n) / n) ** (0.6 if not inhale else 1.4)
        if inhale: e = e * np.linspace(0.6, 1.0, n)
        return x * e

    def reactions(self):
        f = 1.0
        R = {}
        R['hm'] = self.phrase([('m', 'm', 0.32, 1.0, 0)])
        R['curious'] = self.phrase([('h', 'm', 0.16, 0.95, 0), ('m', 'm', 0.2, 1.18, 0)])
        R['oh'] = self.phrase([('', 'o', 0.32, 1.12, 0)])
        R['surprised'] = np.concatenate([self.breath(0.12, True, 0.3), self.phrase([('', 'o', 0.26, 1.3, 0)])])
        R['gasp'] = np.concatenate([self.breath(0.22, True, 0.55), self.phrase([('h', 'a', 0.12, 1.35, 0)]) * 0.6])
        R['happy'] = self.phrase([('h', 'a', 0.12, 1.15, 0.05), ('h', 'a', 0.16, 1.05, 0)])
        R['laugh'] = self.phrase([('h', 'a', 0.1, 1.2, 0.04), ('h', 'a', 0.1, 1.15, 0.04), ('h', 'a', 0.12, 1.05, 0.04), ('h', '@', 0.16, 0.95, 0)])
        R['sigh'] = np.concatenate([self.breath(0.25, True, 0.3), self.phrase([('h', 'a', 0.5, 0.95, 0)]) * 0.7, self.breath(0.4, False, 0.25)])
        R['hurt'] = self.phrase([('', '@', 0.14, 1.25, 0)])
        R['faint'] = np.concatenate([self.phrase([('', 'o', 0.6, 1.0, 0)]), self.breath(0.5, False, 0.2)])
        R['worried'] = self.phrase([('', 'u', 0.18, 1.05, 0.03), ('h', 'm', 0.25, 0.92, 0)])
        return {k: self.finish(v) for k, v in R.items()}

    def hum(self, notes):
        """Hum a melody: [(note name, seconds)]."""
        from compose import nn
        segs = []
        for name, d in notes:
            f = 440.0 * 2 ** ((nn(name) - 69) / 12) * (self.p['f0'] / 104.0) * 0.5 * 2
            n = int(d * SR)
            src = self.source(np.full(n, f), breath=0.06)
            y = self.tract(src, VOWELS['m']) * np.minimum(1, np.arange(n) / (0.03 * SR)) * np.minimum(1, (n - np.arange(n)) / (0.06 * SR))
            segs.append(y)
        return normalize(np.concatenate(segs), -3)


def build(name):
    v = Voice(name)
    d = os.path.join(VOICE_DIR, name)
    os.makedirs(d, exist_ok=True)
    for i, s in enumerate(v.bank(32)):
        write_wav(os.path.join(d, 'syl_%02d.wav' % i), s.astype(np.float32), mono=True)
    for k, s in v.reactions().items():
        write_wav(os.path.join(d, 'react_%s.wav' % k), s.astype(np.float32), mono=True)
    print('voice', name)


if __name__ == '__main__':
    sys.path.insert(0, os.path.dirname(__file__))
    for n in (sys.argv[1:] or PROFILES.keys()):
        build(n)
