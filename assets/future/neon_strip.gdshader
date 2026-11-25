shader_type spatial;
// 네온 시가의 네온 줄과 지붕 등(2026-11-25). 색은 MultiMesh 색(COLOR), INSTANCE_CUSTOM.a는 위상.
// blink > 0이면 느리게 깜빡이는 등(지붕 꼭대기 붉은 등), 아니면 가끔 살짝 흔들리는 네온.
uniform float energy = 3.0;
uniform float blink = 0.0;
varying vec4 col;
varying float ph;

void vertex() {
	col = COLOR;
	ph = INSTANCE_CUSTOM.a;
}

void fragment() {
	float k = 1.0;
	if (blink > 0.0) {
		k = 0.08 + step(0.82, fract(TIME * blink + ph));
	} else {
		k = 0.88 + 0.12 * sin(TIME * (3.0 + ph * 5.0) + ph * 40.0);
	}
	ALBEDO = vec3(0.0);
	ROUGHNESS = 0.4;
	EMISSION = col.rgb * energy * k;
}
