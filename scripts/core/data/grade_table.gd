class_name GradeTable
extends Resource
## 사람 등급 6개(병졸~군신). 배열은 모두 등급 순서대로 6칸이다.

@export var names: PackedStringArray
## 1/N의 N. 높은 등급부터 차례로 굴린다(병졸은 나머지라 1).
@export var odds: PackedFloat64Array
@export var power: PackedFloat32Array
@export var colors: PackedColorArray
## 더 캐묻기에 성공해 한 칸 오를 확률. 군신은 0.
@export var press_chance: PackedFloat32Array
## 영주가 쓰러질 때 대신 막아설 확률.
@export var guard_chance: PackedFloat32Array
## 이 등급부터 대신 막아서도 죽지 않고 다친다(영웅 = 4).
@export var guard_survive_from: int = 4
## 이 등급부터 기술을 쓴다(장수 = 3).
@export var skill_from: int = 3

@export_group("기척")
## 겉으로 보이는 등급이 맞을 확률, 한 칸 낮게 보일 확률. 나머지는 한 칸 높게.
@export var hint_exact: float = 0.55
@export var hint_low: float = 0.25
## 이 등급부터 몸에 빛이 돈다(정예 = 2).
@export var aura_from: int = 2

@export_group("대사")
@export var hint_lines: PackedStringArray
## 한 칸 오를 때마다 나오는 말. 0번은 비워 둔다(첫인사는 ClassData).
@export var step_lines: PackedStringArray
@export var final_lines: PackedStringArray
