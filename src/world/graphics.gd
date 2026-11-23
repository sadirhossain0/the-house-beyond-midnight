class_name GraphicsController
extends Node
## Applies graphics settings to the viewport and environment, runs dynamic resolution, and builds
## per-room colour grading LUTs.

var viewport: Viewport
var env: Environment
var moon: DirectionalLight3D
var dyn_scale := 1.0
var _frame_times: Array[float] = []
var _timer := 0.0
var _slow := 0
var _fast := 0
var _lut_cache := {}

## Per-room palettes: lift (added to shadows), gain (multiplies highlights), saturation.
const GRADES := {
	"exterior": {"lift": Color(0.0, 0.014, 0.04), "gain": Color(1.02, 1.0, 1.06), "sat": 1.2},
	"hall": {"lift": Color(0.0, 0.03, 0.035), "gain": Color(1.12, 1.03, 0.9), "sat": 1.3},
	"corridor": {"lift": Color(0.03, 0.0, 0.035), "gain": Color(1.12, 0.98, 0.9), "sat": 1.32},
	"cloakroom": {"lift": Color(0.0, 0.035, 0.025), "gain": Color(1.08, 1.06, 0.9), "sat": 1.3},
	"guestroom": {"lift": Color(0.02, 0.0, 0.05), "gain": Color(1.1, 1.0, 1.02), "sat": 1.3},
	"ballroom_now": {"lift": Color(0.0, 0.025, 0.07), "gain": Color(0.98, 1.04, 1.16), "sat": 1.12},
	"ballroom_then": {"lift": Color(0.0, 0.005, 0.05), "gain": Color(1.06, 1.0, 0.95), "sat": 1.18},
	"balcony": {"lift": Color(0.0, 0.014, 0.045), "gain": Color(1.03, 1.0, 1.08), "sat": 1.2},
	"neutral": {"lift": Color(0, 0, 0), "gain": Color(1, 1, 1), "sat": 1.0},
}

func setup(p_viewport: Viewport, p_env: Environment, p_moon: DirectionalLight3D) -> void:
	viewport = p_viewport; env = p_env; moon = p_moon
	Events.settings_changed.connect(func(path, _v): if String(path).begins_with("graphics") or path == "graphics.*": apply())
	get_tree().root.size_changed.connect(_apply_scale)
	apply()

func apply() -> void:
	var g: Dictionary = Settings.data.graphics
	var mobile := RenderingServer.get_current_rendering_method() != "forward_plus"
	dyn_scale = minf(dyn_scale, g.render_scale) if g.dynamic_res else float(g.render_scale)
	viewport.scaling_3d_mode = {"bilinear": Viewport.SCALING_3D_MODE_BILINEAR, "fsr1": Viewport.SCALING_3D_MODE_FSR, "fsr2": Viewport.SCALING_3D_MODE_FSR2}.get(g.upscaler, Viewport.SCALING_3D_MODE_FSR)
	if mobile and viewport.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2: viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	if OS.has_feature("macos") and g.upscaler == "fsr2": viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_METALFX_TEMPORAL if not mobile else Viewport.SCALING_3D_MODE_FSR
	viewport.fsr_sharpness = 0.25
	var aa: String = g.aa
	viewport.msaa_3d = {"msaa2": Viewport.MSAA_2X, "msaa4": Viewport.MSAA_4X, "msaa8": Viewport.MSAA_8X}.get(aa, Viewport.MSAA_DISABLED)
	viewport.screen_space_aa = {"fxaa": Viewport.SCREEN_SPACE_AA_FXAA, "smaa": Viewport.SCREEN_SPACE_AA_SMAA}.get(aa, Viewport.SCREEN_SPACE_AA_DISABLED)
	viewport.use_taa = aa == "taa" and not mobile and g.upscaler != "fsr2"
	viewport.anisotropic_filtering_level = int(g.aniso)
	viewport.mesh_lod_threshold = {"near": 2.5, "medium": 1.5, "far": 1.0}.get(g.detail, 1.0)
	# shadows
	var sh: String = g.shadows
	var dsize: int = {"off": 1024, "low": 1024, "medium": 2048, "high": 4096, "ultra": 8192}.get(sh, 2048)
	RenderingServer.directional_shadow_atlas_set_size(dsize, true)
	var psize: int = {"off": 1024, "low": 2048, "medium": 2048, "high": 4096, "ultra": 8192}.get(sh, 4096)
	viewport.positional_shadow_atlas_size = psize
	var q: int = {"off": 0, "low": 1, "medium": 2, "high": 3, "ultra": 5}.get(sh, 2)
	RenderingServer.directional_soft_shadow_filter_set_quality(q)
	RenderingServer.positional_soft_shadow_filter_set_quality(q)
	if moon:
		moon.shadow_enabled = sh in ["medium", "high", "ultra"]
		moon.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if sh in ["high", "ultra"] else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	# environment features
	if env:
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.tonemap_exposure = g.brightness * 1.2
		env.tonemap_white = 6.0
		env.glow_enabled = g.bloom
		env.glow_intensity = 0.85 * g.bloom_strength
		env.glow_bloom = 0.07 * g.bloom_strength
		env.glow_hdr_threshold = 1.1
		env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		env.ssao_enabled = g.ssao != "off" and not mobile
		env.ssao_intensity = 1.6; env.ssao_radius = 0.9
		RenderingServer.environment_set_ssao_quality(1 if g.ssao == "low" else 3, g.ssao == "low", 0.5, 2, 50.0, 300.0)
		env.ssil_enabled = (g.gi == "ssil" or g.gi == "sdfgi") and not mobile
		env.ssil_intensity = 0.8
		RenderingServer.environment_set_ssil_quality(2, true, 0.5, 2, 50.0, 300.0)
		env.sdfgi_enabled = g.gi == "sdfgi" and not mobile
		env.sdfgi_use_occlusion = true; env.sdfgi_energy = 0.6; env.sdfgi_min_cell_size = 0.15
		env.ssr_enabled = g.ssr and not mobile
		env.ssr_max_steps = 48
		var vf: String = g.volumetric_fog
		env.volumetric_fog_enabled = vf != "off" and not mobile
		if vf == "high": RenderingServer.environment_set_volumetric_fog_volume_size(160, 128)
		else: RenderingServer.environment_set_volumetric_fog_volume_size(96, 64)
		RenderingServer.environment_set_volumetric_fog_filter_active(vf == "high")
		env.fog_enabled = vf == "off" or mobile  # cheap depth fog as the fallback
		env.adjustment_enabled = true
	_apply_scale()
	Events.graphics_applied.emit()

func _apply_scale() -> void:
	var g: Dictionary = Settings.data.graphics
	var s := dyn_scale
	var h := float(get_tree().root.size.y)
	if int(g.target_height) > 0 and h > 0.0:
		s = minf(s, float(g.target_height) / h)
	viewport.scaling_3d_scale = clampf(s, 0.25, 2.0)

## Dynamic resolution: step down after sustained slow frames, recover slowly (hysteresis).
func _process(dt: float) -> void:
	var g: Dictionary = Settings.data.graphics
	if not g.dynamic_res: return
	var real_dt := dt / maxf(Engine.time_scale, 0.01)
	_frame_times.append(real_dt * 1000.0)
	if _frame_times.size() > 90: _frame_times.pop_front()
	_timer += real_dt
	if _timer < 1.0: return
	_timer = 0.0
	var cap: int = int(g.fps_cap) if int(g.fps_cap) > 0 else 60
	var target := 1000.0 / cap
	var avg := 0.0
	for t in _frame_times: avg += t
	avg /= maxf(1.0, _frame_times.size())
	_slow = _slow + 1 if avg > target * 1.12 else 0
	_fast = _fast + 1 if avg < target * 0.85 else 0
	var before := dyn_scale
	if _slow >= 2:
		dyn_scale = maxf(float(g.min_scale), dyn_scale - 0.06); _slow = 0
	elif _fast >= 5:
		dyn_scale = minf(float(g.render_scale), dyn_scale + 0.03); _fast = 0
	if before != dyn_scale: _apply_scale()

## A 3D LUT that applies lift/gain/saturation grading (used by Environment colour correction).
func grade_lut(name: String) -> Texture3D:
	if _lut_cache.has(name): return _lut_cache[name]
	var gr: Dictionary = GRADES.get(name, GRADES.neutral)
	var size := 24
	var images: Array[Image] = []
	for b in size:
		var img := Image.create(size, size, false, Image.FORMAT_RGB8)
		for gg in size:
			for r in size:
				var c := Color(float(r) / (size - 1), float(gg) / (size - 1), float(b) / (size - 1))
				c = Color(c.r * gr.gain.r + gr.lift.r * (1.0 - c.r), c.g * gr.gain.g + gr.lift.g * (1.0 - c.g), c.b * gr.gain.b + gr.lift.b * (1.0 - c.b))
				var l := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
				c = Color(lerpf(l, c.r, gr.sat), lerpf(l, c.g, gr.sat), lerpf(l, c.b, gr.sat))
				img.set_pixel(r, gg, Color(clampf(c.r, 0, 1), clampf(c.g, 0, 1), clampf(c.b, 0, 1)))
		images.append(img)
	var tex := ImageTexture3D.new()
	tex.create(Image.FORMAT_RGB8, size, size, size, false, images)
	_lut_cache[name] = tex
	return tex

func set_grade(name: String) -> void:
	if env == null: return
	env.adjustment_color_correction = grade_lut(name) if Settings.data.graphics.color_grading else null

func stats() -> Dictionary:
	return {
		"fps": Engine.get_frames_per_second(),
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"vram_mb": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		"scale": viewport.scaling_3d_scale if viewport else 1.0,
	}
