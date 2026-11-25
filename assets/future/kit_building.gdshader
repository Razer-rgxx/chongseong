shader_type spatial;
// 녹슨 미래 구역의 건물: Kenney City Kit 모델(색표 한 장)을 어둡고 차갑게 덮는다. 창(색표의 파란 칸)은 월드 자리로 켜진 창·깨진 창을 가른다.
// 콘크리트 질감은 월드 triplanar, 녹물 줄과 아래쪽 때는 높이로 그린다.
uniform sampler2D colormap : source_color, filter_linear_mipmap;
uniform sampler2D conc_diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D conc_rough : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_m = 6.0;
uniform vec3 tint : source_color = vec3(0.62, 0.68, 0.85);
uniform float lit_energy = 2.6;
uniform float seed = 3.0;

varying vec3 wpos;
varying vec3 wnrm;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed) * 43758.5453);
}

vec3 tri(sampler2D t, vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	return texture(t, p.zy / tile_m).rgb * w.x + texture(t, p.xz / tile_m).rgb * w.y + texture(t, p.xy / tile_m).rgb * w.z;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 c = texture(colormap, UV).rgb;
	vec3 n = normalize(wnrm);
	float mx = max(c.r, max(c.g, c.b));
	float mn = min(c.r, min(c.g, c.b));
	bool glass = (mx - mn) > 0.28 && c.b > c.g + 0.04 && c.g > c.r + 0.04;
	float along = abs(n.x) > abs(n.z) ? wpos.z : wpos.x;
	float side = n.x * 5.0 + n.z * 9.0;
	vec3 conc = tri(conc_diff, wpos, n);
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 alb = conc * tint * (0.5 + lum * 0.9);
	float vertical = 1.0 - abs(n.y);
	// 녹물 줄: 위가 진하고 아래로 옅어진다
	float band = floor(wpos.y / 9.0);
	float hs = h21(vec2(floor(along / 1.1), band + side));
	float cx = abs(fract(along / 1.1) - 0.5);
	float streak = step(0.72, hs) * pow(1.0 - fract(wpos.y * 0.111 + hs * 9.0), 3.0) * smoothstep(0.35, 0.12, cx);
	alb = mix(alb, vec3(0.2, 0.09, 0.04), streak * 0.6 * vertical);
	alb *= mix(0.45, 1.0, smoothstep(0.0, 6.0, wpos.y));
	float rough = tri(conc_rough, wpos, n).r;
	float metal = 0.0;
	vec3 emit = vec3(0.0);
	if (glass && vertical > 0.5) {
		vec2 cell = floor(vec2(along / 3.3, wpos.y / 3.6));
		float r = h21(cell + vec2(11.0 + side, 7.0));
		alb = vec3(0.03, 0.04, 0.065);
		rough = 0.12;
		metal = 0.6;
		if (r < 0.09) {
			emit = vec3(1.0, 0.6, 0.26) * lit_energy * (0.75 + 0.25 * h21(cell));
			alb = vec3(0.3, 0.2, 0.1);
		} else if (r < 0.17) {
			emit = vec3(0.3, 0.6, 0.9) * lit_energy * (0.75 + 0.25 * h21(cell));
			alb = vec3(0.1, 0.18, 0.28);
		} else if (r < 0.32) {
			alb = vec3(0.006);
			rough = 0.9;
			metal = 0.0;
		}
	}
	ALBEDO = alb;
	ROUGHNESS = clamp(rough, 0.05, 1.0);
	METALLIC = metal;
	EMISSION = emit;
}
