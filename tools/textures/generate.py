"""Bespoke textures for The House Beyond Midnight (all original, generated procedurally).

Writes PNGs to assets/textures/generated/. Everything is drawn at 2x and downsampled for clean edges.
Run: python3 tools/textures/generate.py
"""
import math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

ROOT = os.path.join(os.path.dirname(__file__), '..', '..')
OUT = os.path.join(ROOT, 'assets', 'textures', 'generated')
FONTS = os.path.join(ROOT, 'assets', 'fonts')
os.makedirs(OUT, exist_ok=True)

def font(name, size):
    return ImageFont.truetype(os.path.join(FONTS, name), size)

def bez(p0, p1, p2, p3=None, n=24):
    pts = []
    for i in range(n + 1):
        t = i / n
        if p3 is None:
            x = (1-t)**2*p0[0] + 2*(1-t)*t*p1[0] + t*t*p2[0]; y = (1-t)**2*p0[1] + 2*(1-t)*t*p1[1] + t*t*p2[1]
        else:
            x = (1-t)**3*p0[0] + 3*(1-t)**2*t*p1[0] + 3*(1-t)*t*t*p2[0] + t**3*p3[0]
            y = (1-t)**3*p0[1] + 3*(1-t)**2*t*p1[1] + 3*(1-t)*t*t*p2[1] + t**3*p3[1]
        pts.append((x, y))
    return pts

def fbm(size, scale=4, octaves=5, seed=1):
    """Tileable fractal value noise in [0,1]."""
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size), np.float32); amp = 1.0; tot = 0
    for o in range(octaves):
        n = scale * (2 ** o)
        grid = rng.random((n, n)).astype(np.float32)
        img = Image.fromarray((grid * 255).astype(np.uint8)).resize((size, size), Image.BICUBIC)
        # make tileable by wrapping: resize of a tiled 3x3 then crop centre
        tiled = np.tile(grid, (3, 3))
        timg = Image.fromarray((tiled * 255).astype(np.uint8)).resize((size * 3, size * 3), Image.BICUBIC)
        a = np.asarray(timg, np.float32)[size:size * 2, size:size * 2] / 255.0
        out += a * amp; tot += amp; amp *= 0.5
    return out / tot

def save(img, name, size=None):
    if size: img = img.resize((size, size) if isinstance(size, int) else size, Image.LANCZOS)
    img.save(os.path.join(OUT, name + '.png'), optimize=True)
    print('wrote', name)

# --------------------------------------------------------------------------------- damask masks
def taper(d, pts, w0, w1, fill):
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        w = w0 + (w1 - w0) * i / max(1, n - 1)
        d.ellipse([x - w, y - w, x + w, y + w], fill=fill)

def leaf(d, x, y, length, width, ang, fill):
    pts = []
    for t in np.linspace(0, 1, 24):
        pts.append((t, math.sin(t * math.pi) * width * 0.5))
    pts += [(t, -math.sin(t * math.pi) * width * 0.5) for t, _ in reversed(pts)]
    out = [(x + (px * length) * math.cos(ang) - py * math.sin(ang), y + (px * length) * math.sin(ang) + py * math.cos(ang)) for px, py in pts]
    d.polygon(out, fill=fill)

def damask_motif(d, cx, cy, w, h, fill, rich=True):
    """A symmetric damask: central palmette, mirrored C-scrolls with acanthus leaves, a pomegranate below."""
    sw = w * 0.018
    for s in (-1, 1):
        P = lambda x, y: (cx + s * x * w, cy + y * h)
        # big outer scroll sweeping up and curling in
        taper(d, bez(P(0.02, 0.36), P(0.42, 0.34), P(0.48, -0.18), P(0.2, -0.3), n=60), sw * 1.4, sw * 0.6, fill)
        taper(d, bez(P(0.2, -0.3), P(0.08, -0.34), P(0.08, -0.18), P(0.17, -0.17), n=24), sw * 0.6, sw * 0.9, fill)
        ex, ey = P(0.17, -0.17); d.ellipse([ex - sw * 1.8, ey - sw * 1.8, ex + sw * 1.8, ey + sw * 1.8], fill=fill)
        # inner scroll
        taper(d, bez(P(0.04, 0.18), P(0.26, 0.2), P(0.3, -0.02), P(0.16, -0.06), n=40), sw * 1.0, sw * 0.5, fill)
        # acanthus leaves along the outer scroll
        for t, ln, ang in ((0.18, 0.13, -0.6), (0.38, 0.12, -1.2), (0.58, 0.1, -1.9), (0.3, 0.09, 0.4)):
            px, py = bez(P(0.02, 0.36), P(0.42, 0.34), P(0.48, -0.18), P(0.2, -0.3), n=100)[int(t * 100)]
            leaf(d, px, py, w * ln, w * ln * 0.42, ang if s > 0 else math.pi - ang, fill)
        # small fronds sprouting from the top
        taper(d, bez(P(0.0, -0.36), P(0.1, -0.42), P(0.18, -0.46), P(0.24, -0.43), n=24), sw * 0.8, sw * 0.3, fill)
        leaf(d, *P(0.24, -0.43), w * 0.07, w * 0.03, -0.3 if s > 0 else math.pi + 0.3, fill)
        # tendrils at the base
        taper(d, bez(P(0.02, 0.4), P(0.15, 0.44), P(0.22, 0.4), P(0.2, 0.34), n=24), sw * 0.7, sw * 0.3, fill)
    # central palmette
    pal = bez((cx, cy - h * 0.46), (cx + w * 0.11, cy - h * 0.3), (cx + w * 0.09, cy - h * 0.05), (cx, cy + h * 0.02), n=40)
    pal += [(2 * cx - x, y) for x, y in reversed(pal)]
    d.polygon(pal, fill=fill)
    inner = [(cx + (x - cx) * 0.55, cy - h * 0.2 + (y - cy + h * 0.2) * 0.55) for x, y in pal]
    d.polygon(inner, fill=0)
    for k in range(-2, 3):
        d.line([(cx, cy - h * 0.02), (cx + k * w * 0.03, cy - h * 0.3)], fill=fill, width=max(2, int(sw * 0.5)))
    # pomegranate below
    d.ellipse([cx - w * 0.06, cy + h * 0.06, cx + w * 0.06, cy + h * 0.2], fill=fill)
    d.ellipse([cx - w * 0.03, cy + h * 0.1, cx + w * 0.03, cy + h * 0.16], fill=0)
    d.polygon([(cx - w * 0.03, cy + h * 0.065), (cx, cy + h * 0.03), (cx + w * 0.03, cy + h * 0.065)], fill=fill)

def ogee(d, S, cols, rows, fill, width):
    w, h = S / cols, S / rows
    for i in range(-1, cols + 2):
        for j in range(-1, rows + 2):
            x0, y0 = i * w, j * h
            for s in (-1, 1):
                d.line(bez((x0, y0), (x0 + s * w * 0.42, y0 + h * 0.18), (x0 + s * w * 0.08, y0 + h * 0.36), (x0 + s * w * 0.5, y0 + h * 0.5), n=40), fill=fill, width=width)
                d.line(bez((x0 + s * w * 0.5, y0 + h * 0.5), (x0 + s * w * 0.92, y0 + h * 0.64), (x0 + s * w * 0.58, y0 + h * 0.82), (x0, y0 + h), n=40), fill=fill, width=width)

def damask(name, variant):
    S = 2048 * 2
    img = Image.new('L', (S, S), 0); d = ImageDraw.Draw(img)
    cols, rows = 2, 2
    w, h = S / cols, S / rows
    ogee(d, S, cols, rows, 150, int(S * 0.004))
    for i in range(-1, cols + 1):
        for j in range(-1, rows + 1):
            ox = i * w + w / 2; oy = j * h + h / 2
            scale = {'a': 0.88, 'b': 0.8, 'c': 0.72}[variant]
            damask_motif(d, ox, oy, w * scale, h * scale, 255)
            # small sprig in the lattice gaps
            gx, gy = i * w, j * h + h / 2
            for k in range(6):
                a = k / 6 * math.tau
                leaf(d, gx, gy, w * 0.045, w * 0.018, a, 210)
            d.ellipse([gx - w * 0.012, gy - w * 0.012, gx + w * 0.012, gy + w * 0.012], fill=255)
            if variant == 'b':
                for k in range(3): d.ellipse([ox - w * 0.38 + k * 8, oy + h * 0.42, ox - w * 0.36 + k * 8, oy + h * 0.44], fill=200)
    img = img.filter(ImageFilter.GaussianBlur(1.5))
    n = fbm(S // 4, 6, 4, seed=sum(map(ord, name)))
    n = Image.fromarray((np.clip(0.72 + n * 0.5, 0, 1) * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC)
    img = ImageChops.multiply(img, n)
    rgba = Image.merge('RGBA', (img, img, img, Image.new('L', (S, S), 255)))
    save(rgba, name, 2048)

# --------------------------------------------------------------------------------- rugs & runner
def rug(name, field, border, accent, seed):
    S = 2048 * 2; r = random.Random(seed)
    img = Image.new('RGB', (S, S), field); d = ImageDraw.Draw(img)
    b = int(S * 0.09)
    for rect in ((0, 0, S, b), (0, S - b, S, S), (0, 0, b, S), (S - b, 0, S, S)): d.rectangle(rect, fill=border)
    lw = S // 160
    d.rectangle((b * 0.3, b * 0.3, S - b * 0.3, S - b * 0.3), outline=accent, width=lw)
    d.rectangle((b, b, S - b, S - b), outline=accent, width=lw)
    n = 14
    for i in range(n):
        t = (i + 0.5) / n
        for px, py in ((t * S, b / 2), (t * S, S - b / 2), (b / 2, t * S), (S - b / 2, t * S)):
            d.polygon([(px, py - b * 0.28), (px + b * 0.22, py), (px, py + b * 0.28), (px - b * 0.22, py)], fill=accent)
            d.polygon([(px, py - b * 0.14), (px + b * 0.1, py), (px, py + b * 0.14), (px - b * 0.1, py)], fill=border)
    cx = cy = S / 2
    for sy in (-1, 1):  # pendants above and below the medallion
        py = cy + sy * S * 0.36
        d.polygon([(cx, py - sy * S * 0.06), (cx + S * 0.05, py), (cx, py + sy * S * 0.05), (cx - S * 0.05, py)], fill=accent)
        d.ellipse([cx - S * 0.02, py - S * 0.02, cx + S * 0.02, py + S * 0.02], fill=border)
    for ring in range(5, 0, -1):
        R = S * 0.062 * ring
        pts = [(cx + math.cos(a) * R * (1 + 0.12 * math.cos(a * 8)), cy + math.sin(a) * R * 0.75 * (1 + 0.12 * math.cos(a * 8))) for a in np.linspace(0, math.tau, 200)]
        d.polygon(pts, fill=accent if ring % 2 else border)
    # field lattice of small rosettes (drawn under the medallion afterwards)
    step = S * 0.07
    for gx in np.arange(b * 1.5, S - b * 1.4, step):
        for gy in np.arange(b * 1.5, S - b * 1.4, step):
            if math.hypot(gx - cx, (gy - cy) / 0.75) < S * 0.34: continue
            c = accent if int(gx / step + gy / step) % 2 else border
            for p in range(4):
                a = p * math.tau / 4 + math.pi / 4
                d.ellipse([gx + math.cos(a) * S * 0.01 - S * 0.007, gy + math.sin(a) * S * 0.01 - S * 0.007, gx + math.cos(a) * S * 0.01 + S * 0.007, gy + math.sin(a) * S * 0.01 + S * 0.007], fill=c)
            d.ellipse([gx - S * 0.004, gy - S * 0.004, gx + S * 0.004, gy + S * 0.004], fill=(230, 210, 170))
    # corner spandrels (quarter medallions)
    for qx, qy in ((b, b), (S - b, b), (b, S - b), (S - b, S - b)):
        for ring in range(3, 0, -1):
            R = S * 0.032 * ring
            d.ellipse([qx - R, qy - R * 0.8, qx + R, qy + R * 0.8], fill=accent if ring % 2 else border)
    # guard stripes
    for k, col in ((0.5, accent), (1.0, border)):
        o = b + S * 0.012 * k
        d.rectangle((o, o, S - o, S - o), outline=col, width=S // 300)
    arr = np.asarray(img, np.float32) / 255.0
    weave = fbm(S // 2, 64, 2, seed)  # fine knot texture
    weave = np.asarray(Image.fromarray((weave * 255).astype(np.uint8)).resize((S, S)), np.float32)[..., None] / 255
    wear = fbm(S // 4, 3, 5, seed + 1)
    wear = np.asarray(Image.fromarray((wear * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC), np.float32)[..., None] / 255
    arr = arr * (0.82 + 0.18 * weave) * (0.7 + 0.3 * wear)
    # threadbare centre where people walked
    yy, xx = np.mgrid[0:S, 0:S] / S
    path = np.exp(-((xx - 0.5) ** 2) / 0.02)[..., None]
    arr = arr * (1 - path * 0.18 * wear) + path * 0.06 * wear
    save(Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)), name, 2048)

def runner():
    S = 1024 * 2
    img = Image.new('RGB', (S, S), (90, 20, 24)); d = ImageDraw.Draw(img)
    d.rectangle((S * 0.06, 0, S * 0.09, S), fill=(194, 154, 72)); d.rectangle((S * 0.91, 0, S * 0.94, S), fill=(194, 154, 72))
    d.rectangle((0, 0, S * 0.05, S), fill=(31, 42, 54)); d.rectangle((S * 0.95, 0, S, S), fill=(31, 42, 54))
    for i in range(4):
        cy = (i + 0.5) * S / 4; cx = S / 2
        d.polygon([(cx, cy - S * 0.1), (cx + S * 0.2, cy), (cx, cy + S * 0.1), (cx - S * 0.2, cy)], fill=(194, 154, 72))
        d.polygon([(cx, cy - S * 0.06), (cx + S * 0.12, cy), (cx, cy + S * 0.06), (cx - S * 0.12, cy)], fill=(31, 42, 54))
        d.ellipse([cx - S * 0.02, cy - S * 0.02, cx + S * 0.02, cy + S * 0.02], fill=(170, 40, 40))
    arr = np.asarray(img, np.float32) / 255
    w = fbm(S // 4, 4, 5, 9); w = np.asarray(Image.fromarray((w * 255).astype(np.uint8)).resize((S, S), Image.BICUBIC), np.float32)[..., None] / 255
    arr *= 0.62 + 0.38 * w
    save(Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)), 'runner', 1024)

def star_inlay():
    S = 2048
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
    c = S / 2
    d.ellipse([c - S * 0.48, c - S * 0.48, c + S * 0.48, c + S * 0.48], fill=(42, 23, 11, 255))
    for R, w in ((0.47, 0.012), (0.43, 0.006)):
        d.ellipse([c - S * R, c - S * R, c + S * R, c + S * R], outline=(201, 161, 89, 255), width=int(S * w))
    for i in range(16):
        a = i / 16 * math.tau; long = i % 2 == 0
        R = S * (0.42 if long else 0.28); w = 0.14 if long else 0.1
        for side in (0, 1):
            col = ((226, 196, 138) if long else (122, 74, 34)) if side else ((166, 116, 60) if long else (74, 42, 18))
            a2 = a + (w if side else -w)
            d.polygon([(c, c), (c + math.cos(a) * R, c + math.sin(a) * R), (c + math.cos(a2) * R * 0.3, c + math.sin(a2) * R * 0.3)], fill=col + (255,))
    d.ellipse([c - S * 0.035, c - S * 0.035, c + S * 0.035, c + S * 0.035], fill=(201, 161, 89, 255))
    save(img, 'star_inlay', 1024)

def mural():
    S = 2048; rng = random.Random(4)
    yy, xx = np.mgrid[0:S, 0:S] / S
    r = np.hypot(xx - 0.5, yy - 0.5)
    base = np.stack([0.23 - r * 0.2, 0.3 - r * 0.25, 0.48 - r * 0.33], -1).clip(0.03, 1)
    clouds = fbm(S, 3, 6, 21)[..., None]
    arr = base + np.clip(clouds - 0.45, 0, 1) * np.array([0.5, 0.55, 0.7]) * 0.9
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)); d = ImageDraw.Draw(img)
    for _ in range(500):
        x, y, s = rng.random() * S, rng.random() * S, rng.random() * 2.5 + 0.6
        d.ellipse([x - s, y - s, x + s, y + s], fill=(255, 240, 200))
    pts = [(0.4, 0.45), (0.45, 0.38), (0.5, 0.44), (0.55, 0.36), (0.6, 0.45), (0.57, 0.5), (0.43, 0.5)]
    P = [(x * S, y * S) for x, y in pts]
    d.line(P + [P[0]], fill=(255, 220, 140), width=3)
    for x, y in P: d.ellipse([x - 7, y - 7, x + 7, y + 7], fill=(255, 233, 176))
    # gilt rim
    d.ellipse([S * 0.02, S * 0.02, S * 0.98, S * 0.98], outline=(200, 160, 80), width=18)
    save(img.filter(ImageFilter.GaussianBlur(0.6)), 'mural', 2048)

# --------------------------------------------------------------------------------- clock faces
def clock_face(name, dark=False, roman=True, label='', hour=11, minute=59, size=1024):
    S = size * 2
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
    c = S / 2; R = S * 0.48
    yy, xx = np.mgrid[0:S, 0:S]
    rr = np.hypot(xx - c, yy - c) / R
    face = np.array([32, 38, 31] if dark else [241, 232, 210], np.float32)
    edge = np.array([13, 16, 12] if dark else [205, 191, 156], np.float32)
    col = face * (1 - rr[..., None] ** 2) + edge * rr[..., None] ** 2
    alpha = (rr <= 1).astype(np.float32) * 255
    img = Image.fromarray(np.dstack([col, alpha]).clip(0, 255).astype(np.uint8)); d = ImageDraw.Draw(img)
    ink = (169, 232, 194) if dark else (42, 29, 16)
    d.ellipse([c - R * 0.95, c - R * 0.95, c + R * 0.95, c + R * 0.95], outline=ink, width=int(S * 0.008))
    d.ellipse([c - R * 0.76, c - R * 0.76, c + R * 0.76, c + R * 0.76], outline=ink, width=int(S * 0.003))
    for i in range(60):
        a = i / 60 * math.tau; l = 0.08 if i % 5 == 0 else 0.035
        d.line([(c + math.sin(a) * R * 0.93, c - math.cos(a) * R * 0.93), (c + math.sin(a) * R * (0.93 - l), c - math.cos(a) * R * (0.93 - l))], fill=ink, width=int(S * (0.008 if i % 5 == 0 else 0.003)))
    nums = ['XII', 'I', 'II', 'III', 'IIII', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI'] if roman else [str(i) for i in [12] + list(range(1, 12))]
    f = font('Cinzel.ttf', int(S * 0.085))
    for i, t in enumerate(nums):
        a = i / 12 * math.tau
        layer = Image.new('RGBA', (int(S * 0.3), int(S * 0.15)), (0, 0, 0, 0)); ld = ImageDraw.Draw(layer)
        ld.text((layer.width / 2, layer.height / 2), t, font=f, fill=ink, anchor='mm')
        layer = layer.rotate(-math.degrees(a), resample=Image.BICUBIC, expand=True)
        x = c + math.sin(a) * R * 0.63 - layer.width / 2; y = c - math.cos(a) * R * 0.63 - layer.height / 2
        img.alpha_composite(layer, (int(x), int(y)))
    if label:
        d.text((c, c + R * 0.33), label, font=font('Alegreya-Italic.ttf', int(S * 0.04)), fill=ink, anchor='mm')
    def hand(ang, length, width):
        pts = [(-width, R * 0.1), (-width * 0.5, -length * 0.75), (-width * 1.6, -length * 0.8), (0, -length), (width * 1.6, -length * 0.8), (width * 0.5, -length * 0.75), (width, R * 0.1)]
        rot = [(c + x * math.cos(ang) - y * math.sin(ang), c + x * math.sin(ang) + y * math.cos(ang)) for x, y in pts]
        d.polygon(rot, fill=(217, 251, 229) if dark else (26, 18, 10))
    hand(((hour % 12) + minute / 60) / 12 * math.tau, R * 0.48, S * 0.014)
    hand(minute / 60 * math.tau, R * 0.72, S * 0.009)
    d.ellipse([c - S * 0.02, c - S * 0.02, c + S * 0.02, c + S * 0.02], fill=(26, 18, 10))
    save(img, name, size)

# --------------------------------------------------------------------------------- portraits
def portrait(name, spec, w=768, h=1024):
    W, H = w * 2, h * 2; r = random.Random(spec.get('seed', 5))
    yy, xx = np.mgrid[0:H, 0:W]
    bgc = np.array(spec.get('bg', (75, 58, 40)), np.float32)
    rad = np.hypot((xx - W * 0.5) / W, (yy - H * 0.35) / H)
    arr = bgc * np.clip(1.2 - rad * 1.6, 0.15, 1)[..., None]
    img = Image.fromarray(arr.clip(0, 255).astype(np.uint8)); d = ImageDraw.Draw(img)
    drape = spec.get('drape', (90, 20, 25))
    d.polygon([(0, 0)] + bez((0, 0), (W * 0.3, H * 0.4), (W * 0.1, H)) + [(0, H)], fill=drape)
    d.polygon(bez((W * 0.08, H), (W * 0.15, H * 0.62), (W * 0.5, H * 0.6)) + bez((W * 0.5, H * 0.6), (W * 0.85, H * 0.62), (W * 0.92, H)), fill=spec.get('coat', (29, 26, 34)))
    skin = spec.get('skin', (217, 179, 148)); hair = spec.get('hair', (42, 26, 16))
    if spec.get('female'):
        d.ellipse([W * 0.32, H * 0.63, W * 0.68, H * 0.71], fill=spec.get('trim', (201, 161, 89)))
    else:
        d.polygon([(W * 0.42, H * 0.6), (W * 0.5, H * 0.74), (W * 0.58, H * 0.6)], fill=(232, 224, 208))
        d.rectangle([W * 0.46, H * 0.6, W * 0.54, H * 0.63], fill=spec.get('trim', (90, 26, 26)))
    d.rectangle([W * 0.44, H * 0.48, W * 0.56, H * 0.62], fill=skin)
    d.ellipse([W * 0.35, H * 0.24, W * 0.65, H * 0.52], fill=skin)
    if spec.get('blank'):
        smear = Image.new('L', (W, H), 0); sd = ImageDraw.Draw(smear)
        sd.ellipse([W * 0.33, H * 0.22, W * 0.67, H * 0.54], fill=230)
        for _ in range(40):
            y0 = H * (0.25 + r.random() * 0.27)
            sd.line([(W * 0.32, y0), (W * 0.68, y0 + (r.random() - 0.5) * 40)], fill=255, width=int(8 + r.random() * 16))
        smear = smear.filter(ImageFilter.GaussianBlur(18))
        img = Image.composite(Image.new('RGB', (W, H), (30, 24, 20)), img, smear); d = ImageDraw.Draw(img)
    else:
        for s in (-1, 1):
            ex = W * (0.5 + s * 0.055)
            d.ellipse([ex - W * 0.03, H * 0.37 - H * 0.012, ex + W * 0.03, H * 0.37 + H * 0.012], fill=(242, 236, 224))
            d.ellipse([ex - W * 0.014, H * 0.37 - W * 0.014, ex + W * 0.014, H * 0.37 + W * 0.014], fill=spec.get('eyes', (59, 42, 26)))
            d.line(bez((W * (0.5 + s * 0.025), H * 0.345), (W * (0.5 + s * 0.06), H * (0.338 if spec.get('stern') else 0.33)), (W * (0.5 + s * 0.09), H * 0.345)), fill=hair, width=int(W * 0.012))
        d.line([(W * 0.5, H * 0.37), (W * 0.49, H * 0.41), (W * 0.51, H * 0.415)], fill=(110, 60, 40), width=int(W * 0.006))
        d.line(bez((W * 0.465, H * 0.445), (W * 0.5, H * (0.46 if spec.get('smile') else 0.45)), (W * 0.535, H * 0.445)), fill=spec.get('lips', (138, 58, 48)), width=int(W * 0.01))
        if spec.get('moustache'):
            d.ellipse([W * 0.435, H * 0.422, W * 0.505, H * 0.438], fill=hair); d.ellipse([W * 0.495, H * 0.422, W * 0.565, H * 0.438], fill=hair)
    d.chord([W * 0.335, H * 0.215, W * 0.665, H * 0.365], 180, 360, fill=hair)
    if spec.get('female'):
        d.ellipse([W * 0.43, H * 0.13, W * 0.57, H * 0.27], fill=hair)
        d.rectangle([W * 0.335, H * 0.29, W * 0.375, H * 0.41], fill=hair); d.rectangle([W * 0.625, H * 0.29, W * 0.665, H * 0.41], fill=hair)
    if spec.get('crown'):
        pts = [(W * (0.38 + i * 0.048), H * (0.17 if i % 2 else 0.215)) for i in range(6)]
        d.polygon([(W * 0.38, H * 0.24)] + pts + [(W * 0.62, H * 0.24)], fill=(216, 178, 90))
    if spec.get('child'):
        for s in (-1, 1): d.ellipse([W * (0.5 + s * 0.08) - W * 0.025, H * 0.41 - W * 0.025, W * (0.5 + s * 0.08) + W * 0.025, H * 0.41 + W * 0.025], fill=(240, 190, 180))
    # oil paint: soften, varnish, craquelure, vignette
    img = img.filter(ImageFilter.ModeFilter(5)).filter(ImageFilter.GaussianBlur(1.2))
    arr = np.asarray(img, np.float32) / 255
    arr = arr * np.array([1.0, 0.92, 0.72])
    n = fbm(512, 6, 5, spec.get('seed', 5))
    n = np.asarray(Image.fromarray((n * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC), np.float32)[..., None] / 255
    arr *= 0.85 + 0.3 * n
    vig = np.clip(1.25 - np.hypot((xx - W / 2) / W, (yy - H / 2) / H) * 1.5, 0.35, 1)[..., None]
    img = Image.fromarray((np.clip(arr * vig, 0, 1) * 255).astype(np.uint8)); d = ImageDraw.Draw(img)
    for _ in range(260):
        x, y = r.random() * W, r.random() * H
        d.line([(x, y), (x + (r.random() - 0.5) * 60, y + (r.random() - 0.5) * 60)], fill=(0, 0, 0), width=1)
    if spec.get('plaque'):
        d.rectangle([W * 0.3, H * 0.93, W * 0.7, H * 0.98], fill=(184, 145, 74))
        d.text((W / 2, H * 0.955), spec['plaque'], font=font('Cinzel.ttf', int(H * 0.026)), fill=(42, 26, 10), anchor='mm')
    save(img, name, (w, h))

# --------------------------------------------------------------------------------- music, writing, symbols
def sheet(symbol):
    W, H = 512, 680; r = random.Random(len(symbol) * 7)
    img = Image.new('RGBA', (W, H), (234, 223, 196, 255)); d = ImageDraw.Draw(img)
    for s in range(5):
        for l in range(5):
            y = 100 + s * 110 + l * 12; d.line([(30, y), (W - 30, y)], fill=(58, 42, 26), width=2)
    for s in range(5):
        for k in range(9):
            px = 60 + k * 48 + r.random() * 8; py = 100 + s * 110 + r.randint(0, 8) * 6
            d.ellipse([px - 9, py - 6, px + 9, py + 6], fill=(42, 26, 10)); d.line([(px + 8, py), (px + 8, py - 40)], fill=(42, 26, 10), width=3)
    d.text((40, 70), '3/4', font=font('Cinzel.ttf', 40), fill=(42, 26, 10), anchor='mm')
    cx, cy = W - 70, 60
    red = (122, 31, 31)
    if symbol == 'moon':
        d.ellipse([cx - 30, cy - 30, cx + 30, cy + 30], fill=red); d.ellipse([cx - 14, cy - 38, cx + 40, cy + 16], fill=(234, 223, 196))
    elif symbol == 'star':
        d.polygon([(cx + math.cos(a) * (14 if i % 2 else 32), cy + math.sin(a) * (14 if i % 2 else 32)) for i, a in enumerate(np.linspace(-math.pi / 2, 1.5 * math.pi, 11)[:-1])], fill=red)
    else:
        d.ellipse([cx - 16, cy - 16, cx + 16, cy + 16], fill=red)
        for i in range(8):
            a = i / 8 * math.tau; d.rectangle([cx + math.cos(a) * 24 - 5, cy + math.sin(a) * 24 - 5, cx + math.cos(a) * 24 + 5, cy + math.sin(a) * 24 + 5], fill=red)
    pts = [(i / 16 * W, H - 20 - r.random() * 44) for i in range(17)]
    d.polygon([(0, H)] + pts + [(W, H)], fill=(0, 0, 0, 0))
    save(img, 'sheet_' + symbol)

def writing(name, lines, size=56, w=1024, h=256):
    img = Image.new('RGBA', (w * 2, h * 2), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
    f = font('Alegreya-Italic.ttf', size * 2); lh = size * 2.3
    for i, l in enumerate(lines):
        d.text((w, h + (i - (len(lines) - 1) / 2) * lh), l, font=f, fill=(255, 255, 255, 255), anchor='mm')
    img = img.filter(ImageFilter.GaussianBlur(1.0))
    save(img, name, (w, h))

def symbol(name, kind, S=512):
    img = Image.new('RGBA', (S * 2, S * 2), (0, 0, 0, 0)); d = ImageDraw.Draw(img); c = S; W = int(S * 0.06)
    wh = (255, 255, 255, 255)
    if kind == 'emblem':
        d.ellipse([c - S * 0.6, c - S * 0.6, c + S * 0.6, c + S * 0.6], outline=wh, width=W)
        d.arc([c - S * 0.84, c - S * 0.84, c + S * 0.84, c + S * 0.84], 20, 160, fill=wh, width=W)
        d.line([(c, c), (c - S * 0.1, c - S * 0.4)], fill=wh, width=W); d.line([(c, c), (c + S * 0.2, c - S * 0.34)], fill=wh, width=W)
        for i in range(12):
            a = i / 12 * math.tau; d.ellipse([c + math.cos(a) * S * 0.5 - 10, c + math.sin(a) * S * 0.5 - 10, c + math.cos(a) * S * 0.5 + 10, c + math.sin(a) * S * 0.5 + 10], fill=wh)
    elif kind == 'door':
        d.rectangle([c - S * 0.44, c - S * 0.5, c + S * 0.44, c + S * 0.95], outline=wh, width=W)
        d.arc([c - S * 0.44, c - S * 0.94, c + S * 0.44, c - S * 0.06], 180, 360, fill=wh, width=W)
        d.ellipse([c + S * 0.24 - 20, c + S * 0.25 - 20, c + S * 0.24 + 20, c + S * 0.25 + 20], fill=wh)
    elif kind == 'mark':
        for i in range(3):
            rr = S * (0.16 if i == 0 else 0.1); x = c + (i - 1) * S * 0.5
            d.ellipse([x - rr, c - rr, x + rr, c + rr], fill=wh)
        d.arc([c - S * 0.64, c - S * 0.5, c + S * 0.64, c + S * 0.7], 200, 340, fill=wh, width=W)
    img = img.filter(ImageFilter.GaussianBlur(3))
    save(img, name, S)

def plate(n):
    S = 256
    img = Image.new('RGBA', (S * 2, S * 2), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
    d.ellipse([8, 8, S * 2 - 8, S * 2 - 8], fill=(184, 145, 74, 255))
    d.ellipse([30, 30, S * 2 - 30, S * 2 - 30], outline=(42, 26, 10, 255), width=8)
    d.text((S, S + 10), str(n), font=font('Cinzel.ttf', 220 if n < 10 else 160), fill=(42, 26, 10, 255), anchor='mm')
    save(img, f'plate_{n}', S)

def iris(name, color, seed):
    S = 512; r = random.Random(seed)
    yy, xx = np.mgrid[0:S, 0:S] / S - 0.5
    rr = np.hypot(xx, yy) * 2; ang = np.arctan2(yy, xx)
    base = np.array(color, np.float32) / 255
    fibres = 0.75 + 0.25 * np.sin(ang * 60 + np.sin(ang * 7) * 3) * (0.5 + 0.5 * np.cos(rr * 20))
    col = base[None, None, :] * fibres[..., None] * (1.25 - rr[..., None] * 0.6)
    col = np.where((rr > 0.8)[..., None], col * 0.4, col)
    col = np.where((rr < 0.36)[..., None], 0.02, col)
    hl = np.exp(-(((xx - 0.12) ** 2 + (yy + 0.14) ** 2) / 0.003))[..., None]
    col = col + hl * 1.2
    sclera = np.array([0.96, 0.94, 0.9])
    col = np.where((rr > 1.0)[..., None], sclera, col)
    save(Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8)), 'iris_' + name)

def sign():
    W, H = 1024, 512
    img = Image.new('RGB', (W, H), (58, 42, 26)); d = ImageDraw.Draw(img)
    n = fbm(256, 4, 5, 3); n = Image.fromarray((n * 255).astype(np.uint8)).resize((W, H), Image.BICUBIC)
    img = Image.blend(img, Image.merge('RGB', (n, n, n)), 0.12); d = ImageDraw.Draw(img)
    d.text((W / 2, 140), 'ASHCOMBE HOUSE', font=font('Cinzel.ttf', 100), fill=(216, 200, 160), anchor='mm')
    d.text((W / 2, 270), 'Private · No Visitors After Dark', font=font('Alegreya-Italic.ttf', 58), fill=(216, 200, 160), anchor='mm')
    d.text((W / 2, 390), 'Property of the Hollins Trust', font=font('Alegreya.ttf', 48), fill=(196, 180, 140), anchor='mm')
    save(img, 'sign')

def noise_tex():
    n = fbm(512, 4, 6, 77)
    save(Image.fromarray((n * 255).astype(np.uint8)), 'noise')

def cobweb():
    S = 1024; r = random.Random(3)
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(img)
    spokes = [i / 8 * math.pi / 2 + (r.random() - 0.5) * 0.08 for i in range(9)]
    for a in spokes: d.line([(0, 0), (math.cos(a) * S, math.sin(a) * S)], fill=(235, 235, 240, 200), width=2)
    for ring in range(1, 14):
        pts = []
        for i, a in enumerate(spokes):
            rr = ring / 14 * S * (0.95 + r.random() * 0.1)
            pts.append((math.cos(a) * rr, math.sin(a) * rr))
        for i in range(1, len(pts)):
            d.line(bez(pts[i - 1], ((pts[i - 1][0] + pts[i][0]) / 2 * 0.92, (pts[i - 1][1] + pts[i][1]) / 2 * 0.92), pts[i], n=8), fill=(235, 235, 240, int(120 + r.random() * 100)), width=2)
    save(img, 'cobweb')

if __name__ == '__main__':
    damask('damask_a', 'a'); damask('damask_b', 'b'); damask('damask_c', 'c')
    rug('rug_hall', (94, 26, 30), (29, 43, 58), (196, 154, 74), 71)
    rug('rug_guest', (35, 56, 74), (91, 30, 30), (185, 160, 106), 73)
    runner(); star_inlay(); mural(); sign(); noise_tex(); cobweb()
    clock_face('clock_grand', label='Ashcombe · 1871'); clock_face('clock_dark', dark=True); clock_face('clock_wall', roman=False, size=512)
    clock_face('clock_tower', size=1024)
    P = {
        'portrait_edmund': dict(seed=3, skin=(217, 179, 148), hair=(42, 36, 32), coat=(26, 20, 32), eyes=(42, 58, 58), moustache=True, stern=True, plaque='Edmund Ashcombe', drape=(40, 60, 40)),
        'portrait_margaret': dict(seed=4, female=True, skin=(232, 196, 168), hair=(106, 58, 26), coat=(58, 20, 48), trim=(216, 192, 112), smile=True, plaque='Margaret Ashcombe', drape=(80, 20, 40)),
        'portrait_celeste': dict(seed=5, female=True, skin=(224, 192, 168), hair=(26, 20, 24), coat=(20, 32, 58), trim=(168, 200, 232), plaque='Celeste Ashcombe', drape=(20, 30, 70)),
        'portrait_youngest': dict(seed=6, child=True, blank=True, skin=(232, 200, 176), hair=(122, 74, 42), coat=(42, 58, 42), plaque='The Youngest', drape=(40, 60, 30)),
        'portrait_ancestor1': dict(seed=7, skin=(216, 176, 144), hair=(232, 232, 232), coat=(42, 26, 16), moustache=True),
        'portrait_ancestor2': dict(seed=8, female=True, skin=(232, 200, 176), hair=(90, 90, 90), coat=(58, 42, 58)),
        'portrait_ancestor3': dict(seed=9, skin=(200, 152, 120), hair=(58, 42, 26), coat=(26, 42, 26), stern=True),
        'portrait_ancestor4': dict(seed=10, female=True, skin=(224, 184, 152), hair=(138, 90, 42), coat=(74, 26, 26), smile=True),
        'portrait_watcher': dict(seed=21, skin=(216, 184, 160), hair=(58, 42, 26), coat=(42, 32, 48), moustache=True, stern=True),
        'portrait_lady': dict(seed=22, female=True, skin=(224, 192, 160), hair=(138, 106, 74), coat=(74, 58, 42), smile=True),
        'portrait_guest': dict(seed=31, female=True, bg=(42, 58, 74), skin=(232, 200, 176), hair=(58, 42, 26), coat=(58, 74, 90)),
    }
    for k, v in P.items(): portrait(k, v)
    for s in ('moon', 'star', 'sun'): sheet(s)
    writing('trace_coats', ['He waits where the coats sleep.', 'Number seven is still empty.'], 48)
    writing('trace_bighead', ['Think big: BIGTHINKER'], 56)
    writing('trace_sunglasses', ['Spectacles for the spectral: COOLSPIRITS'], 44)
    writing('trace_disco', ['When the band stops, BOOGIEWOOGIE'], 48)
    writing('trace_tiny', ['Small but terrifying: TINYTERROR'], 52)
    symbol('sym_emblem', 'emblem'); symbol('sym_door', 'door'); symbol('sym_mark', 'mark')
    for i in range(1, 21): plate(i)
    for k, c in {'avery': (91, 107, 51), 'mara': (58, 36, 22), 'porter': (106, 138, 154), 'pip': (58, 106, 90), 'host': (58, 42, 26), 'theo': (60, 80, 110), 'june': (70, 50, 30), 'dancer': (90, 70, 120), 'king': (40, 30, 20)}.items():
        iris(k, c, len(k))
