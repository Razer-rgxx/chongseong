extends RefCounted
## 총 든 낯선 사람 테스트(docs/stranger.md). run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/stranger_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_roll()
	_meta()
	_sword()


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _roll() -> void:
	var far := Vector2(2, 2)
	check.call(Stranger.roll(_rng(1), 0, false, -1, &"clear", far, true).has("spot"), "낯선 사람: 굴림이 되면 {spot, line, final}")
	var a: Dictionary = Stranger.roll(_rng(7), 0, false, -1, &"clear", far, true)
	var b: Dictionary = Stranger.roll(_rng(7), 0, false, -1, &"clear", far, true)
	check.call(a == b, "낯선 사람: 같은 시드면 같은 자리와 말")
	check.call(Stranger.roll(_rng(7), 0, false, -1, &"storm", far, true).is_empty(), "낯선 사람: 폭풍에는 안 나타난다")
	check.call(Stranger.roll(_rng(7), 9, true, -1, &"clear", far, true).is_empty() and Stranger.roll(_rng(7), 4, false, 3, &"clear", far, true).is_empty(), "낯선 사람: 마쳤거나 물건이 놓여 있으면 안 나타난다")
	var hits: int = 0
	var r := _rng(5)
	for i in 400:
		if not Stranger.roll(r, 0, false, -1, &"clear", far).is_empty():
			hits += 1
	check.call(hits > 60 and hits < 180, "낯선 사람: 확률은 작다(400번 중 %d)" % hits)
	var fin: Dictionary = Stranger.roll(_rng(3), 4, false, -1, &"clear", far, true)
	check.call(bool(fin.final) and not bool(Stranger.roll(_rng(3), 3, false, -1, &"clear", far, true).final), "낯선 사람: 4번 만난 뒤가 다섯 번째 만남")
	var spot_ok: bool = true
	for i in 50:
		var x: Dictionary = Stranger.roll(_rng(i), 0, false, -1, &"clear", FieldLayout.STRANGER_SPOTS[0], true)
		if not x.is_empty() and FieldLayout.STRANGER_SPOTS[int(x.spot)].distance_to(FieldLayout.STRANGER_SPOTS[0]) < Stranger.MIN_START:
			spot_ok = false
	check.call(spot_ok, "낯선 사람: 영주에게서 먼 자리에만 선다")
	check.call(Stranger.shot_damage(100.0) == Stranger.SHOT_DAMAGE and Stranger.shot_damage(5.0) == 4.0 and Stranger.shot_damage(1.0) == 0.0, "총: 죽지 않는다(체력 1은 남는다)")


func _meta() -> void:
	var path: String = "user://test_stranger_save.json"
	var m := Meta.new()
	m.see_stranger()
	m.see_stranger()
	m.save(path)
	var m2 := Meta.load_or_new(path)
	check.call(m2.stranger_seen == 2 and not m2.stranger_done, "낯선 사람: 만난 횟수를 저장하고 읽는다")
	m2.stranger_seen = 4
	check.call(Stranger.is_final(m2.stranger_seen, m2.stranger_done), "낯선 사람: 다섯 번째 만남")
	check.call(not m2.take_stranger_sword(), "낯선 사람: 물건이 없으면 검을 안 준다")
	m2.stranger_drop = 2
	m2.save(path)
	var m3 := Meta.load_or_new(path)
	check.call(m3.stranger_drop == 2, "낯선 사람: 떨군 물건의 자리를 저장한다")
	check.call(m3.take_stranger_sword() and m3.stranger_done and m3.stranger_drop == -1 and m3.has_found(Stranger.SWORD), "사이버 카타나: 주우면 도감에 들고 이야기가 끝난다")
	check.call(not m3.take_stranger_sword(), "사이버 카타나: 한 번만")
	m3.save(path)
	var m4 := Meta.load_or_new(path)
	check.call(m4.stranger_done and m4.has_found(Stranger.SWORD) and Stranger.roll(_rng(1), 9, m4.stranger_done, m4.stranger_drop, &"clear", Vector2(2, 2), true).is_empty(), "낯선 사람: 마친 뒤에는 다시 안 나타난다(저장됨)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _sword() -> void:
	var s: SwordData = d.sword_by_id(Stranger.SWORD)
	check.call(s != null and s.display_name == "사이버 카타나" and s.field_only and d.is_field_sword(311), "사이버 카타나: 오픈월드 한정 검 311")
	check.call(s.unique_ready and s.cyber and s.cyber_powers == PackedStringArray(["글리치 순간베기"]), "사이버 카타나: 고유 능력은 글리치 순간베기(docs/cyber_swords.md)")
	var m := Meta.new()
	m.note_found(Stranger.SWORD)
	var sw: Sword = m.unbreakable_sword(d, Stranger.SWORD)
	check.call(sw != null and sw.data.id == 311 and not sw.breakable(), "사이버 카타나: 부러지지 않는 검으로 쥔다")
	var model: SwordModel = SwordModel.make(d.forms[3], 4, 311, d.grades.colors[4])
	# Blender 모델(assets/swords/311.glb)이 있으면 그것(두 손 손잡이, 칼끝이 칼등 쪽으로 조금), 없으면 코드로 지은 모양
	var from_glb: bool = ResourceLoader.exists("res://assets/swords/311.glb")
	var own_look: bool = (model.grip_length == SwordModel.KATANA_GRIP and model.tip_x == SwordModel.KATANA_TIP_X) if from_glb else model.get_child_count() > 8
	check.call(own_look and model.glow_color == SwordModel.KATANA_BLUE, "사이버 카타나: 모양이 따로 있다")
	check.call(model.find_children("*", "CPUParticles3D", true, false).is_empty(), "사이버 카타나: 떠다니는 빛 알갱이 없음")
	model.free()
