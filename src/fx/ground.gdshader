// Rain-soaked ground: grass, fallen leaves and gravel blended by noise, with puddles that go
// dark and glossy. `wetness` follows the weather.
shader_type spatial;
#include "res://src/fx/triplanar.gdshaderinc"
uniform sampler2D a_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D a_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D a_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D b_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D b_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D b_orm : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float a_tile = 3.0;
uniform float b_tile = 2.5;
uniform float blend_scale = 0.08;
uniform float blend_bias = 0.0;
uniform float wetness = 0.85;
uniform float puddles = 0.35;
uniform vec4 tint : source_color = vec4(1.0);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	float m = smoothstep(0.42, 0.58, fbm2(p * blend_scale) + blend_bias);
	vec2 ua = p / a_tile, ub = p / b_tile;
	vec3 ca = texture(a_albedo, ua).rgb, cb = texture(b_albedo, ub).rgb;
	vec3 oa = texture(a_orm, ua).rgb, ob = texture(b_orm, ub).rgb;
	vec3 col = mix(ca, cb, m) * tint.rgb;
	vec3 orm = mix(oa, ob, m);
	float pud = smoothstep(0.66, 0.72, fbm2(p * 0.18 + 11.0)) * puddles;
	float wet = clamp(wetness * 0.7 + pud, 0.0, 1.0);
	col *= mix(1.0, 0.55, wet);
	ALBEDO = mix(col, vec3(0.02, 0.025, 0.03), pud);
	ROUGHNESS = mix(orm.g, 0.08, max(wet * 0.55, pud));
	AO = orm.r; METALLIC = 0.0;
	NORMAL_MAP = mix(mix(texture(a_normal, ua).rgb, texture(b_normal, ub).rgb, m), vec3(0.5, 0.5, 1.0), pud);
}
