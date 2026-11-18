class_name RunData
extends Resource
## 한 판의 흐름. 거리는 칸(1칸 = 2m), 시간은 초.

@export var tick_rate: int = 30
## 언덕 꼭대기 싸움터의 크기(칸).
@export var arena_size: Vector2i = Vector2i(34, 22)

@export_group("구역")
@export var zone_names: PackedStringArray = PackedStringArray(["기슭", "들머리", "비탈", "바위턱", "중턱", "안개 띠", "능선", "칼바람 마루", "봉우리 아래", "정상"])
## 구역마다 뽑기 운, 적 체력 배수, 적 피해 배수. 길이는 구역 수와 같다.
@export var zone_luck: PackedFloat32Array = PackedFloat32Array([1, 1.3, 1.7, 2.2, 3, 4, 5, 6.5, 8, 10])
@export var zone_hp: PackedFloat32Array = PackedFloat32Array([1, 1.25, 1.5, 1.8, 2.2, 2.6, 3.1, 3.7, 4.4, 5.2])
@export var zone_damage: PackedFloat32Array = PackedFloat32Array([1, 1.1, 1.2, 1.35, 1.5, 1.65, 1.8, 2, 2.2, 2.4])

@export_group("낮: 뽑기")
## 낮마다 꽂히는 검 수.
@export var hilts_per_day: int = 16
## 한 번 뽑을 때 드는 체력.
@export var pull_cost: float = 6.0
## 이만큼 가까워야 뽑을 수 있다.
@export var pull_reach: float = 1.1
## 뽑는 데 걸리는 시간 = 기본 + 등급 × 한 단계. 등급이 높을수록 오래 버틴다.
@export var pull_time: float = 0.45
@export var pull_step: float = 0.42
## 꽂힌 검끼리, 그리고 영주와 떨어진 거리.
@export var hilt_spacing: float = 2.2
@export var hilt_clear: float = 2.5

@export_group("낮: 제단")
## 이 구역부터(0부터 센다) 낮마다 숫돌 제단이 하나 선다.
@export var altar_from_zone: int = 1
@export var altar_reach: float = 1.3
## 공짜 뽑기(정예가 준다)를 모아 둘 수 있는 수.
@export var max_free_pulls: int = 3

@export_group("밤")
@export var night_length: float = 75.0
## 날이 밝을 때 되찾는 체력.
@export var heal_per_dawn: float = 50.0
## 적이 나오는 간격 = (처음 - 줄어듦 × 밤의 진행) / (1 + 구역 × 구역 배수).
@export var spawn_start: float = 1.5
@export var spawn_drop: float = 0.8
@export var spawn_zone: float = 0.16
@export var spawn_first: float = 1.5
@export var max_enemies: int = 70
## 늑대와 거인이 나올 확률(구역마다 오르고 상한이 있다). 나머지는 망령.
@export var wolf_chance: Vector3 = Vector3(0.3, 0.03, 0.55)
@export var giant_chance: Vector3 = Vector3(0.04, 0.02, 0.25)
## 밤이 이만큼 지난 뒤부터 거인이 나온다(0~1).
@export var giant_after: float = 0.25
## 마지막 구역에서 밤이 이만큼 남으면 언덕지기가 나온다(0~1).
@export var boss_at: float = 0.55
## 적이 영주를 때리는 거리(서로의 크기에 더한다).
@export var enemy_reach: float = 0.42

@export_group("밤: 새 적(11단계)")
## 구역마다 새 적이 나올 확률(길이는 구역 수, 0부터 센다). 망령·늑대·거인의 확률은 남은 몫(1 - 새 적의 합) 안에서 나눈다.
@export var archer_chance: PackedFloat32Array = PackedFloat32Array([0, 0.06, 0.07, 0.08, 0.08, 0.09, 0.09, 0.1, 0.1, 0.1])
@export var shield_chance: PackedFloat32Array = PackedFloat32Array([0, 0, 0.06, 0.07, 0.07, 0.08, 0.08, 0.09, 0.09, 0.1])
@export var charger_chance: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0.05, 0.06, 0.06, 0.07, 0.07, 0.08, 0.08])
@export var bomber_chance: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0.06, 0.07, 0.07, 0.08, 0.08, 0.08])
@export var caller_chance: PackedFloat32Array = PackedFloat32Array([0, 0, 0, 0, 0, 0.05, 0.05, 0.05, 0.06, 0.06])
## 한 밤에 나오는 부르는 자의 수 상한(넘으면 망령이 나온다).
@export var caller_max: int = 2

@export_group("밤: 공격 표")
## 구역마다 밤의 공격 표 수(docs/attack_tokens.md). 표를 가진 적만 영주를 때린다. 0이면 표 없이 모두 덤빈다.
@export var attack_tokens: PackedInt32Array = PackedInt32Array([4, 4, 5, 5, 6, 6, 7, 8, 9, 10])
## 기다림 거리 = 사거리(적 크기 + enemy_reach) + 이것. 이 안에 들면 표를 청하고, 못 받으면 이 둘레에 머문다.
@export var token_wait_gap: float = 1.5
## 기다리는 적이 옆으로 도는 빠르기(이동 빠르기 × 이것).
@export var token_strafe: float = 0.35
## 때리고 돌려놓은 표가 다시 나가기까지(초).
@export var token_cooldown: float = 0.5
## 표를 들고 이만큼(초) 못 때리면 내려놓는다(식는 시간 없이).
@export var token_hold_max: float = 2.5
## 표를 받고 때리기까지 적어도 이만큼(초). 그동안 눈이 번쩍인다(누가 덤빌지 보이게).
@export var token_warn: float = 0.25
## 기다리는 적이 둘레에서 벗어난 거리를 이 시간(초)에 걸쳐 되돌린다. 작으면 딱딱하고 크면 무르다.
@export var token_settle: float = 0.3

@export_group("밤: 목표와 구역 규칙(12단계)")
## 2~9구역(1번부터 8번)의 밤 목표와 구역 규칙을 이 목록에서 고른다(13단계 갈림길 전까지는 Rules.rng로). 1구역은 버티기, 마지막 구역은 언덕지기.
## 목표: survive 버티기, defend 지키기, hunt 사냥, siege 포위. 구역 규칙: "" 없음, fog 짙은 안개, embers 불씨 땅, graves 무덤.
@export var night_goals: PackedStringArray = PackedStringArray(["survive", "defend", "hunt", "siege"])
@export var zone_rules: PackedStringArray = PackedStringArray(["", "fog", "embers", "graves"])
@export_subgroup("지키기")
## 봉화 체력(× 구역 체력 배수), 자리(싸움터 가운데에서 떨어진 칸), 크기(칸, 이 안으로는 아무도 못 들어온다).
@export var beacon_hp: float = 300.0
@export var beacon_offset: Vector2 = Vector2(0.0, -3.0)
@export var beacon_radius: float = 0.5
## 새로 나온 적 중 봉화를 노리는 몫(표 없이 봉화를 때린다). 이 종류만 노린다.
@export var beacon_share: float = 0.4
@export var beacon_kinds: PackedStringArray = PackedStringArray(["wraith", "wolf", "giant", "shield"])
## 봉화가 꺼지면 새벽 회복에 곱한다.
@export var beacon_out_heal: float = 0.5
@export_subgroup("사냥")
## 밤이 이만큼 지나면(0~1) 우두머리가 나온다. 이 구역에서 나올 수 있는 이 종류 중 하나를 정예로 하고 체력은 이 배수(정예 배수 대신).
@export var hunt_at: float = 0.2
@export var hunt_hp: float = 4.0
@export var hunt_kinds: PackedStringArray = PackedStringArray(["wraith", "wolf", "giant", "archer", "shield", "charger"])
@export_subgroup("포위")
## 적이 한 변에서만 나오고 이만큼(초)마다 다른 변으로 바뀐다. 나오는 빠르기 배수, 밤 길이.
@export var siege_switch: float = 20.0
@export var siege_spawn: float = 1.4
@export var siege_night: float = 60.0
@export_subgroup("보상(새벽)")
## 목표를 이루면 다음 낮의 공짜 뽑기(max_free_pulls까지)와 판이 끝날 때 더하는 조각.
@export var defend_free: int = 1
@export var hunt_free: int = 1
@export var hunt_shards: int = 3
@export var siege_free: int = 1
@export_subgroup("불씨 땅")
## ember_every초마다 ember_count곳이 ember_warn초 미리 보이고(반지름 ember_radius칸) ember_burn초 동안 탄다. 안에 있으면 초당 피해.
@export var ember_every: float = 8.0
@export var ember_count: int = 3
@export var ember_warn: float = 1.0
@export var ember_radius: float = 1.5
@export var ember_burn: float = 4.0
@export var ember_lord: float = 4.0
@export var ember_enemy: float = 8.0
@export_subgroup("무덤")
## 쓰러진 망령이 이 확률로 grave_delay초 뒤 한 번 다시 일어난다(체력 × grave_hp).
@export var grave_chance: float = 0.25
@export var grave_delay: float = 3.0
@export var grave_hp: float = 0.5

@export_group("갈림길과 낮 사건(13단계)")
@export_subgroup("갈림길")
## 새벽(1~9구역 뒤)에 다음 구역의 길 두 개를 보인다. 길마다 다음 밤의 목표·구역 규칙(위 목록에서)과 보상 하나.
## 보상 id(아래 두 가중치와 순서가 같다): pulls 공짜 뽑기, heal 체력, whet 두 칸 검 내구 모두 채움, luck 다음 낮 운, shards 판이 끝날 때 조각.
@export var path_rewards: PackedStringArray = PackedStringArray(["pulls", "heal", "whet", "luck", "shards"])
## 쉬운 길(어려움 0)과 가장 어려운 길(어려움 2)의 보상 가중치. 사이는 어려움 / 2로 섞는다.
## 어려움 = 목표가 path_hard_goals면 +1, 구역 규칙이 있으면 +1. 어려운 길일수록 좋은 보상(공짜 뽑기, 운)이 잘 붙는다.
@export var path_reward_weight: PackedFloat32Array = PackedFloat32Array([1, 3, 3, 1, 2])
@export var path_reward_weight_hard: PackedFloat32Array = PackedFloat32Array([4, 1, 1, 3, 2])
@export var path_hard_goals: PackedStringArray = PackedStringArray(["hunt", "siege"])
## 보상의 양: 공짜 뽑기 +2(max_free_pulls까지), 체력 +60, 다음 낮 운 ×1.3, 판이 끝날 때 조각 +5.
@export var reward_pulls: int = 2
@export var reward_heal: float = 60.0
@export var reward_luck: float = 1.3
@export var reward_shards: int = 5
@export_subgroup("낮 사건")
## 이 구역부터(0부터 센다) 낮마다 사건 하나가 선다. 이 목록에서 같은 확률로 고른다.
## smith 떠돌이 대장장이, cursed 저주받은 손잡이, pilgrim 순례자, seer 점쟁이.
@export var event_from_zone: int = 1
@export var event_kinds: PackedStringArray = PackedStringArray(["smith", "cursed", "pilgrim", "seer"])
## 이만큼(칸) 가까우면 E로 쓴다(저주받은 손잡이는 뽑기 거리 pull_reach).
@export var event_reach: float = 1.4
## 대장장이: 체력을 내면 쥔 검의 내구를 다 채우고, 이번 밤 그 검의 피해 + smith_damage(0.15 = 15%).
@export var smith_cost: float = 15.0
@export var smith_damage: float = 0.15
## 저주받은 손잡이: 체력 없이 뽑고 운 ×cursed_luck. 대신 이번 밤 적이 나오는 빠르기 ×cursed_enemies, 뽑은 검의 최대 내구 ×cursed_durability.
@export var cursed_luck: float = 2.0
@export var cursed_enemies: float = 1.25
@export var cursed_durability: float = 0.5
## 순례자: 칸의 검 하나(쥐지 않은 칸, 없으면 쥔 검)를 바치면 체력을 최대치 × pilgrim_heal만큼 채우고 공짜 뽑기 + pilgrim_free.
@export var pilgrim_heal: float = 0.5
@export var pilgrim_free: int = 1
## 점쟁이: 체력을 내면 오늘 손잡이의 참된 조짐을 모두 보인다(14단계).
@export var seer_cost: float = 10.0

@export_group("정예")
## 밤이 이만큼 지나면(0~1) 정예가 하나 온다.
@export var elite_at: float = 0.4
@export var elite_hp: float = 4.0
@export var elite_damage: float = 1.5
@export var elite_size: float = 1.3
## 이 구역부터 정예가 거인일 수 있다. 확률.
@export var elite_giant_from: int = 2
@export var elite_giant_chance: float = 0.4


## 새 적(나오는 순서대로).
const EXTRA_KINDS: Array[StringName] = [&"archer", &"shield", &"charger", &"bomber", &"caller"]


## 길의 어려움(0~2): 목표가 사냥·포위면 +1, 구역 규칙이 있으면 +1.
func path_hardness(goal: StringName, rule: StringName) -> int:
	return (1 if path_hard_goals.has(String(goal)) else 0) + (0 if rule == &"" else 1)


## 그 어려움의 길에 붙는 보상 가중치(path_rewards와 같은 순서).
func path_weights(hard: int) -> PackedFloat32Array:
	var k: float = clampf(hard / 2.0, 0.0, 1.0)
	var out := PackedFloat32Array()
	for i in path_rewards.size():
		var a: float = path_reward_weight[i] if i < path_reward_weight.size() else 1.0
		var b: float = path_reward_weight_hard[i] if i < path_reward_weight_hard.size() else a
		out.append(lerpf(a, b, k))
	return out


## 그 구역에서 새 적 kind가 나올 확률.
func extra_chance(kind: StringName, zone: int) -> float:
	var a: PackedFloat32Array
	match kind:
		&"archer":
			a = archer_chance
		&"shield":
			a = shield_chance
		&"charger":
			a = charger_chance
		&"bomber":
			a = bomber_chance
		&"caller":
			a = caller_chance
	if a.is_empty():
		return 0.0
	return a[clampi(zone, 0, a.size() - 1)]
