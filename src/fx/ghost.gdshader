// Ghosts: a fresnel glow that brightens at the silhouette, gentle wobble, a tail that curls in the
// draught, faint scanlines like breath on glass.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_back, shadows_disabled;
global uniform float ghost_vision;
global uniform float disco;
uniform vec4 color : source_color = vec4(0.56, 0.91, 0.82, 1.0);
uniform vec4 rim : source_color = vec4(0.94, 1.0, 0.98, 1.0);
uniform float opacity = 0.82;
uniform float wobble = 1.0;
uniform float tail = 0.0;
uniform float flash = 0.0;
uniform float tail_top = 0.0;
uniform float tail_len = 0.9;
uniform float glow = 1.4;
varying vec3 wpos;
varying float ly;
void vertex() {
	ly = VERTEX.y;
	float t = TIME;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = tail * clamp((tail_top - VERTEX.y) / tail_len, 0.0, 1.0);
	VERTEX.x += sin(t * 2.1 + w.y * 3.0 + w.z * 1.3) * 0.012 * wobble + sin(t * 2.6 + VERTEX.y * 6.0) * 0.08 * k;
	VERTEX.z += cos(t * 1.7 + w.y * 2.6 + w.x * 1.1) * 0.012 * wobble + cos(t * 2.2 + VERTEX.y * 5.0) * 0.06 * k;
	wpos = w;
}
void fragment() {
	float f = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 2.2);
	float scan = 0.93 + 0.07 * sin(wpos.y * 46.0 - TIME * 3.0);
	vec3 col = mix(color.rgb * 0.9, rim.rgb, f) * scan * glow;
	col += flash * vec3(1.0, 0.95, 0.8) * 2.0;
	if (disco > 0.5) col *= 0.6 + 0.6 * (0.5 + 0.5 * vec3(sin(TIME * 3.0), sin(TIME * 3.0 + 2.1), sin(TIME * 3.0 + 4.2)));
	float a = (0.42 + f * 0.58) * opacity;
	float k = tail * clamp((tail_top - ly) / tail_len, 0.0, 1.0);
	a *= 1.0 - k * k;
	a = max(a, ghost_vision * 0.6);
	ALBEDO = col * (1.0 + ghost_vision);
	ALPHA = clamp(a, 0.0, 1.0);
}
