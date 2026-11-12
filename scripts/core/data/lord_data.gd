class_name LordData
extends Resource
## 영주. 손맛 수치라 사용자가 PC에서 맞춘다. 거리는 칸, 시간은 초.

@export var hp: float = 140.0
@export var regen_day: float = 8.0
@export var speed: float = 4.3

@export_group("공격")
@export var damage: float = 20.0
@export var reach: float = 1.55
## 라디안.
@export var arc: float = 1.9
@export var cooldown: float = 0.38
## 3연타의 세 번째(강타).
@export var big_damage_mult: float = 1.7
@export var big_reach_mult: float = 1.25
@export var big_arc_mult: float = 1.3
@export var knockback: float = 0.38
@export var hitstop: float = 0.035
@export var hitstop_big: float = 0.07
## 휘두르는 모습이 남는 시간.
@export var swing_time: float = 0.2
## 이만큼 가까운 적은 부채꼴 밖이어도 맞는다(크기에 더하는 칸).
@export var close_hit: float = 0.35
## 맞혔을 때 화면 흔들림 세기(0~1).
@export var shake: float = 0.14
@export var shake_big: float = 0.32

@export_group("돌진")
@export var dash_speed: float = 13.0
@export var dash_time: float = 0.16
@export var dash_cooldown: float = 1.1

@export_group("적의 관심")
## 이 거리 안이면 적이 영주를 쫓는다.
@export var aggro_range: float = 2.6
## 이미 쫓는 적은 이만큼 더 멀어져도 계속 쫓는다.
@export var aggro_keep: float = 1.5

@export_group("쓰러짐")
## 같은 밤에 쓰러진 횟수에 따라 기다리는 시간. 넘치면 마지막 값.
@export var respawn_times: PackedFloat32Array = PackedFloat32Array([8.0, 15.0, 25.0])
@export var respawn_invuln: float = 2.0
## 쓰러진 동안 사람의 힘이 이만큼 준다.
@export var aura_penalty: float = 0.25
