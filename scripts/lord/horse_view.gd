class_name HorseView
extends Node3D
## 39단계 말의 몸(docs/open_world2.md). 규칙은 Rules.horse(Horse)와 lord.riding이고, 이 노드는 그리기만 한다.
## 코드로 만든 어두운 말: 몸통·목·머리·갈기·꼬리·네 다리(무릎과 발굽), 안장·안장 깔개·고삐. 늑대(EnemyView)처럼 CreatureMesh.loft로 다듬는다.
## 걸음은 빠르기로 섞는다: 느리면 네 박자 걷기(뒤왼·앞왼·뒤오·앞오), 빠르면 달리기(뒤 둘이 붙고 앞 둘이 붙는다). 달릴 때 몸이 오르내리고 앞뒤로 흔들린다.
## 발굽이 땅에 닿을 때 footfall(자리, 달리는 정도 0~1)을 낸다(장면이 발굽 소리를 낸다). 빠르면 흙먼지. 서 있으면 숨 쉬듯 조금 움직인다.
## 영주 화면(LordView)이 seat_height·seat_pitch·seat_yaw로 안장 위에 앉는다. 모델은 -Z를 본다.

signal footfall(at: Vector3, k: float)

## 걸음 한 바퀴에 나아가는 거리(m): 걷기와 달리기.
@export var walk_stride: float = 1.7
@export var run_stride: float = 3.6
## 이 빠르기(m/s)에서 다 달리는 걸음이 된다.
@export var run_speed: float = 6.5
## 몸이 도는 빠르기(라디안/초, 그리기만).
@export var turn_speed: float = 9.0
## 안장 윗면 높이(m, 땅 위).
@export var seat: float = 1.56

var rules: Rules
## (x, z) → 땅 높이(m). 들판이 FieldBuilder.walk_height를 넣는다.
var height_of: Callable

var _body: Node3D
var _neck: Node3D
var _head: Node3D
var _tail: Node3D
var _hips: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _dust: CPUParticles3D
var _gait: float = 0.0
var _t: float = 0.0
var _yaw_now: float = 0.0
var _speed_m: float = 0.0
var _bob: float = 0.0
var _pitch: float = 0.0
var _down: Array[bool] = [true, true, true, true]
var _shown: bool = false

## 다리 넷: 엉덩이(어깨) 자리, 위 다리 길이, 아래 다리 길이, 위 다리 기본 각, 무릎 기본 각. 0 앞왼, 1 앞오, 2 뒤왼, 3 뒤오.
const LEGS: Array = [
	[Vector3(-0.15, 1.0, -0.55), 0.46, 0.52, 0.0, 0.0],
	[Vector3(0.15, 1.0, -0.55), 0.46, 0.52, 0.0, 0.0],
	[Vector3(-0.16, 1.06, 0.62), 0.48, 0.56, 0.28, -0.5],
	[Vector3(0.16, 1.06, 0.62), 0.48, 0.56, 0.28, -0.5],
]
## 걸음 한 바퀴(0~1) 안에서 다리마다 땅을 차고 나가는 때: 걷기(네 박자)와 달리기.
const WALK_PHASE: Array = [0.25, 0.75, 0.0, 0.5]
const RUN_PHASE: Array = [0.5, 0.6, 0.0, 0.1]


func setup(r: Rules) -> void:
	rules = r
	_build()
	visible = false


## 안장 윗면 높이(m, 이 노드의 땅 기준). 달리면 몸과 같이 오르내린다.
func seat_height() -> float:
	return seat + _bob


## 몸의 앞뒤 기울기(라디안, 앞이 들리면 +).
func seat_pitch() -> float:
	return _pitch


## 말이 보는 쪽(세계 yaw, 라디안).
func seat_yaw() -> float:
	return _yaw_now


func draw(alpha: float, delta: float) -> void:
	if rules == null:
		return
	var h: Horse = rules.horse
	visible = h.present()
	if not visible:
		_shown = false
		return
	_t += delta
	var p: Vector2 = h.prev_pos.lerp(h.pos, alpha)
	var w: Vector3 = Grid.cells_to_world(p)
	w.y = height_of.call(w.x, w.z) if height_of.is_valid() else 0.0
	position = w
	var want: float = atan2(-cos(h.face), -sin(h.face))
	if not _shown:
		_yaw_now = want
		_shown = true
	_yaw_now = lerp_angle(_yaw_now, want, 1.0 - exp(-turn_speed * delta))
	rotation.y = _yaw_now
	_speed_m = move_toward(_speed_m, h.speed * Grid.CELL, 30.0 * delta)
	if rules.lord.riding and rules.lord.air > 0.0:   # 도약: 몸을 띄우고 앞을 든다
		var up: float = LordState.arc(rules.lord.air, rules.data.horse.leap_time, rules.data.horse.leap_height)
		_body.position.y = up
	else:
		_body.position.y = 0.0
	_animate(delta)


func _animate(delta: float) -> void:
	var run: float = clampf(_speed_m / run_speed, 0.0, 1.0)
	var moving: float = clampf(_speed_m / 1.2, 0.0, 1.0)
	var stride: float = lerpf(walk_stride, run_stride, run)
	_gait += _speed_m * delta / stride
	var swing: float = lerpf(0.38, 0.8, run) * moving
	for i in 4:
		var ph: float = TAU * (_gait + lerpf(float(WALK_PHASE[i]), float(RUN_PHASE[i]), run))
		var L: Array = LEGS[i]
		var hind: bool = i >= 2
		_hips[i].rotation.x = float(L[3]) + sin(ph) * swing
		# 앞으로 내밀 때(sin이 커질 때) 무릎을 접어 발굽을 든다
		var lift: float = maxf(0.0, cos(ph)) * lerpf(0.7, 1.3, run) * moving
		_knees[i].rotation.x = float(L[4]) + (lift if not hind else -lift * 0.7)
		var down: bool = cos(ph) < -0.2 or moving < 0.05
		if down and not _down[i] and moving > 0.05:
			var at: Vector3 = global_transform * ((_hips[i].get_parent() as Node3D).position * Vector3(1, 0, 1))
			footfall.emit(at, run)
		_down[i] = down
	# 달리면 몸이 두 번 오르내리고 앞뒤로 흔들린다. 서 있으면 숨.
	var breath: float = sin(_t * 1.6) * 0.012 * (1.0 - moving)
	_bob = absf(sin(TAU * _gait)) * lerpf(0.025, 0.09, run) * moving + breath
	_pitch = sin(TAU * _gait + 0.6) * lerpf(0.015, 0.07, run) * moving
	_body.rotation.x = _pitch
	_body.position.y += _bob
	_neck.rotation.x = -0.12 * run + sin(TAU * _gait * 2.0) * 0.05 * moving + sin(_t * 0.7) * 0.03 * (1.0 - moving)
	_head.rotation.x = 0.1 * run + sin(_t * 0.9 + 1.0) * 0.04 * (1.0 - moving)
	_tail.rotation.x = 0.15 + run * 0.7 + sin(_t * 2.3) * 0.06
	_tail.rotation.z = sin(_t * 1.7) * 0.12 * (1.0 - run)
	_dust.emitting = run > 0.45


# ---------------------------------------------------------------- 몸 만들기

func _build() -> void:
	var coat := CreatureMesh.fur(Color(0.075, 0.058, 0.048), Color(0.02, 0.016, 0.014))
	var hair := CreatureMesh.fur(Color(0.025, 0.022, 0.02), Color(0.01, 0.01, 0.01))
	var hoof := _mat(Color(0.04, 0.035, 0.03), 0.5)
	var leather := _mat(Color(0.11, 0.065, 0.035), 0.55)
	var cloth := _mat(Color(0.16, 0.04, 0.035), 0.9)
	var iron := _mat(Color(0.25, 0.24, 0.23), 0.4, 0.8)
	_body = Node3D.new()
	add_child(_body)
	# 몸통: 엉덩이가 둥글고 가슴이 깊다
	_add(_body, CreatureMesh.loft([
		[Vector3(0, 1.2, 0.97), 0.1, 0.1],
		[Vector3(0, 1.22, 0.86), 0.25, 0.3],
		[Vector3(0, 1.22, 0.6), 0.3, 0.36],
		[Vector3(0, 1.16, 0.25), 0.29, 0.36],
		[Vector3(0, 1.13, -0.12), 0.3, 0.39],
		[Vector3(0, 1.16, -0.46), 0.28, 0.4],
		[Vector3(0, 1.24, -0.72), 0.21, 0.33],
		[Vector3(0, 1.36, -0.86), 0.13, 0.2],
	], 16, 0.12), coat)
	# 목(어깨 앞에서 위·앞으로), 갈기, 머리
	_neck = Node3D.new()
	_neck.position = Vector3(0, 1.38, -0.78)
	_body.add_child(_neck)
	_add(_neck, CreatureMesh.loft([
		[Vector3(0, -0.06, 0.06), 0.15, 0.22],
		[Vector3(0, 0.26, -0.16), 0.11, 0.18],
		[Vector3(0, 0.5, -0.31), 0.09, 0.14],
		[Vector3(0, 0.66, -0.4), 0.08, 0.11],
	], 12, 0.1), coat)
	_add(_neck, CreatureMesh.loft([
		[Vector3(0, 0.12, 0.12), 0.03, 0.05],
		[Vector3(0, 0.4, -0.06), 0.04, 0.09],
		[Vector3(0, 0.64, -0.24), 0.035, 0.08],
		[Vector3(0, 0.8, -0.36), 0.02, 0.05],
	], 6, 0.0), hair)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.68, -0.42)
	_neck.add_child(_head)
	_add(_head, CreatureMesh.loft([
		[Vector3(0, 0.06, 0.06), 0.075, 0.09],
		[Vector3(0, 0.02, -0.08), 0.09, 0.12],
		[Vector3(0, -0.1, -0.28), 0.07, 0.085],
		[Vector3(0, -0.2, -0.44), 0.058, 0.065],
		[Vector3(0, -0.24, -0.53), 0.048, 0.05],
	], 12, 0.1), coat)
	var ear := CylinderMesh.new()
	ear.top_radius = 0.0
	ear.bottom_radius = 0.032
	ear.height = 0.13
	ear.radial_segments = 6
	for side in [-1.0, 1.0]:
		_add(_head, ear, coat, Vector3(0.05 * side, 0.15, 0.02), Vector3(-0.25, 0, -0.2 * side))
		var eye := SphereMesh.new()
		eye.radius = 0.018
		eye.height = 0.03
		_add(_head, eye, hoof, Vector3(0.082 * side, 0.03, -0.12))
	# 앞머리 갈기 한 줌
	_add(_head, CreatureMesh.loft([[Vector3(0, 0.12, 0.04), 0.03, 0.02], [Vector3(0, 0.06, -0.1), 0.03, 0.02], [Vector3(0, 0.0, -0.16), 0.01, 0.01]], 6, 0.0), hair)
	# 굴레와 재갈, 고삐(목 아래로 늘어져 안장 앞에 닿는다: 목 노드에 붙어 같이 움직인다)
	var strap := BoxMesh.new()
	strap.size = Vector3(0.2, 0.025, 0.025)
	_add(_head, strap, leather, Vector3(0, -0.12, -0.36), Vector3(0.0, 0.0, 0.0))
	_add(_head, strap, leather, Vector3(0, 0.08, -0.06))
	var bit := SphereMesh.new()
	bit.radius = 0.02
	bit.height = 0.04
	for side in [-1.0, 1.0]:
		_add(_head, bit, iron, Vector3(0.06 * side, -0.2, -0.42))
		_rein(_neck, Vector3(0.07 * side, 0.48, -0.84), Vector3(0.12 * side, -0.02, 0.62), leather)
	# 꼬리
	_tail = Node3D.new()
	_tail.position = Vector3(0, 1.24, 0.95)
	_body.add_child(_tail)
	_add(_tail, CreatureMesh.loft([
		[Vector3(0, 0, 0), 0.05, 0.06],
		[Vector3(0, -0.12, 0.12), 0.08, 0.09],
		[Vector3(0, -0.42, 0.2), 0.085, 0.08],
		[Vector3(0, -0.72, 0.22), 0.055, 0.05],
		[Vector3(0, -0.92, 0.2), 0.012, 0.012],
	], 10, 0.0), hair)
	# 안장 깔개, 안장(앞뒤가 솟은 모양), 등자
	var pad := BoxMesh.new()
	pad.size = Vector3(0.66, 0.025, 0.62)
	_add(_body, pad, cloth, Vector3(0, 1.5, -0.08))
	_add(_body, CreatureMesh.loft([
		[Vector3(0, 1.56, 0.24), 0.2, 0.07],
		[Vector3(0, 1.53, 0.12), 0.21, 0.05],
		[Vector3(0, 1.52, -0.1), 0.19, 0.045],
		[Vector3(0, 1.54, -0.28), 0.17, 0.06],
		[Vector3(0, 1.6, -0.36), 0.08, 0.06],
	], 12, 0.3), leather)
	var stir := TorusMesh.new()
	stir.inner_radius = 0.035
	stir.outer_radius = 0.05
	for side in [-1.0, 1.0]:
		var drop := BoxMesh.new()
		drop.size = Vector3(0.02, 0.5, 0.03)
		_add(_body, drop, leather, Vector3(0.31 * side, 1.25, -0.1))
		_add(_body, stir, iron, Vector3(0.32 * side, 0.98, -0.1), Vector3(0, 0, PI / 2.0))
	# 다리: 엉덩이(어깨)와 무릎, 아래 끝에 발굽
	for L in LEGS:
		var hip := Node3D.new()
		hip.position = L[0]
		_body.add_child(hip)
		var top: float = float(L[1])
		var low: float = float(L[2])
		var hind: bool = float(L[0].z) > 0.0
		var up_node := Node3D.new()
		up_node.rotation.x = float(L[3])
		hip.add_child(up_node)
		_add(up_node, CreatureMesh.loft([
			[Vector3(0, 0.1, 0.0), 0.1, 0.16 if hind else 0.12],
			[Vector3(0, -top * 0.45, 0.02 if hind else 0.0), 0.085, 0.11],
			[Vector3(0, -top, 0), 0.05, 0.06],
		], 8, 0.0), coat)
		var knee := Node3D.new()
		knee.position = Vector3(0, -top, 0)
		knee.rotation.x = float(L[4])
		up_node.add_child(knee)
		_add(knee, CreatureMesh.loft([
			[Vector3(0, 0, 0), 0.05, 0.06],
			[Vector3(0, -low * 0.75, 0), 0.034, 0.04],
			[Vector3(0, -low * 0.9, -0.01), 0.045, 0.05],
		], 8, 0.0), coat)
		var hf := CylinderMesh.new()
		hf.top_radius = 0.045
		hf.bottom_radius = 0.06
		hf.height = 0.08
		hf.radial_segments = 10
		_add(knee, hf, hoof, Vector3(0, -low + 0.03, -0.015))
		_hips.append(up_node)
		_knees.append(knee)
	# 흙먼지(달릴 때 발굽 뒤로)
	_dust = CPUParticles3D.new()
	_dust.amount = 26
	_dust.lifetime = 0.9
	_dust.emitting = false
	_dust.local_coords = false
	_dust.position = Vector3(0, 0.08, 0.35)
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(0.3, 0.02, 0.6)
	_dust.direction = Vector3(0, 0.5, 1.0)
	_dust.spread = 35.0
	_dust.initial_velocity_min = 0.4
	_dust.initial_velocity_max = 1.2
	_dust.gravity = Vector3(0, -0.6, 0)
	_dust.scale_amount_min = 0.6
	_dust.scale_amount_max = 1.6
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	fade.colors = PackedColorArray([Color(0.3, 0.25, 0.19, 0.0), Color(0.3, 0.25, 0.19, 0.35), Color(0.3, 0.25, 0.19, 0.0)])
	_dust.color_ramp = fade
	var q := QuadMesh.new()
	q.size = Vector2(0.35, 0.35)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.vertex_color_use_as_albedo = true
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_texture = HitFx._soft_dot()
	q.material = dm
	_dust.mesh = q
	_body.add_child(_dust)


## 고삐 한 줄: 재갈 근처(a)에서 안장 앞(a + d)까지 가는 끈(목 노드 기준).
func _rein(parent: Node3D, a: Vector3, d: Vector3, m: Material) -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.008
	c.bottom_radius = 0.008
	c.height = d.length()
	c.radial_segments = 4
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = m
	parent.add_child(mi)
	mi.position = a + d * 0.5
	var y: Vector3 = d.normalized()
	var x: Vector3 = y.cross(Vector3.FORWARD).normalized() if absf(y.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
	mi.basis = Basis(x, y, x.cross(y))


func _add(parent: Node3D, mesh: Mesh, m: Material, at: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func _mat(c: Color, rough: float, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m
