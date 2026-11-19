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
## 등급별(흔함 … 무한): 판 안에서 부러진 검, 제단에서 녹인 검.
@export var broken: PackedInt32Array = PackedInt32Array([1, 3, 10, 30, 100, 500])
@export var melt: PackedInt32Array = PackedInt32Array([2, 6, 20, 60, 200, 1000])
@export var elite: int = 15

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
