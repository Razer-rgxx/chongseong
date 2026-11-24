extends RefCounted
## 33단계 오픈월드 한정 검 테스트(docs/field_life.md). run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/field_sword_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_table()
	_never_pulled()
	_real_pulls()
	_sheath_and_racks()
	_unique()
	_save()


func _table() -> void:
	var ids: Array[int] = []
	var per: Array[int] = [0, 0, 0, 0, 0, 0]
	var band_ok: bool = true
	var ins_ok: bool = true
	var text_ok: bool = true
	for i in d.field_swords:
		var s: SwordData = d.swords[i]
		ids.append(s.id)
		per[s.grade] += 1
		band_ok = band_ok and s.attack >= 1 and s.attack <= 150 and d.patterns[s.attack].grade == s.grade
		for k in s.inscriptions:
			ins_ok = ins_ok and d.inscriptions.has(k)
		text_ok = text_ok and s.story != "" and s.field_only and not s.unbreakable
	check.call(ids == [301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311], "한정 검: 301~311이 field_only %s" % [ids])
	check.call(per == [0, 0, 6, 3, 2, 0], "한정 검: 전설 6 · 신화 3 · 초월 2 %s" % [per])
	check.call(band_ok, "한정 검: 공격 방식은 이미 있는 150가지 중 제 등급대의 것(손으로 정함)")
	check.call(ins_ok and text_ok, "한정 검: 각인이 표에 있고 이야기가 있다")
	var hill_only: bool = true
	for g in 6:
		for i in d.swords_by_grade[g]:
			hill_only = hill_only and not d.swords[i].field_only
	check.call(hill_only, "한정 검: 뽑기 후보(swords_by_grade)에 하나도 없다")
	check.call(d.is_field_sword(301) and d.is_field_sword(310) and not d.is_field_sword(300) and not d.is_field_sword(999), "is_field_sword: 301~310만")
	var top := d.sword_by_id(310)
	check.call(top.grade == 4 and top.unique_text != "" and top.unique_ready and Powers.READY.has(top.display_name), "한정 검: 초월(310)은 고유 능력이 있고 규칙에 들어갔다")
	check.call(d.sword_by_id(309).display_name == "산 채로 묻힌 칼" and d.sword_by_id(310).display_name == "꺾인 깃발", "한정 검: 309는 무덤 큰 관, 310은 몰락한 기사의 몫")


## 뽑기에서 고르는 검(Rules.pick_sword)을 수천 번 돌려도 한정 검은 안 나온다(시드 고정).
func _never_pulled() -> void:
	var r := Rules.new(d, 4242)
	var bad: int = 0
	var seen: Dictionary = {}
	for k in 6000:
		var g: int = k % 6
		var s: SwordData = r.pick_sword(g)
		if s.field_only or s.grade != g:
			bad += 1
		seen[s.id] = true
	check.call(bad == 0, "뽑기: pick_sword 6000번에 한정 검·다른 등급이 하나도 없다(%d)" % bad)
	check.call(seen.size() == 300, "뽑기: 언덕의 검 300자루는 모두 나온다(%d)" % seen.size())
	var r2 := Rules.new(d, 4242)
	var same: bool = true
	var r3 := Rules.new(d, 4242)
	for k in 200:
		same = same and r2.pick_sword(k % 6) == r3.pick_sword(k % 6)
	check.call(same, "뽑기: 같은 시드면 같은 검")


## 실제 뽑기(전설·신화·초월 손잡이)를 여러 번: 받은 검에 한정 검이 없다.
func _real_pulls() -> void:
	var got: Array[SwordData] = []
	for seed_value in [11, 12, 13]:
		for g in [2, 3, 4]:
			var r := Rules.new(d, seed_value * 10 + g)
			r.debug_grade = g
			r.sword_pulled.connect(func(s: Sword) -> void: got.append(s.data))
			for n in 8:
				var h := r.nearest_hilt(1000.0)
				if h == null:
					break
				r.lord.hp = r.max_hp()
				r.lord.pos = h.pos + Vector2(0.3, 0.0)
				var i := LordInput.new()
				i.pull = true
				r.step(i)
				for t in 300:
					if r.pull_hilt == null:
						break
					r.step()
				if r.pending != null:
					r.choose(-1)
	var bad: int = 0
	for s in got:
		bad += 1 if s.field_only else 0
	check.call(got.size() >= 30 and bad == 0, "뽑기: 전설·신화·초월 손잡이를 %d번 뽑아도 한정 검은 없다" % got.size())


func _sheath_and_racks() -> void:
	var m := Meta.new()
	m.rng.seed = 1
	m.fix_sheath(d)
	check.call(m.sheath_id == -1, "검집: 처음엔 비었다")
	m.note_found(301)
	m.fix_sheath(d)
	check.call(m.sheath_candidates(d) == [301] and m.sheath_id == 301, "검집: 얻은 한정 검(전설 이상)을 넣을 수 있다")
	m.note_found(310)
	check.call(m.sheath_candidates(d)[0] == 310, "검집: 초월 한정 검이 맨 앞(높은 등급부터)")
	var yard: Array[int] = m.yard_swords(d)
	check.call(yard.has(301) and yard.has(310), "검 걸이·북문 검 고르기: 얻은 한정 검이 목록에 있다")
	var s: Sword = m.unbreakable_sword(d, 310)
	check.call(s != null and s.data.id == 310 and not s.breakable() and s.pattern == d.patterns[d.sword_by_id(310).attack], "북문: 한정 검을 부러지지 않는 검으로 쥔다")
	var m2 := Meta.new()
	check.call(not m2.yard_swords(d).has(301), "검 걸이: 안 얻은 한정 검은 없다")
	var r := Rules.new(d, 3, m)
	check.call(r.slots[0] != null and r.slots[0].data.id == m.sheath_id, "언덕: 검집의 한정 검을 들고 판을 시작한다")


func _unique() -> void:
	var taken: Array[float] = []
	for kills in [0, 10, 50]:
		var r := Rules.new(d, 5)
		r.start_night()
		r.give(d.sword_by_id(310), 0)
		r.active = 0
		r.powers.night_kills = kills
		taken.append(r.powers.lord_damage(100.0, null))
	check.call(is_equal_approx(taken[1] / taken[0], 0.8) and is_equal_approx(taken[2] / taken[0], 0.6), "꺾인 깃발: 쓰러뜨린 적 하나마다 받는 피해 -2%%, 최대 40%% (%.1f, %.1f, %.1f)" % taken)
	var r2 := Rules.new(d, 5)
	r2.start_night()
	r2.give(d.sword_by_id(309), 0)
	r2.powers.night_kills = 50
	var plain: float = r2.powers.lord_damage(100.0, null)
	check.call(is_equal_approx(plain, 100.0), "꺾인 깃발: 다른 검을 쥐면 듣지 않는다")


func _save() -> void:
	var path: String = "user://test_field_sword_save.json"
	var m := Meta.new()
	m.note_found(305)
	m.note_found(309)
	m.sheath_id = 309
	m.save(path)
	var m2 := Meta.load_or_new(path)
	m2.fix_sheath(d)
	var s := m2.sheath_sword(d)
	check.call(m2.has_found(305) and m2.has_found(309) and m2.sheath_id == 309 and s != null and s.data.id == 309, "저장: 얻은 한정 검과 검집에 넣은 한정 검을 읽는다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
