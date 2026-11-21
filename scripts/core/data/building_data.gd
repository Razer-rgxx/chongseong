class_name BuildingData
extends Resource
## 마을 건물 하나(2026-11-21 마을 키우기 2단계, docs/village_growth.md). 데이터는 data/buildings/*.tres(파일 이름 순서).
## 바깥 터(동쪽 목책 너머)의 제 자리(plot)에 재료로 짓는다. 지으면 집이 아래부터 한 조각씩 올라간다(BuildingPlot).

@export var id: StringName = &""
@export var display_name: String = ""
## 하는 일(눈에 안 보이는 것만). 창에 한 줄.
@export var desc: String = ""
@export_group("값(재료)")
@export var cost_wood: int = 0
@export var cost_stone: int = 0
@export var cost_iron: int = 0
@export_group("자리와 생김새")
## 집 가운데(마을 칸 좌표)와 너비 × 깊이(m), 앞이 보는 쪽(마을 칸 방향).
@export var plot: Vector2 = Vector2.ZERO
@export var size: Vector2 = Vector2(4.5, 4.0)
@export var facing: Vector2 = Vector2(-1, 0)
## 생김새: cottage(오두막), woodcutter(나무꾼 움막: 열린 헛간과 장작), mason(석공 마당: 돌 헛간과 다듬은 돌).
@export var kind: StringName = &"cottage"
@export_group("하는 일")
## 언덕 판이 끝날 때마다 모아 두는 재료.
@export var made_wood: int = 0
@export var made_stone: int = 0
@export var made_iron: int = 0
## 살 수 있는 주민 수(3단계).
@export var housing: int = 0


func cost() -> Dictionary:
	var c := {}
	if cost_wood > 0:
		c[&"wood"] = cost_wood
	if cost_stone > 0:
		c[&"stone"] = cost_stone
	if cost_iron > 0:
		c[&"iron"] = cost_iron
	return c


func made() -> Dictionary:
	return {&"wood": made_wood, &"stone": made_stone, &"iron": made_iron}
