shader_type spatial;
render_mode cull_disabled;
// 풀 한 포기(가는 잎 여러 장). 끝으로 갈수록 바람에 흔들리고 색이 바랜다.
// 인스턴스 색의 r: 밝기, g: 바랜 정도, b: 흔들림 위상.

uniform vec3 base_color : source_color = vec3(0.2, 0.21, 0.12);
uniform vec3 tip_color : source_color = vec3(0.36, 0.38, 0.22);
uniform vec3 dry_color : source_color = vec3(0.42, 0.36, 0.24);
uniform float wind = 0.12;
uniform float wind_speed = 1.3;
// 이 거리(m)를 넘으면 풀이 줄어들어 사라진다
uniform float fade_from = 40.0;
uniform float fade_to = 60.0;

varying float h;
varying vec3 ic;

void vertex() {
	h = UV.y;
	ic = INSTANCE_CUSTOM.rgb;
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	VERTEX *= 1.0 - smoothstep(fade_from, fade_to, distance(wp, CAMERA_POSITION_WORLD));
	float s = sin(TIME * wind_speed + wp.x * 0.15 + wp.z * 0.11 + ic.b * 6.28);
	float g = sin(TIME * wind_speed * 2.3 + wp.z * 0.4) * 0.35;
	VERTEX.x += (s + g) * wind * h * h;
	VERTEX.z += (s * 0.5) * wind * h * h;
	// 잎의 앞뒤가 따로 어두워지지 않게 위를 보는 법선
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.7));
}

void fragment() {
	vec3 tip = mix(tip_color, dry_color, ic.g);
	vec3 c = mix(base_color, tip, pow(h, 0.8)) * (0.7 + 0.5 * ic.r);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	BACKLIGHT = vec3(0.25, 0.25, 0.12) * h;
	AO = mix(0.6, 1.0, h);
	AO_LIGHT_AFFECT = 0.6;
}
