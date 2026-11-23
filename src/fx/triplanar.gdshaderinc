// Shared helpers: world-space triplanar sampling and value noise.
vec4 tri_sample(sampler2D tex, vec3 wp, vec3 wn, float scale, float sharp) {
	vec3 b = pow(abs(wn), vec3(sharp));
	b /= max(b.x + b.y + b.z, 1e-5);
	vec4 x = texture(tex, wp.zy * scale);
	vec4 y = texture(tex, wp.xz * scale);
	vec4 z = texture(tex, wp.xy * scale);
	return x * b.x + y * b.y + z * b.z;
}
// Triplanar normal (Whiteout blend), returns a world-space normal.
vec3 tri_normal(sampler2D tex, vec3 wp, vec3 wn, float scale, float sharp, float strength) {
	vec3 b = pow(abs(wn), vec3(sharp));
	b /= max(b.x + b.y + b.z, 1e-5);
	vec3 tx = texture(tex, wp.zy * scale).xyz * 2.0 - 1.0;
	vec3 ty = texture(tex, wp.xz * scale).xyz * 2.0 - 1.0;
	vec3 tz = texture(tex, wp.xy * scale).xyz * 2.0 - 1.0;
	tx.xy *= strength; ty.xy *= strength; tz.xy *= strength;
	tx = vec3(tx.xy + wn.zy, abs(tx.z) * wn.x);
	ty = vec3(ty.xy + wn.xz, abs(ty.z) * wn.y);
	tz = vec3(tz.xy + wn.xy, abs(tz.z) * wn.z);
	return normalize(tx.zyx * b.x + ty.xzy * b.y + tz.xyz * b.z);
}
float hash12(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vnoise(vec2 p) { vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), f.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), f.x), f.y); }
float fbm2(vec2 p) { float s = 0.0, a = 0.5; for (int i = 0; i < 5; i++) { s += a * vnoise(p); p *= 2.03; a *= 0.5; } return s; }
