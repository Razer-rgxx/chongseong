extends RefCounted
## 검 보관집 테스트(2026-11-21): 대장간에서 산다(조각), 검 칸 언덕 2 → 3 → 4·들판 1 → 3 → 4, 저장,
## 칸이 넷이면 넷까지 들고 다섯째에 고르기 창, 아무 칸이나 고른다, Q는 다음(검이 든) 칸, 숫자는 그 칸, 쥔 검이 부러지면 다음 칸, 입력 바이트.
## run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/storage_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_buy()
	_saved()
	_hill_slots()
	_swap_and_break()
	_input_bytes()


func _buy() -> void:
	var m := Meta.new()
	check.call(m.hill_slots() == 2 and m.field_slots() == 1, "검 보관집이 없으면 언덕 판 2칸, 들판 1칸")
	check.call(not m.build_storage(d.meta) and m.storage_lv == 0, "조각이 모자라면 못 짓는다")
	m.shards = 1000
	var c1: int = m.storage_cost(d.meta)
	check.call(m.build_storage(d.meta) and m.storage_lv == 1 and m.shards == 1000 - c1, "검 보관집을 지으면 조각 %d을 쓴다" % c1)
	check.call(m.hill_slots() == 3 and m.field_slots() == 3, "검 보관집 1단계: 언덕 판 3칸, 들판 3칸")
	check.call(m.build_storage(d.meta) and m.hill_slots() == 4 and m.field_slots() == 4, "검 보관집 2단계: 4칸")
	check.call(m.storage_cost(d.meta) < 0 and not m.build_storage(d.meta), "4칸이 끝이다")


func _saved() -> void:
	var m := Meta.new()
	m.storage_lv = 2
	var m2 := Meta.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check.call(m2.storage_lv == 2, "검 보관집 단계는 저장하고 불러온다")


func _rules(lv: int) -> Rules:
	var m := Meta.new()
	m.storage_lv = lv
	return Rules.new(d, 3, m)


func _hill_slots() -> void:
	var r := _rules(2)
	check.call(r.slots.size() == 4, "검 보관집이 있으면 언덕 판의 검 칸이 는다 (%d칸)" % r.slots.size())
	for k in 4:
		r._receive(Sword.new(d.swords[k], d))
	check.call(r.slots.all(func(s: Sword) -> bool: return s != null) and r.pending == null, "칸이 넷이면 네 자루까지 그냥 든다")
	var fifth := Sword.new(d.swords[9], d)
	r._receive(fifth)
	check.call(r.pending == fifth, "다섯째 검이면 어느 칸에 들지 고른다")
	r.choose(3)
	check.call(r.slots[3] == fifth and r.pending == null, "넷째 칸을 골라 바꿀 수 있다")
	check.call(Rules.new(d, 3).slots.size() == 2, "보관집이 없으면(메타 없음 포함) 두 칸 그대로")


func _swap_and_break() -> void:
	var r := _rules(2)
	r.slots[0] = Sword.new(d.swords[0], d)
	r.slots[2] = Sword.new(d.swords[1], d)
	r.slots[3] = Sword.new(d.swords[2], d)
	r.active = 0
	r.swap(Rules.SWAP_NEXT)
	check.call(r.active == 2, "Q: 다음 칸 중 검이 든 칸으로(빈 칸은 건너뛴다)")
	r.swap(3)
	check.call(r.active == 3, "숫자 키: 그 칸으로")
	r.swap(Rules.SWAP_NEXT)
	check.call(r.active == 0, "Q는 끝에서 처음으로 돌아간다")
	r.swap(1)
	check.call(r.active == 0, "빈 칸으로는 바꾸지 않는다")
	r.active = 3
	r._break(3)
	check.call(r.active == 0 and r.slots[3] == null, "쥔 검이 부러지면 다음 칸의 검을 쥔다")


func _input_bytes() -> void:
	for k in [Rules.SWAP_NEXT, 3, -1]:
		var i := LordInput.new()
		i.swap_to = k
		check.call(LordInput.from_bytes(i.to_bytes()).swap_to == k, "입력 바이트에 칸 바꾸기(%d)가 그대로 실린다" % k)
