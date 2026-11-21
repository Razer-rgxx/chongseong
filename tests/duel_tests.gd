extends RefCounted
## 21단계 1대1 결투 테스트(docs/duel.md). run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/duel_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_data()
	_start()
	_hit()
	_powers_off()
	_dash_invuln()
	_time_up()
	_best_of_three()
	_draws()
	_push_apart()
	_hook_foe()
	_parry_foe()
	_replay()
	_input_bytes()
	_meta()
	_single_mode()
	Grid.size = Vector2i(34, 22)


func _pat(moves: Array) -> PatternData:
	var p := PatternData.new()
	p.moves = PackedStringArray(moves)
	return p


func _sword(name: String, moves: Array = ["sweep"]) -> Sword:
	var s := Sword.new(d.sword_by_name(name), d)
	s.pattern = _pat(moves)
	return s


## 두 영주가 싸우는 판(싸움 단계까지 넘긴다).
func _duel(seed_value: int = 1, a: Sword = null, b: Sword = null) -> Rules:
	var r := Rules.new(d, seed_value)
	r.start_duel(a if a != null else _sword("녹슨 장검"), b if b != null else _sword("녹슨 장검"))
	_to_fight(r)
	return r


func _to_fight(r: Rules) -> void:
	for t in 400:
		if r.duel_phase == Rules.DUEL_FIGHT:
			return
		r.step_duel()


func _inp(move: Vector2 = Vector2.ZERO, attack: bool = false, dash: bool = false) -> LordInput:
	var i := LordInput.new()
	i.move = move
	i.attack = attack
	i.dash = dash
	return i


## 두 영주를 가까이 세운다(0이 왼쪽, 1이 오른쪽).
func _face_off(r: Rules, gap: float) -> void:
	r.lords[0].pos = Vector2(17.0, 11.0)
	r.lords[1].pos = Vector2(17.0 + gap, 11.0)
	r.lords[0].prev_pos = r.lords[0].pos
	r.lords[1].prev_pos = r.lords[1].pos


func _data() -> void:
	var D := d.duel
	check.call(D != null and D.hp == 200.0 and D.round_time == 90.0 and D.rounds_to_win == 2 and D.break_time == 3.0, "결투 수치(data/duel.tres): 체력 200(2026-11-21 피해를 내리며 같이), 한 판 90초, 2선승, 쉼 3초")


func _start() -> void:
	var r := Rules.new(d, 1)
	var starts: Array[int] = []
	r.duel_round_started.connect(func(n: int) -> void: starts.append(n))
	r.start_duel(_sword("녹슨 장검"), null)
	var D := d.duel
	check.call(r.duel and r.lords.size() == 2 and r.lords[0] == r.lord, "결투 모드: 영주 둘, lord는 0번")
	check.call(r.phase == Rules.Phase.NIGHT and r.enemies.size() == 1 and r.hilts.is_empty(), "결투에는 낮밤·꽂힌 검이 없다")
	check.call(r.lords[0].hp == D.hp and r.lords[1].hp == D.hp and r.max_hp() == D.hp, "두 영주의 체력이 같다(300)")
	check.call(r.lords[0].pos == Grid.middle() + Vector2(-D.start_gap, 0.0) and r.lords[1].pos == Grid.middle() + Vector2(D.start_gap, 0.0), "가운데에서 좌우로 %d칸씩" % int(D.start_gap))
	check.call(absf(angle_difference(r.lords[0].face, 0.0)) < 0.001 and absf(angle_difference(r.lords[1].face, PI)) < 0.001, "서로 마주 본다")
	check.call(r.seat_sword(0) != null and r.seat_sword(1) == null, "1P는 검, 2P는 맨손")
	check.call(not r.seat_sword(0).breakable(), "결투의 검은 부러지지 않는다")
	check.call(r.duel_phase == Rules.DUEL_READY and r.duel_round == 1 and starts == [1], "첫 판은 시작 전 서 있기부터")
	var p0: Vector2 = r.lords[0].pos
	r.step_duel(_inp(Vector2.RIGHT), null)
	check.call(r.lords[0].pos == p0, "시작 전에는 입력이 먹지 않는다")
	for t in roundi(D.ready_time / r.dt) + 2:
		r.step_duel()
	check.call(r.duel_phase == Rules.DUEL_FIGHT, "서 있는 시간이 지나면 싸움")
	r.step_duel(_inp(Vector2.RIGHT), null)
	check.call(r.lords[0].pos.x > p0.x, "싸움이 시작되면 걷는다")
	check.call(r.cur_seat == 0 and r.lord == r.lords[0], "틱이 끝나면 규칙의 lord는 늘 0번")


func _hit() -> void:
	var r := _duel(1)
	_face_off(r, 1.0)
	var s: Sword = r.seat_sword(0)
	var hp0: float = r.lords[1].hp
	var got: Array = []
	r.duelist_hurt.connect(func(seat: int, dmg: float, _b: bool) -> void: got.append([seat, dmg]))
	r.step_duel(_inp(Vector2.ZERO, true), null)
	var lost: float = hp0 - r.lords[1].hp
	var want: float = d.lord.damage * s.form.damage * d.grades.damage_mult[s.grade] * s.bonus * d.move(&"sweep").damage
	check.call(lost > 0.0 and is_equal_approx(lost, want), "1P의 좌클릭이 2P를 맞힌다(%.1f, 바란 값 %.1f)" % [lost, want])
	check.call(r.lords[0].hp == d.duel.hp and got.size() == 1 and got[0][0] == 1, "맞은 쪽만 깎이고 신호는 맞은 영주(1)를 알린다")
	check.call(r.freeze > 0, "맞히면 히트스톱")
	r.freeze = 0
	r.step_duel()
	check.call(r.lords[1].push.x > 0.0 or r.lords[1].pos.x > 18.0, "맞은 영주는 뒤로 밀려난다")
	# 맞은 뒤 무적 동안은 또 맞지 않는다
	var again: float = r.lords[1].hp
	r.freeze = 0
	r.lords[0].cooldown = 0.0
	r.lords[0].combo_timer = 0.0
	_face_off(r, 1.0)
	r.step_duel(_inp(Vector2.ZERO, true), null)
	check.call(r.lords[1].invuln > 0.0 and r.lords[1].hp == again, "맞은 뒤 무적 동안은 피해가 없다")
	# 2P가 1P를 맞힌다(맞는 쪽이 바뀌어도 같다)
	var r2 := _duel(1)
	_face_off(r2, 1.0)
	var h1: float = r2.lords[0].hp
	r2.step_duel(null, _inp(Vector2.ZERO, true))
	check.call(h1 - r2.lords[0].hp > 0.0 and r2.lords[1].hp == d.duel.hp, "2P의 좌클릭은 1P를 맞힌다")
	# 겨눈 쪽이 아니면 안 맞는다
	var r3 := _duel(1)
	_face_off(r3, 1.0)
	r3.lords[1].pos = Vector2(17.0, 15.0)
	r3.step_duel(_inp(Vector2.ZERO, true), null)
	check.call(r3.lords[1].hp == d.duel.hp, "멀리 있으면 안 맞는다")


func _powers_off() -> void:
	# 각인 '날'을 크게 붙여도 결투에서는 듣지 않는다
	var plain := _sword("녹슨 장검")
	var inked := _sword("녹슨 장검")
	inked.ins["날"] = 500.0
	var a := _duel(1, plain)
	var b := _duel(1, inked)
	_face_off(a, 1.0)
	_face_off(b, 1.0)
	a.step_duel(_inp(Vector2.ZERO, true), null)
	b.step_duel(_inp(Vector2.ZERO, true), null)
	check.call(a.powers.off and b.powers.off and b._seats[1].powers.off, "결투에서 Powers는 꺼져 있다")
	check.call(b.powers.ins("날") == 0.0 and not b.powers.using("녹슨 장검"), "각인과 고유 능력은 0 / false")
	check.call(is_equal_approx(a.lords[1].hp, b.lords[1].hp) and a.lords[1].hp < d.duel.hp, "각인이 붙어도 피해가 같다")
	# 처음이자 마지막 칼은 밤에 모든 적을 한 번에 쓰러뜨리지만 결투에서는 아무 일도 없다
	var one := _duel(2, _sword("처음이자 마지막 칼", ["sweep"]))
	_face_off(one, 3.0)
	var effects: Array = []
	one.effect.connect(func(k: StringName, _at: Vector2, _i: Dictionary) -> void: effects.append(k))
	one.step_duel(_inp(Vector2.ZERO, true), null)
	check.call(effects.is_empty() and one.lords[1].hp == d.duel.hp, "고유 능력은 결투에서 일을 내지 않는다(신호 %d)" % effects.size())
	# 속성은 피해만: 불꽃 방식으로 베도 영주에게 불이 붙지 않는다
	var fire := _sword("녹슨 장검", ["sweep"])
	fire.pattern.element = &"fire"
	var f := _duel(3, fire)
	_face_off(f, 1.0)
	f.step_duel(_inp(Vector2.ZERO, true), null)
	var hp: float = f.lords[1].hp
	for t in 90:
		f.freeze = 0
		f.step_duel()
	check.call(hp < d.duel.hp and f.lords[1].hp == hp, "속성 방식도 피해만 들어가고 상태 효과는 안 건다")


func _dash_invuln() -> void:
	var r := _duel(1)
	_face_off(r, 1.0)
	r.step_duel(null, _inp(Vector2.RIGHT, false, true))
	check.call(r.lords[1].dash > 0.0 and r.lords[1].invuln > 0.0, "구르면 잠깐 무적")
	_face_off(r, 1.0)
	r.lords[1].pos = Vector2(18.0, 11.0)
	r.step_duel(_inp(Vector2.ZERO, true), null)
	check.call(r.lords[1].hp == d.duel.hp, "구르는 동안에는 맞지 않는다")


func _time_up() -> void:
	var ended: Array = []
	var r := _duel(1)
	r.duel_round_ended.connect(func(w: int) -> void: ended.append(w))
	r.lords[0].hp = 100.0
	r.lords[1].hp = 200.0
	r.duel_left = r.dt * 0.5
	r.step_duel()
	check.call(ended == [1] and r.duel_wins == [0, 1] and r.duel_phase == Rules.DUEL_BETWEEN, "시간이 다 되면 남은 체력이 많은 쪽이 판을 이긴다")
	var q := _duel(1)
	var ended2: Array = []
	q.duel_round_ended.connect(func(w: int) -> void: ended2.append(w))
	q.duel_left = q.dt * 0.5
	q.step_duel()
	check.call(ended2 == [-1] and q.duel_wins == [0, 0] and q.duel_results == [-1], "체력이 같으면 그 판은 비김(점수 없음)")
	var r2 := _duel(1)
	r2.lords[0].hp = 250.0
	r2.lords[1].hp = 100.0
	r2.duel_left = r2.dt * 0.5
	r2.step_duel()
	check.call(r2.duel_wins == [1, 0], "1P가 앞서면 1P가 이긴다")


func _best_of_three() -> void:
	var r := _duel(1)
	var overs: Array = []
	r.duel_over.connect(func(w: int) -> void: overs.append(w))
	# 1판: 1P 이김
	r.lords[1].hp = 0.0
	r.step_duel()
	check.call(r.duel_wins == [1, 0] and r.duel_phase == Rules.DUEL_BETWEEN and r.phase == Rules.Phase.NIGHT, "한 판을 이기면 쉬고 다음 판")
	for t in roundi(d.duel.break_time / r.dt) + 2:
		r.step_duel()
	check.call(r.duel_round == 2 and r.duel_phase == Rules.DUEL_READY and r.lords[1].hp == d.duel.hp and r.lords[0].pos == Grid.middle() + Vector2(-d.duel.start_gap, 0.0), "다음 판은 체력과 자리가 새로 시작")
	_to_fight(r)
	# 2판: 2P 이김 → 1 대 1
	r.lords[0].hp = 0.0
	r.step_duel()
	check.call(r.duel_wins == [1, 1] and overs.is_empty(), "1 대 1이면 세 번째 판")
	for t in roundi(d.duel.break_time / r.dt) + 2:
		r.step_duel()
	_to_fight(r)
	check.call(r.duel_round == 3, "세 번째 판")
	r.lords[1].hp = 0.0
	r.step_duel()
	check.call(r.duel_wins == [2, 1] and overs == [0] and r.duel_winner == 0 and r.phase == Rules.Phase.OVER and r.duel_phase == Rules.DUEL_DONE, "2판을 먼저 이긴 쪽이 이기고 판이 끝난다(%s)" % [overs])
	r.step_duel(_inp(Vector2.RIGHT), null)
	check.call(overs == [0], "끝난 뒤에는 아무 일도 없다")
	# 2 대 0이면 두 판으로 끝
	var q := _duel(1)
	q.lords[0].hp = 0.0
	q.step_duel()
	for t in roundi(d.duel.break_time / q.dt) + 2:
		q.step_duel()
	_to_fight(q)
	q.lords[0].hp = 0.0
	q.step_duel()
	check.call(q.duel_winner == 1 and q.duel_round == 2 and q.duel_results == [1, 1], "2 대 0이면 두 판으로 끝")


func _draws() -> void:
	var r := _duel(1)
	r.lords[0].hp = 0.0
	r.lords[1].hp = 0.0
	r.step_duel()
	check.call(r.duel_results == [-1] and r.duel_wins == [0, 0], "같은 틱에 둘 다 쓰러지면 그 판은 비김")
	var q := _duel(1)
	var overs: Array = []
	q.duel_over.connect(func(w: int) -> void: overs.append(w))
	for k in 3:
		q.duel_left = q.dt * 0.5
		q.step_duel()
		if q.duel_phase == Rules.DUEL_BETWEEN:
			for t in roundi(d.duel.break_time / q.dt) + 2:
				q.step_duel()
			_to_fight(q)
	check.call(overs == [-1] and q.duel_winner == -1 and q.duel_results == [-1, -1, -1], "세 판 모두 비기면 결투도 비김")
	var m := _duel(1)
	m.lords[1].hp = 0.0
	m.step_duel()
	for t in roundi(d.duel.break_time / m.dt) + 2:
		m.step_duel()
	_to_fight(m)
	m.duel_left = m.dt * 0.5
	m.step_duel()
	for t in roundi(d.duel.break_time / m.dt) + 2:
		m.step_duel()
	_to_fight(m)
	m.duel_left = m.dt * 0.5
	m.step_duel()
	check.call(m.duel_wins == [1, 0] and m.duel_winner == 0, "1 대 0에서 비긴 판이 이어져도 많이 이긴 쪽이 이긴다")


func _push_apart() -> void:
	var r := _duel(1)
	r.lords[0].pos = Vector2(17.0, 11.0)
	r.lords[1].pos = Vector2(17.1, 11.0)
	r.step_duel()
	check.call(r.lords[0].pos.distance_to(r.lords[1].pos) >= d.duel.body_radius * 2.0 - 0.001, "몸이 겹치면 서로 밀어낸다(%.2f칸)" % r.lords[0].pos.distance_to(r.lords[1].pos))
	var q := _duel(1)
	q.lords[0].pos = Vector2(17.0, 11.0)
	q.lords[1].pos = Vector2(17.0, 11.0)
	q.step_duel()
	check.call(q.lords[0].pos != q.lords[1].pos, "완전히 겹쳐도 떨어진다")


func _hook_foe() -> void:
	var s := _sword("녹슨 장검", ["hook", "sweep"])
	var r := _duel(1, s)
	r.lords[0].face = 0.0
	_face_off(r, 6.0)
	var i := LordInput.new()
	i.hook = true
	i.aim_valid = true
	i.aim = r.lords[1].pos
	r.step_duel(i, null)
	check.call(r.lords[0].hook > 0.0 and r.lords[0].hook_target == r._proxies[1], "갈고리 검의 우클릭 갈고리가 상대 영주에게 걸린다")
	var hp0: float = r.lords[1].hp
	for t in 40:
		r.freeze = 0
		r.step_duel()
		if r.lords[0].hook <= 0.0:
			break
	check.call(r.lords[0].pos.distance_to(r.lords[1].pos) < 1.5 and r.lords[1].hp < hp0, "상대 앞까지 날아가 벤다(%.2f칸, 체력 %.0f)" % [r.lords[0].pos.distance_to(r.lords[1].pos), r.lords[1].hp])
	var plain := _duel(1, _sword("녹슨 장검", ["sweep"]))
	_face_off(plain, 6.0)
	plain.step_duel(i, null)
	check.call(plain.lords[0].hook <= 0.0, "갈고리가 없는 검은 갈고리를 못 건다")


func _parry_foe() -> void:
	var r := _duel(1, _sword("녹슨 장검", ["parry"]), _sword("녹슨 장검", ["sweep"]))
	_face_off(r, 1.0)
	r.step_duel(_inp(Vector2.ZERO, true), null)
	check.call(r.lords[0].parry > 0.0, "반격 자세에 들어선다")
	var hp1: float = r.lords[1].hp
	r.freeze = 0
	r.step_duel(null, _inp(Vector2.ZERO, true))
	check.call(r.lords[0].hp == d.duel.hp and r.lords[1].hp < hp1, "반격 자세에서 맞으면 피해 없이 상대가 반격에 맞는다(%.0f → %.0f)" % [hp1, r.lords[1].hp])


## 두 입력열이 같으면 같은 상태가 되는지. 두 영주가 서로 걸어가며 베고 구르고 갈고리를 건다.
func _run_fight(seed_value: int, ticks: int) -> Rules:
	var r := Rules.new(d, seed_value)
	var a := Sword.new(d.sword_by_name("녹슨 대검"), d)
	var b := Sword.new(d.sword_by_name("녹슨 장검"), d)
	b.pattern = _pat(["sweep", "hook", "thrust", "spin"])
	r.start_duel(a, b)
	var rec := RandomNumberGenerator.new()
	rec.seed = 77
	for k in ticks:
		var ia := LordInput.new()
		var ib := LordInput.new()
		for pair in [[ia, 0], [ib, 1]]:
			var inp: LordInput = pair[0]
			var me: LordState = r.lords[pair[1]]
			var foe: LordState = r.lords[1 - pair[1]]
			var to: Vector2 = foe.pos - me.pos
			inp.move = to.normalized() * (1.0 if rec.randf() < 0.8 else -1.0) if to.length() > 1.2 else Vector2(rec.randf_range(-1, 1), rec.randf_range(-1, 1))
			inp.attack = rec.randf() < 0.5
			inp.dash = rec.randf() < 0.04
			inp.hook = rec.randf() < 0.05
			inp.aim_valid = true
			inp.aim = foe.pos
		r.step_duel(ia, ib)
	return r


func _replay() -> void:
	var a := _run_fight(5, 1500)
	var b := _run_fight(5, 1500)
	check.call(a.state_hash() == b.state_hash() and a.tick == b.tick, "같은 시드·같은 두 입력열이면 같은 state_hash")
	check.call(a.lords[0].hp < d.duel.hp or a.lords[1].hp < d.duel.hp or a.duel_round > 1, "다시 돌린 결투에서 실제로 서로 맞았다(%.0f / %.0f, %d판)" % [a.lords[0].hp, a.lords[1].hp, a.duel_round])
	var c := _run_fight(6, 1500)
	check.call(c.state_hash() != a.state_hash(), "시드가 다르면 달라진다")


func _input_bytes() -> void:
	var rec := RandomNumberGenerator.new()
	rec.seed = 9
	var ok: bool = true
	for k in 50:
		var i := LordInput.new()
		i.move = Vector2(rec.randf_range(-1, 1), rec.randf_range(-1, 1))
		i.aim = Vector2(rec.randf_range(0, 34), rec.randf_range(0, 22))
		i.aim_valid = rec.randf() < 0.5
		i.attack = rec.randf() < 0.5
		i.dash = rec.randf() < 0.5
		i.hook = rec.randf() < 0.5
		i.pull = rec.randf() < 0.5
		i.pull_press = rec.randf() < 0.5
		i.swap_to = rec.randi_range(-1, 2)
		var b: PackedByteArray = i.to_bytes()
		var j := LordInput.from_bytes(b)
		ok = ok and b.size() == LordInput.BYTES and j.move == i.move and j.aim == i.aim and j.aim_valid == i.aim_valid and j.attack == i.attack \
			and j.dash == i.dash and j.hook == i.hook and j.pull == i.pull and j.pull_press == i.pull_press and j.swap_to == i.swap_to
	check.call(ok, "LordInput를 바이트로 바꿨다가 되돌려도 같다(%d바이트)" % LordInput.BYTES)
	var empty := LordInput.from_bytes(PackedByteArray())
	check.call(empty.move == Vector2.ZERO and not empty.attack and empty.swap_to == -1, "모자란 바이트는 빈 입력")
	# 바이트로 되돌린 입력으로 돌려도 같은 판이 된다
	var r1 := Rules.new(d, 4)
	var r2 := Rules.new(d, 4)
	r1.start_duel(_sword("녹슨 장검"), _sword("녹슨 장검"))
	r2.start_duel(_sword("녹슨 장검"), _sword("녹슨 장검"))
	for k in 400:
		var i := LordInput.new()
		i.move = Vector2(rec.randf_range(-1, 1), rec.randf_range(-1, 1))
		i.attack = rec.randf() < 0.5
		i.aim_valid = true
		i.aim = Vector2(rec.randf_range(10, 24), rec.randf_range(5, 17))
		r1.step_duel(i, i)
		r2.step_duel(LordInput.from_bytes(i.to_bytes()), LordInput.from_bytes(i.to_bytes()))
	check.call(r1.state_hash() == r2.state_hash(), "바이트를 거친 입력열도 같은 state_hash")


func _meta() -> void:
	var m := Meta.new()
	m.record_duel(0)
	m.record_duel(0)
	m.record_duel(1)
	m.record_duel(-1)
	check.call(m.duel_wins == 2 and m.duel_losses == 1, "결투 기록: 이김 2, 짐 1(비김은 세지 않는다)")
	var path := "user://test_duel_save.json"
	m.save(path)
	var n := Meta.load_or_new(path)
	check.call(n.duel_wins == 2 and n.duel_losses == 1, "결투 기록이 저장되고 다시 읽힌다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var old := Meta.new()
	old.from_dict({"shards": 7, "sheath_id": 5})
	check.call(old.duel_wins == 0 and old.duel_losses == 0 and old.shards == 7, "결투 기록이 없는 옛 저장은 0으로 읽힌다")


func _single_mode() -> void:
	var r := Rules.new(d, 1)
	check.call(not r.duel and r.lords.size() == 1 and r.lords[0] == r.lord, "비결투 모드에서는 lords가 하나(lord)")
	r.start_night()
	for t in 60:
		r.step()
	check.call(r.lords.size() == 1 and r.max_hp() == d.lord.hp, "밤을 돌려도 lords는 하나, 체력은 영주 표 그대로")
	var f := Rules.new(d, 1)
	f.start_field()
	check.call(f.lords.size() == 1, "들판 모드도 lords는 하나")
