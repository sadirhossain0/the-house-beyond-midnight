# Contributing

Thanks for your interest in the house.

## Reporting bugs
Use the **Bug report** form under Issues. A Midnight Code (Pause → Save & Load → Codes) lets us
reproduce your exact progress.

## Working on the project
1. Install **Godot 4.7.2** and Git LFS, then clone and import:
   ```bash
   git lfs install
   git clone https://github.com/sadirhossain0/the-house-beyond-midnight
   godot --headless --path the-house-beyond-midnight --import
   ```
2. Before opening a pull request, run the automated playthrough. It must end with
   `DONE objective=slice_end`, no lines starting with `!!`, and no `SCRIPT ERROR`:
   ```bash
   godot --path . res://src/dev/playtest.tscn -- --out=/tmp/pt --preset=low
   ```
3. Generated assets (characters, music, sound, textures) come from the scripts in `tools/`;
   change the script, not the output.

## Style
- Write specific, concrete text: dialogue, item descriptions and docs should say something only
  this game would say.
- Characters keep the established proportions and each has a story reason for what they carry.
- Never imitate characters or art from existing games.

Plans for the next updates are in [docs/ROADMAP.md](docs/ROADMAP.md).
