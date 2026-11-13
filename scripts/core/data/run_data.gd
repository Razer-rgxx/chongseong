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
@export var pull_cost: float = 10.0
## 이만큼 가까워야 뽑을 수 있다.
@export var pull_reach: float = 1.1
## 뽑는 데 걸리는 시간 = 기본 + 등급 × 한 단계. 등급이 높을수록 오래 버틴다.
@export var pull_time: float = 0.45
@export var pull_step: float = 0.42
## 꽂힌 검끼리, 그리고 영주와 떨어진 거리.
@export var hilt_spacing: float = 2.2
@export var hilt_clear: float = 2.5

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
