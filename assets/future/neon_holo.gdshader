shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
// 광장의 홀로그램(2026-11-25): 더하는 빛, 흐르는 주사선, 제자리에서 돈다(spin, 라디안/초).
uniform vec3 tint : source_color = vec3(0.2, 0.85, 1.0);
uniform float spin = 0.4;
uniform float alpha = 0.55;

void vertex() {
	float a = TIME * spin;
	mat2 r = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a)));
	VERTEX.xz = r * VERTEX.xz;
}

void fragment() {
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float scan = 0.55 + 0.45 * sin(wp.y * 9.0 - TIME * 5.0);
	float flick = 0.85 + 0.15 * sin(TIME * 23.0);
	ALBEDO = tint * scan * flick * alpha * 2.0;
}
