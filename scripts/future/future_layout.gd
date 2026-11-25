class_name FutureLayout
extends RefCounted
## 녹슨 미래 구역(docs/stranger.md 3단계)의 자리와 값. 자리는 여기 하나에만 둔다. 칸 좌표(1칸 = 2m), 위쪽(y 작은 쪽)이 북쪽.
## 폐허가 된 도시 한 블록: 둘레에 무너진 탑 일곱, 가운데는 트인 거리, 거리 위에 부서진 고가.

const SIZE: Vector2i = Vector2i(80, 60)
const START: Vector2 = Vector2(40, 54.5)
## 돌아가는 틈(구역 안)과 들판에서 틈이 서는 자리. 들판 쪽은 낯선 사람이 처음 서던 자리 곁(FieldLayout.STRANGER_SPOTS[0])이다.
const EXIT_AT: Vector2 = Vector2(40, 57.4)
const RIFT_FIELD: Vector2 = Vector2(50, 98.5)
const RIFT_WAKE: Vector2 = Vector2(50, 96.0)
const DROP_OFFSET: Vector2 = Vector2(1.5, 0.0)
const REACH: float = 2.0

## 미래의 능력(Rules.era == future). 사거리 +15%, 마무리 베기 뒤 데이터 메아리(Moves, LordData.echo_delay·echo_damage).
const REACH_MULT: float = 1.15

## 이 구역에서만 하는 일: 단말(E)은 다음 언덕 판 손잡이 조짐을 모두 보여 주고(Meta.pack의 &"note"), 상자는 조각을 한 번 준다.
const NOTE: StringName = &"note"
const TERMINAL_AT: Vector2 = Vector2(68, 21.5)
const CACHE_ID: String = "future_cache"
const CACHE_AT: Vector2 = Vector2(10, 40.5)
const CACHE_SHARDS: int = 90

## 탑: {rect(칸), h(높이 m), ruin(참이면 윗부분이 무너진 모양)}. 모두 막힘(키 큰 막힘).
const TOWERS: Array[Dictionary] = [
	{"rect": Rect2(4, 4, 18, 14), "h": 30.0},
	{"rect": Rect2(30, 3, 20, 11), "h": 38.0},
	{"rect": Rect2(58, 4, 18, 14), "h": 24.0, "ruin": true},
	{"rect": Rect2(4, 24, 12, 12), "h": 11.0, "ruin": true},
	{"rect": Rect2(64, 26, 12, 14), "h": 32.0},
	{"rect": Rect2(4, 44, 14, 10), "h": 16.0},
	{"rect": Rect2(62, 46, 14, 10), "h": 18.0, "ruin": true},
]

## 서 있는 고가의 상판(칸 사각형, 바닥에서 높이 m)과 기둥(원: 중심, 반지름 칸). 상판 밑은 걸어 지나간다. 기둥만 막는다.
const DECK: Rect2 = Rect2(20, 30, 16, 4)
const DECK_H: float = 6.0
const PILLARS: Array[Vector3] = [Vector3(21.0, 31.0, 0.8), Vector3(35.0, 31.0, 0.8), Vector3(21.0, 33.0, 0.8), Vector3(35.0, 33.0, 0.8)]
## 무너져 누운 상판(낮은 막힘, 뛰어넘는다): {rect, tilt(도)}.
const FALLEN: Array[Dictionary] = [
	{"rect": Rect2(38, 31, 12, 4), "tilt": 12.0},
	{"rect": Rect2(52, 37, 4, 11), "tilt": -10.0},
]

## 녹슨 자동차: 중심과 방향(참이면 남북으로 누움). 낮은 막힘(뛰어넘는다).
const CARS: Array[Vector3] = [
	Vector3(26, 22, 0), Vector3(30, 24, 0), Vector3(46, 20, 1), Vector3(58, 24, 0), Vector3(30, 44, 0),
	Vector3(44, 46, 1), Vector3(52, 52, 0), Vector3(24, 38, 1), Vector3(60, 34, 1), Vector3(36, 40, 0),
	Vector3(20, 52, 0), Vector3(66, 44, 1), Vector3(20, 22, 1), Vector3(70, 22, 0),
	Vector3(34, 18, 0), Vector3(14, 21, 0), Vector3(58, 50, 1), Vector3(28, 50, 0), Vector3(50, 40, 1), Vector3(60, 28, 0),
]
const CAR_SIZE: Vector2 = Vector2(2.3, 1.0)   ## 칸(남북이면 뒤바뀐다)

## 웅덩이(칸 중심, 반지름 m).
const PUDDLES: Array[Vector3] = [
	Vector3(36, 48, 2.6), Vector3(46, 28, 3.2), Vector3(28, 14.5, 2.2), Vector3(54, 44, 2.4), Vector3(40, 20, 1.8),
	Vector3(22, 46, 2.0), Vector3(62, 20, 2.6), Vector3(42, 36.5, 1.6), Vector3(14, 40, 2.2), Vector3(68, 38, 1.8),
]

## 꺼져 가는 네온 간판(글자 없음, 도형만): {at(칸), y(m), size(가로·세로 m), yaw(도), color, rate(깜빡임 속도), shape(bar·frame·arrow), dead(꺼진 마디 번호들), mode(flicker·half·steady)}. 탑 벽에 붙는다.
## half는 대부분 죽어 있다가 가끔 지직 켜진다. dead는 처음부터 꺼진 마디다.
const NEON_VIOLET: Color = Color(0.55, 0.38, 0.95)
const NEON_BLUE: Color = Color(0.3, 0.62, 0.95)
const NEON_GREEN: Color = Color(0.5, 0.82, 0.38)
const NEONS: Array[Dictionary] = [
	{"at": Vector2(13, 18.2), "y": 5.0, "size": Vector2(5.0, 1.2), "yaw": 0.0, "color": NEON_BLUE, "rate": 7.0, "shape": "bar", "dead": [2, 3], "mode": "flicker"},
	{"at": Vector2(40, 14.2), "y": 7.0, "size": Vector2(2.0, 6.0), "yaw": 0.0, "color": NEON_VIOLET, "rate": 4.0, "shape": "frame", "dead": [], "mode": "flicker"},
	{"at": Vector2(22.2, 11), "y": 4.0, "size": Vector2(1.0, 4.5), "yaw": 90.0, "color": NEON_GREEN, "rate": 11.0, "shape": "bar", "dead": [1], "mode": "half"},
	{"at": Vector2(57.8, 12), "y": 6.0, "size": Vector2(1.0, 3.0), "yaw": 90.0, "color": NEON_VIOLET, "rate": 5.5, "shape": "bar", "dead": [], "mode": "flicker"},
	{"at": Vector2(63.8, 33), "y": 5.5, "size": Vector2(1.0, 5.0), "yaw": 90.0, "color": NEON_BLUE, "rate": 9.0, "shape": "arrow", "dead": [3], "mode": "flicker"},
	{"at": Vector2(18.2, 49), "y": 4.0, "size": Vector2(1.0, 3.5), "yaw": 90.0, "color": NEON_GREEN, "rate": 3.5, "shape": "frame", "dead": [], "mode": "half"},
	{"at": Vector2(69, 45.8), "y": 3.5, "size": Vector2(5.5, 1.0), "yaw": 0.0, "color": NEON_BLUE, "rate": 13.0, "shape": "bar", "dead": [0, 4], "mode": "flicker"},
	{"at": Vector2(16.2, 30), "y": 3.0, "size": Vector2(1.0, 2.5), "yaw": 90.0, "color": NEON_VIOLET, "rate": 6.0, "shape": "arrow", "dead": [], "mode": "steady"},
]
## 네온 곁의 작은 빛(비싸니 넷만, 그림자 없음): NEONS 번호.
const NEON_LIGHTS: Array[int] = [1, 2, 4, 6]

## 무리: id → {at, wander(칸), zone(1부터), foes: [[적 id, 수], ...]}. Rules.spawn_pack(id, def)에 그대로 넘긴다.
const PACKS: Dictionary = {
	"drones": {"at": Vector2(40, 24), "wander": 4.0, "zone": 6, "foes": [[&"drone", 4]]},
	"husks_w": {"at": Vector2(24, 45), "wander": 3.5, "zone": 6, "foes": [[&"husk", 2], [&"drone", 2]]},
	"husks_e": {"at": Vector2(56, 22), "wander": 3.5, "zone": 7, "foes": [[&"husk", 3], [&"drone", 2]]},
}

## 빛깔: 가라앉은 차가운 파랑에 보라 조금. 채도 낮게.
const BG: Color = Color(0.035, 0.045, 0.075)
const FOG: Color = Color(0.095, 0.11, 0.175)
const AMBIENT: Color = Color(0.36, 0.42, 0.58)
const MOON: Color = Color(0.58, 0.68, 0.95)
const CONCRETE: Color = Color(0.26, 0.29, 0.36)
const ASPHALT: Color = Color(0.085, 0.095, 0.125)
const RUST: Color = Color(0.3, 0.21, 0.17)
## 미래에서 벨 때 베기 빛과 동작 빛의 색(보기만 한다).
const TRAIL: Color = Color(0.38, 0.78, 1.0)


## 막힘 표: {rects(키 큰), circles(키 큰), low_rects(낮은: 자동차·누운 상판), low_circles}. Rules.set_blockers에 그대로 넘긴다.
static func blockers() -> Dictionary:
	var rects: Array = []
	var circles: Array = []
	var low: Array = []
	for t in TOWERS:
		rects.append(t.rect)
	for p in PILLARS:
		circles.append([Vector2(p.x, p.y), p.z])
	for f in FALLEN:
		low.append(f.rect)
	for c in CARS:
		var sz: Vector2 = CAR_SIZE if c.z == 0.0 else Vector2(CAR_SIZE.y, CAR_SIZE.x)
		low.append(Rect2(Vector2(c.x, c.y) - sz / 2.0, sz))
	return {"rects": rects, "circles": circles, "low_rects": low, "low_circles": []}
