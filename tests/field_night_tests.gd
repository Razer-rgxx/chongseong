extends RefCounted
## 29단계 들판 낮밤과 다시 생기는 적 테스트(docs/outside.md): 시계, 밤 세기, 밤 무리, 새벽 되살림, 결정성, 저장. run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/field_night_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_layout()
	_clock()
	_night_strength()
	_night_packs()
	_dawn_respawn()
	_replay()
	_save()
	Grid.size = Vector2i(34, 22)


## clock가 음수면 시계 없음. 영주는 모든 무리에서 먼 곳(들판 남쪽 문 근처)에 둔다.
func _field(clock: float, seed_value: int = 1) -> Rules:
	var r := Rules.new(d, seed_value)
	Grid.size = FieldLayout.SIZE
	r.start_field(clock)
	r.lord.pos = Vector2(55, 105)
	r.lord.prev_pos = r.lord.pos
	r.debug_god = true
	return r


func _run(r: Rules, secs: float) -> void:
	for _t in int(secs * 30.0 + 0.5):
		r.step()


func _layout() -> void:
	var cycle: float = FieldLayout.FIELD_DAY + FieldLayout.FIELD_NIGHT
	check.call(FieldLayout.FIELD_DAY == 240.0 and FieldLayout.FIELD_NIGHT == 150.0 and cycle == 390.0, "들판 낮밤: 낮 240초, 밤 150초")
	check.call(FieldLayout.FIELD_NIGHT_ZONE == 1 and FieldLayout.FIELD_NIGHT_AGGRO == 14.0 and FieldLayout.FIELD_NIGHT_AGGRO > FieldLayout.PACK_AGGRO, "들판 낮밤: 밤 세기 구역 +1, 덤빔 거리 10 → 14칸")
	var P := FieldLayout.NIGHT_PACKS
	var areas := {"night_road": &"road", "night_brook": &"brook", "night_old_field": &"old_field", "night_hamlet": &"hamlet"}
	var ok: bool = P.size() == 4
	for id in areas:
		ok = ok and P.has(id)
		if not P.has(id):
			continue
		var p: Dictionary = P[id]
		var n: int = 0
		for f in p.foes:
			n += int(f[1])
			ok = ok and (f[0] == &"wraith" or f[0] == &"wolf") and d.enemies.has(StringName(f[0]))
		ok = ok and n >= 3 and n <= 5 and FieldLayout.area_at(p.at) == areas[id] and int(p.zone) >= 1 and int(p.zone) + FieldLayout.FIELD_NIGHT_ZONE <= d.run.zone_hp.size()
		ok = ok and not FieldLayout.PACKS.has(id)
	check.call(ok, "밤 무리: 4곳(언덕길, 개울가, 옛 싸움터, 불탄 마을 근처), 망령·늑대 3~5마리")
	# 자리: 막힌 곳과 겹치지 않고 낮 무리·상자·비석에서 떨어져 있다
	var root := Node3D.new()
	var b: Dictionary = FieldBuilder.build(root, Environment.new())
	var clear: bool = true
	var apart: bool = true
	for id in P:
		var p: Dictionary = P[id]
		for a in 16:
			for k in [0.0, 0.5, 1.0]:
				var q: Vector2 = (p.at as Vector2) + Vector2.from_angle(a * TAU / 16.0) * float(p.wander) * k
				for rc: Rect2 in b.rects:
					clear = clear and not rc.grow(0.4).has_point(q)
				for c in b.circles:
					clear = clear and q.distance_to(c[0]) >= float(c[1]) + 0.4
		for k in FieldLayout.PACKS:
			apart = apart and (p.at as Vector2).distance_to(FieldLayout.PACKS[k].at) > float(p.wander) + float(FieldLayout.PACKS[k].wander) + 2.0
		for k in P:
			if k != id:
				apart = apart and (p.at as Vector2).distance_to(P[k].at) > float(p.wander) + float(P[k].wander) + 2.0
		for k in FieldLayout.CACHES:
			apart = apart and (p.at as Vector2).distance_to(FieldLayout.CACHES[k][0]) > float(p.wander) + 1.0
		for k in FieldLayout.STONES:
			apart = apart and (p.at as Vector2).distance_to(FieldLayout.STONES[k][0]) > float(p.wander) + 1.0
		apart = apart and (p.at as Vector2).distance_to(FieldLayout.BOSS_AT) > float(p.wander) + FieldLayout.BOSS_LEASH
	check.call(clear, "밤 무리: 서성이는 곳은 막힌 곳(rects·circles)을 피한다")
	check.call(apart, "밤 무리: 낮 무리·다른 밤 무리·상자·비석·보스 둘레와 떨어져 있다")
	root.free()
	# 화면용 밤의 정도: 아침 0, 낮 한가운데 0, 해 질 때 반, 밤 1, 새벽 끝 0
	var d0: float = FieldLayout.night_amount(0.0)
	var d1: float = FieldLayout.night_amount(100.0)
	var dusk: float = FieldLayout.night_amount(FieldLayout.FIELD_DAY)
	var deep: float = FieldLayout.night_amount(FieldLayout.FIELD_DAY + 80.0)
	var pre: float = FieldLayout.night_amount(cycle - FieldLayout.FIELD_TWILIGHT / 2.0)
	check.call(d0 == 0.0 and d1 == 0.0 and absf(dusk - 0.5) < 0.01 and deep == 1.0 and pre > 0.2 and pre < 0.8 and FieldLayout.night_amount(cycle) == 0.0, "들판 낮밤: 화면용 밤의 정도(아침 0, 해 질 때 0.5, 밤 1, 새벽에 풀려 한 바퀴 끝에 0)")
	var mono: bool = true
	var prev: float = 0.0
	for t in range(int(FieldLayout.FIELD_DAY - 30.0), int(FieldLayout.FIELD_DAY + 40.0)):
		var v: float = FieldLayout.night_amount(float(t))
		mono = mono and v >= prev - 0.0001
		prev = v
	check.call(mono, "들판 낮밤: 해질녘은 천천히 어두워지기만 한다")


func _clock() -> void:
	var r := _field(0.0)
	var dusk: Array = [0]
	var dawn: Array = [0]
	r.field_dusk.connect(func() -> void: dusk[0] += 1)
	r.field_dawn.connect(func() -> void: dawn[0] += 1)
	check.call(r.field_clock_on and r.field_clock == 0.0 and not r.field_night, "시계: 켜면 아침(0초) 낮에서 시작한다")
	_run(r, 10.0)
	check.call(absf(r.field_clock - 10.0) < 0.05, "시계: 30Hz로 센다(10초 = 300틱)")
	_run(r, FieldLayout.FIELD_DAY - 10.0 - 1.0)
	check.call(not r.field_night and dusk[0] == 0, "시계: 낮 240초 동안은 낮이다")
	_run(r, 1.2)
	check.call(r.field_night and dusk[0] == 1 and dawn[0] == 0, "시계: 240초에 해가 지고 field_dusk 신호가 한 번 난다")
	_run(r, FieldLayout.FIELD_NIGHT - 2.0)
	check.call(r.field_night and dawn[0] == 0, "시계: 밤 150초 동안은 밤이다")
	_run(r, 2.2)
	check.call(not r.field_night and dawn[0] == 1 and r.field_clock < 5.0, "시계: 한 바퀴 뒤 날이 밝고 field_dawn 신호, 시계는 0 근처로 돌아간다")
	# 시계 없는 들판(지하 무덤)은 흐르지 않는다
	var c := _field(-1.0)
	_run(c, 300.0)
	check.call(not c.field_clock_on and c.field_clock == 0.0 and not c.field_night, "시계: 시계 없이 연 들판 모드(지하 무덤)는 흐르지 않는다")
	# 밤에 들어오면 밤 무리가 서 있다
	var n := _field(FieldLayout.FIELD_DAY + 30.0)
	check.call(n.field_night and n.packs.size() == 4 and n.pack_alive(&"night_road") == 4, "시계: 밤 중간에 들어오면 밤 무리가 서 있다")
	# 언덕 판의 낮밤은 시계와 따로다
	var hill := Rules.new(d, 3)
	check.call(not hill.field_clock_on and hill.phase == Rules.Phase.DAY, "시계: 언덕 판의 낮밤과는 따로다")


func _near_pack(r: Rules, id: String) -> void:
	r.lord.pos = (FieldLayout.PACKS[id].at as Vector2) + Vector2(FieldLayout.PACK_AGGRO + 2.0, 0.0)
	r.lord.prev_pos = r.lord.pos


func _night_strength() -> void:
	var id: String = "old_field"
	var home: Vector2 = FieldLayout.PACKS[id].at
	var base_zone: int = int(FieldLayout.PACKS[id].zone) - 1
	# 낮: 10칸 안에서 덤비고, 구역은 무리 그대로
	var day := _field(0.0)
	day.spawn_packs()
	day.lord.pos = home + Vector2(12.0, 0.0)
	day.lord.prev_pos = day.lord.pos
	_run(day, 1.0)
	check.call(int(day.packs[StringName(id)].state) == Rules.PACK_IDLE, "낮: 12칸 밖이면 덤비지 않는다")
	day.lord.pos = home + Vector2(9.5, 0.0)
	day.lord.prev_pos = day.lord.pos
	_run(day, 0.5)
	check.call(int(day.packs[StringName(id)].state) == Rules.PACK_ENGAGED and day.zone == base_zone, "낮: 10칸 안이면 덤비고 세기 구역은 그대로")
	# 밤: 14칸 안에서 덤비고, 구역 +1
	var night := _field(FieldLayout.FIELD_DAY + 5.0)
	night.spawn_packs()
	night.lord.pos = home + Vector2(15.0, 0.0)
	night.lord.prev_pos = night.lord.pos
	_run(night, 1.0)
	check.call(int(night.packs[StringName(id)].state) == Rules.PACK_IDLE, "밤: 15칸 밖이면 덤비지 않는다")
	night.lord.pos = home + Vector2(13.0, 0.0)
	night.lord.prev_pos = night.lord.pos
	_run(night, 0.5)
	check.call(int(night.packs[StringName(id)].state) == Rules.PACK_ENGAGED, "밤: 덤빔 거리가 14칸으로 는다(13칸에서 덤빈다)")
	check.call(night.zone == base_zone + FieldLayout.FIELD_NIGHT_ZONE and night.tokens.total() >= day.tokens.total(), "밤: 덤빌 때 세기 구역 +1(공격 표 수가 구역을 따른다)")
	# 구역 표 길이를 넘지 않는다
	var top := _field(FieldLayout.FIELD_DAY + 5.0)
	var last: int = d.run.zone_hp.size()
	top.spawn_pack(&"edge", {"at": Vector2(55, 80), "wander": 2.0, "zone": last, "foes": [[&"wraith", 3]]})
	top.lord.pos = Vector2(55, 78)
	top.lord.prev_pos = top.lord.pos
	_run(top, 0.5)
	check.call(top.zone == last - 1 and top.zone < d.run.zone_hp.size(), "밤: 세기 구역은 구역 표 길이(10)를 넘지 않게 자른다")
	# 낮에 덤빈 무리는 낮 구역 그대로, 밤이 되어도 이미 덤빈 구역은 그대로 둔다
	# 보스는 밤에도 그대로: 깨어남 8칸, 구역은 보스 구역
	var bn := _field(FieldLayout.FIELD_DAY + 5.0)
	bn.spawn_field_boss()
	bn.lord.pos = FieldLayout.BOSS_AT + Vector2(FieldLayout.BOSS_WAKE + 3.0, 0.0)
	bn.lord.prev_pos = bn.lord.pos
	_run(bn, 1.0)
	check.call(bn.field_boss_state == Rules.BOSS_SLEEP, "밤: 들판 보스는 밤에도 8칸 안에서만 깨어난다")
	bn.lord.pos = FieldLayout.BOSS_AT + Vector2(FieldLayout.BOSS_WAKE - 1.0, 0.0)
	bn.lord.prev_pos = bn.lord.pos
	_run(bn, 0.3)
	check.call(bn.field_boss_state == Rules.BOSS_AWAKE and bn.zone == FieldLayout.BOSS_ZONE - 1, "밤: 보스 구역은 밤에도 그대로")


func _night_packs() -> void:
	var r := _field(0.0)
	var dusk: Array = [0]
	r.field_dusk.connect(func() -> void: dusk[0] += 1)
	check.call(r.packs.is_empty() and r.enemies.is_empty(), "밤 무리: 낮에는 서 있지 않다")
	_run(r, FieldLayout.FIELD_DAY + 0.5)
	check.call(dusk[0] == 1 and r.packs.size() == 4 and r.enemies.size() == 18, "밤 무리: 해가 지면 네 곳이 서고 적은 4 + 4 + 5 + 5마리")
	var ok_hp: bool = true
	for e in r.enemies:
		var pk: Dictionary = FieldLayout.NIGHT_PACKS[String(e.pack)]
		var zi: int = int(pk.zone) - 1 + FieldLayout.FIELD_NIGHT_ZONE
		ok_hp = ok_hp and absf(e.max_hp - e.data.hp * d.run.zone_hp[zi]) < 0.01 and bool(r.packs[e.pack].night)
	check.call(ok_hp, "밤 무리: 체력은 무리 구역 + 1의 구역 배수")
	# 날이 밝으면 덤비지 않은 무리는 사라진다(보상·쓰러뜨림 없음)
	var killed: Array = [0]
	var cleared: Array = [0]
	r.enemy_died.connect(func(_e: Enemy) -> void: killed[0] += 1)
	r.pack_cleared.connect(func(_id: StringName) -> void: cleared[0] += 1)
	var kills0: int = r.kills
	_run(r, FieldLayout.FIELD_NIGHT)
	var alive: int = 0
	for e in r.enemies:
		alive += 1 if (not e.dead and FieldLayout.NIGHT_PACKS.has(String(e.pack))) else 0
	var left: bool = false
	for id in r.packs:
		left = left or FieldLayout.NIGHT_PACKS.has(String(id))
	check.call(not r.field_night and alive == 0 and not left, "밤 무리: 날이 밝으면 덤비지 않은 무리는 사라진다")
	check.call(killed[0] == 0 and cleared[0] == 0 and r.kills == kills0, "밤 무리: 사라진 것은 쓰러뜨림으로 치지 않는다(보상 신호 없음)")
	# 덤비는 중인 밤 무리는 날이 밝아도 남고, 덤비기를 그치면 사라진다
	var e2 := _field(FieldLayout.FIELD_DAY + FieldLayout.FIELD_NIGHT - 3.0)
	var home: Vector2 = FieldLayout.NIGHT_PACKS["night_road"].at
	e2.lord.pos = home + Vector2(8.0, 0.0)
	e2.lord.prev_pos = e2.lord.pos
	_run(e2, 0.5)
	check.call(int(e2.packs[&"night_road"].state) == Rules.PACK_ENGAGED, "밤 무리: 밤에는 14칸 안이면 덤빈다")
	_run(e2, 4.0)
	check.call(not e2.field_night and e2.packs.has(&"night_road") and e2.pack_alive(&"night_road") > 0 and not e2.packs.has(&"night_brook"), "밤 무리: 덤비는 중인 무리는 날이 밝아도 남고 나머지는 사라진다")
	e2.lord.pos = home + Vector2(FieldLayout.PACK_LEASH + 5.0, 0.0)
	e2.lord.prev_pos = e2.lord.pos
	_run(e2, 3.0)
	check.call(not e2.packs.has(&"night_road") and e2.pack_alive(&"night_road") == 0, "밤 무리: 덤비기를 그치면(놓아주면) 낮에는 사라진다")
	# 쓰러뜨리면 낮 무리와 같은 신호(무리 전멸)가 나고 다음 밤에는 다시 선다
	var k := _field(FieldLayout.FIELD_DAY + 1.0)
	var done: Array = []
	k.pack_cleared.connect(func(id: StringName) -> void: done.append(id))
	var died: Array = [0]
	k.enemy_died.connect(func(e: Enemy) -> void: died[0] += 1 if e.pack != &"" else 0)
	for e in k.enemies:
		if e.pack == &"night_hamlet":
			k.hurt(e, 1e9, Vector2.ZERO, false)
	_run(k, 0.2)
	check.call(done == [&"night_hamlet"] and died[0] == 5, "밤 무리: 쓰러뜨리면 낮 무리처럼 pack_cleared와 적마다 enemy_died가 난다(보상은 장면이 Meta로)")
	_run(k, FieldLayout.FIELD_NIGHT)
	check.call(not k.packs.has(&"night_hamlet"), "밤 무리: 쓰러뜨린 밤 무리의 기록도 날이 밝으면 지워진다")
	_run(k, FieldLayout.FIELD_DAY)
	check.call(k.field_night and k.packs.has(&"night_hamlet") and k.pack_alive(&"night_hamlet") == 5, "밤 무리: 다음 밤에는 다시 선다")
	# 보상: 낮 무리와 같은 Meta 함수
	var m := Meta.new()
	m.rng.seed = 5
	var kill: int = m.field_kill()
	var clr: int = m.field_clear("night_hamlet")
	check.call(kill == FieldLayout.PACK_KILL_SHARDS and clr >= FieldLayout.PACK_CLEAR_MIN and clr <= FieldLayout.PACK_CLEAR_MAX, "밤 무리: 보상은 낮 무리와 같다(적 하나 1, 무리 5~10)")


func _dawn_respawn() -> void:
	# 낮 무리를 쓰러뜨렸다 → 날이 밝으면 다시 선다
	var r := _field(0.0)
	r.spawn_packs()
	var total: int = FieldLayout.PACKS.size()
	check.call(r.packs.size() == total, "새벽 되살림: 낮에는 낮 무리 17곳이 선다")
	for e in r.enemies:
		if e.pack == &"road_south":
			r.hurt(e, 1e9, Vector2.ZERO, false)
	_run(r, 0.2)
	check.call(r.packs[&"road_south"].cleared and r.pack_alive(&"road_south") == 0, "새벽 되살림: 무리를 쓰러뜨렸다")
	_run(r, FieldLayout.FIELD_DAY + 0.5)
	check.call(r.packs[&"road_south"].cleared, "새벽 되살림: 낮이 가는 동안은 다시 서지 않는다")
	var dawn: Array = [0]
	r.field_dawn.connect(func() -> void: dawn[0] += 1)
	_run(r, FieldLayout.FIELD_NIGHT)
	check.call(dawn[0] == 1 and not r.packs[&"road_south"].cleared and r.pack_alive(&"road_south") == 3, "새벽 되살림: 날이 밝으면 쓰러뜨린 무리가 다시 선다(field_dawn)")
	check.call(r.packs.size() == total, "새벽 되살림: 안 쓰러뜨린 무리는 그대로, 합쳐 17곳(밤 무리는 거두어졌다)")
	# 처음부터 안 섰던 무리(Meta.packs_cleared로 건너뜀)도 날이 밝으면 선다
	var s := _field(FieldLayout.FIELD_DAY + FieldLayout.FIELD_NIGHT - 2.0)
	s.spawn_packs({"foot": 1, "tower": 1})
	check.call(not s.packs.has(&"foot") and not s.packs.has(&"tower"), "새벽 되살림: 이미 쓰러뜨려 건너뛴 무리는 아직 없다")
	_run(s, 2.5)
	check.call(s.packs.has(&"foot") and s.packs.has(&"tower") and s.pack_alive(&"foot") == 4, "새벽 되살림: 건너뛴 무리도 날이 밝으면 다시 선다")
	# Meta: 날이 밝을 때 packs_cleared를 비우면 다시 보상을 받는다(장면이 field_dawn에서 한다), 상자·조각·보스·무덤은 그대로
	var m := Meta.new()
	m.rng.seed = 2
	m.field_clear("foot")
	m.field_open("cache_1", 20)
	m.boss_down = true
	m.crypt_cleared["r1"] = 1
	var g0: Array[int] = m.glints.duplicate()
	m.packs_cleared = {}
	check.call(m.field_clear("foot") > 0 and m.field_found.has("cache_1") and m.boss_down and m.crypt_cleared.has("r1") and m.glints == g0, "새벽 되살림: packs_cleared만 비우고 상자·조각·보스·무덤은 판이 끝날 때까지 그대로")
	var hill := Rules.new(d, 5)
	var m2 := Meta.new()
	m2.field_clock = 123.0
	m2.record_run(hill, d.meta)
	check.call(m2.packs_cleared.is_empty() and m2.field_clock == 123.0, "새벽 되살림: record_run도 지금처럼 무리를 비우고 시계는 건드리지 않는다")


func _replay() -> void:
	var h: Array[int] = []
	for _k in 2:
		var r := _field(FieldLayout.FIELD_DAY - 3.0, 7)
		r.spawn_packs()
		r.slots[0] = Sword.new(d.swords[0], d)
		r.lord.pos = FieldLayout.NIGHT_PACKS["night_old_field"].at + Vector2(12.0, 0.0)
		r.lord.prev_pos = r.lord.pos
		for t in 900:
			var i := LordInput.new()
			i.move = Vector2(-1.0, 0.0) if t < 300 else Vector2(0.0, 1.0)
			i.attack = t % 40 < 5
			r.step(i)
		h.append(r.state_hash())
	check.call(h[0] == h[1], "결정성: 같은 시드·같은 입력이면 시계·밤 무리가 있어도 state_hash가 같다")
	var a := _field(0.0, 4)
	var b := _field(100.0, 4)
	_run(a, 1.0)
	_run(b, 1.0)
	check.call(a.state_hash() != b.state_hash(), "결정성: 시계가 state_hash에 든다")


func _save() -> void:
	var path: String = "user://test_night_old.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"shards": 9, "packs_cleared": {"foot": 1}}))
	f.close()
	var m := Meta.load_or_new(path)
	check.call(m.field_clock == 0.0 and m.shards == 9 and m.packs_cleared.has("foot"), "옛 저장: field_clock이 없으면 0(아침)으로 읽는다")
	m.field_clock = 250.5
	m.save(path)
	var m2 := Meta.load_or_new(path)
	check.call(absf(m2.field_clock - 250.5) < 0.001, "저장: 들판 시계를 저장하고 다시 읽는다")
	# 떠났다 들어오면 시계가 이어진다
	var r := _field(m2.field_clock)
	_run(r, 5.0)
	var at: float = r.field_clock
	var out := Meta.new()
	out.field_clock = r.field_clock   # 들판을 떠날 때 장면이 하는 일
	var r2 := _field(out.field_clock)
	check.call(r.field_night and absf(at - 255.5) < 0.1 and absf(r2.field_clock - at) < 0.001 and r2.field_night, "저장: 떠났다 들어오면 시계가 이어진다(밤이면 밤 무리도 선다)")
	var _w := Meta.new()
	_w.field_clock = 9999.0
	_w.save(path)
	var big := Meta.load_or_new(path)
	check.call(big.field_clock <= FieldLayout.FIELD_DAY + FieldLayout.FIELD_NIGHT, "저장: 이상하게 큰 시계는 한 바퀴 안으로 자른다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
