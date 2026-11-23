// Night sky: the moonlit HDRI with a layer of rain clouds racing across it, and lightning.
shader_type sky;
uniform sampler2D hdri : source_color, filter_linear, repeat_enable;
uniform float hdri_energy = 1.0;
uniform float rotation = 0.0;
uniform float cloud_cover = 0.6;
uniform float cloud_speed = 0.01;
uniform float flash = 0.0;
uniform vec4 cloud_color : source_color = vec4(0.07, 0.08, 0.11, 1.0);
uniform vec3 moon_dir = vec3(0.3, 0.42, 0.85);
uniform vec4 moon_color : source_color = vec4(0.85, 0.9, 1.0, 1.0);
float hh(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vn(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f); return mix(mix(hh(i), hh(i + vec2(1, 0)), f.x), mix(hh(i + vec2(0, 1)), hh(i + vec2(1, 1)), f.x), f.y); }
float fb(vec2 p) { float s = 0.0, a = 0.5; for (int i = 0; i < 5; i++) { s += a * vn(p); p *= 2.07; a *= 0.5; } return s; }
void sky() {
	vec3 d = EYEDIR;
	float ang = atan(d.x, -d.z) + rotation;
	vec2 uv = vec2(ang / 6.2831853 + 0.5, acos(clamp(d.y, -1.0, 1.0)) / 3.14159265);
	vec3 col = texture(hdri, uv).rgb * hdri_energy;
	float md = dot(d, normalize(moon_dir));
	col += moon_color.rgb * smoothstep(0.99955, 0.99975, md) * 3.0;      // disc
	col += moon_color.rgb * pow(max(md, 0.0), 300.0) * 0.8;            // halo
	col += vec3(0.05, 0.06, 0.09) * pow(max(md, 0.0), 10.0);
	if (AT_CUBEMAP_PASS) { COLOR = col; } else {
		float hgt = clamp(d.y, -0.2, 1.0);
		vec2 sp = d.xz / max(d.y + 0.3, 0.05);
		float c = fb(sp * 0.7 + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4));
		float c2 = fb(sp * 1.9 - vec2(TIME * cloud_speed * 1.6, 0.0));
		float cloud = smoothstep(1.0 - cloud_cover, 1.05 - cloud_cover * 0.5, c * 0.7 + c2 * 0.45) * smoothstep(-0.05, 0.12, hgt);
		vec3 lit_cloud = cloud_color.rgb + moon_color.rgb * pow(max(md, 0.0), 8.0) * 0.25;
		col = mix(col, lit_cloud + flash * vec3(0.55, 0.6, 0.75) * c, cloud * 0.85);
		col += flash * vec3(0.18, 0.2, 0.26) * (0.35 + cloud);
		COLOR = col;
	}
}
