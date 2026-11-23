// Facade stone and roof slate in the rain: streaks run down the walls, moss creeps up from the
// ground, and everything is glossier where the water sits.
shader_type spatial;
#include "res://src/fx/triplanar.gdshaderinc"
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile = 3.0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float wetness = 0.8;
uniform float moss = 0.5;
uniform float ground_y = -0.6;
varying vec3 wpos; varying vec3 wnrm;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	float s = 1.0 / tile;
	vec3 col = tri_sample(albedo_tex, wpos, wnrm, s, 4.0).rgb * tint.rgb;
	vec3 orm = tri_sample(orm_tex, wpos, wnrm, s, 4.0).rgb;
	vec2 along = abs(wnrm.x) > abs(wnrm.z) ? wpos.zy : wpos.xy;
	float streak = smoothstep(0.55, 0.8, vnoise(vec2(along.x * 6.0, along.y * 0.25))) * (1.0 - abs(wnrm.y));
	float h = wpos.y - ground_y;
	float mossy = (1.0 - smoothstep(0.0, 2.2, h + fbm2(along * 0.7) * 1.2)) * moss;
	col = mix(col, col * vec3(0.55, 0.7, 0.45), mossy);
	col *= 1.0 - streak * 0.35 * wetness;
	float wet = clamp(wetness * (0.45 + streak * 0.5 + wnrm.y * 0.3), 0.0, 1.0);
	ALBEDO = col * mix(1.0, 0.7, wet);
	ROUGHNESS = mix(orm.g, 0.18, wet);
	AO = orm.r; METALLIC = 0.0;
	vec3 wn = tri_normal(normal_tex, wpos, wnrm, s, 4.0, 1.0);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
