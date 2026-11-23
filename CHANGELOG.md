# Changelog

## Unreleased (Update 2, in progress)

- **Lip sync.** Mouths now take the shape of the vowel being spoken (open for "ah", round for "oo",
  wide for "ee", closed between words), driven by the voice synthesiser's own syllable data.
- **Foley.**
  - Avery's coat rustles and Mara's gown swishes as they walk.
  - The lantern creaks when it swings, and the Midnight Watch ticks quietly while it's in hand.
  - The Porter's key ring jangles as he drifts, and Pip's button-covered jacket rattles when he
    flees.
  - The Host's cane taps when he appears, and the Field Journal turns a page when opened.
- **Dust motes** drift and glint in the raised lantern beam.
- **Downloads.** Windows and Linux ship as single executables, and releases are built by a
  one-click GitHub Actions workflow.

## 0.3.0: the vertical slice

The first playable release: the Prologue, Chapter One (*The Stopped Clocks*) and Chapter Two (*The Last Waltz*), ending at the Grand Clock's second chime.

**Game**
- Ashcombe House: the drive in a storm, the entrance hall, the guest wing, a hidden cloakroom, a guest room, the Grand Ballroom in the present and on the sealed night of 1891, and its balcony.
- The Gloam Lantern (reveal, flare, a flame that leans toward the uncanny) and the Midnight Watch (echoes, and shifting rooms between Now and Then).
- The Field Journal with clues, deductions, documents and ghost cards, plus a three-tier hint system.
- The Forgotten Host: mirrors, chairs on the stars, and the last dance on the beat.
- Mara Bell becomes playable after the balcony scene.
- A wardrobe of outfits, cheat codes written in lantern light, collectibles and achievements.

**Look and sound**
- 23 characters with cartoon proportions, their own head shapes and story props, and procedural animation (gait, posture, gaze, blinking, expressions, lip flaps).
- Vibrant per-room colour grading, volumetric fog and lightning.
- "The Ashcombe Waltz" arranged for every room with adaptive layers; synthesised sound effects, ambience and character voices.

**Systems**
- Three save slots with backups, file export/import, a full restore code and short Midnight Codes.
- Graphics presets from Low to Ultra, console-style hardware profiles, dynamic resolution and FSR.
- Accessibility options, full rebinding, Xbox/PlayStation/Nintendo prompts and touch controls.

**Fixes found in testing**
- Menus could open collapsed and empty because of a layout call that kept a zero size.
- Settings dropdowns showed the wrong value for numbers (for example "30 fps" on High).
- The field-of-view setting wasn't applied to the camera.
- Saving during the Forgotten Host encounter could leave the chapter unfinishable after loading.
- Two story scenes overlapping could hand control back mid-cutscene.
