class_name EnemyData
extends Resource
## 적 표 한 줄. 체력과 공격은 RunData의 날짜별 증가를 곱한다(우두머리는 boss_* 배수만).

@export var id: StringName
@export var display_name: String
@export var hp: float = 30.0
@export var damage: float = 5.0
## 칸/초.
@export var speed: float = 1.5
## 칸.
@export var radius: float = 0.3
@export var gold: int = 1
@export var cooldown: float = 1.0
## 성벽, 건물, 영주관에 주는 피해 배수.
@export var siege_mult: float = 1.0
## 참이면 영주를 쫓지 않는다(공성추).
@export var ignores_lord: bool = false
@export var is_boss: bool = false
@export var color: Color = Color.RED
