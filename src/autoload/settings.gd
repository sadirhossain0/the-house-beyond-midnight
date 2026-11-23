extends Node
## Player settings: graphics presets (Low / Medium / High / Ultra, console & handheld profiles,
## Custom, Auto), audio, controls, assistance, HUD and cheats. Persisted to user://settings.json.
## The settings menu is generated from SCHEMA.

const PATH := "user://settings.json"

const PRESETS := {
	"low": {
		"render_scale": 0.77, "upscaler": "fsr1", "dynamic_res": true, "min_scale": 0.55, "target_height": 0, "fps_cap": 30,
		"aa": "fxaa", "shadows": "low", "shadow_lights": 1, "gi": "off", "ssao": "off", "ssr": false, "volumetric_fog": "off",
		"bloom": true, "bloom_strength": 0.7, "tex_quality": "low", "aniso": 1, "detail": "near", "particles": 0.4,
		"mirrors": false, "color_grading": true, "vignette": true, "film_grain": false, "light_range": 0.6,
	},
	"medium": {
		"render_scale": 0.87, "upscaler": "fsr1", "dynamic_res": true, "min_scale": 0.65, "target_height": 0, "fps_cap": 60,
		"aa": "smaa", "shadows": "medium", "shadow_lights": 2, "gi": "off", "ssao": "low", "ssr": false, "volumetric_fog": "low",
		"bloom": true, "bloom_strength": 0.8, "tex_quality": "high", "aniso": 2, "detail": "medium", "particles": 0.7,
		"mirrors": false, "color_grading": true, "vignette": true, "film_grain": true, "light_range": 0.8,
	},
	"high": {
		"render_scale": 1.0, "upscaler": "fsr2", "dynamic_res": false, "min_scale": 0.75, "target_height": 0, "fps_cap": 60,
		"aa": "taa", "shadows": "high", "shadow_lights": 4, "gi": "ssil", "ssao": "high", "ssr": true, "volumetric_fog": "high",
		"bloom": true, "bloom_strength": 0.85, "tex_quality": "high", "aniso": 3, "detail": "far", "particles": 1.0,
		"mirrors": false, "color_grading": true, "vignette": true, "film_grain": true, "light_range": 1.0,
	},
	"ultra": {
		"render_scale": 1.0, "upscaler": "fsr2", "dynamic_res": false, "min_scale": 0.85, "target_height": 0, "fps_cap": 0,
		"aa": "taa", "shadows": "ultra", "shadow_lights": 8, "gi": "sdfgi", "ssao": "high", "ssr": true, "volumetric_fog": "high",
		"bloom": true, "bloom_strength": 0.9, "tex_quality": "ultra", "aniso": 4, "detail": "far", "particles": 1.5,
		"mirrors": true, "color_grading": true, "vignette": true, "film_grain": true, "light_range": 1.3,
	},
	# Console / handheld budgets so the game can be tuned (and pushed) before a licensed port.
	# Switch Lite: 1280x720 handheld, Tegra X1 at handheld clocks, 4 GB shared memory.
	"switchlite": {
		"render_scale": 1.0, "upscaler": "fsr1", "dynamic_res": true, "min_scale": 0.7, "target_height": 720, "fps_cap": 30,
		"aa": "fxaa", "shadows": "low", "shadow_lights": 1, "gi": "off", "ssao": "off", "ssr": false, "volumetric_fog": "off",
		"bloom": true, "bloom_strength": 0.75, "tex_quality": "low", "aniso": 1, "detail": "medium", "particles": 0.55,
		"mirrors": false, "color_grading": true, "vignette": true, "film_grain": false, "light_range": 0.7,
	},
	# PlayStation 4 (base): 1080p TV, 1.84 TFLOPS GCN, 8 GB GDDR5, slow Jaguar CPU.
	"ps4": {
		"render_scale": 1.0, "upscaler": "fsr1", "dynamic_res": true, "min_scale": 0.8, "target_height": 1080, "fps_cap": 30,
		"aa": "smaa", "shadows": "medium", "shadow_lights": 2, "gi": "off", "ssao": "low", "ssr": false, "volumetric_fog": "low",
		"bloom": true, "bloom_strength": 0.85, "tex_quality": "high", "aniso": 3, "detail": "far", "particles": 0.9,
		"mirrors": false, "color_grading": true, "vignette": true, "film_grain": true, "light_range": 0.9,
	},
	"steamdeck": {
		"render_scale": 1.0, "upscaler": "fsr2", "dynamic_res": true, "min_scale": 0.7, "target_height": 800, "fps_cap": 40,
		"aa": "taa", "shadows": "medium", "shadow_lights": 2, "gi": "off", "ssao": "low", "ssr": false, "volumetric_fog": "low",
		"bloom": true, "bloom_strength": 0.85, "tex_quality": "high", "aniso": 2, "detail": "medium", "particles": 0.8,
		"mirrors": false, "color_grading": true, "vignette": true, "film_grain": true, "light_range": 0.85,
	},
}

const CONSOLE_BUDGETS := {
	"switchlite": {"name": "Switch Lite (handheld)", "fps": 30, "draw_calls": 600, "primitives": 900000, "res": "1280x720", "vram_mb": 1500},
	"ps4": {"name": "PlayStation 4", "fps": 30, "draw_calls": 1500, "primitives": 3500000, "res": "1920x1080", "vram_mb": 4500},
	"steamdeck": {"name": "Steam Deck", "fps": 40, "draw_calls": 2000, "primitives": 4000000, "res": "1280x800", "vram_mb": 6000},
}

const EXPERIMENTAL_CHEATS := ["slowmo", "low_gravity", "ghost_vision", "extra_treasure", "unlocked_doors", "fleet_feet"]

var data: Dictionary = {}
var detected_preset := "medium"
var gpu_name := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = _defaults()
	_load()
	detected_preset = _detect()
	if data.graphics.preset == "auto":
		_apply_preset_values(detected_preset)
	apply_window()

func _defaults() -> Dictionary:
	var touch := DisplayServer.is_touchscreen_available() and OS.has_feature("mobile")
	var g: Dictionary = PRESETS.high.duplicate()
	g.merge({
		"preset": "auto", "resolved": "high", "window_mode": "fullscreen" if OS.has_feature("mobile") else "windowed", "vsync": true,
		"fov": 62.0, "brightness": 1.0, "gamma": 1.0, "camera_shake": true, "flashing": "reduced", "reduce_motion": false,
		"cosmetic_fx": true, "show_fps": false, "perf_overlay": false, "chromatic": false,
	}, true)
	return {
		"graphics": g,
		"audio": {"master": 0.85, "music": 0.7, "sfx": 0.85, "voice": 0.9, "ambience": 0.75, "ui": 0.7, "mono": false,
			"subtitles": true, "subtitle_size": "medium", "speaker_labels": true, "subtitle_bg": 0.6, "visual_cues": false},
		"controls": {"mouse_sens": 1.0, "invert_y": false, "invert_x": false, "lantern_mode": "hold", "focus_mode": "hold",
			"auto_camera": true, "pad_sens": 1.0, "vibration": true, "glyphs": "auto", "nintendo_layout": false, "deadzone": 0.15,
			"touch_controls": "on" if touch else "auto", "touch_scale": 1.0, "touch_opacity": 0.6, "bindings": {}},
		"assist": {"extra_candles": 0, "no_composure_loss": false, "ghost_aggression": "normal", "extended_timing": false,
			"infinite_lantern": false, "no_fall_damage": false, "clue_highlights": "normal", "objective_marker": false,
			"high_contrast": false, "stuck_hints": true, "puzzle_skip": true, "aim_assist": true},
		"hud": {"scale": 1.0, "safe_area": 0.0, "text_scale": 1.0, "candles": "auto", "tool": true, "prompts": true, "watch": true, "crosshair": true, "objective": true},
		"cheats": {"slowmo": false, "low_gravity": false, "ghost_vision": false, "extra_treasure": false, "unlocked_doors": false, "fleet_feet": false,
			"tiny": false, "big_head": false, "sunglasses": false, "disco": false, "party_decor": false, "ghost_costumes": false,
			"filter": "none", "silly_sfx": false, "squeaky_steps": false, "playful_voices": false},
		"unlocked_codes": [],
		"meta": {"first_run": true, "last_slot": 0, "language": "en"},
	}

func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_deep_merge(data, parsed)

func _deep_merge(dst: Dictionary, src: Dictionary) -> void:
	for k in src.keys():
		if dst.has(k) and dst[k] is Dictionary and src[k] is Dictionary:
			_deep_merge(dst[k], src[k])
		else:
			dst[k] = src[k]

func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))

func get_v(path: String) -> Variant:
	var parts := path.split(".")
	var d: Variant = data
	for p in parts:
		if d is Dictionary and d.has(p):
			d = d[p]
		else:
			return null
	return d

func set_v(path: String, value: Variant, silent := false) -> void:
	var parts := path.split(".")
	var d: Dictionary = data
	for i in parts.size() - 1:
		if not d.has(parts[i]):
			d[parts[i]] = {}
		d = d[parts[i]]
	var key := parts[parts.size() - 1]
	if d.get(key) == value:
		return
	d[key] = value
	if parts[0] == "graphics" and PRESETS.low.has(key) and not _applying_preset:
		data.graphics.preset = "custom"
	save()
	if not silent:
		_on_changed(path, value)

var _applying_preset := false

func apply_preset(name: String) -> void:
	var resolved := detected_preset if name == "auto" else name
	if PRESETS.has(resolved):
		_apply_preset_values(resolved)
	data.graphics.preset = name
	data.graphics.resolved = resolved
	save()
	_on_changed("graphics.preset", name)

func _apply_preset_values(name: String) -> void:
	_applying_preset = true
	for k in PRESETS[name].keys():
		data.graphics[k] = PRESETS[name][k]
	data.graphics.resolved = name
	_applying_preset = false

func reset_section(section: String) -> void:
	data[section] = _defaults()[section]
	save()
	_on_changed(section + ".*", null)

func _on_changed(path: String, value: Variant) -> void:
	if path.begins_with("graphics.window_mode") or path.begins_with("graphics.vsync") or path.begins_with("graphics.fps_cap") or path == "graphics.preset":
		apply_window()
	Events.settings_changed.emit(path, value)

func experimental_cheats_on() -> bool:
	for k in EXPERIMENTAL_CHEATS:
		if data.cheats.get(k, false):
			return true
	return false

func apply_window() -> void:
	var g: Dictionary = data.graphics
	Engine.max_fps = int(g.fps_cap)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if g.vsync else DisplayServer.VSYNC_DISABLED)
	if OS.has_feature("mobile") or DisplayServer.get_name() == "headless":
		return
	match String(g.window_mode):
		"fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		"exclusive": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _detect() -> String:
	gpu_name = RenderingServer.get_video_adapter_name()
	var r := gpu_name.to_lower()
	var vendor := RenderingServer.get_video_adapter_vendor().to_lower()
	var mem: float = OS.get_memory_info().get("physical", 8 * 1024 * 1024 * 1024) / (1024.0 * 1024 * 1024)
	var p := "medium"
	if OS.has_feature("mobile"):
		p = "low"
		if r.contains("adreno") and (r.contains("7") or r.contains("8")) and mem >= 6:
			p = "switchlite"
	elif r.contains("llvmpipe") or r.contains("swiftshader") or r.contains("software"):
		p = "low"
	elif r.contains("rtx") or r.contains("rx 7") or r.contains("rx 9") or r.contains("rx 6") or r.contains("arc a7") or r.contains("arc b"):
		p = "ultra"
	elif r.contains("geforce") or r.contains("radeon rx") or r.contains("radeon pro") or r.contains("apple m2") or r.contains("apple m3") or r.contains("apple m4") or r.contains("apple m5"):
		p = "high"
	elif r.contains("van gogh") or r.contains("steam deck"):
		p = "steamdeck"
	elif r.contains("apple m1") or r.contains("iris xe") or r.contains("780m") or r.contains("890m") or r.contains("680m") or vendor.contains("amd"):
		p = "medium"
	elif vendor.contains("intel"):
		p = "low"
	if mem < 6.0 and p in ["ultra", "high"]:
		p = "medium"
	return p

# ---------------------------------------------------------------------------------------------
# Settings menu schema. impact: rough GPU cost label shown beside each option.
# ---------------------------------------------------------------------------------------------
const ON_OFF := [[false, "Off"], [true, "On"]]

func schema() -> Dictionary:
	return {
		"Graphics": [
			{"path": "graphics.preset", "label": "Quality preset", "type": "select", "impact": "all",
				"options": [["auto", "Auto (detect: %s)" % detected_preset.capitalize()], ["low", "Low"], ["medium", "Medium"], ["high", "High"], ["ultra", "Ultra"],
					["switchlite", "Console profile: Switch Lite 720p"], ["ps4", "Console profile: PS4 1080p"], ["steamdeck", "Handheld: Steam Deck 800p"], ["custom", "Custom"]],
				"desc": "Sets every option below at once. Changing any single option switches to Custom. Console profiles emulate that hardware's resolution, frame rate and feature budget."},
			{"group": "Display"},
			{"path": "graphics.window_mode", "label": "Window mode", "type": "select", "options": [["windowed", "Windowed"], ["fullscreen", "Borderless fullscreen"], ["exclusive", "Exclusive fullscreen"]]},
			{"path": "graphics.vsync", "label": "V-Sync", "type": "toggle", "desc": "Prevents tearing. Turn off for lowest input latency."},
			{"path": "graphics.fps_cap", "label": "Frame rate limit", "type": "select", "impact": "saves", "options": [[30, "30 fps"], [40, "40 fps"], [60, "60 fps"], [120, "120 fps"], [0, "Unlimited"]],
				"desc": "30 or 60 keeps laptops, handhelds and phones cooler and saves battery."},
			{"path": "graphics.render_scale", "label": "Render resolution", "type": "range", "min": 0.5, "max": 1.5, "step": 0.05, "fmt": "pct", "impact": "high",
				"desc": "Renders the 3D scene at a fraction of the window size and upscales it. Above 100% supersamples for a cleaner image. The interface always stays sharp."},
			{"path": "graphics.upscaler", "label": "Upscaler", "type": "select", "impact": "medium", "options": [["bilinear", "Bilinear"], ["fsr1", "AMD FSR 1 (sharp, fast)"], ["fsr2", "AMD FSR 2 (temporal, best)"]],
				"desc": "How the lower-resolution image is scaled up. FSR 2 also anti-aliases."},
			{"path": "graphics.dynamic_res", "label": "Dynamic resolution", "type": "toggle", "impact": "saves",
				"desc": "Lowers resolution after a few slow seconds and recovers it when there is headroom, so the frame rate stays steady."},
			{"path": "graphics.min_scale", "label": "Dynamic resolution floor", "type": "range", "min": 0.5, "max": 1.0, "step": 0.05, "fmt": "pct"},
			{"path": "graphics.target_height", "label": "Internal resolution cap", "type": "select", "impact": "high",
				"options": [[0, "Native"], [540, "540p"], [720, "720p"], [800, "800p"], [900, "900p"], [1080, "1080p"], [1440, "1440p"]],
				"desc": "Never render the 3D scene taller than this. Console profiles use 720p (Switch Lite) and 1080p (PS4)."},
			{"path": "graphics.fov", "label": "Field of view", "type": "range", "min": 50, "max": 95, "step": 1, "fmt": "deg", "desc": "A wider view can reduce motion sickness."},
			{"path": "graphics.brightness", "label": "Brightness", "type": "range", "min": 0.6, "max": 1.8, "step": 0.05, "fmt": "x",
				"desc": "The house is meant to be dim but readable. Raise this if the corners are too dark on your screen."},
			{"group": "Lighting"},
			{"path": "graphics.shadows", "label": "Shadow quality", "type": "select", "impact": "high",
				"options": [["off", "Off"], ["low", "Low (lantern only)"], ["medium", "Medium"], ["high", "High (soft)"], ["ultra", "Ultra (4K, softest)"]]},
			{"path": "graphics.shadow_lights", "label": "Shadow-casting lamps", "type": "range", "min": 0, "max": 8, "step": 1, "fmt": "int", "impact": "high",
				"desc": "How many candles and lamps near you cast real shadows."},
			{"path": "graphics.light_range", "label": "Light draw distance", "type": "range", "min": 0.5, "max": 1.5, "step": 0.05, "fmt": "x", "impact": "medium"},
			{"path": "graphics.gi", "label": "Global illumination", "type": "select", "impact": "high",
				"options": [["off", "Off"], ["ssil", "Screen-space (SSIL)"], ["sdfgi", "SDFGI (bounced light everywhere)"]],
				"desc": "Light bouncing off walls and floors. SDFGI is the most realistic and the most demanding."},
			{"path": "graphics.volumetric_fog", "label": "Volumetric fog & moonbeams", "type": "select", "impact": "high",
				"options": [["off", "Off (painted beams)"], ["low", "Low"], ["high", "High"]],
				"desc": "Real light shafts through windows, lantern beams in the dust and ghostly mist."},
			{"path": "graphics.ssao", "label": "Ambient occlusion", "type": "select", "impact": "medium", "options": [["off", "Off"], ["low", "Low"], ["high", "High"]]},
			{"path": "graphics.ssr", "label": "Screen-space reflections", "type": "toggle", "impact": "high", "desc": "Polished floors and mirrors reflect the room."},
			{"path": "graphics.mirrors", "label": "Real-time mirrors", "type": "toggle", "impact": "high", "desc": "True reflections in the ballroom mirrors."},
			{"group": "Textures & detail"},
			{"path": "graphics.tex_quality", "label": "Texture quality", "type": "select", "impact": "memory",
				"options": [["low", "Low (1K)"], ["high", "High (2K)"], ["ultra", "Ultra (4K hero surfaces)"]], "desc": "Applies on the next room load."},
			{"path": "graphics.aniso", "label": "Anisotropic filtering", "type": "select", "impact": "low", "options": [[0, "Off"], [1, "2x"], [2, "4x"], [3, "8x"], [4, "16x"]]},
			{"path": "graphics.detail", "label": "Detail distance", "type": "select", "impact": "medium", "options": [["near", "Near"], ["medium", "Medium"], ["far", "Far"]]},
			{"path": "graphics.particles", "label": "Particles", "type": "range", "min": 0.25, "max": 1.5, "step": 0.05, "fmt": "pct", "impact": "medium",
				"desc": "Rain, dust motes, embers, confetti and ghost wisps."},
			{"group": "Post-processing"},
			{"path": "graphics.aa", "label": "Anti-aliasing", "type": "select", "impact": "medium",
				"options": [["off", "Off"], ["fxaa", "FXAA"], ["smaa", "SMAA"], ["taa", "TAA"], ["msaa2", "MSAA 2x"], ["msaa4", "MSAA 4x"], ["msaa8", "MSAA 8x"]]},
			{"path": "graphics.bloom", "label": "Bloom", "type": "toggle", "impact": "medium"},
			{"path": "graphics.bloom_strength", "label": "Bloom strength", "type": "range", "min": 0.0, "max": 1.5, "step": 0.05, "fmt": "x"},
			{"path": "graphics.color_grading", "label": "Colour grading", "type": "toggle", "desc": "Per-room palettes: deep greens, burgundy, midnight blue, amber."},
			{"path": "graphics.vignette", "label": "Vignette", "type": "toggle"},
			{"path": "graphics.film_grain", "label": "Film grain", "type": "toggle"},
			{"path": "graphics.chromatic", "label": "Lens fringing", "type": "toggle"},
			{"group": "Comfort"},
			{"path": "graphics.camera_shake", "label": "Camera shake", "type": "toggle"},
			{"path": "graphics.flashing", "label": "Flashing effects", "type": "select", "options": [["full", "Full"], ["reduced", "Reduced"], ["off", "Off"]],
				"desc": "Lightning and lantern-flare flashes."},
			{"path": "graphics.reduce_motion", "label": "Reduce motion", "type": "toggle", "desc": "Removes screen ripples, head bob and swirling transitions."},
			{"path": "graphics.cosmetic_fx", "label": "Costume effects", "type": "toggle"},
			{"path": "graphics.show_fps", "label": "Show FPS", "type": "toggle"},
			{"path": "graphics.perf_overlay", "label": "Performance budget overlay", "type": "toggle", "desc": "Frame time, draw calls and primitives against the selected console budget."},
		],
		"Audio": [
			{"path": "audio.master", "label": "Master volume", "type": "range", "min": 0, "max": 1, "step": 0.05, "fmt": "pct"},
			{"path": "audio.music", "label": "Music", "type": "range", "min": 0, "max": 1, "step": 0.05, "fmt": "pct"},
			{"path": "audio.sfx", "label": "Effects", "type": "range", "min": 0, "max": 1, "step": 0.05, "fmt": "pct"},
			{"path": "audio.voice", "label": "Voices", "type": "range", "min": 0, "max": 1, "step": 0.05, "fmt": "pct"},
			{"path": "audio.ambience", "label": "Ambience (rain, wind, clocks)", "type": "range", "min": 0, "max": 1, "step": 0.05, "fmt": "pct"},
			{"path": "audio.ui", "label": "Menu sounds", "type": "range", "min": 0, "max": 1, "step": 0.05, "fmt": "pct"},
			{"path": "audio.mono", "label": "Mono audio", "type": "toggle"},
			{"group": "Subtitles & cues"},
			{"path": "audio.subtitles", "label": "Subtitles", "type": "toggle"},
			{"path": "audio.subtitle_size", "label": "Subtitle size", "type": "select", "options": [["small", "Small"], ["medium", "Medium"], ["large", "Large"], ["xl", "Extra large"]]},
			{"path": "audio.speaker_labels", "label": "Speaker names", "type": "toggle"},
			{"path": "audio.subtitle_bg", "label": "Subtitle background", "type": "range", "min": 0, "max": 1, "step": 0.05, "fmt": "pct"},
			{"path": "audio.visual_cues", "label": "Visual sound cues", "type": "toggle", "desc": "On-screen markers point at important puzzle sounds and ghost tells."},
		],
		"Controls": [
			{"path": "controls.mouse_sens", "label": "Mouse sensitivity", "type": "range", "min": 0.2, "max": 3, "step": 0.05, "fmt": "x"},
			{"path": "controls.invert_y", "label": "Invert camera Y", "type": "toggle"},
			{"path": "controls.invert_x", "label": "Invert camera X", "type": "toggle"},
			{"path": "controls.lantern_mode", "label": "Reveal beam", "type": "select", "options": [["hold", "Hold"], ["toggle", "Toggle"]]},
			{"path": "controls.focus_mode", "label": "Focus / aim", "type": "select", "options": [["hold", "Hold"], ["toggle", "Toggle"]]},
			{"path": "controls.auto_camera", "label": "Camera follows movement", "type": "toggle", "desc": "Gently swings the camera behind you while walking."},
			{"path": "controls.pad_sens", "label": "Controller look speed", "type": "range", "min": 0.3, "max": 3, "step": 0.05, "fmt": "x"},
			{"path": "controls.deadzone", "label": "Stick deadzone", "type": "range", "min": 0.05, "max": 0.4, "step": 0.01, "fmt": "pct"},
			{"path": "controls.vibration", "label": "Vibration", "type": "toggle"},
			{"path": "controls.glyphs", "label": "Button prompts", "type": "select",
				"options": [["auto", "Auto (detect)"], ["keyboard", "Keyboard & mouse"], ["xbox", "Xbox"], ["playstation", "PlayStation"], ["nintendo", "Nintendo"]]},
			{"path": "controls.nintendo_layout", "label": "Nintendo confirm layout", "type": "toggle", "desc": "Confirm with the right face button (A), back with the bottom one (B), as on Switch."},
			{"group": "Touch"},
			{"path": "controls.touch_controls", "label": "Touch controls", "type": "select", "options": [["auto", "Auto"], ["on", "On"], ["off", "Off"]]},
			{"path": "controls.touch_scale", "label": "Touch button size", "type": "range", "min": 0.7, "max": 1.5, "step": 0.05, "fmt": "x"},
			{"path": "controls.touch_opacity", "label": "Touch button opacity", "type": "range", "min": 0.2, "max": 1, "step": 0.05, "fmt": "pct"},
			{"group": "Key bindings"},
			{"type": "bindings"},
		],
		"Assistance": [
			{"note": "Assistance options are settings, not cheats. They never affect achievements, completion or rewards, and you can change them at any time."},
			{"path": "assist.extra_candles", "label": "Extra composure candles", "type": "range", "min": 0, "max": 4, "step": 1, "fmt": "int"},
			{"path": "assist.no_composure_loss", "label": "No composure loss", "type": "toggle"},
			{"path": "assist.ghost_aggression", "label": "Ghost aggression", "type": "select", "options": [["normal", "Normal"], ["reduced", "Reduced"], ["none", "Gentle (no attacks)"]]},
			{"path": "assist.extended_timing", "label": "Extended timing windows", "type": "toggle", "desc": "More time for rhythm steps, timed puzzles and boss tells."},
			{"path": "assist.infinite_lantern", "label": "Infinite lantern charge", "type": "toggle"},
			{"path": "assist.no_fall_damage", "label": "No fall damage", "type": "toggle"},
			{"path": "assist.aim_assist", "label": "Flare aim assist", "type": "toggle"},
			{"path": "assist.clue_highlights", "label": "Clue highlights", "type": "select", "options": [["off", "Off"], ["normal", "Normal"], ["strong", "Strong"]]},
			{"path": "assist.objective_marker", "label": "Objective marker", "type": "toggle"},
			{"path": "assist.high_contrast", "label": "High-contrast clue mode", "type": "toggle", "desc": "Clues and hidden traces use bold outlines and shape icons, never colour alone."},
			{"path": "assist.stuck_hints", "label": "Offer hints when stuck", "type": "toggle", "desc": "After a while without progress the Field Guide quietly offers a nudge. It never shows a solution unless you ask."},
			{"path": "assist.puzzle_skip", "label": "Allow puzzle skip", "type": "toggle", "desc": "After reading a full solution hint you may skip that puzzle. No penalty."},
		],
		"Interface": [
			{"path": "hud.scale", "label": "HUD scale", "type": "range", "min": 0.75, "max": 1.6, "step": 0.05, "fmt": "x"},
			{"path": "hud.text_scale", "label": "Menu text size", "type": "range", "min": 0.85, "max": 1.5, "step": 0.05, "fmt": "x", "desc": "Larger text helps on small handheld screens."},
			{"path": "hud.safe_area", "label": "TV safe area", "type": "range", "min": 0, "max": 0.1, "step": 0.01, "fmt": "pct", "desc": "Keeps the HUD away from screen edges on TVs that crop the picture."},
			{"path": "hud.candles", "label": "Composure candles", "type": "select", "options": [["auto", "When needed"], ["always", "Always"], ["hidden", "Hidden"]]},
			{"path": "hud.tool", "label": "Tool icon", "type": "toggle"},
			{"path": "hud.watch", "label": "Watch face (Now / Then)", "type": "toggle"},
			{"path": "hud.prompts", "label": "Interaction prompts", "type": "toggle"},
			{"path": "hud.crosshair", "label": "Focus reticle", "type": "toggle"},
			{"path": "hud.objective", "label": "Objective ticker", "type": "toggle"},
		],
	}
