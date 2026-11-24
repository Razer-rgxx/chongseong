class_name FieldLayout
extends RefCounted
## 들판(16단계, docs/village.md 16)의 자리와 값. 자리는 여기 하나에만 둔다. 모든 자리는 칸 좌표(1칸 = 2m).
## 위쪽(y 작은 쪽)이 북쪽이다: 언덕 발치는 북, 마을 문은 남.

const SIZE: Vector2i = Vector2i(230, 110)   ## 28단계: 동쪽으로 60칸 더(20단계 170, 원래 110 x 110)
const WORLD_X: float = 460.0   ## m
const WORLD_Z: float = 220.0

const AREA_ORDER: PackedStringArray = ["mine", "aqueduct", "giant", "windmill", "watermill", "ravine", "quarry", "hamlet", "pass", "keep", "marsh", "foot", "watchtower", "grove", "old_field", "brook", "road"]
const AREAS: Dictionary = {
	&"quarry": Rect2(170, 2, 58, 42),
	&"hamlet": Rect2(170, 44, 58, 36),
	&"pass": Rect2(170, 80, 58, 28),
	&"keep": Rect2(110, 2, 58, 46),
	&"marsh": Rect2(110, 68, 58, 40),
	&"foot": Rect2(30, 0, 50, 24),
	&"watchtower": Rect2(78, 24, 32, 28),
	&"grove": Rect2(0, 22, 38, 30),
	&"old_field": Rect2(58, 66, 52, 44),
	&"brook": Rect2(0, 52, 170, 14),   # 새 곳(170~)과 겹치면 AREA_ORDER로 새 곳이 이긴다
	&"road": Rect2(0, 0, 230, 110),
	# 구조물(2026-11-24, docs/landmarks.md): 큰 곳 위에 겹친 작은 곳. AREA_ORDER 앞쪽이라 이긴다
	&"mine": Rect2(160, 72, 20, 6), &"aqueduct": Rect2(38, 80, 34, 11), &"giant": Rect2(4, 72, 18, 12),
	&"windmill": Rect2(8, 90, 14, 14), &"watermill": Rect2(28, 46, 14, 8), &"ravine": Rect2(13, 3, 14, 20),
}
const AREA_NAMES: Dictionary = {
	&"road": "언덕길", &"old_field": "옛 싸움터", &"watchtower": "무너진 망루",
	&"brook": "개울가", &"grove": "검은 숲 가장자리", &"foot": "언덕 발치",
	&"keep": "무너진 성채", &"marsh": "안개 늪",
		&"quarry": "버려진 채석장", &"hamlet": "불탄 마을", &"pass": "까마귀 고개",
	&"mine": "옛 갱도", &"aqueduct": "무너진 수도교", &"giant": "거인의 뼈", &"windmill": "바람개비 언덕",
	&"watermill": "물레방앗간", &"ravine": "흔들다리 골짜기",
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
	"cache_9": [Vector2(127, 17), 45], "cache_10": [Vector2(151, 26), 55],
	"cache_11": [Vector2(218, 14), 50], "cache_12": [Vector2(177.5, 47.5), 35],
	"cache_13": [Vector2(217.5, 69), 40], "cache_14": [Vector2(222, 95), 120],
	"cache_15": [Vector2(168.5, 75.0), 60],   # 옛 갱도 깊은 곳(2026-11-24)
}
## 큰 상자(그림이 크다). 고개 끝의 상자.
const BIG_CACHES: PackedStringArray = ["cache_14"]

## 흩어진 조각 후보 23곳(16~19번은 안개 늪, 20단계 / 20~22번은 불탄 마을, 28단계). 판마다 GLINT_ACTIVE곳이 새로 생긴다. 하나에 GLINT_MIN~GLINT_MAX 조각.
const GLINTS: PackedVector2Array = [
	Vector2(40, 100), Vector2(70, 96), Vector2(30, 84), Vector2(90, 98), Vector2(100, 84), Vector2(70, 74),
	Vector2(40, 72), Vector2(20, 70), Vector2(24, 62), Vector2(12, 52), Vector2(46, 40), Vector2(70, 40),
	Vector2(100, 30), Vector2(76, 24), Vector2(30, 10), Vector2(92, 12),
	Vector2(122, 76), Vector2(140, 86), Vector2(158, 78), Vector2(134, 100),
	Vector2(184, 47.5), Vector2(224, 52), Vector2(212, 74),
]
const GLINT_ACTIVE: int = 4
## 마을 키우기 재료 자리(2026-11-21, docs/village_growth.md 1단계): [칸, 재료]. scripts/debug/pick_mat_spots.gd가 뽑았다.
## 나무는 숲·개울·발치·늪, 돌은 채석장·성채·고개·망루, 쇠는 옛 싸움터·불탄 마을·성채·망루·고개. 판마다 재료별로 MAT_ACTIVE곳이 생긴다.
## 무리가 진 친 자리(포로가 묶이는 자리)·밤 무리·떠도는 사람 자리와는 떨어져 있다.
const MATS: Array = [
	[Vector2(30, 36), &"wood"], [Vector2(22, 43), &"wood"], [Vector2(5, 41), &"wood"], [Vector2(107, 56), &"wood"],
	[Vector2(153, 55), &"wood"], [Vector2(51, 18), &"wood"], [Vector2(61, 17), &"wood"], [Vector2(152, 84), &"wood"],
	[Vector2(173, 15), &"stone"], [Vector2(174, 31), &"stone"], [Vector2(207, 11), &"stone"], [Vector2(155, 34), &"stone"],
	[Vector2(116, 41), &"stone"], [Vector2(192, 95), &"stone"], [Vector2(181, 94), &"stone"], [Vector2(82, 37), &"stone"],
	[Vector2(76, 88), &"iron"], [Vector2(97, 96), &"iron"], [Vector2(65, 106), &"iron"], [Vector2(209, 68), &"iron"],
	[Vector2(205, 76), &"iron"], [Vector2(115, 28), &"iron"], [Vector2(94, 48), &"iron"], [Vector2(213, 95), &"iron"],
]
const MAT_ACTIVE: int = 3
## 무리에 잡혀 있는 사람(2026-11-21 마을 키우기 3단계): 판마다 무리 CAPTIVES곳에 하나씩 묶여 있고, 그 무리를 쓰러뜨리면 풀어 줄 수 있다.
const CAPTIVES: int = 2
## 까마귀 고개로 가는 두 길(늪 → 고개, 불탄 마을 → 고개)을 막은 통나무·돌 더미(칸). 마을에 망루를 지으면 치운다(마을 키우기 5단계).
const PASS_BARRICADES: Array[Rect2] = [Rect2(166.5, 91.0, 4.0, 8.0), Rect2(190.0, 84.0, 6.0, 2.6)]
## 주민 이름(옛 마을의 흔한 이름)과 생김새(VillageProps.LOOKS).
const RESIDENT_NAMES: Array[String] = ["돌쇠", "막손", "덕배", "끝순", "언년", "삼월", "복실", "마당쇠", "개동", "판수", "순덕", "억쇠", "말순", "칠복", "분이", "갑돌"]
const RESIDENT_LOOKS: Array[StringName] = [&"peasant", &"peasant2", &"peasant3", &"peasant4"]
## 한 자리에서 얻는 양(최소, 최대).
const MAT_YIELD: Dictionary = {&"wood": Vector2i(3, 5), &"stone": Vector2i(2, 4), &"iron": Vector2i(1, 3)}
const GLINT_MIN: int = 2
const GLINT_MAX: int = 5

## 비석을 모두(STONES 전부) 읽으면 한 번 받는 조각. 이미 받은 사람(Meta.lore_paid)은 비석이 늘어도 다시 받지 않는다.
const LORE_REWARD: int = 30

## 이야기 비석 id → [칸 자리, 이름, 글]. 글은 줄바꿈(\n)으로 띠에 2~3줄.
const STONES: Dictionary = {
	"stone_1": [Vector2(60, 100), "길머리 비석", "언덕으로 오르는 이는 많았으나\n내려온 이는 적었다."],
	"stone_2": [Vector2(72, 80), "옛 싸움터의 비석", "검을 든 병사 삼백이 여기서 쓰러졌다.\n그들의 검은 아직 풀 사이에 서 있다.\n뽑는 이는 이름을 잃는다고 한다."],
	"stone_3": [Vector2(46, 62), "개울가의 비석", "물은 언덕에서 내려와 마을로 간다.\n옛 사람은 이 물에 칼을 씻고 맹세했다."],
	"stone_4": [Vector2(84, 44), "망루의 비석", "봉화가 꺼진 날 밤, 망루지기는 끝내 내려오지 않았다.\n불을 지키는 일이 그의 맹세였다."],
	"stone_5": [Vector2(20, 30), "검은 숲의 비석", "숲은 해마다 한 걸음씩 길로 다가온다.\n마른 나무 사이에서 소리를 들어도 돌아보지 마라."],
	"stone_6": [Vector2(44, 12), "발치의 비석", "여기서부터 길은 언덕의 것이다.\n칼이 부르면 오르고, 부러지면 다시 내려오라."],
	"stone_7": [Vector2(139, 34), "성채의 비석", "성문은 안에서 잠겨 있었다.\n적은 밖에서 오지 않았다.\n성주는 끝내 문을 열지 않았다."],
	"stone_8": [Vector2(181, 35), "채석장의 비석", "돌은 캐는 대로 나왔고\n사람은 캐는 대로 사라졌다.\n마지막 수레는 아직 구덩이 밑에 있다."],
	"stone_9": [Vector2(188, 62), "불탄 마을의 비석", "불은 하룻밤이었고\n우물은 사흘 동안 말랐다.\n아무도 이 마을의 이름을 적지 않았다."],
}

## 들판에서 영주가 못 들어가는 곳(칸 단위): 둘레의 숲·벼랑과 목책, 망루, 수레, 쓰러진 거목, 돌다리 난간.
const BORDER_RECTS: Array[Rect2] = [
	Rect2(0, 0, 3, 110), Rect2(227, 0, 3, 110), Rect2(0, 0, 230, 2),
	Rect2(0, 108.3, 52, 2), Rect2(58, 108.3, 172, 2),
	Rect2(107, 0, 3, 52), Rect2(107, 66, 3, 44),   # 원래 동쪽 둘레: 개울 근처(y 52~66)만 틈을 내 동쪽으로 이어진다
	# 20단계 동쪽 둘레(x 167~170): 틈 셋(y 22~32 성채 → 채석장, 52~66 개울 → 불탄 마을, 91~99 늪 → 까마귀 고개)
	Rect2(167, 0, 3, 22), Rect2(167, 32, 3, 20), Rect2(167, 66, 3, 7.2), Rect2(167, 76.8, 3, 14.2), Rect2(167, 99, 3, 11),   # (167, 73.2~76.8)는 옛 갱도(MINE_WALLS가 양쪽을 막는다)
]
## 20단계 동쪽 둘레(x 334~340m)의 틈: Vector2(가운데 z m, 반폭 m). 땅 높이의 언덕 띠와 숲·바위가 이 틈을 비운다(BORDER_RECTS의 틈과 같다).
const EAST_GAPS: PackedVector2Array = [Vector2(54, 10), Vector2(118, 14), Vector2(190, 8)]


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
	## 20단계 새 지역(7~8구역 세기)
	"keep_yard": {"at": Vector2(138, 24), "wander": 3.5, "zone": 7, "foes": [[&"giant", 1], [&"shield", 2], [&"archer", 2]]},
	"keep_gate": {"at": Vector2(130, 45), "wander": 3.5, "zone": 7, "foes": [[&"charger", 2], [&"wraith", 2], [&"bomber", 1]]},
	"marsh_west": {"at": Vector2(126, 84), "wander": 3.5, "zone": 7, "foes": [[&"wraith", 3], [&"caller", 1], [&"bomber", 1]]},
	"marsh_east": {"at": Vector2(152, 96), "wander": 4.0, "zone": 8, "foes": [[&"wolf", 2], [&"charger", 1], [&"archer", 2], [&"shield", 1]]},
	## 28단계 새 곳(8~9구역 세기)
	"quarry_pit": {"at": Vector2(190, 22), "wander": 3.5, "zone": 8, "foes": [[&"charger", 2], [&"shield", 2], [&"archer", 1]]},
	"quarry_rim": {"at": Vector2(212, 22), "wander": 3.5, "zone": 8, "foes": [[&"wraith", 2], [&"caller", 1], [&"bomber", 1], [&"wolf", 1]]},
	"hamlet_square": {"at": Vector2(206, 55), "wander": 3.5, "zone": 8, "foes": [[&"giant", 1], [&"wraith", 2], [&"charger", 1]]},
	"hamlet_south": {"at": Vector2(190, 74), "wander": 3.5, "zone": 8, "foes": [[&"wolf", 3], [&"bomber", 2], [&"archer", 1]]},
	"pass_top": {"at": Vector2(204, 95), "wander": 2.5, "zone": 9, "foes": [[&"giant", 1], [&"charger", 2], [&"shield", 1], [&"archer", 1], [&"caller", 1]]},
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


## ---- 곳마다 우두머리(32단계, docs/field_life.md). 옛 싸움터의 무덤 기사처럼 깨어나고 놓아주고 돌아가면 체력이 찬다(Rules.chiefs).
## 우두머리 id → {area: 곳, at: 제자리(칸), kind: 적 표 id(data/enemies, 이미 있는 적의 큰 판), zone: 불려 오는 적의 세기 구역(1부터), sword: 처음 쓰러뜨리면 주는 오픈월드 한정 검 id}.
## 자리는 그 곳 안에서 막힌 곳·길·상자·비석·무리 둘레를 피한다(테스트가 본다). 숲·바위는 둘레에 서지 않는다(FieldBuilder._free).
const CHIEFS: Dictionary = {
	"chief_tower": {"area": &"watchtower", "at": Vector2(100, 38), "kind": &"chief_archer", "zone": 4, "sword": 301},
	"chief_grove": {"area": &"grove", "at": Vector2(19, 42), "kind": &"chief_wolf", "zone": 5, "sword": 302},
	"chief_foot": {"area": &"foot", "at": Vector2(67, 20), "kind": &"chief_giant", "zone": 6, "sword": 303},
	"chief_keep": {"area": &"keep", "at": Vector2(148, 33), "kind": &"chief_shield", "zone": 7, "sword": 304},
	"chief_marsh": {"area": &"marsh", "at": Vector2(139, 88), "kind": &"chief_caller", "zone": 7, "sword": 305},
	"chief_quarry": {"area": &"quarry", "at": Vector2(201, 30), "kind": &"chief_charger", "zone": 8, "sword": 306},
	"chief_hamlet": {"area": &"hamlet", "at": Vector2(187, 54), "kind": &"chief_burnt", "zone": 8, "sword": 307},
	"chief_pass": {"area": &"pass", "at": Vector2(186, 95), "kind": &"chief_knight", "zone": 9, "sword": 308},
}
## 깨어남·놓아줌 거리(칸, 들판 보스와 같다), 처음 쓰러뜨리면 받는 조각, 그다음부터 받는 조각.
const CHIEF_WAKE: float = 8.0
const CHIEF_LEASH: float = 14.0
const CHIEF_FIRST_SHARDS: int = 50
const CHIEF_SHARDS: int = 15
## 제자리 둘레 이만큼(칸)에는 숲·바위 흩뿌림이 서지 않는다.
const CHIEF_CLEAR: float = 4.5


## ---- 떠도는 사람과 영입(34단계, docs/field_life.md). 들판 새벽마다(그리고 들어올 때 아무도 없으면) 아직 영입하지 않은 사람 하나가
## 후보 자리 하나에 선다(Meta.place_wanderer, Meta.rng). 자리는 길·곳 가장자리이고 무리(밤 덤빔 거리)·우두머리·무덤 기사에서 떨어져 있다(테스트가 본다).
## pack은 늙은 사냥꾼의 조건("그 근처 무리 하나")이 보는 가장 가까운 낮 무리다.
const WANDERER_SPOTS: Array[Dictionary] = [
	{"at": Vector2(52, 101), "pack": "road_south"},
	{"at": Vector2(48, 72), "pack": "road_mid"},
	{"at": Vector2(56, 50), "pack": "brook_east"},
	{"at": Vector2(55, 14), "pack": "foot"},
	{"at": Vector2(100, 61), "pack": "brook_east"},
	{"at": Vector2(141, 56), "pack": "keep_gate"},
	{"at": Vector2(192, 40), "pack": "quarry_pit"},
	{"at": Vector2(167, 95), "pack": "marsh_east"},
]
## 총 든 낯선 사람(docs/stranger.md)이 서는 후보 자리(칸). 영주에게서 먼 자리만 뽑는다.
const STRANGER_SPOTS: Array[Vector2] = [
	Vector2(52, 101), Vector2(48, 72), Vector2(56, 50), Vector2(55, 14),
	Vector2(100, 61), Vector2(141, 56), Vector2(192, 40), Vector2(167, 95),
]
## 다섯 사람 id → {name, cond(영입 조건: shards 조각을 낸다 · field_sword 한정 검을 가졌다 · pack 근처 무리를 쓰러뜨렸다 · stones 비석을 읽었다 · chiefs 우두머리를 쓰러뜨렸다), n,
## gift(영입하면 생기는 일, 토스트), 말(Band 한 줄씩): greet 처음, ask 조건을 말함, ready 조건이 맞음, join 영입할 때, village 마을에서(돌아가며 한 줄)}.
const WANDERERS: Dictionary = {
	"gatherer": {"name": "떠돌이 약초꾼", "cond": "shards", "n": 40, "gift": "체력 +10",
		"greet": "쇠 맛 나는 풀만 자라는 땅이야. 그래도 캐면 약이 되지.",
		"ask": "마을까지 데려가 줄 텐가. 길값으로 조각 마흔 개면 되네.",
		"ready": "조각 마흔 개. 그거면 남은 겨울은 버틸 수 있겠어.",
		"join": "가세. 자네 피가 마르기 전에 내 풀이 먼저 닿게 하지.",
		"village": ["뿌리를 말려 두었네. 언덕에 오르기 전에 씹어 두게.", "들판의 풀은 죽은 자 위에서 더 잘 자라더군."]},
	"smith": {"name": "떠돌이 대장장이", "cond": "field_sword", "n": 1, "gift": "망치질 값 -20%",
		"greet": "모루도 없이 떠돈 지 오래다. 망치만 남았지.",
		"ask": "들판에서만 나는 칼을 하나 가져와 봐. 그걸 보고 나서 따라가겠다.",
		"ready": "그 칼, 언덕의 것이 아니군. 좋다, 마을로 가지.",
		"join": "대장간 옆에 자리만 내 주게. 망치질 값은 덜 받겠다.",
		"village": ["검집은 칼보다 오래 간다. 칼이 부러져도 다음 칼이 들어가니까.", "언덕의 칼은 뽑히고 들판의 칼은 빼앗긴다. 둘 다 피를 먹었지."]},
	"hunter": {"name": "늙은 사냥꾼", "cond": "pack", "n": 1, "gift": "들판 무리 조각 +50%",
		"greet": "쉿. 저쪽에 놈들이 진을 쳤다. 나는 이제 시위를 못 당겨.",
		"ask": "근처에 진 친 놈들을 쓰러뜨려 봐. 그럼 네 칼을 믿겠다.",
		"ready": "놈들이 조용해졌군. 네 칼이면 늙은이도 따라갈 만하다.",
		"join": "가자. 무리를 잡으면 쓸 만한 걸 거두는 법은 내가 안다.",
		"village": ["무리는 우두머리가 아니라 가장 굶주린 놈부터 덤빈다.", "밤에는 놈들이 멀리서도 냄새를 맡는다. 바람을 등지고 걸어라."]},
	"pilgrim": {"name": "길 잃은 순례자", "cond": "stones", "n": 5, "gift": "성소 축복 값 -20%",
		"greet": "성소로 가는 길을 잃었소. 돌들이 길을 알려 준다 하였는데.",
		"ask": "들판의 비석 다섯을 읽어 주시오. 거기 적힌 말을 따라가겠소.",
		"ready": "비석들이 말한 길이 당신의 마을로 이어지는구려.",
		"join": "성소의 불을 같이 지키겠소. 기도 값은 조금 덜 들게 해 두지요.",
		"village": ["축복은 사는 것이 아니오. 잠시 빌려 쓰는 것이지.", "언덕 꼭대기에도 성소가 있었다 하오. 지금은 칼만 서 있지만."]},
	"knight": {"name": "몰락한 기사", "cond": "chiefs", "n": 3, "gift": "들판의 검",
		"greet": "기사단은 없다. 깃발도 꺾였다. 나만 남았다.",
		"ask": "들판의 우두머리 셋을 쓰러뜨려라. 그만한 자라면 따를 만하다.",
		"ready": "우두머리 셋이라. 그대라면 내 칼을 맡겨도 되겠군.",
		"join": "이 칼을 받아라. 지킬 것이 없어도 물러서지 않던 칼이다.",
		"village": ["마을의 목책은 낮다. 그래도 지키는 자가 있으면 성벽이다.", "나는 이제 아무도 섬기지 않는다. 그대만 빼고."]},
}
## 영입한 사람의 효과(이미 있는 계산에 곱하거나 더한다): 약초꾼 판 시작·들판 체력 +, 대장장이 망치질 값 ×, 사냥꾼 들판 무리 전멸 조각 ×,
## 순례자 성소 축복 값 ×, 기사가 영입할 때 주는 오픈월드 한정 검 id.
const RECRUIT_HP: float = 10.0
const RECRUIT_FORGE: float = 0.8
const RECRUIT_HUNT: float = 1.5
const RECRUIT_BLESS: float = 0.8
const RECRUIT_SWORD: int = 310


## ---- 지하 무덤 입구(19단계, docs/outside.md). 검은 숲 가장자리의 무너진 무덤.
## 모양이 서는 곳(막힘, 칸 단위), E를 누르는 자리, 나오거나 쓰러져 깰 자리(입구 앞).
const CRYPT_BLOCK: Rect2 = Rect2(28.5, 26.0, 7.0, 3.6)
const CRYPT_DOOR: Vector2 = Vector2(32, 31)
## 무덤에서 쓰러지면 쥔 검이 떨어지는 자리: 깨는 자리(CRYPT_WAKE)에서 조금 옆(깨자마자 발밑에 겹치지 않게).
const CRYPT_DROP_OFFSET: Vector2 = Vector2(1.5, 0.5)
const CRYPT_WAKE: Vector2 = Vector2(32, 33.5)


## ---- 새 지역(20단계, docs/outside.md). 모양이 서는 곳은 여기 하나에만 둔다(칸 단위).
## 무너진 성채의 성벽 조각(군데군데 틈이 있다): 그린 돌 상자와 막힘이 같은 표를 쓴다. 반쯤 남은 탑은 KEEP_TOWER.
const KEEP_WALLS: Array[Rect2] = [
	Rect2(122, 12, 12, 1.2), Rect2(138, 12, 12, 1.2),            # 북쪽 성벽(가운데 틈, 동쪽 끝은 무너짐)
	Rect2(122, 39, 14, 1.2), Rect2(142, 39, 16, 1.2),            # 남쪽 성벽(가운데가 성문 자리)
	Rect2(122, 12, 1.2, 10), Rect2(122, 30, 1.2, 10),            # 서쪽 성벽(가운데 틈)
	Rect2(157, 12, 1.2, 12), Rect2(157, 30, 1.2, 10),            # 동쪽 성벽(가운데 틈)
]
const KEEP_TOWER: Rect2 = Rect2(148, 15, 6, 6)
## 안개 늪: 들어서면 환경 안개 짙기가 MARSH_FOG_MULT배로 MARSH_FOG_TIME초에 걸쳐 짙어지고 빛깔이 바뀐다(화면만, 규칙과 상관없다).
const MARSH_FOG_MULT: float = 5.0
const MARSH_FOG_TIME: float = 2.5
const MARSH_FOG_COLOR: Color = Color(0.3, 0.37, 0.34, 1.0)


## ---- 새 곳 셋(28단계, docs/outside.md). 모양이 서는 곳은 여기 하나에만 둔다(칸 단위). 그린 곳이 곧 막힌 곳이다.
## 버려진 채석장: 파인 구덩이(가운데·반지름 칸, 깊이 m), 돌 벼랑, 잘린 돌덩이, 나무 비계의 기둥.
const QUARRY_PIT_AT: Vector2 = Vector2(198, 22)
const QUARRY_PIT_R: Vector2 = Vector2(20, 13)
const QUARRY_PIT_DEPTH: float = 3.5
const QUARRY_CLIFFS: Array[Rect2] = [
	Rect2(174, 2, 50, 4), Rect2(222, 6, 5, 32),                 # 북쪽·동쪽 벼랑
	Rect2(172, 38, 16, 4), Rect2(196, 38, 31, 4),               # 남쪽 벼랑(가운데 x 188~196이 불탄 마을로 가는 틈)
]
const QUARRY_BLOCKS: Array[Rect2] = [
	Rect2(181, 10, 4, 3), Rect2(210, 9, 5, 3), Rect2(214, 32, 4, 3), Rect2(177, 10, 3, 3),
]
const QUARRY_POSTS: Array[Rect2] = [   # 비계 둘(기둥만 막힘, 위의 널은 머리 위). 기둥은 가는 통나무(0.6m)라 막힘도 그만큼
	Rect2(199.2, 12.2, 0.3, 0.3), Rect2(199.2, 15.5, 0.3, 0.3), Rect2(201.85, 12.2, 0.3, 0.3), Rect2(201.85, 15.5, 0.3, 0.3), Rect2(204.5, 12.2, 0.3, 0.3), Rect2(204.5, 15.5, 0.3, 0.3),
	Rect2(203.2, 30.2, 0.3, 0.3), Rect2(203.2, 33.5, 0.3, 0.3), Rect2(207.5, 30.2, 0.3, 0.3), Rect2(207.5, 33.5, 0.3, 0.3),
]
## 불탄 마을: 지붕 없이 그을린 집 벽 여섯 채(문 자리와 무너진 자리는 비움), 우물, 무너진 울타리.
## 30단계: 울타리와 우물 둘레, 벽의 무너진 낮은 조각은 낮은 막힘(Blockers.JUMP_CLEAR 1m 이하로 그린다, 점프로 넘는다).
const HAMLET_WALLS: Array[Rect2] = [
	Rect2(174, 45, 7, 0.5), Rect2(174, 49.5, 2.3, 0.5), Rect2(178.7, 49.5, 2.3, 0.5), Rect2(174, 45.5, 0.5, 1.4), Rect2(180.5, 45.5, 0.5, 4),
	Rect2(198, 45, 6, 0.5), Rect2(198, 49.5, 1.8, 0.5), Rect2(202.2, 49.5, 1.8, 0.5), Rect2(198, 45.5, 0.5, 4), Rect2(203.5, 47.5, 0.5, 2),
	Rect2(212, 45, 3.5, 0.5), Rect2(212, 49.5, 2.3, 0.5), Rect2(216.7, 49.5, 2.3, 0.5), Rect2(212, 45.5, 0.5, 4), Rect2(218.5, 45.5, 0.5, 4),
	Rect2(176, 66, 2.3, 0.5), Rect2(180.7, 66, 2.3, 0.5), Rect2(176, 71.5, 7, 0.5), Rect2(176, 66.5, 0.5, 5), Rect2(182.5, 66.5, 0.5, 1.5), Rect2(182.5, 70.5, 0.5, 1),
	Rect2(200, 67, 1.8, 0.5), Rect2(204.2, 67, 1.8, 0.5), Rect2(202.7, 72.5, 3.3, 0.5), Rect2(200, 67.5, 0.5, 5), Rect2(205.5, 67.5, 0.5, 5),
	Rect2(214, 66, 2.3, 0.5), Rect2(218.7, 66, 2.3, 0.5), Rect2(214, 71.5, 7, 0.5), Rect2(214, 66.5, 0.5, 2.5), Rect2(220.5, 66.5, 0.5, 5),
]
const HAMLET_WELL: Rect2 = Rect2(191, 51.5, 2, 2)
## 우물의 부러진 두레박 기둥(2.6m): 우물 둘레(낮은 막힘, 30단계)와 따로 높은 막힘이다.
const HAMLET_WELL_POST: Rect2 = Rect2(192.6, 52.45, 0.1, 0.1)
const HAMLET_FENCES: Array[Rect2] = [
	Rect2(176, 77, 7, 0.4), Rect2(200, 77, 8, 0.4), Rect2(212, 77, 7, 0.4), Rect2(185, 62, 0.4, 4), Rect2(222, 68, 0.4, 5),
]
## 까마귀 고개: 양쪽이 벼랑인 좁은 오르막 길(x 172~226, y 91~99). 북쪽 벼랑 가운데(x 190~196)는 불탄 마을로 가는 틈.
const PASS_CLIFFS: Array[Rect2] = [
	Rect2(172, 80, 18, 11), Rect2(196, 80, 31, 11), Rect2(172, 99, 55, 9),
]
## 길이 오르는 높이(m)와 벼랑 옆 땅이 솟는 높이(m).
const PASS_RISE: float = 5.0
const PASS_WALL: float = 4.0


## ---- 들판 구조물(2026-11-24, docs/landmarks.md). 자리·수치는 여기 하나에만 둔다(칸 단위, 길이는 m).
## 상인 행렬: 장터 문에서 길을 따라 언덕 발치 쪽으로 올라갔다가 돌아온다. 들판 시계로만 정해진다(Caravan).
const CARAVAN_CARTS: int = 4
const CARAVAN_STARTS: PackedFloat32Array = [12.0, 205.0]   ## 한 바퀴(낮 + 밤)에서 떠나는 때(초). 하루 두 번
const CARAVAN_FAR: float = 160.0        ## 맨 앞 수레가 서는 곳(길을 따라 문에서 m)
const CARAVAN_SPEED: float = 2.2        ## m/초
const CARAVAN_REST: float = 25.0        ## 먼 끝에서 쉬는 초
const CARAVAN_SPACING: float = 8.0      ## 수레와 수레 사이(m, 소 한 마리 몫 포함)
const CARAVAN_LANE: float = 1.5         ## 길 가운데에서 옆으로(m): 갈 때 동쪽, 올 때 서쪽 길
const CARAVAN_ESCORTS: Array[Vector2] = [Vector2(-0.7, 1.0), Vector2(1.5, -1.0), Vector2(3.8, 1.0)]   ## 호위: (수레 번호(소수), 옆 쪽 ±1)
## 옛 갱도: 늪(서)과 불탄 마을(동)을 잇는 굴. 걷는 길은 y 73.8~76.2, 양쪽 벽 MINE_WALLS가 막는다. 바닥은 MINE_FLOOR_Y로 평평하게 깎는다.
const MINE_WALLS: Array[Rect2] = [Rect2(160, 73.2, 17, 0.6), Rect2(160, 76.2, 17, 0.6)]
const MINE_Z: float = 150.0             ## 굴 가운데 z(m)
const MINE_X: Vector2 = Vector2(320.0, 354.0)   ## 굴 입구에서 입구(m)
const MINE_FLOOR_Y: float = 1.0
const MINE_LANTERNS: PackedFloat32Array = [326.0, 337.0, 348.0]   ## 등불 x(m), 앞뒤 둘만 빛을 낸다
## 무너진 수도교: y 85 줄을 따라 받침 여섯(마지막은 부러진 그루터기). 길(x 48.4)은 둘째 아치 밑을 지난다.
const AQUEDUCT_Y: float = 85.0
const AQUEDUCT_PIERS: PackedFloat32Array = [40.0, 45.5, 51.0, 56.5, 62.0, 67.5]
const AQUEDUCT_SPRING: float = 3.4      ## 아치가 시작하는 높이(m)
## 풍차(바람개비 언덕)와 물레방앗간(개울 북쪽 둑, 개울 따라 앉는다), 날개·바퀴가 도는 빠르기(rad/초)는 날씨별 풍차 배수.
const WINDMILL_AT: Vector2 = Vector2(14, 97)
const WINDMILL_SPEED: float = 0.7
const WINDMILL_WIND: Dictionary = {&"clear": 1.0, &"rain": 1.5, &"fog": 0.4, &"storm": 3.2, &"ash": 1.2}
const WATERMILL_X: float = 34.0
const WATERMILL_SPEED: float = 0.55
## 거인의 뼈: 움푹 팬 곳(가운데 칸, 반지름 칸, 깊이 m)에 누워 있다. 갈비뼈 사이로 걷는다.
const GIANT_AT: Vector2 = Vector2(13, 78)
const GIANT_R: Vector2 = Vector2(8.5, 5.0)
const GIANT_DEPTH: float = 1.3
const GIANT_RIBS: int = 8
## 흔들다리: 남북으로 긴 골짜기(가운데 x m, 길이 z m, 깊이 m)를 동서로 건너는 줄다리. 건너는 줄은 z 28m(칸 y 14).
const RAVINE_X: float = 38.0
const RAVINE_Z: Vector2 = Vector2(2.0, 46.0)
const RAVINE_DEPTH: float = 4.6
const RAVINE_BRIDGE_Z: float = 28.0
const RAVINE_BRIDGE_X: Vector2 = Vector2(31.5, 44.5)
const RAVINE_WALLS: Array[Rect2] = [Rect2(16.6, 2.0, 4.8, 11.5), Rect2(16.6, 14.5, 4.8, 8.5)]
const BRIDGE_SAG: float = 0.6
## 구조물 곳(숲·바위·풀 흩뿌림이 서지 않는다).
const LANDMARK_AREAS: Array = [&"mine", &"aqueduct", &"giant", &"windmill", &"watermill", &"ravine"]


## ---- 들판 낮밤과 다시 생기는 적(29단계, docs/outside.md). 수치는 여기 하나에만 둔다.
## 낮과 밤의 길이(초). 시계는 Rules(들판 모드)가 30Hz로 세고 한 바퀴(낮 + 밤)마다 0으로 돌아간다. 0은 아침.
const FIELD_DAY: float = 240.0
const FIELD_NIGHT: float = 150.0
## 밤에 무리가 덤빌 때 세기 구역에 더하는 수(RunData.zone_hp 길이를 넘지 않게 자른다)와 밤의 덤빔 거리(낮은 PACK_AGGRO).
const FIELD_NIGHT_ZONE: int = 1
const FIELD_NIGHT_AGGRO: float = 14.0
## 밤에 무리 적(낮 무리·밤 무리, 보스 빼고)이 영주에게 주는 피해 배수. 저주받은 밤(×1.25)과 같은 값.
const FIELD_NIGHT_DAMAGE: float = 1.25
## 새벽에 쓰러뜨린 무리를 다시 세울 때, 영주가 제자리에서 이만큼(칸) 안이면 이번 새벽은 건너뛴다(곁에서 솟아 바로 덤비지 않게, 밤 덤빔 거리와 같다).
const FIELD_DAWN_SAFE: float = 14.0
## 해질녘·새벽에 하늘과 빛이 바뀌는 시간(초, night_amount). 화면만 쓴다.
const FIELD_TWILIGHT: float = 40.0
## 영주 횃불의 세기(낮 / 밤). 언덕의 밤 횃불(main.torch_energy)과 같다.
const FIELD_TORCH_DAY: float = 0.0
const FIELD_TORCH_NIGHT: float = 2.6
## 화면(field.gd, night_amount 0~1로 섞는다): 해 빛 세기·빛깔(낮 / 해질녘 / 밤), 해 기울기(낮 / 지는 해 / 달, 도), 환경광, 안개.
const FIELD_SUN_ENERGY: Vector3 = Vector3(0.9, 0.06, 0.5)   ## 낮, 해질녘(가장 낮은 때), 밤
const FIELD_SUN_COLOR_DAY: Color = Color(1.0, 0.78, 0.6)
const FIELD_SUN_COLOR_DUSK: Color = Color(1.0, 0.48, 0.26)
const FIELD_SUN_COLOR_NIGHT: Color = Color(0.55, 0.65, 1.0)
const FIELD_SUN_TILT: Vector3 = Vector3(-35.0, -6.0, -48.0)   ## 낮, 지는 해, 달
const FIELD_SUN_YAW: Vector2 = Vector2(-60.0, 120.0)           ## 해 / 달이 오는 쪽
const FIELD_AMBIENT_NIGHT: Color = Color(0.34, 0.4, 0.55)
const FIELD_AMBIENT_NIGHT_ENERGY: float = 1.5
const FIELD_AMBIENT_NIGHT_SKY: float = 0.1                     ## 밤에 환경광이 하늘에서 받는 몫(낮 1)
const FIELD_FOG_NIGHT: Color = Color(0.05, 0.06, 0.09)
const FIELD_FOG_NIGHT_MULT: float = 1.4
const FIELD_SKY_TINT_NIGHT: Color = Color(0.75, 0.85, 1.0)
const FIELD_SKY_TINT_DUSK: Color = Color(1.0, 0.5, 0.32)
## 밤에만 서는 무리(낮 무리와 같은 모양, 해가 지면 서고 날이 밝으면 덤비는 중이 아닌 것부터 사라진다). 세기 zone은 낮 무리처럼 1부터이고 서는 밤에는 FIELD_NIGHT_ZONE이 더해진다.
## 자리는 막힌 곳과 낮 무리·상자·비석에서 떨어뜨려 테스트가 본다.
const NIGHT_PACKS: Dictionary = {
	"night_road": {"at": Vector2(62, 36), "wander": 3.5, "zone": 3, "foes": [[&"wraith", 3], [&"wolf", 1]]},
	"night_brook": {"at": Vector2(70, 56), "wander": 3.5, "zone": 3, "foes": [[&"wolf", 2], [&"wraith", 2]]},
	"night_old_field": {"at": Vector2(64, 92), "wander": 3.5, "zone": 4, "foes": [[&"wraith", 3], [&"wolf", 2]]},
	"night_hamlet": {"at": Vector2(222, 54), "wander": 3.0, "zone": 8, "foes": [[&"wraith", 3], [&"wolf", 2]]},
}


## ---- 들판 날씨(docs/weather.md). 새벽(낮 가중치)과 해질녘(밤 가중치)마다 Rules.rng로 굴린다. 수치는 여기 하나에만 둔다.
const WEATHERS: Array[StringName] = [&"clear", &"rain", &"fog", &"storm", &"ash"]
const WEATHER_DAY: Dictionary = {&"clear": 40, &"rain": 22, &"fog": 14, &"storm": 8, &"ash": 16}
const WEATHER_NIGHT: Dictionary = {&"clear": 34, &"rain": 20, &"fog": 20, &"storm": 12, &"ash": 14}
const WEATHER_LINES: Dictionary = {&"clear": "하늘이 갠다", &"rain": "비가 내린다", &"fog": "안개가 낀다", &"storm": "폭풍이 몰아친다", &"ash": "잿바람이 분다"}
## 사건 자리는 GLINTS 칸에서 WX_OFFSET만큼 비껴 선다(흩어진 조각과 겹치지 않게). WX_POOLS: 사건 종류 → 쓸 GLINTS 번호(걸어 닿는 곳만).
const WX_OFFSET: Vector2 = Vector2(1.6, 1.2)
const WX_POOLS: Dictionary = {
	&"glint": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15],
	&"pilgrim": [0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11],
	&"struck": [3, 4, 5, 11, 12, 13, 15, 20, 21],
	&"cache": [12, 13, 14, 15, 20, 21, 22],
}
const WX_RAIN_GLINTS: int = 2
## 보상: 종류 → {shards: 조각 범위, mat: 재료(없으면 &""), mat_n: 재료 범위}. Meta.weather_reward가 Meta.rng로 굴린다.
const WX_REWARD: Dictionary = {
	&"glint": {"shards": Vector2i(3, 6), "mat": &"", "mat_n": Vector2i(0, 0)},
	&"pilgrim": {"shards": Vector2i(12, 20), "mat": &"", "mat_n": Vector2i(0, 0)},
	&"struck": {"shards": Vector2i(15, 25), "mat": &"iron", "mat_n": Vector2i(2, 3)},
	&"cache": {"shards": Vector2i(25, 40), "mat": &"", "mat_n": Vector2i(0, 0)},
}
## 잿바람: 불씨 땅이 WX_ASH_EVERY초마다 영주 둘레 WX_ASH_RANGE(최소, 최대 칸)에 WX_ASH_COUNT곳 선다. 철 자리는 WX_ASH_IRON곳 더 생긴다.
const WX_ASH_EVERY: float = 5.0
const WX_ASH_COUNT: int = 2
const WX_ASH_RANGE: Vector2 = Vector2(3.0, 9.0)
const WX_ASH_IRON: int = 2
## 맑은 밤에 비석을 읽으면 한 줄 더(비석 id → 글).
const STONE_NIGHT_LINES: Dictionary = {
	"stone_1": "달빛 아래 보니 내려온 발자국이 하나도 없다.",
	"stone_2": "맑은 밤이면 풀 사이의 검들이 달을 되비춘다.",
	"stone_3": "물 위에 별이 떠 있다. 맹세도 이렇게 비쳤을 것이다.",
	"stone_4": "저 위, 꺼진 봉화 자리에 아직 재 냄새가 난다.",
	"stone_5": "숲 안쪽에서 누가 발을 끈다. 돌아보지 마라.",
	"stone_6": "오르는 이의 등 뒤로 마을 불빛이 작게 남는다.",
	"stone_7": "잠긴 문 안쪽에 긁은 자국이 가득하다.",
	"stone_8": "구덩이 밑에서 바퀴 소리가 난 것도 같다.",
	"stone_9": "우물 자리에만 풀이 자라지 않는다.",
}
## 화면: 날씨마다 안개 짙기 배수, 해 밝기 배수, 안개·빛 물들임(색, 섞는 정도). 날씨가 바뀌면 WX_BLEND초에 걸쳐 섞는다.
const WX_BLEND: float = 8.0
const WX_LOOK: Dictionary = {
	&"clear": {"fog": 1.0, "sun": 1.0, "tint": Color(1, 1, 1), "amt": 0.0},
	&"rain": {"fog": 1.8, "sun": 0.55, "tint": Color(0.5, 0.56, 0.62), "amt": 0.35},
	&"fog": {"fog": 4.0, "sun": 0.7, "tint": Color(0.62, 0.64, 0.66), "amt": 0.6},
	&"storm": {"fog": 2.2, "sun": 0.35, "tint": Color(0.3, 0.34, 0.4), "amt": 0.5},
	&"ash": {"fog": 2.0, "sun": 0.7, "tint": Color(0.75, 0.5, 0.32), "amt": 0.5},
}


## 비석 글에 날씨가 더하는 줄: 맑은 밤이면 한 줄 더.
static func stone_text(id: String, weather: StringName, night: bool) -> String:
	var t: String = STONES[id][2]
	if weather == &"clear" and night and STONE_NIGHT_LINES.has(id):
		t += "\n" + String(STONE_NIGHT_LINES[id])
	return t


## ---- 들판 지도(38단계, docs/open_world2.md). M으로 여는 지도 창(FieldMap)과 가 본 곳(Meta.field_seen).
## 밝힘 격자 한 칸은 들판 SEEN_CELL칸이고 격자는 SEEN_SIZE(들판 크기를 덮는다, 58 × 28 = 1624비트). 걸으면 영주 둘레 SEEN_RADIUS칸에 닿는 격자 칸이
## 밝혀진다. 장면(field.gd)은 SEEN_TICKS틱마다 영주 자리로 밝힌다.
const SEEN_CELL: int = 4
const SEEN_SIZE: Vector2i = Vector2i(58, 28)
const SEEN_RADIUS: float = 18.0
const SEEN_TICKS: int = 10
## 지도 위 곳 이름을 쓰는 자리(칸). 이름은 그 자리가 밝혀졌을 때만 보인다. 언덕길·개울가는 곳 칸이 넓어 길·물가 위에 둔다.
const MAP_LABELS: Dictionary = {
	&"road": Vector2(42, 95), &"brook": Vector2(24, 64), &"old_field": Vector2(84, 89), &"watchtower": Vector2(90, 47.5),
	&"grove": Vector2(17, 46), &"foot": Vector2(44, 9), &"keep": Vector2(134, 30), &"marsh": Vector2(139, 80),
	&"quarry": Vector2(198, 27), &"hamlet": Vector2(200, 60), &"pass": Vector2(200, 87),
	&"mine": Vector2(169, 73), &"aqueduct": Vector2(54, 82), &"giant": Vector2(13, 74), &"windmill": Vector2(14, 92),
	&"watermill": Vector2(35, 48), &"ravine": Vector2(20, 8),
}


## 시계(초)로 본 밤의 정도 0(낮)~1(밤)(화면용). 해질녘은 해가 지는 때(FIELD_DAY)를 가운데로 FIELD_TWILIGHT초에 걸쳐 어두워지고,
## 새벽은 날이 밝는 때(한 바퀴 끝, 시계 0)에 끝나도록 그 앞 FIELD_TWILIGHT초에 걸쳐 밝아진다. 그래서 시계 0(아침)은 늘 0이다.
static func night_amount(clock: float) -> float:
	var cycle: float = FIELD_DAY + FIELD_NIGHT
	var s: float = fposmod(clock, cycle)
	if s < cycle - FIELD_TWILIGHT:
		return smoothstep(FIELD_DAY - FIELD_TWILIGHT / 2.0, FIELD_DAY + FIELD_TWILIGHT / 2.0, s)
	return 1.0 - smoothstep(cycle - FIELD_TWILIGHT, cycle, s)


static func area_at(c: Vector2) -> StringName:
	for id in AREA_ORDER:
		if (AREAS[id] as Rect2).has_point(c):
			return StringName(id)
	return &"road"
