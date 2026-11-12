shader_type spatial;
// 지어진 부분(상자 하나). progress 아래만 돌로 채우고, 채워지는 경계에 빛나는 띠를 그린다.

uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform vec3 half_size = vec3(1.0);
uniform vec3 base_color : source_color = vec3(0.78, 0.72, 0.63);
uniform vec3 glow : source_color = vec3(0.55, 0.88, 1.0);
uniform float course = 0.5;

varying vec3 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float h = (lp.y + half_size.y) / (2.0 * half_size.y);
	if (h > progress + 0.0001) {
		discard;
	}
	// 돌을 쌓은 줄
	float c = abs(fract(lp.y / course) - 0.5) * course;
	float line = 1.0 - smoothstep(0.012, 0.012 + fwidth(lp.y) * 1.5, c);
	ALBEDO = base_color * (1.0 - line * 0.18);
	ROUGHNESS = 0.85;
	float band = (1.0 - smoothstep(0.0, 0.06, progress - h)) * step(progress, 0.999);
	EMISSION = glow * band * 3.0;
}
