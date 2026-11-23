extends Node
## Game state and progression for the active save profile.

var main: Node            # res://src/main.gd (screen flow)
var world: Node3D         # the running GameWorld, or null on the title screen
var in_game := false
var time_since_progress := 0.0
var hint_offered := false
var _play_acc := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.settings_changed.connect(_on_setting)
	apply_time_scale()

func _on_setting(path: String, _v: Variant) -> void:
	if path.begins_with("cheats"):
		apply_time_scale()
		if in_game: Save.profile.cheat_active = Settings.experimental_cheats_on()

func apply_time_scale() -> void:
	Engine.time_scale = 0.5 if Settings.data.cheats.slowmo else 1.0

var profile: Dictionary:
	get: return Save.profile

func _process(dt: float) -> void:
	if not in_game or get_tree().paused: return
	var real_dt := dt / maxf(Engine.time_scale, 0.01)
	Save.profile.play_time = float(Save.profile.get("play_time", 0.0)) + real_dt
	time_since_progress += real_dt
	if Settings.data.assist.stuck_hints and not hint_offered and time_since_progress > 210.0:
		hint_offered = true
		Events.toast.emit("The Field Guide has a thought, if you want it. Press %s for a hint." % Controls.label("hint"), "hint")

func progressed() -> void:
	time_since_progress = 0.0
	hint_offered = false

# ----------------------------------------------------------------------------- flags & objectives
func flag(k: String) -> bool: return bool(profile.flags.get(k, false))

func set_flag(k: String, v := true) -> void:
	profile.flags[k] = v
	progressed()

func objective() -> String: return String(profile.get("objective", ""))

func set_objective(id: String, announce := true) -> void:
	if profile.objective == id: return
	var prev := String(profile.objective)
	if prev != "" and not profile.objectives_done.has(prev): profile.objectives_done.append(prev)
	profile.objective = id
	var ch: int = GameData.OBJECTIVES.get(id, {}).get("chapter", profile.chapter)
	if ch > profile.chapter: profile.chapter = ch
	progressed()
	Events.objective_changed.emit(id)
	if announce: Events.toast.emit(GameData.OBJECTIVES.get(id, {}).get("text", ""), "objective")

func objective_text() -> String:
	var o: Dictionary = GameData.OBJECTIVES.get(objective(), {})
	var t: String = o.get("text", "")
	if o.get("counter", "") == "fragments":
		var n := 0
		for f in ["frag_moon", "frag_star", "frag_sun"]: if flag(f): n += 1
		t += " (%d/3)" % n
	return t

func hint(tier: int) -> String:
	var o: Dictionary = GameData.OBJECTIVES.get(objective(), {})
	var hs: Array = o.get("hints", [])
	if hs.is_empty(): return "Nothing to hint at right now. Explore!"
	tier = clampi(tier, 0, hs.size() - 1)
	var seen: Dictionary = profile.hints_seen
	var k := objective()
	if int(seen.get(k, -1)) < tier:
		seen[k] = tier
		profile.stats.hints_used = int(profile.stats.hints_used) + 1
	Events.hint_shown.emit(k, tier)
	return hs[tier]

# ----------------------------------------------------------------------------- journal
func add_clue(id: String, quiet := false) -> void:
	if profile.clues.has(id) or not GameData.CLUES.has(id): return
	profile.clues.append(id)
	progressed()
	Events.clue_added.emit(id)
	if not quiet:
		Events.toast.emit("Clue: " + GameData.CLUES[id].title, "clue")
		Audio.sfx("clue")

## Try to link two clues. Returns the deduction id, "" if the pair says nothing, or "known".
func deduce(a: String, b: String) -> String:
	for id in GameData.DEDUCTIONS.keys():
		var d: Dictionary = GameData.DEDUCTIONS[id]
		if (d.a == a and d.b == b) or (d.a == b and d.b == a):
			if profile.deductions.has(id): return "known"
			profile.deductions.append(id)
			progressed()
			Events.deduction_made.emit(id)
			Audio.sfx("deduce")
			unlock("its_about_time")
			if profile.deductions.size() == GameData.DEDUCTIONS.size(): unlock("deductive")
			return id
	return ""

# ----------------------------------------------------------------------------- collectibles
func collect(id: String) -> void:
	if profile.collectibles.has(id): return
	profile.collectibles.append(id)
	progressed()
	var c: Dictionary = GameData.COLLECTIBLES.get(id, {})
	Events.collectible_found.emit(id)
	Events.toast.emit(String(c.get("name", id)), "collect")
	Audio.sfx("pickup")
	if c.get("kind") == "record" and not profile.records.has(c.get("track", "")): profile.records.append(c.track)
	if c.get("kind") == "document":
		var clue: String = GameData.DOCUMENTS.get(id, {}).get("clue", "")
		if clue != "": add_clue(clue)
	if c.get("kind") == "emblem":
		var n := 0
		for e in ["em_corridor", "em_hall", "em_ballroom"]: if profile.collectibles.has(e): n += 1
		if n == 3:
			unlock_costume("avery", "lanternkeeper")
			unlock("lantern_keeper")
	if c.get("kind") == "portrait":
		var n2 := 0
		for e in ["pf_gallery", "pf_guest", "pf_balcony"]: if profile.collectibles.has(e): n2 += 1
		if n2 == 3: Events.toast.emit("Portrait restored: The Youngest Ashcombe", "collect")
	if profile.collectibles.size() == GameData.COLLECTIBLES.size(): unlock("curiosity")

func add_ghost_card(id: String) -> void:
	if profile.ghost_cards.has(id): return
	profile.ghost_cards.append(id)
	Events.toast.emit("Ghost card added to your Field Journal: %s" % Cast.BIOS.get(id, {}).get("title", id), "collect")
	if profile.ghost_cards.size() >= GameData.GHOST_CARDS.size(): unlock_costume("avery", "phantom")

func unlock_costume(character: String, costume: String) -> void:
	var key := "%s:%s" % [character, costume]
	if profile.unlocked_costumes.has(key): return
	profile.unlocked_costumes.append(key)
	var label: String = Cast.COSTUMES.get(character, {}).get(costume, {}).get("label", costume)
	Events.toast.emit("New outfit in the wardrobe: %s" % label, "costume")

# ----------------------------------------------------------------------------- achievements
func achievements_tracking() -> bool:
	return not Settings.experimental_cheats_on()

func unlock(id: String) -> void:
	if profile.is_empty() or profile.achievements.has(id) or not achievements_tracking(): return
	profile.achievements.append(id)
	Events.achievement_unlocked.emit(id)
	Audio.sfx("achievement", null, {"bus": &"UI"})

# ----------------------------------------------------------------------------- composure
func max_candles() -> int:
	return 4 + int(Settings.data.assist.extra_candles)
