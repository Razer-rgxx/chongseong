shader_type canvas_item;
// 고르기 창 뒤 화면을 흐리고 어둡게(2026-11-28, 영상의 카드 뒤 배경): 카드에 눈이 모이게.
// 밉맵 없이 두 고리 16번 + 가운데를 섞는 흐림이라 호환 렌더러·웹에서도 돈다. dim은 0(그대로)~1(다 어둡게, 열 때 0에서 올린다).
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float radius = 7.0;      // 흐림 반지름(화소)
uniform float dim : hint_range(0.0, 1.0) = 1.0;
uniform float darkness = 0.72;   // dim 1일 때 어둡게 할 몫

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * radius * dim;
	vec3 sum = texture(screen_tex, SCREEN_UV).rgb;
	float n = 1.0;
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		vec2 d = vec2(cos(a), sin(a));
		sum += texture(screen_tex, SCREEN_UV + d * px * 0.5).rgb;
		sum += texture(screen_tex, SCREEN_UV + vec2(d.x * 1.15, d.y * 0.85) * px).rgb;   // 가로로 조금 더 번지게
		n += 2.0;
	}
	vec3 c = sum / n;
	COLOR = vec4(c * (1.0 - darkness * dim), 1.0);
}
