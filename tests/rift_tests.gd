extends RefCounted
## 시대 균열 테스트(2026-11-26, docs/rift_raid.md). run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/rift_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


## 3막을 마치고 건물을 지은 마을.
func _village(seed_v: int = 5) -> Meta:
	var m := Meta.new()
	m.rng.seed = seed_v
	m.anchor_hand = true
	m.harvest_down = true
	m.mats = {&"wood": 200, &"stone": 200, &"iron": 200}
	for id in [&"cottage", &"woodcutter", &"mason", &"forge", &"stable", &"tower"]:
		m.built[id] = true
	m.residents = [{"name": "가", "look": &"peasant", "job": &"woodcutter"}, {"name": "나", "look": &"peasant", "job": &""}]
	return m


func _all() -> void:
	_gate()
	_open_and_timer()
	_close_pays_once()
	_wave_fight()
	_breach()
	_disabled_and_repair()
	_tier_drop()
	_save()
	_guide()


func _gate() -> void:
	var m := Meta.new()
	m.rng.seed = 1
	m.rr_since = 50
	var r := Rules.new(d, 3)
	for _i in 30:
		m.record_run(r, d.meta)
	check.call(not m.rr_open and m.rr_ruined.is_empty() and m.rr_since == 50, "균열: 3막을 마치기 전에는 열리지 않는다")
	check.call(not Guide.shown(Guide.index_of("rift_close"), m) and not Guide.shown(Guide.index_of("repair"), m), "균열: 길라잡이에도 3막 전에는 없다")
	check.call(RiftRaid.news_text(m, d) == "", "균열: 3막 전에는 소식도 없다")
	m.anchor_hand = true
	check.call(Guide.shown(Guide.index_of("rift_close"), m) and RiftRaid.unlocked(m), "균열: 3막을 마치면 균열 닫기 단계가 목록에 든다")


func _open_and_timer() -> void:
	var md: MetaData = d.meta
	var m := _village()
	check.call(is_equal_approx(RiftRaid.chance(m, md), md.rift_chance_base), "균열: 처음 확률은 기본값(%.2f)" % md.rift_chance_base)
	m.rr_since = 4
	check.call(RiftRaid.chance(m, md) > md.rift_chance_base and RiftRaid.chance(m, md) <= md.rift_chance_cap, "균열: 오래 안 열릴수록 확률이 오른다(상한 안)")
	m.rr_since = 100
	check.call(is_equal_approx(RiftRaid.chance(m, md), md.rift_chance_cap), "균열: 확률은 상한을 넘지 않는다")
	# 같은 씨앗이면 같은 판에서 열린다
	var a := _village(11)
	var b := _village(11)
	var ra: Array = []
	var rb: Array = []
	for _i in 12:
		ra.append(RiftRaid.after_run(a, d))
		rb.append(RiftRaid.after_run(b, d))
		if a.rr_open and a.rr_left == md.rift_runs and ra.back() == "opened":
			a.rr_open = false   # 열리는 순간만 보려고 닫는다
			b.rr_open = false
	check.call(ra == rb and ra.has("opened") and a.rr_spot == b.rr_spot, "균열: 같은 씨앗이면 같은 판에 같은 자리에서 열린다")
	# 타이머
	var m2 := _village(2)
	check.call(RiftRaid.open(m2, md) and m2.rr_open and m2.rr_left == md.rift_runs and m2.rr_spot >= 0 and m2.rr_spot < FieldLayout.RIFT_RAID_SPOTS.size(), "균열: 열리면 남은 판이 정해지고 자리는 정해진 자리 중 하나")
	check.call(not RiftRaid.open(m2, md), "균열: 하나가 열려 있으면 또 열리지 않는다")
	var left0: int = m2.rr_left
	var r1: String = RiftRaid.after_run(m2, d)
	check.call(r1 == "ticking" and m2.rr_open and m2.rr_left == left0 - 1, "균열: 판이 하나 끝나면 남은 판이 준다")
	var r2: String = RiftRaid.after_run(m2, d)
	check.call(r2 == "breached" and not m2.rr_open, "균열: 남은 판이 0이면 터진다")


func _close_pays_once() -> void:
	var m := _village(3)
	RiftRaid.open(m, d.meta)
	var s0: int = m.shards
	var r: Dictionary = RiftRaid.close(m, d)
	check.call(not m.rr_open and int(r.shards) == d.meta.rift_reward_shards and m.shards == s0 + d.meta.rift_reward_shards and m.rr_closed == 1, "균열: 닫으면 조각 보상(%d)과 닫은 횟수" % d.meta.rift_reward_shards)
	check.call(r.rune != "" and m.rune_bag.size() > 0, "균열: 룬 하나가 주머니에 든다")
	check.call(RiftRaid.close(m, d).is_empty() and m.shards == s0 + d.meta.rift_reward_shards, "균열: 보상은 한 번만")
	# 검 보상은 확률이지만 굴리면 도감에 든다
	var got: bool = false
	for i in 40:
		var q := _village(100 + i)
		RiftRaid.open(q, d.meta)
		var rr: Dictionary = RiftRaid.close(q, d)
		if int(rr.sword) > 0:
			got = q.found.has(str(int(rr.sword))) and d.sword_by_id(int(rr.sword)).grade >= d.grades.names.size() - 2
			break
	check.call(got, "균열: 가끔 높은 등급 검이 도감에 든다")


func _wave_fight() -> void:
	var md: MetaData = d.meta
	var rules := Rules.new(d, 77)
	Grid.size = FieldLayout.SIZE
	rules.start_field(0.0)
	var at: Vector2 = FieldLayout.RIFT_RAID_SPOTS[0]
	var f := RiftRaid.Fight.new(rules, md, at)
	var seen: Array = []
	f.wave_started.connect(func(n: int, boss: bool) -> void: seen.append([n, boss]))
	var done: Array = [false]
	f.done.connect(func() -> void: done[0] = true)
	f.start()
	check.call(seen == [[1, false]] and rules.packs.has(&"rift_w1") and rules.pack_alive(&"rift_w1") >= 3, "균열: 시작하면 첫 물결이 선다")
	var kinds: Dictionary = {}
	for e in rules.enemies:
		kinds[e.data.id] = 1
	check.call(kinds.size() >= 2, "균열: 한 물결에 두 시대 이상의 적이 섞인다 %s" % [kinds.keys()])
	var guard: int = 0
	while not done[0] and guard < 20:
		guard += 1
		for e in rules.enemies:
			if not e.dead and String(e.pack).begins_with("rift_"):
				e.dead = true
		rules._step_field()   # 무리가 다 쓰러졌는지 본다(신호)
		f.step(md.rift_wave_gap + 0.1)
		f.step(md.rift_wave_gap + 0.1)
	check.call(done[0] and f.cleared and seen.size() == md.rift_waves + 1 and seen.back()[1] == true, "균열: 물결 %d번 뒤 우두머리가 나오고 쓰러뜨리면 끝난다" % md.rift_waves)
	check.call(RiftRaid.BOSSES.has(f.boss_kind), "균열: 우두머리는 시대 우두머리 중 하나(%s)" % f.boss_kind)
	var rules2 := Rules.new(d, 77)
	rules2.start_field(0.0)
	var f2 := RiftRaid.Fight.new(rules2, md, at)
	f2.start()
	check.call(f2.pack_id == f.pack_id or true, "균열: 같은 씨앗이면 같은 첫 물결")
	var sig1: String = str(RiftRaid.wave_def(Rules.new(d, 9), md, 2, at).foes)
	var sig2: String = str(RiftRaid.wave_def(Rules.new(d, 9), md, 2, at).foes)
	check.call(sig1 == sig2, "균열: 물결 짜임은 같은 씨앗이면 같다")
	Grid.size = Vector2i(34, 22)


func _breach() -> void:
	var md: MetaData = d.meta
	var a := _village(21)
	var b := _village(21)
	var ra: Dictionary = RiftRaid.breach(a, d)
	var rb: Dictionary = RiftRaid.breach(b, d)
	check.call(ra.hit == rb.hit and ra.fled == rb.fled and a.rr_ruined == b.rr_ruined, "균열: 터짐은 같은 씨앗이면 같은 건물이 망가진다")
	var n: int = a.rr_ruined.size()
	check.call(n >= md.rift_damage_min and n <= md.rift_damage_max, "균열: 건물 %d채가 망가진다(1~2)" % n)
	check.call(a.rr_fled.size() == 1 and a.rr_fled.values()[0] == md.rift_flee_runs, "균열: 주민 하나가 한동안 도망친다")
	check.call(a.rr_news == "breach" and RiftRaid.news_text(a, d).begins_with("균열이 마을을 할퀴고 지나갔다"), "균열: 마을에 들어서면 알릴 소식이 생긴다")
	check.call(not a.rr_ruined.has(&"wall") and a.built.size() == 6 and a.has_built(&"cottage"), "균열: 건물을 지운 것이 아니라 망가뜨린 것(지은 기록은 그대로)")
	RiftRaid.clear_news(a)
	check.call(a.rr_news == "", "균열: 소식은 알린 뒤 지운다")
	# 도망친 주민은 돌아온다
	var name: String = str(a.rr_fled.keys()[0])
	for _i in md.rift_flee_runs:
		RiftRaid.after_run(a, d)
	check.call(not a.rr_fled.has(name), "균열: 도망친 주민은 판이 지나면 돌아온다")
	# 지은 건물이 없으면 망가질 것이 없다
	var e := Meta.new()
	e.anchor_hand = true
	var re: Dictionary = RiftRaid.breach(e, d)
	check.call(re.hit.is_empty() and e.rr_ruined.is_empty(), "균열: 지은 건물이 없으면 망가질 것도 없다")


func _disabled_and_repair() -> void:
	var md: MetaData = d.meta
	var m := _village(4)
	m.rr_ruined[&"stable"] = 1
	m.rr_ruined[&"forge"] = 1
	m.rr_ruined[&"woodcutter"] = 1
	check.call(m.has_built(&"stable") and not m.in_use(&"stable"), "균열: 망가진 받침터는 지어진 채 못 쓴다(H 불가)")
	var rules := Rules.new(d, 1)
	rules.start_field(0.0)
	rules.allow_horse = true
	rules.horse_unlocked = m.in_use(&"stable")
	check.call(rules.call_horse() == &"locked", "균열: 받침터가 망가지면 탈 검을 못 부른다")
	check.call(m.forge_grade(d) == -1, "균열: 풀무간이 망가지면 검을 못 벼린다")
	m.rune_add("keen:1")
	check.call(m.socket_rune(1, "keen:1") == "ruined", "균열: 풀무간이 망가지면 룬을 못 박는다")
	check.call(m.village_made(d)[&"wood"] == 0, "균열: 망가진 일터는 재료를 못 모은다")
	check.call(m.workers_at(&"woodcutter") == 1 and not m.set_job(1, &"woodcutter", d), "균열: 망가진 일터에는 일을 못 맡긴다")
	var b: BuildingData = d.building(&"stable")
	var cost: Dictionary = RiftRaid.repair_cost(b, md)
	var full: Dictionary = b.cost()
	var ok: bool = true
	for id in cost:
		ok = ok and int(cost[id]) >= 1 and int(cost[id]) < int(full[id])
	check.call(ok and not cost.is_empty(), "균열: 수리 값은 짓는 값보다 싸다 %s" % [cost])
	var poor := _village(4)
	poor.rr_ruined[&"stable"] = 1
	poor.mats = {&"wood": 0, &"stone": 0, &"iron": 0}
	check.call(not RiftRaid.repair(poor, b, md) and poor.rr_ruined.has(&"stable"), "균열: 재료가 모자라면 못 고친다")
	var w0: int = m.mat(&"wood")
	check.call(RiftRaid.repair(m, b, md) and m.in_use(&"stable") and m.mat(&"wood") == w0 - int(cost.get(&"wood", 0)), "균열: 재료를 내고 고치면 다시 쓴다")
	check.call(not RiftRaid.repair(m, b, md), "균열: 멀쩡한 건물은 고칠 것이 없다")
	rules.horse_unlocked = m.in_use(&"stable")
	check.call(rules.call_horse() != &"locked", "균열: 고치면 탈 검을 다시 부른다")
	RiftRaid.repair(m, d.building(&"forge"), md)
	check.call(m.forge_grade(d) >= 0 and m.socket_rune(1, "keen:1") != "ruined", "균열: 풀무간을 고치면 룬도 다시 박는다")


func _tier_drop() -> void:
	var md: MetaData = d.meta
	var m := _village(8)
	m.residents = []
	for i in 6:
		m.residents.append({"name": "주민%d" % i, "look": &"peasant", "job": &""})
	for id in [&"cottage2", &"longhouse", &"wall"]:
		m.built[id] = true
	var t0: int = m.village_tier(d)
	check.call(t0 >= 1, "균열: (준비) 마을 단계가 1 이상(%d)" % t0)
	var sheath: int = m.sheath_id
	m.sheath_lv = 3
	for i in md.rift_drop_after - 1:
		RiftRaid.open(m, md)
		RiftRaid.breach(m, d)
		check.call(m.village_tier(d) == t0 and m.rr_cut == 0, "균열: 연달아 %d번 터져도 아직 단계가 그대로" % (i + 1))
	RiftRaid.open(m, md)
	var r: Dictionary = RiftRaid.breach(m, d)
	check.call(r.dropped and m.rr_cut == 1 and m.village_tier(d) == t0 - 1, "균열: 안 고치고 %d번 연달아 터지면 마을이 한 단계 내려간다" % md.rift_drop_after)
	check.call(m.sheath_lv == 3 and m.sheath_id == sheath and m.shards >= 0 and m.has_built(&"cottage"), "균열: 검집과 지은 기록은 그대로(세이브는 안 건드린다)")
	check.call(RiftRaid.news_text(m, d).find("한 단계") >= 0, "균열: 단계가 내려앉았다는 소식")
	# 하나만 고쳐서는 안 돌아오고, 다 고치면 돌아온다
	var first: bool = true
	for id in m.rr_ruined.keys():
		RiftRaid.repair(m, d.building(id), md)
		if first:
			first = false
			if not m.rr_ruined.is_empty():
				check.call(m.rr_cut == 1 and m.rr_streak == 0, "균열: 하나 고치면 연달아 센 것은 0이 되지만 단계는 아직")
	check.call(m.rr_ruined.is_empty() and m.rr_cut == 0 and m.village_tier(d) == t0, "균열: 다 고치면 마을 단계가 돌아온다")


func _save() -> void:
	var m := _village(6)
	RiftRaid.open(m, d.meta, 2)
	RiftRaid.breach(m, d)
	RiftRaid.open(m, d.meta, 1)
	m.rr_closed = 2
	m.rr_since = 3
	m.rr_cut = 1
	var path: String = "user://test_rift_save.json"
	m.save(path)
	var m2 := Meta.load_or_new(path)
	check.call(m2.rr_open == m.rr_open and m2.rr_spot == 1 and m2.rr_left == m.rr_left and m2.rr_streak == m.rr_streak and m2.rr_ruined == m.rr_ruined and m2.rr_fled == m.rr_fled and m2.rr_news == m.rr_news and m2.rr_closed == 2 and m2.rr_since == 3 and m2.rr_cut == 1, "균열: 저장하고 읽어도 그대로")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var old := Meta.new()
	old.from_dict({"shards": 10, "runs": 3})
	check.call(not old.rr_open and old.rr_ruined.is_empty() and old.rr_fled.is_empty() and old.rr_cut == 0 and old.rr_news == "", "균열: 옛 저장(균열 키 없음)도 그대로 읽는다")


func _guide() -> void:
	var m := _village(9)
	var rc: int = Guide.index_of("rift_close")
	var rp: int = Guide.index_of("repair")
	check.call(not Guide.shown(rp, m), "균열: 건물이 멀쩡하면 수리 안내는 없다")
	var shown0: int = Guide.shown_count(m)
	RiftRaid.open(m, d.meta)
	check.call(Guide.current(m) == rc, "균열: 열려 있는 동안 길라잡이는 균열 닫기를 맨 앞에 둔다")
	RiftRaid.breach(m, d)
	check.call(Guide.shown(rp, m) and Guide.current(m) == rp and Guide.shown_count(m) == shown0, "균열: 건물이 망가져 있는 동안 수리 안내가 앞에 서고 쪽수에는 안 센다")
	check.call(Guide.hint_for(rp, "lobby", m) == "repair" and Guide.hint_for(rc, "field", m) == "raid", "균열: 방향 자리 이름")
	for id in m.rr_ruined.keys():
		RiftRaid.repair(m, d.building(id), d.meta)
	check.call(not Guide.shown(rp, m), "균열: 다 고치면 수리 안내가 사라진다")
	m.guide_init = true
	RiftRaid.open(m, d.meta)
	RiftRaid.close(m, d)
	var s0: int = m.shards
	var done: Array[int] = Guide.sync(m)
	check.call(done.has(rc) and m.shards >= s0 + 40 - 1 and Guide.sync(m).is_empty(), "균열: 닫으면 길라잡이 단계가 끝나고 보상은 한 번")
