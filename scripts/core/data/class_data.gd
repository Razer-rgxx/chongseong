class_name ClassData
extends Resource
## 사람의 병과 표 한 줄. 힘 = GradeTable.power[등급] × (1 + RunData.level_power × (레벨 - 1)).

@export var id: StringName
@export var display_name: String
@export var damage: float = 0.0
@export var attack_range: float = 0.0
@export var cooldown: float = 1.0
## 투사체 종류: arrow, stone, bolt. 비우면 근접.
@export var projectile: StringName
@export var splash_radius: float = 0.0
@export var slow_time: float = 0.0
## 방패병: 선 성벽이 받는 피해를 1 / (1 + guard_k × √힘)으로 줄인다.
@export var guard_k: float = 0.0
## 사제: 곁의 성벽을 초당 heal × 힘만큼 고친다.
@export var heal: float = 0.0

@export_group("기술 (장수 이상)")
@export var skill_name: String
@export_multiline var skill_description: String

@export_group("대사")
## 대화 뽑기에서 처음 건네는 말. 둘 중 하나를 고른다.
@export var hello_lines: PackedStringArray
