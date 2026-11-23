// Memory echoes seen through the Midnight Watch: warm sepia light, flickering like old film.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.85, 0.62, 1.0);
uniform float opacity = 0.8;
varying vec3 wpos;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; VERTEX.x += sin(wpos.y * 18.0 + TIME * 9.0) * 0.003; }
void fragment() {
	float f = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.6);
	float lines = step(0.5, fract(wpos.y * 28.0 - TIME * 2.0)) * 0.12;
	float flick = 0.82 + 0.18 * h(vec2(floor(TIME * 18.0), 1.0));
	ALBEDO = (color.rgb * (0.35 + f * 0.9) + lines) * flick * opacity;
	ALPHA = 1.0;
}
