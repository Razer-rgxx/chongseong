shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;
// 화면 전체에 덮는 모션 블러. 카메라가 지난 프레임에서 이번 프레임까지 움직인 만큼 화면을 번지게 한다.
// 가까운 것(영주와 바로 앞의 적, mask_near m 안)은 번지지 않게 해서 싸움은 또렷하고 배경만 흐른다.
// radial: 돌진·갈고리 때 화면 가장자리가 가운데로 빨려 드는 속도감(0이면 없음).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform mat4 prev_view;
uniform float strength = 0.5;
uniform float max_len = 0.04;
uniform float mask_near = 9.0;
uniform float radial = 0.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).x;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float lin = -view.z;
	vec4 world = INV_VIEW_MATRIX * vec4(view.xyz, 1.0);
	vec4 prev_clip = PROJECTION_MATRIX * prev_view * world;
	vec2 prev_uv = (prev_clip.xy / max(prev_clip.w, 0.0001)) * 0.5 + 0.5;
	vec2 vel = (SCREEN_UV - prev_uv) * strength;
	float l = length(vel);
	if (l > max_len) {
		vel *= max_len / l;
	}
	float far_w = smoothstep(mask_near, mask_near * 1.8, lin);
	vel *= far_w;
	vec2 from_mid = SCREEN_UV - 0.5;
	vel += from_mid * radial * smoothstep(0.12, 0.55, length(from_mid)) * mix(0.35, 1.0, far_w);
	vec3 c = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float t = float(i) / 7.0 - 0.5;
		c += textureLod(screen_tex, SCREEN_UV - vel * t, 0.0).rgb;
	}
	ALBEDO = c / 8.0;
}
