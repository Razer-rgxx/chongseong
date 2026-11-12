shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
// 아직 지어지지 않은 땅의 것(나무, 바위). 윤곽선, 등고선, 그늘 쪽 빗금만 그린다.

uniform vec3 line_col : source_color = vec3(0.75, 0.87, 1.0);
uniform float spacing = 0.32;
uniform float fill = 0.06;
uniform vec3 light_dir = vec3(-0.5, 0.8, -0.35);

varying vec3 wp;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float f = 1.0 - abs(dot(NORMAL, VIEW));
	float sil = smoothstep(0.62, 0.85, f);
	float c = abs(fract(wp.y / spacing) - 0.5) * spacing;
	float contour = 1.0 - smoothstep(0.01, 0.01 + fwidth(wp.y) * 1.5, c);
	vec3 l = normalize((VIEW_MATRIX * vec4(light_dir, 0.0)).xyz);
	float shade = smoothstep(0.15, -0.35, dot(NORMAL, l));
	float s = wp.x + wp.y * 0.7 + wp.z;
	float hc = abs(fract(s / 0.16) - 0.5) * 0.16;
	float hatch = shade * (1.0 - smoothstep(0.008, 0.008 + fwidth(s) * 1.5, hc));
	ALBEDO = line_col;
	ALPHA = clamp(max(max(sil, contour * 0.55), hatch * 0.55) + fill, 0.0, 1.0);
}
