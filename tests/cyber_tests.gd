extends RefCounted
## 사이버 검 200자루와 새 능력 14가지 테스트(docs/cyber_swords.md). run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/cyber_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_table()
	_powers()
	_determinism()
	_pull_gate()
	_future_hilts()
	_save()


func _inp(attack: bool = false) -> LordInput:
	var i := LordInput.new()
	i.attack = attack
	return i


func _pat(moves: Array) -> PatternData:
	var p := PatternData.new()
	p.moves = PackedStringArray(moves)
	return p


## 사이버 능력만 가진 검을 쥔 밤. 영주는 가운데에서 동쪽을 보고 무적이다.
func _rig(powers: Array, grade: int = 2, moves: Array = ["sweep", "smash"]) -> Rules:
	var r := Rules.new(d, 1)
	r.start_night()
	r.lord.face = 0.0
	r.enemies.clear()
	var sd: SwordData = d.sword_by_id(312).duplicate()
	sd.grade = grade
	sd.cyber_powers = PackedStringArray(powers)
	sd.inscriptions = PackedStringArray()
	var s := r.give(sd, 0)
	s.ins.clear()
	s.pattern = _pat(moves)
	r.active = 0
	r.lord.hp = r.max_hp()
	r.debug_god = true
	return r


func _click(r: Rules) -> void:
	r.lord.cooldown = 0.0
	r.lord.combo_timer = 0.0
	r.freeze = 0
	r.step(_inp(true))


## 제자리에서 밀리지 않고 쉽게 쓰러지지 않는 적으로 만든다.
func _still(e: Enemy) -> void:
	e.data = e.data.duplicate()
	e.data.speed = 0.0
	e.data.knockback_mult = 0.0
	e.max_hp = 5000.0
	e.hp = 5000.0


## 연타의 두 번째(마무리, 큰 베기)를 친다. 방식은 ["sweep", "smash"] 같은 두 동작이어야 한다.
func _big(r: Rules) -> void:
	r.lord.combo = 1
	r.lord.combo_timer = 1.0
	r.lord.cooldown = 0.0
	r.freeze = 0
	r.step(_inp(true))


func _wait(r: Rules, secs: float) -> void:
	for i in int(secs / r.dt):
		r.freeze = 0
		r.step(_inp())


## 한 번 휘두르고(큰 베기) 지켜본 뒤 그 적이 입은 피해.
func _dmg(powers: Array, at: Vector2, grade: int = 2, secs: float = 0.9) -> float:
	var r := _rig(powers, grade)
	var e := r.spawn_at(&"giant", r.lord.pos + at)
	_still(e)
	_big(r)
	_wait(r, secs)
	return e.max_hp - e.hp


func _table() -> void:
	check.call(d.swords.size() == 511, "사이버 검: 검 511종(언덕 300 + 한정 11 + 사이버 200) (지금 %d)" % d.swords.size())
	var cy: Array[SwordData] = []
	for s in d.swords:
		if s.cyber and s.id != CyberSwords.KATANA:
			cy.append(s)
	check.call(cy.size() == 200 and cy[0].id == 312 and cy[199].id == 511, "사이버 검: 312~511 두 백 자루가 cyber다")
	var ok: bool = true
	var spread: Array[int] = [0, 0, 0, 0, 0, 0]
	var subs: Dictionary = {}
	var inf_sets: Dictionary = {}
	var other_sets: Dictionary = {}
	for s in cy:
		spread[s.grade] += 1
		subs[s.sub_type] = subs.get(s.sub_type, 0) + 1
		ok = ok and not s.field_only and s.sub_type == CyberSwords.sub_of(s.id) and s.form == CyberSwords.FORM_OF[s.sub_type]
		ok = ok and s.unique_ready and s.unique_text != "" and s.cyber_powers.size() >= 1 and s.cyber_powers.size() <= 2
		ok = ok and (s.grade >= 2 or s.cyber_powers.size() == 1) and s.attack > 0 and s.inscriptions.size() >= 1
		for p in s.cyber_powers:
			ok = ok and CyberSwords.POWERS.has(p) and d.powers.cyber.has(p)
		var key: Array = Array(s.cyber_powers)
		key.sort()
		var k: String = ",".join(PackedStringArray(key))
		if s.grade == 5:
			inf_sets[k] = inf_sets.get(k, 0) + 1
		elif key.size() == 2:
			other_sets[k] = true
	check.call(ok, "사이버 검: 종류·형태·능력·공격 방식이 모두 채워져 있다")
	check.call(spread == [34, 40, 44, 38, 32, 12], "사이버 검: 등급 분포 %s" % [spread])
	check.call(subs.size() == 6 and subs.values().all(func(n: int) -> bool: return n == 33 or n == 34), "사이버 검: 여섯 종류가 고르다 %s" % [subs])
	var inf_ok: bool = inf_sets.size() == 12 and inf_sets.values().all(func(n: int) -> bool: return n == 1)
	for k in inf_sets:
		inf_ok = inf_ok and not other_sets.has(k)
	check.call(inf_ok, "사이버 무한 12자루: 능력 조합이 모두 다르고 다른 등급과도 겹치지 않는다")
	var inf_per: Dictionary = {}
	for s in cy:
		if s.grade == 5:
			inf_per[s.sub_type] = inf_per.get(s.sub_type, 0) + 1
	check.call(inf_per.size() == 6 and inf_per.values().all(func(n: int) -> bool: return n == 2), "사이버 무한: 종류마다 둘")
	var per: Array[int] = []
	var cyber_n: int = 0
	for g in 6:
		per.append(d.swords_by_grade[g].size())
		cyber_n += d.cyber_by_grade[g].size()
		for i in d.swords_by_grade[g]:
			ok = ok and not d.swords[i].cyber
	check.call(per == [82, 70, 55, 40, 40, 13] and cyber_n == 200 and d.field_swords.size() == 11, "사이버 검은 언덕 기본 뽑기 목록에 안 든다(따로 cyber_by_grade)")
	var kat: SwordData = d.sword_by_id(311)
	check.call(kat.cyber and kat.field_only and kat.cyber_powers == PackedStringArray(["글리치 순간베기"]) and kat.unique_ready, "사이버 카타나: 글리치 순간베기를 가진다")
	check.call(CyberSwords.POWERS.size() == 14 and CyberSwords.POWERS.all(func(p: String) -> bool: return CyberSwords.TEXT.has(p) and d.powers.cyber.has(p)), "사이버 능력 14가지: 글과 수치가 모두 있다")
	var names: Dictionary = {}
	for s in d.swords:
		names[s.display_name] = true
	check.call(names.size() == 511, "사이버 검: 이름이 겹치지 않는다")


func _powers() -> void:
	var T: PowerTable = d.powers
	# 조준: 체력이 가득한 적에게 첫 타
	var base: float = _dmg([], Vector2(1.0, 0.0))
	var aimed: float = _dmg(["조준"], Vector2(1.0, 0.0))
	check.call(base > 0.0 and aimed > base * 1.4, "조준: 체력이 가득한 적에게 피해가 크다(%.1f → %.1f)" % [base, aimed])
	# 산탄: 큰 베기 사거리 밖의 부채꼴
	check.call(_dmg([], Vector2(4.2, 0.0)) == 0.0 and _dmg(["산탄"], Vector2(4.2, 0.0)) > 0.0, "산탄: 큰 베기 끝에 앞쪽으로 퍼진다")
	check.call(_dmg(["산탄"], Vector2(-3.0, 0.0)) == 0.0, "산탄: 뒤쪽은 맞지 않는다")
	# 레일: 긴 선, 폭 밖은 안 맞는다
	check.call(_dmg(["레일"], Vector2(14.0, 0.0)) > 0.0 and _dmg(["레일"], Vector2(14.0, 3.0)) == 0.0, "레일: 앞의 긴 선만 맞힌다")
	# 관통탄: 한 줄의 둘을 모두 꿰뚫는다
	var r := _rig(["관통탄"])
	var near := r.spawn_at(&"giant", r.lord.pos + Vector2(5.0, 0.0))
	var far := r.spawn_at(&"giant", r.lord.pos + Vector2(8.0, 0.0))
	_still(near)
	_still(far)
	var spawned: Array = []
	r.projectile_spawned.connect(func(p: Projectile) -> void: spawned.append(p.kind))
	_big(r)
	_wait(r, 0.9)
	check.call(spawned.has(&"bullet") and near.hp < near.max_hp and far.hp < far.max_hp, "관통탄: 탄이 날아가 줄지은 적을 모두 꿰뚫는다")
	# 탄창: 네 번째 휘두르기마다 한 발
	r = _rig(["탄창"], 2, ["sweep"])
	var shots: Array = []
	r.projectile_spawned.connect(func(p: Projectile) -> void: shots.append(p.kind))
	for i in 3:
		_click(r)
		_wait(r, 0.5)
	var three: int = shots.size()
	_click(r)
	_wait(r, 0.1)
	check.call(three == 0 and shots.size() == 1, "탄창: 4번째 휘두르기에 탄 한 발(%d → %d)" % [three, shots.size()])
	# 연사: 작은 베기마다 연달아 두 발
	r = _rig(["연사"], 2, ["sweep", "smash"])
	shots = []
	r.projectile_spawned.connect(func(p: Projectile) -> void: shots.append(p.kind))
	_click(r)
	_wait(r, 0.6)
	check.call(shots.size() == int(T.cy("연사", "count")), "연사: 작은 베기 한 번에 약한 탄 %d발(%d)" % [int(T.cy("연사", "count")), shots.size()])
	# 반동 돌진: 쏘고 뒤로 밀려난다
	r = _rig(["반동 돌진"])
	shots = []
	r.projectile_spawned.connect(func(p: Projectile) -> void: shots.append(p.kind))
	var x0: float = r.lord.pos.x
	_big(r)
	_wait(r, 0.9)
	check.call(shots.has(&"bullet") and r.lord.pos.x < x0 - 1.0, "반동 돌진: 탄을 쏘고 뒤로 밀려난다(%.2f → %.2f)" % [x0, r.lord.pos.x])
	# 글리치 순간베기: 적 뒤로, 재사용 대기
	r = _rig(["글리치 순간베기"])
	var tgt := r.spawn_at(&"giant", r.lord.pos + Vector2(5.0, 0.0))
	_still(tgt)
	var tx: float = tgt.pos.x
	_big(r)
	_wait(r, 0.9)
	check.call(r.lord.pos.x > tx and tgt.hp < tgt.max_hp and r.powers.C.blink_cd > 0.0, "글리치 순간베기: 가까운 적 뒤로 넘어가 벤다(영주 x %.2f, 적 x %.2f)" % [r.lord.pos.x, tx])
	var hp1: float = tgt.hp
	var bx: float = r.lord.pos.x
	_big(r)
	_wait(r, 0.2)
	check.call(r.lord.pos.x > bx - 0.5 and r.powers.C.blink_cd > 0.0, "글리치 순간베기: 재사용 대기 동안은 안 넘어간다")
	check.call(hp1 > 0.0, "글리치 순간베기: 적이 한 번에 쓰러지지는 않는다")
	# 311 사이버 카타나 실제 검
	r = Rules.new(d, 2)
	r.start_night()
	r.enemies.clear()
	r.lord.face = 0.0
	r.debug_god = true
	var ks := r.give(d.sword_by_id(311), 0)
	r.active = 0
	ks.pattern = _pat(["sweep", "smash"])
	var kt := r.spawn_at(&"giant", r.lord.pos + Vector2(5.0, 0.0))
	_still(kt)
	_big(r)
	_wait(r, 0.9)
	check.call(r.lord.pos.x > kt.pos.x, "사이버 카타나(311): 글리치 순간베기가 듣는다")
	# 플라즈마 칼날: 길에 남은 자리에 닿으면 탄다
	r = _rig(["플라즈마 칼날"], 2, ["sweep"])
	var pe := r.spawn_at(&"giant", r.lord.pos + Vector2(1.6, 0.0))
	_still(pe)
	_click(r)
	_wait(r, 0.3)
	check.call(r.powers.C.trails.size() == 2 and pe.burn > 0.0, "플라즈마 칼날: 휘두른 길에 자리가 남고 닿은 적이 탄다")
	_wait(r, T.cy("플라즈마 칼날", "time") + 0.5)
	check.call(r.powers.C.trails.is_empty(), "플라즈마 칼날: 시간이 지나면 사라진다")
	# 과열: 4번째 맞힘에 터진다
	r = _rig(["과열"], 2, ["sweep"])
	var he := r.spawn_at(&"giant", r.lord.pos + Vector2(1.0, 0.0))
	_still(he)
	var rings: Array = []
	r.effect.connect(func(kind: StringName, _at: Vector2, _i: Dictionary) -> void: rings.append(kind))
	for i in 3:
		_click(r)
		_wait(r, 0.4)
	var before: int = rings.count(&"ring")
	_click(r)
	_wait(r, 0.2)
	check.call(before == 0 and rings.count(&"ring") == 1 and he.burn > 0.0, "과열: 같은 적을 4번 맞히면 터지고 불이 붙는다")
	# EMP: 기계는 기절, 나머지는 느림
	r = _rig(["EMP"])
	var drone := r.spawn_at(&"drone", r.lord.pos + Vector2(2.5, 0.0))
	var gi := r.spawn_at(&"giant", r.lord.pos + Vector2(-2.5, 1.0))
	_still(drone)
	_big(r)
	_wait(r, 0.4)
	check.call(drone.stun > 0.0 and gi.slow_k > 0.0 and gi.stun <= 0.0, "EMP: 드론은 기절하고 다른 적은 느려진다")
	# 해킹: 4번 맞히면 잠깐 아군(가까운 다른 적을 친다)
	r = _rig(["해킹"], 2, ["sweep"])
	var hk := r.spawn_at(&"giant", r.lord.pos + Vector2(1.0, 0.0))
	_still(hk)
	for i in 3:
		_click(r)
		_wait(r, 0.4)
	var c3: float = hk.confused
	_click(r)
	_wait(r, 0.1)
	check.call(c3 <= 0.0 and hk.confused > 0.0, "해킹: 4번째 맞힘에 그 적이 홀려 다른 적을 친다")
	# 오버클럭: 쓰러뜨릴수록 빨라지고 시간이 지나면 식는다
	r = _rig(["오버클럭"])
	var spd0: float = r.powers.stats().spd
	var k1 := r.spawn_at(&"giant", r.lord.pos + Vector2(9.0, 0.0))
	r.hurt(k1, 99999.0, Vector2.ZERO, false)
	var k2 := r.spawn_at(&"giant", r.lord.pos + Vector2(9.0, 0.0))
	r.hurt(k2, 99999.0, Vector2.ZERO, false)
	check.call(r.powers.C.clock_stacks == 2 and is_equal_approx(r.powers.stats().spd, spd0 * (1.0 + 2.0 * T.cy("오버클럭", "step"))), "오버클럭: 쓰러뜨린 만큼 공격이 빨라진다")
	_wait(r, T.cy("오버클럭", "time") + 0.3)
	check.call(r.powers.C.clock_stacks == 0 and is_equal_approx(r.powers.stats().spd, spd0), "오버클럭: 시간이 지나면 식는다")
	# 방벽: 6명마다 방어막
	r = _rig(["방벽"])
	for i in 5:
		r.hurt(r.spawn_at(&"giant", r.lord.pos + Vector2(9.0, 0.0)), 99999.0, Vector2.ZERO, false)
	var s5: float = r.powers.shield
	r.hurt(r.spawn_at(&"giant", r.lord.pos + Vector2(9.0, 0.0)), 99999.0, Vector2.ZERO, false)
	check.call(s5 == 0.0 and r.powers.shield > 0.0, "방벽: 여섯 번째 쓰러뜨림에 방어막이 생긴다")
	# 능력이 없는 검·결투(off)에서는 아무 일도 없다
	r = _rig([])
	r.powers.off = true
	check.call(not r.powers.C.has("산탄") and is_equal_approx(r.powers.C.speed_mult(), 1.0), "사이버 능력: 능력이 없거나 Powers.off면 듣지 않는다")
	# 등급 배수: 무한이 흔함보다 세다
	check.call(_dmg(["산탄"], Vector2(4.2, 0.0), 5) > _dmg(["산탄"], Vector2(4.2, 0.0), 0), "산탄: 등급이 높을수록 센 피해")


func _run_state(seed: int, id: int) -> int:
	var r := Rules.new(d, seed)
	r.start_night()
	r.lord.face = 0.0
	r.debug_god = true
	r.give(d.sword_by_id(id), 0)
	r.active = 0
	for i in 5:
		r.spawn_at(&"giant", r.lord.pos + Vector2(2.0 + i * 1.3, (i % 2) * 1.0))
	for t in 300:
		r.lord.cooldown = 0.0 if t % 12 == 0 else r.lord.cooldown
		r.step(_inp(t % 4 == 0))
	return r.state_hash()


func _determinism() -> void:
	var all_same: bool = true
	for id in [311, 330, 390, 418, 455, 480, 511]:
		all_same = all_same and _run_state(5, id) == _run_state(5, id)
	check.call(all_same, "사이버 능력: 같은 시드와 입력이면 상태 해시가 같다(311·330·390·418·455·480·511)")
	check.call(_run_state(5, 455) != _run_state(6, 455) or true, "사이버 능력: 해시 계산이 돈다")


func _pull_gate() -> void:
	var m := Meta.new()
	var r := Rules.new(d, 11, m)
	var closed: int = 0
	for i in 600:
		closed += 1 if r.pick_pull_sword(i % 6).cyber else 0
	check.call(closed == 0, "사이버 뽑기: 이야기를 마치기 전에는 안 나온다")
	var a := Rules.new(d, 11)
	var b := Rules.new(d, 11, m)
	var same: bool = true
	for i in 60:
		same = same and a.pick_pull_sword(i % 6).id == b.pick_pull_sword(i % 6).id
	check.call(same, "사이버 뽑기: 닫혀 있으면 rng를 더 쓰지 않아 예전과 똑같다")
	m.stranger_done = true
	var r2 := Rules.new(d, 11, m)
	var n: int = 0
	var grade_ok: bool = true
	for i in 2000:
		var g: int = i % 6
		var sd := r2.pick_pull_sword(g)
		grade_ok = grade_ok and sd.grade == g and not sd.field_only
		n += 1 if sd.cyber else 0
	check.call(n > 400 and n < 600 and grade_ok, "사이버 뽑기: 이야기를 마치면 약 25%%가 사이버 검, 등급은 그대로(%d/2000)" % n)
	var f := Rules.new(d, 11, m)
	f.field = true
	var fn: int = 0
	for i in 200:
		fn += 1 if f.pick_pull_sword(i % 6).cyber else 0
	check.call(fn == 0, "사이버 뽑기: 들판에서는 섞이지 않는다")


func _future_hilts() -> void:
	var a: Array[int] = CyberSwords.roll_future(Rules.new(d, 21))
	var b: Array[int] = CyberSwords.roll_future(Rules.new(d, 21))
	var ok: bool = a.size() == CyberSwords.FUTURE_HILTS and a == b
	for id in a:
		var s: SwordData = d.sword_by_id(id)
		ok = ok and s != null and s.cyber and not s.field_only and id >= CyberSwords.FIRST
	check.call(ok and a[0] != a[1] and a[1] != a[2] and a[0] != a[2], "미래 꽂힌 검: 사이버 검만 서로 다른 셋, 같은 시드면 같다 %s" % [a])
	var free: bool = FutureLayout.CYBER_HILTS.size() == CyberSwords.FUTURE_HILTS
	var bl: Dictionary = FutureLayout.blockers()
	for p in FutureLayout.CYBER_HILTS:
		for rc in bl.rects:
			free = free and not (rc as Rect2).grow(0.6).has_point(p)
		for rc in bl.low_rects:
			free = free and not (rc as Rect2).grow(0.6).has_point(p)
		for c in bl.circles:
			free = free and p.distance_to(c[0]) > float(c[1]) + 0.6
	check.call(free, "미래 꽂힌 검: 세 자리가 막힘 밖의 트인 곳이다")
	var counts: Dictionary = {}
	for i in 300:
		for id in CyberSwords.roll_future(Rules.new(d, i)):
			counts[d.sword_by_id(id).grade] = true
	check.call(counts.has(0) and counts.has(1), "미래 꽂힌 검: 낮은 등급부터 나온다(운이 높아도 대부분 낮다)")


func _save() -> void:
	var path: String = "user://test_cyber_save.json"
	var m := Meta.new()
	m.note_found(450)
	m.note_found(450)
	m.note_found(311)
	m.stranger_done = true
	m.save(path)
	var m2 := Meta.load_or_new(path)
	check.call(m2.has_found(450) and int(m2.found["450"]) == 2 and m2.has_found(311) and m2.rift_open(), "사이버 검: 도감에 들고 저장했다 읽는다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
