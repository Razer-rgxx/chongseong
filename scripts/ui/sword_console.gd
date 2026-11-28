class_name SwordConsole
extends Control
## 관리: 원하는 검 받기(` 또는 F6). 번호(1~300), 이름 일부, 공격 방식 이름, 형태, 등급, 각인, "갈고리"로 찾는다.
## 낱말을 여러 개 쓰면 모두 맞는 검만(예: "신화 불꽃", "갈고리 대검"). 끝에 1이나 2를 붙이면 그 칸에 받는다.
## "조각 500"처럼 쓰고 Enter면 조각을 준다(shards_given, 음수면 뺀다).
## ↑↓로 고르고 Enter로 받는다. Esc나 같은 키로 닫는다. 열려 있는 동안 싸움은 멈춘다(main이 틱을 돌리지 않는다).

signal picked(d: SwordData, slot: int)
signal closed
signal shards_given(n: int)
## 낱말 명령(날씨·재료·머리, AdminCmd): {name, args}.
signal command(cmd: Dictionary)

const SHOW: int = 9

var data: GameData
var _field: LineEdit
var _list: VBoxContainer
var _count: Label
var _hits: Array[SwordData] = []
var _sel: int = 0
var _slot: int = -1
var _give: int = 0   # "조각 N"이면 N, 아니면 0
var _cmd: Dictionary = {}   # "날씨 비" 같은 명령이면 그것


func setup(d: GameData) -> void:
	data = d


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var box := UiKit.center_panel(self)
	box.custom_minimum_size = Vector2(620, 0)
	UiKit.header(box, "관리: 검 받기", close)
	var hint := UiKit.label("번호, 이름, 공격 방식, 형태, 등급, 각인, \"갈고리\"로 찾는다. \"조각 500\"은 조각 주기. 끝에 1이나 2를 붙이면 그 칸. ↑↓ 고르기 · Enter 받기 · Esc 닫기", 13, UiKit.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)
	_field = LineEdit.new()
	_field.placeholder_text = "예: 37 · 꺼지지 · 갈고리 대검 · 신화 불꽃 2"
	_field.custom_minimum_size = Vector2(0, 40)
	_field.text_changed.connect(_search)
	_field.text_submitted.connect(func(_t: String) -> void: _pick())
	box.add_child(_field)
	_count = UiKit.label("", 13, UiKit.MUTED)
	box.add_child(_count)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	box.add_child(_list)


func open() -> void:
	# 부모(HUD)의 크기와 상관없이 화면 전체를 덮는다
	position = Vector2.ZERO
	size = get_viewport_rect().size
	visible = true
	_field.text = ""
	_search("")
	_field.grab_focus()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var k := event as InputEventKey
	if k == null or not k.pressed:
		return
	match k.physical_keycode:
		KEY_ESCAPE, KEY_QUOTELEFT, KEY_F6:
			close()
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			_move(1)
			get_viewport().set_input_as_handled()
		KEY_UP:
			_move(-1)
			get_viewport().set_input_as_handled()


func _move(dir: int) -> void:
	if _hits.is_empty():
		return
	_sel = clampi(_sel + dir, 0, mini(_hits.size(), SHOW) - 1)
	_draw()


## 검 하나를 찾을 때 비교하는 글: 번호, 이름, 등급, 형태, 공격 방식, 각인, 갈고리.
func _hay(s: SwordData) -> String:
	var parts: PackedStringArray = [str(s.id), s.display_name, data.grades.names[s.grade]]
	if s.form >= 0 and s.form < data.forms.size():
		parts.append(data.forms[s.form].display_name)
	var p: PatternData = data.pattern_for(s)
	if p:
		parts.append(p.display_name)
		if p.has_hook():
			parts.append("갈고리")
	for i in s.inscriptions:
		parts.append(i)
	return " ".join(parts)


func _search(q: String) -> void:
	_hits.clear()
	_sel = 0
	_slot = -1
	_give = 0
	_cmd = AdminCmd.parse(q)
	if not _cmd.is_empty():
		_draw()
		return
	var words: PackedStringArray = q.strip_edges().split(" ", false)
	if words.size() == 2 and words[0] == "조각" and words[1].is_valid_int():
		_give = int(words[1])
		_draw()
		return
	# 끝의 1, 2는 칸(낱말이 두 개 이상일 때)
	if words.size() >= 2 and (words[-1] == "1" or words[-1] == "2"):
		_slot = int(words[-1]) - 1
		words.remove_at(words.size() - 1)
	if not words.is_empty():
		for s in data.swords:
			var ok: bool = true
			var hay: String = ""
			for w in words:
				if w.is_valid_int():
					if s.id != int(w):
						ok = false
						break
					continue
				if hay == "":
					hay = _hay(s)
				if hay.findn(w) < 0:
					ok = false
					break
			if ok:
				_hits.append(s)
	_draw()


func _draw() -> void:
	for c in _list.get_children():
		c.queue_free()
	if _field.text.strip_edges() == "":
		_count.text = "찾을 말을 쓰면 여기에 나온다."
		return
	if not _cmd.is_empty():
		_count.text = AdminCmd.describe(_cmd)
		return
	if _give != 0:
		_count.text = "Enter: 조각 %+d" % _give
		return
	_count.text = "%d자루%s" % [_hits.size(), (" · %d번 칸에 받는다" % (_slot + 1)) if _slot >= 0 else " · 지금 쥔 칸에 받는다"]
	if _hits.is_empty():
		_count.text = "맞는 검이 없다."
		return
	for i in mini(_hits.size(), SHOW):
		var s: SwordData = _hits[i]
		var row := PanelContainer.new()
		var on: bool = i == _sel
		row.add_theme_stylebox_override("panel", UiKit.style(Color(UiKit.LINE, 0.8 if on else 0.0), 1, Color(0.12, 0.1, 0.07, 0.9) if on else Color(0, 0, 0, 0)))
		var p: PatternData = data.pattern_for(s)
		var form: String = data.forms[s.form].display_name if s.form >= 0 and s.form < data.forms.size() else ""
		var t: String = "%03d  %s   ·   %s %s   ·   %s%s" % [s.id, s.display_name, data.grades.names[s.grade], form, p.display_name if p else "", "   ·   우클릭 갈고리" if p and p.has_hook() else ""]
		var l := UiKit.label(t, 15, (data.grades.colors[s.grade] as Color).lightened(0.2) if s.grade > 0 else UiKit.TEXT)
		row.add_child(l)
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		var idx: int = i
		row.gui_input.connect(func(e: InputEvent) -> void:
			var mb := e as InputEventMouseButton
			if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_sel = idx
				_pick())
		_list.add_child(row)
	if _hits.size() > SHOW:
		_list.add_child(UiKit.label("… %d자루 더" % (_hits.size() - SHOW), 13, UiKit.MUTED))


func _pick() -> void:
	if not _cmd.is_empty():
		var c: Dictionary = _cmd
		close()
		command.emit(c)
		return
	if _give != 0:
		var n: int = _give
		close()
		shards_given.emit(n)
		return
	if _hits.is_empty():
		return
	var d: SwordData = _hits[_sel]
	var slot: int = _slot
	close()
	picked.emit(d, slot)
