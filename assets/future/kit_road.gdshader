shader_type spatial;
// Kenney 길 조각(색표 한 장)을 젖은 낡은 아스팔트로 덮는다: 색표는 밝기만 쓰고(차선은 바래서 희미하게), 질감은 아스팔트 triplanar.
uniform sampler2D colormap : source_color, filter_linear_mipmap;
uniform sampler2D diff : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_t : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_m = 5.0;
uniform vec3 tint : source_color = vec3(0.55, 0.6, 0.78);
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec3 c = texture(colormap, UV).rgb;
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	vec3 a = texture(diff, wpos.xz / tile_m).rgb;
	ALBEDO = a * tint * mix(0.45, 1.1, pow(lum, 1.4));
	ROUGHNESS = clamp(texture(rough_t, wpos.xz / tile_m).r * 0.6, 0.1, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
