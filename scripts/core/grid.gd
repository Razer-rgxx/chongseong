class_name Grid
extends RefCounted
## 칸 좌표와 월드 좌표의 변환은 이 파일의 두 함수로만 한다.
## 1칸 = 2m. 맵 (0, 0) 칸의 바깥 모서리가 월드 원점이고, 칸 (x, y)는 월드 (x, z) 방향으로 늘어난다.

const CELL: float = 2.0
## 한 변의 칸 수. Rules가 시작할 때 RunData.map_size로 맞춘다.
static var size: int = 33


static func cell_to_world(c: Vector2i, height: float = 0.0) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, height, (c.y + 0.5) * CELL)


static func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


static func in_map(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size and c.y < size


static func index(c: Vector2i) -> int:
	return c.y * size + c.x


@warning_ignore("integer_division")
static func cell_of(i: int) -> Vector2i:
	return Vector2i(i % size, i / size)


## 영주관이 서는 가운데 칸.
@warning_ignore("integer_division")
static func center() -> Vector2i:
	return Vector2i(size / 2, size / 2)


## 체비쇼프 거리(가로세로 중 먼 쪽). 성벽 고리와 맵 비우기에 쓴다.
static func ring_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## 칸 단위 실수 좌표(규칙이 쓰는 위치)와 월드 좌표. 칸 (x, y)의 가운데는 (x + 0.5, y + 0.5)다.
static func cells_to_world(v: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(v.x * CELL, height, v.y * CELL)


static func world_to_cells(p: Vector3) -> Vector2:
	return Vector2(p.x / CELL, p.z / CELL)


## 시연판 수치(칸 단위)를 미터로 바꾼다.
static func cells_to_meters(v: float) -> float:
	return v * CELL
