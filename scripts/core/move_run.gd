class_name MoveRun
extends RefCounted
## 좌클릭 한 번(동작 하나)이 진행되는 동안의 값. 늦게 터지는 판정과 날아가는 것이 이것을 들고 있다(Moves가 쓴다).

var id: int = 0
var move: MoveData
## 몇 번째 동작인지(1부터)와 이 방식의 동작 수.
var step: int = 1
var steps: int = 1
## 큰 베기(넉백, 히트스톱, 연격·무거움 같은 각인). 마지막 동작이거나 마지막 숨.
var big: bool = false
## 방식의 마지막 동작(마무리). 메아리는 이것만 울린다.
var finisher: bool = false
var element: StringName = &""
## 메아리로 다시 울리는 것이면 true(영주를 옮기지 않고, 내구를 닳게 하지 않고, after_swing을 부르지 않는다).
var echo: bool = false
## 방식에 메아리가 있는지(마무리의 판정마다 echo_delay초 뒤 한 번 더).
var echo_next: bool = false
## 휘두른 검(내구는 이 검이 아직 쥔 검일 때만 닳는다). 맨손이면 null.
var sword: Sword
## 휘두를 때의 Powers.stats().
var st: Dictionary = {}
## 한 번 맞힐 때의 피해(동작 배수를 곱하기 전, Powers.swing_damage를 거친 값).
var base: float = 0.0
## 넉백 세기(방향에 곱한다).
var knock: float = 0.0
var at: Vector2 = Vector2.ZERO
var face: float = 0.0
var from: Vector2 = Vector2.ZERO
var to: Vector2 = Vector2.ZERO
## 이 동작이 맞힌 적(after_swing에 넘긴다).
var hits: Array[Enemy] = []
## 이 동작에서 한 번만 맞히는 적(돌진의 길). id → true
var seen: Dictionary = {}
var wore: bool = false
var swung: bool = false
## 메아리: 다시 울릴 때 move_started를 한 번 보냈는지.
var echo_started: bool = false
## 오른쪽 클릭 갈고리의 베기인지(방식의 동작이 아니다).
var grapple: bool = false
## 이 동작의 메아리(처음 다시 울릴 때 만든다).
var echo_run: MoveRun = null


## 메아리로 다시 울릴 것. 피해에 mult를 곱한다.
func echo_copy(mult: float) -> MoveRun:
	var e := MoveRun.new()
	e.id = id
	e.move = move
	e.step = step
	e.steps = steps
	e.big = big
	e.finisher = finisher
	e.element = element
	e.echo = true
	e.sword = sword
	e.st = st
	e.base = base * mult
	e.knock = knock
	e.at = at
	e.face = face
	e.from = from
	e.to = to
	return e
