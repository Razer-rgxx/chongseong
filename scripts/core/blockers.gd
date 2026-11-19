class_name Blockers
extends RefCounted
## 장면의 막힌 곳에서 영주를 밀어낸다(30단계에서 들판·마을·무덤의 _push_out을 하나로 모았다). 노드에 기대지 않는 정적 함수뿐이다.
## 규칙(Rules)은 막힘을 모르고(싸움터에는 장애물이 없다), 장면이 틱마다 rules.step 뒤에 영주의 자리에 건다. 적은 지금처럼 막힘을 무시한다.
##
## 막힘 표: rects는 칸 단위 Rect2, circles는 [가운데(칸 Vector2), 반지름(칸)]. 그린 것과 막힘은 같은 표에서 나온다.
## 낮은 막힘(low_rects, low_circles)은 그린 높이가 JUMP_CLEAR m 이하인 것(울타리, 무너진 낮은 벽, 쓰러진 통나무, 우물 둘레 …)이다.
## 영주가 공중에 있으면(airborne) 지나가고, 땅에 있으면(내려앉은 틱도) 높은 막힘처럼 밀어낸다. 높은 막힘은 공중이어도 막는다.

## 이 높이(m) 이하로 그린 막힘은 점프로 넘는다(LordData.jump_height 1.1m보다 낮다).
const JUMP_CLEAR: float = 1.0
## 영주 몸 반지름(칸): 막힌 곳에서 이만큼 떨어진다.
const BODY: float = 0.3
## 밀어낸 자리가 이웃 막힘 안이면 다시 민다(겹친 둥근 막힘 줄, 벽 모서리). 이 횟수까지.
const PASSES: int = 4


## 그 높이(m)로 그린 막힘이 낮은 막힘인가.
static func is_low(height_m: float) -> bool:
	return height_m <= JUMP_CLEAR


## p(칸)를 막힌 곳 밖으로 민다. 둥근 막힘은 가운데에서 바깥으로, 네모 막힘은 가장 가까운 변으로.
## airborne이면 낮은 막힘은 보지 않는다.
static func push_out(p: Vector2, rects: Array, circles: Array, low_rects: Array = [], low_circles: Array = [], airborne: bool = false, r: float = BODY) -> Vector2:
	for pass_i in PASSES:
		var before: Vector2 = p
		p = _out_circles(p, circles, r)
		if not airborne:
			p = _out_circles(p, low_circles, r)
		p = _out_rects(p, rects, r)
		if not airborne:
			p = _out_rects(p, low_rects, r)
		if p.distance_squared_to(before) < 1e-10:
			break
	return p


## p가 막힌 곳 안인가(테스트·점검용). 낮은 막힘은 airborne이 아닐 때만 본다.
static func inside(p: Vector2, rects: Array, circles: Array, low_rects: Array = [], low_circles: Array = [], airborne: bool = false, r: float = BODY) -> bool:
	return push_out(p, rects, circles, low_rects, low_circles, airborne, r).distance_squared_to(p) > 1e-8


static func _out_circles(p: Vector2, circles: Array, r: float) -> Vector2:
	for c in circles:
		var at: Vector2 = c[0]
		var d: Vector2 = p - at
		var min_d: float = float(c[1]) + r
		if d.length() < min_d:
			p = at + (d.normalized() if d.length() > 0.001 else Vector2.DOWN) * min_d
	return p


static func _out_rects(p: Vector2, rects: Array, r: float) -> Vector2:
	for rect: Rect2 in rects:
		var g: Rect2 = rect.grow(r)
		if g.has_point(p):
			var left: float = p.x - g.position.x
			var right: float = g.end.x - p.x
			var up: float = p.y - g.position.y
			var down: float = g.end.y - p.y
			var m: float = minf(minf(left, right), minf(up, down))
			if m == left:
				p.x = g.position.x
			elif m == right:
				p.x = g.end.x
			elif m == up:
				p.y = g.position.y
			else:
				p.y = g.end.y
	return p
