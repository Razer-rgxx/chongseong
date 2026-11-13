class_name BlockFigure
extends Node3D
## 블록 인형. 상자를 조립해 사람 하나를 만든다. 건물과 같은 셰이더라 설계선에서 아래부터 채워지며 나타날 수 있다.
## 지금은 창병만 있다. 병과는 무기와 실루엣, 등급은 장식(띠 → 깃털 → 망토 → 빛 고리)으로 구분한다.

const SOLID: Shader = preload("res://shaders/build_solid.gdshader")
const LINES: Shader = preload("res://shaders/build_lines.gdshader")

@export var grade: int = 2
@export var grade_color: Color = Color(1.0, 0.76, 0.24)
@export var skin: Color = Color(0.86, 0.7, 0.56)
@export var tunic: Color = Color(0.36, 0.4, 0.33)
@export var pants: Color = Color(0.24, 0.21, 0.19)
@export var steel: Color = Color(0.42, 0.44, 0.48)
@export var wood: Color = Color(0.42, 0.29, 0.18)
@export var plume: Color = Color(0.82, 0.2, 0.17)

## [상자, 바닥 높이, 높이] — 아래부터 채울 때 쓴다(높이는 이 인형 기준 m).
var _parts: Array = []
var _top: float = 0.0
var _t: float = 0.0
var _arm_r: Node3D
var _arm_l: Node3D
var _body: Node3D


func _ready() -> void:
	_body = Node3D.new()
	add_child(_body)
	# 다리
	for s in [-1, 1]:
		_box(_body, Vector3(s * 0.13, 0.36, 0), Vector3(0.22, 0.72, 0.24), pants)
		_box(_body, Vector3(s * 0.13, 0.06, 0.03), Vector3(0.24, 0.12, 0.3), pants.darkened(0.4))
	# 몸통, 띠(정예부터 등급 색)
	_box(_body, Vector3(0, 1.02, 0), Vector3(0.58, 0.62, 0.32), tunic)
	_box(_body, Vector3(0, 0.78, 0), Vector3(0.62, 0.1, 0.36), grade_color if grade >= 1 else tunic.darkened(0.3))
	# 머리와 얼굴
	_box(_body, Vector3(0, 1.53, 0), Vector3(0.38, 0.38, 0.38), skin)
	for s in [-1, 1]:
		_box(_body, Vector3(s * 0.08, 1.55, -0.195), Vector3(0.05, 0.07, 0.02), Color(0.08, 0.08, 0.1))
	# 투구와 깃털(정예부터)
	_box(_body, Vector3(0, 1.75, 0), Vector3(0.44, 0.1, 0.44), steel)
	_box(_body, Vector3(0, 1.66, 0.19), Vector3(0.44, 0.2, 0.06), steel)
	if grade >= 2:
		_box(_body, Vector3(0, 1.92, 0.04), Vector3(0.08, 0.24, 0.34), plume)
	# 팔: 어깨를 축으로 흔들 수 있게 따로 둔다
	_arm_r = _arm(1)
	_arm_l = _arm(-1)
	# 창: 오른손에 세워 든다
	_box(_arm_r, Vector3(0.0, 0.25, -0.08), Vector3(0.06, 2.3, 0.06), wood)
	_box(_arm_r, Vector3(0.0, 1.5, -0.08), Vector3(0.05, 0.3, 0.12), steel)
	_box(_arm_r, Vector3(0.0, 1.32, -0.08), Vector3(0.14, 0.05, 0.14), grade_color)
	set_build(1.0)


func _arm(side: int) -> Node3D:
	var pivot := Node3D.new()
	_body.add_child(pivot)
	pivot.position = Vector3(side * 0.38, 1.28, 0)
	_box(pivot, Vector3(0, -0.28, 0), Vector3(0.18, 0.6, 0.2), tunic)
	_box(pivot, Vector3(0, -0.62, 0), Vector3(0.17, 0.12, 0.19), skin)
	return pivot


func _box(parent: Node3D, center: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var solid := ShaderMaterial.new()
	solid.shader = SOLID
	solid.set_shader_parameter("half_size", size / 2.0)
	solid.set_shader_parameter("base_color", color)
	solid.set_shader_parameter("course", 100.0)
	var lines := ShaderMaterial.new()
	lines.shader = LINES
	lines.set_shader_parameter("half_size", size / 2.0)
	lines.set_shader_parameter("width", 0.012)
	lines.set_shader_parameter("built_alpha", 0.16)
	solid.next_pass = lines
	mi.material_override = solid
	parent.add_child(mi)
	mi.position = center
	var world_y: float = parent.position.y + center.y if parent != _body else center.y
	var bottom: float = world_y - size.y / 2.0
	_parts.append([mi, bottom, size.y])
	_top = maxf(_top, bottom + size.y)
	return mi


## 0이면 설계선만, 1이면 다 채워진 인형. 아래부터 차오른다.
func set_build(p: float) -> void:
	for e in _parts:
		var mi: MeshInstance3D = e[0]
		var k: float = clampf((p * _top - e[1]) / e[2], 0.0, 1.0)
		var s := mi.material_override as ShaderMaterial
		s.set_shader_parameter("progress", k)
		(s.next_pass as ShaderMaterial).set_shader_parameter("progress", k)


## 가만히 서 있을 때의 숨쉬기. walk는 0~1(걷는 정도).
func animate(delta: float, walk: float = 0.0) -> void:
	_t += delta
	_body.position.y = sin(_t * 2.4) * 0.015 * (1.0 - walk) + absf(sin(_t * 9.0)) * 0.05 * walk
	_arm_l.rotation.x = sin(_t * 9.0) * 0.6 * walk + sin(_t * 2.4) * 0.04
	_arm_r.rotation.x = -sin(_t * 9.0) * 0.25 * walk
