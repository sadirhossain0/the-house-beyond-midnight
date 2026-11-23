// Painted light shafts, used when volumetric fog is off (Low preset, Mobile renderer).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(0.62, 0.72, 1.0, 1.0);
uniform float intensity = 0.25;
varying vec3 wpos;
float hh(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(hh(i), hh(i + vec2(1, 0)), f.x), mix(hh(i + vec2(0, 1)), hh(i + vec2(1, 1)), f.x), f.y); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float edge = abs(dot(NORMAL, VIEW));
	float along = UV.y;
	float n = vn(vec2(wpos.x * 0.6 + TIME * 0.05, wpos.y * 0.4 - TIME * 0.03)) * 0.6 + 0.6;
	float a = intensity * pow(edge, 1.5) * smoothstep(0.0, 0.35, 1.0 - along) * (0.55 + 0.45 * (1.0 - along)) * n;
	ALBEDO = color.rgb * a;
	ALPHA = 1.0;
}
