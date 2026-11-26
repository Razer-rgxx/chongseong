shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
// 시대 균열(docs/rift_raid.md): 세로로 찢어진 틈. 차가운 푸른 정전기, 금빛 먼지, 재가 섞인다. 싸고 웹에서도 돈다(텍스처 없이 해시 잡음만).

uniform float power : hint_range(0.0, 2.0) = 1.0;   // 1 평소, 커지면 더 밝고 크게 일렁인다
uniform vec3 cold : source_color = vec3(0.35, 0.72, 1.0);
uniform vec3 gold : source_color = vec3(1.0, 0.78, 0.3);
uniform vec3 ash : source_color = vec3(0.34, 0.31, 0.3);

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float x = (uv.x - 0.5) * 2.0;
	float y = uv.y;
	// 찢어진 가운데 줄: 위아래로 갈수록 가늘어지고 어긋나며 흔들린다
	float taper = sin(clamp(y, 0.0, 1.0) * 3.14159);
	float jag = (vnoise(vec2(y * 9.0, floor(TIME * 6.0))) - 0.5) * 0.28 * taper + sin(y * 7.0 + TIME * 1.3) * 0.05;
	float w = (0.05 + 0.16 * taper) * (0.85 + 0.3 * power);
	float d = abs(x - jag);
	float core = smoothstep(w, 0.0, d);
	float halo = smoothstep(0.85, 0.0, abs(x)) * taper;
	// 정전기: 칸마다 번쩍이는 점
	vec2 cell = floor(uv * vec2(34.0, 70.0));
	float st = hash(cell + floor(TIME * 18.0));
	float stat = step(0.93, st) * smoothstep(0.7, 0.0, abs(x)) * taper;
	// 금빛 먼지: 천천히 오르는 알갱이
	vec2 dc = floor(vec2(uv.x * 22.0, uv.y * 40.0 - TIME * 3.0));
	float dust = step(0.955, hash(dc + 7.0)) * halo;
	// 재: 가장자리를 따라 떨어지는 어두운 점
	vec2 ac = floor(vec2(uv.x * 26.0, uv.y * 46.0 + TIME * 2.2));
	float ashp = step(0.94, hash(ac + 31.0)) * smoothstep(0.2, 0.9, abs(x)) * taper;
	// 틈 안쪽은 시대가 섞인다: 높이에 따라 푸른색과 금색이 번갈아 비친다
	float mixv = 0.5 + 0.5 * sin(y * 11.0 - TIME * 2.0 + vnoise(vec2(y * 4.0, TIME)) * 4.0);
	vec3 inner = mix(cold, gold, mixv * 0.55);
	vec3 col = inner * (core * 2.2 + halo * 0.35) * power;
	col += cold * stat * 2.0 + gold * dust * 1.6;
	col = mix(col, ash * 0.6, ashp * 0.8);
	float a = clamp(core + halo * 0.28 + stat + dust * 0.9 + ashp * 0.55, 0.0, 1.0) * clamp(1.0 - abs(x) * 0.15, 0.0, 1.0);
	ALBEDO = col;
	ALPHA = a * (0.85 + 0.15 * sin(TIME * 23.0 + y * 5.0));
}
