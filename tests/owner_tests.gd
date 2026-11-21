extends RefCounted
## 검의 주인과 잔영 테스트(docs/sword_hill.md 2번): 쓰러지면 Meta.fallen에 검·기록·마지막 몸놀림이 남음(최대 12, 저장·불러오기),
## 낮에 주인 있는 검이 꽂힘(owner_chance), 낮에 뽑으면 그 검(굴리지 않음)·밤이 오면 잔영, 밤에 발검하면 바로 잔영,
## 잔영이 기록대로 움직이고 휘두름 틱에 적을 벰, 다 움직이면 사라짐, 한 줄 기록, 결정성.
## run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/owner_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_fallen_recorded()
	_fallen_saved()
	_owner_placed()
	_owner_day_pull()
	_owner_night_draw()
	_ghost_moves_and_cuts()
	_line()
	_replay()


func _inp(pull: bool = false, attack: bool = false) -> LordInput:
	var i := LordInput.new()
	i.pull = pull
	i.attack = attack
	return i


## 제자리에서 이따금 휘두르는 몸놀림 기록(frames틱). k번째 틱마다 휘두름.
func _rec(id: int, frames: int, every: int) -> Dictionary:
	var g: Array = []
	for t in frames:
		g.append_array([5.0 + t * 0.01, 5.0, 0.0, 1.0 if t % every == every - 1 else 0.0])
	return {"id": id, "run": 3, "zone": 4, "kills": 77, "ghost": g}


func _fallen_recorded() -> void:
	var m := Meta.new()
	var r := Rules.new(d, 2, m)
	r.give(d.swords[5], 0)
	r.start_night()
	r.enemies.clear()
	for t in 200:
		r.step(_inp(false, t % 20 == 0))
	r.lord_died()
	check.call(m.fallen.size() == 1 and int(m.fallen[0].id) == d.swords[5].id, "언덕에서 쓰러지면 쥐고 있던 검이 Meta.fallen에 남는다")
	var g: Array = m.fallen[0].ghost
	check.call(g.size() == d.run.ghost_ticks * 4, "마지막 %d틱의 몸놀림이 남는다 (%d값)" % [d.run.ghost_ticks, g.size()])
	var swings: int = 0
	for k in range(3, g.size(), 4):
		swings += 1 if float(g[k]) > 0.0 else 0
	check.call(swings >= 5, "몸놀림 기록에 휘두름이 적힌다 (%d번)" % swings)
	check.call(int(m.fallen[0].zone) == 0 and m.fallen[0].has("kills"), "쓰러진 구역과 그 판 처치 수도 남는다")
	var bare := Rules.new(d, 2, m)
	bare.start_night()
	bare.lord_died()
	check.call(m.fallen.size() == 1, "맨손으로 쓰러지면 남길 검이 없다")
	for k in 20:
		m.add_fallen(_rec(d.swords[k].id, 10, 3))
	check.call(m.fallen.size() == Meta.FALLEN_MAX, "기록은 최대 %d개(오래된 것부터 밀려난다)" % Meta.FALLEN_MAX)


func _fallen_saved() -> void:
	var m := Meta.new()
	m.add_fallen(_rec(d.swords[3].id, 12, 4))
	var m2 := Meta.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check.call(m2.fallen.size() == 1 and int(m2.fallen[0].id) == d.swords[3].id and (m2.fallen[0].ghost as Array).size() == 48, "Meta.fallen은 저장하고 불러온다")


## 주인 있는 검이 반드시 꽂히는 낮(owner_chance 1, 구역 1).
func _owner_day(m: Meta, seed_value: int = 6) -> Rules:
	var keep: float = d.run.owner_chance
	d.run.owner_chance = 1.0
	var r := Rules.new(d, seed_value, m)
	r.zone = 1
	r._new_day()
	d.run.owner_chance = keep
	return r


func _owner_hilt(r: Rules) -> Hilt:
	for h in r.hilts:
		if not h.owner.is_empty():
			return h
	return null


func _owner_placed() -> void:
	var m := Meta.new()
	var r0 := Rules.new(d, 6, m)
	check.call(_owner_hilt(r0) == null, "기록이 없으면(또는 첫 구역이면) 주인 있는 검이 없다")
	m.add_fallen(_rec(d.swords[7].id, 60, 10))
	var r := _owner_day(m)
	var h := _owner_hilt(r)
	check.call(h != null and int(h.owner.id) == d.swords[7].id, "기록이 있으면 낮에 손잡이 하나가 주인 있는 검이 된다")
	var n: int = 0
	for x in r.hilts:
		n += 0 if x.owner.is_empty() else 1
	check.call(n == 1, "주인 있는 검은 낮마다 한 자루까지")


func _owner_day_pull() -> void:
	var m := Meta.new()
	m.add_fallen(_rec(d.swords[7].id, 60, 10))
	var r := _owner_day(m)
	var h := _owner_hilt(r)
	r.lord.pos = h.pos + Vector2(0.3, 0)
	var hp0: float = r.lord.hp
	var got: Array = []
	r.sword_pulled.connect(func(s: Sword) -> void: got.append(s))
	r.step(_inp(true))
	check.call(got.size() == 1 and got[0].data.id == d.swords[7].id and r.pull_hilt == null, "낮에 주인 있는 검을 뽑으면 버티지 않고 그 검이 나온다")
	check.call(is_equal_approx(r.lord.hp, hp0 - r.pull_cost()), "주인 있는 검도 뽑기 값은 같다")
	check.call(r.ghosts.is_empty(), "낮에 뽑으면 잔영은 아직 없다")
	var spawned: Array = []
	r.ghost_spawned.connect(func(g: Ghost) -> void: spawned.append(g))
	r.start_night()
	check.call(spawned.size() == 1 and r.ghosts.size() == 1 and r.ghosts[0].pos.distance_to(r.lord.pos) < 1.6, "밤이 오는 순간 주인의 잔영이 영주 곁에 나온다")


func _owner_night_draw() -> void:
	var m := Meta.new()
	m.add_fallen(_rec(d.swords[9].id, 60, 10))
	var r := _owner_day(m)
	var h := _owner_hilt(r)
	r.start_night()
	r.enemies.clear()
	r.lord.pos = h.pos + Vector2(0.3, 0)
	r.step(_inp(true))
	check.call(r.current() != null and r.current().data.id == d.swords[9].id, "밤에 주인 있는 검을 발검하면 그 검을 쥔다")
	check.call(r.ghosts.size() == 1 and r.ghosts[0].pos.distance_to(h.pos) < 0.5, "밤에 발검하면 잔영이 그 자리에 바로 나온다")


func _ghost_moves_and_cuts() -> void:
	var r := Rules.new(d, 8)
	r.start_night()
	r.enemies.clear()
	var at := Vector2(10, 8)
	r._spawn_ghost(_rec(d.swords[20].id, 30, 6), at)
	var g: Ghost = r.ghosts[0]
	var e := r.spawn_at(&"dummy", at + Vector2(1.0, 0))
	var hp0: float = e.hp
	var swung: Array = []
	r.ghost_swung.connect(func(_g: Ghost, big: bool) -> void: swung.append(big))
	for t in 10:
		r.step(_inp())
	check.call(g.pos.distance_to(at + Vector2(0.09, 0)) < 0.02, "잔영은 기록대로 움직인다(첫 자리를 나타난 자리로 옮겨서)")
	check.call(swung.size() >= 1 and e.hp < hp0, "잔영은 기록의 휘두름 틱에 앞의 적을 벤다")
	var gone: Array = []
	r.ghost_gone.connect(func(x: Ghost) -> void: gone.append(x))
	for t in 30:
		r.step(_inp())
	check.call(r.ghosts.is_empty() and gone.size() == 1, "기록을 다 움직이면 잔영은 사라진다")


func _line() -> void:
	var t: String = Meta.fallen_line(_rec(1, 2, 1), 5, d.run.zone_names)
	check.call(t.contains("2판 전") and t.contains(d.run.zone_names[4]) and t.contains("77마리"), "주인 있는 검의 한 줄 기록: " + t)


func _replay() -> void:
	var hashes: Array[int] = []
	for k in 2:
		var m := Meta.new()
		m.add_fallen(_rec(d.swords[7].id, 90, 7))
		var r := _owner_day(m, 11)
		var h := _owner_hilt(r)
		r.start_night()
		r.lord.pos = h.pos + Vector2(0.3, 0)
		for t in 120:
			r.step(_inp(t == 1, t % 13 == 0))
		hashes.append(r.state_hash())
	check.call(hashes[0] == hashes[1], "결정성: 잔영이 섞인 밤도 같은 입력이면 state_hash가 같다")
