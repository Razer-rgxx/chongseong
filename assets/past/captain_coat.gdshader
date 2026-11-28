shader_type spatial;
// 닻의 선장 연미복 껍데기(2026-11-26, 사용자 "옷에서 코드로 만든 티가 좀 덜나게"): NpcModel이 몸 메시를 한 겹 부풀려 만든 껍데기에 칠한다.
// 칠할 자리는 묶을 때 자세(T자세)의 위치로 정한다(UV2 = x,y, UV.x = z, 모델 앞은 +Z): 그래서 팔다리가 움직여도 무늬가 옷에 붙어 있다.
// 금빛 조끼와 둥근 단추, V로 넓어지는 파란 깃과 금테, 파란 소맷부리와 금띠, 꼬리 밑단 금띠, 옷감 결과 주름 그늘.

uniform vec3 coat : source_color = vec3(0.07, 0.08, 0.14);
uniform vec3 facing : source_color = vec3(0.1, 0.22, 0.55);
uniform vec3 vest : source_color = vec3(0.42, 0.3, 0.14);
uniform vec3 gold : source_color = vec3(0.8, 0.62, 0.26);

varying vec3 bp;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	bp = vec3(UV2.x, UV2.y, UV.x);
}

void fragment() {
	vec3 c = coat;
	float metal = 0.0;
	float rough = 0.82;
	float ax = abs(bp.x);
	float y = bp.y;
	bool front = bp.z > 0.015;
	bool torso = ax < 0.26 && y > 0.8;
	float lap_in = 0.068;
	float lap_out = 0.075 + 0.075 * smoothstep(1.08, 1.44, y);
	bool gilded = false;
	if (front && torso && ax < lap_in && y > 0.97 && y < 1.45) {
		c = vest;   // 조끼
		vec2 b = vec2(ax - 0.038, mod(y - 1.08, 0.058) - 0.029);
		if (y > 1.06 && y < 1.36 && length(b) < 0.0105) {
			gilded = true;   // 두 줄 단추
		}
	}
	if (front && torso && ax >= lap_in && ax < lap_out && y > 1.06 && y < 1.47) {
		c = facing;   // 넓은 파란 깃
	}
	if (front && torso && y > 1.06 && y < 1.47 && (abs(ax - lap_out) < 0.006 || abs(ax - lap_in) < 0.004)) {
		gilded = true;   // 깃 금테
	}
	if (ax > 0.575) {
		c = facing;   // 소맷부리
	}
	if (abs(ax - 0.57) < 0.007) {
		gilded = true;
	}
	if (y < 0.4 && y > 0.37) {
		gilded = true;   // 꼬리 밑단
	}
	// 옷감 결(가는 사선)과 넓은 주름 그늘
	float weave = 0.94 + 0.06 * (0.5 + 0.5 * sin((bp.x + bp.y) * 520.0));
	float fold = 0.82 + 0.18 * noise(vec2(bp.x * 9.0, bp.y * 3.5) + bp.z * 4.0);
	if (gilded) {
		c = gold;
		metal = 0.75;
		rough = 0.35;
		weave = 1.0;
		fold = 0.9 + 0.1 * fold;
	}
	ALBEDO = c * weave * fold;
	METALLIC = metal;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	RIM = 0.25;
	RIM_TINT = 0.5;
}
