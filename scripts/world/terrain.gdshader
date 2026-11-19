shader_type spatial;
// 언덕의 땅. 풀(forrest_ground_01), 흙(forest_ground_04), 바위(lichen_rock) 사진 질감을 섞는다.
// 싸움터 안은 짓밟힌 흙, 밖은 풀, 가파른 비탈은 바위. 큰 얼룩 잡음으로 반복 무늬를 감춘다.

uniform sampler2D grass_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_r : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D dirt_r : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_a : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D macro : filter_linear_mipmap, repeat_enable;

// 싸움터 사각형(m): x0, z0, x1, z1
uniform vec4 arena = vec4(0.0, 0.0, 68.0, 44.0);
// 질감 한 장이 덮는 길이(m)
uniform float tile = 3.5;
uniform float rock_tile = 7.0;
uniform vec3 grass_tint : source_color = vec3(0.62, 0.64, 0.56);
uniform vec3 dirt_tint : source_color = vec3(0.5, 0.47, 0.44);
uniform vec3 rock_tint : source_color = vec3(0.6, 0.6, 0.58);

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	// 위에서 내려다 붙이는 질감(u는 +x, v는 +z)에 맞춘 접선
	TANGENT = normalize(cross(NORMAL, vec3(0.0, 0.0, 1.0)));
	BINORMAL = normalize(cross(NORMAL, TANGENT));
}

// 같은 질감을 두 번(크기와 방향을 바꿔) 읽어 섞는다. 반복 무늬가 덜 보인다.
vec2 turn(vec2 uv) {
	return mat2(vec2(0.8, -0.6), vec2(0.6, 0.8)) * uv * 0.43 + vec2(0.31, 0.77);
}
#define TWO(t, uv, k) mix(texture(t, uv), texture(t, turn(uv)), k)

void fragment() {
	vec2 uv = wpos.xz / tile;
	float m1 = texture(macro, wpos.xz / 70.0).r;
	float m2 = texture(macro, wpos.xz / 17.0 + vec2(0.37, 0.11)).r;
	float k = smoothstep(0.35, 0.65, m2);

	// 싸움터 밖으로의 거리(안이면 음수)
	vec2 q = max(arena.xy - wpos.xz, wpos.xz - arena.zw);
	float out_d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0);
	float dirt_w = smoothstep(3.5, -2.5, out_d + (m2 - 0.5) * 7.0);
	// 싸움터 안에도 풀이 남은 자리, 밖에도 흙이 드러난 자리
	dirt_w = clamp(dirt_w - smoothstep(0.74, 0.88, m2) * 0.35 * step(out_d, 0.0), 0.0, 1.0);
	dirt_w = max(dirt_w, smoothstep(0.6, 0.75, m1) * 0.7 * step(0.0, out_d));

	float steep = 1.0 - clamp(wnrm.y, 0.0, 1.0);
	float rock_w = smoothstep(0.2, 0.42, steep + (m2 - 0.5) * 0.18);

	vec3 ga = TWO(grass_a, uv, k).rgb * grass_tint;
	vec3 da = TWO(dirt_a, uv * 0.9, k).rgb * dirt_tint;
	vec3 gn = TWO(grass_n, uv, k).rgb;
	vec3 dn = TWO(dirt_n, uv * 0.9, k).rgb;
	float gr = TWO(grass_r, uv, k).r;
	float dr = TWO(dirt_r, uv * 0.9, k).r;

	// 바위는 세 방향에서 비춰 붙인다(비탈에서 늘어나지 않게)
	vec3 bw = pow(abs(wnrm), vec3(6.0));
	bw /= (bw.x + bw.y + bw.z);
	vec3 ra = (texture(rock_a, wpos.zy / rock_tile).rgb * bw.x
		+ texture(rock_a, wpos.xz / rock_tile).rgb * bw.y
		+ texture(rock_a, wpos.xy / rock_tile).rgb * bw.z) * rock_tint;
	vec3 rn = texture(rock_n, wpos.xz / rock_tile).rgb;

	vec3 alb = mix(ga, da, dirt_w);
	vec3 nm = mix(gn, dn, dirt_w);
	float rough = mix(gr, dr, dirt_w);
	alb = mix(alb, ra, rock_w);
	nm = mix(nm, mix(rn, vec3(0.5, 0.5, 1.0), bw.x + bw.z), rock_w);
	rough = mix(rough, 0.85, rock_w);

	// 큰 얼룩: 밝기를 조금씩 흔든다
	alb *= 0.86 + 0.24 * m1;
	ALBEDO = alb;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = 1.2;
	ROUGHNESS = clamp(rough, 0.55, 1.0);
	SPECULAR = 0.35;
}
