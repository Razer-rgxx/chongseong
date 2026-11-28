shader_type sky;
// 낮 하늘과 밤 하늘(Poly Haven HDRI)을 night 값으로 섞는다. main이 낮밤이 바뀔 때 night를 0↔1로 옮긴다.

uniform sampler2D day_sky : filter_linear, repeat_enable;
uniform sampler2D night_sky : filter_linear, repeat_enable;
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float day_energy = 1.0;
uniform float night_energy = 0.35;
// 하늘의 색을 조금 빼서 땅의 어두운 사실풍과 맞춘다
uniform float saturation = 0.75;
uniform vec3 tint : source_color = vec3(1.0);

void sky() {
	vec3 d = texture(day_sky, SKY_COORDS).rgb * day_energy;
	vec3 n = texture(night_sky, SKY_COORDS).rgb * night_energy;
	vec3 c = mix(d, n, night);
	float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
	COLOR = mix(vec3(l), c, saturation) * tint;
}
