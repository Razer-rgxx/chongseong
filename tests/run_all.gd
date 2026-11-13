extends SceneTree
## 규칙 단위 테스트. 저장소 맨 위에서: godot --headless --path . -s tests/run_all.gd
## 실패가 하나라도 있으면 종료 코드 1로 끝난다.

var _pass: int = 0
var _fail: int = 0
var d: GameData


func _init() -> void:
	d = GameData.load_default()
	_test_grid()
	_test_data()
	_test_input_map()
	_test_rng_same_seed()
	_test_roll_distribution()
	_test_day_hilts()
	_test_pull()
	_test_pull_refused()
	_test_choice()
	_test_swap()
	_test_lord_move_dash()
	_test_swing_forms()
	_test_durability_break()
	_test_hitstop()
	_test_night_flow()
	_test_lord_dies()
	_test_last_zone_boss()
	_test_replay()
	print("통과 %d, 실패 %d" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
		printerr("실패: " + what)


func _inp(move: Vector2 = Vector2.ZERO, attack: bool = false, dash: bool = false) -> LordInput:
	var i := LordInput.new()
	i.move = move
	i.attack = attack
	i.dash = dash
	return i


## 그 검이 있는 곳으로 영주를 옮긴다.
func _stand_at(r: Rules, h: Hilt) -> void:
	r.lord.pos = h.pos + Vector2(0.3, 0.0)


func _pull_once(r: Rules) -> void:
	var h := r.nearest_hilt(100.0)
	_stand_at(r, h)
	var i := LordInput.new()
	i.pull = true
	r.step(i)
	for t in 200:
		if r.pull_hilt == null:
			break
		r.step()


func _night_rules(seed: int = 1) -> Rules:
	var r := Rules.new(d, seed)
	r.start_night()
	r.lord.face = 0.0
	r.enemies.clear()
	return r


func _test_grid() -> void:
	Grid.size = Vector2i(34, 22)
	check(Grid.cell_to_world(Vector2i(0, 0)) == Vector3(1, 0, 1), "칸 (0,0)의 가운데는 (1, 0, 1)m")
	check(Grid.world_to_cell(Vector3(1.99, 0, 2.0)) == Vector2i(0, 1), "1.99m는 0번 칸, 2.0m는 1번 칸")
	check(Grid.world_to_cells(Grid.cells_to_world(Vector2(3.25, 7.5))) == Vector2(3.25, 7.5), "실수 칸 좌표가 월드로 갔다가 그대로 돌아온다")
	check(Grid.middle() == Vector2(17, 11), "싸움터 한가운데는 (17, 11)")


func _test_data() -> void:
	check(d.swords.size() == 300, "검 300종 (지금 %d)" % d.swords.size())
	var per: Array[int] = []
	for g in 6:
		per.append(d.swords_by_grade[g].size())
	check(per == [82, 70, 55, 40, 40, 13], "등급별 검 수 %s" % [per])
	var names := {}
	for s in d.swords:
		names[s.display_name] = true
	check(names.size() == 300, "검 이름이 겹치지 않는다")
	var missing: Array[String] = []
	for s in d.swords:
		for k in s.inscriptions:
			if not d.inscriptions.has(k):
				missing.append(k)
	check(d.inscriptions.size() == 36 and missing.is_empty(), "각인 36종, 검의 각인이 모두 표에 있다 %s" % [missing])
	var six := true
	for k in d.inscriptions:
		six = six and (d.inscriptions[k] as InscriptionData).values.size() == 6
	check(six, "각인마다 등급별 수치 6개")
	check(d.forms.size() == 4 and d.forms[2].display_name == "대검" and d.forms[2].combo == 2 and d.forms[3].pierce == 2, "형태 4종(대검 2연타, 세검 2명 꿰뚫기)")
	check(d.grades.odds.size() == 6 and d.grades.odds[2] == 40.0 and d.grades.odds[5] == 50000.0, "등급 확률 1/6, 1/40 … 1/50000")
	check(d.enemies.size() == 4 and (d.enemies[&"boss"] as EnemyData).boss and (d.enemies[&"wraith"] as EnemyData).wraith, "적 4종")
	check(d.run.zone_names.size() == 10 and d.run.zone_luck.size() == 10 and d.run.zone_hp.size() == 10 and d.run.zone_damage.size() == 10, "구역 10개, 구역 표 길이가 같다")
	var s := Sword.new(d.sword_by_name("붉은 이삭"), d)
	check(s.grade == 2 and s.form.display_name == "대검" and s.max_durability == roundf(150.0 * 1.3) and is_equal_approx(s.ins["무리 베기"], 34.0), "전설 대검 붉은 이삭: 내구 195, 무리 베기 34")
	check(Sword.new(d.sword_by_name("언덕"), d).max_durability < 0.0, "무한 검 '언덕'은 부러지지 않는다")


func _test_input_map() -> void:
	var cfg := ConfigFile.new()
	check(cfg.load("res://project.godot") == OK, "project.godot을 읽는다")
	for a in ["move_left", "move_right", "move_up", "move_down", "attack", "dash", "pull", "start_night", "swap", "slot_1", "slot_2", "discard", "restart"]:
		check(cfg.has_section_key("input", a), "입력 동작 " + a)


func _test_rng_same_seed() -> void:
	var a := Rules.new(d, 42)
	var b := Rules.new(d, 42)
	var same := true
	for i in 200:
		same = same and a.roll_grade(3.0) == b.roll_grade(3.0)
	for i in a.hilts.size():
		same = same and a.hilts[i].pos == b.hilts[i].pos
	check(same, "같은 시드면 꽂힌 검 자리와 굴린 등급이 같다")


func _test_roll_distribution() -> void:
	var r := Rules.new(d, 7)
	var c: Array[int] = [0, 0, 0, 0, 0, 0]
	var n: int = 200000
	for i in n:
		c[r.roll_grade(1.0)] += 1
	var p1: float = float(c[1]) / n
	var p2: float = float(c[2]) / n
	# 기대값: 귀함 1/6 × (1 - 1/40)(1 - 1/200)(1 - 1/2000)(1 - 1/50000) ≈ 0.1616, 전설 ≈ 0.0248
	check(absf(p1 - 0.1616) < 0.004, "귀함 %.4f (≈0.1616)" % p1)
	check(absf(p2 - 0.0248) < 0.0015, "전설 %.4f (≈0.0248)" % p2)


func _test_day_hilts() -> void:
	var r := Rules.new(d, 3)
	check(r.phase == Rules.Phase.DAY and r.zone == 0, "첫 구역의 낮에서 시작")
	check(r.hilts.size() == d.run.hilts_per_day, "낮마다 검 %d자루가 꽂힌다" % d.run.hilts_per_day)
	var ok := true
	for h in r.hilts:
		ok = ok and h.pos.x >= 2.0 and h.pos.y >= 2.0 and h.pos.x <= 32.0 and h.pos.y <= 20.0
	check(ok, "꽂힌 검은 싸움터 안쪽에 있다")


func _test_pull() -> void:
	var r := Rules.new(d, 5)
	var got: Array[Sword] = []
	r.sword_pulled.connect(func(s: Sword) -> void: got.append(s))
	var steps: Array[int] = []
	r.pull_step.connect(func(_h: Hilt, s: int) -> void: steps.append(s))
	r.debug_grade = 2
	var h := r.nearest_hilt(100.0)
	_stand_at(r, h)
	var i := LordInput.new()
	i.pull = true
	r.step(i)
	check(r.pull_hilt == h and r.pull_grade == 2, "E를 누르면 가까운 검을 뽑기 시작한다")
	var pos0: Vector2 = r.lord.pos
	var ticks: int = 0
	while r.pull_hilt != null and ticks < 200:
		r.step(_inp(Vector2.RIGHT))
		ticks += 1
	check(r.lord.pos == pos0, "뽑는 동안은 움직이지 않는다")
	check(absf(ticks * r.dt - r.pull_duration()) < 0.07, "전설은 %.2f초 버틴다(%.2f)" % [r.pull_duration(), ticks * r.dt])
	check(steps == [1, 2], "전설은 두 번 버틴다(%s)" % [steps])
	check(got.size() == 1 and got[0].grade == 2 and h.gone, "뽑으면 전설 검이 나오고 그 자리는 빈다")
	check(r.slots[0] == got[0] and r.active == 0, "빈 1번 칸에 들고 바로 쥔다")
	check(is_equal_approx(r.lord.hp, d.lord.hp - d.run.pull_cost), "뽑을 때 체력 %d를 쓴다" % d.run.pull_cost)
	r.debug_grade = -1
	_pull_once(r)
	check(r.slots[1] != null and r.active == 0, "두 번째 검은 2번 칸에 들어가고, 쥔 검은 그대로")


func _test_pull_refused() -> void:
	var r := Rules.new(d, 6)
	var why: Array[String] = []
	r.pull_refused.connect(func(t: String) -> void: why.append(t))
	r.lord.hp = d.run.pull_cost
	var h := r.nearest_hilt(100.0)
	_stand_at(r, h)
	var i := LordInput.new()
	i.pull = true
	r.step(i)
	check(r.pull_hilt == null and why.size() == 1, "체력이 뽑기 값 이하면 뽑지 못한다")
	var far := Rules.new(d, 6)
	far.lord.pos = Vector2(0.5, 0.5)
	var hasnt := far.nearest_hilt(d.run.pull_reach) == null
	far.step(i)
	check(hasnt and far.pull_hilt == null, "가까이 없으면 아무 일도 없다")
	var night := Rules.new(d, 6)
	night.start_night()
	night.step(i)
	check(night.pull_hilt == null, "밤에는 뽑지 못한다")


func _test_choice() -> void:
	var r := Rules.new(d, 8)
	r.give(d.swords[0], 0)
	r.give(d.swords[1], 1)
	var asked: Array[Sword] = []
	r.choice_needed.connect(func(s: Sword) -> void: asked.append(s))
	r.debug_grade = 2
	_pull_once(r)
	check(asked.size() == 1 and r.pending == asked[0], "두 칸이 다 차면 어디에 들지 묻는다")
	var t0: int = r.tick
	var p0: Vector2 = r.lord.pos
	r.step(_inp(Vector2.RIGHT))
	check(r.lord.pos == p0 and r.tick == t0 + 1, "고르는 동안은 시간이 멈춘다")
	r.start_night()
	check(r.phase == Rules.Phase.DAY, "고르는 동안은 밤으로 못 넘어간다")
	var a := r.pending
	r.choose(1)
	check(r.slots[1] == a and r.pending == null and r.slots[0].data == d.swords[0], "2번 칸과 바꾼다")
	_pull_once(r)
	var b := r.pending
	r.choose(-1)
	check(b != null and r.pending == null and r.slots[0].data == d.swords[0] and r.slots[1] == a, "두고 가면 두 칸이 그대로다")


func _test_swap() -> void:
	var r := Rules.new(d, 9)
	r.give(d.swords[0], 0)
	check(r.active == 0, "검이 하나면 그걸 쥔다")
	var i := LordInput.new()
	i.swap_to = 2
	r.step(i)
	check(r.active == 0, "다른 칸이 비었으면 바꿔 쥐지 못한다")
	r.give(d.swords[100], 1)
	r.step(i)
	check(r.active == 1, "Q: 다른 칸으로 바꿔 쥔다")
	i.swap_to = 0
	r.step(i)
	check(r.active == 0, "1: 1번 칸을 쥔다")


func _test_lord_move_dash() -> void:
	var r := Rules.new(d, 10)
	var p0: Vector2 = r.lord.pos
	for i in d.run.tick_rate:
		r.step(_inp(Vector2.RIGHT))
	check(absf(r.lord.pos.x - p0.x - d.lord.speed) < 0.05, "1초에 %.1f칸 걷는다(%.2f)" % [d.lord.speed, r.lord.pos.x - p0.x])
	r.lord.pos = Vector2(1.0, 1.0)
	for i in 60:
		r.step(_inp(Vector2(-1, -1)))
	check(r.lord.pos == Vector2(0.5, 0.5), "싸움터 밖으로 못 나간다")
	r.lord.pos = Grid.middle()
	var x0: float = r.lord.pos.x
	r.step(_inp(Vector2.RIGHT, false, true))
	check(r.lord.dash > 0.0 and r.lord.invuln > 0.0, "돌진하면 잠깐 무적")
	for i in 10:
		r.step(_inp(Vector2.RIGHT))
	var moved: float = r.lord.pos.x - x0
	check(moved > d.lord.dash_speed * d.lord.dash_time * 0.9, "돌진은 걷기보다 멀리 간다(%.2f칸)" % moved)


## 장검은 3번째, 대검은 2번째가 큰 베기. 세검은 앞의 2명만 꿰뚫는다.
func _test_swing_forms() -> void:
	var r := _night_rules()
	r.give(d.sword_by_name("녹슨 장검"), 0)
	var big: Array[bool] = []
	r.lord_swung.connect(func(b: bool) -> void: big.append(b))
	for t in 90:
		r.step(_inp(Vector2.ZERO, true))
	check(big.slice(0, 4) == [false, false, true, false], "장검은 세 번째가 큰 베기 %s" % [big.slice(0, 4)])
	var g := _night_rules()
	g.give(d.sword_by_name("녹슨 대검"), 0)
	var gbig: Array[bool] = []
	g.lord_swung.connect(func(b: bool) -> void: gbig.append(b))
	for t in 120:
		g.step(_inp(Vector2.ZERO, true))
	check(gbig.slice(0, 3) == [false, true, false], "대검은 두 번째가 큰 베기 %s" % [gbig.slice(0, 3)])
	var x := _night_rules()
	x.give(d.sword_by_name("녹슨 세검"), 0)
	x.debug_god = true
	var row: Array[Enemy] = []
	for k in 3:
		row.append(x.spawn_at(&"giant", x.lord.pos + Vector2(0.6 + 0.35 * k, 0.0)))
	x.step(_inp(Vector2.ZERO, true))
	var hits: int = 0
	for e in row:
		hits += 1 if e.hp < e.max_hp else 0
	check(hits == 2, "세검은 일직선의 2명까지만 벤다(%d)" % hits)
	var z := _night_rules()
	z.give(d.sword_by_name("녹슨 장검"), 0)
	var e := z.spawn_at(&"wraith", z.lord.pos + Vector2(1.0, 0.0))
	var hp0: float = e.hp
	z.step(_inp(Vector2.ZERO, true))
	var expect: float = d.lord.damage * 1.0 * 1.0 * (1.0 - 0.1 * 0.0)
	check(is_equal_approx(hp0 - e.hp, expect), "흔함 장검 한 번 = %d 피해(%.1f)" % [expect, hp0 - e.hp])
	var behind := z.spawn_at(&"wraith", z.lord.pos + Vector2(-1.2, 0.0))
	var hb: float = behind.hp
	z.lord.cooldown = 0.0
	z.freeze = 0
	z.step(_inp(Vector2.ZERO, true))
	check(behind.hp == hb, "등 뒤 멀리 있는 적은 안 맞는다")


func _test_durability_break() -> void:
	var r := _night_rules()
	r.debug_god = true
	var a := r.give(d.sword_by_name("녹슨 장검"), 0)
	var b := r.give(d.sword_by_name("녹슨 대검"), 1)
	check(r.active == 0, "1번 칸을 쥐고 있다")
	var broke: Array[int] = []
	r.sword_broke.connect(func(k: int, _s: Sword) -> void: broke.append(k))
	a.durability = 2.0
	var e := r.spawn_at(&"giant", r.lord.pos + Vector2(1.0, 0.0))
	e.hp = 99999.0
	var miss := r.spawn_at(&"wraith", Vector2(1, 1))
	miss.hp = 99999.0
	for t in 60:
		e.pos = r.lord.pos + Vector2(1.0, 0.0)
		r.step(_inp(Vector2.ZERO, true))
		if broke.size() > 0:
			break
	check(broke == [0] and r.slots[0] == null, "맞힐 때마다 내구가 1 닳고 0이면 부러진다")
	check(r.active == 1 and r.current() == b, "쥔 검이 부러지면 다른 칸의 검을 쥔다")
	var w := _night_rules()
	var s := w.give(d.sword_by_name("녹슨 장검"), 0)
	var dur: float = s.durability
	w.step(_inp(Vector2.ZERO, true))
	check(s.durability == dur, "허공을 베면 닳지 않는다")


func _test_hitstop() -> void:
	var r := _night_rules()
	r.give(d.sword_by_name("녹슨 장검"), 0)
	r.debug_god = true
	var e := r.spawn_at(&"wraith", r.lord.pos + Vector2(1.0, 0.0))
	var x0: float = e.pos.x
	r.step(_inp(Vector2.ZERO, true))
	check(r.freeze == roundi(d.lord.hitstop / r.dt), "맞히면 히트스톱 %d틱" % r.freeze)
	var p: Vector2 = e.pos
	r.step(_inp(Vector2.RIGHT))
	check(e.pos == p, "히트스톱 동안은 시간이 멈춘다")
	for t in 4:
		r.step()
	check(e.push.x > 0.0 and e.pos.x > x0 + 0.1, "맞은 적은 뒤로 밀려난다(%.2f칸)" % (e.pos.x - x0))


func _test_night_flow() -> void:
	var r := Rules.new(d, 11)
	r.debug_god = true
	var nights: Array[int] = []
	var days: Array[int] = []
	r.night_started.connect(func(z: int) -> void: nights.append(z))
	r.day_started.connect(func(z: int) -> void: days.append(z))
	r.lord.hp = 50.0
	r.start_night()
	check(r.phase == Rules.Phase.NIGHT and r.hilts.is_empty() and nights == [0], "N: 밤이 오면 꽂힌 검이 사라진다")
	var spawned: Array[int] = [0]
	r.enemy_spawned.connect(func(_e: Enemy) -> void: spawned[0] += 1)
	for t in roundi(d.run.night_length * d.run.tick_rate) + 5:
		r.step()
		if r.phase != Rules.Phase.NIGHT:
			break
	check(spawned[0] > 30, "밤 동안 적이 계속 올라온다(%d)" % spawned[0])
	check(r.zone == 1 and r.phase == Rules.Phase.DAY and days == [1], "새벽이 오면 다음 구역의 낮")
	check(is_equal_approx(r.lord.hp, 50.0 + d.run.heal_per_dawn) and r.enemies.is_empty(), "날이 밝으면 체력 +%d, 적은 사라진다" % d.run.heal_per_dawn)
	check(r.hilts.size() == d.run.hilts_per_day, "새 낮에 검이 다시 꽂힌다")
	check(r.lord.pos == Grid.middle(), "새 낮에는 한가운데에서 시작")


func _test_lord_dies() -> void:
	var r := _night_rules()
	var ended: Array[bool] = []
	r.run_ended.connect(func(w: bool) -> void: ended.append(w))
	r.lord.hp = 5.0
	var e := r.spawn_at(&"wolf", r.lord.pos + Vector2(0.5, 0.0))
	e.cooldown = 0.0
	for t in 30:
		r.step()
		if r.phase == Rules.Phase.OVER:
			break
	check(r.phase == Rules.Phase.OVER and ended == [false] and r.lord.hp == 0.0, "체력이 0이 되면 판이 끝난다")


func _test_last_zone_boss() -> void:
	var r := Rules.new(d, 12)
	r.zone = r.zone_count() - 1
	r.debug_god = true
	var bosses: Array[Enemy] = []
	r.boss_spawned.connect(func(e: Enemy) -> void: bosses.append(e))
	r.start_night()
	for t in roundi(d.run.night_length * d.run.tick_rate) + 30:
		r.step()
	check(bosses.size() == 1 and bosses[0].data.boss, "마지막 구역의 밤에는 언덕지기가 나온다")
	check(r.phase == Rules.Phase.NIGHT and r.night_left < 0.0, "언덕지기가 살아 있으면 새벽이 와도 밤이 끝나지 않는다")
	check(is_equal_approx(bosses[0].max_hp, (d.enemies[&"boss"] as EnemyData).hp), "언덕지기 체력은 구역에 따라 오르지 않는다")
	var ended: Array[bool] = []
	r.run_ended.connect(func(w: bool) -> void: ended.append(w))
	r.hurt(bosses[0], 999999.0, Vector2.ZERO, true)
	r.step()
	check(r.phase == Rules.Phase.OVER and r.won and ended == [true], "언덕지기를 쓰러뜨리면 이긴다")


func _test_replay() -> void:
	var a := Rules.new(d, 99)
	var b := Rules.new(d, 99)
	var rec := RandomNumberGenerator.new()
	rec.seed = 5
	var inputs: Array[LordInput] = []
	for i in 2400:
		var inp := _inp(Vector2(rec.randf_range(-1, 1), rec.randf_range(-1, 1)), rec.randf() < 0.4, rec.randf() < 0.05)
		inp.aim_valid = rec.randf() < 0.7
		inp.aim = Vector2(rec.randf_range(5, 29), rec.randf_range(3, 19))
		inp.pull = rec.randf() < 0.1
		inp.swap_to = 2 if rec.randf() < 0.02 else -1
		inputs.append(inp)
	for r in [a, b]:
		for k in inputs.size():
			if k == 600:
				r.start_night()
			if r.pending != null:
				r.choose(k % 3 - 1)
			r.step(inputs[k])
	check(a.state_hash() == b.state_hash() and a.tick == b.tick, "같은 시드·같은 입력이면 똑같이 돈다(뽑기, 밤, 적 포함)")
	check(a.pulls > 0 and a.kills + a.enemies.size() > 0, "다시 돌린 판에서 뽑기와 싸움이 실제로 일어났다(뽑기 %d, 처치 %d)" % [a.pulls, a.kills])
