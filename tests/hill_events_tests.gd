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


## 2단계: Rules에 붙인 것(첫 구역만, events_default를 켤 때).
static func run_rules(game: GameData, chk: Callable) -> void:
	Rules.events_default = true
	var r := Rules.new(game, 21)
	Rules.events_default = false
	chk.call(r.hz != null and r.hilts.size() == 12 and r.hilts.all(func(h: Hilt) -> bool: return h.zi >= 0), "첫 구역 낮: 손잡이 12개가 검 지도에서")
	var h: Hilt = r.hilts[0]
	chk.call(r.hz_wake_preview(h).size() >= 1, "뽑기 전에 깨어날 이웃이 보인다")
	# 결투: 뽑으면 주인이 서고, 쓰러뜨려야 검을 받는다
	r.hz.blades[0].event = HillZone.Event.DUEL
	r._hz_begin(0, Sword.new(r.pick_sword(0), game))
	chk.call(r.enemies.size() == 1 and r.hz_left.get(0, 0) == 1, "결투: 주인 하나가 선다")
	var e: Enemy = r.enemies[0]
	var before: int = r.pulls
	r.hurt(e, e.hp + 1.0, Vector2.ZERO, false)
	chk.call(r.hz.blades[0].state == HillZone.State.DONE and not r.hz_left.has(0), "결투: 이기면 끝난 검")
	chk.call(r.pending != null or r.slots.any(func(s): return s != null), "결투: 이기면 검을 받는다")
	# 거래: 받으면 최대 체력이 준다
	var r2 := _with_events(game, 22)
	r2.hz.blades[1].event = HillZone.Event.TRADE
	r2._hz_begin(1, Sword.new(r2.pick_sword(0), game))
	chk.call(not r2.hz_offer.is_empty(), "거래: 조건이 걸린다")
	r2.hz_offer.ask = &"max_hp"
	var mh: float = r2.max_hp()
	r2.hz_answer(true)
	chk.call(is_equal_approx(r2.max_hp(), mh - r2.hz.d.trade_max_hp) and r2.hz.blades[1].state == HillZone.State.DONE, "거래: 받으면 값을 내고 검")
	var r3 := _with_events(game, 23)
	r3.hz.blades[2].event = HillZone.Event.TRADE
	r3._hz_begin(2, Sword.new(r3.pick_sword(0), game))
	r3.hz_answer(false)
	chk.call(r3.enemies.size() == 1, "거래: 거절하면 결투")
	# 추격: 무리를 다 쓰러뜨리면 검
	var r4 := _with_events(game, 24)
	r4.hz.blades[3].event = HillZone.Event.CHASE
	r4._hz_begin(3, Sword.new(r4.pick_sword(0), game))
	var n: int = r4.enemies.size()
	chk.call(n >= 3 and n <= 5, "추격: 무리 3~5")
	for x in r4.enemies.duplicate():
		r4.hurt(x, x.hp + 1.0, Vector2.ZERO, false)
	chk.call(r4.hz.blades[3].state == HillZone.State.DONE, "추격: 다 쓰러뜨리면 검")
	# 정산: 밤이 되면 깨어난 검 주인이 오고, 다 쓰러뜨리면 새벽
	var r5 := _with_events(game, 25)
	r5.hz._wake(4)
	r5.hz._wake(6)
	var awake: int = r5.hz.awake_count()
	r5.start_night()
	chk.call(r5.enemies.size() == awake, "정산: 깨어난 검 주인만 온다(%d)" % r5.enemies.size())
	for x in r5.enemies.duplicate():
		r5.hurt(x, x.hp + 1.0, Vector2.ZERO, false)
	for k in 3:
		r5.step()
	chk.call(r5.phase != Rules.Phase.NIGHT, "정산: 다 쓰러뜨리면 밤이 끝난다")


static func _with_events(game: GameData, s: int) -> Rules:
	Rules.events_default = true
	var r := Rules.new(game, s)
	Rules.events_default = false
	return r
