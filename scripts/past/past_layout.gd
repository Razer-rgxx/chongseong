class_name PastLayout
extends RefCounted
## 과거 신화 구역(docs/stranger.md 5단계)의 자리와 값. 칸 좌표(1칸 = 2m), 위쪽(y 작은 쪽)이 북쪽.
## 첫 검들이 벼려지던 때의 언덕: 살아 있는 오래된 숲, 성스러운 숲(북서), 선돌 고리와 가운데의 큰 노천 대장간 제단.

## 2026-11-26 판타지 월드(사용자: "과거 판타지 월드도"): 첫 대장간 숲(OLD) 동쪽과 남쪽으로 넓혔다. 모양은 PastWorld, 이야기는 StoryPast.
const SIZE: Vector2i = Vector2i(180, 110)
const OLD: Rect2 = Rect2(0, 0, 80, 60)
## 새 땅 셋(칸): 거인의 뼈 들(동북), 수정 호수(동남), 잿불 능선(남서). 들어서면 이름이 뜬다(PastWorld가 그리고 past.gd가 띄운다).
const REGIONS: Array[Dictionary] = [
	{"name": "거인의 뼈 들", "rect": Rect2(80, 0, 100, 52)},
	{"name": "수정 호수", "rect": Rect2(80, 52, 100, 58)},
	{"name": "잿불 능선", "rect": Rect2(0, 60, 80, 50)},
]
## 거인의 뼈: 쓰러진 거인의 갈비뼈 아치(가로로 늘어선 기둥 쌍). [가운데, 방향(라디안), 개수]. 기둥 하나가 막힘(BONE_R).
const RIBS: Array[Vector3] = [Vector3(118, 22, 0.25), Vector3(150, 30, -0.4)]
const RIB_PAIRS: int = 7
const RIB_GAP: float = 3.2
const RIB_SPAN: float = 7.0
const BONE_R: float = 0.8
## 거인의 해골(큰 막힘)과 부러진 칼(거인을 쓰러뜨린 첫 검, 꾸밈).
const SKULL_AT: Vector2 = Vector2(166, 12)
const SKULL_R: float = 4.0
## 수정 호수: 물(막힘 원들)과 둘레의 수정 무더기(막힘).
const LAKE: Array[Vector3] = [Vector3(130, 80, 13.0), Vector3(146, 86, 10.0), Vector3(118, 88, 8.0)]
const CRYSTALS: Array[Vector3] = [Vector3(104, 66, 1.3), Vector3(160, 70, 1.5), Vector3(170, 96, 1.4), Vector3(108, 100, 1.2), Vector3(150, 104, 1.3), Vector3(96, 84, 1.1)]
## 잿불 능선: 검은 바위(막힘)와 용암 금(꾸밈), 가운데 봉인 고리(보스 자리).
const ASH_ROCKS: Array[Vector3] = [Vector3(10, 70, 2.2), Vector3(26, 66, 1.8), Vector3(62, 68, 2.0), Vector3(72, 82, 1.8), Vector3(8, 96, 2.4), Vector3(30, 104, 1.9), Vector3(66, 102, 2.2), Vector3(50, 76, 1.5)]
const SEAL_AT: Vector2 = Vector2(38, 88)
const SEAL_RING: float = 9.0
const SEAL_STONES: int = 9
## 거인을 쓰러뜨린 첫 검(부러져 꽂힌 큰 칼, 막힘).
const GIANT_SWORD_AT: Vector2 = Vector2(158, 18)
const GIANT_SWORD_R: float = 1.2
## 새 땅의 나무: 뼈 들의 마른 나무(잎 없음)와 호숫가의 금빛 나무. [x, y, 막힘 반지름].
const DEAD_TREES: Array[Vector3] = [Vector3(96, 10, 0.8), Vector3(104, 30, 0.8), Vector3(92, 44, 0.8), Vector3(172, 40, 0.8), Vector3(126, 46, 0.8), Vector3(110, 8, 0.8)]
const LAKE_TREES: Array[Vector3] = [Vector3(92, 60, 1.5), Vector3(176, 58, 1.5), Vector3(96, 106, 1.6), Vector3(174, 106, 1.5), Vector3(140, 62, 1.4)]


## 땅마다 빛과 안개(past.gd가 영주가 선 땅 쪽으로 천천히 섞는다). 옛 숲은 BG·FOG·AMBIENT·SUN 그대로.
const LOOKS: Dictionary = {
	"거인의 뼈 들": {"fog": Color(0.5, 0.45, 0.36), "density": 0.0095, "ambient": Color(0.64, 0.58, 0.48), "sun": Color(1.0, 0.9, 0.7), "bg": Color(0.26, 0.22, 0.16)},
	"수정 호수": {"fog": Color(0.3, 0.32, 0.36), "density": 0.0085, "ambient": Color(0.5, 0.5, 0.56), "sun": Color(0.92, 0.88, 0.95), "bg": Color(0.09, 0.1, 0.13)},
	"잿불 능선": {"fog": Color(0.3, 0.17, 0.11), "density": 0.0105, "ambient": Color(0.48, 0.33, 0.26), "sun": Color(1.0, 0.62, 0.4), "bg": Color(0.12, 0.06, 0.04)},
}

## 새 땅에 흩은 것: 뼈 들의 마른 나무, 호숫가 금빛 나무, 능선의 현무암 기둥. [x, y, 막힘 반지름, 종류(0·1·2)].
## 고정 시드로 한 번만 만든다(꾸밈 자리라 Rules.rng와 무관, 늘 같은 자리). 이야기 자리·무리·길목은 비운다.
const SCATTER_COUNT: Array[int] = [22, 20, 16]
static var _scatter: Array[Vector4] = []


static func scatter() -> Array[Vector4]:
	if not _scatter.is_empty():
		return _scatter
	var rng := RandomNumberGenerator.new()
	rng.seed = 4400
	var keep: Array[Vector3] = [Vector3(START.x, START.y, 6.0), Vector3(SEAL_AT.x, SEAL_AT.y, SEAL_RING + 4.0), Vector3(SKULL_AT.x, SKULL_AT.y, SKULL_R + 4.0), Vector3(GIANT_SWORD_AT.x, GIANT_SWORD_AT.y, 5.0)]
	for p in [Vector2(140, 40), Vector2(166, 78), Vector2(20, 80), Vector2(38, 85)]:   # StoryPast.MEMORIES·BEAST_AT(순환 참조를 피해 숫자로)
		keep.append(Vector3(p.x, p.y, 5.0))
	for id in WORLD_PACKS:
		var at: Vector2 = WORLD_PACKS[id].at
		keep.append(Vector3(at.x, at.y, 7.0))
	for rb in RIBS:
		keep.append(Vector3(rb.x, rb.y, 14.0))
	for l in LAKE:
		keep.append(Vector3(l.x, l.y, l.z + 4.0))
	for c in CRYSTALS:
		keep.append(Vector3(c.x, c.y, 4.0))
	for a in ASH_ROCKS:
		keep.append(Vector3(a.x, a.y, a.z + 3.0))
	for t in DEAD_TREES + LAKE_TREES + edge_trees():
		keep.append(Vector3(t.x, t.y, t.z + 3.0))
	var out: Array[Vector4] = []
	for kind in 3:
		var r: Rect2 = REGIONS[kind].rect.grow(-4.0)
		var made: int = 0
		var tries: int = 0
		while made < SCATTER_COUNT[kind] and tries < 3000:
			tries += 1
			var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
			var ok: bool = true
			for k in keep:
				if p.distance_to(Vector2(k.x, k.y)) < k.z:
					ok = false
					break
			if not ok:
				continue
			var rad: float = [0.6, 1.4, 1.2][kind]
			out.append(Vector4(p.x, p.y, rad, kind))
			keep.append(Vector3(p.x, p.y, rad + 4.5))
			made += 1
	_scatter = out
	return out


## 옛 숲과 새 땅 사이의 나무 줄(드문드문, 길목 둘씩은 비운다).
static func edge_trees() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for x in range(3, 80, 5):
		if (x >= 7 and x <= 15) or (x >= 62 and x <= 72):
			continue
		out.append(Vector3(x, 61.5, 1.4))
	for y in range(3, 60, 5):
		if (y >= 14 and y <= 24) or (y >= 38 and y <= 48):
			continue
		out.append(Vector3(82, y, 1.4))
	return out


## 새 땅의 무리(옛 PACKS와 따로 센다).
const WORLD_PACKS: Dictionary = {
	"bones": {"at": Vector2(132, 14), "wander": 4.5, "zone": 7, "foes": [[&"stone", 2], [&"stag", 2]]},
	"lake": {"at": Vector2(160, 62), "wander": 4.0, "zone": 7, "foes": [[&"stag", 5]]},
	"shore": {"at": Vector2(104, 92), "wander": 4.0, "zone": 8, "foes": [[&"ward", 2], [&"stone", 1]]},
	"ash": {"at": Vector2(60, 92), "wander": 4.0, "zone": 8, "foes": [[&"stone", 2], [&"ward", 2]]},
}
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


static func region_of(at: Vector2) -> String:
	for r in REGIONS:
		if (r.rect as Rect2).has_point(at):
			return r.name
	return ""


## 갈비뼈 기둥 자리들(칸).
static func rib_posts() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for rb in RIBS:
		var dir := Vector2.from_angle(rb.z)
		var side := dir.orthogonal()
		for k in RIB_PAIRS:
			var c := Vector2(rb.x, rb.y) + dir * (k - (RIB_PAIRS - 1) * 0.5) * RIB_GAP
			out.append(c + side * RIB_SPAN * 0.5)
			out.append(c - side * RIB_SPAN * 0.5)
	return out


static func seal_stone(i: int) -> Vector2:
	return SEAL_AT + Vector2.from_angle(TAU * i / SEAL_STONES) * SEAL_RING


## 막힘 표: Rules.set_blockers에 그대로 넘긴다. 제단 가운데 모루는 낮은 막힘(뛰어넘는다).
static func blockers() -> Dictionary:
	var circles: Array = []
	for p in rib_posts():
		circles.append([p, BONE_R])
	circles.append([GIANT_SWORD_AT, GIANT_SWORD_R])
	for t in DEAD_TREES + LAKE_TREES + edge_trees():
		circles.append([Vector2(t.x, t.y), t.z])
	for t in scatter():
		circles.append([Vector2(t.x, t.y), t.z])
	circles.append([SKULL_AT, SKULL_R])
	for l in LAKE:
		circles.append([Vector2(l.x, l.y), l.z])
	for c in CRYSTALS:
		circles.append([Vector2(c.x, c.y), c.z])
	for a in ASH_ROCKS:
		circles.append([Vector2(a.x, a.y), a.z])
	for i in SEAL_STONES:
		if i != 7:   # 고리 북쪽 하나는 비워 들어가는 길
			circles.append([seal_stone(i), 1.0])
	for t in TREES:
		circles.append([Vector2(t.x, t.y), t.z])
	for i in STONE_COUNT:
		circles.append([stone_at(i), STONE_R])
	for i in GROVE_COUNT:
		circles.append([grove_at(i), GROVE_TREE_R])
	return {"rects": [], "circles": circles, "low_rects": [Rect2(ALTAR_AT - Vector2(1.0, 0.6), Vector2(2.0, 1.2))], "low_circles": []}
