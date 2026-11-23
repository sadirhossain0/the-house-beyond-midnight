extends Node
## Audio director: adaptive music stems (AudioStreamSynchronized), layered ambience, positional
## sound effects with variations, room acoustics, and character "voices" built from per-character
## syllable banks. All audio is pre-rendered offline by tools/audio/*.py.

const MUSIC_DIR := "res://assets/audio/music/"
const SFX_DIR := "res://assets/audio/sfx/"
const AMB_DIR := "res://assets/audio/amb/"
const VOICE_DIR := "res://assets/audio/voice/"

## Track definitions: stems are mixed in sync; `mix` gives the default stem volumes (linear 0..1).
const TRACKS := {
	"title": {"stems": ["title_base", "title_choir"], "mix": [1.0, 0.8]},
	"exterior": {"stems": ["exterior_drone"], "mix": [1.0]},
	"hall": {"stems": ["hall_base", "hall_layer1", "hall_layer2"], "mix": [1.0, 0.0, 0.0]},
	"corridor": {"stems": ["corridor_base", "corridor_tension"], "mix": [1.0, 0.0]},
	"ballroom": {"stems": ["waltz_now_missing", "waltz_now_complete", "waltz_then_missing", "waltz_then_complete"], "mix": [1.0, 0.0, 0.0, 0.0]},
	"boss": {"stems": ["boss_base", "boss_intensity1", "boss_intensity2"], "mix": [1.0, 0.0, 0.0]},
	"lastdance": {"stems": ["lastdance"], "mix": [1.0]},
	"echo": {"stems": ["echo_shimmer"], "mix": [1.0]},
	"victory": {"stems": ["victory"], "mix": [1.0], "loop": false},
	"balcony": {"stems": ["balcony_night"], "mix": [1.0]},
	"credits": {"stems": ["credits_song"], "mix": [1.0], "loop": false},
}
const AMBIENCE := ["rain_out", "rain_in", "wind", "room_tone", "clock_ticks", "fire", "drips", "night_garden"]
const VOICES := {
	"avery": {"pitch": 1.0, "rate": 1.0}, "mara": {"pitch": 1.0, "rate": 1.08}, "porter": {"pitch": 1.0, "rate": 0.8},
	"pip": {"pitch": 1.0, "rate": 1.45}, "host": {"pitch": 1.0, "rate": 0.95}, "edmund": {"pitch": 1.0, "rate": 0.75}, "guide": {"pitch": 1.0, "rate": 1.15},
}

var _music_players: Array[AudioStreamPlayer] = []
var _music_active := 0
var current_track := ""
var _track_stream: AudioStreamSynchronized
var _stem_target: Array = []
var _stem_current: Array = []
var _amb_players := {}
var _amb_target := {}
var _sfx_cache := {}
var _voice_banks := {}
var _voice_a: AudioStreamPlayer
var _voice_b: AudioStreamPlayer
var _voice_queue: Array = []
var _voice_timer := 0.0
var _voice_flip := false
var _voice_char := ""
var talking := false
var world_root: Node3D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var p := AudioStreamPlayer.new(); p.bus = &"Music"; p.volume_db = -80.0; add_child(p); _music_players.append(p)
	for a in AMBIENCE:
		var p := AudioStreamPlayer.new(); p.bus = &"Ambience"; p.volume_db = -80.0; add_child(p)
		var s: AudioStream = _load(AMB_DIR + a + ".ogg")
		if s:
			if s is AudioStreamOggVorbis: s.loop = true
			p.stream = s
			p.play()
		_amb_players[a] = p
		_amb_target[a] = 0.0
	_voice_a = AudioStreamPlayer.new(); _voice_a.bus = &"Voice"; add_child(_voice_a)
	_voice_b = AudioStreamPlayer.new(); _voice_b.bus = &"Voice"; add_child(_voice_b)
	apply_volumes()
	Events.settings_changed.connect(func(p, _v): if String(p).begins_with("audio"): apply_volumes())

func _load(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		return load(path) as AudioStream
	return null

func apply_volumes() -> void:
	var a: Dictionary = Settings.data.audio
	var set_bus := func(name: String, lin: float) -> void:
		var idx := AudioServer.get_bus_index(name)
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(lin, 0.0001)))
			AudioServer.set_bus_mute(idx, lin <= 0.001)
	set_bus.call("Master", a.master)
	set_bus.call("Music", a.music * 0.8)
	set_bus.call("SFX", a.sfx)
	set_bus.call("Voice", a.voice)
	set_bus.call("Ambience", a.ambience * 0.85)
	set_bus.call("UI", a.ui)
	# mono: a stereo enhancer with no pan pull-out collapses the mix to mono
	var m := AudioServer.get_bus_index("Master")
	var has_mono := AudioServer.get_bus_effect_count(m) > 1
	if a.mono and not has_mono:
		var e := AudioEffectStereoEnhance.new(); e.pan_pullout = 0.0
		AudioServer.add_bus_effect(m, e, 0)
	elif not a.mono and has_mono:
		AudioServer.remove_bus_effect(m, 0)

# ------------------------------------------------------------------------------------ music
func play_music(track: String, fade := 2.5) -> void:
	if track == current_track: return
	current_track = track
	var old := _music_players[_music_active]
	_music_active = 1 - _music_active
	var p := _music_players[_music_active]
	var tw := create_tween().set_parallel(true)
	tw.tween_property(old, "volume_db", -80.0, fade).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(old.stop)
	if track == "" or not TRACKS.has(track):
		return
	var def: Dictionary = TRACKS[track]
	var sync := AudioStreamSynchronized.new()
	sync.stream_count = def.stems.size()
	_stem_target = []
	_stem_current = []
	for i in def.stems.size():
		var s: AudioStream = _load(MUSIC_DIR + def.stems[i] + ".ogg")
		if s is AudioStreamOggVorbis: s.loop = def.get("loop", true)
		sync.set_sync_stream(i, s)
		sync.set_sync_stream_volume(i, linear_to_db(maxf(def.mix[i], 0.0001)))
		_stem_target.append(def.mix[i]); _stem_current.append(def.mix[i])
	_track_stream = sync
	p.stream = sync
	p.volume_db = -40.0
	p.play()
	var tw2 := create_tween()
	tw2.tween_property(p, "volume_db", 0.0, fade).set_trans(Tween.TRANS_SINE)

## Fade a stem of the current track toward a linear volume (used for layers, Now/Then, intensity).
## Seconds into the current music track (for rhythm sections), compensated for output latency.
func music_position() -> float:
	if _music_players.is_empty(): return 0.0
	var p: AudioStreamPlayer = _music_players[_music_active]
	if not p.playing: return 0.0
	return p.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()

func set_stem(index: int, volume: float) -> void:
	if index < _stem_target.size(): _stem_target[index] = volume

func set_stems(vols: Array) -> void:
	for i in vols.size(): set_stem(i, vols[i])

func music_duck(amount_db := -8.0, seconds := 0.6) -> void:
	var p := _music_players[_music_active]
	var tw := create_tween()
	tw.tween_property(p, "volume_db", amount_db, 0.25)
	tw.tween_interval(seconds)
	tw.tween_property(p, "volume_db", 0.0, 1.2)

func set_music_muffle(on: bool) -> void:
	var idx := AudioServer.get_bus_index("Music")
	var lp := AudioServer.get_bus_effect(idx, 1) as AudioEffectLowPassFilter
	if lp:
		create_tween().tween_property(lp, "cutoff_hz", 900.0 if on else 20000.0, 0.8)

# ------------------------------------------------------------------------------------ ambience
func set_ambience(levels: Dictionary) -> void:
	for k in AMBIENCE: _amb_target[k] = float(levels.get(k, 0.0))

func set_acoustics(room_size: float, wet: float, damping := 0.45) -> void:
	for bus in ["SFX", "Voice"]:
		var idx := AudioServer.get_bus_index(bus)
		var r := AudioServer.get_bus_effect(idx, 0) as AudioEffectReverb
		if r:
			r.room_size = room_size; r.damping = damping
			create_tween().tween_property(r, "wet", wet * (0.6 if bus == "Voice" else 1.0), 0.6)

func _process(dt: float) -> void:
	for k in _amb_players.keys():
		var p: AudioStreamPlayer = _amb_players[k]
		var target := linear_to_db(maxf(_amb_target[k], 0.0001))
		p.volume_db = lerpf(p.volume_db, target, minf(1.0, dt * 1.2))
	if _track_stream:
		for i in _stem_target.size():
			_stem_current[i] = lerpf(_stem_current[i], _stem_target[i], minf(1.0, dt * 0.9))
			_track_stream.set_sync_stream_volume(i, linear_to_db(maxf(_stem_current[i], 0.0001)))
	_update_voice(dt)

# ------------------------------------------------------------------------------------ effects
func _variants(name: String) -> Array:
	if _sfx_cache.has(name): return _sfx_cache[name]
	var list := []
	var single: AudioStream = _load(SFX_DIR + name + ".wav")
	if single: list.append(single)
	for i in range(1, 9):
		var s: AudioStream = _load(SFX_DIR + "%s_%d.wav" % [name, i])
		if s: list.append(s)
		elif i > 1: break
	_sfx_cache[name] = list
	return list

## Play a sound effect. pos: Vector3 for positional (null = 2D). opts: vol (db), pitch, cue (label), bus, range.
func sfx(name: String, pos: Variant = null, opts := {}) -> void:
	var cheats: Dictionary = Settings.data.cheats
	var list := _variants(name)
	if list.is_empty(): return
	var stream: AudioStream = list[_rng.randi() % list.size()]
	var pitch: float = opts.get("pitch", 1.0) * _rng.randf_range(0.94, 1.06)
	if cheats.silly_sfx: pitch *= 1.4
	var vol: float = opts.get("vol", 0.0)
	if opts.has("cue") and Settings.data.audio.visual_cues and pos is Vector3:
		Events.sound_cue.emit(pos, opts.cue)
	if pos is Vector3 and world_root and is_instance_valid(world_root):
		var p := AudioStreamPlayer3D.new()
		p.stream = stream; p.bus = opts.get("bus", &"SFX"); p.pitch_scale = pitch; p.volume_db = vol
		p.unit_size = opts.get("range", 6.0); p.max_distance = opts.get("max", 60.0)
		p.attenuation_filter_cutoff_hz = 6000.0; p.attenuation_filter_db = -12.0
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		world_root.add_child(p)
		p.global_position = pos
		p.finished.connect(p.queue_free)
		p.play()
	else:
		var p2 := AudioStreamPlayer.new()
		p2.stream = stream; p2.bus = opts.get("bus", &"SFX"); p2.pitch_scale = pitch; p2.volume_db = vol
		add_child(p2)
		p2.finished.connect(p2.queue_free)
		p2.play()

func ui(name: String) -> void:
	sfx("ui_" + name, null, {"bus": &"UI"})

func step(surface: String, pos: Vector3) -> void:
	if Settings.data.cheats.squeaky_steps:
		sfx("squeak", pos, {"vol": -6.0}); return
	sfx("step_" + surface, pos, {"vol": -3.0, "range": 4.0})

# ------------------------------------------------------------------------------------ voices
func _bank(char_id: String) -> Array:
	if _voice_banks.has(char_id): return _voice_banks[char_id]
	var list := []
	for i in 64:
		var s: AudioStream = _load(VOICE_DIR + "%s/syl_%02d.wav" % [char_id, i])
		if s == null: break
		list.append(s)
	_voice_banks[char_id] = list
	return list

## A short non-verbal reaction (hm, oh!, gasp, laugh, sigh...).
func react(char_id: String, kind: String) -> void:
	var s: AudioStream = _load(VOICE_DIR + "%s/react_%s.wav" % [char_id, kind])
	if s == null: return
	var p := AudioStreamPlayer.new(); p.stream = s; p.bus = &"Voice"; add_child(p)
	if Settings.data.cheats.playful_voices: p.pitch_scale = 1.35
	p.finished.connect(p.queue_free); p.play()

## Speak `text` in the character's vocal language. Returns an estimated duration in seconds.
## The same line always produces the same sounds (syllables are picked from the letters).
func speak(char_id: String, text: String, line_id := "") -> float:
	# a recorded performance always wins if one is present for this line
	if line_id != "":
		var vo: AudioStream = _load("res://assets/audio/vo/%s.ogg" % line_id)
		if vo:
			_voice_a.stream = vo; _voice_a.pitch_scale = 1.0; _voice_a.play(); talking = true
			_voice_queue.clear(); _voice_timer = vo.get_length()
			return vo.get_length()
	var bank := _bank(char_id)
	_voice_queue.clear()
	_voice_char = char_id
	var v: Dictionary = VOICES.get(char_id, VOICES.avery)
	var words := text.split(" ", false)
	var total := 0.0
	var h := 0
	var count := 0
	for wi in words.size():
		var w: String = words[wi]
		var syl := clampi(int(round(w.length() / 3.0)), 1, 3)
		for si in syl:
			h = (h * 31 + w.unicode_at(si % w.length()) + wi * 7 + si) & 0x7fffffff
			var idx := h % maxi(bank.size(), 1)
			# intonation: declines across the sentence, rises on questions, lifts on exclamations
			var t := float(count) / maxf(1.0, text.length() / 3.0)
			var pitch: float = 1.0 + 0.06 * sin(float(h % 17)) - 0.06 * t
			if w.ends_with("?") and si == syl - 1: pitch += 0.12
			if w.ends_with("!"): pitch += 0.06
			if Settings.data.cheats.playful_voices: pitch *= 1.35
			var dur: float = 0.11 / v.rate
			if bank.size() > 0: dur = bank[idx].get_length() * 0.78 / (pitch * v.rate)
			_voice_queue.append({"idx": idx, "pitch": pitch * v.rate, "gap": dur})
			total += dur
			count += 1
		var pause := 0.035
		if w.ends_with(",") or w.ends_with(";"): pause = 0.16
		elif w.ends_with(".") or w.ends_with("!") or w.ends_with("?") or w.ends_with("…"): pause = 0.28
		_voice_queue.append({"idx": -1, "gap": pause / v.rate})
		total += pause / v.rate
		if count > 40: break
	_voice_timer = 0.0
	talking = true
	return total

func stop_voice() -> void:
	_voice_queue.clear(); _voice_a.stop(); _voice_b.stop(); talking = false

func _update_voice(dt: float) -> void:
	if not talking: return
	_voice_timer -= dt
	if _voice_timer > 0.0: return
	if _voice_queue.is_empty():
		if not _voice_a.playing and not _voice_b.playing: talking = false
		return
	var item: Dictionary = _voice_queue.pop_front()
	_voice_timer = item.gap
	if item.idx < 0: return
	var bank := _bank(_voice_char)
	if bank.is_empty(): return
	var p := _voice_a if _voice_flip else _voice_b
	_voice_flip = not _voice_flip
	p.stream = bank[item.idx]
	p.pitch_scale = item.pitch
	p.play()
