class_name LordInput
extends RefCounted
## 한 틱 동안의 영주 입력. 규칙은 이것만 보고 움직이니, 이것을 틱마다 기록하면 판을 그대로 다시 돌릴 수 있다.

## 길이 1 이하. x는 동쪽, y는 남쪽.
var move: Vector2 = Vector2.ZERO
var aim_valid: bool = false
## 마우스가 가리키는 땅(칸 단위).
var aim: Vector2 = Vector2.ZERO
var attack: bool = false
var dash: bool = false
