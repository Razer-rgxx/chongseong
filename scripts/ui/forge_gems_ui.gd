class_name ForgeGemsUi
extends VBoxContainer
## 대장간 "보석 박기" 그림 창(2026-11-26, 모양팀). 왼쪽 검 카드(그림 썸네일), 가운데 3D 미리보기(돌리기, 빈 자리 고리),
## 그 아래 룬 무늬 줄과 보석 자리 줄, 아래에 보석 주머니와 사는 줄. 글자는 마우스를 올릴 때(툴팁)와 이름칸·조각 숫자뿐이다.
## 규칙은 Meta가 그대로 한다(socket_gem, unsocket_gem, buy_gem). 이 창은 고르고 부르기만 한다.

var data: GameData
var meta: Meta
var changed: Callable   # 저장과 forge_changed 신호는 부른 쪽이 한다
var sel: int = -1
var pick_gem: String = ""        # 들고 있는 보석("종류:단계")
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


## 룬이 새겨진 검(찾은 것만). 쥐는 검집의 검이 먼저.
func swords() -> Array[int]:
	var out: Array[int] = []
	for k in meta.sword_runes:
		var id: int = int(k)
		if meta.runes_of(id).size() > 0 and meta.has_found(id):
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
		pick_gem = ""
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
		var gems_now: Array = meta.gems_of(sel)
		var sockets: int = meta.socket_count(sel)
		_preview.show_sword(d, data, meta.runes_of(sel), gems_now, sockets)
		_preview.set_hot(pick_gem != "" and gems_now.size() < sockets)
		_mid.add_child(_rune_row(T))
		_mid.add_child(_slot_row(T, gems_now, sockets))
		if remove_idx >= 0 and remove_idx < gems_now.size():
			_mid.add_child(_confirm_row(T, String(gems_now[remove_idx])))
	else:
		_mid.add_child(UiKit.label("룬이 새겨진 검이 없다 (벤 적 %d)" % T.slot_kills[0], 15, UiKit.MUTED))
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
		var tip: String = "%s · %s\n룬 %d · 벤 적 %d" % [Meta.shown_name(d), data.grades.names[d.grade], meta.runes_of(id).size(), meta.kills_of(id)]
		var i: int = id
		var t := ForgeTile.card(th.want(d, data), data.grades.colors[d.grade], tip, func() -> void: _select(i))
		t.set_selected(id == sel)
		_cards[id] = t
		_grid.add_child(t)
	_picker_scroll.set_deferred("scroll_vertical", keep)


func _on_thumb(id: int) -> void:
	var t: ForgeTile = _cards.get(id)
	if t != null and is_instance_valid(t):
		t.tex = ForgeThumbs.cache.get(id)
		t.queue_redraw()


func _select(id: int) -> void:
	if id == sel:
		return
	sel = id
	pick_gem = ""
	remove_idx = -1
	msg_text = ""
	refresh()


# ---------------------------------------------------------------- 룬·자리

func _rune_row(T: RuneTable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var runes: Array = meta.runes_of(sel)
	for i in T.slot_kills.size():
		if i < runes.size():
			var key: String = String(runes[i])
			row.add_child(ForgeTile.rune(maxi(0, T.rune_order.find(key)) % 4, "%s\n%s" % [T.rune_name(key), T.runes[key].text]))
		else:
			row.add_child(ForgeTile.rune(i % 4, "벤 적 %d (%d)" % [T.slot_kills[i], meta.kills_of(sel)], true))
	return row


func _slot_row(T: RuneTable, gems_now: Array, sockets: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in maxi(sockets, 1):
		var idx: int = i
		if i >= sockets:
			var lock := ForgeTile.socket([], "룬이 더 새겨지면 열린다", func() -> void: pass)
			lock.modulate = Color(1, 1, 1, 0.35)
			row.add_child(lock)
		elif i < gems_now.size():
			var key: String = String(gems_now[i])
			row.add_child(ForgeTile.socket([T.gem_color(key), int(key.split(":")[1])], "%s\n%s +%d%%" % [T.gem_name(key), T.gems[key.split(":")[0]].text, roundi(T.gem_value(key) * 100.0)], func() -> void: _on_socket(idx)))
		else:
			row.add_child(ForgeTile.socket([], "빈 자리", func() -> void: _on_socket(idx)))
	return row


func _on_socket(i: int) -> void:
	var gems_now: Array = meta.gems_of(sel)
	if i < gems_now.size():   # 박힌 보석: 빼기 확인
		remove_idx = i
		pick_gem = ""
		msg_text = ""
		refresh()
		return
	if pick_gem == "":
		msg_text = ""
		return
	var r: String = meta.socket_gem(sel, pick_gem)
	if r == "ok":
		pick_gem = ""
		changed.call()
	msg_text = {"ok": "박았다", "ruined": "풀무간이 무너졌다", "full": "자리가 없다"}.get(r, "박을 수 없다")
	refresh()


func _confirm_row(T: RuneTable, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(ForgeTile.gem(T.gem_color(key), int(key.split(":")[1]), 0, T.gem_name(key), func() -> void: pass, 40.0))
	var fee: int = int(T.remove_fee[int(key.split(":")[1]) - 1])
	row.add_child(UiKit.label("◇ %d  ?" % fee, 18, UiKit.TITLE if meta.shards >= fee else Color(0.86, 0.36, 0.28)))
	row.add_child(UiKit.button("✓", func() -> void:
		var r: String = meta.unsocket_gem(sel, remove_idx)
		if r == "ok":
			changed.call()
		msg_text = "뺐다" if r == "ok" else "조각이 모자라다"
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
	for type in T.gem_order:
		for tier in range(1, 4):
			var k: String = "%s:%d" % [type, tier]
			if int(meta.gem_bag.get(k, 0)) > 0:
				out.append(k)
	return out


func _gem_tip(T: RuneTable, key: String) -> String:
	return "%s\n%s +%d%%" % [T.gem_name(key), T.gems[key.split(":")[0]].text, roundi(T.gem_value(key) * 100.0)]


func _pouch_row(T: RuneTable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var keys := _bag_keys()
	if keys.is_empty():
		var e := ForgeTile.gem(Color(0.5, 0.5, 0.5), 1, 0, "주머니가 비었다", func() -> void: pass)
		row.add_child(e)
	for k in keys:
		var key: String = k
		var t := ForgeTile.gem(T.gem_color(key), int(key.split(":")[1]), int(meta.gem_bag[key]), _gem_tip(T, key), func() -> void:
			pick_gem = "" if pick_gem == key else key
			remove_idx = -1
			msg_text = ""
			refresh())
		t.set_selected(key == pick_gem)
		row.add_child(t)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(620, 62)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(row)
	return sc


func _shop_row(T: RuneTable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	for type in T.gem_order:
		for tier in range(1, 4):
			var key: String = "%s:%d" % [type, tier]
			var cost: int = int(T.buy_cost[tier - 1])
			var t := ForgeTile.gem(T.gem_color(key), tier, 0, "%s\n◇ %s" % [T.gem_name(key), ForgeGemsUi.num(cost)], func() -> void:
				var r: String = meta.buy_gem(type, tier)
				if r == "ok":
					changed.call()
				msg_text = "샀다" if r == "ok" else "조각이 모자라다"
				refresh(), 32.0)
			t.dim = meta.shards < cost
			t.badge = "+"
			row.add_child(t)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(620, 40)
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(row)
	return sc


func _foot_row(T: RuneTable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiKit.label("◇ %s" % ForgeGemsUi.num(meta.shards), 20, UiKit.TITLE))
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
			lk.tooltip_text = "룬 %d개가 새겨지면 이름을 지을 수 있다" % T.name_runes
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
