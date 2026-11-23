class_name MaterialLib
extends RefCounted
## Shared materials for the estate. CC0 photoscanned PBR sets (Poly Haven) are loaded at the
## texture tier chosen in Settings (low 1K / high 2K / ultra 4K), mapped in world-space triplanar
## so every surface keeps a true real-world scale without UV work. Custom shaders add age.

const TEX := "res://assets/textures/"
const GEN := "res://assets/textures/generated/"

static var _cache := {}
static var _tex_cache := {}
static var tier := "high"

static func set_tier(t: String) -> void:
	if t == tier: return
	tier = t
	_tex_cache.clear()
	_cache.clear()

static func tex(set_name: String, map: String) -> Texture2D:
	var key := "%s/%s/%s" % [set_name, map, tier]
	if _tex_cache.has(key): return _tex_cache[key]
	var t: Texture2D = null
	for tr in [tier, "high", "low"]:
		for ext in ["jpg", "png"]:
			var p := "%s%s/%s_%s.%s" % [TEX, set_name, map, tr, ext]
			if ResourceLoader.exists(p):
				t = load(p); break
		if t: break
	_tex_cache[key] = t
	return t

static func gen(name: String) -> Texture2D:
	var p := GEN + name + ".png"
	if ResourceLoader.exists(p): return load(p)
	return null

## A standard PBR material from a CC0 set, world-triplanar.
static func pbr(set_name: String, tile: float, opts := {}) -> BaseMaterial3D:
	var m := ORMMaterial3D.new()
	m.albedo_texture = tex(set_name, "albedo")
	m.albedo_color = opts.get("tint", Color.WHITE)
	var n := tex(set_name, "normal")
	if n:
		m.normal_enabled = true; m.normal_texture = n; m.normal_scale = opts.get("normal", 1.0)
	var orm := tex(set_name, "orm")
	if orm: m.orm_texture = orm
	m.roughness = opts.get("rough", 1.0)
	m.metallic = opts.get("metal", 0.0)
	if not opts.get("uv", false):
		m.uv1_triplanar = true
		m.uv1_world_triplanar = not opts.get("local", false)
		m.uv1_triplanar_sharpness = 4.0
		m.uv1_scale = Vector3.ONE / tile
	else:
		m.uv1_scale = Vector3(opts.get("uv_scale", 1.0), opts.get("uv_scale", 1.0), 1.0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if opts.has("rim"):
		m.rim_enabled = true; m.rim = opts.rim; m.rim_tint = opts.get("rim_tint", 0.6)
	if opts.has("height") and Settings.data.graphics.resolved in ["high", "ultra"] and not opts.get("local", false):
		var h := tex(set_name, "height")
		if h:
			m.heightmap_enabled = true; m.heightmap_texture = h; m.heightmap_scale = opts.height; m.heightmap_deep_parallax = Settings.data.graphics.resolved == "ultra"
	return m

static func _shader(path: String) -> Shader:
	return load(path) as Shader

static func get_mat(name: String) -> Material:
	if _cache.has(name): return _cache[name]
	var m := _make(name)
	_cache[name] = m
	return m

static func _wallpaper(ground: Color, print_col: Color, stripe := Color(0, 0, 0, 0), damask := "damask_a", age := 0.6) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("res://src/fx/wallpaper.gdshader")
	m.set_shader_parameter("base_albedo", tex("decrepit_wallpaper", "albedo"))
	m.set_shader_parameter("base_normal", tex("decrepit_wallpaper", "normal"))
	m.set_shader_parameter("base_orm", tex("decrepit_wallpaper", "orm"))
	m.set_shader_parameter("damask", gen(damask))
	m.set_shader_parameter("ground_color", ground)
	m.set_shader_parameter("print_color", print_col)
	m.set_shader_parameter("stripe_color", stripe)
	m.set_shader_parameter("age", age)
	return m

static func _make(name: String) -> Material:
	match name:
		# ------------------------------------------------------------------ floors
		"marble_checker":
			var m := ShaderMaterial.new(); m.shader = _shader("res://src/fx/marble_checker.gdshader")
			m.set_shader_parameter("marble_albedo", tex("marble_01", "albedo"))
			m.set_shader_parameter("marble_normal", tex("marble_01", "normal"))
			m.set_shader_parameter("marble_orm", tex("marble_01", "orm"))
			return m
		"boards": return pbr("old_wooden_floor_02", 2.4, {"tint": Color(0.82, 0.72, 0.62), "height": 0.03})
		"boards_dark": return pbr("dark_wooden_planks", 2.4, {"tint": Color(0.9, 0.85, 0.8)})
		"parquet": return pbr("herringbone_parquet", 2.2, {"tint": Color(1.0, 0.93, 0.85), "rough": 0.7, "height": 0.02})
		"parquet_dusty":
			var p := pbr("herringbone_parquet", 2.2, {"tint": Color(0.62, 0.58, 0.54), "rough": 1.0})
			p.detail_enabled = false
			return p
		"stone_floor": return pbr("monastery_stone_floor", 2.6, {"tint": Color(0.75, 0.74, 0.72)})
		"slate_floor": return pbr("slate_floor", 2.0, {})
		"ground_grass":
			var g := ShaderMaterial.new(); g.shader = _shader("res://src/fx/ground.gdshader")
			g.set_shader_parameter("a_albedo", tex("leafy_grass", "albedo")); g.set_shader_parameter("a_normal", tex("leafy_grass", "normal")); g.set_shader_parameter("a_orm", tex("leafy_grass", "orm"))
			g.set_shader_parameter("b_albedo", tex("forest_leaves_02", "albedo")); g.set_shader_parameter("b_normal", tex("forest_leaves_02", "normal")); g.set_shader_parameter("b_orm", tex("forest_leaves_02", "orm"))
			g.set_shader_parameter("a_tile", 3.2); g.set_shader_parameter("b_tile", 2.6); g.set_shader_parameter("tint", Color(0.62, 0.66, 0.6)); g.set_shader_parameter("puddles", 0.15)
			return g
		"ground_gravel":
			var g2 := ShaderMaterial.new(); g2.shader = _shader("res://src/fx/ground.gdshader")
			g2.set_shader_parameter("a_albedo", tex("leaf_scattered_gravel", "albedo")); g2.set_shader_parameter("a_normal", tex("leaf_scattered_gravel", "normal")); g2.set_shader_parameter("a_orm", tex("leaf_scattered_gravel", "orm"))
			g2.set_shader_parameter("b_albedo", tex("gravel_floor_02", "albedo")); g2.set_shader_parameter("b_normal", tex("gravel_floor_02", "normal")); g2.set_shader_parameter("b_orm", tex("gravel_floor_02", "orm"))
			g2.set_shader_parameter("a_tile", 2.4); g2.set_shader_parameter("b_tile", 2.0); g2.set_shader_parameter("tint", Color(0.8, 0.78, 0.74)); g2.set_shader_parameter("puddles", 0.45)
			return g2
		# ------------------------------------------------------------------ walls
		"wall_green": return _wallpaper(Color(0.04, 0.28, 0.2), Color(0.12, 0.48, 0.34), Color(0, 0, 0, 0), "damask_a", 0.65)
		"wall_burgundy": return _wallpaper(Color(0.4, 0.04, 0.1), Color(0.6, 0.1, 0.18), Color(0.05, 0.0, 0.0, 0.35), "damask_b", 0.75)
		"wall_ochre": return _wallpaper(Color(0.6, 0.38, 0.1), Color(0.78, 0.55, 0.18), Color(0, 0, 0, 0), "damask_a", 0.7)
		"wall_cream": return _wallpaper(Color(0.74, 0.67, 0.52), Color(0.8, 0.68, 0.42), Color(0.62, 0.5, 0.25, 0.25), "damask_c", 0.4)
		"wall_blue": return _wallpaper(Color(0.06, 0.12, 0.38), Color(0.14, 0.26, 0.6), Color(0, 0, 0, 0), "damask_b", 0.6)
		"wainscot": return pbr("wooden_panels", 1.6, {"tint": Color(0.48, 0.32, 0.22), "height": 0.02})
		"plaster": return pbr("white_rough_plaster", 3.0, {"tint": Color(0.82, 0.78, 0.7)})
		"plaster_cracked": return pbr("worn_cracked_plaster", 3.0, {"tint": Color(0.8, 0.76, 0.68)})
		"plaster_moulding": return pbr("plastered_wall_04", 2.0, {"tint": Color(0.86, 0.82, 0.74)})
		"stone_facade":
			var s := ShaderMaterial.new(); s.shader = _shader("res://src/fx/wet_stone.gdshader")
			s.set_shader_parameter("albedo_tex", tex("large_sandstone_blocks", "albedo")); s.set_shader_parameter("normal_tex", tex("large_sandstone_blocks", "normal")); s.set_shader_parameter("orm_tex", tex("large_sandstone_blocks", "orm"))
			s.set_shader_parameter("tile", 3.4); s.set_shader_parameter("tint", Color(0.66, 0.66, 0.68))
			return s
		"stone_trim":
			var s2 := ShaderMaterial.new(); s2.shader = _shader("res://src/fx/wet_stone.gdshader")
			s2.set_shader_parameter("albedo_tex", tex("monastery_stone_floor", "albedo")); s2.set_shader_parameter("normal_tex", tex("monastery_stone_floor", "normal")); s2.set_shader_parameter("orm_tex", tex("monastery_stone_floor", "orm"))
			s2.set_shader_parameter("tile", 2.0); s2.set_shader_parameter("tint", Color(0.78, 0.77, 0.75)); s2.set_shader_parameter("moss", 0.25)
			return s2
		"slate_roof":
			var r := ShaderMaterial.new(); r.shader = _shader("res://src/fx/wet_stone.gdshader")
			r.set_shader_parameter("albedo_tex", tex("roof_slates_03", "albedo")); r.set_shader_parameter("normal_tex", tex("roof_slates_03", "normal")); r.set_shader_parameter("orm_tex", tex("roof_slates_03", "orm"))
			r.set_shader_parameter("tile", 2.6); r.set_shader_parameter("tint", Color(0.55, 0.57, 0.62)); r.set_shader_parameter("moss", 0.0); r.set_shader_parameter("wetness", 1.0)
			return r
		"brick": return pbr("castle_wall_slates", 2.2, {"tint": Color(0.7, 0.55, 0.5)})
		# ------------------------------------------------------------------ wood
		"mahogany": return pbr("fine_grained_wood", 1.2, {"tint": Color(0.62, 0.3, 0.2), "rough": 0.7})
		"walnut": return pbr("fine_grained_wood", 1.2, {"tint": Color(0.42, 0.28, 0.19), "rough": 0.75})
		"oak": return pbr("fine_grained_wood", 1.2, {"tint": Color(0.86, 0.7, 0.5)})
		"ebony": return pbr("fine_grained_wood", 1.2, {"tint": Color(0.16, 0.12, 0.1), "rough": 0.5})
		"rotten_wood": return pbr("dark_wooden_planks", 1.5, {"tint": Color(0.5, 0.47, 0.42)})
		"bark": return pbr("bark_willow", 1.6, {"tint": Color(0.22, 0.2, 0.19)})
		# ------------------------------------------------------------------ textiles
		"velvet_red": return pbr("velour_velvet", 0.7, {"tint": Color(0.78, 0.05, 0.14), "rim": 0.5, "rim_tint": 0.3})
		"velvet_green": return pbr("velour_velvet", 0.7, {"tint": Color(0.03, 0.45, 0.3), "rim": 0.5, "rim_tint": 0.3})
		"velvet_plum": return pbr("velour_velvet", 0.7, {"tint": Color(0.5, 0.1, 0.48), "rim": 0.5, "rim_tint": 0.3})
		"velvet_tattered": return pbr("velour_velvet", 0.7, {"tint": Color(0.32, 0.12, 0.13), "rim": 0.3})
		"jacquard": return pbr("quatrefoil_jacquard_fabric", 0.8, {"tint": Color(0.9, 0.8, 0.6)})
		"linen": return pbr("fabric_pattern_07", 0.8, {"tint": Color(0.92, 0.88, 0.8)})
		"dustsheet": return pbr("fabric_pattern_07", 1.0, {"tint": Color(0.78, 0.74, 0.66), "local": true})
		"leather": return pbr("brown_leather", 0.6, {"tint": Color(0.85, 0.7, 0.6)})
		"leather_red": return pbr("leather_red_02", 0.6, {})
		"carpet": return pbr("dirty_carpet", 1.0, {"tint": Color(0.7, 0.12, 0.2)})
		"runner":
			var rm := StandardMaterial3D.new(); rm.albedo_texture = gen("runner"); rm.normal_enabled = true; rm.normal_texture = tex("fabric_pattern_05", "normal")
			rm.roughness = 0.95; rm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			rm.uv1_triplanar = true; rm.uv1_world_triplanar = true; rm.uv1_scale = Vector3.ONE / 1.4
			return rm
		"rug_hall": return _decal_mat("rug_hall", 0.95)
		"rug_guest": return _decal_mat("rug_guest", 0.95)
		# ------------------------------------------------------------------ metals
		"gilt": return _metal(Color(0.86, 0.66, 0.32), 0.32, "metal_plate")
		"gilt_dull": return _metal(Color(0.55, 0.45, 0.3), 0.55, "metal_plate")
		"brass": return _metal(Color(0.8, 0.62, 0.32), 0.28, "")
		"brass_dark": return _metal(Color(0.45, 0.35, 0.2), 0.45, "")
		"silver": return _metal(Color(0.85, 0.85, 0.88), 0.2, "")
		"iron": return pbr("rusty_metal_02", 1.0, {"tint": Color(0.35, 0.33, 0.33), "metal": 0.6, "rough": 0.9})
		"chrome": return _metal(Color(0.92, 0.93, 0.95), 0.06, "")
		"mirror":
			var mm := StandardMaterial3D.new(); mm.albedo_color = Color(0.72, 0.76, 0.82); mm.metallic = 1.0; mm.roughness = 0.03; return mm
		"mirror_dusty":
			var md := StandardMaterial3D.new(); md.albedo_color = Color(0.45, 0.47, 0.5); md.metallic = 1.0; md.roughness = 0.32; return md
		# ------------------------------------------------------------------ glass & light
		"glass":
			var g3 := StandardMaterial3D.new(); g3.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; g3.albedo_color = Color(0.8, 0.88, 1.0, 0.18); g3.roughness = 0.04; g3.metallic = 0.0; g3.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX; return g3
		"crystal":
			var c := StandardMaterial3D.new(); c.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; c.albedo_color = Color(1, 1, 1, 0.5); c.roughness = 0.0; c.metallic = 0.3; c.emission_enabled = true; c.emission = Color(1.0, 0.9, 0.75); c.emission_energy_multiplier = 0.25; return c
		"window_night":
			# dark, rain-streaked night glass: reflective, with the faint blue of the storm outside
			var w := StandardMaterial3D.new(); w.albedo_color = Color(0.025, 0.04, 0.07); w.roughness = 0.04; w.metallic = 0.55
			w.emission_enabled = true; w.emission = Color(0.06, 0.1, 0.2); w.emission_energy_multiplier = 0.7; return w
		"window_lit":
			var wl := StandardMaterial3D.new(); wl.albedo_color = Color(1.0, 0.78, 0.45); wl.emission_enabled = true; wl.emission = Color(1.0, 0.66, 0.3); wl.emission_energy_multiplier = 2.4; return wl
		"window_dark":
			var wd := StandardMaterial3D.new(); wd.albedo_color = Color(0.02, 0.03, 0.05); wd.roughness = 0.06; wd.metallic = 0.5; wd.emission_enabled = true; wd.emission = Color(0.04, 0.07, 0.14); wd.emission_energy_multiplier = 0.5; return wd
		"lamp_glass":
			var lg := StandardMaterial3D.new(); lg.albedo_color = Color(1.0, 0.85, 0.55); lg.emission_enabled = true; lg.emission = Color(1.0, 0.7, 0.35); lg.emission_energy_multiplier = 3.0; return lg
		"green_glass":
			var gg := StandardMaterial3D.new(); gg.albedo_color = Color(0.15, 0.4, 0.28); gg.emission_enabled = true; gg.emission = Color(0.2, 1.0, 0.55); gg.emission_energy_multiplier = 0.8; gg.roughness = 0.1; return gg
		"clock_glow":
			var cg := StandardMaterial3D.new(); cg.albedo_color = Color(0.7, 1.0, 0.85); cg.emission_enabled = true; cg.emission = Color(0.3, 1.0, 0.65); cg.emission_energy_multiplier = 1.4; return cg
		"ember":
			var e := StandardMaterial3D.new(); e.albedo_color = Color(1.0, 0.35, 0.1); e.emission_enabled = true; e.emission = Color(1.0, 0.3, 0.06); e.emission_energy_multiplier = 3.0; return e
		"headlight":
			var h := StandardMaterial3D.new(); h.albedo_color = Color(1, 0.97, 0.86); h.emission_enabled = true; h.emission = Color(1.0, 0.94, 0.78); h.emission_energy_multiplier = 6.0; return h
		"taillight":
			var t := StandardMaterial3D.new(); t.albedo_color = Color(0.6, 0.05, 0.03); t.emission_enabled = true; t.emission = Color(1.0, 0.1, 0.05); t.emission_energy_multiplier = 2.0; return t
		# ------------------------------------------------------------------ misc
		"wax":
			var wx := StandardMaterial3D.new(); wx.albedo_color = Color(0.94, 0.9, 0.8); wx.roughness = 0.5; wx.subsurf_scatter_enabled = true; wx.subsurf_scatter_strength = 0.6; return wx
		"porcelain": return _plain(Color(0.95, 0.94, 0.9), 0.15)
		"black": return _plain(Color(0.02, 0.02, 0.025), 0.9)
		"paper": return pbr("fabric_pattern_07", 0.4, {"tint": Color(0.92, 0.86, 0.72)})
		"car_paint":
			var cp := StandardMaterial3D.new(); cp.albedo_color = Color(0.05, 0.35, 0.3); cp.metallic = 0.5; cp.roughness = 0.22; cp.clearcoat_enabled = true; cp.clearcoat = 1.0; cp.clearcoat_roughness = 0.05; return cp
		"tyre": return _plain(Color(0.04, 0.04, 0.045), 0.85)
		"puddle": return _plain(Color(0.01, 0.012, 0.016), 0.02)
		"hedge": return pbr("leafy_grass", 1.0, {"tint": Color(0.3, 0.4, 0.26)})
		"rubble": return pbr("rough_plaster_broken", 1.0, {"tint": Color(0.7, 0.67, 0.62), "local": true})
		"cake": return _plain(Color(0.96, 0.92, 0.86), 0.5)
		"cake_rotten": return _plain(Color(0.38, 0.38, 0.28), 0.95)
		"icing": return _plain(Color(0.94, 0.78, 0.82), 0.35)
		"star_inlay": return _decal_mat("star_inlay", 0.3, true)
		"mural":
			var mu := StandardMaterial3D.new(); mu.albedo_texture = gen("mural"); mu.emission_enabled = true; mu.emission_texture = gen("mural"); mu.emission = Color(1, 1, 1); mu.emission_energy_multiplier = 0.08; mu.roughness = 0.9; return mu
	push_warning("MaterialLib: unknown material '%s'" % name)
	return _plain(Color(1, 0, 1), 0.5)

static func _plain(c: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = rough; return m

static func _metal(c: Color, rough: float, set_name: String) -> BaseMaterial3D:
	var m := ORMMaterial3D.new()
	m.albedo_color = c; m.metallic = 1.0; m.roughness = rough
	if set_name != "":
		var orm := tex(set_name, "orm")
		if orm:
			m.orm_texture = orm; m.uv1_triplanar = true; m.uv1_world_triplanar = true; m.uv1_scale = Vector3.ONE / 0.6
	return m

static func _decal_mat(gen_name: String, rough: float, alpha := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = gen(gen_name)
	m.roughness = rough
	m.normal_enabled = true; m.normal_texture = tex("fabric_pattern_05", "normal"); m.normal_scale = 0.6
	m.uv2_scale = Vector3.ONE
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if alpha:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		m.normal_enabled = false
	return m

## A colour material for small parts (cached by value).
static func color(c: Color, rough := 0.8, metal := 0.0, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var key := "col:%s:%.2f:%.2f:%s:%.2f" % [c.to_html(), rough, metal, emission.to_html(), energy]
	if _cache.has(key): return _cache[key]
	var m := StandardMaterial3D.new(); m.albedo_color = c; m.roughness = rough; m.metallic = metal
	if energy > 0.0:
		m.emission_enabled = true; m.emission = emission; m.emission_energy_multiplier = energy
	_cache[key] = m
	return m
