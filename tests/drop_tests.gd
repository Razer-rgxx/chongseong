extends RefCounted
## 떨군 검 테스트(2026-11-20: 들판에서 쓰러지면 쥔 검을 떨구고, 줍기 전에 또 쓰러지면 잃는다). run_all.gd가 부른다.

var check: Callable
var game: GameData


static func run(g: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/drop_tests.gd") as GDScript).new()
	t.set("check", chk)
	t.set("game", g)
	t.call("_all")


func _legend_ids() -> Array[int]:
	var out: Array[int] = []
	for s in game.swords:
		if s.grade >= game.meta.sheath_min_grade and not s.get("field_only"):
			out.append(s.id)
	return out


func _all() -> void:
	var m := Meta.new()
	var ids := _legend_ids()
	var a: int = ids[0]
	var b: int = ids[1]
	m.note_found(a)
	m.note_found(b)
	m.fix_sheath(game)
	var sheath: int = m.sheath_id
	var other: int = b if sheath == a else a
	check.call(m.usable(sheath) and m.usable(other), "떨군 검: 처음엔 둘 다 쥘 수 있다")
	# 맨손으로 쓰러지면 떨굴 것이 없다
	check.call(m.drop_sword(game, 0, Vector2(10, 10)) == -1 and m.dropped.is_empty(), "떨군 검: 맨손으로 쓰러지면 아무것도 안 떨군다")
	# 검집의 검을 떨군다
	check.call(m.drop_sword(game, sheath, Vector2(40, 50)) == -1 and m.dropped_id() == sheath, "떨군 검: 쥔 검이 쓰러진 자리에 떨어진다")
	check.call(m.dropped_at() == Vector2(40, 50), "떨군 검: 자리를 기억한다")
	check.call(not m.usable(sheath) and not m.yard_swords(game).has(sheath), "떨군 검: 줍기 전에는 걸이·북문에서 못 고른다")
	check.call(m.sheath_id == sheath, "떨군 검: 떨궈도 검집에서 빠지지는 않는다")
	# 저장하고 읽어도 남는다
	var m2 := Meta.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check.call(m2.dropped_id() == sheath and m2.dropped_at() == Vector2(40, 50), "떨군 검: 저장·읽기")
	# 주우면 돌아온다
	var m3 := Meta.new()
	m3.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check.call(m3.pick_dropped() == sheath and m3.dropped.is_empty() and m3.usable(sheath), "떨군 검: 주우면 다시 쥘 수 있다")
	# 줍기 전에 또 쓰러지면 먼저 떨군 검은 잃는다(검집의 검이면 검집에 다음 좋은 검)
	var gone: int = m.drop_sword(game, other, Vector2(5, 5))
	check.call(gone == sheath and m.lost.has(str(sheath)) and m.dropped_id() == other, "떨군 검: 줍기 전에 또 쓰러지면 먼저 떨군 검을 잃는다")
	check.call(m.sheath_id != sheath, "떨군 검: 잃은 검은 검집에서 빠진다")
	check.call(not m.sheath_candidates(game).has(sheath), "떨군 검: 잃은 검은 검집 후보에도 없다")
	# 언덕에서 다시 뽑으면 되찾는다
	m.note_found(sheath)
	check.call(not m.lost.has(str(sheath)) and m.usable(sheath), "떨군 검: 다시 뽑으면 되찾는다")
	# 옛 저장(칸 없음)은 비어 있다
	var old := Meta.new()
	old.from_dict({"shards": 5})
	check.call(old.dropped.is_empty() and old.lost.is_empty(), "떨군 검: 옛 저장은 비어 있다")
	# 깨어날 때의 말
	check.call(FieldHud.drop_note(game, -1, 0) == "", "떨군 검: 맨손이고 잃은 것도 없으면 말이 없다")
	check.call(FieldHud.drop_note(game, a, b).contains("영영 잃었다"), "떨군 검: 잃었으면 그렇게 말한다")
