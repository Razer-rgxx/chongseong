class_name LordData
extends Resource
## 영주. 손맛 수치라 사용자가 PC에서 맞춘다. 거리는 칸, 시간은 초.
## 검의 형태(FormData)와 등급(GradeTable)이 여기에 곱해진다.

@export var hp: float = 140.0
@export var speed: float = 4.3
## 휘두르는 동안 걷는 빠르기 배수.
@export var swing_move_mult: float = 0.55
## 맞은 뒤 무적 시간.
@export var hurt_invuln: float = 0.3

@export_group("공격")
@export var damage: float = 20.0
@export var reach: float = 1.55
## 라디안.
@export var arc: float = 1.9
@export var cooldown: float = 0.38
## 연타의 마지막(큰 베기).
@export var big_damage_mult: float = 1.7
@export var big_cooldown_mult: float = 1.25
@export var big_knockback_mult: float = 1.6
## 이 시간 안에 다시 휘둘러야 연타가 이어진다.
@export var combo_window: float = 0.9
@export var knockback: float = 0.38
## 넉백을 속도로 바꾸는 배수와 줄어드는 정도(1초에 남는 비율).
@export var knock_speed: float = 14.0
@export var knock_keep: float = 0.001
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
