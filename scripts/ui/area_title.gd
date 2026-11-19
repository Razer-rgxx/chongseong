class_name AreaTitle
extends Control
## 새 곳에 들어설 때 화면 가운데 조금 위에 큰 글자로 이름을 띄웠다가 지운다(엘든 링의 지역 이름처럼).
## 글자 밑에 양 끝이 사라지는 가는 줄 하나. 뽑기 연출 위에는 쓰지 않는다.

@export var fade_in: float = 0.8
@export var hold: float = 2.2
@export var fade_out: float = 1.4

var _label: Label
var _t: float = -1.0


static func make(parent: Node) -> AreaTitle:
	var a := AreaTitle.new()
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	a.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(a)
	a._build()
	return a


func _build() -> void:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.anchor_top = 0.36
	box.anchor_bottom = 0.36
	box.offset_left = -360
	box.offset_right = 360
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	_label = UiKit.label("", 46, UiKit.TITLE)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_label.add_theme_constant_override("shadow_offset_x", 0)
	_label.add_theme_constant_override("shadow_offset_y", 2)
	_label.add_theme_constant_override("shadow_outline_size", 10)
	box.add_child(_label)
	var r := UiKit.rule(560.0, UiKit.LINE, 0.8)
	r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(r)
	modulate.a = 0.0


func show_title(t: String) -> void:
	_label.text = t
	_t = 0.0


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	if _t < fade_in:
		modulate.a = _t / fade_in
	elif _t < fade_in + hold:
		modulate.a = 1.0
	elif _t < fade_in + hold + fade_out:
		modulate.a = 1.0 - (_t - fade_in - hold) / fade_out
	else:
		modulate.a = 0.0
		_t = -1.0
