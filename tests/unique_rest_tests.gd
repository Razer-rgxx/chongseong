extends RefCounted
## 7단계 남은 고유 능력 8종 테스트(scripts/core/uniques.gd). run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/unique_rest_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_table()
	_allies()
	_walls()
	_blade()
	_fate()
	_deterministic()
	_duel_off()


func _night(name: String, seed_value: int = 1) -> Rules:
	var r := Rules.new(d, seed_value)
	var s := r.give(d.sword_by_name(name), 0)
	s.ins.clear()
	var p := PatternData.new()
	p.moves = PackedStringArray(["sweep", "sweep"])
	s.pattern = p
	r.start_night()
	r.lord.face = 0.0
	r.enemies.clear()
	r.debug_god = true
	r.lord.hp = r.max_hp()
	return r


func _foe(r: Rules, at: Vector2, still: bool = true) -> Enemy:
	var e := r.spawn_at(&"wraith", r.lord.pos + at)
	e.max_hp = 99999.0
	e.hp = e.max_hp
	if still:
		e.stun = 99.0
	return e


func _kill(r: Rules, e: Enemy) -> void:
	r.hurt(e, e.hp + 1.0, Vector2.ZERO, false)


func _count(r: Rules, kind: StringName) -> int:
	var n: int = 0
	for a in r.powers.U.allies:
		if a.kind == kind:
			n += 1
	return n


func _run(r: Rules, ticks: int, input: LordInput = null) -> void:
	for i in ticks:
		r.step(input)


func _table() -> void:
	var names: Array[String] = ["망자들의 왕관", "무덤 파수", "천 명의 기사", "그림자 왕", "쇠말뚝", "언덕을 쌓은 검", "되돌아오는 칼", "운명 베기"]
	var ok: bool = true
	for n in names:
		var sw: SwordData = d.sword_by_name(n)
		ok = ok and sw != null and sw.unique_ready and Powers.READY.has(n) and d.powers.uniques.has(n)
	check.call(ok, "남은 8종: unique_ready가 켜졌고 규칙(READY)과 수치 표에 있다")


func _allies() -> void:
	# 망자들의 왕관: 쓰러뜨린 적이 모두 일어난다(최대 8)
	var r := _night("망자들의 왕관")
	for i in 10:
		_kill(r, _foe(r, Vector2(3.0 + 0.1 * i, 0.0)))
	check.call(_count(r, &"wraith") == 8, "망자들의 왕관: 쓰러뜨린 적이 망령으로 일어난다, 최대 8 (%d)" % _count(r, &"wraith"))
	_run(r, int(11.0 / r.dt))
	check.call(_count(r, &"wraith") == 0, "망령은 10초 뒤 사라진다")
	# 아군은 적 목록에 들지 않는다
	r = _night("망자들의 왕관")
	_kill(r, _foe(r, Vector2(3, 0)))
	check.call(r.enemies.filter(func(e: Enemy) -> bool: return not e.dead).is_empty() and _count(r, &"wraith") == 1, "아군은 Rules.enemies에 들지 않는다")
	# 아군이 가까운 적을 때린다
	var far := _foe(r, Vector2(5, 0))
	var h0: float = far.hp
	_run(r, 90)
	check.call(far.hp < h0, "아군 망령이 가까운 적에게 가서 때린다")
	# 다른 검이면 안 일어난다
	r = _night("녹슨 장검")
	_kill(r, _foe(r, Vector2(3, 0)))
	check.call(r.powers.U.allies.is_empty(), "다른 검이면 아군이 없다")
	# 무덤 파수: 30%(rng)
	r = _night("무덤 파수")
	var made: int = 0
	for i in 100:
		_kill(r, _foe(r, Vector2(3, 0)))
		made += r.powers.U.allies.size()
		r.powers.U.allies.clear()
	check.call(made >= 15 and made <= 45, "무덤 파수: 쓰러뜨린 적의 약 30%%가 일어난다 (100 중 %d)" % made)
	# 천 명의 기사: 기사 3명이 따라다니고 베기를 따라 벤다
	r = _night("천 명의 기사")
	_run(r, 2)
	check.call(_count(r, &"knight") == 3, "천 명의 기사: 기사 3명이 일어선다")
	var foe := _foe(r, Vector2(1.2, 0.0))
	var base: float = foe.hp
	var kn: Array = r.powers.U.allies.filter(func(a: Dictionary) -> bool: return a.kind == &"knight")
	for a in kn:
		a.pos = r.lord.pos + Vector2(0.8, 0.0)
	var in_: LordInput = LordInput.new()
	in_.attack = true
	_run(r, 6, in_)
	var lost: float = base - foe.hp
	check.call(lost > 0.0, "천 명의 기사: 베면 피해가 들어간다 (%.1f)" % lost)
	r = _night("천 명의 기사")
	_run(r, 2)
	var with_k: float = _swing_dmg(r)
	var alone := _night("녹슨 장검")
	var without: float = _swing_dmg(alone)
	check.call(with_k > without, "천 명의 기사: 기사가 따라 벤 만큼 더 들어간다 (%.1f > %.1f)" % [with_k, without])
	# 그림자 왕: 돌진한 자리에 그림자(최대 3, 5초)
	r = _night("그림자 왕")
	for i in 4:
		r.powers.on_dash()
	check.call(_count(r, &"shadow") == 3, "그림자 왕: 돌진마다 그림자가 남고 최대 3")
	_run(r, int(5.5 / r.dt))
	check.call(_count(r, &"shadow") == 0, "그림자는 5초 뒤 사라진다")


## 앞 1.2칸의 적(체력 많음)이 한 틱 사이 휘두르기로 입은 피해.
func _swing_dmg(r: Rules) -> float:
	var foe := _foe(r, Vector2(1.2, 0.0))
	for a in r.powers.U.allies:
		a.pos = r.lord.pos + Vector2(0.8, 0.0)
	var base: float = foe.hp
	var in_ := LordInput.new()
	in_.attack = true
	r.step(in_)
	for i in 3:
		r.step(null)
	return base - foe.hp


func _walls() -> void:
	var r := _night("쇠말뚝")
	r.powers.U.on_swing(10.0, {}, false)
	check.call(r.powers.U.walls.is_empty(), "쇠말뚝: 작은 베기에는 서지 않는다")
	r.powers.U.on_swing(10.0, {}, true)
	check.call(r.powers.U.walls.size() == 1, "쇠말뚝: 큰 베기에 영주 앞에 선다")
	var w: Dictionary = r.powers.U.walls[0]
	var e := _foe(r, w.a - Vector2(0.1, 0.0), false)
	e.stun = 0.0
	r.step(null)
	check.call(e.pos.distance_to(w.a) >= w.radius + e.radius - 0.001, "벽 안의 적은 밖으로 밀려난다")
	# 다가오는 적이 벽에서 멈춘다
	r = _night("쇠말뚝")
	r.powers.U.on_swing(10.0, {}, true)
	var x: float = r.powers.U.walls[0].a.x
	var c := r.spawn_at(&"wraith", r.lord.pos + Vector2(x - r.lord.pos.x + 2.0, 0.0))
	c.max_hp = 99999.0
	c.hp = c.max_hp
	_run(r, 90)
	check.call(c.pos.x >= x - 0.001, "쇠말뚝: 다가오는 적이 벽을 넘지 못한다 (벽 %.2f, 적 %.2f)" % [x, c.pos.x])
	_run(r, int(4.5 / r.dt))
	check.call(r.powers.U.walls.is_empty(), "쇠말뚝은 4초 뒤 사라진다")
	for i in 6:
		r.powers.U.on_swing(1.0, {}, true)
		r.lord.face += 0.5
	check.call(r.powers.U.walls.size() == 4, "쇠말뚝: 최대 4개")
	# 언덕을 쌓은 검: 가로지르는 선, 5초, 최대 3
	r = _night("언덕을 쌓은 검")
	for i in 5:
		r.powers.U.on_swing(1.0, {}, true)
	var wl: Dictionary = r.powers.U.walls[0]
	check.call(r.powers.U.walls.size() == 3 and wl.a.distance_to(wl.b) > 2.0, "언덕을 쌓은 검: 폭이 넓은 벽, 최대 3")
	var mid: Vector2 = (wl.a + wl.b) / 2.0
	var e2 := _foe(r, mid + Vector2(0, 0.9), false)
	e2.stun = 0.0
	r.step(null)
	check.call(Uniques._seg_dist(e2.pos, wl.a, wl.b) >= wl.radius + e2.radius - 0.001, "언덕을 쌓은 검: 선 안의 적도 밀려난다")
	# 실제 좌클릭으로(큰 베기는 두 번째 휘두르기)
	r = _night("쇠말뚝")
	var in_ := LordInput.new()
	in_.attack = true
	for i in 120:
		r.step(in_)
		if not r.powers.U.walls.is_empty():
			break
	check.call(not r.powers.U.walls.is_empty(), "쇠말뚝: 실제 좌클릭의 마무리(큰 베기)에 선다")


func _blade() -> void:
	var r := _night("되돌아오는 칼")
	var near := _foe(r, Vector2(3.0, 0.0))
	var far := _foe(r, Vector2(8.5, 0.0))
	var h_near: float = near.hp
	r.lord.dash_dir = Vector2.RIGHT
	r.powers.on_dash()
	check.call(r.powers.U.blades.size() == 1, "되돌아오는 칼: 돌진하면 칼이 나간다")
	var hits: Dictionary = {}
	r.enemy_hit.connect(func(e: Enemy, _dm: float, _b: bool) -> void: hits[e.id] = int(hits.get(e.id, 0)) + 1)
	_run(r, int(3.0 / r.dt))
	check.call(near.hp < h_near and far.hp == far.max_hp, "길 위의 적을 벤다(가는 거리 밖은 안 벤다)")
	check.call(int(hits.get(near.id, 0)) == 2 and int(hits.get(far.id, 0)) == 0, "갈 때 한 번, 올 때 한 번(가까운 적 %d번, 먼 적 %d번)" % [int(hits.get(near.id, 0)), int(hits.get(far.id, 0))])
	check.call(r.powers.U.blades.is_empty(), "칼은 영주에게 돌아와 사라진다")


func _fate() -> void:
	var r := Rules.new(d, 5)
	var f := r.give(d.sword_by_name("운명 베기"), 0)
	f.durability = 100.0
	f.max_durability = maxf(f.max_durability, 100.0)
	var s := Sword.new(d.sword_by_name("녹슨 장검"), d)
	r.powers.on_pulled(s)
	r._receive(s)
	check.call(r.slots[1] == s, "뽑은 검이 빈 칸에 들어갔다")
	check.call(r.fate_reroll(), "운명 베기: 낮에 뽑은 검을 다시 뽑는다")
	check.call(r.slots[1] != s and r.slots[1] != null and is_equal_approx(f.durability, 70.0), "처음 검은 사라지고 새 검이 들어오며 내구 30을 쓴다")
	check.call(r.fate_reroll() and r.fate_reroll(), "낮마다 3번 된다")
	check.call(not r.fate_reroll() and is_equal_approx(f.durability, 10.0), "네 번째는 안 된다")
	# 같은 시드 같은 순서면 같은 검
	var r2 := Rules.new(d, 5)
	var f2 := r2.give(d.sword_by_name("운명 베기"), 0)
	f2.durability = 100.0
	f2.max_durability = maxf(f2.max_durability, 100.0)
	var s2 := Sword.new(d.sword_by_name("녹슨 장검"), d)
	r2.powers.on_pulled(s2)
	r2._receive(s2)
	r2.fate_reroll()
	var r3 := Rules.new(d, 5)
	var f3 := r3.give(d.sword_by_name("운명 베기"), 0)
	f3.durability = 100.0
	f3.max_durability = maxf(f3.max_durability, 100.0)
	var s3 := Sword.new(d.sword_by_name("녹슨 장검"), d)
	r3.powers.on_pulled(s3)
	r3._receive(s3)
	r3.fate_reroll()
	check.call(r2.slots[1].data.id == r3.slots[1].data.id and r2.rng.state == r3.rng.state, "다시 뽑기는 Rules.rng만 써서 같은 시드에 같은 결과")
	# 내구가 모자라면 안 된다, 운명 베기가 없으면 안 된다
	f2.durability = 30.0
	check.call(not r2.fate_reroll(), "내구가 30이 안 남으면 안 된다")
	var r4 := Rules.new(d, 5)
	var s4 := r4.give(d.sword_by_name("녹슨 장검"), 0)
	r4.powers.on_pulled(s4)
	check.call(not r4.fate_reroll(), "운명 베기를 쥐지 않았으면 안 된다")
	# 밤이 지나면 횟수가 돌아온다
	r.start_night()
	check.call(r.powers.U.fate_left == 3, "밤이 지나면 횟수가 돌아온다")


func _scene(seed_value: int) -> int:
	var r := _night("망자들의 왕관", seed_value)
	var s2 := r.give(d.sword_by_name("쇠말뚝"), 1)
	s2.ins.clear()
	var in_ := LordInput.new()
	in_.attack = true
	in_.dash = true
	var foes: Array[Enemy] = []
	for i in 4:
		foes.append(_foe(r, Vector2(2.0 + i, float(i) - 1.5), false))
	for t in 200:
		in_.dash = t % 40 == 0
		r.step(in_)
		if t == 60:
			r.swap(1)
		if t == 120:
			r.swap(0)
		for e in r.enemies:
			if e.hp < 100.0:
				e.hp = 0.0
	return r.state_hash()


func _deterministic() -> void:
	var a: int = _scene(3)
	var b: int = _scene(3)
	check.call(a == b, "결정성: 같은 시드·같은 입력이면 아군·벽·칼이 든 판의 state_hash가 같다")
	var r1 := _night("쇠말뚝")
	var h0: int = r1.state_hash()
	r1.powers.U.on_swing(1.0, {}, true)
	check.call(r1.state_hash() != h0, "벽이 서면 state_hash가 달라진다(해시에 들어 있다)")
	var r2 := _night("망자들의 왕관")
	var h1: int = r2.state_hash()
	_kill(r2, _foe(r2, Vector2(3, 0)))
	check.call(r2.state_hash() != h1, "아군이 생기면 state_hash가 달라진다")
	var r3 := _night("되돌아오는 칼")
	var h2: int = r3.state_hash()
	r3.powers.on_dash()
	check.call(r3.state_hash() != h2, "날아가는 칼이 생기면 state_hash가 달라진다")


func _duel_off() -> void:
	var r := _night("망자들의 왕관")
	r.powers.off = true
	_kill(r, _foe(r, Vector2(3, 0)))
	check.call(r.powers.U.allies.is_empty(), "결투(Powers.off): 망자들의 왕관이 꺼진다")
	for n in ["쇠말뚝", "언덕을 쌓은 검", "그림자 왕", "되돌아오는 칼", "천 명의 기사", "무덤 파수"]:
		var q := _night(n)
		q.powers.off = true
		q.powers.U.on_swing(1.0, {}, true)
		q.powers.U.on_dash()
		q.powers.U.tick(q.dt)
		check.call(q.powers.U.walls.is_empty() and q.powers.U.allies.is_empty() and q.powers.U.blades.is_empty(), "결투(Powers.off): %s가 꺼진다" % n)
	var fr := Rules.new(d, 5)
	var f := fr.give(d.sword_by_name("운명 베기"), 0)
	f.durability = 100.0
	f.max_durability = 100.0
	var s := Sword.new(d.sword_by_name("녹슨 장검"), d)
	fr.powers.on_pulled(s)
	fr._receive(s)
	fr.powers.off = true
	check.call(not fr.fate_reroll(), "결투(Powers.off): 운명 베기가 꺼진다")
