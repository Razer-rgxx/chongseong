class_name DialogueBox
extends Control
## 사람과 이야기할 때 화면 아래 가운데에 뜨는 대사(엘든 링식 자막).
## 양 끝으로 사라지는 검은 띠 위아래에 놋쇠빛 가는 줄, 위에 말하는 사람 이름(놋쇠빛, 작게), 그 아래 가는 줄, 대사(크게, 줄바꿈 자동).
## 오른쪽 아래에 "E 다음" 칸. 줄이 바뀌면 대사만 살짝 사라졌다 나타난다. 띠(Band)와 따로 쓴다: 안내 띠는 그대로 둔다.

const WIDTH: float = 1180.0
const TEXT_WIDTH: float = 860.0
const BOTTOM: float = 70.0      ## 화면 아래에서 띠 아래끝까지(px)
const FADE_IN: float = 0.18
const FADE_OUT: float = 0.3
const LINE_FADE: float = 0.14

var _name: Label
var _line: Label
var _hint: Label
var _hold: bool = false
var _line_t: float = 1.0


static func make(parent: Node) -> DialogueBox:
	var d := DialogueBox.new()
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	d.offset_left = -WIDTH / 2.0
	d.offset_right = WIDTH / 2.0
	d.grow_vertical = Control.GROW_DIRECTION_BEGIN
	d.offset_bottom = -BOTTOM
	d.offset_top = -BOTTOM - 172.0
	parent.add_child(d)
	d._build()
	return d


func _build() -> void:
	var bg := TextureRect.new()
	bg.texture = UiKit.fade_texture(Color(0.01, 0.008, 0.006), 0.82, 0.2)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	for top in [true, false]:
		var r := UiKit.rule(0.0, UiKit.LINE, 0.5)
		r.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		r.offset_top = 0.0 if top else -1.0
		r.offset_bottom = 1.0 if top else 0.0
		add_child(r)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)
	_name = UiKit.label("", 17, UiKit.LINE)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_name)
	var rule := UiKit.rule(200.0, UiKit.LINE, 0.45)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(rule)
	_line = UiKit.label("", 22, UiKit.TEXT)
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	_line.add_theme_constant_override("line_spacing", 6)
	_line.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_line.add_theme_constant_override("shadow_offset_y", 2)
	col.add_child(_line)
	# 오른쪽 아래: 다음으로 넘기는 키
	var hint := HBoxContainer.new()
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -250.0
	hint.offset_top = -40.0
	hint.offset_right = -150.0
	hint.offset_bottom = -12.0
	hint.alignment = BoxContainer.ALIGNMENT_END
	hint.add_theme_constant_override("separation", 8)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	var key := PanelContainer.new()
	var ks := UiKit.style(Color(UiKit.LINE, 0.7), 1, Color(0.06, 0.05, 0.04, 0.9))
	ks.content_margin_left = 7
	ks.content_margin_right = 7
	ks.content_margin_top = 0
	ks.content_margin_bottom = 1
	key.add_theme_stylebox_override("panel", ks)
	key.add_child(UiKit.label("E", 14, UiKit.TITLE))
	hint.add_child(key)
	_hint = UiKit.label("다음", 14, UiKit.MUTED)
	hint.add_child(_hint)
	modulate.a = 0.0
	visible = false


func _process(delta: float) -> void:
	if _hold:
		modulate.a = minf(1.0, modulate.a + delta / FADE_IN)
	else:
		modulate.a = maxf(0.0, modulate.a - delta / FADE_OUT)
		visible = modulate.a > 0.0
	if _line_t < 1.0:
		_line_t = minf(1.0, _line_t + delta / LINE_FADE)
		_line.modulate.a = _line_t


## 대사 한 줄을 띄운다. who가 비면 이름 줄을 감춘다. last면 오른쪽 아래가 "닫기".
func show_line(who: String, text: String, last: bool = false) -> void:
	var changed: bool = _line.text != text
	_name.text = who
	_name.visible = who != ""
	_line.text = text
	_hint.text = "닫기" if last else "다음"
	if changed and visible and modulate.a > 0.5:
		_line_t = 0.0
		_line.modulate.a = 0.0
	_hold = true
	visible = true


func hide_box() -> void:
	_hold = false


func is_showing() -> bool:
	return _hold
