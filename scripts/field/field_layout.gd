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


## ---- 들판 싸움(17단계, docs/outside.md). 수치는 여기 하나에만 둔다.
## 적 하나를 쓰러뜨릴 때의 조각, 무리를 다 쓰러뜨릴 때의 조각(범위, Meta.rng).
const PACK_KILL_SHARDS: int = 1
const PACK_CLEAR_MIN: int = 5
const PACK_CLEAR_MAX: int = 10
## 영주가 무리 제자리에서 이 칸 안에 들면 덤비고, 이 칸 넘게 멀어지면 돌아가며 체력이 찬다.
const PACK_AGGRO: float = 10.0
const PACK_LEASH: float = 25.0
## 서성이는 빠르기(걷는 빠르기의 몇 배)와 목표를 바꾸는 간격(초, 최소·최대), 돌아갈 때의 빠르기 배수.
const PACK_WANDER_SPEED: float = 0.3
const PACK_WANDER_WAIT: Vector2 = Vector2(1.5, 4.0)
const PACK_RETURN_SPEED: float = 1.6
## 돌아가는 동안 체력이 가득 차기까지 걸리는 시간(초).
const PACK_HEAL_TIME: float = 2.0
## 쓰러져 마을에서 깰 때의 자리(북문 앞, 마을 칸 단위)는 lobby의 gate_at 아래쪽 이 만큼.
const WAKE_OFFSET: Vector2 = Vector2(0.0, 1.8)

## 무리 id → {at: 제자리(칸), wander: 서성일 반지름(칸), zone: 세기 구역(1~6, RunData의 구역 배수), foes: [[적 id, 수], …]}.
## 한 무리는 3~6마리. 자리는 막힌 곳(FieldBuilder.build의 rects·circles)과 길·상자·비석을 피해 그 곳(AREAS) 안에 둔다.
const PACKS: Dictionary = {
	"road_south": {"at": Vector2(34, 92), "wander": 3.0, "zone": 1, "foes": [[&"wraith", 3]]},
	"road_mid": {"at": Vector2(30, 76), "wander": 3.5, "zone": 2, "foes": [[&"wolf", 2], [&"wraith", 2]]},
	"brook_east": {"at": Vector2(82, 58), "wander": 3.5, "zone": 2, "foes": [[&"wraith", 2], [&"archer", 2]]},
	"old_field": {"at": Vector2(84, 78), "wander": 4.0, "zone": 3, "foes": [[&"wraith", 2], [&"shield", 1], [&"charger", 1], [&"wolf", 1]]},
	"tower": {"at": Vector2(90, 28), "wander": 3.5, "zone": 4, "foes": [[&"archer", 2], [&"shield", 2], [&"wolf", 1]]},
	"grove": {"at": Vector2(8, 28), "wander": 3.0, "zone": 5, "foes": [[&"wolf", 3], [&"bomber", 1], [&"wraith", 2]]},
	"foot": {"at": Vector2(40, 16), "wander": 3.5, "zone": 6, "foes": [[&"giant", 1], [&"charger", 2], [&"archer", 1]]},
	"foot_east": {"at": Vector2(74, 8), "wander": 3.5, "zone": 6, "foes": [[&"caller", 1], [&"wraith", 3], [&"shield", 1]]},
}


## ---- 들판 보스(18단계, docs/outside.md). 무덤 기사는 옛 싸움터 가운데에 한 마리 선다.
const BOSS_ID: StringName = &"grave_knight"
const BOSS_AT: Vector2 = Vector2(84, 96)
## 영주가 제자리에서 이 칸 안에 들면 깨어나고, 이 칸 넘게 멀어지면 돌아가 체력이 다 찬다(돌아가는 빠르기와 시간은 PACK_RETURN_SPEED·PACK_HEAL_TIME).
const BOSS_WAKE: float = 8.0
const BOSS_LEASH: float = 14.0
## 불려 나오는 망령의 세기 구역(1부터, RunData의 구역 배수. 옛 싸움터).
const BOSS_ZONE: int = 3
## 처음 쓰러뜨리면 받는 조각, 그다음부터 받는 조각. 쓰러뜨릴 때마다 운 부적(상인의 것, Meta.pack)이 하나 든다.
const BOSS_FIRST_SHARDS: int = 80
const BOSS_SHARDS: int = 30
const BOSS_CHARM: StringName = &"charm"


## ---- 지하 무덤 입구(19단계, docs/outside.md). 검은 숲 가장자리의 무너진 무덤.
## 모양이 서는 곳(막힘, 칸 단위), E를 누르는 자리, 나오거나 쓰러져 깰 자리(입구 앞).
const CRYPT_BLOCK: Rect2 = Rect2(28.5, 26.0, 7.0, 3.6)
const CRYPT_DOOR: Vector2 = Vector2(32, 31)
const CRYPT_WAKE: Vector2 = Vector2(32, 33.5)


static func area_at(c: Vector2) -> StringName:
	for id in AREA_ORDER:
		if (AREAS[id] as Rect2).has_point(c):
			return StringName(id)
	return &"road"
