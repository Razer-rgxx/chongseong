shader_type spatial;
render_mode unshaded, cull_disabled;
// 네온 시가 광고판(2026-11-25): 글자 없이 움직이는 도형만(세계에 글자를 띄우지 않는다).
// 판마다 INSTANCE_CUSTOM: r = 무늬(0~1을 넷으로), g = 색(팔레트 자리), b = 빠르기, a = 위상.
// 무늬: 흐르는 가로 띠 · 퍼지는 고리 · 오르내리는 막대 · 비껴가는 빛과 칸. 주사선과 테두리가 얹힌다.
uniform float energy = 1.6;
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
	// 2026-11-25 "ai 티 안나게": 진짜 LED 광고 화면처럼. 어두운 화면 테(빛나는 테두리 없음), LED 점 격자, 덜 진한 색,
	// 판마다 밝기가 다르고, 무늬는 부드러운 그라데이션·흐릿한 도형이 천천히 바뀐다(글자 없음).
	float pat = floor(cust.r * 3.999);
	float t = TIME * (0.25 + cust.b * 0.8) + cust.a * 31.0;
	vec2 uv = UV;
	vec3 a = mix(pal(cust.g), vec3(0.7), 0.22);
	vec3 b = mix(pal(cust.g + 0.37), vec3(0.7), 0.3);
	vec3 col;
	if (pat < 0.5) {          // 천천히 흐르는 두 빛깔 그라데이션과 빛 번짐
		float w = 0.5 + 0.5 * sin(uv.x * 2.2 + uv.y * 1.3 - t * 0.5);
		col = mix(a * 0.35, b, w) * (0.55 + 0.45 * smoothstep(1.0, 0.0, length(uv - vec2(0.3 + 0.4 * sin(t * 0.3), 0.5))));
	} else if (pat < 1.5) {   // 어두운 바탕 위 흐릿한 둥근 도형 둘이 천천히 움직인다(물건 광고 느낌)
		float d1 = length((uv - vec2(0.35 + 0.1 * sin(t * 0.4), 0.55)) * vec2(1.6, 1.0));
		float d2 = length((uv - vec2(0.7, 0.4 + 0.1 * cos(t * 0.5))) * vec2(1.6, 1.0));
		col = vec3(0.04, 0.045, 0.06) + a * smoothstep(0.35, 0.1, d1) * 0.9 + b * smoothstep(0.28, 0.05, d2) * 0.7;
	} else if (pat < 2.5) {   // 오르내리는 막대(소리 그림), 막대 끝이 밝다
		float bar = floor(uv.x * 14.0);
		float hgt = 0.2 + 0.6 * abs(sin(t * (0.6 + h11(bar) * 0.8) + bar));
		float v = step(1.0 - uv.y, hgt) * step(0.2, fract(uv.x * 14.0));
		col = vec3(0.03) + mix(b, a, 1.0 - uv.y) * v * 0.85;
	} else {                  // 장면이 바뀌듯 가끔 색이 넘어간다(넘어가는 동안 살짝 밝다)
		float k = fract(t * 0.08);
		float cut = smoothstep(0.0, 0.05, k) * smoothstep(0.55, 0.5, k);
		col = mix(mix(a, b, uv.y) * 0.6, mix(b * 0.5, a, uv.x) * 0.7, cut) * (0.85 + 0.15 * smoothstep(0.06, 0.0, abs(k - 0.03)));
	}
	// LED 점: 칸마다 동그란 점, 사이는 어둡다
	vec2 px = fract(uv * vec2(96.0, 54.0)) - 0.5;
	float led = 0.55 + 0.45 * smoothstep(0.5, 0.2, length(px));
	float lvl = 0.55 + 0.45 * h11(cust.a * 17.0 + cust.g);
	float bezel = step(0.025, uv.x) * step(uv.x, 0.975) * step(0.04, uv.y) * step(uv.y, 0.96);
	col = mix(vec3(0.015, 0.016, 0.02), col * led * lvl, bezel);
	ALBEDO = col * energy * dim;
}
