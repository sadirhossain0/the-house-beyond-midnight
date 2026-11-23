# Roadmap: updates 2 to 5

Status: planned, not started. Update 1 (the vertical slice: Prologue, Chapter One, Chapter Two)
shipped on `main`. Each update below lists what it is for, the concrete work, and how we'll know
it's done. Work top to bottom inside each update; the order inside a section is the build order.

---

## Update 2: Models, environments, animation and sound

The slice plays end to end, but the models are generated, the rooms are built from code, the key
moments are carried by procedural poses, and the mix is a first pass. This update makes everything
the player looks at and listens to feel authored. The user's priority is to improve the models,
the environments and everything else that can be improved, so 2.0 comes first.

### 2.0 Models and environments (the biggest visual step)

**Characters**
1. **Clean topology.** Retopologise the generated bodies into quad meshes with edge loops at the
   elbows, knees, shoulders and mouth, so they bend without pinching. Add three LOD levels.
2. **Sculpted detail baked to normal maps.**
   - Cloth folds at elbows, knees and waist; seams and stitching on coats.
   - The knit of Avery's scarf and the sequins on Mara's sleeve.
   - Wood grain on the Host's cane and wear on boots.
3. **Painted textures, one atlas per character.**
   - Skin warmer at the cheeks, nose and ears.
   - Freckles painted in rather than modelled.
   - Real fabric patterns: tweed on Avery's coat, damask on the Host's waistcoat, stripes on the
     pyjamas, gold braid on the Porter's uniform.
   - One material per character also cuts draw calls.
4. **Hair.** Carved locks with an anisotropic highlight in place of metaball blobs: Avery's
   blunt fringe, Mara's ringlets, the Host's swept silver hair.
5. **Hands.** Finger bones, so hands can actually grip the lantern handle, point, and hold the
   dance card.
6. **Expression sheets.** Ten expressions per main character, checked side by side, so every
   emotion reads at gameplay distance.

**Environments**
1. **A modular kit modelled in Blender**, replacing code-built boxes. Wall panels, wainscot,
   cornices and ceiling roses, door and window frames, stair parts and balusters, all with bevelled
   edges and trim sheets, so edges catch the light.
2. **Hero props modelled properly.**
   - The Grand Clock, with a carved hood and the brass mechanism visible through its glass.
   - Chandeliers hung with real crystal drops.
   - The grand piano and harp.
   - The folding screen with painted panels, the reception desk with pigeonholes, and the hook
     rails of the cloakroom.
3. **Baked lighting.** LightmapGI for static rooms: soft bounce light and contact shadows. Real-time
   GI only for moving lights, plus reflection probes per room. This is the single biggest jump in
   how rich the interiors look.
4. **Surfaces.**
   - Decals: water stains, scuffs, cobwebs.
   - Dust that settles on top-facing surfaces in the "Now" state.
   - Parallax floors and refractive glass.
   - Wet stone on the porch.
5. **Exterior.**
   - Sculpted terrain and real trees with wind sway.
   - A wrought-iron gate and fence, and clipped hedges.
   - A working fountain, and puddles that ripple in the rain.
   - Distant village lights for a sense of scale.
6. **Set dressing**, a story clutter pass per room:
   - The ballroom: party remains.
   - The cloakroom: umbrellas and hat boxes.
   - The guest room: a half-packed trunk.
   - The Porter's desk: ledgers, keys and a bell.
7. **Budgets.** Draw calls and triangles checked per room with the performance overlay; High
   holds 60 fps on a mid-range GPU.

Done when: before/after shots of every room and every main character show the upgrade side by side.

### 2.1 Animation

What we have: a procedural animator in `src/chars/character.gd` (gait, idles, gaze, blink, lip
flaps, expressions, about 30 action poses). It's good for locomotion and fidgets and stiff for the
big beats.

1. **Authored clips for the story beats.** Keyframe these in Blender (scripted in `tools/blender/`
   so they rebuild with the characters) and export as glTF animations on the shared skeleton:
   - Avery/Mara: pick up, push (chair, screen), lantern raise and flare recoil, open and snap shut
     the watch, startle hop, faint and get back up, bow, curtsy.
   - The last waltz: lead and follow parts of a 3/4 box step at exactly 90 bpm, so the dance phase
     lines up with `lastdance.ogg` beat for beat.
   - Porter: holding out his arms for a coat, the little bow, drifting to hook 7 and back.
   - Host: the sweep out of a mirror, the dizzy stagger after a flare, the moustache twirl, the
     final bow.
   - Pip: peeking out from behind a curtain, the dash between hiding spots, snuffing a candle.
   - Mara: singing gestures for the balcony scene, the startle when the Long Minute breaks.
2. **Mix the two layers.** An `AnimationTree` plays the clips; the procedural layer stays on top for
   gaze, blink, breathing and lip flaps, so faces never freeze during a clip.
3. **Feet on the ground.** Two-bone IK for feet on the staircase and the stage steps; turn-in-place
   instead of sliding; start and stop transitions for walking.
4. **Walks with personality.** Separate cycles: Avery's brisk "never late" pace, Mara's skip on
   the third step, the Porter's floating shuffle with a stoop, the Host's waddle, Pip's bob.
5. **Secondary motion.** Spring bones (`SpringBoneSimulator3D`) for the scarf tails, coat skirts,
   the Host's tailcoat, Mara's feather and curls, Pip's oversized cap, the Porter's hanger.
6. **Faces.** Replace open/closed lip flaps with visemes (rest, A, E, O, M-B-P, F-V). The voice
   synthesiser already knows which vowel each syllable uses, so it can emit a viseme timeline per
   line. Add brow animation per emotion and quick eye darts while thinking.
7. **Dialogue cameras.** Alternate over-the-shoulder shots, a slow push-in on important lines, and
   a little handheld drift instead of static two-shots.

Done when: every scripted interaction plays a matching clip or pose; nothing T-poses, pops or
slides; lips move to the vowels; the last-dance steps land on the beat.

### 2.2 Sound

1. **Foley per character.** Coat rustle for Avery, gown swish for Mara, the Porter's key ring
   jangle, Pip's buttons clicking, the Host's cane tap. The lantern creaks on its handle as it
   swings; the watch ticks quietly while it's the selected tool.
2. **Rooms that sound like rooms.** Separate room tones for each room, a low-pass when a sound
   comes from behind a closed door, and reverb settings tuned per room (the existing reverb zones
   are placeholders).
3. **Music.**
   - Short stingers: clue found, deduction made, emblem revealed.
   - A theme for each ghost: the Porter hums the house theme slightly flat; Pip gets a music box
     that keeps losing its place; the Host gets a pompous variation of the waltz.
   - Bar-synced transitions, so crossfades between rooms and Now/Then land on a downbeat.
   - A proper credits arrangement.
4. **Voices.** Three variants of every reaction bark per character, so the same "oh!" doesn't
   repeat. Whispered delivery for ghosts. Export every line with its ID to a CSV script, so real
   voice actors can be cast later through the existing VO hook (`assets/audio/vo/<line_id>.ogg`).
5. **Mix.** Dialogue-led scenes around -16 LUFS, music ducked under speech (done, retune), a
   master limiter, and a phone/handheld mix with less low end.

Done when: no interaction is silent; every room sounds different with your eyes closed; music
changes on the beat.

### 2.3 Look

1. **Character shading.** Test a soft toon ramp on characters so they sit better in the PBR rooms,
   and an anisotropic hair shader to replace the clay look.
2. **Particles.** Dust motes in the lantern beam, ghost trails, chandelier sparkles, rain splashes
   on the porch and puddles.
3. **Set dressing.** A clutter pass per room (books, letters, abandoned party favours), stain and
   cobweb decals, and the family portraits repainted from the Blender family models.
4. **UI.** Controller glyph images instead of text, page-turn animation in the Field Journal,
   illustrated map rooms, icons for collectibles.

### 2.4 Quality

- Colour-blind check of ghost colours and trace colours.
- Fix whatever human playtesters hit first (see Update 4.5); this list grows during the update.

---

## Update 3: Chapter Three, "The Endless Library" (the third chime)

### Story

After the second chime, a door "that wasn't there" opened above the hall. It leads to the library
wing. Theo Finch, the archive student from the Missing list, came here researching the Ashcombe
records and has been reading the same page for what he thinks is a minute.

The ghost is **Miss Eleanor Marsh**, the last name in the guest register, signed at 11:58 with the
ink still wet. She arrived late with something urgent for Edmund, found the house already holding
its breath, and hid in the library, where she has kept order ever since. She was the youngest
child's governess. She shushes. Noise makes the stacks rearrange themselves, which is why the
library is endless.

### New mechanics

1. **Noise.** Footsteps already know their surface. Wooden floors creak, carpet runners are
   silent, walking is quieter than running, a flare is loud. A noise ring on the HUD shows how
   much you're making. Miss Marsh patrols toward noise; if she reaches you, the stacks shuffle and
   you're sent back to the last reading lamp (no candle loss: it's a puzzle, not a punishment).
2. **Call numbers in lantern light.** Shelf codes appear only in the beam. They're the breadcrumb
   trail through the looping stacks.
3. **Mara can sing.** Now that she's playable, Mara gets one ability: hold a note to keep a ghost
   still for three seconds. Some routes need Avery's lantern, some need Mara's voice, and the
   wardrobe becomes the character switch.
4. **Now/Then in the library.** Now: collapsed shelves, damp-swollen books, a ceiling open to the
   rain. Then: lamplit, orderly, silent. Shelves knocked over in Then stay over in Now and open
   shortcuts.

### Puzzle

Find and reshelve three books, using call numbers revealed by the lantern:
1. Edmund's ledger, hidden on the top gallery, reached by the rolling ladder.
2. Celeste's star atlas, open in Then on a reading desk, and shut in Now.
3. The youngest's storybook, which only Mara can reach, by singing Miss Marsh still while the
   path is crossed.

Reshelving all three opens the reading room, where Theo sits frozen at a desk.

### Encounter: "Quiet, please"

A stealth sequence, not a fight. Miss Marsh walks a widening loop through the stacks, and the
player crosses the room to Theo using carpet runners, shelf cover and Mara's held note. The
encounter ends in a conversation: she reveals what she was bringing Edmund, a telegram from the
insurers. That's a new clue toward the Chapter One newspaper headline about the fire.

### Content list

- **Clues:** the register's 11:58 signature, the ledger's debts, Celeste's star chart, the
  insurers' telegram.
- **Deductions:** two new (the fire and the minute; Celeste knew), plus one that links back to
  Chapter Two.
- **Collectibles:** three documents, a portrait fragment, a music record, an emblem, and one
  new cheat code written in lantern light.
- **Achievements:** four (for example "Library Voice", "Shelved", "Not a Peep").
- **Characters:** Miss Marsh as a new ghost model (tall bun, pince-nez on a chain, a finger always
  half-raised to her lips, a ring of library keys); Theo's frozen and freed poses.
- **Room kit:** modular shelves, rolling ladders on brass rails, green-glass reading lamps, a card
  catalogue, a globe, a gallery walkway, and the reading room.
- **Audio:** a library arrangement of the waltz (harpsichord and pizzicato, very quiet), page
  turns, ladder rolls, shelf slides, the shush, Miss Marsh's voice profile.
- **Third chime.** The hall wardrobe offers Theo's outfit as a costume.

Done when: the automated playthrough covers Chapter Three end to end with no failures, and a
human tester can finish it without hints in about 30–45 minutes.

---

## Update 4: Tech

1. **Fast loading.** Build the rooms once at export time into packed `.scn` files instead of
   procedurally at every launch. Target under 10 seconds to the title. Stream each wing (load the
   ballroom while walking toward it).
2. **Rendering cost.**
   - Bake occluders for each room.
   - Generate LODs for props on import.
   - Merge more static meshes.
   - Check every preset on real GPUs: integrated Intel/AMD, a mid-range card, and a Steam Deck.
3. **Android.**
   - Profile on real phones (one Adreno, one Mali).
   - Hold 30 fps on the Low preset.
   - Test touch controls with people who didn't design them.
   - Ship as an Android App Bundle with Play Asset Delivery: the current 1.6 GB APK is far over
     Google Play's base-size limit.
4. **Shader stutter.** Use Godot's pipeline cache and ubershaders so first-time effects don't hitch.
5. **Automation (GitHub Actions).**
   - Delete the six web-deploy workflows that were added by mistake (Pages, Jekyll, Gatsby,
     Hugo, Nuxt, Next.js).
   - Add a `playtest` workflow: install Godot headless and Mesa lavapipe, import, run
     `src/dev/playtest.tscn`, and fail on any `!!` line or `SCRIPT ERROR`.
   - Add a `release` workflow on version tags: export all platforms and attach the builds.
     Split or zip anything over GitHub's 2 GB per-file limit, or upload to itch.io with butler
     instead.
6. **Code health.**
   - Split `story.gd` per chapter.
   - Move dialogue lines into data files (CSV/JSON) keyed by line ID, ready for localisation and
     the VO script.
   - Review every change with the code-review skill before merging.
7. **Save safety.** Tests for save migration between versions, and a CI check that the Midnight
   Code registry in `GameData.CODE_REGISTRY` is append-only.
8. **Localisation groundwork.** All UI and dialogue text through translation keys, starting with
   English.
9. **Playtest data.** An opt-in, local-only export of per-save stats (hints used, faints, time per
   objective) to CSV, so we can chart where people get stuck.

---

## Update 5: Release path

1. **itch.io demo first.** Free download for Windows, macOS, Linux and Android. Upload with butler,
   which handles large files and delta patches.
2. **Store materials.**
   - Capsule art from Blender renders of the cast.
   - A 90-second trailer cut from real-GPU gameplay and the beauty-shot tool.
   - Ten screenshots.
   - A short store description, written plainly.
   - A press kit page.
3. **Steam.**
   - Steamworks page (one-time fee) with "Coming soon" wishlists.
   - Achievements mapped 1:1 from `GameData.ACHIEVEMENTS` through GodotSteam.
   - Enter Next Fest with the demo once Chapter Three is in.
4. **Google Play.** Internal testing track first, using your own upload key (not the debug key) and
   the App Bundle from Update 4.
5. **macOS distribution.** Apple Developer account for signing and notarisation, so Gatekeeper
   doesn't block the app.
6. **Housekeeping.**
   - Include licence files for CC0 assets (credit Poly Haven), FluidR3 (MIT) and the OFL fonts.
   - Check the name for trademarks.
   - Age rating through IARC (itch.io and Google Play both use it).
   - A privacy note if the playtest export ever leaves the device.
7. **Community.** A devlog on itch.io, GitHub Issues with bug-report templates, and a feedback
   form linked from the title screen.

---

## Order and rough size

| Update | What | Rough size (Claude sessions of the scale of the slice build) |
| --- | --- | --- |
| 2 | Models and environments, then animation, sound, look polish | 4–6 |
| 4 (part) | CI playtest + fast loading, before new content lands | 1 |
| 3 | Chapter Three | 3–4 |
| 4 (rest) | Android, rendering, localisation groundwork | 1–2 |
| 5 | Release | depends on accounts (itch.io, Steam, Apple, Google Play) |

The fast-loading and CI work from Update 4 should go in before Chapter Three, so the new chapter is
tested on every push from day one.
