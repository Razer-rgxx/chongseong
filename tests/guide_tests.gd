extends RefCounted
## 길라잡이 테스트(docs/guide.md). run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/guide_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_order()
	_complete()
	_hidden()
	_legacy()
	_save()


func _order() -> void:
	var ids: Dictionary = {}
	var ok_ch: bool = true
	var last_ch: int = 0
	for i in Guide.size():
		ids[Guide.STEPS[i].id] = 1
		if int(Guide.STEPS[i].need) < 1 or (Guide.reward_text(i) == "" and not bool(Guide.STEPS[i].get("transient", false))):
			ok_ch = false
	check.call(ids.size() == Guide.size() and Guide.size() >= 15 and Guide.size() <= 26, "길라잡이: 단계 15~25개, id가 겹치지 않는다(%d)" % Guide.size())
	check.call(ok_ch, "길라잡이: 모든 단계에 세는 수와 보상이 있다")
	var order: Array = ["talk_gate", "rack", "hill_gate", "first_pull", "good_pull", "first_night", "path", "day_event", "finish_run"]
	var same: bool = true
	for i in order.size():
		if Guide.STEPS[i].id != order[i]:
			same = false
	check.call(same, "길라잡이: 앞 아홉 단계의 순서(문지기 → 도감 → 언덕 → 뽑기 → 밤 → 갈림길 → 사건 → 판 마침)")
	var tr: int = Guide.index_of("traveller")
	check.call(tr == Guide.index_of("future") + 1 and bool(Guide.STEPS[tr].hidden) and Guide.index_of("rift_close") == tr + 1 and Guide.index_of("repair") == tr + 2, "길라잡이: 미래·타임트래블러(숨은 단계) 뒤에 균열 닫기와 수리 안내")
	var m := Meta.new()
	check.call(Guide.current(m) == 0 and Guide.done_count(m) == 0, "길라잡이: 새 저장은 첫 단계부터")


func _complete() -> void:
	var m := Meta.new()
	check.call(Guide.sync(m).is_empty() and m.guide_init, "길라잡이: 아무것도 안 했으면 끝난 것이 없다")
	m.heard["gatekeeper"] = [0]
	var r: Array[int] = Guide.sync(m)
	check.call(r == [0] and m.shards == 5 and Guide.current(m) == 1, "길라잡이: 문지기와 말하면 끝나고 조각 5, 다음은 도감")
	check.call(Guide.sync(m).is_empty() and m.shards == 5, "길라잡이: 보상은 한 번만")
	m.guide_note("rack")
	m.guide_note("run_start")
	check.call(Guide.sync(m) == [1, 2] and m.shards == 15, "길라잡이: 세어 둔 일로 끝난다(도감, 언덕 길)")
	m.guide_note("pull")
	m.guide_note("pull_good")
	Guide.sync(m)
	check.call(Guide.current(m) == Guide.index_of("first_night"), "길라잡이: 뽑기 둘을 마치면 첫 밤이 차례")
	m.guide_note("field_enter")   # 순서와 무관하게 먼저 해낸 것은 끝난다
	var w: int = m.mat(&"wood")
	var got: Array[int] = Guide.sync(m)
	check.call(got == [Guide.index_of("field")] and m.mat(&"wood") == w + 2, "길라잡이: 앞서 해낸 단계도 끝나고 재료 보상")
	var s: int = Guide.index_of("stable_horse")
	check.call(Guide.count(s, m) == 0, "길라잡이: 검 받침터 단계는 0/2에서 시작")
	m.built[&"stable"] = true
	check.call(Guide.count(s, m) == 1 and not Guide.met(s, m), "길라잡이: 받침터만 지으면 1/2")
	m.guide_note("horse")
	check.call(Guide.met(s, m), "길라잡이: 탈 검을 부르면 2/2")
	var y: int = Guide.index_of("yard")
	m.guide_note("yard", 2)
	check.call(not Guide.met(y, m), "길라잡이: 수련장 두 번은 아직")
	m.guide_note("yard")
	check.call(Guide.met(y, m), "길라잡이: 수련장은 세 번 베면 끝")
	var q := Meta.new()
	q.quest_board = [0]
	q.take_quest(0)
	check.call(Guide.count(Guide.index_of("quest"), q) == 1, "길라잡이: 의뢰를 맡으면 센다")


func _hidden() -> void:
	var m := Meta.new()
	var n: int = Guide.index_of("traveller") + 1   # 미래·타임트래블러가 맨 끝에서 둘(그 뒤는 균열 단계)
	var base: int = Guide.size() - 2   # 균열 닫기·수리 안내는 3막 전에는 없다
	check.call(Guide.shown_count(m) == n - 2 and not Guide.shown(n - 1, m) and not Guide.shown(n - 2, m), "길라잡이: 틈이 열리기 전에는 미래·이야기 단계가 목록에 없다")
	m.guide_note("future_enter")
	m.time_traveller = true
	check.call(Guide.sync(m).filter(func(i: int) -> bool: return i >= n - 2).is_empty() and Guide.hint_for(n - 2, "field", m) == "", "길라잡이: 열리기 전에는 끝나지도 않고 방향도 없다")
	m.stranger_done = true
	check.call(Guide.shown_count(m) == base and Guide.hint_for(n - 2, "field", m) == "rift", "길라잡이: 틈이 열리면 목록에 들어가고 방향이 생긴다")
	var ids: Array[int] = Guide.sync(m).filter(func(i: int) -> bool: return i >= n - 2)
	check.call(ids == [n - 2, n - 1], "길라잡이: 열린 뒤에 끝난다")


func _legacy() -> void:
	var m := Meta.new()
	m.from_dict({"shards": 40, "runs": 5, "best": 4, "sheath_peak": 2, "heard": {"gatekeeper": [0]}})
	check.call(not m.guide_init, "길라잡이: 옛 저장은 아직 정리되지 않았다")
	var r: Array[int] = Guide.sync(m)
	check.call(r.is_empty() and m.shards == 40, "길라잡이: 옛 저장은 보상 없이 조용히 끝낸다")
	var need: bool = true
	for id in ["talk_gate", "rack", "hill_gate", "first_pull", "first_night", "path", "day_event", "finish_run", "spend", "quest", "yard"]:
		need = need and Guide.is_done(Guide.index_of(id), m)
	check.call(need, "길라잡이: 이미 판을 해 본 저장은 마을·언덕 단계가 끝나 있다")
	check.call(Guide.current(m) == Guide.index_of("field") or Guide.current(m) > Guide.index_of("finish_run"), "길라잡이: 고참은 첫 단계에 걸리지 않는다")
	var fresh := Meta.new()
	fresh.from_dict({"shards": 3})
	Guide.sync(fresh)
	check.call(Guide.done_count(fresh) == 0 and Guide.current(fresh) == 0, "길라잡이: 옛 저장이라도 한 게 없으면 처음부터")


func _save() -> void:
	var m := Meta.new()
	m.heard["gatekeeper"] = [0]
	m.guide_note("rack")
	m.guide_fold = true
	Guide.sync(m)
	var path: String = "user://test_guide_save.json"
	m.save(path)
	var m2 := Meta.load_or_new(path)
	check.call(m2.guide_done == m.guide_done and m2.guide_ev == m.guide_ev and m2.guide_init and m2.guide_fold and m2.guide_step == m.guide_step, "길라잡이: 저장하고 읽어도 그대로")
	var before: int = m2.shards
	check.call(Guide.sync(m2).is_empty() and m2.shards == before, "길라잡이: 읽은 뒤 보상이 다시 나가지 않는다")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
