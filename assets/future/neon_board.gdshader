shader_type spatial;
render_mode unshaded, cull_disabled;
// 네온 시가 광고판(2026-11-25): 글자 없이 움직이는 도형만(세계에 글자를 띄우지 않는다).
// 판마다 INSTANCE_CUSTOM: r = 무늬(0~1을 넷으로), g = 색(팔레트 자리), b = 빠르기, a = 위상.
// 무늬: 실제 광고처럼(아래 scene). 판마다 밝기가 다르고 몇은 꺼져 있다.
uniform float energy = 1.1;
uniform float dim = 1.0;   // 웹판 등에서 줄일 때

varying flat vec4 cust;   // flat: 판마다 같은 값. 보간하면 화소마다 미세하게 달라져 해시가 화소마다 다른 장면을 고른다(모래 얼룩)

// 2026-11-25 "LED 색감이 너무 AI 스러움": 파스텔 청록·자홍 그라데이션을 버리고 실제 거리 광고의 색으로.
// 흰 바탕의 물건, 빨강·노랑·남색 상표 색 면, 피부색·따뜻한 조명의 흐릿한 사진. 장면은 뚝 끊겨 바뀐다(광고 순서). 글자 없음.
vec3 adpal(float t) {
	t = fract(t) * 8.0;
	if (t < 1.0) return vec3(0.93, 0.92, 0.9);    // 흰 바탕
	if (t < 2.0) return vec3(0.82, 0.1, 0.08);    // 빨강
	if (t < 3.0) return vec3(0.98, 0.76, 0.12);   // 노랑
	if (t < 4.0) return vec3(0.06, 0.13, 0.36);   // 남색
	if (t < 5.0) return vec3(0.86, 0.6, 0.46);    // 피부색
	if (t < 6.0) return vec3(0.95, 0.42, 0.08);   // 주황
	if (t < 7.0) return vec3(0.04, 0.04, 0.05);   // 검정
	return vec3(0.1, 0.42, 0.24);                  // 짙은 초록
}

float h11(float x) { return fract(sin(x * 91.7) * 43758.5453); }
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	cust = INSTANCE_CUSTOM;
}

// 광고 한 장면(sc: 장면 번호의 난수). 네 종류: 흐릿한 사진 · 상표 색 면 · 흰 바탕의 물건 · 어두운 바탕의 빛나는 물건
vec3 scene(vec2 uv, float sc, float t) {
	float kind = floor(h11(sc * 3.1) * 3.999);
	vec3 c1 = adpal(h11(sc * 5.7));
	vec3 c2 = adpal(h11(sc * 9.3 + 0.4));
	if (kind < 0.5) {   // 흐릿한 사진: 따뜻한 조명 아래 사람·풍경처럼 보이는 낮은 주파수 얼룩, 천천히 다가간다(줌)
		vec2 q = (uv - 0.5) * (1.0 - 0.06 * fract(t * 0.05)) + 0.5;
		float n = vnoise(q * 3.0 + sc * 17.0) * 0.65 + vnoise(q * 7.0 + sc * 5.0) * 0.35;
		vec3 dark = mix(vec3(0.05, 0.04, 0.04), c2 * 0.3, 0.5);
		vec3 lit = mix(vec3(0.86, 0.6, 0.46), vec3(0.95, 0.85, 0.7), h11(sc));
		return mix(dark, lit, smoothstep(0.35, 0.75, n)) * mix(0.75, 1.05, uv.y);
	} else if (kind < 1.5) {   // 상표 색 면 + 흰 둥근 판 + 띠
		vec3 c = c1;
		vec2 d = abs(uv - vec2(0.3 + 0.4 * h11(sc * 2.0), 0.5)) - vec2(0.16, 0.22);
		float box = step(max(d.x, d.y), 0.0);
		c = mix(c, vec3(0.94, 0.93, 0.9), box);
		c = mix(c, c2, step(0.92, uv.y));
		return c;
	} else if (kind < 2.5) {   // 흰 바탕의 물건(그림자 진 어두운 덩이)과 아래 상표 색 띠
		vec3 c = vec3(0.9, 0.9, 0.88) - 0.08 * uv.y;
		float d = length((uv - vec2(0.5, 0.48)) * vec2(1.4, 1.0));
		c = mix(c, mix(c1, vec3(0.1), 0.5) * 0.8, smoothstep(0.24, 0.22, d));
		c *= 1.0 - 0.25 * smoothstep(0.3, 0.2, length((uv - vec2(0.52, 0.72)) * vec2(1.4, 3.0)));
		return mix(c, c1, step(0.86, uv.y));
	}
	// 어두운 바탕에 조명 받은 물건
	vec3 c = vec3(0.03, 0.03, 0.035);
	float d = length((uv - vec2(0.5 + 0.2 * (h11(sc) - 0.5), 0.5)) * vec2(1.3, 1.0));
	return c + c1 * smoothstep(0.3, 0.05, d) * 0.9 + vec3(0.9) * smoothstep(0.04, 0.0, abs(d - 0.2)) * 0.15;
}

void fragment() {
	float t = TIME * (0.6 + cust.b * 0.5) + cust.a * 40.0;
	float slot = floor(t / 6.0);                       // 6초쯤마다 뚝 끊겨 다음 광고
	vec3 col = scene(UV, h11(slot + cust.g * 37.0 + cust.r * 11.0), t);
	// LED: 흰색이 살짝 차가운 화이트 포인트, 판마다 밝기
	float led = 0.92;   // 점 격자는 비스듬히 보면 모래 같은 얼룩이 되어 뺐다(거리에서 보는 LED 화면은 매끈하다)
	float lvl = 0.6 + 0.4 * h11(cust.a * 17.0 + cust.g);
	col = col * vec3(0.94, 0.97, 1.0);
	if (h11(cust.a * 5.3 + 1.7) < 0.18) {   // 꺼진 화면(검은 유리에 희미한 비침)
		col = vec3(0.012, 0.014, 0.02) + vec3(0.03) * smoothstep(0.3, 0.0, abs(UV.x - UV.y * 0.6 - 0.2));
	}
	float bezel = step(0.025, UV.x) * step(UV.x, 0.975) * step(0.04, UV.y) * step(UV.y, 0.96);
	col = mix(vec3(0.015, 0.016, 0.02), col * led * lvl, bezel);
	ALBEDO = col * energy * dim;
}
