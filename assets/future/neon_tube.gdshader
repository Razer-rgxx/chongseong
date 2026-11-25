shader_type spatial;
// 네온 시가 Blender 건물의 네온관(2026-11-25 사용자: "건물 네온좀 ai 티 안나게").
// 진짜 네온관처럼: 정면으로 보이는 가운데는 거의 흰빛으로 달아오르고, 가장자리로 갈수록 색이 짙고 어두워진다.
// 관마다(세계 자리 4m 칸) 밝기가 조금씩 다르고, 몇 개는 가끔 지직거리며 꺼진다(낡은 변압기). 같은 색 판처럼 고르게 빛나지 않게.
uniform vec3 tint : source_color = vec3(0.2, 0.9, 1.0);
uniform float energy = 2.2;
uniform float buzz = 0.08;   // 지직거리는 관의 몫

varying vec3 wpos;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float core = pow(facing, 3.0);
	vec3 c = mix(tint * 0.55, mix(tint, vec3(1.0), 0.55), core);   // 가장자리는 짙은 색, 가운데는 흰빛 섞인 색
	vec2 cell = floor(wpos.xz / 4.0) + floor(wpos.y / 4.0);
	float k = h21(cell);
	float lvl = 0.7 + 0.3 * h21(cell + 3.0);
	if (k < buzz) {   // 낡은 관: 대부분 켜져 있다가 가끔 짧게 꺼지거나 흐려진다
		float t = floor(TIME * 9.0 + k * 50.0);
		lvl *= mix(1.0, step(0.25, h21(vec2(t, k * 31.0))), step(0.82, h21(vec2(floor(TIME * 0.7 + k * 9.0), 7.0))));
	}
	ALBEDO = c * 0.25;
	ROUGHNESS = 0.35;
	EMISSION = c * energy * lvl * (0.55 + 0.45 * core);
}
