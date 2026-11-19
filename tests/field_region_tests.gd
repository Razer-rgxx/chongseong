extends RefCounted
## 20단계 새 지역 테스트(docs/outside.md): 동쪽으로 넓힌 들판, 무너진 성채, 안개 늪. run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/field_region_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_size_and_walk()
	_areas()
	_finds()
	_blockers()
	_packs()
	_pack_fight()
	_stones()
	_glints()
	_marsh()
	_save()
	Grid.size = Vector2i(34, 22)


func _field(seed_value: int = 1) -> Rules:
	var r := Rules.new(d, seed_value)
	Grid.size = FieldLayout.SIZE
	r.start_field()
	r.lord.pos = Vector2(112, 58)
	r.lord.prev_pos = r.lord.pos
	return r


func _size_and_walk() -> void:
	check.call(FieldLayout.SIZE == Vector2i(170, 110) and FieldLayout.WORLD_X == 340.0 and FieldLayout.WORLD_Z == 220.0, "새 지역: 들판은 170 x 110칸(동쪽으로 60칸)")
	var r := _field()
	var inp := LordInput.new()
	inp.move = Vector2(1.0, 0.0)
	for _t in 1500:
		r.step(inp)
	check.call(r.lord.pos.x > 160.0 and r.lord.pos.x <= 170.0, "새 지역: 영주가 원래 동쪽 끝(110)을 넘어 새 크기 끝까지 걷는다")
	inp.move = Vector2(0.0, -1.0)
	r.lord.pos = Vector2(140, 50)
	for _t in 1500:
		r.step(inp)
	check.call(r.lord.pos.y >= 0.5 and r.lord.pos.y < 2.0 and r.lord.pos.x == 140.0, "새 지역: 북쪽 끝도 새 크기 안에서 막힌다")
	# 틈: 개울 근처만 원래 동쪽 둘레가 뚫려 있다
	var open: bool = true
	for rc in FieldLayout.BORDER_RECTS:
		open = open and not rc.has_point(Vector2(108.5, 59.0))
	var blocked_n: bool = false
	var blocked_s: bool = false
	var blocked_e: bool = false
	var blocked_old_w: bool = false
	for rc in FieldLayout.BORDER_RECTS:
		blocked_n = blocked_n or rc.has_point(Vector2(108.5, 40.0))
		blocked_s = blocked_s or rc.has_point(Vector2(108.5, 80.0))
		blocked_e = blocked_e or rc.has_point(Vector2(168.5, 58.0))
		blocked_old_w = blocked_old_w or rc.has_point(Vector2(1.5, 50.0))
	check.call(open and blocked_n and blocked_s, "새 지역: 원래 동쪽 둘레는 개울 근처(y 52~66)만 틈이 나 있다")
	check.call(blocked_e and blocked_old_w, "새 지역: 새 동쪽 둘레와 원래 서쪽 둘레는 막혀 있다")
	check.call(FieldLayout.START == Vector2(55, 103) and FieldLayout.GATE == Vector2(55, 107.2) and FieldLayout.BOSS_AT == Vector2(84, 96), "새 지역: 원래 자리(시작·문·보스)는 그대로")


func _areas() -> void:
	check.call(FieldLayout.area_at(Vector2(140, 25)) == &"keep" and FieldLayout.area_at(Vector2(140, 90)) == &"marsh", "곳 판정: 성채와 늪 안의 점")
	check.call(FieldLayout.area_at(Vector2(140, 58)) == &"brook" and FieldLayout.area_at(Vector2(55, 100)) == &"road" and FieldLayout.area_at(Vector2(84, 78)) == &"old_field", "곳 판정: 동쪽 개울가와 원래 곳은 그대로")
	check.call(FieldLayout.AREA_NAMES[&"keep"] == "무너진 성채" and FieldLayout.AREA_NAMES[&"marsh"] == "안개 늪", "곳 이름: 무너진 성채, 안개 늪")
	var all_named: bool = true
	for id in FieldLayout.AREA_ORDER:
		all_named = all_named and FieldLayout.AREA_NAMES.has(StringName(id)) and FieldLayout.AREAS.has(StringName(id))
	check.call(all_named, "곳 표: 모든 곳에 이름이 있다")
	var ka: Rect2 = FieldLayout.AREAS[&"keep"]
	var ma: Rect2 = FieldLayout.AREAS[&"marsh"]
	check.call(not ka.intersects(ma) and ka.position.x >= 110.0 and ma.position.x >= 110.0 and ka.end.x <= 168.0 and ma.end.x <= 168.0 and ma.end.y <= 108.0, "곳 표: 성채와 늪은 겹치지 않고 새 땅 안에 있다")
	var in_walls: bool = true
	for w in FieldLayout.KEEP_WALLS:
		in_walls = in_walls and ka.encloses(w)
	check.call(in_walls and ka.encloses(FieldLayout.KEEP_TOWER) and FieldLayout.KEEP_WALLS.size() >= 6, "성채: 성벽 조각과 탑은 성채 안에 있다")
	# 성벽에 틈이 있다: 서·동 벽 둘 다 가운데가 비고, 북·남 벽도 가운데가 빈다
	var west_gap: bool = true
	for w in FieldLayout.KEEP_WALLS:
		west_gap = west_gap and not w.has_point(Vector2(122.5, 26.0)) and not w.has_point(Vector2(157.5, 27.0)) and not w.has_point(Vector2(139.0, 39.5)) and not w.has_point(Vector2(136.0, 12.5))
	check.call(west_gap, "성채: 성벽은 군데군데 틈이 있다(드나들 수 있다)")


func _finds() -> void:
	check.call(FieldLayout.CACHES.size() == 10 and FieldLayout.CACHES.has("cache_9") and FieldLayout.CACHES.has("cache_10"), "상자: 유품 상자 10개(성채에 cache_9, cache_10)")
	for id in ["cache_9", "cache_10"]:
		var c: Array = FieldLayout.CACHES[id]
		check.call(FieldLayout.area_at(c[0]) == &"keep" and int(c[1]) > 0, "상자: %s는 성채 안, 조각이 있다" % id)
	check.call(FieldLayout.STONES.size() == 7 and FieldLayout.STONES.has("stone_7") and FieldLayout.area_at(FieldLayout.STONES["stone_7"][0]) == &"keep", "비석: 7개, stone_7은 성채 안")
	var lines: int = (FieldLayout.STONES["stone_7"][2] as String).count("\n") + 1
	check.call(lines >= 2 and lines <= 3 and (FieldLayout.STONES["stone_7"][1] as String) != "", "비석: stone_7 글은 2~3줄")
	var m := Meta.new()
	check.call(m.field_open("cache_9", FieldLayout.CACHES["cache_9"][1]) == 45 and m.field_open("cache_9", 45) == 0 and m.field_open("cache_10", FieldLayout.CACHES["cache_10"][1]) == 55 and m.shards == 100, "상자: 새 상자도 한 번만 조각을 준다")
	check.call(FieldLayout.GLINTS.size() == 20 and FieldLayout.GLINT_ACTIVE == 4, "조각 후보: 20곳(16 → 20), 판마다 4곳")
	var marsh_n: int = 0
	for i in range(16, 20):
		marsh_n += 1 if FieldLayout.area_at(FieldLayout.GLINTS[i]) == &"marsh" else 0
	check.call(marsh_n == 4, "조각 후보: 새 4곳은 안개 늪 안")


func _blockers() -> void:
	var root := Node3D.new()
	var b: Dictionary = FieldBuilder.build(root, Environment.new())
	var rects: Array = b.rects
	var has_all: bool = rects.has(FieldLayout.KEEP_TOWER)
	for w in FieldLayout.KEEP_WALLS:
		has_all = has_all and rects.has(w)
	check.call(has_all, "성채: 그린 성벽과 탑이 막힌 곳(rects)에 든다")
	var clear: bool = true
	var spots: Array[Vector2] = [FieldLayout.CACHES["cache_9"][0], FieldLayout.CACHES["cache_10"][0], FieldLayout.STONES["stone_7"][0]]
	for i in range(16, 20):
		spots.append(FieldLayout.GLINTS[i])
	for p in spots:
		for rc: Rect2 in rects:
			clear = clear and not rc.grow(0.6).has_point(p)
		for c in b.circles:
			clear = clear and p.distance_to(c[0]) >= float(c[1]) + 0.6
	check.call(clear, "새 지역: 상자·비석·조각 후보는 막힌 곳과 겹치지 않는다")
	# 성문(남쪽 틈)으로 안으로 들어갈 수 있다: 틈 자리에 막힘이 없다
	var gate_open: bool = true
	for rc: Rect2 in rects:
		gate_open = gate_open and not rc.grow(0.3).has_point(Vector2(139.0, 39.6)) and not rc.grow(0.3).has_point(Vector2(139.0, 46.0))
	check.call(gate_open, "성채: 남쪽 성문 자리는 막혀 있지 않다")
	# 땅: 늪은 얕은 물(깊이 1m 안), 성채 둘레는 걸을 만하다
	var low: float = 1e9
	var high: float = -1e9
	for ix in 20:
		for iz in 14:
			var x: float = (118.0 + ix * 2.0) * Grid.CELL
			var z: float = (76.0 + iz * 2.2) * Grid.CELL
			var h: float = FieldBuilder.walk_height(x, z)
			low = minf(low, h)
			high = maxf(high, h)
	check.call(low > -1.0 and high < 1.2, "늪: 땅은 얕은 물 높이(-1m ~ 1.2m)에 있다")
	check.call(FieldBuilder.marsh_mask(278.0, 176.0) > 0.99 and FieldBuilder.marsh_mask(100.0, 180.0) == 0.0 and FieldBuilder.marsh_mask(280.0, 100.0) == 0.0, "늪: 안개 늪 가운데는 1, 바깥은 0")
	# 원래 동쪽 둘레: 틈은 걸을 만하고 둘레는 솟아 있다
	var gap_h: float = FieldBuilder.walk_height(217.0, 118.0)
	var wall_h: float = FieldBuilder.height(217.0, 60.0)
	check.call(wall_h - gap_h > 2.5, "원래 동쪽 둘레: 틈보다 솟은 언덕 띠")
	root.free()


func _packs() -> void:
	var ids: Array[String] = ["keep_yard", "keep_gate", "marsh_west", "marsh_east"]
	var r := _field()
	var ok_kinds: bool = true
	var ok_count: bool = true
	var ok_zone: bool = true
	for id in ids:
		check.call(FieldLayout.PACKS.has(id), "새 무리: %s가 PACKS에 있다" % id)
		var p: Dictionary = FieldLayout.PACKS[id]
		var n: int = 0
		for f in p.foes:
			n += int(f[1])
			var D: EnemyData = d.enemies.get(StringName(f[0]))
			ok_kinds = ok_kinds and D != null and not D.boss and not D.still
		ok_count = ok_count and n >= 3 and n <= 6
		ok_zone = ok_zone and (int(p.zone) == 7 or int(p.zone) == 8) and FieldLayout.area_at(p.at) in [&"keep", &"marsh"]
		var es: Array[Enemy] = r.spawn_pack(StringName(id))
		check.call(es.size() == n and r.pack_alive(StringName(id)) == n, "새 무리: %s가 정한 수만큼 선다" % id)
		var in_wander: bool = true
		for e in es:
			in_wander = in_wander and e.pos.distance_to(p.at) <= float(p.wander) and e.pack == StringName(id)
		check.call(in_wander, "새 무리: %s의 적은 제자리 반지름 안" % id)
	check.call(ok_kinds and ok_count and ok_zone, "새 무리: 있는 적 3~6마리, 7~8구역 세기, 성채·늪 안")
	var zone_ok: bool = true
	for e in r.enemies:
		var pk: Dictionary = FieldLayout.PACKS[String(e.pack)]
		zone_ok = zone_ok and absf(e.max_hp - e.data.hp * d.run.zone_hp[int(pk.zone) - 1]) < 0.01
	check.call(zone_ok, "새 무리: 체력은 RunData 7~8구역 배수")
	var r2 := _field()
	r2.spawn_packs({"keep_yard": 1, "marsh_east": 1})
	check.call(r2.packs.size() == 10 and not r2.packs.has(&"keep_yard") and r2.packs.has(&"marsh_west"), "새 무리: 쓰러뜨린 무리(packs_cleared)는 다시 안 선다")
	var m := Meta.new()
	m.rng.seed = 3
	var n1: int = m.field_clear("keep_gate")
	check.call(n1 >= FieldLayout.PACK_CLEAR_MIN and n1 <= FieldLayout.PACK_CLEAR_MAX and m.packs_cleared.has("keep_gate") and m.field_clear("keep_gate") == 0, "새 무리: 전멸 조각 5~10, 한 번뿐")
	# 자리 사이: 상자·비석에서 서성임 밖, 무리끼리 겹쳐 깨지 않게 떨어져 있다
	var apart: bool = true
	for a in ids:
		for b in FieldLayout.PACKS:
			if b != a:
				apart = apart and (FieldLayout.PACKS[a].at as Vector2).distance_to(FieldLayout.PACKS[b].at) > float(FieldLayout.PACKS[a].wander) + float(FieldLayout.PACKS[b].wander) + 2.0
	check.call(apart, "새 무리: 다른 무리와 서성임이 겹치지 않는다")


func _pack_fight() -> void:
	var r := _field(5)
	r.debug_god = true
	r.slots[0] = Sword.new(d.swords[0], d)
	r.spawn_pack(&"marsh_west")
	var home: Vector2 = FieldLayout.PACKS["marsh_west"].at
	var engaged: Array = [0]
	r.pack_engaged.connect(func(_id: StringName) -> void: engaged[0] += 1)
	r.lord.pos = home + Vector2(FieldLayout.PACK_AGGRO + 2.0, 0)
	for _t in 60:
		r.step()
	check.call(engaged[0] == 0, "새 무리 싸움: 10칸 밖이면 덤비지 않는다")
	r.lord.pos = home + Vector2(FieldLayout.PACK_AGGRO - 1.0, 0)
	for _t in 90:
		r.step()
	check.call(engaged[0] == 1 and r.zone == 6 and r.tokens.total() > 0, "새 무리 싸움: 덤비면 7구역 표를 쓴다")
	r.lord.pos = home + Vector2(FieldLayout.PACK_LEASH + 5.0, 0)
	for _t in 200:
		r.step()
	check.call(int(r.packs[&"marsh_west"].state) != Rules.PACK_ENGAGED, "새 무리 싸움: 25칸 넘게 멀어지면 놓아준다")
	# 결정성
	var h: Array[int] = []
	for _k in 2:
		var q := _field(9)
		q.debug_god = true
		q.slots[0] = Sword.new(d.swords[0], d)
		q.spawn_packs()
		q.lord.pos = FieldLayout.PACKS["keep_yard"].at + Vector2(6, 0)
		for t in 400:
			var i := LordInput.new()
			i.move = Vector2(-1.0, 0.0) if t < 200 else Vector2(0.0, 1.0)
			q.step(i)
		h.append(q.state_hash())
	check.call(h[0] == h[1], "새 무리 싸움: 같은 시드·같은 입력이면 state_hash가 같다")


func _stones() -> void:
	var ids: Array = FieldLayout.STONES.keys()
	var m := Meta.new()
	var pays: int = 0
	for i in ids.size():
		pays += m.read_stone(ids[i])
		if i < ids.size() - 1:
			check.call(pays == 0, "비석 보상: 일곱 개를 다 읽기 전에는 없다")
	check.call(pays == FieldLayout.LORE_REWARD and m.shards == 30 and m.lore_paid, "비석 보상: 모든 비석(7개)을 읽으면 조각 30")
	# 옛 저장: 여섯 개를 읽고 이미 받았다 → 일곱 번째는 다시 주지 않는다
	var path: String = "user://test_region_save.json"
	var old_read := {}
	for k in ["stone_1", "stone_2", "stone_3", "stone_4", "stone_5", "stone_6"]:
		old_read[k] = 1
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"shards": 100, "lore_read": old_read, "lore_paid": true}))
	f.close()
	var m2 := Meta.load_or_new(path)
	check.call(m2.lore_paid and m2.read_stone("stone_7") == 0 and m2.shards == 100, "비석 보상: 여섯 개로 이미 받은 사람은 일곱 번째에 다시 받지 않는다")
	# 옛 저장: 여섯 개만 읽고 못 받았다(없던 일이지만) → 일곱 번째를 읽어야 받는다
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	f2.store_string(JSON.stringify({"shards": 0, "lore_read": old_read, "lore_paid": false}))
	f2.close()
	var m3 := Meta.load_or_new(path)
	check.call(m3.read_stone("stone_1") == 0 and m3.read_stone("stone_7") == FieldLayout.LORE_REWARD, "비석 보상: 아직 못 받은 사람은 모든 비석을 읽어야 받는다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _glints() -> void:
	var m := Meta.new()
	m.rng.seed = 11
	var seen_new: bool = false
	var in_range: bool = true
	for _k in 40:
		m.roll_glints()
		in_range = in_range and m.glints.size() == FieldLayout.GLINT_ACTIVE
		for g in m.glints:
			in_range = in_range and g >= 0 and g < 20
			seen_new = seen_new or g >= 16
	check.call(in_range and seen_new, "조각 후보: 뽑기는 20곳에서 4곳, 늪의 새 곳도 뽑힌다")
	check.call(FieldCreatures.CROW_SPOTS.size() >= 12 and FieldLayout.area_at(FieldCreatures.CROW_SPOTS[FieldCreatures.CROW_SPOTS.size() - 1]) == &"marsh", "짐승: 늪에 까마귀 자리가 있다")


func _marsh() -> void:
	check.call(FieldLayout.MARSH_FOG_MULT > 1.0 and FieldLayout.MARSH_FOG_TIME > 0.0, "안개 늪: 안개는 늪 안에서만 짙어진다(배수와 시간 상수)")
	# 늪 안개는 화면만: 규칙은 늪 안과 밖에서 같다(같은 입력의 state_hash)
	var hs: Array[int] = []
	for at in [Vector2(140, 90), Vector2(140, 60)]:
		var r := _field(4)
		r.lord.pos = at
		r.lord.prev_pos = at
		for _t in 120:
			r.step()
		hs.append(int(r.lord.hp))
	check.call(hs[0] == hs[1], "안개 늪: 안개는 규칙에 영향이 없다(화면만)")


func _save() -> void:
	var path: String = "user://test_region_old.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"shards": 5, "field_found": {"cache_8": 1}, "glints": [0, 3, 15], "glints_ready": true, "packs_cleared": {"foot": 1}}))
	f.close()
	var m := Meta.load_or_new(path)
	check.call(m.shards == 5 and m.field_found.has("cache_8") and not m.field_found.has("cache_9") and m.glints == [0, 3, 15] and m.packs_cleared.has("foot"), "옛 저장: 16곳 시절 저장도 그대로 읽는다(새 상자·무리는 아직 안 연 것)")
	check.call(m.field_open("cache_9", 45) == 45 and m.field_open("cache_8", 35) == 0, "옛 저장: 새 상자는 열 수 있고 연 상자는 그대로")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
