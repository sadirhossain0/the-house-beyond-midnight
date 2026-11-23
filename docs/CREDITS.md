# Credits and licences

## Engine and tools
- **Godot Engine 4.7** — MIT licence. https://godotengine.org
- **Blender** (GPL; the tool's licence does not apply to the assets made with it) builds the characters, props and car.
- **FluidSynth** (LGPL) renders the score offline. Only the rendered audio ships, not FluidSynth itself.

## Assets from others
- **Poly Haven** (https://polyhaven.com): PBR texture sets, the furniture and decor models in `assets/models/props/`, and the HDRI night skies in `assets/hdri/`. All are **CC0**. Thank you to the Poly Haven artists and patrons.
- **FluidR3_GM soundfont** by Frank Wen: **MIT licence**. Used to render the music and a few musical stingers. The rendered audio files are this game's own recordings.
- **Fonts** (all under the SIL Open Font License 1.1):
  - Cinzel and Cinzel Decorative: Natanael Gama
  - Alegreya: Juan Pablo del Peral, Huerta Tipográfica
  - IM Fell English SC: Igino Marini

## Made for this game
- Every character (`tools/blender/characters.py`): bodies, faces, hair, costumes and rigs.
- Procedural animation (`src/chars/character.gd`).
- The rooms and bespoke props: the Grand Clock, chandeliers, staircases, doors, windows, music stands and more.
- Generated textures: damask wallpapers, rugs, clock faces, signs, trace symbols and irises (`tools/textures/generate.py`).
- The score, "The Ashcombe Waltz" and its arrangements (`tools/audio/compose.py`).
- Sound effects and ambience (`tools/audio/sfx.py`).
- Character voices: a formant synthesiser speaking an invented syllable language (`tools/audio/voices.py`).
- The story, script, puzzles and writing.
