class_name FloatText
extends Label3D
## 떠오르며 사라지는 글자(맞힌 숫자, 얻은 자원).

@export var life: float = 0.9
@export var rise: float = 1.4

var _t: float = 0.0


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	outline_size = 10
	outline_modulate = Color(0, 0, 0, 0.8)
	pixel_size = 0.01


func _process(delta: float) -> void:
	_t += delta
	position.y += rise * delta / life
	modulate.a = 1.0 - pow(_t / life, 2.0)
	if _t >= life:
		queue_free()
