extends RefCounted
## 37단계 적 길찾기 테스트(docs/open_world2.md). 규칙의 막힘(Rules.set_blockers → Nav): 나무·벽을 돌아서 닿음, 그동안 막힘 안에 안 들어감,
## 무덤 방 벽과 닫힌 문, 몸 크기별 격자, 놓아줌 때 돌아감, 돌진·부르기 자리, 결정성, 막힘이 없으면 예전과 같음, 들판 표, 성능.
## run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/pathing_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_tree()
	_wall()
	_sizes()
	_leash_detour()
	_charge_and_summon()
	_crypt_walls()
	_crypt_doors()
	_no_blockers_same()
	_hill_untouched()
	_field_table()
	_replay()
	_perf()
	Grid.size = Vector2i(34, 22)


## 막힘 표를 준 들판 모드 규칙(40×30칸, 관리용 무적). 영주는 at에 가만히 선다.
func _rules(seed_value: int, rects: Array, circles: Array, lord_at: Vector2, area := Vector2i(40, 30)) -> Rules:
	var r := Rules.new(d, seed_value)
	Grid.size = area
	r.start_field()
	r.debug_god = true
	r.lord.pos = lord_at
	r.lord.prev_pos = lord_at
	if not rects.is_empty() or not circles.is_empty():
		r.set_blockers(rects, circles)
	return r


## 무리 하나를 home에 세우고 덤비게 한다. 적은 home에서 x로 0.8칸씩 늘어선다(시드와 상관없이 같은 자리에서 출발).
func _pack(r: Rules, home: Vector2, foes: Array, id: StringName = &"t") -> Array[Enemy]:
	var es: Array[Enemy] = r.spawn_pack(id, {"at": home, "wander": 1.5, "zone": 1, "foes": foes})
	for i in es.size():
		es[i].pos = home + Vector2((i - (es.size() - 1) / 2.0) * 0.8, 0.0)
		es[i].prev_pos = es[i].pos
		es[i].home = es[i].pos
	r._engage_pack(id)
	return es


## ticks틱 돌리며 적마다 영주에게 닿은 틱(기다림 거리 + 0.5칸 안)과 막힘 안에 들어간 횟수, 돌아온(detour) 틱 수를 센다.
func _watch(r: Rules, es: Array[Enemy], rects: Array, circles: Array, ticks: int) -> Dictionary:
	var reached: Dictionary = {}
	var inside: int = 0
	var detours: int = 0
	var max_x: float = -INF
	var min_x: float = INF
	for t in ticks:
		r.step()
		for e in es:
			if e.dead:
				continue
			if Blockers.inside(e.pos, rects, circles, [], [], false, e.radius - 0.02):
				inside += 1
			if e.detour:
				detours += 1
			max_x = maxf(max_x, e.pos.x)
			min_x = minf(min_x, e.pos.x)
			if not reached.has(e) and e.pos.distance_to(r.lord.pos) <= r.tokens.wait_dist(e) + 0.5:
				reached[e] = t
	return {"reached": reached, "inside": inside, "detours": detours, "max_x": max_x, "min_x": min_x}


## 곧은 선이 막힘(넓히지 않은 표)을 지나는가: 막힘이 없을 때 적이 이 선으로 온다.
func _crosses(a: Vector2, b: Vector2, rects: Array, circles: Array) -> bool:
	for i in 41:
		if Blockers.inside(a.lerp(b, i / 40.0), rects, circles, [], [], false, 0.0):
			return true
	return false


func _tree() -> void:
	var circles: Array = [[Vector2(20, 16), 1.2]]
	var lord_at := Vector2(20, 22)
	var home := Vector2(20, 10)
	check.call(_crosses(home, lord_at, [], circles), "길찾기(나무): 시험 자리는 곧은 선이 나무를 지난다")
	var r := _rules(3, [], circles, lord_at)
	var es := _pack(r, home, [[&"wolf", 2], [&"wraith", 2]])
	var w := _watch(r, es, [], circles, 450)
	check.call((w.reached as Dictionary).size() == es.size(), "길찾기(나무): 나무 너머 영주에게 넷 다 닿는다(%d/%d)" % [(w.reached as Dictionary).size(), es.size()])
	check.call(int(w.inside) == 0, "길찾기(나무): 오는 동안 나무 안에 들어간 적이 없다(%d)" % int(w.inside))
	check.call(int(w.detours) > 0, "길찾기(나무): 곧은 선이 막혀 흐름장을 따라 돌아왔다")
	# 막힘을 안 주면(예전) 곧장 나무를 뚫고 온다
	var r0 := _rules(3, [], [], lord_at)
	var es0 := _pack(r0, home, [[&"wolf", 2], [&"wraith", 2]])
	var w0 := _watch(r0, es0, [], circles, 450)
	check.call(int(w0.inside) > 0 and r0.nav == null, "길찾기(나무): 막힘 표가 없으면 예전처럼 곧장 뚫고 온다")


func _wall() -> void:
	var rects: Array = [Rect2(12, 15, 16, 1.0)]
	var lord_at := Vector2(20, 22)
	var home := Vector2(20, 10)
	var r := _rules(5, rects, [], lord_at)
	var es := _pack(r, home, [[&"wolf", 2], [&"wraith", 2], [&"giant", 1]])
	var w := _watch(r, es, rects, [], 900)
	check.call((w.reached as Dictionary).size() == es.size(), "길찾기(벽): 16칸 벽 너머 영주에게 다섯 다 닿는다(거인 포함, %d/%d)" % [(w.reached as Dictionary).size(), es.size()])
	check.call(int(w.inside) == 0, "길찾기(벽): 오는 동안 벽 안에 들어간 적이 없다(%d)" % int(w.inside))
	check.call(float(w.max_x) > 28.0 or float(w.min_x) < 12.0, "길찾기(벽): 벽 끝을 돌아서 왔다")
	# ㄷ자 벽(영주가 안쪽, 입구는 반대편): 막다른 곳에서 멈추지 않고 입구로 돌아 들어온다
	var u: Array = [Rect2(12, 14, 16, 1.0), Rect2(12, 14, 1, 8), Rect2(27, 14, 1, 8)]
	var ru := _rules(6, u, [], Vector2(20, 19))
	var eu := _pack(ru, Vector2(20, 6), [[&"wolf", 2], [&"wraith", 1]])
	var wu := _watch(ru, eu, u, [], 900)
	check.call((wu.reached as Dictionary).size() == eu.size() and int(wu.inside) == 0, "길찾기(ㄷ자 벽): 막다른 벽에 붙지 않고 입구로 돌아 들어와 닿는다(%d/%d)" % [(wu.reached as Dictionary).size(), eu.size()])


## 몸 크기별 격자: 1.6칸 틈은 작은 적(늑대)만 지나고, 큰 적(거인, 반지름 0.62)은 벽 끝으로 돌아간다.
func _sizes() -> void:
	var rects: Array = [Rect2(8, 15, 11.2, 1.0), Rect2(20.8, 15, 11.2, 1.0)]
	var lord_at := Vector2(20, 22)
	var r := _rules(7, rects, [], lord_at)
	check.call(Nav.class_of(d.enemies[&"wolf"].radius) == 0 and Nav.class_of(d.enemies[&"giant"].radius) == 1 and Nav.class_of(d.enemies[&"chief_burnt"].radius) == 1, "몸 크기: 늑대는 작은 격자, 거인·우두머리는 큰 격자")
	check.call(r.nav.free_at(Vector2(20, 15.5), 0) and not r.nav.free_at(Vector2(20, 15.5), 1), "몸 크기: 1.6칸 틈은 작은 격자에서만 트였다")
	var es := _pack(r, Vector2(20, 9), [[&"wolf", 1], [&"giant", 1]])
	var wolf_gap: bool = false
	var giant_gap: bool = false
	var inside: int = 0
	for t in 1500:
		r.step()
		for e in es:
			if absf(e.pos.y - 15.5) < 0.6 and absf(e.pos.x - 20.0) < 1.0:
				if e.data.id == &"wolf":
					wolf_gap = true
				else:
					giant_gap = true
			if Blockers.inside(e.pos, rects, [], [], [], false, e.radius - 0.02):
				inside += 1
	var giant: Enemy = es[1]
	check.call(wolf_gap, "몸 크기: 늑대는 틈으로 지나온다")
	check.call(not giant_gap and inside == 0, "몸 크기: 거인은 틈에 끼지 않고(막힘 안에도 안 들어가고) 벽 끝으로 돈다")
	check.call(giant.pos.distance_to(lord_at) <= r.tokens.wait_dist(giant) + 0.5, "몸 크기: 거인도 벽 끝을 돌아 영주에게 닿는다(%.1f칸)" % giant.pos.distance_to(lord_at))


## 놓아줌: 벽 너머로 끌려온 무리가 영주가 멀어지면 벽을 돌아 제자리로 돌아간다(그동안 벽 안에 안 들어간다).
func _leash_detour() -> void:
	var rects: Array = [Rect2(10, 13, 20, 1.0)]
	var r := _rules(9, rects, [], Vector2(20, 18), Vector2i(40, 60))
	var home := Vector2(20, 8)
	var es := _pack(r, home, [[&"wolf", 2], [&"wraith", 1]])
	for e in es:
		e.pos = e.home + Vector2(0, 10)   # 벽 남쪽(영주 곁)으로 와 있다
		e.prev_pos = e.pos
	var back: Array = []
	r.pack_returned.connect(func(id: StringName) -> void: back.append(id))
	r.lord.pos = Vector2(20, 50)   # 놓아줌 거리(25칸) 밖
	r.lord.prev_pos = r.lord.pos
	var inside: int = 0
	var went_round: bool = false
	var ticks: int = 0
	for t in 1200:
		r.step()
		ticks = t
		for e in es:
			if Blockers.inside(e.pos, rects, [], [], [], false, e.radius - 0.02):
				inside += 1
			went_round = went_round or e.pos.x < 10.0 or e.pos.x > 30.0
		if not back.is_empty():
			break
	check.call(back == [&"t"], "놓아줌: 벽 너머에서도 제자리로 돌아가 다시 선다(%d틱)" % ticks)
	check.call(inside == 0 and went_round, "놓아줌: 돌아가는 동안 벽을 뚫지 않고 끝을 돌아간다")
	var at_home: bool = true
	for e in es:
		at_home = at_home and e.pos.distance_to(e.home) <= 0.5
	check.call(at_home, "놓아줌: 모두 제 자리에 섰다")


## 돌진은 막힘 앞에서 멈추고, 부르는 자리는 막힘 너머로 넘어가지 않는다.
func _charge_and_summon() -> void:
	var rects: Array = [Rect2(10, 15, 20, 1.0)]
	var r := _rules(4, rects, [], Vector2(20, 22))
	var e: Enemy = r.spawn_at(&"charger", Vector2(20, 10))
	var lane: float = r.foes._lane(e.pos, Vector2.DOWN, 8.0, e.radius)
	check.call(lane > 3.0 and lane < 5.0 - e.radius, "돌진: 벽 앞에서 멈춘다(%.2f칸, 벽까지 5칸)" % lane)
	check.call(is_equal_approx(r.foes._lane(e.pos, Vector2.UP, 6.0, e.radius), 6.0), "돌진: 트인 쪽은 그대로 간다")
	var r0 := _rules(4, [], [], Vector2(20, 22))
	check.call(is_equal_approx(r0.foes._lane(Vector2(20, 10), Vector2.DOWN, 8.0, 0.4), 8.0), "돌진: 막힘이 없으면 예전 길이")
	var c: Enemy = r.spawn_at(&"chief_caller", Vector2(20, 14.2))
	var ok: bool = true
	for k in 6:
		r.foes._aim_spots(c)
		for at in c.act_spots:
			ok = ok and at.y < 15.0 - 0.3 and r.nav.free_at(at, 0)
	check.call(ok, "부르기: 벽 곁에서 불러도 망령은 벽 이쪽 빈 곳에 선다")


## 무덤: 이웃 방의 무리가 벽 너머 영주에게 덤벼도 벽과 닫힌 문을 뚫지 않는다(예전에는 곧장 뚫었다).
func _crypt_walls() -> void:
	var cut: Array = [0, 0]
	var ok_room: Array = [true, true]
	for with_nav in [true, false]:
		var c := _crypt(21)
		var r := c.rules
		if not with_nav:
			r.nav = null
		# r2에 들어서서(문이 닫힌다) 서쪽 벽 곁에 선다
		r.lord.pos = Vector2(35, 48)
		r.lord.prev_pos = r.lord.pos
		c.step()
		r.lord.pos = Vector2(27.2, 47.0)
		r.lord.prev_pos = r.lord.pos
		var west: Array[Enemy] = r.spawn_pack(&"west", {"at": Vector2(17, 47), "wander": 1.5, "zone": 8, "foes": [[&"wolf", 2], [&"wraith", 2], [&"giant", 1]]})
		r._engage_pack(&"west")
		var room2: Rect2 = CryptLayout.ROOMS[&"r2"].rect
		var k: int = 0 if with_nav else 1
		for t in 300:
			r.step()
			c.step()
			r.lord.pos = c.push(r.lord.pos)
			for e in r.enemies:
				if e.dead:
					continue
				if e.pack != &"west" and not room2.grow(0.01).has_point(e.pos):
					ok_room[k] = false
				if e.pack == &"west" and e.pos.x > 22.0:
					cut[k] += 1
	check.call(cut[1] > 0, "무덤: (막힘을 모르면) 이웃 방 무리가 벽을 뚫고 온다")
	check.call(cut[0] == 0 and ok_room[0], "무덤: 이웃 방 무리는 벽과 닫힌 문을 뚫지 않고 제 방에 남는다, 들어선 방 무리도 방 안에만")


func _crypt(seed_value: int) -> CryptRun:
	var r := Rules.new(d, seed_value)
	Grid.size = CryptLayout.SIZE
	r.start_field()
	r.lord.pos = CryptLayout.START
	r.lord.prev_pos = r.lord.pos
	r.debug_god = true
	return CryptRun.new(r, Meta.new())


## 무덤의 문: 닫히면 적에게도 막힘, 쓰러뜨려 열리면 복도로 다닌다(CryptRun이 Rules.set_open_gates를 부른다).
func _crypt_doors() -> void:
	var c := _crypt(22)
	var r := c.rules
	var mid: Vector2 = (CryptLayout.DOORS[&"d12"].gap as Rect2).get_center()
	check.call(r.nav != null and r.nav.free_at(mid, 0) and r.nav.free_at(mid, 1), "무덤 문: 처음(아무 방에도 안 들어섬)에는 문 복도가 트였다")
	c.step()   # 입구 방에 들어선다: 무리가 서고 문이 닫힌다
	check.call(c.door_closed(&"d12") and not r.nav.free_at(mid, 0) and not r.nav.free_at(mid, 1), "무덤 문: 닫힌 문 복도는 적에게도 막힘")
	# 싸우는 중에 방 가장자리(문 앞 1.5칸 안)로 물러서도 문이 다시 열리지 않는다
	var keep: Vector2 = r.lord.pos
	r.lord.pos = Vector2(35, 58.8)
	c.step()
	check.call(c.room == &"r1" and c.door_closed(&"d12") and not r.nav.free_at(mid, 0), "무덤 문: 들어선 방 가장자리로 물러서도 문은 닫힌 채다")
	r.lord.pos = keep
	var inside: bool = true
	for t in 200:
		r.step()
		c.step()
		for e in r.enemies:
			inside = inside and (CryptLayout.ROOMS[&"r1"].rect as Rect2).grow(0.01).has_point(e.pos)
	check.call(inside, "무덤 문: 문이 닫힌 동안 방 무리는 방 안에만 있다")
	for e in r.enemies.duplicate():
		r.hurt(e, 1.0e9, Vector2.ZERO, false)
	r.step()
	c.step()
	check.call(not c.door_closed(&"d12") and r.nav.free_at(mid, 0), "무덤 문: 방을 쓰러뜨려 문이 열리면 복도가 다시 트인다")


## 막힘이 멀면(곧은 선이 트였으면) 막힘 표가 없을 때와 틱마다 똑같다: 걷기·표·돌진·놓아줌까지(37단계가 싸움 손맛을 바꾸지 않는다).
func _no_blockers_same() -> void:
	var far: Array = [[Vector2(2, 2), 0.5]]
	var ha: Array[int] = []
	var hb: Array[int] = []
	var detours: int = 0
	for with_nav in [false, true]:
		var r := _rules(31, [], far if with_nav else [], Vector2(20, 20), Vector2i(40, 70))
		r.slots[0] = Sword.new(d.swords[0], d)
		_pack(r, Vector2(20, 12), [[&"wolf", 2], [&"charger", 1], [&"archer", 1], [&"caller", 1]])
		for t in 900:
			var i := LordInput.new()
			i.move = Vector2(0.0, 1.0) if t > 450 else Vector2(0.3, 0.0) if t % 120 < 60 else Vector2(-0.3, 0.0)
			i.attack = t % 9 < 3
			i.aim_valid = true
			i.aim = Vector2(20, 12)
			r.step(i)
			(hb if with_nav else ha).append(r.state_hash())
			for e in r.enemies:
				if e.detour:
					detours += 1
		if with_nav:
			check.call(r.packs[&"t"].state != Rules.PACK_ENGAGED, "막힘 없음: 시험 끝에 무리를 놓아주었다(돌아가기까지 같은지 본다)")
	check.call(ha == hb and detours == 0, "막힘 없음: 막힘이 멀면 막힘 표가 없을 때와 900틱 내내 state_hash가 같다")


## 언덕 싸움터와 결투는 막힘이 없다(nav 없음, 예전과 같은 길).
func _hill_untouched() -> void:
	var r := Rules.new(d, 41)
	r.start_night()
	var detour: bool = false
	for t in 600:
		r.step()
		for e in r.enemies:
			detour = detour or e.detour
	check.call(r.nav == null and not detour and r.enemies.size() > 0, "언덕: 막힘이 없어 적은 예전처럼 곧장 온다(nav 없음)")
	var q := Rules.new(d, 42)
	q.start_duel(null, null)
	check.call(q.nav == null, "결투: 막힘이 없다(nav 없음)")


## 들판의 막힘 표: 장면(FieldBuilder.build)과 규칙 테스트(FieldBuilder.blockers)가 같은 표를 만들고, 늘 같다.
## 무리·우두머리·무덤 기사의 제자리는 그 몸이 설 수 있는 곳이다.
func _field_table() -> void:
	var b1: Dictionary = FieldBuilder.blockers()
	var b2: Dictionary = FieldBuilder.blockers()
	var root := Node3D.new()
	var full: Dictionary = FieldBuilder.build(root, Environment.new())
	root.free()
	check.call(str(b1) == str(b2) and (b1.rects as Array).size() > 50 and (b1.circles as Array).size() > 50, "들판 표: 막힘 표만 만드는 함수는 늘 같은 표를 낸다")
	check.call(str(b1) == str(full), "들판 표: 장면이 짓는 표(build)와 똑같다(꾸밈을 건너뛰어도 랜덤 차례가 같다)")
	Grid.size = FieldLayout.SIZE
	var nav := Nav.new(Vector2(FieldLayout.SIZE), b1.rects, b1.circles, b1.low_rects, b1.low_circles)
	var ok_pack: bool = true
	for id in FieldLayout.PACKS:
		ok_pack = ok_pack and nav.free_at(FieldLayout.PACKS[id].at, 0)
	for id in FieldLayout.NIGHT_PACKS:
		ok_pack = ok_pack and nav.free_at(FieldLayout.NIGHT_PACKS[id].at, 0)
	var ok_big: bool = nav.free_at(FieldLayout.BOSS_AT, 1)
	for id in FieldLayout.CHIEFS:
		ok_big = ok_big and nav.free_at(FieldLayout.CHIEFS[id].at, 1)
	check.call(ok_pack, "들판 표: 무리 제자리는 작은 적이 설 수 있는 곳")
	check.call(ok_big, "들판 표: 우두머리·무덤 기사 제자리는 큰 적이 설 수 있는 곳")


## 들판 표로 성채 둘레에서 싸운다: 같은 시드·같은 입력이면 같은 state_hash, 막힘 안에 안 들어간다.
func _replay() -> void:
	var b: Dictionary = FieldBuilder.blockers()
	var all_r: Array = b.rects + b.low_rects
	var all_c: Array = b.circles + b.low_circles
	var h: Array = []
	var inside: Array[int] = [0, 0]
	var detours: Array[int] = [0, 0]
	for run in 3:
		var r := _keep_fight(b, 51 if run < 2 else 52)
		var line: Array[int] = []
		for t in 600:
			r.step(_keep_input(t))
			r.lord.pos = Blockers.push_out(r.lord.pos, b.rects, b.circles, b.low_rects, b.low_circles, r.lord.airborne())
			if t % 30 == 0:
				line.append(r.state_hash())
			if run < 2:
				for e in r.enemies:
					if not e.dead and Blockers.inside(e.pos, all_r, all_c, [], [], false, e.radius - 0.02):
						inside[run] += 1
					if e.detour:
						detours[run] += 1
		h.append(line)
	check.call(h[0] == h[1], "결정성: 같은 시드·같은 입력이면 들판 막힘 둘레 싸움의 state_hash가 같다")
	check.call(h[2] != h[0], "결정성: 시드가 다르면 달라진다")
	check.call(inside[0] == 0 and detours[0] > 0, "들판: 성채 벽을 돌아오고(%d) 막힘 안에 들어간 적이 없다(%d)" % [detours[0], inside[0]])


## 성채 안에 영주, 성벽 밖 넷에 무리(20마리), 모두 덤빈다.
func _keep_fight(b: Dictionary, seed_value: int) -> Rules:
	var r := Rules.new(d, seed_value)
	Grid.size = FieldLayout.SIZE
	r.start_field()
	r.debug_god = true
	r.set_blockers(b.rects, b.circles, b.low_rects, b.low_circles)
	r.lord.pos = Vector2(140, 26)
	r.lord.prev_pos = r.lord.pos
	r.slots[0] = Sword.new(d.swords[0], d)
	var defs: Array = [
		{"at": Vector2(140, 6), "foes": [[&"wolf", 2], [&"wraith", 2], [&"charger", 1]]},
		{"at": Vector2(116, 26), "foes": [[&"wraith", 3], [&"shield", 1], [&"archer", 1]]},
		{"at": Vector2(163, 20), "foes": [[&"wolf", 3], [&"bomber", 1], [&"giant", 1]]},
		{"at": Vector2(140, 45), "foes": [[&"wraith", 2], [&"shield", 1], [&"charger", 1], [&"caller", 1]]},
	]
	for i in defs.size():
		var def: Dictionary = defs[i]
		def["wander"] = 2.0
		def["zone"] = 7
		r.spawn_pack(StringName("k%d" % i), def)
		r._engage_pack(StringName("k%d" % i))
	return r


func _keep_input(t: int) -> LordInput:
	var i := LordInput.new()
	var a: float = t * 0.012
	i.move = Vector2(cos(a), sin(a)) * 0.5 if (t / 150) % 2 == 1 else Vector2.ZERO
	i.attack = t % 11 < 4
	i.aim_valid = true
	i.aim = Vector2(140, 20)
	return i


## 성능: 들판 표·적 20마리가 성벽을 돌아오는 싸움에서 한 틱 규칙 시간(헤드리스). 30Hz 한 틱(33ms)에 넉넉해야 한다.
func _perf() -> void:
	var b: Dictionary = FieldBuilder.blockers()
	var res: Array = []
	for with_nav in [false, true]:
		var r := _keep_fight(b, 61)
		if not with_nav:
			r.nav = null
		var times: Array[int] = []
		for t in 900:
			var t0: int = Time.get_ticks_usec()
			r.step(_keep_input(t))
			times.append(Time.get_ticks_usec() - t0)
			r.lord.pos = Blockers.push_out(r.lord.pos, b.rects, b.circles, b.low_rects, b.low_circles, r.lord.airborne())
		var sum: int = 0
		for x in times:
			sum += x
		times.sort()
		res.append([sum / 900.0 / 1000.0, times[int(times.size() * 0.95)] / 1000.0, times[times.size() - 1] / 1000.0])
	print("길찾기 성능(적 20, 900틱): 막힘 없음 평균 %.2fms · 95%% %.2fms · 최대 %.2fms / 막힘 있음 평균 %.2fms · 95%% %.2fms · 최대 %.2fms" % [res[0][0], res[0][1], res[0][2], res[1][0], res[1][1], res[1][2]])
	check.call(float(res[1][0]) < 3.0, "성능: 적 20마리가 막힘을 돌아오는 들판 싸움의 한 틱 평균이 3ms 아래(%.2fms)" % float(res[1][0]))
