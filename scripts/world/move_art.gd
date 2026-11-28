class_name MoveArt
extends RefCounted
## 좌클릭 동작 20가지를 그리는 모양과 재질(아트팀, docs/attacks.md 5절). MoveFx(이펙트팀)가 이것으로 그린다.
## 노드에 기대지 않는 정적 함수만 둔다. 부를 때마다 새 메시와 새 재질을 돌려준다(셰이더 자체는 같이 쓴다).
## 길이는 미터다. 땅에 눕는 것(고리, 띠, 금)은 XZ 평면(y = 0)에 있고 앞은 -Z다. 땅에 둘 때는 y를 0.03쯤 띄운다.
## 셰이더는 모두 unshaded이고 텍스처를 쓰지 않아서 Forward+와 Compatibility 둘 다에서 같게 보인다.
## 우주·은하 같은 것은 쓰지 않는다. 쇠의 빛, 그을린 땅, 갈라진 틈으로만 그린다.

const STEEL := Color(0.86, 0.9, 0.97)
const FIRE := Color(1.0, 0.4, 0.09)
const ICE := Color(0.56, 0.82, 1.0)
const BOLT := Color(0.76, 0.66, 1.0)
const BLOOD := Color(0.6, 0.03, 0.05)
const ELEMENTS: Array[StringName] = [&"fire", &"ice", &"bolt", &"blood"]

## 셰이더에서 같이 쓰는 값 잡음(텍스처 없이).
const NOISE := """
float ma_hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float ma_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = ma_hash(i);
	float b = ma_hash(i + vec2(1.0, 0.0));
	float c = ma_hash(i + vec2(0.0, 1.0));
	float d = ma_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
vec3 ma_hot(vec3 c, float white) {
	vec3 h = c / max(max(c.r, c.g), max(c.b, 0.001));
	return mix(h, vec3(1.0), white);
}
"""

## 검기: 앞 테(UV.y = 0.8) 가까이 밝고 가는 심, 뒤(안쪽)로 갈수록 옅어지는 몸통, 양 끝은 사라진다.
const WAVE_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(0.86, 0.9, 0.97, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float core_white : hint_range(0.0, 1.0) = 0.6;
%s
void fragment() {
	float u = UV.x;
	float v = UV.y;
	float mid = sin(u * PI);
	float tips = smoothstep(0.0, 0.2, u) * (1.0 - smoothstep(0.8, 1.0, u));
	float core = exp(-pow((v - 0.8) / (0.04 + 0.05 * mid), 2.0));
	float body = pow(clamp(v, 0.0, 1.0), 1.15) * (1.0 - smoothstep(0.88, 1.0, v));
	float grain = ma_noise(vec2(u * 7.0 - TIME * 4.0, v * 12.0));
	body *= 0.6 + 0.7 * grain;
	vec3 hot = ma_hot(color.rgb, core_white);
	ALBEDO = color.rgb * body * 1.15 + hot * core * 1.3;
	ALPHA = clamp(tips * fade * (0.55 + 0.45 * mid), 0.0, 1.0);
}
"""

## 땅의 자국: 그을린 어두운 바탕 + (glow면) glow_at 자리의 가는 빛줄. progress까지만 드러나고 드러나는 머리가 가장 밝다.
## 빛은 fade보다 먼저 식고(fade³), 그을음은 늦게 사라진다. 띠는 UV2.x = 1이라 양 끝이 뾰족하다.
const MARK_SHADER := """shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.55, 0.25, 1.0);
uniform float progress : hint_range(0.0, 1.0) = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float glow : hint_range(0.0, 1.0) = 1.0;
uniform float glow_at : hint_range(0.0, 1.0) = 0.5;
varying vec2 wxz;
varying float ends;
%s
void vertex() {
	wxz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	ends = UV2.x;
}
void fragment() {
	float u = UV.x;
	float v = UV.y;
	float shown = clamp((progress - u) / 0.02 + 1.0, 0.0, 1.0);
	if (shown <= 0.0) { discard; }
	float span = mix(1.0, clamp(min(u / 0.07, (1.0 - u) / 0.12), 0.0, 1.0), ends);
	float head_w = 0.07 * (1.0 - smoothstep(0.9, 1.0, progress));
	span *= mix(1.0, sqrt(clamp((progress - u) / max(head_w, 0.0001), 0.0, 1.0)), step(0.0001, head_w));
	span = max(span, 0.0001);
	float d = abs(v - 0.5) * 2.0 / span;
	float n1 = ma_noise(wxz * 2.2);
	float n2 = ma_noise(wxz * 7.5 + vec2(13.0, 7.0));
	float scorch = 1.0 - smoothstep(0.5 + n1 * 0.3, 1.0 + n2 * 0.08, d);
	scorch *= 0.72 + 0.28 * n2;
	float gd = abs(v - glow_at) / span;
	float slit = 1.0 - smoothstep(0.02, 0.09, gd);
	float line = exp(-pow(gd / 0.05, 2.0)) * (0.65 + 0.35 * n2) + exp(-pow(gd / 0.2, 2.0)) * 0.22;
	float head = (1.0 - smoothstep(0.0, 0.06, progress - u)) * (1.0 - step(0.999, progress));
	float gf = fade * fade * fade;
	float g = clamp(line * (0.85 + head * 1.6), 0.0, 1.0) * glow * gf;
	vec3 dark = mix(vec3(0.02, 0.015, 0.012), color.rgb * 0.1, 0.3);
	vec3 hot = mix(color.rgb * 0.55, ma_hot(color.rgb, 0.3), gf);
	float sf = smoothstep(0.0, 0.6, fade);
	ALBEDO = mix(dark, hot, clamp(g * 1.5, 0.0, 1.0));
	ALPHA = clamp(max(max(scorch * 0.86, slit * 0.92) * sf, g) * shown, 0.0, 1.0);
}
"""

## 갈라진 틈: grow까지 자라고, energy가 0이면 어두운 금, 1 이상이면 틈에서 빛이 난다(가운데가 더 뜨겁다).
const CRACK_SHADER := """shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(1.0, 0.5, 0.18, 1.0);
uniform float grow : hint_range(0.0, 1.0) = 1.0;
uniform float energy = 0.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	if (UV.x > grow) { discard; }
	float core = 1.0 - abs(UV.y - 0.5) * 2.0;
	float tip = 1.0 - smoothstep(grow - 0.08, grow, UV.x);
	float e = clamp(energy, 0.0, 1.0);
	float heat = 1.0 - UV.x * 0.55;
	vec3 hot = color.rgb * (0.7 + energy * 1.2) * heat;
	ALBEDO = mix(vec3(0.015, 0.011, 0.009), hot, smoothstep(0.35, 0.9, core) * e);
	ALPHA = clamp(smoothstep(0.0, 0.35, core) * tip * fade * 0.95, 0.0, 1.0);
}
"""

## 반격 번쩍임: 늘 카메라를 본다(빌보드). spin으로 화면 안에서 돌린다. 노드의 크기(scale)는 지킨다.
const GLINT_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(0.86, 0.9, 0.97, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float spin = 0.0;
uniform float core_white : hint_range(0.0, 1.0) = 0.6;
varying float halo;
%s
void vertex() {
	halo = UV2.x;
	float c = cos(spin);
	float s = sin(spin);
	VERTEX.xy = mat2(vec2(c, s), vec2(-s, c)) * VERTEX.xy;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	float u = UV.x;
	float a;
	if (halo > 0.5) {
		a = exp(-u * u * 4.5) * 0.5;
	} else {
		float across = abs(UV.y - 0.5) * 2.0 / max(1.0 - u, 0.001);
		a = pow(1.0 - clamp(across, 0.0, 1.0), 2.2) * pow(1.0 - u, 1.1);
	}
	vec3 hot = ma_hot(color.rgb, core_white);
	ALBEDO = mix(color.rgb, hot, clamp(a * 1.6, 0.0, 1.0)) * 1.3;
	ALPHA = clamp(a * fade, 0.0, 1.0);
}
"""

## 잔상 줄기: UV.x 0(꼬리, 오래된 쪽) → 1(머리). 가는 가닥 여러 줄이 꼬리 쪽에서 들쭉날쭉 시작한다.
const STREAK_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 color : source_color = vec4(0.86, 0.9, 0.97, 1.0);
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float core_white : hint_range(0.0, 1.0) = 0.6;
%s
void fragment() {
	float u = UV.x;
	float v = UV.y;
	float soft = smoothstep(0.0, 0.75, 1.0 - abs(v - 0.5) * 2.0);
	float lanes = 9.0;
	float lane = floor(v * lanes);
	float h = ma_hash(vec2(lane, 3.1));
	float h2 = ma_hash(vec2(lane, 8.7));
	float lw = 0.12 + 0.3 * h2;
	float strand = 1.0 - smoothstep(0.0, lw, abs(fract(v * lanes) - 0.3 - 0.4 * h));
	float start = h * 0.55;
	float along = smoothstep(start, start + 0.4, u) * (1.0 - smoothstep(0.88, 1.0, u));
	float a = soft * (0.32 + 0.68 * strand * (0.3 + 0.7 * h2)) * along;
	ALBEDO = mix(color.rgb, ma_hot(color.rgb, core_white), 0.5 * strand) * 1.2;
	ALPHA = clamp(a * fade, 0.0, 1.0);
}
"""

static var _shaders: Dictionary[String, Shader] = {}


# ---------------------------------------------------------------- 색

## 속성 색. &"" = 쇠의 흰빛, fire = 짙은 주황, ice = 푸른 흰빛, bolt = 차가운 흰 보라, blood = 검붉음.
static func element_color(el: StringName) -> Color:
	match el:
		&"fire":
			return FIRE
		&"ice":
			return ICE
		&"bolt":
			return BOLT
		&"blood":
			return BLOOD
	return STEEL


# ---------------------------------------------------------------- 검기

## 날아가는 초승달. XZ 평면에 눕고 앞(-Z)으로 불룩하다. width_m은 두 끝 사이(미터).
## 원점은 초승달의 가운데(앞끝과 두 끝의 중간)다. 가운데가 두껍고 끝은 뾰족하다.
## 바깥(앞) 테가 안쪽보다 높게 기울어(가운데 52°, 끝 15°로 꼬인다) 뒤의 3인칭 카메라에서도 면이 보인다.
## UV.x: 호를 따라 0..1(왼쪽 끝 → 오른쪽 끝), UV.y: 0 안쪽(뒤) → 1 바깥(앞) 테.
static func wave_mesh(width_m: float) -> ArrayMesh:
	var half: float = deg_to_rad(64.0)
	var r: float = width_m * 0.5 / sin(half)
	var sag: float = r * (1.0 - cos(half))
	var thick: float = width_m * 0.3
	var mid_z: float = r - sag * 0.5
	var segs: int = 40
	var rows: int = 3
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in segs + 1:
		var u: float = float(i) / segs
		var a: float = lerpf(-half, half, u)
		var out := Vector3(sin(a), 0.0, -cos(a))
		var along := Vector3(cos(a), 0.0, sin(a))
		var rim: Vector3 = Vector3(0.0, 0.0, mid_z) + out * r
		var body: float = sin(PI * u)
		var t: float = thick * maxf(pow(body, 0.75), 0.015)
		var tilt: float = deg_to_rad(lerpf(15.0, 52.0, body))
		var across: Vector3 = out * cos(tilt) + Vector3.UP * sin(tilt)
		var n: Vector3 = across.cross(along).normalized()
		var lift: float = t * sin(tilt) * 0.5
		for j in rows + 1:
			var v: float = float(j) / rows
			var bow: float = sin(PI * v) * t * 0.12
			verts.append(rim - across * t * (1.0 - v) + Vector3.UP * (lift + bow))
			norms.append(n)
			uvs.append(Vector2(u, v))
	return _commit(verts, norms, uvs, PackedVector2Array(), _grid_indices(segs, rows))


## 검기의 재질. 더해 그리고(additive) 빛을 받지 않는다. 밝고 가는 심, 부드러운 가장자리, 사라지는 양 끝.
## uniform: color(속성 색), fade(0..1, 0이면 보이지 않는다), core_white(심을 흰빛으로 섞는 정도, 색에서 정한다).
static func wave_material(c: Color) -> ShaderMaterial:
	return _material("wave", WAVE_SHADER % NOISE, c)


# ---------------------------------------------------------------- 땅의 고리와 띠

## XZ 평면의 고리. inner = 0이면 원판. UV.x: 둘레를 따라 0..1(UV.x × TAU가 규칙의 각도와 같다: 0 = +X, PI/2 = +Z),
## UV.y: 0 안쪽 → 1 바깥.
static func ring_mesh(inner: float, outer: float, segments: int = 48) -> ArrayMesh:
	var segs: int = maxi(3, segments)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	for i in segs + 1:
		var u: float = float(i) / segs
		var d := Vector3(cos(u * TAU), 0.0, sin(u * TAU))
		for j in 2:
			verts.append(d * (inner if j == 0 else outer))
			norms.append(Vector3.UP)
			uvs.append(Vector2(u, float(j)))
			uv2s.append(Vector2.ZERO)
	return _commit(verts, norms, uvs, uv2s, _grid_indices(segs, 1))


## XZ 평면의 띠. 원점에서 -Z 쪽으로 length만큼, 폭 width(가운데가 X = 0).
## UV.x: 길이를 따라 0(원점) → 1(끝), UV.y: 0(-X 쪽) → 1(+X 쪽). UV2.x = 1(땅 자국 재질이 양 끝을 뾰족하게 한다).
static func band_mesh(length: float, width: float) -> ArrayMesh:
	var segs: int = maxi(1, ceili(length / 0.5))
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	for i in segs + 1:
		var u: float = float(i) / segs
		for j in 2:
			verts.append(Vector3((float(j) - 0.5) * width, 0.0, -length * u))
			norms.append(Vector3.UP)
			uvs.append(Vector2(u, float(j)))
			uv2s.append(Vector2(1.0, 0.0))
	return _commit(verts, norms, uvs, uv2s, _grid_indices(segs, 1))


## 땅에 남는 자국(내려찍기 원, 지진 고리, 찌르기·발도의 띠). 그을린 어두운 바탕에 glow면 가는 빛줄.
## ring_mesh, band_mesh와 같이 쓴다. 섞어 그린다(blend_mix): 땅을 어둡게 할 수 있다.
## uniform: color(빛줄 색), progress(0..1, UV.x가 progress까지만 드러난다. 드러나는 머리가 가장 밝다),
## fade(0..1, 빛은 먼저 식고 그을음은 늦게 사라진다), glow(0 또는 1), glow_at(빛줄이 있는 UV.y, 기본 0.5 = 가운데.
## 내려찍기 원판처럼 테가 빛나야 하면 0.9쯤).
static func ground_mark_material(c: Color, glow: bool) -> ShaderMaterial:
	var m := _material("mark", MARK_SHADER % NOISE, c)
	m.set_shader_parameter("glow", 1.0 if glow else 0.0)
	return m


# ---------------------------------------------------------------- 갈라진 틈

## 가운데에서 뻗는 금(가지와, 이웃한 금을 잇는 짧은 둘레 금 포함). seed가 같으면 모양이 같다(꾸밈용, 규칙 rng와 따로).
## radius(미터)에 따라 금의 수와 굵기가 정해진다. UV.x: 가운데에서의 거리 / radius(0..1), UV.y: 금의 폭을 가로질러 0..1.
static func crack_mesh(seed: int, radius: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count: int = clampi(roundi(4.0 + radius * 1.3), 5, 12)
	var w0: float = clampf(radius * 0.05, 0.05, 0.18)
	var angles: Array[float] = []
	for i in count:
		var a: float = TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / count
		angles.append(a)
		var length: float = radius * rng.randf_range(0.55, 1.0)
		var pts: Array[Vector2] = _jag(rng, Vector2.ZERO, a, length, 7, 0.45)
		_ribbon(st, pts, radius, w0, false)
		if rng.randf() < 0.7:
			var k: int = rng.randi_range(2, pts.size() - 3)
			var side: float = 1.0 if rng.randf() < 0.5 else -1.0
			var bl: float = length * rng.randf_range(0.25, 0.45)
			_ribbon(st, _jag(rng, pts[k], a + side * rng.randf_range(0.45, 0.9), bl, 4, 0.4), radius, w0 * 0.55, false)
	for i in count:
		if rng.randf() < 0.4:
			var a0: float = angles[i]
			var a1: float = angles[(i + 1) % count]
			if a1 < a0:
				a1 += TAU
			var rr: float = radius * rng.randf_range(0.28, 0.5)
			var arc_pts: Array[Vector2] = []
			var n: int = 5
			for s in n + 1:
				var aa: float = lerpf(a0, a1, float(s) / n)
				var rj: float = rr
				if s > 0 and s < n:
					rj *= 1.0 + rng.randf_range(-0.1, 0.1)
				arc_pts.append(Vector2(cos(aa), sin(aa)) * rj)
			_ribbon(st, arc_pts, radius, w0 * 0.5, true)
	return st.commit()


## 갈라진 틈의 재질(섞어 그린다). uniform: color(틈의 빛 색), grow(0..1, 가운데에서 이 거리까지 자란다),
## energy(0 = 어두운 금, 1 이상 = 틈에서 빛, 클수록 밝다), fade(0..1).
static func crack_material(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("crack", CRACK_SHADER)
	m.set_shader_parameter("color", c)
	return m


# ---------------------------------------------------------------- 반격 번쩍임

## 네 갈래 쇠 별(위아래가 size, 옆은 size × 0.78) + 가운데 둥근 빛. XY 평면에 있고 재질이 카메라 쪽으로 돌린다.
## 갈래: UV.x 0(가운데) → 1(끝), UV.y 갈래를 가로질러. 가운데 빛은 UV2.x = 1이고 UV.x가 가운데에서의 거리다.
static func glint_mesh(size: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var idx := PackedInt32Array()
	var halo_r: float = size * 0.4
	var ring: int = 16
	verts.append(Vector3.ZERO)
	uvs.append(Vector2(0.0, 0.5))
	for k in ring:
		var a: float = TAU * k / ring
		verts.append(Vector3(cos(a), sin(a), 0.0) * halo_r)
		uvs.append(Vector2(1.0, 0.5))
	for k in ring:
		idx.append_array(PackedInt32Array([0, 1 + k, 1 + (k + 1) % ring]))
	for _i in ring + 1:
		uv2s.append(Vector2(1.0, 0.0))
	for k in 4:
		var a: float = PI * 0.5 * k
		var dir := Vector3(cos(a), sin(a), 0.0)
		var side := Vector3(-dir.y, dir.x, 0.0)
		var length: float = size * (1.0 if k % 2 == 1 else 0.78)
		var w: float = size * 0.09
		var b: int = verts.size()
		verts.append_array(PackedVector3Array([side * w, -side * w, dir * length]))
		uvs.append_array(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0, 1.0), Vector2(1.0, 0.5)]))
		uv2s.append_array(PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]))
		idx.append_array(PackedInt32Array([b, b + 1, b + 2]))
	for _i in verts.size():
		norms.append(Vector3.BACK)
	return _commit(verts, norms, uvs, uv2s, idx)


## 번쩍임의 재질(더해 그린다, 셰이더가 빌보드로 돌린다). uniform: color, fade(0..1), spin(라디안, 화면 안에서 돌린다).
static func glint_material(c: Color) -> ShaderMaterial:
	return _material("glint", GLINT_SHADER % NOISE, c)


# ---------------------------------------------------------------- 잔상

## 소용돌이·돌진·순간 이동의 잔상 줄기(더해 그린다). band_mesh나 ring_mesh와 같이 쓴다.
## UV.x 0이 꼬리(오래된 쪽), 1이 머리다(band_mesh는 원점이 꼬리, -Z 끝이 머리). uniform: color, fade(0..1).
static func streak_material(c: Color) -> ShaderMaterial:
	return _material("streak", STREAK_SHADER % NOISE, c)


# ---------------------------------------------------------------- 안쪽

static func _shader(key: String, code: String) -> Shader:
	if not _shaders.has(key):
		var sh := Shader.new()
		sh.code = code
		_shaders[key] = sh
	return _shaders[key]


## 빛나는 재질 공통: 색과, 심을 흰빛으로 섞는 정도(채도가 높은 불·피는 거의 섞지 않는다).
static func _material(key: String, code: String, c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader(key, code)
	m.set_shader_parameter("color", c)
	if key != "mark":
		m.set_shader_parameter("core_white", clampf(0.75 - c.s * 0.7, 0.05, 0.75))
	return m


static func _commit(verts: PackedVector3Array, norms: PackedVector3Array, uvs: PackedVector2Array, uv2s: PackedVector2Array, idx: PackedInt32Array) -> ArrayMesh:
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	if not uv2s.is_empty():
		arr[Mesh.ARRAY_TEX_UV2] = uv2s
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## (cols + 1) × (rows + 1) 격자(열마다 rows + 1개씩)의 삼각형.
static func _grid_indices(cols: int, rows: int) -> PackedInt32Array:
	var idx := PackedInt32Array()
	for i in cols:
		for j in rows:
			var a: int = i * (rows + 1) + j
			var c: int = a + rows + 1
			idx.append_array(PackedInt32Array([a, c, a + 1, a + 1, c, c + 1]))
	return idx


## 꺾이며 뻗는 금 한 줄.
static func _jag(rng: RandomNumberGenerator, from: Vector2, a: float, length: float, segs: int, wobble: float) -> Array[Vector2]:
	var pts: Array[Vector2] = [from]
	var p: Vector2 = from
	for _s in segs:
		a += rng.randf_range(-wobble, wobble)
		p += Vector2(cos(a), sin(a)) * (length / segs)
		pts.append(p)
	return pts


## 금 한 줄을 띠로. even이면 가운데가 굵고 양 끝이 가늘다(둘레 금), 아니면 시작이 굵고 끝으로 가늘어진다.
static func _ribbon(st: SurfaceTool, pts: Array[Vector2], radius: float, w0: float, even: bool) -> void:
	var n: int = pts.size()
	for i in n - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var dir: Vector2 = (b - a).normalized()
		var side := Vector2(-dir.y, dir.x)
		var t0: float = float(i) / (n - 1)
		var t1: float = float(i + 1) / (n - 1)
		var wa: float = w0 * ((0.4 + 0.6 * sin(PI * t0)) if even else (1.0 - t0 * 0.85))
		var wb: float = w0 * ((0.4 + 0.6 * sin(PI * t1)) if even else (1.0 - t1 * 0.85))
		var ua: float = clampf(a.length() / radius, 0.0, 1.0)
		var ub: float = clampf(b.length() / radius, 0.0, 1.0)
		var q: Array[Vector3] = [
			Vector3(a.x - side.x * wa, 0.0, a.y - side.y * wa),
			Vector3(a.x + side.x * wa, 0.0, a.y + side.y * wa),
			Vector3(b.x - side.x * wb, 0.0, b.y - side.y * wb),
			Vector3(b.x + side.x * wb, 0.0, b.y + side.y * wb),
		]
		var quv: Array[Vector2] = [Vector2(ua, 0.0), Vector2(ua, 1.0), Vector2(ub, 0.0), Vector2(ub, 1.0)]
		for k: int in [0, 2, 1, 1, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(quv[k])
			st.add_vertex(q[k])
