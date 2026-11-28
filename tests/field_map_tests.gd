extends RefCounted
## 38단계 들판 지도 테스트(docs/open_world2.md): 걸으면 둘레가 밝혀짐, 저장·읽기, 옛 저장, 지도 표시(본 곳만·흐리게), 곳 이름 자리, 키.
## run_all.gd가 부른다: run(데이터, check).

var d: GameData
var check: Callable


static func run(game: GameData, chk: Callable) -> void:
	var t: Object = (load("res://tests/field_map_tests.gd") as GDScript).new()
	t.set("d", game)
	t.set("check", chk)
	t.call("_all")


func _all() -> void:
	_grid()
	_reveal()
	_walk()
	_save()
	_old_save()
	_markers()
	_labels()
	_keys()
	_images()
	Grid.size = Vector2i(34, 22)


func _grid() -> void:
	var S: Vector2i = FieldLayout.SEEN_SIZE
	check.call(S.x * FieldLayout.SEEN_CELL >= FieldLayout.SIZE.x and S.y * FieldLayout.SEEN_CELL >= FieldLayout.SIZE.y, "지도: 밝힘 격자가 들판을 덮는다(%s × %d칸)" % [S, FieldLayout.SEEN_CELL])
	check.call((S.x - 1) * FieldLayout.SEEN_CELL < FieldLayout.SIZE.x and (S.y - 1) * FieldLayout.SEEN_CELL < FieldLayout.SIZE.y, "지도: 밝힘 격자가 들판보다 한 칸 넘게 크지 않다")
	var m := Meta.new()
	check.call(m.field_seen.size() == ceili(S.x * S.y / 8.0) and m.seen_count() == 0, "지도: 새 기록은 아무것도 안 봤다(%d바이트)" % m.field_seen.size())


func _reveal() -> void:
	var m := Meta.new()
	var at: Vector2 = FieldLayout.START
	var n: int = m.see_field(at)
	check.call(n > 0 and m.seen_at(at), "지도: 선 자리가 밝혀진다(%d칸)" % n)
	check.call(m.see_field(at) == 0, "지도: 같은 자리를 다시 밝히면 새로 밝힌 칸이 없다")
	var R: float = FieldLayout.SEEN_RADIUS
	var C: float = float(FieldLayout.SEEN_CELL)
	# 반지름 안은 모두, 반지름 + 칸 대각선 밖은 하나도
	var inside: bool = true
	var outside: bool = true
	for k in 36:
		var dir := Vector2.from_angle(TAU * k / 36.0)
		var near: Vector2 = (at + dir * (R - 0.5)).clamp(Vector2.ZERO, Vector2(FieldLayout.SIZE) - Vector2(0.01, 0.01))
		inside = inside and m.seen_at(near)
		var far: Vector2 = at + dir * (R + C * 1.5)
		if Rect2(Vector2.ZERO, Vector2(FieldLayout.SIZE)).has_point(far):
			outside = outside and not m.seen_at(far)
	check.call(inside, "지도: 반지름 %.0f칸 안은 모두 밝혀진다" % R)
	check.call(outside, "지도: 반지름 밖(칸 하나 반 넘어)은 그대로 어둡다")
	check.call(not m.seen_at(Vector2(200, 20)) and not m.seen_at(FieldLayout.TRAILHEAD), "지도: 먼 곳(채석장, 언덕길 끝)은 아직 안 봤다")
	# 가장자리·밖에서 불러도 격자 밖을 건드리지 않는다
	var e := Meta.new()
	e.see_field(Vector2(0, 0))
	e.see_field(Vector2(FieldLayout.SIZE) - Vector2(0.1, 0.1))
	e.see_field(Vector2(-50, -50))
	e.see_field(Vector2(500, 500))
	check.call(e.seen_cell(0, 0) and e.seen_cell(FieldLayout.SEEN_SIZE.x - 1, FieldLayout.SEEN_SIZE.y - 1) and not e.seen_cell(-1, 0) and not e.seen_cell(FieldLayout.SEEN_SIZE.x, 0), "지도: 들판 가장자리도 밝히고 격자 밖은 늘 안 본 것")
	check.call(e.field_seen.size() == ceili(FieldLayout.SEEN_SIZE.x * FieldLayout.SEEN_SIZE.y / 8.0), "지도: 밝혀도 격자 크기는 그대로")


## 장면처럼 들판 규칙으로 걸으며 SEEN_TICKS틱마다 밝힌다: 지나온 길은 밝고, 안 간 쪽은 어둡다.
func _walk() -> void:
	var r := Rules.new(d, 3)
	Grid.size = FieldLayout.SIZE
	r.start_field()
	r.lord.pos = Vector2(20, 60)
	var m := Meta.new()
	var t: int = 0
	var path: Array[Vector2] = []
	for k in 30 * 12:
		var inp := LordInput.new()
		inp.move = Vector2.RIGHT
		r.step(inp)
		t -= 1
		if t <= 0:
			t = FieldLayout.SEEN_TICKS
			m.see_field(r.lord.pos)
		if k % 30 == 0:
			path.append(r.lord.pos)
	var ok: bool = true
	for p in path:
		ok = ok and m.seen_at(p) and m.seen_at(p + Vector2(0, 12)) and m.seen_at(p + Vector2(0, -12))
	check.call(r.lord.pos.x > 60.0 and ok, "지도: 걸어간 길과 그 둘레(12칸)가 밝혀진다(%.0f칸까지 걸었다)" % r.lord.pos.x)
	check.call(not m.seen_at(Vector2(r.lord.pos.x + 30.0, 60)) and not m.seen_at(Vector2(40, 10)), "지도: 걸어가지 않은 곳은 어둡다")


func _save() -> void:
	var m := Meta.new()
	m.see_field(Vector2(84, 90))
	m.see_field(Vector2(200, 20))
	var n: int = m.seen_count()
	var path := "user://test_field_map.json"
	m.save(path)
	var b := Meta.load_or_new(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check.call(b.field_seen == m.field_seen and b.seen_count() == n and n > 0, "지도: 가 본 곳을 저장하고 그대로 읽는다(%d칸)" % n)
	check.call(b.seen_at(Vector2(84, 90)) and b.seen_at(Vector2(200, 20)) and not b.seen_at(Vector2(30, 10)), "지도: 읽은 뒤에도 같은 곳이 밝다")
	var dd: Dictionary = m.to_dict()
	check.call(dd.get("field_seen") is String and String(dd.field_seen).length() < 400, "지도: 저장은 짧은 글(base64, %d자)" % String(dd.field_seen).length())


func _old_save() -> void:
	var old := Meta.new()
	old.from_dict({"shards": 7, "field_clock": 10.0})
	check.call(old.shards == 7 and old.seen_count() == 0 and old.field_seen.size() == Meta.empty_seen().size(), "지도: 옛 저장(칸 없음)은 아무것도 안 본 상태")
	var bad := Meta.new()
	bad.from_dict({"field_seen": Marshalls.raw_to_base64(PackedByteArray([255, 255, 255]))})
	check.call(bad.seen_count() == 0 and bad.field_seen.size() == Meta.empty_seen().size(), "지도: 크기가 다른 격자는 안 본 것으로 읽는다")
	var junk := Meta.new()
	junk.from_dict({"field_seen": 12})
	check.call(junk.seen_count() == 0, "지도: 모르는 값도 안 본 것으로 읽는다")


func _kinds(list: Array[Dictionary], kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for mk in list:
		if mk.kind == kind:
			out.append(mk)
	return out


func _markers() -> void:
	var m := Meta.new()
	var none: Array[Dictionary] = FieldMap.markers(m)
	check.call(_kinds(none, &"gate").size() == 1 and _kinds(none, &"trail").size() == 1 and _kinds(none, &"crypt").size() == 1, "지도 표시: 북문·언덕길·무덤 입구는 안 본 곳이어도 있다")
	check.call(_kinds(none, &"chief").is_empty() and _kinds(none, &"cache").is_empty() and _kinds(none, &"boss").is_empty() and _kinds(none, &"wanderer").is_empty(), "지도 표시: 안 본 곳의 우두머리·상자·사람은 없다")
	check.call(_kinds(none, &"dropped").is_empty(), "지도 표시: 떨군 검이 없으면 없다")
	m.dropped = {"id": 1, "x": 200.0, "y": 20.0}
	check.call(_kinds(FieldMap.markers(m), &"dropped").size() == 1 and _kinds(FieldMap.markers(m), &"dropped")[0].at == Vector2(200, 20), "지도 표시: 떨군 검은 안 본 곳이어도 있다")
	# 망루 둘레를 보면 망루 우두머리·상자가 나온다
	var tower: Vector2 = FieldLayout.CHIEFS["chief_tower"].at
	m.see_field(tower)
	var seen: Array[Dictionary] = FieldMap.markers(m)
	var ch: Array[Dictionary] = _kinds(seen, &"chief")
	check.call(ch.any(func(x: Dictionary) -> bool: return x.id == "chief_tower" and not x.faded), "지도 표시: 본 곳의 우두머리는 진하게")
	check.call(not ch.any(func(x: Dictionary) -> bool: return x.id == "chief_pass"), "지도 표시: 안 본 곳의 우두머리는 없다")
	m.chiefs_down = {"chief_tower": 1}
	check.call(_kinds(FieldMap.markers(m), &"chief").any(func(x: Dictionary) -> bool: return x.id == "chief_tower" and x.faded), "지도 표시: 잡은 우두머리는 흐리게")
	var cid: String = ""
	for id in FieldLayout.CACHES:
		if m.seen_at(FieldLayout.CACHES[id][0]):
			cid = id
			break
	check.call(cid != "" and _kinds(FieldMap.markers(m), &"cache").any(func(x: Dictionary) -> bool: return x.id == cid and not x.faded), "지도 표시: 본 곳의 유품 상자(%s)" % cid)
	m.field_found[cid] = 1
	check.call(_kinds(FieldMap.markers(m), &"cache").any(func(x: Dictionary) -> bool: return x.id == cid and x.faded), "지도 표시: 연 상자는 흐리게")
	# 무덤 기사
	m.see_field(FieldLayout.BOSS_AT)
	check.call(_kinds(FieldMap.markers(m), &"boss").size() == 1 and not _kinds(FieldMap.markers(m), &"boss")[0].faded, "지도 표시: 본 옛 싸움터의 무덤 기사")
	m.boss_down = true
	check.call(_kinds(FieldMap.markers(m), &"boss")[0].faded, "지도 표시: 쓰러뜨린 무덤 기사는 흐리게")
	# 떠도는 사람은 본 곳에 있을 때만
	m.wanderer = "pilgrim"
	m.wanderer_at = FieldLayout.WANDERER_SPOTS.size() - 1
	var far: Vector2 = FieldLayout.WANDERER_SPOTS[m.wanderer_at].at
	check.call(not m.seen_at(far) and _kinds(FieldMap.markers(m), &"wanderer").is_empty(), "지도 표시: 안 본 곳의 떠도는 사람은 없다")
	m.see_field(far)
	check.call(_kinds(FieldMap.markers(m), &"wanderer").size() == 1, "지도 표시: 본 곳의 떠도는 사람")
	m.wanderer = ""
	check.call(_kinds(FieldMap.markers(m), &"wanderer").is_empty(), "지도 표시: 아무도 없으면 없다")
	# 나무만 고른다(돌기둥·수레·모닥불 둘레는 뺀다)
	var trees: PackedVector2Array = FieldMap.tree_spots([[Vector2(1, 1), 0.3], [Vector2(2, 2), 0.35], [Vector2(3, 3), 0.4], [Vector2(4, 4), 1.5], [Vector2(5, 5), 0.5]])
	check.call(trees == PackedVector2Array([Vector2(1, 1), Vector2(2, 2)]), "지도: 막힘 원 중 나무 둥치만 나무로 그린다")


func _labels() -> void:
	var ok: bool = true
	var bad: Array[String] = []
	for a in FieldLayout.AREA_NAMES:
		if not FieldLayout.MAP_LABELS.has(a):
			bad.append(str(a))
			continue
		var at: Vector2 = FieldLayout.MAP_LABELS[a]
		if FieldLayout.area_at(at) != a:
			bad.append("%s→%s" % [a, FieldLayout.area_at(at)])
	check.call(bad.is_empty(), "지도: 곳마다 이름 자리가 있고 그 곳 안에 있다 %s" % [bad])
	var m := Meta.new()
	check.call(FieldMap.labels(m).is_empty(), "지도: 안 본 곳의 이름은 안 나온다")
	m.see_field(FieldLayout.MAP_LABELS[&"old_field"])
	var ls: Array = FieldMap.labels(m)
	check.call(ls.any(func(x: Array) -> bool: return x[0] == &"old_field") and not ls.any(func(x: Array) -> bool: return x[0] == &"pass"), "지도: 본 곳의 이름만 나온다")


func _keys() -> void:
	var cfg := ConfigFile.new()
	cfg.load("res://project.godot")
	var ev: Variant = cfg.get_value("input", "map", {})
	var has_m: bool = false
	if ev is Dictionary:
		for e in (ev as Dictionary).get("events", []):
			has_m = has_m or (e is InputEventKey and (e as InputEventKey).physical_keycode == KEY_M)
	check.call(has_m, "지도: 행동 map = M")
	var named: bool = false
	for a in GameSettings.ACTIONS:
		named = named or (a[0] == "map" and a[1] == "지도")
	check.call(named, "지도: 설정 창에서 지도 키를 바꿀 수 있다(GameSettings.ACTIONS)")


## 그림 만들기(창 없이): 땅은 들판 크기 × BASE_PX, 먹구름은 본 곳이 투명하고 안 본 곳이 짙다.
func _images() -> void:
	var t0: int = Time.get_ticks_msec()
	var base: Image = FieldMap.base_image()
	var ms: int = Time.get_ticks_msec() - t0
	check.call(base.get_width() == FieldLayout.SIZE.x * FieldMap.BASE_PX and base.get_height() == FieldLayout.SIZE.y * FieldMap.BASE_PX, "지도: 땅 그림 크기 %d × %d(%dms)" % [base.get_width(), base.get_height(), ms])
	var bz: float = FieldBuilder.brook_z(60.0) / Grid.CELL
	var water: Color = base.get_pixel(int(30 * FieldMap.BASE_PX), int(bz * FieldMap.BASE_PX))
	var land: Color = base.get_pixel(int(30 * FieldMap.BASE_PX), int(80 * FieldMap.BASE_PX))
	check.call(water.b > water.r and land.r >= land.b, "지도: 개울은 푸른 먹, 땅은 누런 먹")
	var m := Meta.new()
	m.see_field(Vector2(84, 90))
	var fog: Image = FieldMap.fog_image(m)
	var c: int = FieldMap.FOG_PX
	var lit: float = fog.get_pixel(int(84.0 / FieldLayout.SEEN_CELL * c), int(90.0 / FieldLayout.SEEN_CELL * c)).a
	var dark: float = fog.get_pixel(int(200.0 / FieldLayout.SEEN_CELL * c), int(20.0 / FieldLayout.SEEN_CELL * c)).a
	check.call(lit < 0.05 and dark > 0.95, "지도: 먹구름은 본 곳에서 걷히고(%.2f) 안 본 곳을 덮는다(%.2f)" % [lit, dark])
