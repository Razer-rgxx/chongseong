class_name MoveData
extends Resource
## 좌클릭 기본 동작 하나(docs/attacks.md 1절). data/attacks/moves/<id>.tres에 20개가 있다.
## "칼 길이"는 형태와 각인이 정한 사거리(Powers.stats().reach), "칼 폭"은 각도(stats().arc)다.
## 거리는 칸(1칸 = 2m), 시간은 초. 피해 배수는 형태 피해(stats().dmg)에 곱한다(큰 베기 배수는 따로 곱하지 않는다).

@export var id: StringName = &""
@export var display_name: String = ""
## 공격 방식 이름을 지을 때: 앞쪽에 올 때(이음, "찌르고")와 마지막에 올 때("내려찍기").
@export var link_name: String = ""
@export var end_name: String = ""
## link(이음: 연타의 앞쪽), finish(마무리: 큰 베기), special(어느 자리에도 온다).
@export_enum("link", "finish", "special") var role: String = "link"
## 판정 모양: arc(부채꼴), line(띠), circle(원), ring(고리), plus(십자), path(지나간 길), shot(날아가는 것).
@export var shape: StringName = &"arc"

@export_group("피해")
## 한 번 맞힐 때의 피해 배수.
@export var damage: float = 1.0
## 몇 번 맞히는지(연속 찌르기, 소용돌이). 첫 번은 누르는 순간.
@export var hits: int = 1
## 한 번과 다음 사이(초).
@export var interval: float = 0.0
## 맞은 적이 묶이는 시간(초).
@export var stun: float = 0.0
## 넉백 배수(형태 넉백 × 큰 베기 배수 × 밀쳐내기에 곱한다).
@export var knock: float = 1.0

@export_group("시간")
## 다음 좌클릭까지의 간격 배수. 영주 간격(lord.cooldown) ÷ 형태 빠르기에 곱한다. 큰 베기면 lord.big_cooldown_mult를 더 곱한다.
## 동작이 이어지는 동안(busy)은 이보다 짧아도 기다린다.
@export var cooldown: float = 1.0
## 동작 길이(초). 화면(MoveMotion, MoveFx)이 info.time으로 받는다.
@export var time: float = 0.2
## 판정이 늦게 터지는 시간(내려찍기, 발도).
@export var delay: float = 0.0
## 이 시간(초) 동안 걷지 못하고 돌진·갈고리도 못 한다(제자리, 멈춤).
@export var lock: float = 0.0
## 동작 길이 동안 걷는 빠르기 배수. 0보다 작으면 lord.swing_move_mult(보통 휘두르기).
@export var walk: float = -1.0

@export_group("모양")
## 부채꼴·띠의 길이 = 칼 길이 × 이것.
@export var reach: float = 1.0
## 부채꼴의 폭 = 칼 폭 × 이것.
@export var arc: float = 1.0
## 0보다 크면 칼 폭 대신 이 각도(도).
@export var arc_deg: float = 0.0
## 띠의 폭(칸).
@export var width: float = 0.0
## 원의 반지름(칸). radius_reach가 0보다 크면 칼 길이 × radius_reach.
@export var radius: float = 0.0
@export var radius_reach: float = 0.0
## 원의 가운데를 영주 앞 칼 길이 × 이만큼에 둔다(내려찍기).
@export var ahead: float = 0.0
## 십자 베기: 가로지르는 띠의 길이 = 칼 길이 × 이것.
@export var cross_reach: float = 0.0

@export_group("영주 움직임")
## 움직이는 거리(칸). + 앞, - 뒤. 도약은 최대 거리.
@export var dist: float = 0.0
## 움직이는 시간(초)과, 누른 뒤 움직이기 시작하는 때(물러나 베기).
@export var go_time: float = 0.0
@export var go_after: float = 0.0
## 움직이는 동안 무적.
@export var invuln: bool = false
## 대상을 찾는 거리(칸)와 각도(도, 전체 폭). 순간 베기, 도약.
@export var seek_range: float = 0.0
@export var seek_cone: float = 0.0
## 순간 베기: 적 뒤 몇 칸으로 옮기는지.
@export var behind: float = 0.0
## 돌진베기: 지나간 길에서 이 거리(칸) 안.
@export var path_width: float = 0.0
## 끌어당기기: 영주 앞 몇 칸으로 끌어오는지.
@export var pull_to: float = 0.0
## 대상이 없을 때 대신 하는 동작(순간 베기, 갈고리 베기 → 횡베기).
@export var fallback: StringName = &""

@export_group("날아가는 것")
## 빠르기(칸/초), 가는 거리(칸), 폭(칸). 칼 던지기는 거리만큼 갔다가 영주에게 돌아온다.
@export var speed: float = 0.0
@export var distance: float = 0.0
@export var shot_width: float = 0.0
## 이 시간(초)이 지나면 못 돌아와도 사라진다.
@export var shot_max_time: float = 3.0

@export_group("고리(지진)")
## 고리마다 반지름(칸)과 터지는 때(초). 같은 길이.
@export var ring_radii: PackedFloat32Array = PackedFloat32Array()
@export var ring_times: PackedFloat32Array = PackedFloat32Array()
@export var ring_thick: float = 0.0
@export var ring_damage: float = 0.0

@export_group("반격 자세")
## 반격: 둘레 원의 반지름 = 칼 길이 × counter_reach, 피해 배수 counter_damage. 안 맞으면 끝에 약한 베기(weak_damage).
@export var counter_reach: float = 0.0
@export var counter_damage: float = 0.0
@export var weak_damage: float = 0.0
## 반격에 성공하면 이만큼(초) 무적.
@export var counter_invuln: float = 0.0
