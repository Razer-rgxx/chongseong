class_name Projectile extends RefCounted
## 날아가는 것(검기, 던진 칼). Rules.projectiles에 있고 규칙이 틱마다 옮겨 맞힌다(물리로 맞히지 않는다).
## 화면(MoveFx)은 pos·prev_pos·dir·returning을 읽어 그린다.

var kind: StringName       # &"wave", &"boomerang"
var pos: Vector2           # 칸
var prev_pos: Vector2
var dir: Vector2           # 단위 벡터
var returning: bool        # 칼 던지기가 돌아오는 중
var element: StringName
var width: float           # 칸
var id: int
## 규칙만 쓰는 것: 빠르기(칸/초), 갈 거리, 지금까지 간 거리, 난 뒤 지난 시간, 이번 길에 맞힌 적(id → true), 어느 좌클릭의 것인지.
var speed: float = 0.0
var distance: float = 0.0
var travelled: float = 0.0
var age: float = 0.0
var max_time: float = 3.0
var hit_ids: Dictionary = {}
var run: MoveRun
