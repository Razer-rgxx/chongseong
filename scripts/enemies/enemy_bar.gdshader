shader_type spatial;
// 적 머리 위 체력 막대(2026-11-25 사용자: "막대는 좀 이쁘게"). 판 하나에 그린다(EnemyView._make_bar).
// 영주 막대(LifeBar)와 같은 결: 어두운 바탕, 위아래 놋쇠 실선, 왼쪽 큰 마름모·오른쪽 작은 마름모 마개,
// 위가 밝고 아래가 짙은 채움과 맨 위 빛 한 줄, 깎인 몫은 옅은 금빛, 4등분 눈금. 크기는 m 단위(size).
render_mode unshaded, depth_test_disabled, cull_disabled, shadows_disabled, blend_mix, fog_disabled;

uniform vec2 size = vec2(1.1, 0.2);
uniform float k = 1.0;
uniform float lag = 1.0;
uniform float alpha = 1.0;
uniform vec3 top : source_color = vec3(0.74, 0.17, 0.13);
uniform vec3 bottom : source_color = vec3(0.4, 0.05, 0.05);
uniform vec3 brass : source_color = vec3(0.72, 0.6, 0.4);

const float T = 0.036;    // 막대 반 두께(m)
const float CAP = 0.085;  // 양 끝 마개 자리(m)

// d < 0이 안쪽인 거리 → 덮인 몫(경계는 화소 하나로 부드럽게)
float cov(float d, float aa) {
	return clamp(0.5 - d / aa, 0.0, 1.0);
}

void fragment() {
	vec2 p = vec2(UV.x * size.x, (0.5 - UV.y) * size.y);
	float aa = max(fwidth(p.x), 0.0005) * 1.2;
	float x0 = CAP;
	float x1 = size.x - CAP;
	float w = x1 - x0;
	float u = (p.x - x0) / w;
	float dx = max(x0 - p.x, p.x - x1);
	float d_track = max(dx, abs(p.y) - T);
	float inside = cov(d_track, aa);
	// 바탕(막대보다 조금 넓게)
	vec3 col = vec3(0.022, 0.016, 0.014);
	float a = 0.8 * cov(d_track - 0.01, aa);
	// 깎인 몫(옅은 금빛)
	float a_lag = inside * cov(p.x - (x0 + w * lag), aa);
	col = mix(col, vec3(0.86, 0.72, 0.5), a_lag * 0.5);
	// 채움: 위가 밝고 아래가 짙다, 맨 위 빛 한 줄
	float g = clamp((p.y + T) / (2.0 * T), 0.0, 1.0);
	vec3 fc = mix(bottom, top, smoothstep(0.0, 0.85, g));
	fc = mix(fc, top * 1.35 + vec3(0.08, 0.05, 0.03), smoothstep(0.74, 0.9, g) * (1.0 - smoothstep(0.9, 1.0, g)));
	float a_fill = inside * cov(p.x - (x0 + w * k), aa);
	col = mix(col, fc, a_fill);
	// 4등분 눈금(가는 어두운 금)
	float q = abs(fract(u * 4.0 + 0.5) - 0.5) * w / 4.0;
	float notch = cov(q - 0.003, aa) * step(0.1, u) * step(u, 0.9) * inside;
	col = mix(col, col * 0.35, notch);
	// 위아래 놋쇠 실선(마개까지 닿는다)
	float line = cov(abs(abs(p.y) - (T + 0.017)) - 0.004, aa) * cov(dx - 0.03, aa);
	// 마름모 마개: 왼쪽은 크고 안에 채움 빛 보석, 오른쪽은 작다
	vec2 cl = vec2(p.x - (x0 - 0.028), p.y);
	vec2 cr = vec2(p.x - (x1 + 0.022), p.y);
	float dl = abs(cl.x) + abs(cl.y) - 0.058;
	float dr = abs(cr.x) + abs(cr.y) - 0.036;
	float cap = max(cov(dl, aa), cov(dr, aa));
	float gem = cov(dl + 0.024, aa);
	vec3 bcol = brass * (0.85 + 0.3 * smoothstep(-0.05, 0.05, p.y));
	col = mix(col, bcol, max(line, cap));
	col = mix(col, mix(vec3(0.03, 0.02, 0.02), top * 1.2, step(0.001, k)), gem);
	a = max(a, max(line, cap));
	ALBEDO = col;
	ALPHA = a * alpha;
}
