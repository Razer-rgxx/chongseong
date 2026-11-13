class_name EnemyData
extends Resource
## 밤에 올라오는 적. 거리는 칸, 시간은 초.

@export var id: StringName = &""
@export var display_name: String = ""
@export var hp: float = 30.0
@export var damage: float = 6.0
@export var speed: float = 1.6
@export var radius: float = 0.3
@export var cooldown: float = 1.0
@export var color: Color = Color.WHITE
## 넉백 배수(무거운 것은 덜 밀린다).
@export var knockback_mult: float = 1.0
## 큰 적(거인 베기 각인이 먹힌다).
@export var big: bool = false
## 망령(망령 베기 각인이 먹힌다).
@export var wraith: bool = false
## 구역에 따라 체력과 피해가 오르지 않는다(언덕지기).
@export var boss: bool = false
