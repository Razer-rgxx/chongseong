class_name CryptLayout
extends RefCounted
## 지하 무덤(19단계, docs/outside.md)의 방·문·관·무리. 자리와 수치는 여기 하나에만 둔다. 칸 좌표(1칸 = 2m), 위쪽(y 작은 쪽)이 북쪽.
##
## 모양(나무 모양 그래프, 문 5개):
##   r1 입구 -- r2 갈림 -+- r3 서쪽 -- r5 서쪽 끝(막다른 방)
##                       +- r4 동쪽 -- r6 마지막 방(무덤 주인)
## 방에 들어서면(방 안쪽 ENTER_INSET칸) 그 방의 문이 모두 닫히고, 그 방 무리를 다 쓰러뜨리면 열린다.

const SIZE: Vector2i = Vector2i(70, 76)
const ROOM_ORDER: Array[StringName] = [&"r1", &"r2", &"r3", &"r5", &"r4", &"r6"]

## 방 안으로 이만큼(칸) 들어서면 "들어섰다". 문 막힘은 방 가장자리에서 시작하므로 들어선 뒤에 닫힌다.
const ENTER_INSET: float = 1.5
## 영주 몸 반지름(칸): 막힌 곳에서 이만큼 떨어진다.
const BODY: float = 0.3
## 일반 돌 관의 조각(범위, Meta.rng), 큰 관의 조각과 운 부적(상인·무덤 기사의 것과 같다).
const COFFIN_MIN: int = 10
const COFFIN_MAX: int = 25
const BIG_SHARDS: int = 60
const BIG_CHARM: StringName = &"charm"
## 관 앞에서 E가 먹는 거리(칸), 관이 막는 반지름(칸).
const COFFIN_REACH: float = 2.0
const COFFIN_RADIUS: float = 1.0
## 무덤 주인(마지막 방)의 불려 오는 적 세기 구역과 이름.
const LORD_ID: StringName = &"crypt_lord"
const LORD_ZONE: int = 7

## 나가는 문(입구 방 남쪽 벽): E를 누르는 자리와 영주가 들어서는 자리.
const EXIT_AT: Vector2 = Vector2(35, 71.3)
const START: Vector2 = Vector2(35, 69.0)

## 방 id → {rect, coffin(관 자리), pack(무리: at, wander, zone(1부터), foes) 또는 boss(at, kind, zone), big(마지막 방 큰 관)}.
## 무리는 3~6마리, 세기는 5~7구역(RunData의 구역 배수). 자리는 방 안, 관에서 떨어진 곳.
const ROOMS: Dictionary = {
	&"r1": {"rect": Rect2(26, 58, 18, 14), "coffin": Vector2(28.5, 65.0),
		"pack": {"at": Vector2(35, 64), "wander": 3.0, "zone": 5, "foes": [[&"wraith", 3], [&"wolf", 1]]}},
	&"r2": {"rect": Rect2(26, 40, 18, 14), "coffin": Vector2(35, 42.2),
		"pack": {"at": Vector2(35, 48), "wander": 3.5, "zone": 5, "foes": [[&"archer", 2], [&"shield", 1], [&"wraith", 2]]}},
	&"r3": {"rect": Rect2(4, 40, 18, 14), "coffin": Vector2(7.0, 51.0),
		"pack": {"at": Vector2(13, 46), "wander": 3.5, "zone": 6, "foes": [[&"wolf", 3], [&"bomber", 1], [&"charger", 1]]}},
	&"r5": {"rect": Rect2(4, 22, 18, 14), "coffin": Vector2(13, 24.2),
		"pack": {"at": Vector2(13, 29), "wander": 3.5, "zone": 6, "foes": [[&"shield", 2], [&"archer", 2], [&"wraith", 1]]}},
	&"r4": {"rect": Rect2(48, 40, 18, 14), "coffin": Vector2(63.5, 50.0),
		"pack": {"at": Vector2(57, 46), "wander": 3.5, "zone": 6, "foes": [[&"charger", 2], [&"caller", 1], [&"wraith", 2]]}},
	&"r6": {"rect": Rect2(48, 22, 18, 14), "coffin": Vector2(57, 23.6), "big": true,
		"boss": {"at": Vector2(57, 28.0), "kind": &"crypt_lord", "zone": 7}},
}

## 문 id → {gap(돌판이 서는 복도), walk(열렸을 때 걷는 곳: 복도에서 양쪽 방으로 1칸씩 겹친다), rooms(이어지는 두 방)}.
## 문은 그 두 방 가운데 영주가 들어서 있는 방이 아직 안 쓰러뜨려졌으면 닫힌다.
const DOORS: Dictionary = {
	&"d12": {"gap": Rect2(33, 54, 4, 4), "walk": Rect2(33, 53, 4, 6), "rooms": [&"r1", &"r2"]},
	&"d23": {"gap": Rect2(22, 45, 4, 4), "walk": Rect2(21, 45, 6, 4), "rooms": [&"r2", &"r3"]},
	&"d35": {"gap": Rect2(11, 36, 4, 4), "walk": Rect2(11, 35, 4, 6), "rooms": [&"r3", &"r5"]},
	&"d24": {"gap": Rect2(44, 45, 4, 4), "walk": Rect2(43, 45, 6, 4), "rooms": [&"r2", &"r4"]},
	&"d46": {"gap": Rect2(55, 36, 4, 4), "walk": Rect2(55, 35, 4, 6), "rooms": [&"r4", &"r6"]},
}

## 횃불 자리(방 id → 방 안쪽 모서리에서의 간격 칸, 방마다 둘: 북쪽 두 모서리). 빛과 불꽃은 화면 쪽이 만든다.
const TORCH_INSET: float = 2.0


## 영주가 "들어서 있는" 방(방 안쪽 ENTER_INSET칸 안). 복도·문턱이면 &"".
static func room_at(p: Vector2) -> StringName:
	for id in ROOM_ORDER:
		if (ROOMS[id].rect as Rect2).grow(-ENTER_INSET).has_point(p):
			return id
	return &""


## 방 하나가 지금 문을 막고 있는지(들어서 있고 아직 안 쓰러뜨림). cleared는 그 방이 쓰러뜨려졌는지.
static func door_closed(door: StringName, lord_room: StringName, cleared_rooms: Dictionary) -> bool:
	var rooms: Array = DOORS[door].rooms
	return rooms.has(lord_room) and not cleared_rooms.has(lord_room)


## 영주가 설 수 있는 곳(걷는 판): 모든 방과 열린 문의 걷는 곳.
static func walkable(open_doors: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for id in ROOM_ORDER:
		out.append(ROOMS[id].rect)
	for d in DOORS:
		if open_doors.has(d):
			out.append(DOORS[d].walk)
	return out


## 걷는 판 밖에 있으면 가장 가까운 걸을 수 있는 곳으로 밀어 넣고, 관(둥근 막힘, Blockers)에서 밀어낸다.
## 벽(CryptBuilder.WALL_H 1.5m)과 관(땅 위 1.2m)은 모두 높은 막힘이라 공중이어도 막는다. 낮은 막힘은 없다(돌무더기는 막힘이 아닌 꾸밈).
static func push_in(p: Vector2, open_doors: Dictionary, airborne: bool = false) -> Vector2:
	var best: Vector2 = p
	var best_d: float = INF
	for r in walkable(open_doors):
		var inner: Rect2 = r.grow(-BODY)
		var q := Vector2(clampf(p.x, inner.position.x, inner.end.x), clampf(p.y, inner.position.y, inner.end.y))
		var d: float = p.distance_squared_to(q)
		if d < best_d:
			best_d = d
			best = q
			if d == 0.0:
				break
	p = best
	return Blockers.push_out(p, [], coffin_circles(), [], [], airborne, BODY)


## 관의 둥근 막힘([가운데, 반지름], Blockers 모양).
static func coffin_circles() -> Array:
	var out: Array = []
	for id in ROOM_ORDER:
		out.append([ROOMS[id].coffin, COFFIN_RADIUS])
	return out


## 방의 가운데(무리·무덤 주인 자리).
static func home_of(id: StringName) -> Vector2:
	var R: Dictionary = ROOMS[id]
	if R.has("boss"):
		return R.boss.at
	return R.pack.at
