class_name LordState
extends RefCounted
## 영주의 상태. 위치는 칸 단위 실수, 각도는 라디안(0 = 동쪽 +x, PI/2 = 남쪽 +y).

var pos: Vector2
var prev_pos: Vector2
var hp: float
var face: float = -PI / 2.0
## 마지막으로 움직인 방향. 돌진은 이쪽으로 한다.
var move_dir: Vector2 = Vector2(0.0, 1.0)
var cooldown: float = 0.0
## 휘두를 때마다 1, 2, 3, 1 … 3이 강타다. 0은 아직 안 휘두름.
var combo: int = 0
## 휘두르는 모습이 남은 시간.
var swing: float = 0.0
var big: bool = false
var dash: float = 0.0
var dash_dir: Vector2 = Vector2.ZERO
var dash_cooldown: float = 0.0
var invuln: float = 0.0
