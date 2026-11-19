extends RefCounted
## 34단계 떠도는 사람과 영입 테스트(docs/field_life.md). run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable

const IDS: Array[String] = ["gatherer", "smith", "hunter", "pilgrim", "knight"]


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/wanderer_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_data()
	_spots()
	_appear()
	_conditions()
	_effects()
	_save()
	Grid.size = Vector2i(34, 22)


func _meta(seed_value: int = 1) -> Meta:
	var m := Meta.new()
	m.rng.seed = seed_value
	return m


## 그 사람을 첫 자리에 세운 Meta.
func _with(id: String, at: int = 0) -> Meta:
	var m := _meta()
	m.wanderer = id
	m.wanderer_at = at
	return m


func _data() -> void:
	var keys: Array[String] = []
	keys.assign(FieldLayout.WANDERERS.keys())
	check.call(keys == IDS, "떠도는 사람: 약초꾼·대장장이·사냥꾼·순례자·기사 다섯 %s" % [keys])
	var W: Dictionary = FieldLayout.WANDERERS
	check.call(W.gatherer.cond == "shards" and int(W.gatherer.n) == 40 and W.smith.cond == "field_sword" and int(W.smith.n) == 1 and W.hunter.cond == "pack" and W.pilgrim.cond == "stones" and int(W.pilgrim.n) == 5 and W.knight.cond == "chiefs" and int(W.knight.n) == 3, "떠도는 사람: 조건(조각 40, 한정 검 하나, 근처 무리, 비석 다섯, 우두머리 셋)")
	var names: Array[String] = []
	var lines_ok: bool = true
	for id in W:
		names.append(String(W[id].name))
		for k in ["greet", "ask", "ready", "join", "gift"]:
			lines_ok = lines_ok and String(W[id][k]) != ""
		lines_ok = lines_ok and (W[id].village as Array).size() >= 1
	check.call(names == ["떠돌이 약초꾼", "떠돌이 대장장이", "늙은 사냥꾼", "길 잃은 순례자", "몰락한 기사"], "떠도는 사람: 이름 %s" % [names])
	check.call(lines_ok, "떠도는 사람: 들판의 말(인사·조건·맞음·영입)과 마을의 말이 있다")
	var looks: bool = true
	var village: Dictionary = (load("res://scripts/lobby/lobby.gd") as GDScript).get_script_constant_map().get("RECRUITS", {})
	for id in IDS:
		looks = looks and VillageProps.LOOKS.has(StringName(id)) and village.has(StringName(id))
	check.call(looks, "떠도는 사람: 마을 주민 모양(옷 색)과 마을에 설 자리가 있다")
	check.call(FieldLayout.RECRUIT_HP == 10.0 and FieldLayout.RECRUIT_FORGE == 0.8 and FieldLayout.RECRUIT_HUNT == 1.5 and FieldLayout.RECRUIT_BLESS == 0.8 and FieldLayout.RECRUIT_SWORD == 310, "영입 효과 수치: 체력 +10, 망치질 -20%, 무리 조각 +50%, 축복 -20%, 기사의 검 310")


func _spots() -> void:
	var S: Array[Dictionary] = FieldLayout.WANDERER_SPOTS
	check.call(S.size() == 8, "후보 자리 여덟")
	var root := Node3D.new()
	var blockers: Dictionary = FieldBuilder.build(root, Environment.new())
	var bad: Array[String] = []
	for i in S.size():
		var at: Vector2 = S[i].at
		var pk: String = S[i].pack
		if not FieldLayout.PACKS.has(pk):
			bad.append("%d 무리 없음" % i)
			continue
		var nearest: String = ""
		var nd: float = INF
		for k in FieldLayout.PACKS:
			if at.distance_to(FieldLayout.PACKS[k].at) < nd:
				nd = at.distance_to(FieldLayout.PACKS[k].at)
				nearest = k
		if nearest != pk:
			bad.append("%d 가장 가까운 무리는 %s" % [i, nearest])
		for a in 8:
			for k in [0.0, 1.0]:
				var q: Vector2 = at + Vector2.from_angle(a * TAU / 8.0) * 1.5 * k
				for rc: Rect2 in blockers.rects:
					if rc.grow(0.4).has_point(q):
						bad.append("%d 막힘" % i)
				for c in blockers.circles:
					if q.distance_to(c[0]) < float(c[1]) + 0.4:
						bad.append("%d 막힘(원)" % i)
		for k in FieldLayout.PACKS:
			if at.distance_to(FieldLayout.PACKS[k].at) <= FieldLayout.FIELD_NIGHT_AGGRO + 0.5:
				bad.append("%d 무리 %s" % [i, k])
		for k in FieldLayout.NIGHT_PACKS:
			if at.distance_to(FieldLayout.NIGHT_PACKS[k].at) <= FieldLayout.FIELD_NIGHT_AGGRO + 0.5:
				bad.append("%d 밤 무리 %s" % [i, k])
		for k in FieldLayout.CHIEFS:
			if at.distance_to(FieldLayout.CHIEFS[k].at) <= FieldLayout.CHIEF_WAKE + 2.0:
				bad.append("%d 우두머리 %s" % [i, k])
		if at.distance_to(FieldLayout.BOSS_AT) <= FieldLayout.BOSS_WAKE + 3.0:
			bad.append("%d 무덤 기사" % i)
		for p in [FieldLayout.GATE, FieldLayout.TRAILHEAD, FieldLayout.CRYPT_DOOR]:
			if at.distance_to(p) < 4.0:
				bad.append("%d 문" % i)
		for k in FieldLayout.CACHES:
			if at.distance_to(FieldLayout.CACHES[k][0]) < 3.0:
				bad.append("%d 상자" % i)
		for k in FieldLayout.STONES:
			if at.distance_to(FieldLayout.STONES[k][0]) < 3.0:
				bad.append("%d 비석" % i)
		var w: Vector3 = Grid.cells_to_world(at)
		if absf(w.z - FieldBuilder.brook_z(w.x)) < 9.0:
			bad.append("%d 개울" % i)
	root.free()
	check.call(bad.is_empty(), "후보 자리: 막힘·개울·상자·비석·문을 피하고, 무리(밤 덤빔 거리)·우두머리·무덤 기사에서 떨어져 있고, 사냥꾼의 무리는 가장 가까운 무리 %s" % [bad])


func _appear() -> void:
	var a := _meta(7)
	a.place_wanderer()
	var b := _meta(7)
	b.place_wanderer()
	check.call(a.wanderer != "" and FieldLayout.WANDERERS.has(a.wanderer) and a.wanderer_at >= 0 and a.wanderer_at < 8 and a.wanderer == b.wanderer and a.wanderer_at == b.wanderer_at, "나타나기: 같은 시드면 같은 사람이 같은 자리에 선다(%s, %d)" % [a.wanderer, a.wanderer_at])
	var who: Dictionary = {}
	var where: Dictionary = {}
	var m := _meta(11)
	for k in 200:
		m.place_wanderer()
		who[m.wanderer] = true
		where[m.wanderer_at] = true
	check.call(who.size() == 5 and where.size() == 8, "나타나기: 새벽마다 다시 뽑으면 다섯 사람·여덟 자리가 모두 나온다")
	var r := _meta(3)
	r.recruits = ["gatherer", "smith", "hunter", "pilgrim"]
	var only: bool = true
	for k in 30:
		r.place_wanderer()
		only = only and r.wanderer == "knight"
	check.call(only, "나타나기: 영입한 사람은 다시 나오지 않는다")
	r.recruits.append("knight")
	r.place_wanderer()
	check.call(r.wanderer == "" and r.wanderer_at == -1, "나타나기: 다 영입하면 아무도 없다")
	var e := _meta(5)
	e.ensure_wanderer()
	var first: String = e.wanderer
	var at: int = e.wanderer_at
	e.ensure_wanderer()
	check.call(first != "" and e.wanderer == first and e.wanderer_at == at, "들어올 때: 아무도 없으면 세우고, 이미 서 있으면 그대로")


func _conditions() -> void:
	# 약초꾼: 조각 40을 낸다
	var g := _with("gatherer")
	g.shards = 39
	check.call(not g.wanderer_ready(d) and not g.recruit(d).ok and g.shards == 39 and g.recruits.is_empty(), "약초꾼: 조각이 40 밑이면 안 따라온다")
	check.call(g.wanderer_progress(d) == "가진 조각 39 / 40", "약초꾼: 진행 줄 (%s)" % g.wanderer_progress(d))
	g.shards = 55
	var rg: Dictionary = g.recruit(d)
	check.call(rg.ok and rg.paid == 40 and g.shards == 15 and g.recruits == ["gatherer"] and g.wanderer == "" and g.wanderer_at == -1, "약초꾼: 조각 40을 내고 마을로 간다(들판에는 아무도 없다)")
	# 대장장이: 오픈월드 한정 검 하나
	var s := _with("smith")
	check.call(not s.wanderer_ready(d), "대장장이: 한정 검이 없으면 안 따라온다")
	s.note_found(5)
	check.call(not s.wanderer_ready(d), "대장장이: 언덕의 검은 치지 않는다")
	s.note_found(305)
	check.call(s.wanderer_ready(d) and s.recruit(d).ok and s.has_recruit("smith"), "대장장이: 한정 검을 하나 가졌으면 따라온다")
	# 사냥꾼: 그 자리의 근처 무리를 쓰러뜨림
	var h := _with("hunter", 4)
	var near: String = FieldLayout.WANDERER_SPOTS[4].pack
	h.packs_cleared = {"road_south": 1}
	check.call(not h.wanderer_ready(d) and h.wanderer_progress(d).ends_with("0 / 1"), "사냥꾼: 다른 무리를 쓰러뜨린 것은 치지 않는다(%s)" % h.wanderer_progress(d))
	h.packs_cleared[near] = 1
	check.call(h.wanderer_ready(d) and h.recruit(d).ok, "사냥꾼: 그 근처 무리(%s)를 쓰러뜨렸으면 따라온다" % near)
	# 순례자: 비석 다섯
	var p := _with("pilgrim")
	var stones: Array = FieldLayout.STONES.keys()
	for i in 4:
		p.lore_read[stones[i]] = 1
	p.lore_read["없는 비석"] = 1
	check.call(not p.wanderer_ready(d) and p.wanderer_progress(d) == "읽은 비석 4 / 5", "순례자: 비석 넷이면 안 따라온다(없는 비석은 안 센다)")
	p.lore_read[stones[4]] = 1
	check.call(p.wanderer_ready(d) and p.recruit(d).ok, "순례자: 비석 다섯을 읽었으면 따라온다")
	# 기사: 우두머리 셋, 영입하면 310번 검
	var k := _with("knight")
	k.chief_defeat("chief_tower")
	k.chief_defeat("chief_grove")
	check.call(not k.wanderer_ready(d) and k.wanderer_progress(d) == "쓰러뜨린 우두머리 2 / 3", "기사: 우두머리 둘이면 안 따라온다")
	k.chief_defeat("chief_tower")
	check.call(not k.wanderer_ready(d), "기사: 같은 우두머리를 두 번 쓰러뜨린 것은 하나로 센다")
	k.boss_defeat()
	check.call(not k.wanderer_ready(d), "기사: 옛 싸움터의 무덤 기사는 우두머리로 치지 않는다")
	k.chief_defeat("chief_pass")
	var rk: Dictionary = k.recruit(d)
	check.call(rk.ok and rk.sword == 310 and k.has_found(310) and k.sheath_candidates(d).has(310), "기사: 우두머리 셋이면 따라오고 「꺾인 깃발」(310)을 준다")
	var none := _meta()
	check.call(not none.wanderer_ready(d) and not none.recruit(d).ok and none.wanderer_progress(d) == "", "아무도 없으면 영입도 없다")


func _effects() -> void:
	var base := Rules.new(d, 1, _meta())
	var m := _meta()
	m.recruits = ["gatherer"]
	var hill := Rules.new(d, 1, m)
	check.call(is_equal_approx(hill.max_hp(), base.max_hp() + 10.0) and is_equal_approx(hill.lord.hp, hill.max_hp()), "약초꾼: 판 시작 체력 +10 (%.0f → %.0f)" % [base.max_hp(), hill.max_hp()])
	var field := Rules.new(d, 1)
	field.bonus_hp = m.recruit_hp()
	field.start_field()
	check.call(is_equal_approx(field.lord.hp, d.lord.hp + 10.0), "약초꾼: 들판 체력 +10")
	Grid.size = Vector2i(34, 22)
	var md := d.meta
	var plain := _meta()
	var smith := _meta()
	smith.recruits = ["smith"]
	plain.sheath_lv = 4
	smith.sheath_lv = 4
	check.call(plain.sheath_cost(md) == 150 and smith.sheath_cost(md) == 120, "대장장이: 망치질 값 -20%% (%d → %d)" % [plain.sheath_cost(md), smith.sheath_cost(md)])
	smith.shards = 120
	smith.forge_sheath(d)
	check.call(smith.shards == 0, "대장장이: 줄어든 값만큼만 낸다")
	var pil := _meta()
	pil.recruits = ["pilgrim"]
	check.call(plain.bless_cost(md, "hp") == 20 and pil.bless_cost(md, "hp") == 16, "순례자: 축복 값 -20%")
	var a := _meta(9)
	var b := _meta(9)
	b.recruits = ["hunter"]
	var na: int = a.field_clear("road_mid")
	var nb: int = b.field_clear("road_mid")
	check.call(nb == roundi(na * 1.5) and b.shards == nb, "사냥꾼: 무리 전멸 조각 +50%% (%d → %d)" % [na, nb])
	check.call(b.field_kill() == FieldLayout.PACK_KILL_SHARDS, "사냥꾼: 적 하나 조각은 그대로")


func _save() -> void:
	var path: String = "user://test_wanderer_save.json"
	var m := _meta()
	m.recruits = ["smith", "knight"]
	m.wanderer = "pilgrim"
	m.wanderer_at = 6
	m.save(path)
	var m2 := Meta.load_or_new(path)
	check.call(m2.recruits == ["smith", "knight"] and m2.wanderer == "pilgrim" and m2.wanderer_at == 6, "저장: 영입한 사람, 지금 선 사람과 자리를 읽는다")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"shards": 5}))
	f.close()
	var m3 := Meta.load_or_new(path)
	check.call(m3.recruits.is_empty() and m3.wanderer == "" and m3.wanderer_at == -1 and m3.recruit_hp() == 0.0, "저장: 옛 저장은 비어 있다")
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"recruits": ["hunter", "없는 사람"], "wanderer": "hunter", "wanderer_at": 2}))
	f.close()
	var m4 := Meta.load_or_new(path)
	check.call(m4.recruits == ["hunter"] and m4.wanderer == "", "저장: 모르는 사람은 버리고, 이미 영입한 사람은 들판에 서지 않는다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
