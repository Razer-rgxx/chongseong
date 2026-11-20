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

## ---- 온라인(22단계, docs/duel.md): 입력만 주고받는 락스텝 ----
## 입력 지연(틱): 내 입력은 이만큼 뒤 틱에 먹는다. 둘 다 똑같이 늦다. 30Hz에서 4틱은 약 0.13초.
@export var net_delay: int = 4
## 매 묶음에 겹쳐 담는 입력의 최소·최대 틱 수(최소: 늘 담는 수, 최대: 상대가 못 받아 밀린 만큼 다시 담되 이 수까지).
@export var net_resend_min: int = 3
@export var net_resend_max: int = 24
## 상대 입력이 이 초 동안 안 오면 끊긴 것으로 친다(그 전에는 기다리며 멈춘다).
@export var net_timeout: float = 6.0
## 이 틱마다 state_hash를 주고받아 맞춰 본다.
@export var net_hash_every: int = 30
## 시작 정보(HELLO)를 상대가 받을 때까지 다시 보내는 간격(초).
@export var net_hello_interval: float = 0.5
## 프로토콜 번호: 다르면 서로 겨루지 않는다.
@export var net_version: int = 1
## 공개 방에 붙이는 꼬리표(game, mode, 버전)와 방 이름 머리.
@export var net_tag_game: String = "geom_hill"
@export var net_tag_mode: String = "duel"
@export var net_lobby_prefix: String = "gh"
## 방을 만들고 기다리는 동안 다른 대기 방이 있나 다시 찾는 간격(초)과, 접속·방 찾기를 기다리는 한계(초).
@export var net_search_interval: float = 2.5
@export var net_connect_timeout: float = 20.0
## 대역폭 어림에 쓰는 틱 수(한 판 90초 × 3판 + 시작·쉼).
@export var net_estimate_seconds: float = 290.0
## 결투의 히트스톱(2026-11-20: 언덕·들판은 길게 올렸지만 결투는 두 사람의 리듬을 위해 예전 값을 지킨다).
@export var hitstop: float = 0.035
@export var hitstop_big: float = 0.07
## 온라인 결투(22단계) 단추를 보여 줄까. 실제 GD-Sync 접속·약관 확인 전이라 데모를 내보낼 때는 false로.
@export var online_enabled: bool = true
