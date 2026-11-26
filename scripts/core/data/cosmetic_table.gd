class_name CosmeticTable
extends Resource
## 영주 꾸미기 항목 표(docs/cosmetics.md). data/cosmetics.tres 한 장(scripts/debug/build_cosmetics.gd가 만든다, 손으로 고치지 않는다).
## 자리마다 첫 항목이 기본(처음부터 · 아무것도 안 바꾼 모습)이다.

const SLOTS: Array[StringName] = [&"cape", &"head", &"slash"]
const SLOT_NAMES: Dictionary = {&"cape": "망토", &"head": "머리", &"slash": "베기 빛"}

@export var items: Array[CosmeticItem] = []


func item(id: StringName) -> CosmeticItem:
	for it in items:
		if it.id == id:
			return it
	return null


func of_slot(slot: StringName) -> Array[CosmeticItem]:
	var out: Array[CosmeticItem] = []
	for it in items:
		if it.slot == slot:
			out.append(it)
	return out


## 그 자리의 기본 항목 id(첫 항목).
func default_of(slot: StringName) -> StringName:
	for it in items:
		if it.slot == slot:
			return it.id
	return &""
