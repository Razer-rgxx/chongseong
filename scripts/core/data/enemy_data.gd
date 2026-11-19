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
## 영주를 때리려면 가져가야 하는 공격 표 수(정예는 +1). 0이면 표 없이 덤빈다(언덕지기).
@export var token_cost: int = 1
## 우두머리(32단계)는 이미 있는 적의 큰 판이다: 행동(Foes)과 몸(EnemyView·EnemyArt·EnemyMotion)을 이 종류(적 id)에서 빌린다. 비면 id 그대로.
@export var kind: StringName = &""
## 몸을 그리는 크기 배수(우두머리는 그 종류의 몸을 이만큼 키운다). 규칙의 크기는 radius.
@export var view_scale: float = 1.0

@export_group("행동(11단계, docs/content.md)")
## 표를 청하는 거리(칸, 영주와 가운데 사이). 0이면 사거리 + token_wait_gap(걸어와 때리는 적).
@export var wait_range: float = 0.0
## 몸을 돌리는 빠르기(라디안/초). 0이면 늘 영주를 바로 본다. 방패병은 느려서 옆과 뒤가 열린다.
@export var turn_rate: float = 0.0
## 거리를 두는 적(활잡이, 부르는 자): 이보다 가까우면 물러나고 keep_far보다 멀면 다가온다(칸).
@export var keep_near: float = 0.0
@export var keep_far: float = 0.0
## 행동이 끝난 뒤 멈춰 있는 시간(초): 활잡이는 쏜 뒤, 부르는 자는 부른 뒤.
@export var act_after: float = 0.3

@export_subgroup("활잡이")
## 겨누는 시간(초), 화살 빠르기(칸/초), 화살이 가는 거리(칸), 화살이 영주에게 닿는 거리(칸, 영주 가운데에서).
@export var aim_time: float = 0.0
@export var shot_speed: float = 11.0
@export var shot_range: float = 12.0
@export var shot_radius: float = 0.35

@export_subgroup("방패병")
## 앞에서 막는 각(도). 0이면 막지 않는다. 막으면 피해와 넉백에 곱한다.
@export var guard_arc: float = 0.0
@export var guard_mult: float = 0.25
@export var guard_knock: float = 0.2
## 마무리(큰 베기)에 앞을 맞으면 깨진다: 기절 시간, 막지 못하는 시간(초).
@export var guard_stun: float = 1.2
@export var guard_down: float = 2.0

@export_subgroup("돌격병")
## 표를 받고 이 거리(칸) 안이면 머리를 낮춘다(wind_time초). 그다음 charge_speed칸/초로 charge_length칸까지 곧게 달린다.
@export var charge_min: float = 0.0
@export var charge_max: float = 0.0
@export var wind_time: float = 0.7
@export var charge_speed: float = 13.0
@export var charge_length: float = 9.0
## 영주에게 닿으면 영주가 밀려나는 거리(칸).
@export var charge_knock: float = 6.0
## 돌진이 끝나면 비틀거리는 시간(초)과 그동안 받는 피해 배수.
@export var stagger_time: float = 1.0
@export var stagger_mult: float = 1.5

@export_subgroup("자폭병")
## 표를 받고 이 거리(칸) 안이면 심지에 불이 붙는다(fuse_time초). 그다음 blast_radius칸으로 터진다. 0이면 터지지 않는다.
@export var fuse_range: float = 0.0
@export var fuse_time: float = 0.9
@export var blast_radius: float = 2.2
## 다른 적이 받는 피해(자폭병 피해 × 이것)와 넉백.
@export var blast_enemy_mult: float = 1.0
@export var blast_knock: float = 0.6

@export_subgroup("부르는 자")
## summon_interval초마다 summon_time초 동안 불러내고, 둘레 summon_radius칸에 summon_kind를 summon_count마리 부른다.
## 한 마리가 한 밤에 부르는 수는 summon_max까지(전체 적 수 한도 안에서). summon_count가 0이면 부르지 않는다.
@export var summon_kind: StringName = &"wraith"
@export var summon_count: int = 0
@export var summon_interval: float = 7.0
@export var summon_time: float = 1.0
@export var summon_radius: float = 1.6
@export var summon_max: int = 15

@export_group("무덤 기사(18단계, docs/outside.md)")
## 크게 휘두르기: 앞 swing_arc도(°) 부채꼴, swing_range칸(가운데에서)까지, swing_time초 예고(땅의 부채꼴 빛) 뒤에 한 번 벤다. 끝난 뒤 act_after초 멈춘다.
@export var swing_arc: float = 0.0
@export var swing_range: float = 3.4
@export var swing_time: float = 0.8
## 돌진할 수 있는 거리(charge_min~charge_max칸)에서 돌진을 고를 확률(0~1). 아니면 휘두를 거리까지 다가간다. 돌진은 돌격병과 같은 칸(wind_time, charge_*)을 쓴다.
@export var charge_chance: float = 0.6
## 돌진을 안 고르면 이만큼(초) 다가가다가 다시 고른다.
@export var charge_retry: float = 0.8
## 체력이 이 비율 아래로 내려가면 빨라진다(걷기·예고·돌진·쉬는 시간에 곱하는 배수 rage_mult). 0이면 빨라지지 않는다.
@export var rage_hp: float = 0.0
@export var rage_mult: float = 1.2
## 체력이 이 비율 아래로 내려가면 summon_*으로 한 번 부른다(summon_count가 0이면 안 부른다). 0이면 체력과 상관없이 부른다(부르는 자).
@export var summon_below: float = 0.0
## 31단계: 0보다 크면 체력이 이 비율 아래로 내려갔을 때 summon_count마리를 한 번 더 부른다(무덤 주인 50% → 25%). summon_max는 두 번 몫.
@export var summon_again: float = 0.0
## 그림 크기 배수(기사 모델 기준 1.0). 0이면 기본.
@export var model_scale: float = 0.0

@export_group("수련장(15단계, docs/village.md)")
## 움직이지도 때리지도 않는다(허수아비). 넉백도 받지 않는다.
@export var still: bool = false
## 0보다 크면 이만큼(초) 안 맞으면 체력이 다 차고, 쓰러지지 않는다(체력이 1 밑으로 내려가지 않는다).
@export var refill_after: float = 0.0


## 행동과 몸을 고르는 종류: kind가 있으면 그것(우두머리), 없으면 id.
func acts() -> StringName:
	return kind if kind != &"" else id
