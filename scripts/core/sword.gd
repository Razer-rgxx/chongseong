class_name Sword
extends RefCounted
## 손에 든 검 한 자루. 종류(SwordData)와 지금 남은 내구.

var data: SwordData
var form: FormData
var grade: int
## 각인 이름 → 이 등급의 수치.
var ins: Dictionary = {}
var durability: float
## -1이면 부러지지 않는다.
var max_durability: float


func _init(d: SwordData, game: GameData) -> void:
	data = d
	grade = d.grade
	form = game.forms[d.form]
	for k in d.inscriptions:
		var ins_data: InscriptionData = game.inscriptions.get(k)
		if ins_data:
			ins[k] = ins_data.value(grade)
	if d.unbreakable:
		max_durability = -1.0
	else:
		max_durability = roundf(game.grades.durability[grade] * form.durability)
	durability = max_durability


func breakable() -> bool:
	return max_durability > 0.0


## 기본 피해(형태 × 등급). 각인은 4단계에서 더한다.
func damage(game: GameData) -> float:
	return game.lord.damage * form.damage * game.grades.damage_mult[grade]
