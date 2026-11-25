shader_type spatial;
render_mode unshaded, cull_disabled;
// 네온 시가 광고판(2026-11-25): 글자 없이 움직이는 도형만(세계에 글자를 띄우지 않는다).
// 판마다 INSTANCE_CUSTOM: r = 무늬(0~1을 넷으로), g = 색(팔레트 자리), b = 빠르기, a = 위상.
// 무늬: 흐르는 가로 띠 · 퍼지는 고리 · 오르내리는 막대 · 비껴가는 빛과 칸. 주사선과 테두리가 얹힌다.
uniform float energy = 2.4;
uniform float dim = 1.0;   // 웹판 등에서 줄일 때

varying vec4 cust;

vec3 pal(float t) {
	t = fract(t);
	if (t < 0.2) return vec3(0.15, 0.95, 1.0);    // 청록
	if (t < 0.4) return vec3(1.0, 0.2, 0.75);     // 자홍
	if (t < 0.6) return vec3(1.0, 0.62, 0.18);    // 호박
	if (t < 0.8) return vec3(0.55, 0.35, 1.0);    // 보라
	return vec3(0.35, 1.0, 0.45);                  // 연두
}

float h11(float x) { return fract(sin(x * 91.7) * 43758.5453); }

void vertex() {
	cust = INSTANCE_CUSTOM;
}

void fragment() {
	float pat = floor(cust.r * 3.999);
	float t = TIME * (0.4 + cust.b * 1.6) + cust.a * 31.0;
	vec2 uv = UV;
	vec3 a = pal(cust.g);
	vec3 b = pal(cust.g + 0.37);
	float v = 0.0;
	vec3 col;
	if (pat < 0.5) {
		float s = fract(uv.y * 6.0 - t * 0.6);
		v = smoothstep(0.0, 0.15, s) * smoothstep(0.6, 0.35, s);
		col = mix(a, b, uv.x) * (0.25 + v);
	} else if (pat < 1.5) {
		float d = length(uv - 0.5) * 2.0;
		v = 0.5 + 0.5 * sin(d * 14.0 - t * 4.0);
		col = mix(b, a, v) * (0.2 + 0.8 * v) * smoothstep(1.2, 0.2, d);
	} else if (pat < 2.5) {
		float bar = floor(uv.x * 10.0);
		float hgt = 0.25 + 0.7 * abs(sin(t * (1.0 + h11(bar)) + bar));
		v = step(uv.y, hgt) * step(0.15, fract(uv.x * 10.0));
		col = mix(a, b, uv.y) * (0.12 + v);
	} else {
		float sweep = smoothstep(0.25, 0.0, abs(fract(uv.x + uv.y * 0.4 - t * 0.25) - 0.5) - 0.2);
		vec2 c = floor(uv * vec2(8.0, 5.0));
		float blink = step(0.7, h11(c.x * 7.0 + c.y * 13.0 + floor(t * 2.0)));
		col = a * (0.15 + 0.6 * sweep) + b * blink * 0.5;
	}
	float scan = 0.82 + 0.18 * sin(uv.y * 160.0);
	float edge = max(step(uv.x, 0.03) + step(0.97, uv.x), step(uv.y, 0.04) + step(0.96, uv.y));
	col = col * scan + a * edge * 0.9;
	ALBEDO = col * energy * dim;
}
