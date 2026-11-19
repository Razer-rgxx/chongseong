class_name FieldLayout
extends RefCounted
## 들판(16단계, docs/village.md 16)의 자리와 값. 자리는 여기 하나에만 둔다. 모든 자리는 칸 좌표(1칸 = 2m).
## 위쪽(y 작은 쪽)이 북쪽이다: 언덕 발치는 북, 마을 문은 남.

const SIZE: Vector2i = Vector2i(110, 110)
const WORLD: float = 220.0

const AREA_ORDER: PackedStringArray = ["foot", "watchtower", "grove", "old_field", "brook", "road"]
const AREAS: Dictionary = {
	&"foot": Rect2(30, 0, 50, 24),
	&"watchtower": Rect2(78, 24, 32, 28),
	&"grove": Rect2(0, 22, 38, 30),
	&"old_field": Rect2(58, 66, 52, 44),
	&"brook": Rect2(0, 52, 110, 14),
	&"road": Rect2(0, 0, 110, 110),
}
const AREA_NAMES: Dictionary = {
	&"road": "언덕길", &"old_field": "옛 싸움터", &"watchtower": "무너진 망루",
	&"brook": "개울가", &"grove": "검은 숲 가장자리", &"foot": "언덕 발치",
}

## 흙길이 지나는 점(남 → 북). 개울은 x 52 근처에서 돌다리로 건넌다.
const ROAD: PackedVector2Array = [
	Vector2(55, 109), Vector2(55, 99), Vector2(50, 89), Vector2(46, 79), Vector2(48, 68),
	Vector2(52, 59), Vector2(58, 49), Vector2(60, 39), Vector2(55, 28), Vector2(55, 17), Vector2(55, 5),
]

const GATE: Vector2 = Vector2(55, 107.2)
const TRAILHEAD: Vector2 = Vector2(55, 4.6)
const START: Vector2 = Vector2(55, 103)
const GATE_GAP: Vector2 = Vector2(52, 58)   ## 목책이 비는 x 범위

const BRIDGE_X: float = 104.0   ## 돌다리 가운데(m)
const TOWER: Vector2 = Vector2(92, 36)

## 유품 상자 id → [칸 자리, 조각]. 한 번 찾으면 끝.
const CACHES: Dictionary = {
	"cache_1": [Vector2(88, 86), 20], "cache_2": [Vector2(100, 74), 30],
	"cache_3": [Vector2(88, 42), 25], "cache_4": [Vector2(102, 46), 40],
	"cache_5": [Vector2(12, 42), 15], "cache_6": [Vector2(30, 44), 25],
	"cache_7": [Vector2(14, 60), 10], "cache_8": [Vector2(70, 14), 35],
}

## 흩어진 조각 후보 16곳. 판마다 GLINT_ACTIVE곳이 새로 생긴다. 하나에 GLINT_MIN~GLINT_MAX 조각.
const GLINTS: PackedVector2Array = [
	Vector2(40, 100), Vector2(70, 96), Vector2(30, 84), Vector2(90, 98), Vector2(100, 84), Vector2(70, 74),
	Vector2(40, 72), Vector2(20, 70), Vector2(24, 62), Vector2(12, 52), Vector2(46, 40), Vector2(70, 40),
	Vector2(100, 30), Vector2(76, 24), Vector2(30, 10), Vector2(92, 12),
]
const GLINT_ACTIVE: int = 4
const GLINT_MIN: int = 2
const GLINT_MAX: int = 5

const LORE_REWARD: int = 30

## 이야기 비석 id → [칸 자리, 이름, 글]. 글은 줄바꿈(\n)으로 띠에 2~3줄.
const STONES: Dictionary = {
	"stone_1": [Vector2(60, 100), "길머리 비석", "언덕으로 오르는 이는 많았으나\n내려온 이는 적었다."],
	"stone_2": [Vector2(72, 80), "옛 싸움터의 비석", "검을 든 병사 삼백이 여기서 쓰러졌다.\n그들의 검은 아직 풀 사이에 서 있다.\n뽑는 이는 이름을 잃는다고 한다."],
	"stone_3": [Vector2(46, 62), "개울가의 비석", "물은 언덕에서 내려와 마을로 간다.\n옛 사람은 이 물에 칼을 씻고 맹세했다."],
	"stone_4": [Vector2(84, 44), "망루의 비석", "봉화가 꺼진 날 밤, 망루지기는 끝내 내려오지 않았다.\n불을 지키는 일이 그의 맹세였다."],
	"stone_5": [Vector2(20, 30), "검은 숲의 비석", "숲은 해마다 한 걸음씩 길로 다가온다.\n마른 나무 사이에서 소리를 들어도 돌아보지 마라."],
	"stone_6": [Vector2(44, 12), "발치의 비석", "여기서부터 길은 언덕의 것이다.\n칼이 부르면 오르고, 부러지면 다시 내려오라."],
}

## 들판에서 영주가 못 들어가는 곳(칸 단위): 둘레의 숲·벼랑과 목책, 망루, 수레, 쓰러진 거목, 돌다리 난간.
const BORDER_RECTS: Array[Rect2] = [
	Rect2(0, 0, 3, 110), Rect2(107, 0, 3, 110), Rect2(0, 0, 110, 2),
	Rect2(0, 108.3, 52, 2), Rect2(58, 108.3, 52, 2),
]


static func area_at(c: Vector2) -> StringName:
	for id in AREA_ORDER:
		if (AREAS[id] as Rect2).has_point(c):
			return StringName(id)
	return &"road"
