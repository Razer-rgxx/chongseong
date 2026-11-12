class_name TierTable
extends Resource
## 설계함 등급 8개(흔함~무한). 배열은 모두 등급 순서대로 8칸이다.

@export var names: PackedStringArray
## 1/N의 N. 높은 등급부터 차례로 굴린다(흔함은 나머지).
@export var odds: PackedFloat64Array
@export var colors: PackedColorArray
@export var cost_wood: PackedInt32Array
@export var cost_stone: PackedInt32Array
## 생산 건물이 아침마다 주는 양.
@export var production: PackedInt32Array
## 모집 건물의 손님 운.
@export var visitor_luck: PackedFloat32Array
## 이 등급부터 큰 연출을 튼다(신화 = 3).
@export var reveal_from: int = 3
## 이 등급의 모집 건물에는 이 등급 이상의 손님만 온다(무한 건물은 영웅 이상). -1이면 없음.
@export var min_visitor_grade: PackedInt32Array
