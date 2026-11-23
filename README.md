# The House Beyond Midnight

A cosy-spooky mystery in twelve chimes. It is New Year's Eve, one minute to midnight, and building
surveyor Avery Wren has been sent to value Ashcombe House before demolition. Every clock in the
house has stopped at 11:59, and it has been 11:59 since 1891.

This repository is the **vertical slice**: the Prologue, Chapter One (*The Stopped Clocks*) and
Chapter Two (*The Last Waltz*, with the Forgotten Host encounter). It ends with Mara Bell freed and
the Grand Clock's second chime.

Native **Godot 4.7** game for **Windows, macOS, Linux and Android**. Console readiness notes for
Switch Lite and PS4 are in [`docs/CONSOLE_PORTING.md`](docs/CONSOLE_PORTING.md).

## Playing

| | Keyboard and mouse | Gamepad |
| --- | --- | --- |
| Move / look | WASD / mouse | Left stick / right stick |
| Interact | E | A (Nintendo: B) |
| Raise the Gloam Lantern / use the Midnight Watch | Left mouse (hold) | RT |
| Lantern flare | F | X |
| Observe (focus) | Right mouse (hold) | LT |
| Dodge | Space | B |
| Lantern / Watch | 1 / 2 | D-pad left / right |
| Field Journal · Map · Hint | J · M · H | Y · View · D-pad up |
| Pause | Esc | Menu |

Every action can be rebound (**Settings → Controls**). On phones and tablets, touch controls appear
automatically.

## Features in the slice

- **Rooms:** the drive in a storm, the entrance hall with its imperial staircase and Grand Clock, the
  guest wing, a hidden cloakroom, a guest room, the Grand Ballroom (in two eras, *Now* and *Then*)
  and its balcony.
- **Look:** PBR materials from Poly Haven (CC0) at 1K, 2K or 4K, volumetric fog, SDFGI, SSR,
  colour grading per room, and lightning.
- **Characters:** 23 rigged characters built in Blender with chunky cartoon proportions (big heads,
  small bodies, oversized hands and boots). Each has their own head shape, silhouette and story
  props: Avery's wristwatch worn over the sleeve, pencil and folding rule; Mara's one sequinned
  sleeve and three bangles; the Porter's empty coat hanger and ticket for hook seven; Pip's jacket
  of lost buttons; the Host's empty dance card and wilting carnation. All are animated
  procedurally, with gait, posture, idles, blinking, gaze, lip flaps and expressions.
- **Tools:** the **Gloam Lantern** (reveal hidden writing and doors, flare to startle ghosts, a
  flame that leans toward the uncanny) and the **Midnight Watch** (see echoes of the sealed night,
  and shift rooms between Now and Then at anchor clocks).
- **The Forgotten Host:** a three-phase encounter. Flare the mirror he hides in, push the chairs
  onto the stars past the waltzing dancers, then dance the last waltz on the beat.
- **Field Journal:** clues, deductions, documents, ghost cards and a three-tier hint system.
- **Collection, wardrobe and Paranormal Extras:** costumes, cheat codes hidden in lantern light,
  and filters.
- **Saves:** three slots with backups, export and import of files, a full restore code, and a short
  *Midnight Code*.
- **Score:** "The Ashcombe Waltz", arranged for every room with adaptive stems. In Chapter Two the
  puzzle is the waltz itself: in the fourth bar, the third beat never comes.
- **Sound and voices:** synthesised sound effects and ambience, and character voices from a
  formant synthesiser that speaks an invented language. There is no text-to-speech.
- **Graphics options:** Low, Medium, High, Ultra, Custom and Auto presets, emulated console
  profiles, dynamic resolution, FSR, a frame cap, and a performance overlay.
- **Accessibility:** subtitles with size and background options, extra candles, no composure loss,
  extended timing, aim assist, high contrast, reduced flashing, reduced motion, a safe area, and
  touch controls.

## Building

```bash
godot --headless --path . --import
godot --headless --path . --export-release "Windows" build/windows/HouseBeyondMidnight.exe
godot --headless --path . --export-release "Linux" build/linux/HouseBeyondMidnight.x86_64
godot --headless --path . --export-release "macOS" build/macos/HouseBeyondMidnight.zip
godot --headless --path . --export-release "Android" build/android/HouseBeyondMidnight.apk
```

The macOS build is signed ad hoc. To distribute it you need an Apple Developer ID and
notarisation. The Android build needs the Android SDK path and a keystore in Godot's editor
settings (see `tools/export_all.sh`).

## Rebuilding generated assets

```bash
python3 tools/textures/prepare_cc0.py
python3 tools/textures/generate.py
blender -b -P tools/blender/convert_props.py
python3 tools/blender/characters.py
python3 tools/audio/compose.py
python3 tools/audio/sfx.py
python3 tools/audio/voices.py
```

The first command downloads the CC0 Poly Haven textures, models and HDRIs. The second makes the
wallpapers, rugs, clocks and trace symbols. The Blender steps decimate the props and build the
characters (Blender's `bpy` module). The audio scripts need `fluidsynth` and the FluidR3 GM
soundfont.

## Development harnesses

```bash
godot --path . res://src/dev/playtest.tscn -- --out=/tmp/pt
godot --path . res://src/dev/shots.tscn -- --shots=hall_entry,ballroom_then --preset=ultra
godot --path . res://src/dev/char_test.tscn -- --set=a
```

These run an automated playthrough of the whole slice, take beauty shots from named camera poses,
and line up the cast in a range of poses.

Credits and licences are in [`docs/CREDITS.md`](docs/CREDITS.md).
