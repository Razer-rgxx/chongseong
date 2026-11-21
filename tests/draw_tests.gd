extends RefCounted
## 발검 테스트(docs/sword_hill.md 1번): 밤에도 꽂힌 검, 발검(쥔 검을 꽂고 새 검을 뽑음), 발검 반격(맞는 순간: 피해 없음·둘레 베기·값 돌려받음),
## 반격이 안 되면 값은 그대로, 꽂아 둔 검은 공짜·새벽에도 남음·낮에 바로 뽑힘, 맨손 발검, 체력이 모자라면 못 뽑음, 내구 × 0.3, 결정성.
## run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/draw_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_night_keeps()
	_draw_swap()
	_counter()
	_no_counter()
	_planted()
	_bare()
	_refused()
	_durability()
	_replay()


func _inp(pull: bool = false) -> LordInput:
	var i := LordInput.new()
	i.pull = pull
	return i


## 낮의 판에 검 하나를 쥐여 주고 밤으로. 가장 가까운 손잡이 곁에 선다.
func _night(seed_value: int = 4) -> Rules:
	var r := Rules.new(d, seed_value)
	r.give(d.swords[0], 0)
	r.start_night()
	r.enemies.clear()
	return r


func _stand(r: Rules, h: Hilt) -> void:
	r.lord.pos = h.pos + Vector2(0.3, 0.0)
	r.lord.prev_pos = r.lord.pos


func _draw(r: Rules) -> Hilt:
	var h := r.nearest_hilt(100.0)
	_stand(r, h)
	r.step(_inp(true))
	return h


func _night_keeps() -> void:
	var r := Rules.new(d, 4)
	var n: int = r.hilts.size()
	r.start_night()
	check.call(r.phase == Rules.Phase.NIGHT and r.hilts.size() == n and r.hilts.all(func(h: Hilt) -> bool: return not h.gone), "밤이 와도 뽑지 않은 검은 꽂혀 있다 (%d자루)" % n)


func _draw_swap() -> void:
	var r := _night()
	var old: Sword = r.slots[0]
	var hp0: float = r.lord.hp
	var drawn: Array = []
	r.sword_drawn.connect(func(s: Sword, h: Hilt, p: Hilt) -> void: drawn.append([s, h, p]))
	var h := _draw(r)
	check.call(drawn.size() == 1 and h.gone, "밤에 꽂힌 검 앞에서 E = 발검(그 손잡이는 빈다)")
	check.call(r.slots[0] != old and r.slots[0] == drawn[0][0], "발검: 새 검을 쥔다")
	var planted: Hilt = drawn[0][2]
	check.call(planted != null and planted.sword == old and planted.pos == h.pos and not planted.gone, "발검: 쥐고 있던 검은 그 자리에 꽂힌다(아는 검)")
	check.call(is_equal_approx(r.lord.hp, hp0 - r.pull_cost()), "모르는 검을 발검하면 뽑기 값(체력 %d)을 쓴다" % int(r.pull_cost()))
	check.call(r.lord.parry > 0.0 and r.lord.move_lock > 0.0, "발검하는 동안(draw 시간)은 받아칠 자세다")


func _counter() -> void:
	var r := _night()
	var e := r.spawn_at(&"dummy", r.nearest_hilt(100.0).pos + Vector2(1.0, 0.4))
	var hp_e: float = e.hp
	var hp0: float = r.lord.hp
	var countered: Array = []
	r.draw_countered.connect(func(at: Vector2) -> void: countered.append(at))
	_draw(r)
	r._hurt_lord(30.0, e)
	check.call(countered.size() == 1, "발검 중에 맞으려 하면 발검 반격")
	check.call(is_equal_approx(r.lord.hp, hp0), "발검 반격: 피해가 없고 뽑기 값을 돌려받는다")
	check.call(r.lord.parry <= 0.0 and r.lord.invuln > 0.3, "발검 반격 뒤 잠깐 무적")
	for k in 6:
		r.step(_inp())
	check.call(e.hp < hp_e, "발검 반격은 둘레의 적을 벤다")


func _no_counter() -> void:
	var r := _night()
	var hp0: float = r.lord.hp
	var countered: Array = []
	r.draw_countered.connect(func(at: Vector2) -> void: countered.append(at))
	_draw(r)
	for k in 20:
		r.step(_inp())
	check.call(countered.is_empty() and is_equal_approx(r.lord.hp, hp0 - r.pull_cost()), "안 맞으면 반격도 없고 값도 그대로")
	check.call(r.lord.parry <= 0.0 and r.lord.move_lock <= 0.0, "발검 자세는 draw 시간 뒤 풀린다")


func _planted() -> void:
	var r := _night()
	var old: Sword = r.slots[0]
	_draw(r)
	var planted: Hilt = null
	for h in r.hilts:
		if h.sword == old:
			planted = h
	for k in 20:
		r.step(_inp())
	var hp1: float = r.lord.hp
	_stand(r, planted)
	r.step(_inp(true))
	check.call(r.slots[0] == old and is_equal_approx(r.lord.hp, hp1), "꽂아 둔 검은 공짜로 다시 뽑는다")
	# 새벽까지: 지금 쥔 검(먼저 뽑은 검)이 꽂혔다
	var kept: Sword = null
	for h in r.hilts:
		if h.sword != null and not h.gone:
			kept = h.sword
	r._end_night()
	if r.path_open:
		r.choose_path(0)
	var still: Hilt = null
	for h in r.hilts:
		if h.sword == kept and not h.gone:
			still = h
	check.call(kept != null and still != null and r.phase == Rules.Phase.DAY, "꽂아 둔 검은 새벽에도 남는다")
	var hp2: float = r.lord.hp
	_stand(r, still)
	r.step(_inp(true))
	check.call(r.pull_hilt == null and still.gone and (r.slots[0] == kept or r.slots[1] == kept or r.pending == kept) and is_equal_approx(r.lord.hp, hp2), "낮에 꽂아 둔 검은 버티지 않고 공짜로 바로 뽑는다")


func _bare() -> void:
	var r := Rules.new(d, 4)
	r.start_night()
	r.enemies.clear()
	var n: int = r.hilts.size()
	_draw(r)
	check.call(r.slots[0] != null and r.hilts.size() == n, "맨손으로 발검하면 꽂을 것 없이 뽑기만 한다")


func _refused() -> void:
	var r := _night()
	r.lord.hp = r.pull_cost()
	var why: Array = []
	r.pull_refused.connect(func(t: String) -> void: why.append(t))
	var h := _draw(r)
	check.call(not why.is_empty() and not h.gone, "체력이 뽑기 값 이하면 발검하지 못한다")


func _durability() -> void:
	check.call(is_equal_approx(d.grades.durability[0], 24.0) and is_equal_approx(d.grades.durability[5], 135.0), "검은 빨리 부러진다: 등급 내구 × 0.3 (흔함 24 … 무한 135)")
	check.call(d.move(&"draw") != null and is_equal_approx(d.move(&"draw").counter_damage, 3.0), "발검 수치: data/attacks/moves/draw.tres (반격 × 3)")


func _replay() -> void:
	var hashes: Array[int] = []
	for k in 2:
		var r := _night(9)
		r.spawn_at(&"wolf", r.lord.pos + Vector2(3, 0))
		for t in 150:
			var i := _inp(t % 37 == 2)
			i.attack = t % 11 == 0
			i.move = Vector2.from_angle(t * 0.21) if t % 37 > 8 else Vector2.ZERO
			r.step(i)
		hashes.append(r.state_hash())
	check.call(hashes[0] == hashes[1], "결정성: 발검이 섞인 밤도 같은 입력이면 state_hash가 같다")
