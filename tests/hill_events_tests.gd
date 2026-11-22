extends RefCounted
## 언덕 재설계 1단계(HillZone, docs/hill_events.md) 테스트. run_all.gd가 부른다.

var check: Callable


static func run(_game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/hill_events_tests.gd") as GDScript).new()
	t.set("check", chk)
	t.call("_all")


func _z(s: int = 7) -> HillZone:
	return HillZone.new(load("res://data/hill_zone.tres") as HillZoneData, s)


func _all() -> void:
	var a := _z()
	var b := _z()
	check.call(a.blades.size() == 12, "구역에 검 12자루")
	var same: bool = true
	for i in a.blades.size():
		same = same and a.blades[i].at == b.blades[i].at and a.blades[i].grade == b.blades[i].grade and a.blades[i].event == b.blades[i].event
	check.call(same, "같은 시드면 같은 지도")
	var gap: bool = true
	var linked: bool = true
	for i in a.blades.size():
		linked = linked and not a.blades[i].links.is_empty()
		for j in a.blades.size():
			if i != j:
				gap = gap and a.blades[i].at.distance_to(a.blades[j].at) >= a.d.min_gap - 0.001
		for j in a.blades[i].links:
			linked = linked and a.blades[j].links.has(i)
	check.call(gap, "검끼리 최소 간격")
	check.call(linked, "모든 검이 이어져 있고 줄은 양쪽")
	# 뽑으면 이웃만 깨어난다
	var z := _z(3)
	var cand := z.wake_candidates(0)
	check.call(z.pull(0), "뽑기")
	check.call(z.started == [0], "뽑으면 그 검의 사건이 시작")
	var woke_ok: bool = z.awake_count() >= 1 and z.awake_count() <= 2
	for i in z.blades.size():
		if z.blades[i].state == HillZone.State.AWAKE:
			woke_ok = woke_ok and cand.has(i) and z.blades[i].woke == 1
	check.call(woke_ok, "뽑으면 이어진 검 1~2자루만 깨어나 등급 +1")
	check.call(not z.pull(0), "뽑은 검은 다시 못 뽑는다")
	# 최대 +2
	var m := _z(5)
	for k in 5:
		m._wake(1)
	check.call(m.blades[1].woke == m.d.wake_max, "깨어남 등급은 최대 +2")
	# 60초 뒤 주인이 스스로 온다(멀리 있으면)
	var t := _z(9)
	t._wake(2)
	t.started.clear()
	var far := t.blades[2].at + Vector2(1000, 0)
	for k in int(t.d.owner_timeout * 30.0) - 3:
		t.step(1.0 / 30.0, far)
	check.call(t.started.is_empty(), "시간 전에는 안 온다")
	for k in 6:
		t.step(1.0 / 30.0, far)
	check.call(t.started == [2], "60초 뒤 주인이 스스로 온다")
	# 다가와 닿으면 시작
	var n := _z(11)
	n._wake(4)
	n.started.clear()
	var near := n.blades[4].at + Vector2(4, 0)
	for k in 60:
		n.step(1.0 / 30.0, near)
	check.call(n.started == [4], "주인이 다가와 닿으면 사건 시작")
	# 정산: 깨어나고 안 뽑힌 수 = 몰려오는 수
	var r := _z(13)
	r._wake(1)
	r._wake(5)
	r._wake(7)
	r.pull(7)
	var awake: int = r.awake_count()
	var come := r.begin_reckoning()
	check.call(come.size() == awake and r.awake_count() == 0, "정산 때 남은 깨어난 검 주인이 모두 온다")
	check.call(not r.pull(0), "정산 중에는 못 뽑는다")
	# 끝
	r.finish(1, false)
	check.call(r.blades[1].state == HillZone.State.SLEEP and r.blades[1].woke == 0, "지면 검은 잠들고 깨어남이 사라진다")
	r.finish(5, true)
	check.call(r.blades[5].state == HillZone.State.DONE, "이기면 끝난 검")
	check.call(is_equal_approx(_z(1).duel_hp_mult(0), pow(1.5, float(_z(1).blades[0].grade))), "결투 체력 배수 = 1.5^등급")
