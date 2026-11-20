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
## 밀려나는 속도(칸/초, 돌격병에 받혔을 때). 적의 넉백처럼 knock_keep으로 줄어든다.
var push: Vector2 = Vector2.ZERO
## 갈고리: 날아가는 중이면 hook_target이 있고 hook은 남은 시간. 화면이 줄과 포물선을 그린다.
var hook: float = 0.0
var hook_target: Enemy = null
var hook_from: Vector2 = Vector2.ZERO
var hook_cooldown: float = 0.0
## 좌클릭 동작(docs/attacks.md 4절). 화면이 읽는다. 움직이는 동작(돌진, 물러남, 도약, 순간, 갈고리)은 move_from → move_to.
var move: StringName = &""
var move_t: float = 0.0
var move_time: float = 0.0
var move_from: Vector2 = Vector2.ZERO
var move_to: Vector2 = Vector2.ZERO
## 이 시간이 남아 있으면 걷지 못하고 돌진·갈고리·좌클릭도 못 한다(발도, 지진, 반격 자세, 연속 찌르기, 물러나 베기).
var move_lock: float = 0.0
## 반격 자세가 남은 시간. 이 동안 맞으면 피해 없이 반격한다.
var parry: float = 0.0
## 걸어 다니는 점프(30단계): 공중에 남은 시간(초). 0이면 땅에 있다. 높이는 air_height로(포물선).
var air: float = 0.0
## 지난 틱의 air(화면이 틱 사이 높이를 이어 그린다. Rules.step이 prev_pos와 같이 적는다).
var prev_air: float = 0.0
## 39단계 말: 탔는지와 말이 달리는 속도(칸/초, 방향 바꾸기가 느리다). 탄 채 공중(air)은 말 도약(HorseData.leap_time).
var riding: bool = false
var ride_vel: Vector2 = Vector2.ZERO


func airborne() -> bool:
	return air > 0.0


## 공중에 left초 남았을 때의 높이(m, 칸이 아니다). 뜬 순간과 내려앉는 순간이 0이고 가운데가 jump_height인 포물선.
static func air_height(left: float, D: LordData) -> float:
	return arc(left, D.jump_time, D.jump_height)


## 공중에 left초 남았을 때 높이(m): 뜬 시간 total, 가장 높은 곳 peak인 포물선(점프와 39단계 말 도약이 같이 쓴다).
static func arc(left: float, total: float, peak: float) -> float:
	if left <= 0.0 or total <= 0.0:
		return 0.0
	var u: float = clampf(1.0 - left / total, 0.0, 1.0)
	return 4.0 * peak * u * (1.0 - u)
