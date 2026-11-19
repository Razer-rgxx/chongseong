class_name FieldLayout
extends RefCounted
## 들판(16단계, docs/village.md 16)의 자리와 값. 자리는 여기 하나에만 둔다. 모든 자리는 칸 좌표(1칸 = 2m).
## 위쪽(y 작은 쪽)이 북쪽이다: 언덕 발치는 북, 마을 문은 남.

const SIZE: Vector2i = Vector2i(230, 110)   ## 28단계: 동쪽으로 60칸 더(20단계 170, 원래 110 x 110)
const WORLD_X: float = 460.0   ## m
const WORLD_Z: float = 220.0

const AREA_ORDER: PackedStringArray = ["quarry", "hamlet", "pass", "keep", "marsh", "foot", "watchtower", "grove", "old_field", "brook", "road"]
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
}
const AREA_NAMES: Dictionary = {
	&"road": "언덕길", &"old_field": "옛 싸움터", &"watchtower": "무너진 망루",
	&"brook": "개울가", &"grove": "검은 숲 가장자리", &"foot": "언덕 발치",
	&"keep": "무너진 성채", &"marsh": "안개 늪",
		&"quarry": "버려진 채석장", &"hamlet": "불탄 마을", &"pass": "까마귀 고개",
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
	Rect2(167, 0, 3, 22), Rect2(167, 32, 3, 20), Rect2(167, 66, 3, 25), Rect2(167, 99, 3, 11),
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
const HAMLET_WALLS: Array[Rect2] = [
	Rect2(174, 45, 7, 0.5), Rect2(174, 49.5, 2.3, 0.5), Rect2(178.7, 49.5, 2.3, 0.5), Rect2(174, 45.5, 0.5, 1.4), Rect2(180.5, 45.5, 0.5, 4),
	Rect2(198, 45, 6, 0.5), Rect2(198, 49.5, 1.8, 0.5), Rect2(202.2, 49.5, 1.8, 0.5), Rect2(198, 45.5, 0.5, 4), Rect2(203.5, 47.5, 0.5, 2),
	Rect2(212, 45, 3.5, 0.5), Rect2(212, 49.5, 2.3, 0.5), Rect2(216.7, 49.5, 2.3, 0.5), Rect2(212, 45.5, 0.5, 4), Rect2(218.5, 45.5, 0.5, 4),
	Rect2(176, 66, 2.3, 0.5), Rect2(180.7, 66, 2.3, 0.5), Rect2(176, 71.5, 7, 0.5), Rect2(176, 66.5, 0.5, 5), Rect2(182.5, 66.5, 0.5, 1.5), Rect2(182.5, 70.5, 0.5, 1),
	Rect2(200, 67, 1.8, 0.5), Rect2(204.2, 67, 1.8, 0.5), Rect2(202.7, 72.5, 3.3, 0.5), Rect2(200, 67.5, 0.5, 5), Rect2(205.5, 67.5, 0.5, 5),
	Rect2(214, 66, 2.3, 0.5), Rect2(218.7, 66, 2.3, 0.5), Rect2(214, 71.5, 7, 0.5), Rect2(214, 66.5, 0.5, 2.5), Rect2(220.5, 66.5, 0.5, 5),
]
const HAMLET_WELL: Rect2 = Rect2(191, 51.5, 2, 2)
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
