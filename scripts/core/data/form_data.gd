class_name FormData
extends Resource
## 검의 형태(단검, 장검, 대검, 세검)와 맨손. 영주의 기본 수치(LordData)에 곱한다.

@export var display_name: String = ""
@export var damage: float = 1.0
## 휘두르는 빠르기. 클수록 간격이 짧다.
@export var speed: float = 1.0
@export var reach: float = 1.0
@export var arc: float = 1.0
@export var durability: float = 1.0
## 몇 번째 휘두르기가 큰 베기인지(연타 수).
@export_range(1, 5) var combo: int = 3
@export var knockback: float = 1.0
## 한 번에 벨 수 있는 적의 수. 0이면 제한 없다.
@export var pierce: int = 0
## 화면에 그릴 칼날 길이(m)와 두께(m).
@export var blade_length: float = 1.3
@export var blade_width: float = 0.08
@export_multiline var description: String = ""
