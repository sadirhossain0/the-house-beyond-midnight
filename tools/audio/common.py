"""Shared audio helpers: WAV I/O, filters, reverb, loudness, OGG encoding."""
import os, subprocess, wave
import numpy as np
from scipy import signal

SR = 48000
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
AUDIO = os.path.join(ROOT, 'assets', 'audio')
TMP = os.environ.get('HBM_AUDIO_TMP', '/tmp/hbm_audio')
os.makedirs(TMP, exist_ok=True)
rng = np.random.default_rng(1891)


def read_wav(path):
    with wave.open(path, 'rb') as w:
        n = w.getnframes(); ch = w.getnchannels(); sw = w.getsampwidth(); sr = w.getframerate()
        raw = w.readframes(n)
    if sw == 2:
        a = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
    elif sw == 4:
        a = np.frombuffer(raw, dtype=np.int32).astype(np.float32) / 2147483648.0
    else:
        raise ValueError('unsupported sample width')
    a = a.reshape(-1, ch)
    if ch == 1:
        a = np.repeat(a, 2, axis=1)
    if sr != SR:
        a = signal.resample_poly(a, SR, sr, axis=0)
    return a


def write_wav(path, a, mono=False):
    a = np.asarray(a, dtype=np.float32)
    if a.ndim == 1:
        a = a[:, None]
    if mono and a.shape[1] > 1:
        a = a.mean(axis=1, keepdims=True)
    a = np.clip(a, -1.0, 1.0)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(a.shape[1]); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((a * 32767.0).astype(np.int16).tobytes())


def to_ogg(wav_path, ogg_path, q=6):
    os.makedirs(os.path.dirname(ogg_path), exist_ok=True)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', wav_path, '-c:a', 'libvorbis', '-q:a', str(q), ogg_path], check=True)


def stereo(a):
    return a if a.ndim == 2 else np.stack([a, a], axis=1)


def lowpass(a, hz, order=2):
    sos = signal.butter(order, hz, 'low', fs=SR, output='sos')
    return signal.sosfilt(sos, a, axis=0)


def highpass(a, hz, order=2):
    sos = signal.butter(order, hz, 'high', fs=SR, output='sos')
    return signal.sosfilt(sos, a, axis=0)


def bandpass(a, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], 'band', fs=SR, output='sos')
    return signal.sosfilt(sos, a, axis=0)


def peak(a, f0, q, gain_db):
    """Simple peaking EQ (RBJ biquad)."""
    A = 10 ** (gain_db / 40); w0 = 2 * np.pi * f0 / SR; al = np.sin(w0) / (2 * q)
    b = [1 + al * A, -2 * np.cos(w0), 1 - al * A]; aa = [1 + al / A, -2 * np.cos(w0), 1 - al / A]
    return signal.lfilter(np.array(b) / aa[0], np.array(aa) / aa[0], a, axis=0)


def impulse(seconds=2.2, predelay=0.02, damp=6000.0, width=1.0, early=True, seed=7):
    """A synthetic hall: early reflections plus a decorrelated, darkening exponential tail."""
    r = np.random.default_rng(seed)
    n = int(seconds * SR)
    t = np.arange(n) / SR
    env = np.exp(-6.9 * t / seconds)
    ir = np.zeros((n, 2), np.float32)
    for c in range(2):
        noise = r.standard_normal(n) * env
        # darken over time: blend a low-passed copy in as the tail ages
        lp = lowpass(noise, damp * 0.35)
        mix = np.clip(t / seconds * 1.6, 0, 1)
        ir[:, c] = noise * (1 - mix) + lp * mix
    if width < 1.0:
        m = ir.mean(axis=1, keepdims=True); ir = m + (ir - m) * width
    pd = int(predelay * SR)
    ir = np.concatenate([np.zeros((pd, 2), np.float32), ir])
    if early:
        for d, g in ((0.011, 0.5), (0.017, 0.38), (0.023, 0.3), (0.031, 0.22), (0.043, 0.16)):
            k = int(d * SR) + pd
            ir[k, 0] += g * (1.0 if r.random() > 0.5 else -1.0)
            ir[k + int(0.0007 * SR), 1] += g * (1.0 if r.random() > 0.5 else -1.0)
    ir /= np.sqrt((ir ** 2).sum() / 2)
    return ir


def reverb(a, wet=0.25, seconds=2.2, predelay=0.02, damp=6000.0, seed=7):
    a = stereo(a)
    ir = impulse(seconds, predelay, damp, seed=seed)
    out = np.zeros((a.shape[0] + ir.shape[0] - 1, 2), np.float32)
    for c in range(2):
        out[:, c] = signal.fftconvolve(a[:, c], ir[:, c])
    out[:a.shape[0]] *= 1.0
    dry = np.zeros_like(out); dry[:a.shape[0]] = a
    return dry * (1 - wet * 0.5) + out * wet * 0.35


def normalize(a, peak_db=-1.0):
    m = np.max(np.abs(a)) + 1e-9
    return a * (10 ** (peak_db / 20) / m)


def rms_db(a):
    return 20 * np.log10(np.sqrt(np.mean(a ** 2)) + 1e-9)


def gain_to_rms(a, target_db):
    return a * 10 ** ((target_db - rms_db(a)) / 20)


def fade(a, fin=0.005, fout=0.02):
    a = a.copy(); n = a.shape[0]
    i = min(int(fin * SR), n); o = min(int(fout * SR), n)
    if i > 0: a[:i] *= np.linspace(0, 1, i)[:, None] if a.ndim == 2 else np.linspace(0, 1, i)
    if o > 0: a[n - o:] *= np.linspace(1, 0, o)[:, None] if a.ndim == 2 else np.linspace(1, 0, o)
    return a


def fold_loop(a, loop_len):
    """Make a seamless loop: the reverb tail past the loop point is added back onto the start."""
    a = stereo(a)
    if a.shape[0] < loop_len:
        a = np.concatenate([a, np.zeros((loop_len - a.shape[0], 2), np.float32)])
    head = a[:loop_len].copy()
    tail = a[loop_len:]
    k = min(tail.shape[0], loop_len)
    head[:k] += tail[:k]
    return head


def soft_clip(a, drive=1.0):
    return np.tanh(a * drive) / np.tanh(drive)
