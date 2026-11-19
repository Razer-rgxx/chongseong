class_name GoodsData
extends Resource
## 떠돌이 상인의 물건 하나(15단계, docs/village.md 15.4). 산 것은 다음 판 하나에만 쓰인다(Meta.pack).
## id: ticket(공짜 뽑기 +value), whetstone(처음 쥔 검 최대 내구 ×(1 + value)), charm(1~charm_zones구역 낮 뽑기 운 ×value),
## note(1구역 낮 손잡이 조짐이 참으로 보인다), bread(최대 체력 +value).

@export var id: StringName = &""
@export var display_name: String = ""
## 창에 쓰는 한 줄 설명.
@export var text: String = ""
@export var value: float = 0.0
## 조각.
@export var price: int = 20
