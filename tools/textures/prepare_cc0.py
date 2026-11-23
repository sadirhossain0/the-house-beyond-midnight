"""Prepare CC0 Poly Haven texture sets for the game.

Produces res://assets/textures/<set>/{albedo,normal,orm,height}_{low,high,ultra}.<ext>
  low = 1K, high = 2K, ultra = 4K (only where a 4K source exists).
The ORM map is Poly Haven's 'arm' map (R=AO, G=roughness, B=metal), which matches Godot's ORM layout.
Source: https://polyhaven.com (CC0). See docs/CREDITS.md.
"""
import os, sys, glob
from PIL import Image
Image.MAX_IMAGE_PIXELS = None
SRC = sys.argv[1] if len(sys.argv) > 1 else '/opt/cc0/tex'
DST = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), '..', '..', 'assets', 'textures')
HEIGHT_SETS = {'marble_01', 'herringbone_parquet', 'old_wooden_floor_02', 'wood_floor_worn', 'stone_tiles', 'monastery_stone_floor', 'leaf_scattered_gravel', 'gravel_floor_02', 'stone_block_wall', 'roof_slates_03', 'large_sandstone_blocks', 'wooden_panels', 'slate_floor'}
MAPS = {'Diffuse': ('albedo', 'jpg'), 'nor_gl': ('normal', 'png'), 'arm': ('orm', 'jpg'), 'Displacement': ('height', 'png')}
TIERS = [('ultra', 4096), ('high', 2048), ('low', 1024)]

def main():
    for d in sorted(os.listdir(SRC)):
        sdir = os.path.join(SRC, d)
        out = os.path.join(DST, d)
        os.makedirs(out, exist_ok=True)
        for key, (name, ext) in MAPS.items():
            if name == 'height' and d not in HEIGHT_SETS: continue
            files = glob.glob(os.path.join(sdir, f'{d}_{key}_*'))
            if not files: continue
            src = sorted(files)[-1]
            im = Image.open(src)
            if name == 'height': im = im.convert('L') if im.mode not in ('I;16', 'I') else im.point(lambda v: v / 256).convert('L')
            elif name in ('normal',): im = im.convert('RGB')
            else: im = im.convert('RGB')
            w = im.size[0]
            for tier, size in TIERS:
                if size > w: continue
                path = os.path.join(out, f'{name}_{tier}.{ext}')
                if os.path.exists(path): continue
                r = im if size == w else im.resize((size, size), Image.LANCZOS)
                if ext == 'jpg': r.save(path, quality=92, optimize=True)
                else: r.save(path, optimize=True)
        print('ok', d, flush=True)

main()
