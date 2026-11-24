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

@export_group("조작감")
## 걷기: 0에서 최고 빠르기까지(초), 서기까지(초). 2026-11-25 이전에는 램프 없이 바로 최고 빠르기였다.
@export var accel_time: float = 0.09
@export var stop_time: float = 0.07
## 반대로 꺾을 때 가속에 곱하는 배수(클수록 바로 뒤집힌다).
@export var reverse_mult: float = 3.0
## 돌진·좌클릭 눌림 선입력(초): 조금 일찍 눌러도 이 시간 안에 받아 주면 쓰인다(화면 쪽 PressBuffer).
@export var buffer_time: float = 0.13

@export_group("공격")
## 기본 피해. data/lord.tres가 13으로 둔다(2026-11-21: 검이 너무 세다는 말에 20에서 내림, 등급 배수도 평평하게).
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
@export var hitstop: float = 0.066        ## 벤 순간 멈춤(30Hz에서 2틱). 2026-11-20: 0.035(1틱)는 거의 안 느껴져 올림
@export var hitstop_big: float = 0.133    ## 큰 베기(4틱)
@export var hitstop_kill: float = 0.1     ## 그 베기로 적이 쓰러졌을 때(3틱)
@export var hitstop_elite_kill: float = 0.23  ## 정예·우두머리·보스를 쓰러뜨렸을 때(7틱)
@export var hitstop_hurt: float = 0.066   ## 영주가 맞았을 때(2틱, 결투에서는 없음)
## 마무리 슬로모션(2026-11-24, docs/dopamine.md): 밤을 끝낸 처치·보스·무리/방을 다 쓰러뜨린 순간. 시간 배수와 실제 초.
@export var finish_slow: float = 0.25
@export var finish_slow_time: float = 0.55
## 연쇄가 이어질 때마다 피해 숫자를 이만큼(비율) 키운다(연쇄 15까지). 연쇄가 chain_every 이상이면 피도 크게 튄다.
@export var chain_number_grow: float = 0.03
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

@export_group("점프")
## 걸어 다니는 점프(30단계): 뜬 동안의 시간(초)과 가장 높은 곳(m, 칸이 아니다). 높이는 포물선이다(LordState.air_height).
## 막힘의 높이가 Blockers.JUMP_CLEAR(1.0m) 이하면 공중에서 넘는다. 싸움 판정과는 상관없다(공중이어도 맞는다).
@export var jump_time: float = 0.55
@export var jump_height: float = 1.1

@export_group("갈고리")
## 겨눈 쪽으로 이 거리(칸)와 각도(라디안, 전체 폭) 안의 적에게 건다.
@export var hook_range: float = 9.0
@export var hook_cone: float = 0.9
## 날아가는 빠르기(칸/초). 이 시간(초)이 지나도 못 닿으면 멈춘다.
@export var hook_speed: float = 18.0
@export var hook_max_time: float = 0.7
@export var hook_cooldown: float = 2.5
## 닿으면 큰 베기를 한다. 그 피해에 더 곱하는 값.
@export var hook_damage_mult: float = 1.5
## 적의 몸에서 이만큼(칸) 앞에서 멈춘다.
@export var hook_gap: float = 0.3

@export_group("좌클릭")
## 메아리(초월·무한의 방식): 마무리의 판정이 이만큼(초) 뒤 같은 자리에서 한 번 더, 피해는 이 배수.
@export var echo_delay: float = 0.3
@export var echo_damage: float = 0.5
## 불꽃: 맞은 적에 불이 붙는 시간(초). 불의 초당 피해는 data/powers.tres의 "불_초당", "불_등급당".
@export var fire_burn: float = 2.0
## 서리: 느리게 하는 정도와 시간. 같은 적이 이만큼 맞으면 얼음(묶임)이 된다.
@export var ice_slow: float = 0.3
@export var ice_slow_time: float = 2.0
@export var ice_freeze_hits: int = 3
@export var ice_freeze_time: float = 1.0
## 벼락: 맞은 적 둘레 이 거리(칸) 안의 다른 적 몇 마리에게 이 피해 배수로 번개.
@export var bolt_count: int = 2
@export var bolt_range: float = 3.0
@export var bolt_damage: float = 0.5
## 피: 준 피해의 이만큼을 출혈로 bleed_time초 동안 더 입히고, 준 피해의 blood_heal만큼 체력을 되찾는다.
@export var blood_bleed: float = 0.3
@export var blood_bleed_time: float = 3.0
@export var blood_heal: float = 0.02
