extends Node3D
## 허수아비 그리기. 맞으면 잠깐 하얗게 번쩍이고 흔들린다. 4단계에서 적 그리기의 바탕이 된다.

@export var flash_time: float = 0.1
## 맞았을 때 흔들리는 세기(라디안). 강타는 1.6배.
@export var wobble: float = 0.22

var unit: Unit

var _flash: float = 0.0
var _wob: float = 0.0
var _t: float = 0.0
var _meshes: Array[MeshInstance3D] = []
var _white := StandardMaterial3D.new()
@onready var _model: Node3D = $Model


func _ready() -> void:
	_white.albedo_color = Color.WHITE
	_white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(n as MeshInstance3D)


func hit(big: bool) -> void:
	_flash = flash_time
	_wob = wobble * (1.6 if big else 1.0)


func draw(alpha: float, delta: float) -> void:
	position = Grid.cells_to_world(unit.prev_pos.lerp(unit.pos, alpha))
	_t += delta
	_flash -= delta
	for m in _meshes:
		m.material_overlay = _white if _flash > 0.0 else null
	_wob = move_toward(_wob, 0.0, delta * 1.5)
	_model.rotation.z = sin(_t * 28.0) * _wob
