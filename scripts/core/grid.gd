class_name Grid
extends RefCounted
## 칸 좌표와 월드 좌표의 변환은 이 파일의 함수로만 한다.
## 1칸 = 2m. 싸움터 (0, 0) 칸의 바깥 모서리가 월드 원점이고, 칸 (x, y)는 월드 (x, z) 방향으로 늘어난다.

const CELL: float = 2.0
## 싸움터의 칸 수. Rules가 시작할 때 RunData.arena_size로 맞춘다.
static var size: Vector2i = Vector2i(34, 22)


static func cell_to_world(c: Vector2i, height: float = 0.0) -> Vector3:
	return Vector3((c.x + 0.5) * CELL, height, (c.y + 0.5) * CELL)


static func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL), floori(p.z / CELL))


## 칸 단위 실수 좌표(규칙이 쓰는 위치)와 월드 좌표. 칸 (x, y)의 가운데는 (x + 0.5, y + 0.5)다.
static func cells_to_world(v: Vector2, height: float = 0.0) -> Vector3:
	return Vector3(v.x * CELL, height, v.y * CELL)


static func world_to_cells(p: Vector3) -> Vector2:
	return Vector2(p.x / CELL, p.z / CELL)


## 시험판 수치(칸 단위)를 미터로 바꾼다.
static func cells_to_meters(v: float) -> float:
	return v * CELL


## 싸움터 한가운데(칸 단위 실수).
static func middle() -> Vector2:
	return Vector2(size) / 2.0
