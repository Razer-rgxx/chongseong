class_name VillageData
extends Resource
## 마을 컨텐츠의 수치(15단계, docs/village.md): 의뢰판, 떠돌이 상인, 수련장, 주민의 대사. data/village.tres 한 장.
## 판 밖의 랜덤(의뢰 고르기, 상인의 물건)은 Meta.rng를 쓴다.

@export_group("의뢰판")
## 판에 붙는 의뢰 수.
@export var board_size: int = 3
## 의뢰 표(종류마다 쉬운 것·어려운 것 여러 줄). 판에는 종류가 겹치지 않게 붙는다.
@export var quests: Array[QuestData] = []

@export_group("떠돌이 상인")
## 좌판에 놓는 물건 수(goods 중에서, 판이 끝날 때마다 바뀐다).
@export var stock_size: int = 3
@export var goods: Array[GoodsData] = []
## 운 부적이 듣는 구역 수(1구역부터).
@export var charm_zones: int = 2

@export_group("수련장")
## 띠에 보이는 피해 합의 시간(초).
@export var yard_window: float = 5.0

@export_group("주민")
@export var villagers: Array[VillagerData] = []


func goods_by_id(id: StringName) -> GoodsData:
	for g in goods:
		if g.id == id:
			return g
	return null


func villager(id: StringName) -> VillagerData:
	for v in villagers:
		if v.id == id:
			return v
	return null
