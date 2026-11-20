class_name Horse
extends RefCounted
## 39단계 말의 상태(규칙, 노드 없음). Rules.horse 하나. 위치는 칸, 각은 라디안(0 = 동쪽 +x, PI/2 = 남쪽 +y).
## AWAY: 없음(부르기 전). COMING: 부름을 받고 영주 곁으로 달려오는 중. STANDING: 서 있다(내린 뒤 coast로 몇 걸음 더 가기도 한다). RIDDEN: 영주가 탔다(자리는 영주를 따른다).

const AWAY: int = 0
const COMING: int = 1
const STANDING: int = 2
const RIDDEN: int = 3

var state: int = AWAY
var pos: Vector2 = Vector2.ZERO
var prev_pos: Vector2 = Vector2.ZERO
var face: float = 0.0
## 지금 달리는 빠르기(칸/초). 화면이 걸음을 고른다.
var speed: float = 0.0
## 부른 뒤 지난 시간(초, come_max를 넘으면 곁에 바로 선다).
var come_t: float = 0.0


## 화면에 보이는가(부른 뒤).
func present() -> bool:
	return state != AWAY


## 내려 있고 서 있거나 오는 중(나침반·지도에 자리를 띄운다).
func waiting() -> bool:
	return state == COMING or state == STANDING
