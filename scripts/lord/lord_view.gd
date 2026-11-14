extends Node3D
## 영주 그리기. 규칙의 LordState를 틱 사이로 이어 그리고, 휘두르는 부채꼴, 쥔 검, 돌진 잔상을 보여 준다.
## 모델은 자식 "Model" 씬(scenes/lord/lord_model.tscn)이다. 모델을 바꿔 끼울 때 칼은 "Model/Hand/Blade"에 두면 된다.
## 쥔 검의 형태에 따라 칼날 길이와 두께가, 등급에 따라 코등이 색이 바뀐다.
## assets/characters/lord/paladin.fbx가 있으면 기본 도형 대신 그 기사(LordCharacter)를 세우고 동작을 고른다.

@export var arc_color: Color = Color(1, 1, 1, 0.22)
@export var arc_big_color: Color = Color(1, 0.84, 0.42, 0.38)
@export var ghost_color: Color = Color(0.5, 0.7, 1.0, 0.35)
@export var ghost_life: float = 0.2
## 칼을 들고 있을 때 몸 앞에서 벌어진 각도(라디안).
@export var idle_blade_angle: float = 0.9
## 기사 모델의 베기·구르기·맞기 동작을 트는 빠르기(1 = 원래 빠르기).
@export var slash_speed: float = 1.1
@export var roll_speed: float = 1.3
## 구르기 동작을 몇 초에 끝낼지. 동작의 실제로 구르는 구간만 이 시간에 맞춰 튼다(규칙의 돌진은 0.16초).
@export var roll_time: float = 0.45
## 몸을 돌리는 빠르기(클수록 빨리). 휘두르거나 구를 때는 turn_fast로 거의 바로 돌린다.
@export var turn_speed: float = 12.0
@export var turn_fast: float = 40.0
@export_group("칼 궤적과 베기 빛")
## 휘두르기 시작부터 이 시간 동안 칼끝이 지나간 자리를 그린다(궤적의 길이와 모양은 SlashFx).
@export var trail_time: float = 0.26
## 베기 빛을 사선으로 기울이는 각(라디안). 번갈아 반대로 기운다. 큰 베기는 수평.
@export var arc_tilt: float = 0.35
@export_group("")
@export var hit_speed: float = 1.0
## 달리기 동작 빠르기. 영주가 Mixamo 달리기보다 빨라서 올리면 발이 덜 미끄러지지만, 사용자가 빠르다고 해서 1.1로 뒀다.
@export var run_speed: float = 1.1
## 베기 동작의 앞쪽 준비 자세를 건너뛰는 시간(초). 규칙은 누르는 순간 벤다.
@export var slash_skip: float = 0.25
## 한 번 트는 동작을 길어도 이만큼(초)만 보고 서기·달리기로 돌아간다.
@export var slash_hold: float = 0.8
@export var roll_hold: float = 0.9

var rules: Rules

@onready var _model: Node3D = $Model
@onready var _hand: Node3D = get_node_or_null("Model/Hand") as Node3D
@onready var _blade: MeshInstance3D = get_node_or_null("Model/Hand/Blade") as MeshInstance3D
var _guard := MeshInstance3D.new()
var _guard_mat := StandardMaterial3D.new()
## 밤에 영주 둘레만 밝히는 횃불.
var torch := OmniLight3D.new()
var _arc := MeshInstance3D.new()
var _arc_mesh := ImmediateMesh.new()
var _arc_mat := StandardMaterial3D.new()
var _ghost_mesh := CapsuleMesh.new()
var _ghosts: Array[MeshInstance3D] = []
## 기사 모델(없으면 null, 기본 도형을 쓴다).
var character: LordCharacter = null
var _busy: float = 0.0
var _last_swing: float = 0.0
var _last_invuln: float = 0.0
var _last_dash: float = 0.0
var _state: String = ""
var _yaw_now: float = 0.0
var _yaw_ready: bool = false
var _swing_t: float = 99.0
var _fx: SlashFx = null
var _sweep: float = 1.0


func setup(r: Rules) -> void:
	rules = r


func _ready() -> void:
	_arc.mesh = _arc_mesh
	_arc.top_level = true
	_arc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_arc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_arc_mat.vertex_color_use_as_albedo = true
	add_child(_arc)
	_ghost_mesh.radius = 0.42
	_ghost_mesh.height = 1.6
	if LordCharacter.available():
		for c in _model.get_children():
			c.queue_free()
		_hand = null
		_blade = null
		character = LordCharacter.new()
		_model.add_child(character)
		_fx = SlashFx.new()
		add_child(_fx)
	if _hand:
		var gm := BoxMesh.new()
		gm.size = Vector3(0.34, 0.07, 0.07)
		_guard.mesh = gm
		_guard_mat.emission_enabled = true
		_guard_mat.emission_energy_multiplier = 0.6
		_guard.material_override = _guard_mat
		_guard.position = Vector3(0, 0, -0.3)
		_hand.add_child(_guard)
	if _blade:
		_blade.mesh = (_blade.mesh as BoxMesh).duplicate()
	torch.position = Vector3(0.4, 2.2, 0.3)
	torch.light_color = Color(1.0, 0.72, 0.45)
	torch.omni_range = 9.0
	torch.light_energy = 0.0
	torch.shadow_enabled = true
	add_child(torch)


## 쥔 검이 바뀌면 부른다. null이면 맨손.
func set_sword(s: Sword, grades: GradeTable) -> void:
	if character:
		character.set_sword(s, grades)
		if s:
			_fx.color = Color(0.9, 0.92, 1.0) if s.grade == 0 else (grades.colors[s.grade] as Color).lightened(0.25)
		return
	if not _blade:
		return
	_blade.visible = s != null
	_guard.visible = s != null
	if s == null:
		return
	var m := _blade.mesh as BoxMesh
	m.size = Vector3(s.form.blade_width, 0.05, s.form.blade_length)
	_blade.position = Vector3(0, 0, -(0.32 + s.form.blade_length / 2.0))
	var c: Color = grades.colors[s.grade]
	_guard_mat.albedo_color = c
	_guard_mat.emission = c


## main이 매 프레임 부른다. alpha는 지난 틱과 이번 틱 사이의 위치(0~1).
func draw(alpha: float, delta: float) -> void:
	var L := rules.lord
	position = Grid.cells_to_world(L.prev_pos.lerp(L.pos, alpha))
	if character == null:
		_model.rotation.y = _yaw(L.face)
	# 휘두르기: 콤보마다 쓸어 가는 방향이 바뀐다
	var rel: float = idle_blade_angle
	_arc_mesh.clear_surfaces()
	if L.swing > 0.0:
		var arc: float = L.swing_arc
		var reach_m: float = Grid.cells_to_meters(L.swing_reach)
		var k: float = 1.0 - L.swing / rules.data.lord.swing_time
		var dir: float = 1.0 if L.combo % 2 == 1 else -1.0
		var a0: float = -dir * arc / 2.0
		var a1: float = a0 + dir * arc * minf(1.0, k * 1.6)
		rel = a1
		var col: Color = arc_big_color if L.big else arc_color
		col.a *= 1.0 - k * 0.6
		if character == null:   # 기사 모델이 있으면 바닥 부채꼴 대신 칼 궤적을 그린다
			_fan(position + Vector3(0, 0.12, 0), L.face + minf(a0, a1), L.face + maxf(a0, a1), reach_m, col)
	if _hand:
		_hand.rotation.y = -rel
	if character:
		character.set_frozen(rules.freeze > 0)
		_animate(L, delta)
		_turn(L, delta)
		_draw_trail(delta)
	for i in range(_ghosts.size() - 1, -1, -1):
		var g := _ghosts[i]
		var m := g.material_override as StandardMaterial3D
		m.albedo_color.a -= ghost_color.a * delta / ghost_life
		if m.albedo_color.a <= 0.0:
			g.queue_free()
			_ghosts.remove_at(i)
	if L.dash > 0.0 and character == null:   # 기사 모델은 구르기 동작이 있어서 잔상을 남기지 않는다
		_spawn_ghost()


## 메아리 계곡 같은 두 번째 베기: 그 자리에 베기 빛만 다시 그린다.
func echo_arc(at: Vector2, face: float, arc: float, reach: float) -> void:
	if _fx:
		_fx.arc(Grid.cells_to_world(at, _fx.arc_height), face, arc, Grid.cells_to_meters(minf(reach, 12.0)), -_sweep, 0.0, false)


## 기사 모델의 동작을 고른다. 베기·구르기·맞기는 끝날 때까지 두고, 그 밖에는 달리기와 서 있기.
## 규칙의 값이 새로 커지는 순간(휘두름, 돌진, 무적)을 보고 한 번만 튼다.
func _animate(L: LordState, delta: float) -> void:
	_busy = maxf(0.0, _busy - delta)
	if L.hp <= 0.0:
		if _state != "death":
			_one_shot("death", 1.0)
			_busy = 999.0
	elif L.dash > _last_dash:
		var w: Vector2 = character.roll_window
		if w.x >= 0.0:
			_one_shot("roll", (w.y - w.x) / roll_time, roll_time, w.x)
		else:
			_one_shot("roll", roll_speed, roll_hold)
	elif L.swing > _last_swing:
		_one_shot("big" if L.big else "slash", slash_speed, slash_hold, slash_skip)
		_swing_t = 0.0
		_fx.clear_trail()
		_fx.arc(position + Vector3(0, _fx.arc_height, 0), L.face, L.swing_arc, Grid.cells_to_meters(L.swing_reach), _sweep, 0.0 if L.big else arc_tilt * _sweep, L.big)
		_sweep = -_sweep
	elif L.invuln > _last_invuln and L.swing <= 0.0 and L.dash <= 0.0:
		_one_shot("hit", hit_speed)
	elif _busy <= 0.0:
		if rules.pull_hilt != null:
			_loop("pull")
		elif L.moving:
			_loop("run", run_speed)
		else:
			_loop("idle")
	_last_swing = L.swing
	_last_invuln = L.invuln
	_last_dash = L.dash


## 모델이 보는 쪽: 구를 때는 구르는 쪽, 휘두를 때는 겨눈 쪽(규칙의 face), 걸을 때는 걷는 쪽.
## 서 있으면 그대로 둔다. 확 돌리지 않고 부드럽게 돌려 걸음이 촐랑대지 않게 한다.
func _turn(L: LordState, delta: float) -> void:
	if not _yaw_ready:
		_yaw_now = _yaw(L.face)
		_yaw_ready = true
	var target: float = _yaw_now
	var fast: bool = false
	if (_state == "roll" and _busy > 0.0) or L.dash > 0.0:
		target = _yaw(L.dash_dir.angle())
		fast = true
	elif L.swing > 0.0 or ((_state == "slash" or _state == "big") and _swing_t < slash_hold * 0.5):
		target = _yaw(L.face)
		fast = true
	elif L.moving:
		target = _yaw(L.move_dir.angle())
	var k: float = 1.0 - exp(-(turn_fast if fast else turn_speed) * delta)
	_yaw_now = lerp_angle(_yaw_now, target, k)
	_model.rotation.y = _yaw_now


## 휘두르기 시작부터 trail_time 동안 칼날의 두 끝을 SlashFx에 넘긴다.
func _draw_trail(delta: float) -> void:
	_swing_t += delta
	var bp: Array[Vector3] = character.blade_points()
	var active: bool = _swing_t < trail_time and (_state == "slash" or _state == "big") and not bp.is_empty()
	if bp.is_empty():
		bp = [Vector3.ZERO, Vector3.ZERO]
	_fx.trail_step(delta, active, bp[0].lerp(bp[1], 0.25), bp[1])


func _loop(state: String, speed: float = 1.0) -> void:
	_state = state
	character.play(state, speed)


## cap: 길어도 이만큼만 본다(0 이하면 끝까지). from: 몇 초째부터.
func _one_shot(state: String, speed: float, cap: float = -1.0, from: float = 0.0) -> void:
	_state = state
	var name: String = character.play(state, speed, from)
	var whole: float = maxf(0.0, character.length(name) - from) / maxf(speed, 0.01)
	_busy = minf(whole, cap) if cap > 0.0 else whole


## 규칙의 각도(0 = 동쪽 +x, PI/2 = 남쪽 +z)를 모델의 앞(-Z)이 그쪽을 보게 하는 회전으로 바꾼다.
static func _yaw(face: float) -> float:
	return atan2(-cos(face), -sin(face))


func _fan(c: Vector3, from: float, to: float, r: float, col: Color) -> void:
	var seg: int = 18
	_arc_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _arc_mat)
	for i in seg:
		var t0: float = lerpf(from, to, float(i) / seg)
		var t1: float = lerpf(from, to, float(i + 1) / seg)
		for v in [c, c + Vector3(cos(t0), 0, sin(t0)) * r, c + Vector3(cos(t1), 0, sin(t1)) * r]:
			_arc_mesh.surface_set_color(col)
			_arc_mesh.surface_add_vertex(v)
	_arc_mesh.surface_end()


func _spawn_ghost() -> void:
	var g := MeshInstance3D.new()
	g.mesh = _ghost_mesh
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = ghost_color
	g.material_override = m
	g.top_level = true
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)
	g.global_position = global_position + Vector3(0, 0.8, 0)
	_ghosts.append(g)
