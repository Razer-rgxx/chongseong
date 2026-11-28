class_name InscriptionData
extends Resource
## 각인 하나. 효과 글의 N 자리에 등급별 수치가 들어간다.

@export var key: String = ""
@export var text: String = ""
## 등급별 수치(흔함 … 무한, 6개).
@export var values: PackedFloat32Array = PackedFloat32Array()


func value(grade: int) -> float:
	return values[clampi(grade, 0, values.size() - 1)]


func describe(grade: int) -> String:
	var v: float = value(grade)
	var s: String = str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v
	return text.replace("N", s)
