// Aged damask wallpaper: a scanned paper base, a tinted damask print, water stains, fading
// toward the ceiling, and grime collecting along the skirting.
shader_type spatial;
render_mode blend_mix, cull_back;
#include "res://src/fx/triplanar.gdshaderinc"
uniform sampler2D base_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D base_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D damask : hint_default_black, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 ground_color : source_color = vec4(0.12, 0.23, 0.17, 1.0);
uniform vec4 print_color : source_color = vec4(0.22, 0.38, 0.27, 1.0);
uniform vec4 stripe_color : source_color = vec4(0.0, 0.0, 0.0, 0.0);
uniform float tile = 1.6;
uniform float damask_tile = 0.9;
uniform float age = 0.6;
uniform float floor_y = 0.0;
varying vec3 wpos;
varying vec3 wnrm;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	float s = 1.0 / tile;
	vec3 base = tri_sample(base_albedo, wpos, wnrm, s, 4.0).rgb;
	float paper = dot(base, vec3(0.333));
	vec4 dm = tri_sample(damask, wpos, wnrm, 1.0 / damask_tile, 6.0);
	float pattern = dm.r;
	vec3 col = mix(ground_color.rgb, print_color.rgb, pattern * 0.85);
	vec2 along = abs(wnrm.x) > abs(wnrm.z) ? wpos.zy : wpos.xy;
	if (stripe_color.a > 0.0) col = mix(col, stripe_color.rgb, stripe_color.a * step(0.93, fract(along.x * 2.5)));
	col *= mix(0.65, 1.25, paper);
	float n = fbm2(along * 0.35);
	float stain = smoothstep(0.62, 0.78, fbm2(along * 0.22 + 7.3));
	col = mix(col, col * vec3(0.78, 0.66, 0.45), stain * age * 0.8);
	col = mix(col, col * 1.18, smoothstep(2.6, 6.0, wpos.y - floor_y) * 0.18 * age); // sun-faded up high
	float grime = (1.0 - smoothstep(0.0, 0.9, wpos.y - floor_y)) * age;
	col *= 1.0 - grime * 0.45 * (0.6 + 0.4 * n);
	ALBEDO = col;
	vec3 orm = tri_sample(base_orm, wpos, wnrm, s, 4.0).rgb;
	AO = orm.r; AO_LIGHT_AFFECT = 0.6;
	ROUGHNESS = clamp(orm.g * 0.7 + 0.35 - pattern * 0.12, 0.2, 1.0);
	METALLIC = 0.0;
	vec3 wn = tri_normal(base_normal, wpos, wnrm, s, 4.0, 0.6);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
