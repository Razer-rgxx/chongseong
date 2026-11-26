extends RefCounted
## 검의 기억 테스트(docs/sword_memory.md). run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/memory_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_slots_and_runes()
	_deterministic()
	_sockets()
	_bonuses()
	_naming()
	_save()
	_modes()
	_guide()
	Meta.new()._mirror()   # 화면 거울을 비운다(다른 테스트에 안 새게)


func _meta() -> Meta:
	var m := Meta.new()
	m._mirror()
	return m


func _bag_total(m: Meta) -> int:
	var n: int = 0
	for k in m.rune_bag:
		n += int(m.rune_bag[k])
	return n


func _slots_and_runes() -> void:
	var m := _meta()
	check.call(m.rune_slots(5) == 0 and m.runes_of(5).is_empty() and m.rune_bag.is_empty(), "기억: 처음엔 룬 자리도 룬도 없다")
	for i in 99:
		m.log_kill(5)
	check.call(m.rune_slots(5) == 0 and _bag_total(m) == 0 and m.kills_of(5) == 99, "기억: 99마리면 자리가 없다")
	m.log_kill(5)
	check.call(m.rune_slots(5) == 1 and _bag_total(m) == 1 and m.runes_of(5).is_empty(), "기억: 100마리에 자리 하나, 룬은 주머니로(저절로 박히지 않는다)")
	check.call(m.sync_runes(5).is_empty() and _bag_total(m) == 1, "기억: 자리가 열릴 때 한 번만 준다")
	m.set_memory(5, 400)
	check.call(m.rune_slots(5) == 2 and _bag_total(m) == 2, "기억: 400마리에 자리 둘, 룬 둘째")
	m.set_memory(5, 1000)
	check.call(m.rune_slots(5) == 3 and _bag_total(m) == 3, "기억: 1000마리에 자리 셋, 룬 셋째")
	m.set_memory(5, 99999)
	check.call(m.rune_slots(5) == 3 and _bag_total(m) == 3, "기억: 자리는 셋까지, 더 안 준다")
	check.call(m.rune_news.size() == 3 and m.take_rune_news(d).contains("룬 자리가 열렸다"), "기억: 자리가 열리면 알림")
	check.call(Meta.rt().runes.size() == 8 and Meta.rt().get("gems") == null and Meta.rt().tier_mult.size() == 3, "기억: 룬 8종 × 3단계, 보석 없음")
	var rt: RuneTable = Meta.rt()
	check.call(rt.valid_rune("keen:3") and not rt.valid_rune("keen:4") and not rt.valid_rune("ruby:1") and rt.norm("keen") == "keen:1", "룬: 키 규칙(종류:단계, 옛 키는 1단계)")
	check.call(absf(rt.rune_value("keen:3") - 0.12) < 0.0001 and rt.rune_text("keen:2") == "치명타 확률 +8%", "룬: 단계가 값을 키운다(%s)" % rt.rune_text("keen:2"))
	check.call(m.kills_of(6) == 0, "기억: 검마다 따로 센다")


func _deterministic() -> void:
	var a := _meta()
	var b := _meta()
	for m in [a, b]:
		m.use_note(9, "night", 30)
		m.use_note(9, "big", 10)
		m.use_note(9, "boss", 40)
		m.set_memory(9, 1000)
	check.call(a.rune_bag == b.rune_bag, "기억: 같은 쓰임이면 같은 룬")
	check.call(a.rune_bag == {"hunt:1": 3}, "기억: 자리가 열릴 때 가장 많이 쓴 종류(사냥 40)의 1단계 룬: %s" % str(a.rune_bag))
	var c := _meta()
	c.set_memory(10, 100)
	check.call(c.rune_bag == {"keen:1": 1}, "기억: 쓰임이 없으면 표 순서 첫 룬")
	var e := _meta()
	e.use_note(11, "dash", 5)
	e.use_note(11, "hurt", 5)
	e.set_memory(11, 100)
	check.call(e.rune_bag == {"wind:1": 1}, "기억: 같은 수면 표 순서(바람이 불굴보다 앞): %s" % str(e.rune_bag))
	var f := _meta()
	f.set_memory(12, 100)
	f.use_note(12, "elite", 50)
	f.set_memory(12, 400)   # 쓰임이 바뀐 뒤 열린 둘째 자리는 그때의 쓰임을 따른다
	check.call(f.rune_bag == {"keen:1": 1, "elite:1": 1}, "기억: 자리마다 그때의 쓰임을 따른다: %s" % str(f.rune_bag))


func _sockets() -> void:
	var m := _meta()
	check.call(m.rune_slots(5) == 0 and m.socket_rune(5, "keen:1") == "none", "룬: 주머니에 없으면 거절")
	m.rune_add("keen:1")
	check.call(m.socket_rune(5, "keen:1") == "full", "룬: 자리가 없으면 거절")
	m.set_memory(5, 100)   # 자리 하나 + 공짜 keen:1
	check.call(int(m.rune_bag["keen:1"]) == 2, "룬: 자리가 열리면 공짜 룬이 주머니에")
	check.call(m.socket_rune(5, "keen:1") == "ok" and m.runes_of(5) == ["keen:1"] and int(m.rune_bag["keen:1"]) == 1, "룬: 박으면 주머니에서 빠진다")
	check.call(m.socket_rune(5, "keen:1") == "full", "룬: 자리가 차면 거절")
	m.set_memory(5, 400)
	m.rune_add("night:2")
	check.call(m.socket_rune(5, "night:2") == "ok" and m.runes_of(5) == ["keen:1", "night:2"], "룬: 자리 둘이면 둘째도 박는다")
	m.rune_add("hunt:1")
	check.call(m.socket_rune(5, "hunt:1") == "full", "룬: 자리 수를 넘기면 거절")
	m.set_memory(5, 1000)
	check.call(m.socket_rune(5, "keen:1") == "ok" and m.runes_of(5).size() == 3, "룬: 같은 종류도 박는다")
	check.call(m.socket_rune(5, "nope:1") == "bad" and m.socket_rune(5, "keen:9") == "bad" and m.socket_rune(5, "ruby:1") == "bad", "룬: 모르는 룬은 거절")
	m.shards = 5
	check.call(m.unsocket_rune(5, 1) == "poor" and m.runes_of(5).size() == 3, "룬: 조각이 모자라면 못 뺀다")
	m.shards = 100
	var before: int = int(m.rune_bag.get("night:2", 0))
	check.call(m.unsocket_rune(5, 1) == "ok" and m.shards == 70 and int(m.rune_bag.get("night:2", 0)) == before + 1 and m.runes_of(5) == ["keen:1", "keen:1"], "룬: 2단계를 빼면 조각 30, 룬은 주머니로")
	check.call(m.unsocket_rune(5, 9) == "bad", "룬: 없는 자리는 뺄 수 없다")
	var m2 := _meta()
	m2.shards = 59
	check.call(m2.buy_rune("keen", 1) == "poor" and m2.rune_bag.is_empty(), "룬: 조각이 모자라면 못 산다")
	m2.shards = 60
	check.call(m2.buy_rune("keen", 1) == "ok" and m2.shards == 0 and int(m2.rune_bag["keen:1"]) == 1, "룬: 조각 60에 거친 예리의 룬")
	check.call(m2.buy_rune("nope", 1) == "bad", "룬: 모르는 종류는 못 산다")
	var m3 := _meta()
	var seen: Dictionary = {}
	for i in 600:
		var k: String = m3.roll_rune(true)
		if k != "":
			seen[k] = 1
	check.call(seen.size() > 10 and m3.rune_bag.size() == seen.size(), "룬: 보스 드롭이 여러 종류로 나온다(%d)" % seen.size())
	check.call(m3.boss_defeat().has("rune"), "룬: 우두머리 보상에 rune 칸")
	var m4 := _meta()
	var m5 := _meta()
	m4.rng.seed = 5
	m5.rng.seed = 5
	for i in 50:
		m4.roll_rune(false)
		m5.roll_rune(false)
	check.call(m4.rune_bag == m5.rune_bag, "룬: 같은 Meta 시드면 같은 드롭")


func _held_rules(m: Meta, id: int, seed: int = 11) -> Rules:
	var r := Rules.new(d, seed, m)
	var s := Sword.new(d.sword_by_id(id), d)
	r.slots[0] = s
	r.active = 0
	return r


func _bonuses() -> void:
	var m := _meta()
	m.set_memory(1, 1000)
	for k in ["night:3", "grit:3", "day:3"]:
		m.rune_add(k)
	# 기준: 아무것도 안 박은 검
	var base_a := _held_rules(Meta.new(), 1)
	Meta.new()._mirror()
	var st0: Dictionary = base_a.powers.stats()
	var dur0: float = base_a.slots[0].max_durability
	m._mirror()
	check.call(m.socket_rune(1, "night:3") == "ok" and m.socket_rune(1, "grit:3") == "ok" and m.socket_rune(1, "day:3") == "ok", "룬 보너스: 셋을 박는다")
	var r1 := _held_rules(m, 1)
	var st1: Dictionary = r1.powers.stats()
	r1.phase = Rules.Phase.NIGHT
	var st1n: Dictionary = r1.powers.stats()
	check.call(float(st1n.dmg) > float(st1.dmg) and float(st1.dmg) >= float(st0.dmg) * 0.999, "보너스: 밤의 룬은 밤에만 피해를 올린다(%.3f → %.3f)" % [float(st1.dmg), float(st1n.dmg)])
	check.call(r1.slots[0].max_durability > dur0 or dur0 <= 0.0, "룬 보너스: 낮의 룬이 내구를 올린다(%s → %s)" % [dur0, r1.slots[0].max_durability])
	check.call(absf(float(r1.powers.cv("guard")) - 0.12) < 0.001, "보너스: 불굴의 룬 3단계가 받는 피해를 줄인다(%s)" % r1.powers.cv("guard"))
	# 다른 검에는 안 붙는다
	var other := _held_rules(m, 3)
	check.call(other.powers.cv("night") == 0.0 and other.powers.cv("guard") == 0.0, "보너스: 다른 검에는 안 붙는다")
	Meta.new()._mirror()
	var none := _held_rules(Meta.new(), 1)
	check.call(none.powers.cv("guard") == 0.0 and absf(float(none.powers.stats().dmg) - float(st0.dmg)) < 0.001, "보너스: 룬이 없으면 예전과 같다")
	# 결정성: 같은 시드, 같은 입력이면 같은 해시
	m._mirror()
	var ra := _held_rules(m, 1, 5)
	var rb := _held_rules(m, 1, 5)
	var inp := LordInput.new()
	inp.attack = true
	for t in 90:
		ra.step(inp)
		rb.step(inp)
	check.call(ra.state_hash() == rb.state_hash(), "기억: 룬이 있어도 같은 시드면 같은 상태")
	# 쓰임 세기
	var ma := _meta()
	var rc := _held_rules(ma, 1, 3)
	rc.note_use("dash")
	check.call(ma.use_of(1, "dash") == 1, "기억: 돌진을 센다")
	Meta.new()._mirror()


func _naming() -> void:
	var m := _meta()
	var sd: SwordData = d.sword_by_id(5)
	check.call(not m.can_name(sd, d.grades) and m.set_sword_name(sd, "별빛", d.grades) == "locked", "이름: 룬 자리 셋 전에는 못 짓는다")
	m.set_memory(5, 1000)
	check.call(m.can_name(sd, d.grades), "이름: 룬 자리 셋이면 지을 수 있다")
	check.call(m.set_sword_name(sd, "새벽의검 한 자루 이름이 너무 길다", d.grades) == "ok" and String(m.sword_names["5"]).length() <= 12, "이름: 12자까지만")
	check.call(m.set_sword_name(sd, "새벽 검", d.grades) == "ok" and Meta.shown_name(sd) == "새벽 검", "이름: 지으면 화면 이름이 바뀐다")
	var s := Sword.new(sd, d)
	check.call(s.label().ends_with("새벽 검") and sd.display_name != "새벽 검", "이름: Sword.label이 지은 이름을 쓴다(원래 이름은 그대로)")
	check.call(m.set_sword_name(sd, "★☆%$", d.grades) == "empty", "이름: 쓸 수 없는 글자뿐이면 거절")
	check.call(Meta.clean_name("  검<b>1  ") == "검b1", "이름: 쓸 수 없는 글자는 걸러진다(%s)" % Meta.clean_name("  검<b>1  "))
	check.call(m.set_sword_name(sd, "", d.grades) == "ok" and Meta.shown_name(sd) == sd.display_name, "이름: 비우면 원래 이름")
	var inf: SwordData = null
	for x in d.swords:
		if x.grade >= d.grades.names.size() - 1:
			inf = x
			break
	check.call(inf != null and m.can_name(inf, d.grades), "이름: 무한 등급은 룬 없이도 짓는다")
	# 글꼴: 이름에 쓸 수 있는 모든 한글 음절을 기본 글꼴이 가졌다
	var f: Font = load("res://assets/ui/fonts/DNFForgedBlade-Medium.otf")
	var missing: int = 0
	for c in range(0xAC00, 0xD7A4, 7):
		if not f.has_char(c):
			missing += 1
	check.call(missing == 0, "이름: 기본 글꼴(던파)이 한글 음절을 다 가졌다(빠진 %d)" % missing)


func _save() -> void:
	var m := _meta()
	m.use_note(7, "boss", 12)
	m.set_memory(7, 1000)
	m.rune_add("elite:2", 3)
	m.socket_rune(7, "elite:2")
	m.set_sword_name(d.sword_by_id(7), "검은 달", d.grades)
	var j: Variant = JSON.parse_string(JSON.stringify(m.to_dict()))
	var n := Meta.new()
	n.from_dict(j)
	check.call(n.runes_of(7) == ["elite:2"] and n.rune_placed == 1, "저장: 박은 룬과 박은 횟수")
	check.call(int(n.rune_bag["elite:2"]) == 2 and int(n.rune_bag["hunt:1"]) == 3 and n.use_of(7, "boss") == 12 and n.kills_of(7) == 1000, "저장: 주머니·쓰임·벤 수")
	check.call(int(n.slot_given["7"]) == 3 and n.sync_runes(7).is_empty() and n.rune_news.is_empty(), "저장: 받은 공짜 룬 수가 남아 다시 안 준다")
	check.call(n.sword_names.get("7") == "검은 달" and Meta.shown_name(d.sword_by_id(7)) == "검은 달", "저장: 이름과 화면 거울")
	check.call(absf(float(Meta.carve_of(7).get("knock", 0.0)) - 0.16) < 0.001 and Meta.carve_of(8).is_empty(), "저장: 거울의 수치는 그 검에만")
	var dd: Dictionary = n.to_dict()
	check.call(not dd.has("sword_gems") and not dd.has("gem_bag"), "저장: 보석 칸은 더 안 쓴다")
	# 옛 저장(새 칸 없음)
	var old := Meta.new()
	old.from_dict({"shards": 12})
	check.call(old.sword_runes.is_empty() and old.rune_bag.is_empty() and old.sword_names.is_empty() and old.shards == 12 and old.gem_refund == 0, "저장: 옛 저장은 새 칸 없이도 읽힌다")
	# 옛 자동 룬은 박힌 채 남고, 그 자리의 공짜 룬은 또 안 준다
	var auto := Meta.new()
	auto.from_dict({"sword_runes": {"1": ["keen", "night"]}, "sword_log": {"1": {"k": 450}}})
	check.call(auto.runes_of(1) == ["keen:1", "night:1"] and int(auto.slot_given["1"]) == 2, "저장: 옛 자동 룬은 1단계로 박힌 채 남는다")
	check.call(auto.sync_runes(1).is_empty() and auto.rune_bag.is_empty(), "저장: 옛 자동 룬의 자리는 공짜 룬을 또 주지 않는다")
	# 옛 보석은 사던 값의 조각으로(60/180/500)
	var gem := Meta.new()
	gem.from_dict({"shards": 10, "gem_bag": {"ruby:1": 2, "lapis:3": 1}, "sword_gems": {"1": ["amber:2"]}})
	check.call(gem.shards == 10 + 120 + 500 + 180 and gem.gem_refund == 800 and gem.rune_bag.is_empty() and gem.rune_placed == 1, "저장: 옛 보석은 사던 값의 조각으로 바뀐다(%d)" % gem.shards)
	var again := Meta.new()
	again.from_dict(JSON.parse_string(JSON.stringify(gem.to_dict())))
	check.call(again.shards == gem.shards and again.gem_refund == 0, "저장: 보석 조각은 한 번만 준다")
	# 망가진 값은 걸러진다
	var bad := Meta.new()
	bad.from_dict({"sword_runes": {"1": ["nope", "keen", "keen:9", "night:2", "ruby:1"]}, "rune_bag": {"x": 3, "keen": 2, "keen:1": 1}, "sword_names": {"1": "<<>>"}})
	check.call(bad.runes_of(1) == ["keen:1", "night:2"] and bad.rune_bag == {"keen:1": 3} and bad.sword_names.is_empty(), "저장: 모르는 룬·이름은 걸러진다")
	var guide := Meta.new()
	guide.from_dict({"guide_done": {"gem_socket": 1}})
	check.call(guide.guide_done.has("rune_socket") and not guide.guide_done.has("gem_socket"), "저장: 길라잡이 보석 박기는 룬 박기로 이어진다")


func _modes() -> void:
	# 어느 장면이든 쓰러뜨리면 Meta.log_kill이 부르는 것이라, 쥔 검 번호별로 센다. 들판·무덤·미래·과거는 같은 Rules.hurt를 쓴다.
	var m := _meta()
	for mode in ["hill", "field", "crypt", "future", "past"]:
		for i in 25:
			m.log_kill(12)
	check.call(m.kills_of(12) == 125 and m.rune_slots(12) == 1 and _bag_total(m) == 1, "기억: 모든 곳의 처치가 검 번호로 합쳐진다(125)")
	var r := Rules.new(d, 4, m)
	r.slots[0] = Sword.new(d.sword_by_id(12), d)
	r.active = 0
	var before: int = m.use_of(12, "day") + m.use_of(12, "night")
	var en := r._spawn(&"wraith")
	check.call(en != null, "기억: 적을 세울 수 있다")
	if en != null:
		r.hurt(en, 999999.0, Vector2.ZERO, true)
		check.call(m.use_of(12, "big") == 1 and m.use_of(12, "day") + m.use_of(12, "night") == before + 1, "기억: 처치가 큰 베기·밤낮을 센다")
	Meta.new()._mirror()


func _guide() -> void:
	var m := _meta()
	var a: int = Guide.index_of("first_rune")
	var b: int = Guide.index_of("rune_socket")
	check.call(a >= 0 and b == a + 1 and a < Guide.index_of("future") and a > Guide.index_of("stranger") and Guide.index_of("gem_socket") == -1, "길라잡이: 룬 단계가 낯선 사람 뒤, 숨은 단계 앞, 보석 단계는 없다")
	check.call(Guide.title_of(b) == "룬 박기" and Guide.count(a, m) == 0 and Guide.count(b, m) == 0, "길라잡이: 처음엔 둘 다 0")
	m.set_memory(5, 100)
	check.call(Guide.count(a, m) == 1 and Guide.count(b, m) == 0, "길라잡이: 자리가 열리면 첫 룬이 끝, 박기는 아직")
	m.socket_rune(5, "keen:1")
	check.call(Guide.count(b, m) == 1, "길라잡이: 룬을 박으면 끝")
	var o := _meta()
	o.from_dict({"sword_runes": {"1": ["keen"]}, "shards": 1})
	check.call(Guide.legacy_ok(a, o) and not Guide.legacy_ok(b, o), "길라잡이: 옛 자동 룬은 첫 룬만 이룬 것으로 본다")
