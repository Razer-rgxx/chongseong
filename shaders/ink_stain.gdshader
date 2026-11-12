shader_type spatial;
render_mode unshaded, depth_draw_never;
// 번짐이 지나간 자리의 얼룩. 종이의 설계선을 덮어 지운다.

uniform vec3 ink : source_color = vec3(0.02, 0.03, 0.07);
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p), u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = atan(p.y, p.x);
	float r = length(p) + (noise(vec2(a * 2.0, seed)) - 0.5) * 0.45 + (noise(p * 6.0 + seed) - 0.5) * 0.15;
	ALBEDO = ink;
	ALPHA = (1.0 - smoothstep(0.55, 0.62, r)) * 0.85;
}
