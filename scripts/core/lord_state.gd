class_name LordState
extends RefCounted
## 영주의 상태. 위치는 칸 단위 실수, 각도는 라디안(0 = 동쪽 +x, PI/2 = 남쪽 +y).

var pos: Vector2
var prev_pos: Vector2
var hp: float
var face: float = -PI / 2.0
## 마지막으로 움직인 방향. 돌진은 이쪽으로 한다.
var move_dir: Vector2 = Vector2(0.0, 1.0)
var moving: bool = false
var cooldown: float = 0.0
## 연타 몇 번째인지(1부터). 0은 아직 안 휘두름.
var combo: int = 0
var combo_timer: float = 0.0
## 휘두르는 모습이 남은 시간과 그때의 범위(화면이 그린다).
var swing: float = 0.0
var swing_arc: float = 0.0
var swing_reach: float = 0.0
var big: bool = false
var dash: float = 0.0
var dash_dir: Vector2 = Vector2.ZERO
var dash_cooldown: float = 0.0
var invuln: float = 0.0
