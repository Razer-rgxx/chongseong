class_name GradeTable
extends Resource
## 검 등급 6단계. 뽑기는 높은 등급부터 "운 / N" 확률로 차례로 굴린다(보장은 없다).

@export var names: PackedStringArray = PackedStringArray(["흔함", "귀함", "전설", "신화", "초월", "무한"])
## 1/N. 흔함은 쓰지 않는다.
@export var odds: PackedFloat64Array = PackedFloat64Array([1.0, 6.0, 40.0, 200.0, 2000.0, 50000.0])
@export var damage_mult: PackedFloat32Array = PackedFloat32Array([1.0, 1.25, 1.6, 2.0, 3.0, 5.0])
## 장검 기준 내구. 형태의 durability를 곱한다.
@export var durability: PackedFloat32Array = PackedFloat32Array([80, 110, 150, 200, 300, 450])
@export var colors: PackedColorArray = PackedColorArray()
## 이 등급부터 큰 연출(영상, 없으면 번쩍임).
@export var reveal_from: int = 2
