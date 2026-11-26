class_name ForgeRunesUi
extends VBoxContainer
## 대장간 "룬 박기" 그림 창(2026-11-26). 왼쪽 검 카드(그림 썸네일), 가운데 3D 미리보기(돌리기, 빈 자리 고리),
## 그 아래 룬 자리 줄(잠김·빈 자리·박힌 룬), 아래에 룬 주머니와 사는 줄. 주머니의 룬을 누르고 빈 자리를 누르면 박힌다.
## 글자는 마우스를 올릴 때(툴팁)와 이름칸·조각 숫자뿐이다. 규칙은 Meta가 그대로 한다(socket_rune, unsocket_rune, buy_rune). 이 창은 고르고 부르기만 한다.

var data: GameData
var meta: Meta
var changed: Callable   # 저장과 forge_changed 신호는 부른 쪽이 한다
var sel: int = -1
var pick_rune: String = ""       # 들고 있는 룬("종류:단계")
var remove_idx: int = -1          # 빼기 확인 중인 자리
var msg_text: String = ""

var _preview: ForgePreview
var _picker_scroll: ScrollContainer
var _grid: GridContainer
var _cards: Dictionary = {}       # 검 번호 → ForgeTile
var _mid: VBoxContainer
var _bottom: VBoxContainer
var _name_edit: LineEdit
var _shown_id: int = -2


func setup(p_data: GameData, p_meta: Meta, p_changed: Callable) -> void:
	data = p_data
	meta = p_meta
	changed = p_changed
	add_theme_constant_override("separation", 8)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	add_child(top)
	_picker_scroll = ScrollContainer.new()
	_picker_scroll.custom_minimum_size = Vector2(228, 340)
	_picker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var pp := PanelContainer.new()
	pp.add_theme_stylebox_override("panel", UiKit.style(Color(UiKit.LINE, 0.3), 1, Color(0, 0, 0, 0.35)))
	pp.add_child(_picker_scroll)
	top.add_child(pp)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 6)
	_grid.add_theme_constant_override("v_separation", 6)
	_picker_scroll.add_child(_grid)
	_mid = VBoxContainer.new()
	_mid.add_theme_constant_override("separation", 6)
	top.add_child(_mid)
	_preview = ForgePreview.new()
	_preview.socket_clicked.connect(_on_socket)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiKit.style(Color(UiKit.LINE, 0.3), 1, Color(0.07, 0.065, 0.06, 0.9)))
	frame.add_child(_preview)
	_mid.add_child(frame)
	_bottom = VBoxContainer.new()
	_bottom.add_theme_constant_override("separation", 6)
	add_child(_bottom)


## 룬 자리가 열린 검(찾은 것만). 쥐는 검집의 검이 먼저.
func swords() -> Array[int]:
	var out: Array[int] = []
	for k in meta.slot_given:
		var id: int = int(k)
		if meta.rune_slots(id) > 0 and meta.has_found(id):
			out.append(id)
	out.sort()
	if meta.sheath_id in out:
		out.erase(meta.sheath_id)
		out.push_front(meta.sheath_id)
	return out


func refresh() -> void:
	var T: RuneTable = Meta.rt()
	var ids := swords()
	if not ids.has(sel):
		sel = ids[0] if not ids.is_empty() else -1
		pick_rune = ""
		remove_idx = -1
	_build_picker(ids)
	for c in _mid.get_children():
		if c != _preview.get_parent():
			c.queue_free()
	for c in _bottom.get_children():
		c.queue_free()
	_preview.get_parent().visible = sel >= 0
	if sel >= 0:
		var d := data.sword_by_id(sel)
		var runes_now: Array = meta.runes_of(sel)
		var slots: int = meta.rune_slots(sel)
		_preview.show_sword(d, data, runes_now, slots)
		_preview.set_hot(pick_rune != "" and runes_now.size() < slots)
		_mid.add_child(_slot_row(T, runes_now, slots))
		if remove_idx >= 0 and remove_idx < runes_now.size():
			_mid.add_child(_confirm_row(T, String(runes_now[remove_idx])))
	else:
		_mid.add_child(UiKit.label("룬 자리가 열린 검이 없다 (한 검으로 벤 적 %d)" % T.slot_kills[0], 15, UiKit.MUTED))
	_bottom.add_child(UiKit.rule())
	_bottom.add_child(_pouch_row(T))
	_bottom.add_child(_shop_row(T))
	_bottom.add_child(_foot_row(T))


# ---------------------------------------------------------------- 검 카드

func _build_picker(ids: Array[int]) -> void:
	var keep: int = _picker_scroll.scroll_vertical
	for c in _grid.get_children():
		c.queue_free()
	_cards.clear()
	var th := ForgeThumbs.ensure(self)
	if not th.done.is_connected(_on_thumb):
		th.done.connect(_on_thumb)
	for id in ids:
		var d := data.sword_by_id(id)
		var tip: String = "%s · %s\n룬 %d/%d · 벤 적 %d" % [Meta.shown_name(d), data.grades.names[d.grade], meta.runes_of(id).size(), meta.rune_slots(id), meta.kills_of(id)]
		var i: int = id
		var t := ForgeTile.card(th.want(d, data), data.grades.colors[d.grade], tip, func() -> void: _select(i))
		t.set_selected(id == sel)
		_cards[id] = t
		_grid.add_child(t)
	_picker_scroll.set_deferred("scroll_vertical", keep)


func _on_thumb(id: int) -> void:
	if id == -1:   # 룬 모델 그림이 새로 나왔다
		refresh()
		return
	var t: ForgeTile = _cards.get(id)
	if t != null and is_instance_valid(t):
		t.tex = ForgeThumbs.cache.get(id)
		t.queue_redraw()


func _select(id: int) -> void:
	if id == sel:
		return
	sel = id
	pick_rune = ""
	remove_idx = -1
	msg_text = ""
	refresh()


# ---------------------------------------------------------------- 룬·자리

## 룬 자리 줄: 열린 자리(빈 자리·박힌 룬)와 아직 안 열린 자리(벤 적 수가 툴팁).
func _slot_row(T: RuneTable, runes_now: Array, slots: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in T.slot_kills.size():
		var idx: int = i
		if i >= slots:
			var lock := ForgeTile.slot(-1, 1, "벤 적 %d에 열린다 (%d)" % [T.slot_kills[i], meta.kills_of(sel)], func() -> void: pass, true)
			lock.modulate = Color(1, 1, 1, 0.35)
			row.add_child(lock)
		elif i < runes_now.size():
			var key: String = String(runes_now[i])
			row.add_child(ForgeTile.slot(T.glyph_of(key), T.tier_of(key), _rune_tip(T, key) + "\n누르면 뺀다", func() -> void: _on_socket(idx)))
		else:
			row.add_child(ForgeTile.slot(-1, 1, "빈 자리", func() -> void: _on_socket(idx)))
	return row


func _on_socket(i: int) -> void:
	var runes_now: Array = meta.runes_of(sel)
	if i < runes_now.size():   # 박힌 룬: 빼기 확인
		remove_idx = i
		pick_rune = ""
		msg_text = ""
		refresh()
		return
	if pick_rune == "":
		msg_text = "주머니에서 룬을 먼저 고른다"
		refresh()
		return
	var r: String = meta.socket_rune(sel, pick_rune)
	if r == "ok":
		pick_rune = ""
		changed.call()
	msg_text = {"ok": "박았다", "ruined": "풀무간이 무너졌다", "full": "자리가 없다"}.get(r, "박을 수 없다")
	refresh()


func _confirm_row(T: RuneTable, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(ForgeTile.rune(T.glyph_of(key), T.tier_of(key), 0, _rune_tip(T, key), func() -> void: pass, 40.0))
	var fee: int = int(T.remove_fee[T.tier_of(key) - 1])
	row.add_child(UiKit.label("◇ %d  ?" % fee, 18, UiKit.TITLE if meta.shards >= fee else Color(0.86, 0.36, 0.28)))
	row.add_child(UiKit.button("✓", func() -> void:
		var r: String = meta.unsocket_rune(sel, remove_idx)
		if r == "ok":
			changed.call()
		msg_text = "뺐다" if r == "ok" else ("풀무간이 무너졌다" if r == "ruined" else "조각이 모자라다")
		remove_idx = -1
		refresh(), 34))
	row.add_child(UiKit.button("✕", func() -> void:
		remove_idx = -1
		refresh(), 34))
	return row


# ---------------------------------------------------------------- 주머니·사기·아래 줄

func _bag_keys() -> Array[String]:
	var out: Array[String] = []
	var T: RuneTable = Meta.rt()
	for type in T.rune_order:
		for tier in range(1, T.tier_mult.size() + 1):
			var k: String = "%s:%d" % [type, tier]
			if int(meta.rune_bag.get(k, 0)) > 0:
				out.append(k)
	return out


## 룬 타일에 Blender 룬 모델 그림을 달아 준다(없으면 납작한 무늬 그대로).
func _with_pic(t: ForgeTile, type: String) -> ForgeTile:
	t.tex = ForgeThumbs.ensure(self).want_rune(type)
	return t


func _rune_tip(T: RuneTable, key: String) -> String:
	return "%s\n%s" % [T.rune_name(key), T.rune_text(key)]


func _pouch_row(T: RuneTable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var keys := _bag_keys()
	if keys.is_empty():
		row.add_child(ForgeTile.rune(0, 1, 0, "룬 주머니가 비었다", func() -> void: pass))
	for k in keys:
		var key: String = k
		var t := ForgeTile.rune(T.glyph_of(key), T.tier_of(key), int(meta.rune_bag[key]), _rune_tip(T, key), func() -> void:
			pick_rune = "" if pick_rune == key else key
			remove_idx = -1
			msg_text = ""
			refresh())
		t.set_selected(key == pick_rune)
		row.add_child(_with_pic(t, T.type_of(key)))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(620, 62)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(row)
	return sc


func _shop_row(T: RuneTable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	for type in T.rune_order:
		for tier in range(1, T.tier_mult.size() + 1):
			var key: String = "%s:%d" % [type, tier]
			var cost: int = int(T.buy_cost[tier - 1])
			var t := ForgeTile.rune(T.glyph_of(key), tier, 0, "%s\n%s\n◇ %s" % [T.rune_name(key), T.rune_text(key), ForgeRunesUi.num(cost)], func() -> void:
				var r: String = meta.buy_rune(type, tier)
				if r == "ok":
					changed.call()
				msg_text = "샀다" if r == "ok" else "조각이 모자라다"
				refresh(), 32.0)
			t.dim = meta.shards < cost
			t.badge = "+"
			row.add_child(_with_pic(t, type))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(620, 40)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(row)
	return sc


func _foot_row(T: RuneTable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiKit.label("◇ %s" % ForgeRunesUi.num(meta.shards), 20, UiKit.TITLE))
	if sel >= 0:
		var sd := data.sword_by_id(sel)
		if meta.can_name(sd, data.grades):
			_name_edit = LineEdit.new()
			_name_edit.max_length = T.name_max
			_name_edit.placeholder_text = sd.display_name
			_name_edit.text = String(meta.sword_names.get(str(sel), ""))
			_name_edit.custom_minimum_size = Vector2(200, 0)
			_name_edit.tooltip_text = "검의 이름"
			row.add_child(_name_edit)
			row.add_child(UiKit.button("✓", func() -> void:
				var r: String = meta.set_sword_name(sd, _name_edit.text, data.grades)
				if r == "ok":
					changed.call()
				msg_text = "이름을 지었다" if r == "ok" else "한글·영문·숫자만"
				refresh(), 32))
		else:
			var lk := UiKit.label("✎", 20, UiKit.MUTED)
			lk.tooltip_text = "룬 자리 %d개가 열리면 이름을 지을 수 있다" % T.name_runes
			lk.mouse_filter = Control.MOUSE_FILTER_STOP
			row.add_child(lk)
	row.add_child(UiKit.label(msg_text, 16, UiKit.TITLE))
	return row


static func num(v: int) -> String:
	var s: String = str(absi(v))
	var out: String = ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out
