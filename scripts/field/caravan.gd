class_name Caravan
extends RefCounted
## 상인 행렬(2026-11-24, docs/landmarks.md 1). 들판 시계(Rules.field_clock)만으로 위치가 정해지는 화면 쪽 계산이다.
## Rules에는 상태가 없고(막힘도 없다), 같은 시계면 늘 같은 자리다(테스트가 본다). 수치는 FieldLayout.CARAVAN_*.
##
## 한 바퀴(낮 + 밤) 안에서 CARAVAN_STARTS의 때마다 수레 줄이 장터 문(길 끝)에서 길을 따라 CARAVAN_FAR까지 올라가 쉬고 돌아온다.
## 수레 i는 i * 간격만큼 뒤에서 떠나 그만큼 짧게 오른다(줄이 흐트러지지 않고 같이 서고 같이 돌아선다). 돌아올 때는 맨 뒤 수레가 앞이 된다.
## 갈 때는 길 동쪽 줄, 올 때는 서쪽 줄로 걷고 쉬는 동안 천천히 돌아선다.

static var _pts: PackedVector2Array = PackedVector2Array()   ## 길 점(m), 문 쪽에서 북쪽으로
static var _cum: PackedFloat32Array = PackedFloat32Array()   ## 점마다 누적 길이


static func cycle() -> float:
	return FieldLayout.FIELD_DAY + FieldLayout.FIELD_NIGHT


## 수레(또는 호위) 번호 i(소수 가능)의 그 시계에서의 상태. {on: 길 위에 있다, d: 문에서 길을 따라 m, turn: 0 가는 길 ~ 1 오는 길, moving, roll: 바퀴가 구른 길이 m}
static func state(clock: float, i: float) -> Dictionary:
	var c: float = fposmod(clock, cycle())
	var delay: float = i * FieldLayout.CARAVAN_SPACING / FieldLayout.CARAVAN_SPEED
	var far: float = FieldLayout.CARAVAN_FAR - i * FieldLayout.CARAVAN_SPACING
	var out_t: float = far / FieldLayout.CARAVAN_SPEED
	var rest: float = FieldLayout.CARAVAN_REST
	for st in FieldLayout.CARAVAN_STARTS:
		var tau: float = c - st - delay
		if tau < 0.0:
			tau += cycle()
		if tau >= 2.0 * out_t + rest:
			continue
		if tau < out_t:
			var d: float = tau * FieldLayout.CARAVAN_SPEED
			return {"on": tau > 0.0, "d": d, "turn": 0.0, "moving": true, "roll": d}
		if tau < out_t + rest:
			return {"on": true, "d": far, "turn": smoothstep(out_t + rest * 0.35, out_t + rest * 0.9, tau), "moving": false, "roll": far}
		var back: float = (tau - out_t - rest) * FieldLayout.CARAVAN_SPEED
		return {"on": far - back > 0.0, "d": far - back, "turn": 1.0, "moving": true, "roll": far + back}
	return {"on": false, "d": 0.0, "turn": 0.0, "moving": false, "roll": 0.0}


static func _ensure() -> void:
	if not _pts.is_empty():
		return
	_pts = FieldBuilder.road_points()
	_cum.resize(_pts.size())
	var total: float = 0.0
	for k in _pts.size():
		if k > 0:
			total += _pts[k].distance_to(_pts[k - 1])
		_cum[k] = total


## 길을 따라 d m 간 곳의 (자리 m, 가는 쪽 단위 벡터).
static func road_at(d: float) -> Array:
	_ensure()
	var n: int = _pts.size()
	d = clampf(d, 0.0, _cum[n - 1])
	var k: int = 1
	while k < n - 1 and _cum[k] < d:
		k += 1
	var seg: float = maxf(_cum[k] - _cum[k - 1], 0.0001)
	var u: float = (d - _cum[k - 1]) / seg
	return [_pts[k - 1].lerp(_pts[k], u), (_pts[k] - _pts[k - 1]) / seg]


## 길이(m).
static func road_length() -> float:
	_ensure()
	return _cum[_cum.size() - 1]


## 수레 i의 땅 자리: {on, pos(m, x z), yaw(라디안, 앞은 로컬 -Z), moving, roll}. side는 옆으로 더 떨어질 m(호위).
static func place(clock: float, i: float, side: float = 0.0) -> Dictionary:
	var s: Dictionary = state(clock, i)
	if not bool(s.on):
		return s
	var r: Array = road_at(float(s.d))
	var t: Vector2 = r[1]
	var n := Vector2(-t.y, t.x)   # 북쪽으로 갈 때의 오른쪽 = 동쪽
	var lane: float = lerpf(FieldLayout.CARAVAN_LANE, -FieldLayout.CARAVAN_LANE, float(s.turn))
	s["pos"] = (r[0] as Vector2) + n * (lane + side)
	s["yaw"] = atan2(-t.x, -t.y) + PI * float(s.turn)
	return s
