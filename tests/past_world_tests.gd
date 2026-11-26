extends RefCounted
## 넓힌 과거(판타지 월드)·과거 3막 「첫 닻」·닻의 손 테스트(2026-11-26). run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/past_world_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_layout()
	_story()
	_anchor()


func _layout() -> void:
	var area := Rect2(Vector2.ZERO, Vector2(PastLayout.SIZE))
	var ok: bool = area.encloses(PastLayout.OLD)
	for r in PastLayout.REGIONS:
		ok = ok and area.encloses(r.rect) and not (r.rect as Rect2).intersects(PastLayout.OLD)
	check.call(ok and PastLayout.REGIONS.size() == 4, "판타지 월드: 새 땅 넷이 옛 숲 밖, 구역 안")
	check.call(PastLayout.region_of(Vector2(40, 30)) == "" and PastLayout.region_of(Vector2(150, 20)) == "거인의 뼈 들" and PastLayout.region_of(Vector2(150, 90)) == "수정 호수" and PastLayout.region_of(Vector2(30, 90)) == "잿불 능선" and PastLayout.region_of(StoryPast.SEAL_AT) == "용의 산맥", "판타지 월드: 자리마다 땅 이름(봉인은 용의 산맥)")
	var lit: Array[Vector2] = [Vector2(140, 40), Vector2(166, 78), Vector2(20, 80), Vector2(204, 58), Vector2(232, 43)]
	var same: bool = StoryPast.BEAST_AT == lit[4]
	for i in StoryPast.MEMORIES.size():
		same = same and StoryPast.MEMORIES[i].at == lit[i]
	check.call(same, "판타지 월드: 흩은 것이 비우는 자리(PastLayout.scatter의 숫자)가 이야기 자리와 같다")
	var b: Dictionary = PastLayout.blockers()
	var pts: Array[Vector2] = [PastLayout.START, PastLayout.EXIT_AT, PastLayout.CACHE_AT, StoryPast.SMITH_AT, StoryPast.SEAL_AT, StoryPast.BEAST_AT, StoryPast.CAPTAIN_AT, PastLayout.hoard_at()]
	for m in StoryPast.MEMORIES:
		pts.append(m.at)
	for id in PastLayout.WORLD_PACKS:
		pts.append(PastLayout.WORLD_PACKS[id].at)
	var free: bool = true
	var bad: String = ""
	for p in pts:
		if Blockers.inside(p, b.rects, b.circles, b.low_rects, b.low_circles) or not area.has_point(p):
			free = false
			bad += " %s" % p
	check.call(free, "판타지 월드: 시작·돌문·함·이야기 자리·새 무리 자리는 막힘 밖%s" % bad)
	# 시작에서 새 땅 셋과 이야기 자리까지 걸어서 닿는다(0.5칸 격자 넓이 우선)
	var r := Rules.new(d, 5)
	Grid.size = PastLayout.SIZE
	r.start_field()
	r.set_blockers(b.rects, b.circles, b.low_rects, b.low_circles)
	var reach: bool = true
	var miss: String = ""
	for p in [StoryPast.MEMORIES[0].at, StoryPast.MEMORIES[1].at, StoryPast.MEMORIES[2].at, StoryPast.MEMORIES[3].at, StoryPast.SEAL_AT, StoryPast.SMITH_AT, StoryPast.CAPTAIN_AT, PastLayout.hoard_at()]:
		if not _walk(b, PastLayout.START, p):
			reach = false
			miss += " %s" % p
	check.call(reach, "판타지 월드: 시작에서 기억의 돌 넷·봉인 제단·혼·선장·보물 더미까지 걸어 닿는다%s" % miss)
	var n: int = 0
	for id in PastLayout.WORLD_PACKS:
		n += r.spawn_pack(StringName(id), PastLayout.WORLD_PACKS[id]).size()
	check.call(n == 29, "판타지 월드: 새 무리 일곱이 선다(적 %d)" % n)
	Grid.size = Vector2i(34, 22)


## 0.5칸 격자 넓이 우선 탐색: 영주 반지름만큼 넓힌 막힘을 피해 a에서 b 근처(1.5칸)까지 닿는가.
func _walk(b: Dictionary, a: Vector2, goal: Vector2) -> bool:
	var step: float = 0.5
	var w: int = int(PastLayout.SIZE.x / step)
	var h: int = int(PastLayout.SIZE.y / step)
	var seen := PackedByteArray()
	seen.resize(w * h)
	var q: Array[Vector2i] = [Vector2i(int(a.x / step), int(a.y / step))]
	seen[q[0].y * w + q[0].x] = 1
	var head: int = 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		var p := Vector2(c) * step
		if p.distance_to(goal) < 1.5:
			return true
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: Vector2i = c + dv
			if nx.x < 1 or nx.y < 1 or nx.x >= w - 1 or nx.y >= h - 1 or seen[nx.y * w + nx.x] == 1:
				continue
			seen[nx.y * w + nx.x] = 1
			var np := Vector2(nx) * step
			var blocked: bool = false
			for cc in b.circles:
				if np.distance_to(cc[0]) < float(cc[1]) + 0.35:
					blocked = true
					break
			if not blocked:
				for rr in b.rects:
					if (rr as Rect2).grow(0.35).has_point(np):
						blocked = true
						break
			if not blocked:
				q.append(nx)
	return false


func _story() -> void:
	var m := Meta.new()
	check.call(m.read_memory(0) and not m.read_memory(0) and not m.read_memory(-1) and not m.read_memory(StoryPast.MEMORIES.size()), "첫 닻: 기억의 돌은 한 번만 새로 읽힌다")
	for i in StoryPast.MEMORIES.size():
		m.read_memory(i)
	check.call(not m.beast_ready() and not m.beast_slain() and not m.swear_oath(), "첫 닻: 기억을 다 읽어도 미래 2막(대수확자)을 안 마쳤으면 맹세도 흑룡도 없다")
	m.time_traveller = true
	m.harvest_down = true
	check.call(not m.beast_ready(), "첫 닻: 선장의 맹세 없이는 흑룡을 못 깨운다")
	check.call(m.swear_oath() and not m.swear_oath() and m.captain_oath, "첫 닻: 선장의 맹세는 한 번")
	var before: int = m.shards
	check.call(m.beast_ready() and m.beast_slain() and m.anchor_hand and m.shards == before + StoryPast.REWARD_SHARDS, "첫 닻: 흑룡을 쓰러뜨리면 닻의 손과 조각")
	check.call(not m.beast_ready() and not m.beast_slain() and m.shards == before + StoryPast.REWARD_SHARDS, "첫 닻: 보상은 한 번만")
	var m2 := Meta.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check.call(m2.past_memories.size() == StoryPast.MEMORIES.size() and m2.anchor_hand and m2.captain_oath, "첫 닻: 저장하고 다시 읽어도 남는다")
	var h := Meta.new()
	var got: int = h.dragon_hoard()
	check.call(got == PastLayout.HOARD_SHARDS and h.dragon_hoard() == 0 and h.shards == PastLayout.HOARD_SHARDS, "첫 닻: 용의 보물 더미는 한 번만")
	var m3 := Meta.new()
	var raw: Dictionary = m.to_dict()
	raw["harvest_down"] = false
	raw["past_memories"] = [0, 0, 7, 1]
	m3.from_dict(JSON.parse_string(JSON.stringify(raw)))
	check.call(not m3.anchor_hand and not m3.captain_oath and m3.past_memories.size() == 2, "첫 닻: 저장이 어긋나면(미래 2막 없이 축복·맹세, 겹친 기억) 바로잡는다")
	var e: EnemyData = d.enemies.get(StoryPast.BEAST_ID)
	check.call(e != null and e.past and e.boss and not e.future and e.hp >= 2500 and e.summon_kind == &"drake", "첫 닻: 흑룡 자료(과거·보스, 비룡을 부름)")
	var dk: EnemyData = d.enemies.get(&"drake")
	check.call(dk != null and dk.past and dk.acts() == &"charger", "첫 닻: 비룡 자료(과거, 돌격병 행동)")
	var lines: Dictionary = {}
	var full: int = StoryPast.MEMORIES.size()
	for i in full + 1:
		lines[StoryPast.smith_line(i, false, false, false)] = true
	lines[StoryPast.smith_line(full, true, false, false)] = true
	lines[StoryPast.smith_line(full, true, true, false)] = true
	lines[StoryPast.smith_line(full, true, true, true)] = true
	check.call(lines.size() >= 6, "첫 닻: 첫 대장장이의 말이 단계마다 바뀐다")
	var cl: Dictionary = {}
	cl[StoryPast.captain_line(1, false, false, false)] = true
	cl[StoryPast.captain_line(full, false, false, false)] = true
	cl[StoryPast.captain_line(full, true, false, false)] = true
	cl[StoryPast.captain_line(full, true, true, false)] = true
	cl[StoryPast.captain_line(full, true, true, true)] = true
	check.call(cl.size() == 5 and StoryPast.captain_line(full, true, false, false) == StoryPast.OATH_LINE, "첫 닻: 닻의 선장의 말이 단계마다 바뀌고 맹세 차례엔 맹세 말")
	var mc := Meta.new()
	var cmd5: String = AdminCmd.apply(AdminCmd.parse("첫닻 5"), null, mc)
	check.call(cmd5.contains("맹세") and mc.beast_ready(), "첫 닻: 관리 명령 `첫닻 5`(맹세까지, 흑룡을 깨울 수 있다)")
	var cmd: String = AdminCmd.apply(AdminCmd.parse("첫닻 6"), null, Meta.new())
	check.call(cmd.contains("닻의 손"), "첫 닻: 관리 명령 `첫닻 6`")


## 닻의 손: 언덕 판마다 처음 부러질 검을 한 번 붙잡는다(들판·결투·마을엔 없다).
func _anchor() -> void:
	var m := Meta.new()
	m.time_traveller = true
	m.harvest_down = true
	m.captain_oath = true
	m.anchor_hand = true
	var r := Rules.new(d, 9, m)
	r.slots[0] = Sword.new(d.swords[0], d)
	r.slots[1] = Sword.new(d.swords[1], d)
	var held: Array = []
	r.anchor_saved.connect(func(k: int) -> void: held.append(k))
	var s0: Sword = r.slots[0]
	r.break_slot(0)
	check.call(r.slots[0] == s0 and s0.durability >= 1.0 and s0.durability <= s0.max_durability * StoryPast.ANCHOR_KEEP + 1.0 and held == [0], "닻의 손: 처음 부러질 검을 붙잡아 내구 30%로 남긴다")
	r.break_slot(0)
	check.call(r.slots[0] == null and held.size() == 1, "닻의 손: 한 판에 한 번만")
	var r2 := Rules.new(d, 9, Meta.new())
	r2.slots[0] = Sword.new(d.swords[0], d)
	r2.break_slot(0)
	check.call(r2.slots[0] == null, "닻의 손: 축복이 없으면 그대로 부러진다")
	var r3 := Rules.new(d, 9, m)
	r3.start_field()
	r3.slots[0] = Sword.new(d.swords[0], d)
	r3.break_slot(0)
	check.call(r3.slots[0] == null, "닻의 손: 들판에서는 듣지 않는다")
	var a := Rules.new(d, 11, m)
	var b := Rules.new(d, 11, m)
	a.anchor_used = true
	check.call(a.state_hash() != b.state_hash(), "닻의 손: 쓴 것이 state_hash에 든다")
