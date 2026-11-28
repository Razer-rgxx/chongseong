class_name OmenArt
extends RefCounted
## 손잡이 조짐 0~3의 모습(14단계, 모양팀). docs/content.md 14단계 "손잡이 조짐".
## 등급 색(GradeTable.colors)은 쓰지 않는다. 모두 쇠·녹·흙·불씨(주황빛)·먼지로만 "느낌"을 준다.
##   0  녹슬고 무디다: 칼날·코등이가 붉은 갈색 녹으로 덮이고 거칠다. 조금 더 기운다
##   1  깨끗한 쇠빛: 녹이 없는 어두운 쇠. 해를 받으면 한 줄 번들거린다(놋쇠·흰 강철이 아니다. 귀함 등급과 다르다)
##   2  1의 쇠빛 + 밑동 둘레 땅에 희미한 불씨 금(천천히 숨 쉬듯 밝아졌다 어두워진다)
##   3  2보다 조금 센 금 + 낮은 울림(제자리에서 아주 작게 떨고, 낮은 웅 소리) + 떠오르는 먼지와 밑동의 희미한 빛
##
## HiltView는 이렇게 쓴다(정적 함수뿐, 상태는 hilt_root 아래 자식 노드 "Omen"과 메타에 둔다):
##   1) _ready()에서 _build()와 둔덕을 지은 뒤 한 번: OmenArt.apply(self, 보이는 조짐)
##      "보이는 조짐"은 규칙이 정한 겉 조짐(75% 맞음)이다. 점쟁이를 만나 참된 조짐이 드러나면 그 값으로 다시 apply한다.
##      apply는 먼저 clear하므로 몇 번 불러도 된다.
##   2) 뽑혀서 손잡이가 사라질 때(hilt.gone): OmenArt.clear(self). 부르지 않아도 칼(SwordModel)이 화면에서 숨으면
##      "Omen"이 스스로 꺼지고(소리 포함) 사라진다.
##   hilt_root는 HiltView 노드(땅 위 손잡이 자리, 원점이 밑동)다. 그 아래 어디든 SwordModel이 하나 있어야 재질을 바꾼다.
##   SwordModel의 MeshInstance3D.material_override를 바꾸고(원래 것은 메타 "omen_orig"에 두었다가 clear가 되돌린다),
##   떨림과 기울기는 SwordModel 노드의 transform에 얹는다(HiltView가 움직이는 _sword 노드는 건드리지 않는다).
## 꾸밈용 흔들림(숨 쉬기, 떨림)은 sin 곡선이고, 금의 모양은 손잡이 자리로 정한 시드의 화면용 rng로 만든다.

## 불씨 빛(PullFx의 갈라짐 빛과 같은 집안). 금(黃金)빛 등급 색과 헷갈리지 않게 붉은 주황으로.
const EMBER: Color = Color(1.0, 0.4, 0.12)
const GLOW: Color = Color(1.0, 0.5, 0.26)
const PROPS: String = "Omen"

const CRACK_SHADER: String = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec3 glow : source_color = vec3(1.0, 0.4, 0.12);
uniform float energy = 0.5;
uniform float phase = 0.0;
uniform float breathe = 0.25;
uniform float fade = 1.0;
void fragment() {
	float core = 1.0 - abs(UV.y - 0.5) * 2.0;
	// 밑동에 가까울수록 뜨겁고, 끝으로 갈수록 그냥 어두운 금
	float heat = (1.0 - smoothstep(0.15, 0.95, UV.x)) * energy;
	heat *= 1.0 - breathe + breathe * (0.5 + 0.5 * sin(TIME * 1.25 + phase));
	float hot = smoothstep(0.45, 0.95, core) * heat;
	ALBEDO = mix(vec3(0.02, 0.014, 0.01), glow * (0.7 + 1.6 * heat), clamp(hot * 1.4, 0.0, 1.0));
	ALPHA = smoothstep(0.0, 0.4, core) * (1.0 - smoothstep(0.85, 1.0, UV.x)) * fade * 0.9;
}
"""

static var _mats: Dictionary = {}
static var _hum_stream: AudioStreamWAV = null
static var _dot: Texture2D = null


## 조짐 모습을 입힌다. omen: 0~3(밖이면 가장 가까운 값). 등급과 상관없다.
static func apply(hilt_root: Node3D, omen: int) -> void:
	clear(hilt_root)
	var o: int = clampi(omen, 0, 3)
	var sword: SwordModel = _find_sword(hilt_root)
	if sword:
		sword.set_meta("omen_xf", sword.transform)
		_dress(sword, o)
		if o == 0:
			# 무디게 버려진 느낌: 조금 더 기운다
			sword.rotate_object_local(Vector3.FORWARD, 0.06)
	var props := Props.new()
	props.name = PROPS
	props.omen = o
	props.sword = sword
	props.seed_value = _seed_of(hilt_root)
	hilt_root.add_child(props)


## 조짐 모습을 걷어 내고 원래(흔함의 녹슨 쇠) 재질과 자세로 되돌린다.
static func clear(hilt_root: Node3D) -> void:
	var old := hilt_root.get_node_or_null(PROPS)
	if old:
		hilt_root.remove_child(old)
		old.queue_free()
	var sword: SwordModel = _find_sword(hilt_root)
	if sword == null:
		return
	if sword.has_meta("omen_xf"):
		sword.transform = sword.get_meta("omen_xf")
		sword.remove_meta("omen_xf")
	for mi in _meshes(sword):
		if mi.has_meta("omen_orig"):
			mi.material_override = mi.get_meta("omen_orig")
			mi.remove_meta("omen_orig")


## 지금 입힌 조짐(없으면 -1).
static func omen_of(hilt_root: Node3D) -> int:
	var p := hilt_root.get_node_or_null(PROPS) as Props
	return p.omen if p else -1


# ---------------------------------------------------------------- 칼의 재질

## 칼날(쇠, 무늬 있음) / 코등이·자루끝(쇠, 무늬 없음) / 손잡이(쇠 아님)를 재질의 모양으로 가려 바꾼다.
## HiltView는 늘 흔함(0)의 SwordModel을 세우므로 그 재질(SwordModel._materials(0))을 기준으로 가린다.
static func _dress(sword: SwordModel, o: int) -> void:
	var look: String = "rust" if o == 0 else "iron"
	for mi in _meshes(sword):
		var m := mi.material_override as StandardMaterial3D
		if m == null:
			continue
		var part: String
		if m.emission_enabled:
			continue   # 빛나는 것(흔함에는 없다)은 그대로
		elif m.metallic > 0.5 and m.albedo_texture != null:
			part = "blade"
		elif m.metallic > 0.5:
			part = "guard"
		else:
			part = "grip"
		mi.set_meta("omen_orig", m)
		mi.material_override = _mat(look, part)


static func _mat(look: String, part: String) -> StandardMaterial3D:
	var key: String = look + "/" + part
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	match key:
		"rust/blade":
			# 붉은 갈색 녹, 군데군데 검게 팬 자리와 쇠가 조금 비치는 자리
			m.albedo_texture = _noise_tex(0.035, [0.0, 0.35, 0.62, 0.9],
				[Color(0.09, 0.065, 0.05), Color(0.2, 0.12, 0.075), Color(0.27, 0.17, 0.11), Color(0.28, 0.26, 0.24)], 11)
			m.metallic = 0.25
			m.roughness = 0.92
			m.uv1_triplanar = true
			m.uv1_scale = Vector3.ONE * 3.0
		"rust/guard":
			m.albedo_texture = _noise_tex(0.05, [0.0, 0.5, 1.0],
				[Color(0.1, 0.07, 0.05), Color(0.22, 0.13, 0.08), Color(0.2, 0.18, 0.16)], 23)
			m.metallic = 0.3
			m.roughness = 0.9
			m.uv1_triplanar = true
			m.uv1_scale = Vector3.ONE * 6.0
		"rust/grip":
			m.albedo_color = Color(0.13, 0.1, 0.08)   # 삭아서 빛이 바랜 가죽
			m.roughness = 1.0
		"iron/blade":
			# 어둡고 깨끗한 쇠. 거칠기에만 아주 옅은 얼룩을 둬서 번들거림이 한 줄로 끊기게
			m.albedo_color = Color(0.5, 0.5, 0.5)
			m.metallic = 1.0
			m.roughness = 0.3
			m.roughness_texture = _noise_tex(0.06, [0.0, 1.0], [Color(0.55, 0.55, 0.55), Color(0.9, 0.9, 0.9)], 37)
			m.uv1_triplanar = true
			m.uv1_scale = Vector3.ONE * 2.0
			m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		"iron/guard":
			m.albedo_color = Color(0.3, 0.3, 0.3)
			m.metallic = 1.0
			m.roughness = 0.38
		_:
			m.albedo_color = Color(0.17, 0.11, 0.08)
			m.roughness = 0.8
	_mats[key] = m
	return m


static func _noise_tex(freq: float, offs: Array, cols: Array, noise_seed: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = noise_seed
	n.frequency = freq
	n.fractal_octaves = 4
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	var t := NoiseTexture2D.new()
	t.noise = n
	t.color_ramp = g
	t.seamless = true
	t.width = 256
	t.height = 256
	return t


static func _find_sword(n: Node) -> SwordModel:
	for c in n.get_children():
		if c is SwordModel:
			return c
		var s: SwordModel = _find_sword(c)
		if s:
			return s
	return null


static func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c)
		out.append_array(_meshes(c))
	return out


static func _seed_of(n: Node3D) -> int:
	var p: Vector3 = n.position
	return hash(Vector2i(roundi(p.x * 10.0), roundi(p.z * 10.0)))


# ---------------------------------------------------------------- 땅의 것

## 밑동 둘레의 금, 먼지, 빛, 울림. 칼이 화면에서 숨으면(뽑힘) 스스로 꺼져 사라진다.
class Props extends Node3D:
	var omen: int = 0
	var sword: SwordModel = null
	var seed_value: int = 0
	var _crack_mat: ShaderMaterial = null
	var _light: OmniLight3D = null
	var _hum: AudioStreamPlayer3D = null
	var _dust: Array[CPUParticles3D] = []
	var _t: float = 0.0
	var _out: float = 1.0
	var _ending: bool = false
	var _base_xf := Transform3D.IDENTITY
	var _ph: float = 0.0

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		_ph = rng.randf() * TAU
		if sword and sword.has_meta("omen_xf"):
			_base_xf = sword.transform
		if omen >= 2:
			_cracks(rng, omen == 3)
		if omen == 3:
			_motes()
			_glow()
			_hum_player()
		set_process(omen == 3 or omen == 2)

	func _process(delta: float) -> void:
		_t += delta
		if not _ending and sword != null and is_instance_valid(sword) and not sword.is_visible_in_tree():
			_ending = true
			for p in _dust:
				p.emitting = false
		if _ending:
			_out = maxf(0.0, _out - delta / 0.6)
			if _crack_mat:
				_crack_mat.set_shader_parameter("fade", _out)
			if _hum:
				_hum.volume_db = OmenArt.HUM_DB + linear_to_db(maxf(_out, 0.001))
			if _out <= 0.0:
				queue_free()
		if _light:
			# 울림에 맞춰 아주 느리게 숨 쉬고, 가끔 흔들린다
			var b: float = 0.75 + 0.25 * sin(_t * 4.19 + _ph) * sin(_t * 0.7)
			_light.light_energy = OmenArt.LIGHT_ENERGY * b * _out
		if omen == 3 and sword != null and is_instance_valid(sword) and not _ending:
			# 낮은 울림: 칼이 눈에 겨우 보일 만큼 떤다
			var j: float = OmenArt.HUM_SHAKE
			var off := Vector3(sin(_t * 57.0 + _ph) + 0.6 * sin(_t * 83.0), 0.0, sin(_t * 61.0) + 0.6 * sin(_t * 89.0 + _ph)) * j
			sword.transform = Transform3D(_base_xf.basis, _base_xf.origin + off)

	## 밑동에서 뻗는 짧은 금 여러 줄(가지 포함). UV.x: 밑동에서 끝(0~1), UV.y: 폭.
	func _cracks(rng: RandomNumberGenerator, strong: bool) -> void:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var count: int = 7 if strong else 5
		var maxlen: float = 1.05 if strong else 0.85
		for i in count:
			var a: float = TAU * i / count + rng.randf_range(-0.4, 0.4)
			var L: float = rng.randf_range(maxlen * 0.5, maxlen)
			var from := Vector2(cos(a), sin(a)) * 0.16
			var pts: Array[Vector2] = _line(rng, from, a, L)
			_ribbon(st, pts, 0.0, L, maxlen, 0.035)
			if rng.randf() < 0.6:
				var j: int = rng.randi_range(2, pts.size() - 2)
				var d0: float = L * float(j) / (pts.size() - 1)
				var bl: float = L * rng.randf_range(0.25, 0.45)
				var side: float = 1.0 if rng.randf() < 0.5 else -1.0
				_ribbon(st, _line(rng, pts[j], a + side * rng.randf_range(0.5, 0.9), bl), d0, bl, maxlen, 0.02)
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		_crack_mat = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = OmenArt.CRACK_SHADER
		_crack_mat.shader = sh
		_crack_mat.set_shader_parameter("glow", OmenArt.EMBER)
		_crack_mat.set_shader_parameter("energy", 0.62 if strong else 0.48)
		_crack_mat.set_shader_parameter("phase", _ph)
		_crack_mat.set_shader_parameter("breathe", 0.35 if strong else 0.3)
		mi.material_override = _crack_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position.y = 0.02
		add_child(mi)

	func _line(rng: RandomNumberGenerator, from: Vector2, a: float, L: float) -> Array[Vector2]:
		var pts: Array[Vector2] = [from]
		var segs: int = 5
		var p: Vector2 = from
		for s in segs:
			a += rng.randf_range(-0.5, 0.5)
			p += Vector2(cos(a), sin(a)) * (L / segs)
			pts.append(p)
		return pts

	func _ribbon(st: SurfaceTool, pts: Array[Vector2], d0: float, L: float, maxlen: float, w0: float) -> void:
		var n: int = pts.size()
		for i in n - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var dir: Vector2 = (b - a).normalized()
			var side := Vector2(-dir.y, dir.x)
			var t0: float = float(i) / (n - 1)
			var t1: float = float(i + 1) / (n - 1)
			var wa: float = w0 * (1.0 - t0 * 0.8)
			var wb: float = w0 * (1.0 - t1 * 0.8)
			var u0: float = (d0 + L * t0) / maxlen
			var u1: float = (d0 + L * t1) / maxlen
			var v := [
				[Vector3(a.x - side.x * wa, 0, a.y - side.y * wa), Vector2(u0, 0)],
				[Vector3(a.x + side.x * wa, 0, a.y + side.y * wa), Vector2(u0, 1)],
				[Vector3(b.x - side.x * wb, 0, b.y - side.y * wb), Vector2(u1, 0)],
				[Vector3(b.x + side.x * wb, 0, b.y + side.y * wb), Vector2(u1, 1)],
			]
			for k in [0, 2, 1, 1, 2, 3]:
				st.set_normal(Vector3.UP)
				st.set_uv(v[k][1])
				st.add_vertex(v[k][0])

	## 떠오르는 먼지(해를 받는 흙먼지)와 그 사이의 아주 적은 불씨 티끌.
	func _motes() -> void:
		var dust := _emitter(16, 3.6, 0.7)
		dust.initial_velocity_min = 0.08
		dust.initial_velocity_max = 0.22
		dust.gravity = Vector3(0, 0.05, 0)
		dust.scale_amount_min = 0.6
		dust.scale_amount_max = 1.3
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
		g.colors = PackedColorArray([Color(0.6, 0.52, 0.44, 0.0), Color(0.6, 0.52, 0.44, 0.32), Color(0.55, 0.48, 0.42, 0.0)])
		dust.color_ramp = g
		dust.mesh = _quad(0.07, false, true)
		var sparks := _emitter(6, 2.8, 0.45)
		sparks.initial_velocity_min = 0.15
		sparks.initial_velocity_max = 0.35
		sparks.gravity = Vector3(0, 0.08, 0)
		sparks.scale_amount_min = 0.5
		sparks.scale_amount_max = 1.0
		var e: Color = OmenArt.GLOW
		var g2 := Gradient.new()
		g2.offsets = PackedFloat32Array([0.0, 0.2, 0.7, 1.0])
		g2.colors = PackedColorArray([Color(e * 1.6, 0.0), Color(e * 1.6, 0.8), Color(e, 0.35), Color(e, 0.0)])
		sparks.color_ramp = g2
		sparks.mesh = _quad(0.025, true, false)

	func _emitter(amount: int, life: float, radius: float) -> CPUParticles3D:
		var p := CPUParticles3D.new()
		p.amount = amount
		p.lifetime = life
		p.preprocess = life
		p.local_coords = false
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		p.emission_ring_axis = Vector3.UP
		p.emission_ring_radius = radius
		p.emission_ring_inner_radius = 0.12
		p.emission_ring_height = 0.05
		p.direction = Vector3.UP
		p.spread = 14.0
		p.damping_min = 0.02
		p.damping_max = 0.06
		p.tangential_accel_min = -0.05
		p.tangential_accel_max = 0.05
		p.position.y = 0.05
		add_child(p)
		_dust.append(p)
		p.emitting = true
		return p

	func _quad(size: float, add: bool, lit: bool) -> QuadMesh:
		var q := QuadMesh.new()
		q.size = Vector2(size, size)
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if add:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		if not lit:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		if OmenArt._dot == null:
			OmenArt._dot = HitFx._soft_dot()
		m.albedo_texture = OmenArt._dot
		m.roughness = 1.0
		q.material = m
		return q

	func _glow() -> void:
		_light = OmniLight3D.new()
		_light.light_color = OmenArt.GLOW
		_light.light_energy = OmenArt.LIGHT_ENERGY
		_light.omni_range = 1.7
		_light.omni_attenuation = 1.6
		_light.shadow_enabled = false
		_light.position.y = 0.22
		add_child(_light)

	func _hum_player() -> void:
		_hum = AudioStreamPlayer3D.new()
		_hum.stream = OmenArt._hum()
		_hum.volume_db = OmenArt.HUM_DB
		_hum.unit_size = 1.6
		_hum.max_distance = 10.0
		_hum.position.y = 0.6
		add_child(_hum)
		_hum.play(fposmod(_ph, 1.0) * 1.4)


## 조짐 3의 소리 크기(dB), 밑동 빛의 세기, 칼이 떠는 폭(m).
const HUM_DB: float = -16.0
const LIGHT_ENERGY: float = 0.16
const HUM_SHAKE: float = 0.0012


## 낮은 울림: 52Hz 둘레의 음 셋과 맥놀이(0.67Hz). 1.5초에 딱 맞게 돌아 이어 붙여도 끊기지 않는다. 음이 오르내리지 않는다.
static func _hum() -> AudioStreamWAV:
	if _hum_stream:
		return _hum_stream
	var rate: int = 22050
	var dur: float = 1.5
	var n: int = int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t: float = float(i) / rate
		var v: float = 0.5 * sin(TAU * 52.0 * t) + 0.42 * sin(TAU * (52.0 + 1.0 / dur) * t)
		v += 0.22 * sin(TAU * 104.0 * t) + 0.08 * sin(TAU * 156.0 * t + 0.7)
		var s: int = clampi(int(v * 0.42 * 32767.0), -32768, 32767)
		data.encode_s16(i * 2, s)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	_hum_stream = w
	return w
