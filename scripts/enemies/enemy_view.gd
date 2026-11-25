class_name EnemyView
extends Node3D
## 적 하나. 종류마다 몸을 짓고(망령: 해진 망토, 늑대: 네발짐승, 거인·언덕지기: 기사 모델을 어둡게 키운 것),
## 규칙의 위치를 틱 사이로 이어 그린다. 싸움터 밖으로 밀려나면 언덕 비탈 높이에 선다.
## 나타날 때는 비탈 아래에서 기어 올라오고(망령은 연기처럼 맺힌다), 눈은 스스로 빛나 어두운 밤에도 보인다.
## 공격 표를 든 적은 눈이 더 밝고, 때리기 직전에는 번쩍인다. 몸은 늘 face(기다릴 때는 영주 쪽)를 본다.
## 모델 에셋이 들어오면 _build_* 만 바꾼다. 기사 모델(assets/characters/lord/paladin.fbx)이 없으면 거인은 기본 도형이다.
## 11단계 새 적 5종(활잡이, 방패병, 돌격병, 자폭병, 부르는 자)은 EnemyArt가 몸을 짓고(parts) EnemyMotion이 매 프레임 움직인다.
## 이펙트(EnemyFx)는 parts로 방패·배·지팡이 끝의 실제 자리를 읽는다.

## 정예 발밑 고리의 빛깔(31단계, NightArt.boss_ring 판에 칠한다).
const ELITE_RING: Color = Color(0.62, 0.42, 0.12)
const ELITE_RING_HOT: Color = Color(1.0, 0.8, 0.38)
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
## 무덤 기사(18단계)의 큰 칼 크기 배수, 몸을 기울이는 정도(라디안)와 칼을 내려치는 빠르기(1/초).
@export var rust_sword: float = 1.5
@export var rust_lean: float = 0.3
@export var rust_swing_rate: float = 14.0
## 공격 표를 든 적의 눈: 밝기 배수와 크기 배수. 때리기 직전(attack_soon)에는 더 번쩍인다.
@export var token_eye_bright: float = 1.8
@export var token_eye_size: float = 1.3
@export var soon_eye_bright: float = 3.2
@export var soon_eye_size: float = 1.6
## 체력 막대(2026-11-21): 맞은 적의 머리 위에 짧은 막대(글자 없음). 마지막으로 깎인 뒤 이만큼(초) 보이다 사라진다.
## 깎인 몫은 옅은 막대로 잠깐 남았다가 따라 줄어든다. 보스·우두머리(화면 아래 큰 막대)와 허수아비는 달지 않는다.
@export var bar_show: float = 3.0
@export var bar_fade: float = 0.5
@export var bar_lag_speed: float = 0.9

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
# 눈빛(공격 표)
var _eye_mats: Array[StandardMaterial3D] = []
var _eye_base: Array[Color] = []
var _eye_nodes: Array[Node3D] = []
var _eye_scale: Array[Vector3] = []
var _token_glow: float = 0.0
var _soon_glow: float = 0.0
# 새 적 5종: EnemyArt의 부품(EnemyFx가 읽는다)과 EnemyMotion의 움직임 상태
var parts: Dictionary = {}
var _motion: Dictionary = {}
var _shield_knight: LordCharacter = null
var _vel := Vector3.ZERO
# 무덤 기사(기사 모델이 없을 때의 도형 칼 팔 포즈와 몸 기울임)
var _arm_pivot: Node3D = null
## 체력 막대: 뿌리(카메라를 본다), 채움, 깎인 몫, 막대 너비(m), 마지막으로 깎인 뒤 지난 초(-1이면 감춤), 지난 체력, 깎인 몫의 비율.
const BAR_SHADER: Shader = preload("res://scripts/enemies/enemy_bar.gdshader")

var _bar: Node3D = null
var _bar_mat: ShaderMaterial = null
var _bar_w: float = 0.9
var _bar_t: float = -1.0
var _bar_hp: float = -1.0
var _lag_k: float = 1.0
var _lean: float = 0.0
## 그림자 걸음(보스 패턴)으로 땅에 꺼진 정도(0~1).
var _sink: float = 0.0


func setup(e: Enemy) -> void:
	enemy = e


func _ready() -> void:
	add_child(_body)
	var D := enemy.data
	var r: float = Grid.cells_to_meters(enemy.radius)
	# 32단계 우두머리는 이미 있는 적의 큰 판: 그 종류(acts)의 몸을 view_scale배로 짓는다(언덕지기의 붉은 빛은 입히지 않는다)
	var kind: StringName = D.acts()
	var grow: float = enemy.radius / D.radius * D.view_scale
	var hill_boss: bool = D.boss and D.kind == &""
	# 24단계: 이 적의 Mixamo 모델(assets/characters/enemies/<id>.fbx)이 있으면 그것으로 선다. 늑대·허수아비·방패병은 따로.
	var own: String = "" if kind in [&"wolf", &"dummy", &"shield"] or D.future or D.past else LordCharacter.enemy_path(kind)
	if D.future:   # 녹슨 미래 구역의 적: 도형 몸
		_build_future(kind, grow, D.color)
	elif D.past:   # 과거 신화 구역의 적: 돌과 뿔의 도형 몸
		_build_future(kind, grow, D.color)
	elif own != "":
		_build_knight(grow, D.color, hill_boss, own)
	else:
		match kind:
			&"wolf":
				_build_wolf(grow, D.color)
			&"giant", &"boss", &"grave_knight", &"crypt_lord":
				if LordCharacter.available():
					_build_knight(grow, D.color, hill_boss)
				else:
					_build_giant(r * (D.model_scale / 2.5 if D.model_scale > 0.0 else 1.0), D.color, hill_boss)
			&"archer", &"shield", &"charger", &"bomber", &"caller":
				_build_new(kind, grow, D.color)
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
		if not enemy.hunt:   # 발밑의 금빛 고리(우두머리의 검붉은 고리와 같은 판, 31단계). 사냥 우두머리는 NightFx의 검붉은 고리를 단다
			var ring := NightArt.boss_ring(self, Grid.cells_to_meters(enemy.radius) * 1.7, float(enemy.id % 17))
			var rm := ring.material_override as ShaderMaterial
			rm.set_shader_parameter("color", ELITE_RING)
			rm.set_shader_parameter("hot", ELITE_RING_HOT)
			rm.set_shader_parameter("energy", 1.1)
			ring.position.y = 0.035
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
	if (_knight or _shield_knight) and big and _attack < 0.0:
		_hit_anim = 0.0


func die() -> void:
	_dying = 0.0
	if _bar:
		_bar.visible = false
	if _knight:
		_knight.play("death", 1.0)
	if _shield_knight:
		_shield_knight.play("death", 1.0)
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
	_vel = _vel.lerp(Vector3(p.x - _last_pos.x, 0.0, p.z - _last_pos.z) / maxf(delta, 0.001), 1.0 - exp(-10.0 * delta))
	_last_pos = p
	# 비탈 아래에서 올라오는 중이면 바깥쪽 아래에서 시작한다
	if _rise < 1.0:
		_rise = minf(1.0, _rise + delta / rise_time)
		var k: float = 1.0 - pow(1.0 - _rise, 2.0)
		var q: Vector3 = p + _out_dir * rise_from * (1.0 - k)
		p = _ground(q)
		if enemy.data.wraith and _knight == null:
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
	if not parts.is_empty():
		_animate_new(delta)
	elif _knight:
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
	if enemy.data.model_scale > 0.0 or enemy.data.swing_arc > 0.0:
		_rust_pose(delta)
	_paint()
	_paint_eyes(delta)
	_draw_bar(delta)
	return false


# ---------------------------------------------------------------- 체력 막대(2026-11-21)

## 막대를 달 적인지: 보스·우두머리는 화면 아래 큰 막대가 있고, 허수아비는 수련장 위 줄이 있다.
static func wants_bar(e: Enemy) -> bool:
	return not e.data.boss and e.chief == &"" and e.data.acts() != &"dummy" and e.max_hp < 9999.0


## 체력 몫(0~1)과 깎인 몫(0~1)으로 막대를 그린다. 깎이면 다시 보이고, bar_show초 지나면 옅어져 사라진다.
func _draw_bar(delta: float) -> void:
	if not wants_bar(enemy) or enemy.max_hp <= 0.0:
		return
	if _bar_hp < 0.0:
		_bar_hp = enemy.hp
	if enemy.hp < _bar_hp - 0.001:
		if _bar == null:
			_make_bar()
		_bar_t = 0.0
	_bar_hp = enemy.hp
	if _bar == null or _bar_t < 0.0:
		return
	_bar_t += delta
	if _bar_t > bar_show + bar_fade:
		_bar_t = -1.0
		_bar.visible = false
		return
	_bar.visible = true
	var k: float = clampf(enemy.hp / enemy.max_hp, 0.0, 1.0)
	_lag_k = maxf(k, move_toward(_lag_k, k, delta * bar_lag_speed) if _bar_t > 0.25 else _lag_k)
	_bar_mat.set_shader_parameter("k", k)
	_bar_mat.set_shader_parameter("lag", _lag_k)
	_bar_mat.set_shader_parameter("alpha", 1.0 - clampf((_bar_t - bar_show) / bar_fade, 0.0, 1.0))
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam:
		_bar.global_basis = cam.global_basis


## 판 하나에 셰이더(enemy_bar.gdshader)로 그린다(2026-11-25 "막대는 좀 이쁘게"): 놋쇠 실선·마름모 마개·결 있는 채움.
func _make_bar() -> void:
	_bar_w = clampf(Grid.cells_to_meters(enemy.radius) * 2.4, 0.7, 1.6)
	_bar = Node3D.new()
	_bar.position = Vector3(0.0, _height + 0.4, 0.0)
	add_child(_bar)
	var size := Vector2(_bar_w + 0.17, 0.2)
	_bar_mat = ShaderMaterial.new()
	_bar_mat.shader = BAR_SHADER
	_bar_mat.render_priority = 10
	_bar_mat.set_shader_parameter("size", size)
	if enemy.elite:   # 정예: 호박빛
		_bar_mat.set_shader_parameter("top", Color(0.86, 0.58, 0.18))
		_bar_mat.set_shader_parameter("bottom", Color(0.42, 0.2, 0.04))
	var q := QuadMesh.new()
	q.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = _bar_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bar.add_child(mi)


func _draw_death(delta: float) -> bool:
	_dying += delta
	var k: float = _dying / die_time
	# 터진 자폭병은 바로 사라진다(폭발은 EnemyFx가 그린다)
	if enemy.act == &"explode":
		visible = false
		return true
	if not parts.is_empty() and not _cloaks.is_empty():
		# 두건 쓴 새 적(활잡이, 부르는 자): 망령처럼 흩어지며 위로, 활·지팡이·등불도 같이 오그라든다
		var root := parts.get("root") as Node3D
		if root:
			root.scale = Vector3.ONE * float(parts.get("scale", 1.0)) * clampf(1.4 - k, 0.0, 1.0)
		var light := parts.get("light") as OmniLight3D
		if light:
			light.light_energy *= clampf(1.0 - k, 0.0, 1.0)
	if not _cloaks.is_empty():
		# 망령: 흩어지며 위로
		for c in _cloaks:
			c.set_shader_parameter("fade", clampf(1.0 - k, 0.0, 1.0))
		for e in _eyes_list():
			e.visible = k < 0.4
		_body.position.y += delta * 1.2
		return k >= 1.3
	var kn: LordCharacter = _knight if _knight else _shield_knight
	if kn:
		# 기사: 쓰러지는 동작을 보고 나서 땅으로 가라앉는다
		var fall: float = minf(2.2, kn.length("death"))
		if _dying > fall:
			_body.position.y -= delta * 1.5
		if _eyes:
			_eyes.visible = _dying < fall * 0.6
		elif _shield_knight:
			for e in _eyes_list():
				e.visible = _dying < fall * 0.6
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


## 공격 표를 든 적은 눈이 더 밝고 조금 크다. 때리기 직전(attack_soon)에는 더 번쩍인다. 누가 덤빌지 보이게.
## 기다리는 적은 그대로(어둠 속의 작은 눈).
func _paint_eyes(delta: float) -> void:
	# 기사 모델은 첫 프레임에 눈을 머리 앞에 맞춘 뒤의 크기를 바탕으로 삼는다
	if _eye_nodes.is_empty() and (_knight == null or _eyes_placed):
		for n in _eyes_list():
			_eye_nodes.append(n)
			_eye_scale.append(n.scale)
	_token_glow = lerpf(_token_glow, 1.0 if enemy.token > 0 else 0.0, 1.0 - exp(-10.0 * delta))
	_soon_glow = lerpf(_soon_glow, 1.0 if enemy.attack_soon else 0.0, 1.0 - exp(-30.0 * delta))
	var bright: float = lerpf(lerpf(1.0, token_eye_bright, _token_glow), soon_eye_bright, _soon_glow)
	var size: float = lerpf(lerpf(1.0, token_eye_size, _token_glow), soon_eye_size, _soon_glow)
	for i in _eye_mats.size():
		var c: Color = _eye_base[i]
		# 번쩍일 때는 흰빛으로 조금 기운다
		c = c.lerp(Color.WHITE, 0.3 * _soon_glow)
		_eye_mats[i].albedo_color = Color(c.r * bright, c.g * bright, c.b * bright, 1.0)
		_eye_mats[i].emission = _eye_mats[i].albedo_color
	for i in _eye_nodes.size():
		_eye_nodes[i].scale = _eye_scale[i] * size


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
	_eye_mats.append(m)
	_eye_base.append(m.albedo_color)
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

func _build_future(kind: StringName, grow: float, c: Color) -> void:
	var f: Dictionary = PastEnemyArt.build(kind, _body, grow, c) if enemy.data.past else FutureEnemyArt.build(kind, _body, grow, c)
	_height = float(f.height) * grow
	_arm_pivot = f.get("arm") as Node3D   # 금고지기: 빛 칼 든 오른팔(_rust_pose가 돌린다)
	for m in f.mats:
		_mats.append(m)
		_base.append(m.albedo_color)
	for mi in f.eyes:
		var em := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if enemy.elite:
			em.albedo_color = Color(1.0, 0.8, 0.35)
			em.emission = em.albedo_color
		_eye_mats.append(em)
		_eye_base.append(em.albedo_color)


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

## own: 이 적만의 모델 파일(24단계). 비면 영주 기사 모델을 어둡게 칠해 쓴다.
func _build_knight(grow: float, c: Color, boss: bool, own: String = "") -> void:
	_knight = LordCharacter.new()
	if own != "":
		_knight.char_path = own
	_body.add_child(_knight)
	var rust: bool = enemy.data.model_scale > 0.0   # 무덤 기사: 녹슨 빛, 큰 칼
	var kind: StringName = enemy.data.acts()
	var chief: bool = enemy.data.kind != &""   # 32단계 우두머리: 제 표의 색을 더 짙게 얹는다
	var big: bool = kind in [&"giant", &"boss"] or rust
	_knight_scale = (enemy.data.model_scale if rust else (2.5 if boss else (1.85 if big else 1.0))) * grow
	_knight.scale = Vector3.ONE * _knight_scale
	_height = 1.8 * _knight_scale
	var mul: Color = c if rust else (Color(0.3, 0.1, 0.1) if boss else Color(0.4, 0.4, 0.42).lerp(c, 0.45 if chief else 0.15))
	if not big and not rust and own == "":
		# 사람형 적(활잡이·돌격병·자폭병·부르는 자): 표의 색을 더 짙게 얹어 서로 구별한다
		mul = Color(0.45, 0.44, 0.44).lerp(c, 0.4)
	if own != "":
		# 제 모델은 제 질감을 살려 조금만 어둡게
		mul = Color(0.8, 0.78, 0.76).lerp(c, 0.35 if chief else 0.1) if not boss else Color(0.7, 0.55, 0.55)
	var mats := _knight.recolor(mul, Color(0.55, 0.22, 0.05) if rust else (Color(0.6, 0.06, 0.02) if boss else Color.BLACK), 0.1 if (boss or rust) else 0.0)
	for m in mats:
		_mats.append(m)
		_base.append(m.albedo_color)
	if kind == &"archer" or kind == &"caller":
		# 활잡이는 왼손에 활, 부르는 자는 오른손에 지팡이(손에서 위로 세운다)
		var mi := MeshInstance3D.new()
		mi.mesh = EnemyArt.bow_mesh() if kind == &"archer" else EnemyArt.staff_mesh()
		mi.transform = Transform3D(Basis(Vector3(0, 0, 1), -PI / 2.0), Vector3.ZERO)
		if kind == &"caller":
			mi.position = Vector3(-1.0, 0.0, 0.0)   # 지팡이 1m쯤을 쥔다
		_knight.grip_node("mixamorig_LeftHand" if kind == &"archer" else "mixamorig_RightHand", mi)
	else:
		var sword := SwordModel.make(null, 0, 4000 + enemy.id, Color.WHITE)
		if rust:
			sword.scale = Vector3.ONE * rust_sword
		_knight.hold(sword)
	# 투구 안의 눈. 뼈의 방향이 모델마다 달라서 첫 프레임에 머리 앞에 맞춘다(_place_eyes)
	_eyes = Node3D.new()
	_knight.attach("mixamorig_Head", _eyes)
	_eyes_at(_eyes, Vector3.ZERO, 0.035, 0.022, Color(1.0, 0.35, 0.15) if boss or chief else Color(0.7, 0.85, 1.0))
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
			_knight.play("slash", 0.85, -0.12)
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
	if boss and enemy.data.model_scale <= 0.0:
		var horn := CylinderMesh.new()
		horn.top_radius = 0.0
		horn.bottom_radius = r * 0.12
		horn.height = r * 0.8
		var hm := _mat(Color(0.1, 0.02, 0.03))
		_add(_body, horn, hm, Vector3(-r * 0.3, r * 4.5, 0), Vector3(0, 0, 0.5))
		_add(_body, horn, hm, Vector3(r * 0.3, r * 4.5, 0), Vector3(0, 0, -0.5))
	_eyes_at(_body, Vector3(0, r * 4.05, -r * 0.48), r * 0.15, r * 0.07, Color(1.0, 0.8, 0.35) if boss or enemy.data.kind != &"" else Color(0.75, 0.9, 1.0))
	if enemy.data.model_scale > 0.0:
		# 무덤 기사: 녹슨 도형 몸에 큰 칼을 든 오른팔(어깨에서 돌린다)
		_arm_pivot = Node3D.new()
		_arm_pivot.position = Vector3(r * 1.0, r * 3.2, 0.0)
		_body.add_child(_arm_pivot)
		var sword := SwordModel.make(null, 0, 4000 + enemy.id, Color.WHITE)
		sword.scale = Vector3.ONE * rust_sword * enemy.data.model_scale * 0.7
		sword.position = Vector3(0.0, -r * 0.2, 0.0)
		_arm_pivot.add_child(sword)
		_arm_pivot.rotation = Vector3(-2.2, 0.0, 0.0)


## 무덤 기사형(언덕지기·무덤 기사·무덤 주인)의 행동에 맞춘 몸 기울임: 휘두르기 예고에는 뒤로 젖히고(칼을 들어 올린다), 돌진 준비와 돌진에는 숙인다.
## 기사 모델에는 몸만, 도형에는 칼 든 팔도 돌린다(내려치는 순간 옆에서 앞으로 쓸어낸다).
## 보스 패턴(docs/boss_patterns.md): 내려찍기는 크게 젖혔다가 숙이고, 칼비는 칼을 하늘로 세우고, 땅 가르기는 낮게 숙여 칼을 뒤로 끌고,
## 그림자 걸음은 땅으로 꺼졌다가(_sink) 나온 자리에서 솟는다.
func _rust_pose(delta: float) -> void:
	var want: float = 0.0
	var arm := Vector3(-2.2, 0.0, 0.0)
	var k: float = clampf(enemy.act_t / maxf(enemy.act_time, 0.01), 0.0, 1.0)
	var sink: float = 0.0
	match enemy.act:
		&"slam_wind":
			want = rust_lean * 1.4 * k
			arm = Vector3(lerpf(-2.2, 1.0, k), 0.0, 0.0)
		&"slam":
			want = -rust_lean * 1.3
			arm = Vector3(-2.7, 0.0, 0.0)
		&"rain_wind":
			want = rust_lean * 0.9 * k
			arm = Vector3(lerpf(-2.2, 1.35, k), lerpf(0.0, 0.2, k), 0.0)
		&"rain":
			want = rust_lean * 0.5
			arm = Vector3(1.2, 0.0, 0.0)
		&"cleave_wind":
			want = -rust_lean * 0.7 * k
			arm = Vector3(lerpf(-2.2, -3.0, k), lerpf(0.0, -1.1, k), 0.0)
		&"cleave":
			want = -rust_lean * 1.0
			arm = Vector3(-1.2, 1.3, 0.0)
		&"blink_wind":
			sink = k
		&"swing_wind":
			want = rust_lean * k
			arm = Vector3(lerpf(-2.2, 0.7, k), lerpf(0.0, 1.3, k), 0.0)
		&"swing":
			var q: float = clampf(enemy.act_t * rust_swing_rate / 3.0, 0.0, 1.0)
			want = -rust_lean * 0.5
			arm = Vector3(lerpf(0.7, -2.0, q), lerpf(1.3, -1.3, q), 0.0)
		&"wind":
			want = -rust_lean * 0.8
		&"charge":
			want = -rust_lean * 1.3
		&"charge_end":
			want = rust_lean * 0.3
	_lean = lerpf(_lean, want, 1.0 - exp(-12.0 * delta))
	_body.rotation.x += _lean
	_sink = lerpf(_sink, sink, 1.0 - exp(-(16.0 if sink > _sink else 9.0) * delta))
	_body.position.y = -_height * 1.1 * _sink
	if _arm_pivot:
		_arm_pivot.rotation = _arm_pivot.rotation.lerp(arm, 1.0 - exp(-16.0 * delta))


# ---------------------------------------------------------------- 11단계 새 적 5종(EnemyArt + EnemyMotion)

func _build_new(kind: StringName, grow: float, c: Color) -> void:
	parts = EnemyArt.build(kind, _body, grow, c)
	_motion = EnemyMotion.rest(parts)
	_height = float(parts.get("height", 2.0))
	_shield_knight = parts.get("knight") as LordCharacter
	for m in parts.get("mats", []):
		var sm := m as StandardMaterial3D
		if sm:
			_mats.append(sm)
			_base.append(sm.albedo_color)
	for c2 in parts.get("cloaks", []):
		_cloaks.append(c2 as ShaderMaterial)
	# 눈: 짝마다 재질 하나. 정예는 금빛
	for mi in parts.get("eyes", []):
		var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if m == null or _eye_mats.has(m):
			continue
		if enemy.elite:
			m.albedo_color = Color(1.0, 0.8, 0.35)
			m.emission = m.albedo_color
		_eye_mats.append(m)
		_eye_base.append(m.albedo_color)


func _animate_new(delta: float) -> void:
	var fwd := Vector3(-sin(_yaw), 0.0, -cos(_yaw))
	var right := Vector3(cos(_yaw), 0.0, -sin(_yaw))
	var act: StringName = enemy.act
	if act == &"" and enemy.waiting and enemy.token <= 0:
		act = &"wait"
	if _attack > 1.5:
		_attack = -1.0
	if _hit_anim >= 0.0:
		_hit_anim += delta
		if _hit_anim > 0.6:
			_hit_anim = -1.0
	var state := {
		"act": act,
		"act_t": enemy.act_t,
		"act_time": enemy.act_time,
		"speed": _speed_m,
		"side": _vel.dot(right),
		"backing": _vel.dot(fwd) < -0.2,
		"t": _t,
		"guard": enemy.guard_down <= 0.0 and enemy.act != &"guard_break",
		"stunned": enemy.stun > 0.0,
		"id": enemy.id,
		"recoil": _recoil,
		"attack": _attack,
		"hit": _hit_anim,
	}
	EnemyMotion.animate(parts, _motion, enemy.data.acts(), state, delta)
	# 나타날 때: 두건 쓴 적은 연기처럼 맺힌다
	if not _cloaks.is_empty():
		for c in _cloaks:
			c.set_shader_parameter("fade", _rise)
