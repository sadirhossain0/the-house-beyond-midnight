// Instanced soft halos around candles, lamps and windows. INSTANCE_CUSTOM.x = size, .y = on, .z = seed.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform float intensity = 1.0;
varying float on;
void vertex() {
	on = INSTANCE_CUSTOM.y;
	float fl = 1.0 + 0.05 * sin(TIME * 11.0 + INSTANCE_CUSTOM.z * 30.0) + 0.04 * sin(TIME * 19.0 + INSTANCE_CUSTOM.z * 7.0);
	vec4 c = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	c.xy += VERTEX.xy * INSTANCE_CUSTOM.x * fl * on;
	c.z += 0.05;
	POSITION = PROJECTION_MATRIX * c;
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = pow(clamp(1.0 - d, 0.0, 1.0), 2.4) * on;
	ALBEDO = COLOR.rgb * a * intensity;
	ALPHA = 1.0;
}
