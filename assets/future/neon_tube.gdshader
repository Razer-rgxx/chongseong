shader_type spatial;
// 네온 시가 Blender 건물의 LED 줄(2026-11-25 사용자: "건물 led만 바꾸라고", "led 색이랑 디자인이 별로임").
// 알루미늄 홈에 든 확산형 LED 줄처럼: 앞에서 보면 고르고 부드럽게 빛나고(흰 심 없음), 옆으로 갈수록 어두운 홈 테가 보인다.
// 몇 토막(세계 자리 2m 칸)은 LED가 나가 어둡거나 반쯤만 켜져 있다. 깜빡이거나 지직거리지 않는다(LED는 그러지 않는다).
uniform vec3 tint : source_color = vec3(1.0, 0.8, 0.56);
uniform float energy = 1.6;
uniform float dead = 0.07;   // 나간 토막의 몫

varying vec3 wpos;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	float diffuser = smoothstep(0.15, 0.6, facing);              // 비스듬하면 홈 테(어두운 알루미늄)가 보인다
	vec2 cell = floor(wpos.xz / 2.0) + floor(wpos.y / 2.0) * 17.0;
	float k = h21(cell);
	float lvl = k < dead ? 0.05 : (k < dead * 1.6 ? 0.45 : 0.9 + 0.1 * h21(cell + 3.0));
	ALBEDO = mix(vec3(0.08, 0.085, 0.09), tint * 0.35, diffuser);
	METALLIC = mix(0.8, 0.0, diffuser);
	ROUGHNESS = mix(0.35, 0.6, diffuser);
	EMISSION = tint * energy * lvl * diffuser;
}
