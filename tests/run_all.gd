extends SceneTree
## 규칙 단위 테스트. 저장소 맨 위에서: godot --headless --path . -s tests/run_all.gd
## 실패가 하나라도 있으면 종료 코드 1로 끝난다.

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_test_grid()
	_test_data()
	_test_rng_same_seed()
	_test_roll_distribution()
	_test_day_cycle()
	_test_input_map()
	_test_lord_move()
	_test_lord_dash()
	_test_lord_swing()
	_test_lord_replay()
	print("통과 %d, 실패 %d" % [_pass, _fail])
	quit(1 if _fail > 0 else 0)


func check(ok: bool, what: String) -> void:
	if ok:
		_pass += 1
	else:
		_fail += 1
		printerr("실패: " + what)


func _test_grid() -> void:
	Grid.size = 33
	check(Grid.cell_to_world(Vector2i(0, 0)) == Vector3(1, 0, 1), "칸 (0,0)의 가운데는 (1, 0, 1)m")
	check(Grid.world_to_cell(Vector3(1.99, 0, 2.0)) == Vector2i(0, 1), "1.99m는 0번 칸, 2.0m는 1번 칸")
	check(Grid.center() == Vector2i(16, 16), "가운데 칸은 (16, 16)")
	var ok := true
	for i in Grid.size * Grid.size:
		var c := Grid.cell_of(i)
		if Grid.world_to_cell(Grid.cell_to_world(c)) != c or Grid.index(c) != i:
			ok = false
	check(ok, "모든 칸이 월드로 갔다가 그대로 돌아온다")
	check(not Grid.in_map(Vector2i(-1, 0)) and not Grid.in_map(Vector2i(33, 5)) and Grid.in_map(Vector2i(32, 32)), "맵 경계")
	check(Grid.ring_distance(Vector2i(16, 16), Vector2i(19, 14)) == 3, "체비쇼프 거리")


func _test_data() -> void:
	var d := GameData.load_default()
	check(d.buildings.size() == 22, "건물 22개 (지금 %d)" % d.buildings.size())
	var per_tier: Array[int] = []
	for t in 8:
		per_tier.append(d.buildings_of_tier(t).size())
	check(per_tier == [6, 6, 5, 1, 1, 1, 1, 1], "등급별 건물 수 %s" % [per_tier])
	check(d.buildings[0].display_name == "주막" and d.buildings[0].role == BuildingData.Role.RECRUIT, "첫 건물은 모집 건물 주막")
	check(d.building(&"portcullis").hp_mult == 4.0 and d.building(&"portcullis").path_cost == 18.0, "쇠살문은 체력 4배, 길 비용 18")
	check(d.tiers.odds.size() == 8 and d.tiers.odds[2] == 40.0 and d.tiers.odds[6] == 50000.0, "설계함 확률은 뽑기 데모 그대로")
	check(d.tiers.cost_wood[6] == 160 and d.tiers.cost_stone[6] == 120, "초월 건물 값 160/120")
	check(d.grades.names.size() == 6 and d.grades.odds[2] == 25.0 and d.grades.power[5] == 120.0, "사람 등급 표")
	check(d.classes.size() == 6 and d.classes[0].display_name == "창병" and d.classes[5].heal == 5.0, "병과 6종")
	check(d.enemies.size() == 4 and (d.enemies[&"boss"] as EnemyData).is_boss and (d.enemies[&"ram"] as EnemyData).ignores_lord, "적 4종")
	check(d.lord.hp == 140.0 and d.lord.respawn_times.size() == 3, "영주 수치")
	check(d.run.box_gold == 2 and d.run.days == 7 and d.run.sides_by_day.size() == d.run.days, "판 수치")


func _test_rng_same_seed() -> void:
	var d := GameData.load_default()
	var a := Rules.new(d, 1234)
	var b := Rules.new(d, 1234)
	var c := Rules.new(d, 4321)
	var same := true
	var differ := false
	for i in 2000:
		var x := a.roll_tier(d.tiers.odds, 10.0)
		if x != b.roll_tier(d.tiers.odds, 10.0):
			same = false
		if x != c.roll_tier(d.tiers.odds, 10.0):
			differ = true
	check(same, "같은 시드는 같은 결과")
	check(differ, "다른 시드는 다른 결과")


func _test_roll_distribution() -> void:
	var d := GameData.load_default()
	var r := Rules.new(d, 7)
	var n: int = 200000
	var count: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
	for i in n:
		count[r.roll_tier(d.tiers.odds, 1.0)] += 1
	# 높은 등급부터 굴리니 귀함은 1/6 × (1 - 1/40) × (1 - 1/200) … ≈ 0.1616
	var rare: float = float(count[1]) / n
	var legend: float = float(count[2]) / n
	check(absf(rare - 0.1616) < 0.005, "귀함 비율 %.4f" % rare)
	check(absf(legend - 0.0248) < 0.002, "전설 비율 %.4f" % legend)


func _test_day_cycle() -> void:
	var d := GameData.load_default()
	var r := Rules.new(d, 1)
	var nights: Array[int] = []
	var ended: Array[bool] = []
	r.night_started.connect(func(day: int) -> void: nights.append(day))
	r.run_ended.connect(func(won: bool) -> void: ended.append(won))
	var ticks_per_day: int = ceili(d.run.day_length * d.run.tick_rate) + 1
	for day in d.run.days:
		for i in ticks_per_day:
			r.step()
		check(r.phase == Rules.Phase.NIGHT, "%d일째 낮 %d틱 뒤에는 밤" % [day + 1, ticks_per_day])
		r.end_night()
	check(nights == [1, 2, 3, 4, 5, 6, 7], "밤이 7번 왔다 %s" % [nights])
	check(r.phase == Rules.Phase.OVER and ended == [true], "7일째 밤을 넘기면 승리로 끝난다")


func _test_input_map() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "attack", "dash"]:
		check(InputMap.has_action(a) and InputMap.action_get_events(a).size() >= 2, "입력 %s에 키가 둘 이상" % a)


func _inp(move: Vector2 = Vector2.ZERO, attack: bool = false, dash: bool = false) -> LordInput:
	var i := LordInput.new()
	i.move = move
	i.attack = attack
	i.dash = dash
	return i


func _test_lord_move() -> void:
	var d := GameData.load_default()
	var r := Rules.new(d, 1)
	var x0: float = r.lord.pos.x
	for i in d.run.tick_rate:
		r.step(_inp(Vector2.RIGHT))
	check(absf((r.lord.pos.x - x0) - d.lord.speed) < 0.05, "1초에 %.2f칸 간다(속도 %.2f)" % [r.lord.pos.x - x0, d.lord.speed])
	check(absf(r.lord.face) < 0.01, "움직이는 쪽을 바라본다")
	for i in 400:
		r.step(_inp(Vector2.LEFT))
	check(r.lord.pos.x >= 0.3 - 0.0001, "맵 밖으로 못 나간다")


func _test_lord_dash() -> void:
	var d := GameData.load_default()
	var r := Rules.new(d, 1)
	var y0: float = r.lord.pos.y
	r.step(_inp(Vector2.DOWN, false, true))
	for i in 10:
		r.step(_inp())
	var dist: float = r.lord.pos.y - y0
	var want: float = d.lord.dash_speed * ceili(d.lord.dash_time / r.dt) * r.dt
	check(absf(dist - want) < 0.2, "돌진 거리 %.2f칸(약 %.2f)" % [dist, want])
	var y1: float = r.lord.pos.y
	r.step(_inp(Vector2.ZERO, false, true))
	r.step(_inp())
	check(absf(r.lord.pos.y - y1) < 0.001, "다시 쓰기 전에는 돌진이 안 된다")


func _test_lord_swing() -> void:
	var d := GameData.load_default()
	var r := Rules.new(d, 1)
	var L := r.lord
	L.face = 0.0
	var front := r.add_dummy(L.pos + Vector2(1.2, 0.0))
	var back := r.add_dummy(L.pos + Vector2(-1.2, 0.0))
	var dmg: Array[float] = []
	var bigs: Array[bool] = []
	r.unit_hit.connect(func(u: Unit, amount: float, big: bool) -> void:
		if u == front:
			dmg.append(amount)
			bigs.append(big)
		else:
			dmg.append(-1.0))
	var held := _inp(Vector2.ZERO, true)
	held.aim_valid = true
	for i in 60:
		held.aim = r.lord.pos + Vector2(3.0, 0.0)
		r.step(held)
	check(dmg.size() >= 3 and not dmg.has(-1.0), "앞의 허수아비만 맞는다 %s" % [dmg])
	check(dmg.size() >= 3 and absf(dmg[0] - d.lord.damage) < 0.01 and absf(dmg[2] - d.lord.damage * d.lord.big_damage_mult) < 0.01 and bigs[2] and not bigs[0], "세 번째가 강타 %s" % [dmg])
	var expect: int = ceili(60.0 * r.dt / d.lord.cooldown)
	check(dmg.size() <= expect + 1, "공격 간격을 지킨다(%d번)" % dmg.size())
	# 넉백과 히트스톱
	var r2 := Rules.new(d, 1)
	r2.lord.face = 0.0
	var u := r2.add_dummy(r2.lord.pos + Vector2(1.0, 0.0))
	var x0: float = u.pos.x
	r2.step(_inp(Vector2.ZERO, true))
	check(absf((u.pos.x - x0) - (d.lord.knockback - d.run.dummy_return_speed * r2.dt)) < 0.01, "맞으면 %.2f칸 밀린다(허수아비는 같은 틱에 조금 돌아온다)" % (u.pos.x - x0))
	check(r2.freeze == roundi(d.lord.hitstop / r2.dt), "맞히면 히트스톱 %d틱" % r2.freeze)
	var lp: Vector2 = r2.lord.pos
	r2.step(_inp(Vector2.RIGHT))
	check(r2.lord.pos == lp, "히트스톱 동안은 시간이 멈춘다")


func _test_lord_replay() -> void:
	var d := GameData.load_default()
	var a := Rules.new(d, 99)
	var b := Rules.new(d, 99)
	for r in [a, b]:
		r.add_dummy(r.lord.pos + Vector2(1.0, 0.5))
		r.add_dummy(r.lord.pos + Vector2(-1.0, -0.5))
	var rec := RandomNumberGenerator.new()
	rec.seed = 5
	var inputs: Array[LordInput] = []
	for i in 600:
		var inp := _inp(Vector2(rec.randf_range(-1, 1), rec.randf_range(-1, 1)), rec.randf() < 0.4, rec.randf() < 0.05)
		inp.aim_valid = rec.randf() < 0.7
		inp.aim = Vector2(rec.randf_range(10, 22), rec.randf_range(10, 22))
		inputs.append(inp)
	for inp in inputs:
		a.step(inp)
	for inp in inputs:
		b.step(inp)
	check(a.lord.pos == b.lord.pos and a.units[0].hp == b.units[0].hp and a.units[1].pos == b.units[1].pos, "같은 입력을 다시 넣으면 똑같이 돈다")
