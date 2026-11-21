class_name Ghost
extends RefCounted
## 검 주인의 잔영(docs/sword_hill.md 2번). Meta.fallen 기록의 마지막 몇 초 몸놀림을 그대로 다시 움직인다.
## 기록의 자리는 나타난 자리로 옮긴다(첫 자리 → 나타난 자리). 휘두름이 적힌 틱(act 1, 큰 베기 2)에 앞을 벤다(Rules._ghost_swing).
## 규칙 안의 것이라 state_hash에 든다. 그리기는 GhostView.

var id: int
## 주인이 쥐고 있던 검(SwordData.id).
var sword_id: int
## [x, y, 얼굴, 휘두름] × 틱.
var frames := PackedFloat32Array()
var offset := Vector2.ZERO
## 다음에 읽을 틱.
var i: int = 0
var pos := Vector2.ZERO
var prev_pos := Vector2.ZERO
var face: float = 0.0


func count() -> int:
	return frames.size() / 4


func done() -> bool:
	return i >= count()


## 0~1: 얼마나 다시 움직였는지(그리기: 끝으로 갈수록 흐려진다).
func progress() -> float:
	return float(i) / float(maxi(1, count()))
