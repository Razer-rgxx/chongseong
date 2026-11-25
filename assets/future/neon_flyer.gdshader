shader_type spatial;
// 하늘길을 지나는 차(2026-11-25): 판마다 INSTANCE_CUSTOM r = 빠르기(m/초), g = 위상(0~1), b = 길 길이(m).
// 꼭짓점을 제 x축(앞쪽)으로 밀어 길을 따라 되풀이한다. 앞은 흰 등, 뒤는 붉은 등, 몸은 어두운 쇠.
uniform vec3 body : source_color = vec3(0.04, 0.045, 0.06);
varying float front;

void vertex() {
	front = VERTEX.x;
	float len = max(INSTANCE_CUSTOM.b, 1.0);
	float off = mod(TIME * INSTANCE_CUSTOM.r + INSTANCE_CUSTOM.g * len, len) - len * 0.5;
	VERTEX.x += off;
}

void fragment() {
	ALBEDO = body;
	METALLIC = 0.7;
	ROUGHNESS = 0.3;
	float head = smoothstep(1.0, 1.2, front);
	float tail = smoothstep(-1.0, -1.2, front);
	EMISSION = vec3(1.0, 0.95, 0.85) * head * 5.0 + vec3(1.0, 0.1, 0.12) * tail * 4.0;
}
