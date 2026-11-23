# The House Beyond Midnight: project memory

Read this first in every session. Plans for the next updates are in `docs/ROADMAP.md`.
**Update 2 is in progress** (the user said to do everything we can). Done so far: lip sync from the
voice synth's vowels, character foley, dust motes in the lantern beam. Next: 2.0 models and
environments, then the rest of 2.1–2.3. Log progress in `CHANGELOG.md` under "Unreleased".

## What this is

A cosy-spooky 3D mystery game, native **Godot 4.7.2** (Forward+, Mobile renderer on Android, Jolt
physics). Vertical slice: Prologue, Chapter One "The Stopped Clocks", Chapter Two "The Last Waltz"
with the three-phase Forgotten Host encounter, ending at the Grand Clock's second chime. Targets:
Windows, macOS, Linux, Android. Console (Switch Lite, PS4) = profiles and notes only, see
`docs/CONSOLE_PORTING.md`. The web version was dropped on purpose.

## What the user wants (keep to these)

- The best possible quality, and nothing that feels like generic "AI slop": specific,
  story-grounded details in characters, writing and art. Explain changes plainly; no fluff.
- Characters: chunky cartoon proportions (big heads, small bodies, ~2¼ heads tall), each with
  their own silhouette, head shape and story props. Original designs only: never imitate Nintendo
  characters (no Luigi/Mario/Wario/Waluigi lookalikes: watch purple+yellow+moustache combos).
- A vibrant world: saturated per-room colour, warm lamplight against cool moonlight.
- Voices must not sound AI-made (they're a formant synth speaking an invented language).
- Big downloads are fine; quality over size.
- Next update priority (user's words): "improve models, environments and everything that we can".
  That's `docs/ROADMAP.md` section 2.0, then animation and sound.
- Keep the GitHub page professional: screenshots in `docs/media/` (plain git, not LFS) and the
  README gallery updated when visuals change.

## Layout

- `src/autoload/`: Events, Settings (presets incl. console profiles), Controls, Save (slots,
  export/import, restore codes), Audio (stems, sfx, voices), Game (flags, objectives, hints).
- `src/world/`: World, rooms (`rooms/*.gd` build the estate procedurally from CC0 materials),
  props, graphics (grades, dynamic resolution).
- `src/chars/`: `cast.gd` (costumes, NPCs, bios), `character.gd` (model loader + procedural
  animator; poses are authored in character space and mapped onto rigs).
- `src/player/`: player, camera rig, lantern.
- `src/game/`: `story.gd` (Prologue, Ch1), `chapter2.gd` (Ch2 + Host encounter), dialogue,
  game screen (loading, pause, saving, cards), `data.gd` (all authored content).
- `src/ui/`: HUD, menus (journal, map, wardrobe, collection, extras, settings, saves, help),
  title, loading, touch controls, `ui_kit.gd` theme.
- `tools/`: Blender character/prop/car generators, texture tools, audio (compose, sfx, voices).
- `src/dev/`: test harnesses (not exported).

## Commands

```bash
godot --headless --path . --import
# full automated playthrough (must end "DONE objective=slice_end", no "!!" lines, 0 SCRIPT ERROR)
xvfb-run -a godot --path . --rendering-driver vulkan --resolution 960x540 res://src/dev/playtest.tscn -- --out=/tmp/pt --preset=low
# start at the Host encounter
... res://src/dev/playtest.tscn -- --out=/tmp/pt --from=encounter
# menu/title screenshots, in-game beauty shots, character line-up
... res://src/dev/ui_shots.tscn -- --out=/tmp/ui
... res://src/dev/beauty.tscn -- --out=/tmp/beauty --preset=high
... res://src/dev/char_test.tscn -- --set=a
python3 tools/blender/characters.py [--only a,b] [--preview]
python3 tools/audio/compose.py | sfx.py | voices.py
tools/export_all.sh
```

## Gotchas learned the hard way

- New `class_name` scripts need `godot --headless --path . --editor --quit` to refresh the class
  cache before running scenes.
- Full-screen Controls: use `set_anchors_and_offsets_preset(PRESET_FULL_RECT)`.
  `set_anchors_preset` keeps a zero size once in the tree (this broke every menu once).
- Settings round-trip through JSON as floats: compare numbers with `GameMenu.same_value`.
- Player control: `player.lock()` / `player.unlock()` are reference-counted per key. Every
  sequence must unlock exactly what it locked. Exception by design: `_to_phase3` locks and
  `_end_encounter` releases.
- `queue_free()` doesn't remove a child immediately: never loop on `get_child_count()` after it.
- The container renders with lavapipe (software Vulkan): High preset is slow (~5 min per beauty
  shot) and two heavy Godot instances at once run out of memory (15 GB). Run them one at a time.
- Blender mesh coordinates in `prim()` objects are local to the object: test vertices with
  `v.co`, not `v.co - centre`.
- Loops with rubato: loop length comes from the tempo map (`Song.seconds()`).

## Git and releases

- Push to `main` of `sadirhossain0/the-house-beyond-midnight`. Binaries go through Git LFS
  (`.gitattributes`); the environment allows `lfs.github.com`. README images live in `docs/media/`
  in plain git.
- This cloud session **cannot** create GitHub releases or change repository settings (description,
  topics, social preview): the GitHub proxy returns 403. Releases are made by the
  **"Build and release"** workflow (`.github/workflows/release.yml`); start it with
  `gh api -X POST repos/sadirhossain0/the-house-beyond-midnight/actions/workflows/release.yml/dispatches -f ref=main -f "inputs[version]=X.Y.Z"`
  (the `gh workflow run` shortcut fails: GraphQL is blocked). Put release notes in
  `docs/releases/X.Y.Z.md`.
- Desktop builds embed the data pack (one file each) and ship only the 2K texture tier, to stay
  under GitHub's 2 GB release-asset limit. The Claude app can't send files over 500 MB.
- Deleting the user's GitHub workflow files is blocked by a safety check: leave the six Pages
  workflows for the user to remove (or ask first).
- `build/`, `dist/` and `.godot/` are ignored.
