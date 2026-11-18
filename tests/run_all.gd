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
	_test_tokens_cap()
	_test_tokens_cost()
	_test_tokens_boss()
	_test_tokens_cooldown()
	_test_tokens_order()
	_test_tokens_release()
	_test_tokens_ring()
	_test_tokens_replay()
	_test_foes_data()
	_test_foes_spawn()
	_test_archer()
	_test_arrow_cut()
	_test_shield()
	_test_charger()
	_test_bomber()
	_test_caller()
	_test_foes_tokens()
	_test_foes_replay()
	_test_night_choice()
	_test_defend()
	_test_hunt()
	_test_siege()
	_test_fog()
	_test_embers()
	_test_graves()
	_test_goal_rewards()
	_test_goals_replay()
	_test_path_cards()
	_test_path_bias()
	_test_path_rewards()
	_test_events_place()
	_test_event_smith()
	_test_event_cursed()
	_test_event_pilgrim()
	_test_event_seer()
	_test_path_replay()
	_test_omens()
	_test_omen_luck()
	_test_pull_timing()
	_test_pull_timing_miss()
	_test_pull_timing_replay()
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
	check(d.enemies.size() == 9 and (d.enemies[&"boss"] as EnemyData).boss and (d.enemies[&"wraith"] as EnemyData).wraith, "적 9종(11단계 새 적 5종 포함)")
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
	check(r.zone == 1 and r.path_open and days.is_empty() and r.hilts.is_empty(), "새벽이 오면 갈림길: 길을 고르기 전에는 낮이 시작되지 않는다")
	r.choose_path(0)
	check(r.zone == 1 and r.phase == Rules.Phase.DAY and days == [1], "길을 고르면 다음 구역의 낮")
	var path_heal: float = d.run.reward_heal if r.path_reward == &"heal" else 0.0
	check(is_equal_approx(r.lord.hp, minf(r.max_hp(), 50.0 + d.run.heal_per_dawn + path_heal)) and r.enemies.is_empty(), "날이 밝으면 체력 +%d, 적은 사라진다" % d.run.heal_per_dawn)
	check(r.hilts.size() == d.run.hilts_per_day, "새 낮에 검이 다시 꽂힌다")
	check(r.lord.pos == Grid.middle(), "새 낮에는 한가운데에서 시작")


func _test_lord_dies() -> void:
	var r := _night_rules()
	var ended: Array[bool] = []
	r.run_ended.connect(func(w: bool) -> void: ended.append(w))
	r.lord.hp = 5.0
	var e := r.spawn_at(&"wolf", r.lord.pos + Vector2(0.5, 0.0))
	e.cooldown = 0.0
	# 두 번 물어야 한다: 표를 받고 0.25초, 돌려놓은 표가 0.5초 식은 뒤 다시 받고 0.25초
	for t in 60:
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
	var g := _mv(["parry"])
	var gw := _foe(g, Vector2(0.5, 0.0), &"wolf")
	gw.stun = 0.0
	gw.cooldown = 0.2
	g.step(_inp(Vector2.ZERO, true))
	_wait(g, 12)
	check(_hurt_by(gw) > 0.0, "반격 자세: 관리용 무적이어도 반격한다")
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


# ---------------------------------------------------------------- 공격 표(docs/attack_tokens.md)

## 표 수만 바꾼 표(구역마다 같은 수). 다른 테스트의 d는 건드리지 않는다.
func _tok_data(n: int) -> GameData:
	var g := GameData.load_default()
	g.run = d.run.duplicate() as RunData
	g.run.attack_tokens = PackedInt32Array([n])
	return g


## 표를 시험할 밤: 적이 저절로 나오지 않고, 영주는 다치지 않는다(맞은 것은 간격이 다시 차는 것으로 센다).
func _tok_rules(g: GameData = null) -> Rules:
	var r := Rules.new(g if g else d, 1)
	r.start_night()
	r.enemies.clear()
	r.debug_god = true
	r._spawn_t = 1e9
	r.elite_out = true
	return r


## 영주 둘레 각 a(라디안), 거리 dist에 선 적.
func _at(r: Rules, kind: StringName, a: float, dist: float) -> Enemy:
	return r.spawn_at(kind, r.lord.pos + Vector2.from_angle(a) * dist)


## 사거리 안(바로 때릴 수 있는 자리)에 선 적.
func _close(r: Rules, kind: StringName, a: float) -> Enemy:
	var e := _at(r, kind, a, 0.0)
	e.pos = r.lord.pos + Vector2.from_angle(a) * (e.radius + d.run.enemy_reach - 0.05)
	e.prev_pos = e.pos
	return e


## 기다림 거리 둘레에 선 적.
func _ringed(r: Rules, kind: StringName, a: float) -> Enemy:
	var e := _at(r, kind, a, 0.0)
	e.pos = r.lord.pos + Vector2.from_angle(a) * r.tokens.wait_dist(e)
	e.prev_pos = e.pos
	return e


## n틱 돌리며 영주를 때린 것을 적는다: [틱, 적, 때리기 직전에 든 표]. 간격이 다시 차면 때린 것.
func _run_log(r: Rules, n: int, log: Array, each: Callable = Callable()) -> void:
	for t in n:
		var before := {}
		for e in r.enemies:
			before[e] = [e.cooldown, e.token]
		r.freeze = 0
		r.step(_inp())
		for e in r.enemies:
			if before.has(e) and e.cooldown > float(before[e][0]) + 0.05:
				log.append([r.tick, e, int(before[e][1])])
		if each.is_valid():
			each.call()


## 표 수만큼만 동시에 때린다. 표 없이 때리는 적이 없다. 1초에 때리는 수가 표 수로 묶인다.
func _test_tokens_cap() -> void:
	var r := _tok_rules()
	check(r.tokens.total() == 4 and d.run.attack_tokens.size() == 10 and d.run.attack_tokens[9] == 10, "표: 구역 10개, 첫 구역 4장, 마지막 10장")
	for i in 12:
		_at(r, &"wolf", TAU * i / 12.0, 5.0)
	var log: Array = []
	var worst: Array[int] = [0, 0]
	_run_log(r, 300, log, func() -> void:
		var holders: int = 0
		for e in r.enemies:
			if e.token > 0:
				holders += 1
		worst[0] = maxi(worst[0], r.tokens.held() + r.tokens.cooling_count())
		worst[1] = maxi(worst[1], holders))
	var no_token: int = 0
	var per_sec := {}
	for a in log:
		if int(a[2]) <= 0:
			no_token += 1
		per_sec[int(a[0]) / 30] = int(per_sec.get(int(a[0]) / 30, 0)) + 1
	var most: int = 0
	for k in per_sec:
		most = maxi(most, int(per_sec[k]))
	check(worst[0] <= 4 and worst[1] <= 4, "표: 늑대 12마리가 몰려도 든 표 + 식는 표는 4장을 넘지 않는다(가장 많을 때 %d, 표 든 늑대 %d)" % worst)
	check(no_token == 0 and log.size() > 8, "표: 표를 든 늑대만 때린다(때림 %d, 표 없이 %d)" % [log.size(), no_token])
	# 표 한 장은 받고 0.25초 뒤에 때리고, 돌려놓으면 0.5초 식는다: 1초에 4 × 1/0.75 ≈ 5번을 넘지 못한다(표가 없으면 늑대 12마리 × 1/0.7 ≈ 17번)
	var cap: int = ceili(4.0 / (d.run.token_warn + d.run.token_cooldown))
	check(most <= cap, "표: 1초에 때리는 수가 표로 묶인다(가장 많을 때 %d번, 한도 %d)" % [most, cap])
	var free := _tok_rules(_tok_data(0))
	for i in 12:
		_at(free, &"wolf", TAU * i / 12.0, 5.0)
	var flog: Array = []
	_run_log(free, 300, flog)
	check(flog.size() > log.size() * 2, "표: 표 수가 0이면 꺼진다(모두 덤빈다, %d번 대 %d번)" % [flog.size(), log.size()])


## 거인은 표 3장, 정예는 +1. 맨 앞의 큰 적이 받을 만큼 표가 없으면 뒤의 작은 적도 기다린다.
func _test_tokens_cost() -> void:
	var r := _tok_rules()
	var g := _ringed(r, &"giant", 0.0)
	var a := _ringed(r, &"wraith", 2.0)
	var b := _ringed(r, &"wraith", 4.0)
	r.step(_inp())
	check(g.token == 3 and a.token == 1 and b.token == 0 and r.tokens.free_count() == 0, "표: 거인은 3장을 가져간다(거인 %d, 망령 %d·%d)" % [g.token, a.token, b.token])
	var eg := r.spawn_at(&"giant", Vector2(1, 1))
	eg.elite = true
	var ew := r.spawn_at(&"wolf", Vector2(1, 1))
	ew.elite = true
	var z := _tok_rules()
	z.zone = 5
	check(r.tokens.cost(eg) == 4 and r.tokens.cost(ew) == 2 and z.tokens.cost(eg) == 4, "표: 정예는 한 장 더(거인 4, 늑대 2)")
	check(_tok_rules(_tok_data(2)).tokens.cost(eg) == 2, "표: 표 값은 그 밤의 표 수를 넘지 않는다(언젠가는 받는다)")
	# 망령 둘이 먼저 2장을 들고, 거인이 와서 기다리고, 늦게 온 망령은 남은 2장이 있어도 거인 뒤에 선다
	var q := _tok_rules()
	var h1 := _close(q, &"wraith", 0.0)
	var h2 := _close(q, &"wraith", PI)
	q.step(_inp())
	h1.cooldown = 99.0
	h2.cooldown = 99.0
	var big := _ringed(q, &"giant", PI / 2.0)
	q.step(_inp())
	var late := _ringed(q, &"wraith", -PI / 2.0)
	q.step(_inp())
	check(h1.token == 1 and h2.token == 1 and big.token == 0 and late.token == 0 and q.tokens.free_count() == 2, "표: 먼저 기다린 거인이 받을 만큼 표가 없으면 늦게 온 망령도 기다린다(남은 표 %d)" % q.tokens.free_count())
	q.hurt(h1, 99999.0, Vector2.ZERO, false)
	_wait(q, 16)
	check(big.token == 3 and late.token == 0, "표: 표가 식어 3장이 되면 거인이 받는다")


## 언덕지기는 표 없이 때리고 남의 표도 막지 않는다.
func _test_tokens_boss() -> void:
	var r := _tok_rules()
	var full: Array[Enemy] = []
	for i in r.tokens.total():
		full.append(_ringed(r, &"wraith", -0.9 + 0.6 * i))
	r.step(_inp())
	for e in full:
		e.cooldown = 99.0
	var boss := _close(r, &"boss", PI)
	boss.cooldown = 0.0
	var log: Array = []
	_run_log(r, 10, log)
	var boss_hit: bool = log.any(func(x: Array) -> bool: return x[1] == boss)
	check(r.tokens.cost(boss) == 0 and boss.token == 0 and boss_hit, "표: 언덕지기는 표 없이 덤빈다")
	check(r.tokens.held() == r.tokens.total() and full.all(func(e: Enemy) -> bool: return e.token == 1), "표: 언덕지기는 남의 표를 가져가지 않는다")


## 때리면(막혔어도) 표를 돌려놓고, 돌려놓은 표는 0.5초 식은 뒤에 다음 적이 받는다. 받고 0.25초 동안은 눈이 번쩍이고 때리지 않는다.
func _test_tokens_cooldown() -> void:
	var r := _tok_rules(_tok_data(1))
	var a := _close(r, &"wraith", 0.0)
	a.cooldown = 0.0
	var b := _ringed(r, &"wraith", PI)
	r.step(_inp())
	check(a.token == 1 and b.token == 0 and a.attack_soon and not b.attack_soon, "표: 받자마자 곧 때린다고 알린다(attack_soon)")
	var t0: int = r.tick
	var log: Array = []
	var gone: Array[int] = [-1, -1]
	_run_log(r, 60, log, func() -> void:
		if gone[0] < 0 and a.token == 0:
			gone[0] = r.tick
		if gone[1] < 0 and b.token == 1:
			gone[1] = r.tick)
	var warn: int = roundi(d.run.token_warn * d.run.tick_rate)
	check(log.size() >= 1 and log[0][1] == a and int(log[0][0]) - t0 >= warn - 1, "표: 받고 %d틱 뒤에 때린다(%d틱)" % [warn, int(log[0][0]) - t0 if log.size() > 0 else -1])
	check(gone[0] == int(log[0][0]) if log.size() > 0 else false, "표: 때린 틱에 표를 돌려놓는다")
	var cool: int = roundi(d.run.token_cooldown * d.run.tick_rate)
	var gap: int = gone[1] - gone[0]
	check(gap >= cool - 1 and gap <= cool + 1, "표: 돌려놓은 표는 0.5초(%d틱) 뒤에 다음 적이 받는다(%d틱)" % [cool, gap])
	check(a.token == 0, "표: 막 때린 적보다 오래 기다린 적이 먼저 받는다")
	# 반격 자세에 막혀도 때린 것으로 친다
	var p := _mv(["parry"])
	p.debug_god = false
	p.tokens.cooling.clear()
	var wolf := _close(p, &"wolf", 0.0)
	wolf.max_hp = 9999.0
	wolf.hp = 9999.0
	wolf.cooldown = 0.0
	p.step(_inp())
	var hp0: float = p.lord.hp
	var had: int = wolf.token
	p.step(_inp(Vector2.ZERO, true))
	_wait(p, 12)
	# 늑대 하나뿐이라 식는 표 한 장은 늑대가 돌려놓은 것이다(남은 표로 다시 받았을 수는 있다)
	check(had == 1 and p.lord.hp == hp0 and _hurt_by(wolf) > 0.0 and p.tokens.cooling_count() == 1, "표: 반격 자세에 막혀도 때린 것이라 표를 돌려놓는다")
	# 돌진 무적에 막혀도
	var q := _tok_rules(_tok_data(1))
	var w := _close(q, &"wraith", 0.0)
	w.cooldown = 0.0
	q.step(_inp())
	q.lord.invuln = 5.0
	_wait(q, 12)
	check(w.token == 0 and q.tokens.cooling_count() == 1, "표: 무적에 막혀도 한 번 때리면 돌려놓는다")


## 가장 오래 기다린 적이 먼저 받는다(목록 순서가 앞이어도 늦게 온 적은 뒤).
func _test_tokens_order() -> void:
	var r := _tok_rules(_tok_data(1))
	var h := _close(r, &"wraith", 0.0)
	var late := _at(r, &"wraith", PI / 2.0, 0.0)
	late.pos = r.lord.pos + Vector2(0.0, r.tokens.wait_dist(late) + 1.2)
	late.prev_pos = late.pos
	var early := _ringed(r, &"wraith", PI)
	r.step(_inp())
	h.cooldown = 99.0
	_wait(r, 40)
	check(h.token == 1 and early.waiting and late.waiting and early.wait_t > late.wait_t, "표: 둘 다 둘레에서 기다린다(먼저 온 쪽 %.2f초, 늦게 온 쪽 %.2f초)" % [early.wait_t, late.wait_t])
	r.hurt(h, 99999.0, Vector2.ZERO, false)
	_wait(r, 16)
	check(early.token == 1 and late.token == 0, "표: 가장 오래 기다린 적이 먼저 받는다(목록 순서는 늦게 온 쪽이 앞)")
	r.hurt(early, 99999.0, Vector2.ZERO, false)
	_wait(r, 16)
	check(late.token == 1, "표: 그다음 적이 받는다")


## 표를 내려놓는 경우: 2.5초 못 때림(식는 시간 없이), 기절, 얼음, 망각, 멀리 밀려남, 죽음.
func _test_tokens_release() -> void:
	var r := _tok_rules(_tok_data(1))
	var h := _close(r, &"wraith", 0.0)
	var w := _ringed(r, &"wraith", PI)
	r.step(_inp())
	h.cooldown = 99.0
	var t0: int = r.tick
	var dropped: Array[int] = [-1, -1]
	for i in 100:
		_wait(r, 1)
		if dropped[0] < 0 and h.token == 0:
			dropped[0] = r.tick - t0
		if dropped[1] < 0 and w.token == 1:
			dropped[1] = r.tick - t0
	var hold: int = roundi(d.run.token_hold_max * d.run.tick_rate)
	check(absi(dropped[0] - hold) <= 1, "표: %.1f초(%d틱) 못 때리면 내려놓는다(%d틱)" % [d.run.token_hold_max, hold, dropped[0]])
	check(dropped[1] == dropped[0], "표: 오래 못 때려 내려놓은 표는 식지 않고 바로 다음 적에게 간다")
	var cases: Array = [
		["기절", func(e: Enemy, _rr: Rules) -> void: e.stun = 1.0],
		["얼음", func(e: Enemy, _rr: Rules) -> void:
			e.frozen = true
			e.stun = 1.0],
		["망각", func(e: Enemy, _rr: Rules) -> void: e.confused = 2.0],
		["멀리 밀려남", func(e: Enemy, rr: Rules) -> void: e.pos = rr.lord.pos + (e.pos - rr.lord.pos).normalized() * rr.tokens.wait_dist(e) * 2.5],
	]
	for c in cases:
		r = _tok_rules()
		var e := _close(r, &"wraith", 0.0)
		e.cooldown = 99.0
		_close(r, &"wraith", PI).cooldown = 99.0
		r.step(_inp())
		var had: int = e.token
		(c[1] as Callable).call(e, r)
		r.step(_inp())
		var free_now: int = r.tokens.free_count()
		check(had == 1 and e.token == 0 and r.tokens.cooling_count() == 1 and free_now == 2, "표: %s이면 내려놓는다(식는 표 %d)" % [c[0], r.tokens.cooling_count()])
		_wait(r, 20)
		if c[0] != "멀리 밀려남":
			check(e.token == 0, "표: %s 동안은 표를 청하지 않는다" % c[0])
	r = _tok_rules()
	var k := _close(r, &"wraith", 0.0)
	r.step(_inp())
	r.hurt(k, 99999.0, Vector2.ZERO, false)
	check(k.dead and k.token == 0 and r.tokens.cooling_count() == 1, "표: 죽으면 내려놓는다")
	r.skip_night()
	r.choose_path(0)
	check(r.phase == Rules.Phase.DAY and not r.tokens.cooling.is_empty(), "표: (낮이 되어도 식는 표가 남아 있다가)")
	r.start_night()
	check(r.tokens.cooling.is_empty(), "표: 밤이 시작되면 식는 표가 없다")


## 표 없는 적은 기다림 거리 안으로 들어오지 않고, 영주를 보며 둘레를 돈다(짝수 번호 시계, 홀수 반시계).
func _test_tokens_ring() -> void:
	var r := _tok_rules(_tok_data(1))
	for i in 10:
		_at(r, &"wraith" if i % 3 else &"wolf", TAU * i / 10.0 + 0.1, 6.0)
	var ever := {}
	var deep: Array[float] = [99.0]
	var sum: Array[float] = [0.0, 0.0]
	var waited := {}
	var prev := {}
	# 덜컥거림: 기다리는 동안 한 틱의 걸음이 앞 틱과 얼마나 다른지(합, 수)
	var jolts: Array[float] = [0.0, 0.0]
	_run_log(r, 240, [], func() -> void:
		for e in r.enemies:
			if e.token > 0:
				ever[e] = true
			var to: Vector2 = r.lord.pos - e.pos
			if not ever.has(e):
				deep[0] = minf(deep[0], to.length() - r.tokens.wait_dist(e))
			if e.waiting and e.token == 0 and not ever.has(e):
				waited[e] = true
				sum[0] += e.face.dot(to.normalized())
				sum[1] += 1.0
			var v: Vector2 = e.pos - e.prev_pos
			if prev.has(e) and e.waiting and e.token == 0 and r.tick > 120:
				jolts[0] += (v - prev[e]).length()
				jolts[1] += 1.0
			prev[e] = v)
	var jolt: float = jolts[0] / maxf(1.0, jolts[1])
	var worst: Array[float] = deep
	check(worst[0] > -0.05 and waited.size() >= 5, "표: 표 없는 적은 기다림 거리 안으로 들어오지 않는다(가장 깊이 %.3f칸, 기다린 적 %d)" % [worst[0], waited.size()])
	check(sum[1] > 0.0 and sum[0] / sum[1] > 0.99, "표: 기다리는 적은 영주 쪽을 본다(%.3f)" % (sum[0] / maxf(1.0, sum[1])))
	var step_len: float = d.enemies[&"wraith"].speed * d.run.token_strafe / d.run.tick_rate
	check(jolt < step_len * 0.25, "표: 기다리는 적이 덜컥거리지 않는다(틱마다 걸음 차이 %.4f칸, 옆걸음 %.4f칸)" % [jolt, step_len])
	# 돌 방향: 짝수 번호는 각이 커지는 쪽(위에서 보면 시계), 홀수는 반대. 너무 가까우면 물러난다.
	var q := _tok_rules(_tok_data(1))
	var h := _close(q, &"wraith", PI / 2.0)
	q.step(_inp())
	h.cooldown = 99.0
	var a := _ringed(q, &"wraith", 0.0)
	var b := _ringed(q, &"wraith", PI)
	var even: Enemy = a if a.id % 2 == 0 else b
	var odd: Enemy = b if even == a else a
	var ae: float = (even.pos - q.lord.pos).angle()
	var ao: float = (odd.pos - q.lord.pos).angle()
	_wait(q, 20)
	var de: float = angle_difference(ae, (even.pos - q.lord.pos).angle())
	var dd: float = angle_difference(ao, (odd.pos - q.lord.pos).angle())
	check(de > 0.05 and dd < -0.05, "표: 짝수 번호는 시계, 홀수는 반시계로 돈다(%.2f, %.2f)" % [de, dd])
	check(absf(even.pos.distance_to(q.lord.pos) - q.tokens.wait_dist(even)) < 0.05, "표: 돌면서 기다림 거리를 지킨다")
	var c := _close(q, &"wraith", -PI / 2.0)
	_wait(q, 45)
	check(c.token == 0 and c.pos.distance_to(q.lord.pos) > q.tokens.wait_dist(c) - 0.1, "표: 너무 가까운 표 없는 적은 기다림 거리까지 물러난다(%.2f칸)" % c.pos.distance_to(q.lord.pos))


## 같은 시드·같은 입력이면 표 나누기도 같다(랜덤을 쓰지 않는다).
func _test_tokens_replay() -> void:
	var logs: Array[String] = []
	var hashes: Array[int] = []
	var waits: Array[int] = []
	for run_i in 2:
		var r := Rules.new(d, 31)
		r.zone = 3
		r.debug_god = true
		r.start_night()
		var rec := RandomNumberGenerator.new()
		rec.seed = 4
		var text: String = ""
		var waited: int = 0
		for k in 1200:
			var inp := _inp(Vector2(rec.randf_range(-1, 1), rec.randf_range(-1, 1)) * 0.3, rec.randf() < 0.3, rec.randf() < 0.02)
			r.step(inp)
			for e in r.enemies:
				if e.waiting and e.token == 0:
					waited += 1
			if k % 30 == 0:
				for e in r.enemies:
					if e.token > 0:
						text += "%d:%d:%d " % [r.tick, e.id, e.token]
		logs.append(text)
		hashes.append(r.state_hash())
		waits.append(waited)
	check(hashes[0] == hashes[1] and logs[0] == logs[1] and logs[0].length() > 0, "표: 같은 시드·같은 입력이면 누가 언제 표를 받는지도 같다")
	check(waits[0] > 100, "표: 다시 돌린 밤에서 실제로 표를 기다린 적이 있다(%d)" % waits[0])


# ---------------------------------------------------------------- 11단계 새 적 5종(docs/content.md, Foes)

## 적의 행동을 적는다: [틱, 적, act, info, 그때 든 표].
func _acts(r: Rules) -> Array:
	var log: Array = []
	r.enemy_act.connect(func(e: Enemy, act: StringName, info: Dictionary) -> void: log.append([r.tick, e, act, info, e.token]))
	return log


## 그 행동의 첫 기록(없으면 빈 배열).
func _first(log: Array, act: StringName, e: Enemy = null) -> Array:
	for x in log:
		if x[2] == act and (e == null or x[1] == e):
			return x
	return []


func _count(log: Array, act: StringName) -> int:
	var n: int = 0
	for x in log:
		if x[2] == act:
			n += 1
	return n


## 그 행동이 적힐 때까지(최대 n틱) 돌린다.
func _until(r: Rules, log: Array, act: StringName, n: int, e: Enemy = null) -> Array:
	for i in n:
		var got := _first(log, act, e)
		if not got.is_empty():
			return got
		r.freeze = 0
		r.step(_inp())
	return _first(log, act, e)


## 손으로 놓은 활잡이 화살.
func _arrow(r: Rules, at: Vector2, dir: Vector2) -> Projectile:
	var A: EnemyData = d.enemies[&"archer"]
	var p := Projectile.new()
	p.kind = &"arrow"
	p.pos = at
	p.prev_pos = at
	p.dir = dir
	p.speed = A.shot_speed
	p.distance = A.shot_range
	p.width = A.shot_radius * 2.0
	p.max_time = 3.0
	p.damage = A.damage
	r.enemy_projectiles.append(p)
	return p


func _test_foes_data() -> void:
	var want := {&"archer": [18, 7, 1.4, 0.28, 1], &"shield": [60, 8, 1.2, 0.34, 1], &"charger": [70, 18, 1.5, 0.4, 2], &"bomber": [10, 22, 2.6, 0.24, 1], &"caller": [40, 0, 1.3, 0.3, 0]}
	var ok: bool = true
	for k in want:
		var e: EnemyData = d.enemies.get(k)
		var w: Array = want[k]
		ok = ok and e != null and e.hp == w[0] and e.damage == w[1] and is_equal_approx(e.speed, w[2]) and is_equal_approx(e.radius, w[3]) and e.token_cost == w[4]
	check(ok, "새 적 5종: 체력·피해·빠르기·크기·표 값이 표와 같다")
	var A: EnemyData = d.enemies[&"archer"]
	var S: EnemyData = d.enemies[&"shield"]
	var C: EnemyData = d.enemies[&"charger"]
	var B: EnemyData = d.enemies[&"bomber"]
	var K: EnemyData = d.enemies[&"caller"]
	check(A.keep_near == 5.0 and A.keep_far == 8.0 and A.aim_time == 0.6 and A.shot_speed == 11.0 and A.shot_range == 12.0, "활잡이: 5~8칸, 0.6초 겨눔, 11칸/초, 12칸")
	check(S.guard_arc == 120.0 and S.guard_mult == 0.25 and S.guard_knock == 0.2 and S.guard_stun == 1.2 and S.guard_down == 2.0, "방패병: 앞 120°, ×0.25, 넉백 ×0.2, 기절 1.2초, 2초")
	check(C.charge_min == 3.0 and C.charge_max == 8.0 and C.wind_time == 0.7 and C.charge_speed == 13.0 and C.charge_length == 9.0 and C.charge_knock == 6.0 and C.stagger_time == 1.0 and C.stagger_mult == 1.5, "돌격병: 3~8칸, 0.7초, 13칸/초, 9칸, 넉백 6, 1초 ×1.5")
	check(B.fuse_range == 1.2 and B.fuse_time == 0.9 and B.blast_radius == 2.2, "자폭병: 1.2칸, 0.9초, 반지름 2.2칸")
	check(K.keep_near == 10.0 and K.summon_interval == 7.0 and K.summon_time == 1.0 and K.summon_count == 3 and K.summon_kind == &"wraith", "부르는 자: 10칸, 7초마다 1초, 망령 3마리")
	# 처음 나오는 구역(1부터 세면 2, 3, 4, 5, 6)에 5~8%, 그전에는 0, 구역이 오를수록 늘어난다
	var first := {&"archer": 1, &"shield": 2, &"charger": 3, &"bomber": 4, &"caller": 5}
	var mix_ok: bool = true
	for k in first:
		var z: int = first[k]
		var c0: float = d.run.extra_chance(k, z - 1)
		var c1: float = d.run.extra_chance(k, z)
		var c9: float = d.run.extra_chance(k, 9)
		mix_ok = mix_ok and c0 == 0.0 and c1 >= 0.05 - 0.0001 and c1 <= 0.08 + 0.0001 and c9 >= c1
	check(mix_ok and d.run.caller_max == 2, "나오는 비율: 처음 나오는 구역에 5~8%, 오를수록 늘어난다. 부르는 자는 한 밤에 2마리까지")


func _test_foes_spawn() -> void:
	var r := Rules.new(d, 3)
	check(r._extra_total() == 0.0 and r._pick_extra(0.0) == &"", "1구역에는 새 적이 없다")
	r.zone = 5
	check(r._pick_extra(0.0) == &"archer" and r._pick_extra(0.999) == &"" and is_equal_approx(r._extra_total(), 0.09 + 0.08 + 0.06 + 0.07 + 0.05), "6구역: 다섯 종 모두 나올 수 있다(합 %.2f)" % r._extra_total())
	# 2구역의 한 밤: 활잡이만 새로 나온다
	var kinds := {}
	var z1 := Rules.new(d, 8)
	z1.zone = 1
	z1.debug_god = true
	z1.enemy_spawned.connect(func(e: Enemy) -> void: kinds[e.data.id] = int(kinds.get(e.data.id, 0)) + 1)
	z1.start_night()
	for t in 1500:
		z1.step()
	check(int(kinds.get(&"archer", 0)) > 0 and not kinds.has(&"shield") and not kinds.has(&"caller") and int(kinds.get(&"wraith", 0)) > int(kinds.get(&"archer", 0)), "2구역의 밤: 활잡이가 조금 나오고 방패병·부르는 자는 없다 %s" % [kinds])
	# 부르는 자만 나오게 해도 한 밤에 2마리까지(넘으면 망령)
	var g := GameData.load_default()
	g.run = d.run.duplicate() as RunData
	g.run.caller_chance = PackedFloat32Array([1.0])
	var ck := {}
	var rc := Rules.new(g, 9)
	rc.debug_god = true
	rc.enemy_spawned.connect(func(e: Enemy) -> void: ck[e.data.id] = int(ck.get(e.data.id, 0)) + 1)
	rc.start_night()
	for t in 600:
		rc.step()
	check(int(ck.get(&"caller", 0)) == 2 and rc.callers_out == 2 and int(ck.get(&"wraith", 0)) > 5, "부르는 자는 한 밤에 2마리까지 %s" % [ck])
	# 새 적도 정예가 된다(부르는 자는 빼고)
	var eg := GameData.load_default()
	eg.run = d.run.duplicate() as RunData
	eg.run.bomber_chance = PackedFloat32Array([1.0])
	var re := Rules.new(eg, 4)
	re.start_night()
	var el := re._spawn_elite()
	check(el.elite and el.data.id == &"bomber" and is_equal_approx(el.max_hp, el.data.hp * d.run.elite_hp), "정예는 새 적에게도 붙는다(자폭병 정예)")


func _test_archer() -> void:
	var A: EnemyData = d.enemies[&"archer"]
	# 거리 두기: 가까우면 물러나고 멀면 다가온다(쏘지 않게 간격을 길게)
	var r := _tok_rules()
	var near := _at(r, &"archer", 0.0, 3.0)
	var far := _at(r, &"archer", PI, 14.0)
	near.cooldown = 99.0
	far.cooldown = 99.0
	for t in 200:
		r.freeze = 0
		r.step(_inp())
	var dn: float = near.pos.distance_to(r.lord.pos)
	var df: float = far.pos.distance_to(r.lord.pos)
	check(dn >= A.keep_near - 0.05 and df <= A.keep_far + 0.05 and df >= A.keep_near - 0.05, "활잡이: 가까우면 물러나고 멀면 다가와 5~8칸에 선다(%.2f, %.2f)" % [dn, df])
	# 겨누고 쏜다: 0.6초 겨눔 → 화살 → 서 있는 영주가 맞는다
	r = _tok_rules()
	r.debug_god = false
	var log := _acts(r)
	var spawned: Array[Projectile] = []
	var ended: Array = []
	r.enemy_projectile_spawned.connect(func(p: Projectile) -> void: spawned.append(p))
	r.enemy_projectile_ended.connect(func(p: Projectile, hit: bool) -> void: ended.append([p, hit, r.tick]))
	var a := _at(r, &"archer", 0.0, 7.0)
	a.cooldown = 0.0
	var hp0: float = r.lord.hp
	var aim := _until(r, log, &"aim", 60)
	var shoot := _until(r, log, &"shoot", 40)
	var info: Dictionary = aim[3] if not aim.is_empty() else {}
	check(not aim.is_empty() and int(aim[4]) > 0 and info.has("from") and info.has("dir") and is_equal_approx(float(info.get("time", 0.0)), A.aim_time), "활잡이: 표를 받으면 겨눈다(aim: from, dir, time %.2f)" % float(info.get("time", 0.0)))
	var gap: int = int(shoot[0]) - int(aim[0]) if not shoot.is_empty() else -1
	check(absi(gap - roundi(A.aim_time * d.run.tick_rate)) <= 1 and int(shoot[4]) == 0 and spawned.size() == 1 and spawned[0].kind == &"arrow", "활잡이: 0.6초 뒤 쏘고 표를 돌려놓는다(%d틱)" % gap)
	var moved: bool = a.prev_pos.distance_to(a.pos) < 0.001
	for t in 40:
		if not ended.is_empty():
			break
		r.freeze = 0
		r.step(_inp())
	check(moved and ended.size() == 1 and bool(ended[0][1]) and is_equal_approx(hp0 - r.lord.hp, a.damage) and r.enemy_projectiles.is_empty(), "활잡이: 화살이 날아가 서 있는 영주를 맞힌다(-%.1f)" % (hp0 - r.lord.hp))
	var fly: int = int(ended[0][2]) - int(shoot[0]) if not ended.is_empty() else 0
	var expect: float = (7.0 - a.radius - 0.1) / A.shot_speed * d.run.tick_rate
	check(absf(fly - expect) <= 2.0, "활잡이: 화살은 11칸/초(%d틱, 어림 %.1f)" % [fly, expect])
	# 돌진 중에는 지나간다
	var q := _tok_rules()
	q.debug_god = false
	var p := _arrow(q, q.lord.pos + Vector2(2.0, 0.0), Vector2(-1.0, 0.0))
	q.lord.dash = 1.0
	var hq: float = q.lord.hp
	for t in 12:
		q.freeze = 0
		q.step(_inp())
	check(q.lord.hp == hq and p.pos.x < q.lord.pos.x - 1.0 and not p.cut, "화살: 돌진 중에는 맞지 않고 지나간다")
	# 사거리 끝에서 사라진다
	var gone: Array = []
	q.enemy_projectile_ended.connect(func(pp: Projectile, hit: bool) -> void: gone.append(hit))
	for t in 40:
		q.freeze = 0
		q.step(_inp())
	check(gone.size() == 1 and not bool(gone[0]) and q.enemy_projectiles.is_empty() and absf(p.travelled - A.shot_range) < 0.5, "화살: 12칸을 가면 사라진다(%.1f칸)" % p.travelled)


func _test_arrow_cut() -> void:
	var r := _mv(["sweep"])
	var ended: Array = []
	r.enemy_projectile_ended.connect(func(p: Projectile, hit: bool) -> void: ended.append([p, hit]))
	var front := _arrow(r, r.lord.pos + Vector2(1.0, 0.0), Vector2(-1.0, 0.0))
	var back := _arrow(r, r.lord.pos + Vector2(-2.5, 0.0), Vector2(1.0, 0.0))
	r.step(_inp(Vector2.ZERO, true))
	check(ended.size() == 1 and ended[0][0] == front and not bool(ended[0][1]) and front.cut and not back.cut, "화살: 좌클릭 판정(횡베기)에 닿은 화살은 부러진다(p.cut). 뒤의 화살은 그대로")
	var w := _mv(["wave"])
	var cut: Array = []
	w.enemy_projectile_ended.connect(func(p: Projectile, hit: bool) -> void: cut.append(p.cut))
	_arrow(w, w.lord.pos + Vector2(7.0, 0.0), Vector2(-1.0, 0.0))
	w.step(_inp(Vector2.ZERO, true))
	_wait(w, 20)
	check(cut.size() == 1 and bool(cut[0]), "화살: 검기에 닿아도 부러진다")


func _test_shield() -> void:
	var S: EnemyData = d.enemies[&"shield"]
	var r := _tok_rules()
	var log := _acts(r)
	var s := _at(r, &"shield", 0.0, 1.5)
	s.face = Vector2(-1.0, 0.0)
	var h0: float = s.hp
	r.hurt(s, 10.0, Vector2(1.0, 0.0), false)
	check(is_equal_approx(h0 - s.hp, 10.0 * S.guard_mult) and is_equal_approx(s.push.x, S.guard_knock * d.lord.knock_speed) and _count(log, &"block") == 1, "방패병: 앞에서 맞으면 피해 ×0.25, 넉백 ×0.2(-%.2f)" % (h0 - s.hp))
	var blk := _first(log, &"block")
	check(not blk.is_empty() and (blk[3] as Dictionary).has("at") and ((blk[3] as Dictionary).get("dir", Vector2.ZERO) as Vector2).x < -0.9, "방패병: block 신호(at, 막은 쪽 dir)")
	s.push = Vector2.ZERO
	s.face = Vector2(1.0, 0.0)
	h0 = s.hp
	r.hurt(s, 10.0, Vector2.ZERO, false)
	var back: float = h0 - s.hp
	s.face = Vector2(0.0, 1.0)
	h0 = s.hp
	r.hurt(s, 10.0, Vector2.ZERO, false)
	check(back == 10.0 and h0 - s.hp == 10.0, "방패병: 옆과 뒤에서 맞으면 그대로 들어간다")
	h0 = s.hp
	r.hurt(s, 10.0, Vector2.ZERO, false, true)
	check(h0 - s.hp == 10.0, "방패병: 출혈·불(dot)은 막지 못한다")
	# 마무리(큰 베기)에 앞을 맞으면 깨진다
	s.face = Vector2(-1.0, 0.0)
	h0 = s.hp
	r.hurt(s, 10.0, Vector2.ZERO, true)
	var gb := _first(log, &"guard_break")
	check(h0 - s.hp == 10.0 and not gb.is_empty() and is_equal_approx(float((gb[3] as Dictionary).get("time", 0.0)), S.guard_stun) and is_equal_approx(s.stun, S.guard_stun) and is_equal_approx(s.guard_down, S.guard_down) and s.act == &"guard_break", "방패병: 마무리에 맞으면 깨진다(1.2초 기절, 2초 못 막음)")
	h0 = s.hp
	r.hurt(s, 10.0, Vector2.ZERO, false)
	check(h0 - s.hp == 10.0, "방패병: 깨진 동안은 앞에서도 그대로 들어간다")
	for t in roundi(S.guard_down * d.run.tick_rate) + 2:
		r.freeze = 0
		r.step(_inp())
	s.face = (r.lord.pos - s.pos).normalized()
	h0 = s.hp
	r.hurt(s, 10.0, Vector2.ZERO, false)
	check(s.guard_down == 0.0 and s.act != &"guard_break" and is_equal_approx(h0 - s.hp, 2.5), "방패병: 2초 뒤에는 다시 막는다")
	# 몸을 천천히 돌린다(돌아서는 동안 등이 열린다)
	var q := _tok_rules()
	var t := _at(q, &"shield", PI, 3.0)
	t.face = Vector2(-1.0, 0.0)
	for i in 3:
		q.freeze = 0
		q.step(_inp())
	var turned: float = absf(angle_difference(PI, t.face.angle()))
	check(turned > 0.1 and turned <= S.turn_rate * 3.0 / d.run.tick_rate + 0.01, "방패병: 몸을 turn_rate로 천천히 돌린다(%.2f라디안)" % turned)
	# 좌클릭으로: 앞의 방패병은 덜 다친다
	var m := _mv(["sweep"])
	var w := _foe(m, Vector2(1.0, 0.0), &"wraith")
	var sh := _foe(m, Vector2(1.0, 0.3), &"shield")
	sh.stun = 0.0
	sh.face = Vector2(-1.0, 0.0)
	m.step(_inp(Vector2.ZERO, true))
	check(_hurt_by(sh) > 0.0 and is_equal_approx(_hurt_by(sh), _hurt_by(w) * S.guard_mult), "방패병: 횡베기도 앞에서 막는다(%.1f / %.1f)" % [_hurt_by(sh), _hurt_by(w)])


func _test_charger() -> void:
	var C: EnemyData = d.enemies[&"charger"]
	var r := _tok_rules()
	r.debug_god = false
	var log := _acts(r)
	var c := _at(r, &"charger", 0.0, 5.0)
	c.cooldown = 0.0
	var hp0: float = r.lord.hp
	var lp0: Vector2 = r.lord.pos
	var wind := _until(r, log, &"wind", 60)
	var at_wind: Vector2 = c.pos
	var info: Dictionary = wind[3] if not wind.is_empty() else {}
	check(not wind.is_empty() and int(wind[4]) > 0 and is_equal_approx(float(info.get("time", 0.0)), C.wind_time) and float(info.get("length", 0.0)) > 8.9 and info.has("dir") and info.has("from"), "돌격병: 3~8칸에서 표를 받으면 머리를 낮춘다(wind: from, dir, length %.1f, time)" % float(info.get("length", 0.0)))
	var charge := _until(r, log, &"charge", 40)
	var gap: int = int(charge[0]) - int(wind[0]) if not charge.is_empty() else -1
	check(absi(gap - roundi(C.wind_time * d.run.tick_rate)) <= 1 and c.prev_pos.distance_to(at_wind) < 0.01, "돌격병: 0.7초 멈춘 뒤 달린다(%d틱)" % gap)
	var end := _until(r, log, &"charge_end", 40)
	check(not end.is_empty() and bool((end[3] as Dictionary).get("hit", false)) and is_equal_approx(hp0 - r.lord.hp, c.damage) and c.token == 0, "돌격병: 영주에게 닿으면 피해(-%.0f)를 주고 멈춘다" % (hp0 - r.lord.hp))
	for t in 30:
		r.freeze = 0
		r.step(_inp())
	var pushed: float = r.lord.pos.distance_to(lp0)
	check(pushed > C.charge_knock * 0.8 and pushed < C.charge_knock * 1.05, "돌격병: 큰 넉백(영주가 %.1f칸 밀려난다)" % pushed)
	# 비틀거리는 동안 받는 피해 ×1.5
	var q := _tok_rules()
	var e := _at(q, &"charger", 0.0, 6.0)
	q.foes._end_charge(e, false)
	var h0: float = e.hp
	q.hurt(e, 10.0, Vector2.ZERO, false)
	var stagger: float = h0 - e.hp
	for t in roundi(C.stagger_time * d.run.tick_rate) + 1:
		q.freeze = 0
		q.step(_inp())
	h0 = e.hp
	q.hurt(e, 10.0, Vector2.ZERO, false)
	check(is_equal_approx(stagger, 15.0) and e.act != &"charge_end" and h0 - e.hp == 10.0, "돌격병: 끝나고 1초 비틀거리며 그동안 피해 ×1.5(%.1f)" % stagger)
	# 돌진으로 피하면 맞지 않는다
	var v := _tok_rules()
	v.debug_god = false
	var vl := _acts(v)
	var c2 := _at(v, &"charger", 0.0, 5.0)
	c2.cooldown = 0.0
	var hv: float = v.lord.hp
	_until(v, vl, &"charge", 60)
	v.lord.dash = 1.0
	var end2 := _until(v, vl, &"charge_end", 40)
	check(not end2.is_empty() and not bool((end2[3] as Dictionary).get("hit", true)) and v.lord.hp == hv and c2.pos.distance_to(v.lord.pos) > 3.0, "돌격병: 돌진 중인 영주는 지나쳐 9칸 끝까지 달린다")
	# 기절하면 돌진이 멈춘다
	var w := _tok_rules()
	var wl := _acts(w)
	var c3 := _at(w, &"charger", 0.0, 5.0)
	c3.cooldown = 0.0
	_until(w, wl, &"wind", 60)
	c3.stun = 0.5
	w.freeze = 0
	w.step(_inp())
	check(c3.act == &"" and _first(wl, &"charge").is_empty(), "돌격병: 머리를 낮추는 동안 기절하면 돌진하지 않는다")


func _test_bomber() -> void:
	var B: EnemyData = d.enemies[&"bomber"]
	var r := _tok_rules()
	r.debug_god = false
	var log := _acts(r)
	var b := _at(r, &"bomber", 0.0, 1.0)
	var near := _at(r, &"wraith", 0.0, 2.5)
	var far := _at(r, &"wraith", PI, 5.0)
	near.stun = 99.0
	far.stun = 99.0
	var hp0: float = r.lord.hp
	var fuse := _until(r, log, &"fuse", 30)
	var info: Dictionary = fuse[3] if not fuse.is_empty() else {}
	check(not fuse.is_empty() and int(fuse[4]) > 0 and is_equal_approx(float(info.get("radius", 0.0)), B.blast_radius) and is_equal_approx(float(info.get("time", 0.0)), B.fuse_time), "자폭병: 1.2칸 안에서 표를 받으면 심지(fuse: at, radius 2.2, time 0.9)")
	var boom := _until(r, log, &"explode", 40)
	var gap: int = int(boom[0]) - int(fuse[0]) if not boom.is_empty() else -1
	check(absi(gap - roundi(B.fuse_time * d.run.tick_rate)) <= 1 and b.dead and r.kills == 0, "자폭병: 0.9초 뒤 터지고 사라진다(스스로 터진 것은 처치가 아니다, %d틱)" % gap)
	check(is_equal_approx(hp0 - r.lord.hp, b.damage) and is_equal_approx(_hurt_by(near), b.damage * B.blast_enemy_mult) and near.push.length() > 0.1 and _hurt_by(far) == 0.0, "자폭병: 영주와 반지름 안의 다른 적을 다친다(멀리 있는 적은 그대로)")
	# 심지가 타는 동안 쓰러지면 바로 터진다(이어서 다른 자폭병의 심지도)
	var q := _tok_rules()
	var ql := _acts(q)
	var b1 := _at(q, &"bomber", 0.0, 1.0)
	var b2 := _at(q, &"bomber", 0.0, 2.6)
	b2.stun = 99.0
	_until(q, ql, &"fuse", 30, b1)
	q.foes._begin(b2, &"fuse", 5.0)
	var t0: int = q.tick
	q.hurt(b1, 999.0, Vector2.ZERO, false)
	var e1 := _first(ql, &"explode", b1)
	var e2 := _first(ql, &"explode", b2)
	check(not e1.is_empty() and int(e1[0]) == t0 and q.kills == 2 and not e2.is_empty() and b2.dead, "자폭병: 심지가 타는 동안 쓰러지면 바로 터지고, 심지 붙은 다른 자폭병도 터진다")
	var z := _tok_rules()
	var zl := _acts(z)
	var b3 := _at(z, &"bomber", 0.0, 6.0)
	z.hurt(b3, 999.0, Vector2.ZERO, false)
	check(b3.dead and _count(zl, &"explode") == 0, "자폭병: 심지 전에 쓰러지면 터지지 않는다")


func _test_caller() -> void:
	var K: EnemyData = d.enemies[&"caller"]
	var r := _tok_rules()
	var log := _acts(r)
	var spawned: Array[Enemy] = []
	r.enemy_spawned.connect(func(e: Enemy) -> void: spawned.append(e))
	var c := _at(r, &"caller", 0.0, 12.0)
	spawned.clear()
	check(is_equal_approx(c.cooldown, K.summon_interval) and r.tokens.cost(c) == 0, "부르는 자: 표를 쓰지 않고, 7초 뒤 처음 부른다")
	var max_tok: Array[int] = [0]
	var wind := []
	for t in roundi((K.summon_interval + K.summon_time) * d.run.tick_rate) + 4:
		r.freeze = 0
		r.step(_inp())
		max_tok[0] = maxi(max_tok[0], c.token)
	wind = _first(log, &"call_wind")
	var call := _first(log, &"call")
	var spots: Array = (call[3] as Dictionary).get("spots", []) if not call.is_empty() else []
	var near_spots: bool = spawned.size() == 3
	for i in mini(spawned.size(), spots.size()):
		near_spots = near_spots and spawned[i].data.id == &"wraith" and (spawned[i].pos as Vector2).distance_to(spots[i]) < 0.5
	check(not wind.is_empty() and is_equal_approx(float((wind[3] as Dictionary).get("time", 0.0)), K.summon_time) and is_equal_approx(float((wind[3] as Dictionary).get("radius", 0.0)), K.summon_radius), "부르는 자: 1초 동안 불러낸다(call_wind: at, radius, time)")
	check(not call.is_empty() and int((call[3] as Dictionary).get("count", 0)) == 3 and spots.size() == 3 and near_spots and int(call[0]) - int(wind[0]) == roundi(K.summon_time * d.run.tick_rate), "부르는 자: 둘레에 망령 3마리(call: count, spots)")
	check(max_tok[0] == 0 and c.summoned == 3, "부르는 자: 표를 들지 않는다")
	# 도망친다
	var f := _tok_rules()
	var fc := _at(f, &"caller", 0.0, 4.0)
	for t in 60:
		f.freeze = 0
		f.step(_inp())
	check(fc.pos.distance_to(f.lord.pos) > 6.0, "부르는 자: 가까우면 도망친다(%.1f칸)" % fc.pos.distance_to(f.lord.pos))
	# 한 마리가 한 밤에 부르는 수(summon_max)와 전체 적 수 한도
	var g := GameData.load_default()
	var kd := (d.enemies[&"caller"] as EnemyData).duplicate() as EnemyData
	kd.summon_interval = 0.5
	kd.summon_max = 5
	g.enemies[&"caller"] = kd
	var m := _tok_rules(g)
	var mc := _at(m, &"caller", 0.0, 12.0)
	for t in 300:
		m.freeze = 0
		m.step(_inp())
	check(mc.summoned == 5 and m.enemies.size() == 6, "부르는 자: 한 밤에 summon_max(%d)마리까지만 부른다" % mc.summoned)
	var g2 := GameData.load_default()
	g2.enemies[&"caller"] = kd
	g2.run = d.run.duplicate() as RunData
	g2.run.max_enemies = 3
	var n := _tok_rules(g2)
	var nc := _at(n, &"caller", 0.0, 12.0)
	var most: Array[int] = [0]
	for t in 300:
		n.freeze = 0
		n.step(_inp())
		most[0] = maxi(most[0], n.enemies.size())
	check(most[0] == 3 and nc.summoned == 2, "부르는 자: 전체 적 수 한도 안에서만 부른다(%d)" % most[0])
	# 불러내는 동안 기절하면 끊긴다
	var s := _tok_rules()
	var sl := _acts(s)
	var sc := _at(s, &"caller", 0.0, 12.0)
	sc.cooldown = 0.0
	_until(s, sl, &"call_wind", 10)
	sc.stun = 0.3
	for t in 40:
		s.freeze = 0
		s.step(_inp())
	check(_first(sl, &"call").is_empty() and sc.summoned == 0, "부르는 자: 불러내는 동안 기절하면 끊긴다")


func _test_foes_tokens() -> void:
	# 표 1장: 활잡이 셋이 돌아가며 쏜다(동시에 겨누는 것은 하나)
	var r := _tok_rules(_tok_data(1))
	var log := _acts(r)
	for i in 3:
		_at(r, &"archer", i * 2.0, 7.0).cooldown = 0.0
	var worst: Array[int] = [0]
	for t in 300:
		r.freeze = 0
		r.step(_inp())
		var n: int = 0
		for e in r.enemies:
			if e.act == &"aim":
				n += 1
		worst[0] = maxi(worst[0], n)
	check(worst[0] == 1 and _count(log, &"shoot") >= 3, "표: 표 1장이면 활잡이도 한 번에 하나만 겨눈다(쏨 %d)" % _count(log, &"shoot"))
	var aims_ok: bool = true
	for x in log:
		if x[2] == &"aim" or x[2] == &"wind" or x[2] == &"fuse":
			aims_ok = aims_ok and int(x[4]) > 0
	# 자폭병의 심지도 표가 있어야 붙는다
	var b := _tok_rules(_tok_data(1))
	var bl := _acts(b)
	for i in 3:
		var bb := _at(b, &"bomber", i * 2.0, 1.0)
		bb.max_hp = 9999.0
		bb.hp = bb.max_hp
	var fusing: Array[int] = [0]
	for t in 240:
		b.freeze = 0
		b.step(_inp())
		var n: int = 0
		for e in b.enemies:
			if e.act == &"fuse":
				n += 1
		fusing[0] = maxi(fusing[0], n)
	for x in bl:
		if x[2] == &"fuse":
			aims_ok = aims_ok and int(x[4]) > 0
	check(fusing[0] == 1 and _count(bl, &"explode") >= 2 and aims_ok, "표: 겨눔·심지는 표를 든 적만 한다(심지는 한 번에 %d)" % fusing[0])
	var c := _tok_rules()
	var ch := _ringed(c, &"charger", 0.0)
	for t in 15:
		c.freeze = 0
		c.step(_inp())
	check(c.tokens.wait_dist(ch) == d.enemies[&"charger"].wait_range and (ch.token == 2 or ch.act != &""), "표: 돌격병은 5.5칸 둘레에서 표 2장을 받는다")


func _test_foes_replay() -> void:
	var g := GameData.load_default()
	g.run = d.run.duplicate() as RunData
	for k in RunData.EXTRA_KINDS:
		g.run.set(String(k) + "_chance", PackedFloat32Array([0.14]))
	var hashes: Array[int] = []
	var logs: Array[String] = []
	var counts: Array[int] = []
	for run_i in 2:
		var r := Rules.new(g, 77)
		r.zone = 5
		r.debug_god = true
		var text: Array[String] = [""]
		var acts: Array[int] = [0]
		r.enemy_act.connect(func(e: Enemy, act: StringName, _i: Dictionary) -> void:
			text[0] += "%d:%d:%s " % [r.tick, e.id, act]
			acts[0] += 1)
		r.start_night()
		var rec := RandomNumberGenerator.new()
		rec.seed = 5
		for k in 1500:
			r.step(_inp(Vector2(rec.randf_range(-1, 1), rec.randf_range(-1, 1)), rec.randf() < 0.3, rec.randf() < 0.03))
		hashes.append(r.state_hash())
		logs.append(text[0])
		counts.append(acts[0])
	check(hashes[0] == hashes[1] and logs[0] == logs[1], "새 적: 같은 시드·같은 입력이면 행동과 결과가 같다(state_hash)")
	check(counts[0] > 20 and logs[0].contains("aim") and logs[0].contains("fuse") and logs[0].contains("call"), "새 적: 다시 돌린 밤에서 다섯 종이 실제로 움직였다(행동 %d)" % counts[0])


# ---------------------------------------------------------------- 12단계: 밤의 목표와 구역 규칙

## 그 목표와 구역 규칙의 밤(3구역, 0부터 2). 영주는 다치지 않는다.
func _goal_rules(goal: StringName, rule: StringName = &"", g: GameData = null, seed: int = 21) -> Rules:
	var r := Rules.new(g if g else d, seed)
	r.zone = 2
	r.debug_god = true
	r.set_next_night(goal, rule)
	r.start_night()
	return r


## 그 값만 바꾼 표.
func _run_data(values: Dictionary) -> GameData:
	var g := GameData.load_default()
	g.run = d.run.duplicate() as RunData
	for k in values:
		g.run.set(k, values[k])
	return g


func _test_night_choice() -> void:
	var r := Rules.new(d, 31)
	var got: Array = []
	r.night_goal_changed.connect(func(gl: StringName, rl: StringName) -> void: got.append([gl, rl]))
	r.set_next_night(&"siege", &"embers")
	r.start_night()
	check(r.goal == &"survive" and r.rule == &"" and got == [[&"survive", &""]], "목표: 1구역은 늘 버티기(구역 규칙 없음), night_goal_changed")
	check(is_equal_approx(r.night_total, d.run.night_length) and r.beacon_max == 0.0 and r.siege < 0, "버티기: 지금과 같다(75초, 봉화·포위 없음)")
	var seen := {}
	var rules_seen := {}
	var valid: Array[bool] = [true]
	for sd in 60:
		var q := Rules.new(d, 400 + sd)
		q.debug_god = true
		q.start_night()
		q.skip_night()
		for c in q.path_cards:
			seen[c.goal] = true
			rules_seen[c.rule] = true
			valid[0] = valid[0] and Rules.GOALS.has(c.goal) and Rules.ZONE_RULES.has(c.rule)
	check(valid[0], "목표: 2구역 갈림길의 목표와 구역 규칙은 표에 있는 값")
	check(seen.size() == 4 and rules_seen.size() == 4, "목표: 2~9구역의 갈림길에 네 목표와 네 규칙(없음 포함)이 다 나온다(%d, %d)" % [seen.size(), rules_seen.size()])
	var a := Rules.new(d, 77)
	var b := Rules.new(d, 77)
	for q in [a, b]:
		q.debug_god = true
		q.start_night()
		q.skip_night()
	check(str(a.path_cards) == str(b.path_cards), "목표: 같은 시드면 같은 갈림길")
	a.choose_path(1)
	check(a.next_goal == b.path_cards[1].goal and a.next_rule == b.path_cards[1].rule, "목표: 고른 길의 목표와 규칙이 다음 밤의 것")
	a.set_next_night(&"hunt", &"graves")
	a.start_night()
	check(a.goal == &"hunt" and a.rule == &"graves", "목표: set_next_night로 고른 목표가 그 밤에 쓰인다(13단계 갈림길)")
	a.set_next_night(&"nope", &"")
	check(a.next_goal == &"hunt", "목표: 모르는 값은 무시한다")
	var last := Rules.new(d, 32)
	last.zone = last.zone_count() - 1
	last.set_next_night(&"defend", &"fog")
	last.start_night()
	check(last.goal == &"survive" and last.rule == &"" and last.beacon_max == 0.0, "목표: 마지막 구역은 지금과 같다(언덕지기)")


func _test_defend() -> void:
	var r := _goal_rules(&"defend")
	var zi: int = 2
	check(r.goal == &"defend" and is_equal_approx(r.beacon_max, d.run.beacon_hp * d.run.zone_hp[zi]) and r.beacon_hp == r.beacon_max, "지키기: 봉화 체력 300 × 구역 체력 배수")
	check(r.beacon_pos.distance_to(Grid.middle()) < 4.0, "지키기: 봉화는 싸움터 가운데 근처")
	# 나오는 적의 40%쯤이 봉화를 노린다
	var born: Array[Enemy] = []
	r.enemy_spawned.connect(func(e: Enemy) -> void: born.append(e))
	for t in 30 * 40:
		r.step()
	var marked: Array[int] = [0, 0]
	for e in born:
		if d.run.beacon_kinds.has(String(e.data.id)) and not e.elite:
			marked[0] += 1
			marked[1] += 1 if e.beacon else 0
		elif e.beacon:
			marked[1] += 1000
	var share: float = float(marked[1]) / maxf(1.0, marked[0])
	check(marked[0] > 30 and share > 0.25 and share < 0.55, "지키기: 적의 40%%쯤이 봉화를 노린다(%d / %d)" % [marked[1], marked[0]])
	# 봉화를 노리는 적은 표 없이 봉화를 때린다
	var q := _goal_rules(&"defend")
	q._spawn_t = 1e9
	q.elite_out = true
	q.enemies.clear()
	q.lord.pos = q.beacon_pos + Vector2(10.0, 0.0)
	var hits: Array = []
	var outs: Array[int] = [0]
	q.beacon_hit.connect(func(hp: float, mx: float) -> void: hits.append([hp, mx]))
	q.beacon_out.connect(func() -> void: outs[0] += 1)
	var e := q.spawn_at(&"wraith", q.beacon_pos + Vector2(-3.0, 0.0))
	e.beacon = true
	var tokened: Array[bool] = [false]
	for t in 30 * 6:
		q.step()
		if e.token > 0:
			tokened[0] = true
	check(hits.size() >= 2 and not tokened[0] and q.beacon_hp < q.beacon_max, "지키기: 봉화를 노리는 적은 표 없이 봉화를 때린다(beacon_hit %d번)" % hits.size())
	check(e.pos.distance_to(q.beacon_pos) >= d.run.beacon_radius + e.radius - 0.01, "지키기: 봉화 안으로는 들어오지 못한다")
	check(hits.size() > 0 and is_equal_approx(float(hits[0][1]), q.beacon_max), "지키기: beacon_hit(hp, max)")
	q.hit_beacon(99999.0)
	check(q.beacon_hp == 0.0 and q.beacon_lost and outs[0] == 1 and q.phase == Rules.Phase.NIGHT, "지키기: 봉화가 꺼지면 beacon_out, 밤은 이어진다")
	q.hit_beacon(10.0)
	check(outs[0] == 1, "지키기: 꺼진 봉화는 다시 꺼지지 않는다")
	# 꺼진 뒤에는 영주를 노린다(표를 청한다)
	q.lord.pos = e.pos + Vector2(3.0, 0.0)
	for t in 30 * 3:
		q.step()
	check(not q.at_beacon(e) and e.pos.distance_to(q.lord.pos) < 3.0, "지키기: 봉화가 꺼지면 그 적도 영주에게 온다")


func _test_hunt() -> void:
	var r := _goal_rules(&"hunt")
	var bosses: Array[Enemy] = []
	var elites: Array[Enemy] = []
	var at: Array[float] = [-1.0]
	r.boss_spawned.connect(func(e: Enemy) -> void:
		bosses.append(e)
		at[0] = 1.0 - r.night_left / r.night_total)
	r.elite_spawned.connect(func(e: Enemy) -> void: elites.append(e))
	for t in 30 * 30:
		r.step()
	check(bosses.size() == 1 and absf(at[0] - d.run.hunt_at) < 0.02, "사냥: 밤이 20%% 지나면 우두머리가 나온다(%.2f)" % at[0])
	var b: Enemy = bosses[0] if bosses.size() > 0 else null
	check(b != null and b.hunt and b.elite and r.hunt_boss == b and not b.data.boss, "사냥: 우두머리는 이 구역의 적 하나를 정예로 한 것")
	if b:
		var zi: int = 2
		check(is_equal_approx(b.max_hp, b.data.hp * d.run.zone_hp[zi] * d.run.hunt_hp) and is_equal_approx(b.radius, b.data.radius * d.run.elite_size), "사냥: 체력 ×4, 몸이 크다")
		check(d.run.hunt_kinds.has(String(b.data.id)) and r._can_appear(b.data.id), "사냥: 이 구역에서 나올 수 있는 적")
	check(elites.is_empty(), "사냥: 우두머리가 그 밤의 정예를 대신한다")
	var days: Array[int] = []
	r.day_started.connect(func(z: int) -> void: days.append(z))
	var left: float = r.night_left
	r.hurt(b, 999999.0, Vector2.ZERO, false)
	r.step()
	check(r.phase == Rules.Phase.DAY and r.path_open and r.zone == 3 and left > 10.0, "사냥: 쓰러뜨리면 그 자리에서 새벽이 온다")
	r.choose_path(0)
	check(days == [3], "사냥: (길을 고르면 낮)")
	check(r.last_night.goal == &"hunt" and r.last_night.ok and not r.last_night.fled, "사냥: 결과에 남는다")
	# 못 쓰러뜨리면 달아난다
	var q := _goal_rules(&"hunt")
	for t in roundi(q.night_total * 30) + 5:
		q.step()
		if q.phase != Rules.Phase.NIGHT:
			break
	check(q.phase == Rules.Phase.DAY and q.zone == 3 and q.last_night.fled and not q.last_night.ok and q.enemies.is_empty(), "사냥: 밤이 끝날 때까지 못 쓰러뜨리면 달아난다")
	check(q.goal_shards == 0, "사냥: 달아나면 보상이 없다")
	# 1구역 적만 나오는 곳에서는 망령·늑대만
	var only := _goal_rules(&"hunt")
	only.zone = 0
	var kinds := {}
	for t in 20:
		kinds[only._spawn_hunt().data.id] = true
	check(kinds.keys().all(func(k: StringName) -> bool: return k == &"wraith" or k == &"wolf"), "사냥: 1구역의 적에서 고른다(%s)" % str(kinds.keys()))


func _test_siege() -> void:
	var r := _goal_rules(&"siege")
	var sides: Array[int] = []
	r.siege_side.connect(func(sd: int) -> void: sides.append(sd))
	check(is_equal_approx(r.night_total, d.run.siege_night) and is_equal_approx(r.night_left, 60.0), "포위: 밤 길이 60초")
	check(r.siege >= 0 and r.siege <= 3, "포위: 시작할 때 변 하나")
	var first: int = r.siege
	var spawned: Array[Enemy] = []
	r.enemy_spawned.connect(func(e: Enemy) -> void: spawned.append(e))
	var size := Vector2(Grid.size)
	var bad: Array[int] = [0]
	var cur: Array[int] = [first]
	r.siege_side.connect(func(sd: int) -> void: cur[0] = sd)
	r.enemy_spawned.connect(func(e: Enemy) -> void:
		if e.summoned > 0:
			return
		var p := e.pos
		var ok: bool = [p.y < 0.0, p.y > size.y, p.x < 0.0, p.x > size.x][cur[0]] if cur[0] >= 0 else true
		if not ok:
			bad[0] += 1)
	for t in 30 * 21:
		r.step()
	check(sides.size() == 1 and sides[0] != first and sides[0] >= 0, "포위: 20초마다 다른 변으로(siege_side)")
	check(spawned.size() > 10 and bad[0] == 0, "포위: 적이 한 변에서만 나온다(%d마리, 어긋남 %d)" % [spawned.size(), bad[0]])
	# 나오는 빠르기 ×1.4
	var plain := _goal_rules(&"survive")
	var n: Array[int] = [0, 0]
	plain.enemy_spawned.connect(func(_e: Enemy) -> void: n[0] += 1)
	var s2 := _goal_rules(&"siege")
	s2.enemy_spawned.connect(func(_e: Enemy) -> void: n[1] += 1)
	for t in 30 * 18:
		plain.step()
		s2.step()
	check(float(n[1]) > float(n[0]) * 1.2, "포위: 적이 더 빨리 나온다(%d → %d)" % [n[0], n[1]])
	var ends: Array[int] = []
	s2.siege_side.connect(func(sd: int) -> void: ends.append(sd))
	for t in 30 * 50:
		s2.step()
		if s2.phase != Rules.Phase.NIGHT:
			break
	check(s2.phase == Rules.Phase.DAY and ends.size() > 0 and ends[-1] == -1 and s2.siege == -1, "포위: 60초면 새벽, 끝나면 siege_side(-1)")


func _test_fog() -> void:
	var a := _goal_rules(&"survive", &"fog", null, 55)
	var b := _goal_rules(&"survive", &"", null, 55)
	check(a.rule == &"fog", "짙은 안개: 구역 규칙이 붙는다")
	for t in 30 * 20:
		a.step(_inp(Vector2(0.3, 0.1), true))
		b.step(_inp(Vector2(0.3, 0.1), true))
	var same: bool = a.enemies.size() == b.enemies.size() and a.kills == b.kills and a.lord.pos == b.lord.pos
	for i in mini(a.enemies.size(), b.enemies.size()):
		same = same and a.enemies[i].pos == b.enemies[i].pos and a.enemies[i].hp == b.enemies[i].hp
	check(same and a.rng.state == b.rng.state, "짙은 안개: 화면만 바뀌고 규칙은 같다")


func _test_embers() -> void:
	var r := _goal_rules(&"survive", &"embers")
	r._spawn_t = 1e9
	r.elite_out = true
	r.enemies.clear()
	r.debug_god = false
	var warns: Array = []
	var burns: Array = []
	r.ember_warn.connect(func(at: Vector2, rad: float, tm: float) -> void: warns.append([r.tick, at, rad, tm]))
	r.ember_burn.connect(func(at: Vector2, rad: float, tm: float) -> void: burns.append([r.tick, at, rad, tm]))
	var t0: int = r.tick
	for t in roundi(d.run.ember_every * 30) + 2:
		r.step()
	check(warns.size() == 3 and burns.is_empty(), "불씨 땅: 8초마다 3곳이 미리 보인다(%d)" % warns.size())
	check(warns.size() > 0 and is_equal_approx(warns[0][2], 1.5) and is_equal_approx(warns[0][3], 1.0) and absf((warns[0][0] - t0) / 30.0 - 8.0) < 0.1, "불씨 땅: 반지름 1.5칸, 1초 미리")
	# 불이 붙을 자리에 영주와 적을 세운다
	var at: Vector2 = r.embers[0].at
	r.lord.pos = at
	var e := r.spawn_at(&"giant", at + Vector2(0.5, 0.0))
	e.stun = 99.0
	e.max_hp = 9999.0
	e.hp = 9999.0
	var hp0: float = r.lord.hp
	var hurt_n: Array[int] = [0]
	r.lord_hurt.connect(func(_d: float) -> void: hurt_n[0] += 1)
	for t in 32:
		r.step()
		r.lord.pos = at
		e.pos = at + Vector2(0.5, 0.0)
	check(burns.size() == 3 and is_equal_approx(burns[0][3], 4.0), "불씨 땅: 1초 뒤 4초 동안 탄다(ember_burn)")
	var lord_lost: float = hp0 - r.lord.hp
	for t in 30:
		r.step()
		r.lord.pos = at
		e.pos = at + Vector2(0.5, 0.0)
	var per_s: float = hp0 - r.lord.hp - lord_lost
	check(absf(per_s - 4.0) < 0.3, "불씨 땅: 안에 있으면 영주 초당 4(%.2f)" % per_s)
	check(hurt_n[0] >= 1, "불씨 땅: 영주가 타면 맞음 신호(1초 몫마다)")
	var e_hp0: float = e.hp
	for t in 30:
		r.step()
		r.lord.pos = at
		e.pos = at + Vector2(0.5, 0.0)
	check(absf(e_hp0 - e.hp - 8.0) < 0.5, "불씨 땅: 적 초당 8(%.2f)" % (e_hp0 - e.hp))
	for t in 30 * 3:
		r.step()
	check(r.embers.size() <= 3, "불씨 땅: 다 탄 자리는 사라진다")
	var none := _goal_rules(&"survive", &"")
	var w2: Array[int] = [0]
	none.ember_warn.connect(func(_a: Vector2, _b: float, _c: float) -> void: w2[0] += 1)
	for t in 30 * 10:
		none.step()
	check(w2[0] == 0, "불씨 땅: 규칙이 없으면 불이 없다")


func _test_graves() -> void:
	var g := _run_data({"grave_chance": 1.0})
	var r := _goal_rules(&"survive", &"graves", g)
	r._spawn_t = 1e9
	r.elite_out = true
	r.enemies.clear()
	var rises: Array = []
	r.grave_rise.connect(func(at: Vector2) -> void: rises.append([r.tick, at]))
	var w := r.spawn_at(&"wraith", r.lord.pos + Vector2(5.0, 0.0))
	w.stun = 99.0
	var at: Vector2 = w.pos
	var mhp: float = w.max_hp
	var t0: int = r.tick
	r.hurt(w, 99999.0, Vector2.ZERO, false)
	var wolf := r.spawn_at(&"wolf", r.lord.pos + Vector2(-5.0, 0.0))
	r.hurt(wolf, 99999.0, Vector2.ZERO, false)
	for t in 30 * 4:
		r.step()
	check(rises.size() == 1 and absf((rises[0][0] - t0) / 30.0 - 3.0) < 0.1 and rises[0][1] == at, "무덤: 쓰러진 망령이 3초 뒤 그 자리에서 일어난다(grave_rise)")
	var back: Enemy = null
	for e in r.enemies:
		if e.risen:
			back = e
	check(back != null and back.data.id == &"wraith" and is_equal_approx(back.max_hp, mhp * 0.5) and is_equal_approx(back.hp, mhp * 0.5), "무덤: 체력 절반으로")
	check(rises.size() == 1, "무덤: 망령만 일어난다(늑대는 아니다)")
	if back:
		r.hurt(back, 99999.0, Vector2.ZERO, false)
	for t in 30 * 4:
		r.step()
	check(rises.size() == 1, "무덤: 한 번만 일어난다")
	# 25%
	var q := _goal_rules(&"survive", &"graves")
	q._spawn_t = 1e9
	q.elite_out = true
	q.enemies.clear()
	for i in 400:
		var e := q.spawn_at(&"wraith", Vector2(3.0, 3.0))
		q.hurt(e, 99999.0, Vector2.ZERO, false)
	var p: float = q.graves.size() / 400.0
	check(p > 0.18 and p < 0.32, "무덤: 25%% 확률(%.2f)" % p)
	var none := _goal_rules(&"survive", &"")
	none.hurt(none.spawn_at(&"wraith", Vector2(3.0, 3.0)), 99999.0, Vector2.ZERO, false)
	check(none.graves.is_empty(), "무덤: 규칙이 없으면 일어나지 않는다")


## 새벽의 보상: 공짜 뽑기, 조각, 봉화가 꺼지면 회복 절반.
func _test_goal_rewards() -> void:
	var heal: float = d.run.heal_per_dawn
	var lit := _goal_rules(&"defend")
	lit.lord.hp = 20.0
	lit.skip_night()
	check(lit.free_pulls == d.run.defend_free and is_equal_approx(lit.lord.hp, 20.0 + heal) and lit.last_night.ok, "보상: 봉화를 지키면 다음 낮 공짜 뽑기 +1")
	var out := _goal_rules(&"defend")
	out.lord.hp = 20.0
	out.hit_beacon(999999.0)
	out.skip_night()
	check(out.free_pulls == 0 and is_equal_approx(out.lord.hp, 20.0 + heal * 0.5) and not out.last_night.ok and is_equal_approx(out.last_night.heal, heal * 0.5), "보상: 봉화가 꺼지면 보상이 없고 새벽 회복이 절반")
	var h := _goal_rules(&"hunt")
	for t in 30 * 16:
		h.step()
	var free0: int = h.free_pulls
	h.hurt(h.hunt_boss, 999999.0, Vector2.ZERO, false)
	h.step()
	check(h.phase == Rules.Phase.DAY and h.free_pulls == free0 + 1 + d.run.hunt_free and h.goal_shards == 3, "보상: 사냥은 공짜 뽑기 +1(정예 몫과 따로), 조각 +3")
	var sh := Meta.run_shards(h, d.meta)
	check(int(sh.goal) == 3 and int(sh.total) >= 3, "보상: 사냥의 조각은 판이 끝날 때 센다")
	var sg := _goal_rules(&"siege")
	sg.skip_night()
	check(sg.free_pulls == d.run.siege_free and sg.last_night.goal == &"siege", "보상: 포위를 버티면 공짜 뽑기 +1")
	var sv := _goal_rules(&"survive")
	sv.skip_night()
	check(sv.free_pulls == 0 and sv.goal_shards == 0, "보상: 버티기는 없다")
	var cap := _goal_rules(&"siege")
	cap.free_pulls = d.run.max_free_pulls
	cap.skip_night()
	check(cap.free_pulls == d.run.max_free_pulls, "보상: 공짜 뽑기는 모아 둘 수 있는 수까지")


## 같은 시드·같은 입력이면 목표마다 결과가 같다.
func _test_goals_replay() -> void:
	var cases: Array = [[&"defend", &"embers"], [&"hunt", &"graves"], [&"siege", &"fog"]]
	for c in cases:
		var hashes: Array[int] = []
		var logs: Array[String] = []
		for run_i in 2:
			var r := _goal_rules(c[0], c[1], null, 88)
			var text: Array[String] = [""]
			r.beacon_hit.connect(func(hp: float, _m: float) -> void: text[0] += "b%d:%.1f " % [r.tick, hp])
			r.ember_warn.connect(func(at: Vector2, _r: float, _t: float) -> void: text[0] += "e%d:%s " % [r.tick, at])
			r.grave_rise.connect(func(at: Vector2) -> void: text[0] += "g%d:%s " % [r.tick, at])
			r.siege_side.connect(func(sd: int) -> void: text[0] += "s%d:%d " % [r.tick, sd])
			r.boss_spawned.connect(func(e: Enemy) -> void: text[0] += "h%d:%s " % [r.tick, e.data.id])
			var rec := RandomNumberGenerator.new()
			rec.seed = 9
			for k in 1500:
				r.step(_inp(Vector2(rec.randf_range(-1, 1), rec.randf_range(-1, 1)), rec.randf() < 0.4, rec.randf() < 0.03))
			hashes.append(r.state_hash())
			logs.append(text[0])
		check(hashes[0] == hashes[1] and logs[0] == logs[1] and logs[0] != "", "목표 %s·%s: 같은 시드·같은 입력이면 결과가 같다(state_hash)" % [c[0], c[1]])


# ---------------------------------------------------------------- 13단계: 갈림길과 낮 사건

## 그 구역(0부터)의 밤을 넘겨 새벽의 갈림길에 선 판. 영주는 다치지 않는다.
func _dawn(zone: int, g: GameData = null, seed: int = 61) -> Rules:
	var r := Rules.new(g if g else d, seed)
	r.debug_god = true
	r.zone = zone
	r.start_night()
	r.skip_night()
	return r


## 그 사건 하나만 서는 표.
func _ev_data(kind: String) -> GameData:
	return _run_data({"event_kinds": PackedStringArray([kind])})


## 사건 kind가 선 2구역의 낮(길은 0번).
func _ev_day(kind: String, seed: int = 62) -> Rules:
	var r := _dawn(0, _ev_data(kind), seed)
	r.choose_path(0)
	return r


func _press_e(r: Rules) -> void:
	var i := LordInput.new()
	i.pull = true
	r.step(i)


func _test_path_cards() -> void:
	var r := Rules.new(d, 63)
	r.debug_god = true
	var offered: Array = []
	var days: Array[int] = []
	r.path_offered.connect(func(c: Array) -> void: offered.append(c))
	r.day_started.connect(func(z: int) -> void: days.append(z))
	check(not r.path_open and r.path_cards.is_empty() and r.path_log.size() == 1, "갈림길: 1구역은 고르지 않는다")
	r.start_night()
	r.skip_night()
	check(r.path_open and offered.size() == 1 and r.path_cards.size() == 2 and days.is_empty() and r.hilts.is_empty() and r.altar == null and r.event == null, "갈림길: 새벽에 길 두 개, 고르기 전에는 낮이 아니다(손잡이·제단·사건 없음)")
	var a: Dictionary = r.path_cards[0]
	var b: Dictionary = r.path_cards[1]
	check(a.goal != b.goal or a.rule != b.rule, "갈림길: 두 길의 목표·규칙이 같지 않다")
	check(a.reward != b.reward and d.run.path_rewards.has(String(a.reward)) and d.run.path_rewards.has(String(b.reward)), "갈림길: 두 길의 보상은 서로 다른 보상 표의 값")
	var p0: Vector2 = r.lord.pos
	var t0: int = r.tick
	r.step(_inp(Vector2.RIGHT))
	r.start_night()
	check(r.lord.pos == p0 and r.phase == Rules.Phase.DAY and r.tick == t0 + 1, "갈림길: 고르는 동안 시간이 멈추고 밤도 오지 않는다")
	r.choose_path(5)
	check(r.path_open, "갈림길: 없는 길은 무시한다")
	var chosen: Array = []
	r.path_chosen.connect(func(i: int, c: Dictionary) -> void: chosen.append([i, c]))
	r.choose_path(1)
	check(not r.path_open and days == [1] and chosen.size() == 1 and chosen[0][0] == 1 and r.hilts.size() == d.run.hilts_per_day, "갈림길: 고르면 path_chosen, 그다음 낮(손잡이)")
	check(r.next_goal == b.goal and r.next_rule == b.rule and r.path_reward == b.reward, "갈림길: 고른 길의 목표·규칙·보상")
	check(r.path_log.size() == 2 and r.path_log[1].zone == 1 and r.path_log[1].goal == b.goal, "갈림길: 지나온 길에 남는다(지도 창)")
	r.choose_path(0)
	check(r.path_log.size() == 2, "갈림길: 한 번만 고른다")
	r.start_night()
	check(r.goal == b.goal and r.rule == b.rule, "갈림길: 그 밤의 목표·규칙이 된다")
	# 구역 제한: 2~9구역은 표의 값, 마지막 구역은 둘 다 언덕지기(버티기, 규칙 없음)
	var ok: Array[bool] = [true]
	var hard_seen: Array[int] = [0]
	for z in range(0, 8):
		var q := _dawn(z, null, 70 + z)
		for c in q.path_cards:
			ok[0] = ok[0] and Rules.GOALS.has(c.goal) and Rules.ZONE_RULES.has(c.rule)
			hard_seen[0] += d.run.path_hardness(c.goal, c.rule)
	check(ok[0] and hard_seen[0] > 0, "갈림길: 2~9구역의 길은 표의 목표와 규칙")
	var last := _dawn(8)
	check(last.last_zone() and last.path_cards.size() == 2 and last.path_cards.all(func(c: Dictionary) -> bool: return c.goal == &"survive" and c.rule == &""), "갈림길: 10구역 앞은 둘 다 언덕지기(보상만 다르다)")
	check(last.path_cards[0].reward != last.path_cards[1].reward, "갈림길: 10구역 앞 두 길의 보상은 다르다")
	var top := _dawn(9)
	check(top.phase == Rules.Phase.OVER and not top.path_open, "갈림길: 정상의 밤이 끝나면 길이 없다")


## 어려운 길(사냥·포위, 구역 규칙)일수록 좋은 보상(공짜 뽑기, 운)이 잘 붙는다.
func _test_path_bias() -> void:
	var R := d.run
	check(R.path_hardness(&"survive", &"") == 0 and R.path_hardness(&"hunt", &"") == 1 and R.path_hardness(&"defend", &"fog") == 1 and R.path_hardness(&"siege", &"embers") == 2, "갈림길: 어려움 = 사냥·포위 +1, 구역 규칙 +1")
	var good := func(w: PackedFloat32Array) -> float:
		var t: float = 0.0
		for x in w:
			t += x
		return (w[R.path_rewards.find("pulls")] + w[R.path_rewards.find("luck")]) / t
	var g0: float = good.call(R.path_weights(0))
	var g1: float = good.call(R.path_weights(1))
	var g2: float = good.call(R.path_weights(2))
	check(g0 < g1 and g1 < g2, "갈림길: 좋은 보상의 몫이 어려움을 따라 오른다(%.2f < %.2f < %.2f)" % [g0, g1, g2])
	var r := Rules.new(d, 64)
	var n: Array[int] = [0, 0]
	for i in 3000:
		if [&"pulls", &"luck"].has(r.roll_path_reward(0)):
			n[0] += 1
		if [&"pulls", &"luck"].has(r.roll_path_reward(2)):
			n[1] += 1
	check(absf(n[0] / 3000.0 - g0) < 0.04 and absf(n[1] / 3000.0 - g2) < 0.04, "갈림길: 굴린 보상이 가중치를 따른다(%.2f, %.2f)" % [n[0] / 3000.0, n[1] / 3000.0])
	# 실제 길에서도: 어려운 길의 보상이 더 좋다
	var easy: Array[int] = [0, 0]
	var hard: Array[int] = [0, 0]
	for sd in 300:
		var q := Rules.new(d, 1000 + sd)
		q.zone = 3
		for c in q.make_path_cards():
			var h: int = R.path_hardness(c.goal, c.rule)
			var is_good: int = 1 if [&"pulls", &"luck"].has(c.reward) else 0
			if h == 0:
				easy[0] += 1
				easy[1] += is_good
			elif h == 2:
				hard[0] += 1
				hard[1] += is_good
	var ke: float = easy[1] / maxf(1.0, easy[0])
	var kh: float = hard[1] / maxf(1.0, hard[0])
	check(easy[0] > 20 and hard[0] > 20 and kh > ke + 0.15, "갈림길: 가장 어려운 길이 좋은 보상을 더 자주 받는다(쉬움 %.2f, 어려움 %.2f)" % [ke, kh])


func _test_path_rewards() -> void:
	var R := d.run
	var p := _dawn(1)
	p.free_pulls = 0
	p.path_cards[0].reward = &"pulls"
	p.choose_path(0)
	check(p.free_pulls == R.reward_pulls and p.path_reward == &"pulls", "보상: 공짜 뽑기 +2(낮이 열릴 때)")
	var pc := _dawn(1)
	pc.free_pulls = R.max_free_pulls - 1
	pc.path_cards[0].reward = &"pulls"
	pc.choose_path(0)
	check(pc.free_pulls == R.max_free_pulls, "보상: 공짜 뽑기는 모아 둘 수 있는 수까지")
	var h := _dawn(1)
	h.lord.hp = 10.0
	h.path_cards[1].reward = &"heal"
	h.choose_path(1)
	check(is_equal_approx(h.lord.hp, 10.0 + R.reward_heal), "보상: 체력 +60")
	var hc := _dawn(1)
	hc.lord.hp = hc.max_hp() - 5.0
	hc.path_cards[0].reward = &"heal"
	hc.choose_path(0)
	check(is_equal_approx(hc.lord.hp, hc.max_hp()), "보상: 체력은 최대치까지")
	var w := _dawn(1)
	var s0 := w.give(d.sword_by_name("늙은 사자"), 0)
	var s1 := w.give(d.sword_by_name("붉은 이삭"), 1)
	s0.durability = 1.0
	s1.durability = 2.0
	w.path_cards[0].reward = &"whet"
	w.choose_path(0)
	check(s0.durability == s0.max_durability and s1.durability == s1.max_durability, "보상: 두 칸 검 내구 모두 채움")
	var l := _dawn(1)
	var base: float = l.luck()
	l.path_cards[0].reward = &"luck"
	l.choose_path(0)
	check(is_equal_approx(l.luck(), base * R.reward_luck) and is_equal_approx(l.pull_luck(l.hilts[0]) / (R.cursed_luck if l.hilts[0].cursed else 1.0), base * R.reward_luck), "보상: 다음 낮 운 ×1.3(뽑기에 쓰인다)")
	l.start_night()
	l.skip_night()
	l.path_cards[0].reward = &"heal"
	l.choose_path(0)
	check(is_equal_approx(l.day_luck, 1.0), "보상: 운은 그 낮 한 번만")
	var sh := _dawn(1)
	sh.path_cards[0].reward = &"shards"
	sh.choose_path(0)
	var got := Meta.run_shards(sh, d.meta)
	check(sh.path_shards == R.reward_shards and int(got.path) == R.reward_shards and int(got.total) >= R.reward_shards, "보상: 판이 끝날 때 조각 +5(Meta.run_shards의 path)")
	var m := _meta()
	var rec := m.record_run(sh, d.meta)
	check(m.shards == rec.total and int(rec.path) == R.reward_shards, "보상: 조각은 Meta.record_run이 센다")


func _test_events_place() -> void:
	var r := Rules.new(d, 65)
	check(r.event == null, "사건: 1구역에는 없다")
	var kinds := {}
	var ok: Array[bool] = [true]
	for sd in 40:
		var q := _dawn(0, null, 300 + sd)
		var order: Array[String] = []
		q.day_started.connect(func(_z: int) -> void: order.append("day"))
		q.event_placed.connect(func(ev: DayEvent) -> void: order.append(String(ev.kind)))
		q.choose_path(0)
		var ev: DayEvent = q.event
		if ev == null:
			ok[0] = false
			continue
		kinds[ev.kind] = true
		ok[0] = ok[0] and order.size() == 2 and order[0] == "day" and order[1] == String(ev.kind)
		ok[0] = ok[0] and ev.pos.x > 0.0 and ev.pos.y > 0.0 and ev.pos.x < Grid.size.x and ev.pos.y < Grid.size.y and not ev.used
		var cursed: Array = q.hilts.filter(func(h: Hilt) -> bool: return h.cursed)
		if ev.kind == &"cursed":
			ok[0] = ok[0] and cursed.size() == 1 and ev.hilt == cursed[0] and ev.pos == ev.hilt.pos
		else:
			ok[0] = ok[0] and cursed.is_empty() and q.hilts.all(func(h: Hilt) -> bool: return h.pos.distance_to(ev.pos) >= d.run.event_reach + d.run.pull_reach - 0.01)
	check(ok[0], "사건: 2구역부터 낮마다 하나(day_started 뒤 event_placed), 저주받은 손잡이는 손잡이 하나, 나머지는 손잡이와 떨어진 자리")
	check(kinds.size() == 4, "사건: 네 사건이 다 나온다(%s)" % str(kinds.keys()))
	# 쓰지 않으면 밤이 올 때 떠난다
	var q := _ev_day("seer")
	var gone: Array = []
	q.event_gone.connect(func(ev: DayEvent) -> void: gone.append(ev))
	var ev0: DayEvent = q.event
	q.start_night()
	check(q.event == null and gone == [ev0], "사건: 쓰지 않으면 밤이 오며 사라진다(event_gone)")


func _test_event_smith() -> void:
	var R := d.run
	var r := _ev_day("smith")
	var s := r.give(d.sword_by_name("늙은 사자"), 0)
	s.durability = 3.0
	var dmg0: float = r.powers.stats().dmg
	r.lord.hp = 50.0
	var used: Array = []
	var gone: Array = []
	r.event_used.connect(func(ev: DayEvent, res: Dictionary) -> void: used.append([ev.kind, res]))
	r.event_gone.connect(func(ev: DayEvent) -> void: gone.append(ev.kind))
	r.lord.pos = r.event.pos + Vector2(R.event_reach + 0.3, 0.0)
	check(r.near_event() == null, "대장장이: 멀면 쓸 수 없다")
	r.lord.pos = r.event.pos + Vector2(0.5, 0.0)
	check(r.near_event() == r.event, "대장장이: 가까우면 E로 쓴다")
	_press_e(r)
	check(is_equal_approx(r.lord.hp, 50.0 - R.smith_cost) and s.durability == s.max_durability, "대장장이: 체력 15를 내고 쥔 검의 내구를 다 채운다")
	check(is_equal_approx(s.night_bonus, 1.0 + R.smith_damage) and is_equal_approx(r.powers.stats().dmg, dmg0 * (1.0 + R.smith_damage)), "대장장이: 이번 밤 그 검의 피해 +15%")
	check(used.size() == 1 and used[0][0] == &"smith" and gone == [&"smith"] and r.event.used and r.pull_hilt == null, "대장장이: event_used, event_gone")
	_press_e(r)
	check(is_equal_approx(r.lord.hp, 50.0 - R.smith_cost) and used.size() == 1 and r.near_event() == null, "대장장이: 한 번만 쓴다")
	r.start_night()
	check(is_equal_approx(s.night_bonus, 1.0 + R.smith_damage), "대장장이: (밤 동안 남는다)")
	r.skip_night()
	check(is_equal_approx(s.night_bonus, 1.0), "대장장이: 새벽에 피해 보너스가 사라진다")
	# 못 쓰는 때: 체력이 모자람, 쥔 검이 없음
	var low := _ev_day("smith")
	low.give(d.sword_by_name("늙은 사자"), 0)
	low.lord.hp = R.smith_cost
	var why: Array[String] = []
	low.pull_refused.connect(func(t: String) -> void: why.append(t))
	low.lord.pos = low.event.pos
	_press_e(low)
	check(why.size() == 1 and not low.event.used and is_equal_approx(low.lord.hp, R.smith_cost), "대장장이: 체력이 모자라면 못 쓴다")
	var bare := _ev_day("smith")
	bare.slots = [null, null]
	bare.lord.pos = bare.event.pos
	_press_e(bare)
	check(not bare.event.used, "대장장이: 쥔 검이 없으면 못 쓴다")


func _test_event_cursed() -> void:
	var R := d.run
	var r := _ev_day("cursed")
	var ev: DayEvent = r.event
	var h: Hilt = ev.hilt
	check(h != null and h.cursed and r.near_event() == null, "저주받은 손잡이: 낮의 손잡이 하나(E는 뽑기)")
	var normal: Hilt = null
	for x in r.hilts:
		if not x.cursed:
			normal = x
			break
	check(is_equal_approx(r.pull_luck(h), r.luck() * r.omen_luck(h.omen) * R.cursed_luck) and is_equal_approx(r.pull_luck(normal), r.luck() * r.omen_luck(normal.omen)), "저주받은 손잡이: 운 ×2(조짐 배수도 그대로 곱한다)")
	r.lord.hp = 3.0
	r.free_pulls = 1
	var used: Array = []
	r.event_used.connect(func(e: DayEvent, res: Dictionary) -> void: used.append(res))
	var gone: Array = []
	r.event_gone.connect(func(e: DayEvent) -> void: gone.append(e))
	r.lord.pos = h.pos + Vector2(0.3, 0.0)
	_press_e(r)
	check(r.pull_hilt == h, "저주받은 손잡이: 체력이 모자라도 뽑는다")
	for t in 300:
		if r.pull_hilt == null:
			break
		r.step()
	var s: Sword = r.slots[0] if r.slots[0] else r.pending
	check(s != null and is_equal_approx(r.lord.hp, 3.0) and r.free_pulls == 1, "저주받은 손잡이: 체력도 공짜 뽑기도 들지 않는다")
	if s:
		var full: float = Sword.new(s.data, d).max_durability
		check(not s.breakable() or (is_equal_approx(s.max_durability, maxf(1.0, roundf(full * R.cursed_durability))) and s.durability == s.max_durability), "저주받은 손잡이: 이 검의 최대 내구 절반(%s → %s)" % [full, s.max_durability])
	check(used.size() == 1 and used[0].sword == s and gone == [ev] and ev.used and r.cursed_night and h.gone, "저주받은 손잡이: 뽑으면 쓴 것(event_used, event_gone), 이번 밤 저주")
	# 이번 밤 적 +25%: 새로 나오는 적의 체력과 피해(나오는 빠르기는 그대로)
	var a := _ev_day("cursed", 66)
	var b := _ev_day("cursed", 66)
	a.cursed_night = true
	for q in [a, b]:
		q.start_night()
		q.enemies.clear()
		for t in 60:
			q.step()
			if not q.enemies.is_empty():
				break
	var ea: Enemy = a.enemies[0] if a.enemies.size() == 1 else null
	var eb: Enemy = b.enemies[0] if b.enemies.size() == 1 else null
	check(ea != null and eb != null and ea.data == eb.data and is_equal_approx(a._spawn_t, b._spawn_t), "저주받은 손잡이: 적이 나오는 때와 종류는 그대로")
	if ea and eb:
		check(is_equal_approx(ea.max_hp, eb.max_hp * R.cursed_enemies) and is_equal_approx(ea.hp, ea.max_hp) and is_equal_approx(ea.damage, eb.damage * R.cursed_enemies), "저주받은 손잡이: 이번 밤 적의 체력·피해 ×1.25(%.1f/%.1f, %.1f/%.1f)" % [ea.max_hp, eb.max_hp, ea.damage, eb.damage])
	var el_a := a._spawn_elite()
	var el_b := b._spawn_elite()
	check(el_a.data == el_b.data and is_equal_approx(el_a.max_hp, el_b.max_hp * R.cursed_enemies) and is_equal_approx(el_a.damage, el_b.damage * R.cursed_enemies), "저주받은 손잡이: 정예도 ×1.25(정예 배수 위에 곱한다)")
	a.skip_night()
	a.choose_path(0)
	check(not a.cursed_night, "저주받은 손잡이: 저주는 그 밤만")
	# 늘 부러지지 않는 검은 내구가 없다
	var u := _ev_day("cursed")
	var ud: SwordData = null
	for sd in d.swords:
		if sd.unbreakable:
			ud = sd
			break
	if ud:
		var us := Sword.new(ud, d)
		u._cursed_pulled(u.event.hilt, us)
		check(not us.breakable() and us.max_durability < 0.0 and u.cursed_night, "저주받은 손잡이: 부러지지 않는 검이면 내구는 그대로(%s)" % ud.display_name)


func _test_event_pilgrim() -> void:
	var R := d.run
	var r := _ev_day("pilgrim")
	var a := r.give(d.sword_by_name("늙은 사자"), 0)
	var b := r.give(d.sword_by_name("붉은 이삭"), 1)
	r.active = 0
	r.lord.hp = 20.0
	r.free_pulls = 0
	var res: Array = []
	r.event_used.connect(func(_e: DayEvent, x: Dictionary) -> void: res.append(x))
	check(r.pilgrim_slot() == 1, "순례자: 쥐지 않은 칸의 검을 바친다")
	r.lord.pos = r.event.pos
	_press_e(r)
	check(r.slots[0] == a and r.slots[1] == null and r.active == 0, "순례자: 그 칸의 검이 사라진다")
	check(is_equal_approx(r.lord.hp, minf(r.max_hp(), 20.0 + r.max_hp() * R.pilgrim_heal)) and r.free_pulls == R.pilgrim_free, "순례자: 체력을 최대치의 50%만큼, 공짜 뽑기 +1")
	check(res.size() == 1 and res[0].sword == b and r.event.used, "순례자: event_used(바친 검)")
	_press_e(r)
	check(r.slots[0] == a and res.size() == 1, "순례자: 한 번만")
	var one := _ev_day("pilgrim")
	var c := one.give(d.sword_by_name("늙은 사자"), 0)
	one.slots[1] = null
	one.active = 0
	one.lord.pos = one.event.pos
	check(one.pilgrim_slot() == 0, "순례자: 한 자루뿐이면 쥔 검")
	_press_e(one)
	check(one.slots[0] == null and one.slots[1] == null and one.current() == null and c != null, "순례자: 쥔 검을 바치면 맨손")
	var none := _ev_day("pilgrim")
	none.slots = [null, null]
	none.lord.pos = none.event.pos
	_press_e(none)
	check(not none.event.used, "순례자: 바칠 검이 없으면 못 쓴다")


func _test_event_seer() -> void:
	var R := d.run
	var r := _ev_day("seer")
	r.lord.hp = 40.0
	var used: Array = []
	r.event_used.connect(func(e: DayEvent, _x: Dictionary) -> void: used.append(e.kind))
	var shown: Array = [0]
	r.omens_revealed.connect(func() -> void: shown[0] += 1)
	var wrong: int = 0
	for h in r.hilts:
		wrong += 1 if h.seen_omen() != h.omen else 0
	check(not r.seer_used_today and r.hilts.all(func(h: Hilt) -> bool: return not h.revealed and h.seen_omen() == h.shown_omen), "점쟁이: 쓰기 전에는 조짐을 모른다(겉 조짐, 틀린 것 %d개)" % wrong)
	r.lord.pos = r.event.pos
	_press_e(r)
	check(is_equal_approx(r.lord.hp, 40.0 - R.seer_cost) and r.seer_used_today and used == [&"seer"], "점쟁이: 체력 10을 내면 오늘 참된 조짐(seer_used_today, event_used)")
	check(shown[0] == 1 and r.hilts.all(func(h: Hilt) -> bool: return h.revealed and h.seen_omen() == h.omen), "점쟁이: 오늘 손잡이가 모두 참된 조짐을 보인다(omens_revealed)")
	_press_e(r)
	check(is_equal_approx(r.lord.hp, 40.0 - R.seer_cost) and shown[0] == 1, "점쟁이: 한 번만")
	r.start_night()
	r.skip_night()
	r.choose_path(0)
	check(not r.seer_used_today and r.hilts.all(func(h: Hilt) -> bool: return not h.revealed), "점쟁이: 그 낮만(다음 낮 손잡이는 다시 모른다)")
	var low := _ev_day("seer")
	low.lord.hp = R.seer_cost
	low.lord.pos = low.event.pos
	_press_e(low)
	check(not low.event.used and not low.seer_used_today, "점쟁이: 체력이 모자라면 못 쓴다")


## 같은 시드·같은 입력·같은 길이면 갈림길·사건·뽑기가 같다.
func _test_path_replay() -> void:
	var hashes: Array[int] = []
	var logs: Array[String] = []
	for run_i in 2:
		var r := Rules.new(d, 67)
		r.debug_god = true
		var text: Array[String] = [""]
		r.path_offered.connect(func(c: Array) -> void: text[0] += "p%d:%s " % [r.tick, str(c)])
		r.event_placed.connect(func(ev: DayEvent) -> void: text[0] += "e%d:%s@%s " % [r.tick, ev.kind, ev.pos])
		r.event_used.connect(func(ev: DayEvent, _x: Dictionary) -> void: text[0] += "u%d:%s " % [r.tick, ev.kind])
		r.sword_pulled.connect(func(s: Sword) -> void: text[0] += "s%d:%d " % [r.tick, s.data.id])
		var rec := RandomNumberGenerator.new()
		rec.seed = 5
		for day in 4:
			if r.zone > 0 and r.event:
				r.lord.pos = r.event.pos
				_press_e(r)
			for k in 240:
				var i := _inp(Vector2(rec.randf_range(-1, 1), rec.randf_range(-1, 1)))
				i.pull = rec.randf() < 0.2
				r.step(i)
				if r.pending:
					r.choose(rec.randi_range(-1, 1))
			r.start_night()
			for k in 300:
				r.step(_inp(Vector2(rec.randf_range(-1, 1), rec.randf_range(-1, 1)), rec.randf() < 0.4))
			r.skip_night()
			r.choose_path(rec.randi_range(0, 1))
		hashes.append(r.state_hash())
		logs.append(text[0])
	check(hashes[0] == hashes[1] and logs[0] == logs[1] and logs[0].contains("p") and logs[0].contains("e"), "갈림길·사건: 같은 시드·같은 입력이면 결과가 같다(state_hash)")


# ---------------------------------------------------------------- 14단계: 뽑기 손맛

## 손잡이 조짐: 숨은 조짐의 비율, 겉 조짐이 맞는 비율.
func _test_omens() -> void:
	var R := d.run
	var n: Array[int] = [0, 0, 0, 0]
	var same: Array[int] = [0, 0, 0, 0]
	var near := true
	var total: int = 0
	for sd in 500:
		var r := Rules.new(d, 1000 + sd)
		for h in r.hilts:
			n[h.omen] += 1
			same[h.omen] += 1 if h.shown_omen == h.omen else 0
			near = near and absi(h.shown_omen - h.omen) <= 1 and h.shown_omen >= 0 and h.shown_omen <= 3 and not h.revealed
			total += 1
	var wsum: float = 0.0
	for w in R.omen_weights:
		wsum += w
	var ok := true
	var text: Array[String] = []
	for o in 4:
		var p: float = float(n[o]) / total
		ok = ok and absf(p - R.omen_weights[o] / wsum) < 0.02
		text.append("%.3f" % p)
	check(ok, "조짐: 숨은 조짐 0~3이 30/45/20/5%% 비율로 나온다(%s, %d자루)" % [", ".join(text), total])
	# 1·2는 위아래로 다 갈 수 있어 75%, 0·3은 끝에 붙어 87.5%
	var a1: float = float(same[1] + same[2]) / float(n[1] + n[2])
	var a0: float = float(same[0] + same[3]) / float(n[0] + n[3])
	var all: float = float(same[0] + same[1] + same[2] + same[3]) / total
	check(near and absf(a1 - R.omen_shown_true) < 0.03 and absf(a0 - (R.omen_shown_true + (1.0 - R.omen_shown_true) * 0.5)) < 0.04, "조짐: 겉 조짐은 75%% 맞고 아니면 한 단계 위나 아래(1·2: %.3f, 0·3: %.3f, 모두 %.3f)" % [a1, a0, all])
	# 같은 시드면 같은 조짐
	var x := Rules.new(d, 77)
	var y := Rules.new(d, 77)
	var eq := true
	for i in x.hilts.size():
		eq = eq and x.hilts[i].omen == y.hilts[i].omen and x.hilts[i].shown_omen == y.hilts[i].shown_omen
	check(eq, "조짐: 같은 시드면 같은 조짐")


## 조짐은 그 손잡이를 뽑을 때 운에 곱한다.
func _test_omen_luck() -> void:
	var R := d.run
	var r := Rules.new(d, 21)
	var ok := true
	for h in r.hilts:
		ok = ok and is_equal_approx(r.pull_luck(h), r.luck() * R.omen_luck[h.omen])
	check(ok and is_equal_approx(r.omen_luck(0), 0.7) and is_equal_approx(r.omen_luck(3), 2.0), "조짐: 뽑을 때 운 × 0.7/1.0/1.4/2.0")
	var mean: float = 0.0
	var wsum: float = 0.0
	for o in 4:
		mean += R.omen_weights[o] * R.omen_luck[o]
		wsum += R.omen_weights[o]
	check(absf(mean / wsum - 1.0) < 0.05, "조짐: 운 배수의 평균이 약 1(%.3f)" % (mean / wsum))
	# 뽑기가 그 배수를 쓴다: 배수 0이면 늘 흔함, 아주 크면 늘 가장 높은 등급
	for big in [false, true]:
		var g := _run_data({"omen_luck": PackedFloat32Array([1e7, 1e7, 1e7, 1e7] if big else [0, 0, 0, 0])})
		var q := Rules.new(g, 22)
		q.debug_god = true
		var grades: Array[int] = []
		q.pull_started.connect(func(_h: Hilt, gr: int) -> void: grades.append(gr))
		for k in 6:
			q.lord.hp = 100.0
			q.slots = [null, null]
			_pull_once(q)
		var top: int = d.grades.odds.size() - 1
		check(grades.size() == 6 and grades.all(func(x: int) -> bool: return x == (top if big else 0)), "조짐: 뽑기 등급이 조짐 배수를 쓴다(%s)" % str(grades))


## 버팀마다 누르는 방식: good = 창 가운데, late = 가운데 + 0.06초, early = 창이 열리기 전, spam = 틱마다, none = 안 누름.
## 돌려주는 것: 뽑는 데 걸린 틱 수.
func _pull_timed(r: Rules, mode: String, only: Array = []) -> int:
	var h := r.nearest_hilt(100.0)
	_stand_at(r, h)
	var i := LordInput.new()
	i.pull = true
	r.step(i)
	var ticks: int = 0
	while r.pull_hilt != null and ticks < 300:
		var p := LordInput.new()
		var at: float = r.pull_t + r.dt * 0.5
		var open: bool = r.pull_win_step > r.pull_judged
		var c: float = (r.pull_win_open + r.pull_win_close) * 0.5
		var want: bool = only.is_empty() or only.has(r.pull_win_step)
		match mode:
			"good":
				p.pull_press = open and want and absf(at - c) <= r.dt * 0.5 + 0.0001
			"late":
				p.pull_press = open and want and at >= c + 0.06 - r.dt * 0.5 and at < c + 0.06 + r.dt * 0.5
			"early":
				p.pull_press = open and want and at < r.pull_win_open - 0.05
			"spam":
				p.pull_press = true
		r.step(p)
		ticks += 1
	return ticks


func _test_pull_timing() -> void:
	var R := d.run
	var r := Rules.new(d, 5)
	r.debug_grade = 2
	r.lord.hp = 50.0
	var win: Array = []
	var good: Array = []
	var perf: Array = [0]
	var steps: Array = []
	var got: Array[Sword] = []
	r.pull_window.connect(func(_h: Hilt, o: float, c: float) -> void: win.append([r.pull_t, o, c]))
	r.pull_good.connect(func(_h: Hilt, k: int) -> void: good.append([k, r.pull_t]))
	r.pull_perfect.connect(func(_h: Hilt) -> void: perf[0] += 1)
	r.pull_step.connect(func(_h: Hilt, k: int) -> void: steps.append(k))
	r.sword_pulled.connect(func(s: Sword) -> void: got.append(s))
	var ticks: int = _pull_timed(r, "good")
	check(win.size() == 2 and is_equal_approx(win[0][0], 0.0), "타이밍: 버팀마다 창 하나, 첫 창은 뽑기 시작에(%s)" % str(win))
	var ok := win.size() == 2
	for k in win.size():
		ok = ok and is_equal_approx(win[k][1], R.pull_step * (k + 1) - R.pull_window) and is_equal_approx(win[k][2], R.pull_step * (k + 1) + R.pull_window)
	check(ok, "타이밍: 창은 그 버팀이 저절로 끝나는 때 ± 0.08초")
	check(good.size() == 2 and good[0][0] == 1 and good[1][0] == 2 and steps == [1, 2], "타이밍: 가운데에 누르면 제대로 당김(pull_good 1, 2)")
	check(good.size() == 2 and good[0][1] >= R.pull_step - 0.0001 and good[1][1] >= R.pull_step * 2 - 0.0001, "타이밍: 제대로 당기면 그 버팀이 끝난다(그 때까지 당긴다)")
	check(perf[0] == 1 and r.pull_all_good, "타이밍: 버팀을 모두 제대로 당기면 pull_perfect")
	check(is_equal_approx(r.lord.hp, 50.0 - R.pull_cost + 2.0 * R.pull_good_refund), "타이밍: 제대로 당길 때마다 체력 1을 돌려받는다(%.1f)" % r.lord.hp)
	var slow := Rules.new(d, 5)
	slow.debug_grade = 2
	var none_ticks: int = _pull_timed(slow, "none")
	check(ticks <= none_ticks, "타이밍: 제대로 당겨도 늦어지지 않는다(%d틱, 안 누르면 %d틱)" % [ticks, none_ticks])
	if got.size() == 1:
		var s: Sword = got[0]
		var base: float = Sword.new(s.data, d).max_durability
		check(not s.breakable() or (is_equal_approx(s.max_durability, maxf(base + 1.0, roundf(base * (1.0 + R.pull_perfect_durability)))) and s.durability == s.max_durability), "타이밍: 모두 제대로면 그 검의 최대 내구 +10%%(%s → %s)" % [base, s.max_durability])
	else:
		check(false, "타이밍: 검이 하나 나온다")
	# 늦게(가운데 + 0.06초) 눌러도 창 안이면 친다
	var l := Rules.new(d, 5)
	l.debug_grade = 3
	l.lord.hp = 50.0
	var lg: Array = [0]
	var lp: Array = [0]
	l.pull_good.connect(func(_h: Hilt, _k: int) -> void: lg[0] += 1)
	l.pull_perfect.connect(func(_h: Hilt) -> void: lp[0] += 1)
	_pull_timed(l, "late")
	check(lg[0] == 3 and lp[0] == 1 and is_equal_approx(l.lord.hp, 50.0 - R.pull_cost + 3.0), "타이밍: 창 안이면 늦게 눌러도 제대로 당김(3번, 모두 제대로)")
	# 한 번만 제대로: 돌려받기는 1, 모두 제대로는 아니다
	var o := Rules.new(d, 5)
	o.debug_grade = 2
	o.lord.hp = 50.0
	var op: Array = [0]
	o.pull_perfect.connect(func(_h: Hilt) -> void: op[0] += 1)
	var og: Array = []
	o.sword_pulled.connect(func(s: Sword) -> void: og.append(s))
	_pull_timed(o, "good", [2])
	check(op[0] == 0 and o.pull_goods == 1 and is_equal_approx(o.lord.hp, 50.0 - R.pull_cost + 1.0), "타이밍: 하나만 맞히면 체력 1만, 모두 제대로는 아니다")
	if og.size() == 1:
		check(is_equal_approx(og[0].max_durability, Sword.new(og[0].data, d).max_durability), "타이밍: 모두 제대로가 아니면 내구 보너스 없음")
	# 버팀이 하나뿐이면 모두 제대로가 없다(최소 2번)
	var one := Rules.new(d, 5)
	one.debug_grade = 1
	one.lord.hp = 50.0
	var p1: Array = [0]
	one.pull_perfect.connect(func(_h: Hilt) -> void: p1[0] += 1)
	_pull_timed(one, "good")
	check(one.pull_goods == 1 and p1[0] == 0 and not one.pull_all_good, "타이밍: 버팀이 한 번이면 모두 제대로는 없다(최소 2번)")
	# 흔함은 버티지 않으니 창도 없다
	var zero := Rules.new(d, 5)
	zero.debug_grade = 0
	var w0: Array = [0]
	zero.pull_window.connect(func(_h: Hilt, _o: float, _c: float) -> void: w0[0] += 1)
	_pull_timed(zero, "spam")
	check(w0[0] == 0 and zero.pull_goods == 0, "타이밍: 흔함은 창이 없다")
	# 가득 찬 체력: 뽑기 값과 함께 셈해서 버리지 않는다
	var full := Rules.new(d, 5)
	full.debug_grade = 2
	_pull_timed(full, "good")
	check(is_equal_approx(full.lord.hp, full.max_hp() - R.pull_cost + 2.0), "타이밍: 체력이 가득 차 있어도 돌려받기를 버리지 않는다(%.1f)" % full.lord.hp)
	# 공짜 뽑기: 체력은 쓰지 않고 돌려받기만(최대치까지)
	var fr := Rules.new(d, 5)
	fr.debug_grade = 2
	fr.free_pulls = 1
	fr.lord.hp = 40.0
	_pull_timed(fr, "good")
	check(fr.free_pulls == 0 and is_equal_approx(fr.lord.hp, 42.0), "타이밍: 공짜 뽑기도 체력 1씩 돌려받는다")


## 못 맞혀도 손해는 없고, 버팀마다 한 번만 판정한다.
func _test_pull_timing_miss() -> void:
	var R := d.run
	var base := Rules.new(d, 5)
	base.debug_grade = 3
	base.lord.hp = 50.0
	var bt: int = _pull_timed(base, "none")
	var bs: Sword = base.slots[0]
	for mode in ["none", "early", "spam"]:
		var r := Rules.new(d, 5)
		r.debug_grade = 3
		r.lord.hp = 50.0
		var miss: Array = []
		var good: Array = [0]
		var win: Array = [0]
		r.pull_miss.connect(func(_h: Hilt, k: int) -> void: miss.append(k))
		r.pull_good.connect(func(_h: Hilt, _k: int) -> void: good[0] += 1)
		r.pull_window.connect(func(_h: Hilt, _o: float, _c: float) -> void: win[0] += 1)
		var t: int = _pull_timed(r, mode)
		var s: Sword = r.slots[0]
		check(good[0] == 0 and miss == [1, 2, 3] and win[0] == 3, "타이밍(%s): 놓치면 pull_miss, 버팀마다 한 번만(%s)" % [mode, str(miss)])
		check(t == bt and is_equal_approx(r.lord.hp, 50.0 - R.pull_cost) and s != null and bs != null and s.data == bs.data and s.max_durability == bs.max_durability and r.state_hash() == base.state_hash(), "타이밍(%s): 못 맞혀도 손해 없음(시간·체력·검·확률 같다)" % mode)
	# 일찍 누르면 그 창은 끝까지 닫히지 않은 채로 놓친 것이고, 다음 창은 그 창이 닫힌 뒤에 열린다
	var e := Rules.new(d, 5)
	e.debug_grade = 2
	var at: Array = []
	e.pull_window.connect(func(_h: Hilt, _o: float, _c: float) -> void: at.append(e.pull_t))
	_pull_timed(e, "early")
	check(at.size() == 2 and at[1] > R.pull_step + R.pull_window - 0.0001, "타이밍: 일찍 눌러 놓치면 다음 창은 앞 창이 닫힌 뒤(%s)" % str(at))


## 같은 시드·같은 누름이면 같다(조짐, 판정, 돌려받기).
func _test_pull_timing_replay() -> void:
	var hashes: Array[int] = []
	var logs: Array[String] = []
	for run_i in 2:
		var r := Rules.new(d, 88)
		r.debug_god = true
		var text: Array[String] = [""]
		r.pull_window.connect(func(_h: Hilt, o: float, _c: float) -> void: text[0] += "w%d:%.3f " % [r.tick, o])
		r.pull_good.connect(func(_h: Hilt, k: int) -> void: text[0] += "g%d:%d " % [r.tick, k])
		r.pull_miss.connect(func(_h: Hilt, k: int) -> void: text[0] += "m%d:%d " % [r.tick, k])
		r.pull_perfect.connect(func(_h: Hilt) -> void: text[0] += "p%d " % r.tick)
		r.sword_pulled.connect(func(s: Sword) -> void: text[0] += "s%d:%d:%s " % [r.tick, s.data.id, s.max_durability])
		var rec := RandomNumberGenerator.new()
		rec.seed = 9
		for k in 900:
			# 가까운 손잡이 쪽으로 걸어가며(조금 흔들리게) 뽑고, 뽑는 동안 아무 때나 누른다
			var h := r.nearest_hilt(100.0)
			var to: Vector2 = (h.pos - r.lord.pos).normalized() if h else Vector2.ZERO
			var i := _inp(to + Vector2(rec.randf_range(-0.4, 0.4), rec.randf_range(-0.4, 0.4)))
			i.pull = rec.randf() < 0.3
			i.pull_press = rec.randf() < 0.12
			r.step(i)
			if r.pending:
				r.choose(rec.randi_range(-1, 1))
		hashes.append(r.state_hash())
		logs.append(text[0])
	check(hashes[0] == hashes[1] and logs[0] == logs[1] and logs[0].contains("w") and logs[0].contains("s"), "타이밍: 같은 시드·같은 누름이면 결과가 같다(state_hash)")
