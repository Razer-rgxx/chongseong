extends RefCounted
## 17단계 들판 싸움 테스트(docs/outside.md). run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/field_fight_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_layout()
	_spawn()
	_aggro()
	_leash()
	_wander()
	_rewards()
	_death()
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


func _layout() -> void:
	var P := FieldLayout.PACKS
	check.call(P.size() == 17, "들판 싸움: 무리 자리는 17곳(원래 8 + 새 지역 4 + 28단계 새 곳 5)")
	var zones := {}
	var ok_kinds: bool = true
	var ok_count: bool = true
	var ok_area: bool = true
	var ok_off: bool = true
	var areas := {"road_south": &"road", "road_mid": &"road", "brook_east": &"brook", "old_field": &"old_field", "tower": &"watchtower", "grove": &"grove", "foot": &"foot", "foot_east": &"foot", "keep_yard": &"keep", "keep_gate": &"keep", "marsh_west": &"marsh", "marsh_east": &"marsh", "quarry_pit": &"quarry", "quarry_rim": &"quarry", "hamlet_square": &"hamlet", "hamlet_south": &"hamlet", "pass_top": &"pass"}
	var zone_of := {&"road": [1, 2], &"brook": [1, 2], &"old_field": [3, 4], &"watchtower": [3, 4], &"grove": [5, 6], &"foot": [5, 6], &"keep": [7, 8], &"marsh": [7, 8], &"quarry": [8], &"hamlet": [8], &"pass": [9]}
	for id in P:
		var p: Dictionary = P[id]
		var n: int = 0
		for f in p.foes:
			n += int(f[1])
			ok_kinds = ok_kinds and d.enemies.has(StringName(f[0])) and not d.enemies[StringName(f[0])].boss and not d.enemies[StringName(f[0])].still
		ok_count = ok_count and n >= 3 and n <= 6
		zones[int(p.zone)] = 1
		var a: StringName = FieldLayout.area_at(p.at)
		ok_area = ok_area and a == areas.get(id, &"") and (zone_of[a] as Array).has(int(p.zone))
		var near: float = 1e9
		for i in FieldLayout.ROAD.size() - 1:
			near = minf(near, (p.at as Vector2).distance_to(Geometry2D.get_closest_point_to_segment(p.at, FieldLayout.ROAD[i], FieldLayout.ROAD[i + 1])))
		for k in FieldLayout.CACHES:
			near = minf(near, (p.at as Vector2).distance_to(FieldLayout.CACHES[k][0]))
		for k in FieldLayout.STONES:
			near = minf(near, (p.at as Vector2).distance_to(FieldLayout.STONES[k][0]))
		ok_off = ok_off and near > float(p.wander) + 1.0
	check.call(ok_kinds and ok_count, "들판 싸움: 무리는 있는 적(영주·허수아비 아님) 3~6마리")
	check.call(zones.size() == 9, "들판 싸움: 세기 구역 1~9가 모두 있다")
	check.call(ok_area, "들판 싸움: 곳과 세기가 설계서대로(길·개울 1~2, 싸움터·망루 3~4, 숲·발치 5~6)")
	check.call(ok_off, "들판 싸움: 자리는 길·상자·비석에서 떨어져 있다")
	# 막힌 곳(나무·바위·망루 …)을 피한다
	var root := Node3D.new()
	var blockers: Dictionary = FieldBuilder.build(root, Environment.new())
	var clear: bool = true
	for id in P:
		var p: Dictionary = P[id]
		for a in 16:
			for k in [0.0, 0.5, 1.0]:
				var q: Vector2 = (p.at as Vector2) + Vector2.from_angle(a * TAU / 16.0) * float(p.wander) * k
				for rc: Rect2 in blockers.rects + blockers.low_rects:
					clear = clear and not rc.grow(0.4).has_point(q)
				for c in blockers.circles + blockers.low_circles:
					clear = clear and q.distance_to(c[0]) >= float(c[1]) + 0.4
	check.call(clear, "들판 싸움: 무리가 서성이는 곳은 막힌 곳(rects·circles)을 피한다")
	root.free()


func _spawn() -> void:
	var r := _field()
	check.call(r.field and r.phase == Rules.Phase.NIGHT and r.lord.hp == r.max_hp(), "들판 싸움: 들판 모드는 체력이 가득한 채 시작한다")
	var es := r.spawn_pack(&"road_south")
	check.call(es.size() == 3 and r.enemies.size() == 3 and r.pack_alive(&"road_south") == 3, "spawn_pack: 정해진 수의 적이 선다")
	var inside: bool = true
	for e in es:
		inside = inside and e.pack == &"road_south" and e.pos.distance_to(FieldLayout.PACKS["road_south"].at) <= float(FieldLayout.PACKS["road_south"].wander) and e.home == e.pos
	check.call(inside, "spawn_pack: 적은 제자리 반지름 안에 서고 무리 id를 가진다")
	check.call(r.spawn_pack(&"road_south").is_empty() and r.enemies.size() == 3, "spawn_pack: 같은 무리를 두 번 두지 않는다")
	var far := r.spawn_pack(&"foot")
	var near := es[0]
	check.call(far[0].max_hp > d.enemies[far[0].data.id].hp * 1.5 and near.max_hp == d.enemies[&"wraith"].hp * d.run.zone_hp[0], "spawn_pack: 세기는 RunData 구역 배수(1구역 1배, 6구역은 더 세다)")
	check.call(r.zone == 0, "spawn_pack: 두고 나서 구역은 그대로")
	var r2 := _field()
	var skip := {"road_south": 1, "road_mid": 1}
	r2.spawn_packs(skip)
	check.call(r2.packs.size() == FieldLayout.PACKS.size() - 2 and not r2.packs.has(&"road_south"), "spawn_packs: 이미 쓰러뜨린 무리는 안 생긴다")
	var kinds: int = 0
	for e in r2.enemies:
		kinds += 1 if e.pack == &"" else 0
	check.call(kinds == 0, "spawn_packs: 모든 적이 무리에 속한다")


func _aggro() -> void:
	var r := _field()
	r.spawn_pack(&"road_south")
	var home: Vector2 = FieldLayout.PACKS["road_south"].at
	var engaged: Array = [0]
	r.pack_engaged.connect(func(_id: StringName) -> void: engaged[0] += 1)
	r.lord.pos = home + Vector2(FieldLayout.PACK_AGGRO + 1.0, 0)
	for t in 90:
		r.step()
	check.call(engaged[0] == 0 and int(r.packs[&"road_south"].state) == Rules.PACK_IDLE, "덤빔: 영주가 10칸 밖이면 덤비지 않는다")
	var calm: bool = true
	for e in r.enemies:
		calm = calm and e.pos.distance_to(home) <= float(FieldLayout.PACKS["road_south"].wander) + 0.5 and e.token == 0
	check.call(calm, "덤빔: 덤비기 전에는 제자리 둘레에 머문다")
	r.lord.pos = home + Vector2(FieldLayout.PACK_AGGRO - 1.0, 0)
	r.lord.prev_pos = r.lord.pos
	var before: float = r.enemies[0].pos.distance_to(r.lord.pos)
	for t in 60:
		r.lord.pos = home + Vector2(FieldLayout.PACK_AGGRO - 1.0, 0)
		r.step()
	check.call(engaged[0] == 1 and int(r.packs[&"road_south"].state) == Rules.PACK_ENGAGED, "덤빔: 영주가 10칸 안이면 덤빈다(한 번)")
	var closer: bool = true
	for e in r.enemies:
		closer = closer and e.pos.distance_to(r.lord.pos) < before
	check.call(closer, "덤빔: 덤비면 영주 쪽으로 다가온다")
	# 공격 표: 표를 가진 적만 때린다(표 수는 무리 구역)
	check.call(r.zone == int(r.packs[&"road_south"].zone) and r.tokens.total() > 0, "덤빔: 공격 표(Tokens)는 그 무리의 구역을 따른다")
	# 멀리서 맞으면 덤빈다
	var r2 := _field()
	r2.spawn_pack(&"brook_east")
	r2.lord.pos = Vector2(40, 100)
	r2.hurt(r2.enemies[0], 1.0, Vector2.ZERO, false)
	check.call(int(r2.packs[&"brook_east"].state) == Rules.PACK_ENGAGED, "덤빔: 먼 데서 맞아도 덤빈다")


func _leash() -> void:
	var r := _field()
	r.debug_god = true
	r.spawn_pack(&"road_south")
	var home: Vector2 = FieldLayout.PACKS["road_south"].at
	var returned: Array = [0]
	var at_home: Array = [true]
	r.pack_returned.connect(func(_id: StringName) -> void:
		returned[0] += 1
		for e in r.enemies:
			at_home[0] = at_home[0] and e.hp == e.max_hp and e.pos.distance_to(e.home) < 0.6)
	r.lord.pos = home + Vector2(5, 0)
	for t in 30:
		r.step()
	check.call(int(r.packs[&"road_south"].state) == Rules.PACK_ENGAGED, "돌아가기: 먼저 덤빈다")
	for e in r.enemies:
		e.hp = 1.0
		e.pos = home + Vector2(18, 0)
	# 25칸 안에서는 쫓는다
	r.lord.pos = home + Vector2(FieldLayout.PACK_LEASH - 1.0, 0)
	r.step()
	check.call(int(r.packs[&"road_south"].state) == Rules.PACK_ENGAGED, "돌아가기: 25칸 안이면 계속 쫓는다")
	r.lord.pos = home + Vector2(FieldLayout.PACK_LEASH + 1.0, 0)
	r.step()
	check.call(int(r.packs[&"road_south"].state) == Rules.PACK_RETURNING, "돌아가기: 제자리에서 25칸 넘게 멀어지면 돌아간다")
	var healing: bool = true
	var hp0: float = r.enemies[0].hp
	for t in 12:
		r.step()
	for e in r.enemies:
		healing = healing and e.hp > 1.0
	check.call(healing and r.enemies[0].hp > hp0, "돌아가기: 돌아가는 동안 체력이 찬다")
	for t in 1200:
		r.step()
	check.call(at_home[0] and int(r.packs[&"road_south"].state) == Rules.PACK_IDLE and returned[0] == 1, "돌아가기: 제자리에 닿으면 체력이 다 차고 다시 서성인다")
	check.call(r.lord.hp == r.max_hp(), "돌아가기: 영주는 맞지 않았다")


func _wander() -> void:
	var r := _field()
	r.spawn_pack(&"old_field")
	var home: Vector2 = FieldLayout.PACKS["old_field"].at
	var w: float = FieldLayout.PACKS["old_field"].wander
	r.lord.pos = home + Vector2(0, 40)
	var moved: bool = false
	var inside: bool = true
	var start: Array[Vector2] = []
	for e in r.enemies:
		start.append(e.pos)
	for t in 900:
		r.lord.pos = home + Vector2(0, 40)
		r.step()
		for e in r.enemies:
			inside = inside and e.pos.distance_to(home) <= w + 0.5
	for i in r.enemies.size():
		moved = moved or r.enemies[i].pos.distance_to(start[i]) > 0.3
	check.call(inside, "서성임: 제자리 반지름 안에 머문다")
	check.call(moved, "서성임: 가만있지 않고 천천히 움직인다")
	var night_before: float = r.night_left
	for t in 300:
		r.lord.pos = home + Vector2(0, 40)
		r.step()
	check.call(r.night_left == night_before and r.phase == Rules.Phase.NIGHT and r.zone == 0 and r.enemies.size() == 5, "들판 모드: 낮밤·구역 시간이 흐르지 않고 밤 나오기가 없다")


func _rewards() -> void:
	var r := _field()
	var m := Meta.new()
	m.rng.seed = 3
	r.spawn_pack(&"road_south")
	var cleared: Array = []
	var kills: Array = [0]
	r.pack_cleared.connect(func(id: StringName) -> void: cleared.append(id))
	r.enemy_died.connect(func(e: Enemy) -> void:
		if e.pack != &"":
			kills[0] += m.field_kill())
	var es: Array[Enemy] = r.enemies.duplicate()
	r.hurt(es[0], 99999.0, Vector2.ZERO, false)
	r.hurt(es[1], 99999.0, Vector2.ZERO, false)
	r.step()
	check.call(kills[0] == 2 * FieldLayout.PACK_KILL_SHARDS and m.shards == 2 and cleared.is_empty(), "보상: 적 하나에 조각 1")
	r.hurt(es[2], 99999.0, Vector2.ZERO, false)
	r.step()
	r.step()
	check.call(cleared == [&"road_south"], "보상: 무리를 다 쓰러뜨리면 신호가 한 번 온다")
	var got: int = m.field_clear("road_south")
	check.call(got >= FieldLayout.PACK_CLEAR_MIN and got <= FieldLayout.PACK_CLEAR_MAX and m.shards == 3 + got, "보상: 무리 전멸 조각 5~10")
	check.call(m.packs_cleared.has("road_south") and m.field_clear("road_south") == 0 and m.shards == 3 + got, "보상: 같은 무리는 두 번 안 준다")
	var seen := {}
	for s in 40:
		var mm := Meta.new()
		mm.rng.seed = s
		seen[mm.field_clear("x")] = 1
	check.call(seen.size() >= 4, "보상: 조각 수는 Meta.rng로 범위에서 달라진다")
	# 쓰러뜨린 무리는 안 생기고, 판이 끝나면(record_run) 비워져 다시 생긴다
	var r2 := _field()
	r2.spawn_packs(m.packs_cleared)
	check.call(not r2.packs.has(&"road_south") and r2.packs.size() == 16, "보상: 쓰러뜨린 무리는 들판에 들어와도 안 생긴다")
	var hill := Rules.new(d, 5)
	m.record_run(hill, d.meta)
	check.call(m.packs_cleared.is_empty(), "보상: record_run에서 쓰러뜨린 무리를 비운다")
	var r3 := _field()
	r3.spawn_packs(m.packs_cleared)
	check.call(r3.packs.size() == 17, "보상: 판이 끝나면 무리가 다시 생긴다")
	# 무리 전멸은 마지막이 자폭해도 센다
	var r4 := _field()
	r4.spawn_pack(&"x", {"at": Vector2(30, 30), "wander": 2.0, "zone": 1, "foes": [[&"bomber", 3]]})
	var c4: Array = [0]
	r4.pack_cleared.connect(func(_id: StringName) -> void: c4[0] += 1)
	for e in r4.enemies.duplicate():
		r4.foes.explode(e)
	r4.step()
	check.call(c4[0] == 1, "보상: 모두 터져 없어져도 무리 전멸로 센다")


func _death() -> void:
	var r := _field()
	r.spawn_pack(&"road_south")
	var over: Array = []
	r.run_ended.connect(func(won: bool) -> void: over.append(won))
	r.lord.hp = 1.0
	r.lord.invuln = 0.0
	r._hurt_lord(50.0)
	check.call(r.phase == Rules.Phase.OVER and over == [false], "쓰러짐: 들판에서도 쓰러지면 신호가 온다")
	var r2 := _field()
	r2.lord.hp = 10.0
	r2.start_field()
	check.call(r2.lord.hp == r2.max_hp(), "쓰러짐: 들판에 나갈 때마다 체력이 가득")


func _script_inputs(t: int) -> LordInput:
	var i := LordInput.new()
	i.move = Vector2(0.0, -1.0) if t < 500 else Vector2(1.0, 0.0)
	i.attack = t % 7 < 4
	i.dash = t % 90 == 0
	i.aim_valid = true
	i.aim = Vector2(35.0, 80.0)
	return i


func _replay() -> void:
	var h: Array[int] = []
	for run in 2:
		var r := _field(11)
		r.debug_god = true
		r.lord.pos = Vector2(40, 100)
		r.slots[0] = Sword.new(d.swords[0], d)
		r.spawn_packs()
		for t in 900:
			r.step(_script_inputs(t))
		h.append(r.state_hash())
	check.call(h[0] == h[1], "결정성: 같은 시드·같은 입력이면 들판 state_hash가 같다")
	var r3 := _field(12)
	r3.debug_god = true
	r3.lord.pos = Vector2(40, 100)
	r3.slots[0] = Sword.new(d.swords[0], d)
	r3.spawn_packs()
	for t in 900:
		r3.step(_script_inputs(t))
	check.call(r3.state_hash() != h[0], "결정성: 시드가 다르면 달라진다")


func _save() -> void:
	var path: String = "user://test_pack_save.json"
	var m := Meta.new()
	m.field_clear("grove")
	m.field_clear("foot")
	m.save(path)
	var m2 := Meta.load_or_new(path)
	check.call(m2.packs_cleared.size() == 2 and m2.packs_cleared.has("grove") and m2.shards == m.shards, "저장: 쓰러뜨린 무리도 저장하고 읽는다")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"shards": 9, "field_found": {"cache_1": 1}}))
	f.close()
	var m3 := Meta.load_or_new(path)
	check.call(m3.shards == 9 and m3.packs_cleared.is_empty() and m3.field_found.has("cache_1"), "저장: 옛 저장은 쓰러뜨린 무리가 비어 있는 기본값으로 읽는다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# 북문에서 고른 검은 부러지지 않는다
	var m4 := Meta.new()
	var s: Sword = m4.unbreakable_sword(d, d.swords[0].id)
	check.call(s != null and not s.breakable() and m4.unbreakable_sword(d, 0) == null, "들판 검: 고른 검은 부러지지 않고 0은 맨손")
