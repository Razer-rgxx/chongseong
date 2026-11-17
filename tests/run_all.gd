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
	_test_meta_save()
	_test_sheath()
	_test_forge()
	_test_bless()
	_test_elite()
	_test_altar()
	_test_run_shards()
	_test_inscriptions()
	_test_uniques()
	_test_hook()
	_test_patterns()
	_test_moves()
	_test_moving_moves()
	_test_shots()
	_test_parry()
	_test_elements()
	_test_echo()
	_test_moves_with_powers()
	_test_replay_moves()
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


## 동작들만으로 된 공격 방식(테스트용).
func _pat(moves: Array, element: StringName = &"", echo: bool = false) -> PatternData:
	var p := PatternData.new()
	p.moves = PackedStringArray(moves)
	p.element = element
	p.echo = echo
	return p


## 녹슨 장검(각인 없음)에 그 방식을 넣어 쥔 밤. 영주는 가운데에서 동쪽(+x)을 본다. 무적.
func _mv(moves: Array, element: StringName = &"", echo: bool = false) -> Rules:
	var r := _ins_rules()
	r.current().pattern = _pat(moves, element, echo)
	r.debug_god = true
	return r


## 영주 기준 그 자리에 서 있는 적(묶어 둬서 걷지 않는다, 체력이 많다).
func _foe(r: Rules, at: Vector2, kind: StringName = &"giant") -> Enemy:
	var e := r.spawn_at(kind, r.lord.pos + at)
	e.max_hp = 99999.0
	e.hp = e.max_hp
	e.stun = 99.0
	return e


## 맞은 횟수(적 id → 수)를 센다.
func _count_hits(r: Rules) -> Dictionary:
	var n := {}
	r.enemy_hit.connect(func(e: Enemy, _d: float, _b: bool) -> void: n[e.id] = int(n.get(e.id, 0)) + 1)
	return n


## 입력 없이 n틱. 히트스톱은 건너뛴다(때를 재기 쉽게).
func _wait(r: Rules, n: int) -> void:
	for i in n:
		r.freeze = 0
		r.step(_inp())


## 연타를 끊지 않고 한 번 누른다(간격과 히트스톱은 건너뛴다).
func _click(r: Rules) -> void:
	r.lord.cooldown = 0.0
	r.freeze = 0
	r.step(_inp(Vector2.ZERO, true))


func _hurt_by(e: Enemy) -> float:
	return e.max_hp - e.hp


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
	check(d.forms.size() == 4 and d.forms[2].display_name == "대검" and d.forms[3].pierce == 2, "형태 4종(세검 2명 꿰뚫기)")
	check(d.moves.size() == 20 and d.patterns.size() == 151 and d.patterns.all(func(p: PatternData) -> bool: return p != null), "좌클릭: 기본 동작 20, 공격 방식 151(맨손 + 150)")
	var unknown: Array[String] = []
	for p in d.patterns:
		for m in p.moves:
			if not d.moves.has(StringName(m)):
				unknown.append(m)
	check(unknown.is_empty(), "방식의 동작이 모두 표에 있다 %s" % [unknown])
	check(d.patterns[0].moves == PackedStringArray(["sweep"]) and d.pattern_for(null) == d.patterns[0], "맨손은 횡베기 하나뿐인 0번 방식")
	check(d.grades.odds.size() == 6 and d.grades.odds[2] == 40.0 and d.grades.odds[5] == 50000.0, "등급 확률 1/6, 1/40 … 1/50000")
	check(d.enemies.size() == 4 and (d.enemies[&"boss"] as EnemyData).boss and (d.enemies[&"wraith"] as EnemyData).wraith, "적 4종")
	check(d.run.zone_names.size() == 10 and d.run.zone_luck.size() == 10 and d.run.zone_hp.size() == 10 and d.run.zone_damage.size() == 10, "구역 10개, 구역 표 길이가 같다")
	var s := Sword.new(d.sword_by_name("붉은 이삭"), d)
	check(s.grade == 2 and s.form.display_name == "대검" and s.max_durability == roundf(150.0 * 1.3) and is_equal_approx(s.ins["무리 베기"], 34.0), "전설 대검 붉은 이삭: 내구 195, 무리 베기 34")
	check(Sword.new(d.sword_by_name("언덕"), d).max_durability < 0.0, "무한 검 '언덕'은 부러지지 않는다")


func _test_input_map() -> void:
	var cfg := ConfigFile.new()
	check(cfg.load("res://project.godot") == OK, "project.godot을 읽는다")
	for a in ["move_left", "move_right", "move_up", "move_down", "attack", "dash", "hook", "pull", "start_night", "swap", "slot_1", "slot_2", "discard", "restart"]:
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


## 좌클릭 한 번이 방식의 다음 동작이고 마지막이 큰 베기다. 간격은 형태 빠르기와 동작에서. 세검은 부채꼴에서 앞의 2명만 꿰뚫는다.
func _test_swing_forms() -> void:
	var r := _night_rules()
	var sw := r.give(d.sword_by_name("녹슨 장검"), 0)
	var n: int = sw.pattern.steps()
	var big: Array[bool] = []
	var moved: Array[StringName] = []
	r.lord_swung.connect(func(b: bool) -> void: big.append(b))
	r.move_started.connect(func(m: StringName, i: Dictionary) -> void:
		if not i.echo:
			moved.append(m))
	for t in 150:
		r.freeze = 0
		r.step(_inp(Vector2.ZERO, true))
	var want: Array[bool] = []
	for k in n + 1:
		want.append(k == n - 1)
	check(n >= 2 and big.slice(0, n + 1) == want, "녹슨 장검(%s): %d연타, 마지막이 큰 베기 %s" % [sw.pattern.display_name, n, big.slice(0, n + 1)])
	var names: Array[StringName] = []
	for m in sw.pattern.moves:
		names.append(StringName(m))
	check(moved.slice(0, n) == names, "누를 때마다 방식의 다음 동작 %s" % [moved.slice(0, n)])
	var two := _mv(["sweep", "smash"])
	var gbig: Array[bool] = []
	two.lord_swung.connect(func(b: bool) -> void: gbig.append(b))
	for t in 120:
		two.freeze = 0
		two.step(_inp(Vector2.ZERO, true))
	check(gbig.slice(0, 3) == [false, true, false], "두 동작 방식은 두 번째가 큰 베기 %s" % [gbig.slice(0, 3)])
	var gap := func(name: String) -> float:
		var q := _night_rules()
		q.give(d.sword_by_name(name), 0).pattern = _pat(["sweep", "sweep", "sweep"])
		q.step(_inp(Vector2.ZERO, true))
		return q.lord.cooldown
	check(gap.call("녹슨 단검") < gap.call("녹슨 장검") and gap.call("녹슨 장검") < gap.call("녹슨 대검"), "간격은 형태 빠르기에서(단검 < 장검 < 대검)")
	var w := _mv(["sweep", "sweep", "spin"])
	w.lord.combo_timer = 0.0
	for k in 2:
		w.lord.cooldown = 0.0
		w.step(_inp(Vector2.ZERO, true))
	check(w.lord.combo == 2, "연타가 이어진다(%d)" % w.lord.combo)
	_wait(w, 40)
	w.lord.cooldown = 0.0
	w.step(_inp(Vector2.ZERO, true))
	check(w.lord.combo == 1, "combo_window가 지나면 처음 동작부터")
	var x := _night_rules()
	x.give(d.sword_by_name("녹슨 세검"), 0).pattern = _pat(["sweep"])
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
	z.give(d.sword_by_name("녹슨 장검"), 0).pattern = _pat(["sweep", "sweep", "sweep"])
	var e := z.spawn_at(&"wraith", z.lord.pos + Vector2(1.0, 0.0))
	var hp0: float = e.hp
	z.step(_inp(Vector2.ZERO, true))
	var expect: float = d.lord.damage * 1.0 * 1.0 * d.powers.i("투박함_피해")
	check(is_equal_approx(hp0 - e.hp, expect), "흔함 장검(투박함) 횡베기 한 번 = %d 피해(%.1f)" % [expect, hp0 - e.hp])
	var behind := z.spawn_at(&"wraith", z.lord.pos + Vector2(-1.2, 0.0))
	var hb: float = behind.hp
	z.lord.cooldown = 0.0
	z.freeze = 0
	z.step(_inp(Vector2.ZERO, true))
	check(behind.hp == hb, "등 뒤 멀리 있는 적은 안 맞는다")
	var u := _night_rules()
	var fist: Array[StringName] = []
	u.move_started.connect(func(m: StringName, _i: Dictionary) -> void: fist.append(m))
	var ub: Array[bool] = []
	u.lord_swung.connect(func(b: bool) -> void: ub.append(b))
	u.step(_inp(Vector2.ZERO, true))
	check(fist == [&"sweep"] and ub == [false], "맨손: 횡베기 하나, 마무리가 없다")


func _test_durability_break() -> void:
	var r := _night_rules()
	r.debug_god = true
	var a := r.give(d.sword_by_name("녹슨 장검"), 0)
	var b := r.give(d.sword_by_name("녹슨 대검"), 1)
	a.pattern = _pat(["sweep", "sweep", "sweep"])
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
	r.give(d.sword_by_name("녹슨 장검"), 0).pattern = _pat(["sweep", "sweep", "sweep"])
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
		inp.hook = rec.randf() < 0.03
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


func _meta() -> Meta:
	var m := Meta.new()
	m.rng.seed = 3
	return m


func _test_meta_save() -> void:
	var m := _meta()
	m.shards = 123
	m.sheath_id = 196
	m.sheath_lv = 4
	m.sheath_ins = PackedStringArray(["연격"])
	m.bless = {"hp": 2}
	m.note_found(196)
	m.note_found(196)
	var path := "user://test_save.json"
	m.save(path)
	var n := Meta.load_or_new(path)
	check(n.shards == 123 and n.sheath_id == 196 and n.sheath_lv == 4 and n.sheath_ins == PackedStringArray(["연격"]) and n.bless_level("hp") == 2 and int(n.found["196"]) == 2, "저장했다가 그대로 불러온다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(Meta.load_or_new("user://없는_파일.json").shards == 0, "저장이 없으면 빈 기록으로 시작")


func _test_sheath() -> void:
	var m := _meta()
	var common := d.sword_by_name("녹슨 장검")
	var legend := d.sword_by_name("늙은 사자")
	var myth := d.sword_by_name("왕의 그늘")
	m.note_found(common.id)
	m.fix_sheath(d)
	check(m.sheath_candidates(d).is_empty() and m.sheath_id == -1, "흔함만 뽑아 봤으면 검집에 넣을 검이 없다")
	m.note_found(legend.id)
	m.note_found(myth.id)
	m.fix_sheath(d)
	check(m.sheath_candidates(d) == [myth.id, legend.id] and m.sheath_id == myth.id, "전설 이상만, 높은 등급부터. 비었으면 가장 좋은 걸 넣는다")
	m.sheath_id = common.id
	m.fix_sheath(d)
	check(m.sheath_id == myth.id, "자격 없는 검은 빠지고 가장 좋은 걸로 바뀐다")
	m.sheath_id = legend.id
	m.sheath_lv = 5
	m.sheath_ins = PackedStringArray(["처형"])
	var r := Rules.new(d, 1, m)
	var s := r.slots[0]
	check(s != null and s.data == legend and s.from_sheath and r.active == 0, "판을 검집의 검을 들고 시작한다")
	s.pattern = _pat(["sweep", "sweep", "sweep"])
	check(is_equal_approx(s.bonus, 1.4) and s.max_durability == roundf(150.0 * 1.5) and s.ins.has("처형") and s.label() == "+5 늙은 사자", "+5: 피해 ×1.4, 내구 ×1.5, 검집 각인")
	var e := r.spawn_at(&"giant", r.lord.pos + Vector2(1.0, 0.0))
	r.start_night()
	r.lord.face = 0.0
	var hp0: float = e.hp
	r.step(_inp(Vector2.ZERO, true))
	check(is_equal_approx(hp0 - e.hp, 20.0 * 1.6 * 1.4), "검집 보너스가 피해에 들어간다(%.1f)" % (hp0 - e.hp))


func _test_forge() -> void:
	var md := d.meta
	var m := _meta()
	m.shards = 30
	var r := m.forge_sheath(d)
	check(r.paid and m.shards == 0, "강화 값은 조각 30(0단계)")
	check(not m.forge_sheath(d).paid, "조각이 모자라면 강화하지 않는다")
	var ok: int = 0
	var n: int = 4000
	for i in n:
		var t := _meta()
		t.rng.seed = i + 10
		t.shards = 99999
		t.sheath_lv = 6
		if t.forge_sheath(d).ok:
			ok += 1
	check(absf(float(ok) / n - md.sheath_rates[6] / 100.0) < 0.03, "+6에서 성공 확률 %d%% (%.3f)" % [md.sheath_rates[6], float(ok) / n])
	var drop := _meta()
	drop.shards = 99999
	drop.sheath_lv = 5
	drop.sheath_peak = 5
	var dropped := false
	for i in 50:
		var res := drop.forge_sheath(d)
		if not res.ok:
			dropped = res.dropped
			break
	check(dropped, "+5부터는 실패하면 한 단계 내려간다")
	var low := _meta()
	low.shards = 99999
	low.sheath_lv = 4
	var never := true
	for i in 200:
		low.sheath_lv = 4
		var res2 := low.forge_sheath(d)
		if res2.dropped:
			never = false
	check(never, "+4 이하는 실패해도 내려가지 않는다")
	var up := _meta()
	up.shards = 99999
	up.sheath_lv = 4
	while up.sheath_lv < 5:
		up.forge_sheath(d)
	check(up.sheath_ins.size() == 1, "+5에 처음 닿으면 각인이 하나 붙는다")
	var again := up.sheath_ins.size()
	up.sheath_lv = 4
	while up.sheath_lv < 5:
		up.forge_sheath(d)
	check(up.sheath_ins.size() == again, "다시 +5에 닿아도 각인은 더 붙지 않는다")


func _test_bless() -> void:
	var m := _meta()
	m.bless = {"hp": 2, "luck": 5, "cost": 3, "heal": 1}
	var r := Rules.new(d, 2, m)
	check(r.max_hp() == 160.0 and r.lord.hp == 160.0, "단단한 몸 2: 최대 체력 160")
	check(is_equal_approx(r.luck(), 1.4) and r.pull_cost() == d.run.pull_cost - 3.0 and r.heal_at_dawn() == 60.0, "운 ×1.4, 뽑기 체력 -3, 새벽 회복 60")
	m.shards = 79
	check(not m.forge_bless(d.meta, "cost").paid, "가벼운 손 3단계에서 강화하려면 조각 80이 든다")
	m.shards = 80
	var res := m.forge_bless(d.meta, "cost")
	check(res.paid and m.shards == 0, "축복 값은 조각 20 × (단계 + 1)")
	var full := _meta()
	full.bless = {"cost": 4}
	full.shards = 9999
	check(full.bless_full(d.meta, "cost") and not full.forge_bless(d.meta, "cost").paid, "끝까지 올린 축복은 더 강화하지 않는다")
	var fail := _meta()
	fail.shards = 99999
	fail.bless = {"hp": 9}
	var lv_ok := true
	for i in 30:
		fail.forge_bless(d.meta, "hp")
		lv_ok = lv_ok and fail.bless_level("hp") >= 9
	check(lv_ok, "축복은 실패해도 내려가지 않는다")


func _test_elite() -> void:
	var r := Rules.new(d, 13)
	r.debug_god = true
	var got: Array[Enemy] = []
	r.elite_spawned.connect(func(e: Enemy) -> void: got.append(e))
	r.start_night()
	var at: float = -1.0
	for t in roundi(d.run.night_length * d.run.tick_rate):
		r.step()
		if got.size() > 0 and at < 0.0:
			at = 1.0 - r.night_left / d.run.night_length
	check(got.size() == 1, "밤마다 정예가 하나 온다")
	check(absf(at - d.run.elite_at) < 0.02, "밤이 %d%% 지나면 온다(%.2f)" % [d.run.elite_at * 100, at])
	var r2 := _night_rules()
	r2.give(d.sword_by_name("녹슨 장검"), 0)
	var e := r2._spawn_elite()
	check(e.elite and is_equal_approx(e.radius, e.data.radius * d.run.elite_size) and is_equal_approx(e.max_hp, e.data.hp * d.run.elite_hp), "정예는 크고 체력이 4배")
	r2.hurt(e, 999999.0, Vector2.ZERO, false)
	check(r2.elites_killed == 1 and r2.free_pulls == 1, "정예를 쓰러뜨리면 공짜 뽑기 하나")
	var day := Rules.new(d, 14)
	day.free_pulls = 1
	var hp0: float = day.lord.hp
	_pull_once(day)
	check(day.free_pulls == 0 and day.lord.hp == hp0 and day.slots[0] != null, "공짜 뽑기는 체력을 쓰지 않는다")
	day.free_pulls = 9
	day.hurt(day.spawn_at(&"wolf", Vector2(1, 1)), 0.0, Vector2.ZERO, false)
	var e2 := day.spawn_at(&"wolf", Vector2(1, 1))
	e2.elite = true
	day.hurt(e2, 9999.0, Vector2.ZERO, false)
	check(day.free_pulls == d.run.max_free_pulls, "공짜 뽑기는 %d개까지만 모인다" % d.run.max_free_pulls)


func _test_altar() -> void:
	var r := Rules.new(d, 15)
	check(r.altar == null, "첫 구역에는 제단이 없다")
	r.zone = 1
	r._new_day()
	check(r.altar != null and not r.altar.used, "2구역부터 낮마다 제단이 선다")
	var a := r.give(d.sword_by_name("늙은 사자"), 0)
	var b := r.give(d.sword_by_name("붉은 이삭"), 1)
	a.durability = 10.0
	r.lord.pos = r.altar.pos + Vector2(0.3, 0.0)
	var opened: Array[bool] = []
	r.altar_opened.connect(func() -> void: opened.append(true))
	var i := LordInput.new()
	i.pull = true
	r.step(i)
	check(opened.size() == 1 and r.altar_open and r.pull_hilt == null, "제단 앞에서 E를 누르면 제단 창이 열린다")
	var p0: Vector2 = r.lord.pos
	r.step(_inp(Vector2.RIGHT))
	check(r.lord.pos == p0, "제단 창이 열려 있는 동안은 시간이 멈춘다")
	var kinds: Array = r.altar_options().map(func(o: Dictionary) -> String: return o.kind)
	check(kinds == ["melt", "melt", "repair", "transfer"], "녹이기 둘, 벼리기, 옮기기(무리 베기) %s" % [kinds])
	r.use_altar(kinds.find("transfer"))
	check(a.ins.has("무리 베기") and r.slots[1] == null and r.altar.used and not r.altar_open, "옮기기: 다른 칸의 검을 바치고 각인을 받는다")
	r.step(i)
	check(not r.altar_open, "제단은 한 번만 쓴다")
	var m := Rules.new(d, 16)
	m.zone = 1
	m._new_day()
	m.give(d.sword_by_name("왕의 그늘"), 0)
	m.lord.pos = m.altar.pos
	m.step(i)
	m.use_altar(0)
	check(m.slots[0] == null and m.melted_by_grade[3] == 1, "녹이기: 신화 검 하나를 녹였다")
	var rep := Rules.new(d, 17)
	rep.zone = 1
	rep._new_day()
	var s1 := rep.give(d.sword_by_name("늙은 사자"), 0)
	rep.give(d.sword_by_name("녹슨 단검"), 1)
	s1.durability = 3.0
	rep.lord.pos = rep.altar.pos
	rep.step(i)
	rep.use_altar(2)
	check(s1.durability == s1.max_durability and rep.slots[1] == null, "벼리기: 쥔 검의 내구가 다 찬다")
	var close := Rules.new(d, 18)
	close.zone = 1
	close._new_day()
	close.give(d.swords[0], 0)
	close.lord.pos = close.altar.pos
	close.step(i)
	close.use_altar(-1)
	check(not close.altar_open and not close.altar.used, "그냥 닫으면 제단은 그대로 남는다")


func _test_run_shards() -> void:
	var r := Rules.new(d, 19)
	r.kills = 41
	r.zone = 4
	r.broken_by_grade[0] = 3
	r.broken_by_grade[2] = 1
	r.melted_by_grade[3] = 1
	r.elites_killed = 2
	var s := Meta.run_shards(r, d.meta)
	check(s.kills == 10 and s.zone == 40 and s.broken == 3 + 10 and s.melt == 60 and s.elite == 30 and s.total == 153, "조각: 처치 10, 구역 40, 부러진 검 13, 녹인 검 60, 정예 30 = 153 (%s)" % [s])
	var m := _meta()
	r.won = true
	r.zone = r.zone_count() - 1
	var got := m.record_run(r, d.meta)
	check(got.zone == 9 * 10 + 60 and m.best == r.zone_count() + 1 and m.runs == 1 and m.shards == got.total, "정상까지 오르면 조각 60을 더 받고, 기록이 남는다")


# ---------------------------------------------------------------- 각인과 고유 능력

## 각인 하나만 단 흔함 장검을 쥔 밤. 다른 각인은 지운다.
func _ins_rules(key: String = "", v: float = 0.0, name: String = "녹슨 장검") -> Rules:
	var r := _night_rules()
	var s := r.give(d.sword_by_name(name), 0)
	s.ins.clear()
	s.pattern = _pat(["sweep", "sweep", "sweep"])
	if key != "":
		s.ins[key] = v
	r.lord.hp = r.max_hp()
	return r


## 바로 앞(오른쪽 1칸)의 적을 한 번 벤 피해. 연타가 이어지지 않게 매번 첫 타로 친다.
func _hit(r: Rules, kind: StringName = &"wraith", at: Vector2 = Vector2(1.0, 0.0), hp_frac: float = 1.0) -> float:
	var e := r.spawn_at(kind, r.lord.pos + at)
	e.hp = e.max_hp * hp_frac
	var h0: float = e.hp
	_swing_once(r)
	return h0 - e.hp


func _swing_once(r: Rules) -> void:
	r.lord.cooldown = 0.0
	r.lord.combo_timer = 0.0
	r.freeze = 0
	r.step(_inp(Vector2.ZERO, true))


func _test_inscriptions() -> void:
	var base: float = _hit(_ins_rules())
	check(is_equal_approx(base, d.lord.damage), "각인 없는 흔함 장검 = %d 피해(%.1f)" % [d.lord.damage, base])
	var pct := func(key: String) -> float: return d.inscriptions[key].value(0) / 100.0
	check(is_equal_approx(_hit(_ins_rules("날", 10)), base * 1.1), "날: 피해 +N%")
	var r := _ins_rules("가벼움", 50)
	_swing_once(r)
	check(is_equal_approx(r.lord.cooldown, d.lord.cooldown / 1.5), "가벼움: 휘두르기 간격이 짧아진다(%.3f)" % r.lord.cooldown)
	var far: Vector2 = Vector2(d.lord.reach + 0.6, 0.0)
	check(_hit(_ins_rules(), &"wraith", far) == 0.0 and _hit(_ins_rules("긴 날", 100), &"wraith", far) > 0.0, "긴 날: 사거리가 늘어 먼 적도 닿는다")
	var side: Vector2 = Vector2.from_angle(d.lord.arc / 2.0 + 0.3) * 1.3
	check(_hit(_ins_rules(), &"wraith", side) == 0.0 and _hit(_ins_rules("넓은 날", 100), &"wraith", side) > 0.0, "넓은 날: 각도가 넓어 옆의 적도 벤다")
	r = _ins_rules("출혈", 9)
	var e := r.spawn_at(&"giant", r.lord.pos + Vector2(1.0, 0.0))
	_swing_once(r)
	var after: float = e.hp
	for i in 100:
		r.step(_inp())
	check(e.bleed_t <= 0.0 and is_equal_approx(after - e.hp, 9.0), "출혈: 3초 동안 N 피해를 더 입는다(%.2f)" % (after - e.hp))
	check(is_equal_approx(_hit(_ins_rules("처형", 50), &"giant", Vector2(1, 0), 0.25), base * 1.5) and is_equal_approx(_hit(_ins_rules("처형", 50), &"giant"), base), "처형: 체력 30% 이하만 피해 +N%")
	r = _ins_rules("연격", 50)
	var g := r.spawn_at(&"giant", r.lord.pos + Vector2(1.0, 0.0))
	var hits: Array[float] = []
	for i in 3:
		var h0: float = g.hp
		r.lord.cooldown = 0.0
		r.freeze = 0
		r.step(_inp(Vector2.ZERO, true))
		hits.append(h0 - g.hp)
	check(is_equal_approx(hits[0], base) and is_equal_approx(hits[2], base * 1.5), "연격: 마지막 타(마무리) 피해 +N%% (%.1f, %.1f)" % [hits[0], hits[2]])
	r = _ins_rules("밀쳐내기", 100)
	var w := r.spawn_at(&"wraith", r.lord.pos + Vector2(1.0, 0.0))
	_swing_once(r)
	var r0 := _ins_rules()
	var w0 := r0.spawn_at(&"wraith", r0.lord.pos + Vector2(1.0, 0.0))
	_swing_once(r0)
	check(is_equal_approx(w.push.length(), w0.push.length() * 2.0), "밀쳐내기: 넉백 +N%")
	r = _ins_rules("무거움", 50)
	_swing_once(r)
	check(is_equal_approx(r.lord.cooldown, d.lord.cooldown / d.powers.i("무거움_속도")), "무거움: 속도 -10%")
	r = _ins_rules("꿰뚫기", 1, "녹슨 세검")
	var row: Array[Enemy] = []
	for i in 4:
		row.append(r.spawn_at(&"wraith", r.lord.pos + Vector2(0.7 + i * 0.5, 0.0)))
	_swing_once(r)
	check(row.filter(func(x: Enemy) -> bool: return x.hp < x.max_hp).size() == 3, "꿰뚫기: 세검이 한 명 더 꿰뚫는다")
	r = _ins_rules("불씨", 100)
	e = r.spawn_at(&"giant", r.lord.pos + Vector2(1.0, 0.0))
	_swing_once(r)
	check(e.burn > 0.0, "불씨: 확률로 불이 붙는다")
	r = _ins_rules("서리", 2)
	e = r.spawn_at(&"giant", r.lord.pos + Vector2(1.0, 0.0))
	_swing_once(r)
	check(e.slow_k > 0.0 and e.slow_t > 1.9 and e.slow_t <= 2.0, "서리: N초 동안 느려진다")
	r = _ins_rules("번개", 2)
	var zaps: Array = [0]
	r.effect.connect(func(k: StringName, _a: Vector2, _i: Dictionary) -> void:
		if k == &"zap":
			zaps[0] += 1)
	r.spawn_at(&"giant", r.lord.pos + Vector2(1.0, 0.0))
	r.spawn_at(&"wraith", r.lord.pos + Vector2(6.0, 0.0))
	_swing_once(r)
	_swing_once(r)
	check(zaps[0] == 1, "번개: N번째 타격마다 둘레 적에게 번개")
	r = _ins_rules("흡혈", 50)
	r.lord.hp = 50.0
	_hit(r, &"giant")
	check(is_equal_approx(r.lord.hp, 50.0 + base * 0.5), "흡혈: 준 피해의 N%만큼 회복")
	r = _ins_rules("사냥", 7)
	r.lord.hp = 50.0
	_hit(r, &"wraith", Vector2(1, 0), 0.01)
	check(is_equal_approx(r.lord.hp, 57.0), "사냥: 쓰러뜨리면 체력 +N")
	r = _ins_rules("광기", 100)
	r.lord.hp = r.max_hp() * 0.5
	check(is_equal_approx(_hit(r, &"giant"), base * 1.5), "광기: 체력이 낮을수록 피해가 는다")
	r = _ins_rules("첫 타", 100)
	g = r.spawn_at(&"giant", r.lord.pos + Vector2(1.0, 0.0))
	var a0: float = g.hp
	_swing_once(r)
	var a1: float = g.hp
	_swing_once(r)
	check(is_equal_approx(a0 - a1, base * 2.0) and is_equal_approx(a1 - g.hp, base), "첫 타: 처음 베는 적에게만 피해 +N%")
	r = _ins_rules("등 뒤", 100)
	g = r.spawn_at(&"giant", r.lord.pos + Vector2(1.0, 0.0))
	g.face = Vector2.RIGHT
	var b0: float = g.hp
	_swing_once(r)
	check(is_equal_approx(b0 - g.hp, base * 2.0), "등 뒤: 등을 보인 적에게 피해 +N%")
	r = _ins_rules("돌진 베기", 15)
	e = r.spawn_at(&"giant", r.lord.pos + Vector2(0.0, 1.0))
	var c0: float = e.hp
	r.lord.move_dir = Vector2.DOWN
	r.step(_inp(Vector2.DOWN, false, true))
	for i in 5:
		r.step(_inp(Vector2.DOWN))
	check(is_equal_approx(c0 - e.hp, 15.0), "돌진 베기: 지나간 적에게 N 피해")
	r = _ins_rules("날랜 발", 50)
	check(is_equal_approx(r.powers.dash_cooldown(), d.lord.dash_cooldown * 0.5), "날랜 발: 돌진 재사용 -N%")
	var tough := Sword.new(d.sword_by_name("녹슨 장검"), d)
	check(tough.max_durability == roundf(d.grades.durability[0] * d.forms[1].durability * (1.0 + d.inscriptions["투박함"].value(0) / 100.0)), "투박함·단단함: 내구 +N%")
	r = _ins_rules("숫돌", 3)
	var s := r.current()
	s.durability = 10.0
	_hit(r, &"wraith", Vector2(1, 0), 0.01)
	check(is_equal_approx(s.durability, 12.0), "숫돌: 쓰러뜨리면 내구 +N(한 번 닳고 3 참)")
	r = _ins_rules("막기", 50)
	r.lord.swing = 0.1
	check(is_equal_approx(r.powers.lord_damage(10.0, null), 5.0), "막기: 휘두르는 동안 받는 피해 -N%")
	r = _ins_rules("버팀", 20)
	check(is_equal_approx(r.powers.lord_damage(10.0, null), 8.0), "버팀: 받는 피해 -N%")
	r = _ins_rules("가시", 9)
	e = r.spawn_at(&"giant", r.lord.pos + Vector2(1.0, 0.0))
	var t0: float = e.hp
	r.powers.lord_damage(5.0, e)
	check(is_equal_approx(t0 - e.hp, 9.0), "가시: 나를 때린 적에게 N 피해")
	check(is_equal_approx(_hit(_ins_rules("잔상", 100), &"giant"), base * 2.0), "잔상: 확률로 한 번 더 벤다")
	r = _ins_rules("바꿔 쥐기", 100)
	r.give(d.sword_by_name("녹슨 장검"), 1)
	r.swap(1)
	r.swap(0)
	check(is_equal_approx(_hit(r, &"giant"), base * 2.0) and is_equal_approx(_hit(r, &"giant"), base), "바꿔 쥐기: 바꿔 쥔 뒤 첫 공격만 피해 +N%")
	r = _ins_rules("무리 베기", 100)
	var trio: Array[Enemy] = []
	for i in 3:
		trio.append(r.spawn_at(&"giant", r.lord.pos + Vector2.from_angle((i - 1) * 0.4) * 1.2))
	_swing_once(r)
	check(trio.all(func(x: Enemy) -> bool: return is_equal_approx(x.max_hp - x.hp, base * 2.0)), "무리 베기: 셋 이상 베면 피해 +N%")
	check(is_equal_approx(_hit(_ins_rules("거인 베기", 100), &"giant"), base * 2.0) and is_equal_approx(_hit(_ins_rules("거인 베기", 100), &"wraith"), base), "거인 베기: 큰 적에게만")
	check(is_equal_approx(_hit(_ins_rules("망령 베기", 100), &"wraith"), base * 2.0) and is_equal_approx(_hit(_ins_rules("망령 베기", 100), &"giant"), base), "망령 베기: 망령에게만")
	r = _ins_rules("마지막 일격", 30)
	e = r.spawn_at(&"giant", r.lord.pos + Vector2(1.0, 0.0))
	var m0: float = e.hp
	r.current().durability = 1.0
	_swing_once(r)
	check(r.slots[0] == null and is_equal_approx(m0 - e.hp, base + 30.0), "마지막 일격: 부러질 때 둘레에 N 피해")
	r = _ins_rules("가벼운 손", 2)
	check(is_equal_approx(r.pull_cost(), d.run.pull_cost - 2.0), "가벼운 손: 뽑을 때 체력을 N 덜 쓴다")
	r = _ins_rules("행운", 50)
	check(is_equal_approx(r.luck(), d.run.zone_luck[0] * 1.5), "행운: 뽑기 운 +N%")
	r = _ins_rules("피의 값", 50)
	var hp_before: float = r.lord.hp
	check(is_equal_approx(_hit(r, &"giant"), base * 1.5) and is_equal_approx(r.lord.hp, hp_before - 1.0), "피의 값: 휘두를 때 체력 1, 피해 +N%")
	r = _ins_rules("새벽", 100)
	r.night_left = 20.0
	check(is_equal_approx(_hit(r, &"giant"), base * 2.0), "새벽: 밤의 마지막 30초 피해 +N%")
	check(d.inscriptions.size() == 36, "각인은 36종")


func _named(name: String, k: int = 0) -> Rules:
	var r := _night_rules()
	var s := r.give(d.sword_by_name(name), k)
	s.ins.clear()
	s.pattern = _pat(["sweep", "sweep", "sweep"])
	r.active = k
	r.lord.hp = r.max_hp()
	return r


func _test_uniques() -> void:
	var ready: Array = []
	for sw in d.swords:
		if sw.unique_ready:
			ready.append(sw.display_name)
		if sw.unique_ready != Powers.READY.has(sw.display_name) and sw.unique_text != "":
			check(false, "unique_ready가 규칙과 다르다: " + sw.display_name)
	check(ready.size() == Powers.READY.size(), "unique_ready %d개 = 규칙에 들어간 고유 능력 %d개" % [ready.size(), Powers.READY.size()])
	var base: float = d.lord.damage * d.forms[1].damage
	var r := _named("성주의 저울")
	var s := r.current()
	var gm: float = d.grades.damage_mult[s.grade] * d.forms[s.data.form].damage / d.forms[1].damage
	check(is_equal_approx(_hit(r, &"giant"), base * gm * 1.4), "성주의 저울: 체력 절반 이상이면 피해 +40%")
	r.lord.hp = 10.0
	check(is_equal_approx(r.powers.lord_damage(10.0, null), 6.0), "성주의 저울: 절반 아래면 받는 피해 -40%")
	r = _named("마지막 숨")
	r.lord.hp = r.max_hp() * 0.1
	_swing_once(r)
	check(r.lord.big, "마지막 숨: 체력 20% 이하면 늘 큰 베기")
	r = _named("처음이자 마지막 칼")
	var many: Array[Enemy] = []
	for i in 5:
		many.append(r.spawn_at(&"giant", Vector2(3 + i * 4, 3)))
	_swing_once(r)
	check(many.all(func(x: Enemy) -> bool: return x.dead), "처음이자 마지막 칼: 밤마다 한 번 모든 적이 쓰러진다")
	r = _named("충신", 1)
	r.give(d.sword_by_name("녹슨 장검"), 0)
	r.active = 0
	r.lord.hp = 5.0
	r._hurt_lord(50.0)
	check(r.phase == Rules.Phase.NIGHT and r.lord.hp == 30.0 and r.slots[1] == null, "충신: 대신 부러지고 체력 30으로 버틴다")
	r = _named("영원한 파수")
	r.lord.hp = 5.0
	r._hurt_lord(50.0)
	check(r.phase == Rules.Phase.NIGHT and r.powers.undying > 0.0, "영원한 파수: 10초 동안 쓰러지지 않는다")
	for i in 320:
		r.step(_inp())
	check(r.phase == Rules.Phase.OVER, "영원한 파수: 시간이 다하도록 체력을 못 되찾으면 쓰러진다")
	r = Rules.new(d, 3)
	r.give(d.sword_by_name("두 번째 기회"), 0)
	r.start_night()
	r.lord.hp = 5.0
	r.enemies.clear()
	r._hurt_lord(50.0)
	check(r.phase == Rules.Phase.NIGHT and is_equal_approx(r.lord.hp, r.max_hp()) and r.powers.run_used.has("second"), "두 번째 기회: 그 밤을 처음부터 다시 한다")
	r = _named("바람 가르는 깃")
	r.powers.dash_charges = r.powers.max_charges()
	r.step(_inp(Vector2.DOWN, false, true))
	for i in 6:
		r.step(_inp(Vector2.DOWN))
	r.step(_inp(Vector2.DOWN, false, true))
	check(r.lord.dash > 0.0, "바람 가르는 깃: 돌진을 두 번 연달아 한다")
	r = _named("쌍칼 서약")
	var other := r.give(d.sword_by_name("녹슨 장검"), 1)
	other.ins.clear()
	other.ins["날"] = 50.0
	check(is_equal_approx(r.powers.ins("날"), 50.0), "쌍칼 서약: 다른 칸의 각인도 발동한다")
	r = _named("첫 번째 왕", 1)
	var w := r.give(d.sword_by_name("녹슨 장검"), 0)
	w.ins.clear()
	w.ins["날"] = 20.0
	r.active = 0
	check(is_equal_approx(r.powers.ins("날"), 30.0), "첫 번째 왕: 두 검의 각인 수치 +50%")
	r = _named("행운의 녹")
	var l0: float = r.luck()
	r.current().durability = 1.0
	r.spawn_at(&"giant", r.lord.pos + Vector2(1, 0))
	_swing_once(r)
	check(r.slots[0] == null and is_equal_approx(r.luck(), l0 * 3.0), "행운의 녹: 부러지면 다음 뽑기 운 ×3")
	r = Rules.new(d, 4)
	r.give(d.sword_by_name("언덕의 첫 검"), 0)
	r.give(d.sword_by_name("모든 검의 어머니"), 1)
	var plain := Sword.new(d.sword_by_name("녹슨 장검"), d)
	var dur0: float = plain.max_durability
	var n_ins: int = plain.ins.size()
	r.powers.on_pulled(plain)
	check(plain.max_durability == roundf(dur0 * 1.2) and plain.ins.size() == n_ins + 1, "언덕의 첫 검(+20% 내구)과 모든 검의 어머니(각인 하나 더)")
	r = _named("메아리 계곡")
	var e := r.spawn_at(&"giant", r.lord.pos + Vector2(1, 0))
	_swing_once(r)
	var e1: float = e.hp
	for i in 20:
		r.step(_inp())
	check(e.hp < e1, "메아리 계곡: 0.5초 뒤 같은 베기가 한 번 더")
	r = _named("망각")
	var fool := r.spawn_at(&"wolf", r.lord.pos + Vector2(1, 0))
	var victim := r.spawn_at(&"giant", r.lord.pos + Vector2(1.6, 0.2))
	_swing_once(r)
	var v0: float = victim.hp
	var hp0: float = r.lord.hp
	for i in 40:
		r.step(_inp())
	check(fool.confused > 0.0 or victim.hp < v0, "망각: 찔린 적이 다른 적을 친다")
	check(r.lord.hp >= hp0 - victim.damage * 2.0, "망각: 그동안 나를 덜 때린다")
	r = _named("늪지기")
	e = r.spawn_at(&"giant", r.lord.pos + Vector2(1, 0))
	_swing_once(r)
	r.step(_inp())
	r.step(_inp())
	check(r.powers.zones.size() == 1 and e.slow_k > 0.0, "늪지기: 찌른 자리에 늪이 생겨 느려진다")


func _hook_in() -> LordInput:
	var i := LordInput.new()
	i.hook = true
	return i


func _test_hook() -> void:
	var r := _ins_rules()
	r.current().pattern = _pat(["hook", "sweep", "spin"])
	var e := r.spawn_at(&"wraith", r.lord.pos + Vector2(6.0, 0.5))
	var side := r.spawn_at(&"wraith", r.lord.pos + Vector2(0.0, 4.0))
	e.hp = 9999.0
	side.hp = 9999.0
	var h0: float = e.hp
	var start: Vector2 = r.lord.pos
	r.step(_hook_in())
	check(r.lord.hook > 0.0 and r.lord.hook_target == e, "갈고리: 겨눈 쪽(부채꼴 안)의 적에게 건다")
	for t in 40:
		if r.lord.hook <= 0.0:
			break
		r.freeze = 0
		r.step()
	# 닿은 뒤 벤 넉백으로 적은 조금 밀려난다. 영주가 적이 있던 곳 앞까지 왔는지 본다
	check(r.lord.pos.x - start.x > 6.0 - e.radius - d.lord.hook_gap - 1.0 and r.lord.hook_target == null, "갈고리: 그 적 앞까지 날아간다(%.2f칸)" % (r.lord.pos.x - start.x))
	var want: float = d.lord.damage * d.lord.big_damage_mult * d.lord.hook_damage_mult
	check(is_equal_approx(h0 - e.hp, want), "갈고리: 닿으면 큰 베기 × %.1f (%.1f, 바란 값 %.1f)" % [d.lord.hook_damage_mult, h0 - e.hp, want])
	check(is_equal_approx(side.hp, 9999.0), "갈고리: 옆의 적은 그대로")
	r.freeze = 0
	r.step(_hook_in())
	check(r.lord.hook <= 0.0, "갈고리: 다시 쓰려면 기다려야 한다")
	var r2 := _ins_rules()
	r2.current().pattern = _pat(["hook", "sweep", "spin"])
	r2.spawn_at(&"wraith", r2.lord.pos + Vector2(0.0, 4.0))
	r2.spawn_at(&"wraith", r2.lord.pos + Vector2(d.lord.hook_range + 2.0, 0.0))
	r2.step(_hook_in())
	check(r2.lord.hook <= 0.0 and r2.lord.hook_cooldown <= 0.0, "갈고리: 겨눈 쪽 사거리 안에 적이 없으면 안 걸고 기다림도 없다")
	var r3 := Rules.new(d, 1)
	r3.give(d.sword_by_name("녹슨 장검"), 0).pattern = _pat(["hook", "sweep", "spin"])
	r3.lord.face = 0.0
	r3.spawn_at(&"wraith", r3.lord.pos + Vector2(3.0, 0.0))
	r3.step(_hook_in())
	check(r3.lord.hook <= 0.0, "갈고리: 낮에는 안 걸린다")
	# 갈고리 검이 아니면 우클릭 갈고리가 안 걸린다
	var plain := _ins_rules()
	plain.spawn_at(&"wraith", plain.lord.pos + Vector2(4.0, 0.0))
	plain.step(_hook_in())
	check(not plain.pattern().has_hook() and plain.lord.hook <= 0.0 and plain.lord.hook_cooldown <= 0.0, "갈고리: 갈고리 검이 아니면 우클릭이 안 걸린다")
	var bare := _night_rules()
	bare.spawn_at(&"wraith", bare.lord.pos + Vector2(4.0, 0.0))
	bare.step(_hook_in())
	check(bare.lord.hook <= 0.0, "갈고리: 맨손으로도 안 걸린다")
	var real: SwordData = null
	for sd in d.swords:
		if d.pattern_for(sd).has_hook():
			real = sd
			break
	var hr := _night_rules()
	hr.give(real, 0)
	var t := hr.spawn_at(&"wraith", hr.lord.pos + Vector2(4.0, 0.0))
	hr.step(_hook_in())
	check(hr.lord.hook > 0.0 and hr.lord.hook_target == t, "갈고리: 표의 갈고리 검(%s, %s)으로는 걸린다" % [real.display_name, d.pattern_for(real).display_name])
	# 좌클릭의 갈고리 베기: 겨눈 쪽 적에게 날아가 동작의 배수로 벤다. 우클릭의 재사용 시간은 쓰지 않는다
	var lm := _mv(["hook", "sweep", "spin"])
	var far := _foe(lm, Vector2(5.0, 0.0), &"wraith")
	var started: Array[Dictionary] = []
	lm.move_started.connect(func(m: StringName, i: Dictionary) -> void:
		if m == &"hook":
			started.append(i))
	var arrived: Array[Dictionary] = []
	lm.move_area.connect(func(m: StringName, i: Dictionary) -> void:
		if m == &"hook":
			arrived.append(i))
	var from: Vector2 = lm.lord.pos
	lm.step(_inp(Vector2.ZERO, true))
	check(lm.lord.hook > 0.0 and lm.lord.hook_cooldown <= 0.0 and started.size() == 1 and started[0].has("from") and started[0].has("to"), "갈고리 베기: 좌클릭으로 날아간다(우클릭 재사용 없음)")
	_wait(lm, 20)
	check(arrived.size() == 1 and lm.lord.pos.x - from.x > 3.5 and is_equal_approx(_hurt_by(far), d.lord.damage * 1.3), "갈고리 베기: 닿으면 × 1.3 (%.1f, %.2f칸)" % [_hurt_by(far), lm.lord.pos.x - from.x])
	var none := _mv(["hook", "sweep", "spin"])
	var near := _foe(none, Vector2(0.0, 0.8))
	none.step(_inp(Vector2.ZERO, true))
	check(none.lord.hook <= 0.0 and is_equal_approx(_hurt_by(near), d.lord.damage), "갈고리 베기: 겨눈 쪽에 적이 없으면 횡베기")


# ---------------------------------------------------------------- 좌클릭: 공격 방식 150가지

## build_attacks.gd가 만든 표: 검마다 방식 1~150, 모두 쓰인다, 등급대 수, 갈고리 12가지, 이름이 겹치지 않는다.
func _test_patterns() -> void:
	var used := {}
	var range_ok := true
	var grade_ok := true
	for s in d.swords:
		range_ok = range_ok and s.attack >= 1 and s.attack <= 150
		if s.attack >= 1 and s.attack <= 150:
			used[s.attack] = true
			grade_ok = grade_ok and d.patterns[s.attack].grade == s.grade
	check(range_ok, "검마다 공격 방식 번호가 1~150")
	check(used.size() == 150, "방식 150가지가 모두 검에 쓰인다(%d)" % used.size())
	check(grade_ok, "검은 자기 등급대의 방식을 받는다")
	var per: Array[int] = [0, 0, 0, 0, 0, 0]
	var hooks: Array[int] = [0, 0, 0, 0, 0, 0]
	var names := {}
	var keys := {}
	var shape_ok := true
	for i in range(1, 151):
		var p := d.patterns[i]
		per[p.grade] += 1
		if p.has_hook():
			hooks[p.grade] += 1
		names[p.display_name] = true
		keys["%s|%s|%s" % [",".join(p.moves), p.element, p.echo]] = true
		var n: int = p.steps()
		var last: MoveData = d.move(StringName(p.moves[n - 1]))
		match p.grade:
			0:
				shape_ok = shape_ok and n >= 2 and n <= 3 and p.element == &"" and not p.echo
			1:
				shape_ok = shape_ok and n == 3 and p.element == &"" and not p.echo
			2:
				shape_ok = shape_ok and n == 3 and p.element != &"" and not p.echo
			3:
				shape_ok = shape_ok and n >= 3 and n <= 4 and p.element != &"" and not p.echo
			4:
				shape_ok = shape_ok and n == 4 and p.element != &"" and p.echo
			5:
				shape_ok = shape_ok and p.element != &"" and p.echo
		shape_ok = shape_ok and last.role != "link"
	check(per == [41, 35, 28, 20, 20, 6], "등급대별 방식 수 %s" % [per])
	check(hooks == [0, 0, 4, 4, 3, 1], "갈고리 베기가 든 방식은 12가지(전설 4, 신화 4, 초월 3, 무한 1) %s" % [hooks])
	check(names.size() == 150 and keys.size() == 150, "방식 이름과 내용이 겹치지 않는다(%d, %d)" % [names.size(), keys.size()])
	check(shape_ok, "등급대의 모양(이음 수, 속성, 메아리, 마지막은 마무리)")
	var hook_swords: int = 0
	for s in d.swords:
		hook_swords += 1 if d.pattern_for(s).has_hook() else 0
	check(hook_swords >= 20 and hook_swords <= 28, "갈고리 검은 약 24자루(%d)" % hook_swords)
	var sw := Sword.new(d.sword_by_name("녹슨 단검"), d)
	check(sw.pattern == d.patterns[d.sword_by_name("녹슨 단검").attack], "검을 들면 표의 방식이 붙는다")


## 모양마다 덮는 곳만 맞는지.
func _test_moves() -> void:
	var B: float = d.lord.reach
	# 횡베기: 앞 부채꼴
	var r := _mv(["sweep"])
	var front := _foe(r, Vector2(1.0, 0.2))
	var back := _foe(r, Vector2(-1.2, 0.0))
	r.step(_inp(Vector2.ZERO, true))
	check(_hurt_by(front) > 0.0 and _hurt_by(back) == 0.0, "횡베기: 앞 부채꼴만")
	# 찌르기: 곧은 띠 안 모두(꿰뚫음), 띠 밖은 안 맞는다, 반 칸 앞으로
	r = _mv(["thrust"])
	var row: Array[Enemy] = []
	for k in 3:
		row.append(_foe(r, Vector2(0.7 + 0.7 * k, 0.0)))
	var off := _foe(r, Vector2(1.2, 1.0))
	var x0: float = r.lord.pos.x
	r.step(_inp(Vector2.ZERO, true))
	_wait(r, 4)
	check(row.all(func(e: Enemy) -> bool: return is_equal_approx(_hurt_by(e), d.lord.damage * 0.9)), "찌르기: 띠 안의 셋을 모두 꿰뚫는다(× 0.9)")
	check(_hurt_by(off) == 0.0, "찌르기: 띠 밖(옆 1칸)은 안 맞는다")
	check(absf(r.lord.pos.x - x0 - 0.5) < 0.01, "찌르기: 반 칸 앞으로(%.2f)" % (r.lord.pos.x - x0))
	# 반월: 넓은 부채꼴(220°)
	r = _mv(["crescent"])
	var wide := _foe(r, Vector2.from_angle(deg_to_rad(100.0)) * 1.2)
	var dead_back := _foe(r, Vector2(-1.2, 0.0))
	r.step(_inp(Vector2.ZERO, true))
	var s2 := _mv(["sweep"])
	var wide2 := _foe(s2, Vector2.from_angle(deg_to_rad(100.0)) * 1.2)
	s2.step(_inp(Vector2.ZERO, true))
	check(_hurt_by(wide) > 0.0 and _hurt_by(wide2) == 0.0 and _hurt_by(dead_back) == 0.0, "반월: 옆 100°도 벤다(횡베기는 못 벤다), 바로 뒤는 안 맞는다")
	# 올려베기: 맞은 적이 묶인다
	r = _mv(["rising"])
	var up := r.spawn_at(&"giant", r.lord.pos + Vector2(1.0, 0.0))
	r.step(_inp(Vector2.ZERO, true))
	check(up.stun > 0.3 and is_equal_approx(_hurt_by(up), d.lord.damage * 0.9), "올려베기: × 0.9, 0.35초 묶임")
	# 회전베기: 등 뒤도
	r = _mv(["sweep", "spin"])
	r.lord.combo = 1
	r.lord.combo_timer = 1.0
	var behind := _foe(r, Vector2(-1.2, 0.0))
	var out := _foe(r, Vector2(0.0, B + 1.0))
	r.step(_inp(Vector2.ZERO, true))
	check(_hurt_by(behind) > 0.0 and _hurt_by(out) == 0.0 and r.lord.big, "회전베기: 등 뒤의 적도 벤다, 칼 길이 밖은 안 맞는다(마무리)")
	# 내려찍기: 0.12초 뒤 앞의 원
	r = _mv(["smash"])
	var c := _foe(r, Vector2(B * 0.8 + 1.0, 0.0))
	var far := _foe(r, Vector2(-1.0, 0.0))
	var areas: Array[Dictionary] = []
	r.move_area.connect(func(_m: StringName, i: Dictionary) -> void: areas.append(i))
	r.step(_inp(Vector2.ZERO, true))
	var at0: float = _hurt_by(c)
	_wait(r, 4)
	check(at0 == 0.0 and _hurt_by(c) > 0.0 and _hurt_by(far) == 0.0, "내려찍기: 바로는 안 맞고 0.12초 뒤 앞의 원 안만")
	check(areas.size() == 1 and areas[0].shape == &"circle" and is_equal_approx(float(areas[0].radius), 1.6) and int(areas[0].hits) == 1, "내려찍기: move_area(circle, 반지름 1.6, 맞힌 수)")
	# 십자 베기: 앞 띠 + 가로지르는 띠
	r = _mv(["cross"])
	var side := _foe(r, Vector2(B * 1.3 / 2.0, -B * 1.6 / 2.0 + 0.1))
	var nope := _foe(r, Vector2(-1.5, -1.5))
	r.step(_inp(Vector2.ZERO, true))
	check(_hurt_by(side) > 0.0 and _hurt_by(nope) == 0.0, "십자 베기: 가로지르는 띠의 끝도 벤다")
	# 발도: 0.25초 멈췄다가 아주 긴 띠
	r = _mv(["iaido"])
	var line_far := _foe(r, Vector2(B * 3.0 - 0.2, 0.0))
	var past := _foe(r, Vector2(B * 3.0 + 1.0, 0.0))
	var beside := _foe(r, Vector2(2.0, 1.0))
	var p0: Vector2 = r.lord.pos
	r.step(_inp(Vector2.ZERO, true))
	r.freeze = 0
	r.step(_inp(Vector2.RIGHT))
	var still: bool = r.lord.pos == p0
	var early: float = _hurt_by(line_far)
	_wait(r, 8)
	check(still and early == 0.0 and is_equal_approx(_hurt_by(line_far), d.lord.damage * 2.4), "발도: 멈췄다가 0.25초 뒤 칼 길이 × 3의 띠, × 2.4")
	check(_hurt_by(past) == 0.0 and _hurt_by(beside) == 0.0, "발도: 띠 끝 너머와 옆은 안 맞는다")
	# 지진: 둘레 원 + 퍼지는 고리 셋
	r = _mv(["quake"])
	var inner := _foe(r, Vector2(1.0, 0.0))
	var ring2 := _foe(r, Vector2(0.0, 3.5), &"wolf")
	var rings: Array[Dictionary] = []
	r.move_area.connect(func(m: StringName, i: Dictionary) -> void:
		if m == &"quake":
			rings.append(i))
	var hits := _count_hits(r)
	r.step(_inp(Vector2.ZERO, true))
	var ring_first: float = _hurt_by(ring2)
	_wait(r, 25)
	check(_hurt_by(inner) > 0.0 and ring_first == 0.0, "지진: 둘레 원(1.5)이 바로, 먼 적은 아직")
	check(rings.size() == 3 and rings.all(func(i: Dictionary) -> bool: return i.shape == &"ring"), "지진: 고리 셋(move_area ring %d)" % rings.size())
	check(int(hits.get(ring2.id, 0)) == 1 and is_equal_approx(_hurt_by(ring2), d.lord.damage * 0.6), "지진: 반지름 3.5의 적은 두 번째 고리에 한 번(× 0.6)")
	# 소용돌이: 0.15초마다 둘레 원 4번, 그동안 걸을 수 있다
	r = _mv(["whirl"])
	var wf := _foe(r, Vector2(1.0, 0.0))
	var ticks: Array[int] = [0]
	r.move_area.connect(func(m: StringName, _i: Dictionary) -> void:
		if m == &"whirl":
			ticks[0] += 1)
	hits = _count_hits(r)
	var wx: float = r.lord.pos.x
	r.step(_inp(Vector2.ZERO, true))
	for i in 20:
		r.freeze = 0
		r.step(_inp(Vector2.DOWN))
	check(int(hits.get(wf.id, 0)) == 4 and ticks[0] == 4, "소용돌이: 네 번 벤다(%d, move_area %d)" % [int(hits.get(wf.id, 0)), ticks[0]])
	check(r.lord.pos.y > Grid.middle().y + 1.0 and is_equal_approx(r.lord.pos.x, wx), "소용돌이: 도는 동안 걷는다")
	# 연속 찌르기: 4번
	r = _mv(["flurry"])
	var ff := _foe(r, Vector2(1.0, 0.0))
	hits = _count_hits(r)
	r.step(_inp(Vector2.ZERO, true))
	_wait(r, 12)
	check(int(hits.get(ff.id, 0)) == 4 and is_equal_approx(_hurt_by(ff), d.lord.damage * 0.35 * 4.0), "연속 찌르기: 네 번, 한 번에 × 0.35 (%d번)" % int(hits.get(ff.id, 0)))
	# 끌어당기기: 앞 60° 안의 먼 적을 영주 앞으로
	r = _mv(["pull"])
	var pulled := _foe(r, Vector2(3.0, 0.3), &"wraith")
	var aside := _foe(r, Vector2(0.0, 3.0), &"wraith")
	r.step(_inp(Vector2.ZERO, true))
	var pd: float = pulled.pos.distance_to(r.lord.pos)
	check(pd < 1.4 and pulled.pos.x > r.lord.pos.x and _hurt_by(pulled) > 0.0, "끌어당기기: 앞의 적을 영주 앞 1칸으로(%.2f칸)" % pd)
	check(aside.pos.distance_to(r.lord.pos) > 2.9 and _hurt_by(aside) == 0.0, "끌어당기기: 부채꼴 밖은 그대로")


## 영주를 옮기는 동작: 돌진베기, 도약, 순간 베기, 물러나 베기.
func _test_moving_moves() -> void:
	var r := _mv(["lunge"])
	var on_path := _foe(r, Vector2(2.0, 0.5))
	var off_path := _foe(r, Vector2(2.0, 2.0))
	var start: Vector2 = r.lord.pos
	var info: Array[Dictionary] = []
	r.move_started.connect(func(_m: StringName, i: Dictionary) -> void: info.append(i))
	r.step(_inp(Vector2.ZERO, true))
	r.freeze = 0
	r.step(_inp())
	var inv: bool = r.lord.invuln > 0.0
	_wait(r, 8)
	check(absf(r.lord.pos.x - start.x - 3.5) < 0.01 and inv, "돌진베기: 0.15초에 3.5칸 앞으로, 무적(%.2f)" % (r.lord.pos.x - start.x))
	check(_hurt_by(on_path) > 0.0 and _hurt_by(off_path) == 0.0, "돌진베기: 지나간 길 0.8칸 안만 벤다")
	check(info.size() == 1 and info[0].has("from") and info[0].has("to") and is_equal_approx(float(info[0].time), 0.15), "돌진베기: move_started에 from·to·time")
	# 도약: 겨눈 쪽 적의 자리로 뛰어 원(2.0), 밖으로 넉백
	r = _mv(["leap"])
	var target := _foe(r, Vector2(4.0, 0.0))
	var near := _foe(r, Vector2(4.0, 1.5), &"wraith")
	var far := _foe(r, Vector2(4.0, 4.0))
	var land := r.lord.pos + Vector2(4.0, 0.0)
	r.step(_inp(Vector2.ZERO, true))
	_wait(r, 3)
	var mid_air: bool = r.lord.invuln > 0.0 and _hurt_by(target) == 0.0
	_wait(r, 10)
	check(mid_air and r.lord.pos.distance_to(land) < 0.01, "도약: 0.35초 날아 겨눈 쪽 적의 자리에 내린다(무적)")
	check(_hurt_by(target) > 0.0 and _hurt_by(near) > 0.0 and _hurt_by(far) == 0.0 and near.pos.y > land.y + 1.5, "도약: 내린 자리 반지름 2.0, 밖으로 넉백")
	var open := _mv(["leap"])
	var aim := _inp(Vector2.ZERO, true)
	aim.aim_valid = true
	aim.aim = open.lord.pos + Vector2(2.0, 0.0)
	var o0: Vector2 = open.lord.pos
	open.step(aim)
	_wait(open, 14)
	check(absf(open.lord.pos.x - o0.x - 2.0) < 0.01, "도약: 적이 없으면 겨눈 곳(최대 5칸)")
	# 순간 베기: 앞의 가장 가까운 적 뒤 1칸으로 옮겨 그 적을 벤다
	r = _mv(["blink"])
	var mark := _foe(r, Vector2(3.0, 0.0))
	var behind: Vector2 = mark.pos + Vector2(1.0, 0.0)
	r.step(_inp(Vector2.ZERO, true))
	check(r.lord.pos.distance_to(behind) < 0.05 and absf(angle_difference(r.lord.face, PI)) < 0.01 and _hurt_by(mark) > 0.0, "순간 베기: 적 뒤 1칸에 나타나 돌아서 벤다")
	var empty := _mv(["blink"])
	var e0: Vector2 = empty.lord.pos
	var close := _foe(empty, Vector2(-1.0, 0.0) * 0.0 + Vector2(0.0, 0.8))
	empty.step(_inp(Vector2.ZERO, true))
	check(empty.lord.pos == e0, "순간 베기: 앞에 적이 없으면 제자리에서 횡베기")
	check(_hurt_by(close) > 0.0, "순간 베기: 대신 하는 횡베기도 아주 가까운 적은 벤다")
	# 물러나 베기: 벤 뒤 2칸 뒤로(무적)
	r = _mv(["retreat"])
	var rf := _foe(r, Vector2(1.0, 0.0))
	var rx: float = r.lord.pos.x
	r.step(_inp(Vector2.ZERO, true))
	var first_inv: bool = r.lord.invuln > 0.0
	_wait(r, 10)
	check(_hurt_by(rf) > 0.0 and absf(rx - r.lord.pos.x - 2.0) < 0.01 and first_inv, "물러나 베기: 베고 2칸 뒤로 물러난다(%.2f, 무적)" % (rx - r.lord.pos.x))


## 날아가는 것: 검기(꿰뚫고 적마다 한 번), 칼 던지기(갈 때 한 번, 올 때 한 번).
func _test_shots() -> void:
	var r := _mv(["wave"])
	var a := _foe(r, Vector2(3.0, 0.0))
	var b := _foe(r, Vector2(5.0, 0.3))
	var c := _foe(r, Vector2(11.0, 0.0))
	var hits := _count_hits(r)
	var spawned: Array[Projectile] = []
	var ended: Array[Projectile] = []
	r.projectile_spawned.connect(func(p: Projectile) -> void: spawned.append(p))
	r.projectile_ended.connect(func(p: Projectile) -> void: ended.append(p))
	r.step(_inp(Vector2.ZERO, true))
	var first: float = _hurt_by(b)
	var moved: bool = r.projectiles.size() == 1
	_wait(r, 4)
	var travelling: bool = r.projectiles.size() == 1 and r.projectiles[0].pos.x > r.lord.pos.x + 2.0
	_wait(r, 30)
	check(spawned.size() == 1 and moved and travelling and first == 0.0, "검기: 날아가는 초승달이 생겨 앞으로 간다")
	check(int(hits.get(a.id, 0)) == 1 and int(hits.get(b.id, 0)) == 1 and _hurt_by(c) == 0.0, "검기: 꿰뚫고 적마다 한 번, 8칸 너머는 안 닿는다")
	check(ended.size() == 1 and r.projectiles.is_empty() and spawned[0].kind == &"wave", "검기: 다 가면 사라진다(projectile_ended)")
	r = _mv(["boomerang"])
	var g := _foe(r, Vector2(3.0, 0.0))
	hits = _count_hits(r)
	var ret: Array[bool] = [false]
	r.step(_inp(Vector2.ZERO, true))
	for i in 60:
		r.freeze = 0
		r.step(_inp())
		if not r.projectiles.is_empty() and r.projectiles[0].returning:
			ret[0] = true
		if r.projectiles.is_empty():
			break
	check(ret[0] and r.projectiles.is_empty(), "칼 던지기: 6칸 갔다가 돌아와 사라진다")
	check(int(hits.get(g.id, 0)) == 2, "칼 던지기: 갈 때 한 번, 올 때 한 번(%d)" % int(hits.get(g.id, 0)))


## 반격 자세: 맞으면 피해 없이 둘레를 반격한다. 안 맞으면 끝에 약한 베기.
func _test_parry() -> void:
	var r := _mv(["parry"])
	r.debug_god = false
	var wolf := r.spawn_at(&"wolf", r.lord.pos + Vector2(0.5, 0.0))
	wolf.max_hp = 9999.0
	wolf.hp = 9999.0
	wolf.cooldown = 0.2
	var areas: Array[Dictionary] = []
	r.move_area.connect(func(m: StringName, i: Dictionary) -> void:
		if m == &"parry":
			areas.append(i))
	var hp0: float = r.lord.hp
	r.step(_inp(Vector2.ZERO, true))
	for i in 12:
		r.freeze = 0
		r.step(_inp())
	check(r.lord.hp == hp0, "반격 자세: 맞아도 피해가 없다")
	check(areas.size() == 1 and areas[0].shape == &"circle" and is_equal_approx(_hurt_by(wolf), d.lord.damage * 2.5), "반격 자세: 둘레 원으로 × 2.5 반격(%.1f)" % _hurt_by(wolf))
	var q := _mv(["parry"])
	var front := _foe(q, Vector2(1.0, 0.0))
	var qa: Array[Dictionary] = []
	q.move_area.connect(func(_m: StringName, i: Dictionary) -> void: qa.append(i))
	q.step(_inp(Vector2.ZERO, true))
	var during: float = _hurt_by(front)
	_wait(q, 14)
	check(during == 0.0 and qa.size() == 1 and qa[0].shape == &"arc" and is_equal_approx(_hurt_by(front), d.lord.damage * 0.6), "반격 자세: 안 맞으면 끝에 약한 횡베기 × 0.6")


## 속성: 불꽃은 불, 서리는 느림(세 번째면 얼음), 벼락은 둘레로 번개, 피는 출혈과 회복.
func _test_elements() -> void:
	var r := _mv(["sweep", "sweep", "sweep"], &"fire")
	var e := _foe(r, Vector2(1.0, 0.0))
	_swing_once(r)
	check(e.burn > 0.0, "불꽃: 맞은 적에 불이 붙는다")
	var hp1: float = e.hp
	e.stun = 0.0
	_wait(r, 15)
	check(e.hp < hp1, "불꽃: 불이 타며 피해를 준다")
	r = _mv(["sweep", "sweep", "sweep"], &"ice")
	e = _foe(r, Vector2(1.0, 0.0))
	e.stun = 0.0
	_swing_once(r)
	var slowed: bool = e.slow_k > 0.0 and not e.frozen
	_swing_once(r)
	_swing_once(r)
	check(slowed and e.frozen and e.stun > 0.0, "서리: 느려지고, 같은 적이 세 번째 맞으면 얼음")
	r = _mv(["sweep", "sweep", "sweep"], &"bolt")
	var zaps: Array = [0]
	r.effect.connect(func(k: StringName, _a: Vector2, _i: Dictionary) -> void:
		if k == &"zap":
			zaps[0] += 1)
	e = _foe(r, Vector2(1.0, 0.0))
	var o1 := _foe(r, Vector2(3.0, 1.0))
	var o2 := _foe(r, Vector2(3.0, -1.0))
	var o3 := _foe(r, Vector2(7.0, 0.0))
	_swing_once(r)
	check(zaps[0] == 2 and is_equal_approx(_hurt_by(o1), d.lord.damage * 0.5) and _hurt_by(o2) > 0.0 and _hurt_by(o3) == 0.0, "벼락: 3칸 안의 다른 적 둘에 × 0.5 번개")
	r = _mv(["sweep", "sweep", "sweep"], &"blood")
	r.lord.hp = 50.0
	e = _foe(r, Vector2(1.0, 0.0))
	_swing_once(r)
	check(e.bleed_t > 0.0 and is_equal_approx(r.lord.hp, 50.0 + d.lord.damage * d.lord.blood_heal), "피: 출혈이 걸리고 준 피해의 2%를 되찾는다")
	var h1: float = e.hp
	_wait(r, 30)
	check(e.hp < h1, "피: 출혈로 피해가 이어진다")
	var info: Array[StringName] = []
	r.move_started.connect(func(_m: StringName, i: Dictionary) -> void: info.append(i.element))
	_swing_once(r)
	check(info == [&"blood"], "속성은 move_started의 element로 화면에 간다")


## 메아리: 마무리가 0.3초 뒤 같은 자리에서 한 번 더(피해 × echo_damage).
func _test_echo() -> void:
	var r := _mv(["sweep", "spin"], &"", true)
	var e := _foe(r, Vector2(1.0, 0.0))
	var hits := _count_hits(r)
	var echoes: Array[StringName] = []
	r.move_started.connect(func(m: StringName, i: Dictionary) -> void:
		if i.echo:
			echoes.append(m))
	_click(r)
	var after1: float = _hurt_by(e)
	_click(r)
	var after2: float = _hurt_by(e)
	_wait(r, 6)
	var early: float = _hurt_by(e)
	_wait(r, 6)
	var spin: float = after2 - after1
	check(is_equal_approx(spin, d.lord.damage * 1.3) and early == after2, "메아리: 마무리 직후에는 아직")
	check(int(hits.get(e.id, 0)) == 3 and is_equal_approx(_hurt_by(e) - after2, spin * d.lord.echo_damage), "메아리: 0.3초 뒤 × %.1f로 한 번 더(%.1f)" % [d.lord.echo_damage, _hurt_by(e) - after2])
	check(echoes == [&"spin"], "메아리: move_started(echo = true)를 한 번 보낸다")
	var plain := _mv(["sweep", "spin"])
	var pe := _foe(plain, Vector2(1.0, 0.0))
	_click(plain)
	_click(plain)
	var ph: float = _hurt_by(pe)
	_wait(plain, 15)
	check(_hurt_by(pe) == ph, "메아리가 없는 방식은 한 번뿐")
	var link := _mv(["sweep", "spin"], &"", true)
	var le := _foe(link, Vector2(1.0, 0.0))
	_click(link)
	var lh: float = _hurt_by(le)
	_wait(link, 15)
	check(_hurt_by(le) == lh, "메아리는 마무리만 울린다")
	var shot := _mv(["sweep", "wave"], &"", true)
	var se := _foe(shot, Vector2(4.0, 0.0))
	var spawned: Array[int] = [0]
	shot.projectile_spawned.connect(func(_p: Projectile) -> void: spawned[0] += 1)
	hits = _count_hits(shot)
	_click(shot)
	_click(shot)
	_wait(shot, 40)
	check(spawned[0] == 2 and int(hits.get(se.id, 0)) == 2, "메아리: 검기는 0.3초 뒤 한 번 더 날아간다")


## 새 동작도 각인·고유 능력·내구·히트스톱을 거친다.
func _test_moves_with_powers() -> void:
	var r := _mv(["thrust"])
	r.current().ins["날"] = 50.0
	var e := _foe(r, Vector2(1.0, 0.0))
	r.step(_inp(Vector2.ZERO, true))
	check(is_equal_approx(_hurt_by(e), d.lord.damage * 0.9 * 1.5), "각인(날)이 찌르기에도 든다")
	r = _mv(["sweep", "smash"])
	r.current().ins["연격"] = 50.0
	e = _foe(r, Vector2(B_SMASH, 0.0))
	_click(r)
	var h1: float = _hurt_by(e)
	_click(r)
	_wait(r, 5)
	check(is_equal_approx(_hurt_by(e) - h1, d.lord.damage * 1.8 * 1.5), "각인(연격)이 늦게 터지는 마무리(내려찍기)에도 든다")
	r = _mv(["wave"])
	r.current().ins["흡혈"] = 50.0
	r.lord.hp = 50.0
	e = _foe(r, Vector2(3.0, 0.0))
	r.step(_inp(Vector2.ZERO, true))
	_wait(r, 10)
	check(is_equal_approx(r.lord.hp, 50.0 + d.lord.damage * 1.2 * 0.5), "각인(흡혈)이 날아가는 검기에도 든다")
	r = _mv(["flurry"])
	r.current().ins["출혈"] = 9.0
	e = _foe(r, Vector2(1.0, 0.0))
	r.step(_inp(Vector2.ZERO, true))
	check(e.bleed_t > 0.0, "각인(출혈)이 연속 찌르기에도 든다")
	r = _mv(["flurry"])
	var s := r.current()
	var dur: float = s.durability
	e = _foe(r, Vector2(1.0, 0.0))
	r.step(_inp(Vector2.ZERO, true))
	_wait(r, 12)
	check(s.durability == dur - 1.0, "내구는 동작마다 한 번 닳는다(네 번 찔러도 1)")
	r = _mv(["sweep", "spin"])
	e = _foe(r, Vector2(1.0, 0.0))
	r.step(_inp(Vector2.ZERO, true))
	var small: int = r.freeze
	r.freeze = 0
	r.lord.cooldown = 0.0
	r.step(_inp(Vector2.ZERO, true))
	check(small == roundi(d.lord.hitstop / r.dt) and r.freeze == roundi(d.lord.hitstop_big / r.dt), "히트스톱: 이음은 짧게, 마무리는 길게")
	r = _named("메아리 계곡")
	r.current().pattern = _pat(["iaido"])
	e = _foe(r, Vector2(1.0, 0.0))
	r.step(_inp(Vector2.ZERO, true))
	_wait(r, 10)
	var after_iaido: float = _hurt_by(e)
	_wait(r, 20)
	check(after_iaido > 0.0 and _hurt_by(e) > after_iaido, "고유 능력(메아리 계곡)이 늦게 터지는 발도 뒤에도 울린다")


const B_SMASH: float = 1.55 * 0.8 + 0.5


## 같은 시드·같은 입력이면 같은 결과: 여러 방식(갈고리·날아가는 것·속성·메아리 포함)으로 싸우는 밤.
func _test_replay_moves() -> void:
	var picks: Array[int] = [5, 40, 80, 88, 110, 115, 130, 135, 145, 146, 148]
	var hashes: Array[int] = []
	var kills: Array[int] = []
	for run_i in 2:
		var r := Rules.new(d, 77)
		r.debug_god = true
		r.start_night()
		var rec := RandomNumberGenerator.new()
		rec.seed = 9
		for k in 1800:
			if k % 160 == 0:
				var p: int = picks[(k / 160) % picks.size()]
				var sd: SwordData = null
				for s in d.swords:
					if s.attack == p:
						sd = s
						break
				r.give(sd, (k / 160) % 2)
				r.active = (k / 160) % 2
			var inp := _inp(Vector2(rec.randf_range(-1, 1), rec.randf_range(-1, 1)), rec.randf() < 0.6, rec.randf() < 0.03)
			inp.aim_valid = rec.randf() < 0.8
			inp.aim = Vector2(rec.randf_range(5, 29), rec.randf_range(3, 19))
			inp.hook = rec.randf() < 0.05
			r.step(inp)
		hashes.append(r.state_hash())
		kills.append(r.kills)
	check(hashes[0] == hashes[1] and kills[0] == kills[1], "같은 시드·같은 입력이면 여러 방식으로 싸워도 똑같이 돈다")
	check(kills[0] > 10, "다시 돌린 밤에서 실제로 싸웠다(처치 %d)" % kills[0])
