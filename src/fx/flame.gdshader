// Instanced candle flames (MultiMesh). INSTANCE_CUSTOM.x = seed, .y = lit (0/1), .z = scale.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
global uniform float disco;
uniform vec4 color : source_color = vec4(1.0, 0.62, 0.26, 1.0);
uniform float brightness = 3.0;
varying float seed;
varying float lit;
void vertex() {
	seed = INSTANCE_CUSTOM.x; lit = INSTANCE_CUSTOM.y;
	float flick = 1.0 + 0.12 * sin(TIME * 13.0 + seed * 40.0) + 0.08 * sin(TIME * 23.0 + seed * 17.0);
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
	vec3 center = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float s = INSTANCE_CUSTOM.z > 0.0 ? INSTANCE_CUSTOM.z : 1.0;
	vec3 p = center + right * VERTEX.x * s + up * VERTEX.y * s * flick * lit;
	p.x += sin(TIME * 3.0 + seed * 9.0) * 0.006 * VERTEX.y * 10.0;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(p, 1.0);
}
void fragment() {
	if (lit < 0.5) discard;
	vec2 p = UV * 2.0 - 1.0; float y = 1.0 - UV.y;
	float w = (1.0 - y) * 0.85 * sqrt(max(y, 0.0)) * 1.6;
	float d = abs(p.x) / max(w, 0.001);
	float core = smoothstep(1.0, 0.0, d) * smoothstep(1.0, 0.55, y) * smoothstep(0.0, 0.1, y);
	vec3 col = mix(color.rgb, vec3(1.0, 0.96, 0.86), smoothstep(0.3, 1.0, core));
	col = mix(vec3(0.25, 0.4, 1.0), col, smoothstep(0.0, 0.22, y));
	if (disco > 0.5) col = mix(col, 0.5 + 0.5 * vec3(sin(TIME * 4.0 + seed * 6.0), sin(TIME * 4.0 + seed * 6.0 + 2.0), sin(TIME * 4.0 + seed * 6.0 + 4.0)), 0.6);
	ALBEDO = col * core * brightness;
	ALPHA = 1.0;
}
