shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// 설계선(상자 하나). 모서리를 선으로 그린다. 아직 안 지어진 부분은 진하게, 지어진 부분은 옅게, 뒤쪽 모서리는 더 옅게.

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec3 half_size = vec3(1.0);
uniform vec3 line_col : source_color = vec3(0.82, 0.94, 1.0);
uniform float width = 0.028;
uniform float built_alpha = 0.22;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
	VERTEX += NORMAL * 0.004;
}

void fragment() {
	vec3 d = half_size - abs(lp);
	float m1 = min(min(d.x, d.y), d.z);
	float m3 = max(max(d.x, d.y), d.z);
	float m2 = d.x + d.y + d.z - m1 - m3;
	float edge = 1.0 - smoothstep(width, width + fwidth(m2) * 1.5, m2);
	float h = (lp.y + half_size.y) / (2.0 * half_size.y);
	bool above = h > progress;
	float a = edge * (above ? 0.95 : built_alpha);
	if (!FRONT_FACING) {
		a *= 0.35;
	}
	if (above) {
		a = max(a, 0.07);
	}
	float scan = (1.0 - smoothstep(0.0, 0.015, abs(h - progress))) * step(progress, 0.999) * step(0.001, progress);
	ALBEDO = line_col;
	ALPHA = clamp(max(a, scan), 0.0, 1.0);
}
