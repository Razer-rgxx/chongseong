shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// 가로등 밑 땅에 비친 빛 웅덩이(2026-11-25 "더 ai 스럽지 않게"). MultiMesh 판마다 색(COLOR: 나트륨 주황·흰 LED)과 세기(a).
// 가운데가 밝고 가장자리로 부드럽게 사라진다. 빛을 내는 대신 더하기로 칠해서 가볍다.
uniform float energy = 1.1;

varying vec4 col;

void vertex() {
	col = COLOR;
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float k = pow(clamp(1.0 - d, 0.0, 1.0), 2.2);
	ALBEDO = col.rgb * k * energy * col.a;
}
