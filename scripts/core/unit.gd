class_name Unit
extends RefCounted
## 칸 위에서 움직이는 것 하나. 지금은 허수아비, 4단계부터 적도 이걸 쓴다. 위치는 칸 단위 실수.

var id: int
var pos: Vector2
## 바로 앞 틱의 위치. 화면이 틱 사이를 이어 그릴 때 쓴다.
var prev_pos: Vector2
var radius: float = 0.3
var hp: float = 1.0
var max_hp: float = 1.0
## 넉백 배수(공성추 0.26, 우두머리 0.13처럼 무거운 것은 덜 밀린다).
var knockback_mult: float = 1.0
var dummy: bool = false
## 허수아비가 돌아올 자리.
var home: Vector2
