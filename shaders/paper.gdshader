shader_type spatial;
// 설계 도면 종이. 칸(2m)마다 굵은 선, 반 칸마다 가는 선, 네 칸마다 더 굵은 선. 영지 밖은 어둡다.

uniform vec3 paper : source_color = vec3(0.07, 0.16, 0.3);
uniform vec3 paper_edge : source_color = vec3(0.035, 0.08, 0.17);
uniform vec3 line_col : source_color = vec3(0.62, 0.78, 0.95);
uniform float cell = 2.0;
uniform float map_meters = 66.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p), u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float grid(vec2 p, float step_m, float w) {
	vec2 g = abs(fract(p / step_m - 0.5) - 0.5) * step_m;
	vec2 fw = fwidth(p) * 1.5;
	vec2 l = 1.0 - smoothstep(vec2(w), vec2(w) + fw, g);
	return max(l.x, l.y);
}

void fragment() {
	vec2 p = wpos.xz;
	bool inside = p.x > 0.0 && p.y > 0.0 && p.x < map_meters && p.y < map_meters;
	float n = noise(p * 2.3) * 0.6 + noise(p * 19.0) * 0.4;
	float vig = smoothstep(map_meters * 0.3, map_meters * 0.8, length(p - vec2(map_meters * 0.5)));
	vec3 col = mix(paper, paper_edge, vig) * (0.9 + 0.12 * n);
	if (inside) {
		col = mix(col, line_col, grid(p, cell * 0.5, 0.01) * 0.035 + grid(p, cell, 0.018) * 0.1 + grid(p, cell * 4.0, 0.03) * 0.16);
	} else {
		col *= 0.55;
	}
	// 영지 둘레의 이중 테두리
	vec2 e = min(p, vec2(map_meters) - p);
	float d = min(e.x, e.y);
	float fw = fwidth(d) * 1.5;
	float frame = (1.0 - smoothstep(0.05, 0.05 + fw, abs(d - 0.0))) + (1.0 - smoothstep(0.03, 0.03 + fw, abs(d + 0.7))) * 0.6;
	col = mix(col, line_col, clamp(frame, 0.0, 1.0) * 0.8);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
