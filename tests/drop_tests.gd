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
	_log_tests()
	_memory_tests()


## 검의 기록(2026-11-20): 뽑기·벤 적·부러짐·완벽한 뽑기가 쌓이고 저장된다.
func _log_tests() -> void:
	var m := Meta.new()
	m.runs = 6
	var id: int = game.swords[0].id
	check.call(m.log_line(id) == "", "검의 기록: 처음엔 없다")
	m.log_pull(id, true)
	m.log_kill(id)
	m.log_kill(id)
	m.log_break(id)
	check.call(m.kills_of(id) == 2, "검의 기록: 벤 적을 센다")
	check.call(m.log_line(id).contains("부러짐 1") and m.log_line(id).contains("완벽한 뽑기 1") and m.log_line(id).contains("7번째 판"), "검의 기록: 한 줄")
	var m2 := Meta.new()
	m2.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check.call(m2.kills_of(id) == 2 and m2.log_line(id) == m.log_line(id), "검의 기록: 저장·읽기")
	m.log_kill(0)
	check.call(not m.sword_log.has("0"), "검의 기록: 맨손은 안 센다")


## 검의 기억(2026-11-20): 1000·2500·5000·7500·10000마리에서 이름과 피해 배수.
func _memory_tests() -> void:
	var m := Meta.new()
	var sd: SwordData = game.swords[0]
	var id: int = sd.id
	check.call(m.memory_title(sd) == sd.display_name and m.memory_tier(id) == 0, "검의 기억: 처음엔 이름 그대로")
	var crossed: Array[int] = []
	for i in 10000:
		var t: int = m.log_kill(id)
		if t > 0:
			crossed.append(t)
	check.call(crossed == [1, 2, 3, 4, 5], "검의 기억: 다섯 단계를 한 번씩 넘는다")
	check.call(m.memory_tier(id) == 5 and m.memory_next(id) == 0, "검의 기억: 10000마리면 마지막 단계")
	check.call(is_equal_approx(float(m.memory_table()[id]), float(Meta.MEMORY[4][2])), "검의 기억: 피해 배수 표")
	m.sword_log[str(id)]["k"] = 2500
	check.call(m.memory_title(sd).contains("추억이 담긴 검") and m.memory_title(sd).begins_with(sd.display_name), "검의 기억: 2500마리 이름")
	check.call(Meta.josa("검", "과", "와") == "과" and Meta.josa("서리", "과", "와") == "와", "검의 기억: 조사")
	var r := Rules.new(game, 7, m)
	var s := Sword.new(sd, game)
	check.call(is_equal_approx(r.memory_mult(s), float(Meta.MEMORY[1][2])), "검의 기억: 규칙이 피해 배수를 받는다")
