shader_type spatial;
// 네온 시가 Blender 건물의 벽(tools/blender/make_city.py, 2026-11-25). 벽 질감 한 장 = 창 cells × cells칸(창 한 칸 2.4m × 3.4m, UV가 m 단위라 늘어나지 않는다).
// 켜진 창은 칸마다 고른다: 건물(인스턴스 자리)·층 무리(4층)마다 몫이 다르고, 따뜻한·차가운·분홍 빛, 몇 창은 느리게 꺼졌다 켜진다.
// 멀어서 창 한 칸이 몇 화소보다 작으면 무늬 대신 평균 빛(지글거림 막기). shop = 1이면 가게층 유리(거의 다 켜지고 따뜻하다).
uniform sampler2D alb : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float cells = 4.0;
uniform vec4 win = vec4(0.16, 0.2, 0.84, 0.8);   // 칸 안의 유리 자리(x0, y0, x1, y1, 위가 0)
uniform float lit = 0.3;
uniform float warm = 0.45;
uniform float pink = 0.06;   // 진한 색 빛(화면·네온 비침)의 몫
uniform float lit_energy = 2.4;
uniform float flicker = 0.04;
uniform float wall_rough = 0.8;
uniform float glass_rough = 0.08;
uniform vec3 tint : source_color = vec3(1.0);
uniform vec3 pink_col : source_color = vec3(1.0, 0.4, 0.75);
uniform float shop = 0.0;

varying flat vec2 bseed;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	bseed = MODEL_MATRIX[3].xz;
}

void fragment() {
	vec2 g = UV * cells;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	vec3 a = texture(alb, UV).rgb * tint;
	NORMAL_MAP = texture(nrm, UV).rgb;
	float inwin = step(win.x, f.x) * step(f.x, win.z) * step(win.y, f.y) * step(f.y, win.w);
	float lum = dot(a, vec3(0.3, 0.59, 0.11));
	float glass = inwin * (1.0 - smoothstep(0.1, 0.2, lum));   // 창살·창틀(밝은 화소)은 빛나지 않는다
	float bs = h21(floor(bseed * 0.37) + 0.5);
	float band = h21(vec2(floor(cell.y / 4.0), bs * 97.0));
	float share = shop > 0.5 ? 0.92 : lit * (0.35 + 1.3 * band);
	float r = h21(cell + vec2(bs * 61.0, 13.0));
	vec3 emit = vec3(0.0);
	if (r < share) {
		// 실내등 색(2026-11-25 "ai 티 안나게"): 백열등 주황·형광등 흰빛·차가운 형광이 대부분, 진한 분홍·푸른 화면 빛은 드물게(pink 몫)
		float k = h21(cell + vec2(7.0, bs * 17.0));
		vec3 col = k < warm ? vec3(1.0, 0.74, 0.46) : (k < warm + 0.22 ? vec3(0.96, 0.92, 0.82) : (k < 1.0 - pink ? vec3(0.74, 0.86, 1.0) : (h21(cell + 2.0) < 0.5 ? pink_col : vec3(0.3, 0.6, 1.0))));
		if (shop > 0.5) {
			col = mix(vec3(1.0, 0.8, 0.56), col, 0.3);
		}
		float on = 1.0;
		if (flicker > 0.0) {
			on = step(0.1, h21(cell + vec2(floor(TIME * flicker + r * 37.0), 3.0)));
		}
		// 창마다 밝기가 다르다. 몇 창은 블라인드 줄, 몇 창은 커튼이 반쯤 가렸다. 천장등이라 위가 밝고 아래로 어두워진다
		float wx = (f.x - win.x) / max(0.01, win.z - win.x);
		float blinds = h21(cell + vec2(9.0, bs * 5.0)) < 0.25 ? 0.6 + 0.4 * step(0.5, fract(f.y * 18.0)) : 1.0;
		float cur = h21(cell + vec2(4.0, bs * 3.0));
		float curtain = cur < 0.3 ? mix(0.18, 1.0, step(cur * 2.2 + 0.15, wx)) : 1.0;
		float ceil_l = mix(1.15, 0.55, smoothstep(0.0, 1.0, (f.y - win.y) / max(0.01, win.w - win.y)));
		emit = col * lit_energy * (0.3 + 0.7 * h21(cell + 5.0)) * on * blinds * curtain * ceil_l;
	}
	vec2 fw = fwidth(g);
	float near = clamp(1.6 - max(fw.x, fw.y) * 3.0, 0.0, 1.0);
	float area = (win.z - win.x) * (win.w - win.y);
	vec3 far_glow = vec3(0.9, 0.78, 0.62) * lit_energy * share * area * 0.55;
	EMISSION = mix(far_glow, emit * glass, near);
	ALBEDO = a * mix(1.0, (r < share ? 0.55 : 1.0), glass);
	ROUGHNESS = mix(wall_rough, glass_rough, glass * near);
	METALLIC = mix(0.1, 0.5, glass * near);
}
