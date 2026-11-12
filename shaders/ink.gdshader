shader_type spatial;
// 번짐: 밤마다 쳐들어와 설계도를 지우는 먹물 덩어리. 일렁이고, 가장자리만 보랏빛으로 빛난다.

uniform vec3 ink : source_color = vec3(0.015, 0.015, 0.035);
uniform vec3 rim : source_color = vec3(0.5, 0.28, 0.95);
uniform float wobble = 0.1;
uniform float speed = 2.2;

void vertex() {
	float t = TIME * speed;
	VERTEX += NORMAL * wobble * (sin(VERTEX.y * 7.0 + t) * 0.5 + sin(VERTEX.x * 6.0 - t * 1.3) * 0.35 + sin(VERTEX.z * 5.0 + t * 0.7) * 0.25);
}

void fragment() {
	float f = pow(1.0 - abs(dot(NORMAL, VIEW)), 3.0);
	ALBEDO = ink;
	ROUGHNESS = 0.12;
	SPECULAR = 0.9;
	EMISSION = rim * f * 1.4;
}
