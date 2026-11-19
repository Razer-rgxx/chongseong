class_name VillagerData
extends Resource
## 마을 주민 한 사람과 그 대사(15단계, docs/village.md 15.3). 줄마다 조건을 붙일 수 있다(lines, cond, cond_n은 같은 순서).
## cond: ""(늘), "runs"(오른 횟수 ≥ cond_n), "best"(가장 높이 오른 구역 ≥ cond_n), "legend"(전설 이상을 뽑아 봄),
## "top"(정상에 오름), "quest"(의뢰를 맡고 있음). Meta.talk가 조건이 맞는 줄 중 안 들은 것부터 고른다.

@export var id: StringName = &""
@export var display_name: String = ""
@export var lines: PackedStringArray = PackedStringArray()
@export var cond: PackedStringArray = PackedStringArray()
@export var cond_n: PackedInt32Array = PackedInt32Array()
