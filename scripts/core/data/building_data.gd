class_name BuildingData
extends Resource
## 건물 표 한 줄. 값(나무, 돌), 생산량, 손님 운은 등급마다 달라서 TierTable에 있다.

enum Role { RECRUIT, PRODUCE, DEFEND, PROMOTE }

@export var id: StringName
@export var display_name: String
@export_range(0, 7) var tier: int = 0
@export var role: Role = Role.RECRUIT
## 생산: wood, stone, both. 방어: shoot, splash, slow, block, heart. 나머지는 비워 둔다.
@export var kind: StringName
@export_multiline var description: String
## 체력 배수(쇠살문 4). 기본 체력은 RunData.building_hp_base × building_hp_growth^tier.
@export var hp_mult: float = 1.0
## 길찾기 비용. 0이면 RunData.cost_building을 쓴다(쇠살문 18).
@export var path_cost: float = 0.0

@export_group("방어")
@export var damage: float = 0.0
@export var attack_range: float = 0.0
@export var cooldown: float = 0.0
## 돌이 떨어진 곳의 피해 반경(칸). 0이면 한 명만 맞힌다.
@export var splash_radius: float = 0.0
## 느리게 하는 시간(초). 0이면 느리게 하지 않는다.
@export var slow_time: float = 0.0
## 투사체 종류: arrow, stone. 비우면 범위 안을 바로 친다.
@export var projectile: StringName
