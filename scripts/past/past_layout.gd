class_name PastLayout
extends RefCounted
## 과거 신화 구역(docs/stranger.md 5단계)의 자리와 값. 칸 좌표(1칸 = 2m), 위쪽(y 작은 쪽)이 북쪽.
## 첫 검들이 벼려지던 때의 언덕: 살아 있는 오래된 숲, 성스러운 숲(북서), 선돌 고리와 가운데의 큰 노천 대장간 제단.

const SIZE: Vector2i = Vector2i(80, 60)
const START: Vector2 = Vector2(40, 51.5)
const EXIT_AT: Vector2 = Vector2(40, 57.4)   ## 돌아가는 돌문(구역 안)
const REACH: float = 2.0

## 과거의 능력(Rules.era == past): 쥔 검이 무엇이든 맞힐 때 피해 +10%, 밀림 +25%(Powers.strike).
const DMG_MULT: float = 1.10
const KNOCK_MULT: float = 1.25

## 이 구역에서만 하는 일: 첫 대장간 제단(E)에서 조각 REFORGE_COST개로 검집의 검 하나를 다시 벼린다(검 번호마다 한 번, 부러지기 전 내구 +10%).
const ALTAR_AT: Vector2 = Vector2(40, 28)
const REFORGE_COST: int = 150
const REFORGE_DUR: float = 0.10
## 성스러운 숲 한가운데의 함(조각을 한 번만 준다).
const CACHE_ID: String = "past_cache"
const GROVE_AT: Vector2 = Vector2(18, 16)
const CACHE_AT: Vector2 = Vector2(18, 16)
const CACHE_SHARDS: int = 100

## 선돌 고리: 제단 둘레 STONE_COUNT개(반지름 칸). 막힘 반지름은 STONE_R(칸).
const STONE_COUNT: int = 8
const STONE_RING: float = 10.0
const STONE_R: float = 0.9
## 성스러운 숲의 흰 나무 고리.
const GROVE_COUNT: int = 6
const GROVE_RING: float = 5.5
const GROVE_TREE_R: float = 1.0
## 큰 나무: (x, y, 막힘 반지름 칸). 모두 키 큰 막힘.
const TREES: Array[Vector3] = [
	Vector3(6, 8, 1.6), Vector3(14, 28, 1.5), Vector3(8, 40, 1.7), Vector3(6, 52, 1.6), Vector3(22, 52, 1.5),
	Vector3(26, 34, 1.6), Vector3(30, 8, 1.7), Vector3(52, 8, 1.6), Vector3(66, 10, 1.7), Vector3(74, 22, 1.6),
	Vector3(70, 34, 1.5), Vector3(74, 48, 1.7), Vector3(60, 54, 1.6), Vector3(54, 46, 1.5), Vector3(14, 46, 1.5),
	Vector3(64, 28, 1.6), Vector3(34, 48, 1.5), Vector3(48, 50, 1.5), Vector3(10, 20, 1.4), Vector3(44, 10, 1.6),
]

## 무리: Rules.spawn_pack(id, def)에 그대로 넘긴다.
const PACKS: Dictionary = {
	"stags": {"at": Vector2(60, 18), "wander": 4.0, "zone": 6, "foes": [[&"stag", 4]]},
	"stones": {"at": Vector2(22, 42), "wander": 3.5, "zone": 6, "foes": [[&"stone", 2]]},
	"wards": {"at": Vector2(58, 40), "wander": 3.5, "zone": 7, "foes": [[&"ward", 2], [&"stag", 2]]},
}

## 빛깔: 늦은 오후의 따뜻한 금빛. 채도는 낮게.
const BG: Color = Color(0.2, 0.15, 0.1)
const FOG: Color = Color(0.45, 0.34, 0.22)
const AMBIENT: Color = Color(0.6, 0.5, 0.38)
const SUN: Color = Color(1.0, 0.8, 0.5)
const GROUND: Color = Color(0.17, 0.15, 0.09)
const STONE: Color = Color(0.36, 0.34, 0.3)
const BARK: Color = Color(0.17, 0.12, 0.08)
const LEAF: Color = Color(0.13, 0.17, 0.07)
const GOLD: Color = Color(1.0, 0.72, 0.3)
## 과거에서 벨 때 베기 빛과 동작 빛의 색(보기만 한다).
const TRAIL: Color = Color(1.0, 0.78, 0.35)


static func stone_at(i: int) -> Vector2:
	return ALTAR_AT + Vector2.from_angle(TAU * i / STONE_COUNT + 0.3) * STONE_RING


static func grove_at(i: int) -> Vector2:
	return GROVE_AT + Vector2.from_angle(TAU * i / GROVE_COUNT) * GROVE_RING


## 막힘 표: Rules.set_blockers에 그대로 넘긴다. 제단 가운데 모루는 낮은 막힘(뛰어넘는다).
static func blockers() -> Dictionary:
	var circles: Array = []
	for t in TREES:
		circles.append([Vector2(t.x, t.y), t.z])
	for i in STONE_COUNT:
		circles.append([stone_at(i), STONE_R])
	for i in GROVE_COUNT:
		circles.append([grove_at(i), GROVE_TREE_R])
	return {"rects": [], "circles": circles, "low_rects": [Rect2(ALTAR_AT - Vector2(1.0, 0.6), Vector2(2.0, 1.2))], "low_circles": []}
