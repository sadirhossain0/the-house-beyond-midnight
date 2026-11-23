// Black-and-white marble checker floor. Both tiles come from the same marble scan: the dark tile
// inverts it so the veins stay pale against black. Grout, scuffs and a worn path add age.
shader_type spatial;
#include "res://src/fx/triplanar.gdshaderinc"
uniform sampler2D marble_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D marble_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D marble_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_size = 0.9;
uniform float texture_scale = 2.4;
uniform vec4 light_tint : source_color = vec4(0.94, 0.91, 0.84, 1.0);
uniform vec4 dark_tint : source_color = vec4(0.035, 0.033, 0.04, 1.0);
uniform vec4 vein_tint : source_color = vec4(0.72, 0.66, 0.55, 1.0);
uniform float grout = 0.012;
uniform float wear = 0.5;
uniform float polish = 0.18;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	vec2 cell = floor(p / tile_size);
	vec2 f = fract(p / tile_size);
	float dark = mod(cell.x + cell.y, 2.0);
	// offset each tile's sample so neighbouring tiles look cut from different slabs
	vec2 uv = p / texture_scale + vec2(hash12(cell), hash12(cell + 9.1)) * 3.7;
	vec3 m = texture(marble_albedo, uv).rgb;
	float lum = dot(m, vec3(0.333));
	vec3 lightc = m * light_tint.rgb * 1.08;
	float vein = pow(clamp(1.0 - lum * 1.15, 0.0, 1.0), 1.6);
	vec3 darkc = mix(dark_tint.rgb, vein_tint.rgb, vein * 0.85);
	vec3 col = mix(lightc, darkc, dark);
	float gx = min(f.x, 1.0 - f.x), gy = min(f.y, 1.0 - f.y);
	float g = 1.0 - smoothstep(grout * 0.5, grout, min(gx, gy) * tile_size);
	col = mix(col, vec3(0.16, 0.14, 0.11), g * 0.9);
	float n = fbm2(p * 0.8);
	float path = (1.0 - smoothstep(0.6, 2.4, abs(p.x))) * wear;
	col *= 1.0 - smoothstep(0.55, 0.9, fbm2(p * 2.2 + 3.0)) * 0.12;
	ALBEDO = col;
	vec3 orm = texture(marble_orm, uv).rgb;
	ROUGHNESS = clamp(polish + orm.g * 0.25 + g * 0.6 + path * 0.25 * n + dark * 0.04, 0.05, 1.0);
	METALLIC = 0.0;
	AO = mix(orm.r, 0.4, g);
	SPECULAR = 0.6;
	NORMAL_MAP = texture(marble_normal, uv).rgb;
	NORMAL_MAP_DEPTH = 0.5 + g * 2.0;
}
