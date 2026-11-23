// Hidden traces (writing, symbols, doorways) that appear only inside the Gloam Lantern's beam.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
global uniform vec3 lantern_pos;
global uniform vec3 lantern_dir;
global uniform float lantern_cos;
global uniform float lantern_range;
global uniform float lantern_beam;
global uniform float lantern_glow;
global uniform float ghost_vision;
global uniform float high_contrast;
uniform sampler2D mask : source_color, filter_linear_mipmap, hint_default_white;
uniform vec4 color : source_color = vec4(0.49, 1.0, 0.77, 1.0);
uniform float revealed = 0.0;
uniform float pulse = 0.0;
uniform float intensity = 2.2;
varying vec3 wpos;
float hh(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(hh(i), hh(i + vec2(1, 0)), f.x), mix(hh(i + vec2(0, 1)), hh(i + vec2(1, 1)), f.x), f.y); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec4 m = texture(mask, UV);
	vec3 d = wpos - lantern_pos;
	float dist = length(d);
	float c = dot(d / max(dist, 0.001), lantern_dir);
	float cone = smoothstep(lantern_cos, lantern_cos + 0.05, c) * (1.0 - smoothstep(lantern_range * 0.6, lantern_range, dist));
	float near = (1.0 - smoothstep(0.6, 2.2, dist)) * lantern_glow * 0.35;
	float vis = max(max(cone * lantern_beam, near), max(revealed, ghost_vision * 0.8));
	float shimmer = 0.7 + 0.3 * vn(UV * 9.0 + TIME * 0.7);
	vec3 col = color.rgb * shimmer * (intensity + pulse * 2.0);
	if (high_contrast > 0.5) col = vec3(1.0, 0.92, 0.2) * 2.5;
	float a = m.a * m.r * vis * (0.85 + 0.15 * sin(TIME * 4.0));
	ALBEDO = col * a;
	ALPHA = 1.0;
}
