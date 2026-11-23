# Console porting: Nintendo Switch Lite and PlayStation 4

Console builds can only be made by a licensed developer. Each platform holder gives approved
studios an NDA'd SDK, development hardware and certification requirements. Godot's console ports are
distributed through third parties (W4 Games for Switch and PlayStation, among others), and only to
those developers. Nothing in this repository can produce a console build on its own.

What the repository *does* do is make the port straightforward once you have that access:

| Already in the game | Where |
| --- | --- |
| Hardware profiles that emulate each console's budget (resolution, frame cap, shadows, GI, fog, texture tier) | `src/autoload/settings.gd` → `PRESETS.switchlite`, `PRESETS.ps4` |
| Budgets to test against (draw calls, primitives, VRAM) | `Settings.CONSOLE_BUDGETS`, shown live by **Settings → Interface → Performance overlay** |
| Dynamic resolution with an internal-height cap (720p / 1080p) and FSR upscaling | `src/world/graphics.gd` |
| Correct button glyphs: Nintendo (A/B swapped, ZL/ZR, +/−) and PlayStation (✕ ○ □ △, Options) | `src/autoload/controls.gd` → `GLYPHS`, `glyph_family()` |
| Nintendo confirm/cancel layout swap | Settings → Controls → *Nintendo button layout* |
| Safe-area margin for TVs | Settings → Interface → *Safe area* |
| Rumble that respects the vibration setting | `Controls.rumble()` |
| Saves as small JSON slots with a backup, plus export/import and restore codes | `src/autoload/save_system.gd` |
| No keyboard is required anywhere, and every menu is pad-navigable | `src/ui/*` |

## Switch Lite (handheld only, 720p, 4 GB shared memory)

Run with the `switchlite` preset and the performance overlay on. The target is a locked 30 fps at
720p.

- Renderer: use the Mobile renderer (the project already sets `rendering_method.mobile="mobile"`).
  Forward+ features (SDFGI, SSIL, SSR, volumetric fog) are off in this profile.
- Textures: the `low` tier (1K Poly Haven maps). Use ASTC; the project already imports ETC2/ASTC.
- Lights: one shadowed light at a time (`shadow_lights: 1`). The light manager already culls by
  distance and priority.
- Particles at 55%. Rain is the most expensive effect on the drive.
- Characters: about 30k triangles each. If the ballroom's six dancers plus the Host go over the
  draw-call budget, merge each dancer's Body surfaces in Blender (`tools/blender/characters.py`)
  into a single atlas material.
- Memory: the 2K prop textures don't fit. Export with the low tier only, using `*_high.*` and
  `*_ultra.*` exclude filters.
- Certification items to plan for: suspend/resume (pause on focus loss is already implemented),
  the user-account picker for saves, and "the game must not hang during loading" (the loading
  screen keeps animating while the world builds).

## PlayStation 4 (1080p, GCN 1.84 TFLOPS, 8 GB)

Run with the `ps4` preset: 30 fps, 1080p internal with dynamic resolution down to 80%.

- Renderer: Forward+ works on PS4-class GCN hardware. Keep SDFGI off and the SSAO low.
- Textures: the `high` tier (2K).
- Ultra-only features (SSR, 4K textures, SDFGI) stay off.
- The Jaguar CPU is the bottleneck. Pre-bake rooms to `.scn` instead of building them at load time
  (`World.build_all()` currently builds procedurally), and keep the procedural character animator
  to visible characters only (`Character.freeze` does this for far or off-screen dancers).
- TRC items to plan for: the trophy list (map `GameData.ACHIEVEMENTS` 1:1), Activities for the
  chapters, the system software keyboard for the register name, and save-data icons.

## Checklist when the SDK arrives

1. Install the console export template from your Godot console provider.
2. Add an export preset with `custom_features="switchlite"` or `"ps4"`. `Settings._detect()` can
   read those features to choose the preset automatically.
3. Replace `user://` save paths with the platform's save-data API inside `save_system.gd`. Every
   read and write already goes through `_read` and `_write`.
4. Map achievements to trophies or Switch equivalents in `Game.unlock()`.
5. Profile every room with the overlay. Budgets are in `Settings.CONSOLE_BUDGETS`.
