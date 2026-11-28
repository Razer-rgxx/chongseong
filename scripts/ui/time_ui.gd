class_name TimeUi
extends Control
## 시대 표시와 시대 고르기 창(docs/stranger.md 4단계). 타임트래블러를 얻은 뒤에만 보인다. 구석에 놋쇠빛 작은 글자로 시대를 적고,
## T로 작은 창("현재 시대 / 미래")을 연다. 고르면 picked(era)를 알린다. 싸움 중인지는 부르는 쪽이 본다(Meta.can_travel).

signal picked(era: StringName)
signal closed

var _meta: Meta
var _era: StringName = TimeTravel.ERA_NOW
var _tag: Label
var _win: Control = null


static func make(parent: Node, meta: Meta, era: StringName) -> TimeUi:
	var u := TimeUi.new()
	u._meta = meta
	u._era = era
	u.set_anchors_preset(Control.PRESET_FULL_RECT)
	u.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(u)
	u._build()
	return u


func _build() -> void:
	_tag = UiKit.label("", 14, UiKit.LINE)
	_tag.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tag.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tag.offset_right = -16.0
	_tag.offset_bottom = -12.0
	UiKit.soft_shadow(_tag)
	add_child(_tag)
	refresh()


func refresh() -> void:
	_tag.visible = _meta.time_traveller
	_tag.text = "시대 · %s" % TimeTravel.NAMES[_era]


func is_open() -> bool:
	return _win != null


func toggle() -> void:
	if _win != null:
		close()
	elif _meta.time_traveller:
		_open()


func close() -> void:
	if _win == null:
		return
	_win.queue_free()
	_win = null
	closed.emit()


func _open() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_win = holder
	var box: VBoxContainer = UiKit.center_panel(holder)
	box.custom_minimum_size = Vector2(300, 0)
	UiKit.header(box, "시대를 고른다", close)
	box.add_child(UiKit.label("싸움 중에는 시간이 열리지 않는다.", 13, UiKit.MUTED))
	var eras: Array = [TimeTravel.ERA_NOW, TimeTravel.ERA_FUTURE]
	if _meta.past_open():
		eras.append(TimeTravel.ERA_PAST)
	for era in eras:
		var here: bool = era == _era
		var b := UiKit.button("%s%s" % [TimeTravel.NAMES[era], "  (지금 여기)" if here else ""], func() -> void: picked.emit(era), 40.0)
		b.disabled = here
		box.add_child(b)
