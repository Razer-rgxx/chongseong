class_name PressBuffer
extends RefCounted
## 눌림 선입력(조작감): 누른 순간부터 window초 동안 "눌렀다"로 남겨, 규칙이 받아 줄 수 있는 틱에 쓰이게 한다.
## 화면(입력을 모으는 쪽) 일이라 규칙과 LordInput은 그대로다. 규칙이 받아 줬으면(consumed) 바로 비운다.

var left: float = 0.0


func press(window: float) -> void:
	left = maxf(window, 0.0)


func on() -> bool:
	return left > 0.0


func end_tick(dt: float, consumed: bool) -> void:
	left = 0.0 if consumed else maxf(0.0, left - dt)
