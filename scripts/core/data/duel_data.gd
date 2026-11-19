class_name DuelData
extends Resource
## 1대1 결투(21단계, docs/duel.md)의 수치. data/duel.tres 한 장. 거리는 칸, 시간은 초.
## 맞는 쪽의 구르기 무적·넉백 세기·히트스톱은 적을 칠 때와 같고(LordData), 여기에는 결투만의 값을 둔다.

## 두 영주의 체력(같다).
@export var hp: float = 300.0
## 한 판의 시간. 다 되면 남은 체력 비율이 높은 쪽이 이긴다(같으면 비김).
@export var round_time: float = 90.0
## 먼저 이겨야 하는 판 수(3판 2선승이면 2). 최대 판 수는 이것 × 2 - 1.
@export var rounds_to_win: int = 2
## 판이 시작하기 전에 서 있는 시간과, 판 사이에 쉬는 시간.
@export var ready_time: float = 2.0
@export var break_time: float = 3.0
## 시작 자리: 싸움터 가운데에서 좌우로 이만큼(칸).
@export var start_gap: float = 6.0
## 영주의 몸 크기(칸). 맞는 판정과 서로 밀어내는 거리(둘의 합)에 쓴다.
@export var body_radius: float = 0.45
## 맞은 뒤 무적 시간(적에게 맞을 때와 같은 값).
@export var hurt_invuln: float = 0.3
## 넉백 배수(1이면 적을 칠 때와 같다).
@export var knockback_mult: float = 1.0
## 남은 체력 비율이 이 차이보다 작으면 비긴 것으로 친다.
@export var tie_eps: float = 0.0001
