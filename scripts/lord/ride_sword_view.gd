class_name RideSwordView
extends Node3D
## 탈 검(2026-11-21 사용자: "말 없애고 탈 수 있는 검"). 규칙은 39단계 말 그대로(Rules.horse = Horse, HorseData, lord.riding)이고
## 이 노드가 말 대신 그린다: 언덕의 옛 대검 한 자루가 땅 위에 낮게 누워 떠 있고, 영주는 그 칼 넓은 면에 선다.
## HorseView와 같은 물음(seat_height·seat_pitch·seat_yaw·stands)을 받는다. stands()가 true라 LordView는 다리를 벌리지 않고 선 채로 탄다.
## 서 있으면 숨 쉬듯 오르내리고, 돌면 안쪽으로 기울고, 빠르면 칼끝이 조금 들리며 뒤로 재·흙먼지가 끌린다. 모델은 -Z를 본다.

## 떠 있는 높이(m, 땅에서 칼 넓은 면까지).
@export var hover: float = 0.42
## 대검 크기 배수(사람 키를 받칠 만큼).
@export var size: float = 2.3
## 도는 빠르기(라디안/초, 그리기만).
@export var turn_speed: float = 8.0
## 이 빠르기(m/s)에서 다 빠른 자세(칼끝 들림·먼지).
@export var run_speed: float = 6.5

## HorseView와 같은 신호(발소리). 탈 검은 발이 없어 내지 않는다.
signal footfall(at: Vector3, k: float)

var rules: Rules
## (x, z) → 땅 높이(m). 들판이 FieldBuilder.walk_height를 넣는다.
var height_of: Callable

var _body: Node3D
var _dust: CPUParticles3D
var _t: float = 0.0
var _yaw_now: float = 0.0
var _turn: float = 0.0
var _speed_m: float = 0.0
var _bob: float = 0.0
var _pitch: float = 0.0
var _shown: bool = false


func setup(r: Rules) -> void:
	rules = r
	_build()
	visible = false


## 영주가 서는 높이(m, 땅 기준): 칼 넓은 면.
func seat_height() -> float:
	return hover + _bob + 0.04


func seat_pitch() -> float:
	return _pitch


func seat_yaw() -> float:
	return _yaw_now


## 탈 검은 서서 탄다(LordView가 다리를 벌려 앉히지 않는다).
func stands() -> bool:
	return true


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
	var before: float = _yaw_now
	_yaw_now = lerp_angle(_yaw_now, want, 1.0 - exp(-turn_speed * delta))
	rotation.y = _yaw_now
	var spin: float = angle_difference(before, _yaw_now) / maxf(delta, 0.001)
	_turn = lerpf(_turn, clampf(spin * 0.12, -0.35, 0.35), 1.0 - exp(-6.0 * delta))
	_speed_m = move_toward(_speed_m, h.speed * Grid.CELL, 30.0 * delta)
	var run: float = clampf(_speed_m / run_speed, 0.0, 1.0)
	var up: float = 0.0
	if rules.lord.riding and rules.lord.air > 0.0:   # 도약: 칼이 영주와 같이 뜬다
		up = LordState.arc(rules.lord.air, rules.data.horse.leap_time, rules.data.horse.leap_height)
	_bob = sin(_t * 2.1) * lerpf(0.03, 0.012, run) + up
	_pitch = run * 0.06
	_body.position.y = hover + _bob
	_body.rotation = Vector3(_pitch, 0.0, -_turn)
	_dust.emitting = run > 0.35


func _build() -> void:
	_body = Node3D.new()
	add_child(_body)
	var forms: Array[FormData] = rules.data.forms
	var great: FormData = forms[2] if forms.size() > 2 else null
	var m := SwordModel.make(great, 0, 7331, Color.WHITE)
	# 칼날이 앞(-Z)으로, 넓은 면이 위로 눕는다. 자루가 영주 발뒤꿈치 뒤로 나온다
	m.rotation.x = -PI * 0.5
	m.scale = Vector3.ONE * size
	m.position = Vector3(0.0, 0.0, (m.grip_length + 0.1) * size)
	_body.add_child(m)
	for n in m.find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# 칼 아래로 끌리는 재와 흙먼지(빠를 때)
	_dust = CPUParticles3D.new()
	_dust.amount = 30
	_dust.lifetime = 0.9
	_dust.emitting = false
	_dust.local_coords = false
	_dust.position = Vector3(0, -hover + 0.05, 0.6)
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(0.25, 0.02, 0.9)
	_dust.direction = Vector3(0, 0.6, 1.0)
	_dust.spread = 30.0
	_dust.initial_velocity_min = 0.4
	_dust.initial_velocity_max = 1.3
	_dust.gravity = Vector3(0, -0.5, 0)
	_dust.scale_amount_min = 0.6
	_dust.scale_amount_max = 1.5
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	fade.colors = PackedColorArray([Color(0.32, 0.29, 0.25, 0.0), Color(0.32, 0.29, 0.25, 0.35), Color(0.3, 0.27, 0.23, 0.0)])
	_dust.color_ramp = fade
	var q := QuadMesh.new()
	q.size = Vector2(0.32, 0.32)
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dm.vertex_color_use_as_albedo = true
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_texture = HitFx._soft_dot()
	q.material = dm
	_dust.mesh = q
	add_child(_dust)
