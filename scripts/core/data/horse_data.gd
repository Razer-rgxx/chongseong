class_name HorseData
extends Resource
## 39단계 말(docs/open_world2.md)의 수치. data/horse.tres 한 장. 거리는 칸, 시간은 초, 각은 라디안(따로 적은 것 빼고).
## 손맛 수치라 사용자가 PC에서 맞춘다. 말은 들판에서만 부른다(Rules.allow_horse).

@export_group("달리기")
## 탄 채 걷는 빠르기 배수(LordData.speed × 이것).
@export var speed_mult: float = 2.2
## 다 달릴 때 방향을 바꾸는 빠르기(라디안/초)와 서 있을 때 도는 빠르기. 그 사이는 빠르기에 따라 섞는다.
@export var turn_rate: float = 3.2
@export var turn_still: float = 6.0
## 가려는 쪽과 달리는 쪽이 크게 어긋나면(뒤로 돌 때) 빠르기를 이 배수까지 늦춘다.
@export var turn_slow: float = 0.35
## 서 있다가 다 달리기까지, 다 달리다 서기까지 걸리는 시간.
@export var accel_time: float = 0.45
@export var stop_time: float = 0.35
## 막힘에서 밀어낼 때의 몸 반지름(걸을 때 Blockers.BODY 0.3보다 크다).
@export var body_r: float = 0.45

@export_group("도약")
## 탄 채 점프 키: 공중에 뜬 시간과 가장 높은 곳(m). 공중이면 낮은 막힘(Blockers.JUMP_CLEAR 1m)을 넘는다(30단계 규칙).
@export var leap_time: float = 0.62
@export var leap_height: float = 1.3

@export_group("부르기")
## 말이 나타나 달려오는 거리(영주에게서), 멈추는 자리(영주 곁, 다가온 쪽), 다 왔다고 치는 거리, 늦추기 시작하는 세기(남은 거리 × 이것 = 빠르기).
@export var call_from: float = 22.0
@export var call_side: float = 1.6
@export var arrive_eps: float = 0.15
@export var arrive_brake: float = 3.0
## 이 시간 안에 못 오면(막혀서) 곁에 바로 선다.
@export var come_max: float = 6.0
## 말 곁에서 E로 탈 수 있는 거리, 내리면 영주가 서는 자리(말의 왼쪽으로 이만큼).
@export var mount_reach: float = 2.2
@export var dismount_side: float = 1.1
## 내린 말이 달리던 빠르기에서 서기까지 걸리는 시간(떨어졌을 때 몇 걸음 더 간다).
@export var coast_time: float = 0.9

@export_group("떨어짐")
## 탄 채 맞으면 떨어진다: 때린 쪽 반대로 밀리는 빠르기(칸/초, LordData.knock_keep으로 줄어든다)와 휘청이는 시간(걷지도 베지도 못한다).
@export var fall_push: float = 7.0
@export var fall_stagger: float = 0.45

@export_group("말 위 베기")
## 좌클릭: 기본 동작 횡베기(sweep)를 넓게 한 가지. 쥔 검의 사거리 × slash_reach, 부채꼴 각(도), 피해 배수, 간격 배수.
@export var slash_reach: float = 1.7
@export var slash_arc_deg: float = 220.0
@export var slash_damage: float = 1.15
@export var slash_cooldown: float = 1.15

@export_group("화면")
## 탄 채 카메라: 거리 배수와 더 높이(m), 바뀌는 데 걸리는 시간.
@export var camera_far: float = 1.35
@export var camera_up: float = 0.9
@export var camera_blend: float = 0.4
