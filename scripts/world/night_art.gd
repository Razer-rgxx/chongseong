class_name NightArt
extends RefCounted
## 12단계 밤의 모양(모양팀, docs/content.md "12단계"). 노드에 기대지 않는 정적 함수만 둔다.
##   봉화       돌 받침 위에 쇠 불바구니, 안에 장작과 숯, 불꽃, 불빛, 오르는 불씨와 옅은 연기. set_fire·set_coals로 줄이거나 끈다.
##   우두머리 고리  발밑의 검붉은 고리 재질(boss_ring_material)과 그것을 입힌 판(boss_ring)
##   무덤       망령이 터져 나오는 흙더미(grave_mound): 가운데가 터져 꺼진 둔덕, 둘레의 흙덩이, 기운 썩은 말뚝
## 어두운 사실풍: 돌, 녹슨 쇠, 흙, 숯, 불. 글자와 문양은 없다. 꾸밈용 랜덤은 seed가 정해진 것만 쓴다(늘 같은 모양).
##
## 좌표: 미터. 원점 = 발밑(땅 높이). 기능팀은 parent를 HillBuilder.height로 땅에 맞춘 자리에 두고 부른다.
##   var b := NightArt.beacon(node)      # node.position = Grid.cells_to_world(at) + 땅 높이
##   NightArt.set_fire(b, 0.6)           # 불꽃 크기와 불빛(0 = 꺼짐, 1 = 다 탄다)
##   NightArt.set_coals(b, 0.3)          # 숯의 붉은 빛(0 = 식었다)
##   NightFx.watch_beacon(b)를 부르면 불빛이 일렁이고 맞을 때·꺼질 때의 효과가 이 봉화에서 난다.

const IRON := Color(0.085, 0.075, 0.068)
const RUST := Color(0.2, 0.1, 0.055)
const FIRE_LIGHT := Color(1.0, 0.56, 0.26)
const RING_RED := Color(0.36, 0.035, 0.022)
const RING_HOT := Color(0.62, 0.08, 0.035)

## 봉화의 잣수(m): 받침 높이, 불바구니 아래·위, 불꽃이 서는 자리.
const PLINTH_TOP: float = 1.08
const BASKET_LOW: float = 1.32
const BASKET_TOP: float = 1.86
const FIRE_AT := Vector3(0.0, 1.62, 0.0)

## 불꽃 판(세로축만 카메라를 보는 판). power 0..1 = 크기와 세기, 위로 흐르는 잡음으로 일렁인다. 더해 그린다.
const FLAME_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float power = 1.0;
uniform float seed = 0.0;
uniform float energy = 1.5;
uniform float speed = 1.0;
uniform vec4 core : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform vec4 mid : source_color = vec4(1.0, 0.42, 0.1, 1.0);
uniform vec4 edge : source_color = vec4(0.5, 0.08, 0.02, 1.0);
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 4; i++) { s += vn(p) * a; p = p * 2.03 + 17.1; a *= 0.5; }
	return s;
}
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	float v = 1.0 - UV.y;
	float t = TIME * speed;
	float x = UV.x - 0.5;
	x += (fbm(vec2(UV.x * 2.0 + seed, v * 1.6 - t * 1.3)) - 0.5) * 0.34 * v;
	float n = fbm(vec2(x * 5.0 + seed * 3.1, v * 3.2 - t * 2.4));
	float n2 = vn(vec2(x * 11.0 - seed, v * 7.0 - t * 4.0));
	float w = 0.46 * pow(clamp(1.0 - v, 0.0, 1.0), 0.55);
	float shape = 1.0 - smoothstep(w * 0.25, w, abs(x));
	float p = max(power, 0.001);
	float f = shape * (0.55 + n * 0.85 + n2 * 0.2) - v * (1.05 / p) * (0.55 + 0.45 * n);
	f *= smoothstep(0.0, 0.06, v);
	f = clamp(f, 0.0, 1.0);
	vec3 c = mix(edge.rgb, mid.rgb, smoothstep(0.03, 0.32, f));
	c = mix(c, core.rgb, smoothstep(0.42, 0.85, f));
	ALBEDO = c * energy;
	ALPHA = clamp(smoothstep(0.015, 0.22, f) * clamp(power * 2.5, 0.0, 1.0), 0.0, 1.0);
}
"""

## 우두머리 발밑 고리. 판(1 × 1, 원점 = 가운데)을 지름만큼 늘린다. 찢긴 검붉은 테와 그 안의 그을린 그늘, 천천히 숨 쉬는 빛.
## fade(0..1) = 나타남, energy = 빛 세기(밤에 보이는 만큼만), spin = 무늬가 도는 빠르기.
const RING_SHADER := """shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_disabled, shadows_disabled;
uniform vec4 color : source_color = vec4(0.36, 0.035, 0.022, 1.0);
uniform vec4 hot : source_color = vec4(0.62, 0.08, 0.035, 1.0);
uniform float fade = 1.0;
uniform float energy = 1.3;
uniform float spin = 0.12;
uniform float seed = 0.0;
varying vec2 lp;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() { lp = VERTEX.xz * 2.0; }
void fragment() {
	float r = length(lp);
	if (r > 1.0) { discard; }
	float a = atan(lp.y, lp.x) + TIME * spin;
	vec2 polar = vec2(cos(a), sin(a)) * 3.0;
	float n = vn(polar + seed + r * 4.0);
	float n2 = vn(vec2(a * 9.0, r * 22.0) + seed * 1.3);
	float rr = r + (n - 0.5) * 0.05;
	float ring = smoothstep(0.76, 0.84, rr) * (1.0 - smoothstep(0.9, 0.97, rr));
	float broken = smoothstep(0.22, 0.42, n2 * 0.6 + n * 0.6);
	float inner = (1.0 - smoothstep(0.55, 0.84, r)) * 0.32 * (0.6 + 0.4 * n);
	float glow = ring * broken;
	float breathe = 0.78 + 0.22 * sin(TIME * 1.7 + seed);
	ALBEDO = mix(vec3(0.03, 0.022, 0.018), mix(color.rgb, hot.rgb, n2), glow);
	EMISSION = mix(color.rgb, hot.rgb, n2 * glow) * glow * energy * breathe;
	ROUGHNESS = 1.0;
	ALPHA = clamp((glow * 0.92 + inner) * fade, 0.0, 1.0);
}
"""

static var _cache: Dictionary = {}


# ---------------------------------------------------------------- 봉화

## 봉화를 parent 아래에 짓는다. 돌려주는 키:
##   root(Node3D), plinth(돌 받침 MeshInstance3D), basket(쇠 바구니 MeshInstance3D), flames(Array[MeshInstance3D]),
##   flame_mats(Array[ShaderMaterial], power = 불 크기), coal_mat(StandardMaterial3D, 숯), light(OmniLight3D, meta "base_energy"),
##   embers(CPUParticles3D, 오르는 불씨), smoke(CPUParticles3D, 옅은 연기),
##   fire_at(Vector3, 불꽃 가운데. root 기준), rim(float, 바구니 테 높이 m), radius(m, 받침 반지름), height(m),
##   fire(float, 지금 불 0..1), coals(float, 지금 숯 빛 0..1)
static func beacon(parent: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "Beacon"
	parent.add_child(root)
	var P: Dictionary = {"root": root, "fire_at": FIRE_AT, "rim": BASKET_TOP, "radius": 0.66, "height": 2.0, "fire": 1.0, "coals": 1.0}
	# 받침: 세 덩이를 쌓은 거친 돌(면이 각진 것은 정으로 다듬은 돌). 둘레에 이끼 낀 바위
	var stone := VillageMaterials.get_mat("lichen_rock", Color(0.3, 0.29, 0.27), 1.4, Color(0.6, 0.58, 0.55))
	var pl := MeshInstance3D.new()
	pl.name = "Plinth"
	pl.mesh = plinth_mesh()
	pl.material_override = stone
	root.add_child(pl)
	P.plinth = pl
	var rocks: Array[Dictionary] = HillBuilder.rock_parts()
	if not rocks.is_empty():
		for i in 4:
			var a: float = TAU * float(i) / 4.0 + 0.5 + float(i % 2) * 0.3
			var part: Dictionary = rocks[(i * 3 + 1) % rocks.size()]
			var s: float = 0.32 / maxf(0.2, (part.size as Vector3).x) * (0.8 + 0.25 * float((i * 7) % 3))
			HillBuilder.put_flat(root, part, Vector3(cos(a), 0.0, sin(a)) * 0.7, a * 2.3, s, 0.35)
	# 쇠 바구니와 다리
	var iron := iron_material()
	var bk := MeshInstance3D.new()
	bk.name = "Basket"
	bk.mesh = basket_mesh()
	bk.material_override = iron
	root.add_child(bk)
	P.basket = bk
	# 장작(그을린 통나무)과 숯 바닥
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = _noise_tex("charwood", 0.2, Color(0.16, 0.12, 0.09), Color(0.02, 0.018, 0.016))
	wood.uv1_scale = Vector3(1.0, 4.0, 1.0)
	wood.roughness = 0.95
	for i in 4:
		var log_mesh := CylinderMesh.new()
		log_mesh.top_radius = 0.045 + 0.008 * float(i % 2)
		log_mesh.bottom_radius = log_mesh.top_radius * 1.1
		log_mesh.height = 0.62 - 0.05 * float(i)
		log_mesh.radial_segments = 7
		log_mesh.rings = 1
		var lg := MeshInstance3D.new()
		lg.mesh = log_mesh
		lg.material_override = wood
		var yaw: float = float(i) * 1.15
		lg.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, 0.95 + 0.12 * float(i % 3))
		lg.position = Vector3(cos(yaw) * 0.04, BASKET_LOW + 0.2 + 0.03 * float(i), sin(yaw) * 0.04)
		root.add_child(lg)
	var coal := StandardMaterial3D.new()
	coal.albedo_texture = _noise_tex("coal_alb", 0.3, Color(0.07, 0.06, 0.055), Color(0.015, 0.013, 0.012))
	coal.roughness = 0.9
	coal.emission_enabled = true
	coal.emission_texture = _coal_glow()
	coal.emission = Color(1.0, 0.36, 0.1)
	coal.emission_energy_multiplier = 2.2
	coal.set_meta("base_energy", 2.2)
	var bed := SphereMesh.new()
	bed.radius = 0.25
	bed.height = 0.18
	bed.radial_segments = 14
	bed.rings = 5
	var bm := MeshInstance3D.new()
	bm.name = "Coals"
	bm.mesh = bed
	bm.material_override = coal
	bm.position = Vector3(0.0, BASKET_LOW + 0.12, 0.0)
	root.add_child(bm)
	P.coal_mat = coal
	# 불꽃: 크기가 다른 판 셋(세로축 빌보드), 저마다 다른 잡음
	var flames: Array[MeshInstance3D] = []
	var fmats: Array[ShaderMaterial] = []
	var sizes: Array[Vector2] = [Vector2(0.95, 1.25), Vector2(0.7, 0.95), Vector2(0.55, 0.7)]
	var offs: Array[Vector3] = [Vector3(0.0, 0.0, 0.0), Vector3(0.1, 0.0, 0.06), Vector3(-0.11, 0.0, -0.05)]
	for i in sizes.size():
		var q := QuadMesh.new()
		q.size = sizes[i]
		q.center_offset = Vector3(0.0, sizes[i].y * 0.5, 0.0)
		var m := ShaderMaterial.new()
		m.shader = _shader("flame", FLAME_SHADER)
		m.set_shader_parameter("seed", 3.7 * float(i) + 1.3)
		m.set_shader_parameter("speed", 1.0 + 0.15 * float(i))
		m.set_shader_parameter("energy", 1.5 - 0.15 * float(i))
		var f := MeshInstance3D.new()
		f.name = "Flame%d" % i
		f.mesh = q
		f.material_override = m
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.position = Vector3(0.0, BASKET_LOW + 0.16, 0.0) + offs[i]
		f.sorting_offset = 0.1 * float(i)
		root.add_child(f)
		flames.append(f)
		fmats.append(m)
	P.flames = flames
	P.flame_mats = fmats
	# 불빛: 바구니 위. 그림자를 드리운다(밤의 유일한 큰 불이라)
	var light := OmniLight3D.new()
	light.name = "FireLight"
	light.light_color = FIRE_LIGHT
	light.light_energy = 2.4
	light.omni_range = 11.0
	light.omni_attenuation = 1.2
	light.shadow_enabled = true
	light.position = FIRE_AT + Vector3(0.0, 0.45, 0.0)
	light.set_meta("base_energy", 2.4)
	root.add_child(light)
	P.light = light
	# 오르는 불씨와 옅은 연기(불이 타는 동안 늘)
	var embers := CPUParticles3D.new()
	embers.name = "Embers"
	embers.amount = 14
	embers.lifetime = 1.8
	embers.randomness = 0.6
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 0.22
	embers.direction = Vector3.UP
	embers.spread = 22.0
	embers.initial_velocity_min = 0.6
	embers.initial_velocity_max = 1.6
	embers.gravity = Vector3(0.0, 0.6, 0.0)
	embers.damping_min = 0.2
	embers.damping_max = 0.6
	embers.tangential_accel_min = -0.6
	embers.tangential_accel_max = 0.6
	embers.scale_amount_min = 0.5
	embers.scale_amount_max = 1.0
	embers.color_ramp = _gradient([Color(1.6, 0.8, 0.35, 1.0), Color(1.2, 0.4, 0.1, 0.9), Color(0.5, 0.1, 0.03, 0.0)], [0.0, 0.5, 1.0])
	embers.mesh = _dot_quad(0.035)
	embers.position = FIRE_AT + Vector3(0.0, 0.15, 0.0)
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(embers)
	P.embers = embers
	var smoke := CPUParticles3D.new()
	smoke.name = "Smoke"
	smoke.amount = 10
	smoke.lifetime = 3.2
	smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.15
	smoke.direction = Vector3.UP
	smoke.spread = 10.0
	smoke.initial_velocity_min = 0.7
	smoke.initial_velocity_max = 1.1
	smoke.gravity = Vector3(0.25, 0.25, 0.1)
	smoke.angle_min = -180.0
	smoke.angle_max = 180.0
	smoke.angular_velocity_min = -20.0
	smoke.angular_velocity_max = 20.0
	smoke.scale_amount_curve = _curve(0.35, 1.8)
	smoke.color_ramp = _gradient([Color(0.16, 0.15, 0.14, 0.0), Color(0.16, 0.15, 0.14, 0.32), Color(0.14, 0.135, 0.13, 0.0)], [0.0, 0.2, 1.0])
	smoke.mesh = _lit_quad(1.0)
	smoke.position = FIRE_AT + Vector3(0.0, 0.7, 0.0)
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(smoke)
	P.smoke = smoke
	set_fire(P, 1.0)
	return P


## 불꽃 크기와 불빛(0 = 꺼짐, 1 = 다 탄다). 0이면 불씨와 연기도 멈춘다. 숯 빛은 set_coals로 따로.
static func set_fire(parts: Dictionary, k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	parts["fire"] = k
	for m: ShaderMaterial in parts.get("flame_mats", []):
		m.set_shader_parameter("power", k)
	for f: MeshInstance3D in parts.get("flames", []):
		f.visible = k > 0.01
		f.scale = Vector3.ONE * (0.55 + 0.45 * k)
	var l: OmniLight3D = parts.get("light")
	if l:
		l.light_energy = float(l.get_meta("base_energy", 2.4)) * (0.12 * float(parts.get("coals", 1.0)) + 0.88 * k)
		l.visible = l.light_energy > 0.01
	var e: CPUParticles3D = parts.get("embers")
	if e:
		e.emitting = k > 0.05
		e.speed_scale = 0.6 + 0.4 * k
	var s: CPUParticles3D = parts.get("smoke")
	if s:
		s.emitting = k > 0.05


## 숯의 붉은 빛(0 = 식어 검다, 1 = 타는 숯).
static func set_coals(parts: Dictionary, k: float) -> void:
	k = clampf(k, 0.0, 1.0)
	parts["coals"] = k
	var m: StandardMaterial3D = parts.get("coal_mat")
	if m:
		m.emission_energy_multiplier = float(m.get_meta("base_energy", 2.2)) * k * k
	set_fire(parts, float(parts.get("fire", 1.0)))


## 세 덩이 돌 받침(아래 넓은 덩이, 가운데 좁은 기둥, 위 넓은 판). 면을 각지게 그린다.
static func plinth_mesh() -> ArrayMesh:
	if _cache.has("plinth"):
		return _cache["plinth"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_drum(st, 0.0, 0.42, 0.64, 0.58, 8, 11, 0.0)
	_drum(st, 0.4, 0.95, 0.44, 0.4, 7, 23, 0.3)
	_drum(st, 0.93, PLINTH_TOP, 0.56, 0.54, 9, 37, 0.15)
	st.generate_normals()
	st.generate_tangents()
	var mesh := st.commit()
	_cache["plinth"] = mesh
	return mesh


## 쇠 불바구니: 아래 고리, 가운데 고리, 위 테, 밖으로 휜 살 10개(끝이 바깥으로 갈고리처럼), 받침에 박힌 다리 셋.
static func basket_mesh() -> ArrayMesh:
	if _cache.has("basket"):
		return _cache["basket"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r0: float = 0.2
	var r1: float = 0.33
	var r2: float = 0.43
	var ymid: float = lerpf(BASKET_LOW, BASKET_TOP, 0.48)
	_hoop(st, BASKET_LOW, r0, 0.016, 18)
	_hoop(st, ymid, r1, 0.013, 22)
	_hoop(st, BASKET_TOP, r2, 0.018, 26)
	var bars: int = 10
	for i in bars:
		var a: float = TAU * float(i) / bars
		var d := Vector3(cos(a), 0.0, sin(a))
		var pts: Array[Vector3] = [
			d * (r0 * 0.6) + Vector3(0.0, BASKET_LOW - 0.03, 0.0),
			d * r0 + Vector3(0.0, BASKET_LOW, 0.0),
			d * r1 + Vector3(0.0, ymid, 0.0),
			d * r2 + Vector3(0.0, BASKET_TOP, 0.0),
			d * (r2 + 0.05) + Vector3(0.0, BASKET_TOP + 0.09, 0.0),
			d * (r2 + 0.1) + Vector3(0.0, BASKET_TOP + 0.12, 0.0),
		]
		_path(st, pts, 0.012, 5)
	# 바닥 살(+ 모양)과 받침에 박힌 다리 셋
	_path(st, [Vector3(-r0, BASKET_LOW - 0.03, 0.0), Vector3(r0, BASKET_LOW - 0.03, 0.0)], 0.012, 5)
	_path(st, [Vector3(0.0, BASKET_LOW - 0.03, -r0), Vector3(0.0, BASKET_LOW - 0.03, r0)], 0.012, 5)
	for i in 3:
		var a: float = TAU * float(i) / 3.0 + 0.3
		var d := Vector3(cos(a), 0.0, sin(a))
		_path(st, [d * 0.3 + Vector3(0.0, PLINTH_TOP - 0.03, 0.0), d * 0.28 + Vector3(0.0, PLINTH_TOP + 0.06, 0.0), d * r0 + Vector3(0.0, BASKET_LOW, 0.0)], 0.02, 6)
	_path(st, [Vector3(0.0, PLINTH_TOP - 0.02, 0.0), Vector3(0.0, BASKET_LOW - 0.02, 0.0)], 0.035, 8)
	st.generate_normals()
	st.generate_tangents()
	var mesh := st.commit()
	_cache["basket"] = mesh
	return mesh


## 녹슨 쇠(검은 쇠에 붉은 녹이 얼룩진다).
static func iron_material() -> StandardMaterial3D:
	if _cache.has("iron"):
		return _cache["iron"]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _noise_tex("rust", 0.18, RUST, IRON)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 3.0
	m.metallic = 0.55
	m.roughness = 0.62
	m.rim_enabled = true
	m.rim = 0.2
	_cache["iron"] = m
	return m


# ---------------------------------------------------------------- 우두머리 고리

## 발밑 고리 재질(판마다 하나씩: fade·energy를 따로 바꾼다). seed로 무늬를 다르게.
static func boss_ring_material(seed: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader("boss_ring", RING_SHADER)
	m.set_shader_parameter("color", RING_RED)
	m.set_shader_parameter("hot", RING_HOT)
	m.set_shader_parameter("seed", seed)
	return m


## 고리 판 하나(눕힌 판, 지름 radius_m × 2). 노드를 땅 위 3cm쯤에 둔다. NightFx.ring_follow가 이것을 쓴다.
static func boss_ring(parent: Node3D, radius_m: float, seed: float = 0.0) -> MeshInstance3D:
	var q := PlaneMesh.new()
	q.size = Vector2.ONE
	var mi := MeshInstance3D.new()
	mi.name = "BossRing"
	mi.mesh = q
	mi.material_override = boss_ring_material(seed)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(radius_m * 2.0, 1.0, radius_m * 2.0)
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- 무덤

## 망령이 터져 나온 흙더미. 돌려주는 키: root, mound(MeshInstance3D, 가운데가 터져 꺼진 둔덕), clods(Array[MeshInstance3D], 둘레 흙덩이),
## stake(기운 썩은 말뚝), mat(흙 재질, 이 무덤만의 것: albedo 알파로 사라지게 할 수 있다), height(m).
## 둔덕은 길쭉하다(길이 1.7m, 폭 0.95m, 테 높이 0.3m). -Z가 머리 쪽(말뚝).
static func grave_mound(parent: Node3D, seed: int = 0) -> Dictionary:
	var root := Node3D.new()
	root.name = "Grave"
	parent.add_child(root)
	var mat := StandardMaterial3D.new()
	var base: String = "res://assets/hill/forest_ground_04/forest_ground_04"
	if ResourceLoader.exists(base + "_diff.jpg"):
		mat.albedo_texture = load(base + "_diff.jpg")
		mat.normal_enabled = true
		mat.normal_texture = load(base + "_nor_gl.jpg")
		mat.albedo_color = Color(0.3, 0.26, 0.23)
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE / 1.2
	else:
		mat.albedo_color = Color(0.09, 0.075, 0.06)
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	var mound := MeshInstance3D.new()
	mound.name = "Mound"
	mound.mesh = mound_mesh(seed)
	mound.material_override = mat
	root.add_child(mound)
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + seed
	var clods: Array[MeshInstance3D] = []
	for i in 7:
		var s := SphereMesh.new()
		s.radius = rng.randf_range(0.06, 0.13)
		s.height = s.radius * rng.randf_range(1.1, 1.5)
		s.radial_segments = 6
		s.rings = 3
		var c := MeshInstance3D.new()
		c.mesh = s
		c.material_override = mat
		var a: float = rng.randf() * TAU
		c.position = Vector3(cos(a) * rng.randf_range(0.6, 1.1), s.height * 0.25, sin(a) * rng.randf_range(0.75, 1.3))
		c.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, 0.0)
		root.add_child(c)
		clods.append(c)
	# 기운 썩은 말뚝(머리 쪽)
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = _noise_tex("rotwood", 0.15, Color(0.2, 0.17, 0.13), Color(0.05, 0.045, 0.04))
	wood.uv1_scale = Vector3(1.0, 5.0, 1.0)
	wood.roughness = 1.0
	var post := CylinderMesh.new()
	post.top_radius = 0.035
	post.bottom_radius = 0.05
	post.height = 0.9
	post.radial_segments = 6
	post.rings = 1
	var stake := MeshInstance3D.new()
	stake.name = "Stake"
	stake.mesh = post
	stake.material_override = wood
	stake.position = Vector3(0.08, 0.3, -0.98)
	stake.rotation = Vector3(-0.32, 0.4, 0.22)
	root.add_child(stake)
	return {"root": root, "mound": mound, "clods": clods, "stake": stake, "mat": mat, "height": 0.3}


## 길쭉한 둔덕(가운데가 터져 꺼지고 테가 솟았다). 정점 색으로 꺼진 안쪽을 어둡게 한다.
static func mound_mesh(seed: int = 0) -> ArrayMesh:
	var key: String = "mound%d" % seed
	if _cache.has(key):
		return _cache[key]
	var nz := FastNoiseLite.new()
	nz.seed = 40 + seed
	nz.frequency = 1.6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: int = 12
	var sides: int = 28
	var rx: float = 0.95
	var rz: float = 1.25
	var verts: Array[Vector3] = []
	var cols: Array[Color] = []
	for i in rings + 1:
		var t: float = float(i) / rings
		for k in sides:
			var a: float = TAU * float(k) / sides
			var d := Vector2(cos(a) * rx, sin(a) * rz) * t
			var n: float = nz.get_noise_2d(d.x * 1.0, d.y * 1.0)
			# 테: t ≈ 0.55에서 솟고, 가운데는 땅 밑으로 꺼진다(터진 구멍), 끝(t = 1)은 땅에 묻힌다
			var rim: float = exp(-pow((t - 0.55) / 0.22, 2.0)) * 0.3
			var pit: float = -0.16 * (1.0 - smoothstep(0.0, 0.42, t))
			var h: float = rim + pit + n * 0.06 * (1.0 - t) - smoothstep(0.85, 1.0, t) * 0.06
			verts.append(Vector3(d.x * (1.0 + n * 0.12), h, d.y * (1.0 + n * 0.12)))
			var dark: float = 1.0 - smoothstep(0.0, 0.45, t)
			cols.append(Color(1.0, 1.0, 1.0).lerp(Color(0.25, 0.22, 0.2), dark))
	for i in rings:
		for k in sides:
			var a: int = i * sides + k
			var b: int = i * sides + (k + 1) % sides
			var c: int = (i + 1) * sides + k
			var d: int = (i + 1) * sides + (k + 1) % sides
			for v: int in [a, c, b, b, c, d]:
				st.set_color(cols[v])
				st.set_uv(Vector2(verts[v].x, verts[v].z))
				st.add_vertex(verts[v])
	st.generate_normals()
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


# ---------------------------------------------------------------- 알갱이 재료(NightFx·EventFx도 쓴다)

## 가장자리가 들쭉날쭉한 연기·먼지 조각(가운데가 진하고 잡음으로 찢긴다).
static func puff() -> ImageTexture:
	if _cache.has("puff"):
		return _cache["puff"]
	var s: int = 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var nz := FastNoiseLite.new()
	nz.seed = 5
	nz.frequency = 0.08
	nz.fractal_octaves = 3
	for y in s:
		for x in s:
			var d: float = Vector2(x + 0.5 - s * 0.5, y + 0.5 - s * 0.5).length() / (s * 0.5)
			var n: float = nz.get_noise_2d(x, y) * 0.5 + 0.5
			var a: float = (1.0 - smoothstep(0.15, 1.0, d + (n - 0.5) * 0.8)) * (0.35 + 0.9 * n)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(a, 0.0, 1.0)))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache["puff"] = t
	return t


## 둥근 빛 점(불씨).
static func dot() -> GradientTexture2D:
	if _cache.has("dot"):
		return _cache["dot"]
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	_cache["dot"] = t
	return t


## 땅처럼 빛을 받는 알갱이 판 셰이더(연기, 먼지, 재). 판은 카메라를 보지만 법선은 위를 본다.
const LIT_SHADER := """shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_disabled;
uniform sampler2D tex : source_color, filter_linear_mipmap, hint_default_white;
void vertex() {
	mat4 mw = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	mw = mw * mat4(vec4(cos(INSTANCE_CUSTOM.x), -sin(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(sin(INSTANCE_CUSTOM.x), cos(INSTANCE_CUSTOM.x), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * mw;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}
void fragment() {
	vec4 t = texture(tex, UV);
	ALBEDO = COLOR.rgb * t.rgb;
	ALPHA = clamp(COLOR.a * t.a, 0.0, 1.0);
	ROUGHNESS = 1.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
}
"""


## 빛을 받는 연기 판(크기별로 한 번만).
static func _lit_quad(size: float) -> QuadMesh:
	var key: String = "litq%.2f" % size
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = _shader("lit", LIT_SHADER)
	m.set_shader_parameter("tex", puff())
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = m
	_cache[key] = q
	return q


## 더해 그리는 빛 점 판(불씨).
static func _dot_quad(size: float) -> QuadMesh:
	var key: String = "dotq%.3f" % size
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = dot()
	m.disable_receive_shadows = true
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = m
	_cache[key] = q
	return q


# ---------------------------------------------------------------- 도움

## 각진 돌 덩이 하나(아래 반지름 ra, 위 rb, 면 sides개, 꼭짓점마다 반지름을 조금 흔든다). 평평한 윗면.
static func _drum(st: SurfaceTool, y0: float, y1: float, ra: float, rb: float, sides: int, seed: int, turn: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var lo: Array[Vector3] = []
	var hi: Array[Vector3] = []
	for k in sides:
		var a: float = TAU * (float(k) + rng.randf_range(-0.18, 0.18)) / sides + turn
		var j: float = rng.randf_range(0.92, 1.06)
		lo.append(Vector3(cos(a) * ra * j, y0, sin(a) * ra * j))
		hi.append(Vector3(cos(a) * rb * j * rng.randf_range(0.95, 1.03), y1 + rng.randf_range(-0.015, 0.015), sin(a) * rb * j))
	st.set_smooth_group(-1)
	for k in sides:
		var n: int = (k + 1) % sides
		# 바깥 면(위·아래 두 줄로 나눠 가운데를 조금 부풀린다)
		var m0: Vector3 = lo[k].lerp(hi[k], 0.5) * Vector3(1.04, 1.0, 1.04)
		var m1: Vector3 = lo[n].lerp(hi[n], 0.5) * Vector3(1.04, 1.0, 1.04)
		for tri: Array in [[lo[k], m0, lo[n]], [lo[n], m0, m1], [m0, hi[k], m1], [m1, hi[k], hi[n]]]:
			for v: Vector3 in tri:
				st.set_uv(Vector2(v.x + v.z, v.y))
				st.add_vertex(v)
		# 윗면
		var c := Vector3(0.0, y1 + 0.01, 0.0)
		for v: Vector3 in [c, hi[n], hi[k]]:
			st.set_uv(Vector2(v.x, v.z))
			st.add_vertex(v)


## 고리(눕힌 원). 쇠 띠.
static func _hoop(st: SurfaceTool, y: float, r: float, t: float, seg: int) -> void:
	var pts: Array[Vector3] = []
	for i in seg + 1:
		var a: float = TAU * float(i) / seg
		pts.append(Vector3(cos(a) * r, y, sin(a) * r))
	_path(st, pts, t, 5)


## 점들을 잇는 둥근 관(마디마다 단면을 다시 세운다).
static func _path(st: SurfaceTool, pts: Array[Vector3], r: float, sides: int) -> void:
	st.set_smooth_group(0)
	var n: int = pts.size()
	var rings: Array = []
	for i in n:
		var t: Vector3 = pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]
		t = t.normalized() if t.length() > 1e-5 else Vector3.UP
		var ref: Vector3 = Vector3.UP if absf(t.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
		var s: Vector3 = ref.cross(t).normalized()
		var u: Vector3 = t.cross(s).normalized()
		var ring: Array[Vector3] = []
		for k in sides:
			var a: float = TAU * float(k) / sides
			ring.append(pts[i] + (s * cos(a) + u * sin(a)) * r)
		rings.append(ring)
	for i in n - 1:
		var A: Array[Vector3] = rings[i]
		var B: Array[Vector3] = rings[i + 1]
		for k in sides:
			var k2: int = (k + 1) % sides
			for v: Vector3 in [A[k], B[k], A[k2], A[k2], B[k], B[k2]]:
				st.set_uv(Vector2(float(k) / sides, float(i)))
				st.add_vertex(v)


static func _noise_tex(key: String, freq: float, light: Color, dark: Color) -> NoiseTexture2D:
	if _cache.has(key):
		return _cache[key]
	var nz := FastNoiseLite.new()
	nz.frequency = freq
	nz.fractal_octaves = 4
	var g := Gradient.new()
	g.colors = PackedColorArray([dark, light])
	var t := NoiseTexture2D.new()
	t.noise = nz
	t.color_ramp = g
	t.seamless = true
	t.width = 128
	t.height = 128
	_cache[key] = t
	return t


## 숯의 빛 무늬: 대부분 검고 갈라진 틈만 붉다.
static func _coal_glow() -> NoiseTexture2D:
	if _cache.has("coal_glow"):
		return _cache["coal_glow"]
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_CELLULAR
	nz.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	nz.frequency = 0.06
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.3, 1.0])
	g.colors = PackedColorArray([Color(1.0, 0.75, 0.4), Color(0.8, 0.25, 0.06), Color(0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0)])
	var t := NoiseTexture2D.new()
	t.noise = nz
	t.color_ramp = g
	t.seamless = true
	t.width = 128
	t.height = 128
	_cache["coal_glow"] = t
	return t


static func _gradient(cols: Array, offs: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	return g


static func _curve(a: float, b: float) -> Curve:
	var c := Curve.new()
	c.max_value = maxf(a, b)
	c.add_point(Vector2(0.0, a))
	c.add_point(Vector2(1.0, b))
	return c


static func _shader(key: String, code: String) -> Shader:
	var k: String = "sh_" + key
	if _cache.has(k):
		return _cache[k]
	var s := Shader.new()
	s.code = code
	_cache[k] = s
	return s
