class_name EnemyView
extends Node3D
## 적 하나. 종류마다 몸을 짓고(망령: 해진 망토, 늑대: 네발짐승, 거인·언덕지기: 기사 모델을 어둡게 키운 것),
## 규칙의 위치를 틱 사이로 이어 그린다. 싸움터 밖으로 밀려나면 언덕 비탈 높이에 선다.
## 나타날 때는 비탈 아래에서 기어 올라오고(망령은 연기처럼 맺힌다), 눈은 스스로 빛나 어두운 밤에도 보인다.
## 모델 에셋이 들어오면 _build_* 만 바꾼다. 기사 모델(assets/characters/lord/paladin.fbx)이 없으면 거인은 기본 도형이다.

const CLOAK_SHADER: Shader = preload("res://scripts/enemies/wraith_cloak.gdshader")

@export var flash_time: float = 0.09
@export var die_time: float = 0.6
## 맞으면 뒤로 젖혀지는 각도(라디안)와 돌아오는 빠르기.
@export var recoil_angle: float = 0.35
@export var recoil_return: float = 9.0
## 비탈에서 올라오는 시간(초)과 거리(m).
@export var rise_time: float = 0.55
@export var rise_from: float = 5.0
## 늑대 한 걸음의 길이(m). 작으면 다리를 빨리 놀린다.
@export var wolf_stride: float = 1.3
## 거인 걸음 동작의 빠르기(이동 1m/초당). 걷기 동작이 있으면 그것을, 없으면 달리기를 느리게 튼다.
@export var giant_anim_per_speed: float = 0.32
@export var turn_speed: float = 8.0

var enemy: Enemy
var _mats: Array[StandardMaterial3D] = []
var _base: Array[Color] = []
var _cloaks: Array[ShaderMaterial] = []
var _flash: float = 0.0
var _dying: float = -1.0
var _body := Node3D.new()
var _t: float = 0.0
var _recoil: float = 0.0
var _rise: float = 1.0
var _out_dir := Vector3.ZERO
var _height: float = 2.0
var _speed_m: float = 0.0
var _last_pos := Vector3.ZERO
var _last_cd: float = 0.0
var _attack: float = -1.0
var _yaw: float = 0.0
# 늑대
var _hips: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _head: Node3D = null
var _tail: Node3D = null
var _gait: float = 0.0
# 망령
var _arms: Array[Node3D] = []
var _wisps: CPUParticles3D = null
# 거인(기사 모델)
var _knight: LordCharacter = null
var _knight_scale: float = 1.0
var _eyes_placed: bool = false
var _eyes: Node3D = null
var _hit_anim: float = -1.0


func setup(e: Enemy) -> void:
	enemy = e


func _ready() -> void:
	add_child(_body)
	var D := enemy.data
	var r: float = Grid.cells_to_meters(enemy.radius)
	var grow: float = enemy.radius / D.radius
	match D.id:
		&"wolf":
			_build_wolf(grow, D.color)
		&"giant", &"boss":
			if LordCharacter.available():
				_build_knight(grow, D.color, D.boss)
			else:
				_build_giant(r, D.color, D.boss)
		_:
			_build_wraith(grow, D.color)
	if enemy.elite:
		# 정예: 몸이 은은한 금빛, 발밑을 비추는 작은 빛
		for m in _mats:
			m.emission_enabled = true
			m.emission = Color(1.0, 0.75, 0.35)
			m.emission_energy_multiplier = 0.3
		for c in _cloaks:
			c.set_shader_parameter("rim", Color(1.0, 0.8, 0.4))
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.75, 0.4)
		l.light_energy = 1.2
		l.omni_range = 3.5 * grow
		l.position.y = 1.2
		add_child(l)
	position = _ground(Grid.cells_to_world(enemy.pos))
	_yaw = atan2(-enemy.face.x, -enemy.face.y)
	rotation.y = _yaw
	_last_pos = position
	_last_cd = enemy.cooldown
	# 싸움터 가장자리에서 나왔으면 비탈 아래에서 올라온다
	if HillBuilder.outside(position.x, position.z) > 0.5:
		_rise = 0.0
		var mid := Grid.cells_to_world(Grid.middle())
		_out_dir = Vector3(position.x - mid.x, 0.0, position.z - mid.z).normalized()


func hit(big: bool = false) -> void:
	_flash = flash_time
	_recoil = 1.6 if big else 1.0
	if _knight and big and _attack < 0.0:
		_hit_anim = 0.0


func die() -> void:
	_dying = 0.0
	if _knight:
		_knight.play("death", 1.0)
	if _wisps:
		_wisps.amount = 24
		_wisps.explosiveness = 0.8


## 땅 위의 자리(싸움터 밖이면 비탈 높이).
static func _ground(p: Vector3) -> Vector3:
	p.y = HillBuilder.height(p.x, p.z)
	return p


## main이 매 프레임 부른다. 다 사라졌으면 true.
func draw(alpha: float, delta: float) -> bool:
	_t += delta
	if _dying >= 0.0:
		return _draw_death(delta)
	var p := _ground(Grid.cells_to_world(enemy.prev_pos.lerp(enemy.pos, alpha)))
	var step: float = Vector2(p.x - _last_pos.x, p.z - _last_pos.z).length()
	_speed_m = lerpf(_speed_m, step / maxf(delta, 0.001), 1.0 - exp(-10.0 * delta))
	_last_pos = p
	# 비탈 아래에서 올라오는 중이면 바깥쪽 아래에서 시작한다
	if _rise < 1.0:
		_rise = minf(1.0, _rise + delta / rise_time)
		var k: float = 1.0 - pow(1.0 - _rise, 2.0)
		var q: Vector3 = p + _out_dir * rise_from * (1.0 - k)
		p = _ground(q)
		if enemy.data.wraith:
			p = Grid.cells_to_world(enemy.prev_pos.lerp(enemy.pos, alpha))
	position = p
	_yaw = lerp_angle(_yaw, atan2(-enemy.face.x, -enemy.face.y), 1.0 - exp(-turn_speed * delta))
	rotation.y = _yaw
	# 쿨다운이 다시 차면 막 때린 것
	if enemy.cooldown > _last_cd + 0.05:
		_attack = 0.0
	_last_cd = enemy.cooldown
	if _attack >= 0.0:
		_attack += delta
	_recoil = maxf(0.0, _recoil - delta * recoil_return * maxf(0.3, _recoil))
	_flash -= delta
	if _knight:
		_animate_knight(delta)
	elif _hips.size() > 0:
		_animate_wolf(delta)
	elif not _cloaks.is_empty():
		_animate_wraith(delta)
	else:
		_body.rotation.x = recoil_angle * _recoil
		_body.scale = Vector3(1.0 + 0.06 * _recoil, 1.0 - 0.08 * _recoil, 1.0 + 0.06 * _recoil)
		if _attack > 0.4:
			_attack = -1.0
	_paint()
	return false


func _draw_death(delta: float) -> bool:
	_dying += delta
	var k: float = _dying / die_time
	if not _cloaks.is_empty():
		# 망령: 흩어지며 위로
		for c in _cloaks:
			c.set_shader_parameter("fade", clampf(1.0 - k, 0.0, 1.0))
		for e in _eyes_list():
			e.visible = k < 0.4
		_body.position.y += delta * 1.2
		return k >= 1.3
	if _knight:
		# 기사: 쓰러지는 동작을 보고 나서 땅으로 가라앉는다
		var fall: float = minf(2.2, _knight.length("death"))
		if _dying > fall:
			_body.position.y -= delta * 1.5
		if _eyes:
			_eyes.visible = _dying < fall * 0.6
		return _dying > fall + 1.2
	# 늑대와 도형 거인: 옆으로 넘어간 뒤 가라앉는다
	_body.rotation.z = lerpf(_body.rotation.z, PI / 2.0, 1.0 - pow(1.0 - minf(1.0, k * 1.8), 3.0))
	_body.position.y = -maxf(0.0, k - 0.6) * 2.0
	return k >= 1.0


func _eyes_list() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n in _body.find_children("Eye*", "MeshInstance3D", true, false):
		out.append(n as Node3D)
	return out


## 맞았을 때 번쩍임과 상태 빛: 불(주황 깜빡임), 얼음(푸른 흰빛), 망각(보라), 느림(푸른 기), 출혈(붉은 기)
func _paint() -> void:
	var w: float = clampf(_flash / flash_time, 0.0, 1.0)
	var tint := Color(0, 0, 0, 0)
	if enemy.burn > 0.0:
		tint = Color(1.0, 0.45, 0.1, 0.45 + 0.2 * sin(_t * 18.0))
	elif enemy.frozen:
		tint = Color(0.75, 0.92, 1.0, 0.7)
	elif enemy.confused > 0.0:
		tint = Color(0.65, 0.4, 1.0, 0.45)
	elif enemy.slow_k > 0.0:
		tint = Color(0.45, 0.65, 1.0, 0.35)
	elif enemy.bleed_t > 0.0:
		tint = Color(0.6, 0.0, 0.0, 0.35)
	for i in _mats.size():
		var c: Color = _base[i].lerp(Color(tint.r, tint.g, tint.b), tint.a)
		_mats[i].albedo_color = c.lerp(Color.WHITE, w)
	for c in _cloaks:
		c.set_shader_parameter("tint", Vector4(tint.r, tint.g, tint.b, tint.a))
		c.set_shader_parameter("flash", w * 0.8)


# ---------------------------------------------------------------- 공통 부품

func _mat(c: Color, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if glow:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 4.0
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		_mats.append(m)
		_base.append(c)
	return m


func _add(parent: Node3D, mesh: Mesh, m: Material, at: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func _eyes_at(parent: Node3D, at: Vector3, gap: float, size: float, c: Color) -> void:
	var s := SphereMesh.new()
	s.radius = size
	s.height = size * 1.4
	s.radial_segments = 8
	s.rings = 4
	var m := _mat(Color(1.0, 0.8, 0.35) if enemy.elite else c, true)
	for side in [-1.0, 1.0]:
		var e := _add(parent, s, m, at + Vector3(gap * side, 0, 0))
		e.name = "Eye%d" % (0 if side < 0 else 1)
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------- 망령

func _build_wraith(s: float, c: Color) -> void:
	_height = 2.1 * s
	var cloak := ShaderMaterial.new()
	cloak.shader = CLOAK_SHADER
	cloak.set_shader_parameter("tatter", _tatter())
	cloak.set_shader_parameter("rim", c)
	cloak.set_shader_parameter("phase", float(enemy.id % 17) * 0.37)
	cloak.set_shader_parameter("fade", 1.0)
	_cloaks.append(cloak)
	# 몸통과 두건을 한 겹의 망토로(아래에서 위로: 높이, 가로, 앞뒤, 뒤로 밀림)
	var prof: Array = [
		[0.0, 0.5, 0.46, 0.06], [0.35, 0.44, 0.4, 0.05], [0.75, 0.37, 0.32, 0.03],
		[1.1, 0.34, 0.26, 0.01], [1.38, 0.33, 0.22, 0.0], [1.5, 0.27, 0.2, 0.0],
		[1.58, 0.17, 0.16, 0.01], [1.66, 0.19, 0.19, 0.03], [1.82, 0.2, 0.2, 0.05],
		[1.96, 0.16, 0.17, 0.09], [2.05, 0.08, 0.1, 0.14], [2.1, 0.01, 0.01, 0.19],
	]
	for p in prof:
		p[0] *= s
		p[1] *= s
		p[2] *= s
		p[3] *= s
	var robe := _add(_body, CreatureMesh.lathe(prof, 22), cloak, Vector3.ZERO)
	robe.name = "Robe"
	# 두건 안의 어둠과 눈
	var face := SphereMesh.new()
	face.radius = 0.15 * s
	face.height = 0.24 * s
	var void_m := StandardMaterial3D.new()
	void_m.albedo_color = Color(0.0, 0.0, 0.0)
	void_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_add(_body, face, void_m, Vector3(0, 1.8 * s, -0.09 * s))
	_eyes_at(_body, Vector3(0, 1.82 * s, -0.21 * s), 0.055 * s, 0.03 * s, Color(0.9, 0.88, 1.0))
	# 늘어진 소매(팔): 어깨에서 앞으로 뻗는다
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(0.27 * s * side, 1.42 * s, 0.0)
		_body.add_child(pivot)
		var arm := CreatureMesh.loft([
			[Vector3(0, 0.05, 0) * s, 0.07 * s, 0.07 * s],
			[Vector3(0.06 * side, -0.3, -0.08) * s, 0.075 * s, 0.075 * s],
			[Vector3(0.05 * side, -0.62, -0.2) * s, 0.1 * s, 0.09 * s],
			[Vector3(0.04 * side, -0.7, -0.24) * s, 0.11 * s, 0.1 * s],
		], 10, 0.0, false)
		_add(pivot, arm, cloak, Vector3.ZERO)
		_arms.append(pivot)
	_wisps = _make_wisps(c, s)
	_body.add_child(_wisps)


static func _tatter() -> NoiseTexture2D:
	var nz := FastNoiseLite.new()
	nz.frequency = 0.035
	nz.fractal_octaves = 3
	var t := NoiseTexture2D.new()
	t.noise = nz
	t.seamless = true
	t.width = 128
	t.height = 128
	return t


func _make_wisps(c: Color, s: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 1.4
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.4 * s
	p.emission_ring_inner_radius = 0.1 * s
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = 0.15
	p.initial_velocity_max = 0.4
	p.gravity = Vector3(0, 0.3, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.5, 1.0))
	curve.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(c, 0.0), Color(c.darkened(0.4), 0.12), Color(c, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	p.color_ramp = g
	var q := QuadMesh.new()
	q.size = Vector2(0.6, 0.6) * s
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = HitFx._soft_dot()
	q.material = m
	p.mesh = q
	p.position.y = 0.05
	return p


func _animate_wraith(delta: float) -> void:
	var bob: float = 0.25 + sin(_t * 2.5 + enemy.id) * 0.1
	_body.position.y = bob
	# 움직이면 앞으로 기울고, 맞으면 뒤로 젖혀진다
	var lean: float = -0.18 * clampf(_speed_m / 3.0, 0.0, 1.0)
	_body.rotation.x = lean + recoil_angle * _recoil
	_body.scale = Vector3.ONE * (1.0 + 0.05 * _recoil)
	# 나타날 때: 연기처럼 맺힌다
	var fade: float = 1.0
	if _rise < 1.0:
		fade = _rise
	for c in _cloaks:
		c.set_shader_parameter("fade", fade)
	# 팔: 영주에게 가까우면 앞으로 뻗고, 때릴 때 휘두른다
	var reach: float = -0.5
	if _attack >= 0.0:
		var k: float = clampf(_attack / 0.35, 0.0, 1.0)
		reach = -1.4 + sin(k * PI) * -0.4
		if _attack > 0.5:
			_attack = -1.0
	for i in _arms.size():
		var a := _arms[i]
		a.rotation.x = lerpf(a.rotation.x, reach + sin(_t * 1.7 + i) * 0.12, 1.0 - exp(-8.0 * delta))


# ---------------------------------------------------------------- 늑대

func _build_wolf(s: float, c: Color) -> void:
	_height = 1.0 * s
	var coat: Color = Color(0.13, 0.12, 0.11).lerp(c, 0.12)
	var fur := CreatureMesh.fur(coat, coat.darkened(0.6))
	_mats.append(fur)
	_base.append(fur.albedo_color)
	var torso := CreatureMesh.loft([
		[Vector3(0, 0.66, 0.6), 0.06, 0.06],
		[Vector3(0, 0.66, 0.52), 0.15, 0.16],
		[Vector3(0, 0.64, 0.36), 0.17, 0.19],
		[Vector3(0, 0.65, 0.12), 0.15, 0.16],
		[Vector3(0, 0.62, -0.14), 0.18, 0.24],
		[Vector3(0, 0.62, -0.34), 0.2, 0.27],
		[Vector3(0, 0.72, -0.5), 0.19, 0.25],
		[Vector3(0, 0.84, -0.6), 0.15, 0.17],
		[Vector3(0, 0.92, -0.66), 0.1, 0.1],
	], 14, 0.12)
	var body_node := Node3D.new()
	body_node.scale = Vector3.ONE * s
	_body.add_child(body_node)
	_add(body_node, torso, fur, Vector3.ZERO)
	# 머리
	_head = Node3D.new()
	_head.position = Vector3(0, 0.92, -0.68)
	body_node.add_child(_head)
	var skull := CreatureMesh.loft([
		[Vector3(0, 0.02, 0.05), 0.07, 0.07],
		[Vector3(0, 0.03, -0.05), 0.12, 0.1],
		[Vector3(0, 0.01, -0.15), 0.1, 0.085],
		[Vector3(0, -0.025, -0.25), 0.06, 0.055],
		[Vector3(0, -0.035, -0.33), 0.038, 0.04],
	], 12, 0.15)
	_add(_head, skull, fur, Vector3.ZERO)
	var ear := CylinderMesh.new()
	ear.top_radius = 0.0
	ear.bottom_radius = 0.04
	ear.height = 0.12
	ear.radial_segments = 6
	for side in [-1.0, 1.0]:
		_add(_head, ear, fur, Vector3(0.06 * side, 0.12, -0.02), Vector3(-0.3, 0, -0.3 * side))
	var nose := SphereMesh.new()
	nose.radius = 0.022
	nose.height = 0.03
	_add(_head, nose, _mat(Color(0.03, 0.03, 0.03)), Vector3(0, -0.025, -0.36))
	_eyes_at(_head, Vector3(0, 0.045, -0.165), 0.055, 0.017, Color(1.0, 0.72, 0.25))
	# 꼬리
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.66, 0.58)
	body_node.add_child(_tail)
	var tail := CreatureMesh.loft([
		[Vector3(0, 0, 0), 0.05, 0.05],
		[Vector3(0, -0.06, 0.14), 0.08, 0.085],
		[Vector3(0, -0.18, 0.27), 0.09, 0.095],
		[Vector3(0, -0.3, 0.34), 0.065, 0.07],
		[Vector3(0, -0.4, 0.37), 0.015, 0.015],
	], 10, 0.0)
	_add(_tail, tail, fur, Vector3.ZERO)
	# 다리: 엉덩이(어깨) 관절과 무릎 관절
	var legs: Array = [
		[Vector3(-0.11, 0.58, -0.38), 0.28, 0.3, 0.0, 0.0],
		[Vector3(0.11, 0.58, -0.38), 0.28, 0.3, 0.0, 0.0],
		[Vector3(-0.11, 0.6, 0.38), 0.3, 0.34, 0.35, -0.65],
		[Vector3(0.11, 0.6, 0.38), 0.3, 0.34, 0.35, -0.65],
	]
	for L in legs:
		var hip := Node3D.new()
		hip.position = L[0]
		body_node.add_child(hip)
		var upper := CreatureMesh.loft([
			[Vector3(0, 0.06, 0), 0.08, 0.11],
			[Vector3(0, -L[1] * 0.45, 0), 0.07, 0.085],
			[Vector3(0, -L[1], 0), 0.045, 0.05],
		], 8, 0.0)
		var up_node := Node3D.new()
		up_node.rotation.x = L[3]
		hip.add_child(up_node)
		_add(up_node, upper, fur, Vector3.ZERO)
		var knee := Node3D.new()
		knee.position = Vector3(0, -L[1], 0)
		knee.rotation.x = L[4]
		up_node.add_child(knee)
		var lower := CreatureMesh.loft([
			[Vector3(0, 0, 0), 0.045, 0.05],
			[Vector3(0, -L[2] * 0.85, 0), 0.032, 0.036],
			[Vector3(0, -L[2], -0.05), 0.045, 0.028],
		], 8, 0.0)
		_add(knee, lower, fur, Vector3.ZERO)
		_hips.append(hip)
		_knees.append(knee)


func _animate_wolf(delta: float) -> void:
	var run: float = clampf(_speed_m / 3.5, 0.0, 1.0)
	_gait += _speed_m * delta / wolf_stride * TAU
	for i in _hips.size():
		# 대각선 짝(앞왼·뒤오, 앞오·뒤왼)이 같이 움직이는 빠른 걸음
		var ph: float = _gait + (0.0 if i == 0 or i == 3 else PI)
		_hips[i].rotation.x = sin(ph) * 0.6 * run
		_knees[i].get_parent().rotation.x = (0.35 if i >= 2 else 0.0)
		var bend: float = maxf(0.0, sin(ph + 1.3)) * 0.9 * run
		_knees[i].rotation.x = (-0.65 if i >= 2 else 0.0) + (bend if i < 2 else -bend * 0.6)
	var bounce: float = absf(sin(_gait)) * 0.05 * run
	_body.position.y = bounce
	_body.rotation.x = recoil_angle * _recoil + sin(_gait * 2.0) * 0.03 * run
	_tail.rotation.x = 0.2 + sin(_t * 2.0) * 0.1 - run * 0.5
	_tail.rotation.y = sin(_t * 3.0 + enemy.id) * 0.25
	# 물 때: 머리를 내밀며 몸을 앞으로
	var bite: float = 0.0
	if _attack >= 0.0:
		bite = sin(clampf(_attack / 0.25, 0.0, 1.0) * PI)
		if _attack > 0.3:
			_attack = -1.0
	_head.rotation.x = -0.15 - bite * 0.45 + sin(_gait * 2.0) * 0.05 * run
	_body.position.z = -bite * 0.2


# ---------------------------------------------------------------- 거인과 언덕지기(기사 모델)

func _build_knight(grow: float, c: Color, boss: bool) -> void:
	_knight = LordCharacter.new()
	_body.add_child(_knight)
	_knight_scale = (2.5 if boss else 1.85) * grow
	_knight.scale = Vector3.ONE * _knight_scale
	_height = 1.8 * _knight_scale
	var mul: Color = Color(0.3, 0.1, 0.1) if boss else Color(0.4, 0.4, 0.42).lerp(c, 0.15)
	var mats := _knight.recolor(mul, Color(0.6, 0.06, 0.02) if boss else Color.BLACK, 0.08 if boss else 0.0)
	for m in mats:
		_mats.append(m)
		_base.append(m.albedo_color)
	var sword := SwordModel.make(null, 0, 4000 + enemy.id, Color.WHITE)
	_knight.hold(sword)
	# 투구 안의 눈. 뼈의 방향이 모델마다 달라서 첫 프레임에 머리 앞에 맞춘다(_place_eyes)
	_eyes = Node3D.new()
	_knight.attach("mixamorig_Head", _eyes)
	_eyes_at(_eyes, Vector3.ZERO, 0.035, 0.012, Color(1.0, 0.35, 0.15) if boss else Color(0.7, 0.85, 1.0))
	_knight.play("idle")


func _place_eyes() -> void:
	if _eyes_placed or _eyes == null or not _eyes.is_inside_tree():
		return
	_eyes_placed = true
	var at: Node3D = _eyes.get_parent()
	var fwd: Vector3 = -global_basis.z.normalized()
	var right: Vector3 = global_basis.x.normalized()
	var k: float = _knight_scale
	var want: Vector3 = at.global_position + fwd * 0.11 * k + Vector3.UP * 0.07 * k
	var inv: Transform3D = at.global_transform.affine_inverse()
	_eyes.transform = Transform3D(Basis.IDENTITY, inv * want)
	# 두 눈 사이를 세계 기준 좌우로 맞추고, 뼈의 크기와 상관없이 같은 크기로 보이게
	var unit: float = (inv.basis * right).length()
	for e in _eyes_list():
		var side: float = -1.0 if e.name == "Eye0" else 1.0
		e.position = (inv.basis * right).normalized() * 0.035 * k * unit * side
		e.scale = Vector3.ONE * unit * k


func _animate_knight(delta: float) -> void:
	_place_eyes()
	_body.rotation.x = recoil_angle * 0.4 * _recoil
	var moving: bool = _speed_m > 0.25
	var walk: String = "walk" if _knight.has("walk") else "run"
	if _attack >= 0.0:
		if _attack <= delta + 0.0001:
			_knight.play("slash", 0.85, 0.15)
		if _attack > maxf(0.6, _knight.length("slash1") / 0.85 - 0.3):
			_attack = -1.0
	elif _hit_anim >= 0.0:
		if _hit_anim <= 0.0001:
			_knight.play("hit", 1.2)
		_hit_anim += delta
		if _hit_anim > 0.45:
			_hit_anim = -1.0
	elif moving:
		var sp: float = _speed_m * giant_anim_per_speed / _knight_scale * (1.0 if walk == "walk" else 0.55)
		_knight.play(walk, clampf(sp, 0.3, 1.2))
	else:
		_knight.play("idle", 0.8)


# ---------------------------------------------------------------- 기사 모델이 없을 때의 거인

func _build_giant(r: float, c: Color, boss: bool) -> void:
	r *= 0.75
	_height = r * 4.4
	var m := _mat(c.darkened(0.4))
	var dark := _mat(c.darkened(0.7))
	var leg := CapsuleMesh.new()
	leg.radius = r * 0.28
	leg.height = r * 1.5
	_add(_body, leg, dark, Vector3(-r * 0.4, r * 0.7, 0))
	_add(_body, leg, dark, Vector3(r * 0.4, r * 0.7, 0))
	var torso := CapsuleMesh.new()
	torso.radius = r * 0.8
	torso.height = r * 2.6
	_add(_body, torso, m, Vector3(0, r * 2.4, 0))
	var arm := CapsuleMesh.new()
	arm.radius = r * 0.25
	arm.height = r * 1.9
	_add(_body, arm, dark, Vector3(-r * 1.0, r * 2.4, 0), Vector3(0, 0, 0.15))
	_add(_body, arm, dark, Vector3(r * 1.0, r * 2.4, 0), Vector3(0, 0, -0.15))
	var head := SphereMesh.new()
	head.radius = r * 0.42
	head.height = r * 0.84
	_add(_body, head, m, Vector3(0, r * 4.0, -r * 0.1))
	if boss:
		var horn := CylinderMesh.new()
		horn.top_radius = 0.0
		horn.bottom_radius = r * 0.12
		horn.height = r * 0.8
		var hm := _mat(Color(0.1, 0.02, 0.03))
		_add(_body, horn, hm, Vector3(-r * 0.3, r * 4.5, 0), Vector3(0, 0, 0.5))
		_add(_body, horn, hm, Vector3(r * 0.3, r * 4.5, 0), Vector3(0, 0, -0.5))
	_eyes_at(_body, Vector3(0, r * 4.05, -r * 0.48), r * 0.15, r * 0.07, Color(1.0, 0.8, 0.35) if boss else Color(0.75, 0.9, 1.0))
