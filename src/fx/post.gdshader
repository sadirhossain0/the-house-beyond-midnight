// Full-screen finishing pass: vignette, grain, lens fringing, Now/Then ripple, echo sepia,
// ghost vision, hurt pulse, faint blur, fades, flashes and the Paranormal Extras filters.
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.35;
uniform float grain = 0.03;
uniform float chroma = 0.0;
uniform int filter_mode = 0; // 0 none, 1 retro film, 2 monochrome, 3 VHS
uniform float shift = 0.0;
uniform float echo = 0.0;
uniform float ghost = 0.0;
uniform float hurt = 0.0;
uniform float faint = 0.0;
uniform float fade = 0.0;
uniform float flash = 0.0;
uniform float motion = 1.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
vec3 sat(vec3 c, float s) { float l = dot(c, vec3(0.2126, 0.7152, 0.0722)); return mix(vec3(l), c, s); }
void fragment() {
	vec2 uv = SCREEN_UV;
	if (shift > 0.0) { vec2 d = uv - 0.5; float r = length(d); uv += normalize(d + 1e-5) * sin(r * 40.0 - shift * 18.0) * 0.012 * shift * (1.0 - shift) * 4.0 * motion; }
	if (filter_mode == 3) uv.x += sin(uv.y * 240.0 + TIME * 8.0) * 0.0007 + (h(vec2(floor(TIME * 30.0), floor(uv.y * 60.0))) - 0.5) * 0.0015;
	if (faint > 0.0) uv += vec2(sin(TIME * 1.3), cos(TIME * 1.1)) * 0.008 * faint * motion;
	vec3 col = textureLod(screen_tex, uv, faint * 3.0).rgb;
	if (chroma > 0.0 || filter_mode == 3) {
		float k = filter_mode == 3 ? 0.0022 : 0.0012 * chroma;
		vec2 off = (uv - 0.5) * k * 2.0;
		col.r = textureLod(screen_tex, uv + off, faint * 3.0).r;
		col.b = textureLod(screen_tex, uv - off, faint * 3.0).b;
	}
	if (echo > 0.0) { vec3 se = vec3(dot(col, vec3(0.393, 0.769, 0.189)), dot(col, vec3(0.349, 0.686, 0.168)), dot(col, vec3(0.272, 0.534, 0.131))); col = mix(col, se * 1.05 + 0.02, echo * 0.85); }
	if (ghost > 0.0) col = mix(col, vec3(dot(col, vec3(0.3, 0.6, 0.1))) * vec3(0.55, 1.15, 1.05), ghost * 0.55);
	if (shift > 0.0) col = mix(col, sat(col, 0.0) * vec3(0.8, 1.0, 0.95) + 0.04, sin(shift * 3.14159) * 0.55);
	if (filter_mode == 1) { float l = dot(col, vec3(0.3, 0.59, 0.11)); col = mix(col, vec3(l * 1.1, l * 0.95, l * 0.75), 0.75); col *= 0.96 + 0.04 * h(vec2(floor(TIME * 24.0), 3.0)); col += step(0.997, h(vec2(floor(uv.x * 400.0), floor(TIME * 12.0)))) * 0.25; }
	else if (filter_mode == 2) { float l = dot(col, vec3(0.3, 0.59, 0.11)); col = vec3(smoothstep(0.02, 0.9, l)); }
	else if (filter_mode == 3) { col *= 0.92 + 0.08 * sin(SCREEN_UV.y / SCREEN_PIXEL_SIZE.y * 1.5); col = sat(col, 1.25) * vec3(1.02, 0.98, 1.05); }
	vec2 v = SCREEN_UV - 0.5;
	float vig = smoothstep(0.85, 0.2, length(v * vec2(1.0, 0.85)));
	col *= mix(1.0, vig, vignette);
	col = mix(col, vec3(0.35, 0.02, 0.04), hurt * (1.0 - vig) * 0.8);
	col += flash * vec3(0.9, 0.95, 1.0);
	col += (h(SCREEN_UV / SCREEN_PIXEL_SIZE * 0.5 + fract(TIME) * 100.0) - 0.5) * grain;
	col = mix(col, vec3(0.0), fade);
	COLOR = vec4(col, 1.0);
}
