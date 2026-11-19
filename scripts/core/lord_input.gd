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
## 겨눈 쪽의 적에게 갈고리를 걸고 날아가 벤다(밤).
var hook: bool = false
## 가까운 꽂힌 검을 뽑는다(낮).
var pull: bool = false
## 뽑는 동안 이 틱에 E나 좌클릭을 눌렀다(누른 순간만, 버팀 타이밍 판정에 쓴다. 14단계).
var pull_press: bool = false
## 다른 칸의 검으로 바꿔 쥔다. -1은 그대로, 0이나 1은 그 칸으로.
var swap_to: int = -1
