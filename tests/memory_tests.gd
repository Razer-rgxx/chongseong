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


func _slots_and_runes() -> void:
	var m := _meta()
	check.call(m.rune_slots(5) == 0 and m.runes_of(5).is_empty(), "기억: 처음엔 룬 자리가 없다")
	for i in 99:
		m.log_kill(5)
	check.call(m.runes_of(5).is_empty() and m.kills_of(5) == 99, "기억: 99마리면 룬이 없다")
	m.log_kill(5)
	check.call(m.runes_of(5).size() == 1 and m.rune_slots(5) == 1, "기억: 100마리에 룬 하나")
	m.set_memory(5, 400)
	check.call(m.runes_of(5).size() == 2, "기억: 400마리에 룬 둘")
	m.set_memory(5, 1000)
	check.call(m.runes_of(5).size() == 3 and m.rune_slots(5) == 3, "기억: 1000마리에 룬 셋")
	m.set_memory(5, 99999)
	check.call(m.runes_of(5).size() == 3, "기억: 자리는 셋까지")
	var uniq: Dictionary = {}
	for k in m.runes_of(5):
		uniq[k] = 1
	check.call(uniq.size() == 3, "기억: 같은 룬이 겹치지 않는다")
	check.call(Meta.rt().runes.size() == 8 and Meta.rt().gems.size() == 6, "기억: 룬 8종, 보석 6종")
	check.call(m.kills_of(6) == 0, "기억: 검마다 따로 센다")


func _deterministic() -> void:
	var a := _meta()
	var b := _meta()
	for m in [a, b]:
		m.use_note(9, "night", 30)
		m.use_note(9, "big", 10)
		m.use_note(9, "boss", 40)
		m.set_memory(9, 1000)
	check.call(a.runes_of(9) == b.runes_of(9), "기억: 같은 쓰임이면 같은 룬")
	check.call(a.runes_of(9) == ["hunt", "night", "keen"], "기억: 쓰임이 많은 순서(사냥 40, 밤 30, 예리 10)로 고른다: %s" % str(a.runes_of(9)))
	var c := _meta()
	c.set_memory(10, 100)
	check.call(c.runes_of(10) == ["keen"], "기억: 쓰임이 없으면 표 순서 첫 룬")
	var e := _meta()
	e.use_note(11, "dash", 5)
	e.use_note(11, "hurt", 5)
	e.set_memory(11, 100)
	check.call(e.runes_of(11) == ["wind"], "기억: 같은 수면 표 순서(바람이 불굴보다 앞): %s" % str(e.runes_of(11)))


func _sockets() -> void:
	var m := _meta()
	check.call(m.socket_count(5) == 0 and m.socket_gem(5, "ruby:1") == "none", "보석: 룬이 없으면 자리 0, 주머니에 없으면 거절")
	m.gem_add("ruby:1")
	check.call(m.socket_gem(5, "ruby:1") == "full", "보석: 룬이 없으면 자리가 없다")
	m.set_memory(5, 100)
	check.call(m.socket_count(5) == 1, "보석: 룬 하나면 자리 하나")
	check.call(m.socket_gem(5, "ruby:1") == "ok" and m.gems_of(5) == ["ruby:1"] and m.gem_bag.is_empty(), "보석: 박으면 주머니에서 빠진다")
	m.gem_add("lapis:2")
	check.call(m.socket_gem(5, "lapis:2") == "full", "보석: 자리가 차면 거절")
	m.set_memory(5, 400)
	check.call(m.socket_count(5) == 2 and m.socket_gem(5, "lapis:2") == "ok", "보석: 룬 둘이면 자리 둘")
	m.gem_add("amber:1")
	check.call(m.socket_gem(5, "amber:1") == "full", "보석: 자리는 둘까지")
	check.call(m.socket_gem(5, "nope:1") == "bad" and m.socket_gem(5, "ruby:9") == "bad", "보석: 모르는 보석은 거절")
	m.shards = 5
	check.call(m.unsocket_gem(5, 0) == "poor" and m.gems_of(5).size() == 2, "보석: 조각이 모자라면 못 뺀다")
	m.shards = 100
	check.call(m.unsocket_gem(5, 0) == "ok" and m.shards == 90 and int(m.gem_bag.get("ruby:1", 0)) == 1 and m.gems_of(5) == ["lapis:2"], "보석: 빼면 조각 10, 보석은 주머니로")
	var m2 := _meta()
	m2.shards = 59
	check.call(m2.buy_gem("ruby", 1) == "poor" and m2.gem_bag.is_empty(), "보석: 조각이 모자라면 못 산다")
	m2.shards = 60
	check.call(m2.buy_gem("ruby", 1) == "ok" and m2.shards == 0 and int(m2.gem_bag["ruby:1"]) == 1, "보석: 조각 60에 거친 홍옥")
	var m3 := _meta()
	var seen: Dictionary = {}
	for i in 400:
		var k: String = m3.roll_gem(true)
		if k != "":
			seen[k] = 1
	check.call(seen.size() > 6 and m3.gem_bag.size() == seen.size(), "보석: 보스 드롭이 여러 종류로 나온다(%d)" % seen.size())
	check.call(m3.boss_defeat().has("gem"), "보석: 우두머리 보상에 gem 칸")


func _held_rules(m: Meta, id: int, seed: int = 11) -> Rules:
	var r := Rules.new(d, seed, m)
	var s := Sword.new(d.sword_by_id(id), d)
	r.slots[0] = s
	r.active = 0
	return r


func _bonuses() -> void:
	var m := _meta()
	m.set_memory(1, 400)
	m.sword_runes["1"] = ["night", "grit"]
	m.gem_add("ruby:3")
	m.gem_add("amethyst:3")
	m.sword_runes["2"] = ["night", "grit"]
	m._mirror()
	# 기준: 아무것도 안 박은 검
	var base_a := _held_rules(Meta.new(), 1)
	Meta.new()._mirror()
	var st0: Dictionary = base_a.powers.stats()
	var dur0: float = base_a.slots[0].max_durability
	m._mirror()
	m.socket_gem(1, "ruby:3")
	m.socket_gem(1, "amethyst:3")
	var r1 := _held_rules(m, 1)
	var st1: Dictionary = r1.powers.stats()
	r1.phase = Rules.Phase.NIGHT
	var st1n: Dictionary = r1.powers.stats()
	check.call(absf(float(st1.dmg) / float(st0.dmg) - 1.10) < 0.06, "보석 보너스: 홍옥 3단계가 피해를 올린다(%.3f)" % (float(st1.dmg) / float(st0.dmg)))
	check.call(float(st1n.dmg) >= float(st1.dmg), "보너스: 밤의 룬은 밤에만")
	check.call(r1.slots[0].max_durability > dur0 or dur0 <= 0.0, "보석 보너스: 자수정이 내구를 올린다(%s → %s)" % [dur0, r1.slots[0].max_durability])
	check.call(float(r1.powers.cv("guard")) > 0.0 and float(r1.powers.cv("dmg")) > 0.0, "보너스: cv가 룬과 보석을 합친다")
	# 다른 검에는 안 붙는다
	var other := _held_rules(m, 3)
	check.call(other.powers.cv("dmg") == 0.0 and other.powers.cv("guard") == 0.0, "보너스: 다른 검에는 안 붙는다")
	Meta.new()._mirror()
	var none := _held_rules(Meta.new(), 1)
	check.call(none.powers.cv("dmg") == 0.0 and absf(float(none.powers.stats().dmg) - float(st0.dmg)) < 0.001, "보너스: 룬·보석이 없으면 예전과 같다")
	# 결정성: 같은 시드, 같은 입력이면 같은 해시
	m._mirror()
	var ra := _held_rules(m, 1, 5)
	var rb := _held_rules(m, 1, 5)
	var inp := LordInput.new()
	inp.attack = true
	for t in 90:
		ra.step(inp)
		rb.step(inp)
	check.call(ra.state_hash() == rb.state_hash(), "기억: 룬·보석이 있어도 같은 시드면 같은 상태")
	# 쓰임 세기
	var ma := _meta()
	var rc := _held_rules(ma, 1, 3)
	rc.note_use("dash")
	check.call(ma.use_of(1, "dash") == 1, "기억: 돌진을 센다")
	Meta.new()._mirror()


func _naming() -> void:
	var m := _meta()
	var sd: SwordData = d.sword_by_id(5)
	check.call(not m.can_name(sd, d.grades) and m.set_sword_name(sd, "별빛", d.grades) == "locked", "이름: 룬 셋 전에는 못 짓는다")
	m.set_memory(5, 1000)
	check.call(m.can_name(sd, d.grades), "이름: 룬 셋이면 지을 수 있다")
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
	m.gem_add("obsidian:2", 3)
	m.socket_gem(7, "obsidian:2")
	m.set_sword_name(d.sword_by_id(7), "검은 달", d.grades)
	var j: Variant = JSON.parse_string(JSON.stringify(m.to_dict()))
	var n := Meta.new()
	n.from_dict(j)
	check.call(n.runes_of(7) == m.runes_of(7) and n.gems_of(7) == ["obsidian:2"], "저장: 룬과 박은 보석")
	check.call(int(n.gem_bag["obsidian:2"]) == 2 and n.use_of(7, "boss") == 12 and n.kills_of(7) == 1000, "저장: 주머니·쓰임·벤 수")
	check.call(n.sword_names.get("7") == "검은 달" and Meta.shown_name(d.sword_by_id(7)) == "검은 달", "저장: 이름과 화면 거울")
	check.call(Meta.carve_of(7).has("knock") and Meta.carve_of(8).is_empty(), "저장: 거울의 수치는 그 검에만")
	# 옛 저장(새 칸 없음)
	var old := Meta.new()
	old.from_dict({"shards": 12})
	check.call(old.sword_runes.is_empty() and old.gem_bag.is_empty() and old.sword_names.is_empty() and old.shards == 12, "저장: 옛 저장은 새 칸 없이도 읽힌다")
	# 망가진 값은 걸러진다
	var bad := Meta.new()
	bad.from_dict({"sword_runes": {"1": ["nope", "keen", "keen"]}, "sword_gems": {"1": ["ruby:9", "ruby:1"]}, "gem_bag": {"x": 3, "ruby:1": 2}, "sword_names": {"1": "<<>>"}})
	check.call(bad.runes_of(1) == ["keen"] and bad.gems_of(1) == ["ruby:1"] and bad.gem_bag.size() == 1 and bad.sword_names.is_empty(), "저장: 모르는 룬·보석·이름은 걸러진다")


func _modes() -> void:
	# 어느 장면이든 쓰러뜨리면 Meta.log_kill이 부르는 것이라, 쥔 검 번호별로 센다. 들판·무덤·미래·과거는 같은 Rules.hurt를 쓴다.
	var m := _meta()
	for mode in ["hill", "field", "crypt", "future", "past"]:
		for i in 25:
			m.log_kill(12)
	check.call(m.kills_of(12) == 125 and m.runes_of(12).size() == 1, "기억: 모든 곳의 처치가 검 번호로 합쳐진다(125)")
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
	var b: int = Guide.index_of("gem_socket")
	check.call(a >= 0 and b == a + 1 and a < Guide.index_of("future") and a > Guide.index_of("stranger"), "길라잡이: 룬·보석 단계가 낯선 사람 뒤, 숨은 단계 앞")
	check.call(Guide.count(a, m) == 0 and Guide.count(b, m) == 0, "길라잡이: 처음엔 둘 다 0")
	m.set_memory(5, 100)
	check.call(Guide.count(a, m) == 1 and Guide.count(b, m) == 0, "길라잡이: 룬이 새겨지면 첫 룬이 끝")
	m.gem_add("ruby:1")
	m.socket_gem(5, "ruby:1")
	check.call(Guide.count(b, m) == 1, "길라잡이: 보석을 박으면 끝")
	Meta.new()._mirror()
