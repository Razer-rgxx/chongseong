extends Node3D
## 영주 그리기. 규칙의 LordState를 틱 사이로 이어 그리고, 휘두르는 부채꼴, 쥔 검, 돌진 잔상을 보여 준다.
## 모델은 자식 "Model" 씬(scenes/lord/lord_model.tscn)이다. 모델을 바꿔 끼울 때 칼은 "Model/Hand/Blade"에 두면 된다.
## 쥔 검의 형태에 따라 칼날 길이와 두께가, 등급에 따라 코등이 색이 바뀐다.

@export var arc_color: Color = Color(1, 1, 1, 0.22)
@export var arc_big_color: Color = Color(1, 0.84, 0.42, 0.38)
@export var ghost_color: Color = Color(0.5, 0.7, 1.0, 0.35)
@export var ghost_life: float = 0.2
## 칼을 들고 있을 때 몸 앞에서 벌어진 각도(라디안).
@export var idle_blade_angle: float = 0.9

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
		_fan(position + Vector3(0, 0.12, 0), L.face + minf(a0, a1), L.face + maxf(a0, a1), reach_m, col)
	if _hand:
		_hand.rotation.y = -rel
	for i in range(_ghosts.size() - 1, -1, -1):
		var g := _ghosts[i]
		var m := g.material_override as StandardMaterial3D
		m.albedo_color.a -= ghost_color.a * delta / ghost_life
		if m.albedo_color.a <= 0.0:
			g.queue_free()
			_ghosts.remove_at(i)
	if L.dash > 0.0:
		_spawn_ghost()


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
