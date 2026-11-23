// Title backdrop: Ashcombe House in silhouette against a moonlit storm. Lit windows breathe,
// rain slants across the frame, clouds drift over the moon, and lightning now and then.
shader_type canvas_item;
uniform float flash = 0.0;
uniform vec2 res = vec2(1920.0, 1080.0);
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float a = 0.5, s = 0.0; for (int i = 0; i < 5; i++) { s += n(p) * a; p *= 2.03; a *= 0.5; } return s; }
float box(vec2 p, vec2 c, vec2 s) { vec2 d = abs(p - c) - s; return step(max(d.x, d.y), 0.0); }
float roofline(vec2 p) {
	// the house: central block with a pediment, two wings, chimneys, a clock tower
	float m = 0.0;
	m = max(m, box(p, vec2(0.0, -0.18), vec2(0.34, 0.2)));
	m = max(m, box(p, vec2(-0.5, -0.24), vec2(0.18, 0.14)));
	m = max(m, box(p, vec2(0.5, -0.24), vec2(0.18, 0.14)));
	m = max(m, step(abs(p.x) * 0.55, 0.06 - (p.y - 0.02)) * step(0.02, p.y));
	m = max(m, box(p, vec2(0.0, 0.13), vec2(0.05, 0.14)));
	m = max(m, step(abs(p.x) * 1.6, 0.11 - (p.y - 0.27)) * step(0.27, p.y));
	m = max(m, box(p, vec2(-0.26, 0.06), vec2(0.018, 0.06)));
	m = max(m, box(p, vec2(0.27, 0.06), vec2(0.018, 0.06)));
	m = max(m, box(p, vec2(-0.6, -0.07), vec2(0.015, 0.05)));
	m = max(m, box(p, vec2(0.62, -0.07), vec2(0.015, 0.05)));
	return m;
}
float windows(vec2 p) {
	float w = 0.0;
	for (int i = -3; i <= 3; i++) for (int j = 0; j < 2; j++) {
		vec2 c = vec2(float(i) * 0.085, -0.28 + float(j) * 0.14);
		float on = step(0.45, h(vec2(float(i), float(j))));
		w += box(p, c, vec2(0.017, 0.034)) * on;
	}
	for (int i = -1; i <= 1; i++) { if (i == 0) continue; for (int k = 0; k < 2; k++) {
		vec2 c = vec2(float(i) * (0.44 + float(k) * 0.1), -0.27);
		w += box(p, c, vec2(0.016, 0.03)) * step(0.5, h(vec2(float(i) + 9.0, float(k))));
	} }
	return min(w, 1.0);
}
void fragment() {
	vec2 uv = UV;
	float aspect = res.x / res.y;
	vec2 p = vec2((uv.x - 0.5) * aspect, 0.5 - uv.y);
	float t = TIME;
	vec3 sky = mix(vec3(0.01, 0.012, 0.03), vec3(0.05, 0.07, 0.13), smoothstep(-0.4, 0.5, p.y));
	vec2 mp = vec2(0.42 * aspect * 0.55, 0.28);
	float md = length(p - mp);
	sky += vec3(0.55, 0.62, 0.8) * exp(-md * 9.0) * 0.35;
	float moon = smoothstep(0.062, 0.058, md);
	float crater = fbm((p - mp) * 40.0);
	sky = mix(sky, vec3(0.86, 0.88, 0.92) * (0.82 + crater * 0.25), moon);
	float clouds = fbm(vec2(p.x * 1.6 + t * 0.012, p.y * 3.0 - 0.3));
	clouds = smoothstep(0.42, 0.85, clouds);
	vec3 cloud_col = mix(vec3(0.03, 0.035, 0.06), vec3(0.32, 0.36, 0.46), exp(-md * 4.0) + flash * 0.8);
	sky = mix(sky, cloud_col, clouds * 0.85);
	float stars = step(0.9975, h(floor(uv * res * 0.5))) * (1.0 - clouds) * smoothstep(0.0, 0.3, p.y);
	sky += stars * 0.7;
	sky += flash * vec3(0.5, 0.55, 0.7) * (0.4 + clouds);
	// trees and the house
	vec2 hp = (p - vec2(0.0, -0.08)) * 1.45;
	float trees = step(p.y, -0.32 + fbm(vec2(p.x * 7.0, 1.0)) * 0.22 + 0.04 * sin(p.x * 30.0));
	float house = roofline(hp);
	float win = windows(hp) * house;
	float breathe = 0.75 + 0.25 * sin(t * 0.7 + hp.x * 3.0) * n(vec2(t * 0.6, hp.x * 10.0));
	vec3 col = sky;
	col = mix(col, vec3(0.012, 0.013, 0.02) + flash * 0.05, max(house, trees));
	col += win * vec3(1.0, 0.68, 0.32) * breathe * 0.9;
	float clock = smoothstep(0.024, 0.02, length(hp - vec2(0.0, 0.17)));
	col += clock * vec3(0.5, 1.0, 0.8) * (0.6 + 0.2 * sin(t * 1.3));
	// ground fog
	float fog = fbm(vec2(p.x * 2.0 - t * 0.03, p.y * 6.0)) * smoothstep(-0.2, -0.5, p.y);
	col = mix(col, vec3(0.08, 0.1, 0.14), fog * 0.6);
	// rain
	vec2 rp = uv * vec2(res.x / 6.0, res.y / 60.0);
	rp.x += rp.y * 0.18;
	rp.y += t * 14.0;
	float drop = step(0.985, h(floor(rp))) * smoothstep(0.0, 0.6, fract(rp.y));
	col += drop * vec3(0.35, 0.4, 0.5) * 0.35;
	// vignette
	col *= smoothstep(1.25, 0.35, length((uv - 0.5) * vec2(1.0, 0.9)) * 1.4);
	COLOR = vec4(col, 1.0);
}
