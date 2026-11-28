extends RefCounted
## 들판 구조물 테스트(2026-11-24, docs/landmarks.md): 상인 행렬이 시계로만 정해지는가, 옛 갱도가 끝에서 끝까지 걸을 수 있는가, 갱도 상자가 한 번만 주는가.

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/landmarks_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_caravan()
	_tunnel()
	_cache()
	_others()


func _caravan() -> void:
	var cyc: float = Caravan.cycle()
	var a: Dictionary = Caravan.place(40.0, 0.0)
	var b: Dictionary = Caravan.place(40.0, 0.0)
	check.call(bool(a.on) and a.pos == b.pos and a.yaw == b.yaw, "구조물: 상인 행렬은 같은 시계면 같은 자리")
	check.call(Caravan.place(40.0 + cyc, 0.0).pos.is_equal_approx(a.pos), "구조물: 상인 행렬은 한 바퀴마다 되풀이")
	check.call(not bool(Caravan.state(0.0, 0.0).on) and not bool(Caravan.state(195.0, 3.0).on), "구조물: 떠나기 전과 돌아온 뒤에는 길에 없다")
	var far: Dictionary = Caravan.state(12.0 + FieldLayout.CARAVAN_FAR / FieldLayout.CARAVAN_SPEED + 5.0, 0.0)
	check.call(bool(far.on) and not bool(far.moving) and is_equal_approx(float(far.d), FieldLayout.CARAVAN_FAR), "구조물: 먼 끝에서 쉰다")
	var s1: Dictionary = Caravan.state(60.0, 1.0)
	var s0: Dictionary = Caravan.state(60.0, 0.0)
	check.call(is_equal_approx(float(s0.d) - float(s1.d), FieldLayout.CARAVAN_SPACING), "구조물: 수레 사이 간격이 일정")
	check.call(bool(Caravan.state(205.0 + 30.0, 0.0).on), "구조물: 하루 두 번째 길 나섬")


func _free(b: Dictionary, c: Vector2) -> bool:
	return Blockers.push_out(c, b.rects, b.circles, b.low_rects, b.low_circles).distance_to(c) < 0.01


func _tunnel() -> void:
	var b: Dictionary = FieldBuilder.blockers()
	var ok: bool = true
	var x: float = 156.0
	while x <= 182.0:
		ok = ok and _free(b, Vector2(x, 75.0))
		x += 0.5
	check.call(ok, "구조물: 옛 갱도는 끝에서 끝까지 걸을 수 있다")
	check.call(not _free(b, Vector2(169.0, 73.5)) and not _free(b, Vector2(169.0, 76.5)), "구조물: 갱도 벽은 막혀 있다")
	check.call(FieldLayout.area_at(Vector2(169, 75)) == &"mine" and FieldLayout.AREA_NAMES[&"mine"] == "옛 갱도", "구조물: 갱도 안은 옛 갱도 곳")
	check.call(FieldBuilder.walk_height(338.0, 150.0) == FieldLayout.MINE_FLOOR_Y, "구조물: 굴 바닥은 평평하다")


func _cache() -> void:
	var m := Meta.new()
	m.shards = 0
	var pay: int = int(FieldLayout.CACHES["cache_15"][1])
	check.call(FieldLayout.CACHES["cache_15"][0].distance_to(Vector2(168.5, 75.0)) < 0.1 and m.field_open("cache_15", pay) == pay and m.shards == pay, "구조물: 갱도 상자는 조각을 준다")
	check.call(m.field_open("cache_15", pay) == 0 and m.shards == pay, "구조물: 갱도 상자는 한 번만 준다")


func _others() -> void:
	var b: Dictionary = FieldBuilder.blockers()
	check.call(_free(b, Vector2(48.4, 85.0)) and not _free(b, Vector2(45.5, 85.0)), "구조물: 수도교 아치 밑으로 길이 지나고 받침은 막힌다")
	var g: Vector2 = FieldLayout.GIANT_AT
	check.call(_free(b, g + Vector2(0.0, 1.7)), "구조물: 거인의 갈비뼈 사이로 걷는다")
	check.call(_free(b, Vector2(19.0, 14.0)) and not _free(b, Vector2(19.0, 8.0)), "구조물: 골짜기는 흔들다리 줄로만 건넌다")
	check.call(FieldBuilder.walk_height(38.0, 28.0) > FieldBuilder.height(38.0, 28.0) + 3.0, "구조물: 흔들다리 위는 다리 높이")
