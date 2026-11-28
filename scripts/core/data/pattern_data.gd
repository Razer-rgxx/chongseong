class_name PatternData
extends Resource
## 공격 방식 하나(docs/attacks.md 3절): 기본 동작 2~4개를 차례로 + 속성. 좌클릭 한 번이 다음 동작 하나이고,
## 마지막 동작이 마무리(큰 베기)다. data/attacks/patterns/000.tres(맨손) … 150.tres.
## 001~150은 scripts/debug/build_attacks.gd가 만든다(손으로 고치면 다시 돌릴 때 덮인다).

## 방식 번호(0 = 맨손). 검 표의 attack과 같다.
@export var id: int = 0
@export var display_name: String = ""
## 0 흔함 … 5 무한. 어느 등급대의 방식인지.
@export_range(0, 5) var grade: int = 0
## 동작 id(MoveData.id)를 차례로.
@export var moves: PackedStringArray = PackedStringArray()
## 속성: "", "fire", "ice", "bolt", "blood".
@export var element: StringName = &""
## 마무리가 조금 뒤 한 번 더 울린다(메아리). 시간과 피해는 data/lord.tres의 "좌클릭".
@export var echo: bool = false


func steps() -> int:
	return moves.size()


func move_at(step: int) -> StringName:
	return StringName(moves[clampi(step - 1, 0, moves.size() - 1)])


## 갈고리 검인지(우클릭 갈고리를 쓸 수 있다).
func has_hook() -> bool:
	return moves.has("hook")
