shader_type spatial;
// 네온 시가 Blender 건물의 LED 줄(2026-11-25 사용자: "사이버펑크 조사보고 건물 led 재질 색 모양 손봐").
// 둥근 네온 플렉스 관(PMMA)처럼: 빛이 관 안에서 고르게 퍼지고, 정면 가운데만 조금 밝고 옅으며 가장자리는 짙은 색.
// 건물(세계 24m 칸)마다 실선이거나 아르데코식 점선(dash 몫), 몇 토막은 LED가 나갔다. 깜빡이지 않는다.
uniform vec3 tint : source_color = vec3(0.0, 0.78, 1.0);
uniform float energy = 2.6;
uniform float dead = 0.04;
uniform float dash = 0.4;   // 점선인 건물의 몫

varying vec3 wpos;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
	vec3 c = mix(tint * 0.7, mix(tint, vec3(1.0), 0.28), facing * facing);   // 가운데는 옅게, 가장자리는 짙게
	float bld = h21(floor(wpos.xz / 24.0) + 0.5);
	float on = 1.0;
	if (bld < dash) {   // 점선: 관을 따라 1.6m마다 1m 켜짐(축이 무엇이든 세계 좌표 합이 관을 따라 변한다)
		on = step(0.38, fract((wpos.x + wpos.y + wpos.z) / 1.6 + bld * 7.0));
	}
	vec2 cell = floor(wpos.xz / 2.0) + floor(wpos.y / 2.0) * 17.0;
	float k = h21(cell);
	float lvl = k < dead ? 0.04 : 0.88 + 0.12 * h21(cell + 3.0);
	ALBEDO = c * 0.3;
	ROUGHNESS = 0.25;
	EMISSION = c * energy * lvl * on;
}
