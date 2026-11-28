class_name HillZoneData
extends Resource
## 언덕 재설계(docs/hill_events.md)의 수치. data/hill_zone.tres 한 장. 거리는 칸, 시간은 초.

## 구역 안에 꽂힌 검 수.
@export var swords: int = 12
## 검이 놓이는 둘레(가운데에서 이 반지름 안). 검끼리는 min_gap보다 가깝지 않다.
@export var radius: float = 22.0
@export var min_gap: float = 6.0
## 이 거리 안의 검끼리 잇는다. 한 검에 이어진 수는 최대 max_links.
@export var link_dist: float = 13.0
@export var max_links: int = 3
## 뽑으면 이웃이 하나 깨어나고, 이 확률로 둘.
@export var wake_two: float = 0.25
## 깨어남 한 번에 오르는 등급, 오를 수 있는 최대.
@export var wake_grade: int = 1
@export var wake_max: int = 2
## 깨어난 검 주인이 다가오는 빠르기(칸/초)와 혼자 찾아오는 시간.
@export var owner_speed: float = 2.0
@export var owner_timeout: float = 60.0
## 주인이 이만큼 가까이 오면 사건이 시작된다.
@export var owner_reach: float = 2.0
## 사건 비율: 결투, 거래, 추격.
@export var event_weights: PackedFloat32Array = PackedFloat32Array([0.45, 0.3, 0.25])
## 처음 등급 비율(0 = 가장 낮은 등급).
@export var grade_weights: PackedFloat32Array = PackedFloat32Array([0.45, 0.3, 0.15, 0.07, 0.025, 0.005])
## 결투 주인 체력 배수: 등급마다 이만큼 곱한다.
@export var duel_hp_step: float = 1.5
## 결투에 지면 잃는 체력 비율.
@export var duel_lose_hp: float = 0.3
## 거래 요구: 최대 체력 감소량, 내구 비율.
@export var trade_max_hp: float = 20.0
@export var trade_durability: float = 0.5
## 추격 무리 수와 놓치는 거리.
@export var chase_min: int = 3
@export var chase_max: int = 5
@export var chase_escape: float = 30.0
