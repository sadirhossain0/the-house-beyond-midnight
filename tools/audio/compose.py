"""The score. Every cue is built from one tune, "The Ashcombe Waltz", arranged per room and rendered
through FluidR3 (MIT-licensed General MIDI soundfont) with FluidSynth, then finished with our own
hall reverb and seamless loop folding. Adaptive tracks render one file per stem, sample-locked, so
the game can crossfade layers (Now/Then, missing/complete beat, boss intensity) without drift.

The waltz has a famous flaw: in the fourth bar, the third beat never comes. The "missing" stems
leave that beat as a hole the whole band falls into; the "complete" stems play it.

    python3 tools/audio/compose.py [track ...]
"""
import os, sys, subprocess
import numpy as np
import mido
from common import *

SF2 = '/usr/share/sounds/sf2/FluidR3_GM.sf2'
TPB = 960
OUT = os.path.join(AUDIO, 'music')
NAMES = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11}


def nn(s):
    if isinstance(s, int): return s
    p = NAMES[s[0]]; i = 1
    while i < len(s) and s[i] in '#b':
        p += 1 if s[i] == '#' else -1; i += 1
    return 12 * (int(s[i:]) + 1) + p


# ------------------------------------------------------------------------------- the tune
# (pitch, beats) per bar. 3/4. A, A', B, A'.
A = [[('A4', 1), ('D5', 2)], [('C#5', 1), ('D5', 1), ('E5', 1)], [('F5', 2), ('E5', 1)], [('D5', 2), ('A4', 1)],
     [('Bb4', 1), ('D5', 2)], [('A4', 1), ('C5', 1), ('Bb4', 1)], [('A4', 1), ('G4', 1), ('F4', 1)], [('E4', 3)]]
A2 = [[('A4', 1), ('D5', 2)], [('C#5', 1), ('D5', 1), ('E5', 1)], [('F5', 1), ('G5', 1), ('A5', 1)], [('Bb5', 2), ('A5', 1)],
      [('G5', 1), ('F5', 1), ('E5', 1)], [('F5', 1), ('E5', 1), ('D5', 1)], [('C#5', 2), ('E5', 1)], [('D5', 3)]]
B = [[('C5', 1), ('F5', 2)], [('E5', 1), ('F5', 1), ('G5', 1)], [('A5', 2), ('G5', 1)], [('F5', 2), ('C5', 1)],
     [('D5', 1), ('F5', 2)], [('E5', 1), ('D5', 1), ('C5', 1)], [('Bb4', 1), ('A4', 1), ('G4', 1)], [('A4', 3)]]
TUNE = A + A2 + B + A2
CH_A = ['Dm', 'A7', 'Dm', 'Dm', 'Gm', 'Dm', 'Dm', 'A7']
CH_A2 = ['Dm', 'A7', 'Dm', 'Gm', 'C7', 'F', 'A7', 'Dm']
CH_B = ['F', 'C7', 'F', 'F', 'Bb', 'C7', 'Gm', 'A7']
CHORDS = CH_A + CH_A2 + CH_B + CH_A2
CHORD_TONES = {'Dm': [2, 5, 9], 'A7': [9, 1, 4, 7], 'Gm': [7, 10, 2], 'C7': [0, 4, 7, 10], 'F': [5, 9, 0], 'Bb': [10, 2, 5], 'D': [2, 6, 9], 'A': [9, 1, 4],
               'G': [7, 11, 2], 'Bm': [11, 2, 6], 'Em': [4, 7, 11], 'Am': [9, 0, 4], 'E7': [4, 8, 11, 2], 'Dsus': [2, 7, 9], 'Bbmaj7': [10, 2, 5, 9], 'Gm6': [7, 10, 2, 4], 'C': [0, 4, 7]}
ROOT = {'Dm': 'D', 'A7': 'A', 'Gm': 'G', 'C7': 'C', 'F': 'F', 'Bb': 'Bb', 'D': 'D', 'A': 'A', 'G': 'G', 'Bm': 'B', 'Em': 'E', 'Am': 'A', 'E7': 'E', 'Dsus': 'D', 'Bbmaj7': 'Bb', 'Gm6': 'G', 'C': 'C'}
MISSING_BAR = 3          # bar 4 (0-indexed 3): its third beat never comes


def voicing(chord, lo, hi, n=3):
    pcs = CHORD_TONES[chord]
    out = []
    p = lo
    while p <= hi and len(out) < n:
        if p % 12 in pcs: out.append(p)
        p += 1
    return out


def root(chord, octave=2):
    return nn(ROOT[chord] + str(octave))


def major(pitch_name):
    """D minor tune -> D major (raise F, C, Bb)."""
    return pitch_name.replace('F', 'F#').replace('C5', 'C#5').replace('C4', 'C#4').replace('C6', 'C#6').replace('Bb', 'B')


# ------------------------------------------------------------------------------- song model
class Part:
    def __init__(self, program, vol=100, pan=64, rev=50, chorus=0, channel=None, human=0.008, legato=0.95, bank=0):
        self.program = program; self.vol = vol; self.pan = pan; self.rev = rev; self.chorus = chorus
        self.channel = channel; self.human = human; self.legato = legato; self.bank = bank
        self.notes = []   # (beat, dur, pitch, vel)

    def n(self, beat, dur, pitch, vel=80):
        self.notes.append((float(beat), float(dur), nn(pitch), int(vel)))
        return self


class Song:
    def __init__(self, name, bpm, meter=3, bars=32, loop=True, tail=5.0, rubato=0.0, room=0.75, wet=0.22, rev_seconds=2.6):
        self.name = name; self.bpm = bpm; self.meter = meter; self.bars = bars; self.loop = loop; self.tail = tail
        self.rubato = rubato; self.room = room; self.wet = wet; self.rev_seconds = rev_seconds
        self.stems = {}
        self.skip = []   # (start_beat, end_beat) holes the whole band falls into (per stem name filter)

    def part(self, stem, *a, **k):
        p = Part(*a, **k)
        self.stems.setdefault(stem, []).append(p)
        return p

    @property
    def beats(self): return self.bars * self.meter

    def k(self, bar):
        """Tempo multiplier for a bar: the band breathes at phrase ends (same for every stem)."""
        if self.rubato <= 0: return 1.0
        ph = bar % 8
        return 1.0 - self.rubato * (0.6 if ph == 7 else (0.25 if ph == 3 else 0.0)) + self.rubato * 0.15 * np.sin(bar * 0.9)

    def seconds(self):
        return sum(self.meter * 60.0 / (self.bpm * self.k(b)) for b in range(self.bars))

    def midi(self, stem):
        mf = mido.MidiFile(ticks_per_beat=TPB)
        meta = mido.MidiTrack(); mf.tracks.append(meta)
        meta.append(mido.MetaMessage('time_signature', numerator=self.meter, denominator=4, time=0))
        # tempo map: gentle rubato that breathes at phrase ends, identical for every stem
        last = 0
        for bar in range(self.bars + 8):
            k = self.k(bar)
            t = bar * self.meter * TPB
            meta.append(mido.MetaMessage('set_tempo', tempo=mido.bpm2tempo(self.bpm * k), time=t - last)); last = t
        chans = [c for c in range(16) if c != 9]
        r = np.random.default_rng(hash((self.name, stem)) & 0xffff)
        for i, p in enumerate(self.stems[stem]):
            ch = p.channel if p.channel is not None else chans[i % len(chans)]
            tr = mido.MidiTrack(); mf.tracks.append(tr)
            ev = [(0, mido.Message('control_change', channel=ch, control=0, value=p.bank)),
                  (0, mido.Message('program_change', channel=ch, program=p.program)),
                  (0, mido.Message('control_change', channel=ch, control=7, value=p.vol)),
                  (0, mido.Message('control_change', channel=ch, control=10, value=p.pan)),
                  (0, mido.Message('control_change', channel=ch, control=91, value=p.rev)),
                  (0, mido.Message('control_change', channel=ch, control=93, value=p.chorus))]
            for (b, d, pitch, vel) in p.notes:
                cut = False
                for (s0, s1, stems) in self.skip:
                    if stems is not None and stem not in stems: continue
                    if s0 <= b < s1: cut = True; break
                    if b < s0 < b + d: d = s0 - b
                if cut or d <= 0.02: continue
                jitter = r.normal(0, p.human) * self.bpm / 60.0 if p.human > 0 else 0.0
                on = max(0, int((b + jitter) * TPB))
                off = max(on + 10, int((b + d * p.legato) * TPB))
                v = int(np.clip(vel + r.normal(0, 4), 1, 127))
                ev.append((on, mido.Message('note_on', channel=ch, note=int(pitch), velocity=v)))
                ev.append((off, mido.Message('note_off', channel=ch, note=int(pitch), velocity=0)))
            ev.sort(key=lambda e: (e[0], 0 if e[1].type != 'note_on' else 1))
            t0 = 0
            for t, m in ev:
                m.time = t - t0; t0 = t; tr.append(m)
        return mf

    def render(self):
        os.makedirs(OUT, exist_ok=True)
        wavs = {}
        for stem in self.stems:
            mid = os.path.join(TMP, f'{self.name}_{stem}.mid'); wav = os.path.join(TMP, f'{self.name}_{stem}.wav')
            self.midi(stem).save(mid)
            subprocess.run(['fluidsynth', '-ni', '-q', '-g', '0.45', '-r', str(SR), '-o', 'synth.reverb.active=1',
                            '-o', f'synth.reverb.room-size={self.room}', '-o', 'synth.reverb.damp=0.35', '-o', 'synth.reverb.level=0.55',
                            '-o', 'synth.chorus.active=1', '-o', 'synth.polyphony=512', '-F', wav, SF2, mid], check=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            wavs[stem] = read_wav(wav)
        # common processing: hall reverb, loop folding, a shared gain so stems keep their balance
        length = int(round(self.seconds() * SR)) if self.loop else max(w.shape[0] for w in wavs.values())
        proc = {}
        for stem, a in wavs.items():
            a = highpass(a, 28)
            a = reverb(a, wet=self.wet, seconds=self.rev_seconds, predelay=0.025)
            if self.loop:
                a = fold_loop(a, length)
            else:
                a = a[:length + int(self.tail * SR)]
                a = fade(a, 0.002, min(3.0, self.tail))
            proc[stem] = a
        n = max(a.shape[0] for a in proc.values())
        mix = np.zeros((n, 2), np.float32)
        for a in proc.values(): mix[:a.shape[0]] += a
        # loudness-match every cue (RMS -19 dBFS) without letting peaks pass -1.5 dBFS
        g = min(10 ** (-1.5 / 20) / (np.max(np.abs(mix)) + 1e-9), 10 ** ((-19.0 - rms_db(mix)) / 20))
        for stem, a in proc.items():
            w = os.path.join(TMP, f'{self.name}__{stem}.wav')
            write_wav(w, soft_clip(a * g, 1.1))
            to_ogg(w, os.path.join(OUT, f'{stem}.ogg'), q=7)
        print(f'{self.name}: {len(proc)} stems, {n / SR:.1f}s')


# ------------------------------------------------------------------------------- instruments (GM)
PIANO, BRIGHT, HARPSI, CELESTA, GLOCK, MUSICBOX, VIBES, MARIMBA = 0, 1, 6, 8, 9, 10, 11, 12
TUBULAR, ORGAN, CHURCH = 14, 19, 19
VIOLIN, VIOLA, CELLO, CONTRABASS, TREMOLO, PIZZ, HARP, TIMPANI = 40, 41, 42, 43, 44, 45, 46, 47
STRINGS, SLOW_STRINGS, SYNTH_STR, CHOIR, OOHS = 48, 49, 50, 52, 53
TRUMPET, TROMBONE, TUBA, HORN, BRASS = 56, 57, 58, 60, 61
OBOE, ENG_HORN, BASSOON, CLARINET, PICCOLO, FLUTE = 68, 69, 70, 71, 72, 73
WOODBLOCK, BOWED_GLASS, PAD_WARM, PAD_HALO = 115, 92, 89, 94


def melody(part, start_bar, bars, meter=3, octave=0, vel=82, transform=None, dur_scale=1.0):
    for i, bar in enumerate(bars):
        b = (start_bar + i) * meter
        for (p, d) in bar:
            name = transform(p) if transform else p
            part.n(b, d * dur_scale, nn(name) + 12 * octave, vel)
            b += d


def waltz_bass(part, chords, start_bar=0, octave=2, vel=78, fifth_every=2, meter=3, beat=1.0):
    for i, c in enumerate(chords):
        r = root(c, octave)
        if fifth_every and i % fifth_every == 1 and c in CHORD_TONES:
            r = r + 7 if (r + 7) <= nn('A3') else r - 5
        part.n((start_bar + i) * meter, beat, r, vel)


def waltz_chords(part, chords, start_bar=0, lo='A3', hi='F4', vel=56, beats=(1, 2), meter=3, dur=0.8):
    for i, c in enumerate(chords):
        for bt in beats:
            for p in voicing(c, nn(lo), nn(hi), 3):
                part.n((start_bar + i) * meter + bt, dur, p, vel)


def pad(part, chords, start_bar=0, lo='D3', hi='D4', vel=50, meter=3, bars_per=1, n=4):
    for i in range(0, len(chords), bars_per):
        for p in voicing(chords[i], nn(lo), nn(hi), n):
            part.n((start_bar + i) * meter, meter * bars_per, p, vel)


def arpeggio(part, chords, start_bar=0, lo='D3', meter=3, vel=58, pattern=(0, 1, 2, 3, 2, 1), step=0.5):
    for i, c in enumerate(chords):
        v = voicing(c, nn(lo), nn(lo) + 24, 6)
        for k in range(int(meter / step)):
            idx = pattern[k % len(pattern)] % len(v)
            part.n((start_bar + i) * meter + k * step, step * 1.6, v[idx], vel - (6 if k % 2 else 0))


# ------------------------------------------------------------------------------- cues
def ballroom():
    s = Song('ballroom', 90, bars=32, rubato=0.0, room=0.85, wet=0.24)
    s.skip = [(MISSING_BAR * 3 + 2, MISSING_BAR * 3 + 3, {'waltz_now_missing', 'waltz_then_missing'})]
    for stem in ['waltz_then_missing', 'waltz_then_complete']:
        vln = s.part(stem, VIOLIN, 104, 58, 50, human=0.006); melody(vln, 0, TUNE, vel=92)
        fl = s.part(stem, FLUTE, 80, 74, 50); melody(fl, 16, B, octave=1, vel=70)
        for i, bar in enumerate(A2):
            if i in (2, 3, 4): melody(fl, 8 + i, [bar], octave=0, vel=58)
        pno = s.part(stem, PIANO, 92, 70, 40); waltz_bass(pno, CHORDS, octave=2, vel=72); waltz_chords(pno, CHORDS, vel=50)
        cb = s.part(stem, PIZZ, 90, 48, 40); waltz_bass(cb, CHORDS, octave=2, vel=84)
        st = s.part(stem, STRINGS, 72, 64, 60); pad(st, CHORDS, lo='F3', hi='D5', vel=42)
        vla = s.part(stem, VIOLA, 70, 80, 50)
        for i, c in enumerate(CHORDS):
            v = voicing(c, nn('A3'), nn('A4'), 2)
            for bt in (1, 2): vla.n(i * 3 + bt, 0.6, v[-1], 46)
        hp = s.part(stem, HARP, 70, 40, 60)
        for i in (7, 15, 23, 31):
            for k, p in enumerate(voicing(CHORDS[i], nn('D3'), nn('D6'), 9)): hp.n(i * 3 + k * 0.16, 2.5, p, 52)
    for stem in ['waltz_now_missing', 'waltz_now_complete']:
        mb = s.part(stem, MUSICBOX, 96, 64, 90, human=0.012); melody(mb, 0, TUNE, octave=1, vel=78)
        cel = s.part(stem, CELESTA, 70, 50, 90); waltz_bass(cel, CHORDS, octave=3, vel=56); waltz_chords(cel, CHORDS, lo='A4', hi='F5', vel=34)
        gl = s.part(stem, BOWED_GLASS, 50, 80, 100); pad(gl, CHORDS[::2] * 1, lo='D4', hi='D5', vel=30, bars_per=2)
        low = s.part(stem, SLOW_STRINGS, 50, 64, 80); pad(low, CHORDS[::4], lo='D2', hi='D3', vel=40, bars_per=4, n=2)
    return s


def lastdance():
    s = Song('lastdance', 90, bars=40, rubato=0.0, room=0.85, wet=0.24)
    tune = TUNE + A2[:8]
    ch = CHORDS + CH_A2
    vln = s.part('lastdance', VIOLIN, 108, 58, 50, human=0.005); melody(vln, 0, tune, vel=96)
    vln2 = s.part('lastdance', VIOLIN, 84, 72, 50)
    for i, bar in enumerate(tune):
        if i >= 8: melody(vln2, i, [bar], octave=-1, vel=64)
    fl = s.part('lastdance', FLUTE, 84, 76, 50); melody(fl, 16, B, octave=1, vel=72); melody(fl, 32, A2, octave=1, vel=70)
    pno = s.part('lastdance', PIANO, 92, 70, 40); waltz_bass(pno, ch, octave=2, vel=74); waltz_chords(pno, ch, vel=52)
    cb = s.part('lastdance', PIZZ, 92, 48, 40); waltz_bass(cb, ch, octave=2, vel=88)
    st = s.part('lastdance', STRINGS, 80, 64, 60); pad(st, ch, lo='F3', hi='D5', vel=48)
    hn = s.part('lastdance', HORN, 70, 54, 60); pad(hn, ch[::2], lo='A3', hi='A4', vel=46, bars_per=2, n=2)
    hp = s.part('lastdance', HARP, 74, 40, 60)
    for i in range(7, 40, 8):
        for k, p in enumerate(voicing(ch[i], nn('D3'), nn('D6'), 9)): hp.n(i * 3 + k * 0.16, 2.5, p, 56)
    tp = s.part('lastdance', TIMPANI, 80, 64, 40)
    for i in range(24, 40): tp.n(i * 3, 1, root(ch[i], 2), 60 if i % 2 else 72)
    return s


def title():
    s = Song('title', 66, bars=24, rubato=0.12, room=0.92, wet=0.3, rev_seconds=3.2)
    ch = CH_A + CH_A2 + CH_A[:8]
    cel = s.part('title_base', CELESTA, 90, 70, 90, human=0.015); melody(cel, 0, A, octave=1, vel=70); melody(cel, 16, A, octave=1, vel=62)
    hp = s.part('title_base', HARP, 84, 50, 70); arpeggio(hp, ch, lo='D3', vel=56)
    vc = s.part('title_base', CELLO, 80, 54, 60); melody(vc, 8, A2, octave=-1, vel=70)
    st = s.part('title_base', SLOW_STRINGS, 76, 64, 80); pad(st, ch, lo='D3', hi='F4', vel=46)
    cb = s.part('title_base', CONTRABASS, 70, 60, 60)
    for i, c in enumerate(ch): cb.n(i * 3, 3, root(c, 1), 54)
    ch2 = s.part('title_choir', OOHS, 84, 64, 100); pad(ch2, ch, lo='A3', hi='A4', vel=48, n=3)
    sop = s.part('title_choir', CHOIR, 70, 64, 100); melody(sop, 8, A2, octave=0, vel=50, dur_scale=1.0)
    return s


def exterior():
    s = Song('exterior', 54, meter=4, bars=16, rubato=0.08, room=0.95, wet=0.34, rev_seconds=4.0)
    ch = ['Dm', 'Dm', 'Bb', 'Bb', 'Gm', 'Gm', 'A7', 'A7'] * 2
    st = s.part('exterior_drone', SLOW_STRINGS, 74, 64, 90)
    for i in range(0, 16, 2):
        for p in voicing(ch[i], nn('D2'), nn('A3'), 3): st.n(i * 4, 8, p, 44 + (i % 4) * 2)
    gl = s.part('exterior_drone', BOWED_GLASS, 46, 70, 110)
    for i in range(0, 16, 4): gl.n(i * 4 + 2, 10, voicing(ch[i], nn('D4'), nn('D5'), 2)[-1], 34)
    pn = s.part('exterior_drone', PIANO, 64, 80, 110, human=0.02)
    motif = [('A4', 0.0), ('D5', 1.5), ('C#5', 6.0), ('D5', 6.5), ('F5', 17.0), ('E5', 18.0), ('A4', 33.0), ('D5', 34.5), ('Bb4', 48.0), ('A4', 49.0)]
    for p, b in motif: pn.n(b, 3, p, 46)
    return s


def hall():
    s = Song('hall', 84, bars=32, rubato=0.05, room=0.88, wet=0.28)
    hp = s.part('hall_base', HARP, 86, 50, 70, human=0.01)
    for i, c in enumerate(CHORDS):
        v = voicing(c, nn('D3'), nn('D5'), 6)
        hp.n(i * 3, 2.8, root(c, 2), 62)
        for k, bt in enumerate((1, 1.5, 2, 2.5)): hp.n(i * 3 + bt, 1.0, v[(k + 1) % len(v)], 46)
    cel = s.part('hall_base', CELESTA, 76, 76, 80); melody(cel, 0, A, octave=1, vel=60); melody(cel, 16, B, octave=1, vel=56)
    pz = s.part('hall_base', PIZZ, 70, 56, 50); waltz_bass(pz, CHORDS, octave=2, vel=64)
    cl = s.part('hall_layer1', CLARINET, 88, 56, 60); melody(cl, 8, A2, octave=-1, vel=70); melody(cl, 24, A2, octave=-1, vel=70)
    bs = s.part('hall_layer1', BASSOON, 70, 70, 50)
    for i in range(16, 24): bs.n(i * 3, 2, root(CHORDS[i], 3), 56)
    st = s.part('hall_layer2', STRINGS, 78, 64, 70); pad(st, CHORDS, lo='F3', hi='D5', vel=44)
    vc = s.part('hall_layer2', CELLO, 74, 50, 60); melody(vc, 0, A, octave=-1, vel=58)
    return s


def corridor():
    s = Song('corridor', 72, bars=16, rubato=0.06, room=0.7, wet=0.3, rev_seconds=2.4)
    ch = ['Dm', 'Dm', 'Gm', 'Gm', 'Bb', 'Bb', 'A7', 'A7'] * 2
    vc = s.part('corridor_base', CELLO, 76, 52, 60)
    for i in range(0, 16, 2): vc.n(i * 3, 6, root(ch[i], 2), 50)
    mb = s.part('corridor_base', MUSICBOX, 74, 80, 100, human=0.02)
    frag = A[:3] + [[('D5', 3)]]
    melody(mb, 2, frag, octave=1, vel=58); melody(mb, 10, frag, octave=1, vel=52)
    gl = s.part('corridor_base', BOWED_GLASS, 40, 64, 110); gl.n(0, 24, 'A4', 28); gl.n(24, 24, 'Bb4', 26)
    tr = s.part('corridor_tension', TREMOLO, 70, 64, 60)
    for i in range(0, 16, 4):
        for p in voicing(ch[i], nn('D3'), nn('D4'), 3): tr.n(i * 3, 12, p, 44)
    wb = s.part('corridor_tension', WOODBLOCK, 56, 40, 30, human=0.0)
    for b in range(0, 48, 1): wb.n(b, 0.2, 'E5' if b % 2 == 0 else 'B4', 40 if b % 2 == 0 else 30)
    lo = s.part('corridor_tension', CONTRABASS, 70, 64, 50)
    for b in range(0, 48, 3): lo.n(b, 1.5, 'D2', 52)
    return s


def boss():
    s = Song('boss', 150, bars=32, room=0.8, wet=0.2)
    ch = (['Dm', 'Dm', 'Bb', 'A7'] * 4) + (['Gm', 'Dm', 'A7', 'Dm'] * 4)
    cb = s.part('boss_base', CELLO, 96, 54, 40, human=0.004)
    for i, c in enumerate(ch):
        r = root(c, 2)
        for k, p in enumerate((r, r + 7, r + 12)): cb.n(i * 3 + k, 0.9, p, 86 if k == 0 else 70)
    hs = s.part('boss_base', HARPSI, 84, 74, 40); waltz_chords(hs, ch, lo='D4', hi='A4', vel=66, dur=0.5)
    tp = s.part('boss_base', TIMPANI, 86, 64, 40)
    for i, c in enumerate(ch): tp.n(i * 3, 1, root(c, 2), 74 if i % 2 == 0 else 62)
    br = s.part('boss_intensity1', BRASS, 86, 64, 50)
    for i, c in enumerate(ch):
        if i % 2 == 0:
            for p in voicing(c, nn('D4'), nn('D5'), 3): br.n(i * 3 + 2, 0.5, p, 84); br.n(i * 3 + 3, 0.8, p, 92)
    trm = s.part('boss_intensity1', TREMOLO, 80, 64, 50); pad(trm, ch, lo='A3', hi='F5', vel=58)
    vl = s.part('boss_intensity2', VIOLIN, 96, 64, 50); melody(vl, 0, A + A2 + A + A2, octave=0, vel=96, dur_scale=1.0)
    chr_ = s.part('boss_intensity2', CHOIR, 84, 64, 70); pad(chr_, ch, lo='D4', hi='D5', vel=64)
    return s


def echo():
    s = Song('echo', 60, meter=4, bars=8, room=0.95, wet=0.4, rev_seconds=4.5)
    gk = s.part('echo_shimmer', GLOCK, 66, 40, 120, human=0.02)
    for k, (p, b) in enumerate([('A5', 0), ('D6', 1.5), ('C#6', 4), ('D6', 5), ('E6', 6), ('F6', 8), ('E6', 10), ('D6', 12), ('A5', 16), ('Bb5', 20), ('A5', 24), ('D6', 28)]):
        gk.n(b, 3, p, 50)
    hl = s.part('echo_shimmer', PAD_HALO, 60, 64, 120); hl.n(0, 16, 'D4', 40); hl.n(0, 16, 'A4', 34); hl.n(16, 16, 'Bb3', 40); hl.n(16, 16, 'F4', 34)
    st = s.part('echo_shimmer', SYNTH_STR, 46, 64, 120); st.n(0, 32, 'D5', 26)
    return s


def victory():
    s = Song('victory', 100, bars=13, loop=False, tail=4.5, room=0.88, wet=0.26)
    tune = [[(major(p), d) for p, d in bar] for bar in A2[:4]] + [[('A5', 1), ('F#5', 1), ('E5', 1)], [('D5', 3)]]
    ch = ['D', 'A7', 'D', 'G', 'A7', 'D', 'D']
    vl = s.part('victory', VIOLIN, 104, 58, 50); melody(vl, 0, tune, vel=96)
    tpt = s.part('victory', TRUMPET, 80, 70, 50); melody(tpt, 0, tune, octave=-1, vel=70)
    st = s.part('victory', STRINGS, 86, 64, 60); pad(st, ch, lo='D3', hi='F#4', vel=60)
    hp = s.part('victory', HARP, 76, 40, 60)
    for i in range(7):
        for k, p in enumerate(voicing(ch[min(i, 6)], nn('D3'), nn('D6'), 9)): hp.n(i * 3 + k * 0.12, 2, p, 50)
    tp = s.part('victory', TIMPANI, 80, 64, 40); tp.n(0, 1, 'D2', 80); tp.n(15, 1, 'A1', 76); tp.n(18, 3, 'D2', 90)
    cb = s.part('victory', CONTRABASS, 80, 54, 40)
    for i, c in enumerate(ch): cb.n(i * 3, 3, root(c, 2), 70)
    fin = s.part('victory', BRASS, 80, 64, 60)
    for p in voicing('D', nn('D3'), nn('D5'), 5): fin.n(18, 6, p, 80)
    return s


def balcony():
    s = Song('balcony', 62, bars=16, rubato=0.1, room=0.95, wet=0.32, rev_seconds=3.6)
    ch = ['D', 'A', 'Bm', 'G', 'D', 'Em', 'A', 'D'] * 2
    tune = [[(major(p), d) for p, d in bar] for bar in A]
    ob = s.part('balcony_night', ENG_HORN, 92, 60, 70, human=0.015); melody(ob, 0, tune, octave=0, vel=70); melody(ob, 8, tune, octave=0, vel=64)
    hp = s.part('balcony_night', HARP, 80, 50, 80); arpeggio(hp, ch, lo='D3', vel=50, pattern=(0, 2, 4, 3, 5, 1))
    st = s.part('balcony_night', SLOW_STRINGS, 60, 64, 90); pad(st, ch, lo='D3', hi='D4', vel=38)
    return s


def credits():
    s = Song('credits', 88, bars=56, loop=False, tail=6.0, rubato=0.06, room=0.88, wet=0.26)
    tune = A + A2 + B + A2 + [[(major(p), d) for p, d in bar] for bar in A2]
    ch = CHORDS + ['D', 'A7', 'D', 'G', 'C', 'G', 'A7', 'D']
    pn = s.part('credits_song', PIANO, 84, 64, 60, human=0.012)
    melody(pn, 0, tune[:8], vel=70)
    for i, c in enumerate(ch[:8]): pn.n(i * 3, 3, root(c, 2), 54)
    vl = s.part('credits_song', VIOLIN, 100, 58, 60); melody(vl, 8, tune[8:], vel=90)
    vc = s.part('credits_song', CELLO, 86, 50, 60); melody(vc, 16, tune[16:24], octave=-1, vel=76)
    hp = s.part('credits_song', HARP, 76, 40, 60); arpeggio(hp, ch, lo='D3', vel=50)
    st = s.part('credits_song', STRINGS, 74, 64, 70); pad(st, ch[8:], start_bar=8, lo='F3', hi='D5', vel=44)
    cb = s.part('credits_song', PIZZ, 80, 50, 40); waltz_bass(cb, ch[8:], start_bar=8, octave=2, vel=74)
    fl = s.part('credits_song', FLUTE, 74, 76, 60); melody(fl, 40, tune[40:48], octave=1, vel=66)
    fin = s.part('credits_song', CHOIR, 70, 64, 90); pad(fin, ch[48:], start_bar=48, lo='A3', hi='A4', vel=50)
    end = s.part('credits_song', STRINGS, 80, 64, 70)
    for p in voicing('D', nn('D2'), nn('D5'), 7): end.n(56 * 3 - 3, 6, p, 64)
    return s


CUES = {'ballroom': ballroom, 'lastdance': lastdance, 'title': title, 'exterior': exterior, 'hall': hall, 'corridor': corridor,
        'boss': boss, 'echo': echo, 'victory': victory, 'balcony': balcony, 'credits': credits}

if __name__ == '__main__':
    want = sys.argv[1:] or list(CUES)
    for k in want:
        CUES[k]().render()
