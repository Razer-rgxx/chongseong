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
## 검집 강화로 오른 피해 배수.
var bonus: float = 1.0
## 떠돌이 대장장이(13단계)가 벼린 이번 밤의 피해 배수. 새벽에 1로 돌아온다.
var night_bonus: float = 1.0
## 검집 단계(0이면 검집에서 온 검이 아니거나 강화 안 함).
var sheath_lv: int = 0
var from_sheath: bool = false
## 표에 없는데 붙은 각인(검집, 제단 옮기기).
var extra_ins: PackedStringArray = PackedStringArray()
## 좌클릭 공격 방식(표의 attack). 테스트는 다른 방식을 넣어 볼 수 있다.
var pattern: PatternData


func _init(d: SwordData, game: GameData) -> void:
	data = d
	grade = d.grade
	form = game.forms[d.form]
	pattern = game.pattern_for(d)
	for k in d.inscriptions:
		var ins_data: InscriptionData = game.inscriptions.get(k)
		if ins_data:
			ins[k] = ins_data.value(grade)
	if d.unbreakable:
		max_durability = -1.0
	else:
		var tough: float = float(ins.get("단단함", 0.0)) + float(ins.get("투박함", 0.0))
		max_durability = roundf(game.grades.durability[grade] * form.durability * (1.0 + tough / 100.0))
		if d.cyber and game.powers:   # 2026-11-26: 사이버 검은 내구가 적다(PowerTable.cyber_durability)
			max_durability = maxf(1.0, roundf(max_durability * game.powers.cyber_durability))
	_carve_tough()
	durability = max_durability


## 룬·보석의 내구 배수(검의 기억). 검집 강화가 내구를 다시 정한 뒤에도 부른다.
func _carve_tough() -> void:
	var t: float = float(Meta.carve_of(data.id).get("tough", 0.0))
	if t > 0.0 and max_durability > 0.0:
		max_durability = roundf(max_durability * (1.0 + t))
		durability = max_durability


func breakable() -> bool:
	return max_durability > 0.0


## 기본 피해(형태 × 등급 × 검집 × 대장장이). 각인은 아직 더하지 않는다.
func damage(game: GameData) -> float:
	return game.lord.damage * form.damage * game.grades.damage_mult[grade] * bonus * night_bonus


## 화면에 쓸 이름(검집 단계가 붙는다).
func label() -> String:
	return ("+%d " % sheath_lv if sheath_lv > 0 else "") + Meta.shown_name(data)


## 각인 하나를 이 검의 등급 수치로 붙인다. 이미 있으면 아무 일도 없다.
func add_ins(key: String, game: GameData) -> void:
	var ins_data: InscriptionData = game.inscriptions.get(key)
	if ins_data == null or ins.has(key):
		return
	ins[key] = ins_data.value(grade)
	extra_ins.append(key)


## 검집에서 꺼낸 검: 피해와 내구가 단계만큼 오르고, 검집의 각인이 붙는다.
func apply_sheath(lv: int, keys: PackedStringArray, game: GameData) -> void:
	from_sheath = true
	sheath_lv = lv
	bonus = 1.0 + game.meta.sheath_damage * lv
	if breakable():
		max_durability = roundf(max_durability * (1.0 + game.meta.sheath_durability * lv))
		durability = max_durability
	for k in keys:
		add_ins(k, game)
