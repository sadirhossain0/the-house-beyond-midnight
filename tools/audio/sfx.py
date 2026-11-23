"""Sound effects and ambience, synthesised from physical-ish models (impacts with resonant modes,
stick-slip friction, granular textures, filtered noise fields) plus a few sampled-instrument
stingers rendered through FluidSynth. Several variants of anything you hear often.

    python3 tools/audio/sfx.py
"""
import os, subprocess, sys
import numpy as np
import mido
from common import *

SFX = os.path.join(AUDIO, 'sfx')
AMB = os.path.join(AUDIO, 'amb')
SF2 = '/usr/share/sounds/sf2/FluidR3_GM.sf2'
R = np.random.default_rng(31121891)


def t(sec): return np.arange(int(sec * SR)) / SR
def noise(sec): return R.standard_normal(int(sec * SR)).astype(np.float32)
def env_exp(sec, decay): return np.exp(-t(sec) / decay)
def pad_to(a, n): return np.concatenate([a, np.zeros(n - len(a), np.float32)]) if len(a) < n else a[:n]


def pink(sec):
    w = noise(sec)
    b = [0.049922035, -0.095993537, 0.050612699, -0.004408786]; a = [1, -2.494956002, 2.017265875, -0.522189400]
    from scipy.signal import lfilter
    return lfilter(b, a, w).astype(np.float32) * 6


def brown(sec):
    w = np.cumsum(noise(sec)) * 0.02
    return highpass(w - np.mean(w), 15).astype(np.float32)


def modes(sec, freqs, decays, amps, excite=None):
    """Sum of decaying sinusoids (struck object)."""
    tt = t(sec); out = np.zeros_like(tt, dtype=np.float32)
    for f, d, a in zip(freqs, decays, amps):
        out += a * np.sin(2 * np.pi * f * tt + R.random() * 6) * np.exp(-tt / d)
    if excite is not None: out = np.convolve(out, excite)[:len(tt)]
    return out


def place(dst, src, at, gain=1.0):
    i = int(at * SR)
    n = min(len(src), len(dst) - i)
    if n > 0: dst[i:i + n] += src[:n] * gain
    return dst


def save(name, a, room=None, mono=True, peak_db=-3.0):
    a = np.asarray(a, np.float32)
    if room:
        a = reverb(a, wet=room[0], seconds=room[1], predelay=0.01)
    a = normalize(a, peak_db)
    a = fade(a, 0.002, 0.03)
    write_wav(os.path.join(SFX, name + '.wav'), a, mono=mono)


def save_amb(name, a, seconds):
    loop = int(seconds * SR)
    a = fold_loop(stereo(a), loop)
    a = gain_to_rms(a, -24)
    a = np.clip(a, -0.98, 0.98)
    w = os.path.join(TMP, 'amb_' + name + '.wav'); write_wav(w, a)
    to_ogg(w, os.path.join(AMB, name + '.ogg'), q=5)


def fs(notes, program, sec, vel=90, bank=0, gain=1.0):
    """Render a short phrase on a GM instrument. notes: [(beat_sec, dur_sec, midi)]."""
    mf = mido.MidiFile(ticks_per_beat=480); tr = mido.MidiTrack(); mf.tracks.append(tr)
    tr.append(mido.MetaMessage('set_tempo', tempo=500000, time=0))
    tr.append(mido.Message('program_change', program=program, channel=0, time=0))
    ev = []
    for (b, d, p) in notes:
        v = vel if not isinstance(p, tuple) else p[1]; p = p if not isinstance(p, tuple) else p[0]
        ev.append((int(b * 960), mido.Message('note_on', note=p, velocity=v, channel=0)))
        ev.append((int((b + d) * 960), mido.Message('note_off', note=p, velocity=0, channel=0)))
    ev.sort(key=lambda e: e[0]); last = 0
    for tt_, m in ev: m.time = tt_ - last; last = tt_; tr.append(m)
    mid = os.path.join(TMP, 'fs.mid'); wav = os.path.join(TMP, 'fs.wav')
    mf.save(mid)
    subprocess.run(['fluidsynth', '-ni', '-q', '-g', '0.6', '-r', str(SR), '-o', 'synth.reverb.active=0', '-F', wav, SF2, mid], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    a = read_wav(wav).mean(axis=1)
    return pad_to(a, int(sec * SR)) * gain


def N(name):
    from compose import nn
    return nn(name)


# ======================================================================== footsteps
def step(surface, i):
    s = 0.45; out = np.zeros(int(s * SR), np.float32)
    heel_t = 0.0; toe_t = 0.07 + R.random() * 0.03
    if surface in ('wood', 'parquet'):
        for at, g in ((heel_t, 1.0), (toe_t, 0.55)):
            body = modes(0.25, [95 + R.random() * 30, 210 + R.random() * 40, 480 + R.random() * 80], [0.05, 0.035, 0.02], [1.0, 0.6, 0.3])
            click = bandpass(noise(0.02), 1800, 5000) * env_exp(0.02, 0.004) * 0.6
            place(out, body * g, at); place(out, click * g, at)
        if surface == 'wood' and R.random() < 0.45:   # a floorboard complains
            tt = t(0.32); f = 520 + 140 * np.sin(2 * np.pi * 3.0 * tt) + R.random() * 200
            saw = 2 * ((np.cumsum(f) / SR) % 1.0) - 1
            cr = bandpass(saw * (0.5 + 0.5 * np.sin(2 * np.pi * 22 * tt) ** 2), 700, 2600) * np.sin(np.pi * tt / 0.32) * 0.18
            place(out, cr.astype(np.float32), 0.05)
    elif surface in ('stone', 'marble'):
        for at, g in ((heel_t, 1.0), (toe_t, 0.6)):
            click = highpass(noise(0.015), 2500) * env_exp(0.015, 0.0025)
            body = bandpass(noise(0.06), 350, 1100) * env_exp(0.06, 0.012) * 0.7
            place(out, click * g, at); place(out, body * g, at)
            if surface == 'marble':
                place(out, modes(0.3, [1250 + R.random() * 200, 2730 + R.random() * 300, 4100], [0.08, 0.05, 0.03], [0.1, 0.07, 0.04]) * g, at)
    elif surface in ('carpet', 'rug'):
        for at, g in ((heel_t, 1.0), (toe_t, 0.5)):
            th = lowpass(noise(0.09), 500) * env_exp(0.09, 0.02) * 1.6
            sc = bandpass(noise(0.12), 900, 3000) * np.sin(np.pi * t(0.12) / 0.12) * 0.06
            place(out, th * g, at); place(out, sc * g, at + 0.02)
    elif surface == 'gravel':
        for k in range(70):
            at = R.random() ** 1.6 * 0.22 + (0.0 if k < 40 else toe_t)
            g = bandpass(noise(0.012), 1500 + R.random() * 4000, 7000 + R.random() * 6000) * env_exp(0.012, 0.0015 + R.random() * 0.002)
            place(out, g * (0.3 + R.random() * 0.7), at)
        place(out, lowpass(noise(0.08), 400) * env_exp(0.08, 0.02) * 0.8, 0.0)
    elif surface in ('grass', 'leaves', 'ground'):
        place(out, lowpass(noise(0.1), 300) * env_exp(0.1, 0.025) * 1.0, 0)
        for k in range(45):
            at = 0.02 + R.random() * 0.2
            c = bandpass(noise(0.01), 2500, 9000) * env_exp(0.01, 0.0018)
            place(out, c * (0.15 + 0.35 * R.random()), at)
        if surface != 'grass':
            for k in range(20): place(out, highpass(noise(0.004), 4000) * R.random() * 0.6, 0.03 + R.random() * 0.25)
    elif surface == 'squeak':
        tt = t(0.22); f = 1400 + 900 * np.sin(np.pi * tt / 0.22) + (i * 120)
        sq = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.sin(np.pi * tt / 0.22) ** 0.5
        place(out, sq.astype(np.float32) * 0.5, 0.02)
    out = highpass(out, 60)
    return out


def footsteps():
    for surf in ['wood', 'parquet', 'stone', 'marble', 'carpet', 'gravel', 'grass', 'leaves', 'ground']:
        for i in range(1, 6):
            room = {'stone': (0.18, 1.2), 'marble': (0.22, 1.6), 'wood': (0.12, 0.9), 'parquet': (0.15, 1.4)}.get(surf)
            save(f'step_{surf}_{i}', step(surf, i), room=room, peak_db=-6)
    for i in range(1, 4): save(f'squeak_{i}', step('squeak', i), peak_db=-8)


# ======================================================================== impacts & mechanisms
def friction(sec, f0, wobble=0.3, rate=18, res=(300, 900, 2100), brightness=1.0):
    tt = t(sec)
    f = f0 * (1 + wobble * np.sin(2 * np.pi * 0.7 * tt + R.random() * 3) + 0.2 * np.cumsum(R.standard_normal(len(tt))) / SR)
    f = np.maximum(f, 30)
    phase = np.cumsum(f) / SR
    stick = (phase % 1.0) ** (3 + brightness)
    am = 0.55 + 0.45 * np.sin(2 * np.pi * rate * tt + 2 * np.sin(2 * np.pi * 0.9 * tt))
    x = (stick - stick.mean()) * am
    out = sum(bandpass(x, r * 0.8, r * 1.25) for r in res)
    return out.astype(np.float32)


def door_creak():
    for i in range(1, 4):
        sec = 1.6 + R.random() * 0.8
        c = friction(sec, 60 + R.random() * 40, 0.5, 14 + R.random() * 10, (380, 820, 1700, 3100))
        c *= np.sin(np.pi * t(sec) / sec) ** 0.6
        save(f'door_creak_{i}', c, room=(0.3, 2.5))


def door_slam():
    out = np.zeros(int(2.5 * SR), np.float32)
    place(out, modes(1.0, [55, 82, 140, 260], [0.35, 0.22, 0.12, 0.06], [1.0, 0.7, 0.5, 0.3]), 0)
    place(out, bandpass(noise(0.08), 200, 3000) * env_exp(0.08, 0.015), 0)
    for k in range(8): place(out, modes(0.15, [900 + R.random() * 1500], [0.03], [0.15]), 0.05 + k * 0.03 + R.random() * 0.02)
    save('door_slam', out, room=(0.55, 3.2), peak_db=-1)


def knock():
    out = np.zeros(int(1.6 * SR), np.float32)
    for k, at in enumerate((0.0, 0.28, 0.56)):
        place(out, modes(0.3, [140 + k * 3, 330, 720], [0.08, 0.05, 0.02], [1.0, 0.55, 0.25]) * (1.0 if k else 0.85), at)
        place(out, bandpass(noise(0.02), 800, 4000) * env_exp(0.02, 0.003) * 0.4, at)
    save('knock', out, room=(0.35, 2.4))


def grind(sec, lo=60, hi=900):
    x = lowpass(noise(sec), hi) * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 7 * t(sec)) * R.random(len(t(sec)))))
    x += lowpass(brown(sec), lo * 2) * 2
    return x.astype(np.float32)


def hidden_door():
    sec = 3.0; g = grind(sec) * np.sin(np.pi * t(sec) / sec) ** 0.5
    out = np.concatenate([g, np.zeros(int(1.0 * SR), np.float32)])
    place(out, modes(1.5, [70, 105], [0.4, 0.3], [1, 0.5]), sec - 0.1)
    sh = fs([(0.0, 1.5, N('A5')), (0.12, 1.5, N('D6')), (0.24, 1.5, N('F6'))], 8, 4.0, vel=70)
    out = pad_to(out, len(sh)); out += sh * 0.5
    save('hidden_door', out, room=(0.4, 2.6))


def chains_break():
    out = np.zeros(int(3.0 * SR), np.float32)
    for k in range(26):
        f0 = 1800 + R.random() * 3500
        place(out, modes(0.6, [f0, f0 * 2.76, f0 * 5.4], [0.25, 0.12, 0.06], [0.5, 0.3, 0.15]), R.random() ** 1.5 * 1.4)
    sw = fs([(0.0, 2.0, N('D5')), (0.0, 2.0, N('A5')), (0.05, 2.0, N('D6'))], 52, 3.0, vel=60)
    out += sw * 0.5
    save('chains_break', out, room=(0.45, 3.0))


def furniture_slide():
    for i in range(1, 4):
        sec = 0.9 + R.random() * 0.5
        c = friction(sec, 90 + R.random() * 60, 0.4, 30, (250, 600, 1400), 0.5) * np.sin(np.pi * t(sec) / sec) ** 0.7
        c += lowpass(noise(sec), 300) * 0.4 * np.sin(np.pi * t(sec) / sec)
        save(f'furniture_slide_{i}', c, room=(0.3, 2.0))


def cloth(sec, n=6):
    out = np.zeros(int(sec * SR), np.float32)
    for k in range(n):
        d = 0.08 + R.random() * 0.15
        b = bandpass(noise(d), 600, 5000) * np.sin(np.pi * t(d) / d) ** 2 * (0.4 + R.random() * 0.6)
        place(out, b, R.random() * (sec - d))
    return out


def coat_hang():
    out = cloth(1.0, 8)
    place(out, modes(0.4, [2300, 3900, 6100], [0.08, 0.05, 0.03], [0.4, 0.25, 0.12]), 0.55)
    save('coat_hang', out, room=(0.25, 1.4))


def tea_pour():
    sec = 2.6; tt = t(sec)
    fc = 500 + 900 * (tt / sec)
    x = noise(sec)
    out = np.zeros_like(x)
    for k in range(0, len(x), 2400):
        seg = x[k:k + 2400]; f = fc[min(k, len(fc) - 1)]
        out[k:k + len(seg)] = bandpass(seg, f * 0.7, f * 1.4)
    bubbles = np.zeros_like(x)
    for k in range(60):
        d = 0.03; f = 600 + R.random() * 900 + 700 * R.random()
        place(bubbles, np.sin(2 * np.pi * np.cumsum(f * (1 + 2 * t(d))) / SR) * env_exp(d, 0.008) * 0.2, R.random() * sec)
    out = out * np.sin(np.pi * tt / sec) ** 0.4 * 0.8 + bubbles
    place(out, modes(0.6, [2900, 5200, 7600], [0.2, 0.1, 0.05], [0.3, 0.15, 0.08]), sec - 0.4)
    save('tea_pour', out, room=(0.2, 1.4))


def eat():
    out = np.zeros(int(1.4 * SR), np.float32)
    for bite in range(3):
        for k in range(25):
            c = bandpass(noise(0.008), 1500, 7000) * env_exp(0.008, 0.0015)
            place(out, c * R.random(), bite * 0.38 + R.random() * 0.12)
        place(out, lowpass(noise(0.05), 300) * env_exp(0.05, 0.015) * 0.5, bite * 0.38)
    save('eat', out, room=(0.15, 1.0))


def paper():
    for name, n in (('paper', 1), ('pickup_paper', 1)):
        sec = 0.6
        out = np.zeros(int(sec * SR), np.float32)
        for k in range(50):
            d = 0.005 + R.random() * 0.02
            place(out, highpass(noise(d), 1500) * env_exp(d, d / 3) * R.random(), R.random() ** 0.8 * (sec - d))
        save(name, out, room=(0.15, 1.0))


def quill():
    sec = 1.4; tt = t(sec)
    x = bandpass(noise(sec), 2000, 8000) * (0.5 + 0.5 * np.sign(np.sin(2 * np.pi * (7 + 3 * np.sin(2 * np.pi * 0.8 * tt)) * tt)))
    x *= np.sin(np.pi * tt / sec) ** 0.3
    save('quill', x * 0.5, room=(0.15, 1.0))


def candle_out():
    sec = 0.7; tt = t(sec)
    puff = lowpass(noise(sec), 900) * np.exp(-tt / 0.12) * (1 - np.exp(-tt / 0.01))
    whoomp = np.sin(2 * np.pi * np.cumsum(90 * np.exp(-tt / 0.3)) / SR) * np.exp(-tt / 0.15) * 0.4
    sad = fs([(0.05, 0.6, N('F4')), (0.25, 0.8, N('D4'))], 8, 1.4, vel=55)
    out = pad_to(puff + whoomp, len(sad)) + sad * 0.35
    save('candle_out', out, room=(0.2, 1.4))


def lantern_light():
    out = np.zeros(int(1.6 * SR), np.float32)
    place(out, highpass(noise(0.12), 2000) * env_exp(0.12, 0.03), 0)
    tt = t(1.0)
    place(out, lowpass(noise(1.0), 1200) * (1 - np.exp(-tt / 0.05)) * np.exp(-tt / 0.4) * 1.2, 0.1)
    place(out, fs([(0, 1.2, N('D6')), (0.08, 1.2, N('A6'))], 8, 1.5, vel=60) * 0.3, 0.15)
    save('lantern_light', out, room=(0.2, 1.6))


def whoosh(sec, f0=300, f1=2500, q=1.0):
    tt = t(sec); x = noise(sec); out = np.zeros_like(x)
    for k in range(0, len(x), 1200):
        seg = x[k:k + 1200]; f = f0 + (f1 - f0) * np.sin(np.pi * min(k / len(x), 1.0)) ** 2
        out[k:k + len(seg)] = bandpass(seg, max(40, f * (1 - 0.4 / q)), f * (1 + 0.4 / q))
    return (out * np.sin(np.pi * tt / sec) ** 1.5).astype(np.float32)


def magic():
    out = whoosh(0.7, 400, 3000) * 0.8
    sh = fs([(0.0, 1.2, N('D6')), (0.06, 1.2, N('F#6')), (0.12, 1.2, N('A6')), (0.18, 1.4, N('D7'))], 8, 1.8, vel=80)
    save('flare', pad_to(out, len(sh)) * 0.8 + sh * 0.5, room=(0.3, 2.0))
    rv = fs([(0.0, 2.0, N('A5')), (0.15, 2.0, N('D6')), (0.3, 2.0, N('E6')), (0.45, 2.2, N('A6'))], 8, 3.0, vel=64)
    sw = whoosh(1.2, 200, 1800, 2.0)[::-1] * 0.4
    save('reveal', rv + pad_to(sw, len(rv)), room=(0.4, 3.0))
    save('mark_reveal', fs([(0.0, 1.5, N('D5')), (0.2, 1.5, N('A5')), (0.4, 2.0, N('D6'))], 8, 2.6, vel=72), room=(0.35, 2.6))
    save('observe', fs([(0, 1.6, N('A6')), (0.0, 1.6, N('E6'))], 92, 2.0, vel=60) + fs([(0, 1.0, N('A6'))], 9, 2.0, vel=50) * 0.4, room=(0.3, 2.0))
    save('star_lock', fs([(0, 1.4, N('D6')), (0, 1.4, N('A6'))], 9, 1.8, vel=86) + pad_to(modes(0.6, [80, 120], [0.2, 0.15], [0.6, 0.3]), int(1.8 * SR)), room=(0.3, 2.0))
    ga = whoosh(1.4, 150, 1400, 2.0) * 0.7
    ch = fs([(0.1, 1.8, N('D4')), (0.1, 1.8, N('A4')), (0.1, 1.8, N('F5'))], 53, 2.2, vel=60)
    save('ghost_appear', pad_to(ga, len(ch)) + ch * 0.6, room=(0.45, 3.0))
    save('dodge', whoosh(0.35, 500, 2200, 1.5) * 0.7, room=(0.1, 0.8))
    hs = whoosh(1.2, 200, 2600, 2.5)
    tt = t(1.2); whistle = np.sin(2 * np.pi * np.cumsum(900 + 500 * np.sin(np.pi * tt / 1.2)) / SR) * np.sin(np.pi * tt / 1.2) ** 2 * 0.15
    save('host_sweep', hs + whistle.astype(np.float32), room=(0.35, 2.4))
    bonk = modes(0.5, [160, 330, 2100, 3400], [0.12, 0.08, 0.2, 0.15], [1.0, 0.5, 0.25, 0.2])
    tweets = np.zeros(int(1.6 * SR), np.float32)
    for k in range(5):
        d = 0.08; tt2 = t(d)
        tweets = place(tweets, np.sin(2 * np.pi * np.cumsum(3200 + 1500 * tt2 / d) / SR) * np.sin(np.pi * tt2 / d) * 0.15, 0.35 + k * 0.2)
    save('host_stun', pad_to(bonk, len(tweets)) + tweets, room=(0.3, 2.0))


def watch():
    for i in range(1, 3):
        out = np.zeros(int(0.7 * SR), np.float32)
        for k, at in enumerate((0, 0.25, 0.5)):
            place(out, modes(0.05, [3400 + k * 100, 6100], [0.008, 0.004], [0.6, 0.3]), at)
        save(f'watch_tick_{i}', out, room=(0.1, 0.6), peak_db=-8)
    out = np.zeros(int(1.6 * SR), np.float32)
    place(out, modes(0.1, [2500, 4200], [0.015, 0.008], [0.8, 0.4]), 0)
    sp = friction(0.5, 900, 0.1, 60, (3000, 5000)) * env_exp(0.5, 0.15) * 0.3
    place(out, sp, 0.05)
    place(out, fs([(0, 1.0, N('A6')), (0.1, 1.0, N('D7'))], 10, 1.4, vel=70) * 0.6, 0.15)
    save('watch_open', out, room=(0.2, 1.6))
    sw = whoosh(2.2, 120, 2200, 2.0)[::-1] * 0.8
    bell = fs([(1.6, 3.0, N('D3')), (1.6, 3.0, N('A3'))], 14, 4.6, vel=96)
    rev = fs([(0, 2.0, N('D6')), (0.25, 2.0, N('C#6')), (0.5, 2.0, N('B5')), (0.75, 2.0, N('A5'))], 8, 4.6, vel=56)
    save('watch_shift', pad_to(sw, len(bell)) + bell * 0.8 + rev * 0.35, room=(0.45, 3.5), peak_db=-1)


def clock_chime():
    a = fs([(0, 6.0, N('D4')), (0, 6.0, N('D5')), (1.6, 5.0, N('A3'))], 14, 8.0, vel=110)
    hum = np.sin(2 * np.pi * 73.4 * t(8.0)) * env_exp(8.0, 3.0) * 0.08
    save('clock_chime', a + hum.astype(np.float32), room=(0.55, 4.5), peak_db=-1)
    save('chapter_card', fs([(0, 5.0, N('D2')), (0, 5.0, N('A2')), (0, 5.0, N('D3')), (0.4, 5.0, N('F4'))], 0, 6.0, vel=70), room=(0.5, 4.0))


def thunder():
    for i in range(1, 5):
        sec = 7.0 + R.random() * 3
        tt = t(sec)
        out = np.zeros(len(tt), np.float32)
        for k in range(5 + i):
            at = R.random() ** 2 * 2.5
            d = 1.5 + R.random() * 3
            seg = brown(d) * np.exp(-t(d) / (d * 0.35)) * (1 - np.exp(-t(d) / 0.06))
            place(out, lowpass(seg, 160 + R.random() * 200) * (0.5 + R.random()), at)
        crack = highpass(noise(0.4), 1500) * env_exp(0.4, 0.05) * (0.5 if i % 2 else 0.1)
        place(out, crack, 0)
        save(f'thunder_{i}', out, room=(0.3, 4.0), peak_db=-1, mono=False)


def instruments():
    phr = [(0, 0.5, N('A4')), (0.5, 1.0, N('D5')), (1.5, 0.5, N('C#5')), (2.0, 0.5, N('D5')), (2.5, 1.2, N('E5'))]
    for name, prog, oct_ in (('violin', 40, 0), ('cello', 42, -24), ('flute', 73, 12)):
        save(f'note_{name}', fs([(b, d, p + oct_) for b, d, p in phr], prog, 4.5, vel=96), room=(0.35, 2.4))
    save('note_wrong', fs([(0, 1.5, N('D4')), (0.0, 1.5, N('G#4')), (0.1, 1.4, N('C#5'))], 40, 2.6, vel=90), room=(0.3, 2.0))
    for i in range(1, 4):
        save(f'dance_step_{i}', fs([(0, 0.3, N(['D3', 'A3', 'F3'][i - 1]))], 45, 0.8, vel=100) + pad_to(modes(0.1, [180, 420], [0.03, 0.02], [0.4, 0.2]), int(0.8 * SR)), room=(0.3, 1.8))
    save('dance_miss', fs([(0, 0.6, N('C#3')), (0.15, 0.6, N('C3'))], 45, 1.2, vel=90), room=(0.25, 1.6))
    w = fs([(b * 0.67, d * 0.67, p) for b, d, p in [(0, 1, N('A4')), (1, 2, N('D5')), (3, 1, N('C#5')), (4, 1, N('D5')), (5, 1, N('E5')), (6, 2, N('F5')), (8, 1, N('E5')), (9, 2, N('D5'))]], 40, 9.0, vel=70)
    acc = fs([(b * 0.67, 0.4, p) for b, p in [(0, N('D3')), (1, N('A3')), (2, N('A3')), (3, N('A2')), (4, N('G3')), (5, N('G3')), (6, N('D3')), (7, N('A3')), (8, N('A3')), (9, N('D3')), (10, N('A3'))]], 0, 9.0, vel=60)
    save('waltz_distant', lowpass(w + acc * 0.7, 1400), room=(0.6, 4.0))


def host_hum():
    from voices import Voice
    v = Voice('host')
    phr = [('A3', 0.35), ('D4', 0.7), ('C#4', 0.35), ('D4', 0.35), ('E4', 0.35), ('F4', 0.7), ('E4', 0.35), ('D4', 1.0)]
    out = v.hum(phr)
    save('host_hum', out, room=(0.35, 2.6))


def ui():
    def cel(notes, prog=8, vel=70, sec=1.2): return fs(notes, prog, sec, vel=vel)
    save('ui_click', modes(0.08, [2400, 5200], [0.01, 0.005], [0.6, 0.3]) + highpass(noise(0.08), 3000) * env_exp(0.08, 0.004) * 0.2, peak_db=-12)
    save('ui_hover', modes(0.06, [3200], [0.008], [0.4]), peak_db=-20)
    save('ui_open', cel([(0, 0.6, N('D5')), (0.05, 0.6, N('A5'))], 46, 60), room=(0.25, 1.4), peak_db=-9)
    save('ui_close', cel([(0, 0.6, N('A5')), (0.05, 0.6, N('D5'))], 46, 60), room=(0.25, 1.4), peak_db=-10)
    save('ui_tool', modes(0.2, [1900, 3300, 5100], [0.05, 0.03, 0.02], [0.6, 0.3, 0.2]), room=(0.15, 1.0), peak_db=-10)
    save('ui_objective', cel([(0, 1.0, N('A4')), (0.12, 1.0, N('D5')), (0.24, 1.4, N('F5'))], 46, 70, 2.0), room=(0.3, 2.0), peak_db=-8)
    a = cel([(0, 1.2, N('D5')), (0.1, 1.2, N('F#5')), (0.2, 1.2, N('A5')), (0.32, 2.0, N('D6'))], 8, 80, 2.6)
    save('ui_achievement', a, room=(0.35, 2.4), peak_db=-6); save('achievement', a, room=(0.35, 2.4), peak_db=-6)
    c = cel([(0, 1.0, N('E6')), (0.1, 1.2, N('A6'))], 8, 70, 1.6)
    save('ui_clue', c, room=(0.3, 2.0), peak_db=-8); save('clue', c, room=(0.3, 2.0), peak_db=-8)
    d = cel([(0, 1.6, N('D4')), (0, 1.6, N('A4')), (0.15, 1.6, N('D5')), (0.3, 2.0, N('F#5'))], 46, 80, 2.6)
    save('ui_deduce', d, room=(0.35, 2.6), peak_db=-6); save('deduce', d, room=(0.35, 2.6), peak_db=-6)
    save('ui_unlock', cel([(0, 0.8, N('A5')), (0.08, 0.8, N('C#6')), (0.16, 1.2, N('E6'))], 9, 70, 1.6), room=(0.3, 2.0), peak_db=-8)
    save('ui_wrong', cel([(0, 0.5, N('D4')), (0.12, 0.7, N('C#4'))], 12, 70, 1.2), room=(0.2, 1.2), peak_db=-10)
    save('ui_start', cel([(0, 2.0, N('D3')), (0, 2.0, N('A3')), (0.3, 2.4, N('D4')), (0.6, 2.8, N('F4'))], 46, 80, 3.6), room=(0.45, 3.0), peak_db=-6)
    p = cel([(0, 0.6, N('A5')), (0.07, 0.8, N('D6'))], 8, 64, 1.2) + cloth(1.2, 3) * 0.2
    for i in (1, 2): save(f'pickup_{i}', p, room=(0.2, 1.4), peak_db=-8)


# ======================================================================== ambience beds
def ambience():
    L = 48.0
    # rain outside: wide, bright, with heavy drops on leaves and gravel
    a = np.zeros((int(L * SR) + SR, 2), np.float32)
    for c in range(2):
        a[:, c] = bandpass(pink(L + 1), 400, 9000) * 0.6 + lowpass(pink(L + 1), 500) * 0.4
    for k in range(int(L * 60)):
        d = 0.01; at = R.random() * L; c = R.integers(0, 2)
        drop = bandpass(noise(d), 2000, 9000) * env_exp(d, 0.002) * R.random() * 2.0
        i = int(at * SR); a[i:i + len(drop), c] += drop[:max(0, min(len(drop), a.shape[0] - i))]
    save_amb('rain_out', a, L)
    # rain heard indoors: muffled roar plus patter on window glass
    a2 = np.zeros((int(L * SR) + SR, 2), np.float32)
    for c in range(2): a2[:, c] = lowpass(pink(L + 1), 700) * 0.8
    for k in range(int(L * 14)):
        at = R.random() * L; c = R.integers(0, 2)
        tick = modes(0.03, [2800 + R.random() * 2000], [0.006], [0.5 + R.random()])
        i = int(at * SR); n = min(len(tick), a2.shape[0] - i); a2[i:i + n, c] += tick[:n] * 0.6
    save_amb('rain_in', a2, L)
    # wind: moaning resonances drifting in pitch, with gusts
    tt = t(L + 1)
    w = np.zeros((len(tt), 2), np.float32)
    gust = 0.5 + 0.5 * np.sin(2 * np.pi * tt / 11.0) * np.sin(2 * np.pi * tt / 4.3 + 1)
    for c in range(2):
        x = pink(L + 1); y = np.zeros_like(x)
        for k in range(0, len(x), 4800):
            seg = x[k:k + 4800]; f = 260 + 140 * np.sin(2 * np.pi * k / SR / 13.0 + c) + 90 * np.sin(2 * np.pi * k / SR / 5.0)
            y[k:k + len(seg)] = bandpass(seg, f * 0.85, f * 1.2)
        w[:, c] = y * (0.4 + gust) + lowpass(x, 200) * 0.3
    save_amb('wind', w, L)
    # room tone: an old house breathing
    rt = np.zeros((len(tt), 2), np.float32)
    for c in range(2): rt[:, c] = lowpass(pink(L + 1), 260) * 0.5 + np.sin(2 * np.pi * 50 * tt) * 0.004
    for k in range(5):
        at = R.random() * L
        cr = friction(0.7, 50 + R.random() * 30, 0.4, 9, (300, 700)) * np.sin(np.pi * t(0.7) / 0.7) * 0.12
        i = int(at * SR); n = min(len(cr), rt.shape[0] - i); rt[i:i + n, k % 2] += cr[:n]
    save_amb('room_tone', rt, L)
    # clock ticks (a hall clock that has started again)
    ct = np.zeros((int(L * SR) + SR, 2), np.float32)
    for k in range(int(L)):
        f = 2600 if k % 2 == 0 else 2100
        tk = modes(0.1, [f, f * 2.3, 600], [0.012, 0.006, 0.03], [0.6, 0.3, 0.3])
        i = int(k * SR); ct[i:i + len(tk), 0] += tk; ct[i:i + len(tk), 1] += tk * 0.8
    ct = reverb(ct, 0.3, 1.6)[:ct.shape[0]]
    save_amb('clock_ticks', ct, L)
    # fire: roar and crackle
    fi = np.zeros((len(tt), 2), np.float32)
    for c in range(2): fi[:, c] = lowpass(brown(L + 1), 300) * 2 + bandpass(pink(L + 1), 300, 1200) * 0.15
    for k in range(int(L * 9)):
        at = R.random() * L; d = 0.004 + R.random() * 0.01
        cr = highpass(noise(d), 1200) * env_exp(d, d / 3) * R.random() ** 2 * 3
        i = int(at * SR); n = min(len(cr), fi.shape[0] - i); fi[i:i + n, R.integers(0, 2)] += cr[:n]
    save_amb('fire', fi, L)
    # drips: water finding its way through the ceiling
    dr = np.zeros((int(L * SR) + SR, 2), np.float32)
    for k in range(int(L * 0.8)):
        at = R.random() * L; d = 0.12; tt2 = t(d)
        f = 900 + R.random() * 900
        plink = np.sin(2 * np.pi * np.cumsum(f * (1 + 1.4 * tt2 / d)) / SR) * np.exp(-tt2 / 0.025)
        i = int(at * SR); dr[i:i + len(plink), R.integers(0, 2)] += plink * (0.3 + R.random() * 0.5)
    dr = reverb(dr, 0.5, 2.5)[:dr.shape[0]]
    save_amb('drips', dr, L)
    # night garden: crickets, a distant owl, leaves
    ng = np.zeros((len(tt), 2), np.float32)
    for c in range(2): ng[:, c] = bandpass(pink(L + 1), 300, 3000) * 0.1
    for ci in range(6):
        f = 4300 + R.random() * 700; rate = 14 + R.random() * 6; ph = R.random() * 6
        chirp = np.sin(2 * np.pi * f * tt) * (np.sin(2 * np.pi * rate * tt + ph) > 0.3) * (np.sin(2 * np.pi * tt / (2.5 + R.random() * 2) + ph) > 0)
        ng[:, ci % 2] += chirp.astype(np.float32) * 0.03
    for k in range(3):
        at = 6 + k * 15 + R.random() * 4
        for j, d in enumerate((0.35, 0.18, 0.5)):
            tt2 = t(d); hoot = np.sin(2 * np.pi * (380 - 30 * tt2 / d) * tt2) * np.sin(np.pi * tt2 / d) ** 2 * 0.1
            i = int((at + j * 0.45) * SR); n = min(len(hoot), ng.shape[0] - i); ng[i:i + n, 0] += hoot[:n]; ng[i:i + n, 1] += hoot[:n] * 0.6
    ng = reverb(ng, 0.4, 3.0)[:ng.shape[0]]
    save_amb('night_garden', ng, L)


if __name__ == '__main__':
    sys.path.insert(0, os.path.dirname(__file__))
    jobs = sys.argv[1:] or ['footsteps', 'door_creak', 'door_slam', 'knock', 'hidden_door', 'chains_break', 'furniture_slide', 'coat_hang', 'tea_pour', 'eat',
                            'paper', 'quill', 'candle_out', 'lantern_light', 'magic', 'watch', 'clock_chime', 'thunder', 'instruments', 'ui', 'host_hum', 'ambience']
    for j in jobs:
        globals()[j]()
        print('done', j)
