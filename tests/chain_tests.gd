extends RefCounted
## 처치 연쇄와 새 기록 테스트(2026-11-24, docs/dopamine.md). run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/chain_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_chain()
	_shards()
	_records()
	_save()


## 밤의 언덕에서 늑대 하나를 세운다.
func _foe(r: Rules) -> Enemy:
	var e: Enemy = r._spawn(&"wolf")
	e.hp = 1.0
	return e


func _kill(r: Rules) -> void:
	r.hurt(_foe(r), 99999.0, Vector2.ZERO, false)


func _chain() -> void:
	var r := Rules.new(d, 7)
	r.start_night()
	r.debug_god = true
	var got: Array = []
	r.kill_chain.connect(func(n: int, paid: int) -> void: got.append([n, paid]))
	var window: int = roundi(d.run.chain_window / r.dt)
	_kill(r)
	check.call(r.chain == 1 and got.is_empty(), "연쇄: 첫 처치는 1이고 신호를 내지 않는다")
	for i in window - 1:
		r.step()
	_kill(r)
	check.call(r.chain == 2 and got == [[2, 0]], "연쇄: chain_window 안의 처치는 이어진다")
	for i in window + 2:
		r.step()
	_kill(r)
	check.call(r.chain == 1 and r.chain_best == 2 and got.size() == 1, "연쇄: 시간이 지나면 1부터 다시, 가장 긴 것은 남는다")
	var every: int = d.meta.chain_every
	for i in every * 2 - 1:
		_kill(r)
	check.call(r.chain == every * 2 and r.chain_best == every * 2, "연쇄: 한 틱 안에 여럿을 쓰러뜨려도 센다")
	var paid: Array = got.filter(func(x: Array) -> bool: return int(x[1]) > 0)
	check.call(paid.size() == 2 and int(paid[0][0]) == every and int(paid[1][0]) == every * 2 and r.chain_paid == 2 * d.meta.chain_shards, "연쇄: chain_every의 배수마다 조각이 붙는다 (%s)" % [paid])
	var yard := Rules.new(d, 7)
	yard.start_night()
	var still: Enemy = _foe(yard)
	still.data = still.data.duplicate()
	still.data.still = true
	yard.hurt(still, 99999.0, Vector2.ZERO, false)
	check.call(yard.chain == 0, "연쇄: 허수아비는 세지 않는다")


func _shards() -> void:
	var r := Rules.new(d, 19)
	r.chain_paid = 9
	r.chain_best = 17
	var s := Meta.run_shards(r, d.meta)
	check.call(s.chain == 9 and s.total == s.kills + s.zone + s.broken + s.elite + s.melt + s.goal + s.path + 9, "연쇄: 붙은 조각은 판이 끝날 때 받는다")
	var a := Rules.new(d, 3)
	var b := Rules.new(d, 3)
	b.chain = 4
	check.call(a.state_hash() != b.state_hash(), "연쇄: state_hash에 든다")


func _records() -> void:
	var m := Meta.new()
	var r := Rules.new(d, 5)
	r.zone = 2
	r.kills = 30
	r.chain_best = 8
	var first := m.record_run(r, d.meta)
	check.call(not first.new_best and not first.new_kills and not first.new_chain and m.best_kills == 30 and m.best_chain == 8, "새 기록: 첫 판은 기록만 남기고 '새 기록'이라 하지 않는다")
	var r2 := Rules.new(d, 6)
	r2.zone = 4
	r2.kills = 31
	r2.chain_best = 8
	var second := m.record_run(r2, d.meta)
	check.call(second.new_best and second.new_kills and not second.new_chain and m.best_kills == 31, "새 기록: 넘은 것만 새 기록 (같으면 아니다)")
	var r3 := Rules.new(d, 7)
	r3.zone = 1
	r3.kills = 2
	r3.chain_best = 9
	var third := m.record_run(r3, d.meta)
	check.call(not third.new_best and not third.new_kills and third.new_chain and m.best == 5 and m.best_kills == 31 and m.best_chain == 9, "새 기록: 못 넘으면 예전 기록이 남는다")


func _save() -> void:
	var m := Meta.new()
	m.best_kills = 44
	m.best_chain = 12
	var m2 := Meta.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check.call(m2.best_kills == 44 and m2.best_chain == 12, "새 기록: 저장하고 다시 읽어도 남는다")
