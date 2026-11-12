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
