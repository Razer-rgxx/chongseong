extends RefCounted
## 18단계 들판 보스(무덤 기사) 테스트(docs/outside.md). run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/field_boss_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_data()
	_layout()
	_wake()
	_leash()
	_summon()
	_rage()
	_swing()
	_slain()
	_rewards()
	_replay()
	_save()
	Grid.size = Vector2i(34, 22)


func _field(seed_value: int = 1) -> Rules:
	var r := Rules.new(d, seed_value)
	Grid.size = FieldLayout.SIZE
	r.start_field()
	r.lord.pos = Vector2(55, 103)
	r.lord.prev_pos = r.lord.pos
	return r


## 보스를 세우고 영주를 보스에서 dist칸 떨어진 곳(오른쪽)에 둔다.
func _setup(dist: float, seed_value: int = 1) -> Rules:
	var r := _field(seed_value)
	r.debug_god = true
	r.spawn_field_boss()
	r.lord.pos = FieldLayout.BOSS_AT + Vector2(dist, 0.0)
	r.lord.prev_pos = r.lord.pos
	return r


func _data() -> void:
	var D: EnemyData = d.enemies[FieldLayout.BOSS_ID]
	check.call(D.boss and D.big and D.token_cost == 0 and D.hp > d.enemies[&"giant"].hp and D.display_name == "무덤 기사", "무덤 기사: 표 없이 덤비는 큰 우두머리, 체력은 거인보다 많다")
	check.call(D.model_scale == 2.2 and D.swing_arc == 150.0 and D.swing_time == 0.8 and D.charge_length == 8.0 and D.summon_count == 4 and D.summon_max == 4 and D.summon_below == 0.5 and D.rage_hp == 0.5 and D.rage_mult == 1.2, "무덤 기사: 행동 수치가 설계서대로(2.2배, 휘두르기 150°·0.8초, 돌진 8칸, 망령 4마리, 50% 밑 ×1.2)")
	check.call(FieldLayout.BOSS_WAKE == 8.0 and FieldLayout.BOSS_LEASH == 14.0 and FieldLayout.BOSS_FIRST_SHARDS == 80 and FieldLayout.BOSS_SHARDS == 30, "무덤 기사: 깨어남 8칸, 둘레 14칸, 조각 80 / 30")


func _layout() -> void:
	var at: Vector2 = FieldLayout.BOSS_AT
	check.call(FieldLayout.area_at(at) == &"old_field", "무덤 기사 자리: 옛 싸움터 안")
	var root := Node3D.new()
	var blockers: Dictionary = FieldBuilder.build(root, Environment.new())
	var clear: bool = true
	for a in 16:
		for k in [0.0, 0.5, 1.0]:
			var q: Vector2 = at + Vector2.from_angle(a * TAU / 16.0) * 3.0 * k
			for rc: Rect2 in blockers.rects + blockers.low_rects:
				clear = clear and not rc.grow(0.4).has_point(q)
			for c in blockers.circles + blockers.low_circles:
				clear = clear and q.distance_to(c[0]) >= float(c[1]) + 0.4
	check.call(clear, "무덤 기사 자리: 둘레 3칸은 막힌 곳(rects·circles)을 피한다")
	root.free()
	var near: float = 1e9
	for k in FieldLayout.CACHES:
		near = minf(near, at.distance_to(FieldLayout.CACHES[k][0]))
	for k in FieldLayout.STONES:
		near = minf(near, at.distance_to(FieldLayout.STONES[k][0]))
	var pack_gap: float = 1e9
	for k in FieldLayout.PACKS:
		pack_gap = minf(pack_gap, at.distance_to(FieldLayout.PACKS[k].at))
	check.call(near > FieldLayout.BOSS_WAKE and pack_gap > FieldLayout.BOSS_WAKE + FieldLayout.PACK_AGGRO - 1.0, "무덤 기사 자리: 상자·비석은 깨어남 거리 밖, 무리와 겹쳐 깨지 않는다")
	var near_road: float = 1e9
	for i in FieldLayout.ROAD.size() - 1:
		near_road = minf(near_road, at.distance_to(Geometry2D.get_closest_point_to_segment(at, FieldLayout.ROAD[i], FieldLayout.ROAD[i + 1])))
	check.call(near_road > FieldLayout.BOSS_WAKE, "무덤 기사 자리: 길에서 깨어남 거리보다 멀다")
	var r := _field()
	var b: Enemy = r.spawn_field_boss()
	check.call(b != null and r.field_boss == b and b.pos == at and b.home == at and b.max_hp == d.enemies[FieldLayout.BOSS_ID].hp and r.field_boss_state == Rules.BOSS_SLEEP and r.spawn_field_boss() == null, "spawn_field_boss: 한 마리만 서고 구역 배수를 받지 않는다")
	check.call(r.zone == 0, "spawn_field_boss: 두고 나서 구역은 그대로")


func _wake() -> void:
	var r := _setup(FieldLayout.BOSS_WAKE + 1.0)
	var b: Enemy = r.field_boss
	var woke: Array = [0]
	r.field_boss_woke.connect(func(_e: Enemy) -> void: woke[0] += 1)
	for t in 120:
		r.step()
	check.call(woke[0] == 0 and r.field_boss_state == Rules.BOSS_SLEEP and b.pos == FieldLayout.BOSS_AT and b.act == &"", "깨어남: 영주가 8칸 밖이면 가만히 서 있다")
	r.lord.pos = FieldLayout.BOSS_AT + Vector2(FieldLayout.BOSS_WAKE - 0.5, 0.0)
	r.step()
	check.call(woke[0] == 1 and r.field_boss_state == Rules.BOSS_AWAKE, "깨어남: 8칸 안에 오면 깨어난다(한 번)")
	for t in 90:
		r.step()
	check.call(woke[0] == 1 and b.pos.distance_to(r.lord.pos) < FieldLayout.BOSS_WAKE - 0.5, "깨어남: 깨어나면 영주 쪽으로 다가온다")
	# 멀리서 맞아도 깨어난다
	var r2 := _setup(30.0)
	r2.hurt(r2.field_boss, 1.0, Vector2.ZERO, false)
	check.call(r2.field_boss_state == Rules.BOSS_AWAKE, "깨어남: 먼 데서 맞아도 깨어난다")


func _leash() -> void:
	var r := _setup(5.0)
	var b: Enemy = r.field_boss
	var back: Array = [0]
	r.field_boss_returned.connect(func(_e: Enemy) -> void: back[0] += 1)
	for t in 30:
		r.step()
	check.call(r.field_boss_state == Rules.BOSS_AWAKE, "돌아가기: 먼저 깨어난다")
	b.hp = 100.0
	b.summoned = 3
	b.pos = FieldLayout.BOSS_AT + Vector2(10.0, 0.0)
	r.lord.pos = FieldLayout.BOSS_AT + Vector2(FieldLayout.BOSS_LEASH - 1.0, 0.0)
	r.step()
	check.call(r.field_boss_state == Rules.BOSS_AWAKE, "돌아가기: 14칸 안이면 계속 쫓는다")
	r.lord.pos = FieldLayout.BOSS_AT + Vector2(FieldLayout.BOSS_LEASH + 1.0, 0.0)
	r.step()
	check.call(r.field_boss_state == Rules.BOSS_RETURNING and b.summoned == 0, "돌아가기: 둘레 14칸을 넘으면 돌아간다")
	var hp0: float = b.hp
	for t in 12:
		r.step()
	check.call(b.hp > hp0, "돌아가기: 돌아가는 동안 체력이 찬다")
	for t in 600:
		r.step()
	check.call(b.hp == b.max_hp and b.pos.distance_to(FieldLayout.BOSS_AT) < 0.1 and r.field_boss_state == Rules.BOSS_SLEEP and back[0] == 1, "돌아가기: 제자리에 닿으면 체력이 다 차고 다시 잔다")
	check.call(r.lord.hp == r.max_hp(), "돌아가기: 영주는 맞지 않았다")
	# 돌아가는 중에 다시 8칸 안에 오면 깨어난다
	var r2 := _setup(5.0)
	for t in 10:
		r2.step()
	r2.lord.pos = FieldLayout.BOSS_AT + Vector2(FieldLayout.BOSS_LEASH + 2.0, 0.0)
	r2.step()
	r2.lord.pos = FieldLayout.BOSS_AT + Vector2(3.0, 0.0)
	r2.step()
	check.call(r2.field_boss_state == Rules.BOSS_AWAKE, "돌아가기: 돌아가는 중에 다시 가까이 오면 깨어난다")


func _summon() -> void:
	# 체력이 많으면 안 부른다
	var r := _setup(6.0)
	var spawned: Array = [0]
	r.enemy_spawned.connect(func(e: Enemy) -> void:
		if e.data.id == &"wraith":
			spawned[0] += 1)
	for t in 600:
		r.step()
	check.call(spawned[0] == 0 and r.field_boss.summoned == 0, "부르기: 체력이 50% 위면 안 부른다")
	# 50% 밑이면 한 번만 4마리
	r.field_boss.hp = r.field_boss.max_hp * 0.49
	var winds: Array = [0]
	r.enemy_act.connect(func(_e: Enemy, act: StringName, _i: Dictionary) -> void:
		if act == &"call_wind":
			winds[0] += 1)
	for t in 1500:
		r.step()
	check.call(spawned[0] == 4 and winds[0] == 1 and r.field_boss.summoned == 4, "부르기: 50% 밑에서 망령 4마리를 한 번만 부른다")
	var all_called: bool = true
	for e in r.enemies:
		if e.data.id == &"wraith":
			all_called = all_called and e.caller == r.field_boss.id
	check.call(all_called, "부르기: 불려 온 적은 부른 자를 안다")
	# 돌아가면 거두고, 다시 오면 또 부를 수 있다
	r.lord.pos = FieldLayout.BOSS_AT + Vector2(FieldLayout.BOSS_LEASH + 3.0, 0.0)
	r.step()
	var left: int = 0
	for e in r.enemies:
		left += 1 if e.data.id == &"wraith" and not e.dead else 0
	check.call(left == 0 and r.field_boss.summoned == 0, "부르기: 돌아가면 불러낸 적을 거둔다")
	# 부르는 중 끊기면(기절) 부른 것으로 세지 않는다
	var r2 := _setup(6.0)
	r2.field_boss.hp = r2.field_boss.max_hp * 0.4
	r2.step()
	for t in 200:
		r2.step()
		if r2.field_boss.act == &"call_wind":
			break
	check.call(r2.field_boss.act == &"call_wind" and r2.field_boss.summoned == 0, "부르기: 부르는 동안 예고가 있고 아직 부르지 않았다")
	r2.field_boss.stun = 1.0
	r2.step()
	check.call(r2.field_boss.act != &"call_wind" and r2.field_boss.summoned == 0, "부르기: 기절하면 끊긴다")


## 휘두르기 예고에서 내려칠 때까지 걸린 틱 수.
func _swing_ticks(hp_ratio: float) -> int:
	var r := _setup(2.5)
	var b: Enemy = r.field_boss
	b.hp = b.max_hp * hp_ratio
	b.summoned = b.data.summon_max
	var t0: Array = [-1]
	var t1: Array = [-1]
	var n: Array = [0]
	r.enemy_act.connect(func(_e: Enemy, act: StringName, _i: Dictionary) -> void:
		if act == &"swing_wind" and t0[0] < 0:
			t0[0] = n[0]
		elif act == &"swing" and t1[0] < 0:
			t1[0] = n[0])
	for t in 300:
		n[0] = t
		r.step()
		if t1[0] >= 0:
			break
	return t1[0] - t0[0]


func _rage() -> void:
	var slow: int = _swing_ticks(1.0)
	var fast: int = _swing_ticks(0.4)
	check.call(absi(slow - roundi(0.8 * 30.0)) <= 1, "휘두르기: 0.8초 예고(%d틱)" % slow)
	check.call(fast < slow and absi(fast - roundi(0.8 * 30.0 / 1.2)) <= 1, "빨라짐: 체력 50%% 밑이면 예고가 1.2배 빠르다(%d → %d틱)" % [slow, fast])
	var r := _setup(10.0)
	var b: Enemy = r.field_boss
	check.call(r.foes._rate(b) == 1.0 and not r.foes.raged(b), "빨라짐: 체력이 가득이면 1배")
	b.hp = b.max_hp * 0.5
	check.call(r.foes._rate(b) == 1.2 and r.foes.raged(b), "빨라짐: 체력 50% 밑이면 ×1.2")
	# 걷는 거리: 빨라지면 같은 시간에 더 간다
	var dist: Array[float] = []
	for ratio in [1.0, 0.4]:
		var q := _setup(13.0)
		q.field_boss.hp = q.field_boss.max_hp * ratio
		q.field_boss.summoned = q.field_boss.data.summon_max
		q.field_boss.cooldown = 99.0
		q.lord.pos = FieldLayout.BOSS_AT + Vector2(13.0, 0.0)
		q.field_boss.pos = FieldLayout.BOSS_AT
		q.hurt(q.field_boss, 0.0, Vector2.ZERO, false)   # 깨운다
		for t in 30:
			q.step()
		dist.append(q.field_boss.pos.distance_to(FieldLayout.BOSS_AT))
	check.call(dist[1] > dist[0] * 1.15 and dist[0] > 0.5, "빨라짐: 걷는 빠르기도 1.2배(%.2f → %.2f칸)" % [dist[0], dist[1]])
	# 돌진은 돌격병처럼 머리를 낮춘 뒤 달린다
	var q2 := _setup(6.0, 4)
	var seen: Dictionary = {}
	q2.enemy_act.connect(func(_e: Enemy, act: StringName, i: Dictionary) -> void: seen[act] = i)
	for t in 1200:
		if q2.field_boss.act == &"":
			q2.lord.pos = q2.field_boss.pos + Vector2(6.0 if t < 600 else 2.5, 0.0)   # 멀리 두면 돌진을, 가까이 두면 휘두르기를 고른다
		q2.step()
	check.call(seen.has(&"wind") and seen.has(&"charge") and seen.has(&"swing_wind") and seen.has(&"swing"), "행동: 돌진(머리 낮춤 → 달림)과 휘두르기가 모두 나온다")
	if seen.has(&"charge"):
		var c: Dictionary = seen[&"charge"]
		check.call((c.to as Vector2).distance_to(c.from as Vector2) <= 8.0001, "돌진: 8칸 안에서 멈춘다")


func _swing() -> void:
	# 앞에 있으면 맞고, 예고 중에 뒤로 가면 안 맞는다
	var r := _setup(2.5)
	var b: Enemy = r.field_boss
	b.summoned = b.data.summon_max
	r.debug_god = false
	var hp0: float = r.lord.hp
	var winds: Array = []
	var hits: Array = []
	r.enemy_act.connect(func(_e: Enemy, act: StringName, i: Dictionary) -> void:
		if act == &"swing_wind":
			winds.append(i)
		elif act == &"swing":
			hits.append(i))
	for t in 200:
		r.lord.pos = FieldLayout.BOSS_AT + Vector2(2.5, 0.0)
		r.step()
		if not hits.is_empty():
			break
	check.call(not winds.is_empty() and float(winds[0].arc) == 150.0 and float(winds[0].time) == 0.8, "휘두르기: 앞 150°를 0.8초 알린 뒤 벤다(enemy_act)")
	check.call(not hits.is_empty() and hits[0].hit and r.lord.hp == hp0 - b.damage, "휘두르기: 앞 부채꼴 안이면 맞는다")
	var r2 := _setup(2.5)
	var b2: Enemy = r2.field_boss
	b2.summoned = b2.data.summon_max
	r2.debug_god = false
	var hit2: Array = []
	var started: Array = [false]
	r2.enemy_act.connect(func(_e: Enemy, act: StringName, i: Dictionary) -> void:
		if act == &"swing_wind":
			started[0] = true
		elif act == &"swing":
			hit2.append(i))
	for t in 200:
		if started[0]:
			r2.lord.pos = b2.pos + Vector2(-2.5, 0.0)   # 뒤로 돌아 들어간다
		else:
			r2.lord.pos = FieldLayout.BOSS_AT + Vector2(2.5, 0.0)
		r2.step()
		if not hit2.is_empty():
			break
	check.call(not hit2.is_empty() and not hit2[0].hit and r2.lord.hp == r2.max_hp(), "휘두르기: 뒤로 돌아가면 맞지 않는다")
	# 쉬는 동안 쿨다운이 돈다: 같은 자리에서 곧바로 두 번 베지 않는다
	check.call(b2.cooldown > 0.0 or b2.act == &"swing", "휘두르기: 벤 뒤에는 쉰다")


func _slain() -> void:
	var r := _setup(5.0)
	var b: Enemy = r.field_boss
	var slain: Array = [0]
	var died: Array = [0]
	r.field_boss_slain.connect(func(_e: Enemy) -> void: slain[0] += 1)
	r.enemy_died.connect(func(e: Enemy) -> void:
		if e == b:
			died[0] += 1)
	b.hp = b.max_hp * 0.4
	for t in 400:
		r.step()
		if b.summoned > 0:
			break
	check.call(b.summoned == 4, "쓰러뜨림: (준비) 망령이 불려 나왔다")
	r.hurt(b, 99999.0, Vector2.ZERO, true)
	for t in 5:
		r.step()
	var wraiths: int = 0
	for e in r.enemies:
		wraiths += 1 if e.data.id == &"wraith" and not e.dead else 0
	check.call(slain[0] == 1 and died[0] == 1 and r.field_boss_state == Rules.BOSS_DOWN and wraiths == 0, "쓰러뜨림: 신호는 한 번, 불려 온 망령도 사라진다")
	for t in 60:
		r.step()
	check.call(slain[0] == 1 and r.enemies.is_empty(), "쓰러뜨림: 쓰러뜨린 뒤 다시 서지 않는다")


func _rewards() -> void:
	var m := Meta.new()
	m.shards = 0
	var first: Dictionary = m.boss_defeat()
	check.call(first.shards == 80 and first.first and first.charm and m.shards == 80 and m.boss_first and m.boss_down, "보상: 처음 쓰러뜨리면 조각 80")
	check.call(m.pack.has(&"charm"), "보상: 운 부적이 Meta.pack(상인의 것과 같은 항목)에 든다")
	var again: Dictionary = m.boss_defeat()
	check.call(again.shards == 30 and not again.first and not again.charm and m.shards == 110, "보상: 다음부터는 조각 30, 운 부적은 겹쳐 들지 않는다")
	m.pack.clear()
	var third: Dictionary = m.boss_defeat()
	check.call(third.shards == 30 and third.charm and m.pack == [&"charm"], "보상: 쓰러뜨릴 때마다 운 부적이 하나 든다(비어 있으면 다시)")
	# 다음 판 시작에 운 부적이 적용된다(상인의 것과 같다)
	var r := Rules.new(d, 3, m)
	check.call(r.has_pack(&"charm") and m.pack.is_empty(), "보상: 다음 판은 운 부적을 쥐고 시작한다")
	# 판이 끝나면 boss_down만 비우고, 처음 보상은 기억한다
	var hill := Rules.new(d, 5)
	m.record_run(hill, d.meta)
	check.call(not m.boss_down and m.boss_first, "보상: record_run이 boss_down을 비우고 boss_first는 남긴다")
	# 조각 받은 뒤 상인 좌판의 운 부적을 또 사지는 못한다(같은 물건은 하나)
	var m2 := Meta.new()
	m2.shards = 1000
	m2.boss_defeat()
	m2.stock = [&"charm"]
	check.call(m2.buy(d, &"charm") == "이미 샀다", "보상: 이미 든 운 부적은 상인에게서 또 사지 않는다")


func _replay() -> void:
	var h: Array[int] = []
	for run in 2:
		var r := _setup(6.0, 21)
		r.slots[0] = Sword.new(d.swords[0], d)
		for t in 900:
			r.step(_inputs(t))
		h.append(r.state_hash())
	check.call(h[0] == h[1], "결정성: 같은 시드·같은 입력이면 보스 싸움의 state_hash가 같다")
	var r3 := _setup(6.0, 22)
	r3.slots[0] = Sword.new(d.swords[0], d)
	for t in 900:
		r3.step(_inputs(t))
	check.call(r3.state_hash() != h[0], "결정성: 시드가 다르면 달라진다")
	var r4 := _setup(6.0, 21)
	var before: int = r4.state_hash()
	r4.hurt(r4.field_boss, 1.0, Vector2.ZERO, false)
	check.call(r4.state_hash() != before, "결정성: 보스 상태가 state_hash에 든다")


func _inputs(t: int) -> LordInput:
	var i := LordInput.new()
	i.move = Vector2(-1.0, 0.0) if t % 200 < 100 else Vector2(1.0, 0.0)
	i.attack = t % 7 < 4
	i.dash = t % 90 == 0
	i.aim_valid = true
	i.aim = FieldLayout.BOSS_AT
	return i


func _save() -> void:
	var path: String = "user://test_boss_save.json"
	var m := Meta.new()
	m.boss_defeat()
	m.save(path)
	var m2 := Meta.load_or_new(path)
	check.call(m2.boss_down and m2.boss_first and m2.pack.has(&"charm"), "저장: 쓰러뜨림·처음 보상·운 부적을 저장하고 읽는다")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"shards": 9, "packs_cleared": {"grove": 1}}))
	f.close()
	var m3 := Meta.load_or_new(path)
	check.call(m3.shards == 9 and not m3.boss_down and not m3.boss_first and m3.packs_cleared.has("grove"), "저장: 옛 저장은 보스 칸이 기본값(안 쓰러뜨림)으로 읽힌다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
