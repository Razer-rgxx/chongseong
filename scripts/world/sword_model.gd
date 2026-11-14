class_name SwordModel
extends Node3D
## 칼 한 자루의 모양을 코드로 만든다(모델 에셋 없이). 칼날은 형태(단검·장검·대검·세검)를 따르고,
## 코등이·손잡이·자루끝은 칼 번호로 고른다(같은 칼은 늘 같은 모양). 등급이 오를수록 재질이 좋아지고 빛이 붙는다.
## 지역 좌표: 코등이가 원점, 칼날은 +Y, 손잡이는 -Y. 날이 선 쪽은 ±X, 칼등의 두께는 Z.
##
## 등급별 모습: 흔함 녹슨 쇠 / 귀함 닦은 강철과 놋쇠 / 전설 금빛 코등이와 피홈의 빛 /
## 신화 검은 강철에 빛나는 무늬 / 초월 칼날 전체가 빛나고 빛 알갱이 / 무한 검은 칼날에 날만 타오르고 알갱이가 많다.

const KINDS: Dictionary = {"단검": "dagger", "장검": "longsword", "대검": "greatsword", "세검": "rapier"}

## 칼날 길이(m)와 손잡이 길이(m). 궤적과 손에 쥐는 자리에 쓴다.
var blade_length: float = 1.0
var grip_length: float = 0.2
var grade: int = 0
var glow_color: Color = Color.WHITE


## form: FormData(칼날 길이·너비), grade: 0~5, seed: 칼 번호, col: 등급 색. form이 null이면 그냥 장검.
static func make(form: FormData, p_grade: int, seed: int, col: Color) -> SwordModel:
	var s := SwordModel.new()
	s._build(form, p_grade, seed, col)
	return s


static func for_sword(sw: Sword, grades: GradeTable) -> SwordModel:
	return make(sw.form, sw.grade, sw.data.id if sw.data else 0, grades.colors[sw.grade])


## 칼날의 손잡이 쪽 끝과 칼끝(세계 좌표).
func blade_points() -> Array[Vector3]:
	return [global_transform * Vector3(0, 0.05, 0), global_transform * Vector3(0, blade_length, 0)]


func _build(form: FormData, p_grade: int, seed: int, col: Color) -> void:
	grade = p_grade
	glow_color = col
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 13
	var kind: String = KINDS.get(form.display_name, "longsword") if form else "longsword"
	blade_length = form.blade_length if form else 1.1
	var width: float = form.blade_width if form else 0.08
	var mats := _materials(grade, col)
	add_child(_blade(kind, blade_length, width, mats[0]))
	if grade >= 2:
		add_child(_fuller(kind, blade_length, width, mats[3]))
	grip_length = {"dagger": 0.11, "longsword": 0.2, "greatsword": 0.36, "rapier": 0.14}.get(kind, 0.2)
	var guard_w: float = {"dagger": 0.16, "longsword": 0.26, "greatsword": 0.42, "rapier": 0.2}.get(kind, 0.26)
	_guard(rng.randi() % 4, guard_w, mats[1], mats[3])
	_grip(grip_length, mats[2])
	_pommel(rng.randi() % 3, guard_w, mats[1], mats[3])
	if grade >= 4:
		_aura(col, grade)


# ---------------------------------------------------------------- 재질

## [칼날, 코등이와 자루끝, 손잡이, 빛]
static func _materials(g: int, col: Color) -> Array[StandardMaterial3D]:
	var blade := StandardMaterial3D.new()
	var guard := StandardMaterial3D.new()
	var grip := StandardMaterial3D.new()
	var glow := StandardMaterial3D.new()
	blade.metallic = 0.9
	guard.metallic = 0.9
	grip.roughness = 0.8
	glow.emission_enabled = true
	glow.albedo_color = col
	glow.emission = col
	glow.emission_energy_multiplier = 2.0 + g * 0.6
	match g:
		0:   # 녹슨 쇠: 얼룩진 잡음
			blade.albedo_texture = _stain(Color(0.36, 0.31, 0.27), Color(0.54, 0.54, 0.56))
			blade.roughness = 0.6
			guard.albedo_color = Color(0.3, 0.28, 0.26)
			guard.roughness = 0.7
			grip.albedo_color = Color(0.22, 0.15, 0.1)
		1:
			blade.albedo_color = Color(0.82, 0.84, 0.88)
			blade.roughness = 0.22
			guard.albedo_color = Color(0.66, 0.5, 0.26)
			guard.roughness = 0.35
			grip.albedo_color = Color(0.18, 0.1, 0.07)
		2:
			blade.albedo_color = Color(0.86, 0.87, 0.9)
			blade.roughness = 0.15
			guard.albedo_color = Color(0.9, 0.68, 0.28)
			guard.roughness = 0.25
			grip.albedo_color = Color(0.3, 0.06, 0.05)
		3:
			blade.albedo_color = Color(0.22, 0.24, 0.28)
			blade.roughness = 0.18
			blade.emission_enabled = true
			blade.emission = col
			blade.emission_energy_multiplier = 1.0
			blade.emission_texture = _runes()
			guard.albedo_color = Color(0.15, 0.15, 0.17)
			guard.roughness = 0.3
			grip.albedo_color = Color(0.08, 0.07, 0.08)
		4:
			blade.albedo_color = col.lightened(0.5)
			blade.roughness = 0.1
			blade.emission_enabled = true
			blade.emission = col
			blade.emission_energy_multiplier = 1.6
			guard.albedo_color = Color(0.92, 0.88, 0.8)
			guard.roughness = 0.2
			grip.albedo_color = Color(0.85, 0.82, 0.75)
		_:
			blade.albedo_color = Color(0.03, 0.03, 0.04)
			blade.roughness = 0.08
			blade.emission_enabled = true
			blade.emission = col
			blade.emission_energy_multiplier = 3.0
			blade.emission_texture = _edges()
			guard.albedo_color = Color(0.05, 0.05, 0.06)
			guard.roughness = 0.15
			guard.emission_enabled = true
			guard.emission = col
			guard.emission_energy_multiplier = 0.4
			grip.albedo_color = Color(0.04, 0.04, 0.05)
	blade.uv1_triplanar = g == 0
	if g == 0:
		blade.uv1_scale = Vector3.ONE * 3.0
	return [blade, guard, grip, glow]


static func _stain(a: Color, b: Color) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = 0.03
	n.fractal_octaves = 4
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.2, 0.75])
	g.colors = PackedColorArray([a, b])
	var t := NoiseTexture2D.new()
	t.noise = n
	t.color_ramp = g
	t.seamless = true
	t.width = 256
	t.height = 256
	return t


## 신화: 칼날 위의 빛나는 무늬(잡음의 가는 띠만 남긴다).
static func _runes() -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	n.frequency = 0.05
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.08, 0.16])
	g.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color.BLACK])
	var t := NoiseTexture2D.new()
	t.noise = n
	t.color_ramp = g
	t.width = 128
	t.height = 512
	return t


## 무한: 날(UV 가장자리)만 밝게.
static func _edges() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.12, 0.3, 1.0])
	g.colors = PackedColorArray([Color.WHITE, Color(0.35, 0.35, 0.35), Color.BLACK, Color.BLACK])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 4
	return t


# ---------------------------------------------------------------- 칼날

## 길이를 따라 단면(날이 깎인 육각형)을 이어 붙인다. 너비와 두께는 형태마다 다른 선을 따른다.
## UV: u는 날에서 0, 가운데 등에서 0.5. v는 0(코등이)~1(칼끝).
static func _blade(kind: String, L: float, W: float, m: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var n: int = 14
	var tip: float = {"dagger": 0.32, "longsword": 0.16, "greatsword": 0.12, "rapier": 0.3}.get(kind, 0.16)
	var thick: float = {"dagger": 0.16, "longsword": 0.13, "greatsword": 0.1, "rapier": 0.42}.get(kind, 0.13)
	var rings: Array = []
	for i in n + 1:
		var t: float = float(i) / n
		var w: float = _width(kind, t, tip) * W / 2.0
		var h: float = maxf(0.004, W * thick * (1.0 - t * 0.5)) * (1.0 if t < 1.0 - tip else (1.0 - t) / tip)
		var y: float = 0.02 + t * (L - 0.02)
		rings.append([
			Vector3(-w, y, 0), Vector3(-w * 0.55, y, h), Vector3(w * 0.55, y, h),
			Vector3(w, y, 0), Vector3(w * 0.55, y, -h), Vector3(-w * 0.55, y, -h),
		])
	var us := [0.0, 0.5, 0.5, 0.0, 0.5, 0.5]   # 0 = 날, 0.5 = 등(가운데)
	for i in n:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		var va: float = float(i) / n
		var vb: float = float(i + 1) / n
		for k in 6:
			var k2: int = (k + 1) % 6
			var u0: float = us[k]
			var u1: float = us[k2]
			_quad(st, a[k], a[k2], b[k2], b[k], Vector2(u0, va), Vector2(u1, va), Vector2(u1, vb), Vector2(u0, vb))
	# 밑동 막기
	var r0: Array = rings[0]
	for k in range(1, 5):
		st.set_uv(Vector2(0.5, 0))
		st.add_vertex(r0[0])
		st.add_vertex(r0[k + 1])
		st.add_vertex(r0[k])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	return mi


## 형태마다 칼날 너비(0~1)를 길이(t)에 따라.
static func _width(kind: String, t: float, tip: float) -> float:
	var body: float
	match kind:
		"dagger":    # 나뭇잎꼴: 가운데가 조금 불룩
			body = 1.0 + 0.3 * sin(PI * minf(1.0, t / (1.0 - tip)) * 0.9)
		"greatsword":   # 넓고 곧게, 밑동은 날을 세우지 않은 좁은 부분
			body = 0.78 if t < 0.1 else 1.0 - t * 0.12
		"rapier":    # 바늘처럼 가늘어진다
			body = 1.0 - t * 0.55
		_:
			body = 1.0 - t * 0.28
	if t > 1.0 - tip:
		var k: float = (t - (1.0 - tip)) / tip
		body *= sqrt(maxf(0.0, 1.0 - k * k)) if kind != "rapier" else (1.0 - k)
	return maxf(0.0, body)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(ub)
	st.add_vertex(b)
	st.set_uv(uc)
	st.add_vertex(c)
	st.set_uv(ua)
	st.add_vertex(a)
	st.set_uv(uc)
	st.add_vertex(c)
	st.set_uv(ud)
	st.add_vertex(d)


## 피홈: 칼날 가운데의 가는 빛줄(전설 이상).
static func _fuller(kind: String, L: float, W: float, m: Material) -> Node3D:
	var n := Node3D.new()
	var len: float = L * (0.55 if kind != "rapier" else 0.4)
	for side in [-1.0, 1.0]:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(maxf(0.006, W * 0.12), len, 0.004)
		b.mesh = bm
		b.material_override = m
		b.position = Vector3(0, 0.06 + len / 2.0, side * W * 0.13 * (2.5 if kind == "rapier" else 1.0))
		n.add_child(b)
	return n


# ---------------------------------------------------------------- 코등이, 손잡이, 자루끝

## 0 곧은 막대, 1 아래로 휜 막대, 2 막대와 가운데 원반, 3 끝이 넓어지는 날개꼴.
func _guard(style: int, w: float, m: Material, glow: Material) -> void:
	match style:
		0:
			_box(Vector3(w, 0.035, 0.045), Vector3(0, 0, 0), m)
			for sx in [-1.0, 1.0]:
				_ball(0.025, Vector3(sx * w / 2.0, 0, 0), m)
		1:   # 가운데 막대와 아래로 꺾인 두 끝
			_box(Vector3(w * 0.62, 0.032, 0.042), Vector3.ZERO, m)
			for sx in [-1.0, 1.0]:
				var tip := _box(Vector3(w * 0.26, 0.03, 0.04), Vector3(sx * w * 0.4, -0.022, 0), m)
				tip.rotation.z = sx * -0.55
		2:
			_box(Vector3(w, 0.03, 0.04), Vector3.ZERO, m)
			var disc := _cyl(0.045, 0.045, 0.03, Vector3.ZERO, m)
			disc.rotation.x = PI / 2.0
		_:
			for sx in [-1.0, 1.0]:
				var wing := _box(Vector3(w * 0.5, 0.03, 0.05), Vector3(sx * w * 0.25, 0.012, 0), m)
				wing.rotation.z = sx * 0.18
				_box(Vector3(0.03, 0.07, 0.06), Vector3(sx * w * 0.5, 0.035, 0), m)
	if grade >= 2:
		var gem := _ball(0.018, Vector3(0, 0, 0.03), glow)
		gem.scale = Vector3(1, 1.3, 0.6)
		var gem2 := _ball(0.018, Vector3(0, 0, -0.03), glow)
		gem2.scale = Vector3(1, 1.3, 0.6)


func _grip(len: float, m: Material) -> void:
	_cyl(0.017, 0.019, len, Vector3(0, -len / 2.0, 0), m)
	var rings: int = int(len / 0.035)
	for i in rings:
		_cyl(0.021, 0.021, 0.008, Vector3(0, -0.02 - i * (len - 0.03) / maxf(1, rings - 1), 0), m)


## 0 공, 1 원반, 2 각진 덩이.
func _pommel(style: int, guard_w: float, m: Material, glow: Material) -> void:
	var y: float = -grip_length - 0.025
	match style:
		0:
			_ball(0.032 + guard_w * 0.03, Vector3(0, y, 0), m)
		1:
			var d := _cyl(0.04, 0.04, 0.025, Vector3(0, y, 0), m)
			d.rotation.x = PI / 2.0
		_:
			var b := _box(Vector3(0.045, 0.05, 0.045), Vector3(0, y, 0), m)
			b.rotation.y = PI / 4.0
	if grade >= 3:
		_ball(0.014, Vector3(0, y - 0.03, 0), glow)


## 초월 이상: 칼날을 따라 피어오르는 빛 알갱이.
func _aura(col: Color, g: int) -> void:
	var p := CPUParticles3D.new()
	p.amount = 18 if g == 4 else 36
	p.lifetime = 0.9
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.02, blade_length * 0.45, 0.01)
	p.position = Vector3(0, blade_length * 0.5, 0)
	p.direction = Vector3(0, 1, 0)
	p.spread = 60.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.25
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.05, 0.05)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = HitFx._soft_dot()
	q.material = m
	p.mesh = q
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(col, 0.0), Color(col.lightened(0.3), 1.0), Color(col, 0.0)])
	gr.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	p.color_ramp = gr
	add_child(p)


func _box(size: Vector3, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	add_child(mi)
	return mi


func _cyl(top: float, bottom: float, h: float, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 10
	c.rings = 1
	mi.mesh = c
	mi.material_override = m
	mi.position = at
	add_child(mi)
	return mi


func _ball(r: float, at: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 6
	mi.mesh = s
	mi.material_override = m
	mi.position = at
	add_child(mi)
	return mi
