extends Node3D
## 블록 인형 시범: 설계 도면 위에 정예 창병 하나. 설계선에서 차오른 뒤 천천히 돈다.

const PAPER: Shader = preload("res://shaders/paper.gdshader")

@export var build_time: float = 1.6
## 화면이 뜬 뒤 이만큼 기다렸다가 차오르기 시작한다.
@export var start_delay: float = 1.0
@export var turn_speed: float = 0.9

var _t: float = 0.0
@onready var _fig: BlockFigure = $Figure


func _ready() -> void:
	var g := $Ground as MeshInstance3D
	var m := ShaderMaterial.new()
	m.shader = PAPER
	m.set_shader_parameter("map_meters", 2000.0)
	g.material_override = m


func _process(delta: float) -> void:
	_t += delta
	_fig.set_build(clampf((_t - start_delay) / build_time, 0.0, 1.0))
	_fig.animate(delta)
	if _t > start_delay + build_time:
		_fig.rotation.y += delta * turn_speed
