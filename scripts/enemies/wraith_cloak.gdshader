shader_type spatial;
render_mode cull_disabled;
// 망령의 해진 망토. 아래로 갈수록 펄럭이고 끝단이 잡음 모양으로 찢겨 있다. 가장자리가 희미하게 빛난다.
// UV.y: 끝단 0 ~ 꼭대기 1. tint(rgb, 세기)와 flash는 상태 빛과 맞았을 때 번쩍임. fade는 나타나고 흩어질 때.

uniform vec3 cloth : source_color = vec3(0.06, 0.055, 0.075);
uniform vec3 rim : source_color = vec3(0.62, 0.56, 0.9);
uniform float rim_power = 2.6;
uniform float rim_energy = 1.1;
uniform sampler2D tatter : filter_linear_mipmap, repeat_enable;
uniform float flutter = 0.07;
uniform float tear = 0.32;
uniform float phase = 0.0;
uniform vec4 tint = vec4(0.0);
uniform float flash = 0.0;
uniform float fade = 1.0;

varying float vy;

void vertex() {
	vy = UV.y;
	float a = UV.x * 6.2832;
	float w = pow(1.0 - vy, 2.0);
	VERTEX.x += sin(TIME * 3.1 + a * 2.0 + vy * 5.0 + phase) * flutter * w;
	VERTEX.z += cos(TIME * 2.6 + a * 3.0 + vy * 4.0 + phase) * flutter * w;
	VERTEX.y += sin(TIME * 4.0 + a * 4.0 + phase) * flutter * 0.4 * w;
}

void fragment() {
	float n = texture(tatter, vec2(UV.x * 3.0, vy * 0.7 + TIME * 0.04 + phase)).r;
	// 끝단에서 tear 높이까지는 잡음이 높은 곳만 남는다(찢긴 띠)
	float keep = n - 0.55 + smoothstep(0.0, tear, vy) * 0.8;
	float n2 = texture(tatter, UV * 1.7 + vec2(phase)).r;
	keep = min(keep, n2 - (1.0 - fade));
	ALPHA = keep > 0.0 ? 1.0 : 0.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	vec3 c = mix(cloth, tint.rgb * 0.5, tint.a);
	float fr = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	vec3 e = rim * fr * rim_energy * (0.4 + 0.6 * vy) + tint.rgb * tint.a * 0.4;
	if (!FRONT_FACING) {
		c *= 0.25;
		e *= 0.15;
	}
	ALBEDO = mix(c, vec3(1.0), flash);
	EMISSION = e + vec3(flash * 1.5);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
