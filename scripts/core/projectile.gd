class_name Projectile extends RefCounted
var kind: StringName       # &"wave", &"boomerang"
var pos: Vector2           # 칸
var prev_pos: Vector2
var dir: Vector2           # 단위 벡터
var returning: bool        # 칼 던지기가 돌아오는 중
var element: StringName
var width: float           # 칸
var id: int
