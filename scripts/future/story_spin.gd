extends Node3D
## 자료 조각이 천천히 돌며 떠 있다(꾸밈).

var _t: float = 0.0


func _process(delta: float) -> void:
	_t += delta
	rotation.y += delta * 1.4
	position.y += sin(_t * 2.0) * delta * 0.15
