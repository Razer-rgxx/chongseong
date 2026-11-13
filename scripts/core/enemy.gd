class_name Enemy
extends RefCounted
## 밤에 올라오는 적 하나. 위치는 칸 단위 실수.

var id: int
var data: EnemyData
var pos: Vector2
## 바로 앞 틱의 위치. 화면이 틱 사이를 이어 그릴 때 쓴다.
var prev_pos: Vector2
## 넉백으로 밀려나는 속도(칸/초).
var push: Vector2 = Vector2.ZERO
var face: Vector2 = Vector2.DOWN
var hp: float
var max_hp: float
var damage: float
var cooldown: float = 0.0
var dead: bool = false
