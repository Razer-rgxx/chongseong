class_name Enemy
extends RefCounted
## 밤에 올라오는 적 하나. 위치는 칸 단위 실수.

var id: int
var data: EnemyData
var pos: Vector2
## 바로 앞 틱의 위치. 화면이 틱 사이를 이어 그릴 때 쓴다.
var prev_pos: Vector2
## 넉백으로 밀려나는 속도(칸/초).
var push: Vector2 = Vector2.ZERO
var face: Vector2 = Vector2.DOWN
var hp: float
var max_hp: float
var damage: float
## 크기(칸). 정예는 표의 값보다 크다.
var radius: float
## 정예: 밤마다 하나, 체력이 몇 배이고 쓰러뜨리면 공짜 뽑기를 준다.
var elite: bool = false
var cooldown: float = 0.0
var dead: bool = false

# ---- 공격 표(Tokens, docs/attack_tokens.md). 화면은 읽기만 한다.
## 들고 있는 표 수(없으면 0). 표가 있어야 영주를 때린다.
var token: int = 0
## 표를 든 지 얼마나 됐는지(token_hold_max가 지나면 내려놓는다).
var token_t: float = 0.0
## 표를 받은 뒤 때리기 전에 기다리는 남은 시간(token_warn).
var windup: float = 0.0
## 곧(token_warn 안에) 때린다. 화면이 눈을 번쩍인다.
var attack_soon: bool = false
## 기다림 거리 안에 들어와 표를 청하는 중(기다림 거리 × 2 밖으로 나가면 그친다).
var waiting: bool = false
## 표를 청하며 기다린 시간. 가장 오래 기다린 적이 먼저 받는다.
var wait_t: float = 0.0

# ---- 각인과 고유 능력이 붙이는 상태(Powers)
## 처음 베였는지(첫 타 각인).
var was_hit: bool = false
## 출혈: 초당 피해와 남은 시간.
var bleed: float = 0.0
var bleed_t: float = 0.0
## 불: 남은 시간(꺼지지 않는 불이면 줄지 않는다).
var burn: float = 0.0
## 느림: 줄이는 비율과 남은 시간.
var slow_k: float = 0.0
var slow_t: float = 0.0
## 묶임(못 움직이고 못 때림). 얼음은 묶임과 같이 온다.
var stun: float = 0.0
var frozen: bool = false
## 받는 피해 2배가 남은 시간(거인의 무릎).
var vuln: float = 0.0
## 거인의 무릎: 연달아 베인 횟수.
var knee: int = 0
## 망각: 남은 시간 동안 영주 대신 가까운 적을 친다.
var confused: float = 0.0
## 서리 속성에 맞은 횟수(세 번째면 얼음).
var ice_hits: int = 0
