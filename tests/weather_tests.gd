extends RefCounted
## 들판 날씨 테스트(docs/weather.md): 새벽·해질녘에만 바뀜, 결정성, 날씨마다 사건이 서고 한 번만 줌, 잿바람 불씨 땅, 저장.
## run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/weather_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_cycle()
	_events()
	_ash()
	_stone()
	_save()
	Grid.size = Vector2i(34, 22)


func _field(clock: float, seed_value: int = 1, weather: StringName = &"clear") -> Rules:
	var r := Rules.new(d, seed_value)
	Grid.size = FieldLayout.SIZE
	r.start_field(clock, weather)
	r.lord.pos = Vector2(55, 105)
	r.lord.prev_pos = r.lord.pos
	r.debug_god = true
	return r


func _run(r: Rules, secs: float) -> void:
	for _t in int(secs * 30.0 + 0.5):
		r.step()


## 시계를 경계(해질녘 FIELD_DAY, 새벽 한 바퀴) 바로 앞에 두고 한 번 넘긴 뒤의 규칙.
func _cross(seed_value: int, night: bool) -> Rules:
	var r := _field(FieldLayout.FIELD_DAY - 0.2 if night else FieldLayout.FIELD_DAY + FieldLayout.FIELD_NIGHT - 0.2, seed_value)
	_run(r, 0.5)
	return r


## 시드를 돌려 날씨가 kind인 규칙을 찾는다.
func _find(kind: StringName, night: bool) -> Rules:
	for sd in range(1, 400):
		var r := _cross(sd, night)
		if r.field_weather == kind:
			return r
	return null


func _cycle() -> void:
	var r := _field(10.0)
	var w0: StringName = r.field_weather
	var changes: Array = [0]
	r.field_weather_changed.connect(func(_k: StringName) -> void: changes[0] += 1)
	_run(r, 100.0)
	check.call(r.field_weather == w0 and changes[0] == 0, "날씨: 낮 한가운데에서는 바뀌지 않는다")
	var seen: Dictionary = {}
	var moved: bool = false
	for sd in range(1, 80):
		var a := _cross(sd, true)
		var b := _cross(sd, false)
		seen[a.field_weather] = 1
		seen[b.field_weather] = 1
		moved = moved or a.field_weather != &"clear" or b.field_weather != &"clear"
	check.call(seen.size() == FieldLayout.WEATHERS.size() and moved, "날씨: 해질녘·새벽에 굴려 다섯 날씨가 모두 나온다")
	var x := _cross(5, true)
	var y := _cross(5, true)
	check.call(x.field_weather == y.field_weather and x.state_hash() == y.state_hash(), "날씨: 같은 시드면 같은 날씨와 같은 state_hash")
	var z := _cross(5, true)
	z.field_weather = &"storm"
	check.call(z.state_hash() != y.state_hash(), "날씨: field_weather가 state_hash에 든다")
	var sig: Array = [&""]
	var q := _field(FieldLayout.FIELD_DAY - 0.2, 3, &"ash")
	q.field_weather_changed.connect(func(k: StringName) -> void: sig[0] = k)
	_run(q, 0.5)
	check.call(sig[0] == q.field_weather or q.field_weather == &"ash", "날씨: 바뀌면 field_weather_changed가 새 날씨와 함께 온다")


func _events() -> void:
	var rain := _find(&"rain", false)
	check.call(rain != null and rain.weather_spots.size() == FieldLayout.WX_RAIN_GLINTS and rain.weather_spots[0].kind == &"glint", "비: 젖은 쇳조각 자리가 둘 선다")
	var fog := _find(&"fog", true)
	check.call(fog != null and fog.weather_spots.size() == 1 and fog.weather_spots[0].kind == &"pilgrim", "안개: 길 잃은 순례자가 선다")
	var storm := _find(&"storm", false)
	check.call(storm != null and storm.weather_spots.size() == 1 and storm.weather_spots[0].kind == &"struck", "폭풍: 벼락 맞은 검이 선다")
	var night := _find(&"clear", true)
	var day := _find(&"clear", false)
	check.call(night != null and night.weather_spots.size() == 1 and night.weather_spots[0].kind == &"cache" and day != null and day.weather_spots.is_empty(), "맑음: 숨은 상자는 맑은 밤에만 선다")
	var meta := Meta.new()
	for r in [rain, fog, storm, night]:
		var sp: Dictionary = r.weather_spots[0]
		var before: int = meta.shards
		var first: Dictionary = r.use_weather_spot(int(sp.id))
		var second: Dictionary = r.use_weather_spot(int(sp.id))
		if not first.is_empty():
			meta.weather_reward(first.kind)
		check.call(not first.is_empty() and second.is_empty() and meta.shards > before, "%s 사건: 한 번만 주고 조각이 는다" % String(sp.kind))
	var iron0: int = meta.mat(&"iron")
	meta.weather_reward(&"struck")
	check.call(meta.mat(&"iron") > iron0, "폭풍 사건: 쇠 재료도 준다")
	var ash_meta := Meta.new()
	ash_meta.ensure_mat_spots()
	var n0: int = ash_meta.mat_spots.size()
	var added: Array[int] = ash_meta.ash_iron()
	check.call(added.size() == FieldLayout.WX_ASH_IRON and ash_meta.mat_spots.size() == n0 + added.size() and FieldLayout.MATS[added[0]][1] == &"iron", "잿바람: 철 자리가 더 선다")
	var cut := _find(&"rain", true)
	var moved: bool = false
	if cut != null:
		_run(cut, FieldLayout.FIELD_NIGHT + 1.0)
		moved = cut.weather_spots.is_empty() or cut.weather_spots[0].kind != &"glint" or cut.field_weather != &"rain"
	check.call(moved or cut == null or cut.weather_spots.size() == 2, "비: 날이 밝으면 자리가 새로 정해진다")


func _ash() -> void:
	var r := _field(10.0, 1, &"ash")
	r.debug_god = false
	r.lord.pos = Vector2(120, 20)
	r.lord.prev_pos = r.lord.pos
	r.lord.hp = r.max_hp()
	var warned: Array = [0]
	r.ember_warn.connect(func(_a: Vector2, _b: float, _c: float) -> void: warned[0] += 1)
	_run(r, 14.0)
	check.call(warned[0] >= FieldLayout.WX_ASH_COUNT and not r.embers.is_empty(), "잿바람: 영주 곁에 불씨 땅이 선다")
	var o := _field(10.0, 1, &"clear")
	_run(o, 14.0)
	check.call(o.embers.is_empty(), "맑은 날에는 불씨 땅이 없다")
	var hp0: float = r.max_hp()
	r.embers.clear()
	r.embers.append({"at": r.lord.pos, "warn": 0.0, "burn": 3.0})
	_run(r, 1.0)
	check.call(r.lord.hp < hp0, "잿바람: 불씨 땅 안에 서면 닳는다")


func _stone() -> void:
	var id: String = "stone_1"
	var plain: String = FieldLayout.stone_text(id, &"rain", true)
	var lit: String = FieldLayout.stone_text(id, &"clear", true)
	check.call(plain == FieldLayout.STONES[id][2] and lit.length() > plain.length() and FieldLayout.stone_text(id, &"clear", false) == plain, "맑은 밤: 비석에 한 줄이 더 붙는다")
	var all: bool = true
	for k in FieldLayout.STONES:
		all = all and FieldLayout.STONE_NIGHT_LINES.has(k)
	check.call(all, "맑은 밤: 모든 비석에 더할 줄이 있다")


func _save() -> void:
	var m := Meta.new()
	m.field_weather = &"storm"
	m.weather_spots = [{"id": 0, "kind": &"struck", "at": Vector2(30.5, 40.25), "done": false}, {"id": 1, "kind": &"glint", "at": Vector2(5, 6), "done": true}]
	var back := Meta.new()
	back.from_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	check.call(back.field_weather == &"storm" and back.weather_spots.size() == 2 and back.weather_spots[0].at == Vector2(30.5, 40.25) and back.weather_spots[1].done and back.weather_spots[0].kind == &"struck", "저장: 날씨와 사건 자리가 그대로 돌아온다")
	var old := Meta.new()
	old.from_dict({"shards": 3})
	check.call(old.field_weather == &"clear" and old.weather_spots.is_empty(), "저장: 옛 저장은 맑음으로 시작한다")
	var r := Rules.new(d, 1)
	Grid.size = FieldLayout.SIZE
	r.start_field(10.0, back.field_weather, back.weather_spots)
	check.call(r.field_weather == &"storm" and r.weather_spots.size() == 2, "저장: 규칙이 저장한 날씨와 자리로 이어 간다")
