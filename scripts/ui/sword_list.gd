class_name SwordList
extends Control
## 내 검 목록(2026-11-25 사용자: 미래에서 "검이 뭐뭐 있는지"). 가진 검(Meta.yard_swords: 도감에 있고 잃지도 떨구지도 않은 검)을
## 등급 높은 것부터 줄로 보이고, 하나를 고르면 오른쪽에 카드(SwordCard)를 띄운다. 보기만 한다(버리기·바꿔 쥐기 없음).
## 지금 쥔 검·검집의 검·사이버 검은 표시를 붙인다. 열려 있는 동안 트리를 멈추지는 않는다(부르는 쪽이 판단).

signal closed

var _data: GameData
var _meta: Meta
var _held: Array[int] = []
var _list: VBoxContainer
var _card: RichTextLabel
var _card_box: PanelContainer
var _count: Label


## parent에 얹어 연다. held: 지금 손에 든 검 번호들(칸 순서).
static func open(parent: Node, data: GameData, meta: Meta, held: Array[int]) -> SwordList:
	var w := SwordList.new()
	w._data = data
	w._meta = meta
	w._held = held
	parent.add_child(w)
	return w


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var box := UiKit.center_panel(self)
	UiKit.header(box, "내 검", close)
	_count = UiKit.label("", 14, UiKit.MUTED)
	box.add_child(_count)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(430, 460)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_card_box = PanelContainer.new()
	_card_box.custom_minimum_size = Vector2(380, 0)
	row.add_child(_card_box)
	_card = UiKit.rich(15, 360)
	_card_box.add_child(_card)
	box.add_child(UiKit.label("Tab이나 Esc로 닫는다", 13, UiKit.MUTED))
	_fill()


func _fill() -> void:
	var ids: Array[int] = _meta.yard_swords(_data)
	for id in _held:   # 들고 나온 검은 목록에 없을 수 있다(떨군 검을 주워 든 경우 등)
		if id > 0 and not ids.has(id):
			ids.push_front(id)
	ids.sort_custom(func(a: int, b: int) -> bool:
		var da := _data.sword_by_id(a)
		var db := _data.sword_by_id(b)
		if da.grade != db.grade:
			return da.grade > db.grade
		return a < b)
	_count.text = "가진 검 %d자루 · 도감 %d/%d" % [ids.size(), _meta.found.size(), _data.swords.size()]
	if ids.is_empty():
		_list.add_child(UiKit.label("가진 검이 없다. 언덕에서 뽑아 와야 한다.", 16))
		_card_box.visible = false
		return
	var last_grade: int = -1
	var first: Button = null
	for id in ids:
		var d := _data.sword_by_id(id)
		if d == null:
			continue
		if d.grade != last_grade:
			last_grade = d.grade
			var g := UiKit.label(_data.grades.names[d.grade], 15, _data.grades.colors[d.grade])
			_list.add_child(g)
		var tags: PackedStringArray = []
		if _held.has(id):
			tags.append("쥔 검")
		if id == _meta.sheath_id:
			tags.append("검집")
		if d.cyber:
			tags.append("사이버")
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s · %s%s" % [d.display_name, _data.forms[d.form].display_name, ("   [" + " · ".join(tags) + "]") if not tags.is_empty() else ""]
		b.add_theme_color_override("font_color", _data.grades.colors[d.grade].lerp(UiKit.TEXT, 0.35))
		var sid: int = id
		b.pressed.connect(func() -> void: _show(sid))
		_list.add_child(b)
		if first == null:
			first = b
			_show(id)


func _show(id: int) -> void:
	var s: Sword = _meta.unbreakable_sword(_data, id)
	if s == null:
		return
	_card_box.add_theme_stylebox_override("panel", UiKit.style(_data.grades.colors[s.grade], 2))
	_card.text = SwordCard.bbcode(s, _data, -1, _held.has(id))


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and (k.physical_keycode == KEY_ESCAPE or k.physical_keycode == KEY_TAB):
		close()
		get_viewport().set_input_as_handled()
