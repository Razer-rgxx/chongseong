class_name MetaData
extends Resource
## 판과 판 사이(마을)의 수치. 조각을 얼마나 주고, 대장간과 성소의 강화가 얼마나 들고 몇 %로 붙는지.

@export_group("조각")
## 처치 몇 마리에 조각 하나.
@export var kills_per_shard: int = 4
## 넘은 구역 하나에.
@export var per_zone: int = 10
## 정상까지 올랐을 때 더 주는 조각.
@export var win_bonus: int = 60
## 처치 연쇄(2026-11-24): 연쇄가 chain_every의 배수가 될 때마다 조각 chain_shards(언덕에서 판이 끝날 때 받는다).
@export var chain_every: int = 5
@export var chain_shards: int = 3
## 등급별(흔함 … 무한): 판 안에서 부러진 검, 제단에서 녹인 검.
@export var broken: PackedInt32Array = PackedInt32Array([1, 3, 10, 30, 100, 500])
@export var melt: PackedInt32Array = PackedInt32Array([2, 6, 20, 60, 200, 1000])
@export var elite: int = 15

@export_group("마을 키우기: 재료 (2026-11-21)")
## 언덕 판이 끝날 때 넘긴 구역마다 받는 나무·돌·쇠, 정예 하나에 쇠, 꼭대기까지 이기면 더 받는 쇠.
@export var run_wood_per_zone: int = 2
@export var run_stone_per_zone: int = 2
@export var run_iron_per_zone: int = 1
@export var run_iron_per_elite: int = 1
@export var run_iron_win: int = 5

@export_group("마을 키우기: 마을 단계 (2026-11-21)")
## 개척지 → 마을 → 읍 → 성읍. 단계마다 지은 건물 수(검 보관집 포함)와 사는 사람 수, 성읍은 돌담도.
@export var tier_names: PackedStringArray = PackedStringArray(["개척지", "마을", "읍", "성읍"])
@export var tier_buildings: PackedInt32Array = PackedInt32Array([0, 2, 5, 7])
@export var tier_residents: PackedInt32Array = PackedInt32Array([0, 1, 3, 6])
## 단계마다 바깥 터 길가에 켜지는 등불 수와 마을을 걷는 사람 수.
@export var tier_lights: PackedInt32Array = PackedInt32Array([0, 2, 4, 6])
@export var tier_walkers: PackedInt32Array = PackedInt32Array([0, 2, 4, 6])
## 열리는 것(마을 키우기 5단계): 단계마다 언덕을 몇 구역부터 오를 수 있는지(가장 깊은 곳), 풀무간이 벼려 주는 검의 등급.
@export var tier_start_zone: PackedInt32Array = PackedInt32Array([1, 3, 5, 7])
@export var tier_forge_grade: PackedInt32Array = PackedInt32Array([0, 1, 1, 2])

@export_group("마을: 검 보관집 (2026-11-21)")
## 검 보관집을 짓는 값(조각). 마을 북동쪽 빈 터에 집이 올라가고, 그 집에서 검집을 산다.
@export var storage_house_cost: int = 80
## 보관집에서 사는 검집 단계별 값(조각). 1단계: 검 칸 3, 2단계: 4(언덕 판·들판·무덤 모두).
@export var storage_costs: PackedInt32Array = PackedInt32Array([100, 220])

@export_group("대장간: 검집")
## 이 등급 이상으로 뽑아 본 검만 검집에 넣는다(2 = 전설).
@export var sheath_min_grade: int = 2
@export var sheath_max: int = 10
## 강화 값 = 기본 × (지금 단계 + 1).
@export var sheath_cost: int = 30
## 지금 단계에서 다음 단계로 오를 확률(%).
@export var sheath_rates: PackedFloat32Array = PackedFloat32Array([95, 90, 80, 70, 60, 50, 40, 30, 20, 10])
## 이 단계부터는 실패하면 한 단계 내려간다.
@export var sheath_drop_from: int = 5
@export var sheath_damage: float = 0.08
@export var sheath_durability: float = 0.1
## 이 단계에 처음 닿으면 각인이 하나 붙는다.
@export var sheath_ins_levels: PackedInt32Array = PackedInt32Array([5, 10])

@export_group("성소: 축복")
@export var bless_keys: PackedStringArray = PackedStringArray(["hp", "luck", "cost", "heal"])
@export var bless_names: PackedStringArray = PackedStringArray(["단단한 몸", "언덕의 운", "가벼운 손", "새벽의 숨"])
@export var bless_max: PackedInt32Array = PackedInt32Array([10, 10, 4, 5])
## 한 단계마다: 최대 체력 +10, 뽑기 운 +8%, 뽑을 때 체력 -1, 새벽 회복 +10.
@export var bless_step: PackedFloat32Array = PackedFloat32Array([10, 0.08, 1, 10])
@export var bless_cost: int = 20
@export var bless_rates: PackedFloat32Array = PackedFloat32Array([90, 80, 70, 60, 50, 40, 35, 30, 25, 20])
